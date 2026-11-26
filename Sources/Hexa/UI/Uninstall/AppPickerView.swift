// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI
import UniformTypeIdentifiers

struct AppPickerView: View {
    @ObservedObject private var l10n = L10n.shared
    @State private var apps: [InstalledApps.InstalledApp] = []
    @State private var query = ""
    @State private var isLoading = false
    /// False until the first list arrives: the picker waits from its first frame,
    /// before `onAppear` starts the load, instead of showing "no apps found".
    @State private var hasLoadedApps = false
    @State private var isBrowsingApplications = false
    @State private var selectedAppIDs = Set<String>()

    var compact = false
    var canBrowseApplications = false
    var allowsMultipleSelection = false
    var title: String? = nil
    var loadApps: () -> [InstalledApps.InstalledApp] = { InstalledApps.installedApplications() }
    var onCancel: () -> Void
    var onSelect: (URL) -> Void
    var onSelectApp: ((InstalledApps.InstalledApp) -> Void)? = nil
    var onSelectMultiple: (([URL]) -> Void)? = nil

    init(compact: Bool = false,
         canBrowseApplications: Bool = false,
         allowsMultipleSelection: Bool = false,
         title: String? = nil,
         onCancel: @escaping () -> Void,
         onSelect: @escaping (URL) -> Void,
         onSelectApp: ((InstalledApps.InstalledApp) -> Void)? = nil,
         onSelectMultiple: (([URL]) -> Void)? = nil,
         loadApps: @escaping () -> [InstalledApps.InstalledApp] = { InstalledApps.installedApplications() }) {
        self.compact = compact
        self.canBrowseApplications = canBrowseApplications
        self.allowsMultipleSelection = allowsMultipleSelection
        self.title = title
        self.onCancel = onCancel
        self.onSelect = onSelect
        self.onSelectApp = onSelectApp
        self.onSelectMultiple = onSelectMultiple
        self.loadApps = loadApps
    }

    private var filteredApps: [InstalledApps.InstalledApp] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return apps }
        return apps.filter { app in
            app.name.localizedCaseInsensitiveContains(trimmed)
                || (app.bundleID?.localizedCaseInsensitiveContains(trimmed) ?? false)
                || (app.identity?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? HexaTheme.Spacing.s : HexaTheme.Spacing.m) {
            header
            TextField(l10n.s.uninstallerPickerSearch, text: $query)
                .textFieldStyle(.roundedBorder)
                .font(.hexa(.body))
            appList
            if allowsMultipleSelection {
                selectionFooter
            }
        }
        .padding(compact ? HexaTheme.Spacing.s : HexaTheme.Spacing.l)
        .frame(width: compact ? nil : 520, height: compact ? nil : 560)
        .onAppear { loadAppsIfNeeded() }
        .fileImporter(isPresented: $isBrowsingApplications,
                      allowedContentTypes: [.applicationBundle]) { result in
            guard let url = try? result.get() else { return }
            onSelect(url)
        }
    }

    private var header: some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            Text(title ?? l10n.s.uninstallerPickerTitle)
                .font(compact ? .hexa(.body) : .hexa(.heading))
            Spacer()
            if canBrowseApplications {
                Button {
                    isBrowsingApplications = true
                } label: {
                    Label(l10n.s.uninstallerChoose, hexaIcon: "folder")
                }
                .controlSize(compact ? .small : .regular)
            }
            Button(l10n.s.uninstallerCancel, action: onCancel)
                .controlSize(compact ? .small : .regular)
        }
    }

    @ViewBuilder
    private var appList: some View {
        let apps = filteredApps
        if isLoading || !hasLoadedApps {
            HexaBusyState(variant: .compact, message: l10n.s.loadingMessage)
                .frame(maxWidth: .infinity)
                .frame(height: compact ? 150 : 360)
        } else if apps.isEmpty {
            VStack(spacing: HexaTheme.Spacing.s) {
                HexaIcons.image("app.dashed")
                    .font(compact ? .hexa(.display(24)) : .hexa(.display(34)))
                    .foregroundStyle(HexaTheme.fgSecondary)
                Text(l10n.s.uninstallerPickerEmpty)
                    .font(.hexa(.body))
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: compact ? 150 : 360)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                    ForEach(apps) { app in
                        let selected = selectedAppIDs.contains(app.id)
                        HexaListItem(
                            nsImage: app.icon,
                            title: app.name,
                            caption: app.bundleID ?? app.url.path,
                            selected: allowsMultipleSelection && selected,
                            accessory: {
                                if allowsMultipleSelection {
                                    HexaIcons.image(selected ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selected ? HexaTheme.fgPrimary : HexaTheme.fgTertiary)
                                }
                            },
                            action: {
                                if allowsMultipleSelection {
                                    toggleSelection(for: app)
                                } else if let onSelectApp {
                                    onSelectApp(app)
                                } else {
                                    onSelect(app.url)
                                }
                            }
                        )
                    }
                }
                .padding(.vertical, HexaTheme.Spacing.xs)
            }
            .frame(height: compact ? 235 : nil)
        }
    }

    private var selectionFooter: some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            Text(String(format: l10n.s.uninstallerSelectedFormat, selectedAppIDs.count, apps.count))
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
            Spacer(minLength: 0)
            Button(l10n.s.uninstallerPickerScanSelection) {
                confirmMultipleSelection()
            }
            .buttonStyle(HexaActionButtonStyle())
            .controlSize(compact ? .small : .regular)
            .disabled(selectedAppIDs.isEmpty)
        }
    }

    private func toggleSelection(for app: InstalledApps.InstalledApp) {
        if selectedAppIDs.contains(app.id) {
            selectedAppIDs.remove(app.id)
        } else {
            selectedAppIDs.insert(app.id)
        }
    }

    private func confirmMultipleSelection() {
        let selected = apps.filter { selectedAppIDs.contains($0.id) }.map(\.url)
        guard !selected.isEmpty else { return }
        onSelectMultiple?(selected)
    }

    private func loadAppsIfNeeded() {
        guard apps.isEmpty, !isLoading else { return }
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = loadApps()
            DispatchQueue.main.async {
                apps = loaded
                isLoading = false
                hasLoadedApps = true
            }
        }
    }
}
