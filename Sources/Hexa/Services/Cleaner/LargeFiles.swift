// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Foundation

/// Finds the large and old files of the user's own home folder and moves a
/// confirmed selection to the Trash. Read only until the user confirms: the
/// search lists, it never removes, and nothing here runs on a timer.
///
/// The rules, in order of importance:
/// 1. Home only. The walk starts at the home folder, never follows a symbolic
///    link and never leaves the device it started on, so no other volume and
///    no removable media is traversed.
/// 2. Both thresholds. A file is a candidate only when it is old enough and
///    big enough; the modification date and the allocated size decide.
/// 3. Nothing that cannot be reviewed. Package contents, system folders, the
///    Trash, this app's own data, hidden entries, symbolic links and cloud
///    items that are not downloaded stay out. A package is one item and is
///    never decomposed, so no byte is counted twice.
/// 4. Revalidate at the moment of removal. The identity the scan saw, the
///    scope of the home, the thresholds and the exclusions are checked again
///    for each item right before its move; anything that changed is refused
///    and reported, never moved.
enum LargeFiles {
    /// The two figures that make a file "large and old", both read from the
    /// persisted choices at the start of every search.
    struct Thresholds: Equatable {
        static let megabyte: Int64 = 1024 * 1024

        /// Days since the last modification.
        let ageDays: Int
        /// Allocated bytes the item must reach.
        let minimumBytes: Int64

        /// The defaults D9 settled: 180 days and 500 MB.
        static let standard = Thresholds(
            ageDays: CleanerPolicy.defaultLargeFileAgeDays,
            minimumBytes: Int64(CleanerPolicy.defaultLargeFileSizeMegabytes) * megabyte)

        /// The saved choice. A value that is not one of the fixed choices is
        /// brought to the nearest one, so a restored backup cannot inject an
        /// arbitrary number; a key that was never written falls back to the
        /// defaults of D9.
        static func persisted(in defaults: UserDefaults = .standard) -> Thresholds {
            let savedAge = defaults.object(forKey: DefaultsKey.cleanerLargeFileAgeDays) as? Int
            let savedMegabytes = defaults.object(forKey: DefaultsKey.cleanerLargeFileSizeMegabytes) as? Int
            return Thresholds(
                ageDays: CleanerPolicy.sanitizedLargeFileAgeDays(savedAge ?? CleanerPolicy.defaultLargeFileAgeDays),
                minimumBytes: Int64(CleanerPolicy.sanitizedLargeFileSizeMegabytes(
                    savedMegabytes ?? CleanerPolicy.defaultLargeFileSizeMegabytes)) * megabyte)
        }

        /// Both thresholds, never one of them.
        func accepts(size: Int64, modified: Date, now: Date = Date()) -> Bool {
            guard size >= minimumBytes, size > 0 else { return false }
            return modified <= now.addingTimeInterval(-Double(ageDays) * 86_400)
        }
    }

    /// One offered file or package. It carries no selection: the user marks
    /// what they want in the interface, and nothing is marked by the search.
    struct Candidate: Identifiable, Equatable {
        let url: URL
        /// Allocated bytes of the file, or of the whole package as one item.
        let size: Int64
        /// The modification date the age threshold was read against.
        let modified: Date
        /// The identity observed at scan time: the proof re-read before a move.
        let identity: UninstallerSupport.FileIdentity
        /// A package is one item; its contents are never offered.
        let isPackage: Bool

        var id: String { url.standardizedFileURL.path }
        var name: String { url.lastPathComponent }
    }

    /// Why a path is never offered. The first match wins, so a path can report
    /// the reason the user is most likely to recognize.
    enum Exclusion: Equatable {
        /// Not inside the home folder.
        case outsideHome
        /// The Trash of the home folder.
        case trash
        /// This app's own data.
        case ownData
        /// A folder macOS manages, never a file of the user's own.
        case systemDirectory
        /// A dot file, or an entry macOS flags as hidden.
        case hidden
        /// A symbolic link: never listed, never followed.
        case symbolicLink
        /// A cloud item whose current version is not downloaded: it holds no
        /// local bytes to free, and moving it moves nothing real.
        case cloudNotDownloaded
    }

    /// What one search found. It carries no selection and no removal path, so
    /// the list can never clean anything by accident.
    struct SearchResult: Equatable {
        /// Largest first.
        let candidates: [Candidate]
        /// The paths the walk could not read, with the reason.
        let denied: [SpaceMapDenial]
        /// A cancel ended the walk: the list is what was found so far.
        let cancelled: Bool

        static let empty = SearchResult(candidates: [], denied: [], cancelled: false)

        /// A finished search that found nothing: a result, not a search still
        /// running.
        var isEmpty: Bool { candidates.isEmpty }

        var totalSize: Int64 { candidates.reduce(0) { $0 + $1.size } }

        func markedCancelled() -> SearchResult {
            SearchResult(candidates: candidates, denied: denied, cancelled: true)
        }
    }

