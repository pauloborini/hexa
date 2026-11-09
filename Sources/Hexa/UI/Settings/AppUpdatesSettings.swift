// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

struct AppUpdatesSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var updates = AppUpdatesService.shared
    @AppStorage(DefaultsKey.appUpdatesIncludeHomebrewApps) private var includeHomebrewApps = true
    @AppStorage(DefaultsKey.appUpdatesIncludeAppStore) private var includeAppStore = true
    @AppStorage(DefaultsKey.appUpdatesIncludeOnlineCatalog)
    private var includeOnlineCatalog = true
    @AppStorage(DefaultsKey.panelUtilityAppUpdates) private var showInPanel = true
    let embedded: Bool

    init(embedded: Bool = false) {
        self.embedded = embedded
    }

    private var text: AppUpdateStrings { FeatureStrings.appUpdates(l10n.language) }

    var body: some View {
        Group {
            if embedded {
                content
            } else {
                HexaScreenScaffold(title: text.pageTitle, subtitle: text.caption, scrolls: false) {
                    content
                }
            }
        }
    }

    private var content: some View {
        OverlayScrollView {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.l) {
                if !embedded {
                    HexaSection(l10n.s.updatesSection) {
                        Button(WorkspaceStrings.localized(l10n.language).viewUpdates) { FeatureWorkspaceWindow.shared.show(.appUpdates) }
                            .buttonStyle(HexaActionButtonStyle())
                    }
                }

                HexaSection(text.sourcesTitle) {
                    Toggle(text.includeHomebrewToggle, isOn: $includeHomebrewApps)
                        .toggleStyle(TrailingSwitchToggleStyle())
                        .disabled(includeHomebrewApps && enabledSourceCount == 1)
                        .onChange(of: includeHomebrewApps) { _, _ in
                            updates.sourceSelectionDidChange()
                        }
                    // Without brew the list stays silent (DEC-004); only this
                    // source says why it finds nothing.
                    if includeHomebrewApps, updates.hasCheckedThisSession,
                       !updates.packageManagerAvailable {
                        Text(text.packageMissing)
                            .hexaCaption()
                    }
                    Toggle(text.includeStoreToggle, isOn: $includeAppStore)
                        .toggleStyle(TrailingSwitchToggleStyle())
                        .disabled(includeAppStore && enabledSourceCount == 1)
                        .onChange(of: includeAppStore) { _, _ in
                            updates.sourceSelectionDidChange()
                        }
                    Text(text.includeStoreCaption)
                        .hexaCaption()
                    Toggle(text.includeOnlineToggle, isOn: $includeOnlineCatalog)
                        .toggleStyle(TrailingSwitchToggleStyle())
                        .disabled(includeOnlineCatalog && enabledSourceCount == 1)
                        .onChange(of: includeOnlineCatalog) { _, _ in
                            updates.sourceSelectionDidChange()
                        }
                    Text(text.includeOnlineCaption)
                        .hexaCaption()
                }

                HexaSection(l10n.s.tabAdvanced) {
                    Toggle(text.showInPanel, isOn: $showInPanel)
                        .toggleStyle(TrailingSwitchToggleStyle())
                }
            }
            .padding(.horizontal, HexaTheme.Spacing.xxl)
            .padding(.bottom, HexaTheme.Spacing.pageGap)
        }
    }

    private var enabledSourceCount: Int {
        [includeHomebrewApps, includeAppStore, includeOnlineCatalog].filter { $0 }.count
    }
}
