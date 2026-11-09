// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI
import UniformTypeIdentifiers

protocol PanelOrderItem: RawRepresentable, CaseIterable, Hashable where RawValue == String {}

/// The major, user-customizable sections of the menu panel. Raw values are the
/// stable identifiers persisted in the saved order and the collapsed set, so
/// renaming a case would orphan a user's stored layout — keep them stable.
enum PanelSectionID: String, CaseIterable, Identifiable, Hashable {
    case keepAwake, brightness, mixer, system, network, disk, power, fanControl, utilities

    var id: String { rawValue }

    /// Localized display name, reused from the existing section titles.
    func title(_ s: Strings) -> String {
        switch self {
        case .keepAwake: return s.keepAwakeTitle
        case .brightness: return FeatureStrings.brightness(L10n.shared.language).pageTitle
        case .mixer: return s.mixerSection
        case .system: return s.systemSection
        case .network: return s.networkSection
        case .disk: return s.diskSection
        case .power: return s.powerSection
        case .fanControl: return FeatureStrings.fanControl(L10n.shared.language).title
        case .utilities: return s.utilitiesSection
        }
    }

    var symbolName: String {
        switch self {
        // The panel uses the same glyph as the sidebar and the hub, so a
        // feature is recognized by one symbol on every surface.
        case .keepAwake: return AppFeature.keepAwake.symbolName
        case .brightness: return AppFeature.brightness.symbolName
        case .mixer: return "slider.vertical.3"
        case .system: return "cpu.fill"
        case .network: return "wifi"
        case .disk: return "externaldrive.fill"
        case .power: return "battery.100"
        case .fanControl: return "fanblades.fill"
        case .utilities: return "square.grid.2x2.fill"
        }
    }

    /// The UserDefaults key that controls whether this section shows in the panel.
    /// The monitoring blocks reuse their existing `monitorShow*` keys; the rest
    /// get a dedicated `panelShow*` key so every section is hideable.
    var visibilityKey: String {
        switch self {
        case .keepAwake: return DefaultsKey.panelShowKeepAwake
        case .brightness: return DefaultsKey.panelShowBrightness
        case .mixer: return DefaultsKey.monitorShowMixer
        case .system: return DefaultsKey.monitorShowSystem
        case .network: return DefaultsKey.monitorShowNetwork
        case .disk: return DefaultsKey.monitorShowDisk
        case .power: return DefaultsKey.monitorShowPower
        case .fanControl: return DefaultsKey.panelShowFanControl
        case .utilities: return DefaultsKey.panelShowUtilities
        }
    }

    /// Installed sections show by default and remain individually hideable.
    var shownByDefault: Bool { true }

    /// Hub features that keep this section alive: with all of them off, the
    /// section leaves the panel, the section navigation and the layout
    /// editors, regardless of its visibility key (which is preserved for the
    /// feature's return).
    var featureGate: [AppFeature] {
        switch self {
        case .keepAwake: return [.keepAwake]
        case .brightness: return [.brightness]
        case .mixer: return [.mixer]
        case .system: return [.monitorCPU, .monitorGPU, .monitorMemory]
        case .network: return [.monitorNetwork]
        case .disk: return [.monitorDisk]
        case .power: return [.monitorPower]
        case .fanControl: return [.fanControl]
        case .utilities: return [.cleaner, .appUpdates, .mediaTools, .uninstaller, .screenOCR,
                                 .screenshot, .portManager]
        }
    }

    var isAvailable: Bool { featureGate.contains(where: \.isAvailable) }
}

/// Persisted panel layout: the order the sections appear in and which ones are
/// collapsed. The order is a comma-joined list of ids; any section missing from
/// a saved order (e.g. one added in a later version) is appended in its canonical
/// position, so a section can never silently disappear. Collapsed sections are a
/// comma-joined set of ids.
enum PanelLayout {
    private static var defaults: UserDefaults { .standard }

