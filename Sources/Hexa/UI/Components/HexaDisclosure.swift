// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Disclosure/acordeão animado (spec §7): o chevron rotaciona JUNTO com a
/// expansão (transição sutil easeInOut de 0.2s) e a altura anima de forma contínua, sem pulo
/// seco nem bounce. Respeita "reduce motion" (troca por transição instantânea).
struct HexaDisclosure<Content: View, Label: View>: View {
    @ObservedObject private var l10n = L10n.shared
    @Binding private var isExpanded: Bool
    private let indentsContent: Bool
    private let label: () -> Label
    private let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var headerFocus: Bool

    /// `indentsContent: false` serves a header that sits outside its card, when
    /// the card must share the left edge of its neighbours.
    init(isExpanded: Binding<Bool>,
         indentsContent: Bool = true,
         @ViewBuilder label: @escaping () -> Label,
         @ViewBuilder content: @escaping () -> Content) {
        _isExpanded = isExpanded
        self.indentsContent = indentsContent
        self.label = label
        self.content = content
    }

    private var toggleAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(toggleAnimation) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: HexaTheme.Spacing.s) {
                    label()
                    Spacer(minLength: 0)
                    HexaIcons.image("chevron.right", size: 11)
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, HexaTheme.Spacing.s)
                .frame(height: HexaTheme.Density.rowCompact)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                        .fill(Color.clear)
                )
                .overlay {
                    if headerFocus {
                        RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                            .strokeBorder(HexaTheme.focusRing, lineWidth: 2)
                            .padding(1)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focused($headerFocus)
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(isExpanded ? l10n.s.disclosureExpanded : l10n.s.disclosureCollapsed)

            if isExpanded {
                content()
                    .disclosureIndent(indentsContent)
                    .padding(.top, HexaTheme.Spacing.s)
                    .transition(reduceMotion ? .identity : .opacity)
            }
        }
    }
}
