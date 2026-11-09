// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import AppKit
import SwiftUI

/// The Dock module: hold the Dock to one display, choose which one, and call
/// it back after sleep or a display change. The page is both the operation and
/// its settings, per DEC-014.
struct DockDisplayLockView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = DockDisplayLockService.shared
    @ObservedObject private var permissions = Permissions.shared

    @AppStorage(DefaultsKey.dockDisplayLockEnabled) private var enabled = false
    @AppStorage(DefaultsKey.dockDisplayLockTarget) private var targetStorage = DockDisplayLockTarget.mainStorage
    @AppStorage(DefaultsKey.dockDisplayLockReturns) private var returnsAfterWake = false

    private var text: DockDisplayLockStrings { FeatureStrings.dockDisplayLock(l10n.language) }

    private var target: DockDisplayLockTarget { DockDisplayLockTarget(storage: targetStorage) }

    private var choiceIsAway: Bool {
        switch target {
        case .main: return false
        case .builtIn: return !service.displays.contains(where: \.isBuiltIn)
        case let .display(uuid): return !service.displays.contains { $0.uuid == uuid }
        }
    }

    /// A remembered display that is not connected gets its own row so the
    /// picker does not show an empty selection. A built-in one stays in its
    /// own row, which is drawn even when the Mac is closed.
    private var disconnectedChoice: DockDisplayLockTarget? {
        guard case let .display(uuid) = target,
              !service.displays.contains(where: { $0.uuid == uuid }) else { return nil }
        return target
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xl) {
            HexaCard {
                SettingsRow(symbol: "panel-bottom", title: text.title,
                            caption: text.enableCaption) {
                    Toggle(text.title, isOn: $enabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .onChange(of: enabled) { _, isOn in
                            DockDisplayLockService.shared.syncWithPreferences()
                            if isOn {
                                permissions.requestAccessibility()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    DockDisplayLockService.shared.moveDockToAnchor()
                                }
                            }
                        }
                }
                if enabled {
                    HairlineDivider()
                    displayRow
                    HairlineDivider()
                    statusRow
                    HairlineDivider()
                    SettingsRow(symbol: "arrow.uturn.backward", title: text.returnsToggle,
                                caption: text.returnsCaption) {
                        Toggle(text.returnsToggle, isOn: $returnsAfterWake)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }
            }

            if enabled, !permissions.accessibility {
                HexaSection(l10n.s.permissionAccessibility) {
                    Text(text.needsAccessibility).hexaCaption()
                    Button(l10n.s.permissionRequest) { permissions.openAccessibilitySettings() }
                        .buttonStyle(HexaActionButtonStyle())
                }
            }
        }
        .padding(.horizontal, HexaTheme.Spacing.xxl)
        .onAppear {
            DockDisplayLockService.shared.refresh()
            DockDisplayLockService.shared.syncWithPreferences()
        }
        .onDisappear { DockDisplayLockService.shared.readDockDisplay() }
    }

    private var displayRow: some View {
        SettingsRow(symbol: "display", title: text.displayPicker,
                    caption: choiceIsAway ? text.fallbackNote : nil) {
            Picker(text.displayPicker, selection: targetBinding) {
                Text(text.mainDisplay).tag(DockDisplayLockTarget.main)
                if service.displays.contains(where: \.isBuiltIn) || target == .builtIn {
                    Text(text.builtInDisplay).tag(DockDisplayLockTarget.builtIn)
                }
                ForEach(service.displays) { display in
                    Text(displayName(display)).tag(DockDisplayLockTarget.display(uuid: display.uuid))
                }
                if let disconnectedChoice {
                    Text(text.disconnectedDisplay).tag(disconnectedChoice)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 240)
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        if service.displays.count < 2 {
            notAvailableNote(text.singleDisplay)
        } else if !service.separateSpacesOn {
            notAvailableNote(text.spacesOff)
        } else if let dock = service.displays.first(where: { $0.id == service.dockDisplayID }) {
            HStack(spacing: HexaTheme.Spacing.m) {
                Label(String(format: text.dockLocationFormat, displayName(dock)),
                      systemImage: dock.id == service.anchorID ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                Spacer(minLength: HexaTheme.Spacing.m)
                if dock.id != service.anchorID, permissions.accessibility {
                    Button(text.moveButton) { DockDisplayLockService.shared.moveDockToAnchor() }
                        .buttonStyle(HexaActionButtonStyle())
                        .disabled(service.isMovingDock)
                }
            }
        } else {
            HStack(spacing: HexaTheme.Spacing.m) {
                Label(text.dockUnknown, systemImage: "questionmark.circle")
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                Spacer(minLength: HexaTheme.Spacing.m)
                if service.isRunning {
                    Text(String(format: text.runningFormat, service.displays.count))
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgTertiary)
                }
            }
        }
    }

    private func notAvailableNote(_ message: String) -> some View {
        HStack(alignment: .top, spacing: HexaTheme.Spacing.s) {
            HexaIcons.image("info.circle", size: 13)
                .foregroundStyle(HexaTheme.fgSecondary)
            Text(message)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func displayName(_ display: DockDisplayLockDisplay) -> String {
        let name = display.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? text.mainDisplay : name
    }

    /// A chosen display that is not connected right now: the choice stays,
    /// and the picker says so instead of showing the fallback.
    private var targetBinding: Binding<DockDisplayLockTarget> {
        Binding {
            target
        } set: { newValue in
            targetStorage = newValue.storageValue
            DockDisplayLockService.shared.refresh()
            // Once the picker's menu has closed: called while it was still
            // closing, the press on the edge left the Dock where it was.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                DockDisplayLockService.shared.moveDockToAnchor()
            }
        }
    }
}
