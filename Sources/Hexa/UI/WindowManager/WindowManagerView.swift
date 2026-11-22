// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Main unified view for the Window Manager module (`DEC-014`, `DEC-017`).
/// Switches seamlessly between Operation (interactive layout grid) and Settings
/// inside Hexa's single operational window.
struct WindowManagerView: View {
    let settingsMode: Bool

    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = WindowManagerService.shared
    @ObservedObject private var permissions = Permissions.shared

    private var text: WindowManagerStrings { FeatureStrings.windowManager(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.l) {
            if settingsMode {
                WindowManagerSettingsView()
            } else {
                operationView
            }
        }
        .padding(.horizontal, HexaTheme.Spacing.xxl)
        .onAppear {
            service.syncWithPreferences()
        }
    }

    private var operationView: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.l) {
            if !permissions.accessibility {
                HexaSection(l10n.s.permissionAccessibility) {
                    Text(text.needsAccessibility)
                        .hexaCaption()
                    HStack(spacing: HexaTheme.Spacing.s) {
                        HexaAccessButton(icon: "accessibility", title: l10n.s.permissionRequest) {
                            permissions.requestAccessibility()
                        }
                        HexaAccessButton(icon: "gearshape", title: FeatureStrings.hub(l10n.language).openSystemSettings) {
                            permissions.openAccessibilitySettings()
                        }
                    }
                }
            }

            if let statusMessage {
                HexaCard {
                    HexaStatusNote(message: statusMessage, tone: statusIsWarning ? .warning : .neutral)
                }
            }

            WindowLayoutGridVisualizer()
        }
    }

    private var statusMessage: String? {
        guard let outcome = service.lastOutcome else { return nil }
        switch outcome {
        case .applied(let action):
            return String(format: text.statusAppliedFormat, text.actionTitle(action))
        case .restored:
            return text.statusRestored
        case .missingAccessibility:
            return text.needsAccessibility
        case .noWindow:
            return text.statusNoWindow
        case .noRestoreHistory:
            return text.statusNoRestore
        case .failed:
            return text.statusFailed
        }
    }

    private var statusIsWarning: Bool {
        switch service.lastOutcome {
        case .missingAccessibility, .noWindow, .noRestoreHistory, .failed:
            return true
        case .applied, .restored, .none:
            return false
        }
    }
}
