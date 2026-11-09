// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// The central editor for every global shortcut belonging to an installed
/// feature. It writes the same preferences as each feature page, so there is
/// still one setting and one registration path for every action.
struct ShortcutsSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var router = SettingsRouter.shared
    @AppStorage(DefaultsKey.keyboardBrightnessShortcutsEnabled) private var keyboardBrightnessShortcutsEnabled = false
    @AppStorage(DefaultsKey.hotkeyEnabled) private var keepAwakeHotkeyEnabled = true
    @State private var expandedFeatures: [FeatureGroup: Set<AppFeature>] = [.tools: [.screenshot]]

    private var text: ShortcutSettingsStrings { FeatureStrings.shortcuts(l10n.language) }
    private var hub: FeatureHubStrings { FeatureStrings.hub(l10n.language) }

    private var availableRoles: [GlobalShortcutRole] {
        GlobalShortcutRole.availableRoles(isAvailable: { $0.isAvailable }).filter { role in
            role != .displayBrightnessDecrease && role != .displayBrightnessIncrease
        }.filter {
            !$0.isKeyboardBrightness || BrightnessService.keyboardLightIsSupported
        }
    }

    private var captureRoles: [GlobalShortcutRole] {
        GlobalShortcutRole.captureRoles(in: availableRoles)
    }

    private var visibleGroups: [FeatureGroup] {
        FeatureGroup.allCases.filter { group in
            availableRoles.contains { $0.group == group }
        }
    }

    var body: some View {
        HexaScreenScaffold(title: l10n.s.shortcutsPageTitle,
                           subtitle: l10n.s.shortcutsPageCaption,
                           scrolls: false) {
            OverlayScrollView {
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.l) {
                    ForEach(visibleGroups, id: \.self) { group in
                        HexaSection(groupTitle(group)) {
                            ForEach(featuresWithShortcuts(in: group), id: \.self) { feature in
                                if feature == .screenshot {
                                    captureGroupRows
                                } else {
                                    featureRows(feature, in: group)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, HexaTheme.Spacing.xxl)
                .padding(.bottom, HexaTheme.Spacing.pageGap)
            }
        }
        .onAppear { revealKeyboardBrightnessShortcuts() }
        .onChange(of: router.requestID) { _, _ in revealKeyboardBrightnessShortcuts() }
    }

    private func featuresWithShortcuts(in group: FeatureGroup) -> [AppFeature] {
        AppFeature.allCases.filter { feature in
            // The screenshot slot anchors the combined capture group; the
            // other capture tools render inside it instead of on their own.
            if feature == .screenshot { return group == .tools && !captureRoles.isEmpty }
            if GlobalShortcutRole.captureFeatures.contains(feature) { return false }
            return availableRoles.contains { $0.feature == feature && $0.group == group }
        }
    }

    /// One group for every capture tool's shortcut. Rows keep each tool's own
    /// icon; the group carries the shared page's name and symbol.
    @ViewBuilder
    private var captureGroupRows: some View {
        let roles = captureRoles
        let tools = captureTools(in: roles)
        disclosureHeader(
            title: FeatureStrings.screenshot(l10n.language).screenCaptureTitle,
            symbolName: AppFeature.screenshot.symbolName,
            isActive: featureHasActiveShortcut(.screenshot, roles: roles),
            count: tools.count,
            isExpanded: expansionBinding(for: .screenshot, in: .tools))
        if expandedFeatures[.tools, default: []].contains(.screenshot) {
            ForEach(tools, id: \.self) { feature in
                captureModuleRow(feature)
                    .disclosureIndent()
            }
        }
    }

    private func captureTools(in roles: [GlobalShortcutRole]) -> [AppFeature] {
        var seen = Set<AppFeature>()
        return roles.map(\.feature).filter { seen.insert($0).inserted }
    }

    private func captureModuleRow(_ feature: AppFeature) -> some View {
        Button {
            FeatureWorkspaceWindow.shared.show(feature)
            FeatureWorkspaceState.shared.featureSettingsMode = true
        } label: {
            HStack(spacing: HexaTheme.Spacing.s) {
                ShortcutRowLabel(
                    title: feature.hubTitle(l10n.s, hub: hub),
                    symbolName: feature.symbolName,
                    contextLabel: nil,
                    statusText: nil,
                    statusIsActive: false
                )
                Spacer()
                HexaIcons.image("chevron.forward", size: 11)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgTertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isLink)
        .accessibilityRemoveTraits(.isButton)
    }

    @ViewBuilder
    private func featureRows(_ feature: AppFeature, in group: FeatureGroup) -> some View {
        let roles = availableRoles.filter { $0.feature == feature && $0.group == group }
        if roles.count > 1 {
            featureHeader(feature, roles: roles, count: roles.count, in: group)
            if expandedFeatures[group, default: []].contains(feature) {
                if feature == .brightness {
                    KeyboardBrightnessShortcutToggle(isEnabled: $keyboardBrightnessShortcutsEnabled)
                        .disclosureIndent()
                }
                ForEach(roles) { role in
                    roleRow(role, showsFeatureContext: false)
                        .disclosureIndent()
                }
            }
        } else if let role = roles.first {
            if feature == .keepAwake {
                KeepAwakeShortcutToggle(isEnabled: $keepAwakeHotkeyEnabled)
                roleRow(role)
            } else {
                roleRow(role)
            }
        }
    }

    @ViewBuilder
    private func featureHeader(_ feature: AppFeature, roles: [GlobalShortcutRole],
                               count: Int, in group: FeatureGroup) -> some View {
        let header = disclosureHeader(
            title: featureTitle(feature, roles: roles),
            symbolName: featureSymbol(feature, roles: roles),
            isActive: featureHasActiveShortcut(feature, roles: roles),
            count: count,
            isExpanded: expansionBinding(for: feature, in: group))
        if feature == .brightness {
            header.settingsSectionAnchor(.keyboardBrightnessShortcuts)
        } else {
            header
        }
    }

    private func revealKeyboardBrightnessShortcuts() {
        guard router.destination == FeatureSettingsDestination(
            .shortcuts, sectionAnchor: .keyboardBrightnessShortcuts) else { return }
        expandedFeatures[.energyDisplay, default: []].insert(.brightness)
    }

    private func featureTitle(_ feature: AppFeature, roles: [GlobalShortcutRole]) -> String {
        if feature == .brightness || (!roles.isEmpty && roles.allSatisfy(\.isKeyboardBrightness)) {
            return FeatureStrings.brightness(l10n.language).keyboardLight
        }
        return feature.hubTitle(l10n.s, hub: hub)
    }

    private func featureSymbol(_ feature: AppFeature, roles: [GlobalShortcutRole]) -> String {
        feature == .brightness || (!roles.isEmpty && roles.allSatisfy(\.isKeyboardBrightness))
            ? "keyboard" : feature.symbolName
    }

    private func disclosureHeader(title: String,
                                  symbolName: String,
                                  isActive: Bool,
                                  count: Int,
                                  isExpanded: Binding<Bool>) -> some View {
        DisclosureHeaderRow(isExpanded: isExpanded) {
            ShortcutRowLabel(
                title: title,
                symbolName: symbolName,
                contextLabel: nil,
                statusText: isActive ? text.active : text.inactive,
                statusIsActive: isActive
            )
            Spacer()
            Text("\(count)")
                .font(.hexa(.data))
                .foregroundStyle(HexaTheme.fgSecondary)
                .padding(.horizontal, HexaTheme.Spacing.s)
                .padding(.vertical, 2) // geometria de plataforma (spec §4): inset de cápsula de contagem
                .background(Capsule().fill(HexaTheme.surfaceInset))
        }
    }

    private func roleRow(_ role: GlobalShortcutRole,
                         showsFeatureContext: Bool = true,
                         reservesClearButtonSpace: Bool = false) -> some View {
        let title = role.title(l10n.s)
        let featureTitle = role.isKeyboardBrightness
            ? FeatureStrings.brightness(l10n.language).keyboardLight
            : role.feature.hubTitle(l10n.s, hub: hub)
        let active = role.requiredEnableKeys.allSatisfy {
            UserDefaults.standard.bool(forKey: $0)
        }
        return ShortcutPreferenceRow(
            role: role,
            isEnabled: roleIsEnabled(role),
            label: title,
            symbolName: role.isKeyboardBrightness ? "keyboard" : role.feature.symbolName,
            contextLabel: showsFeatureContext && title != featureTitle ? featureTitle : nil,
            statusText: active ? text.active : text.inactive,
            statusIsActive: active,
            reservesClearButtonSpace: reservesClearButtonSpace,
            onChange: {
                FeatureRuntime.shared.sync(role.availabilityFeatures)
            }
        )
    }

    private func roleIsEnabled(_ role: GlobalShortcutRole) -> Bool {
        if role == .keepAwake { return keepAwakeHotkeyEnabled }
        return !role.isKeyboardBrightness || keyboardBrightnessShortcutsEnabled
    }

    private func expansionBinding(for feature: AppFeature, in group: FeatureGroup) -> Binding<Bool> {
        Binding {
            expandedFeatures[group, default: []].contains(feature)
        } set: { expanded in
            if expanded {
                expandedFeatures[group, default: []].insert(feature)
            } else {
                expandedFeatures[group, default: []].remove(feature)
            }
        }
    }

    private func featureHasActiveShortcut(_ feature: AppFeature,
                                          roles: [GlobalShortcutRole]) -> Bool {
        roles.contains { role in
            role.requiredEnableKeys.allSatisfy { UserDefaults.standard.bool(forKey: $0) }
        }
    }

    private func groupTitle(_ group: FeatureGroup) -> String {
        switch group {
        case .sound: return hub.groupSound
        case .energyDisplay:
            return ShortcutSettingsStrings.groupEnergyAmbient(l10n.language)
        case .tools: return hub.groupTools
        case .dynamicIsland: return FeatureStrings.notch(l10n.language).title
        case .monitor: return hub.groupMonitor
        }
    }
}

private struct KeepAwakeShortcutToggle: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var hotkeys = HotkeyManager.shared
    @Binding var isEnabled: Bool

    var body: some View {
        Toggle(l10n.s.hotkeyToggle, isOn: $isEnabled)
            .toggleStyle(TrailingSwitchToggleStyle())
            .onChange(of: isEnabled) { _, _ in
                HotkeyManager.shared.syncWithPreferences()
            }
        if isEnabled, hotkeys.registrationFailed {
            HexaStatusNote(message: l10n.s.shortcutUnavailable)
        }
    }
}

private struct KeyboardBrightnessShortcutToggle: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var brightness = BrightnessService.shared
    @Binding var isEnabled: Bool

    var body: some View {
        Toggle(FeatureStrings.brightness(l10n.language).keyboardBrightnessShortcuts,
               isOn: $isEnabled)
            .toggleStyle(TrailingSwitchToggleStyle())
            .onChange(of: isEnabled) { _, _ in
                brightness.syncWithPreferences()
            }
        if isEnabled, brightness.keyboardBrightnessShortcutRegistrationFailed {
            HexaStatusNote(message: l10n.s.shortcutUnavailable)
        }
    }
}
