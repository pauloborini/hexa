// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

import FanControlCore

@testable import Hexa

/// Pins the input validation that guards every fan control write: curve
/// points inside the documented ranges, monotonic curves, manual levels on
/// the 5% step, and NaN sensor temperatures rejected before they can reach
/// an SMC write. The helper re-validates on its side of the XPC; these tests
/// pin the same contract in the app.
final class FanControlPolicyValidationTests: XCTestCase {
    private var validCurve: FanControlCurve {
        FanControlCurve(sensor: .hottestSoC, points: [
            FanControlCurvePoint(temperature: 40, coolingLevel: 20),
            FanControlCurvePoint(temperature: 80, coolingLevel: 80)
        ])
    }

    // MARK: Curve ranges

    func testAcceptsValidCurve() {
        XCTAssertTrue(FanControlPolicy.validCurve(validCurve))
        XCTAssertTrue(FanControlPolicy.validCurves([validCurve]))
        XCTAssertTrue(FanControlPolicy.validConfiguration(.curve([validCurve])))
    }

    func testRejectsTemperatureOutOfRange() {
        let below = FanControlCurve(sensor: .hottestSoC, points: [
            FanControlCurvePoint(temperature: FanControlPolicy.minimumCurveTemperature - 1,
                                 coolingLevel: 20),
            FanControlCurvePoint(temperature: 80, coolingLevel: 80)
        ])
        let above = FanControlCurve(sensor: .hottestSoC, points: [
            FanControlCurvePoint(temperature: 40, coolingLevel: 20),
            FanControlCurvePoint(temperature: FanControlPolicy.maximumCurveTemperature + 1,
                                 coolingLevel: 80)
        ])
        XCTAssertFalse(FanControlPolicy.validCurve(below))
        XCTAssertFalse(FanControlPolicy.validCurve(above))
    }

    func testRejectsCoolingLevelOffStepOrRange() {
        for level in [-5, 33, 105] {
            let curve = FanControlCurve(sensor: .hottestSoC, points: [
                FanControlCurvePoint(temperature: 40, coolingLevel: level),
                FanControlCurvePoint(temperature: 80, coolingLevel: 80)
            ])
            XCTAssertFalse(FanControlPolicy.validCurve(curve), "level \(level)")
        }
    }

    // MARK: Monotonic curves (no extreme drops)

    func testRejectsDecreasingTemperature() {
        let curve = FanControlCurve(sensor: .hottestSoC, points: [
            FanControlCurvePoint(temperature: 60, coolingLevel: 20),
            FanControlCurvePoint(temperature: 40, coolingLevel: 40)
        ])
        XCTAssertFalse(FanControlPolicy.validCurve(curve))
    }

    func testRejectsDecreasingCoolingLevel() {
        let curve = FanControlCurve(sensor: .hottestSoC, points: [
            FanControlCurvePoint(temperature: 40, coolingLevel: 60),
            FanControlCurvePoint(temperature: 80, coolingLevel: 20)
        ])
        XCTAssertFalse(FanControlPolicy.validCurve(curve))
    }

    func testRejectsTooFewPointsAndDuplicateSensors() {
        let single = FanControlCurve(sensor: .hottestSoC,
                                     points: [FanControlCurvePoint(temperature: 40, coolingLevel: 20)])
        XCTAssertFalse(FanControlPolicy.validCurve(single))
        XCTAssertFalse(FanControlPolicy.validCurves([validCurve, validCurve]))
        XCTAssertFalse(FanControlPolicy.validCurves([]))
    }

    // MARK: Manual level

    func testRejectsManualLevelOffStepOrRange() {
        XCTAssertFalse(FanControlPolicy.validConfiguration(.manual(level: 33)))
        XCTAssertFalse(FanControlPolicy.validConfiguration(.manual(level: -5)))
        XCTAssertFalse(FanControlPolicy.validConfiguration(.manual(level: 105)))
        XCTAssertTrue(FanControlPolicy.validConfiguration(.manual(level: 50)))
    }

    // MARK: NaN and persisted-curve revalidation

    func testRejectsNaNTemperature() {
        XCTAssertFalse(FanControlPolicy.validTemperature(.nan))
        XCTAssertFalse(FanControlPolicy.validTemperature(.infinity))
    }

    func testResumeDecodingRevalidatesTheCurve() {
        let base = "{\"mode\":\"curve\",\"manualLevel\":0,\"curves\":" +
            "[{\"sensor\":\"hottestSoC\",\"points\":[" +
            "{\"temperature\":%@,\"coolingLevel\":%@}," +
            "{\"temperature\":80,\"coolingLevel\":80}]}]}"
        let valid = String(format: base, "40", "20")
        let offRange = String(format: base, "15", "20")
        let offStep = String(format: base, "40", "33")
        XCTAssertNotNil(FanControlConfiguration.decodeResume(valid))
        XCTAssertNil(FanControlConfiguration.decodeResume(offRange))
        XCTAssertNil(FanControlConfiguration.decodeResume(offStep))
    }

    func testCoolingTargetStaysInsideSensorReportedBounds() {
        // Level 0 maps to the reported minimum and 100 to the reported
        // maximum: no level can write past the sensor's own range.
        XCTAssertEqual(FanControlPolicy.coolingTargetRPM(minimum: 1200, maximum: 6000, level: 0), 1200)
        XCTAssertEqual(FanControlPolicy.coolingTargetRPM(minimum: 1200, maximum: 6000, level: 100), 6000)
        XCTAssertEqual(FanControlPolicy.coolingTargetRPM(minimum: 1200, maximum: 6000, level: 50), 3600)
    }

    func testCoolingTargetRejectsImplausibleBounds() {
        XCTAssertNil(FanControlPolicy.coolingTargetRPM(minimum: -1, maximum: 6000, level: 50))
        XCTAssertNil(FanControlPolicy.coolingTargetRPM(minimum: 6000, maximum: 6000, level: 50))
        XCTAssertNil(FanControlPolicy.coolingTargetRPM(minimum: 1200,
                                                      maximum: FanControlPolicy.maximumSaneRPM + 1,
                                                      level: 50))
        XCTAssertNil(FanControlPolicy.coolingTargetRPM(minimum: 1200, maximum: 6000, level: 33))
    }
}
