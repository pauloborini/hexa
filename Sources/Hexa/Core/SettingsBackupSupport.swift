// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Foundation

/// The portable part of the app's settings: what a backup file carries and
/// how an incoming file is validated. Pure logic so the harness can pin down
/// exactly which keys travel (and, more importantly, which never do).
enum SettingsBackupSupport {
    static let formatVersionKey = "hexaBackupVersion"
    static let appVersionKey = "hexaBackupAppVersion"
    static let settingsKey = "settings"
    static let formatVersion = 1

    /// Keys the backup carries: every registered preference, the availability
    /// layer, and the deliberately unregistered selection/layout keys — minus
    /// state that belongs to one machine or one moment.
    static func exportKeys() -> Set<String> {
        var keys = Set(Defaults.registeredDefaults.keys)
        keys.formUnion(AppFeature.availabilityDefaults.keys)
        keys.formUnion(unregisteredPreferenceKeys)
        keys.subtract(machineStateKeys)
        return keys
    }

    /// Backups written before Dynamic Island existed have no island keys.
    /// Importing one must not erase the receiving Mac's island preferences.
    static func omitsDynamicIslandSettings(_ settings: [String: Any]) -> Bool {
        dynamicIslandKeys(in: exportKeys()).isDisjoint(with: settings.keys)
    }

    static func keysToClear(whenImporting settings: [String: Any]) -> Set<String> {
        let keys = exportKeys().union(givenBackOnImportKeys)
        guard omitsDynamicIslandSettings(settings) else { return keys }
        return keys.subtracting(dynamicIslandKeys(in: keys))
    }

    /// macOS shortcuts taken over on one Mac are not carried to another: the
    /// takeover would switch the system's shortcut off there as soon as the
    /// matching shortcut registered. Importing gives this Mac's back, because
    /// the imported shortcuts may now sit on different keys; the user takes
    /// them over again here if wanted.
    static let givenBackOnImportKeys: Set<String> = [DefaultsKey.systemShortcutTakeOverKeys]

    private static func dynamicIslandKeys(in keys: Set<String>) -> Set<String> {
        let availability = Set(AppFeature.features(in: .dynamicIsland).map(\.availabilityKey))
        return keys.filter {
            $0.hasPrefix("notch") || $0 == DefaultsKey.panelControlNotch
                || availability.contains($0)
        }
    }

    /// Preferences stored without a registered default (absence means "use
    /// the built-in behavior"), still part of how the user set the app up.
    static let unregisteredPreferenceKeys: Set<String> = [
        DefaultsKey.language,
        DefaultsKey.appVolumes,
        DefaultsKey.appOutputDevices,
        DefaultsKey.mixerHiddenApps,
        DefaultsKey.preferredInputDevice,
        DefaultsKey.menuBarCPU,
        DefaultsKey.menuBarGPU,
        DefaultsKey.menuBarMemory,
        DefaultsKey.menuBarNetwork,
        DefaultsKey.menuBarBattery,
        DefaultsKey.menuBarPower,
        DefaultsKey.panelSectionOrder,
        DefaultsKey.panelUtilityOrder,
        DefaultsKey.panelSystemOrder,
        DefaultsKey.panelNetworkOrder,
        DefaultsKey.panelDiskOrder,
        DefaultsKey.panelPowerOrder,
        DefaultsKey.panelCollapsedSections,
        // Legacy island layouts stay restorable; absence selects the new layout.
        DefaultsKey.notchQuickAccessSide,
        DefaultsKey.notchQuickAccessSecond,
        DefaultsKey.notchQuickAccessThird,
        // Experience flags: a restored Mac must not replay onboarding or the
        // feature intros the user has already been through.
        DefaultsKey.featureHubKeptFeatures,
        DefaultsKey.brightnessUpdatePromptState,
        DefaultsKey.panelCollapsedResetVersion,
        DefaultsKey.onboardingStep,
    ]

