// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import FanControlCore
import CoreGraphics
import FanControlCore
import Carbon.HIToolbox
import FanControlCore
import Foundation

/// Every UserDefaults key used by the app, in one place.
enum DefaultsKey {
    static let language = "appLanguage"                   // AppLanguage.rawValue
    static let appearance = "appAppearance"               // AppAppearance.rawValue
    static let clamshellPreferred = "clamshellPreferred"  // apply closed-lid mode to every session
    static let onboardingStep = "onboardingStep"          // resume point if onboarding is interrupted
    static let lastUpdateIntroVersion = "lastUpdateIntroVersion"
    static let supportUpdateIntroVersion = "supportUpdateIntroVersion"
    static let updateHighlightsSeenVersion = "updateHighlightsSeenVersion"
    static let featureHubKeptFeatures = "featureHubKeptFeatures" // comma-joined AppFeature raw values
    static let brightnessUpdatePromptState = "brightnessUpdatePromptState"
    static let defaultDuration = "defaultDurationMinutes" // 0 = indefinite
    static let batteryLimit = "batteryLimitPercent"       // 0 = never
    static let keepAwakeAutoStart = "keepAwakeAutoStart"  // start Keep Awake when the app launches
    static let keepAwakeRightClickToggle = "keepAwakeRightClickToggle"
    static let keepAwakeAllowDisplaySleep = "keepAwakeAllowDisplaySleep"
    static let keepAwakeExternalDisplay = "keepAwakeExternalDisplay"
    static let keepAwakeConnectedToPower = "keepAwakeConnectedToPower"
    static let keepAwakeRunningApps = "keepAwakeRunningApps"
    static let keepAwakeRunningAppBundleIDs = "keepAwakeRunningAppBundleIDs"
    // Match mode over the automation conditions: false is Any (one matching
    // condition starts a session), true is All (every enabled condition has
    // to match, and losing one ends the session).
    static let keepAwakeAutomationRequireAll = "keepAwakeAutomationRequireAll"
    static let keepAwakePauseWhenLocked = "keepAwakePauseWhenLocked"
    static let keepAwakeSwitchUsesUntil = "keepAwakeSwitchUsesUntil" // panel switch restarts the Until chip
    static let keepAwakeUntilTime = "keepAwakeUntilTime"  // last picked end time; 0 = none yet
    static let keepAwakeMouseJiggleEnabled = "keepAwakeMouseJiggleEnabled"
    static let keepAwakeMouseJiggleInterval = "keepAwakeMouseJiggleIntervalMinutes"
    static let hotkeyEnabled = "hotkeyEnabled"
    static let launchAtLoginWanted = "launchAtLoginWanted"  // the user's choice; the system record can be lost
    static let launchAtLoginRegisteredPath = "launchAtLoginRegisteredPath" // app path of the last registration
    static let keepAwakeShortcut = "keepAwakeShortcut"    // GlobalShortcut storage value
    static let showCountdown = "showCountdownInMenuBar"
    static let statusItemPlacementGeneration = "statusItemPlacementGeneration"
    static let sleepDisabledFlag = "hexaDisabledSleep"   // internal guard for pmset disablesleep
    static let clamshellRuleSelfRemoving = "clamshellRuleSelfRemoving" // the rule on disk grants its own removal

