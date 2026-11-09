// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import Combine
import DiskArbitration
import Foundation

enum DiskEjectState: Equatable {
    case ejecting
    case ready
    case failed(String)
}

final class DiskProtectionService: ObservableObject {
    static let shared = DiskProtectionService()

    @Published private(set) var states: [String: DiskEjectState] = [:]
    @Published private(set) var excludedVolumes: [String] = []

    private var diskReadings: AnyCancellable?

    private init() {
        reloadExclusions()
        // A finished or failed ejection describes one mount. Each fresh disk
        // reading (stale snapshots repeat the same value) drops "ready", since
        // the volume is either gone or mounted again, and drops a failure once
        // the volume is gone, so a remount never inherits an old state.
        diskReadings = SystemMonitor.shared.$snapshot
            .compactMap(\.disk)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] reading in self?.pruneStates(present: Set(reading.devices.map(\.id))) }
    }

    private func pruneStates(present: Set<String>) {
        let kept = states.filter { id, state in
            switch state {
            case .ejecting: return true
            case .ready: return false
            case .failed: return present.contains(id)
            }
        }
        if kept != states { states = kept }
    }

    func reloadExclusions() {
        let raw = UserDefaults.standard.stringArray(forKey: DefaultsKey.diskEjectExcludedVolumes) ?? []
        let sanitized = Defaults.sanitizedDiskExclusionList(raw)
        if raw != sanitized {
            UserDefaults.standard.set(sanitized, forKey: DefaultsKey.diskEjectExcludedVolumes)
        }
        excludedVolumes = sanitized
    }

    func addExcludedVolume(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !excludedVolumes.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        let updated = Defaults.sanitizedDiskExclusionList(excludedVolumes + [trimmed])
        UserDefaults.standard.set(updated, forKey: DefaultsKey.diskEjectExcludedVolumes)
        excludedVolumes = updated
    }

    func removeExcludedVolume(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let updated = excludedVolumes.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        UserDefaults.standard.set(updated, forKey: DefaultsKey.diskEjectExcludedVolumes)
        excludedVolumes = updated
    }

    func isExcluded(disk: DiskDeviceReading) -> Bool {
        guard !excludedVolumes.isEmpty else { return false }
        let set = Set(excludedVolumes.map { $0.lowercased() })
        return Self.isExcluded(volumeName: disk.name,
                               volumeUUID: disk.volumeUUID,
                               mountPath: disk.mountPath,
                               excludedVolumes: set)
    }

    /// A volume counts as excluded when any of the identities the caller hands
    /// over (name, UUID, mount path, or the path's last component) is in the
    /// list, compared case-insensitively. Identities are optional because the
    /// same list is honoured or ignored depending on which identifiers the
    /// caller happened to hand over, so a caller that has none says so with an
    /// explicit nil.
    private static func isExcluded(volumeName: String?,
                                   volumeUUID: String?,
                                   mountPath: String?,
                                   excludedVolumes: Set<String>) -> Bool {
        guard !excludedVolumes.isEmpty else { return false }
        if let name = volumeName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            if excludedVolumes.contains(name) || excludedVolumes.contains(name.lowercased()) {
                return true
            }
        }
        if let uuid = volumeUUID?.trimmingCharacters(in: .whitespacesAndNewlines), !uuid.isEmpty {
            if excludedVolumes.contains(uuid) || excludedVolumes.contains(uuid.lowercased()) {
                return true
            }
        }
        if let mountPath = mountPath?.trimmingCharacters(in: .whitespacesAndNewlines), !mountPath.isEmpty {
            if excludedVolumes.contains(mountPath) || excludedVolumes.contains(mountPath.lowercased()) {
                return true
            }
            let lastComponent = (mountPath as NSString).lastPathComponent
            if !lastComponent.isEmpty && (excludedVolumes.contains(lastComponent) || excludedVolumes.contains(lastComponent.lowercased())) {
                return true
            }
        }
        return false
    }

    func state(for disk: DiskDeviceReading) -> DiskEjectState? {
        states[disk.id]
    }

    func ejectAll(_ disks: [DiskDeviceReading]) {
        ejectableDisks(from: disks).forEach(performEject)
    }

    /// Ejecting a volume ejects its whole physical disk. When that disk has
    /// other mounted volumes, ask first and name them, like the Finder does.
    func eject(_ disk: DiskDeviceReading, aboveIsland: Bool = false) {
        guard disk.canEject else { return }
        let siblings = (SystemMonitor.shared.snapshot.disk?.devices ?? []).filter {
            $0.id != disk.id && $0.ejectBSDName == disk.ejectBSDName
        }
        guard !siblings.isEmpty else {
            performEject(disk)
            return
        }
        let strings = L10n.shared.s
        let title = String(format: strings.diskEjectSiblingsTitleFormat, disk.name)
        let message = String(format: strings.diskEjectSiblingsMessageFormat,
                             siblings.map(\.name).joined(separator: ", "))
        DispatchQueue.main.async {
            if aboveIsland {
                guard NSAlert.confirmAboveIsland(title, message: message, action: strings.diskEjectAll,
                                                 destructive: false, cancel: strings.uninstallerCancel) else { return }
            } else {
                let alert = NSAlert()
                alert.messageText = title
                alert.informativeText = message
                alert.addButton(withTitle: strings.diskEjectAll)
                alert.addButton(withTitle: strings.uninstallerCancel).keyEquivalent = "\u{1b}"
                NSApp.activate(ignoringOtherApps: true)
                guard alert.runModal() == .alertFirstButtonReturn else { return }
            }
            self.performEject(disk)
        }
    }

    private func performEject(_ disk: DiskDeviceReading) {
        guard disk.canEject else { return }
        DispatchQueue.main.async {
            self.states[disk.id] = .ejecting
        }
        let volumeURL = URL(fileURLWithPath: disk.mountPath)
        DispatchQueue.global(qos: .utility).async {
            do {
                try NSWorkspace.shared.unmountAndEjectDevice(at: volumeURL)
                self.complete(diskID: disk.id, state: .ready)
            } catch {
                self.ejectWithDiskArbitration(disk, fallbackError: error)
            }
        }
    }

    private func ejectWithDiskArbitration(_ disk: DiskDeviceReading, fallbackError: Error) {
        guard let ejectBSDName = disk.ejectBSDName else {
            complete(diskID: disk.id, state: .failed(fallbackError.localizedDescription))
            return
        }
        guard let session = DASessionCreate(kCFAllocatorDefault) else {
            complete(diskID: disk.id, state: .failed(fallbackError.localizedDescription))
            return
        }
        let queue = DispatchQueue(label: "com.hexa.utils.disk-eject.\(ejectBSDName)", qos: .utility)
        DASessionSetDispatchQueue(session, queue)

        guard let daDisk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, "/dev/\(ejectBSDName)") else {
            DASessionSetDispatchQueue(session, nil)
            complete(diskID: disk.id, state: .failed(fallbackError.localizedDescription))
            return
        }

        let context = DiskEjectContext(service: self,
                                       diskID: disk.id,
                                       session: session,
                                       queue: queue,
                                       disk: daDisk)
        DADiskUnmount(daDisk,
                      DADiskUnmountOptions(kDADiskUnmountOptionWhole),
                      diskUnmountCallback,
                      Unmanaged.passRetained(context).toOpaque())
    }

    /// One volume per physical disk. Ejecting takes the whole disk, so a disk
    /// that holds any excluded volume is skipped entirely.
    func ejectableDisks(from disks: [DiskDeviceReading]) -> [DiskDeviceReading] {
        let protectedDisks = Set(disks.filter(isExcluded(disk:)).compactMap(\.ejectBSDName))
        var seen = Set<String>()
        return disks.filter { disk in
            guard disk.canEject, let id = disk.ejectBSDName else { return false }
            guard !protectedDisks.contains(id) else { return false }
            return seen.insert(id).inserted
        }
    }

    fileprivate func complete(diskID: String, state: DiskEjectState) {
        DispatchQueue.main.async {
            self.states[diskID] = state
        }
    }

    fileprivate static func message(for dissenter: DADissenter) -> String {
        if let statusString = DADissenterGetStatusString(dissenter) {
            let text = statusString as String
            if !text.isEmpty { return text }
        }
        return "Disk Arbitration \(DADissenterGetStatus(dissenter))"
    }
}

