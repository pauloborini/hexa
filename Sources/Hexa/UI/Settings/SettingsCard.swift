// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Where a row's text column starts, so follow-up controls can line up with it.
let settingsRowTextInset: CGFloat = 26 + 12

/// Icon, title, one line of explanation and the control on the right. A nil
/// symbol shows the app's own menu bar glyph, for rows about that icon.
struct SettingsRow<Accessory: View>: View {
    let symbol: String?
    let title: String
    let badge: String?
    let caption: String?
    let accessory: Accessory

    init(symbol: String?, title: String, badge: String? = nil, caption: String? = nil,
         @ViewBuilder accessory: () -> Accessory) {
        self.symbol = symbol
        self.title = title
        self.badge = badge
        self.caption = caption
        self.accessory = accessory()
    }

    var body: some View {
        HStack(spacing: HexaTheme.Spacing.m) {
            iconTile
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                HStack(spacing: HexaTheme.Spacing.xs) {
                    Text(title)
                        .font(.hexa(.body))
                    if let badge {
                        // Etiqueta de estado: dot colorido + texto neutro
                        // (HexaStateTag, spec §7); nunca accent nem azul.
                        HexaStateTag(badge, kind: .warning)
                            .accessibilityHidden(true)
                    }
                }
                if let caption {
                    Text(caption)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: HexaTheme.Spacing.m)
            accessory
        }
    }

    @ViewBuilder
    private var iconTile: some View {
        if let symbol {
            // Ícone sem accent nem azul (Fase 2: estados por fg.*).
            HexaIcons.image(symbol, size: 13)
                .foregroundStyle(HexaTheme.fgSecondary)
                .frame(width: 26, height: 26)
                .background(HexaTheme.surfaceInset,
                            in: RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
        } else {
            // The menu bar draws the glyph white on a dark bar; the badge keeps
            // that pairing so it reads as the same icon in both appearances.
            MenuBarGlyph()
                .frame(width: 17, height: 13)
                .frame(width: 26, height: 26)
                .background(HexaTheme.surfaceInset,
                            in: RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
        }
    }
}

/// A row that picks one of a few options: segments beside the title while the
/// row fits on one line, under the title otherwise, and a menu there when the
/// segments don't fit either. A row wider than its column would center the page
/// and cut it on both sides.
struct SettingsChoiceRow<Value: Hashable>: View {
    let symbol: String?
    let title: String
    @Binding var selection: Value
    let options: [(value: Value, title: String)]

    init(symbol: String?, title: String, selection: Binding<Value>, options: [(Value, String)]) {
        self.symbol = symbol
        self.title = title
        _selection = selection
        self.options = options.map { (value: $0.0, title: $0.1) }
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            SettingsRow(symbol: symbol, title: title) {
                HexaSegmentControl(labeledOptions, selection: $selection)
                    .fixedSize()
            }
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                SettingsRow(symbol: symbol, title: title) { EmptyView() }
                ViewThatFits(in: .horizontal) {
                    HexaSegmentControl(labeledOptions, selection: $selection)
                    menu.fixedSize()
                }
                .padding(.leading, settingsRowTextInset)
            }
        }
    }

    private var labeledOptions: [(Value, String)] {
        options.map { ($0.value, $0.title) }
    }

    private var menu: some View {
        Picker(title, selection: $selection) {
            ForEach(options, id: \.value) { item in
                Text(item.title).tag(item.value)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
    }
}

/// A row whose choice is a menu: beside the title while the row fits on one
/// line, under the title otherwise, lined up with its text, or with its icon
/// when the menu is wider than the text leaves room for. A menu kept beside a
/// title that has to wrap squeezes the title letter by letter, and a row
/// wider than its column would center the page and cut it on both sides.
struct SettingsMenuRow<Value: Hashable, Options: View>: View {
    let symbol: String?
    let title: String
    @Binding var selection: Value
    let options: Options

    init(symbol: String?, title: String, selection: Binding<Value>, @ViewBuilder options: () -> Options) {
        self.symbol = symbol
        self.title = title
        _selection = selection
        self.options = options()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            SettingsRow(symbol: symbol, title: title) { menu }
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                SettingsRow(symbol: symbol, title: title) { EmptyView() }
                // Only the menu's width decides here: a title too long for one
                // line wraps above it either way.
                ViewThatFits(in: .horizontal) {
                    menu.padding(.leading, settingsRowTextInset)
                    menu
                }
            }
        }
    }

    private var menu: some View {
        Picker(title, selection: $selection) { options }.pickerStyle(.menu).labelsHidden().fixedSize()
    }
}

/// A switch pushed to the trailing edge with its label at the leading one,
/// so a shared control that carries its own label lines up with the rows
/// around it on a redesigned page.
struct TrailingSwitchToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: HexaTheme.Spacing.m) {
            configuration.label
            Spacer(minLength: HexaTheme.Spacing.m)
            Toggle(isOn: configuration.$isOn) { EmptyView() }
                .labelsHidden()
                .toggleStyle(HexaSwitchStyle())
        }
    }
}

/// Tile selecionável reutilizável para escolhas visuais em Ajustes (spec §5/§7).
struct SettingsChoiceTile<Content: View>: View {
    let selected: Bool
    var cornerRadius: CGFloat = HexaTheme.Radius.control
    var padding: CGFloat = HexaTheme.Spacing.s
    var fillsWidth: Bool = false
    let action: () -> Void
    @ViewBuilder let content: () -> Content
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            content()
                .padding(padding)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(selected ? HexaTheme.selectionBg : HexaTheme.surfaceInset)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(selected ? HexaTheme.accentSolid : HexaTheme.borderHairline,
                                      lineWidth: selected ? 1.5 : HexaTheme.hairline)
                )
                .overlay {
                    if isFocused {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(HexaTheme.focusRing, lineWidth: 2)
                            .padding(1)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