    /// Whether this app left `pmset disablesleep` on and still owes the restore.
    static func sleepDisabledValue(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: sleepDisabledFlag)
    }

    /// Whether the rule on disk is the one that carries its own removal.
    /// A rule written before that grant existed is replaced by the next
    /// activation, so it never survives the mode it was installed for.
    static func clamshellRuleSelfRemovingValue(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: clamshellRuleSelfRemoving)
    }
    // Machine state, never exported: the system shortcuts this process owns,
    // so a launch after a crash can restore them. The switcher-only key is
    // what builds before the take-over was shared wrote; it is read once,
    // folded into the shared one, and then retired.
    static let switcherNativeHotkeysSuppressed = "switcherNativeHotkeysSuppressed"
    static let systemShortcutsSuppressed = "systemShortcutsSuppressed"
    // Storage keys of shortcuts the user chose to take over from macOS. A
    // preference, exported.
    static let systemShortcutTakeOverKeys = "systemShortcutTakeOverKeys"
    static let releaseNotesOnUpdate = "releaseNotesOnUpdate" // show What's New after an update
    static let appVolumes = "appVolumes"                  // [bundle id: 0...2]
    static let appOutputDevices = "appOutputDevices"      // [bundle id: audio device UID]
    static let mixerShowFinder = "mixerShowFinder"
    static let mixerAppArrangement = "mixerAppArrangement"
    static let mixerHideInactiveApps = "mixerHideInactiveApps"
    static let mixerHiddenApps = "mixerHiddenApps"        // [persistence id: display name] kept out of the mixer list
    static let mixerLowerVolumeOnHeadphonesDisconnect = "mixerLowerVolumeOnHeadphonesDisconnect"
    static let mixerHeadphonesDisconnectVolumePercent = "mixerHeadphonesDisconnectVolumePercent"
    static let preciseVolumeRollerEnabled = "preciseVolumeRollerEnabled"
    static let preferredInputDevice = "preferredInputDevice" // audio input device UID
    static let brightnessControlEnabled = "brightnessControlEnabled" // sliders for every display
    static let brightnessKeysEnabled = "brightnessKeysEnabled" // brightness keys act on the display under the pointer
    static let brightnessOSDEnabled = "brightnessOSDEnabled" // brightness adjustment overlay
    static let brightnessKeyStep = "brightnessKeyStep" // BrightnessSupport.KeyStep raw value
    static let displayBrightnessShortcutsEnabled = "displayBrightnessShortcutsEnabled"
    static let displayBrightnessDecreaseShortcut = "displayBrightnessDecreaseShortcut"
    static let displayBrightnessIncreaseShortcut = "displayBrightnessIncreaseShortcut"
    static let keyboardBrightnessShortcutsEnabled = "keyboardBrightnessShortcutsEnabled"
    static let keyboardBrightnessDecreaseShortcut = "keyboardBrightnessDecreaseShortcut"
    static let keyboardBrightnessIncreaseShortcut = "keyboardBrightnessIncreaseShortcut"
    // Per-monitor connection paths that accept brightness writes but never
    // answer reads. Kept local so wake handling does not repeatedly probe a
    // sensitive display path.
    static let brightnessDDCWriteOnlyPaths = "brightnessDDCWriteOnlyPaths"
    // Set once the paths cached before paired discovery requests have been
    // dropped, so a monitor written off then is classified again exactly once.
    static let brightnessDDCWriteOnlyPathsRechecked = "brightnessDDCWriteOnlyPathsRechecked"
    // Per-monitor connection paths a person has told this app to dim in
    // software: the only way to know a write-only channel swallows its writes
    // is to watch the panel, which no probe can do.
    static let brightnessForcedSoftwarePaths = "brightnessForcedSoftwarePaths"
    // Per-monitor connections where the lower end of the brightness slider
    // also dims the picture below the panel's hardware minimum.
    static let brightnessExtendedDimmingPaths = "brightnessExtendedDimmingPaths"
    // Displays this app switched off, so a run that ends without putting them
    // back can be repaired on the next start instead of needing a replug.
    static let displaysSwitchedOff = "displaysSwitchedOff"
    // Identity saved before disabling each display, kept separate so older
    // versions can still read the repair list of display numbers.
    static let displaysSwitchedOffFingerprints = "displaysSwitchedOffFingerprints"
    // Set while a start is under way and cleared once the app has run
    // healthily for a while, or when it is quit properly. Found still set at
    // the next start, it means the previous one died on the way up.
    static let startupDidNotFinish = "startupDidNotFinish"
    static let cleanerScheduleFrequency = "cleanerScheduleFrequency"    // off | daily | weekly
    static let cleanerScheduleHour = "cleanerScheduleHour"
    static let cleanerScheduleMinute = "cleanerScheduleMinute"
    static let cleanerScheduleWeekday = "cleanerScheduleWeekday"        // 1 Sunday ... 7 Saturday
    static let cleanerScheduleNotify = "cleanerScheduleNotify"
    static let cleanerLastAutoRun = "cleanerLastAutoRun"                // Double, epoch seconds
    static let cleanerLastAutoMovedToTrash = "cleanerLastAutoMovedToTrash"  // Int bytes sent to the Trash
    static let cleanerLastAutoFailed = "cleanerLastAutoFailed"          // Int items left in place
    static let cleanerScreenshotAgeDays = "cleanerScreenshotAgeDays"    // Int, 0 = off
    static let cleanerCodingConversationAgeDays = "cleanerCodingConversationAgeDays"  // Int, 0 = off
    static let cleanerLargeFileAgeDays = "cleanerLargeFileAgeDays"        // Int, one of CleanerPolicy.largeFileAgeChoices
    static let cleanerLargeFileSizeMegabytes = "cleanerLargeFileSizeMegabytes" // Int, one of CleanerPolicy.largeFileSizeChoicesMegabytes
    static let settingsWindowWidth = "settingsWindowWidth"     // last user-chosen content size (0 = unset)
    static let settingsWindowHeight = "settingsWindowHeight"
    static let cleaningModeKeepScreenVisible = "cleaningModeKeepScreenVisible"
    static let panelUtilityUninstaller = "panelUtilityUninstaller"
    static let killProcessGroupRelated = "killProcessGroupRelated"
    static let killProcessSortBy = "killProcessSortBy" // cpu | memory | name | pid
    static let killProcessSortAscending = "killProcessSortAscending"
    static let panelUtilityCleaner = "panelUtilityCleaner"
    static let panelUtilityAppUpdates = "panelUtilityAppUpdates"
    static let appUpdatesIncludeHomebrewApps = "appUpdatesIncludeHomebrewApps"
    static let appUpdatesIncludeAppStore = "appUpdatesIncludeAppStore"
    static let appUpdatesIncludeOnlineCatalog = "appUpdatesIncludeOnlineCatalog"
    static let appUpdatesRules = "appUpdatesRules" // JSON, portable bundle-ID rules
    static let appUpdatesLastCheck = "appUpdatesLastCheck"            // Double, epoch seconds
    static let appUpdatesLastCount = "appUpdatesLastCount"
    // Findings already announced once, so a pending update nobody installs
    // does not speak up again after every relaunch.
    static let appUpdatesNotifiedIDs = "appUpdatesNotifiedIDs"
    static let panelUtilityMedia = "panelUtilityMedia"
    // Show/hide whole panel sections that have no monitorShow* key of their own.
    static let panelShowKeepAwake = "panelShowKeepAwake"
    static let panelShowBrightness = "panelShowBrightness"
    static let panelShowUtilities = "panelShowUtilities"

    // System monitor — live metrics shown next to the menu bar icon (opt-in).
    static let menuBarCPU = "menuBarCPU"
    static let menuBarGPU = "menuBarGPU"
    static let menuBarMemory = "menuBarMemory"
    static let menuBarCPUTemperature = "menuBarCPUTemperature"
    static let menuBarGPUTemperature = "menuBarGPUTemperature"
    static let menuBarBatteryTemperature = "menuBarBatteryTemperature"
    static let menuBarTemperature = "menuBarTemperature" // legacy Developer key for the old generic temperature metric
    static let menuBarNetwork = "menuBarNetwork"
    static let menuBarDiskUsage = "menuBarDiskUsage"
    static let menuBarDiskActivity = "menuBarDiskActivity"
    static let menuBarBattery = "menuBarBattery"
    static let menuBarBatteryTime = "menuBarBatteryTime"
    static let menuBarPeripheralBattery = "menuBarPeripheralBattery"
    static let menuBarConnectedDevices = "menuBarConnectedDevices"
    static let menuBarPower = "menuBarPower"
    static let menuBarFanSpeed = "menuBarFanSpeed"
    static let menuBarPreset = "menuBarPreset"           // dense
    static let menuBarMetricSpacing = "menuBarMetricSpacing" // standard | compact
    static let menuBarMetricAppearance = "menuBarMetricAppearance" // values | bars
    static let menuBarUsageBarNormalColor = "menuBarUsageBarNormalColor" // #RRGGBB
    static let menuBarUsageBarElevatedColor = "menuBarUsageBarElevatedColor" // #RRGGBB
    static let menuBarUsageBarCriticalColor = "menuBarUsageBarCriticalColor" // #RRGGBB
    static let menuBarUsageBarMediumThreshold = "menuBarUsageBarMediumThreshold" // percent
    static let menuBarUsageBarHighThreshold = "menuBarUsageBarHighThreshold" // percent
    static let menuBarHideIconWithMetrics = "menuBarHideIconWithMetrics" // glyph hides while metrics render in the main item
    static let menuBarMetricOrder = "menuBarMetricOrder" // comma-separated MenuBarMetric raw values
    static let menuBarCombineTemperatures = "menuBarCombineTemperatures" // usage/charge + temperature in one block when possible
    static let menuBarSeparateMetrics = "menuBarSeparateMetrics" // one status item per active metric
    static let menuBarNetworkUploadFirst = "menuBarNetworkUploadFirst" // network menu bar block shows upload above download
    static let menuBarLabelStyle = "menuBarLabelStyle"     // compact | classic
    static let menuBarMemoryStyle = "menuBarMemoryStyle"   // dot | percent | both
    static let menuBarDiskStyle = "menuBarDiskStyle"       // percent | free | used
    static let monitorMemoryMetric = "monitorMemoryMetric" // used | app
    static let monitorInterval = "monitorIntervalSeconds"  // sampling cadence: 1/2/5
    static let temperatureUnit = "temperatureUnit"          // celsius | fahrenheit
    // System monitor — which blocks appear in the panel.
    static let monitorShowSystem = "monitorShowSystem"
    static let monitorShowNetwork = "monitorShowNetwork"
    static let monitorShowDisk = "monitorShowDisk"
    static let monitorShowPower = "monitorShowPower"
    static let monitorShowMixer = "monitorShowMixer"
    static let panelShowFanControl = "panelShowFanControl"
    static let fanControlMode = "fanControlMode"
    static let fanControlCoolingLevel = "fanControlCoolingLevel"
    static let fanControlCurves = "fanControlCurves"
    // Re-apply the last manual speed or curve when the app opens and after wake.
    static let fanControlResume = "fanControlResume"
    // Machine-only: the control the user left running while resume is on,
    // cleared when they return to System so it never outlives that choice.
    static let fanControlResumeConfiguration = "fanControlResumeConfiguration"
    // Previous panel visibility key, read once by the migration below.
    static let monitorShowFanControlBeta = "monitorShowFanControlBeta"
    // Machine-only recovery state. A true value means the helper must confirm
    // automatic fan control before this marker can be cleared.
    static let fanControlRecoveryNeeded = "fanControlRecoveryNeeded"
    static let fanControlHelperVersion = "fanControlHelperVersion"
    // System monitor — per-metric history graphs (each independently toggleable).
    static let monitorGraphCPU = "monitorGraphCPU"
    static let monitorGraphGPU = "monitorGraphGPU"
    static let monitorGraphMemory = "monitorGraphMemory"
    static let monitorGraphNetwork = "monitorGraphNetwork"
    static let monitorGraphDisk = "monitorGraphDisk"
    static let monitorGraphPower = "monitorGraphPower"
    static let monitorGraphBattery = "monitorGraphBattery"
    static let monitorGraphScale = "monitorGraphScale"
    // System monitor — per-item visibility inside each panel section.
    static let monitorSysTemps = "monitorSysTemps"
    static let monitorSysCPU = "monitorSysCPU"
    static let monitorSysGPU = "monitorSysGPU"
    static let monitorSysBattery = "monitorSysBattery"
    static let monitorSysMemory = "monitorSysMemory"
    static let monitorSysAlerts = "monitorSysAlerts"
    static let monitorSysUptime = "monitorSysUptime"
    static let monitorSysFans = "monitorSysFans"
    static let monitorNetSpeed = "monitorNetSpeed"
    static let monitorNetApps = "monitorNetApps"
    static let monitorNetTotals = "monitorNetTotals"
    static let monitorNetAddresses = "monitorNetAddresses"
    static let monitorNetTest = "monitorNetTest"
    static let monitorDiskUsage = "monitorDiskUsage"
    static let monitorDiskActivity = "monitorDiskActivity"
    static let monitorDiskSMART = "monitorDiskSMART"
    static let monitorDiskProtection = "monitorDiskProtection"
    static let monitorDiskTools = "monitorDiskTools"
    static let monitorPwrTemperature = "monitorPwrTemperature"
    static let monitorPwrSystem = "monitorPwrSystem"
    static let monitorPwrAdapter = "monitorPwrAdapter"
    static let monitorPwrBattery = "monitorPwrBattery"
    static let monitorPwrTimeRemaining = "monitorPwrTimeRemaining"
    static let monitorPwrHealth = "monitorPwrHealth"
    // System monitor — optional notifications for sustained or actionable conditions.
    static let monitorAlertCPU = "monitorAlertCPU"
    static let monitorAlertCPUTemperature = "monitorAlertCPUTemperature"
    static let monitorAlertBatteryTemperature = "monitorAlertBatteryTemperature"
    static let monitorAlertMemory = "monitorAlertMemory"
    static let monitorAlertDisk = "monitorAlertDisk"
    static let monitorAlertBattery = "monitorAlertBattery"
    static let monitorAlertCPUThreshold = "monitorAlertCPUThreshold"
    static let monitorAlertCPUTemperatureThreshold = "monitorAlertCPUTemperatureThreshold"
    static let monitorAlertBatteryTemperatureThreshold = "monitorAlertBatteryTemperatureThreshold"
    static let monitorAlertDiskFreePercent = "monitorAlertDiskFreePercent"
    static let monitorAlertBatteryPercent = "monitorAlertBatteryPercent"
    static let monitorAlertCooldownMinutes = "monitorAlertCooldownMinutes"
    // Menu panel layout — the order the major sections appear in and which are
    // collapsed, both comma-joined section ids (see PanelSectionID). Absent keys
    // mean the canonical order and nothing collapsed, so no defaults registration.
    static let panelSectionOrder = "panelSectionOrder"
    static let panelUtilityOrder = "panelUtilityOrder"
    static let panelSystemOrder = "panelSystemOrder"
    static let panelNetworkOrder = "panelNetworkOrder"
    static let panelDiskOrder = "panelDiskOrder"
    static let panelPowerOrder = "panelPowerOrder"
    static let panelNavigationEnabled = "panelNavigationEnabled" // legacy: the panel always navigates by sections
    static let windowLayoutHiddenActions = "windowLayoutHiddenActions" // comma-separated action ids hidden from the grid
    static let windowLayoutWindowGap = "windowLayoutWindowGap" // px between adjacent snapped windows
    static let windowLayoutScreenGap = "windowLayoutScreenGap" // px between a snapped window and the visible frame edge
    static let windowLayoutMarginPercent = "windowLayoutMarginPercent" // per-edge percentage for margin maximize
    static let windowLayoutSideRepeatCyclesThirds = "windowLayoutSideRepeatCyclesThirds" // repeated Left/Right cycles half, 2/3, 1/3 on the same display
    static let windowLayoutIgnoredApps = "windowLayoutIgnoredApps" // apps that temporarily disable window layout while focused
    static let panelCollapsedSections = "panelCollapsedSections"
    static let panelCollapsedResetVersion = "panelCollapsedResetVersion"

    // Media utility — local video, GIF, image and OCR tools.
    static let mediaLastTool = "mediaLastTool"
    static let mediaVideoStart = "mediaVideoStart"
    static let mediaVideoEnd = "mediaVideoEnd"
    static let mediaVideoQuality = "mediaVideoQuality"
    static let mediaVideoMaxDimension = "mediaVideoMaxDimension"
    static let mediaVideoFPS = "mediaVideoFPS"
    static let mediaVideoKeepAudio = "mediaVideoKeepAudio"
    static let mediaVideoCodec = "mediaVideoCodec"
    static let mediaVideoSizing = "mediaVideoSizing"
    static let mediaVideoTargetMegabytes = "mediaVideoTargetMegabytes"
    static let mediaGIFStart = "mediaGIFStart"
    static let mediaGIFEnd = "mediaGIFEnd"
    static let mediaGIFQuality = "mediaGIFQuality"
    static let mediaGIFWidth = "mediaGIFWidth"
    static let mediaGIFFPS = "mediaGIFFPS"
    static let mediaGIFLoops = "mediaGIFLoops"
    static let mediaGIFSizing = "mediaGIFSizing"
    static let mediaGIFTargetMegabytes = "mediaGIFTargetMegabytes"
    static let mediaImageQuality = "mediaImageQuality"
    static let mediaImageMaxDimension = "mediaImageMaxDimension"
    static let mediaImageFormat = "mediaImageFormat"
    static let mediaImageStripMetadata = "mediaImageStripMetadata"
    static let mediaImageResizeKind = "mediaImageResizeKind"
    static let mediaImageResizeWidth = "mediaImageResizeWidth"
    static let mediaImageResizeHeight = "mediaImageResizeHeight"
    static let mediaImageExactResizeMode = "mediaImageExactResizeMode"
    static let mediaImageWatermarkKind = "mediaImageWatermarkKind"
    static let mediaImageWatermarkText = "mediaImageWatermarkText"
    static let mediaImageWatermarkLogoPath = "mediaImageWatermarkLogoPath"
    static let mediaImageWatermarkPosition = "mediaImageWatermarkPosition"
    static let mediaImageWatermarkOpacity = "mediaImageWatermarkOpacity"
    static let mediaImageWatermarkMargin = "mediaImageWatermarkMargin"
    static let mediaImageWatermarkScale = "mediaImageWatermarkScale"
    static let mediaImageRenamePattern = "mediaImageRenamePattern"
    static let mediaImageBackground = "mediaImageBackground"
    static let mediaImagePreserveModificationDate = "mediaImagePreserveModificationDate"
    static let mediaImageSaveInSubfolder = "mediaImageSaveInSubfolder"
    static let mediaImageProfiles = "mediaImageProfiles"
    static let mediaImageSelectedProfileID = "mediaImageSelectedProfileID"
    static let mediaTextAccurate = "mediaTextAccurate"
    static let mediaTextLanguageCorrection = "mediaTextLanguageCorrection"



    static let diskEjectExcludedVolumes = "diskEjectExcludedVolumes" // volume names/UUIDs excluded from Eject all disks
    // Quick tools: color picker, screen OCR, mic mute.
    static let colorPickerShortcutEnabled = "colorPickerShortcutEnabled"
    static let colorPickerShortcut = "colorPickerShortcut"
    static let colorPickerFormat = "colorPickerFormat"       // hex | rgb | hsl | swiftui
    static let colorPickerBareHex = "colorPickerBareHex"     // copy HEX without the leading #
    static let screenOCRShortcutEnabled = "screenOCRShortcutEnabled"
    static let screenOCRShortcut = "screenOCRShortcut"
    static let screenOCRRemoveLineBreaks = "screenOCRRemoveLineBreaks"
    static let screenOCRDetectQRCodes = "screenOCRDetectQRCodes" // QR content wins over OCR text
    static let wallpaperApplyAllDisplays = "wallpaperApplyAllDisplays"
    static let wallpaperFilter = "wallpaperFilter"
    static let wallpaperOwnBookmarks = "wallpaperOwnBookmarks"
    // paths hidden from folder scans (does not delete files)
    static let wallpaperExcludedOwnPaths = "wallpaperExcludedOwnPaths"
    static let panelUtilityScreenOCR = "panelUtilityScreenOCR"
    // Mode chooser visibility for dedicated capture shortcuts.
    static let screenshotShowCaptureMenuOnShortcut = "screenshotShowCaptureMenuOnShortcut"
    static let recorderShowCaptureMenuOnShortcut = "recorderShowCaptureMenuOnShortcut"
    static let screenOCRShowCaptureMenuOnShortcut = "screenOCRShowCaptureMenuOnShortcut"
    static let colorPickerShowCaptureMenuOnShortcut = "colorPickerShowCaptureMenuOnShortcut"
    // Screenshot capture and editor.
    static let screenshotShortcutEnabled = "screenshotShortcutEnabled"
    static let screenshotShortcut = "screenshotShortcut"
    static let unifiedScreenCaptureShortcutMigrated = "unifiedScreenCaptureShortcutMigrated"
    static let restoredScreenCaptureShortcutsMigrated = "restoredScreenCaptureShortcutsMigrated"
    static let orphanedCaptureShortcutMigrated = "orphanedCaptureShortcutMigrated"
    static let screenshotFullScreenShortcutEnabled = "screenshotFullScreenShortcutEnabled"
    static let screenshotFullScreenShortcut = "screenshotFullScreenShortcut"
    static let screenshotLastCaptureShortcutEnabled = "screenshotLastCaptureShortcutEnabled"
    static let screenshotLastCaptureShortcut = "screenshotLastCaptureShortcut"
    static let recentCapturesShortcutEnabled = "recentCapturesShortcutEnabled"
    static let recentCapturesShortcut = "recentCapturesShortcut"
    static let screenshotClipboardShortcutEnabled = "screenshotClipboardShortcutEnabled"
    static let screenshotClipboardShortcut = "screenshotClipboardShortcut"
    static let screenshotFreeze = "screenshotFreeze"
    static let screenshotHideHexaWindows = "screenshotHideHexaWindows"
    static let screenshotAutoSaveToFolder = "screenshotAutoSaveToFolder"
    static let screenshotSaveFolder = "screenshotSaveFolder"
    static let screenshotSaveSubfolder = "screenshotSaveSubfolder"
    static let screenshotFileNamePattern = "screenshotFileNamePattern"
    static let screenshotFileNumberNext = "screenshotFileNumberNext"
    static let screenshotDefaultAction = "screenshotDefaultAction"
    static let screenshotIncludePointer = "screenshotIncludePointer"
    static let screenshotShowLastRegion = "screenshotShowLastRegion"
    static let screenshotLoupeStartsOn = "screenshotLoupeStartsOn"
    static let screenshotLoupeRememberZoom = "screenshotLoupeRememberZoom"
    static let screenshotLoupeDefaultZoom = "screenshotLoupeDefaultZoom"
    static let screenshotLoupeLastZoom = "screenshotLoupeLastZoom"
    static let screenshotLoupeSteppedZoomByDefault = "screenshotLoupeSteppedZoomByDefault"
    static let screenshotDownscale = "screenshotDownscale"
    static let screenshotDelay = "screenshotDelay"
    static let screenshotLastTool = "screenshotLastTool"
    static let screenshotLastColor = "screenshotLastColor"
    static let screenshotLastStroke = "screenshotLastStroke"
    static let screenshotLastTextSize = "screenshotLastTextSize"
    static let screenshotLastBlurLevel = "screenshotLastBlurLevel"
    static let screenshotLastArrowStyle = "screenshotLastArrowStyle"
    static let screenshotLastSticker = "screenshotLastSticker"
    static let screenshotAnnotationShadows = "screenshotAnnotationShadows"
    static let screenshotToolOrder = "screenshotToolOrder"
    static let screenshotToolShortcuts = "screenshotToolShortcuts"
    static let screenshotToolShortcutsEnabled = "screenshotToolShortcutsEnabled"
    static let screenshotBackdropStyle = "screenshotBackdropStyle"
    static let screenshotBackdropPresets = "screenshotBackdropPresets"
    static let screenshotWatermarkStyle = "screenshotWatermarkStyle"
    static let screenshotWatermarkPresets = "screenshotWatermarkPresets"
    static let screenshotOpenEditorDirectly = "screenshotOpenEditorDirectly"
    static let screenshotCopyToClipboard = "screenshotCopyToClipboard"
    static let screenshotPreviewPosition = "screenshotPreviewPosition"
    static let screenshotPreviewDestination = "screenshotPreviewDestination"
    static let screenshotPreviewTakesFocus = "screenshotPreviewTakesFocus"
    static let screenshotPreviewEnabled = "screenshotPreviewEnabled"
    static let screenshotPreviewDuration = "screenshotPreviewDuration"
    static let panelUtilityScreenshot = "panelUtilityScreenshot"

    // Screen recorder - records the picked area, keeps the untouched master
    // in Application Support until retention sweeps it.
    static let recorderShortcutEnabled = "recorderShortcutEnabled"
    static let recorderShortcut = "recorderShortcut"
    static let recorderCountdown = "recorderCountdown"
    static let recorderFrameRate = "recorderFrameRate"
    static let recorderSystemAudio = "recorderSystemAudio"
    static let recorderMicrophone = "recorderMicrophone"
    // Machine state, never exported: whether this Mac's audio system has let
    // a recording hear the Mac's sound through a process tap.
    static let recorderSystemAudioTapVerified = "recorderSystemAudioTapVerified"
    static let recorderSaveFolder = "recorderSaveFolder"
    static let recorderOpenEditor = "recorderOpenEditor"
    static let recorderAutomaticZoom = "recorderAutomaticZoom"
    static let recorderGIFFrameRate = "recorderGIFFrameRate"
    static let recorderEditorPresets = "recorderEditorPresets"
    static let recorderSharingEnabled = "recorderSharingEnabled"
    static let panelUtilityPortManager = "panelUtilityPortManager"
    static let panelUtilityKillProcess = "panelUtilityKillProcess"
    static let panelUtilityPurgeMemory = "panelUtilityPurgeMemory"
    static let panelUtilityFlushDNS = "panelUtilityFlushDNS"
    static let panelQuickBrightness = "panelQuickBrightness"

    // Window Layout — snapping, global shortcuts and optional pointer gestures.
    static let windowLayoutShortcutsEnabled = "windowLayoutShortcutsEnabled"
    static let windowDirectionalEnabled = "windowDirectionalEnabled"
    static let windowDirectionalShortcut = "windowDirectionalShortcut"
    static let pointerDisplayEnabled = "pointerDisplayEnabled"
    static let pointerDisplayShortcut = "pointerDisplayShortcut"
    static let windowEdgeSnapEnabled = "windowEdgeSnapEnabled"
    static let windowEdgeSnapDisabledZones = "windowEdgeSnapDisabledZones" // comma-separated visual zone ids
    static let windowGestureEnabled = "windowGestureEnabled"
    static let windowGestureModifiers = "windowGestureModifiers"
    static let windowGestureRaiseWindow = "windowGestureRaiseWindow"
    static let windowLayoutShortcutLeft = "windowLayoutShortcutLeft"
    static let windowLayoutShortcutRight = "windowLayoutShortcutRight"
    static let windowLayoutShortcutTop = "windowLayoutShortcutTop"
    static let windowLayoutShortcutBottom = "windowLayoutShortcutBottom"
    static let windowLayoutShortcutCenterHalf = "windowLayoutShortcutCenterHalf"
    static let windowLayoutShortcutTopLeft = "windowLayoutShortcutTopLeft"
    static let windowLayoutShortcutTopRight = "windowLayoutShortcutTopRight"
    static let windowLayoutShortcutBottomLeft = "windowLayoutShortcutBottomLeft"
    static let windowLayoutShortcutBottomRight = "windowLayoutShortcutBottomRight"
    static let windowLayoutShortcutMaximize = "windowLayoutShortcutMaximize"
    static let windowLayoutShortcutMarginMaximize = "windowLayoutShortcutMarginMaximize"
    static let windowLayoutShortcutCenter = "windowLayoutShortcutCenter"
    static let windowLayoutShortcutRestore = "windowLayoutShortcutRestore"
    static let windowLayoutShortcutLeftThird = "windowLayoutShortcutLeftThird"
    static let windowLayoutShortcutCenterThird = "windowLayoutShortcutCenterThird"
    static let windowLayoutShortcutRightThird = "windowLayoutShortcutRightThird"
    static let windowLayoutShortcutLeftTwoThirds = "windowLayoutShortcutLeftTwoThirds"
    static let windowLayoutShortcutRightTwoThirds = "windowLayoutShortcutRightTwoThirds"
    static let windowLayoutShortcutCenterTwoThirds = "windowLayoutShortcutCenterTwoThirds"
    static let windowLayoutShortcutTopThird = "windowLayoutShortcutTopThird"
    static let windowLayoutShortcutMiddleThird = "windowLayoutShortcutMiddleThird"
    static let windowLayoutShortcutBottomThird = "windowLayoutShortcutBottomThird"
    static let windowLayoutShortcutTopTwoThirds = "windowLayoutShortcutTopTwoThirds"
    static let windowLayoutShortcutBottomTwoThirds = "windowLayoutShortcutBottomTwoThirds"
    static let windowLayoutShortcutTopQuarter = "windowLayoutShortcutTopQuarter"
    static let windowLayoutShortcutUpperMiddleQuarter = "windowLayoutShortcutUpperMiddleQuarter"
    static let windowLayoutShortcutLowerMiddleQuarter = "windowLayoutShortcutLowerMiddleQuarter"
    static let windowLayoutShortcutBottomQuarter = "windowLayoutShortcutBottomQuarter"
    static let windowLayoutShortcutLeftQuarter = "windowLayoutShortcutLeftQuarter"
    static let windowLayoutShortcutLeftMiddleQuarter = "windowLayoutShortcutLeftMiddleQuarter"
    static let windowLayoutShortcutRightMiddleQuarter = "windowLayoutShortcutRightMiddleQuarter"
    static let windowLayoutShortcutRightQuarter = "windowLayoutShortcutRightQuarter"
    static let windowLayoutShortcutPreviousDisplay = "windowLayoutShortcutPreviousDisplay"
    static let windowLayoutShortcutNextDisplay = "windowLayoutShortcutNextDisplay"
    static let windowLayoutShortcutFullScreen = "windowLayoutShortcutFullScreen"
    static let windowLayoutShortcutTopLeftSixth = "windowLayoutShortcutTopLeftSixth"
    static let windowLayoutShortcutTopCenterSixth = "windowLayoutShortcutTopCenterSixth"
    static let windowLayoutShortcutTopRightSixth = "windowLayoutShortcutTopRightSixth"
    static let windowLayoutShortcutBottomLeftSixth = "windowLayoutShortcutBottomLeftSixth"
    static let windowLayoutShortcutBottomCenterSixth = "windowLayoutShortcutBottomCenterSixth"
    static let windowLayoutShortcutBottomRightSixth = "windowLayoutShortcutBottomRightSixth"


    // Optional top-of-screen workspace and activity presentations.
    static let notchShowPlayingMusic = "notchShowPlayingMusic"
    static let notchAutoNowPlayingDefaultApplied = "notchAutoNowPlayingDefaultApplied" // local migration marker; never backed up
    static let notchIncludeOtherPlayers = "notchIncludeOtherPlayers"
    static let notchDefaultProfileInitialized = "notchDefaultProfileInitialized" // local migration marker; never backed up
    static let notchInitialExtensionsInstalled = "notchInitialExtensionsInstalled" // local first-install marker; never backed up
    static let notchIdleContent = "notchIdleContent"
    static let notchHiddenControls = "notchHiddenControls"
    // Travels with the controls so old backups migrate and later choices survive.
    static let notchScratchpadControlHidden = "notchScratchpadControlHidden"
    static let notchControlOrder = "notchControlOrder"
    static let notchSize = "notchSize"
    static let notchOutlineEnabled = "notchOutlineEnabled"
    static let notchCustomWidth = "notchCustomWidth"
    static let notchCustomHeight = "notchCustomHeight"
    // Fits the island to one Mac's camera housing; never backed up.
    static let notchCameraFitWidth = "notchCameraFitWidth"
    static let notchCameraFitHeight = "notchCameraFitHeight"
    static let notchHapticFeedback = "notchHapticFeedback"
    static let notchTranslucentBackground = "notchTranslucentBackground"
    static let notchCaptureControls = "notchCaptureControls"
    static let notchAppPanel = "notchAppPanel"
    static let notchHidesMenuBarIcon = "notchHidesMenuBarIcon" // the island takes the glyph's place while it is on
    static let notchKeepAwakeActivity = "notchKeepAwakeActivity" // a running Keep Awake session in the closed island
    static let notchHoverExpands = "notchHoverExpands"
    static let notchGesturesEnabled = "notchGesturesEnabled"
    static let notchKeyboardLight = "notchKeyboardLight"
    static let notchNotificationsEnabled = "notchNotificationsEnabled"
    static let notchDismissNativeNotifications = "notchDismissNativeNotifications"
    static let notchTimerEnabled = "notchTimerEnabled"
    static let notchTimerMode = "notchTimerMode"
    static let notchTimerMinutes = "notchTimerMinutes"
    static let notchTimerSoundEnabled = "notchTimerSoundEnabled"
    static let notchHideTimerCountdown = "notchHideTimerCountdown"
    static let notchPomodoroFocusMinutes = "notchPomodoroFocusMinutes"
    static let notchPomodoroShortBreakMinutes = "notchPomodoroShortBreakMinutes"
    static let notchPomodoroLongBreakMinutes = "notchPomodoroLongBreakMinutes"
    static let notchPomodoroLongBreakInterval = "notchPomodoroLongBreakInterval"
    static let notchPomodoroTotalSessions = "notchPomodoroTotalSessions"
    static let notchAccessoriesEnabled = "notchAccessoriesEnabled"
    static let notchLyricsEnabled = "notchLyricsEnabled"
    static let notchLyricsOnline = "notchLyricsOnline"
    static let notchLiveEqualizer = "notchLiveEqualizer"
    static let notchQueueEnabled = "notchQueueEnabled"
    static let notchDownloadsEnabled = "notchDownloadsEnabled"
    static let notchDownloadsFolderBookmark = "notchDownloadsFolderBookmark"
    // Watch: any part of any window read live in the island.
    static let notchWatchEnabled = "notchWatchEnabled"
    static let notchWatchSound = "notchWatchSound"
    static let notchWatchCondition = "notchWatchCondition"
    static let notchCalendarEnabled = "notchCalendarEnabled"
    static let notchCalendarCountdown = "notchCalendarCountdown"
    static let notchCalendarTimeLeft = "notchCalendarTimeLeft" // the event under way counts down to its end
    static let notchCalendarExcluded = "notchCalendarExcluded" // [EKCalendar.calendarIdentifier] left out of the island
    // [countdown key: event end] chosen from an event's menu; unregistered, so it stays out of backups
    static let notchCalendarChosenCountdowns = "notchCalendarChosenCountdowns"
    static let notchEnabled = "notchEnabled"
    static let notchDisplay = "notchDisplay"
    // How the island looks on a display without a camera housing.
    static let notchSilhouette = "notchSilhouette"
    // The capsule's size and place, fitted by hand on such a display.
    static let notchCapsuleFitWidth = "notchCapsuleFitWidth"
    static let notchCapsuleFitHeight = "notchCapsuleFitHeight"
    static let notchCapsuleFitDrop = "notchCapsuleFitDrop"
    static let notchOpenOnHover = "notchOpenOnHover"
    static let notchHideInFullscreen = "notchHideInFullscreen"
    static let notchHideUntilHover = "notchHideUntilHover"
    static let notchCoversMenus = "notchCoversMenus"
    static let notchHoverDelay = "notchHoverDelay"
    static let notchReturnHome = "notchReturnHome"
    static let notchHomeModule = "notchHomeModule"
    static let notchOpensActivity = "notchOpensActivity"
    static let notchHiddenModules = "notchHiddenModules"
    static let notchModuleOrder = "notchModuleOrder"
    static let notchQuickAccessLayout = "notchQuickAccessLayout"
    static let notchQuickAccessSide = "notchQuickAccessSide"
    static let notchQuickAccessSecond = "notchQuickAccessSecond"
    static let notchQuickAccessThird = "notchQuickAccessThird"
    static let notchVolume = "notchVolume"
    static let notchBrightness = "notchBrightness"
    static let notchBattery = "notchBattery"
    static let notchCapture = "notchCapture"
    static let notchTrackChange = "notchTrackChange"
    static let notchShowInCaptures = "notchShowInCaptures"
    static let notchLockScreen = "notchLockScreen" // music and live activities over the lock screen
    static let notchLockSounds = "notchLockSounds" // padlock sounds as the Mac locks and unlocks
    static let panelControlNotch = "panelControlNotch"


    static let simulateBetaUI = "simulateBetaUI"

    // Keeping the Dock on one display: the feature's own switch, the display
    // it is held to ("main", "builtIn" or a display UUID), and whether the
    // Dock is called back after sleep and display changes.
    static let dockDisplayLockEnabled = "dockDisplayLockEnabled"
    static let dockDisplayLockTarget = "dockDisplayLockTarget"
    static let dockDisplayLockReturns = "dockDisplayLockReturns"

    // Splitting the menu bar into visible and hidden sections.
    static let menuBarHidingEnabled = "menuBarHidingEnabled"
    static let menuBarHidingRehideDelay = "menuBarHidingRehideDelay"

    /// Features hub availability layer, one key per AppFeature raw value.
    /// Registered true: unavailable features vanish from every surface and
    /// hold no resources, without ever touching their own enable keys.
    static func featureAvailable(_ id: String) -> String { "featureAvailable.\(id)" }
}

