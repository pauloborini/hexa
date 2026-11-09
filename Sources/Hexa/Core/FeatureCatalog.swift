// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Foundation

/// Every feature the Features hub can switch off entirely. The raw value is
/// the stable identity persisted inside the availability key, so cases can be
/// added but never renamed.
///
/// Availability is a layer ABOVE each feature's own enable key: an unavailable
/// feature disappears from Settings, the menu panel and the menu bar, and its
/// service tears down (and never instantiates on the next launch). Turning a
/// feature back on restores saved enable choices. A first install turns on its
/// primary control when no enable choice was saved before.
enum AppFeature: String, CaseIterable {
    // Sound: only the per-app mixer
    case mixer
    // Energy and display: Keep Awake, brightness (keyboard light rides with it)
    case keepAwake, brightness
    // Tools
    case mediaTools, cleaner, maintenanceTasks, uninstaller, appUpdates, killProcess, portManager
    // Screen capture and OCR (the capture module: the capture tool, its editor,
    // region and window capture, recent captures and screen text)
    case screenshot, screenOCR
    // The desktop's bars: the Dock held to one display, and the menu bar's own
    // items split into visible and hidden sections.
    case dockDisplayLock, menuBarHiding
    // Dynamic Island, then its extensions
    case notch, notchCalendar, notchNotifications, notchGestures, notchTimer, notchAccessories, notchLyrics,
         notchQueue, notchLiveEqualizer, notchDownloads, notchWatch
    // System monitor, one entry per metric family (temperatures live with
    // their parent metric: CPU temp with CPU, battery temp with power).
    case monitorCPU, monitorGPU, monitorMemory, monitorNetwork, monitorDisk, monitorPower, connectedDevices, fanControl
}

/// Hub sections, in display order.
enum FeatureGroup: String, CaseIterable {
    case sound, energyDisplay, tools, dynamicIsland, monitor
}

/// System permissions surfaced by the hub's transparency portal.
enum AppPermission: String, CaseIterable {
    case accessibility, screenRecording, fullDiskAccess, filesAndFolders, notifications,
         automationFinder, automationTerminal, automationPlayback, audioCapture, appManagement, calendar, bluetooth
}

enum PermissionPollingSupport {
    static func interval(visibleSurfaceCount: Int,
                         accessibilityIsNeeded: Bool,
                         screenRecordingIsNeeded: Bool,
                         accessibilityIsGranted: Bool,
                         screenRecordingIsGranted: Bool) -> TimeInterval? {
        guard visibleSurfaceCount > 0 else {
            return nil
        }
        guard accessibilityIsNeeded || screenRecordingIsNeeded else {
            return nil
        }
        return 2.5
    }
}

extension AppFeature {
    /// Whether an engaged feature needs permission changes while it sits in
    /// the background. One-shot tools ask and refresh at the moment they run;
    /// polling for those just because their tile is installed wastes wakeups.
    func monitorsPermissionChanges(boolFor: (String) -> Bool) -> Bool {
        switch self {
        case .notchWatch:
            // Watch asks when an area is chosen and checks on every reading.
            return false
        default:
            return true
        }
    }

    var monitorsPermissionChanges: Bool {
        monitorsPermissionChanges(boolFor: UserDefaults.standard.bool(forKey:))
    }

    var group: FeatureGroup {
        switch self {
        case .mixer:
            return .sound
        case .keepAwake, .brightness:
            return .energyDisplay
        case .mediaTools, .cleaner, .maintenanceTasks, .uninstaller, .appUpdates, .killProcess, .portManager,
             .screenshot, .screenOCR, .dockDisplayLock, .menuBarHiding:
            return .tools
        case .notch, .notchCalendar, .notchNotifications, .notchGestures, .notchTimer, .notchAccessories,
             .notchLyrics, .notchQueue, .notchLiveEqualizer, .notchDownloads, .notchWatch:
            return .dynamicIsland
        case .monitorCPU, .monitorGPU, .monitorMemory, .monitorNetwork, .monitorDisk, .monitorPower,
             .connectedDevices, .fanControl:
            return .monitor
        }
    }

