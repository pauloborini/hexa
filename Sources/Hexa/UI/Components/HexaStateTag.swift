// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Etiqueta compacta: contorno e texto neutros, forma identifica estado.
/// Apenas sessão Manter acordado recebe o laranja fixo aprovado.
struct HexaStateTag: View {
    enum Kind {
        case neutral, ok, warning, danger, awake

        var color: Color {
            switch self {
            case .awake: HexaTheme.awakeActive
            default: HexaTheme.fgSecondary
            }
        }
    }

    private let kind: Kind
    private let text: String

    init(_ text: String, kind: Kind = .neutral) {
        self.text = text
        self.kind = kind
    }

    var body: some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            if kind == .ok || kind == .warning || kind == .danger {
                HexaIcons.image(kind == .ok ? "checkmark" : (kind == .warning ? "exclamationmark" : "xmark"), size: 11)
                    .font(.hexa(.label)).foregroundStyle(kind.color)
            } else {
                Circle().fill(kind.color).frame(width: HexaTheme.Spacing.xs, height: HexaTheme.Spacing.xs)
            }
            Text(text)
                .font(.hexa(.label))
                .lineLimit(1)
                .foregroundStyle(HexaTheme.fgSecondary)
        }
        .padding(.horizontal, HexaTheme.Spacing.s)
        .frame(height: HexaTheme.Density.rowCompact)
        .background(
            RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                .strokeBorder(HexaTheme.borderHairline, lineWidth: HexaTheme.hairline)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(text))
    }
}
