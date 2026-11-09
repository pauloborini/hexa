// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Linha de leitura label + valor (par de leitura com valor à direita).
/// Anatomia canônica: HStack com `Spacing.s`, label em `body` (`fgSecondary`),
/// `Spacer(minLength: Spacing.s)` e valor em `data` (`fgPrimary`) alinhado à
/// direita; valor `nil` omite só o `Text` (leitura ainda indisponível) e mantém
/// o label. Slot `trailing` opcional para controle inline (ex.: ocultar item).
/// Ícones, legendas, animação de valor e a condição de exibição da linha
/// inteira ficam no call site.
struct HexaKeyValueRow<Trailing: View>: View {
    private let label: String
    private let value: String?
    private let trailing: Trailing

    init(label: String, value: String?) where Trailing == EmptyView {
        self.init(label: label, value: value, trailing: { EmptyView() })
    }

    init(label: String, value: String?, @ViewBuilder trailing: () -> Trailing) {
        self.label = label
        self.value = value
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            Text(label)
                .font(.hexa(.body))
                .foregroundStyle(HexaTheme.fgSecondary)
            Spacer(minLength: HexaTheme.Spacing.s)
            if let value {
                Text(value)
                    .font(.hexa(.data))
                    .foregroundStyle(HexaTheme.fgPrimary)
            }
            trailing
        }
    }
}
