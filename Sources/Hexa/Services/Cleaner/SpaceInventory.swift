// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import Darwin
import Foundation

/// One informational line of "Onde está o espaço": a known large folder, its
/// allocated size and its path. It is not an `Item` and has no selection flag
/// and no removal path, so `cleanSelected` and `mayRemove` cannot reach it.
struct SpaceInventoryRow: Identifiable, Equatable {
    let location: SpaceInventory.Location
    let url: URL
    let size: Int64

    var id: String { url.path }
}

/// One measured folder of the space map: the folder, the bytes it holds and
/// whether part of it could not be read. It is not an `Item`: it has no
/// selection flag and no removal path, so the map can never clean anything.
struct SpaceMapEntry: Identifiable, Equatable {
    let url: URL
    let size: Int64
    /// A denied descendant cut the walk short: the size is a floor, never a
    /// complete total.
    let partial: Bool

    var id: String { url.path }
}

/// A path the walk could not read, kept with the reason it failed.
struct SpaceMapDenial: Identifiable, Equatable {
    /// Why the read failed. It is the app's own word, never the system's
    /// localized message, so the section can say it in the user's language.
    enum Reason: Equatable {
        case accessDenied
        case unavailable
    }

    let url: URL
    let reason: Reason

    var id: String { url.path }
}

/// The figures of one volume. A read that failed stays unavailable (`nil`) and
/// is never reported as zero.
struct SpaceVolume: Equatable {
    let total: Int64?
    let free: Int64?

    var isAvailable: Bool { total != nil && free != nil }

    /// Used is the difference of the two figures read from the same volume.
    var used: Int64? {
        guard let total, let free else { return nil }
        return max(0, total - free)
    }

    /// Strictly below 10 percent free.
    var lowSpace: Bool {
        guard let total, let free, total > 0 else { return false }
        return Double(free) / Double(total) < 0.1
    }

    /// Reads the volume that holds `url`. A refused read leaves both figures out.
    static func read(for url: URL) -> SpaceVolume {
        let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
        return SpaceVolume(total: values?.volumeTotalCapacity.map(Int64.init),
                           free: values?.volumeAvailableCapacity.map(Int64.init))
    }
}

/// The estimated system data: the measured first-level children of `~/Library`.
/// The estimate is partial by construction and is never derived from what is
/// left on the volume.
struct SpaceSystemData: Equatable {
    let size: Int64
    let partial: Bool
}

/// The measured space map: the largest folders, the refusals met, the volume
/// figures and the estimated system data. Read-only: it carries no selection,
/// no `Item` and no removal path, so nothing here can be cleaned.
struct SpaceMap: Equatable {
    /// How many folders the ranking shows.
    static let rankingLimit = 10

    /// Every measured folder, largest first.
    let entries: [SpaceMapEntry]
    let denials: [SpaceMapDenial]
    let volume: SpaceVolume
    let systemData: SpaceSystemData?
    /// A cancel ended the walk: the figures are what was measured so far.
    let cancelled: Bool

    /// The ten largest measured folders.
    var ranking: [SpaceMapEntry] { Array(entries.prefix(Self.rankingLimit)) }

    /// The sum of every measured folder. It counts each byte once by
    /// construction: `~/Library` is measured through its children and is never
    /// an entry itself. `systemData` is the sum of those same children, so it
    /// is not added here again.
    var measuredTotal: Int64 { entries.reduce(0) { $0 + $1.size } }

    /// Nothing was measured and nothing was refused.
    var isEmpty: Bool { entries.isEmpty && denials.isEmpty }

    /// The same map, marked as the result of a cancelled walk.
    func markedCancelled() -> SpaceMap {
        SpaceMap(entries: entries, denials: denials, volume: volume,
                 systemData: systemData, cancelled: true)
    }
}

/// The fixed locations the attended scan measures. Read-only: only metadata is
/// read (allocated sizes and existence). Nothing inside a folder is opened, and
/// no process runs to compute a row.
enum SpaceInventory {
    enum Group: CaseIterable {
        case models, tools, vms, simulators
    }

    /// Declaration order is display order.
    enum Location: CaseIterable {
        case lmStudio, ollama, huggingFace
        case cursor, codex, zcode, gemini
        case claudeVMs
        case simulators

        var group: Group {
            switch self {
            case .lmStudio, .ollama, .huggingFace: return .models
            case .cursor, .codex, .zcode, .gemini: return .tools
            case .claudeVMs: return .vms
            case .simulators: return .simulators
            }
        }

        /// Relative to the home folder.
        var relativePath: String {
            switch self {
            case .lmStudio: return ".lmstudio/models"
            case .ollama: return ".ollama/models"
            case .huggingFace: return ".cache/huggingface/hub"
            case .cursor: return "Library/Application Support/Cursor/User/globalStorage"
            case .codex: return ".codex"
            case .zcode: return ".zcode/cli"
            case .gemini: return ".gemini"
            case .claudeVMs: return "Library/Application Support/Claude/vm_bundles"
            case .simulators: return "Library/Developer/CoreSimulator/Devices"
            }
        }
    }

