// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Botão de ejeção de um volume, com estados ejetando, pronto e falhou. Usado no
/// seletor de discos do painel de Discos e na lista do painel rápido.
struct DiskSelectorEjectButton: View {
    let state: DiskEjectState?
    let idleHelp: String
    let busyHelp: String
    let readyHelp: String
    let failedHelp: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            if busy {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.55)
            } else {
                HexaIcons.image(iconName, size: HexaIconMetrics.small)
                    .font(.hexa(.micro))
            }
        }
        .buttonStyle(HexaIconButtonStyle(variant: .small, iconTint: tint))
        .disabled(busy)
        .help(help)
        .accessibilityLabel(help)
        .onHover { hovering = $0 }
    }

    private var iconName: String {
        state == .ready ? "checkmark" : "eject.fill"
    }

    private var tint: Color? {
        switch state {
        case .ejecting:
            return nil
        case .ready:
            return HexaTheme.statusOk
        case .failed:
            return HexaTheme.statusDanger
        case .none:
            return hovering ? HexaTheme.fgPrimary : HexaTheme.fgSecondary
        }
    }

    private var busy: Bool {
        state == .ejecting
    }

    private var help: String {
        switch state {
        case .ejecting: return busyHelp
        case .ready: return readyHelp
        case .failed: return failedHelp
        case .none: return idleHelp
        }
    }
}