/// A single invitation for existing Dynamic Island users to turn on display
/// controls after updating. "pending" survives a launch interrupted before
/// the invitation can be shown; "handled" prevents future updates replaying it.
enum BrightnessUpdatePromptInfo {
    static let pending = "pending"
    static let handled = "handled"

    static func isUpgrade(appVersion: String, previousVersion: String?) -> Bool {
        guard let previousVersion,
              let previous = UpdateServiceSupport.SemanticVersion(raw: previousVersion),
              let current = UpdateServiceSupport.SemanticVersion(raw: appVersion) else { return false }
        return current > previous
    }

    static func needsSetup(notchAvailable: Bool, brightnessAvailable: Bool,
                           notchEnabled: Bool, notchBrightness: Bool, brightnessEnabled: Bool) -> Bool {
        notchAvailable && brightnessAvailable && notchEnabled && notchBrightness && !brightnessEnabled
    }
}

enum Defaults {
    static let finderBundleIdentifier = "com.apple.finder"

    static let allowedDurations = [0, 15, 30, 60, 120, 240, 480]
    static let allowedKeepAwakeMouseJiggleIntervals = [1, 2, 5, 10, 15]
    static let allowedBatteryLimits = [0, 5, 10, 20]
    static let allowedMonitorIntervals = [1, 2, 5]
    static let allowedMenuBarPresets = ["dense"]
    static let allowedMenuBarMetricSpacings = ["standard", "compact"]
    static let allowedMenuBarMetricAppearances = ["values", "bars"]
    static let defaultMenuBarMetricOrder = [
        "cpu", "cpuTemperature",
        "gpu", "gpuTemperature",
        "memory",
        "battery", "batteryTime", "batteryTemperature", "peripheralBattery",
        "network", "diskUsage", "diskActivity", "connectedDevices", "power", "fanSpeed",
    ]
    static let allowedMenuBarLabelStyles = ["compact", "classic"]
    static let allowedMenuBarMemoryStyles = ["dot", "percent", "both"]
    static let allowedMonitorMemoryMetrics = ["used", "app"]
    static let allowedMonitorAlertCooldowns = [2, 5, 15, 30, 60]

