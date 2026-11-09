// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Foundation

struct ShortcutSettingsStrings {
    let active: String
    let inactive: String
}

extension FeatureStrings {
    static func shortcuts(_ language: AppLanguage) -> ShortcutSettingsStrings {
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

extension ShortcutSettingsStrings {
    static func groupEnergyAmbient(_ language: AppLanguage) -> String {
        switch language {
        case .enUS: return "Power and environment"
        case .ptBR: return "Energia e ambiente"
        case .tr: return "Enerji ve ortam"
        case .ru: return "Энергия и среда"
        case .es: return "Energía y entorno"
        case .sk: return "Energia a prostredie"
        case .de: return "Energie und Umgebung"
        case .fr: return "Énergie et environnement"
        case .it: return "Energia e ambiente"
        case .ja: return "エネルギーと環境"
        case .ko: return "에너지 및 환경"
        case .zhHans: return "能耗与环境"
        case .zhTW, .zhHK: return "能耗與環境"
        case .uk: return "Живлення та середовище"
        }
    }
}

extension ShortcutSettingsStrings {
    static let enUS = ShortcutSettingsStrings(
        active: "Active",
        inactive: "Inactive"
    )

    static let ptBR = ShortcutSettingsStrings(
        active: "Ativo",
        inactive: "Inativo"
    )

    static let tr = ShortcutSettingsStrings(
        active: "Etkin",
        inactive: "Etkin değil"
    )

    static let ru = ShortcutSettingsStrings(
        active: "Активно",
        inactive: "Неактивно"
    )

    static let es = ShortcutSettingsStrings(
        active: "Activo",
        inactive: "Inactivo"
    )

    static let sk = ShortcutSettingsStrings(
        active: "Aktívna",
        inactive: "Neaktívna"
    )

    static let de = ShortcutSettingsStrings(
        active: "Aktiv",
        inactive: "Inaktiv"
    )

    static let fr = ShortcutSettingsStrings(
        active: "Actif",
        inactive: "Inactif"
    )

    static let it = ShortcutSettingsStrings(
        active: "Attiva",
        inactive: "Inattiva"
    )

    static let ja = ShortcutSettingsStrings(
        active: "有効",
        inactive: "無効"
    )

    static let ko = ShortcutSettingsStrings(
        active: "활성",
        inactive: "비활성"
    )

    static let zhHans = ShortcutSettingsStrings(
        active: "已启用",
        inactive: "未启用"
    )

    static let zhTW = ShortcutSettingsStrings(
        active: "已啟用",
        inactive: "未啟用"
    )

    static let zhHK = ShortcutSettingsStrings(
        active: "已啟用",
        inactive: "未啟用"
    )
    static let uk = ShortcutSettingsStrings(
        active: "Активно",
        inactive: "Неактивно"
    )
}
