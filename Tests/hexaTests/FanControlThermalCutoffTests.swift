// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa
import FanControlCore

/// Pina o corte térmico do modo manual: o corte só dispara a partir de
/// `serious`, e o motivo térmico sobrevive ao roundtrip do codec IPC.
final class FanControlThermalCutoffTests: XCTestCase {
    // MARK: - thermal state cases

    /// Estados abaixo de `serious` mantêm a sessão manual.
    func testNominalAndFairDoNotTriggerCutoff() {
        XCTAssertFalse(FanControlPolicy.manualThermalCutoffActive(.nominal))
        XCTAssertFalse(FanControlPolicy.manualThermalCutoffActive(.fair))
    }

    /// A partir de `serious` o corte devolve a sessão ao firmware.
    func testSeriousAndCriticalTriggerCutoff() {
        XCTAssertTrue(FanControlPolicy.manualThermalCutoffActive(.serious))
        XCTAssertTrue(FanControlPolicy.manualThermalCutoffActive(.critical))
    }

    // MARK: - stop reason roundtrip

    /// O motivo térmico produzido pelo helper chega ao app pelo codec.
    func testThermalPressureStopReasonSurvivesRoundtrip() {
        let snapshot = FanControlSnapshot(fans: [], isCooling: false, endsAt: nil,
                                          stopReason: .thermalPressure, coolingLevel: nil,
                                          configuration: nil, temperatures: nil)
        let decoded = FanControlIPC.decode(FanControlIPC.encode(.success(snapshot)))
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.snapshot.stopReason, .thermalPressure)
    }

    /// Corte térmico apaga o estado persistido antes do wake; uma saída normal
    /// do app continua preservando a configuração autorizada para retomada.
    func testThermalCutoffDiscardsPersistedResumeBeforeWakeButQuitKeepsIt() throws {
        let suiteLock = DefaultsSuiteLock("fan-control-thermal-cutoff")
        defer { withExtendedLifetime(suiteLock) {} }
        let suiteName = "hexaTests.fan-control-thermal-cutoff"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = FanControlConfiguration.manual(level: 65)
        let stored = try XCTUnwrap(FanControlConfiguration.encodeResume(configuration))
        defaults.set(stored, forKey: DefaultsKey.fanControlResumeConfiguration)

        let thermalResponse = FanControlResponse.success(FanControlSnapshot(
            fans: [], isCooling: false, endsAt: nil, stopReason: .thermalPressure,
            coolingLevel: nil, configuration: nil, temperatures: nil))
        XCTAssertFalse(thermalResponse.snapshot.isCooling, "corte devolve o controle ao automático")
        FanControlService.discardResumeConfiguration(after: thermalResponse, in: defaults)

        XCTAssertNil(defaults.string(forKey: DefaultsKey.fanControlResumeConfiguration))
        XCTAssertNil(FanControlConfiguration.decodeResume(
            defaults.string(forKey: DefaultsKey.fanControlResumeConfiguration) ?? ""))

        defaults.set(stored, forKey: DefaultsKey.fanControlResumeConfiguration)
        let quitResponse = FanControlResponse.success(FanControlSnapshot(
            fans: [], isCooling: false, endsAt: nil, stopReason: .appDisconnected,
            coolingLevel: nil, configuration: nil, temperatures: nil))
        FanControlService.discardResumeConfiguration(after: quitResponse, in: defaults)
        XCTAssertEqual(FanControlConfiguration.decodeResume(
            defaults.string(forKey: DefaultsKey.fanControlResumeConfiguration) ?? ""),
                       configuration)
    }
}