    var symbolName: String {
        switch self {
        case .mixer: return "speaker.wave.2"
        case .keepAwake: return "moon.zzz.fill"
        case .brightness: return "display.2"
        case .mediaTools: return "photo.on.rectangle.angled"
        case .cleaner: return "sparkles"
        case .maintenanceTasks: return "wrench.and.screwdriver"
        case .uninstaller: return "trash"
        case .appUpdates: return "arrow.down.app"
        case .notchGestures: return "hand.draw"
        case .notchTimer: return "timer"
        case .notchAccessories: return "battery.25percent"
        case .notchLyrics: return "quote.bubble"
        case .notchQueue: return "list.bullet"
        case .notchLiveEqualizer: return "waveform"
        case .notchDownloads: return "arrow.down.circle"
        case .notchNotifications: return "bell"
        case .notchCalendar: return "calendar"
        case .notchWatch: return "eye"
        case .notch: return "macbook"
        case .killProcess: return "xmark.octagon"
        case .portManager: return "network"
        case .screenshot: return "camera.viewfinder"
        case .screenOCR: return "text.viewfinder"
        case .dockDisplayLock: return "panel-bottom"
        case .menuBarHiding: return "menubar.dock.rectangle"
        case .monitorCPU: return "cpu"
        case .monitorGPU: return "rectangle.connected.to.line.below"
        case .monitorMemory: return "memorychip"
        case .monitorNetwork: return "network"
        case .monitorDisk: return "internaldrive"
        case .monitorPower: return "bolt.fill"
        case .connectedDevices: return "cable.connector"
        case .fanControl: return "fanblades.fill"
        }
    }

    var availabilityKey: String { DefaultsKey.featureAvailable(rawValue) }

    var isBeta: Bool { false }

    /// Availability read straight from defaults. Existing features stay
    /// available on update; explicit beta opt-ins may start unavailable.
    var isAvailable: Bool {
        isAvailable(in: .standard)
    }

    func isAvailable(in defaults: UserDefaults) -> Bool {
        defaults.bool(forKey: availabilityKey)
    }

    /// The feature's own enable keys; any one being true means the feature is
    /// engaged. Empty means the feature works on demand (a panel tile, a
    /// context-menu action), so being available already counts as engaged for
    /// the permissions portal.
    var enabledKeys: [String] {
        switch self {
        case .notchGestures: return [DefaultsKey.notchGesturesEnabled]
        case .notchTimer: return [DefaultsKey.notchTimerEnabled]
        case .notchAccessories: return [DefaultsKey.notchAccessoriesEnabled]
        case .notchLyrics: return [DefaultsKey.notchLyricsEnabled]
        case .notchQueue: return [DefaultsKey.notchQueueEnabled]
        case .notchLiveEqualizer: return [DefaultsKey.notchLiveEqualizer]
        case .notchDownloads: return [DefaultsKey.notchDownloadsEnabled]
        case .notchNotifications: return [DefaultsKey.notchNotificationsEnabled]
        case .notchCalendar: return [DefaultsKey.notchCalendarEnabled]
        case .notchWatch: return [DefaultsKey.notchWatchEnabled]
        case .notch: return [DefaultsKey.notchEnabled]
        case .brightness: return [DefaultsKey.brightnessControlEnabled]
        case .dockDisplayLock: return [DefaultsKey.dockDisplayLockEnabled]
        case .menuBarHiding: return [DefaultsKey.menuBarHidingEnabled]
        case .mixer, .keepAwake, .mediaTools, .cleaner, .maintenanceTasks, .uninstaller, .appUpdates, .killProcess,
             .portManager, .screenshot, .screenOCR, .monitorCPU, .monitorGPU, .monitorMemory,
             .monitorNetwork, .monitorDisk, .monitorPower, .connectedDevices, .fanControl:
            return []
        }
    }

    /// Turn on the feature's main behavior at install time. Features with
    /// several independent controls start with one useful behavior. The
    /// live equalizer stays off: it asks for system audio recording on the
    /// first song, so only the user's own switch turns it on.
    private var initialEnableKeys: [String] {
        switch self {
        case .notchLiveEqualizer: return []
        default: return enabledKeys.first.map { [$0] } ?? []
        }
    }

    /// Registered defaults are visible through `object(forKey:)`, so only the
    /// persistent domain can tell a fresh install from a saved off choice.
    func enableOnFirstInstall(in defaults: UserDefaults, savedValues: [String: Any]) {
        let choices = enabledKeys
        guard !choices.contains(where: { savedValues[$0] != nil }) else { return }
        for key in initialEnableKeys {
            defaults.set(true, forKey: key)
        }
    }

