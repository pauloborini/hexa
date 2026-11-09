// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// One section in the compact grid beside its options: the box that shows
/// it in the island, its icon and its name. A cell drags to a new place;
/// choosing one opens its options and its preview. A box rather than a
/// switch leaves the name its whole line even in the narrowest window.
struct NotchSectionListRow: View {
    let module: NotchModule
    @Binding var included: Bool
    let available: Bool
    let selected: Bool
    /// Controls is the island's default page, so it cannot be switched off (DEC-039).
    var pinned = false
    @Binding var order: [NotchModule]
    @Binding var dragging: NotchModule?
    let select: () -> Void
    var moveUp: () -> Void = {}
    var moveDown: () -> Void = {}
    @ObservedObject private var l10n = L10n.shared
    @State private var hovering = false
    private var editor: NotchEditorStrings { FeatureStrings.notchEditor(l10n.language) }
    private var experience: NotchExperienceStrings { FeatureStrings.notchExperience(l10n.language) }
    private var title: String { module.title(l10n.language) }

    var body: some View {
        PanelReorderableItem(item: module, order: $order, dragging: $dragging) {
            HStack(spacing: HexaTheme.Spacing.s) {
                // A section whose feature is off cannot show, whatever was chosen.
                Toggle(title, isOn: pinned ? .constant(true) : (available ? $included : .constant(false)))
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                    .disabled(pinned || !available)
                    .help(pinned ? experience.alwaysAvailable : "")
                    .accessibilityHint(pinned ? experience.alwaysAvailable : "")
                Button(action: select) {
                    HStack(spacing: HexaTheme.Spacing.s) {
                        NotchSectionTile(module: module, shown: included && available, side: 22)
                        Text(title)
                            .font(.hexa(.body))
                            .foregroundStyle(available ? HexaTheme.fgPrimary : HexaTheme.fgSecondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 2)
                    }
                    .padding(.vertical, HexaTheme.Spacing.xs)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(editor.summary(module))
                .accessibilityLabel(title)
                .accessibilityValue(editor.summary(module))
                .accessibilityAddTraits(selected ? .isSelected : [])
                reorderMenu
            }
            .padding(.horizontal, HexaTheme.Spacing.s)
            .frame(maxWidth: .infinity, minHeight: HexaTheme.Density.rowCompact, alignment: .leading)
            .background(selected ? HexaTheme.selectionBg : hovering ? HexaTheme.surfaceInset : .clear,
                        in: RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .opacity(dragging == module ? 0.45 : 1)
        }
    }

    /// The same reorder the drag does, for the keyboard and for a window too
    /// narrow to drag in.
    private var reorderMenu: some View {
        let index = order.firstIndex(of: module)
        return Menu {
            Button(experience.moveUp, action: moveUp)
                .disabled(index == nil || index == 0)
            Button(experience.moveDown, action: moveDown)
                .disabled(index == nil || index == order.count - 1)
        } label: {
            HexaIcons.image("ellipsis", size: 11)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(editor.reorderHint)
        .accessibilityLabel(editor.reorderHint)
    }
}

/// What the chosen section is, above its options: its icon, name and one
/// line on what it shows, and why it cannot show while its feature is off.
struct NotchSectionHeader: View {
    let module: NotchModule
    let shown: Bool
    /// Why an unavailable section cannot show.
    let reason: String?
    let openFeatures: () -> Void
    @ObservedObject private var l10n = L10n.shared
    private var editor: NotchEditorStrings { FeatureStrings.notchEditor(l10n.language) }

    var body: some View {
        HStack(alignment: .top, spacing: HexaTheme.Spacing.m) {
            NotchSectionTile(module: module, shown: shown, side: 38)
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                    Text(module.title(l10n.language)).font(.hexa(.heading))
                    Text(editor.summary(module))
                        .font(.hexa(.body))
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // Only the title and its summary read as one element; the
                // reason keeps its own text and its own button.
                .accessibilityElement(children: .combine)
                if let reason {
                    HStack(spacing: HexaTheme.Spacing.s) {
                        Text(reason)
                            .font(.hexa(.body))
                            .foregroundStyle(HexaTheme.statusWarning)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel(reason)
                        Button(editor.openFeatures, action: openFeatures).controlSize(.small)
                            .accessibilityLabel(editor.openFeatures)
                    }
                    .padding(.top, HexaTheme.Spacing.xs)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

/// A section's icon on neutral surface; grey while the section is hidden.
struct NotchSectionTile: View {
    let module: NotchModule
    let shown: Bool
    let side: CGFloat

    /// The control radius everywhere the tile is large enough for it; a tiny
    /// tile keeps corners proportional so it still reads as a rounded square.
    private var radius: CGFloat {
        side >= 20 ? HexaTheme.Radius.control : min(HexaTheme.Radius.control, side * 0.27)
    }

    var body: some View {
        HexaIcons.image(module.symbol, size: side * 0.46)
            .font(.hexaManrope(size: side * 0.46, weight: .semibold))
            .foregroundStyle(shown ? HexaTheme.fgPrimary : HexaTheme.fgSecondary)
            .frame(width: side, height: side)
            .background(shown ? HexaTheme.selectionBg : HexaTheme.surfaceInset,
                        in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .accessibilityHidden(true)
    }
}
