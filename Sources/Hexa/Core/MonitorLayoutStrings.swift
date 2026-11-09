// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Foundation

struct MonitorLayoutFeatureStrings {
    /// Heading for the settings shared by the menu bar and the panel.
    let shared: String
}

extension FeatureStrings {
    static func monitorLayout(_ language: AppLanguage) -> MonitorLayoutFeatureStrings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .tr: return .tr
        case .ru: return .ru
        case .es: return .es
        case .sk: return .sk
        case .de: return .de
        case .fr: return .fr
        case .it: return .it
        case .ja: return .ja
        case .ko: return .ko
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        case .uk: return .uk
        }
    }
}

extension MonitorLayoutFeatureStrings {
    static let enUS = MonitorLayoutFeatureStrings(shared: "Readings")
    static let ptBR = MonitorLayoutFeatureStrings(shared: "Leituras")
    static let tr = MonitorLayoutFeatureStrings(shared: "Ölçümler")
    static let ru = MonitorLayoutFeatureStrings(shared: "Показания")
    static let es = MonitorLayoutFeatureStrings(shared: "Lecturas")
    static let sk = MonitorLayoutFeatureStrings(shared: "Hodnoty")
    static let de = MonitorLayoutFeatureStrings(shared: "Messwerte")
    static let fr = MonitorLayoutFeatureStrings(shared: "Mesures")
    static let it = MonitorLayoutFeatureStrings(shared: "Letture")
    static let ja = MonitorLayoutFeatureStrings(shared: "計測")
    static let ko = MonitorLayoutFeatureStrings(shared: "측정값")
    static let zhHans = MonitorLayoutFeatureStrings(shared: "读数")
    static let zhTW = MonitorLayoutFeatureStrings(shared: "讀數")
    static let zhHK = MonitorLayoutFeatureStrings(shared: "讀數")
    static let uk = MonitorLayoutFeatureStrings(shared: "Показники")
}
