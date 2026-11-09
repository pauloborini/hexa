// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Rodapé de resultados (spec §7): metadados de seleção à esquerda, ação
/// secundária opcional (reset/cancelar, botão plain) e ação primária à direita
/// (`HexaActionButtonStyle`). O texto dos botões, a formatação da contagem e a
/// condição de desabilitar ficam no call site; o primitive cuida só do
/// esqueleto. A divisória acima do rodapé é do contêiner (`HairlineDivider`).
struct HexaResultsFooter<Metadata: View>: View {
    private let secondaryTitle: String?
    private let secondaryAction: (() -> Void)?
    private let secondaryDisabled: Bool
    private let primaryTitle: String
    private let primaryAction: () -> Void
    private let primaryDisabled: Bool
    private let primaryControlSize: ControlSize
    private let contentPadding: CGFloat
    private let metadata: Metadata

    init(contentPadding: CGFloat = HexaTheme.Spacing.l,
         secondaryTitle: String? = nil,
         secondaryAction: (() -> Void)? = nil,
         secondaryDisabled: Bool = false,
         primaryTitle: String,
         primaryAction: @escaping () -> Void,
         primaryDisabled: Bool = false,
         primaryControlSize: ControlSize = .regular,
         @ViewBuilder metadata: () -> Metadata) {
        self.contentPadding = contentPadding
        self.secondaryTitle = secondaryTitle
        self.secondaryAction = secondaryAction
        self.secondaryDisabled = secondaryDisabled
        self.primaryTitle = primaryTitle
        self.primaryAction = primaryAction
        self.primaryDisabled = primaryDisabled
        self.primaryControlSize = primaryControlSize
        self.metadata = metadata()
    }

    var body: some View {
        HStack {
            metadata
            Spacer()
            if let secondaryTitle, let secondaryAction {
                Button(secondaryTitle, action: secondaryAction)
                    .disabled(secondaryDisabled)
            }
            Button(primaryTitle, action: primaryAction)
                .buttonStyle(HexaActionButtonStyle())
                .controlSize(primaryControlSize)
                .disabled(primaryDisabled)
        }
        .padding(contentPadding)
    }
}
