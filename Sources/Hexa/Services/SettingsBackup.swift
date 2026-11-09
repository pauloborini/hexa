// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import UniformTypeIdentifiers

/// Settings backup: writes the exportable preferences to a plist and brings
/// one back in. Importing replaces the current preferences and relaunches, so
/// every service, panel and status item comes back from a clean state instead
/// of chasing 25 live re-syncs.
enum SettingsBackup {
    /// Shows the save panel and writes the file. nil = user cancelled.
    @discardableResult
    static func runExportPanel() -> Bool? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Hexa Settings.plist"
        panel.allowedContentTypes = [.propertyList]
        panel.canCreateDirectories = true
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard let data = currentSettingsData() else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }

    private static func currentSettingsData() -> Data? {
        let defaults = UserDefaults.standard
        // object(forKey:) sees through to registered defaults, so the file is
        // a complete snapshot: importing it reproduces this exact setup even
        // where the user never touched a control.
        let payload = SettingsBackupSupport.payload(appVersion: AppInfo.version) {
            defaults.object(forKey: $0)
        }
        return try? PropertyListSerialization.data(fromPropertyList: payload, format: .xml, options: 0)
    }

    /// The settings as they were before the last import, in the export
    /// format, so an import can be undone like any other backup.
    static var previousSettingsURL: URL? {
        PrivateFileStore.containerURL?.appendingPathComponent("Settings Before Import.plist")
    }

    static var hasPreviousSettings: Bool {
        guard let url = previousSettingsURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Shows the open panel; nil = user cancelled.
    static func runImportPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.propertyList, .xml]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    /// Reads and validates a backup; nil when the file is not one of ours.
    static func readSettings(at url: URL) -> [String: Any]? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        var coordinatedData: Data?
        let coordinator = NSFileCoordinator()
        var error: NSError?
        coordinator.coordinate(readingItemAt: url, options: .withoutChanges, error: &error) { readURL in
            coordinatedData = try? Data(contentsOf: readURL)
        }
        guard let data = coordinatedData ?? (try? Data(contentsOf: url)),
              let payload = try? PropertyListSerialization.propertyList(from: data,
                                                                        options: [],
                                                                        format: nil) as? [String: Any]
        else { return nil }
        return SettingsBackupSupport.sanitizedSettings(from: payload)
    }

    enum ImportFailure {
        /// Nothing was imported: without a copy, the import could not be undone.
        case copyNotSaved
        /// The settings are in place but the app is still running on the old
        /// ones; only a quit and reopen applies them.
        case relaunchNotStarted
    }

    /// Keeps a copy of the current settings, clears the exportable keys
    /// (unset ones fall back to their registered defaults), writes the file's
    /// values and relaunches. Returns only when the app stays open.
    static func applyAndRelaunch(settings: [String: Any]) -> ImportFailure? {
        guard let copyURL = previousSettingsURL,
              let container = PrivateFileStore.containerURL,
              PrivateFileStore.createDirectory(at: container),
              let current = currentSettingsData(),
              PrivateFileStore.write(current, to: copyURL)
        else { return .copyNotSaved }
        let defaults = UserDefaults.standard
        for key in SettingsBackupSupport.keysToClear(whenImporting: settings) {
            defaults.removeObject(forKey: key)
        }
        for (key, value) in settings {
            defaults.set(value, forKey: key)
        }
        return FeatureRuntime.shared.relaunchApp() ? nil : .relaunchNotStarted
    }
}
