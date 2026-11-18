// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Darwin
import Foundation
import IOKit

final class DiskSampler {
    private struct DiskMetadata {
        var bsdName: String?
        var wholeDisk: String?
        var fileSystem: String?
        var ioCounterIDs: [String] = []
        var smartServiceID: UInt64?
    }

    private var previous: [String: (counters: DiskIOCounters, time: TimeInterval)] = [:]
    private var sessionTotals: [String: DiskIOCounters] = [:]
    private var metadataCache: [String: (metadata: DiskMetadata, bsdName: String?, volumeUUID: String?, mediaID: UInt64, updatedAt: TimeInterval)] = [:]
    private var smartCache: [UInt64: (reading: DiskSMARTReading?, updatedAt: TimeInterval)] = [:]
    private static let metadataRefreshInterval: TimeInterval = 30
    /// Panel closed: identity metadata only changes on (re)mount, so a full
    /// lookup stays reusable for a long time; the hourly re-run self-heals
    /// remounts that swapped BSD names while the panel never opened.
    private static let backgroundMetadataRefreshInterval: TimeInterval = 3600
    /// Widest sample gap that still yields a rate: must clear the slowest
    /// background disk cadence (10 s nominal) plus the timer's tolerance and
    /// scheduling slop, or roughly half the background samples get discarded
    /// and their bytes vanish from the session totals. Sleep/pause gaps are
    /// minutes long and still fall outside.
    private static let maxGap: TimeInterval = 15

    func sample(now: TimeInterval, refreshMetadata: Bool = false,
                isCurrent: () -> Bool = { true }) -> DiskReading {
        guard isCurrent() else { return DiskReading(devices: []) }
        let counters = Self.readCounters(isCurrent: isCurrent)
        guard isCurrent() else { return DiskReading(devices: []) }
        var diskSnapshots: [String: (readBytesPerSec: Double?, writeBytesPerSec: Double?,
                                     totalRead: UInt64?, totalWritten: UInt64?)] = [:]
        var smartSnapshots: [UInt64: DiskSMARTReading?] = [:]
        var nextPrevious = previous
        var nextSessionTotals = sessionTotals
        let volumes = Self.mountedVolumes(isCurrent: isCurrent)
        guard isCurrent() else { return DiskReading(devices: []) }
        let devices = volumes.compactMap { volume -> DiskDeviceReading? in
            guard isCurrent() else { return nil }
            let metadata = metadata(for: volume, now: now, refresh: refreshMetadata, isCurrent: isCurrent)
            guard isCurrent() else { return nil }
            let wholeDisk = metadata.wholeDisk
            let counter = Self.bestCounter(from: metadata.ioCounterIDs, counters: counters)
            let ioCounters = counter?.counters ?? DiskIOCounters()
            let diskID = counter?.id ?? wholeDisk ?? metadata.bsdName ?? volume.mountPath
            let rates: (readBytesPerSec: Double?, writeBytesPerSec: Double?,
                        totalRead: UInt64?, totalWritten: UInt64?)
            if let snapshot = diskSnapshots[diskID] {
                rates = snapshot
            } else {
                rates = Self.ratesAndTotals(for: diskID, counters: ioCounters, now: now,
                                            previous: &nextPrevious, sessionTotals: &nextSessionTotals)
                diskSnapshots[diskID] = rates
            }
            let isInternal = volume.isInternal
            let isRemovable = volume.isRemovable || !isInternal
            let isEjectable = volume.isEjectable || (!isInternal && isRemovable)
            var smart: DiskSMARTReading?
            if refreshMetadata, wholeDisk != nil, let serviceID = metadata.smartServiceID {
                if let cached = smartSnapshots[serviceID] {
                    smart = cached
                } else if let cached = smartCache[serviceID], now - cached.updatedAt < Self.metadataRefreshInterval {
                    smart = cached.reading
                    smartSnapshots[serviceID] = .some(smart)
                } else if isCurrent() {
                    smart = NativeDisk.readSMART(serviceID: serviceID, isCurrent: isCurrent)
                    guard isCurrent() else { return nil }
                    smartCache[serviceID] = (smart, now)
                    smartSnapshots[serviceID] = .some(smart)
                }
            }
            return DiskDeviceReading(id: volume.mountPath,
                                     name: volume.name,
                                     mountPath: volume.mountPath,
                                     volumeUUID: volume.volumeUUID,
                                     bsdName: metadata.bsdName,
                                     wholeDisk: wholeDisk,
                                     ioCounterID: counter?.id,
                                     fileSystem: metadata.fileSystem
                                         ?? DiskSupport.fileSystemLabel(type: volume.fileSystemType),
                                     totalBytes: volume.totalBytes,
                                     freeBytes: volume.freeBytes,
                                     purgeableBytes: volume.purgeableBytes,
                                     usedBytes: volume.usedBytes,
                                     isInternal: isInternal,
                                     isRemovable: isRemovable,
                                     isEjectable: isEjectable,
                                     smart: smart,
                                     readBytesPerSec: rates.readBytesPerSec,
                                     writeBytesPerSec: rates.writeBytesPerSec,
                                     totalReadBytes: rates.totalRead,
                                     totalWrittenBytes: rates.totalWritten,
                                     holdsSystemVolume: !volume.internalKnown)
        }
        // Any volume on the physical disk that holds `/` is the boot disk, even when
        // it is external and reports itself as ejectable.
        let systemWholeDisks = Set(devices.filter { $0.mountPath == "/" }.compactMap(\.wholeDisk))
        let marked = devices.map { device -> DiskDeviceReading in
            var device = device
            device.holdsSystemVolume = device.holdsSystemVolume || systemWholeDisks.isEmpty || device.wholeDisk == nil || device.mountPath == "/"
                || device.wholeDisk.map(systemWholeDisks.contains) == true
            return device
        }
        let sorted = marked.sorted(by: sortVolumes)
        guard isCurrent() else { return DiskReading(devices: []) }
        previous = nextPrevious
        sessionTotals = nextSessionTotals
        return DiskReading(devices: sorted)
    }