    /// What happened to one item of a confirmed removal.
    enum Outcome: Equatable {
        case movedToTrash(size: Int64)
        /// The item is no longer what the scan saw: left in place.
        case refused
        /// The move itself failed: left in place, reported, never counted as
        /// a success.
        case failed

        var isFailure: Bool {
            if case .movedToTrash = self { return false }
            return true
        }
    }

    /// The result of a removal for one item, in the order the items were given.
    struct RemovalReport: Identifiable, Equatable {
        let url: URL
        let size: Int64
        let outcome: Outcome

        var id: String { url.standardizedFileURL.path }
        var isFailure: Bool { outcome.isFailure }
    }

    /// Every rule that keeps a path out of the list, in one place. `values` is
    /// read by the caller so the walk reuses the same read; a nil value only
    /// means the resource read failed, and the path is still checked by scope,
    /// name and link.
    static func exclusion(for url: URL, home: URL,
                          values: URLResourceValues?) -> Exclusion? {
        let path = url.standardizedFileURL.path
        let homePath = home.standardizedFileURL.path
        guard path.hasPrefix(homePath + "/") else { return .outsideHome }
        if isInside(path, homePath + "/.Trash") { return .trash }
        if ownDataPaths(home: homePath).contains(where: { isInside(path, $0) }) { return .ownData }
        if systemPaths(home: homePath).contains(where: { isInside(path, $0) }) { return .systemDirectory }
        // A dot name hides everything below it: the entry and its contents.
        if path.dropFirst(homePath.count + 1).split(separator: "/").contains(where: { $0.hasPrefix(".") })
            || values?.isHidden == true {
            return .hidden
        }
        if UninstallerSupport.isSymbolicLink(url) { return .symbolicLink }
        if isCloudPlaceholder(isUbiquitous: values?.isUbiquitousItem == true,
                              status: values?.ubiquitousItemDownloadingStatus) {
            return .cloudNotDownloaded
        }
        return nil
    }

    /// A cloud item is only offered once its current version is on this Mac:
    /// a placeholder has no local bytes, and an outdated copy is not the file
    /// the age threshold would be judged against.
    static func isCloudPlaceholder(isUbiquitous: Bool,
                                   status: URLUbiquitousItemDownloadingStatus?) -> Bool {
        guard isUbiquitous else { return false }
        return status != URLUbiquitousItemDownloadingStatus.current
    }

    /// The folders macOS manages, plus the user's own `Library` and
    /// `Applications`, which are excluded too. The Cleaner already owns the
    /// caches, logs and containers inside `Library`, and installed apps in
    /// `Applications` belong to the app tools, so listing either folder here
    /// would offer bytes another tool already reaches: no byte is counted
    /// twice. A system root that holds the home folder itself is left out of
    /// the list, so a home under `/var` is not excluded by its own ancestor.
    static func systemPaths(home: String) -> [String] {
        let roots = ["/Applications", "/Library", "/System", "/Users", "/Volumes",
                     "/bin", "/cores", "/dev", "/etc", "/opt", "/private", "/sbin", "/usr", "/var"]
        return roots.filter { !isInside(home, $0) } + [home + "/Library", home + "/Applications"]
    }

    /// This app's own data, never offered to the user as a file to remove.
    static func ownDataPaths(home: String) -> [String] {
        ["/Library/Application Support/hexa",
         "/Library/Application Support/io.github.pauloborini.hexa",
         "/Library/Caches/io.github.pauloborini.hexa",
         "/Library/Containers/io.github.pauloborini.hexa",
         "/Library/Group Containers/io.github.pauloborini.hexa",
         "/Library/HTTPStorages/io.github.pauloborini.hexa",
         "/Library/Preferences/io.github.pauloborini.hexa.plist",
         "/.hexa"].map { home + $0 }
    }

    /// Whether `path` is `root` itself or lives inside it.
    static func isInside(_ path: String, _ root: String) -> Bool {
        path == root || path.hasPrefix(root + "/")
    }

    // MARK: - Search

    private static let resourceKeys: [URLResourceKey] = [
        .isDirectoryKey, .isRegularFileKey, .isPackageKey, .isHiddenKey,
        .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .contentModificationDateKey,
        .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey,
    ]