    /// Which permissions the feature can use at all. Whether it is using them
    /// RIGHT NOW is answered by `activeFeatures(using:)`, which also applies
    /// the dynamic rules (the Cleaner only notifies when a schedule is on, and
    /// so on).
    var permissions: [AppPermission] {
        switch self {
        case .notchGestures: return []
        case .notchTimer: return []
        // Battery and connection of paired accessories.
        case .notchAccessories: return [.bluetooth]
        case .notchLyrics, .notchQueue: return []
        // The bars read the player's own audio output, which macOS gates
        // behind the same permission the mixer asks for.
        case .notchLiveEqualizer: return [.audioCapture]
        case .notchDownloads: return [.filesAndFolders]
        // The chosen area is read with the screen capture, and the alert
        // becomes a notification where the island is hidden.
        case .notchWatch: return [.screenRecording, .notifications]
        case .notchNotifications: return [.accessibility]
        case .notchCalendar: return [.calendar]
        case .notch: return [.accessibility, .automationPlayback]
        // The end of a timed or battery-limited session is a notification.
        case .keepAwake: return [.accessibility, .notifications]
        case .brightness: return [.accessibility]
        // Finder moves the items the Trash call cannot; Terminal runs the brew
        // commands that ask for a password.
        case .cleaner: return [.fullDiskAccess, .filesAndFolders, .notifications, .automationFinder]
        case .uninstaller: return [.fullDiskAccess, .automationFinder, .automationTerminal]
        case .appUpdates: return [.appManagement, .automationTerminal]
        case .mixer: return [.audioCapture, .accessibility]
        // The area is read with the screen capture grant.
        case .screenOCR: return [.screenRecording]
        // Saving to the Desktop (the default) or Documents reaches a folder
        // macOS protects.
        case .screenshot: return [.screenRecording, .filesAndFolders]
        // Bluetooth reads the battery of connected accessories.
        case .monitorPower: return [.bluetooth]
        // Reading where the Dock is and nudging the pointer before it reaches
        // an edge are both Accessibility work.
        case .dockDisplayLock: return [.accessibility]
        // The sections are read through every app's AXExtrasMenuBar, and the
        // visibility restriction needs the grant on macOS 27 and later.
        case .menuBarHiding: return [.accessibility]
        case .mediaTools, .maintenanceTasks, .monitorCPU, .monitorGPU, .monitorMemory, .monitorNetwork, .monitorDisk,
             .connectedDevices, .fanControl, .killProcess, .portManager:
            return []
        }
    }

    static func features(in group: FeatureGroup) -> [AppFeature] {
        allCases.filter { $0.group == group }
    }

    /// The Dynamic Island's extensions: everything else in its group. They
    /// do nothing without the island, so uninstalling it offers to take them
    /// along.
    static var dynamicIslandExtensions: [AppFeature] {
        features(in: .dynamicIsland).filter { $0 != .notch }
    }

    var initialInstallGroup: [AppFeature] {
        self == .notch ? [self] + Self.dynamicIslandExtensions : [self]
    }

    /// Switches the Features page may offer to uninstall once they turn out
    /// never used. Each one does nothing until its own switch is on, and no
    /// other feature leans on it while it is off.
    static let offeredWhenNeverSwitchedOn: [AppFeature] = []

    /// Installed features from that list whose switches are off and were never
    /// saved on this Mac: installed, but not once turned on. A switch turned
    /// on and back off is saved, so a feature someone used keeps its place.
    static func neverSwitchedOn(isAvailable: (AppFeature) -> Bool,
                                boolFor: (String) -> Bool,
                                isSaved: (String) -> Bool) -> [AppFeature] {
        offeredWhenNeverSwitchedOn.filter { feature in
            isAvailable(feature)
                && !feature.enabledKeys.isEmpty
                && !feature.enabledKeys.contains(where: boolFor)
                && !feature.enabledKeys.contains { isSaved($0) && !savedOnEveryMac.contains($0) }
        }
    }

    /// Switches a launch migration saves on every Mac, so a saved value there
    /// says nothing about use. Only one that is on counts.
    private static let savedOnEveryMac: Set<String> = []

    /// Whether a Mac that never chose this feature has it installed. Most
    /// people updating never saved an availability, so this list IS their
    /// install: moving a feature out of it uninstalls it for all of them,
    /// which is why a test pins it. The switch has no default on purpose, so
    /// every new feature is placed here by decision. New features belong on
    /// the opt-in side: an update should never grow the panel and Settings on
    /// its own, and the Features page and release notes are where they get
    /// installed.
    var installedByDefault: Bool {
        switch self {
        case .mixer, .keepAwake, .brightness, .mediaTools, .cleaner, .maintenanceTasks, .uninstaller, .appUpdates,
             .screenshot, .screenOCR,
             .notch, .notchCalendar, .notchNotifications, .notchGestures, .notchTimer, .notchAccessories,
             .notchLyrics, .notchQueue, .notchLiveEqualizer, .notchDownloads, .notchWatch,
             .monitorCPU, .monitorGPU, .monitorMemory, .monitorNetwork, .monitorDisk, .monitorPower,
             .connectedDevices:
            return true
        case .killProcess, .portManager, .dockDisplayLock, .menuBarHiding, .fanControl:
            return false
        }
    }

    /// Registered defaults keep every feature an update already had and leave
    /// opt-in features and explicit betas uninstalled.
    static var availabilityDefaults: [String: Any] {
        Dictionary(uniqueKeysWithValues: allCases.map { ($0.availabilityKey, $0.installedByDefault) })
    }

