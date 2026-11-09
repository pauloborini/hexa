// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest
@testable import Hexa

final class SettingsBackupSupportTests: XCTestCase {
    private let discardedPreferences = [
        "audioPriorityOutputEnabled", "audioPriorityInputEnabled",
        "audioPriorityOutputUIDs", "audioPriorityInputUIDs", "audioPriorityDeviceNames",
        "autoQuitExceptions", "quitProtectionQuitEnabled", "quitProtectionCloseEnabled",
        "shelfShortcutEnabled", "shelfItems", "switcherEnabled", "switcherPreviewSize",
        "mouseNavigationEnabled", "smoothScrollEnabled", "scrollInverterEnabled",
        "dockPreviewEnabled", "spacesOrderEnabled", "finderRenameEnabled",
        "diskImageInstallerTrashesDownload", "finderPasteImageAsFile",
        "homebrewGroupDependencies", "scratchpadShortcutEnabled",
        "quickLauncherShortcutEnabled", "quickLauncherItemOrder",
        "urlCleanerEnabled", "windowMaximizeEnabled", "keyboardDebounceEnabled",
        "micMuteShortcutEnabled", "micMuteActive", "panelUtilityScreenRecorder",
        "clipboardHistoryEnabled", "clipboardHistoryShortcutEnabled",
        "clipboardAutoClearOnDelay", "textSnippetsEnabled", "snippetLibraryEnabled",
        "panelControlMouseScroll", "radialMenuEnabled",
        "featuresOnboardingVersion", "hasOnboarded",
        // ISSUE-534: the WhatsApp features left the app.
        "whatsAppDownloadsEnabled", "whatsAppDownloadsCategories",
        "whatsAppOrganizerEnabled", "whatsAppOrganizerRecords", "whatsAppOrganizerUndoTransaction",
        // Preferences and layouts of features that left the app.
        "cameraPreviewShortcutEnabled", "cameraPreviewShortcut",
        "notchCameraEnabled", "notchMusicActivity", "notchHideInCaptures",
        "panelToggleOrder", "panelControlOrder",
        "panelToggleDarkMode", "panelToggleKeyboardLight", "panelUtilityMicMute",
        "panelToggleEmptyTrash", "panelToggleEjectDisks", "panelToggleHiddenFiles",
        "panelToggleDesktopIcons", "panelToggleLockScreen", "panelToggleDisplayOff",
        "panelToggleScreenSaver", "pastePlainEnabled", "pastePlainShortcut",
    ]

    func testDiscardedPreferencesAreNotExportable() {
        let keys = SettingsBackupSupport.exportKeys()
        for key in discardedPreferences {
            XCTAssertFalse(keys.contains(key), key)
        }
    }

    func testOldBackupCannotReintroduceDiscardedPreferences() throws {
        var settings = Dictionary(uniqueKeysWithValues: discardedPreferences.map {
            ($0, Defaults.registeredDefaults[$0] ?? true)
        })
        settings[DefaultsKey.appearance] = "dark"
        let restored = try XCTUnwrap(SettingsBackupSupport.sanitizedSettings(from: [
            SettingsBackupSupport.formatVersionKey: 1,
            SettingsBackupSupport.settingsKey: settings,
        ]))
        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(restored[DefaultsKey.appearance] as? String, "dark")
    }

    func testPayloadDoesNotReadDiscardedPreferences() throws {
        var requestedKeys = Set<String>()
        let payload = SettingsBackupSupport.payload(appVersion: "1.0.0") { key in
            requestedKeys.insert(key)
            return key == DefaultsKey.language ? "pt-BR" : nil
        }
        let settings = try XCTUnwrap(payload[SettingsBackupSupport.settingsKey] as? [String: Any])
        XCTAssertEqual(settings.count, 1)
        XCTAssertEqual(settings[DefaultsKey.language] as? String, "pt-BR")
        XCTAssertTrue(requestedKeys.isDisjoint(with: discardedPreferences))
    }

