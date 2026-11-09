// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import SwiftUI

struct PanelAppUpdatesView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var updates = AppUpdatesService.shared

    var onClose: () -> Void

    private var text: AppUpdateStrings { FeatureStrings.appUpdates(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            header
            AppUpdatesListView(compact: true)
                .panelCard()
        }
        .onAppear {
            PanelInteractionState.shared.viewKeepsPopoverOpen = true
            // The panel is the fast way in, so it arrives with an answer
            // instead of an empty list waiting for a click.
            updates.checkIfNeeded()
        }
        .onDisappear { PanelInteractionState.shared.viewKeepsPopoverOpen = false }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        HexaPanelHeader(title: text.pageTitle, icon: "arrow.down.app") {
            // The panel's own footer already has a plain Settings button, so
            // this one is an icon: same row, no second word saying Settings.
            HexaIconButton(icon: "gearshape",
                           label: l10n.s.menuSettings,
                           variant: .small) {
                SettingsRouter.shared.page = .appUpdates
                FeatureWorkspaceWindow.shared.show(.appUpdates)
                FeatureWorkspaceState.shared.featureSettingsMode = true
            }
            .help(l10n.s.menuSettings)
            HexaIconButton(icon: "xmark.circle.fill",
                           label: l10n.s.uninstallerCancel,
                           variant: .small,
                           action: onClose)
            .help(l10n.s.uninstallerCancel)
        }
    }
}
