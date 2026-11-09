// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Linha da sidebar única (spec §7). Hover: SÓ o texto clareia — sem fill,
/// sem crescimento. Seleção: `selection.bg` + `fg.primary` + dot. Foco: anel
/// `focus.ring`, dirigido pelo dono da lista (que também aplica `.focused`).
struct HexaSidebarRow: View {
    let title: String
    let selected: Bool
    var isFocused: Bool = false
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: HexaTheme.Spacing.s) {
                Text(title)
                    .font(.hexa(.body))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: HexaTheme.Spacing.xs)
                if selected {
                    Circle()
                        .fill(HexaTheme.fgPrimary)
                        .frame(width: 5, height: 5)
                }
            }
            .foregroundStyle(selected || isHovered ? HexaTheme.fgPrimary : HexaTheme.fgSecondary)
            .padding(.horizontal, HexaTheme.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: HexaTheme.Density.rowSidebar)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                        .fill(HexaTheme.selectionBg)
                }
            }
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                        .strokeBorder(HexaTheme.focusRing, lineWidth: 2)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Campo de busca da sidebar única (spec §7): lupa, Esc limpa e botão de
/// limpar quando há texto. O foco é do consumidor, que dirige os atalhos
/// de teclado da busca da sidebar.
struct HexaSidebarSearchField: View {
    @ObservedObject private var l10n = L10n.shared
    @Binding var query: String
    var isFocused: FocusState<Bool>.Binding? = nil
    var placeholder: String = ""

    var body: some View {
        HStack(spacing: HexaTheme.Spacing.xs) {
            HexaIcons.image("magnifyingglass")
                .foregroundStyle(HexaTheme.fgSecondary)
            if let isFocused {
                field.focused(isFocused)
            } else {
                field
            }
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    HexaIcons.image("xmark.circle.fill")
                        .foregroundStyle(HexaTheme.fgSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(l10n.s.urlCleanerClearButton)
            }
        }
        .padding(.vertical, HexaTheme.Spacing.xs)
        .padding(.horizontal, HexaTheme.Spacing.s)
        .background(HexaTheme.surfaceInset, in: RoundedRectangle(cornerRadius: HexaTheme.Radius.control))
        .padding(.horizontal, HexaTheme.Spacing.s)
        .padding(.top, HexaTheme.Spacing.xs)
        .padding(.bottom, HexaTheme.Spacing.xs)
    }

    private var field: some View {
        TextField(placeholder, text: $query)
            .textFieldStyle(.plain)
            .font(.hexa(.body))
            .onExitCommand { query = "" }
    }
}