    func testCurrentPreferencesAndLegacyNotchKeysRemainRestorable() throws {
        let settings: [String: Any] = [
            DefaultsKey.language: "pt-BR",
            DefaultsKey.appearance: "dark",
            DefaultsKey.clamshellPreferred: true,
            DefaultsKey.notchEnabled: true,
            DefaultsKey.notchQuickAccessLayout: Data(),
            DefaultsKey.notchQuickAccessSide: "volume",
            DefaultsKey.notchQuickAccessSecond: "brightness",
            DefaultsKey.notchQuickAccessThird: "settings",
        ]
        let restored = try XCTUnwrap(SettingsBackupSupport.sanitizedSettings(from: [
            SettingsBackupSupport.formatVersionKey: 1,
            SettingsBackupSupport.settingsKey: settings,
        ]))
        XCTAssertEqual(Set(restored.keys), Set(settings.keys))
        XCTAssertEqual(restored[DefaultsKey.notchQuickAccessSecond] as? String, "brightness")
        XCTAssertEqual(restored[DefaultsKey.notchQuickAccessLayout] as? Data, Data())
        XCTAssertEqual(restored[DefaultsKey.clamshellPreferred] as? Bool, true)
    }

    func testBackupWithoutIslandSettingsDoesNotClearIslandPreferences() {
        let keys = SettingsBackupSupport.keysToClear(whenImporting: [
            DefaultsKey.appearance: "dark",
        ])
        XCTAssertTrue(keys.contains(DefaultsKey.appearance))
        XCTAssertFalse(keys.contains(DefaultsKey.notchEnabled))
        XCTAssertFalse(keys.contains(DefaultsKey.notchQuickAccessLayout))
        XCTAssertFalse(keys.contains(DefaultsKey.notchQuickAccessSide))
        XCTAssertFalse(keys.contains(DefaultsKey.panelControlNotch))
    }

    func testExplicitIslandBackupStillReplacesIslandPreferences() {
        let keys = SettingsBackupSupport.keysToClear(whenImporting: [
            DefaultsKey.notchEnabled: true,
        ])
        XCTAssertTrue(keys.contains(DefaultsKey.notchQuickAccessLayout))
        XCTAssertTrue(keys.contains(DefaultsKey.notchQuickAccessSide))
        XCTAssertTrue(keys.contains(DefaultsKey.panelControlNotch))
    }

    // ISSUE-532: a file never registers the login item or takes macOS
    // shortcuts over on the Mac that imports it.
    func testSystemEffectsDoNotTravelAndTakeoversAreGivenBackOnImport() throws {
        let exported = SettingsBackupSupport.exportKeys()
        XCTAssertFalse(exported.contains(DefaultsKey.launchAtLoginWanted))
        XCTAssertFalse(exported.contains(DefaultsKey.systemShortcutTakeOverKeys))
        let restored = try XCTUnwrap(SettingsBackupSupport.sanitizedSettings(from: [
            SettingsBackupSupport.formatVersionKey: 1,
            SettingsBackupSupport.settingsKey: [
                DefaultsKey.launchAtLoginWanted: true,
                DefaultsKey.systemShortcutTakeOverKeys: ["screenCaptureShortcut"],
            ],
        ]))
        XCTAssertTrue(restored.isEmpty)
        for settings: [String: Any] in [[DefaultsKey.appearance: "dark"], [DefaultsKey.notchEnabled: true]] {
            let cleared = SettingsBackupSupport.keysToClear(whenImporting: settings)
            XCTAssertTrue(cleared.contains(DefaultsKey.systemShortcutTakeOverKeys))
            XCTAssertFalse(cleared.contains(DefaultsKey.launchAtLoginWanted))
        }
    }

    func testRecoveryMarkersAndMachineStateAreNotPortable() throws {
        let settings: [String: Any] = [
            DefaultsKey.switcherNativeHotkeysSuppressed: true,
            DefaultsKey.systemShortcutsSuppressed: true,
            DefaultsKey.unifiedScreenCaptureShortcutMigrated: true,
            DefaultsKey.restoredScreenCaptureShortcutsMigrated: true,
            DefaultsKey.fanControlRecoveryNeeded: true,
        ]
        let restored = try XCTUnwrap(SettingsBackupSupport.sanitizedSettings(from: [
            SettingsBackupSupport.formatVersionKey: 1,
            SettingsBackupSupport.settingsKey: settings,
        ]))
        XCTAssertTrue(restored.isEmpty)
    }

    func testUnknownKeysAndInvalidTypesAreRejected() throws {
        let restored = try XCTUnwrap(SettingsBackupSupport.sanitizedSettings(from: [
            SettingsBackupSupport.formatVersionKey: 1,
            SettingsBackupSupport.settingsKey: [
                "unknownPreference": true,
                DefaultsKey.appearance: 42,
                DefaultsKey.keepAwakeAutoStart: "true",
                DefaultsKey.defaultDuration: true,
                DefaultsKey.notchQuickAccessSide: 42,
                DefaultsKey.clamshellPreferred: true,
            ],
        ]))
        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(restored[DefaultsKey.clamshellPreferred] as? Bool, true)
    }
}
