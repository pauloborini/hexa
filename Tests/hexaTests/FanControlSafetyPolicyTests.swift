// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

import FanControlCore

/// Pins a contagem de falhas de temperatura usada pelo watchdog em sessão
/// manual: três ticks consecutivos sem leitura útil devolvem o controle ao
/// Sistema com `temperatureUnavailable`, e uma leitura útil zera a contagem.
final class FanControlSafetyPolicyTests: XCTestCase {
    /// Replica a sequência do watchdog: atualiza a contagem a cada tick e
    /// consulta `restoreReason` com os demais sinais saudáveis.
    private func firstStopReason(samples: [Bool]) -> (reason: FanControlStopReason?, count: Int) {
        var failures = 0
        for hasUsableReading in samples {
            failures = FanControlPolicy.nextTemperatureFailures(
                previous: failures, hasUsableReading: hasUsableReading)
            if let reason = FanControlPolicy.restoreReason(
                now: Date(), endsAt: nil, heartbeatAge: 0, verificationFailures: 0,
                temperatureFailures: failures) {
                return (reason, failures)
            }
        }
        return (nil, failures)
    }

    func testMissingReadingsCountConsecutively() {
        var failures = 0
        for expected in 1...3 {
            failures = FanControlPolicy.nextTemperatureFailures(previous: failures,
                                                                hasUsableReading: false)
            XCTAssertEqual(failures, expected)
        }
    }

    func testUsableReadingResetsCount() {
        XCTAssertEqual(FanControlPolicy.nextTemperatureFailures(previous: 2,
                                                                hasUsableReading: true), 0)
        XCTAssertEqual(FanControlPolicy.nextTemperatureFailures(previous: 0,
                                                                hasUsableReading: true), 0)
    }

    func testTwoMissesDoNotRestore() {
        let result = firstStopReason(samples: [false, false])
        XCTAssertNil(result.reason)
        XCTAssertEqual(result.count, 2)
    }

    func testThreeConsecutiveMissesRequestTemperatureRestore() {
        XCTAssertEqual(FanControlPolicy.temperatureFailureLimit, 3)
        let result = firstStopReason(samples: [false, false, false])
        XCTAssertEqual(result.reason, .temperatureUnavailable)
        XCTAssertEqual(result.count, 3)
    }

    func testUsableReadingBetweenMissesPreventsRestore() {
        let result = firstStopReason(samples: [false, false, true, false, false])
        XCTAssertNil(result.reason)
        XCTAssertEqual(result.count, 2)
    }

    /// Sem limite de tempo, heartbeat em dia e sem falhas: nenhum motivo de
    /// retorno. Não há corte por estado térmico do macOS.
    func testHealthyStateHasNoStopReason() {
        XCTAssertNil(FanControlPolicy.restoreReason(
            now: Date(), endsAt: nil, heartbeatAge: 0, verificationFailures: 0))
    }

    func testTimeLimitStillStopsAtEndsAt() {
        XCTAssertEqual(FanControlPolicy.restoreReason(
            now: Date(), endsAt: Date().addingTimeInterval(-1),
            heartbeatAge: 0, verificationFailures: 0), .timeLimit)
    }

    func testHeartbeatLossStillStopsAboveLimit() {
        XCTAssertEqual(FanControlPolicy.restoreReason(
            now: Date(), endsAt: nil,
            heartbeatAge: FanControlPolicy.heartbeatLimit + 1,
            verificationFailures: 0), .heartbeatLost)
    }

    func testHardwareChangeStillStopsAtVerificationLimit() {
        XCTAssertEqual(FanControlPolicy.restoreReason(
            now: Date(), endsAt: nil, heartbeatAge: 0,
            verificationFailures: FanControlPolicy.verificationFailureLimit), .hardwareChanged)
    }

    /// Helpers anteriores podem reportar `thermalPressure`; o app precisa
    /// continuar decodificando esse valor.
    func testLegacyThermalPressureStopReasonStillDecodes() throws {
        let data = Data("\"thermalPressure\"".utf8)
        let reason = try JSONDecoder().decode(FanControlStopReason.self, from: data)
        XCTAssertEqual(reason, .thermalPressure)
    }

    /// Piso manual: com o piso ativo o alvo sobe para 1200 RPM dentro da faixa;
    /// com o piso inativo o alvo é exatamente o de `coolingTargetRPM`.
    func testManualSafetyFloorRaisesZeroLevelToFloor() throws {
        let floored = try XCTUnwrap(FanControlPolicy.manualTargetRPM(
            minimum: 0, maximum: 6000, level: 0, safetyFloorActive: true))
        XCTAssertEqual(floored, 1200)
        assertWithinBounds(floored, minimum: 0, maximum: 6000)

        let unfloored = try XCTUnwrap(FanControlPolicy.manualTargetRPM(
            minimum: 0, maximum: 6000, level: 0, safetyFloorActive: false))
        XCTAssertEqual(unfloored, 0)
        assertWithinBounds(unfloored, minimum: 0, maximum: 6000)
    }

