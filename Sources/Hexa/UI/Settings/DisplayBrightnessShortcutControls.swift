// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

struct DisplayBrightnessShortcutControls: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var brightness = BrightnessService.shared
    @AppStorage(DefaultsKey.displayBrightnessShortcutsEnabled) private var enabled = false
    var showsShortcutRows = true
    var showsSettingsRow = false

    var body: some View {
        let strings = FeatureStrings.brightness(l10n.language)
        Group {
            if showsSettingsRow {
                SettingsRow(symbol: "keyboard", title: strings.displayBrightnessShortcuts,
                            caption: strings.displayBrightnessShortcutCaption) {
                    Toggle(strings.displayBrightnessShortcuts, isOn: $enabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            } else {
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                    HStack(spacing: HexaTheme.Spacing.s) {
                        HexaIcons.image("keyboard", size: 11)
                            .font(.hexa(.label))
                            .foregroundStyle(HexaTheme.fgSecondary)
                            .frame(width: 15)
                        Text(strings.displayBrightnessShortcuts)
                            .font(.hexa(.label))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Toggle(strings.displayBrightnessShortcuts, isOn: $enabled)
                            .toggleStyle(HexaSwitchStyle())
                            .labelsHidden()
                    }
                    Text(strings.displayBrightnessShortcutCaption)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, HexaTheme.Spacing.xl)
                }
            }
        }
        .onChange(of: enabled) { _, _ in brightness.syncWithPreferences() }
        if showsShortcutRows, enabled {
            ForEach([GlobalShortcutRole.displayBrightnessDecrease, .displayBrightnessIncrease]) { role in
                ShortcutPreferenceRow(role: role, isEnabled: enabled, label: role.title(l10n.s)) {
                    brightness.syncWithPreferences()
                }
                .padding(.leading, showsSettingsRow ? settingsRowTextInset : 0)
            }
        }
        if enabled, brightness.displayBrightnessShortcutRegistrationFailed {
            Text(l10n.s.shortcutUnavailable)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.statusDanger)
                .padding(.leading, showsSettingsRow ? settingsRowTextInset : 0)
        }
    }
}
