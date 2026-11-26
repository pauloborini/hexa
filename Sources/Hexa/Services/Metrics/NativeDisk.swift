// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import Foundation
import IOKit
import DiskArbitration

/// Resolves the physical IOMedia through the service plane, including APFS
/// containers and snapshots. Ambiguous or missing ancestry stays unresolved.
enum NativeDisk {
    struct Identity {
        var mediaID: UInt64?
        var wholeDisk: String?
        var smartServiceID: UInt64?
    }

    static func mediaID(bsdName: String, isCurrent: () -> Bool) -> UInt64? {
        guard !bsdName.isEmpty, isCurrent(),
              let matching = IOBSDNameMatching(kIOMainPortDefault, 0, bsdName),
              isCurrent() else { return nil }
        let entry = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard entry != 0 else { return nil }
        defer { IOObjectRelease(entry) }
        var id: UInt64 = 0
        guard isCurrent(), IORegistryEntryGetRegistryEntryID(entry, &id) == KERN_SUCCESS else { return nil }
        return id
    }

    static func fileSystemName(bsdName: String, isCurrent: () -> Bool) -> String? {
        guard !bsdName.isEmpty, isCurrent(),
              let session = DASessionCreate(kCFAllocatorDefault), isCurrent(),
              let disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, bsdName),
              isCurrent(), let description = DADiskCopyDescription(disk) as NSDictionary? else { return nil }
        return description[kDADiskDescriptionVolumeTypeKey] as? String
    }

    static func identity(bsdName: String, isCurrent: () -> Bool) -> Identity {
        guard !bsdName.isEmpty, isCurrent(),
              let matching = IOBSDNameMatching(kIOMainPortDefault, 0, bsdName),
              isCurrent() else { return Identity() }
        let entry = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard entry != 0 else { return Identity() }
        defer { IOObjectRelease(entry) }
        var visited = Set<UInt64>()
        var physical = Set<String>()
        var smart = Set<UInt64>()

        func visit(_ entry: io_registry_entry_t) {
            guard isCurrent() else { return }
            var id: UInt64 = 0
            guard IORegistryEntryGetRegistryEntryID(entry, &id) == KERN_SUCCESS,
                  visited.insert(id).inserted else { return }
            if isCurrent(), IOObjectConformsTo(entry, "IOMedia") != 0,
               isCurrent(),
               IOObjectConformsTo(entry, "AppleAPFSMedia") == 0,
               isCurrent(),
               (property("Whole", entry) as? Bool) == true,
               isCurrent(),
               let name = property("BSD Name", entry) as? String {
                physical.insert(name)
            }
            if isCurrent(), (property("NVMe SMART Capable", entry) as? Bool) == true {
                smart.insert(id)
            }
            var iterator: io_iterator_t = 0
            guard isCurrent(), IORegistryEntryGetParentIterator(entry, kIOServicePlane, &iterator) == KERN_SUCCESS else { return }
            defer { IOObjectRelease(iterator) }
            while isCurrent() {
                let parent = IOIteratorNext(iterator)
                guard parent != 0 else { break }
                defer { IOObjectRelease(parent) }
                visit(parent)
            }
        }
        visit(entry)
        var mediaID: UInt64 = 0
        guard isCurrent(), IORegistryEntryGetRegistryEntryID(entry, &mediaID) == KERN_SUCCESS,
              physical.count == 1 else { return Identity() }
        return Identity(mediaID: mediaID, wholeDisk: physical.first, smartServiceID: smart.count == 1 ? smart.first : nil)
    }

    private static func property(_ key: String, _ entry: io_registry_entry_t) -> Any? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }

    static func readSMART(serviceID: UInt64, isCurrent: () -> Bool) -> DiskSMARTReading? {
        guard isCurrent(), let matching = IORegistryEntryIDMatching(serviceID), isCurrent() else { return nil }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard let type = CFUUIDCreateFromString(kCFAllocatorDefault, "AA0FA6F9-C2D6-457F-B10B-59A13253292F" as CFString),
              let pluginID = CFUUIDCreateFromString(kCFAllocatorDefault, "C244E858-109C-11D4-91D4-0050E4C6426F" as CFString),
              let interfaceID = CFUUIDCreateFromString(kCFAllocatorDefault, "CCD1DB19-FD9A-4DAF-BF95-12454B230AB6" as CFString) else {
            return nil
        }
        var plugin: UnsafeMutablePointer<UnsafeMutablePointer<IOCFPlugInInterface>?>?
        var score: Int32 = 0
        guard isCurrent() else { return nil }
        let result = IOCreatePlugInInterfaceForService(service, type, pluginID, &plugin, &score)
        guard let plugin else { return nil }
        defer { IODestroyPlugInInterface(plugin) }
        guard result == KERN_SUCCESS, let pluginTable = plugin.pointee,
              let queryInterface = pluginTable.pointee.QueryInterface else { return nil }
        var interface: UnsafeMutableRawPointer?
        guard isCurrent(), queryInterface(plugin, CFUUIDGetUUIDBytes(interfaceID), &interface) == 0,
              let interface else { return nil }
        guard let table = interface.load(as: UnsafeRawPointer?.self),
              let releasePtr = table.load(fromByteOffset: 24, as: UnsafeRawPointer?.self) else { return nil }
        // IUNKNOWN_C_GUTS followed by version/revision and SMARTReadData.
        // The SDK does not expose IONVMeSMARTInterface to Swift.
        typealias Release = @convention(c) (UnsafeMutableRawPointer) -> UInt32
        typealias Read = @convention(c) (UnsafeMutableRawPointer, UnsafeMutableRawPointer) -> Int32
        let release = unsafeBitCast(releasePtr, to: Release.self)
        defer { _ = release(interface) }
        guard isCurrent(),
              let readPtr = table.load(fromByteOffset: 40, as: UnsafeRawPointer?.self) else { return nil }
        let read = unsafeBitCast(readPtr, to: Read.self)
        var bytes = [UInt8](repeating: 0, count: 512)
        let readStatus = bytes.withUnsafeMutableBytes { buffer -> Int32? in
            guard let baseAddress = buffer.baseAddress else { return nil }
            return read(interface, baseAddress)
        }
        guard isCurrent(), readStatus == KERN_SUCCESS else { return nil }
        return decodeSMART(bytes)
    }

    static func decodeSMART(_ bytes: [UInt8]) -> DiskSMARTReading? {
        guard bytes.count == 512 else { return nil }
        func number(_ offset: Int) -> UInt64? {
            guard offset >= 0, offset + 16 <= bytes.count else { return nil }
            guard bytes[(offset + 8)..<(offset + 16)].allSatisfy({ $0 == 0 }) else { return nil }
            return (0..<8).reduce(UInt64(0)) { $0 | (UInt64(bytes[offset + $1]) << ($1 * 8)) }
        }
        func dataBytes(_ offset: Int) -> UInt64? {
            guard let value = number(offset) else { return nil }
            let result = value.multipliedReportingOverflow(by: DiskSupport.nvmeDataUnitBytes)
            return result.overflow ? nil : result.partialValue
        }
        let kelvin = UInt16(bytes[1]) | UInt16(bytes[2]) << 8
        let temperature = kelvin == 0 ? nil : Double(kelvin) - 273.15
        var reading = DiskSMARTReading()
        reading.status = bytes[0] == 0 ? "Verified" : "Failing"
        reading.totalReadBytes = dataBytes(32)
        reading.totalWrittenBytes = dataBytes(48)
        reading.temperatureCelsius = temperature.flatMap { (-40...125).contains($0) ? $0 : nil }
        reading.healthPercent = DiskSupport.healthPercent(fromPercentageUsed: UInt64(bytes[5]))
        reading.powerCycles = number(112)
        reading.powerOnHours = number(128)
        reading.unsafeShutdowns = number(144)
        reading.mediaErrors = number(160)
        return reading
    }
}