    /// The standardized path of a location under `home`. It reads nothing from
    /// the disk, so the section can name every location before any measurement.
    static func url(for location: Location, home: String) -> URL {
        URL(fileURLWithPath: home + "/" + location.relativePath, isDirectory: true).standardizedFileURL
    }

    /// The inventory rows for `home`, measured on demand by `JunkCleaner`. A
    /// location is skipped when it is absent, is a symbolic link, or overlaps a
    /// cleanable item of the same scan (the same path, or one inside the
    /// other), so no byte is counted twice. Sizes are the allocated sizes of
    /// `JunkCleaner.directorySize`, the helper the cleanable scans use. Once
    /// `cancellation` is cancelled, no further location is measured and the
    /// rows measured so far are returned.
    static func rows(home: String, excluding items: [JunkCleaner.Item],
                     cancellation: CleanerSupport.ScanCancellation? = nil) -> [SpaceInventoryRow] {
        let fm = FileManager.default
        let claimed = items.map { $0.url.standardizedFileURL.path }
        return Location.allCases.compactMap { location -> SpaceInventoryRow? in
            guard cancellation?.isCancelled != true else { return nil }
            let folder = url(for: location, home: home)
            guard fm.fileExists(atPath: folder.path), !UninstallerSupport.isSymbolicLink(folder) else {
                return nil
            }
            guard !claimed.contains(where: { overlaps($0, folder.path) }) else { return nil }
            let size = JunkCleaner.directorySize(of: folder, fm: fm, cancellation: cancellation)
            // A size cut short by a cancel is not a measurement, so the row is dropped.
            guard cancellation?.isCancelled != true else { return nil }
            return SpaceInventoryRow(location: location, url: folder, size: size)
        }
    }

    /// Whether two standardized paths are the same, or one is inside the other.
    static func overlaps(_ a: String, _ b: String) -> Bool {
        a == b || a.hasPrefix(b + "/") || b.hasPrefix(a + "/")
    }

    // MARK: - Space map

    /// Measures the space map of `home` and `applications`: the first-level
    /// children of the home folder, of `~/Library` and of the applications
    /// folder, largest first, the refusals met, the volume figures and the
    /// estimated system data. `~/Library` itself is never summed together with
    /// its children: the children replace it, so no byte is counted twice.
    /// Only an explicit request calls this: one run, no timer, no polling.
    /// Every finished folder goes to `onProgress`, so the map fills in while it
    /// measures; a cancellation stops the walk and keeps what was measured.
    static func map(home: String = NSHomeDirectory(),
                    applications: String = "/Applications",
                    cancellation: CleanerSupport.ScanCancellation? = nil,
                    onProgress: ((SpaceMap) -> Void)? = nil) -> SpaceMap {
        let fm = FileManager.default
        let homeURL = URL(fileURLWithPath: home, isDirectory: true)
        let libraryURL = homeURL.appendingPathComponent("Library", isDirectory: true)
        let applicationsURL = URL(fileURLWithPath: applications, isDirectory: true)
        let homeDevice = device(of: homeURL)
        let libraryDevice = device(of: libraryURL)
        let applicationsDevice = device(of: applicationsURL)
        let volume = SpaceVolume.read(for: homeURL)

        var entries: [SpaceMapEntry] = []
        var denials: [SpaceMapDenial] = []
        var systemDataSize: Int64 = 0
        var systemDataMeasured = false

        func isCancelled() -> Bool { cancellation?.isCancelled == true }

        func snapshot() -> SpaceMap {
            SpaceMap(entries: entries.sorted { $0.size > $1.size },
                     denials: denials,
                     volume: volume,
                     systemData: systemDataMeasured
                        ? SpaceSystemData(size: systemDataSize, partial: true)
                        : nil,
                     cancelled: isCancelled())
        }

        func measure(_ folder: URL, on containerDevice: dev_t?, isSystemData: Bool) {
            guard !isCancelled() else { return }
            // A symbolic link is never followed: it can leave the root or point
            // back inside it, and either way it is not this folder's own bytes.
            guard !UninstallerSupport.isSymbolicLink(folder) else { return }
            // A folder whose device cannot be read is a refusal, as in the walk: it is not measured.
            guard let folderDevice = device(of: folder) else {
                denials.append(SpaceMapDenial(url: folder, reason: .unavailable))
                return
            }
            // A mount point is another volume, never part of this root's bytes.
            guard let containerDevice, folderDevice == containerDevice else { return }
            let measured = measuredSize(of: folder, fm: fm, cancellation: cancellation)
            // A size cut by a cancel is not a measurement, so nothing is published.
            guard !isCancelled() else { return }
            entries.append(SpaceMapEntry(url: folder, size: measured.size,
                                         partial: !measured.denials.isEmpty))
            denials.append(contentsOf: measured.denials)
            if isSystemData {
                systemDataMeasured = true
                systemDataSize += measured.size
            }
            onProgress?(snapshot())
        }

        // `~/Library` is left out of the home children on purpose: its children
        // are measured right below, so the folder and its contents never add up
        // twice.
        let homeChildren = folders(in: homeURL, cancellation: cancellation, denials: &denials)
        for folder in homeChildren where folder.lastPathComponent != "Library" {
            measure(folder, on: homeDevice, isSystemData: false)
        }
        for folder in folders(in: libraryURL, cancellation: cancellation, denials: &denials) {
            measure(folder, on: libraryDevice, isSystemData: true)
        }
        for folder in folders(in: applicationsURL, cancellation: cancellation, denials: &denials) {
            measure(folder, on: applicationsDevice, isSystemData: false)
        }
        return snapshot()
    }

