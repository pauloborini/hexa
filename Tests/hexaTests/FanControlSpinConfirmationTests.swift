// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

import FanControlCore

/// Pina a confirmação de giro: a ventoinha parada não confirma, o giro dentro
/// da banda do alvo confirma, e leitura inválida não confirma.
final class FanControlSpinConfirmationTests: XCTestCase {
    // MARK: - spin band cases

    /// Ventoinha parada contra alvo alto: não há giro, não confirma.
    func testStoppedFanDoesNotConfirmAgainstTarget() {
        XCTAssertFalse(FanControlPolicy.fanSpinConfirmed(actualRPM: 0, targetRPM: 4000))
    }

    /// Na banda do alvo (60% de 4000 RPM) o giro está confirmado.
    func testFanInsideBandConfirms() {
        XCTAssertTrue(FanControlPolicy.fanSpinConfirmed(actualRPM: 2400, targetRPM: 4000))
    }

    /// Acima do alvo o giro está confirmado.
    func testFanAboveTargetConfirms() {
        XCTAssertTrue(FanControlPolicy.fanSpinConfirmed(actualRPM: 5000, targetRPM: 4000))
    }

    /// Alvo zero não exige giro.
    func testZeroTargetDoesNotRequireSpin() {
        XCTAssertTrue(FanControlPolicy.fanSpinConfirmed(actualRPM: 0, targetRPM: 0))
    }

    /// Leitura inválida (não finita ou negativa) não confirma.
    func testInvalidReadingsDoNotConfirm() {
        XCTAssertFalse(FanControlPolicy.fanSpinConfirmed(actualRPM: .nan, targetRPM: 4000))
        XCTAssertFalse(FanControlPolicy.fanSpinConfirmed(actualRPM: 2400, targetRPM: .infinity))
        XCTAssertFalse(FanControlPolicy.fanSpinConfirmed(actualRPM: -1, targetRPM: 4000))
        XCTAssertFalse(FanControlPolicy.fanSpinConfirmed(actualRPM: 2400, targetRPM: -1))
    }

    // MARK: - policy constants

    /// Os literais do contrato não derivam de nada: ratio 0.6 e limite de três.
    func testSpinPolicyConstantsMatchTheContract() {
        XCTAssertEqual(FanControlPolicy.spinConfirmationRatio, 0.6)
        XCTAssertEqual(FanControlPolicy.spinConfirmationFailureLimit, 3)
    }
}
