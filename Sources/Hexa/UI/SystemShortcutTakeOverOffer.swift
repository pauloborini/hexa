// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// The two lines and the button the recorder shows instead of refusing a
/// combination macOS answers. The row decides what accepting does.
struct SystemShortcutTakeOverOffer: View {
    @ObservedObject private var l10n = L10n.shared
    let shortcut: GlobalShortcut
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            Text(String(format: l10n.s.shortcutTakeOverOffer, shortcut.displayString))
                .font(.hexa(.label))
            // The confirming action sits at the trailing end with the other
            // choice right beside it, the way a Mac dialog orders its buttons,
            // and the pair lines up under the shortcut field.
            HStack {
                Spacer()
                Button(l10n.s.shortcutTakeOverDismiss, action: onDismiss)
                    .buttonStyle(HexaActionButtonStyle())
                Button(l10n.s.shortcutTakeOverAction, action: onAccept)
                    .buttonStyle(HexaActionButtonStyle())
            }
            Text(l10n.s.shortcutTakeOverCaption)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
        }
    }
}
