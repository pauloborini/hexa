// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Cabeçalho de painel embutido (spec §7): título com ícone semântico
/// (`Label` + `hexaIcon`, papel `body`) e slot de ações à direita, separado
/// por `Spacer`. Os botões continuam sendo primitivos do consumidor
/// (tipicamente `HexaIconButton` variante `small`, cada um com `.help()` e
/// estado próprio); o componente compõe, não reimplementa. Espaçamento
/// `Spacing.s` fixo; a condição de exibição de cada ação fica no call site.
struct HexaPanelHeader<Actions: View>: View {
    let title: String
    let icon: String
    private let actions: () -> Actions

    init(title: String, icon: String, @ViewBuilder actions: @escaping () -> Actions) {
        self.title = title
        self.icon = icon
        self.actions = actions
    }

    var body: some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            Label(title, hexaIcon: icon)
                .font(.hexa(.body))
            Spacer()
            actions()
        }
    }
}
