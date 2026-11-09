// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import SwiftUI

/// The mixer as a desk: the output fader on the left, one fader per app
/// running sideways, pinned ones first. Every row action of the panel's list
/// is here: the app's menu pins, moves and routes it, Command-drag reorders,
/// a click on a level types a new one. The toolbar opens
/// the options: where sound effects go, the switches the
/// panel keeps under Options, and the hidden rows.
struct NotchMixerView: View {
    let size: CGSize
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.mixerAppArrangement) private var arrangementValue = ""
    @AppStorage(DefaultsKey.mixerHideInactiveApps) private var hideInactiveApps = false
    @State private var showingOptions = false
    @State private var editingVolumeID: String?
    @State private var draggingAppID: String?
    @State private var dropTarget: MixerAppDropTarget?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.notchSettingsPreview) private var preview
    private static let masterWidth: CGFloat = 72
    private static let columnWidth: CGFloat = 96
    private var faderHeight: CGFloat { max(104, size.height - 40) }

    private var arrangement: MixerAppArrangement { MixerAppArrangement(rawValue: arrangementValue) }

    /// The same order and the same hidden rows as the panel's list.
    private var apps: [MixerApp] {
        arrangement.ordered(mixer.apps, identity: { $0.persistenceID }).filter { app in
            MixerRoutingSupport.shouldShowApp(isPlaying: app.isPlaying, volume: app.volume,
                                              selectedOutputDeviceUID: app.selectedOutputDeviceUID,
                                              hideInactiveApps: hideInactiveApps)
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                NotchOutputDeviceMenu(width: size.width - 40, showsFullName: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                NotchIconButton(symbol: showingOptions ? "xmark" : "slider.horizontal.3",
                                title: showingOptions ? l10n.s.menuClose : l10n.s.notchMixerOptions,
                                selected: showingOptions, action: toggleOptions)
            }
            .frame(height: 32)
            if showingOptions {
                NotchMixerOptions(editingVolumeID: $editingVolumeID)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(alignment: .top, spacing: 10) {
                    NotchMasterFader(height: faderHeight, editingVolumeID: $editingVolumeID)
                        .frame(width: Self.masterWidth)
                    HairlineDivider(vertical: true)
                    desk.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { if !preview { mixer.refreshApps() } }
        // Escape closes the options before the island.
        .onChange(of: showingOptions) { _, showing in
            guard !preview else { return }
            NotchService.shared.setPageLayer(.mixer, close: showing ? closeOptions : nil)
        }
        .onDisappear { if !preview { NotchService.shared.setPageLayer(.mixer, close: nil) } }
    }

    private func toggleOptions() {
        editingVolumeID = nil
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { showingOptions.toggle() }
    }

    /// What Escape does: it only ever closes the options.
    private func closeOptions() {
        editingVolumeID = nil
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { showingOptions = false }
    }

    @ViewBuilder private var desk: some View {
        if !AppVolumeMixer.isSupported {
            NotchEmptyView(symbol: NotchModule.mixer.symbol, message: l10n.s.mixerUnavailable)
        } else if mixer.needsPermission {
            permission
        } else if apps.isEmpty {
            if mixer.isReadingApps, !mixer.hasLoadedApps {
                HexaBusyState(variant: .compact, message: l10n.s.loadingMessage)
                    .frame(maxHeight: .infinity)
            } else {
                NotchEmptyView(symbol: NotchModule.mixer.symbol, message: l10n.s.mixerEmpty)
            }
        } else {
            let apps = apps
            let ids = apps.compactMap(\.persistenceID)
            NotchRail(items: apps, rows: 1, itemWidth: Self.columnWidth,
                      width: size.width - Self.masterWidth - 21) { app in
                NotchAppFader(app: app, height: faderHeight, editingVolumeID: $editingVolumeID,
                              isPinned: arrangement.isPinned(app.persistenceID),
                              togglePin: { updateArrangement { $0.togglePin(app.persistenceID ?? "") } },
                              moveBack: moveAction(for: app, offset: -1, ids: ids),
                              moveForward: moveAction(for: app, offset: 1, ids: ids))
                    .modifier(MixerAppReorderModifier(
                        id: app.persistenceID,
                        icon: ResponsibleProcess.icon(for: app.ownerPid, pointSize: 32),
                        draggingID: $draggingAppID,
                        target: $dropTarget,
                        dragChanged: { NotchService.shared.fileDragChanged($0, internalDrag: true) },
                        canMove: { source, target in
                            ids.contains(source) && ids.contains(target)
                                && arrangement.isPinned(source) == arrangement.isPinned(target)
                        },
                        move: { source, target, after in
                            updateArrangement { $0.move(source, to: target, after: after, visibleIDs: ids) }
                        },
                        sideways: true))
                    .help(app.name + "\n" + FeatureStrings.mixer(l10n.language).arrange)
            }
        }
    }

    private func updateArrangement(_ change: (inout MixerAppArrangement) -> Void) {
        var updated = arrangement
        change(&updated)
        arrangementValue = updated.rawValue
    }

    private func moveAction(for app: MixerApp, offset: Int, ids: [String]) -> (() -> Void)? {
        guard let id = app.persistenceID,
              arrangement.neighbor(of: id, offset: offset, visibleIDs: ids) != nil else { return nil }
        return { updateArrangement { $0.move(id, offset: offset, visibleIDs: ids) } }
    }

    private var permission: some View {
        HStack(spacing: 14) {
            NotchGlyphBadge(symbol: "slider.horizontal.3")
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(l10n.s.mixerPermissionBody).font(.hexaManrope(size: 12)).foregroundStyle(HexaTheme.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(l10n.s.permissionOpenSettings) { Permissions.shared.openAudioCaptureSettings() }
                    .buttonStyle(.bordered).controlSize(.small)
            }
        }
        .padding(.horizontal, 8)
    }
}

/// A level that reads as text and, clicked, takes a typed one: the same
/// editor as the panel's rows, so the two agree on what a "150" means.
private struct NotchEditablePercent: View {
    let percent: Int
    let maximum: Int
    let editorID: String
    @Binding var editingID: String?
    let label: String
    var tint: Color = HexaTheme.fgSecondary
    var boosting = false
    var width: CGFloat = 40
    var height: CGFloat = 18
    let commit: (Double) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        EditableVolumePercent(currentPercent: percent, maximumPercent: maximum, width: width, height: height,
                              editorID: editorID, editingID: $editingID, accessibilityLabel: label) {
            HStack(spacing: 1) {
                if boosting {
                    HexaIcons.image("bolt.fill", size: 10).font(.hexa(.micro)).foregroundStyle(tint)
                }
                Text("\(percent)%")
                    .font(.hexa(.data))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: percent)
            }
            .frame(maxWidth: .infinity, minHeight: height)
        } onCommit: { commit($0) }
        .frame(height: height)
    }
}

