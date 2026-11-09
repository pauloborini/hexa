// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// An in-place destination gallery. It only observes navigation, never the
/// contents or services of the sections represented by its buttons.
///
/// Rows step in whole, so the grid always rests on a row boundary; a dot per
/// resting position shows where it is and that more rows follow. Rows that
/// have stepped away keep their place for the motion but take no clicks.
struct NotchSectionsView: View {
    @ObservedObject var service: NotchService
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedPosition: Int?
    private var text: NotchStrings { FeatureStrings.notch(l10n.language) }
    private var sections: [NotchModule] { service.filteredSections }
    private static let pitch = NotchLayout.sectionTileHeight + NotchLayout.sectionSpacing

    var body: some View {
        Group {
            if sections.isEmpty {
                NotchEmptyView(symbol: "magnifyingglass", message: text.empty)
            } else {
                gallery
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: sections) { _, visible in
            if !visible.contains(where: { $0 == service.highlightedSection }) {
                service.highlightedSection = visible.first
            }
        }
    }

    private var gallery: some View {
        let columns = service.geometry.sectionColumns
        let rows = NotchSectionPaging.rows(count: sections.count, columns: columns)
        let visible = service.geometry.sectionRows(count: sections.count)
        let positions = NotchSectionPaging.positions(rows: rows, visible: visible)
        let first = NotchSectionPaging.clamped(service.sectionRow, rows: rows, visible: visible)
        let shown = first..<(first + visible)
        return HStack(spacing: 0) {
            VStack(spacing: NotchLayout.sectionSpacing) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: NotchLayout.sectionSpacing) {
                        ForEach(0..<columns, id: \.self) { column in
                            let index = row * columns + column
                            if index < sections.count {
                                tile(sections[index], visible: shown.contains(row))
                            } else {
                                Color.clear.frame(maxWidth: .infinity).frame(height: NotchLayout.sectionTileHeight)
                            }
                        }
                    }
                    .allowsHitTesting(shown.contains(row))
                    .accessibilityHidden(!shown.contains(row))
                }
            }
            .offset(y: -CGFloat(first) * Self.pitch)
            .frame(height: NotchLayout.railHeight(rows: visible, rowHeight: NotchLayout.sectionTileHeight,
                                                  spacing: NotchLayout.sectionSpacing), alignment: .top)
            .clipped()
            .animation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0), value: first)
            .accessibilityScrollAction { edge in
                if edge == .bottom { service.scrollSections(by: 1) }
                else if edge == .top { service.scrollSections(by: -1) }
            }
            indicator(positions: positions, current: first)
                .frame(width: NotchLayout.sectionIndicatorWidth, alignment: .trailing)
        }
        .accessibilityHint(text.sectionKeyboardHint)
    }

    /// One dot per resting position, the current one lit. Clicking a dot
    /// rests the gallery there; the wheel and the arrow keys step rows. The
    /// column keeps its width when everything fits, so tiles never shift.
    @ViewBuilder private func indicator(positions: Int, current: Int) -> some View {
        if positions > 1 {
            VStack(spacing: 5) {
                ForEach(0..<positions, id: \.self) { position in
                    Button { service.showSectionRow(position) } label: {
                        Circle()
                            .fill(HexaTheme.fgPrimary.opacity(position == current ? 0.9 : contrast == .increased ? 0.5 : 0.28))
                            .frame(width: 6, height: 6)
                            .frame(width: 12, height: 12)
                            .overlay {
                                if focusedPosition == position {
                                    Circle()
                                        .strokeBorder(HexaTheme.focusRing, lineWidth: 2)
                                }
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .focused($focusedPosition, equals: position)
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: current)
            .accessibilityHidden(true)
        } else {
            Color.clear
        }
    }

    private func tile(_ module: NotchModule, visible: Bool) -> some View {
        let highlighted = service.highlightedSection == module
        let current = service.selected == module
        let shape = RoundedRectangle(cornerRadius: HexaTheme.Radius.panel, style: .continuous)
        return Button { service.select(module) } label: {
            VStack(spacing: 3) {
                HexaIcons.image(module.symbol, size: HexaIconMetrics.standard)
                    .foregroundStyle(tint(for: module))
                    .frame(width: HexaIconMetrics.standard, height: HexaIconMetrics.standard)
                Text(module.title(l10n.language))
                    .font(.hexa(.label))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                    .frame(height: 16)
                ShortcutCaps(keys: ["⌥", "⌘", module.shortcutKey.uppercased()])
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .frame(height: NotchLayout.sectionTileHeight)
            .background(highlighted ? HexaTheme.selectionBg : HexaTheme.surfaceRaised, in: shape)
            .overlay {
                if contrast == .increased {
                    shape.strokeBorder(HexaTheme.accentSolid, lineWidth: HexaTheme.hairline)
                }
            }
            .overlay(alignment: .topTrailing) {
                if current {
                    HexaIcons.image("checkmark.circle.fill", size: 10)
                        .font(.hexaManrope(size: 10))
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .padding(7)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: HexaTheme.Radius.panel, lifts: false))
        .accessibilityLabel(module.title(l10n.language))
        .accessibilityAddTraits(current ? .isSelected : [])
        .accessibilityIdentifier("notch.module.\(module.rawValue)")
        // A stepped-away row sits under the header, clipped; it keeps no
        // tooltip there.
        .help(visible ? "\(module.title(l10n.language)) (⌥⌘\(module.shortcutKey.uppercased()))" : "")
    }

    private func tint(for module: NotchModule) -> Color {
        HexaTheme.fgPrimary
    }
}

/// The gallery's search lives in the header as a magnifier: the field
/// unfolds under the pointer or as soon as something is typed, since the
/// keyboard already goes to it while the gallery is open.
struct NotchSectionSearch: View {
    @ObservedObject var service: NotchService
    /// Infinite fills the room its parent gives it, up to the camera.
    var maximumFieldWidth: CGFloat = 150
    @ObservedObject private var l10n = L10n.shared
    @FocusState private var searching: Bool
    @State private var hovered = false
    @State private var fieldWidth: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var text: NotchStrings { FeatureStrings.notch(l10n.language) }
    private var expanded: Bool { hovered || searching || !service.sectionQuery.isEmpty }

    /// The whole prompt where it fits, otherwise the plain word, and no
    /// prompt where even that would be cut, so the placeholder never ends
    /// in a letter cut in half. The magnifier and the accessibility label
    /// still say what the field is for.
    private var prompt: String {
        let font = HexaTheme.manropeFont(size: 12)
        // The field's text sits a few points inside its frame.
        func fits(_ prompt: String) -> Bool {
            (prompt as NSString).size(withAttributes: [.font: font]).width + 6 <= fieldWidth
        }
        if fits(text.searchSections) { return text.searchSections }
        return fits(l10n.s.actionSearch) ? l10n.s.actionSearch : ""
    }

    var body: some View {
        HStack(spacing: expanded ? 4 : 6) {
            HexaIcons.image("magnifyingglass", size: 13)
                .font(.hexa(.body))
                .foregroundStyle(expanded ? HexaTheme.fgPrimary : HexaTheme.fgTertiary)
                .frame(width: expanded ? 22 : 28, height: 28)
            // The field keeps its focus at a hair's width, so typing filters
            // the gallery before the field has even shown itself.
            TextField(prompt, text: Binding(get: { service.sectionQuery }, set: service.searchSections))
                .textFieldStyle(.plain)
                .font(.hexaManrope(size: 12))
                .focused($searching)
                .frame(maxWidth: expanded ? maximumFieldWidth : 1)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { fieldWidth = $0 }
                .opacity(expanded ? 1 : 0)
                .accessibilityLabel(text.searchSections)
            if !service.sectionQuery.isEmpty {
                Button { service.searchSections(""); searching = true } label: {
                    HexaIcons.image("xmark.circle.fill").foregroundStyle(HexaTheme.fgSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(l10n.s.actionClear)
            }
        }
        .padding(.trailing, expanded ? 8 : 0)
        .frame(height: 28)
        .background(expanded ? HexaTheme.surfaceInset : .clear, in: RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
        .overlay {
            if searching {
                RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                    .strokeBorder(HexaTheme.focusRing, lineWidth: 2)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
        .clipped()
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) { hovered = hovering }
        }
        .onTapGesture { searching = true }
        .onAppear { searching = true }
        .help(text.searchSections)
    }
}
