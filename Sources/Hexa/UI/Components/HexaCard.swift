// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// O cartão único do hexa (spec §7): fundo `surface.raised`, raio de painel
/// (10), respiro de seção (16), SEM contorno. Toda tela que desenha um cartão
/// usa este componente. O título da seção NUNCA vive dentro do cartão: componha
/// com `HexaSection`, que põe o rótulo em cima. Exceção funcional: com
/// "Aumentar contraste" do macOS a hairline volta (acessibilidade, spec §7).
struct HexaCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.m) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(HexaTheme.Spacing.l)
        .hexaCardSurface(
            increaseContrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        )
        .font(.hexa(.body))
    }
}

/// Seção padrão de página (spec §7): rótulo de seção (micro caixa-alta) FORA
/// do cartão, com respiro 8 até ele. O padrão da tela de Telas.
struct HexaSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            SectionLabel(title: title)
            HexaCard(content: content)
        }
    }
}

extension View {
    /// O desenho do cartão único (spec §7): fundo raised, raio de painel e
    /// hairline apenas com "Aumentar contraste". Compartilhado pelo componente
    /// de página (`HexaCard`) e pelo modifier canônico do painel.
    func hexaCardSurface(increaseContrast: Bool) -> some View {
        background(
            RoundedRectangle(cornerRadius: HexaTheme.Radius.panel, style: .continuous)
                .fill(HexaTheme.surfaceRaised)
        )
        .overlay {
            if increaseContrast {
                RoundedRectangle(cornerRadius: HexaTheme.Radius.panel, style: .continuous)
                    .strokeBorder(HexaTheme.borderHairline, lineWidth: HexaTheme.hairline)
            }
        }
    }
}
