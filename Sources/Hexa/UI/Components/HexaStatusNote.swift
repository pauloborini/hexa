// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Nota inline de status (spec §7): bloco de texto curto que sinaliza um
/// estado ao operador, com fonte `label` e cor do tom semântico. Sem ícone,
/// ou com ícone semântico opcional (`Label` + `hexaIcon`). A condição de
/// exibição fica no call site; o componente renderiza só o bloco, com quebra
/// de linha vertical livre. Modificadores de recorte (limite de linhas,
/// padding, cartão) pertencem ao consumidor.
struct HexaStatusNote: View {
    /// Tons observados nos consumidores reais: aviso (`statusWarning`) e
    /// neutro (`fgSecondary`).
    enum Tone {
        case warning
        case neutral

        fileprivate var color: Color {
            switch self {
            case .warning: return HexaTheme.statusWarning
            case .neutral: return HexaTheme.fgSecondary
            }
        }
    }

    let message: String
    var icon: String?
    var tone: Tone = .warning

    var body: some View {
        if let icon {
            Label(message, hexaIcon: icon)
                .font(.hexa(.label))
                .foregroundStyle(tone.color)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(message)
                .font(.hexa(.label))
                .foregroundStyle(tone.color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
