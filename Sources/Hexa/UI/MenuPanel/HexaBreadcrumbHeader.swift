// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Cabeçalho editorial com trilha de foco (breadcrumb) e botão de retorno (ARCH-03).
/// Substitui o header ad-hoc de métrica por uma navegação com tipografia editorial;
/// o botão de retorno é o primitive canônico de ícone (HexaIconButton, spec §7).
struct HexaBreadcrumbHeader: View {
    let trail: String
    let title: String
    let symbolName: String
    let onBack: () -> Void

    @ObservedObject private var l10n = L10n.shared

    init(
        trail: String,
        title: String,
        symbolName: String,
        onBack: @escaping () -> Void
    ) {
        self.trail = trail
        self.title = title
        self.symbolName = symbolName
        self.onBack = onBack
    }

    init(
        metric: MetricDetailKind,
        onBack: @escaping () -> Void
    ) {
        let s = L10n.shared.s
        let domain = metric.panelSection.domain
        self.trail = "\(domain.title(s)) / \(metric.title(s))"
        self.title = metric.title(s)
        self.symbolName = metric.symbolName
        self.onBack = onBack
    }

    var body: some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            HexaIconButton(icon: "chevron.left",
                           label: l10n.s.actionBack) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    onBack()
                }
            }
            .help(l10n.s.actionBack)

            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                Text(trail)
                    .hexaFont(.micro)
                    .foregroundStyle(HexaTheme.accentText)
                    .lineLimit(1)
                    .accessibilityHidden(true)

                HStack(spacing: HexaTheme.Spacing.xs) {
                    HexaIcons.image(symbolName, size: 13)
                        .font(.hexa(.body))
                    Text(title)
                        .font(.hexa(.body))
                        .lineLimit(1)
                }
                .foregroundStyle(HexaTheme.fgPrimary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
