// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import Foundation

/// The Dynamic Island page's sections. The workspace sidebar lists them, and
/// the page shows the one picked.
enum NotchSettingsTab: CaseIterable {
    case content, appearance, activity, behavior

    func title(_ language: AppLanguage) -> String {
        let editor = FeatureStrings.notchEditor(language)
        switch self {
        case .content: return editor.content
        case .appearance: return editor.appearance
        case .activity: return editor.activity
        case .behavior: return editor.behavior
        }
    }
}
