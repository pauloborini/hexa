// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Fonte única dos atalhos do notch expandido (DEC-008).
struct NotchShortcutsBarView: View {
    @ObservedObject var service: NotchService
    var configuration: NotchQuickAccessConfiguration? = nil
    var width: CGFloat? = nil
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var awake = KeepAwakeManager.shared

    private var buttons: [NotchQuickButton] { (configuration ?? service.quickAccessConfiguration).sanitized().buttons }
    private var layout: NotchQuickAccessLayout {
        NotchQuickAccessLayout(count: buttons.count, width: width ?? service.contentSize.width)
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: NotchQuickAccessLayout.buttonSpacing),
                                 count: layout.columns), spacing: NotchQuickAccessLayout.buttonSpacing) {
            ForEach(buttons.prefix(layout.visibleCount)) { button in
                Button { if let action = button.action { service.activateQuickAction(action) } } label: {
                    label(button)
                }
                .buttonStyle(NotchButtonStyle(cornerRadius: HexaTheme.Radius.control, lifts: false))
                .help(title(button))
                .accessibilityLabel(title(button))
                .accessibilityAddTraits(selected(button) ? .isSelected : [])
                .accessibilityIdentifier("notch.shortcutsBar.\(button.id.uuidString)")
            }
            if layout.hasOverflow {
                NotchMenuButton(title: allTitle, items: buttons.map { button in
                    NotchMenuItem(title: title(button), checked: selected(button), symbol: button.action?.symbol) {
                        if let action = button.action { service.activateQuickAction(action) }
                    }
                }, cornerRadius: HexaTheme.Radius.control) {
                    NotchQuickButtonLabel(symbol: "square.grid.2x2", title: allTitle)
                }
                .help(allTitle)
                .accessibilityIdentifier("notch.shortcutsBar.all")
            }
        }
        .frame(height: layout.height, alignment: .top)
    }

    private var allTitle: String { NotchShortcutStrings.all(l10n.language) }
    private var text: NotchStrings { FeatureStrings.notch(l10n.language) }

    private func title(_ button: NotchQuickButton) -> String {
        guard let action = button.action else { return "" }
        if action == .explore && service.showingSections { return l10n.s.obBack }
        if !button.label.isEmpty { return button.label }
        if action == .pin { return service.pinned ? text.unpin : text.pin }
        return action.title(l10n)
    }

    private func selected(_ button: NotchQuickButton) -> Bool {
        switch button.action {
        case .explore: return service.showingSections
        case .pin: return service.pinned
        case .control(.keepAwake): return awake.isActive
        case .module(let module): return !service.showingSections && !service.showingAppPanel && service.selected == module
        default: return false
        }
    }

    private func label(_ button: NotchQuickButton) -> some View {
        let active = button.action == .control(.keepAwake) && awake.isActive
        let symbol = button.action == .explore && service.showingSections ? "arrow.uturn.backward"
            : button.action == .pin && service.pinned ? "pin.fill" : button.action?.symbol ?? "questionmark"
        return NotchQuickButtonLabel(symbol: symbol, title: title(button), selected: selected(button), awakeActive: active)
    }
}

/// Anatomia compartilhada por botões executáveis e pelo editor da grade.
struct NotchQuickButtonLabel: View {
    let symbol: String
    let title: String
    var selected = false
    var awakeActive = false
    /// The editor shows a drag handle so the tile reads as reorderable.
    var showsGrip = false

    var body: some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            HexaIcons.image(symbol)
            Text(title)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .truncationMode(.tail)
                .minimumScaleFactor(0.85)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if showsGrip {
                HexaIcons.image("line.3.horizontal", size: 10)
                    .foregroundStyle(HexaTheme.fgTertiary)
                    .accessibilityHidden(true)
            }
        }
        .font(.hexa(.label))
        .foregroundStyle(awakeActive ? HexaTheme.surfaceBase : HexaTheme.fgPrimary)
        .padding(.horizontal, HexaTheme.Spacing.m)
        .frame(maxWidth: .infinity)
        .frame(height: NotchQuickAccessLayout.height)
        .background(awakeActive ? HexaTheme.awakeActive : selected ? HexaTheme.selectionBg : HexaTheme.surfaceInset,
                    in: RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
    }
}

extension NotchQuickAction {
    var symbol: String {
        switch self {
        case .explore: return "square.grid.2x2"
        case .pin: return "pin"
        case .module(let module): return module.symbol
        case .control(let item): return item.symbol
        }
    }

    func title(_ l10n: L10n) -> String {
        switch self {
        case .explore: return FeatureStrings.notch(l10n.language).sectionsTitle
        case .pin: return FeatureStrings.notch(l10n.language).pin
        case .module(let module): return module.title(l10n.language)
        case .control(let item): return item.title(l10n)
        }
    }
}
