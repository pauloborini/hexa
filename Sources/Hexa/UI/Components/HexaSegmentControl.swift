// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Segment control neutro (spec §7): seleção por `selection.bg` + `fg.primary`
/// + borda informativa `accent.solid` 1.5 (nunca só troca de cor de texto),
/// não-selecionado `fg.secondary`, desabilitado `fg.disabled`, foco por
/// teclado com anel `focus.ring`. Sem fill de accent nos segmentos.
struct HexaSegmentControl<Value: Hashable>: View {
    @Environment(\.isEnabled) private var isEnabled

    private let items: [(value: Value, title: String)]
    /// Valores desabilitados (permanecem visíveis em `fg.disabled`).
    private let disabled: Set<Value>
    @Binding private var selection: Value
    @FocusState private var keyboardFocus: Value?

    init(_ items: [(Value, String)],
         disabled: Set<Value> = [],
         selection: Binding<Value>) {
        self.items = items.map { (value: $0.0, title: $0.1) }
        self.disabled = disabled
        _selection = selection
    }

    var body: some View {
        HStack(spacing: HexaTheme.Spacing.xs) {
            ForEach(items, id: \.value) { item in
                segment(item)
            }
        }
        .padding(HexaTheme.Spacing.xs)
        .background(HexaTheme.surfaceInset, in: RoundedRectangle(cornerRadius: HexaTheme.Radius.control))
        .overlay { RoundedRectangle(cornerRadius: HexaTheme.Radius.control).strokeBorder(HexaTheme.borderHairline, lineWidth: HexaTheme.hairline) }
        .onMoveCommand { direction in
            // Rota por setas dentro do grupo (contrato spec §7).
            guard isEnabled, let current = keyboardFocus,
                  let currentIndex = items.firstIndex(where: { $0.value == current }) else { return }
            let delta = direction == .left ? -1 : (direction == .right ? 1 : 0)
            guard delta != 0 else { return }
            for distance in 1...items.count {
                let next = (currentIndex + delta * distance + items.count) % items.count
                let value = items[next].value
                if !disabled.contains(value) {
                    keyboardFocus = value
                    selection = value
                    return
                }
            }
        }
    }

    private func segment(_ item: (value: Value, title: String)) -> some View {
        let isSelected = selection == item.value
        let isDisabled = disabled.contains(item.value) || !isEnabled
        let hasFocus = keyboardFocus == item.value
        return Button {
            guard !isDisabled else { return }
            selection = item.value
        } label: {
            Text(item.title)
                .font(.hexa(.label))
                .lineLimit(1)
                .padding(.horizontal, HexaTheme.Spacing.m)
                .frame(height: HexaTheme.Density.rowCompact)
                .frame(maxWidth: .infinity)
                .foregroundStyle(isDisabled
                    ? HexaTheme.fgDisabled
                    : (isSelected ? HexaTheme.fgPrimary : HexaTheme.fgSecondary))
                .background(
                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                        .fill(isSelected && !isDisabled ? HexaTheme.selectionBg : Color.clear)
                )
                .overlay {
                    if hasFocus && !isDisabled {
                        RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                            .strokeBorder(HexaTheme.focusRing, lineWidth: 2)
                            .padding(1)
                    } else if isSelected && !isDisabled {
                        RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                            .strokeBorder(HexaTheme.accentSolid, lineWidth: 1.5)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .focused($keyboardFocus, equals: item.value)
        .help(item.title)
        .accessibilityAddTraits(isSelected && !isDisabled ? [.isSelected, .isButton] : .isButton)
    }
}

extension HexaSegmentControl where Value == Int {
    init(_ titles: [String],
         disabled: Set<Int> = [],
         selection: Binding<Int>) {
        self.init(titles.enumerated().map { ($0.offset, $0.element) },
                  disabled: disabled,
                  selection: selection)
    }
}
