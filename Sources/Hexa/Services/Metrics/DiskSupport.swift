// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Foundation

struct DiskSMARTReading: Equatable {
    var status: String?
    var totalReadBytes: UInt64?
    var totalWrittenBytes: UInt64?
    var temperatureCelsius: Double?
    var healthPercent: Int?
    var powerCycles: UInt64?
    var powerOnHours: UInt64?
    var unsafeShutdowns: UInt64?
    var mediaErrors: UInt64?

    var hasDetails: Bool {
        status != nil || totalReadBytes != nil || totalWrittenBytes != nil
            || temperatureCelsius != nil || healthPercent != nil
            || powerCycles != nil || powerOnHours != nil
            || unsafeShutdowns != nil || mediaErrors != nil
    }
}

struct DiskDeviceReading: Identifiable, Equatable {
    var id: String
    var name: String
    var mountPath: String
    /// Stable across renames and remounts, so the eject exclusion list matches
    /// on it as well as on the name and the mount path.
    var volumeUUID: String?
    var bsdName: String?
    var wholeDisk: String?
    var ioCounterID: String?
    var fileSystem: String?
    var totalBytes: UInt64
    var freeBytes: UInt64
    var purgeableBytes: UInt64?
    var usedBytes: UInt64
    var isInternal: Bool
    var isRemovable: Bool
    var isEjectable: Bool
    var smart: DiskSMARTReading?
    var readBytesPerSec: Double?
    var writeBytesPerSec: Double?
    var totalReadBytes: UInt64?
    var totalWrittenBytes: UInt64?
    /// True when this volume lives on the same physical disk as the running system
    /// (the `/` volume, or another volume sharing its whole disk). Ejecting it would
    /// take the Mac's own boot volume offline, so it is never offered for ejection.
    var holdsSystemVolume = false

    var usedFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1, max(0, Double(usedBytes) / Double(totalBytes)))
    }

    var canEject: Bool {
        !isInternal && !holdsSystemVolume && (isEjectable || isRemovable) && ejectBSDName != nil
    }

    var ejectBSDName: String? {
        wholeDisk ?? bsdName
    }
}

enum DiskMenuBarStyle: String, CaseIterable {
    case percent, free, used

    static let defaultsKey = DefaultsKey.menuBarDiskStyle

    static var current: DiskMenuBarStyle {
        DiskMenuBarStyle(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .percent
    }

    var showsPercentage: Bool { self == .percent }

    var minimumValue: String { showsPercentage ? "100%" : "1000 GB" }

    func value(for disk: DiskDeviceReading) -> String {
        switch self {
        case .percent: return MetricFormat.percent(disk.usedFraction)
        case .free: return MetricFormat.diskBytes(disk.freeBytes)
        case .used: return MetricFormat.diskBytes(disk.usedBytes)
        }
    }
}

struct DiskReading: Equatable {
    var devices: [DiskDeviceReading] = []

    var isEmpty: Bool { devices.isEmpty }

    var uniqueIODevices: [DiskDeviceReading] {
        var seen = Set<String>()
        return devices.filter { device in
            let key = device.ioCounterID ?? device.wholeDisk ?? device.bsdName ?? device.id
            return seen.insert(key).inserted
        }
    }
}

enum DiskSupport {
    static let nvmeDataUnitBytes: UInt64 = 512_000

    /// Short user-facing label for a volume format. `type` is the mount table
    /// token from statfs; `name` is used only to tell FAT widths apart.
    static func fileSystemLabel(type: String?, name: String? = nil) -> String? {
        guard let type = type?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !type.isEmpty else { return nil }
        switch type {
        case "apfs": return "APFS"
        case "hfs": return "HFS+"
        case "exfat": return "exFAT"
        case "ntfs": return "NTFS"
        case "msdos":
            if let name {
                if name.contains("32") { return "FAT32" }
                if name.contains("16") { return "FAT16" }
                if name.contains("12") { return "FAT12" }
            }
            return "FAT"
        case "cd9660": return "ISO 9660"
        default:
            // Unknown formats only earn a tag when the token already reads
            // like an acronym; anything longer is driver noise, not a format.
            guard (2...6).contains(type.count),
                  type.allSatisfy({ $0.isLetter || $0.isNumber }),
                  type.contains(where: \.isLetter) else { return nil }
            return type.uppercased()
        }
    }

    static func healthPercent(fromPercentageUsed used: UInt64?) -> Int? {
        guard let used else { return nil }
        return max(0, min(100, 100 - Int(clamping: used)))
    }

    static func uint(_ value: Any?) -> UInt64? {
        if let number = value as? NSNumber {
            let int = number.int64Value
            return int < 0 ? nil : UInt64(int)
        }
        if let string = value as? String {
            return UInt64(string.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}
