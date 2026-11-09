// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import Foundation

/// Localized strings for process options and related process settings.
enum ProcessStrings {
    /// Section title for the process options card.
    static var optionsTitle: String {
        optionsTitle(for: L10n.shared.language)
    }

    /// Section title for the process options card for a given language.
    static func optionsTitle(for language: AppLanguage) -> String {
        switch language {
        case .enUS: return "Process Options"
        case .ptBR: return "Opções de processos"
        case .tr: return "İşlem Seçenekleri"
        case .ru: return "Параметры процессов"
        case .es: return "Opciones de procesos"
        case .sk: return "Možnosti procesov"
        case .de: return "Prozessoptionen"
        case .fr: return "Options des processus"
        case .it: return "Opzioni dei processi"
        case .ja: return "プロセス設定"
        case .ko: return "프로세스 옵션"
        case .zhHans: return "进程选项"
        case .zhTW: return "處理程序選項"
        case .zhHK: return "處理程序選項"
        case .uk: return "Параметри процесів"
        }
    }
}

extension KillProcessFeatureStrings {
    /// Section title for the process options card in Kill Process view.
    var optionsTitle: String {
        ProcessStrings.optionsTitle(for: L10n.shared.language)
    }
}
