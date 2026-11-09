// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Pins the deterministic formatting of the system monitor. `MetricFormat`
/// deliberately exposes its `locale` so a test can pin the decimal rules
/// (its own doc comment promises that); every test here pins it to a fixed
/// locale and restores the original in a defer, leaving no state behind.
final class MetricFormatTests: XCTestCase {
    /// Runs the body with the formatter pinned to a fixed-locale, restoring
    /// the process value afterwards.
    private func pinned(_ body: () -> Void) {
        let original = MetricFormat.locale
        MetricFormat.locale = Locale(identifier: "en_US_POSIX")
        defer { MetricFormat.locale = original }
        body()
    }

    // MARK: Bytes and rates

    func testByteScalingUsesBase1024Units() {
        pinned {
            XCTAssertEqual(MetricFormat.bytes(0), "0 B")
            XCTAssertEqual(MetricFormat.bytes(512), "512 B")
            XCTAssertEqual(MetricFormat.bytes(1_572_864), "1.5 MB")
            XCTAssertEqual(MetricFormat.bytes(1_200_000_000), "1.1 GB")
        }
    }

    func testCompactRatesCollapseAndRound() {
        pinned {
            XCTAssertEqual(MetricFormat.bytesPerSecCompact(0), "0B")
            XCTAssertEqual(MetricFormat.bytesPerSecCompact(999), "999B")
            XCTAssertEqual(MetricFormat.bytesPerSecCompact(1_048_576), "1.0M")
            XCTAssertEqual(MetricFormat.bytesPerSecCompact(327_680), "320K")
        }
    }

    func testPerSecondRatesKeepOneUnitPerStep() {
        pinned {
            XCTAssertEqual(MetricFormat.bytesPerSec(1_572_864), "1.5 MB/s")
            XCTAssertEqual(MetricFormat.bytesPerSec(0), "0 B/s")
        }
    }

    func testDiskBytesUseBase1000() {
        pinned {
            XCTAssertEqual(MetricFormat.diskBytes(5_000), "5.0 KB")
            XCTAssertEqual(MetricFormat.diskBytes(12_345_678_901), "12 GB")
            XCTAssertEqual(MetricFormat.diskBytesPrecise(1_500_000_000_000), "1.50 TB")
        }
    }

    // MARK: Percentages and power

    func testPercentClampsAndRounds() {
        pinned {
            XCTAssertEqual(MetricFormat.percent(0.1234), "12%")
            XCTAssertEqual(MetricFormat.percent(0.999), "100%")
            XCTAssertEqual(MetricFormat.percent(-2), "0%")
        }
        XCTAssertEqual(MetricFormat.boundedPercentage(150), 100)
        XCTAssertEqual(MetricFormat.boundedPercentage(.nan), 0)
        XCTAssertEqual(MetricFormat.boundedPercentage(-1), 0)
    }

    func testMenuBarMemoryFallsBackToPlaceholder() {
        pinned {
            XCTAssertEqual(MetricFormat.menuBarMemoryPercent(used: 2, total: 8), "25%")
            XCTAssertEqual(MetricFormat.menuBarMemoryPercent(used: nil, total: 8), "--%")
            XCTAssertEqual(MetricFormat.menuBarMemoryPercent(used: 2, total: 0), "--%")
        }
    }

    func testWattsKeepOneDecimalUnderTen() {
        pinned {
            XCTAssertEqual(MetricFormat.watts(8.54), "8.5 W")
            XCTAssertEqual(MetricFormat.watts(23), "23 W")
            XCTAssertEqual(MetricFormat.wattsCompact(8.6), "9W")
        }
    }

    func testSystemPowerDerivesFromBatteryDischarge() {
        XCTAssertNil(MetricFormat.systemPowerWatts(measured: nil, batteryWatts: nil, externalConnected: false))
        XCTAssertNil(MetricFormat.systemPowerWatts(measured: nil, batteryWatts: 5, externalConnected: false),
                     "a positive battery rate is charging, not discharging")
        // A negative battery rate means the machine is drawing from the
        // battery; the reported power comes out positive.
        XCTAssertEqual(MetricFormat.systemPowerWatts(measured: nil, batteryWatts: -8.5, externalConnected: false), 8.5)
        XCTAssertNil(MetricFormat.systemPowerWatts(measured: nil, batteryWatts: -8.5, externalConnected: true))
        XCTAssertEqual(MetricFormat.systemPowerWatts(measured: 3.2, batteryWatts: -8.5, externalConnected: false), 3.2)
    }

    // MARK: Temperature and uptime

    func testTemperatureConvertsUnits() {
        pinned {
            XCTAssertEqual(MetricFormat.temperature(23.6, unit: .celsius), "24 °C")
            XCTAssertEqual(MetricFormat.temperature(100, unit: .fahrenheit), "212 °F")
            XCTAssertEqual(MetricFormat.temperatureCompact(23.6, unit: .celsius), "24°")
            XCTAssertEqual(MetricFormat.temperatureUnitSuffix(.celsius), "°C")
            XCTAssertEqual(MetricFormat.temperatureUnitSuffix(.fahrenheit), "°F")
        }
    }