/// The system output: its device, level and mute, in the same column shape
/// as the apps beside it.
private struct NotchMasterFader: View {
    let height: CGFloat
    @Binding var editingVolumeID: String?
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var level: Double? { mixer.systemOutputVolume.map { mixer.systemOutputMuted == true ? 0 : $0 } }
    private var muted: Bool { mixer.systemOutputMuted == true }

    /// The fader already shows the level it sets, so the open header keeps
    /// its title instead of repeating it.
    private func adjustOutput(volume: Double? = nil, muted: Bool? = nil) {
        NotchService.shared.noteOwnVolumeAdjustment()
        mixer.requestOutputAdjustment(volume: volume, muted: muted)
    }

    var body: some View {
        VStack(spacing: 6) {
            Button {
                if let muted = mixer.systemOutputMuted { adjustOutput(muted: !muted) }
            } label: {
                HexaIcons.image(muted ? "speaker.slash.fill" : "speaker.wave.2.fill", size: 15)
                    .font(.hexa(.heading))
                    .foregroundStyle(muted ? HexaTheme.fgPrimary : HexaTheme.fgPrimary)
                    .contentTransition(.opacity)
                    .animation(reduceMotion ? nil : .smooth(duration: 0.24), value: muted)
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
            }
            .buttonStyle(NotchButtonStyle(cornerRadius: HexaTheme.Radius.notch))
            .disabled(mixer.systemOutputMuted == nil)
            .accessibilityLabel(muted ? l10n.s.actionUnmute : l10n.s.actionMute)
            if let level {
                NotchLevelSlider(value: Binding(get: { level }, set: { adjustOutput(volume: $0) }),
                                 label: l10n.s.mixerSystemOutputTitle, vertical: true, trackThickness: 28)
                    .frame(width: 40, height: NotchMixerFaderLayout.trackHeight(in: height))
                NotchEditablePercent(percent: MixerRoutingSupport.volumePercent(level, maximum: 1), maximum: 100,
                                     editorID: "notch-system-output", editingID: $editingVolumeID,
                                     label: l10n.s.mixerSystemOutputTitle, height: 28) {
                    adjustOutput(volume: $0)
                }
            } else {
                Text(l10n.s.mixerOutputUnavailable).font(.hexaManrope(size: 10)).foregroundStyle(HexaTheme.fgSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .top)
    }
}

/// Both the output and app columns reserve the same header, gaps and footer.
private enum NotchMixerFaderLayout {
    static func trackHeight(in height: CGFloat) -> CGFloat {
        min(160, max(32, height - 32 - 28 - 6 * 2))
    }
}

private struct NotchOutputDeviceMenu: View {
    var width: CGFloat = 150
    var lines = 1
    var showsFullName = false
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @ObservedObject private var l10n = L10n.shared
    private var deviceName: String {
        mixer.outputDevices.first(where: { $0.uid == mixer.currentOutputDeviceUID })?.name ?? l10n.s.mixerOutputUnavailable
    }

    private var current: String { mixer.outputSwitchError ?? deviceName }
    private var items: [NotchMenuItem] {
        mixer.outputDevices.filter(\.canBeDefaultOutput).map { device in
            NotchMenuItem(title: device.name, checked: device.uid == mixer.currentOutputDeviceUID) {
                _ = mixer.setUniversalOutputDeviceUID(device.uid)
            }
        }
    }

    var body: some View {
        if showsFullName {
            NotchMenuButton(title: l10n.s.mixerSystemOutputTitle, items: items) {
                HStack(spacing: HexaTheme.Spacing.xs) {
                    Text(current)
                    HexaIcons.image("chevron.down", size: HexaIconMetrics.small)
                }
                    .font(.hexa(.body))
                    .foregroundStyle(HexaTheme.fgPrimary.opacity(0.85))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: width, minHeight: 32, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .help(current)
            .accessibilityValue(current)
        } else {
            NotchDeviceMenu(title: l10n.s.mixerSystemOutputTitle, current: current,
                            width: width, lines: lines, alignment: lines > 1 ? .center : .trailing,
                            items: items)
        }
    }
}

/// Everything the desk leaves out, in one list that scrolls down: where the
/// output and sound effects go, and the panel's options under them.
private struct NotchMixerOptions: View {
    @Binding var editingVolumeID: String?
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @ObservedObject private var l10n = L10n.shared
    private var outputDevices: [MixerOutputDevice] { mixer.outputDevices.filter(\.canBeDefaultOutput) }
    private var soundEffectsDevices: [MixerOutputDevice] { mixer.outputDevices.filter(\.canBeDefaultSystemOutput) }
    private var soundEffectsName: String {
        mixer.outputDevices.first(where: { $0.uid == mixer.currentSystemSoundOutputDeviceUID })?.name ?? l10n.s.mixerOutputUnavailable
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    row(l10n.s.mixerSystemOutputTitle, symbol: "speaker.wave.2") { NotchOutputDeviceMenu(width: 200) }
                    if outputDevices.isEmpty {
                        message(l10n.s.mixerSystemOutputNoDevices, systemImage: "speaker.slash")
                    }
                    if let error = mixer.outputSwitchError {
                        message(String(format: l10n.s.mixerSystemOutputErrorFormat, error),
                                systemImage: "exclamationmark.triangle")
                    }
                    row(l10n.s.mixerSoundEffectsOutputTitle, symbol: "bell") {
                        NotchDeviceMenu(title: l10n.s.mixerSoundEffectsOutputTitle, current: soundEffectsName,
                                        width: 200, lines: 1, alignment: .trailing,
                                        items: soundEffectsDevices.map { device in
                                            NotchMenuItem(title: device.name,
                                                          checked: device.uid == mixer.currentSystemSoundOutputDeviceUID) {
                                                _ = mixer.setSystemSoundOutputDeviceUID(device.uid)
                                            }
                                        })
                    }
                    if soundEffectsDevices.isEmpty {
                        message(l10n.s.mixerSystemOutputNoDevices, systemImage: "bell.slash")
                    }
                }
                HairlineDivider()
                MixerOptionsControls()
            }
            .padding(.trailing, 4)
            .padding(.bottom, 4)
        }
        .scrollIndicators(.automatic)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func row<Menu: View>(_ title: String, symbol: String, @ViewBuilder menu: () -> Menu) -> some View {
        HStack(spacing: 8) {
            HexaIcons.image(symbol, size: 11).font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary).frame(width: 18)
            Text(title).font(.hexaManrope(size: 11)).foregroundStyle(HexaTheme.fgSecondary).lineLimit(1)
            Spacer(minLength: 4)
            menu()
        }
        .frame(height: 22)
    }

