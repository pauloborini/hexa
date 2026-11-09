// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import SwiftUI

/// Per-app volume sliders, the mixer macOS never shipped. Shows every app
/// holding an audio connection (a green dot marks the ones playing right now).
/// 100% is untouched passthrough; below it attenuates and above it (up to 200%)
/// boosts, with the slider and percentage turning amber in the boost range.
struct MixerSection: View {
    @Environment(\.featureWorkspacePresentation) private var workspacePresentation
    @Environment(\.notchPresentation) private var inNotch
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @AppStorage(DefaultsKey.mixerAppArrangement)
    private var arrangementValue = ""
    @AppStorage(DefaultsKey.mixerHideInactiveApps)
    private var hideInactiveApps = false
    @State private var optionsExpanded = false
    @State private var normalSliderTint = HexaTheme.fgSecondary
    @State private var accentRevision = 0
    @State private var lastResolvedAccent: NSColor?
    @State private var editingVolumeID: String?
    @State private var draggingAppID: String?
    @State private var dropTarget: MixerAppDropTarget?
    var collapsible = true
    var settingsMode = false

    private var mixerStrings: MixerFeatureStrings {
        FeatureStrings.mixer(l10n.language)
    }

    var body: some View {
        Group {
            if workspacePresentation {
                workspaceControls
            } else if settingsMode {
                HexaSection(l10n.s.mixerSection) {
                    mixerControls
                }
            } else if !collapsible {
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                    SectionLabel(title: l10n.s.mixerSection)
                    mixerControls.hexaSectionCard(interactive: false)
                }
            } else {
                PanelSection(.mixer, title: l10n.s.mixerSection, collapsible: collapsible) {
                    mixerControls.panelCard(interactive: false)
                }
            }
        }
        .onReceive(NSApplication.shared.publisher(for: \.effectiveAppearance, options: [.new])) { _ in
            refreshSliderTint()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NSSystemColorsDidChangeNotification"))) { _ in
            refreshSliderTint()
        }
        .onAppear { mixer.refreshApps() }
    }

    private var workspaceControls: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.l) {
            HexaSection(l10n.s.mixerSystemOutputTitle) { audioDevicesSection }
            // Sem rótulo: o título da página já está no scaffold (DEC-017).
            HexaCard {
                if !AppVolumeMixer.isSupported { emptyLabel(l10n.s.mixerUnavailable) }
                else if mixer.needsPermission { permissionHint }
                else if visibleApps.isEmpty { emptyAppList }
                else { mixerRows }
            }
            HexaSection(mixerStrings.options) { MixerOptionsControls() }
        }
    }

    private var mixerControls: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            audioDevicesSection

            if AppVolumeMixer.isSupported, (!visibleApps.isEmpty || mixer.needsPermission) {
                HairlineDivider()
            }

            if !AppVolumeMixer.isSupported {
                emptyLabel(l10n.s.mixerUnavailable)
            } else if mixer.needsPermission {
                permissionHint
            } else if visibleApps.isEmpty {
                emptyAppList
            } else {
                mixerRows
            }

            HairlineDivider()
            optionsDisclosure
        }
    }

    private var audioDevicesSection: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            universalOutputPicker
            systemSoundOutputPicker
            if let outputSwitchError = mixer.outputSwitchError {
                inputMessage(String(format: l10n.s.mixerSystemOutputErrorFormat, outputSwitchError),
                             systemImage: "exclamationmark.triangle")
            }
        }
    }

    private var optionsDisclosure: some View {
        HexaDisclosure(isExpanded: $optionsExpanded) {
            Text(mixerStrings.options)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
        } content: {
            MixerOptionsControls()
        }
    }

    private var universalOutputPicker: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            HStack(spacing: HexaTheme.Spacing.s) {
                Label {
                    Text(l10n.s.mixerSystemOutputTitle)
                        .font(.hexa(.label))
                } icon: {
                    HexaIcons.image("speaker.wave.2.fill", size: 11)
                        .font(.hexa(.label))
                        .frame(width: 16)
                }
                .foregroundStyle(HexaTheme.fgSecondary)

                Spacer(minLength: 6)

                Picker(l10n.s.mixerSystemOutputTooltip, selection: universalOutputSelectionBinding) {
                    if mixer.currentOutputDeviceUID == nil {
                        Text(l10n.s.mixerOutputUnavailable)
                            .tag(MixerRoutingSupport.systemDefaultSelectionID)
                    }
                    ForEach(universalOutputDevices) { device in
                        Text(outputDeviceTitle(device))
                            .tag(device.uid)
                    }
                    if let selected = mixer.currentOutputDeviceUID,
                       !universalOutputDevices.contains(where: { $0.uid == selected }) {
                        Text(l10n.s.mixerOutputUnavailable)
                            .tag(selected)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(width: 164)
                .disabled(universalOutputDevices.isEmpty)
                .help(l10n.s.mixerSystemOutputTooltip)
            }

            if let volume = mixer.systemOutputVolume {
                HStack(spacing: HexaTheme.Spacing.s) {
                    HexaIcons.image(mixer.systemOutputMuted == true || volume <= 0.001
                          ? "speaker.slash.fill"
                          : "speaker.wave.2.fill", size: 11)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .frame(width: 16)

                    MixerVolumeSlider(value: systemOutputVolumeBinding,
                                      normalTint: normalSliderTint,
                                      boostTint: normalSliderTint,
                                      isBoosting: false,
                                      accentRevision: accentRevision,
                                      maximum: 1,
                                      accessibilityLabel: l10n.s.mixerSystemOutputTitle)

                    EditableVolumePercent(currentPercent: MixerRoutingSupport.volumePercent(volume, maximum: 1),
                                          maximumPercent: 100,
                                          width: 36,
                                          editorID: "system-output",
                                          editingID: $editingVolumeID,
                                          accessibilityLabel: l10n.s.mixerSystemOutputTitle) {
                        Text("\(MixerRoutingSupport.volumePercent(volume, maximum: 1))%")
                            .font(.hexa(.data))
                            .foregroundStyle(HexaTheme.fgSecondary)
                    } onCommit: {
                        setSystemOutputVolume($0)
                    }
                }
            }

            if universalOutputDevices.isEmpty {
                inputMessage(l10n.s.mixerSystemOutputNoDevices, systemImage: "speaker.slash")
            }
        }
    }

    private var systemSoundOutputPicker: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            HStack(spacing: HexaTheme.Spacing.s) {
                Label {
                    Text(l10n.s.mixerSoundEffectsOutputTitle)
                        .font(.hexa(.label))
                } icon: {
                    HexaIcons.image("bell.fill", size: 11)
                        .font(.hexa(.label))
                        .frame(width: 16)
                }
                .foregroundStyle(HexaTheme.fgSecondary)

                Spacer(minLength: 6)

                Picker(l10n.s.mixerSoundEffectsOutputTooltip,
                       selection: systemSoundOutputSelectionBinding) {
                    if mixer.currentSystemSoundOutputDeviceUID == nil {
                        Text(l10n.s.mixerOutputUnavailable)
                            .tag(MixerRoutingSupport.systemDefaultSelectionID)
                    }
                    ForEach(systemSoundOutputDevices) { device in
                        Text(systemSoundOutputDeviceTitle(device))
                            .tag(device.uid)
                    }
                    if let selected = mixer.currentSystemSoundOutputDeviceUID,
                       !systemSoundOutputDevices.contains(where: { $0.uid == selected }) {
                        Text(l10n.s.mixerOutputUnavailable)
                            .tag(selected)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(width: 164)
                .disabled(systemSoundOutputDevices.isEmpty)
                .help(l10n.s.mixerSoundEffectsOutputTooltip)
            }

            if systemSoundOutputDevices.isEmpty {
                inputMessage(l10n.s.mixerSystemOutputNoDevices, systemImage: "bell.slash")
            }
        }
    }

    private var universalOutputDevices: [MixerOutputDevice] {
        mixer.outputDevices.filter(\.canBeDefaultOutput)
    }

    private var systemSoundOutputDevices: [MixerOutputDevice] {
        mixer.outputDevices.filter(\.canBeDefaultSystemOutput)
    }

    private var universalOutputSelectionBinding: Binding<String> {
        Binding(
            get: { mixer.currentOutputDeviceUID ?? MixerRoutingSupport.systemDefaultSelectionID },
            set: { selection in
                guard selection != MixerRoutingSupport.systemDefaultSelectionID else { return }
                mixer.setUniversalOutputDeviceUID(selection)
            }
        )
    }

    private func setSystemOutputVolume(_ value: Double) {
        if inNotch {
            // The slider shows the level; the island's header need not repeat it.
            NotchService.shared.noteOwnVolumeAdjustment()
        }
        mixer.requestOutputAdjustment(volume: value)
    }

    private var systemOutputVolumeBinding: Binding<Double> {
        Binding(
            get: { mixer.systemOutputVolume ?? 0 },
            set: { setSystemOutputVolume($0) }
        )
    }

    private var systemSoundOutputSelectionBinding: Binding<String> {
        Binding(
            get: {
                mixer.currentSystemSoundOutputDeviceUID
                    ?? MixerRoutingSupport.systemDefaultSelectionID
            },
            set: { selection in
                guard selection != MixerRoutingSupport.systemDefaultSelectionID else { return }
                mixer.setSystemSoundOutputDeviceUID(selection)
            }
        )
    }

    private var arrangement: MixerAppArrangement { MixerAppArrangement(rawValue: arrangementValue) }

    private var visibleApps: [MixerApp] {
        arrangement.ordered(mixer.apps, identity: { $0.persistenceID }).filter { app in
            MixerRoutingSupport.shouldShowApp(isPlaying: app.isPlaying,
                                              volume: app.volume,
                                              selectedOutputDeviceUID: app.selectedOutputDeviceUID,
                                              hideInactiveApps: hideInactiveApps)
        }
    }

    private func outputDeviceTitle(_ device: MixerOutputDevice) -> String {
        device.isDefault ? "\(device.name) (\(l10n.s.mixerOutputCurrent))" : device.name
    }

    private func systemSoundOutputDeviceTitle(_ device: MixerOutputDevice) -> String {
        device.uid == mixer.currentSystemSoundOutputDeviceUID
            ? "\(device.name) (\(l10n.s.mixerOutputCurrent))"
            : device.name
    }

    private func inputMessage(_ text: String, systemImage: String) -> some View {
        Label(text, hexaIcon: systemImage)
            .font(.hexa(.label))
            .foregroundStyle(HexaTheme.fgSecondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var mixerRows: some View {
        rowList
    }

    @ViewBuilder
    private var rowList: some View {
        ForEach(visibleApps) { app in
            MixerRow(app: app,
                     normalTint: normalSliderTint,
                     accentRevision: accentRevision,
                     editingVolumeID: $editingVolumeID,
                     isPinned: arrangement.isPinned(app.persistenceID),
                     togglePin: { updateArrangement { $0.togglePin(app.persistenceID ?? "") } },
                     moveUp: moveAction(for: app, offset: -1),
                     moveDown: moveAction(for: app, offset: 1))
                .modifier(MixerAppReorderModifier(
                    id: app.persistenceID,
                    icon: ResponsibleProcess.icon(for: app.ownerPid, pointSize: 32),
                    draggingID: $draggingAppID,
                    target: $dropTarget,
                    dragChanged: { active in
                        if inNotch { NotchService.shared.fileDragChanged(active, internalDrag: true) }
                    },
                    canMove: { source, target in
                        let ids = visibleApps.compactMap(\.persistenceID)
                        return ids.contains(source) && ids.contains(target)
                            && arrangement.isPinned(source) == arrangement.isPinned(target)
                    },
                    move: { source, target, after in
                        updateArrangement {
                            $0.move(source, to: target, after: after,
                                    visibleIDs: visibleApps.compactMap(\.persistenceID))
                        }
                    }))
                .help(FeatureStrings.mixer(l10n.language).arrange)
        }
    }

    private func updateArrangement(_ change: (inout MixerAppArrangement) -> Void) {
        var updated = arrangement
        change(&updated)
        arrangementValue = updated.rawValue
    }

    private func moveAction(for app: MixerApp, offset: Int) -> (() -> Void)? {
        let ids = visibleApps.compactMap(\.persistenceID)
        guard let id = app.persistenceID,
              arrangement.neighbor(of: id, offset: offset, visibleIDs: ids) != nil else { return nil }
        return {
            updateArrangement {
                $0.move(id, offset: offset, visibleIDs: visibleApps.compactMap(\.persistenceID))
            }
        }
    }

    /// Recria os sliders apenas quando o token neutro resolve outra cor.
    private func refreshSliderTint() {
        var resolved: NSColor?
        NSApplication.shared.effectiveAppearance.performAsCurrentDrawingAppearance {
            resolved = NSColor(HexaTheme.fgSecondary).usingColorSpace(.sRGB)
        }
        if let resolved, let last = lastResolvedAccent, resolved == last { return }
        lastResolvedAccent = resolved
        normalSliderTint = HexaTheme.fgSecondary
        accentRevision += 1
    }

    private func emptyLabel(_ text: String) -> some View {
        Text(text)
            .font(.hexa(.label))
            .foregroundStyle(HexaTheme.fgSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, HexaTheme.Spacing.xs)
    }

    /// Until the first read lands, an empty list means nothing was read yet,
    /// not that no app is playing. After that, an empty list is a real answer.
    @ViewBuilder
    private var emptyAppList: some View {
        if mixer.isReadingApps, !mixer.hasLoadedApps {
            HexaBusyState(variant: .compact, message: l10n.s.loadingMessage)
        } else {
            emptyLabel(l10n.s.mixerEmpty)
        }
    }

    private var permissionHint: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            Text(l10n.s.mixerPermissionBody)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HexaAccessButton(icon: "hand.raised",
                             title: l10n.s.permissionOpenSettings) {
                Permissions.shared.openAudioCaptureSettings()
            }
        }
    }
}