    func testUptimeCompressesToTheTwoLargestUnits() {
        pinned {
            XCTAssertEqual(MetricFormat.uptime(59), "0min")
            XCTAssertEqual(MetricFormat.uptime(3_660), "1h 1min")
            XCTAssertEqual(MetricFormat.uptime(90_000), "1d 1h")
            XCTAssertEqual(MetricFormat.uptime(-5), "0min")
        }
    }

    // MARK: Graphs and counters

    func testGraphCeilingSnapsToUnitSteps() {
        XCTAssertEqual(MetricFormat.graphCeiling(900_000, unitStep: 1024), 1_048_576)
        XCTAssertEqual(MetricFormat.graphCeiling(1_100_000, unitStep: 1024), 2_097_152)
        XCTAssertEqual(MetricFormat.graphCeiling(5.2, unitStep: 1000), 10)
    }

    func testNetSpeedGuardsResetsAndZeroElapsed() {
        let previous = NetworkCounters(received: 1_000, sent: 500)
        let current = NetworkCounters(received: 3_000, sent: 1_500)
        let speed = MetricFormat.netSpeed(previous: previous, current: current, elapsed: 2)
        XCTAssertEqual(speed.down, 1000, accuracy: 0.001)
        XCTAssertEqual(speed.up, 500, accuracy: 0.001)
        // A non-increasing counter reads as zero, never a bogus spike.
        let reset = MetricFormat.netSpeed(previous: previous, current: NetworkCounters(received: 10, sent: 5), elapsed: 2)
        XCTAssertEqual(reset.down, 0)
        XCTAssertEqual(reset.up, 0)
        let stalled = MetricFormat.netSpeed(previous: previous, current: current, elapsed: 0)
        XCTAssertEqual(stalled.down, 0)
        XCTAssertEqual(stalled.up, 0)
    }

    func testProcessCPUPercentageStaysBounded() {
        // 50% of one core out of two cores over 1s.
        let halfCore = MetricFormat.processCPUPercentage(previousNanoseconds: 0,
                                                         currentNanoseconds: 500_000_000,
                                                         elapsed: 1,
                                                         processorCount: 2)
        XCTAssertEqual(halfCore, 25, accuracy: 0.001)
        XCTAssertEqual(MetricFormat.processCPUPercentage(previousNanoseconds: 100, currentNanoseconds: 0, elapsed: 1, processorCount: 2), 0)
        XCTAssertEqual(MetricFormat.processCPUPercentage(previousNanoseconds: 0, currentNanoseconds: 100, elapsed: 0, processorCount: 2), 0)
    }

    func testStabilizedGPUHidesSingleSampleSpikes() {
        XCTAssertEqual(MetricFormat.stabilizedGPUUsage(previous: nil, current: 0.8), 0.8)
        // A single spike can only rise 0.20 above the baseline.
        let capped = MetricFormat.stabilizedGPUUsage(previous: 0.1, current: 0.9)
        XCTAssertEqual(capped, 0.3, accuracy: 0.0001)
        let decayed = MetricFormat.stabilizedGPUUsage(previous: 0.8, current: 0)
        XCTAssertEqual(decayed, 0.28, accuracy: 0.0001)
        // A non-finite sample reads as zero and still decays from the baseline.
        let nonFinite = MetricFormat.stabilizedGPUUsage(previous: 0.5, current: .nan)
        XCTAssertEqual(nonFinite, 0.175, accuracy: 0.0001)
    }

    func testMachTimeConversionAndGuards() {
        XCTAssertEqual(MetricFormat.machTimeNanoseconds(1_000, numerator: 1, denominator: 0), nil)
        XCTAssertEqual(MetricFormat.machTimeNanoseconds(1_000, numerator: 2, denominator: 4), 500)
    }

    /// Frozen inbound counter in the background: `nettop` runs at most once
    /// per policy interval and the last rate is reused in between.
    func testBackgroundCounterFallbackThrottlesProcessReader() {
        var sent: UInt64 = 0
        var processReads = 0
        var bytesIn: Double = 0
        let sampler = NetworkSampler(
            counterReader: {
                sent += 1_000
                return NetworkCounters(received: 0, sent: sent)
            },
            processReader: {
                processReads += 1
                bytesIn += 5_000
                return [NetworkProcessSample(pid: 1, name: "app", bytesIn: bytesIn, bytesOut: 0)]
            })

        var downloads: [Double?] = []
        for second in 0..<12 {
            downloads.append(sampler.sample(now: TimeInterval(second), background: true).downBytesPerSec)
        }

        XCTAssertEqual(processReads, 3)              // t = 1, 6, 11
        XCTAssertEqual(downloads[6], 1_000)          // 5 000 bytes over 5 s
        XCTAssertEqual(downloads[9], 1_000)          // reused between runs
    }
}