    /// Never exported: live state, per-machine placement, private content and
    /// anything an update flow owns. Clipboard entries stay
    /// out by construction (they are not preference keys), listed here only
    /// when they would otherwise slip in through the registered set.
    static let machineStateKeys: Set<String> = [
        // Launch at login is a login item on one Mac. Restoring the wish would
        // register the app there at the next launch without a question.
        DefaultsKey.launchAtLoginWanted,
        DefaultsKey.displaysSwitchedOff,
        DefaultsKey.displaysSwitchedOffFingerprints,
        DefaultsKey.cleanerLastAutoRun,
        // When the last check ran and what it found belong to one Mac.
        DefaultsKey.appUpdatesLastCheck,
        DefaultsKey.appUpdatesLastCount,
        DefaultsKey.appUpdatesNotifiedIDs,
        DefaultsKey.cleanerLastAutoMovedToTrash,
        DefaultsKey.cleanerLastAutoFailed,
        // A chosen folder is authority on one Mac, not portable configuration.
        // Restoring it elsewhere could search a different volume or trigger a
        // protected-folder prompt without a fresh choice.
        DefaultsKey.notchDownloadsFolderBookmark,
        DefaultsKey.screenshotSaveFolder,
        // A local watermark file is authority on this Mac, not portable data.
        DefaultsKey.mediaImageWatermarkLogoPath,
        DefaultsKey.unifiedScreenCaptureShortcutMigrated,
        DefaultsKey.restoredScreenCaptureShortcutsMigrated,
        DefaultsKey.orphanedCaptureShortcutMigrated,
        DefaultsKey.settingsWindowWidth,
        DefaultsKey.settingsWindowHeight,
        // The last magnifier level is session history; its remembered/default
        // policy remains portable, but another Mac need not inherit the value.
        DefaultsKey.screenshotLoupeLastZoom,
        // Whether the audio system let a recording hear the Mac's sound is a
        // grant this Mac gave, not a setting.
        DefaultsKey.recorderSystemAudioTapVerified,
        DefaultsKey.fanControlRecoveryNeeded,
        DefaultsKey.fanControlHelperVersion,
        // Control left running on one Mac must not start fans on another.
        DefaultsKey.fanControlResumeConfiguration,
        DefaultsKey.switcherNativeHotkeysSuppressed,
        DefaultsKey.systemShortcutsSuppressed,
        // DDC capability belongs to one physical monitor on one Mac port.
        DefaultsKey.brightnessDDCWriteOnlyPaths,
        // Restoring it would skip the one-time recheck of the cache above on
        // a Mac that still holds its own stale verdicts.
        DefaultsKey.brightnessDDCWriteOnlyPathsRechecked,
        DefaultsKey.brightnessForcedSoftwarePaths,
        DefaultsKey.brightnessExtendedDimmingPaths,
        // A fit measured against one Mac's camera housing would misfit another's.
        DefaultsKey.notchCameraFitWidth,
        DefaultsKey.notchCameraFitHeight,
    ]

    /// The file's content: an envelope with the format version, the app
    /// version that wrote it, and the filtered settings.
    static func payload(appVersion: String,
                        valueFor: (String) -> Any?) -> [String: Any] {
        var settings: [String: Any] = [:]
        for key in exportKeys() {
            if let value = valueFor(key) {
                settings[key] = value
            }
        }
        settings = portableNotchDisplay(settings)
        settings = portableMediaSettings(settings)
        return [
            formatVersionKey: formatVersion,
            appVersionKey: appVersion,
            settingsKey: settings,
        ]
    }

    /// Validates an incoming file and returns only the keys this build knows
    /// and exports — unknown, renamed or never-exported keys are dropped, so
    /// a tampered or future file can never write outside the allowed set.
    static func sanitizedSettings(from payload: [String: Any]) -> [String: Any]? {
        guard let version = formatVersion(from: payload),
              version >= 1, version <= formatVersion,
              let settings = payload[settingsKey] as? [String: Any]
        else { return nil }
        let allowed = exportKeys()
        let filtered = settings.filter { allowed.contains($0.key) && valueLooksRight($0.key, $0.value) }
        return portableNotchDisplay(portableMediaSettings(filtered))
    }