    func testManualSafetyFloorKeepsHigherTargetsUnchanged() throws {
        let target = try XCTUnwrap(FanControlPolicy.manualTargetRPM(
            minimum: 0, maximum: 6000, level: 50, safetyFloorActive: true))
        XCTAssertEqual(target, 3000)
        assertWithinBounds(target, minimum: 0, maximum: 6000)
    }

    func testManualSafetyFloorNeverGoesBelowFanMinimum() throws {
        let target = try XCTUnwrap(FanControlPolicy.manualTargetRPM(
            minimum: 1500, maximum: 6000, level: 0, safetyFloorActive: true))
        XCTAssertEqual(target, 1500)
        assertWithinBounds(target, minimum: 1500, maximum: 6000)
    }

    func testManualSafetyFloorNeverExceedsFanMaximum() throws {
        let target = try XCTUnwrap(FanControlPolicy.manualTargetRPM(
            minimum: 0, maximum: 1000, level: 100, safetyFloorActive: true))
        XCTAssertEqual(target, 1000)
        assertWithinBounds(target, minimum: 0, maximum: 1000)
    }

    func testManualTargetRejectsInvalidInputsAsCoolingTargetDoes() {
        XCTAssertNil(FanControlPolicy.manualTargetRPM(
            minimum: -1, maximum: 6000, level: 0, safetyFloorActive: true))
        XCTAssertNil(FanControlPolicy.manualTargetRPM(
            minimum: 0, maximum: 6000, level: 33, safetyFloorActive: true))
    }

    func testSafetyFloorActiveWithoutReadings() {
        XCTAssertTrue(FanControlPolicy.safetyFloorActive(for: [], cpuCoverageExpected: false))
    }

    func testSafetyFloorInactiveAtOrBelowThreshold() {
        XCTAssertFalse(FanControlPolicy.safetyFloorActive(for: [temperature(49.9)],
                                                          cpuCoverageExpected: false))
        XCTAssertFalse(FanControlPolicy.safetyFloorActive(for: [temperature(50.0)],
                                                          cpuCoverageExpected: false))
    }

    func testSafetyFloorActiveAboveThreshold() {
        XCTAssertTrue(FanControlPolicy.safetyFloorActive(for: [temperature(50.1)],
                                                         cpuCoverageExpected: false))
    }

    func testSafetyFloorActiveWhenAnyReadingIsHot() {
        XCTAssertTrue(FanControlPolicy.safetyFloorActive(for: [
            temperature(40), temperature(55)
        ], cpuCoverageExpected: false))
    }

    /// Cobertura de CPU esperada e sem leitura de CPU: o piso fica ativo mesmo
    /// com a GPU fria.
    func testSafetyFloorActiveWhenExpectedCPUReadingIsMissing() {
        XCTAssertTrue(FanControlPolicy.safetyFloorActive(for: [
            FanControlTemperatureReading(source: .hottestGPU, celsius: 40)
        ], cpuCoverageExpected: true))
    }

    func testSafetyFloorInactiveWhenExpectedCPUReadingsAreCool() {
        XCTAssertFalse(FanControlPolicy.safetyFloorActive(for: [
            FanControlTemperatureReading(source: .averageCPU, celsius: 40),
            FanControlTemperatureReading(source: .hottestCPU, celsius: 42)
        ], cpuCoverageExpected: true))
    }

    /// Sem cobertura de CPU esperada, a ausência de leitura de CPU não ativa o piso.
    func testSafetyFloorInactiveWhenCPUCoverageNotExpectedAndGPUCool() {
        XCTAssertFalse(FanControlPolicy.safetyFloorActive(for: [
            FanControlTemperatureReading(source: .hottestGPU, celsius: 40)
        ], cpuCoverageExpected: false))
    }

    func testSafetyFloorActiveWhenCPUCoverageNotExpectedAndGPUHot() {
        XCTAssertTrue(FanControlPolicy.safetyFloorActive(for: [
            FanControlTemperatureReading(source: .hottestGPU, celsius: 55)
        ], cpuCoverageExpected: false))
    }

    /// Sem prazo de sessão, o relógio nunca expira a sessão.
    func testSessionWithoutDeadlineNeverExpires() {
        XCTAssertFalse(FanControlPolicy.sessionExpired(nowUptime: 1_000_000, endsAtUptime: nil))
    }

    func testSessionBeforeDeadlineIsNotExpired() {
        XCTAssertFalse(FanControlPolicy.sessionExpired(nowUptime: 99.9, endsAtUptime: 100))
    }

    /// No instante exato do prazo a sessão já expira, como em `restoreReason`.
    func testSessionExpiresExactlyAtDeadline() {
        XCTAssertTrue(FanControlPolicy.sessionExpired(nowUptime: 100, endsAtUptime: 100))
    }

    func testSessionAfterDeadlineIsExpired() {
        XCTAssertTrue(FanControlPolicy.sessionExpired(nowUptime: 100.1, endsAtUptime: 100))
    }

    private func temperature(_ celsius: Double) -> FanControlTemperatureReading {
        FanControlTemperatureReading(source: .hottestSoC, celsius: celsius)
    }

    private func assertWithinBounds(_ target: Double, minimum: Double, maximum: Double,
                                    file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThanOrEqual(target, minimum, file: file, line: line)
        XCTAssertLessThanOrEqual(target, maximum, file: file, line: line)
    }
}