    /// The sections in display order: the user's saved order first, then any not
    /// yet listed, in their canonical order.
    static var order: [PanelSectionID] {
        let saved = (defaults.string(forKey: DefaultsKey.panelSectionOrder) ?? "")
            .split(separator: ",")
            .compactMap { PanelSectionID(rawValue: String($0)) }
        var seen = Set<PanelSectionID>()
        var result: [PanelSectionID] = []
        for id in saved where seen.insert(id).inserted { result.append(id) }
        for id in PanelSectionID.allCases where seen.insert(id).inserted {
            if id == .disk, let networkIndex = result.firstIndex(of: .network) {
                result.insert(id, at: networkIndex + 1)
            } else if id == .brightness, let keepAwakeIndex = result.firstIndex(of: .keepAwake) {
                // Added later: saved orders predate it, so it slots in at
                // its canonical place instead of the end.
                result.insert(id, at: keepAwakeIndex + 1)
            } else {
                result.append(id)
            }
        }
        return result
    }

    static func setOrder(_ ids: [PanelSectionID]) {
        defaults.set(ids.map(\.rawValue).joined(separator: ","), forKey: DefaultsKey.panelSectionOrder)
    }

    static func itemOrder<Item: PanelOrderItem>(_ type: Item.Type, key: String) -> [Item] {
        let defaultOrder = type.allCases.map(\.rawValue)
        let raw = defaults.string(forKey: key) ?? ""
        return Defaults.sanitizedPanelItemOrder(raw, defaultOrder: defaultOrder).compactMap(Item.init(rawValue:))
    }

    static func setItemOrder<Item: PanelOrderItem>(_ ids: [Item], key: String) {
        defaults.set(ids.map(\.rawValue).joined(separator: ","), forKey: key)
    }

    static func resetItemOrder(key: String) {
        defaults.removeObject(forKey: key)
    }

    static func isShown(_ id: PanelSectionID) -> Bool {
        defaults.object(forKey: id.visibilityKey) as? Bool ?? id.shownByDefault
    }

    static func setShown(_ shown: Bool, for id: PanelSectionID) {
        defaults.set(shown, forKey: id.visibilityKey)
    }

    /// Whether the section earns a tab in the panel right now: installed and
    /// shown, and for brightness also switched on, since that tab is enabled
    /// from Settings rather than from an empty panel screen. The one rule the
    /// island panel (`MenuPanelView`) reads.
    static func isVisibleInPanel(_ id: PanelSectionID) -> Bool {
        guard id.isAvailable, isShown(id) else { return false }
        return id != .brightness || defaults.bool(forKey: DefaultsKey.brightnessControlEnabled)
    }

    static func isCollapsed(_ id: PanelSectionID) -> Bool {
        collapsedSet().contains(id.rawValue)
    }

    static func setCollapsed(_ collapsed: Bool, for id: PanelSectionID) {
        var set = collapsedSet()
        if collapsed { set.insert(id.rawValue) } else { set.remove(id.rawValue) }
        defaults.set(set.sorted().joined(separator: ","), forKey: DefaultsKey.panelCollapsedSections)
    }

    static func resetCollapsedSectionsOnce(for version: String) {
        guard defaults.string(forKey: DefaultsKey.panelCollapsedResetVersion) != version else { return }
        defaults.removeObject(forKey: DefaultsKey.panelCollapsedSections)
        defaults.set(version, forKey: DefaultsKey.panelCollapsedResetVersion)
    }

    private static func collapsedSet() -> Set<String> {
        Set((defaults.string(forKey: DefaultsKey.panelCollapsedSections) ?? "")
            .split(separator: ",").map(String.init))
    }
}

/// A major panel section with a collapsible header. The header row (the section
/// title plus a chevron) toggles a persisted collapsed state; collapsing hides
/// the body but keeps the header so it can be reopened. Every major component in
/// the panel uses this so they all collapse and reorder consistently.
struct PanelSection<Content: View>: View {
    @ObservedObject private var l10n = L10n.shared
    private let id: PanelSectionID
    private let title: String
    private let collapsible: Bool
    private let supportsEditing: Bool
    private let editButtonVisible: Bool
    private let resetAction: (() -> Void)?
    private let content: (Bool) -> Content
    @State private var collapsed: Bool
    @State private var editing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isHeaderFocused: Bool
    @FocusState private var isEditFocused: Bool
    @FocusState private var isResetFocused: Bool

