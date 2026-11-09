// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import AppKit
import SwiftUI

/// Rodapé padronizado e acessível do painel da menu bar (ARCH-04).
struct HexaPanelFooter: View {
    var isEmbeddedInNotch: Bool = false
    @Environment(\.notchPresentation) private var notchPresentation
    @ObservedObject private var l10n = L10n.shared
    @FocusState private var focusedAction: FooterAction?

    private enum FooterAction: Hashable {
        case settings
        case quit
    }

    private var isInNotch: Bool {
        isEmbeddedInNotch || notchPresentation
    }

    var body: some View {
        VStack(spacing: HexaTheme.Spacing.s) {
            // Divisor full width: atravessa o inset (spec §7); o respiro
            // lateral fica nos botões, não nele.
            HairlineDivider()
            HStack(spacing: HexaTheme.Spacing.s) {
                footerButton(
                    l10n.s.panelSettings,
                    systemImage: "gearshape",
                    actionType: .settings
                ) {
                    if let page = PanelInteractionState.shared.hostedSettingsPage,
                       let feature = FeatureVisibilitySupport.features(for: page).first,
                       feature.isAvailable {
                        SettingsRouter.shared.page = page
                        FeatureWorkspaceWindow.shared.show(feature)
                    } else {
                        SettingsRouter.shared.page = .general
                        appDelegate()?.openFeatureWorkspace(.general)
                    }
                }

                footerButton(
                    l10n.s.panelQuit,
                    systemImage: "power",
                    actionType: .quit
                ) {
                    NSApp.terminate(nil)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            // Inset do shell do painel (o shell antigo cobria com o padding
            // do contêiner). No notch o host já aplica o inset próprio
            // (NotchLayout), então sem margem dupla aqui.
            .padding(.horizontal, isInNotch ? 0 : HexaPanelMetrics.padding)
        }
        .padding(.bottom, isInNotch ? 0 : HexaTheme.Spacing.m)
    }

    private func footerButton(
        _ title: String,
        systemImage: String,
        actionType: FooterAction,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, hexaIcon: systemImage)
                .font(.hexa(.label))
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.78)
                .labelStyle(.titleAndIcon)
                .frame(maxWidth: .infinity)
        }
        // Estilo canônico de ação (spec §7): hover e anel de foco são do
        // próprio estilo; .small mantém a linha do rodapé em 28 pt.
        .buttonStyle(HexaActionButtonStyle())
        .controlSize(.small)
        .focused($focusedAction, equals: actionType)
    }
}