    /// Features that are available, engaged and using `permission` right now.
    /// Readers are injectable so the logic stays testable without touching
    /// real UserDefaults.
    static func activeFeatures(using permission: AppPermission,
                               isAvailable: (AppFeature) -> Bool,
                               boolFor: (String) -> Bool,
                               stringFor: (String) -> String?,
                               dataFor: (String) -> Data? = { _ in nil }) -> [AppFeature] {
        allCases.filter { feature in
            guard feature.permissions.contains(permission), isAvailable(feature) else { return false }
            let keys = feature.enabledKeys
            guard keys.isEmpty || keys.contains(where: boolFor) else { return false }
            switch (feature, permission) {
            case (.notch, .automationPlayback):
                return !(stringFor(DefaultsKey.notchHiddenModules) ?? "").split(separator: ",").contains("music")
            case (.notchWatch, .screenRecording):
                return isAvailable(.notch) && boolFor(DefaultsKey.notchEnabled)
                    && !(stringFor(DefaultsKey.notchHiddenModules) ?? "").split(separator: ",").contains("watch")
            case (.notchNotifications, .accessibility):
                return isAvailable(.notch) && boolFor(DefaultsKey.notchEnabled)
                    && !(stringFor(DefaultsKey.notchHiddenModules) ?? "").split(separator: ",").contains("notifications")
            case (.notchDownloads, .filesAndFolders):
                return isAvailable(.notch) && boolFor(DefaultsKey.notchEnabled)
                    && dataFor(DefaultsKey.notchDownloadsFolderBookmark) != nil
                    && !(stringFor(DefaultsKey.notchHiddenModules) ?? "").split(separator: ",").contains("downloads")
            case (.notchAccessories, .bluetooth):
                return isAvailable(.notch) && boolFor(DefaultsKey.notchEnabled)
            case (.notchCalendar, .calendar):
                return isAvailable(.notch) && boolFor(DefaultsKey.notchEnabled)
                    && !(stringFor(DefaultsKey.notchHiddenModules) ?? "").split(separator: ",").contains("calendar")
            case (.notch, .accessibility):
                return (boolFor(DefaultsKey.notchVolume) && isAvailable(.mixer))
                    || (boolFor(DefaultsKey.notchKeyboardLight) && isAvailable(.brightness))
                    || (boolFor(DefaultsKey.notchBrightness) && isAvailable(.brightness)
                        && boolFor(DefaultsKey.brightnessControlEnabled))
            case (.keepAwake, .accessibility):
                return boolFor(DefaultsKey.keepAwakeMouseJiggleEnabled)
            case (.mixer, .accessibility):
                return boolFor(DefaultsKey.preciseVolumeRollerEnabled)
            case (.brightness, .accessibility):
                return boolFor(DefaultsKey.brightnessKeysEnabled)
                    || boolFor(DefaultsKey.brightnessOSDEnabled)
                    || BrightnessSupport.KeyStep.sanitized(stringFor(DefaultsKey.brightnessKeyStep)) != .standard
            case (.cleaner, .notifications):
                return (stringFor(DefaultsKey.cleanerScheduleFrequency) ?? "off") != "off"
                    && boolFor(DefaultsKey.cleanerScheduleNotify)
            case (.notchLiveEqualizer, .audioCapture):
                return isAvailable(.notch) && boolFor(DefaultsKey.notchEnabled)
                    && !(stringFor(DefaultsKey.notchHiddenModules) ?? "").split(separator: ",").contains("music")
            default:
                return true
            }
        }
    }

    /// Runtime convenience over the injectable core.
    static func activeFeatures(using permission: AppPermission,
                               defaults: UserDefaults = .standard) -> [AppFeature] {
        activeFeatures(using: permission,
                       isAvailable: { defaults.bool(forKey: $0.availabilityKey) },
                       boolFor: { defaults.bool(forKey: $0) },
                       stringFor: { defaults.string(forKey: $0) },
                       dataFor: { defaults.data(forKey: $0) })
    }
}

extension AppPermission {
    var symbolName: String {
        switch self {
        case .accessibility: return "accessibility"
        case .screenRecording: return "rectangle.dashed.badge.record"
        case .fullDiskAccess: return "externaldrive.badge.person.crop"
        case .filesAndFolders: return "folder.badge.person.crop"
        case .notifications: return "bell.badge"
        case .automationFinder, .automationTerminal, .automationPlayback: return "gearshape.2"
        case .audioCapture: return "waveform"
        case .calendar: return "calendar"
        case .appManagement: return "app.badge"
        case .bluetooth: return "dot.radiowaves.left.and.right"
        }
    }
}