    static let registeredDefaults: [String: Any] = [
        DefaultsKey.appearance: AppAppearance.fallback.rawValue,
        DefaultsKey.clamshellPreferred: false,
        DefaultsKey.defaultDuration: 0,
        DefaultsKey.batteryLimit: 10,
        DefaultsKey.keepAwakeAutoStart: false,
        DefaultsKey.keepAwakeRightClickToggle: false,
        DefaultsKey.keepAwakeAllowDisplaySleep: false,
        DefaultsKey.keepAwakeExternalDisplay: false,
        DefaultsKey.keepAwakeConnectedToPower: false,
        DefaultsKey.keepAwakeRunningApps: false,
        DefaultsKey.keepAwakeRunningAppBundleIDs: [String](),
        DefaultsKey.keepAwakeAutomationRequireAll: false,
        DefaultsKey.keepAwakePauseWhenLocked: false,
        DefaultsKey.keepAwakeSwitchUsesUntil: false,
        DefaultsKey.keepAwakeUntilTime: 0.0,
        DefaultsKey.keepAwakeMouseJiggleEnabled: false,
        DefaultsKey.keepAwakeMouseJiggleInterval: 5,
        DefaultsKey.hotkeyEnabled: true,
        DefaultsKey.dockDisplayLockEnabled: false,
        DefaultsKey.dockDisplayLockTarget: DockDisplayLockTarget.mainStorage,
        DefaultsKey.dockDisplayLockReturns: false,
        DefaultsKey.menuBarHidingEnabled: false,
        DefaultsKey.menuBarHidingRehideDelay: MenuBarHidingRehideDelay.defaultValue.rawValue,
        DefaultsKey.launchAtLoginWanted: false,
        DefaultsKey.keepAwakeShortcut: "control+option+command:40",
        DefaultsKey.showCountdown: false,
        DefaultsKey.releaseNotesOnUpdate: true,
        DefaultsKey.mixerShowFinder: true,
        DefaultsKey.mixerHideInactiveApps: false,
        DefaultsKey.mixerAppArrangement: "",
        DefaultsKey.mixerLowerVolumeOnHeadphonesDisconnect: false,
        DefaultsKey.mixerHeadphonesDisconnectVolumePercent: defaultMixerHeadphonesDisconnectVolumePercent,
        DefaultsKey.preciseVolumeRollerEnabled: false,
        DefaultsKey.brightnessControlEnabled: false,
        DefaultsKey.brightnessKeysEnabled: false,
        DefaultsKey.brightnessOSDEnabled: false,
        DefaultsKey.brightnessKeyStep: BrightnessSupport.KeyStep.standard.rawValue,
        DefaultsKey.displayBrightnessShortcutsEnabled: false,
        DefaultsKey.displayBrightnessDecreaseShortcut: "shift+command:27",
        DefaultsKey.displayBrightnessIncreaseShortcut: "shift+command:24",
        DefaultsKey.keyboardBrightnessShortcutsEnabled: false,
        DefaultsKey.keyboardBrightnessDecreaseShortcut: "option+command:27",
        DefaultsKey.keyboardBrightnessIncreaseShortcut: "option+command:24",
        DefaultsKey.cleanerScheduleFrequency: "off",
        DefaultsKey.cleanerScheduleHour: 9,
        DefaultsKey.cleanerScheduleMinute: 0,
        DefaultsKey.cleanerScheduleWeekday: 2,
        DefaultsKey.cleanerScheduleNotify: true,
        DefaultsKey.cleanerLastAutoRun: 0.0,
        DefaultsKey.cleanerLastAutoMovedToTrash: 0,
        DefaultsKey.cleanerLastAutoFailed: 0,
        DefaultsKey.cleanerScreenshotAgeDays: CleanerPolicy.defaultScreenshotAgeDays,
        DefaultsKey.cleanerCodingConversationAgeDays: CleanerPolicy.defaultCodingConversationAgeDays,
        DefaultsKey.cleanerLargeFileAgeDays: CleanerPolicy.defaultLargeFileAgeDays,
        DefaultsKey.cleanerLargeFileSizeMegabytes: CleanerPolicy.defaultLargeFileSizeMegabytes,
        DefaultsKey.notchShowPlayingMusic: false,
        DefaultsKey.notchIncludeOtherPlayers: true,
        DefaultsKey.notchIdleContent: NotchIdleContent.none.rawValue,
        DefaultsKey.notchHiddenControls: NotchControlItem.defaultHidden,
        DefaultsKey.notchScratchpadControlHidden: false,
        DefaultsKey.notchControlOrder: "",
        DefaultsKey.notchSize: NotchSize.spacious.rawValue,
        DefaultsKey.notchOutlineEnabled: false,
        DefaultsKey.notchCustomWidth: NotchSize.defaultWidth,
        DefaultsKey.notchCustomHeight: NotchSize.defaultHeight,
        DefaultsKey.notchCameraFitWidth: 0.0,
        DefaultsKey.notchCameraFitHeight: 0.0,
        DefaultsKey.notchHapticFeedback: true,
        DefaultsKey.notchTranslucentBackground: false,
        DefaultsKey.notchCaptureControls: true,
        DefaultsKey.notchAppPanel: false,
        DefaultsKey.notchHidesMenuBarIcon: false,
        DefaultsKey.notchKeepAwakeActivity: false,
        DefaultsKey.notchHoverExpands: true,
        DefaultsKey.notchGesturesEnabled: true,
        DefaultsKey.notchKeyboardLight: true,
        DefaultsKey.notchNotificationsEnabled: true,
        DefaultsKey.notchDismissNativeNotifications: false,
        DefaultsKey.notchTimerEnabled: true,
        DefaultsKey.notchTimerMode: NotchTimerMode.timer.rawValue,
        DefaultsKey.notchTimerMinutes: 15,
        DefaultsKey.notchTimerSoundEnabled: true,
        DefaultsKey.notchHideTimerCountdown: false,
        DefaultsKey.notchPomodoroFocusMinutes: 25,
        DefaultsKey.notchPomodoroShortBreakMinutes: 5,
        DefaultsKey.notchPomodoroLongBreakMinutes: 15,
        DefaultsKey.notchPomodoroLongBreakInterval: 4,
        DefaultsKey.notchPomodoroTotalSessions: 4,
        DefaultsKey.notchAccessoriesEnabled: true,
        DefaultsKey.notchCalendarEnabled: true,
        DefaultsKey.notchCalendarCountdown: false,
        DefaultsKey.notchCalendarTimeLeft: false,
        DefaultsKey.notchCalendarExcluded: [String](),
        DefaultsKey.notchLyricsEnabled: true,
        DefaultsKey.notchLyricsOnline: false,
        DefaultsKey.notchLiveEqualizer: false,
        DefaultsKey.notchQueueEnabled: true,
        DefaultsKey.notchDownloadsEnabled: true,
        DefaultsKey.notchWatchEnabled: true,
        DefaultsKey.notchWatchSound: true,
        DefaultsKey.notchWatchCondition: NotchWatchCondition.changes.rawValue,
        DefaultsKey.notchEnabled: false,
        DefaultsKey.notchDisplay: NotchDisplay.automatic.rawValue,
        DefaultsKey.notchSilhouette: NotchSilhouette.capsule.rawValue,
        DefaultsKey.notchCapsuleFitWidth: 0.0,
        DefaultsKey.notchCapsuleFitHeight: 0.0,
        DefaultsKey.notchCapsuleFitDrop: 0.0,
        DefaultsKey.notchOpenOnHover: false,
        DefaultsKey.notchHideInFullscreen: false,
        DefaultsKey.notchHideUntilHover: false,
        DefaultsKey.notchCoversMenus: true,
        DefaultsKey.notchHoverDelay: NotchSupport.defaultHoverDelay,
        DefaultsKey.notchReturnHome: false,
        DefaultsKey.notchHomeModule: NotchModule.controls.rawValue,
        DefaultsKey.notchOpensActivity: true,
        DefaultsKey.notchHiddenModules: "",
        DefaultsKey.notchModuleOrder: "",
        DefaultsKey.notchQuickAccessLayout: Data(),
        DefaultsKey.notchVolume: true,
        DefaultsKey.notchBrightness: true,
        DefaultsKey.notchBattery: true,
        DefaultsKey.notchCapture: true,
        DefaultsKey.notchTrackChange: true,
        DefaultsKey.notchShowInCaptures: true,
        DefaultsKey.notchLockScreen: false,
        DefaultsKey.notchLockSounds: false,
        DefaultsKey.panelControlNotch: true,
        DefaultsKey.cleaningModeKeepScreenVisible: false,
        DefaultsKey.panelUtilityUninstaller: true,
        DefaultsKey.killProcessGroupRelated: true,
        DefaultsKey.killProcessSortBy: "cpu",
        DefaultsKey.killProcessSortAscending: false,
        DefaultsKey.panelUtilityCleaner: true,
        DefaultsKey.panelUtilityAppUpdates: true,
        DefaultsKey.appUpdatesIncludeHomebrewApps: true,
        DefaultsKey.appUpdatesIncludeAppStore: true,
        DefaultsKey.appUpdatesIncludeOnlineCatalog: true,
        DefaultsKey.appUpdatesRules: "[]",
        DefaultsKey.appUpdatesLastCheck: 0.0,
        DefaultsKey.appUpdatesLastCount: 0,
        DefaultsKey.appUpdatesNotifiedIDs: [String](),
        DefaultsKey.panelUtilityMedia: true,
        DefaultsKey.panelShowKeepAwake: true,
        DefaultsKey.panelShowBrightness: true,
        DefaultsKey.panelShowUtilities: true,
        // Menu bar metrics start off (the icon stays clean) and are opt-in.
        // The panel shows every monitoring block by default; users hide what
        // they don't want.
        DefaultsKey.monitorInterval: 2,
        DefaultsKey.temperatureUnit: TemperatureUnit.celsius.rawValue,
        DefaultsKey.menuBarCPUTemperature: false,
        DefaultsKey.menuBarGPUTemperature: false,
        DefaultsKey.menuBarBatteryTemperature: false,
        DefaultsKey.menuBarBatteryTime: false,
        DefaultsKey.menuBarDiskUsage: false,
        DefaultsKey.menuBarDiskActivity: false,
        DefaultsKey.menuBarPeripheralBattery: false,
        DefaultsKey.menuBarConnectedDevices: false,
        DefaultsKey.menuBarFanSpeed: false,
        DefaultsKey.menuBarPreset: "dense",
        DefaultsKey.menuBarMetricSpacing: "compact",  // owner's call: compact by default
        DefaultsKey.menuBarMetricAppearance: "values",
        DefaultsKey.menuBarUsageBarNormalColor: MenuBarUsageBarSupport.defaultNormalColor,
        DefaultsKey.menuBarUsageBarElevatedColor: MenuBarUsageBarSupport.defaultElevatedColor,
        DefaultsKey.menuBarUsageBarCriticalColor: MenuBarUsageBarSupport.defaultCriticalColor,
        DefaultsKey.menuBarUsageBarMediumThreshold: MenuBarUsageBarSupport.defaultMediumThreshold,
        DefaultsKey.menuBarUsageBarHighThreshold: MenuBarUsageBarSupport.defaultHighThreshold,
        DefaultsKey.menuBarHideIconWithMetrics: false,
        DefaultsKey.windowLayoutHiddenActions: "",
        DefaultsKey.windowLayoutWindowGap: 0,
        DefaultsKey.windowLayoutScreenGap: 0,
        DefaultsKey.windowLayoutMarginPercent: 5.0,
        DefaultsKey.windowLayoutSideRepeatCyclesThirds: false,
        DefaultsKey.menuBarMetricOrder: defaultMenuBarMetricOrder.joined(separator: ","),
        DefaultsKey.menuBarCombineTemperatures: true,
        DefaultsKey.menuBarSeparateMetrics: false,
        DefaultsKey.menuBarNetworkUploadFirst: false,
        DefaultsKey.menuBarLabelStyle: "compact",
        DefaultsKey.menuBarMemoryStyle: "percent",
        DefaultsKey.menuBarDiskStyle: "percent",
        DefaultsKey.monitorMemoryMetric: "used",
        DefaultsKey.monitorShowSystem: true,
        DefaultsKey.monitorShowNetwork: true,
        DefaultsKey.monitorShowDisk: true,
        DefaultsKey.monitorShowPower: true,
        DefaultsKey.monitorShowMixer: true,
        DefaultsKey.panelShowFanControl: true,
        DefaultsKey.fanControlMode: FanControlMode.system.rawValue,
        DefaultsKey.fanControlCoolingLevel: FanControlPolicy.defaultCoolingLevel,
        DefaultsKey.fanControlCurves: FanControlConfiguration.defaultCurvesStorage,
        DefaultsKey.fanControlResume: false,
        DefaultsKey.fanControlResumeConfiguration: "",
        DefaultsKey.fanControlRecoveryNeeded: false,
        DefaultsKey.fanControlHelperVersion: "",
        DefaultsKey.panelNavigationEnabled: true,
        DefaultsKey.monitorGraphCPU: true,
        DefaultsKey.monitorGraphGPU: true,
        DefaultsKey.monitorGraphMemory: true,
        DefaultsKey.monitorGraphNetwork: true,
        DefaultsKey.monitorGraphDisk: true,
        DefaultsKey.monitorGraphPower: true,
        DefaultsKey.monitorGraphBattery: true,
        DefaultsKey.monitorGraphScale: true,
        // Every per-item block shows by default; users hide what they don't want.
        DefaultsKey.monitorSysTemps: true,
        DefaultsKey.monitorSysCPU: true,
        DefaultsKey.monitorSysGPU: true,
        DefaultsKey.monitorSysBattery: true,
        DefaultsKey.monitorSysMemory: true,
        DefaultsKey.monitorSysAlerts: true,
        DefaultsKey.monitorSysUptime: true,
        DefaultsKey.monitorSysFans: true,
        DefaultsKey.monitorNetSpeed: true,
        DefaultsKey.monitorNetApps: true,
        DefaultsKey.monitorNetTotals: true,
        DefaultsKey.monitorNetAddresses: true,
        DefaultsKey.monitorNetTest: true,
        DefaultsKey.monitorDiskUsage: true,
        DefaultsKey.monitorDiskActivity: true,
        DefaultsKey.monitorDiskSMART: true,
        DefaultsKey.monitorDiskProtection: true,
        DefaultsKey.monitorDiskTools: true,
        DefaultsKey.monitorPwrTemperature: true,
        DefaultsKey.monitorPwrSystem: true,
        DefaultsKey.monitorPwrAdapter: true,
        DefaultsKey.monitorPwrBattery: true,
        DefaultsKey.monitorPwrTimeRemaining: true,
        DefaultsKey.monitorPwrHealth: true,
        DefaultsKey.monitorAlertCPU: false,
        DefaultsKey.monitorAlertCPUTemperature: false,
        DefaultsKey.monitorAlertBatteryTemperature: false,
        DefaultsKey.monitorAlertMemory: false,
        DefaultsKey.monitorAlertDisk: false,
        DefaultsKey.monitorAlertBattery: false,
        DefaultsKey.monitorAlertCPUThreshold: 90,
        DefaultsKey.monitorAlertCPUTemperatureThreshold: 90,
        DefaultsKey.monitorAlertBatteryTemperatureThreshold: 40,
        DefaultsKey.monitorAlertDiskFreePercent: 10,
        DefaultsKey.monitorAlertBatteryPercent: 15,
        DefaultsKey.monitorAlertCooldownMinutes: 15,
        DefaultsKey.mediaLastTool: MediaTool.videoCompressor.rawValue,
        DefaultsKey.mediaVideoStart: 0.0,
        DefaultsKey.mediaVideoEnd: 0.0,
        DefaultsKey.mediaVideoQuality: 0.68,
        DefaultsKey.mediaVideoMaxDimension: 1280,
        DefaultsKey.mediaVideoFPS: 30.0,
        DefaultsKey.mediaVideoKeepAudio: true,
        DefaultsKey.mediaVideoCodec: MediaVideoCodec.h264.rawValue,
        DefaultsKey.mediaVideoSizing: MediaSizingMode.resolution.rawValue,
        DefaultsKey.mediaVideoTargetMegabytes: 20,
        DefaultsKey.mediaGIFStart: 0.0,
        DefaultsKey.mediaGIFEnd: 0.0,
        DefaultsKey.mediaGIFQuality: 0.74,
        DefaultsKey.mediaGIFWidth: 720,
        DefaultsKey.mediaGIFFPS: 12.0,
        DefaultsKey.mediaGIFLoops: true,
        DefaultsKey.mediaGIFSizing: MediaSizingMode.resolution.rawValue,
        DefaultsKey.mediaGIFTargetMegabytes: 10,
        DefaultsKey.mediaImageQuality: 0.68,
        DefaultsKey.mediaImageMaxDimension: 1600,
        DefaultsKey.mediaImageFormat: MediaImageFormat.jpeg.rawValue,
        DefaultsKey.mediaImageStripMetadata: true,
        DefaultsKey.mediaImageResizeKind: MediaImageResizeKind.maxDimension.rawValue,
        DefaultsKey.mediaImageResizeWidth: 1600,
        DefaultsKey.mediaImageResizeHeight: 1200,
        DefaultsKey.mediaImageExactResizeMode: MediaImageExactResizeMode.stretch.rawValue,
        DefaultsKey.mediaImageWatermarkKind: MediaImageWatermarkKind.off.rawValue,
        DefaultsKey.mediaImageWatermarkText: "",
        DefaultsKey.mediaImageWatermarkLogoPath: "",
        DefaultsKey.mediaImageWatermarkPosition: MediaImageWatermarkPosition.bottomRight.rawValue,
        DefaultsKey.mediaImageWatermarkOpacity: 0.45,
        DefaultsKey.mediaImageWatermarkMargin: 32,
        DefaultsKey.mediaImageWatermarkScale: 0.18,
        DefaultsKey.mediaImageRenamePattern: "",
        DefaultsKey.mediaImageBackground: MediaImageBackground.transparent.rawValue,
        DefaultsKey.mediaImagePreserveModificationDate: false,
        DefaultsKey.mediaImageSaveInSubfolder: false,
        DefaultsKey.mediaImageProfiles: "[]",
        DefaultsKey.mediaImageSelectedProfileID: "",
        DefaultsKey.mediaTextAccurate: true,
        DefaultsKey.mediaTextLanguageCorrection: true,
        DefaultsKey.windowLayoutIgnoredApps: [String](),
        DefaultsKey.diskEjectExcludedVolumes: [String](),
        DefaultsKey.colorPickerShortcutEnabled: false,
        DefaultsKey.colorPickerShortcut: GlobalShortcut.colorPickerDefault.storageValue,
        DefaultsKey.colorPickerFormat: "hex",
        DefaultsKey.colorPickerBareHex: false,
        DefaultsKey.screenOCRShortcutEnabled: false,
        DefaultsKey.screenOCRShortcut: GlobalShortcut.screenOCRDefault.storageValue,
        DefaultsKey.screenOCRRemoveLineBreaks: false,
        DefaultsKey.screenOCRDetectQRCodes: true,
        DefaultsKey.wallpaperApplyAllDisplays: true,
        DefaultsKey.wallpaperFilter: "all",
        DefaultsKey.panelUtilityScreenOCR: true,
        DefaultsKey.recorderShortcutEnabled: false,
        DefaultsKey.recorderShortcut: GlobalShortcut.screenRecorderDefault.storageValue,
        DefaultsKey.recorderCountdown: 3,
        DefaultsKey.recorderFrameRate: 60,
        DefaultsKey.recorderSystemAudio: true,
        DefaultsKey.recorderMicrophone: false,
        DefaultsKey.recorderSaveFolder: "",
        DefaultsKey.recorderOpenEditor: true,
        DefaultsKey.recorderAutomaticZoom: true,
        DefaultsKey.recorderGIFFrameRate: 12,
        DefaultsKey.recorderEditorPresets: Data(),
        DefaultsKey.recorderSharingEnabled: true,
        DefaultsKey.panelUtilityPortManager: true,
        DefaultsKey.panelUtilityKillProcess: true,
        DefaultsKey.panelUtilityPurgeMemory: true,
        DefaultsKey.panelUtilityFlushDNS: true,
        DefaultsKey.panelQuickBrightness: true,
        DefaultsKey.screenshotShowCaptureMenuOnShortcut: true,
        DefaultsKey.recorderShowCaptureMenuOnShortcut: true,
        DefaultsKey.screenOCRShowCaptureMenuOnShortcut: true,
        DefaultsKey.colorPickerShowCaptureMenuOnShortcut: true,
        DefaultsKey.screenshotShortcutEnabled: false,
        DefaultsKey.screenshotShortcut: GlobalShortcut.screenshotDefault.storageValue,
        DefaultsKey.unifiedScreenCaptureShortcutMigrated: false,
        DefaultsKey.restoredScreenCaptureShortcutsMigrated: false,
        DefaultsKey.screenshotFullScreenShortcutEnabled: false,
        DefaultsKey.screenshotFullScreenShortcut: GlobalShortcut.screenshotFullScreenDefault.storageValue,
        DefaultsKey.screenshotLastCaptureShortcutEnabled: false,
        DefaultsKey.screenshotLastCaptureShortcut: GlobalShortcut.screenshotLastCaptureDefault.storageValue,
        DefaultsKey.recentCapturesShortcutEnabled: false,
        DefaultsKey.recentCapturesShortcut: GlobalShortcut.recentCapturesDefault.storageValue,
        DefaultsKey.screenshotClipboardShortcutEnabled: false,
        DefaultsKey.screenshotClipboardShortcut: GlobalShortcut.screenshotClipboardDefault.storageValue,
        DefaultsKey.screenshotFreeze: true,
        DefaultsKey.screenshotHideHexaWindows: true,
        DefaultsKey.screenshotAutoSaveToFolder: false,
        DefaultsKey.screenshotSaveFolder: "",
        DefaultsKey.screenshotSaveSubfolder: "",
        DefaultsKey.screenshotFileNamePattern: "",
        DefaultsKey.screenshotFileNumberNext: 1,
        // DEC-030: a fresh install saves every capture.
        DefaultsKey.screenshotDefaultAction: ScreenshotDefaultAction.save.rawValue,
        DefaultsKey.screenshotIncludePointer: false,
        DefaultsKey.screenshotShowLastRegion: true,
        DefaultsKey.screenshotLoupeStartsOn: false,
        DefaultsKey.screenshotLoupeRememberZoom: false,
        DefaultsKey.screenshotLoupeDefaultZoom: 1.0,
        DefaultsKey.screenshotLoupeLastZoom: 1.0,
        DefaultsKey.screenshotLoupeSteppedZoomByDefault: false,
        DefaultsKey.screenshotDownscale: false,
        DefaultsKey.screenshotDelay: 0,
        DefaultsKey.screenshotLastTool: "arrow",
        DefaultsKey.screenshotLastColor: "red",
        DefaultsKey.screenshotLastStroke: "medium",
        DefaultsKey.screenshotLastTextSize: ScreenshotSupport.defaultTextSize,
        DefaultsKey.screenshotLastBlurLevel: ScreenshotSupport.BlurStrength.defaultLevel,
        DefaultsKey.screenshotLastArrowStyle: "filled",
        DefaultsKey.screenshotLastSticker: "check",
        DefaultsKey.screenshotAnnotationShadows: false,
        DefaultsKey.screenshotToolOrder: ScreenshotSupport.Tool.defaultOrderStorage,
        DefaultsKey.screenshotToolShortcutsEnabled: true,
        DefaultsKey.screenshotToolShortcuts: "",
        DefaultsKey.screenshotBackdropStyle: "",
        DefaultsKey.screenshotBackdropPresets: "[]",
        DefaultsKey.screenshotWatermarkStyle: "",
        DefaultsKey.screenshotWatermarkPresets: "[]",
        DefaultsKey.screenshotOpenEditorDirectly: false,
        DefaultsKey.screenshotCopyToClipboard: false,
        DefaultsKey.screenshotPreviewPosition: ScreenshotSupport.QuickPreviewPosition.automatic.rawValue,
        DefaultsKey.screenshotPreviewDestination: ScreenshotSupport.QuickPreviewDestination.notch.rawValue,
        DefaultsKey.screenshotPreviewTakesFocus: false,
        DefaultsKey.screenshotPreviewEnabled: false,
        DefaultsKey.screenshotPreviewDuration: ScreenshotSupport.defaultConfirmationPreviewDuration,
        DefaultsKey.panelUtilityScreenshot: true,
        DefaultsKey.windowLayoutShortcutsEnabled: false,
        DefaultsKey.windowDirectionalEnabled: false,
        DefaultsKey.windowDirectionalShortcut: GlobalShortcut.windowDirectionalDefault.storageValue,
        DefaultsKey.pointerDisplayEnabled: false,
        DefaultsKey.pointerDisplayShortcut: GlobalShortcut.pointerNextDisplayDefault.storageValue,
        DefaultsKey.windowEdgeSnapEnabled: false,
        DefaultsKey.windowEdgeSnapDisabledZones: "",
        DefaultsKey.windowGestureEnabled: false,
        DefaultsKey.windowGestureRaiseWindow: false,
        DefaultsKey.windowLayoutShortcutLeft: GlobalShortcut.windowLayoutLeftDefault.storageValue,
        DefaultsKey.windowLayoutShortcutRight: GlobalShortcut.windowLayoutRightDefault.storageValue,
        DefaultsKey.windowLayoutShortcutTop: GlobalShortcut.windowLayoutTopDefault.storageValue,
        DefaultsKey.windowLayoutShortcutBottom: GlobalShortcut.windowLayoutBottomDefault.storageValue,
        DefaultsKey.windowLayoutShortcutCenterHalf: "",
        DefaultsKey.windowLayoutShortcutTopLeft: GlobalShortcut.windowLayoutTopLeftDefault.storageValue,
        DefaultsKey.windowLayoutShortcutTopRight: GlobalShortcut.windowLayoutTopRightDefault.storageValue,
        DefaultsKey.windowLayoutShortcutBottomLeft: GlobalShortcut.windowLayoutBottomLeftDefault.storageValue,
        DefaultsKey.windowLayoutShortcutBottomRight: GlobalShortcut.windowLayoutBottomRightDefault.storageValue,
        DefaultsKey.windowLayoutShortcutMaximize: GlobalShortcut.windowLayoutMaximizeDefault.storageValue,
        DefaultsKey.windowLayoutShortcutMarginMaximize: "",
        DefaultsKey.windowLayoutShortcutCenter: GlobalShortcut.windowLayoutCenterDefault.storageValue,
        DefaultsKey.windowLayoutShortcutRestore: GlobalShortcut.windowLayoutRestoreDefault.storageValue,
        DefaultsKey.windowLayoutShortcutLeftThird: GlobalShortcut.windowLayoutLeftThirdDefault.storageValue,
        DefaultsKey.windowLayoutShortcutCenterThird: GlobalShortcut.windowLayoutCenterThirdDefault.storageValue,
        DefaultsKey.windowLayoutShortcutRightThird: GlobalShortcut.windowLayoutRightThirdDefault.storageValue,
        DefaultsKey.windowLayoutShortcutLeftTwoThirds: GlobalShortcut.windowLayoutLeftTwoThirdsDefault.storageValue,
        DefaultsKey.windowLayoutShortcutRightTwoThirds: GlobalShortcut.windowLayoutRightTwoThirdsDefault.storageValue,
        DefaultsKey.windowLayoutShortcutCenterTwoThirds: "",
        DefaultsKey.windowLayoutShortcutTopThird: "",
        DefaultsKey.windowLayoutShortcutMiddleThird: "",
        DefaultsKey.windowLayoutShortcutBottomThird: "",
        DefaultsKey.windowLayoutShortcutTopTwoThirds: "",
        DefaultsKey.windowLayoutShortcutBottomTwoThirds: "",
        DefaultsKey.windowLayoutShortcutTopQuarter: "",
        DefaultsKey.windowLayoutShortcutUpperMiddleQuarter: "",
        DefaultsKey.windowLayoutShortcutLowerMiddleQuarter: "",
        DefaultsKey.windowLayoutShortcutBottomQuarter: "",
        DefaultsKey.windowLayoutShortcutLeftQuarter: "",
        DefaultsKey.windowLayoutShortcutLeftMiddleQuarter: "",
        DefaultsKey.windowLayoutShortcutRightMiddleQuarter: "",
        DefaultsKey.windowLayoutShortcutRightQuarter: "",
        DefaultsKey.windowLayoutShortcutPreviousDisplay: "",
        DefaultsKey.windowLayoutShortcutNextDisplay: GlobalShortcut.windowLayoutNextDisplayDefault.storageValue,
        DefaultsKey.windowLayoutShortcutTopLeftSixth: "",
        DefaultsKey.windowLayoutShortcutTopCenterSixth: "",
        DefaultsKey.windowLayoutShortcutTopRightSixth: "",
        DefaultsKey.windowLayoutShortcutBottomLeftSixth: "",
        DefaultsKey.windowLayoutShortcutBottomCenterSixth: "",
        DefaultsKey.windowLayoutShortcutBottomRightSixth: "",
        DefaultsKey.windowLayoutShortcutFullScreen: "",
    ]

