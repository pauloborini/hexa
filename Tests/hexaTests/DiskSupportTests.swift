// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import Foundation
import XCTest

@testable import Hexa

final class DiskSupportTests: XCTestCase {
    private var defaultsSuiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        defaultsSuiteName = "DiskSupportTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
    }

    override func tearDown() {
        if let defaultsSuiteName {
            defaults?.removePersistentDomain(forName: defaultsSuiteName)
        }
        defaults = nil
        defaultsSuiteName = nil
        super.tearDown()
    }

    // MARK: - NativeDisk.decodeSMART

    func testDecodeSMARTRejectsInvalidByteCount() {
        XCTAssertNil(NativeDisk.decodeSMART([]))
        XCTAssertNil(NativeDisk.decodeSMART([UInt8](repeating: 0, count: 511)))
        XCTAssertNil(NativeDisk.decodeSMART([UInt8](repeating: 0, count: 513)))
    }

    func testDecodeSMARTParsesStatusFromCriticalWarningByte() throws {
        var bytes = [UInt8](repeating: 0, count: 512)
        let verified = try XCTUnwrap(NativeDisk.decodeSMART(bytes))
        XCTAssertEqual(verified.status, "Verified")

        for warning: UInt8 in [0x01, 0x04, 0x10, 0xFF] {
            bytes[0] = warning
            let failing = try XCTUnwrap(NativeDisk.decodeSMART(bytes))
            XCTAssertEqual(failing.status, "Failing")
        }
    }

    func testDecodeSMARTParsesKelvinTemperatureAndRejectsZeroAndOutOfRange() throws {
        var bytes = [UInt8](repeating: 0, count: 512)
        XCTAssertNil(try XCTUnwrap(NativeDisk.decodeSMART(bytes)).temperatureCelsius)

        // 310 K (0x0136 little-endian) -> 36.85 C
        bytes[1] = 0x36
        bytes[2] = 0x01
        let nominal = try XCTUnwrap(NativeDisk.decodeSMART(bytes))
        XCTAssertEqual(try XCTUnwrap(nominal.temperatureCelsius), 36.85, accuracy: 1e-9)

        // Lower in-range boundary: 234 K -> -39.15 C
        bytes[1] = 234
        bytes[2] = 0
        let lowValid = try XCTUnwrap(NativeDisk.decodeSMART(bytes))
        XCTAssertEqual(try XCTUnwrap(lowValid.temperatureCelsius), -39.15, accuracy: 1e-9)

        // Lower out-of-range: 233 K -> -40.15 C (< -40)
        bytes[1] = 233
        bytes[2] = 0
        XCTAssertNil(try XCTUnwrap(NativeDisk.decodeSMART(bytes)).temperatureCelsius)

        // Upper in-range boundary: 398 K (0x018E) -> 124.85 C
        bytes[1] = 0x8E
        bytes[2] = 0x01
        let highValid = try XCTUnwrap(NativeDisk.decodeSMART(bytes))
        XCTAssertEqual(try XCTUnwrap(highValid.temperatureCelsius), 124.85, accuracy: 1e-9)

        // Upper out-of-range: 399 K (0x018F) -> 125.85 C (> 125)
        bytes[1] = 0x8F
        bytes[2] = 0x01
        XCTAssertNil(try XCTUnwrap(NativeDisk.decodeSMART(bytes)).temperatureCelsius)

        bytes[1] = 0xFF
        bytes[2] = 0xFF
        XCTAssertNil(try XCTUnwrap(NativeDisk.decodeSMART(bytes)).temperatureCelsius)
    }

    func testDecodeSMARTParsesHealthPercentFromPercentageUsedByte() throws {
        var bytes = [UInt8](repeating: 0, count: 512)
        bytes[5] = 0
        XCTAssertEqual(try XCTUnwrap(NativeDisk.decodeSMART(bytes)).healthPercent, 100)

        bytes[5] = 35
        XCTAssertEqual(try XCTUnwrap(NativeDisk.decodeSMART(bytes)).healthPercent, 65)

        bytes[5] = 100
        XCTAssertEqual(try XCTUnwrap(NativeDisk.decodeSMART(bytes)).healthPercent, 0)

        bytes[5] = 200
        XCTAssertEqual(try XCTUnwrap(NativeDisk.decodeSMART(bytes)).healthPercent, 0)
    }

    func testDecodeSMARTParsesDataUnitsAndEnforcesOverflowGuards() throws {
        var bytes = [UInt8](repeating: 0, count: 512)
        let readUnits: UInt64 = 0x0102_0304
        let writtenUnits: UInt64 = 0x0506_0708
        writeLittleEndianUInt64(readUnits, to: &bytes, offset: 32)
        writeLittleEndianUInt64(writtenUnits, to: &bytes, offset: 48)

        let reading = try XCTUnwrap(NativeDisk.decodeSMART(bytes))
        XCTAssertEqual(reading.totalReadBytes, readUnits * 512_000)
        XCTAssertEqual(reading.totalWrittenBytes, writtenUnits * 512_000)

        // Largest unit count that does not overflow UInt64 when multiplied by 512_000
        let maxSafeUnits = UInt64.max / 512_000
        writeLittleEndianUInt64(maxSafeUnits, to: &bytes, offset: 32)
        writeLittleEndianUInt64(maxSafeUnits + 1, to: &bytes, offset: 48)

        let boundary = try XCTUnwrap(NativeDisk.decodeSMART(bytes))
        XCTAssertEqual(boundary.totalReadBytes, maxSafeUnits * 512_000)
        XCTAssertNil(boundary.totalWrittenBytes)

        // Non-zero upper 64 bits of 128-bit NVMe field -> nil
        writeLittleEndianUInt64(1, to: &bytes, offset: 32)
        bytes[32 + 8] = 1
        writeLittleEndianUInt64(1, to: &bytes, offset: 48)
        bytes[48 + 15] = 0x80

        let highBits = try XCTUnwrap(NativeDisk.decodeSMART(bytes))
        XCTAssertNil(highBits.totalReadBytes)
        XCTAssertNil(highBits.totalWrittenBytes)
    }

    func testDecodeSMARTParsesCountersAndGuards128BitOverflow() throws {
        var bytes = [UInt8](repeating: 0, count: 512)
        writeLittleEndianUInt64(42, to: &bytes, offset: 112)
        writeLittleEndianUInt64(12_345, to: &bytes, offset: 128)
        writeLittleEndianUInt64(7, to: &bytes, offset: 144)
        writeLittleEndianUInt64(UInt64.max, to: &bytes, offset: 160)

        let reading = try XCTUnwrap(NativeDisk.decodeSMART(bytes))
        XCTAssertEqual(reading.powerCycles, 42)
        XCTAssertEqual(reading.powerOnHours, 12_345)
        XCTAssertEqual(reading.unsafeShutdowns, 7)
        XCTAssertEqual(reading.mediaErrors, UInt64.max)

        bytes[112 + 8] = 1
        bytes[128 + 10] = 2
        bytes[144 + 12] = 3
        bytes[160 + 15] = 4

        let overflowed = try XCTUnwrap(NativeDisk.decodeSMART(bytes))
        XCTAssertNil(overflowed.powerCycles)
        XCTAssertNil(overflowed.powerOnHours)
        XCTAssertNil(overflowed.unsafeShutdowns)
        XCTAssertNil(overflowed.mediaErrors)
    }

    func testDiskSMARTReadingHasDetails() {
        XCTAssertFalse(DiskSMARTReading().hasDetails)
        XCTAssertTrue(DiskSMARTReading(status: "Verified").hasDetails)
        XCTAssertTrue(DiskSMARTReading(totalReadBytes: 0).hasDetails)
        XCTAssertTrue(DiskSMARTReading(totalWrittenBytes: 0).hasDetails)
        XCTAssertTrue(DiskSMARTReading(temperatureCelsius: 35).hasDetails)
        XCTAssertTrue(DiskSMARTReading(healthPercent: 99).hasDetails)
        XCTAssertTrue(DiskSMARTReading(powerCycles: 1).hasDetails)
        XCTAssertTrue(DiskSMARTReading(powerOnHours: 10).hasDetails)
        XCTAssertTrue(DiskSMARTReading(unsafeShutdowns: 0).hasDetails)
        XCTAssertTrue(DiskSMARTReading(mediaErrors: 0).hasDetails)
    }

    // MARK: - DiskSupport

    func testHealthPercentFromPercentageUsed() {
        XCTAssertNil(DiskSupport.healthPercent(fromPercentageUsed: nil))
        XCTAssertEqual(DiskSupport.healthPercent(fromPercentageUsed: 0), 100)
        XCTAssertEqual(DiskSupport.healthPercent(fromPercentageUsed: 37), 63)
        XCTAssertEqual(DiskSupport.healthPercent(fromPercentageUsed: 100), 0)
        XCTAssertEqual(DiskSupport.healthPercent(fromPercentageUsed: 150), 0)
        XCTAssertEqual(DiskSupport.healthPercent(fromPercentageUsed: UInt64.max), 0)
    }

    func testFileSystemLabel() {
        XCTAssertNil(DiskSupport.fileSystemLabel(type: nil))
        XCTAssertNil(DiskSupport.fileSystemLabel(type: ""))
        XCTAssertNil(DiskSupport.fileSystemLabel(type: "   \n\t "))

        XCTAssertEqual(DiskSupport.fileSystemLabel(type: "apfs"), "APFS")
        XCTAssertEqual(DiskSupport.fileSystemLabel(type: "  APFS\n"), "APFS")
        XCTAssertEqual(DiskSupport.fileSystemLabel(type: "hfs"), "HFS+")
        XCTAssertEqual(DiskSupport.fileSystemLabel(type: "exfat"), "exFAT")
        XCTAssertEqual(DiskSupport.fileSystemLabel(type: "ntfs"), "NTFS")
        XCTAssertEqual(DiskSupport.fileSystemLabel(type: "cd9660"), "ISO 9660")

        XCTAssertEqual(DiskSupport.fileSystemLabel(type: "msdos"), "FAT")
        XCTAssertEqual(DiskSupport.fileSystemLabel(type: "msdos", name: "MS-DOS (FAT32)"), "FAT32")
        XCTAssertEqual(DiskSupport.fileSystemLabel(type: "msdos", name: "MS-DOS (FAT16)"), "FAT16")
        XCTAssertEqual(DiskSupport.fileSystemLabel(type: "msdos", name: "MS-DOS (FAT12)"), "FAT12")
        XCTAssertEqual(DiskSupport.fileSystemLabel(type: "msdos", name: "MS-DOS"), "FAT")

        // Short acronym-like unknown formats
        XCTAssertEqual(DiskSupport.fileSystemLabel(type: "udf"), "UDF")
        XCTAssertEqual(DiskSupport.fileSystemLabel(type: "ext4"), "EXT4")
        XCTAssertEqual(DiskSupport.fileSystemLabel(type: "a1"), "A1")
        XCTAssertEqual(DiskSupport.fileSystemLabel(type: "btrfs1"), "BTRFS1")

        // Rejected unknown tokens
        XCTAssertNil(DiskSupport.fileSystemLabel(type: "x"))
        XCTAssertNil(DiskSupport.fileSystemLabel(type: "unknown"))
        XCTAssertNil(DiskSupport.fileSystemLabel(type: "1234"))
        XCTAssertNil(DiskSupport.fileSystemLabel(type: "fs-1"))
    }

    func testUintParser() {
        XCTAssertNil(DiskSupport.uint(nil))
        XCTAssertNil(DiskSupport.uint(NSObject()))
        XCTAssertNil(DiskSupport.uint(Date()))

        XCTAssertEqual(DiskSupport.uint(NSNumber(value: 0)), 0)
        XCTAssertEqual(DiskSupport.uint(NSNumber(value: 123_456)), 123_456)
        XCTAssertNil(DiskSupport.uint(NSNumber(value: -1)))
        XCTAssertNil(DiskSupport.uint(NSNumber(value: -42.5)))

        XCTAssertEqual(DiskSupport.uint("0"), 0)
        XCTAssertEqual(DiskSupport.uint("  98765 \n"), 98_765)
        XCTAssertNil(DiskSupport.uint("-1"))
        XCTAssertNil(DiskSupport.uint("abc"))
        XCTAssertNil(DiskSupport.uint(""))
    }

    // MARK: - DiskDeviceReading

    func testDiskDeviceReadingUsedFraction() {
        let zeroTotal = makeDevice(totalBytes: 0, usedBytes: 500)
        XCTAssertEqual(zeroTotal.usedFraction, 0, accuracy: 1e-9)

        let normal = makeDevice(totalBytes: 1_000, usedBytes: 250)
        XCTAssertEqual(normal.usedFraction, 0.25, accuracy: 1e-9)

        let clamped = makeDevice(totalBytes: 1_000, usedBytes: 1_500)
        XCTAssertEqual(clamped.usedFraction, 1.0, accuracy: 1e-9)
    }

    func testDiskDeviceReadingEjectabilityAndSystemVolumeGuard() {
        let externalEjectable = makeDevice(
            bsdName: "disk4s1",
            wholeDisk: "disk4",
            isInternal: false,
            isRemovable: false,
            isEjectable: true,
            holdsSystemVolume: false
        )
        XCTAssertEqual(externalEjectable.ejectBSDName, "disk4")
        XCTAssertTrue(externalEjectable.canEject)

        let externalRemovable = makeDevice(
            bsdName: "disk5s1",
            wholeDisk: nil,
            isInternal: false,
            isRemovable: true,
            isEjectable: false,
            holdsSystemVolume: false
        )
        XCTAssertEqual(externalRemovable.ejectBSDName, "disk5s1")
        XCTAssertTrue(externalRemovable.canEject)

        let internalDisk = makeDevice(
            bsdName: "disk3s1",
            wholeDisk: "disk3",
            isInternal: true,
            isRemovable: true,
            isEjectable: true,
            holdsSystemVolume: false
        )
        XCTAssertFalse(internalDisk.canEject)

        let externalSystemDisk = makeDevice(
            bsdName: "disk6s1",
            wholeDisk: "disk6",
            isInternal: false,
            isRemovable: true,
            isEjectable: true,
            holdsSystemVolume: true
        )
        XCTAssertFalse(externalSystemDisk.canEject)

        let fixedExternal = makeDevice(
            bsdName: "disk7s1",
            wholeDisk: "disk7",
            isInternal: false,
            isRemovable: false,
            isEjectable: false,
            holdsSystemVolume: false
        )
        XCTAssertFalse(fixedExternal.canEject)

        let missingBSD = makeDevice(
            bsdName: nil,
            wholeDisk: nil,
            isInternal: false,
            isRemovable: true,
            isEjectable: true,
            holdsSystemVolume: false
        )
        XCTAssertNil(missingBSD.ejectBSDName)
        XCTAssertFalse(missingBSD.canEject)
    }

    // MARK: - SystemMonitor.samplingPlan (Disk & SMART gating)

    func testSamplingPlanEnablesDiskHealthForFullMonitorAndPanelDisk() {
        defaults.set(true, forKey: AppFeature.monitorDisk.availabilityKey)

        let fullMonitorPlan = SystemMonitor.samplingPlan(
            defaults: defaults,
            shouldRun: true,
            fullMonitorVisible: true,
            menuPanelNeeds: .none
        )
        XCTAssertTrue(fullMonitorPlan.needDisk)
        XCTAssertTrue(fullMonitorPlan.needDiskHealth)

        var diskPanelNeeds = SystemMonitorPanelNeeds.none
        diskPanelNeeds.disk = true
        let panelPlan = SystemMonitor.samplingPlan(
            defaults: defaults,
            shouldRun: true,
            fullMonitorVisible: false,
            menuPanelNeeds: diskPanelNeeds
        )
        XCTAssertTrue(panelPlan.needDisk)
        XCTAssertTrue(panelPlan.needDiskHealth)
    }

    func testSamplingPlanKeepsDiskHealthOffForMenuBarOnlyBackgroundSampling() {
        defaults.set(true, forKey: AppFeature.monitorDisk.availabilityKey)
        defaults.set(true, forKey: DefaultsKey.menuBarDiskUsage)

        let usageOnlyPlan = SystemMonitor.samplingPlan(
            defaults: defaults,
            shouldRun: true,
            fullMonitorVisible: false,
            menuPanelNeeds: .none
        )
        XCTAssertTrue(usageOnlyPlan.needDisk)
        XCTAssertFalse(usageOnlyPlan.needDiskHealth)

        defaults.set(false, forKey: DefaultsKey.menuBarDiskUsage)
        defaults.set(true, forKey: DefaultsKey.menuBarDiskActivity)

        let activityOnlyPlan = SystemMonitor.samplingPlan(
            defaults: defaults,
            shouldRun: true,
            fullMonitorVisible: false,
            menuPanelNeeds: .none
        )
        XCTAssertTrue(activityOnlyPlan.needDisk)
        XCTAssertFalse(activityOnlyPlan.needDiskHealth)
    }

    func testSamplingPlanGatesDiskAndHealthWhenFeatureUnavailableOrIdle() {
        defaults.set(false, forKey: AppFeature.monitorDisk.availabilityKey)
        defaults.set(true, forKey: DefaultsKey.menuBarDiskUsage)
        var diskPanelNeeds = SystemMonitorPanelNeeds.none
        diskPanelNeeds.disk = true

        let unavailablePlan = SystemMonitor.samplingPlan(
            defaults: defaults,
            shouldRun: true,
            fullMonitorVisible: true,
            menuPanelNeeds: diskPanelNeeds
        )
        XCTAssertFalse(unavailablePlan.needDisk)
        XCTAssertFalse(unavailablePlan.needDiskHealth)

        defaults.set(true, forKey: AppFeature.monitorDisk.availabilityKey)
        let idlePlan = SystemMonitor.samplingPlan(
            defaults: defaults,
            shouldRun: false,
            fullMonitorVisible: true,
            menuPanelNeeds: diskPanelNeeds
        )
        XCTAssertFalse(idlePlan.needDisk)
        XCTAssertFalse(idlePlan.needDiskHealth)
    }

    // MARK: - Helpers

    private func writeLittleEndianUInt64(_ value: UInt64, to bytes: inout [UInt8], offset: Int) {
        for index in 0..<8 {
            bytes[offset + index] = UInt8((value >> (index * 8)) & 0xFF)
        }
    }

    private func makeDevice(
        id: String = "/Volumes/Test",
        name: String = "Test",
        mountPath: String = "/Volumes/Test",
        volumeUUID: String? = "00000000-0000-0000-0000-000000000001",
        bsdName: String? = "disk2s1",
        wholeDisk: String? = "disk2",
        ioCounterID: String? = nil,
        fileSystem: String? = "APFS",
        totalBytes: UInt64 = 1_000,
        freeBytes: UInt64 = 500,
        purgeableBytes: UInt64? = nil,
        usedBytes: UInt64 = 500,
        isInternal: Bool = false,
        isRemovable: Bool = false,
        isEjectable: Bool = false,
        smart: DiskSMARTReading? = nil,
        readBytesPerSec: Double? = nil,
        writeBytesPerSec: Double? = nil,
        totalReadBytes: UInt64? = nil,
        totalWrittenBytes: UInt64? = nil,
        holdsSystemVolume: Bool = false
    ) -> DiskDeviceReading {
        DiskDeviceReading(
            id: id,
            name: name,
            mountPath: mountPath,
            volumeUUID: volumeUUID,
            bsdName: bsdName,
            wholeDisk: wholeDisk,
            ioCounterID: ioCounterID,
            fileSystem: fileSystem,
            totalBytes: totalBytes,
            freeBytes: freeBytes,
            purgeableBytes: purgeableBytes,
            usedBytes: usedBytes,
            isInternal: isInternal,
            isRemovable: isRemovable,
            isEjectable: isEjectable,
            smart: smart,
            readBytesPerSec: readBytesPerSec,
            writeBytesPerSec: writeBytesPerSec,
            totalReadBytes: totalReadBytes,
            totalWrittenBytes: totalWrittenBytes,
            holdsSystemVolume: holdsSystemVolume
        )
    }
}
