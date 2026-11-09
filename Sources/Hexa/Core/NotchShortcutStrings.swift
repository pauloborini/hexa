// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

/// Nome do acesso aos excedentes da grade, nos 15 idiomas do app.
enum NotchShortcutStrings {
    static func all(_ language: AppLanguage) -> String {
        switch language {
        case .ptBR: return "Todos"
        case .enUS: return "All"
        case .tr: return "Tümü"
        case .ru: return "Все"
        case .es: return "Todos"
        case .sk: return "Všetky"
        case .de: return "Alle"
        case .fr: return "Tous"
        case .it: return "Tutti"
        case .ja: return "すべて"
        case .ko: return "모두"
        case .uk: return "Усі"
        case .zhHans: return "全部"
        case .zhTW, .zhHK: return "全部"
        }
    }
}
