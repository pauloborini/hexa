// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Settings surface for the Window Manager module (`DEC-014`, `DEC-017`).
/// Configures keyboard shortcuts, shortcut profiles, screen/window gaps,
/// magnetic snap zones, Stage Manager reservation, and ignored apps.
struct WindowManagerSettingsView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = WindowManagerService.shared
    @ObservedObject private var permissions = Permissions.shared

    @AppStorage(DefaultsKey.windowLayoutShortcutsEnabled) private var shortcutsEnabled = false
    @AppStorage(DefaultsKey.windowEdgeSnapEnabled) private var edgeSnapEnabled = false
    @AppStorage(DefaultsKey.windowManagerSnapModifier) private var snapModifierRaw = WindowSnapModifier.none.rawValue
    @AppStorage(DefaultsKey.windowManagerReserveStageManagerSpace) private var reserveStageManager = true
    @AppStorage(DefaultsKey.windowLayoutSideRepeatCyclesThirds) private var sideCycleThirds = false
    @AppStorage(DefaultsKey.windowLayoutCycleSameWidth) private var cycleSameWidth = false
    @AppStorage(DefaultsKey.windowLayoutWindowGap) private var windowGap = 0
    @AppStorage(DefaultsKey.windowLayoutScreenGap) private var screenGap = 0
    @AppStorage(DefaultsKey.windowLayoutMarginPercent) private var marginPercent = WindowGapsConfig.defaultMarginPercent
    @AppStorage(DefaultsKey.windowEdgeSnapDisabledZones) private var disabledZonesRaw = ""
    @AppStorage(DefaultsKey.windowManagerShortcutProfile) private var profileRaw = WindowShortcutProfile.standard.rawValue

    @State private var permissionDemandID = UUID()
    @State private var selectedProfileRaw: String = WindowShortcutProfile.standard.rawValue

    private var text: WindowManagerStrings { FeatureStrings.windowManager(l10n.language) }

    private var enabledZones: Set<WindowSnapZone> {
        WindowSnapZone.enabledZones(from: disabledZonesRaw)
    }

    private var safeMarginPercent: Double { WindowGapsConfig.sanitizedMarginPercent(marginPercent) }

    private var marginLabel: String {
        (safeMarginPercent / 100).formatted(.percent.precision(.fractionLength(0))
            .locale(Locale(identifier: l10n.language.rawValue)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.l) {
            if !permissions.accessibility {
                accessibilityBanner
            }

            behaviorSection
            spacingSection
            snapZonesSection
            shortcutsSection
            ignoredAppsSection
        }
        .onAppear {
            service.syncWithPreferences()
            selectedProfileRaw = (WindowShortcutProfile(rawValue: profileRaw) ?? .standard).rawValue
            permissions.setActivePermissionSurface(permissionDemandID, visible: !permissions.accessibility)
        }
        .onChange(of: permissions.accessibility) { _, _ in
            permissions.setActivePermissionSurface(permissionDemandID, visible: !permissions.accessibility)
        }
        .onChange(of: profileRaw) { _, newValue in
            selectedProfileRaw = (WindowShortcutProfile(rawValue: newValue) ?? .standard).rawValue
        }
        .onDisappear {
            permissions.setActivePermissionSurface(permissionDemandID, visible: false)
        }
    }

    // MARK: - Accessibility Banner

    private var accessibilityBanner: some View {
        HexaSection(l10n.s.permissionAccessibility) {
            Text(text.needsAccessibility)
                .hexaCaption()
            HStack(spacing: HexaTheme.Spacing.s) {
                HexaAccessButton(icon: "accessibility", title: l10n.s.permissionRequest) {
                    permissions.requestAccessibility()
                }
                HexaAccessButton(icon: "gearshape", title: FeatureStrings.hub(l10n.language).openSystemSettings) {
                    permissions.openAccessibilitySettings()
                }
            }
        }
    }

    // MARK: - Behavior

    private var behaviorSection: some View {
        HexaSection(text.behaviorSection) {
            SettingsRow(symbol: "keyboard", title: text.shortcutsToggle, caption: text.shortcutsCaption) {
                Toggle(text.shortcutsToggle, isOn: $shortcutsEnabled)
                    .labelsHidden()
                    .toggleStyle(HexaSwitchStyle())
                    .onChange(of: shortcutsEnabled) { _, isOn in
                        if isOn { permissions.requestAccessibility() }
                        service.syncWithPreferences()
                    }
            }
            HairlineDivider()
            SettingsRow(symbol: "layout-grid", title: text.edgeSnapToggle, caption: text.edgeSnapCaption) {
                Toggle(text.edgeSnapToggle, isOn: $edgeSnapEnabled)
                    .labelsHidden()
                    .toggleStyle(HexaSwitchStyle())
                    .onChange(of: edgeSnapEnabled) { _, isOn in
                        if isOn { permissions.requestAccessibility() }
                        service.syncWithPreferences()
                    }
            }
            if edgeSnapEnabled {
                HairlineDivider()
                SettingsRow(symbol: "command", title: text.snapModifierLabel) {
                    Picker(text.snapModifierLabel, selection: $snapModifierRaw) {
                        Text(text.snapModifierNone).tag(WindowSnapModifier.none.rawValue)
                        Text(text.snapModifierOption).tag(WindowSnapModifier.option.rawValue)
                        Text(text.snapModifierControl).tag(WindowSnapModifier.control.rawValue)
                        Text(text.snapModifierCommand).tag(WindowSnapModifier.command.rawValue)
                        Text(text.snapModifierShift).tag(WindowSnapModifier.shift.rawValue)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                    .onChange(of: snapModifierRaw) { _, _ in service.syncWithPreferences() }
                }
                if snapModifierRaw == WindowSnapModifier.option.rawValue, WindowAccessibilityClient.nativeOptionTilingEnabled {
                    HexaStatusNote(message: text.nativeOptionTilingNotice)
                }
            }
            HairlineDivider()
            SettingsRow(symbol: "panels-top-left", title: text.stageManagerToggle, caption: text.stageManagerCaption) {
                Toggle(text.stageManagerToggle, isOn: $reserveStageManager)
                    .labelsHidden()
                    .toggleStyle(HexaSwitchStyle())
                    .onChange(of: reserveStageManager) { _, _ in service.syncWithPreferences() }
            }
            HairlineDivider()
            SettingsRow(symbol: "rectangle.split.3x1", title: text.sameWidthCycleToggle, caption: text.sameWidthCycleCaption) {
                Toggle(text.sameWidthCycleToggle, isOn: $cycleSameWidth)
                    .labelsHidden()
                    .toggleStyle(HexaSwitchStyle())
                    .onChange(of: cycleSameWidth) { _, _ in service.resetHorizontalCycle() }
            }
            HairlineDivider()
            SettingsRow(symbol: "rectangle.split.3x1", title: text.sideCycleToggle, caption: text.sideCycleCaption) {
                Toggle(text.sideCycleToggle, isOn: $sideCycleThirds)
                    .labelsHidden()
                    .toggleStyle(HexaSwitchStyle())
                    .disabled(cycleSameWidth)
            }
        }
    }

    // MARK: - Spacing & Margins

    private var spacingSection: some View {
        HexaSection(text.spacingSection) {
            SettingsRow(symbol: "rectangle.inset.filled", title: text.windowGapLabel) {
                Picker(text.windowGapLabel, selection: $windowGap) {
                    ForEach(WindowGapsConfig.presets, id: \.self) { px in
                        Text(px == 0 ? text.gapNone : "\(px) px").tag(px)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
                .onChange(of: windowGap) { _, _ in service.syncWithPreferences() }
            }
            HairlineDivider()
            SettingsRow(symbol: "rectangle.dashed", title: text.screenGapLabel) {
                Picker(text.screenGapLabel, selection: $screenGap) {
                    ForEach(WindowGapsConfig.presets, id: \.self) { px in
                        Text(px == 0 ? text.gapNone : "\(px) px").tag(px)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
                .onChange(of: screenGap) { _, _ in service.syncWithPreferences() }
            }
            HairlineDivider()
            SettingsRow(symbol: "rectangle", title: text.marginPercentLabel) {
                HStack(spacing: HexaTheme.Spacing.s) {
                    Slider(value: Binding(get: { safeMarginPercent }, set: { marginPercent = $0 }),
                           in: WindowGapsConfig.marginPercentRange, step: 1)
                        .frame(width: 120)
                        .accessibilityLabel(text.marginPercentLabel)
                        .accessibilityValue(marginLabel)
                    Text(marginLabel)
                        .font(.hexa(.data))
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .frame(minWidth: HexaTheme.Density.rowStandard, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - Snap Zones

    private var snapZonesSection: some View {
        HexaSection(text.snapZonesSection) {
            Text(text.snapZonesCaption)
                .hexaCaption()
            VStack(spacing: HexaTheme.Spacing.xs) {
                HStack(spacing: HexaTheme.Spacing.xs) {
                    zoneToggle(.topLeft, title: text.topLeft)
                    zoneToggle(.top, title: text.maximize)
                    zoneToggle(.topRight, title: text.topRight)
                }
                HStack(spacing: HexaTheme.Spacing.xs) {
                    zoneToggle(.left, title: text.leftHalf)
                    Spacer(minLength: HexaTheme.Spacing.s)
                        .frame(maxWidth: .infinity)
                    zoneToggle(.right, title: text.rightHalf)
                }
                HStack(spacing: HexaTheme.Spacing.xs) {
                    zoneToggle(.bottomLeft, title: text.bottomLeft)
                    zoneToggle(.bottom, title: text.bottomHalf)
                    zoneToggle(.bottomRight, title: text.bottomRight)
                }
            }
            .padding(.top, HexaTheme.Spacing.xs)
        }
    }

    private func zoneToggle(_ zone: WindowSnapZone, title: String) -> some View {
        let active = enabledZones.contains(zone)
        return WindowSnapZoneTile(title: title, isActive: active) {
            var next = enabledZones
            if active { next.remove(zone) } else { next.insert(zone) }
            disabledZonesRaw = WindowSnapZone.disabledStorageValue(from: next)
            service.syncWithPreferences()
        }
    }

    // MARK: - Keyboard Shortcuts

    private var shortcutsSection: some View {
        let activeProfile = WindowShortcutProfile(rawValue: profileRaw) ?? .standard
        return HexaSection(text.shortcutsSection) {
            HStack(spacing: HexaTheme.Spacing.s) {
                Text(text.shortcutProfileLabel)
                    .font(.hexa(.body))
                Spacer()
                Picker(text.shortcutProfileLabel, selection: $selectedProfileRaw) {
                    Text(text.profileStandard).tag(WindowShortcutProfile.standard.rawValue)
                    Text(text.profileCompact).tag(WindowShortcutProfile.compact.rawValue)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
                Button(text.resetShortcutsButton) {
                    let profile = WindowShortcutProfile(rawValue: selectedProfileRaw) ?? .standard
                    service.applyShortcutProfile(profile)
                }
                .buttonStyle(HexaActionButtonStyle())
                .controlSize(.small)
            }

            if !service.failedShortcutActions.isEmpty {
                HexaStatusNote(message: text.shortcutUnavailable)
            }

            HairlineDivider()

            VStack(spacing: HexaTheme.Spacing.s) {
                ForEach(WindowManagerAction.allCases) { action in
                    WindowManagerShortcutRow(
                        action: action,
                        profile: activeProfile,
                        title: text.actionTitle(action),
                        emptyTitle: text.noShortcutAssigned,
                        isEnabled: shortcutsEnabled,
                        hasConflict: service.failedShortcutActions.contains(action)
                    )
                    if action != WindowManagerAction.allCases.last {
                        HairlineDivider()
                    }
                }
            }
        }
    }

    // MARK: - Ignored Apps

    private var ignoredAppsSection: some View {
        HexaSection(text.ignoredAppsSection) {
            Text(text.ignoredAppsCaption)
                .hexaCaption()
            if service.ignoredApps.isEmpty {
                Text(text.ignoredAppsEmpty)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgTertiary)
            } else {
                VStack(spacing: HexaTheme.Spacing.xs) {
                    ForEach(service.ignoredApps, id: \.self) { bundleID in
                        HStack(spacing: HexaTheme.Spacing.s) {
                            Text(appDisplayName(for: bundleID))
                                .font(.hexa(.body))
                                .lineLimit(1)
                            Text(bundleID)
                                .font(.hexa(.data))
                                .foregroundStyle(HexaTheme.fgTertiary)
                                .lineLimit(1)
                            Spacer()
                            Button(text.removeButton) {
                                service.removeIgnoredApp(bundleID)
                            }
                            .buttonStyle(HexaActionButtonStyle())
                            .controlSize(.small)
                        }
                    }
                }
            }
            HStack {
                Button(text.addIgnoredAppButton) {
                    pickIgnoredApp()
                }
                .buttonStyle(HexaActionButtonStyle())
                .controlSize(.small)
                Spacer()
            }
        }
    }

    private func appDisplayName(for bundleID: String) -> String {
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
           let name = running.localizedName {
            return name
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path)
        }
        return bundleID
    }

    private func pickIgnoredApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK,
              let url = panel.url,
              let bundleID = Bundle(url: url)?.bundleIdentifier else { return }
        service.addIgnoredApp(bundleID)
    }
}

private struct WindowSnapZoneTile: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.hexa(.label))
                .foregroundStyle(isActive ? HexaTheme.fgPrimary : HexaTheme.fgSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: HexaTheme.Density.rowCompact)
                .background(
                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                        .fill(isActive ? HexaTheme.selectionBg : HexaTheme.surfaceInset)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                        .strokeBorder(
                            isFocused ? HexaTheme.focusRing : (isActive ? HexaTheme.accentSolid : HexaTheme.borderHairline),
                            lineWidth: isFocused ? HexaTheme.hairline * 2 : HexaTheme.hairline
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .help(title)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }
}

private struct WindowManagerShortcutRow: View {
    @ObservedObject private var l10n = L10n.shared
    let action: WindowManagerAction
    let profile: WindowShortcutProfile
    let title: String
    let emptyTitle: String
    let isEnabled: Bool
    let hasConflict: Bool

    @AppStorage private var rawValue: String
    @State private var isRecording = false
    @State private var errorText: String?
    @State private var pendingTakeOver: GlobalShortcut?

    init(action: WindowManagerAction,
         profile: WindowShortcutProfile,
         title: String,
         emptyTitle: String,
         isEnabled: Bool,
         hasConflict: Bool) {
        self.action = action
        self.profile = profile
        self.title = title
        self.emptyTitle = emptyTitle
        self.isEnabled = isEnabled
        self.hasConflict = hasConflict
        let fallback = action.defaultShortcut(for: profile)?.storageValue
            ?? WindowManagerAction.clearedShortcutStorageValue
        _rawValue = AppStorage(wrappedValue: fallback, action.shortcutKey)
    }

    private var currentShortcut: GlobalShortcut? {
        WindowManagerAction.resolvedShortcut(storedValue: rawValue,
                                             defaultShortcut: action.defaultShortcut(for: profile))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            HStack(spacing: HexaTheme.Spacing.s) {
                Text(title)
                    .font(.hexa(.body))
                    .foregroundStyle(isEnabled ? HexaTheme.fgPrimary : HexaTheme.fgSecondary)
                    .lineLimit(1)
                Spacer(minLength: HexaTheme.Spacing.s)
                ShortcutRecorderButton(
                    shortcut: pendingTakeOver ?? currentShortcut ?? .windowLayoutLeftDefault,
                    isEnabled: isEnabled,
                    waitingTitle: l10n.s.shortcutPressKeys,
                    emptyTitle: (pendingTakeOver == nil && currentShortcut == nil) ? emptyTitle : nil,
                    clearAction: {
                        rawValue = WindowManagerAction.clearedShortcutStorageValue
                        errorText = nil
                        pendingTakeOver = nil
                        WindowManagerService.shared.setShortcut(nil, for: action)
                    },
                    notCapturedAction: { errorText = l10n.s.shortcutNotCaptured },
                    recordingChanged: { recording in
                        isRecording = recording
                        if recording {
                            errorText = nil
                            pendingTakeOver = nil
                        }
                    },
                    invalidAction: { errorText = l10n.s.shortcutInvalid },
                    captureAction: save
                )
                .controlSize(.small)
                .frame(width: 118)
                .disabled(!isEnabled)
            }
            if let errorText {
                HexaStatusNote(message: errorText)
            } else if hasConflict {
                HexaStatusNote(message: l10n.s.shortcutUnavailable)
            } else if isRecording {
                Text(ShortcutRecordingCaption.text(l10n.s, canClear: true))
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
            if let pendingTakeOver {
                SystemShortcutTakeOverOffer(
                    shortcut: pendingTakeOver,
                    onAccept: {
                        rawValue = pendingTakeOver.storageValue
                        SystemShortcutTakeover.setTakeOver(action.shortcutKey, true)
                        self.pendingTakeOver = nil
                        errorText = nil
                        WindowManagerService.shared.setShortcut(pendingTakeOver, for: action)
                    },
                    onDismiss: {
                        self.pendingTakeOver = nil
                        errorText = String(format: l10n.s.shortcutConflictFormat, "macOS")
                    }
                )
            }
        }
        .onChange(of: l10n.language) { _, _ in errorText = nil }
    }

    private func save(_ shortcut: GlobalShortcut) {
        if let conflictName = WindowManagerService.shared.conflictTitle(
            for: shortcut,
            excluding: action,
            language: l10n.language
        ) {
            errorText = String(format: l10n.s.shortcutConflictFormat, conflictName)
            return
        }
        switch SystemShortcutTakeoverSupport.recorderDecision(
            shortcut: shortcut,
            conflictsWithMacOS: SystemShortcutTakeover.conflictsWithMacOS(shortcut),
            takenOver: SystemShortcutTakeover.isTakenOver(action.shortcutKey),
            current: currentShortcut
        ) {
        case .offer:
            pendingTakeOver = shortcut
            errorText = nil
            return
        case .save(let clearTakeOver):
            rawValue = shortcut.storageValue
            errorText = nil
            if clearTakeOver {
                SystemShortcutTakeover.setTakeOver(action.shortcutKey, false)
            }
            WindowManagerService.shared.setShortcut(shortcut, for: action)
        }
    }
}
