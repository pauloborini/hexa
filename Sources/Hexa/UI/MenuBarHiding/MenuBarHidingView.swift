// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import AppKit
import SwiftUI

/// The menu bar module: choose the visible and hidden sections and read what
/// ended up in each. Assignment itself is the native
/// ⌘-drag, so the page explains it instead of replacing it.
struct MenuBarHidingView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = MenuBarHidingService.shared
    @ObservedObject private var permissions = Permissions.shared

    @AppStorage(DefaultsKey.menuBarHidingEnabled) private var enabled = false
    @AppStorage(DefaultsKey.menuBarHidingRehideDelay)
    private var rehideDelay = MenuBarHidingRehideDelay.defaultValue.rawValue

    private var text: MenuBarHidingStrings { FeatureStrings.menuBarHiding(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xl) {
            HexaCard {
                SettingsRow(symbol: "menubar.dock.rectangle", title: text.title,
                            caption: text.enableCaption) {
                    Toggle(text.title, isOn: $enabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .onChange(of: enabled) { _, isOn in
                            MenuBarHidingService.shared.syncWithPreferences()
                            if isOn { permissions.requestAccessibility() }
                        }
                }
                if enabled {
                    HairlineDivider()
                    sectionRow(.visible, title: text.visible)
                    HairlineDivider()
                    sectionRow(.hidden, title: text.hidden)
                    HairlineDivider()
                    SettingsRow(symbol: "clock", title: text.rehideDelayTitle,
                                caption: text.rehideHint) {
                        Picker(text.rehideDelayTitle, selection: $rehideDelay) {
                            Text(text.rehideInstant)
                                .tag(MenuBarHidingRehideDelay.instant.rawValue)
                            Text(l10n.s.monitorInterval5)
                                .tag(MenuBarHidingRehideDelay.fiveSeconds.rawValue)
                            Text(l10n.s.monitorInterval5.replacingOccurrences(of: "5", with: "10"))
                                .tag(MenuBarHidingRehideDelay.tenSeconds.rawValue)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()
                    }
                }
            }

            if enabled {
                if case let .unavailable(reason) = service.state {
                    HexaCard {
                        Text(reason)
                            .font(.hexa(.label))
                            .foregroundStyle(HexaTheme.fgSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Button {
                    FeatureWorkspaceWindow.shared.openPermissionsHub()
                } label: {
                    Text(FeatureStrings.hub(l10n.language).viewAllPermissions)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgTertiary)
                        .underline()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, HexaTheme.Spacing.xxl)
        .onAppear {
            MenuBarHidingService.shared.syncWithPreferences()
            MenuBarHidingService.shared.refreshLayout()
        }
        .onChange(of: permissions.accessibility) { _, granted in
            if granted, enabled { MenuBarHidingService.shared.hide() }
        }
    }

    private func sectionRow(_ section: MenuBarSection, title: String) -> some View {
        let bundles = service.itemsInSections[section] ?? []
        return VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            HStack(spacing: HexaTheme.Spacing.s) {
                Text(title)
                    .font(.hexa(.body))
                Spacer(minLength: HexaTheme.Spacing.m)
                Text("\(bundles.count)")
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgTertiary)
            }
            if bundles.isEmpty {
                Text(text.emptySection)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
            } else {
                Text(bundles.map(appName).joined(separator: " · "))
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func appName(_ bundleIdentifier: String) -> String {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .first?.localizedName ?? bundleIdentifier
    }
}
