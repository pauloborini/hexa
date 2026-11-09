// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// One control of the island as a card. The whole card is the button: it
/// switches the control on or off, and the glyph on its corner says which
/// state it is in, so there is no second target repeating the same label.
struct NotchEditorItem: View {
    let symbol: String
    let title: String
    @Binding var included: Bool
    var selected = false
    var available = true
    var unavailableReason: String? = nil
    var unavailableAction: (() -> Void)? = nil
    let select: () -> Void
    @ObservedObject private var l10n = L10n.shared
    private var experience: NotchExperienceStrings { FeatureStrings.notchExperience(l10n.language) }

    var body: some View {
        Button {
            if available { select() } else { unavailableAction?() }
        } label: {
            VStack(spacing: HexaTheme.Spacing.xs) {
                HexaIcons.image(symbol, size: 20)
                    .foregroundStyle(included && available ? HexaTheme.fgPrimary : HexaTheme.fgSecondary)
                // A fixed two-line title area keeps the icons of a row level.
                Text(title).font(.hexa(.label)).lineLimit(2)
                    .multilineTextAlignment(.center).frame(height: 28, alignment: .top)
                if let unavailableReason {
                    // One line; the full reason is also in the tooltip.
                    Text(unavailableReason).font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .lineLimit(1)
                }
            }.frame(maxWidth: .infinity)
                .padding(.horizontal, HexaTheme.Spacing.s)
                .padding(.vertical, HexaTheme.Spacing.s)
                .background(selected ? HexaTheme.selectionBg : HexaTheme.surfaceInset, in: RoundedRectangle(cornerRadius: HexaTheme.Radius.panel))
                .overlay { RoundedRectangle(cornerRadius: HexaTheme.Radius.panel).strokeBorder(selected ? HexaTheme.accentSolid : .clear, lineWidth: 1) }
                .overlay(alignment: .topTrailing) {
                    HexaIcons.image(stateGlyph, size: 12)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .padding(HexaTheme.Spacing.s)
                }
        }
        .buttonStyle(.plain)
        .disabled(!available && unavailableAction == nil)
        .accessibilityAddTraits(included && available ? .isSelected : [])
        .accessibilityValue(included ? experience.included : experience.notIncluded)
        .help(helpText)
    }

    private var stateGlyph: String {
        guard available else {
            return unavailableAction == nil ? "minus.circle" : "arrow.up.right.circle"
        }
        return included ? "checkmark.circle.fill" : "plus.circle"
    }

    private var helpText: String {
        unavailableReason ?? title
    }
}