    static func register() {
        let defaults = UserDefaults.standard
        migrateExistingNotchDefaults(in: defaults)
        migrateAutoNowPlayingDefault(in: defaults)
        removeNotchMascotDefaults(in: defaults)
        migrateFanControlVisibility(in: defaults)
        migrateBatteryTemperatureVisibility(in: defaults)
        migrateLegacyMenuBarHidingPreference(in: defaults)
        defaults.register(defaults: registeredDefaults)
        defaults.register(defaults: AppFeature.availabilityDefaults)
        migrateLegacyMenuBarTemperatureMetric(in: defaults)
        migrateUtilityOrderForScreenshot(in: defaults)
        migrateUtilityOrderForAppUpdates(in: defaults)
        migrateScreenshotOpenEditorDirectly(in: defaults)
        migrateUnifiedScreenCaptureShortcut(in: defaults)
        migrateRestoredScreenCaptureShortcuts(in: defaults)
        migrateOrphanedCaptureShortcut(in: defaults)
        migrateSilentHeadphonesDisconnectVolume(in: defaults)
        recheckBrightnessDDCWriteOnlyPaths(in: defaults)
    }

    /// Retire the v1 always-hidden toggle without touching NSStatusItem's
    /// saved positions. The old section was already to the hidden side of
    /// the remaining arrow, so those icons continue to use standard hiding.
    static func migrateLegacyMenuBarHidingPreference(in defaults: UserDefaults) {
        defaults.removeObject(forKey: "menuBarHidingAlwaysHidden")
    }