    private static func bestCounter(from ids: [String], counters: [String: DiskIOCounters])
        -> (id: String, counters: DiskIOCounters)? {
        for id in ids {
            if let value = counters[id] {
                return (id, value)
            }
        }
        return nil
    }

    private static func ratesAndTotals(for diskID: String, counters: DiskIOCounters, now: TimeInterval,
                                       previous: inout [String: (counters: DiskIOCounters, time: TimeInterval)],
                                       sessionTotals: inout [String: DiskIOCounters])
        -> (readBytesPerSec: Double?, writeBytesPerSec: Double?, totalRead: UInt64?, totalWritten: UInt64?) {
        defer { previous[diskID] = (counters, now) }
        var totals = sessionTotals[diskID] ?? DiskIOCounters()
        guard let prev = previous[diskID], now > prev.time, now - prev.time <= Self.maxGap else {
            sessionTotals[diskID] = totals
            return (nil, nil, totals.read, totals.written)
        }

        let speed = MetricFormat.diskSpeed(previous: prev.counters, current: counters, elapsed: now - prev.time)
        if counters.read >= prev.counters.read {
            totals.read += counters.read - prev.counters.read
        }
        if counters.written >= prev.counters.written {
            totals.written += counters.written - prev.counters.written
        }
        sessionTotals[diskID] = totals
        return (speed.read, speed.write, totals.read, totals.written)
    }

    private func metadata(for volume: MountedVolume, now: TimeInterval, refresh: Bool,
                          isCurrent: () -> Bool) -> DiskMetadata {
        let mediaID = volume.bsdName.flatMap { NativeDisk.mediaID(bsdName: $0, isCurrent: isCurrent) }
        if let cached = metadataCache[volume.mountPath],
           cached.bsdName == volume.bsdName, cached.volumeUUID == volume.volumeUUID,
           let mediaID, cached.mediaID == mediaID,
           now - cached.updatedAt < Self.metadataRefreshInterval {
            return cached.metadata
        }
        // Reuse the physical identity while the disk panel is closed.
        if !refresh,
           let cached = metadataCache[volume.mountPath],
           cached.bsdName == volume.bsdName, cached.volumeUUID == volume.volumeUUID,
           let mediaID, cached.mediaID == mediaID,
           now - cached.updatedAt < Self.backgroundMetadataRefreshInterval {
            return cached.metadata
        }
        guard isCurrent() else { return DiskMetadata() }
        let identity = volume.bsdName.map { NativeDisk.identity(bsdName: $0, isCurrent: isCurrent) }
        let fileSystemName = volume.fileSystemType?.lowercased() == "msdos"
            ? volume.bsdName.flatMap { NativeDisk.fileSystemName(bsdName: $0, isCurrent: isCurrent) } : nil
        let metadata = DiskMetadata(bsdName: volume.bsdName,
                                    wholeDisk: identity?.wholeDisk,
                                    fileSystem: DiskSupport.fileSystemLabel(type: volume.fileSystemType, name: fileSystemName),
                                    ioCounterIDs: [identity?.wholeDisk, volume.bsdName].compactMap { $0 },
                                    smartServiceID: identity?.smartServiceID)
        guard isCurrent() else { return DiskMetadata() }
        if let id = identity?.mediaID, id == mediaID {
            metadataCache[volume.mountPath] = (metadata, volume.bsdName, volume.volumeUUID, id, now)
        } else {
            return DiskMetadata(bsdName: volume.bsdName)
        }
        return metadata
    }

