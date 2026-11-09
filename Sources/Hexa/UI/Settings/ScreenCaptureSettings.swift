// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Settings for Screen OCR (Copy text from screen).
struct ScreenTextCaptureSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var service = ScreenCaptureService.shared
    @AppStorage(DefaultsKey.screenOCRShortcutEnabled) private var shortcutEnabled = false
    @AppStorage(DefaultsKey.screenOCRShowCaptureMenuOnShortcut) private var showCaptureMenu = true
    @AppStorage(DefaultsKey.screenOCRRemoveLineBreaks) private var removesLineBreaks = false
    @AppStorage(DefaultsKey.screenOCRDetectQRCodes) private var detectsQRCodes = true
    let embedded: Bool

    init(embedded: Bool = false) {
        self.embedded = embedded
    }

    private var strings: ScreenshotFeatureStrings {
        FeatureStrings.screenshot(l10n.language)
    }

    var body: some View {
        Group {
            if embedded {
                content
            } else {
                HexaScreenScaffold(title: l10n.s.ocrName, scrolls: false) {
                    content
                }
            }
        }
    }

    private var content: some View {
        OverlayScrollView {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.l) {
                HexaSection(strings.ocrShortcutSection) {
                    Toggle(strings.ocrShortcutLabel, isOn: $shortcutEnabled)
                        .toggleStyle(TrailingSwitchToggleStyle())
                        .onChange(of: shortcutEnabled) { _, _ in
                            service.syncWithPreferences()
                        }
                    ShortcutPreferenceRow(role: .screenOCR, isEnabled: shortcutEnabled) {
                        service.syncWithPreferences()
                    }
                    Toggle(l10n.s.ocrShowMenuOnShortcut,
                           isOn: $showCaptureMenu)
                        .toggleStyle(TrailingSwitchToggleStyle())
                        .disabled(!shortcutEnabled)
                    if shortcutEnabled, service.toolShortcutRegistrationFailures.contains(.text) {
                        HexaStatusNote(message: l10n.s.shortcutUnavailable)
                    }
                    if !permissions.screenRecording {
                        PermissionRow(kind: .screenRecording)
                    }
                }
                .settingsSectionAnchor(.screenOCR, cornerRadius: HexaTheme.Radius.panel)

                HexaSection(l10n.s.ocrTextRecognitionSection) {
                    VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                        Toggle(l10n.s.ocrRemoveLineBreaksToggle, isOn: $removesLineBreaks)
                            .toggleStyle(TrailingSwitchToggleStyle())
                        Text(l10n.s.ocrRemoveLineBreaksCaption)
                            .font(.hexa(.label))
                            .foregroundStyle(HexaTheme.fgSecondary)
                    }
                    VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                        Toggle(l10n.s.ocrQRToggle, isOn: $detectsQRCodes)
                            .toggleStyle(TrailingSwitchToggleStyle())
                        Text(l10n.s.ocrQRCaption)
                            .font(.hexa(.label))
                            .foregroundStyle(HexaTheme.fgSecondary)
                    }
                }
            }
            .padding(.horizontal, HexaTheme.Spacing.xxl)
            .padding(.bottom, HexaTheme.Spacing.pageGap)
        }
    }
}

/// Backward compatibility wrapper redirecting to ScreenshotCaptureSettings.
struct ScreenCaptureSettings: View {
    let embedded: Bool

    init(embedded: Bool = false) {
        self.embedded = embedded
    }

    var body: some View {
        ScreenshotCaptureSettings(embedded: embedded)
    }
}
