// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Métricas canônicas do contêiner da menu bar (ARCH-01, spec §4).
/// Painel horizontal (Fase 2 do redesign): rail de domínios à esquerda,
/// conteúdo à direita, e dimensões ESTÁVEIS — a altura não varia com o
/// conteúdo (o conteúdo rola), então o popover nunca se reposiciona ao
/// trocar de domínio ou expandir opções.
enum HexaPanelMetrics {
    /// Largura total da janela do painel.
    static let panelWidth: CGFloat = 560
    /// Altura total do painel, antes do teto da tela (aplicado em MenuPanelView).
    static let panelHeight: CGFloat = 420
    /// Largura do rail vertical de domínios.
    static let railWidth: CGFloat = 148
    /// Largura do conteúdo do domínio (rail + respiros laterais deduzidos).
    static let contentWidth: CGFloat = panelWidth - railWidth - 2 * HexaTheme.Spacing.m
    /// Reserva vertical do header (lockup da marca centralizado).
    static let headerHeight: CGFloat = 52
    /// Marca do header (PanelHeader, spec §7): 28 px, wordmark 24.
    static let headerBrandSize: CGFloat = 28
    static let headerWordmarkSize: CGFloat = 24
    /// Padding padronizado em torno do conteúdo.
    static let padding: CGFloat = HexaTheme.Spacing.m
}

/// Casca estrutural unificada do painel da menu bar (ARCH-01).
/// Anatomia horizontal: banner opcional, header com a marca centralizada,
/// corpo com rail de domínios à esquerda e conteúdo rolável à direita, e
/// rodapé. A área de corpo é flexível: o banner aparece encolhendo o corpo,
/// nunca mudando as dimensões do painel. O fundo de vidro NÃO é pintado aqui:
/// a superfície cobre o popover inteiro e é aplicada na raiz do conteúdo
/// (MenuPanelView), onde a safe area do balão está no escopo.
/// Só é usado pelo layout de rail de `MenuPanelView` (`navigablePanel` e `metricPanel`), inalcançável no grafo de chamadas atual.
struct HexaPanelContainer<Banner: View, Rail: View, Header: View, Content: View, Footer: View>: View {
    let height: CGFloat
    let banner: Banner
    let rail: Rail
    let header: Header
    let content: Content
    let footer: Footer

    init(
        height: CGFloat,
        @ViewBuilder banner: () -> Banner,
        @ViewBuilder rail: () -> Rail,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.height = height
        self.banner = banner()
        self.rail = rail()
        self.header = header()
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(spacing: 0) {
            banner
            header
            HStack(alignment: .top, spacing: 0) {
                rail
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            footer
        }
        .frame(width: HexaPanelMetrics.panelWidth, height: height)
    }
}

extension HexaPanelContainer where Banner == EmptyView {
    init(
        height: CGFloat,
        @ViewBuilder rail: () -> Rail,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.init(
            height: height,
            banner: { EmptyView() },
            rail: rail,
            header: header,
            content: content,
            footer: footer
        )
    }
}

extension HexaPanelContainer where Footer == HexaPanelFooter {
    init(
        height: CGFloat,
        @ViewBuilder banner: () -> Banner,
        @ViewBuilder rail: () -> Rail,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            height: height,
            banner: banner,
            rail: rail,
            header: header,
            content: content,
            footer: { HexaPanelFooter() }
        )
    }
}

extension HexaPanelContainer where Banner == EmptyView, Footer == HexaPanelFooter {
    init(
        height: CGFloat,
        @ViewBuilder rail: () -> Rail,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            height: height,
            banner: { EmptyView() },
            rail: rail,
            header: header,
            content: content,
            footer: { HexaPanelFooter() }
        )
    }
}