    private func message(_ text: String, systemImage: String) -> some View {
        Label(text, hexaIcon: systemImage)
            .font(.hexaManrope(size: 9.5))
            .foregroundStyle(HexaTheme.fgSecondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// One app: an icon with actions beside it, a fader and level. The track ticks at unity, and the
/// fader turns amber in the boost range the way the panel's slider does.
/// The panel row's menu, output picker and context menu fold into the
/// column's own menu, with the route shown as a badge on the icon.
private struct NotchAppFader: View {
    let app: MixerApp
    let height: CGFloat
    @Binding var editingVolumeID: String?
    let isPinned: Bool
    let togglePin: () -> Void
    let moveBack: (() -> Void)?
    let moveForward: (() -> Void)?
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @ObservedObject private var l10n = L10n.shared
    private var strings: MixerFeatureStrings { FeatureStrings.mixer(l10n.language) }
    private var percent: Int { MixerRoutingSupport.volumePercent(app.volume, maximum: AppVolumeMixer.maxVolume) }
    private var boosting: Bool { percent > 100 }
    private var muted: Bool { app.volume <= 0.001 }
    private var routed: Bool { !app.isBypassed && app.selectedOutputDeviceUID != nil }
    private var routeDescription: String {
        if app.outputDeviceUnavailable { return l10n.s.mixerOutputFallback }
        return mixer.outputDevices.first(where: { $0.uid == app.selectedOutputDeviceUID })?.name
            ?? l10n.s.mixerOutputUnavailable
    }

    var body: some View {
        VStack(spacing: 6) {
            icon
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .help(app.name)
                .overlay(alignment: .trailing) {
                    if app.persistenceID != nil || !app.isBypassed { actionsMenu }
                }
                .overlay(alignment: .leading) {
                    if isPinned {
                        HexaIcons.image("pin.fill", size: 9).font(.hexaManrope(size: 9)).foregroundStyle(HexaTheme.fgSecondary)
                            .accessibilityLabel(strings.pinFirst)
                    }
                }
            if app.isBypassed {
                // Conferencing and pro audio apps manage their own sound: listed so
                // their absence never reads as a bug, never tapped.
                Text(l10n.s.mixerBypassedCaption)
                    .font(.hexaManrope(size: 9)).foregroundStyle(HexaTheme.fgSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                NotchLevelSlider(value: Binding(get: { app.volume }, set: { mixer.setVolume($0, for: app) }),
                                 label: app.name, range: 0...AppVolumeMixer.maxVolume,
                                 tint: HexaTheme.fgPrimary, vertical: true, trackThickness: 28, marker: 1,
                                 valueLabel: "\(percent)%")
                    .frame(width: 40, height: NotchMixerFaderLayout.trackHeight(in: height))
                NotchEditablePercent(percent: percent, maximum: Int(AppVolumeMixer.maxVolume * 100),
                                     editorID: "notch-app:\(app.id)", editingID: $editingVolumeID,
                                     label: app.name, tint: boosting ? HexaTheme.fgPrimary : HexaTheme.fgSecondary,
                                     boosting: boosting, height: 28) {
                    mixer.setVolume($0, for: app)
                }
                .frame(maxWidth: .infinity)
                .overlay(alignment: .leading) {
                    Button { mixer.setVolume(1, for: app) } label: {
                        HexaIcons.image("arrow.counterclockwise", size: 13)
                            .font(.hexa(.body))
                            .foregroundStyle(boosting ? HexaTheme.fgPrimary : HexaTheme.fgSecondary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(NotchButtonStyle(cornerRadius: HexaTheme.Radius.control))
                    .opacity(percent == 100 ? 0 : 1)
                    .disabled(percent == 100)
                    .help(l10n.s.mixerResetTooltip)
                    .accessibilityLabel(l10n.s.mixerResetTooltip)
                }
                .overlay(alignment: .trailing) {
                    Button { mixer.toggleMute(app) } label: {
                        HexaIcons.image(muted ? "speaker.slash.fill" : "speaker.wave.2.fill", size: 13)
                            .font(.hexa(.body))
                            .foregroundStyle(muted ? HexaTheme.fgPrimary : HexaTheme.fgSecondary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(NotchButtonStyle(cornerRadius: HexaTheme.Radius.control))
                    .accessibilityLabel(muted ? l10n.s.actionUnmute : l10n.s.actionMute)
                }
                .frame(height: 28)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .top)
        .contextMenu { actions }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(app.name)
        .accessibilityValue("\(percent)%")
        .accessibilityAction(named: Text(strings.moveLeft)) { moveBack?() }
        .accessibilityAction(named: Text(strings.moveRight)) { moveForward?() }
    }

    private var icon: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(nsImage: ResponsibleProcess.icon(for: app.ownerPid, pointSize: 32))
                .resizable()
                .frame(width: 28, height: 28)
            if app.isPlaying {
                Circle().fill(HexaTheme.fgPrimary).frame(width: 7, height: 7)
                    .overlay(Circle().stroke(.black, lineWidth: 1.2))
                    .offset(x: 1, y: 1)
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .bottomLeading) {
            // An app sent to its own device wears the route on its icon; the
            // panel's row shows the picker itself, which the column has no
            // room for.
            if routed {
                HexaIcons.image(app.outputDeviceUnavailable ? "exclamationmark.triangle.fill" : "arrow.triangle.branch", size: 10)
                    .font(.hexa(.micro))
                    .foregroundStyle(app.outputDeviceUnavailable ? HexaTheme.fgPrimary : HexaTheme.fgPrimary)
                    .frame(width: 12, height: 12)
                    .background(.black, in: Circle())
                    .offset(x: -2, y: 1)
                    .help(routeDescription)
                    .accessibilityLabel(routeDescription)
            }
        }
    }

    private var actionsMenu: some View {
        Menu { actions } label: {
            HexaIcons.image("ellipsis", size: 13)
                .font(.hexa(.body))
                .foregroundStyle(HexaTheme.fgPrimary.opacity(0.7))
                .frame(width: 24, height: 28)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(strings.actions)
        .accessibilityLabel("\(strings.actions): \(app.name)")
    }

    @ViewBuilder private var actions: some View {
        if app.persistenceID != nil {
            Button(action: togglePin) {
                Label(isPinned ? strings.unpin : strings.pinFirst, hexaIcon: isPinned ? "pin.slash" : "pin")
            }
            Button { moveBack?() } label: { Label(strings.moveLeft, hexaIcon: "arrow.left") }
                .disabled(moveBack == nil)
            Button { moveForward?() } label: { Label(strings.moveRight, hexaIcon: "arrow.right") }
                .disabled(moveForward == nil)
        }
        if !app.isBypassed {
            if app.persistenceID != nil { Divider() }
            Picker(l10n.s.mixerOutputTooltip, selection: outputSelection) {
                Text(l10n.s.mixerOutputDefault).tag(MixerRoutingSupport.systemDefaultSelectionID)
                ForEach(mixer.outputDevices) { device in
                    Text(device.isDefault ? "\(device.name) (\(l10n.s.mixerOutputCurrent))" : device.name).tag(device.uid)
                }
                if let selected = app.selectedOutputDeviceUID,
                   MixerRoutingSupport.needsUnavailableOutputRow(selectedUID: selected,
                                                                 isUnavailable: app.outputDeviceUnavailable,
                                                                 listedUIDs: mixer.outputDevices.map(\.uid)) {
                    Text(l10n.s.mixerOutputUnavailable).tag(selected)
                }
            }
            .pickerStyle(.menu)
            Divider()
            Button(l10n.s.mixerResetTooltip) { mixer.setVolume(1, for: app) }
                .disabled(percent == 100)
        }
        if app.persistenceID != nil {
            Divider()
            Button(l10n.s.mixerHideFromList) { mixer.hideFromList(app) }
        }
    }

    private var outputSelection: Binding<String> {
        Binding(
            get: { app.selectedOutputDeviceUID ?? MixerRoutingSupport.systemDefaultSelectionID },
            set: { selection in
                mixer.setOutputDeviceUID(selection == MixerRoutingSupport.systemDefaultSelectionID ? nil : selection,
                                         for: app)
            }
        )
    }
}