/// The options under the routing, shared with the island's mixer page so
/// both surfaces offer the same switches: idle rows, the headphone guard,
/// the precise roller and the hidden apps.
struct MixerOptionsControls: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @ObservedObject private var preciseVolumeRoller = PreciseVolumeRollerService.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(DefaultsKey.mixerHideInactiveApps)
    private var hideInactiveApps = false
    @AppStorage(DefaultsKey.mixerLowerVolumeOnHeadphonesDisconnect)
    private var lowerOnHeadphonesDisconnect = false
    @AppStorage(DefaultsKey.mixerHeadphonesDisconnectVolumePercent)
    private var headphonesDisconnectVolumePercent = Defaults.defaultMixerHeadphonesDisconnectVolumePercent
    @AppStorage(DefaultsKey.preciseVolumeRollerEnabled)
    private var preciseVolumeRollerEnabled = false
    @State private var showListChooser = false

    var body: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            if AppVolumeMixer.isSupported {
                inactiveAppsVisibilityToggle
            }
            headphoneDisconnectProtectionToggle
            preciseVolumeRollerToggle
            if AppVolumeMixer.isSupported, !listChoices.isEmpty {
                listVisibilityFooter
            }
        }
    }

    private func inputMessage(_ text: String, systemImage: String) -> some View {
        Label(text, hexaIcon: systemImage)
            .font(.hexa(.label))
            .foregroundStyle(HexaTheme.fgSecondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var headphoneDisconnectProtectionToggle: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            Toggle(l10n.s.mixerLowerOnHeadphonesDisconnect,
                   isOn: $lowerOnHeadphonesDisconnect)
                .toggleStyle(.checkbox)
                .font(.hexa(.label))

            Text(l10n.s.mixerLowerOnHeadphonesDisconnectCaption)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if lowerOnHeadphonesDisconnect {
                HStack(spacing: HexaTheme.Spacing.s) {
                    Stepper(value: headphonesDisconnectVolumeBinding,
                            in: Defaults.minimumMixerHeadphonesDisconnectVolumePercent...100,
                            step: 5) {
                        Text(l10n.s.mixerHeadphonesDisconnectVolume)
                            .font(.hexa(.label))
                    }
                    .controlSize(.small)
                    Spacer(minLength: 6)
                    Text("\(headphonesDisconnectDisplayPercent)%")
                        .font(.hexa(.data))
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .frame(width: 38, alignment: .trailing)
                }
            }
        }
    }

    private var headphonesDisconnectVolumeBinding: Binding<Int> {
        Binding(
            get: { Defaults.sanitizedMixerHeadphonesDisconnectVolumePercent(headphonesDisconnectVolumePercent) },
            set: { headphonesDisconnectVolumePercent = Defaults.sanitizedMixerHeadphonesDisconnectVolumePercent($0) }
        )
    }

    private var headphonesDisconnectDisplayPercent: Int {
        Defaults.sanitizedMixerHeadphonesDisconnectVolumePercent(headphonesDisconnectVolumePercent)
    }

    private var preciseVolumeRollerToggle: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            Toggle(l10n.s.preciseVolumeRollerEnable, isOn: $preciseVolumeRollerEnabled)
                .toggleStyle(.checkbox)
                .font(.hexa(.label))
                .onChange(of: preciseVolumeRollerEnabled) { _, enabled in
                    if enabled { permissions.requestAccessibility() }
                    PreciseVolumeRollerService.shared.syncWithPreferences()
                }

            Text(l10n.s.preciseVolumeRollerCaption)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if preciseVolumeRollerEnabled, !permissions.accessibility {
                HexaAccessButton(icon: "hand.raised", title: l10n.s.permissionOpenSettings) {
                    Permissions.shared.openAccessibilitySettings()
                }
            } else if preciseVolumeRoller.tapFailed {
                inputMessage(l10n.s.preciseVolumeRollerTapFailed,
                             systemImage: "exclamationmark.triangle")
            }
        }
    }

    /// One entry per app the list knows about: visible rows checked, hidden
    /// apps unchecked, everything in one alphabetical run so the menu reads
    /// like the list itself.
    private struct MixerListChoice: Identifiable {
        let id: String
        let name: String
        let isListed: Bool
        /// A row with nothing stable to remember it by cannot be hidden; it
        /// still shows here so the menu mirrors the list.
        let canToggle: Bool
    }

    private var listChoices: [MixerListChoice] {
        // The hidden list updates the moment a box is unchecked, while the
        // visible rows only change when the next HAL refresh lands. Keyed by
        // persistence id with the hidden entry winning, a just-hidden app
        // shows up once (unchecked) instead of twice during that gap.
        var seen = Set<String>()
        var choices = mixer.hiddenApps.map { hidden -> MixerListChoice in
            seen.insert(hidden.id)
            return MixerListChoice(id: hidden.id, name: hidden.name, isListed: false, canToggle: true)
        }
        for app in mixer.apps {
            let id = app.persistenceID ?? app.id
            guard seen.insert(id).inserted else { continue }
            choices.append(MixerListChoice(id: id, name: app.name,
                                           isListed: true, canToggle: app.persistenceID != nil))
        }
        choices.sort {
            MixerRoutingSupport.displayOrderedBefore(name: $0.name, id: $0.id,
                                                     otherName: $1.name, otherID: $1.id)
        }
        return choices
    }

    /// Which apps the list shows: the row reads how many are
    /// hidden and opens a check per app, right in the panel so several can be
    /// checked or unchecked in one go. Hidden apps stay here even while they
    /// are not running, so they can always be brought back.
    private var listVisibilityFooter: some View {
        HexaDisclosure(isExpanded: $showListChooser) {
            HStack(spacing: HexaTheme.Spacing.s) {
                Text(l10n.s.mixerVisibleApps)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                Spacer(minLength: 6)
                Text(mixer.hiddenApps.isEmpty
                     ? l10n.s.mixerAllShown
                     : "\(l10n.s.mixerHiddenCountLabel): \(mixer.hiddenApps.count)")
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
        } content: {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                ForEach(listChoices) { choice in
                    Toggle(isOn: listedBinding(for: choice)) {
                        Text(choice.name)
                            .font(.hexa(.label))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                    .disabled(!choice.canToggle)
                }
            }
        }
    }

    private func listedBinding(for choice: MixerListChoice) -> Binding<Bool> {
        Binding(
            get: { choice.isListed },
            set: { listed in
                if listed {
                    mixer.showInList(id: choice.id)
                } else if let app = mixer.apps.first(where: { ($0.persistenceID ?? $0.id) == choice.id }) {
                    mixer.hideFromList(app)
                }
            }
        )
    }

    private var inactiveAppsVisibilityToggle: some View {
        let label = FeatureStrings.mixer(l10n.language).hideInactiveApps
        return HStack(spacing: HexaTheme.Spacing.s) {
            Text(label)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
            Spacer(minLength: 6)
            Toggle(label, isOn: $hideInactiveApps)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .accessibilityLabel(label)
        }
    }
}

