// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

struct KeepAwakeAutomationEditor: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var awake = KeepAwakeManager.shared
    @AppStorage(DefaultsKey.keepAwakeExternalDisplay) private var externalDisplay = false
    @AppStorage(DefaultsKey.keepAwakeConnectedToPower) private var connectedToPower = false
    @AppStorage(DefaultsKey.keepAwakeRunningApps) private var runningApps = false
    @AppStorage(DefaultsKey.keepAwakeAutomationRequireAll) private var requireAll = false

    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            VStack(spacing: HexaTheme.Spacing.xs) {
                conditionRow(
                    title: strings.externalDisplayToggle,
                    icon: "display",
                    summary: externalDisplay ? strings.externalDisplayActive : strings.automationOff,
                    isOn: conditionBinding($externalDisplay)
                )
                conditionRow(
                    title: strings.powerToggle,
                    icon: "powerplug.fill",
                    summary: connectedToPower ? strings.powerActive : strings.automationOff,
                    isOn: conditionBinding($connectedToPower)
                )
                conditionRow(
                    title: strings.runningAppsToggle,
                    icon: "app.fill",
                    summary: runningApps ? strings.runningAppsActive : strings.automationOff,
                    isOn: conditionBinding($runningApps)
                )
            }
            // One condition cannot be combined with anything, so the mode
            // would be a control with no effect.
            if selectedConditionCount > 1 {
                Picker(selection: $requireAll) {
                    Text(strings.matchAny).tag(false)
                    Text(strings.matchAll).tag(true)
                } label: { EmptyView() }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(compact ? .small : .regular)
                .font(compact ? .hexa(.label) : .hexa(.body))
                .onChange(of: requireAll) { _, _ in
                    awake.automationPreferencesDidChange()
                }
            }
            if runningApps {
                AppBundleList(title: strings.runningAppsListTitle,
                              caption: strings.runningAppsListCaption,
                              addTitle: strings.runningAppsAddButton,
                              removeLabel: strings.runningAppsRemoveButton,
                              bundleIDs: awake.runningAppBundleIDs,
                              reachesEveryApp: true,
                              onAdd: { saveRunningApps(awake.runningAppBundleIDs + [$0]) },
                              onRemove: { id in saveRunningApps(awake.runningAppBundleIDs.filter { $0 != id }) })
            }
        }
    }

    private var selectedConditionCount: Int {
        [externalDisplay, connectedToPower, runningApps].filter { $0 }.count
    }

    private var strings: KeepAwakeAutomationStrings {
        FeatureStrings.keepAwakeAutomation(l10n.language)
    }

    private func saveRunningApps(_ bundleIDs: [String]) {
        let sanitized = Defaults.sanitizedBundleIdentifierList(bundleIDs)
        UserDefaults.standard.set(sanitized, forKey: DefaultsKey.keepAwakeRunningAppBundleIDs)
        awake.automationPreferencesDidChange()
    }

    /// Escrita do toggle preserva o efeito original: grava a preferência e notifica o gerenciador.
    private func conditionBinding(_ value: Binding<Bool>) -> Binding<Bool> {
        Binding(get: { value.wrappedValue },
                set: {
                    value.wrappedValue = $0
                    awake.automationPreferencesDidChange()
                })
    }

    private func conditionRow(title: String,
                              icon: String,
                              summary: String,
                              isOn: Binding<Bool>) -> some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            HexaIcons.image(icon)
                .font(.hexa(.body))
                .foregroundStyle(isOn.wrappedValue ? HexaTheme.fgPrimary : HexaTheme.fgSecondary)
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                Text(title)
                    .font(compact ? .hexa(.label) : .hexa(.body))
                    .foregroundStyle(HexaTheme.fgPrimary)
                    .lineLimit(1)
                Text(summary)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Toggle(isOn: isOn) {
                Text(title)
            }
            .labelsHidden()
            .toggleStyle(HexaSwitchStyle())
            .allowsHitTesting(false)
        }
        .padding(HexaTheme.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                .fill(isOn.wrappedValue ? HexaTheme.selectionBg : HexaTheme.surfaceInset)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                .strokeBorder(HexaTheme.borderHairline)
        )
        .contentShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
        .onTapGesture {
            isOn.wrappedValue.toggle()
        }
    }

}
