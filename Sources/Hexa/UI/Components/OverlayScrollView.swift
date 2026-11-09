// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Container de rolagem vertical padrão do hexa (spec §7).
/// Implementado em SwiftUI nativo com scroll indicators automáticos do macOS,
/// eliminando conflitos de AutoLayout/NSHostingView no AppKit e garantindo
/// indicador nativo posicionado à direita em overlay, com margem curta
/// `Spacing.xs` na borda, suporte a ScrollViewReader e rolagem fluida em
/// todas as superfícies (scaffold, sidebar e painéis).
struct OverlayScrollView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView(.vertical) {
            content
        }
        .scrollIndicators(.automatic)
        .contentMargins(.all, CGFloat.zero, for: .scrollIndicators)
        .contentMargins(.trailing, HexaTheme.Spacing.xs, for: .scrollIndicators)
    }
}