private final class DiskEjectContext {
    weak var service: DiskProtectionService?
    let diskID: String
    let session: DASession
    let queue: DispatchQueue
    let disk: DADisk

    init(service: DiskProtectionService, diskID: String, session: DASession,
         queue: DispatchQueue, disk: DADisk) {
        self.service = service
        self.diskID = diskID
        self.session = session
        self.queue = queue
        self.disk = disk
    }

    deinit {
        DASessionSetDispatchQueue(session, nil)
    }
}

private func diskUnmountCallback(_ disk: DADisk,
                                 _ dissenter: DADissenter?,
                                 _ context: UnsafeMutableRawPointer?) {
    guard let context else { return }
    if let dissenter {
        let box = Unmanaged<DiskEjectContext>.fromOpaque(context).takeRetainedValue()
        box.service?.complete(diskID: box.diskID,
                              state: .failed(DiskProtectionService.message(for: dissenter)))
        return
    }

    _ = Unmanaged<DiskEjectContext>.fromOpaque(context).takeUnretainedValue()
    DADiskEject(disk, DADiskEjectOptions(kDADiskEjectOptionDefault), diskEjectCallback, context)
}

private func diskEjectCallback(_ disk: DADisk,
                               _ dissenter: DADissenter?,
                               _ context: UnsafeMutableRawPointer?) {
    guard let context else { return }
    let box = Unmanaged<DiskEjectContext>.fromOpaque(context).takeRetainedValue()
    if let dissenter {
        box.service?.complete(diskID: box.diskID,
                              state: .failed(DiskProtectionService.message(for: dissenter)))
    } else {
        box.service?.complete(diskID: box.diskID, state: .ready)
    }
}
