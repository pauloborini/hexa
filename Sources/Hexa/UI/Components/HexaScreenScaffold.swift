// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Scaffold único das telas da coluna direita (spec §7): título e subtítulo
/// nos tokens da spec, área fixa opcional (ex.: segmento do Monitor) e o slot
/// de conteúdo. O espaçamento é do scaffold: `pageGap` (24pt) fixo entre o cabeçalho
/// e o body, sem padding cortando a borda inferior da tela. Com `scrolls` (padrão),
/// o scaffold é dono da rolagem do conteúdo e anexa `pageGap` (24pt) no fim do
/// conteúdo rolável para permitir overscroll sem margem permanente no rodapé.
/// Respiro lateral pertence ao conteúdo. Nenhuma tela da coluna direita se
/// implementa fora dele; só muda o que entra nos slots.
struct HexaScreenScaffold<Pinned: View, Trailing: View, Content: View>: View {
    let title: String?
    var subtitle: String?
    let trailing: (() -> Trailing)?
    let pinned: (() -> Pinned)?
    let scrolls: Bool
    @ViewBuilder let content: () -> Content

    /// Tela comum: título e subtítulo opcionais (nil não renderiza) e conteúdo.
    init(title: String? = nil,
         subtitle: String? = nil,
         scrolls: Bool = true,
         @ViewBuilder content: @escaping () -> Content) where Pinned == EmptyView, Trailing == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.trailing = nil
        self.pinned = nil
        self.scrolls = scrolls
        self.content = content
    }

    /// Tela com área fixa entre o subtítulo e o conteúdo rolável.
    init(title: String? = nil,
         subtitle: String? = nil,
         scrolls: Bool = true,
         @ViewBuilder pinned: @escaping () -> Pinned,
         @ViewBuilder content: @escaping () -> Content) where Trailing == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.trailing = nil
        self.pinned = pinned
        self.scrolls = scrolls
        self.content = content
    }

    /// Tela com ação no cabeçalho e área fixa.
    init(title: String? = nil,
         subtitle: String? = nil,
         scrolls: Bool = true,
         @ViewBuilder trailing: @escaping () -> Trailing,
         @ViewBuilder pinned: @escaping () -> Pinned,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
        self.pinned = pinned
        self.scrolls = scrolls
        self.content = content
    }

    /// Tela com ação no cabeçalho sem área fixa.
    init(title: String? = nil,
         subtitle: String? = nil,
         scrolls: Bool = true,
         @ViewBuilder trailing: @escaping () -> Trailing,
         @ViewBuilder content: @escaping () -> Content) where Pinned == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
        self.pinned = nil
        self.scrolls = scrolls
        self.content = content
    }

    private var hasHeader: Bool {
        title != nil || subtitle != nil || trailing != nil || pinned != nil
    }

    @ViewBuilder
    private var header: some View {
        if hasHeader {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.l) {
                if title != nil || subtitle != nil || trailing != nil {
                    VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                        HStack(alignment: .center) {
                            if let title {
                                Text(title)
                                    .font(.hexa(.featureTitle))
                                    .foregroundStyle(HexaTheme.fgPrimary)
                                    .accessibilityAddTraits(.isHeader)
                            }
                            if let trailing {
                                Spacer()
                                trailing()
                            }
                        }
                        if let subtitle {
                            Text(subtitle)
                                .font(.hexa(.featureSubtitle))
                                .foregroundStyle(HexaTheme.fgSecondary)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(minHeight: HexaTheme.Density.rowStandard, alignment: .topLeading)
                        }
                    }
                    .padding(.horizontal, HexaTheme.Spacing.xxl)
                }
                if let pinned {
                    pinned()
                        .padding(.horizontal, HexaTheme.Spacing.xxl)
                }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if hasHeader {
                header
                    .padding(.bottom, HexaTheme.Spacing.pageGap)
            }
            slot
                .frame(maxWidth: FeatureWorkspaceMetrics.scaffoldWidth, alignment: .topLeading)
                .clipped()
        }
        .padding(.top, FeatureWorkspaceMetrics.workspaceTopInset)
        .frame(width: FeatureWorkspaceMetrics.scaffoldWidth, alignment: .topLeading)
        .fixedSize(horizontal: true, vertical: false)
        .clipped()
        .font(.hexa(.body))
        .foregroundStyle(HexaTheme.fgPrimary)
    }

    @ViewBuilder
    private var slot: some View {
        if scrolls {
            OverlayScrollView {
                content()
                    .padding(.bottom, HexaTheme.Spacing.pageGap)
            }
        } else {
            content()
        }
    }
}