    private func sortVolumes(_ lhs: DiskDeviceReading, _ rhs: DiskDeviceReading) -> Bool {
        if lhs.isInternal != rhs.isInternal { return lhs.isInternal && !rhs.isInternal }
        if lhs.mountPath == "/" { return true }
        if rhs.mountPath == "/" { return false }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    private struct MountedVolume {
        var name: String
        var mountPath: String
        var volumeUUID: String?
        var totalBytes: UInt64
        var freeBytes: UInt64
        var purgeableBytes: UInt64?
        var usedBytes: UInt64
        var isInternal: Bool
        var internalKnown: Bool
        var isRemovable: Bool
        var isEjectable: Bool
        var bsdName: String?
        var fileSystemType: String?
    }

    private static func mountedVolumes(isCurrent: () -> Bool) -> [MountedVolume] {
        let keys: Set<URLResourceKey> = [
            .volumeNameKey,
            .volumeLocalizedNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeIsInternalKey,
            .volumeIsReadOnlyKey,
            .volumeIsRemovableKey,
            .volumeIsEjectableKey,
            .volumeIsLocalKey,
            .volumeUUIDStringKey,
        ]
        guard isCurrent(), let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: Array(keys),
                                                               options: [.skipHiddenVolumes]) else {
            return []
        }

        return urls.compactMap { url in
            guard isCurrent(), let values = try? url.resourceValues(forKeys: keys),
                  values.volumeIsLocal != false,
                  let total = positiveUInt(values.volumeTotalCapacity),
                  total > 0 else { return nil }
            let rawFree = positiveUInt(values.volumeAvailableCapacity, requiringPositive: true)
                ?? positiveUInt(values.volumeAvailableCapacity)
            guard isCurrent() else { return nil }
            let free = importantFree(for: url, isReadOnly: values.volumeIsReadOnly == true)
                ?? rawFree
                ?? 0
            let purgeable: UInt64? = {
                guard let rawFree, free > rawFree else { return nil }
                return free - rawFree
            }()
            let physicalUsed = rawFree.map { total >= $0 ? total - $0 : 0 }
                ?? (total >= free ? total - free : 0)
            let name = values.volumeLocalizedName ?? values.volumeName ?? url.lastPathComponent
            guard isCurrent() else { return nil }
            let identity = statfsIdentity(for: url.path)
            return MountedVolume(name: name.isEmpty ? url.path : name,
                                 mountPath: url.path,
                                 volumeUUID: values.volumeUUIDString,
                                 totalBytes: total,
                                 freeBytes: min(free, total),
                                 purgeableBytes: purgeable,
                                 usedBytes: min(physicalUsed, total),
                                 isInternal: values.volumeIsInternal ?? false,
                                 internalKnown: values.volumeIsInternal != nil,
                                 isRemovable: values.volumeIsRemovable ?? false,
                                 isEjectable: values.volumeIsEjectable ?? false,
                                 bsdName: identity.bsdName,
                                 fileSystemType: identity.fileSystemType)
        }
    }

    private static func statfsIdentity(for mountPath: String) -> (bsdName: String?, fileSystemType: String?) {
        var fs = statfs()
        guard statfs(mountPath, &fs) == 0 else { return (nil, nil) }
        let bsdName = withUnsafeBytes(of: fs.f_mntfromname) { rawBuffer -> String? in
            guard let value = string(fromFixedCString: rawBuffer) else { return nil }
            let trimmed = value.replacingOccurrences(of: "/dev/", with: "")
            return trimmed.hasPrefix("disk") ? trimmed : nil
        }
        let fileSystemType = withUnsafeBytes(of: fs.f_fstypename) { rawBuffer -> String? in
            string(fromFixedCString: rawBuffer)
        }
        return (bsdName, fileSystemType)
    }

