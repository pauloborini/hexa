// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Ação neutra compartilhada entre painel, Ajustes e cartão de permissão (spec §7).
/// `.secondary` (padrão): fundo inset em repouso. `.primary`: a ação de maior
/// peso da superfície, fundo `selection.bg` (12.46:1 com fg.primary, spec §6).
/// Feedback de hover e clique estritamente local e isolado.
struct HexaActionButtonStyle: ButtonStyle {
    enum Variant { case primary, secondary }
    var variant: Variant = .secondary
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
    @Environment(\.controlSize) private var controlSize

    func makeBody(configuration: Configuration) -> some View {
        HexaActionButtonBody(configuration: configuration,
                             isEnabled: isEnabled,
                             isFocused: isFocused,
                             controlSize: controlSize,
                             variant: variant)
    }

    private struct HexaActionButtonBody: View {
        let configuration: Configuration
        let isEnabled: Bool
        let isFocused: Bool
        let controlSize: ControlSize
        let variant: Variant
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .font(.hexa(.label))
                .foregroundStyle(isEnabled ? HexaTheme.fgPrimary : HexaTheme.fgDisabled)
                .padding(.horizontal, HexaTheme.Spacing.m)
                .frame(minHeight: controlSize == .mini || controlSize == .small
                    ? HexaTheme.Density.rowCompact : HexaTheme.Density.rowStandard)
                .background {
                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                        .fill(isEnabled ? fill : HexaTheme.surfaceInset.opacity(0.5))
                }
                .overlay {
                    if isFocused && isEnabled {
                        RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                            .strokeBorder(HexaTheme.focusRing, lineWidth: 2)
                            .padding(1)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.control))
                .onHover { isHovered = $0 }
        }

        private var fill: Color {
            if variant == .primary {
                if configuration.isPressed { return HexaTheme.selectionBg.opacity(0.8) }
                return HexaTheme.selectionBg
            }
            if configuration.isPressed { return HexaTheme.selectionBg }
            if isHovered { return HexaTheme.selectionBg.opacity(0.7) }
            return HexaTheme.surfaceInset
        }
    }
}