    /// Walks `home` and lists the files and packages that meet both
    /// thresholds. Only an explicit request calls this: one walk per call, no
    /// timer and no polling. Every candidate goes to `onProgress` as it is
    /// found, so the list fills in instead of waiting for the end; once
    /// `cancellation` is cancelled the walk stops and returns what it found.
    static func search(home: String = NSHomeDirectory(),
                       thresholds: Thresholds,
                       cancellation: CleanerSupport.ScanCancellation? = nil,
                       onProgress: ((SearchResult) -> Void)? = nil) -> SearchResult {
        let fm = FileManager.default
        let homeURL = URL(fileURLWithPath: home, isDirectory: true).standardizedFileURL
        var candidates: [Candidate] = []
        var denied: [SpaceMapDenial] = []

        func isCancelled() -> Bool { cancellation?.isCancelled == true }
        func snapshot() -> SearchResult {
            SearchResult(candidates: candidates.sorted { $0.size > $1.size },
                         denied: denied, cancelled: isCancelled())
        }

        // A home that cannot be read is a refusal, never an empty list.
        guard fm.fileExists(atPath: homeURL.path),
              let homeDevice = SpaceInventory.device(of: homeURL) else {
            return SearchResult(candidates: [], denied: [SpaceMapDenial(url: homeURL, reason: .unavailable)],
                                cancelled: false)
        }
        guard let enumerator = fm.enumerator(
            at: homeURL,
            includingPropertiesForKeys: resourceKeys,
            options: [],
            errorHandler: { failed, error in
                denied.append(SpaceMapDenial(url: failed, reason: SpaceInventory.reason(for: error)))
                return true
            }) else {
            return SearchResult(candidates: [], denied: [SpaceMapDenial(url: homeURL, reason: .unavailable)],
                                cancelled: false)
        }

        for case let url as URL in enumerator {
            autoreleasepool { }
            if isCancelled() { break }
            let values = try? url.resourceValues(forKeys: Set(resourceKeys))
            let isDirectory = values?.isDirectory == true
            // An excluded folder is never entered, so nothing inside it is read.
            if exclusion(for: url, home: homeURL, values: values) != nil {
                if isDirectory { enumerator.skipDescendants() }
                continue
            }
            // A mount point is another volume: never walked and never listed.
            if isDirectory, SpaceInventory.device(of: url) != homeDevice {
                enumerator.skipDescendants()
                continue
            }
            let isPackage = isDirectory && values?.isPackage == true
            // A plain folder is walked, never listed.
            guard isPackage || values?.isRegularFile == true else { continue }
            // A package is one item: its contents are never offered.
            if isPackage { enumerator.skipDescendants() }
            guard let identity = UninstallerSupport.fileIdentity(at: url),
                  let modified = values?.contentModificationDate else { continue }
            let size = isPackage
                ? JunkCleaner.directorySize(of: url, fm: fm, cancellation: cancellation)
                : Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
            guard thresholds.accepts(size: size, modified: modified) else { continue }
            candidates.append(Candidate(url: url, size: size, modified: modified,
                                        identity: identity, isPackage: isPackage))
            onProgress?(snapshot())
        }
        return snapshot()
    }

    // MARK: - Removal

    /// Whether the item is still exactly what the scan offered: inside the
    /// home, not a link, still meeting both thresholds, still outside every
    /// exclusion and still carrying the identity the scan observed. This runs
    /// right before each move, so a file replaced in the meantime is refused
    /// instead of trashed.
    static func validate(_ candidate: Candidate, home: String = NSHomeDirectory(),
                         thresholds: Thresholds) -> Bool {
        let homeURL = URL(fileURLWithPath: home, isDirectory: true).standardizedFileURL
        let url = candidate.url.standardizedFileURL
        guard url.path.hasPrefix(homeURL.path + "/") else { return false }
        guard !UninstallerSupport.isSymbolicLink(url),
              UninstallerSupport.fileIdentity(at: url) == candidate.identity else { return false }
        let values = try? url.resourceValues(forKeys: Set(resourceKeys))
        guard exclusion(for: url, home: homeURL, values: values) == nil else { return false }
        let isPackage = values?.isPackage == true
        guard isPackage || values?.isRegularFile == true,
              let modified = values?.contentModificationDate else { return false }
        let size = isPackage
            ? JunkCleaner.directorySize(of: url, fm: .default)
            : Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
        return thresholds.accepts(size: size, modified: modified)
    }

    /// Moves the given items to the Trash through `trash`, one at a time, and
    /// reports each one. Without a confirmation nothing moves at all. Every
    /// item is revalidated first, so a link, a replaced file or a file that no
    /// longer meets the thresholds is refused and reported instead of moved.
    /// Nothing is deleted in place: the Trash is the only destination.
    static func trash(_ candidates: [Candidate],
                      confirmed: Bool,
                      home: String = NSHomeDirectory(),
                      thresholds: Thresholds,
                      trash: (URL) throws -> Void) -> [RemovalReport] {
        guard confirmed else { return [] }
        var reports: [RemovalReport] = []
        for candidate in candidates {
            guard validate(candidate, home: home, thresholds: thresholds) else {
                reports.append(RemovalReport(url: candidate.url, size: candidate.size, outcome: .refused))
                continue
            }
            do {
                try trash(candidate.url)
                reports.append(RemovalReport(url: candidate.url, size: candidate.size,
                                             outcome: .movedToTrash(size: candidate.size)))
            } catch {
                reports.append(RemovalReport(url: candidate.url, size: candidate.size, outcome: .failed))
            }
        }
        return reports
    }
}
