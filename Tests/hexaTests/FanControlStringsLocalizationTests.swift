// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Pina a paridade do catálogo de strings do Fan Control: a legenda de segurança
/// e as chaves do motivo térmico e do estado de verificação existem nos mesmos
/// 15 idiomas da base, com texto presente e distinto entre si.
final class FanControlStringsLocalizationTests: XCTestCase {
    // MARK: - language coverage

    /// A base do app tem 15 idiomas; a paridade do Fan Control acompanha a base.
    func testAppLanguageCountIsPinnedToFifteen() {
        XCTAssertEqual(AppLanguage.allCases.count, 15)
    }

    // MARK: - key parity

    /// Todo idioma entrega as três chaves do plano com texto preenchido.
    func testEveryLanguageFillsTheThreePlanKeys() {
        for language in AppLanguage.allCases {
            let strings = FeatureStrings.fanControl(language)

            XCTAssertFalse(strings.safetyCaption.isEmpty,
                           "safetyCaption vazia em \(language.rawValue)")
            XCTAssertFalse(strings.thermalPressureStopped.isEmpty,
                           "thermalPressureStopped vazia em \(language.rawValue)")
            XCTAssertFalse(strings.coolingUnverified.isEmpty,
                           "coolingUnverified vazia em \(language.rawValue)")
        }
    }

    /// As três chaves não podem colidir: são mensagens distintas na tela.
    func testTheThreePlanKeysAreDistinctPerLanguage() {
        for language in AppLanguage.allCases {
            let strings = FeatureStrings.fanControl(language)

            XCTAssertNotEqual(strings.safetyCaption, strings.thermalPressureStopped,
                              "safetyCaption e thermalPressureStopped colidem em \(language.rawValue)")
            XCTAssertNotEqual(strings.safetyCaption, strings.coolingUnverified,
                              "safetyCaption e coolingUnverified colidem em \(language.rawValue)")
            XCTAssertNotEqual(strings.thermalPressureStopped, strings.coolingUnverified,
                              "thermalPressureStopped e coolingUnverified colidem em \(language.rawValue)")
        }
    }
}