    /// Keep the previous implicit choices for people who already configured
    /// the island. A fresh setup gets the new profile instead.
    static func migrateExistingNotchDefaults(in defaults: UserDefaults,
                                             domainName: String? = Bundle.main.bundleIdentifier) {
        guard let domainName else { return }
        let saved = defaults.persistentDomain(forName: domainName) ?? [:]
        guard saved[DefaultsKey.notchDefaultProfileInitialized] == nil else {
            // The previous profile registered Compact without persisting it.
            // Preserve that implicit choice before registering Spacious.
            if saved[DefaultsKey.notchSize] == nil {
                defaults.set(NotchSize.compact.rawValue, forKey: DefaultsKey.notchSize)
            }
            return
        }
        let automaticKeys: Set<String> = [DefaultsKey.notchScratchpadControlHidden,
                                          DefaultsKey.notchHidesMenuBarIcon]
        let wasConfigured = saved.keys.contains {
            $0.hasPrefix("notch") && !automaticKeys.contains($0)
                && ($0 != DefaultsKey.notchHiddenControls
                    || saved[$0] as? String != NotchControlItem.defaultHidden)
        } || saved[DefaultsKey.notchHidesMenuBarIcon] as? Bool == true
        if wasConfigured {
            defaults.set(true, forKey: DefaultsKey.notchInitialExtensionsInstalled)
            let previous: [String: Any] = [
                DefaultsKey.notchSize: NotchSize.spacious.rawValue,
                DefaultsKey.notchAppPanel: true,
                DefaultsKey.notchKeyboardLight: false,
                DefaultsKey.notchNotificationsEnabled: false,
                DefaultsKey.notchAccessoriesEnabled: false,
                DefaultsKey.notchLyricsEnabled: false,
                DefaultsKey.notchLiveEqualizer: false,
                DefaultsKey.notchQueueEnabled: false,
                DefaultsKey.notchDownloadsEnabled: false,
                DefaultsKey.notchOpenOnHover: true,
                DefaultsKey.notchCapture: false,
                DefaultsKey.notchTrackChange: false,
            ]
            for (key, value) in previous where saved[key] == nil {
                defaults.set(value, forKey: key)
            }
        }
        if !wasConfigured {
            // Pin the new choice so subsequent launches cannot mistake this
            // setup for an older profile with an implicit Compact size.
            defaults.set(NotchSize.spacious.rawValue, forKey: DefaultsKey.notchSize)
        }
        defaults.set(true, forKey: DefaultsKey.notchDefaultProfileInitialized)
    }

