// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Advanced page: export and import of the app's settings as a file, and the
/// app's own removal (DEC-031). Both the import and the removal are
/// confirmation-gated; the removal says what it gives back before it starts.
struct AdvancedSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @State private var exported: Bool?
    @State private var importFailed = false
    @State private var importFailure: SettingsBackup.ImportFailure?
    @State private var pendingImport: [String: Any]?
    @State private var showImportConfirm = false
    @State private var showUninstallConfirm = false
    @State private var uninstalling = false
    @State private var uninstallStopped = false

    private var backup: BackupFeatureStrings {
        FeatureStrings.backup(l10n.language)
    }

    var body: some View {
        HexaScreenScaffold(title: l10n.s.tabAdvanced,
                           subtitle: FeatureStrings.generalSettings(l10n.language).advancedPageDescription) {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.l) {
                HexaSection(backup.title) {
                    Text(backup.description)
                        .hexaCaption()
                    HStack(spacing: HexaTheme.Spacing.s) {
                        Button {
                            importFailed = false
                            importFailure = nil
                            exported = SettingsBackup.runExportPanel()
                        } label: {
                            Label(backup.exportButton, hexaIcon: "square.and.arrow.up")
                        }
                        .buttonStyle(HexaActionButtonStyle())
                        Button {
                            guard let url = SettingsBackup.runImportPanel() else { return }
                            confirmImport(from: url)
                        } label: {
                            Label(backup.importButton, hexaIcon: "square.and.arrow.down")
                        }
                        .buttonStyle(HexaActionButtonStyle())
                    }
                    // The copy kept by the last import, offered as its undo.
                    if SettingsBackup.hasPreviousSettings, let url = SettingsBackup.previousSettingsURL {
                        Button {
                            confirmImport(from: url)
                        } label: {
                            Label(backup.restorePrevious, hexaIcon: "arrow.uturn.backward")
                        }
                        .buttonStyle(HexaActionButtonStyle())
                    }
                    if exported == true {
                        HexaStateTag(backup.exported, kind: .ok)
                    } else if exported == false {
                        HexaStatusNote(message: backup.exportFailed)
                    }
                    if importFailed {
                        HexaStatusNote(message: backup.invalidFile)
                    }
                    switch importFailure {
                    case .copyNotSaved: HexaStatusNote(message: backup.copyNotSaved)
                    case .relaunchNotStarted: HexaStatusNote(message: backup.restartFailed)
                    case nil: EmptyView()
                    }
                }
                HexaSection(l10n.s.advancedUninstallSection) {
                    Text(l10n.s.advancedUninstallDescription)
                        .hexaCaption()
                    Text(l10n.s.advancedUninstallRecommended)
                        .hexaCaption()
                    Button(role: .destructive) {
                        showUninstallConfirm = true
                    } label: {
                        Label(l10n.s.advancedUninstallButton, hexaIcon: "trash")
                    }
                    .buttonStyle(HexaActionButtonStyle())
                    .disabled(uninstalling)
                    // The removal runs off the main thread and waits for the
                    // helper: the muted button alone would read as a hang.
                    if uninstalling {
                        ProgressView()
                            .tint(HexaTheme.fgSecondary)
                            .controlSize(.small)
                    }
                }
            }
            .padding(.horizontal, HexaTheme.Spacing.xxl)
        }
        .alert(backup.importConfirmTitle, isPresented: $showImportConfirm) {
            Button(l10n.s.uninstallerCancel, role: .cancel) { pendingImport = nil }
            Button(backup.importAction) {
                if let pendingImport {
                    importFailure = SettingsBackup.applyAndRelaunch(settings: pendingImport)
                }
            }
        } message: {
            Text(SettingsBackupSupport.omitsDynamicIslandSettings(pendingImport ?? [:])
                 ? backup.importMissingIslandBody : backup.importConfirmBody)
        }
        .alert(l10n.s.advancedUninstallConfirmTitle, isPresented: $showUninstallConfirm) {
            Button(l10n.s.uninstallerCancel, role: .cancel) {}
            Button(l10n.s.advancedUninstallButton, role: .destructive) {
                uninstalling = true
                Uninstaller.runFromApp {
                    uninstalling = false
                    uninstallStopped = true
                }
            }
        } message: {
            Text(l10n.s.advancedUninstallConfirmBody)
        }
        // No actions: the system supplies its own, localized OK.
        .alert(l10n.s.advancedUninstallFailedTitle, isPresented: $uninstallStopped) {
        } message: {
            Text(l10n.s.advancedUninstallFailedBody)
        }
    }

    private func confirmImport(from url: URL) {
        exported = nil
        importFailed = false
        importFailure = nil
        if let settings = SettingsBackup.readSettings(at: url) {
            pendingImport = settings
            showImportConfirm = true
        } else {
            importFailed = true
        }
    }
}