    init(_ id: PanelSectionID, title: String, collapsible: Bool = true,
         @ViewBuilder content: @escaping () -> Content) {
        self.id = id
        self.title = title
        self.collapsible = collapsible
        self.supportsEditing = false
        self.editButtonVisible = false
        self.resetAction = nil
        self.content = { _ in content() }
        _collapsed = State(initialValue: PanelLayout.isCollapsed(id))
    }

    init(_ id: PanelSectionID, title: String, collapsible: Bool = true,
         supportsEditing: Bool,
         editButtonVisible: Bool = true,
         resetAction: (() -> Void)? = nil,
         @ViewBuilder content: @escaping (Bool) -> Content) {
        self.id = id
        self.title = title
        self.collapsible = collapsible
        self.supportsEditing = supportsEditing
        self.editButtonVisible = editButtonVisible
        self.resetAction = resetAction
        self.content = content
        _collapsed = State(initialValue: PanelLayout.isCollapsed(id))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            header

            if !collapsible || !collapsed {
                content(isEditing)
            }
        }
    }

    private var header: some View {
        HStack(spacing: HexaTheme.Spacing.xs) {
            if collapsible {
                Button(action: toggle) {
                    HStack(spacing: HexaTheme.Spacing.xs) {
                        sectionTitle(title)
                        Spacer(minLength: 0)
                        collapseIcon
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focused($isHeaderFocused)
                .overlay {
                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                        .strokeBorder(isHeaderFocused ? HexaTheme.focusRing : .clear, lineWidth: 2)
                        .padding(1) // geometria de plataforma (spec §4): offset de foco
                }
                .accessibilityValue(collapsed ? l10n.s.disclosureCollapsed : l10n.s.disclosureExpanded)
            } else {
                sectionTitle(title)
                Spacer(minLength: 0)
            }
            if supportsEditing {
                if isEditing, let resetAction {
                    resetButton(resetAction)
                        .opacity(editButtonVisible ? 1 : 0)
                        .disabled(!editButtonVisible)
                        .accessibilityHidden(!editButtonVisible)
                }
                editButton
                    .opacity(editButtonVisible ? 1 : 0)
                    .disabled(!editButtonVisible)
                    .accessibilityHidden(!editButtonVisible)
            }
        }
    }

    private var collapseIcon: some View {
        HexaIcons.image("chevron.right", size: 10)
            .font(.hexa(.micro))
            .foregroundStyle(HexaTheme.fgTertiary)
            .rotationEffect(.degrees(collapsed ? 0 : 90))
    }

    private var editButton: some View {
        Button(action: toggleEditing) {
            if isEditing {
                Label(l10n.s.buttonDone, hexaIcon: "checkmark")
                    .font(.hexa(.label))
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, HexaTheme.Spacing.s)
                    .frame(height: HexaTheme.Spacing.xl)
                    .contentShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
            } else {
                HexaIcons.image("slider.horizontal.3", size: 11)
                    .font(.hexa(.label))
                    .frame(width: HexaTheme.Spacing.xl, height: HexaTheme.Spacing.xl)
                    .contentShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
            }
        }
        .buttonStyle(.plain)
        .focused($isEditFocused)
        .foregroundStyle(isEditing ? HexaTheme.accentText : HexaTheme.fgSecondary)
        .background(
            RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                .fill(isEditing ? HexaTheme.selectionBg : HexaTheme.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                .strokeBorder(
                    isEditFocused ? HexaTheme.focusRing : (isEditing ? HexaTheme.accentSolid.opacity(0.35) : HexaTheme.borderHairline),
                    lineWidth: isEditFocused ? 2 : HexaTheme.hairline
                )
        )
        .help(isEditing ? l10n.s.uninstallerDoneTitle : l10n.s.menuEdit)
    }

    private func resetButton(_ action: @escaping () -> Void) -> some View {
        HexaIconButton(icon: "arrow.counterclockwise",
                       label: l10n.s.mixerOutputDefault,
                       variant: .small) {
            action()
        }
        .focused($isResetFocused)
        .help(l10n.s.mixerOutputDefault)
    }

    private var isEditing: Bool { supportsEditing && editButtonVisible && editing }

    private func toggleEditing() {
        if collapsed {
            collapsed = false
            PanelLayout.setCollapsed(false, for: id)
        }
        editing.toggle()
    }

    private func toggle() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            collapsed.toggle()
        }
        PanelLayout.setCollapsed(collapsed, for: id)
    }
}