    /// The island used to take Now Playing as soon as media played. Controls
    /// stay the factory face (DEC-006, DEC-023); a stored yes is turned off
    /// once so that choice is opt-in.
    static func migrateAutoNowPlayingDefault(in defaults: UserDefaults) {
        guard !defaults.bool(forKey: DefaultsKey.notchAutoNowPlayingDefaultApplied) else { return }
        defaults.set(false, forKey: DefaultsKey.notchShowPlayingMusic)
        if defaults.string(forKey: DefaultsKey.notchIdleContent) == NotchIdleContent.music.rawValue {
            defaults.set(NotchIdleContent.none.rawValue, forKey: DefaultsKey.notchIdleContent)
        }
        defaults.set(true, forKey: DefaultsKey.notchAutoNowPlayingDefaultApplied)
    }

    /// Discovery used to send one request per read, which reads a monitor that
    /// answers only paired requests as write-only. That verdict is cached and
    /// never re-probed, so it would outlive the fix: drop the cache once.
    static func recheckBrightnessDDCWriteOnlyPaths(in defaults: UserDefaults) {
        guard !defaults.bool(forKey: DefaultsKey.brightnessDDCWriteOnlyPathsRechecked) else {
            return
        }
        defaults.set(true, forKey: DefaultsKey.brightnessDDCWriteOnlyPathsRechecked)
        defaults.removeObject(forKey: DefaultsKey.brightnessDDCWriteOnlyPaths)
    }

    /// The Companheiro was removed: its installed flag and saved choices, and
    /// the Command Bar switch that only it read, are dropped once. Literal
    /// names on purpose, since their keys no longer exist in `DefaultsKey`.
    static func removeNotchMascotDefaults(in defaults: UserDefaults) {
        let removed = ["featureAvailable.notchMascot", "notchMascotBetaInstalled", "notchMascotEnabled",
                       "notchMascotVisits", "notchMascotReactions", "notchMascotStyle", "notchMascotShape",
                       "notchMascotPalette", "notchMascotSide", "notchMascotVisitFrequency",
                       "notchCommandBar", "notchCommandBarStyle"]
        for key in removed {
            defaults.removeObject(forKey: key)
        }
    }

    static func migrateBatteryTemperatureVisibility(in defaults: UserDefaults) {
        guard defaults.object(forKey: DefaultsKey.monitorPwrTemperature) == nil else { return }
        defaults.set(defaults.object(forKey: DefaultsKey.monitorSysTemps) as? Bool ?? true,
                     forKey: DefaultsKey.monitorPwrTemperature)
    }

    static func migrateFanControlVisibility(in defaults: UserDefaults) {
        if let oldValue = defaults.object(forKey: DefaultsKey.monitorShowFanControlBeta) as? Bool {
            if defaults.object(forKey: DefaultsKey.panelShowFanControl) == nil {
                defaults.set(oldValue, forKey: DefaultsKey.panelShowFanControl)
            }
            if oldValue,
               defaults.object(forKey: AppFeature.fanControl.availabilityKey) == nil {
                defaults.set(true, forKey: AppFeature.fanControl.availabilityKey)
            }
        }
        defaults.removeObject(forKey: DefaultsKey.monitorShowFanControlBeta)
    }

    /// The "open the editor right after capturing" toggle became the Edit
    /// choice of the after-capture action picker. A setup that jumped
    /// straight into the editor keeps doing exactly that, unless a newer
    /// picker choice already exists.
    static func migrateScreenshotOpenEditorDirectly(in defaults: UserDefaults,
                                                    domainName: String? = Bundle.main.bundleIdentifier) {
        guard defaults.bool(forKey: DefaultsKey.screenshotOpenEditorDirectly) else { return }
        defaults.set(false, forKey: DefaultsKey.screenshotOpenEditorDirectly)
        // The registered default is a real action now, so only the persistent
        // domain tells a picker choice apart from no choice.
        let saved = domainName.flatMap { defaults.persistentDomain(forName: $0) } ?? [:]
        let action = saved[DefaultsKey.screenshotDefaultAction] as? String ?? ""
        guard action.isEmpty else { return }
        defaults.set(ScreenshotDefaultAction.edit.rawValue,
                     forKey: DefaultsKey.screenshotDefaultAction)
    }

    /// The four screen tools now share the screenshot shortcut. Preserve the
    /// first dedicated shortcut an existing setup had enabled, while fresh
    /// installs keep the combined shortcut off by default.
    static func migrateUnifiedScreenCaptureShortcut(in defaults: UserDefaults) {
        guard !defaults.bool(forKey: DefaultsKey.unifiedScreenCaptureShortcutMigrated) else {
            return
        }
        defer {
            defaults.set(true, forKey: DefaultsKey.unifiedScreenCaptureShortcutMigrated)
        }
        guard !defaults.bool(forKey: DefaultsKey.screenshotShortcutEnabled) else { return }

        let legacyChoices: [(enabled: String, shortcut: String, fallback: GlobalShortcut)] = [
            (DefaultsKey.recorderShortcutEnabled,
             DefaultsKey.recorderShortcut,
             .screenRecorderDefault),
            (DefaultsKey.screenOCRShortcutEnabled,
             DefaultsKey.screenOCRShortcut,
             .screenOCRDefault),
            (DefaultsKey.colorPickerShortcutEnabled,
             DefaultsKey.colorPickerShortcut,
             .colorPickerDefault),
        ]
        guard let choice = legacyChoices.first(where: {
            defaults.bool(forKey: $0.enabled)
        }) else { return }
        let shortcut = defaults.string(forKey: choice.shortcut) ?? choice.fallback.storageValue
        defaults.set(true, forKey: DefaultsKey.screenshotShortcutEnabled)
        defaults.set(shortcut, forKey: DefaultsKey.screenshotShortcut)
    }