    /// A display mode this version does not offer, such as one kept by an
    /// earlier development build, restores as the automatic choice.
    private static func portableNotchDisplay(_ settings: [String: Any]) -> [String: Any] {
        var result = settings
        if let mode = result[DefaultsKey.notchDisplay] as? String, NotchDisplay(rawValue: mode) == nil {
            result[DefaultsKey.notchDisplay] = NotchDisplay.automatic.rawValue
        }
        return result
    }

    static func formatVersion(from payload: [String: Any]) -> Int? {
        if let intValue = payload[formatVersionKey] as? Int {
            return intValue
        }
        if let number = payload[formatVersionKey] as? NSNumber {
            return number.intValue
        }
        if let string = payload[formatVersionKey] as? String,
           let intValue = Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return intValue
        }
        return nil
    }

    private static func portableMediaSettings(_ source: [String: Any]) -> [String: Any] {
        var settings = source
        if let rawProfiles = settings[DefaultsKey.mediaImageProfiles] as? String {
            if let portableProfiles = MediaSupport.portableImageProfiles(rawProfiles) {
                settings[DefaultsKey.mediaImageProfiles] = portableProfiles
            } else {
                settings.removeValue(forKey: DefaultsKey.mediaImageProfiles)
            }
        }
        guard let kind = settings[DefaultsKey.mediaImageWatermarkKind] as? String else {
            return settings
        }
        let hasText = ((settings[DefaultsKey.mediaImageWatermarkText] as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        switch MediaImageWatermarkKind.sanitized(kind) {
        case .logo:
            settings[DefaultsKey.mediaImageWatermarkKind] = MediaImageWatermarkKind.off.rawValue
        case .textAndLogo:
            settings[DefaultsKey.mediaImageWatermarkKind] = hasText
                ? MediaImageWatermarkKind.text.rawValue : MediaImageWatermarkKind.off.rawValue
        case .off, .text:
            break
        }
        return settings
    }

    /// A backup is a file the user can hand around and edit, so a value has to
    /// look like the setting it claims to be before it is written back. The
    /// registered defaults already say what each setting is, and a value of
    /// the wrong shape is dropped rather than restored: a number where a
    /// switch belongs, or text where a number belongs, would otherwise reach
    /// code that trusts its own settings.
    static func valueLooksRight(_ key: String, _ value: Any) -> Bool {
        switch key {
        case DefaultsKey.notchQuickAccessSide, DefaultsKey.notchQuickAccessSecond, DefaultsKey.notchQuickAccessThird:
            return value is String
        default: break
        }
        guard let expected = Defaults.registeredDefaults[key] else {
            // Not a registered setting, so there is nothing to compare
            // against; the allowed list is the only gate for these.
            return true
        }
        switch expected {
        case is Bool: return isBoolean(value)
        case is Int: return isInteger(value)
        case is Double: return isNumber(value)
        case is String: return value is String
        case is [String]: return value is [String]
        case is [String: String]: return value is [String: String]
        case is [Any]: return value is [Any]
        case is [String: Any]: return value is [String: Any]
        default: return true
        }
    }

    private static func number(_ value: Any) -> NSNumber? {
        value as? NSNumber
    }

    private static func isBoolean(_ value: Any) -> Bool {
        guard let value = number(value) else { return false }
        return CFGetTypeID(value) == CFBooleanGetTypeID()
    }

    private static func isInteger(_ value: Any) -> Bool {
        guard let value = number(value), CFGetTypeID(value) != CFBooleanGetTypeID() else {
            return false
        }
        return !CFNumberIsFloatType(unsafeBitCast(value, to: CFNumber.self))
    }

    private static func isNumber(_ value: Any) -> Bool {
        guard let value = number(value), CFGetTypeID(value) != CFBooleanGetTypeID() else {
            return false
        }
        return value.doubleValue.isFinite
    }
}