    private static func string(fromFixedCString rawBuffer: UnsafeRawBufferPointer) -> String? {
        guard let base = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
            return nil
        }
        let length = rawBuffer.prefix(while: { $0 != 0 }).count
        guard length > 0 else { return nil }
        let bytes = UnsafeBufferPointer(start: base, count: length)
        return String(decoding: bytes, as: UTF8.self)
    }

    /// Free space counting what the system would purge to make room. Only a
    /// writable volume can answer it: asking a mounted image costs a round
    /// trip to the purge service and comes back as an error on every sample,
    /// which is what filled the log while a disk image was attached.
    private static func importantFree(for url: URL, isReadOnly: Bool) -> UInt64? {
        guard !isReadOnly,
              let values = try? url.resourceValues(
                forKeys: [.volumeAvailableCapacityForImportantUsageKey]) else { return nil }
        return positiveUInt(values.volumeAvailableCapacityForImportantUsage, requiringPositive: true)
            ?? positiveUInt(values.volumeAvailableCapacityForImportantUsage)
    }

    private static func positiveUInt(_ value: Int?) -> UInt64? {
        guard let value, value >= 0 else { return nil }
        return UInt64(value)
    }

    private static func positiveUInt(_ value: Int?, requiringPositive: Bool) -> UInt64? {
        guard let result = positiveUInt(value), !requiringPositive || result > 0 else { return nil }
        return result
    }

    private static func positiveUInt(_ value: Int64?, requiringPositive: Bool) -> UInt64? {
        guard let result = positiveUInt(value), !requiringPositive || result > 0 else { return nil }
        return result
    }

    private static func positiveUInt(_ value: Int64?) -> UInt64? {
        guard let value, value >= 0 else { return nil }
        return UInt64(value)
    }

    static func readCounters(isCurrent: () -> Bool = { true }) -> [String: DiskIOCounters] {
        guard isCurrent() else { return [:] }
        var counters = readBlockStorageCounters(isCurrent: isCurrent)
        guard isCurrent() else { return counters }
        for (key, value) in readMediaCounters(isCurrent: isCurrent) where counters[key] == nil {
            counters[key] = value
        }
        return counters
    }

    private static func readBlockStorageCounters(isCurrent: () -> Bool) -> [String: DiskIOCounters] {
        var iterator = io_iterator_t()
        guard isCurrent() else { return [:] }
        let matching = IOServiceMatching("IOBlockStorageDriver")
        guard isCurrent(), IOServiceGetMatchingServices(kIOMainPortDefault,
                                           matching, &iterator) == kIOReturnSuccess else { return [:] }
        defer { IOObjectRelease(iterator) }

        var result: [String: DiskIOCounters] = [:]
        while isCurrent() {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }
            defer { IOObjectRelease(service) }
            if isCurrent(), let bsdName = wholeDiskBSDName(descendingFrom: service, isCurrent: isCurrent),
               isCurrent(), let stats = property("Statistics", from: service) as? [String: Any] {
                result[bsdName] = DiskIOCounters(read: DiskSupport.uint(stats["Bytes (Read)"]) ?? 0,
                                                 written: DiskSupport.uint(stats["Bytes (Write)"]) ?? 0)
            }
        }
        return result
    }

    private static func readMediaCounters(isCurrent: () -> Bool) -> [String: DiskIOCounters] {
        var iterator = io_iterator_t()
        guard isCurrent() else { return [:] }
        let matching = IOServiceMatching("IOMedia")
        guard isCurrent(), IOServiceGetMatchingServices(kIOMainPortDefault,
                                           matching, &iterator) == kIOReturnSuccess else { return [:] }
        defer { IOObjectRelease(iterator) }

        var result: [String: DiskIOCounters] = [:]
        while isCurrent() {
            let media = IOIteratorNext(iterator)
            guard media != 0 else { break }
            defer { IOObjectRelease(media) }
            if isCurrent(), let bsdName = property("BSD Name", from: media) as? String,
               isCurrent(), let stats = property("Statistics", from: media) as? [String: Any],
               let counters = counters(from: stats) {
                result[bsdName] = counters
            }
        }
        return result
    }

    private static func counters(from stats: [String: Any]) -> DiskIOCounters? {
        let read = DiskSupport.uint(stats["Bytes (Read)"])
            ?? DiskSupport.uint(stats["Bytes read from block device"])
            ?? DiskSupport.uint(stats["Bytes read by user"])
        let written = DiskSupport.uint(stats["Bytes (Write)"])
            ?? DiskSupport.uint(stats["Bytes written to block device"])
            ?? DiskSupport.uint(stats["Bytes written by user"])
        guard read != nil || written != nil else { return nil }
        return DiskIOCounters(read: read ?? 0, written: written ?? 0)
    }

    private static func wholeDiskBSDName(descendingFrom entry: io_registry_entry_t,
                                         isCurrent: () -> Bool) -> String? {
        guard isCurrent() else { return nil }
        if let whole = property("Whole", from: entry) as? Bool,
           whole, isCurrent(),
           let name = property("BSD Name", from: entry) as? String {
            return name
        }

        var iterator = io_iterator_t()
        guard isCurrent(), IORegistryEntryGetChildIterator(entry, kIOServicePlane, &iterator) == kIOReturnSuccess else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        while isCurrent() {
            let child = IOIteratorNext(iterator)
            guard child != 0 else { break }
            defer { IOObjectRelease(child) }
            if let name = wholeDiskBSDName(descendingFrom: child, isCurrent: isCurrent) {
                return name
            }
        }
        return nil
    }

    private static func property(_ key: String, from entry: io_registry_entry_t) -> Any? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue()
    }
}