    /// The unified-capture migration copied an enabled dedicated shortcut to
    /// the general capture role. Now that dedicated shortcuts are back, keep
    /// the original role instead of registering the same combination twice.
    static func migrateRestoredScreenCaptureShortcuts(in defaults: UserDefaults) {
        guard !defaults.bool(forKey: DefaultsKey.restoredScreenCaptureShortcutsMigrated) else {
            return
        }
        defer {
            defaults.set(true, forKey: DefaultsKey.restoredScreenCaptureShortcutsMigrated)
        }
        guard defaults.bool(forKey: DefaultsKey.screenshotShortcutEnabled),
              let generalShortcut = defaults.string(forKey: DefaultsKey.screenshotShortcut)
        else { return }

        let dedicatedKeys = [
            (DefaultsKey.recorderShortcutEnabled, DefaultsKey.recorderShortcut),
            (DefaultsKey.screenOCRShortcutEnabled, DefaultsKey.screenOCRShortcut),
            (DefaultsKey.colorPickerShortcutEnabled, DefaultsKey.colorPickerShortcut),
        ]
        guard dedicatedKeys.contains(where: { enabledKey, shortcutKey in
            defaults.bool(forKey: enabledKey)
                && defaults.string(forKey: shortcutKey) == generalShortcut
        }) else { return }
        defaults.set(false, forKey: DefaultsKey.screenshotShortcutEnabled)
    }

    /// The general capture shortcut now belongs to the screenshot tool, so on
    /// an install without that tool a saved combination would register
    /// nothing. Move it once onto the first available tool that has no
    /// shortcut of its own, so the combination keeps opening the chooser.
    /// A tool whose shortcut is switched off but was customized still counts
    /// as having its own, so its saved combination is never overwritten.
    /// Availability is read from the passed defaults — the same key
    /// `isAvailable` reads from the standard ones — to stay testable.
    static func migrateOrphanedCaptureShortcut(in defaults: UserDefaults) {
        guard !defaults.bool(forKey: DefaultsKey.orphanedCaptureShortcutMigrated) else {
            return
        }
        defer {
            defaults.set(true, forKey: DefaultsKey.orphanedCaptureShortcutMigrated)
        }
        guard defaults.bool(forKey: DefaultsKey.screenshotShortcutEnabled),
              !defaults.bool(forKey: AppFeature.screenshot.availabilityKey)
        else { return }
        let shortcut = defaults.string(forKey: DefaultsKey.screenshotShortcut)
            ?? GlobalShortcut.screenshotDefault.storageValue

        let candidates: [(feature: AppFeature, enabled: String,
                          shortcut: String, unset: String)] = [
            (.screenOCR, DefaultsKey.screenOCRShortcutEnabled,
             DefaultsKey.screenOCRShortcut,
             GlobalShortcut.screenOCRDefault.storageValue),
        ]
        guard let target = candidates.first(where: {
            defaults.bool(forKey: $0.feature.availabilityKey)
                && !defaults.bool(forKey: $0.enabled)
                && (defaults.string(forKey: $0.shortcut) ?? $0.unset) == $0.unset
        }) else { return }
        defaults.set(true, forKey: target.enabled)
        defaults.set(shortcut, forKey: target.shortcut)
        defaults.set(false, forKey: DefaultsKey.screenshotShortcutEnabled)
    }

    static func migrateUtilityOrderForScreenshot(in defaults: UserDefaults) {
        guard let storedOrder = defaults.object(forKey: DefaultsKey.panelUtilityOrder) as? String else {
            return
        }
        let ids = storedOrder.split(separator: ",").map(String.init)
        guard !ids.contains("screenshot") else { return }
        defaults.set((["screenshot"] + ids).joined(separator: ","),
                     forKey: DefaultsKey.panelUtilityOrder)
    }

    /// App updates joins the panel next to the other app-management tools
    /// instead of at the end of a long list, without disturbing the rest of
    /// a layout the user arranged.
    static func migrateUtilityOrderForAppUpdates(in defaults: UserDefaults) {
        guard let storedOrder = defaults.object(forKey: DefaultsKey.panelUtilityOrder) as? String else {
            return
        }
        defaults.set(utilityOrderWithAppUpdates(storedOrder).joined(separator: ","),
                     forKey: DefaultsKey.panelUtilityOrder)
    }

    static func utilityOrderWithAppUpdates(_ storedOrder: String) -> [String] {
        var ids = storedOrder.split(separator: ",").map(String.init)
        guard !ids.contains("appUpdates") else { return ids }
        let anchor = ids.firstIndex(of: "cleaner") ?? min(1, ids.count)
        ids.insert("appUpdates", at: anchor)
        return ids
    }

    static func sanitizedDefaultDuration(_ minutes: Int) -> Int {
        allowedDurations.contains(minutes) ? minutes : 0
    }

    static func sanitizedBatteryLimit(_ percent: Int) -> Int {
        allowedBatteryLimits.contains(percent) ? percent : 10
    }

    static func sanitizedKeepAwakeMouseJiggleInterval(_ minutes: Int) -> Int {
        allowedKeepAwakeMouseJiggleIntervals.contains(minutes) ? minutes : 5
    }

    static func sanitizedMonitorInterval(_ seconds: Int) -> Int {
        allowedMonitorIntervals.contains(seconds) ? seconds : 2
    }

    static func sanitizedMenuBarPreset(_ preset: String) -> String {
        allowedMenuBarPresets.contains(preset) ? preset : "dense"
    }

    static func sanitizedMenuBarMetricSpacing(_ spacing: String) -> String {
        // Corrupt values fall back to the registered default (compact).
        allowedMenuBarMetricSpacings.contains(spacing) ? spacing : "compact"
    }

    static func sanitizedMenuBarMetricAppearance(_ appearance: String) -> String {
        allowedMenuBarMetricAppearances.contains(appearance) ? appearance : "values"
    }

    static func sanitizedMenuBarMetricOrder(_ raw: String) -> [String] {
        let defaults = defaultMenuBarMetricOrder
        var seen = Set<String>()
        var result: [String] = []
        for rawValue in raw.split(separator: ",").map({ String($0) }) {
            let values = rawValue == "temperature"
                ? ["cpuTemperature", "gpuTemperature", "batteryTemperature"]
                : [rawValue]
            for value in values {
                guard defaults.contains(value), !seen.contains(value) else { continue }
                seen.insert(value)
                result.append(value)
            }
        }
        for value in defaults where !seen.contains(value) {
            result.append(value)
        }
        return result
    }

    private static func migrateLegacyMenuBarTemperatureMetric(in defaults: UserDefaults) {
        guard let domainName = Bundle.main.bundleIdentifier,
              let domain = defaults.persistentDomain(forName: domainName),
              let legacyEnabled = domain[DefaultsKey.menuBarTemperature] as? Bool
        else { return }

        let newKeys = [
            DefaultsKey.menuBarCPUTemperature,
            DefaultsKey.menuBarGPUTemperature,
            DefaultsKey.menuBarBatteryTemperature,
        ]
        let alreadyMigrated = newKeys.contains { domain[$0] != nil }
        if legacyEnabled, !alreadyMigrated {
            for key in newKeys {
                defaults.set(true, forKey: key)
            }
        }
        if let rawOrder = domain[DefaultsKey.menuBarMetricOrder] as? String {
            defaults.set(sanitizedMenuBarMetricOrder(rawOrder).joined(separator: ","),
                         forKey: DefaultsKey.menuBarMetricOrder)
        }
        defaults.removeObject(forKey: DefaultsKey.menuBarTemperature)
    }

    static func sanitizedMenuBarLabelStyle(_ style: String) -> String {
        allowedMenuBarLabelStyles.contains(style) ? style : "compact"
    }

    static func sanitizedMenuBarMemoryStyle(_ style: String) -> String {
        allowedMenuBarMemoryStyles.contains(style) ? style : "percent"
    }

    static func sanitizedMonitorMemoryMetric(_ metric: String) -> String {
        allowedMonitorMemoryMetrics.contains(metric) ? metric : "used"
    }

    static func sanitizedMonitorAlertCooldown(_ value: Int) -> Int {
        allowedMonitorAlertCooldowns.contains(value) ? value : 15
    }

    static func sanitizedPercent(_ value: Int, fallback: Int, range: ClosedRange<Int>) -> Int {
        range.contains(value) ? value : fallback
    }

    static func sanitizedBundleIdentifierList(_ bundleIDs: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in bundleIDs {
            // A file name may legally end in a space. Trimming one would
            // store a spelling the running program never reports, so only
            // an identifier is trimmed.
            let bundleID = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !bundleID.isEmpty, !seen.contains(bundleID) else { continue }
            seen.insert(bundleID)
            result.append(bundleID)
        }
        return result
    }

    static func sanitizedDiskExclusionList(_ list: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in list {
            let item = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = item.lowercased()
            guard !item.isEmpty, seen.insert(lower).inserted else { continue }
            result.append(item)
        }
        return result
    }

    static func sanitizedPanelItemOrder(_ raw: String, defaultOrder: [String]) -> [String] {
        let allowed = Set(defaultOrder)
        var seen = Set<String>()
        var result: [String] = []
        for id in raw.split(separator: ",").map(String.init) {
            guard allowed.contains(id), seen.insert(id).inserted else { continue }
            result.append(id)
        }
        for id in defaultOrder where seen.insert(id).inserted {
            result.append(id)
        }
        return result
    }

    static func sanitizedAppVolume(_ volume: Double) -> Double {
        guard volume.isFinite else { return 1 }
        return min(max(volume, 0), 2)
    }

    /// The volume the speakers are set to when headphones disconnect. It is a
    /// protection against a sudden blast, not a mute, so it never goes low
    /// enough to leave the sound inaudible.
    static let minimumMixerHeadphonesDisconnectVolumePercent = 10
    static let defaultMixerHeadphonesDisconnectVolumePercent = 25

    static func sanitizedMixerHeadphonesDisconnectVolumePercent(_ percent: Int) -> Int {
        min(max(percent, minimumMixerHeadphonesDisconnectVolumePercent), 100)
    }

    /// The option shipped with a stored value of 0, so ticking the box without
    /// touching the stepper silenced the speakers on the next disconnect. A
    /// value below the floor becomes the sane default.
    static func migrateSilentHeadphonesDisconnectVolume(in defaults: UserDefaults) {
        guard let stored = defaults.object(forKey: DefaultsKey.mixerHeadphonesDisconnectVolumePercent) as? Int,
              stored < minimumMixerHeadphonesDisconnectVolumePercent else { return }
        defaults.set(defaultMixerHeadphonesDisconnectVolumePercent,
                     forKey: DefaultsKey.mixerHeadphonesDisconnectVolumePercent)
    }

    static func sanitizedAppOutputDeviceUID(_ value: Any?) -> String? {
        MixerRoutingSupport.sanitizedDeviceUID(value)
    }

    static func sanitizedAppOutputDevices(_ raw: [String: Any]) -> [String: String] {
        MixerRoutingSupport.sanitizedRouteMap(raw)
    }

}
