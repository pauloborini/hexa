// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Interactive visual grid of window placement presets (`DEC-014`, `DEC-017`).
/// Each tile renders a miniature layout diagram using Hexa's semantic tokens and
/// executes the placement directly on the last active external window.
struct WindowLayoutGridVisualizer: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = WindowManagerService.shared

    private var text: WindowManagerStrings { FeatureStrings.windowManager(l10n.language) }

    private let columns = [
        GridItem(.adaptive(minimum: 112, maximum: 148), spacing: HexaTheme.Spacing.s)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.l) {
            ForEach(WindowManagerAction.Category.allCases, id: \.self) { category in
                let actions = WindowManagerAction.allCases.filter { $0.category == category }
                HexaSection(text.categoryTitle(category)) {
                    LazyVGrid(columns: columns, spacing: HexaTheme.Spacing.s) {
                        ForEach(actions) { action in
                            WindowLayoutActionTile(
                                action: action,
                                title: text.actionTitle(action),
                                shortcutText: action.savedShortcut()?.displayString
                            ) {
                                service.apply(action)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct WindowLayoutActionTile: View {
    let action: WindowManagerAction
    let title: String
    let shortcutText: String?
    let onTap: () -> Void

    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: HexaTheme.Spacing.s) {
                previewGlyph
                    .frame(width: 48, height: 32)
                Text(title)
                    .font(.hexa(.label))
                    .foregroundStyle(isHovered ? HexaTheme.fgPrimary : HexaTheme.fgSecondary)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                if let shortcutText {
                    Text(shortcutText)
                        .font(.hexa(.data))
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .lineLimit(1)
                } else {
                    Text(" ")
                        .font(.hexa(.data))
                        .hidden()
                }
            }
            .padding(.horizontal, HexaTheme.Spacing.s)
            .padding(.vertical, HexaTheme.Spacing.m)
            .frame(maxWidth: .infinity, minHeight: 96)
            .background(
                RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                    .fill(isHovered ? HexaTheme.selectionBg : HexaTheme.surfaceInset)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                    .strokeBorder(
                        isFocused ? HexaTheme.focusRing : (isHovered ? HexaTheme.accentSolid : HexaTheme.borderHairline),
                        lineWidth: isFocused ? HexaTheme.hairline * 2 : HexaTheme.hairline
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .onHover { isHovered = $0 }
        .accessibilityLabel(shortcutText.map { "\(title), \($0)" } ?? title)
    }

    @ViewBuilder
    private var previewGlyph: some View {
        if let unit = action.previewUnitRect {
            GeometryReader { geo in
                let pad = HexaTheme.Spacing.xs
                let innerW = max(1, geo.size.width - pad * 2)
                let innerH = max(1, geo.size.height - pad * 2)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                        .fill(HexaTheme.surfaceBase)
                        .overlay(
                            RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                                .strokeBorder(HexaTheme.borderHairline, lineWidth: HexaTheme.hairline)
                        )
                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                        .fill(isHovered ? HexaTheme.fgPrimary : HexaTheme.accentSolid)
                        .frame(width: innerW * unit.width, height: innerH * unit.height)
                        .offset(x: pad + innerW * unit.minX,
                                y: pad + innerH * unit.minY)
                }
            }
            .accessibilityHidden(true)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                    .fill(HexaTheme.surfaceBase)
                    .overlay(
                        RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                            .strokeBorder(HexaTheme.borderHairline, lineWidth: HexaTheme.hairline)
                    )
                HexaIcons.image(utilitySymbolName)
                    .foregroundStyle(isHovered ? HexaTheme.fgPrimary : HexaTheme.fgSecondary)
            }
            .accessibilityHidden(true)
        }
    }

    private var utilitySymbolName: String {
        switch action {
        case .restore: return "arrow.uturn.backward"
        case .previousDisplay: return "chevron.left"
        case .nextDisplay: return "chevron.right"
        default: return "layout-grid"
        }
    }
}