private struct MixerRow: View {
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isResetFocused: Bool
    @FocusState private var isMuteFocused: Bool
    let app: MixerApp
    let normalTint: Color
    let accentRevision: Int
    @Binding var editingVolumeID: String?
    let isPinned: Bool
    let togglePin: () -> Void
    let moveUp: (() -> Void)?
    let moveDown: (() -> Void)?

    private var arrangementStrings: MixerFeatureStrings { FeatureStrings.mixer(l10n.language) }

    /// Warm accent to flag the boost range, darkened in Light Mode for contrast.
    private var boostColor: Color { PanelMetricColor.orange(for: colorScheme) }
    /// Tie the visual state to the displayed percentage, so "amber" and ">100%"
    /// always agree and the reset hides exactly when the row reads 100%.
    private var isBoosting: Bool { (app.volume * 100).rounded() > 100 }
    private var isAtUnity: Bool { (app.volume * 100).rounded() == 100 }

    /// Large icon spanning the row's two lines; the
    /// bitmap must be requested at this size or the upscale looks blurry.
    private static let iconPointSize: CGFloat = 32

    var body: some View {
        HStack(alignment: .center, spacing: HexaTheme.Spacing.s) {
            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: ResponsibleProcess.icon(for: app.ownerPid,
                                                       pointSize: Self.iconPointSize))
                    .resizable()
                    .frame(width: Self.iconPointSize, height: Self.iconPointSize)
                if app.isPlaying {
                    Circle()
                        .fill(HexaTheme.statusOk)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(HexaTheme.surfaceRaised, lineWidth: 1.2))
                        .offset(x: -1, y: -1)
                }
            }

            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                HStack(spacing: HexaTheme.Spacing.s) {
                    Text(app.name)
                        .font(.hexa(.body))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if isPinned {
                        HexaIcons.image("pin.fill", size: 9)
                            .foregroundStyle(HexaTheme.fgSecondary)
                            .accessibilityLabel(arrangementStrings.pin)
                    }
                    Spacer(minLength: 4)

                    if app.persistenceID != nil {
                        Menu { arrangementActions } label: {
                            HexaIcons.image("ellipsis")
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize()
                        .help(isPinned ? arrangementStrings.unpin : arrangementStrings.pin)
                        .accessibilityLabel("\(isPinned ? arrangementStrings.unpin : arrangementStrings.pin): \(app.name)")
                    }
                    if !app.isBypassed {
                        outputPicker
                    }
                }

                if app.isBypassed {
                    // Zoom and pro audio apps are listed but never tapped:
                    // the row explains itself instead of the
                    // app silently missing from the mixer.
                    Text(l10n.s.mixerBypassedCaption)
                        .font(.hexa(.body))
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    HStack(spacing: HexaTheme.Spacing.s) {
                        MixerVolumeSlider(value: volumeBinding,
                                          normalTint: normalTint,
                                          boostTint: boostColor,
                                          isBoosting: isBoosting,
                                          accentRevision: accentRevision,
                                          maximum: AppVolumeMixer.maxVolume,
                                          accessibilityLabel: app.name)

                        EditableVolumePercent(currentPercent: MixerRoutingSupport.volumePercent(app.volume, maximum: AppVolumeMixer.maxVolume),
                                              maximumPercent: Int(AppVolumeMixer.maxVolume * 100),
                                              width: 42,
                                              editorID: "app:\(app.id)",
                                              editingID: $editingVolumeID,
                                              accessibilityLabel: app.name) {
                            HStack(spacing: HexaTheme.Spacing.xs) {
                                if isBoosting {
                                    HexaIcons.image("bolt.fill", size: 10)
                                        .font(.hexa(.micro))
                                        .foregroundStyle(boostColor)
                                }
                                Text("\(MixerRoutingSupport.volumePercent(app.volume, maximum: AppVolumeMixer.maxVolume))%")
                                    .font(.hexa(.data))
                                    .foregroundStyle(isBoosting ? boostColor : HexaTheme.fgSecondary)
                            }
                        } onCommit: {
                            mixer.setVolume($0, for: app)
                        }

                        Button {
                            mixer.setVolume(1, for: app)
                        } label: {
                            HexaIcons.image("arrow.counterclockwise", size: 10)
                                .font(.hexa(.micro))
                                .foregroundStyle(isBoosting ? boostColor : HexaTheme.fgSecondary)
                                .frame(width: 14)
                        }
                        .buttonStyle(.plain)
                        .focused($isResetFocused)
                        .overlay {
                            RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                                .strokeBorder(isResetFocused ? HexaTheme.focusRing : .clear, lineWidth: 2)
                        }
                        .help(l10n.s.mixerResetTooltip)
                        .opacity(isAtUnity ? 0 : 1)
                        .disabled(isAtUnity)

                        Button {
                            mixer.toggleMute(app)
                        } label: {
                            HexaIcons.image(app.volume <= 0.001 ? "speaker.slash.fill" : "speaker.wave.2.fill", size: 10)
                                .foregroundStyle(app.volume <= 0.001
                                                 ? HexaTheme.statusWarning
                                                 : HexaTheme.fgSecondary)
                                .frame(width: 16)
                        }
                        .buttonStyle(.plain)
                        .focused($isMuteFocused)
                        .overlay {
                            RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                                .strokeBorder(isMuteFocused ? HexaTheme.focusRing : .clear, lineWidth: 2)
                        }
                        .accessibilityLabel(app.volume <= 0.001 ? l10n.s.actionUnmute : l10n.s.actionMute)
                    }

                    if app.outputDeviceUnavailable {
                        Label(l10n.s.mixerOutputFallback, hexaIcon: "speaker.badge.exclamationmark")
                            .font(.hexa(.label))
                            .foregroundStyle(HexaTheme.fgSecondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        // geometria de plataforma (spec §4): micro-respiro vertical de 2 pt da
        // linha do mixer, fora da escala (mínimo 4); mudar alteraria a
        // densidade aprovada do painel.
        .padding(.vertical, 2)
        .accessibilityAction(named: Text(arrangementStrings.moveUp)) { moveUp?() }
        .accessibilityAction(named: Text(arrangementStrings.moveDown)) { moveDown?() }
        .contextMenu {
            if app.persistenceID != nil {
                arrangementActions
                Divider()
                Button(l10n.s.mixerHideFromList) {
                    mixer.hideFromList(app)
                }
            }
        }
    }

    @ViewBuilder
    private var arrangementActions: some View {
        Button(action: togglePin) {
            Label(isPinned ? arrangementStrings.unpin : arrangementStrings.pin,
                  hexaIcon: isPinned ? "pin.slash" : "pin")
        }
    }

    private var volumeBinding: Binding<Double> {
        Binding(
            get: { app.volume },
            set: { mixer.setVolume($0, for: app) }
        )
    }

    private var outputPicker: some View {
        Picker(l10n.s.mixerOutputTooltip, selection: outputSelectionBinding) {
            Text(l10n.s.mixerOutputDefault)
                .tag(MixerRoutingSupport.systemDefaultSelectionID)
            ForEach(mixer.outputDevices) { device in
                Text(outputDeviceTitle(device))
                    .tag(device.uid)
            }
            if let selected = app.selectedOutputDeviceUID,
               MixerRoutingSupport.needsUnavailableOutputRow(selectedUID: selected,
                                                             isUnavailable: app.outputDeviceUnavailable,
                                                             listedUIDs: mixer.outputDevices.map(\.uid)) {
                Text(l10n.s.mixerOutputUnavailable)
                    .tag(selected)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .controlSize(.small)
        .frame(width: 112)
        .help(l10n.s.mixerOutputTooltip)
    }

    private var outputSelectionBinding: Binding<String> {
        Binding(
            get: { app.selectedOutputDeviceUID ?? MixerRoutingSupport.systemDefaultSelectionID },
            set: { selection in
                mixer.setOutputDeviceUID(selection == MixerRoutingSupport.systemDefaultSelectionID ? nil : selection,
                                         for: app)
            }
        )
    }

    private func outputDeviceTitle(_ device: MixerOutputDevice) -> String {
        device.isDefault ? "\(device.name) (\(l10n.s.mixerOutputCurrent))" : device.name
    }
}

/// The percentage keeps its compact read-only appearance until clicked, then
/// becomes a selected text field so the next keystroke replaces the old value.
struct EditableVolumePercent<Label: View>: View {
    let currentPercent: Int
    let maximumPercent: Int
    let width: CGFloat
    var height: CGFloat = 18
    let editorID: String
    @Binding var editingID: String?
    let accessibilityLabel: String
    @ViewBuilder let label: () -> Label
    let onCommit: (Double) -> Void

    @State private var draft = ""

    private var isEditing: Bool { editingID == editorID }

    var body: some View {
        ZStack {
            HStack(spacing: HexaTheme.Spacing.xs) {
                AutofocusingVolumeTextField(text: $draft,
                                            isActive: isEditing,
                                            accessibilityLabel: accessibilityLabel,
                                            onSubmit: commit,
                                            onCancel: cancel)
                Text("%")
                    .font(.hexa(.micro))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, HexaTheme.Spacing.xs)
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                    .fill(HexaTheme.surfaceInset)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                    .strokeBorder(HexaTheme.focusRing, lineWidth: 1)
            )
            .opacity(isEditing ? 1 : 0)
            .allowsHitTesting(isEditing)
            .accessibilityHidden(!isEditing)

            Button(action: beginEditing) {
                label()
                    .frame(width: width, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(isEditing ? 0 : 1)
            .allowsHitTesting(!isEditing)
            .accessibilityLabel("\(accessibilityLabel) \(currentPercent)%")
            .accessibilityHidden(isEditing)
        }
        .frame(width: width, alignment: .trailing)
    }

    private func beginEditing() {
        draft = String(currentPercent)
        editingID = editorID
    }

    @discardableResult
    private func commit() -> Bool {
        guard let volume = MixerRoutingSupport.volumeFraction(
            fromPercentageText: draft,
            maximumPercent: maximumPercent
        ) else {
            NSSound.beep()
            return false
        }
        onCommit(volume)
        editingID = nil
        return true
    }

    private func cancel() {
        if isEditing { editingID = nil }
    }
}

/// A native field is used because an NSPopover can attach its SwiftUI backing
/// view after a FocusState request has already fired. The field retries when it
/// joins the window, then owns Return, Escape and loss-of-focus behavior.
private struct AutofocusingVolumeTextField: NSViewRepresentable {
    @Binding var text: String
    let isActive: Bool
    let accessibilityLabel: String
    let onSubmit: () -> Bool
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text,
                    isActive: isActive,
                    onSubmit: onSubmit,
                    onCancel: onCancel)
    }

    func makeNSView(context: Context) -> MixerPercentNativeTextField {
        let field = MixerPercentNativeTextField()
        field.delegate = context.coordinator
        context.coordinator.field = field
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.alignment = .right
        field.font = HexaTheme.dataFont(size: 11.5, weight: .medium)
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.isEnabled = isActive
        field.isHidden = !isActive
        field.setAccessibilityLabel(accessibilityLabel)
        field.didAttachToWindow = { [weak field, weak coordinator = context.coordinator] in
            guard let field else { return }
            coordinator?.focusIfNeeded(field)
        }
        return field
    }

    func updateNSView(_ field: MixerPercentNativeTextField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.onSubmit = onSubmit
        context.coordinator.onCancel = onCancel
        field.setAccessibilityLabel(accessibilityLabel)
        if field.stringValue != text { field.stringValue = text }
        context.coordinator.setActive(isActive, field: field)
    }

    static func dismantleNSView(_ field: MixerPercentNativeTextField,
                                coordinator: Coordinator) {
        coordinator.stopMonitoringEscape()
        field.didAttachToWindow = nil
        field.delegate = nil
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        private var isActive: Bool
        var onSubmit: () -> Bool
        var onCancel: () -> Void
        weak var field: MixerPercentNativeTextField?
        private var didFocus = false
        private var isFinishing = false
        private var escapeMonitor: Any?

        init(text: Binding<String>,
             isActive: Bool,
             onSubmit: @escaping () -> Bool,
             onCancel: @escaping () -> Void) {
            self.text = text
            self.isActive = isActive
            self.onSubmit = onSubmit
            self.onCancel = onCancel
            super.init()
            if isActive { startMonitoringEscape() }
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard isActive, didFocus, !isFinishing,
                  let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
            isFinishing = true
            if !onSubmit() { onCancel() }
        }

        func control(_ control: NSControl,
                     textView: NSTextView,
                     doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                text.wrappedValue = (control as? NSTextField)?.stringValue ?? text.wrappedValue
                if onSubmit() { isFinishing = true }
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                finish(onCancel)
                return true
            }
            return false
        }

        func focusIfNeeded(_ field: MixerPercentNativeTextField) {
            guard isActive, !didFocus else { return }
            DispatchQueue.main.async { [weak self, weak field] in
                guard let self, let field, self.isActive, !self.didFocus else { return }
                if field.focusAndSelectAll() { self.didFocus = true }
            }
        }

        func setActive(_ active: Bool, field: MixerPercentNativeTextField) {
            if active != isActive {
                isActive = active
                didFocus = false
                isFinishing = false
                if active {
                    field.isHidden = false
                    field.isEnabled = true
                    startMonitoringEscape()
                } else {
                    stopMonitoringEscape()
                    field.isEnabled = false
                    field.isHidden = true
                }
            }
            if active { focusIfNeeded(field) }
        }

        private func startMonitoringEscape() {
            guard escapeMonitor == nil else { return }
            escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                // The monitor sees the whole app; Escape in another window,
                // such as Settings, stays there.
                guard let self, self.isActive, event.keyCode == 53,
                      let window = self.field?.window, event.window === window else { return event }
                // While an input method is composing, Esc belongs to it and
                // drops the candidate; the next one cancels the level.
                if (window.firstResponder as? NSTextView)?.hasMarkedText() == true { return event }
                self.finish(self.onCancel)
                return nil
            }
        }

        func stopMonitoringEscape() {
            guard let escapeMonitor else { return }
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }

        private func finish(_ action: () -> Void) {
            guard !isFinishing else { return }
            isFinishing = true
            action()
        }
    }
}

private struct MixerVolumeSlider: View {
    @Binding var value: Double
    let normalTint: Color
    let boostTint: Color
    let isBoosting: Bool
    let accentRevision: Int
    let maximum: Double
    let accessibilityLabel: String

    private var activeTint: Color { isBoosting ? boostTint : normalTint }
    private var percentage: Int { MixerRoutingSupport.volumePercent(value, maximum: maximum) }

    var body: some View {
        nativeSlider
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue("\(percentage)%")
    }

    private var nativeSlider: some View {
        Slider(value: $value, in: 0...maximum)
            .controlSize(.small)
            // Pass an explicit accent (not nil) for the normal state: on the
            // macOS slider, tint(nil) does not reliably clear a previously
            // applied colour, so the bar would stay amber after leaving boost.
            .tint(activeTint)
            .id(accentRevision)
    }
}