struct PanelDragHandle: View {
    var body: some View {
        HexaIcons.image("line.3.horizontal", size: 11)
            .font(.hexa(.label))
            .foregroundStyle(HexaTheme.fgTertiary)
            .frame(width: PanelRowMetrics.dragHandleWidth, height: 22)
            .contentShape(Rectangle())
            .help(L10n.shared.s.monitorOrderHint)
    }
}

struct PanelReorderableItem<Item: PanelOrderItem, Content: View>: View {
    let item: Item
    var isEnabled = true
    /// Rows inside a `PanelRowGroup` have no card of their own, so the one
    /// being dragged gets a card for its preview and stays readable over
    /// whatever sits under the pointer.
    var previewsAsCard = false
    @Binding var order: [Item]
    @Binding var dragging: Item?
    let content: () -> Content

    var body: some View {
        if isEnabled {
            draggableContent
                .onDrop(of: [UTType.text], delegate: PanelItemDropDelegate(item: item,
                                                                           order: $order,
                                                                           dragging: $dragging))
        } else {
            content()
        }
    }

    @ViewBuilder
    private var draggableContent: some View {
        if previewsAsCard {
            content()
                .onDrag(itemProvider) {
                    content()
                        .frame(minWidth: 220, alignment: .leading)
                        .panelCard(interactive: false, padded: false)
                }
        } else {
            content()
                .onDrag(itemProvider)
        }
    }

    private func itemProvider() -> NSItemProvider {
        dragging = item
        return NSItemProvider(object: item.rawValue as NSString)
    }
}

private struct PanelItemDropDelegate<Item: PanelOrderItem>: DropDelegate {
    let item: Item
    @Binding var order: [Item]
    @Binding var dragging: Item?

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging != item,
              let from = order.firstIndex(of: dragging),
              let to = order.firstIndex(of: item) else { return }
        order.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

struct PanelInlineHideButton: View {
    @ObservedObject private var l10n = L10n.shared
    @Binding var isVisible: Bool
    @FocusState private var isFocused: Bool

    var body: some View {
        HexaIconButton(icon: isVisible ? "eye.slash.fill" : "eye.fill",
                       label: isVisible ? l10n.s.panelHideItem : l10n.s.panelShowItem,
                       variant: .small,
                       iconTint: isVisible ? HexaTheme.fgSecondary : HexaTheme.accentText) {
            isVisible.toggle()
        }
        .focused($isFocused)
        .help(isVisible ? l10n.s.panelHideItem : l10n.s.panelShowItem)
    }
}

struct PanelHiddenBadge: View {
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        Label(l10n.s.panelHiddenItem, hexaIcon: "eye.slash.fill")
            .font(.hexa(.micro))
            .foregroundStyle(HexaTheme.fgSecondary)
            .padding(.horizontal, HexaTheme.Spacing.s)
            .padding(.vertical, HexaTheme.Spacing.xs)
            .background(
                Capsule()
                    .fill(HexaTheme.fgPrimary.opacity(0.08))
            )
    }
}

struct PanelHiddenItemRow: View {
    let title: String
    let systemImage: String
    @Binding var isVisible: Bool

    var body: some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            HexaIcons.image(systemImage, size: 11)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgTertiary)
                .frame(width: 16)
            Text(title)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            PanelHiddenBadge()
            PanelInlineHideButton(isVisible: $isVisible)
        }
        .padding(.vertical, HexaTheme.Spacing.xs)
        .padding(.horizontal, HexaTheme.Spacing.xs)
        // O mesmo desenho do cartão único (spec §7): sem contorno; a
        // hairline só volta com "Aumentar contraste".
        .hexaCardSurface(
            increaseContrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        )
    }
}