    /// The first-level folders of `container`, without following a link and
    /// without reading anything inside them. A container that is absent has no
    /// children and is not a refusal; a container that refuses to be listed
    /// leaves a denial with its reason.
    private static func folders(in container: URL, fm: FileManager = .default,
                                cancellation: CleanerSupport.ScanCancellation? = nil,
                                denials: inout [SpaceMapDenial]) -> [URL] {
        guard cancellation?.isCancelled != true, fm.fileExists(atPath: container.path) else { return [] }
        var failures: [SpaceMapDenial] = []
        guard let enumerator = fm.enumerator(
            at: container,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsSubdirectoryDescendants],
            errorHandler: { failed, error in
                failures.append(SpaceMapDenial(url: failed, reason: reason(for: error)))
                return true
            }) else {
            denials.append(SpaceMapDenial(url: container, reason: .unavailable))
            return []
        }
        var found: [URL] = []
        for case let child as URL in enumerator {
            if cancellation?.isCancelled == true { break }
            if UninstallerSupport.isSymbolicLink(child) { continue }
            let isDirectory = (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard isDirectory else { continue }
            found.append(child)
        }
        denials.append(contentsOf: failures)
        return found
    }

    /// The allocated bytes of `url` and the paths inside it the walk could not
    /// read. Same rule as the cleanable scans: no symbolic link is followed and
    /// a link is not counted. A cancellation stops the walk and returns what it
    /// measured so far.
    static func measuredSize(of url: URL, fm: FileManager = .default,
                             cancellation: CleanerSupport.ScanCancellation? = nil)
        -> (size: Int64, denials: [SpaceMapDenial]) {
        if UninstallerSupport.isSymbolicLink(url) { return (0, []) }
        guard cancellation?.isCancelled != true else { return (0, []) }
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return (0, [SpaceMapDenial(url: url, reason: .unavailable)])
        }
        if !isDir.boolValue { return (allocatedSize(url), []) }
        var denials: [SpaceMapDenial] = []
        // The root's own device. A directory on another device is a mount point:
        // it is another volume, so it is neither walked nor counted.
        guard let rootDevice = device(of: url) else {
            return (0, [SpaceMapDenial(url: url, reason: .unavailable)])
        }
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
            options: [],
            errorHandler: { failed, error in
                denials.append(SpaceMapDenial(url: failed, reason: reason(for: error)))
                return true
            }) else {
            return (0, [SpaceMapDenial(url: url, reason: .unavailable)])
        }
        var total: Int64 = 0
        for case let item as URL in enumerator {
            // A background queue never pops the thread pool: without this
            // drain, every URL and resourceValues stays until the walk ends.
            autoreleasepool { }
            if cancellation?.isCancelled == true { break }
            if UninstallerSupport.isSymbolicLink(item) {
                enumerator.skipDescendants()
                continue
            }
            let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDirectory {
                // A directory whose device cannot be read is a refusal: its contents are not measured.
                guard let itemDevice = device(of: item) else {
                    denials.append(SpaceMapDenial(url: item, reason: .unavailable))
                    enumerator.skipDescendants()
                    continue
                }
                // Not a refusal: a mount point is skipped silently, with its contents.
                if itemDevice != rootDevice {
                    enumerator.skipDescendants()
                    continue
                }
            }
            total += allocatedSize(item)
        }
        return (total, denials)
    }

    /// Why a read failed, in the app's own terms. macOS delivers the message
    /// already localized in its own language, so it is never shown.
    static func reason(for error: Error) -> SpaceMapDenial.Reason {
        let failure = error as NSError
        if failure.domain == NSCocoaErrorDomain, failure.code == NSFileReadNoPermissionError {
            return .accessDenied
        }
        if failure.domain == NSPOSIXErrorDomain,
           failure.code == Int(EACCES) || failure.code == Int(EPERM) {
            return .accessDenied
        }
        return .unavailable
    }

    /// The device a path lives on. A measured root keeps its own: a mount point
    /// inside it is another volume and is never walked as part of the root.
    static func device(of url: URL) -> dev_t? {
        var info = stat()
        guard stat(url.path, &info) == 0 else { return nil }
        return info.st_dev
    }

    private static func allocatedSize(_ url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
        return Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
    }
}
