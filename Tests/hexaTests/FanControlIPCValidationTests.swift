// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

import FanControlCore

/// Pins the IPC decoder guard for snapshot temperatures: the reading count
/// is bounded by the known sources and every celsius value must pass the
/// same range check as the policy. Invalid payloads decode to nil, like the
/// other fields. NaN stays rejected by the JSON decoder (regression).
final class FanControlIPCValidationTests: XCTestCase {
    private func encoded(temperatures: [FanControlTemperatureReading]) -> Data {
        FanControlIPC.encode(FanControlResponse.success(
            FanControlSnapshot(fans: [], isCooling: false, endsAt: nil,
                               stopReason: nil, coolingLevel: nil,
                               configuration: nil, temperatures: temperatures)
        ))
    }

    private func readings(celsius: Double) -> [FanControlTemperatureReading] {
        FanControlTemperatureSource.allCases.map {
            FanControlTemperatureReading(source: $0, celsius: celsius)
        }
    }

    func testAcceptsTemperaturesInsideRange() {
        let decoded = FanControlIPC.decode(encoded(temperatures: readings(celsius: 50)))
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.snapshot.temperatures?.count,
                       FanControlTemperatureSource.allCases.count)
    }

    func testRejectsCelsiusAtUpperBound() {
        let data = encoded(temperatures: readings(celsius: 125))
        XCTAssertNil(FanControlIPC.decode(data))
    }

    func testRejectsCelsiusBelowLowerBound() {
        let data = encoded(temperatures: readings(celsius: -1))
        XCTAssertNil(FanControlIPC.decode(data))
    }

    func testRejectsMoreReadingsThanSources() {
        var extra = readings(celsius: 50)
        extra.append(FanControlTemperatureReading(source: .hottestGPU, celsius: 50))
        XCTAssertGreaterThan(extra.count, FanControlTemperatureSource.allCases.count)
        XCTAssertNil(FanControlIPC.decode(encoded(temperatures: extra)))
    }

    func testRejectsNaNCelsiusFromWire() {
        // JSONEncoder refuses NaN, so the wire payload is built by replacing
        // a valid literal. The unmodified payload must decode first, which
        // proves the replacement is the only reason for the nil below.
        let valid = encoded(temperatures: [FanControlTemperatureReading(source: .hottestSoC,
                                                                        celsius: 50)])
        XCTAssertNotNil(FanControlIPC.decode(valid))
        guard let text = String(data: valid, encoding: .utf8),
              let range = text.range(of: "\"celsius\":50") else {
            return XCTFail("payload no formato esperado")
        }
        let nan = text.replacingCharacters(in: range, with: "\"celsius\":NaN")
        XCTAssertNil(FanControlIPC.decode(Data(nan.utf8)))
    }

    // MARK: - coolingSpinConfirmed roundtrip

    private func encoded(coolingSpinConfirmed: Bool?) -> Data {
        FanControlIPC.encode(FanControlResponse.success(
            FanControlSnapshot(fans: [], isCooling: true, endsAt: nil,
                               stopReason: nil, coolingLevel: nil,
                               configuration: nil, temperatures: nil,
                               coolingSpinConfirmed: coolingSpinConfirmed)
        ))
    }

    func testRoundtripPreservesCoolingSpinConfirmedFalse() {
        let decoded = FanControlIPC.decode(encoded(coolingSpinConfirmed: false))
        XCTAssertEqual(decoded?.snapshot.coolingSpinConfirmed, false)
    }

    func testRoundtripPreservesCoolingSpinConfirmedTrue() {
        let decoded = FanControlIPC.decode(encoded(coolingSpinConfirmed: true))
        XCTAssertEqual(decoded?.snapshot.coolingSpinConfirmed, true)
    }

    func testDecodesLegacyPayloadWithoutCoolingSpinConfirmed() throws {
        // Snapshot antigo: o payload não traz o campo. O decoder precisa aceitar
        // a ausência e devolver nil, em vez de rejeitar o payload inteiro.
        let valid = encoded(coolingSpinConfirmed: false)
        XCTAssertNotNil(FanControlIPC.decode(valid))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: valid) as? [String: Any])
        var payload = try XCTUnwrap(object["payload"] as? [String: Any])
        var snapshot = try XCTUnwrap(payload["snapshot"] as? [String: Any])
        snapshot.removeValue(forKey: "coolingSpinConfirmed")
        payload["snapshot"] = snapshot
        object["payload"] = payload
        let legacy = try JSONSerialization.data(withJSONObject: object)
        let decoded = FanControlIPC.decode(legacy)
        XCTAssertNotNil(decoded)
        XCTAssertNil(decoded?.snapshot.coolingSpinConfirmed)
    }
}
