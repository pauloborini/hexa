// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Cartão arquitetônico canônico da menu bar (ARCH-05, DEC-011, DEC-017).
/// Encapsula a apresentação visual padronizada de cartões e blocos da menu bar:
/// no painel, o MESMO desenho do cartão único (`HexaCard`, spec §7) — fundo
/// `HexaTheme.surfaceRaised`, raio 10 (`HexaTheme.Radius.panel`), respiro 16 e
/// SEM contorno (hairline só com "Aumentar contraste"); no notch, a superfície
/// de controle própria da ilha (`NotchControlSurface`).
struct HexaSectionCard<Content: View>: View {
    var padded: Bool = true
    var interactive: Bool = true
    @ViewBuilder let content: () -> Content

    init(padded: Bool = true, interactive: Bool = true, @ViewBuilder content: @escaping () -> Content) {
        self.padded = padded
        self.interactive = interactive
        self.content = content
    }

    var body: some View {
        content()
            .modifier(HexaSectionCardModifier(padded: padded, interactive: interactive))
    }
}

/// Modifier do cartão canônico da menu bar (ARCH-05).
struct HexaSectionCardModifier: ViewModifier {
    var padded: Bool = true
    var interactive: Bool = true
    @Environment(\.notchPresentation) private var notchPresentation

    func body(content: Content) -> some View {
        if notchPresentation {
            content
                .padding(padded ? HexaTheme.Spacing.m : 0)
                .modifier(NotchControlSurface(cornerRadius: HexaTheme.Radius.notch, interactive: interactive))
        } else {
            // O mesmo desenho do cartão único (HexaCard, spec §7): sem
            // contorno; hairline só com "Aumentar contraste". Respiro 16,
            // raio de painel 10.
            content
                .padding(padded ? HexaTheme.Spacing.l : 0)
                .hexaCardSurface(
                    increaseContrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
                )
        }
    }
}

extension View {
    /// Aplica o estilo de cartão arquitetônico canônico do Hexa (ARCH-05).
    func hexaSectionCard(padded: Bool = true, interactive: Bool = true) -> some View {
        modifier(HexaSectionCardModifier(padded: padded, interactive: interactive))
    }
}
