// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Combine
import Foundation

/// The way a language agrees a noun with the number in front of it.
enum CountAgreement {
    /// One form for exactly one, another for every other count.
    case oneAndMany
    /// Russian and Ukrainian: the number's last digits decide. 21 takes the
    /// first form and 22 the middle one, while 11 through 14 fall back to the last.
    case byLastDigits
    /// Slovak: the whole number decides. Only one itself takes the first form
    /// and only two through four the middle one, so 21 and 22 read
    /// "21 súborov" and "22 súborov" the same way 25 does.
    case byWholeNumber
}

/// Languages the interface can use. The first launch defaults to the system
/// language; the onboarding and Settings let the user override it at any time.
enum AppLanguage: String, CaseIterable, Identifiable {
    case enUS = "en-US"
    case ptBR = "pt-BR"
    case tr = "tr"
    case ru = "ru"
    case es = "es"
    case sk = "sk"
    case de = "de"
    case fr = "fr"
    case it = "it"
    case ja = "ja"
    case ko = "ko"
    case uk = "uk"
    case zhHans = "zh-Hans"
    case zhTW = "zh-TW"
    case zhHK = "zh-HK"

    var id: String { rawValue }

    /// How this language agrees a counted noun with the number in front of
    /// it. Three of the fifteen put a distinct form between one and many, and
    /// they disagree on which numbers take it, so the count itself is not
    /// enough to pick a form without knowing the language's rule.
    var countAgreement: CountAgreement {
        switch self {
        case .ru, .uk: return .byLastDigits
        case .sk: return .byWholeNumber
        default: return .oneAndMany
        }
    }

    /// The language's own name, shown in its own script, the way macOS lists them.
    var displayName: String {
        switch self {
        case .enUS: return "English (US)"
        case .ptBR: return "Português (Brasil)"
        case .tr: return "Türkçe"
        case .ru: return "Русский"
        case .es: return "Español"
        case .sk: return "Slovenčina"
        case .de: return "Deutsch"
        case .fr: return "Français"
        case .it: return "Italiano"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .zhHans: return "简体中文"
        case .zhHK: return "繁體中文（香港）"
        case .zhTW: return "繁體中文（台灣）"
        case .uk: return "Українська"
        }
    }

    /// Common "Done" button title across all 15 supported languages.
    var buttonDone: String {
        switch self {
        case .enUS: return "Done"
        case .ptBR: return "Concluído"
        case .tr: return "Bitti"
        case .ru: return "Готово"
        case .es: return "Listo"
        case .sk: return "Hotovo"
        case .de: return "Fertig"
        case .fr: return "Terminé"
        case .it: return "Fine"
        case .ja: return "完了"
        case .ko: return "완료"
        case .uk: return "Готово"
        case .zhHans: return "完成"
        case .zhTW: return "完成"
        case .zhHK: return "完成"
        }
    }

    /// Common "OK" confirmation button title across all 15 supported languages.
    var buttonOK: String {
        switch self {
        case .ru, .uk: return "ОК"
        case .zhHans, .zhTW, .zhHK: return "好"
        case .ko: return "확인"
        default: return "OK"
        }
    }

    /// Dates and times in this language, arranged the way System Settings
    /// asks: region, 12- or 24-hour clock and first day of the week. A locale
    /// made from the language alone would bring that language's own clock.
    func formattingLocale(system: Locale = .autoupdatingCurrent) -> Locale {
        var components = Locale.Components(identifier: rawValue)
        components.region = system.region
        components.hourCycle = system.hourCycle
        components.firstDayOfWeek = system.firstDayOfWeek
        return Locale(components: components)
    }

    static var systemDefault: AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        let p = preferred.lowercased()

        if p.hasPrefix("zh-hk") || p.hasPrefix("zh-hant-hk") {
            return .zhHK
        }

        if p.hasPrefix("zh-tw") || p.hasPrefix("zh-hant-tw") || p.hasPrefix("zh-hant") {
            return .zhTW
        }

        let matches: [(String, AppLanguage)] = [
            ("pt", .ptBR), ("tr", .tr), ("ru", .ru), ("es", .es), ("sk", .sk), ("de", .de),
            ("fr", .fr), ("it", .it), ("ja", .ja), ("ko", .ko), ("uk", .uk), ("zh", .zhHans),
        ]
        for (prefix, language) in matches where preferred.hasPrefix(prefix) { return language }
        return .enUS
    }
}

/// Source of every user-facing string. Views observe this object so the whole
/// interface re-renders immediately when the language changes.
final class L10n: ObservableObject {
    static let shared = L10n()

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: DefaultsKey.language) }
    }

    var s: Strings { Strings.localized(language) }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: DefaultsKey.language),
           let saved = AppLanguage(rawValue: raw) {
            language = saved
        } else {
            language = .systemDefault
        }
    }
}

extension Strings {
    /// The catalog for a language other than the current one, as the
    /// feature string tables offer theirs.
    static func localized(_ language: AppLanguage) -> Strings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .tr: return .tr
        case .ru: return .ru
        case .es: return .es
        case .sk: return .sk
        case .de: return .de
        case .fr: return .fr
        case .it: return .it
        case .ja: return .ja
        case .ko: return .ko
        case .zhHans: return .zhHans
        case .zhHK: return .zhHK
        case .zhTW: return .zhTW
        case .uk: return .uk
        }
    }

    /// Common "Done" button title across all 15 supported languages.
    var buttonDone: String {
        switch panelQuit {
        case "Quit": return AppLanguage.enUS.buttonDone
        case "Sair": return AppLanguage.ptBR.buttonDone
        case "Çık": return AppLanguage.tr.buttonDone
        case "Выйти": return AppLanguage.ru.buttonDone
        case "Salir": return AppLanguage.es.buttonDone
        case "Ukončiť": return AppLanguage.sk.buttonDone
        case "Beenden": return AppLanguage.de.buttonDone
        case "Quitter": return AppLanguage.fr.buttonDone
        case "Esci": return AppLanguage.it.buttonDone
        case "終了": return AppLanguage.ja.buttonDone
        case "종료": return AppLanguage.ko.buttonDone
        case "Вийти": return AppLanguage.uk.buttonDone
        case "退出": return AppLanguage.zhHans.buttonDone
        case "結束": return AppLanguage.zhTW.buttonDone
        default: return L10n.shared.language.buttonDone
        }
    }

    /// Common "OK" confirmation button title across all 15 supported languages.
    var buttonOK: String {
        switch panelQuit {
        case "Quit": return AppLanguage.enUS.buttonOK
        case "Sair": return AppLanguage.ptBR.buttonOK
        case "Çık": return AppLanguage.tr.buttonOK
        case "Выйти": return AppLanguage.ru.buttonOK
        case "Salir": return AppLanguage.es.buttonOK
        case "Ukončiť": return AppLanguage.sk.buttonOK
        case "Beenden": return AppLanguage.de.buttonOK
        case "Quitter": return AppLanguage.fr.buttonOK
        case "Esci": return AppLanguage.it.buttonOK
        case "終了": return AppLanguage.ja.buttonOK
        case "종료": return AppLanguage.ko.buttonOK
        case "Вийти": return AppLanguage.uk.buttonOK
        case "退出": return AppLanguage.zhHans.buttonOK
        case "結束": return AppLanguage.zhTW.buttonOK
        default: return L10n.shared.language.buttonOK
        }
    }

    /// Canonical placeholder when a live telemetry reading has not arrived yet.
    var unavailablePlaceholder: String { "…" }
}

/// Flat, compiler-checked catalog of UI strings. Adding a field here forces
/// both translations to be provided.
struct Strings {
    // MARK: Menu bar & context menu
    let statusIdleTooltip: String
    let statusActiveUntil: String      // + time
    let statusActiveIndefinite: String
    let menuEnableAwake: String
    let menuDisableAwake: String
    let menuActivateFor: String
    let menuSettings: String
    let menuAbout: String
    let menuQuit: String
    // Standard application menu bar (App / Edit / Window) shown while one of the
    // app's own windows is focused. Without it, an accessory app has no main menu
    // and the standard shortcuts (Cmd+H/M/W/Q, Cmd+C/V/X/A) do nothing.
    let menuHide: String
    let menuHideOthers: String
    let menuShowAll: String
    let menuEdit: String
    let menuUndo: String
    let menuRedo: String
    /// Named actions an icon-only control borrows so it can say what it
    /// does. No feature owns these, because half a dozen already share them.
    let actionClear: String
    let actionRemove: String
    let actionBack: String
    let actionSearch: String
    let actionMute: String
    let actionUnmute: String
    let actionPlay: String
    let actionPause: String
    let menuCut: String
    let menuCopy: String
    let menuPaste: String
    let menuSelectAll: String
    let menuWindow: String
    let menuMinimize: String
    let menuZoom: String
    let menuClose: String

    // MARK: Durations
    let minutes15: String
    let minutes30: String
    let hour1: String
    let hours2: String
    let hours4: String
    let hours8: String
    let indefinitely: String
    let indefinite: String

    // MARK: Panel — header & footer
    let panelSettings: String
    let panelQuit: String
    let panelHotkeyHint: String

    // MARK: Panel — keep awake card
    let keepAwakeTitle: String
    let keepAwakeEndsIn: String        // + remaining
    let keepAwakeUntilDisabled: String
    let keepAwakeNormalRules: String
    let keepAwakeUntilLabel: String
    let keepAwakeUntilStart: String
    let keepAwakeOptions: String
    let notchMixerOptions: String
    let ocrTextRecognitionSection: String
    let mediaOutputParamsSection: String
    let cleanerAutomationSection: String
    let cleanerAutoOrganizeSection: String
    let keepAwakeMouseJiggle: String
    let keepAwakeMouseJiggleCaption: String
    let keepAwakeMouseJiggleInterval: String
    let keepAwakeBatteryLimit: String
    let keepAwakeBatteryLimitNever: String
    let keepAwakeBatteryLimitCaption: String
    let durationLabel: String
    let clamshellTitle: String
    let clamshellOnCaption: String
    let clamshellNeedsSession: String
    let clamshellReady: String
    let clamshellNeedsPassword: String

    // MARK: Panel — system monitor
    let systemSection: String
    let temperatures: String
    let cpuLabel: String
    let gpuLabel: String
    let batteryLabel: String
    let usageSection: String
    let memorySection: String
    let memoryPressure: String
    let memorySwapUsed: String
    let memoryCompressed: String
    let memoryCachedFiles: String
    let pressureNormal: String
    let pressureWarning: String
    let pressureCritical: String
    let monitorUnavailable: String
    let energyAppsTitle: String
    let energyAppsIdle: String

    // MARK: Notifications
    let notifySessionEndedTitle: String
    let notifySessionEndedBody: String
    let notifyBatteryTitle: String
    let notifyBatteryBody: String

    // MARK: Administrator prompts (shown by macOS password dialogs)
    let adminPromptClamshellOn: String
    let adminPromptClamshellOff: String
    let adminPromptRecover: String
    let sleepRestorePending: String
    let sleepRestoreAction: String
    let adminPromptSudoersInstall: String
    let adminPromptSudoersRemove: String

    // MARK: Settings — window & tabs
    let settingsTitle: String
    let tabGeneral: String
    let tabEnergy: String
    let tabMouse: String
    let tabSwitcher: String
    let tabAdvanced: String
    let tabAbout: String
    let tabReleaseNotes: String
    let releaseNotesOnUpdateToggle: String
    let minimalWindowPreviews: String
    let minimalWindowPreviewsCaption: String
    let settingsGroupFeatures: String

    // MARK: Settings — advanced
    let advancedResetSection: String
    let advancedResetDescription: String
    let advancedClearButton: String
    let advancedCleared: String
    let advancedClearFailed: String
    let advancedClearConfirmTitle: String
    let advancedClearConfirmBody: String
    let advancedUninstallSection: String
    let advancedUninstallDescription: String
    let advancedUninstallRecommended: String
    let advancedUninstallButton: String
    let advancedUninstallConfirmTitle: String
    let advancedUninstallConfirmBody: String
    let advancedUninstallFailedTitle: String
    let advancedUninstallFailedBody: String
    let advancedUninstallTrashFailedBody: String

    // MARK: Settings — general
    let launchAtLogin: String
    let languageLabel: String
    let menuBarSection: String
    let showCountdown: String
    let globalHotkeySection: String
    let hotkeyToggle: String
    let hotkeyCaption: String

    // MARK: Settings — energy
    let sessionSection: String
    let defaultDurationLabel: String
    let keepAwakeAutoStart: String
    let keepAwakeAutoStartCaption: String
    let clamshellSection: String
    let configuring: String
    let sudoersFailed: String
    let clamshellExplanation: String

    // MARK: Settings — mouse
    let scrollSection: String
    let invertMouseScroll: String
    let invertMouseScrollCaption: String
    let scrollTrackpadNote: String
    let scrollActiveNow: String
    let mouseNavigationActiveNow: String
    let smoothScrollName: String
    let smoothScrollCaption: String
    let smoothScrollStepLabel: String
    let mouseNavigationSection: String
    let mouseNavigationEnable: String
    let mouseNavigationCaption: String
    let middleClickSection: String
    let middleClickEnable: String
    let middleClickEnableCaption: String
    let middleClickDragConflict: String
    let middleClickNoTrackpad: String
    let middleClickTapPicker: String
    let middleClickTapOff: String
    let middleClickTapThreeFingers: String
    let middleClickTapFourFingers: String
    let middleClickTapCaption: String
    let quickToolsTab: String
    let quickToolShortcutToggle: String
    let ocrName: String
    let ocrCaption: String
    let ocrCopied: String
    let ocrNoText: String
    let ocrClipboardChanged: String
    let colorPickerName: String
    let colorPickerCaption: String
    let colorPickerFormatLabel: String
    let colorPickerBareHexToggle: String
    let colorPickerPickNow: String
    let micMuteName: String
    let micUnmuteName: String
    let micMuteCaption: String
    let micMutedHUD: String
    let micUnmutedHUD: String
    let micMutePartialHUD: String
    let micUnmutePartialHUD: String
    let micMuteMenuBarToggle: String
    let micMuteMenuBarCaption: String
    let launcherName: String
    let launcherCaption: String
    let launcherOpenNow: String
    let launcherEditHint: String
    let launcherEmptyState: String
    let launcherAddSection: String
    let launcherKeysHint: String

    // MARK: Settings — switcher
    let switcherSection: String
    let switcherEnable: String
    let switcherEnableCaption: String
    let switcherUsageHint: String
    let switcherNoWindows: String
    let switcherIconRowMode: String
    let switcherIconRowModeCaption: String
    let switcherSimpleModeCaption: String
    let switcherShortcutHintApps: String
    let switcherShortcutHintWindows: String
    let switcherWindowShortcutCaption: String
    let switcherTakeOverSystemShortcuts: String
    let switcherTakeOverSystemShortcutsCaption: String
    let switcherAppearanceDelay: String
    let switcherAppearanceDelayCaption: String
    let switcherInstantSelection: String
    let switcherInstantSelectionCaption: String
    let switcherMergeTabs: String
    let switcherMergeTabsCaption: String
    let switcherWindowlessApps: String
    let switcherWindowlessAppsCaption: String
    let switcherWindowlessAppsOff: String
    let switcherWindowlessAppsFinder: String
    let switcherWindowlessAppsAll: String
    let switcherNoOpenWindow: String
    let switcherOtherDesktop: String
    let dockPreviewName: String
    let dockPreviewEnable: String
    let dockPreviewEnableCaption: String
    let dockPreviewCurrentSpaceOnlyCaption: String
    let dockPreviewBackgroundOpacity: String
    let dockPreviewBackgroundOpacityCaption: String
    let dockPreviewOpenDelay: String
    let dockPreviewOpenDelayCaption: String
    let dockPreviewQuitAppOnClose: String
    let dockPreviewQuitAppOnCloseCaption: String
    let dockPreviewKeepDockVisible: String
    let dockPreviewKeepDockVisibleCaption: String
    let dockPreviewOrderByCreation: String
    let dockPreviewOrderByCreationCaption: String
    let dockClickMinimize: String
    let dockClickMinimizeCaption: String
    let dockClickCycleWindows: String
    let dockClickCycleWindowsCaption: String
    let dockPreviewActiveNow: String
    let dockPreviewDockUnavailable: String
    let dockPreviewAutohideBeta: String
    let dockPreviewOpenWindow: String
    let dockPreviewCloseWindow: String
    let dockPreviewMinimizeWindow: String
    let dockPreviewRestoreWindow: String
    let dockPreviewPinPanel: String
    let dockPreviewUnpinPanel: String
    let dockPreviewPinned: String
    let dockPreviewClosePanel: String
    let dockPreviewPreviousWindow: String
    let dockPreviewNextWindow: String

    // MARK: Feature — cut & paste in Finder
    let cutPasteName: String
    let cutPasteEnable: String
    let cutPasteEnableCaption: String
    let cutPasteShowHUD: String
    let cutPasteShowHUDCaption: String
    let cutPasteHowTitle: String
    let cutPasteStep1: String
    let cutPasteStep2: String
    let cutPasteTextNote: String
    let cutPasteActiveNow: String
    let cutPasteAutomationNote: String
    let cutReadyTitle: String
    let cutReadyHint: String
    let cutCancel: String
    let cutDoneTitle: String
    let cutMovedSingular: String
    let cutMovedPluralFormat: String      // + count
    let cutSomeFailed: String
    let cutMovingTitle: String
    let cutMovingCountFormat: String      // + position, total

    // MARK: Feature — quit on last window close
    let autoQuitName: String
    let autoQuitEnable: String
    let autoQuitEnableCaption: String
    let autoQuitActiveNow: String
    let autoQuitHowTitle: String
    let autoQuitStep1: String
    let autoQuitStep2: String
    let autoQuitPredictableNote: String
    let autoQuitOngoingWorkNote: String
    let autoQuitExceptionsTitle: String
    let autoQuitExceptionsCaption: String
    let autoQuitExceptionsEmpty: String
    let autoQuitAddApp: String

    // MARK: Feature — complete app uninstaller
    let uninstallerName: String
    let uninstallerEnableCaption: String
    let uninstallerStep1: String
    let uninstallerStep2: String
    let uninstallerStep3: String
    let uninstallerMenuItem: String
    let uninstallerDropTitle: String
    let uninstallerDropSubtitle: String
    let uninstallerChoose: String
    let uninstallerPickerTitle: String
    let uninstallerPickerSearch: String
    let uninstallerPickerEmpty: String
    let uninstallerEmptyNote: String
    let uninstallerFDANote: String
    let uninstallerFDAGrant: String
    let uninstallerFDAHint: String
    let uninstallerFDARelaunch: String
    let uninstallerScanning: String
    let loadingMessage: String
    let uninstallerRemoving: String
    let uninstallerFoundTitle: String
    let uninstallerSelectedFormat: String   // + selected, total
    let uninstallerRemove: String
    let uninstallerCancel: String
    let uninstallerConfirmationExpired: String
    let uninstallerQuitTitle: String
    let uninstallerQuitBodyFormat: String
    let uninstallerQuitAndRemove: String
    let uninstallerForceQuitTitle: String
    let uninstallerForceQuitBodyFormat: String
    let uninstallerForceQuitAndRemove: String
    let uninstallerTerminalContinue: String
    let uninstallerTerminalStillInstalled: String
    let uninstallerDoneTitle: String
    let movedToTrashFormat: String          // + size string
    let freedPermanentlyFormat: String      // + size string
    let uninstallerSomeFailed: String
    let uninstallerFailedNeedsFDA: String
    let uninstallerFailedMoreFormat: String
    let uninstallerAnother: String
    let uninstallerCatApp: String
    let uninstallerCatSupport: String
    let uninstallerCatCaches: String
    let uninstallerCatPreferences: String
    let uninstallerCatContainers: String
    let uninstallerCatLogs: String
    let uninstallerCatState: String
    let uninstallerCatOther: String
    let uninstallerHiddenHomeLegend: String
    let uninstallerSystemExtensionNote: String
    let uninstallerLoginItemNote: String
    let uninstallerAdminUnloadPrompt: String
    let spaceInventoryTitle: String
    let spaceInventoryLegend: String
    let spaceInventoryModelsCaption: String
    let spaceInventoryToolsCaption: String
    let spaceInventoryVMsCaption: String
    let spaceInventorySimulatorsTitle: String
    let spaceInventorySimulatorsScope: String
    let spaceInventorySimulatorNote: String
    let spaceInventorySimulatorWarning: String
    let spaceInventoryMeasure: String
    let uninstallerSelectionUnavailable: String
    let uninstallerRefusedSystemApp: String
    let uninstallerRefusedNestedApp: String
    let uninstallerRefusedSelfApp: String
    let uninstallerClearSelection: String

    // MARK: Feature — URL cleaner
    let urlCleanerName: String
    let urlCleanerEnable: String
    let urlCleanerEnableCaption: String
    let urlCleanerActiveNow: String
    let urlCleanerManualTitle: String
    let urlCleanerInputPlaceholder: String
    let urlCleanerOutputPlaceholder: String
    let urlCleanerCleanButton: String
    let urlCleanerPasteButton: String
    let urlCleanerCopyButton: String
    let urlCleanerClearButton: String
    let urlCleanerNoURL: String
    let urlCleanerNoChange: String
    let urlCleanerCleaned: String
    let urlCleanerCopied: String
    let urlCleanerLocalNote: String

    // MARK: Feature — Homebrew manager
    let homebrewTrustTitle: String
    let homebrewTrustCaption: String
    let homebrewTrustButton: String
    let homebrewGroupDependencies: String
    let homebrewUninstall: String
    let homebrewAllPackages: String
    let homebrewOpenTerminal: String
    let homebrewCancelOperation: String
    let homebrewClearLog: String
    let homebrewConfirmUninstallTitle: String
    let homebrewConfirmUninstallBodyFormat: String
    let homebrewTerminalFallback: String
    let homebrewOperationUninstallFormat: String
    let homebrewOperationUpgradeAll: String
    let homebrewOperationUninstalledFormat: String
    let homebrewOperationUpgradedAll: String
    let homebrewOperationFailedFormat: String
    let homebrewOperationCancelled: String
    let homebrewOperationPreparing: String
    let homebrewOperationDownloading: String
    let homebrewOperationUninstalling: String
    let homebrewOperationUpgrading: String
    let homebrewOperationFinalizing: String
    let homebrewOperationRefreshing: String
    let homebrewOperationTerminal: String
    let homebrewOperationElapsedFormat: String
    let homebrewOperationShowDetails: String
    let homebrewOperationHideDetails: String
    let homebrewOperationTechnicalLog: String
    let homebrewOperationProgressUnknown: String

    // MARK: Feature — local media tools
    let mediaName: String
    let mediaEnableCaption: String
    let mediaLocalNote: String
    let mediaToolVideo: String
    let mediaToolGIF: String
    let mediaToolImage: String
    let mediaToolText: String
    let mediaSelectFile: String
    let mediaDropHint: String
    let mediaOutput: String
    let mediaOutputAutomatic: String
    let mediaChooseOutput: String
    let mediaStartVideo: String
    let mediaStartGIF: String
    let mediaStartImage: String
    let mediaStartConvertPDF: String
    let mediaStartText: String
    let mediaCancel: String
    let mediaStartTime: String
    let mediaEndTime: String
    let mediaQuality: String
    let mediaCompressionLow: String
    let mediaCompressionMedium: String
    let mediaCompressionHigh: String
    let mediaCompressionLowDescription: String
    let mediaCompressionMediumDescription: String
    let mediaCompressionHighDescription: String
    let mediaMaxSize: String
    let mediaSizingResolution: String
    let mediaSizingFileSize: String
    let mediaTargetSize: String
    let mediaTargetSizeHint: String
    let mediaErrorTargetTooSmall: String
    let mediaErrorGIFTooLongFormat: String
    let mediaMegabytesSuffix: String
    let mediaWidth: String
    let mediaFPS: String
    let mediaKeepAudio: String
    let mediaCodec: String
    let mediaFormat: String
    let mediaStripMetadata: String
    let mediaLoopGIF: String
    let mediaOCRMode: String
    let mediaOCRAccurate: String
    let mediaOCRFast: String
    let mediaLanguageCorrection: String
    let mediaTextOutputNote: String
    let mediaRunning: String
    let mediaCompleted: String
    let mediaCancelled: String
    let mediaStatusNotice: String
    let mediaOpenInFinder: String
    let mediaCopyText: String
    let mediaRunAgain: String
    let mediaEmptyText: String
    let mediaResultSavedFormat: String
    let mediaResultSizeFormat: String
    let mediaResultGrewCaption: String
    let mediaErrorNoFile: String
    let mediaErrorNoVideo: String
    let mediaErrorSameOutput: String
    let mediaErrorUnsupported: String

    // MARK: Feature — temporary shelf
    let extraBrightnessName: String
    let extraBrightnessCaption: String
    let extraBrightnessUnsupported: String
    let shelfHotkeyLabel: String

    // MARK: Panel — per-app breakdown
    let breakdownMeasuring: String

    // MARK: Panel — volume mixer
    let mixerSection: String
    let mixerEmpty: String
    let mixerUnavailable: String
    let mixerPermissionBody: String
    let mixerResetTooltip: String
    let mixerOutputDefault: String
    let mixerOutputCurrent: String
    let mixerOutputUnavailable: String
    let mixerOutputFallback: String
    let mixerBypassedCaption: String
    let mixerOutputTooltip: String
    let mixerAirPlayChooseSpeaker: String
    let mixerSystemOutputTitle: String
    let mixerSystemOutputNoDevices: String
    let mixerSystemOutputTooltip: String
    let mixerSystemOutputErrorFormat: String
    let mixerLowerOnHeadphonesDisconnect: String
    let mixerLowerOnHeadphonesDisconnectCaption: String
    let mixerHeadphonesDisconnectVolume: String
    let preciseVolumeRollerEnable: String
    let preciseVolumeRollerCaption: String
    let preciseVolumeRollerTapFailed: String
    let mixerInputTitle: String
    let mixerInputNoDevices: String
    let mixerInputUnavailable: String
    let mixerInputFallback: String
    let mixerInputTooltip: String
    let mixerInputErrorFormat: String
    let mixerVisibleApps: String
    let mixerAllShown: String
    let mixerHiddenCountLabel: String
    let mixerHideFromList: String

    // MARK: Panel — audio device priority
    let audioPrioritySection: String
    let audioPriorityOutputEnable: String
    let audioPriorityInputEnable: String
    let audioPriorityOutputList: String
    let audioPriorityInputList: String
    let audioPriorityMoveUp: String
    let audioPriorityMoveDown: String
    let audioPriorityUnavailable: String
    let audioPriorityCurrent: String
    let audioPriorityCaption: String

    // MARK: Settings — updates
    let updatesSection: String
    let autoCheckToggle: String
    let betaBadgeLabel: String
    let checkNowButton: String
    let updateChecking: String
    let updateUpToDate: String
    let updateInstallButton: String
    let updateFailedPrefix: String
    let updateLastChecked: String
    let menuCheckUpdates: String

    // MARK: Permissions (shared by Settings & onboarding)
    let permissionRequired: String
    let permissionAccessibility: String
    let permissionScreenRecording: String
    let permissionGranted: String
    let permissionMissing: String
    let permissionOpenSettings: String
    let permissionRequest: String
    let permissionRestartNote: String

    // MARK: Secure input
    let secureInputTitle: String
    let secureInputHeldFormat: String
    let secureInputUnattributed: String
    let secureInputUnidentified: String
    let secureInputRevealFormat: String

    // MARK: About
    let aboutDescription: String
    let versionPrefix: String
    let reviewIntro: String
    let reviewHighlights: String
    let viewOnGitHub: String
    let downloadLatestRelease: String

    // MARK: Onboarding
    let obContinue: String
    let obBack: String
    let obStepWelcomeTitle: String
    let obStepWelcomeBody: String
    let obWelcomeBullet1Title: String
    let obWelcomeBullet1Body: String
    let obWelcomeBullet2Title: String
    let obWelcomeBullet2Body: String
    let obWelcomeBullet3Title: String
    let obWelcomeBullet3Body: String
    let obStepModulesTitle: String
    let obStepModulesBody: String
    let obStepPermissionsTitle: String
    let obStepPermissionsBody: String
    let obStepDoneTitle: String
    let obStepDoneBody: String
    let obDoneHint: String
    let obFinish: String
    let obPermissionPendingNote: String
    let obRedoOnboarding: String
    // About screen: release notes, outside the first-run set
    let obWhatsNewTitle: String
    let releaseNotesUnavailable: String
    let obWhatsNewFallback: String

    // MARK: Settings — monitor / menu bar metrics
    let tabMonitor: String
    let monitorMenuBarSection: String
    let monitorMenuBarCaption: String
    let monitorCombineTemperatures: String
    let monitorCombineTemperaturesCaption: String
    let monitorSeparateMenuBarMetrics: String
    let monitorSeparateMenuBarMetricsCaption: String
    let monitorNetworkUploadFirst: String
    let monitorShowCPU: String
    let monitorShowMemory: String
    let monitorShowNetwork: String
    let monitorShowPowerLabel: String
    let monitorIntervalLabel: String
    let monitorInterval1: String
    let monitorInterval2: String
    let monitorInterval5: String
    let monitorPanelSection: String
    let panelNavigationMode: String
    let panelNavigationCaption: String
    let panelFooterSections: String
    let panelFooterList: String
    let betaBadge: String
    let betaFeatureWarning: String

    // MARK: Panel — network
    let networkSection: String
    let networkIPAddresses: String
    let networkLocalIP: String
    let networkDownload: String
    let networkUpload: String
    let networkThisSession: String
    let networkMeasuring: String
    let networkApps: String
    let networkAppsIdle: String

    // MARK: Panel — disk
    let diskSection: String
    let diskUsed: String
    let diskFree: String
    let diskMenuBarStyleLabel: String
    let diskMenuBarUsedPercentage: String
    let diskMenuBarAvailableSpace: String
    let diskMenuBarUsedSpace: String
    let diskAvailable: String
    let diskPurgeable: String
    let diskInternal: String
    let diskExternal: String
    let diskSelect: String
    let diskRead: String
    let diskWrite: String
    let diskSMARTStatus: String
    let diskSMARTUnavailable: String
    let diskTotalRead: String
    let diskTotalWritten: String
    let diskTemperature: String
    let diskHealth: String
    let diskPowerCycles: String
    let diskPowerOnHours: String
    let diskUnsafeShutdowns: String
    let diskMediaErrors: String
    let diskEject: String
    let diskEjectAll: String
    let diskEjecting: String
    let diskReadyToRemove: String
    let diskEjectFailed: String
    let diskEjectSiblingsTitleFormat: String
    let diskEjectSiblingsMessageFormat: String
    let diskProtectionCaption: String
    let diskNoExternal: String
    let diskOpenInFinder: String
    let diskStorageSettings: String
    let diskNoDisks: String

    // MARK: Panel — power
    let powerSection: String
    let powerSystem: String
    let powerAdapter: String
    let powerBattery: String
    let powerCharging: String
    let powerOnBattery: String
    let powerPluggedIn: String
    let powerUnavailable: String
    let powerAdapterMaxFormat: String   // + rated watts, e.g. "30 W max"
    let monitorShowGPU: String
    let monitorShowCPUTemperature: String
    let monitorShowGPUTemperature: String
    let monitorShowBatteryTemperature: String
    let monitorShowPeripheralBattery: String
    let peripheralBatteryNoDevices: String

    // MARK: Update notification + onboarding menu bar setup
    let obStepMenuBarTitle: String
    let obStepMenuBarBody: String
    let obStepMenuBarNote: String
    let monitorMenuBarPresetLabel: String
    let menuBarPresetReadable: String
    let menuBarPresetDense: String
    let menuBarSpacingLabel: String
    let menuBarSpacingStandard: String
    let menuBarSpacingCompact: String
    let menuBarHideIconToggle: String
    let menuBarHideIconCaption: String
    let monitorLabelStyleLabel: String
    let menuBarLabelStyleCompact: String
    let menuBarLabelStyleClassic: String
    let monitorMemoryStyleLabel: String
    let monitorMemoryPressureDot: String
    let memoryStyleDot: String
    let memoryStylePercent: String
    let memoryStyleBoth: String
    // MARK: System uptime, battery health, speed test
    let systemUptime: String
    let batteryCharge: String
    let powerHealth: String
    let powerCycles: String
    let speedTestRun: String
    let speedTestAgain: String
    let speedTestLatency: String
    let speedTestTesting: String
    let speedTestFailed: String

    // MARK: Per-item panel config (Settings + onboarding)
    let disclosureExpanded: String
    let disclosureCollapsed: String
    let panelHideItem: String
    let panelShowItem: String
    let panelHiddenItem: String
    let monitorItemUptime: String
    let monitorItemNetSpeed: String
    let monitorItemNetTotals: String
    let monitorItemNetTest: String
    let monitorItemDiskUsage: String
    let monitorItemDiskActivity: String
    let monitorItemDiskSMART: String
    let monitorItemDiskProtection: String
    let monitorItemDiskTools: String
    let monitorPanelConfigHint: String
    let monitorOrderHint: String
    let obStepPanelTitle: String
    let obStepPanelBody: String
    let obStepPanelNavigationTitle: String
    let obStepPanelNavigationBody: String

    // MARK: Cleaning mode
    let cleaningMenuItem: String
    let utilitiesSection: String
    let quickControlsSection: String
    let panelCategoryWindows: String
    let panelCategoryInput: String
    let panelCategoryFiles: String
    let windowMaximizeName: String
    let windowMaximizeCaption: String
    let windowMaximizeActiveNow: String
    let windowMaximizeNeedsAccessibility: String
    let keyDebounceName: String
    let keyDebounceEnable: String
    let keyDebounceCaption: String
    let keyDebounceActiveNow: String
    let keyDebounceGlobalWindow: String
    let keyDebouncePerKeySection: String
    let keyDebouncePerKeyCaption: String
    let keyDebounceKeyLabel: String
    let keyDebounceWindowLabel: String
    let keyDebounceAddKey: String
    let keyDebounceNoOverrides: String
    let keyDebounceRemoveKey: String
    let cleaningPanelCaption: String
    let cleaningOverlayTitle: String
    let cleaningOverlaySubtitle: String
    let cleaningOverlayUnlock: String
    let cleaningOverlayMouseHint: String
    let cleaningKeepScreenVisibleToggle: String
    let cleaningKeepScreenVisibleCaption: String
    let cleaningStartNow: String
    let cleaningNeedsAxTitle: String
    let cleaningNeedsAxBody: String

    // MARK: Support / donate
    let tabSupport: String
    let shortcutsPageCaption: String
    let shortcutsPageTitle: String
    let settingsSearchPlaceholder: String
    let donateHeading: String
    let donateMessage: String
    let donateButton: String
    let donateThanks: String
    let supportIntroTitle: String
    let supportIntroMessage: String
    let supportIntroStarButton: String
    let supportIntroStarMessage: String
    let supportIntroCoffeeButton: String
    let supportIntroLaterButton: String
    let supportIntroDoneButton: String
    let discordIntroTitle: String
    let discordIntroMessage: String
    let discordIntroJoinButton: String
    let communityIntroTitle: String
    let communityIntroMessage: String
    let communityIntroFollowButton: String
    let showMenuBarIcon: String
    let menuBarIconStillHiddenTitle: String
    let menuBarIconStillHiddenBody: String
    let menuBarIconManagerHintFormat: String  // + manager name (twice)
    let menuBarIconDisallowedBody: String

    // MARK: Configurable shortcuts
    let shortcutRecording: String
    let shortcutReset: String
    let shortcutNone: String
    let shortcutClear: String
    let shortcutInvalid: String
    let shortcutPressKeys: String
    let shortcutEscapeHint: String
    let shortcutDeleteHint: String
    let shortcutNotCaptured: String
    let shortcutConflictFormat: String
    let shortcutTakeOverOffer: String
    let shortcutTakeOverAction: String
    let shortcutTakeOverCaption: String
    let shortcutTakeOverDismiss: String
    let shortcutUnavailable: String
    let switcherUsageHintFormat: String

    // MARK: Media keys
    let musicBlockSection: String
    let musicBlockTitle: String
    let musicBlockCaption: String
    let musicBlockUnavailable: String
    let musicBlockReplacementLabel: String
    let musicBlockReplacementNone: String
    let musicBlockReplacementBlocked: String
    let musicBlockChooseApp: String
    let musicBlockPlayReplacement: String

    // MARK: Cleaner
    let cleanerName: String
    let cleanerIntroTitle: String
    let cleanerIntroCaption: String
    let cleanerScan: String
    let cleanerScanning: String
    let cleanerCleaning: String
    let cleanerCatLeftovers: String
    let cleanerCatLoginItems: String
    let cleanerCatCaches: String
    let cleanerCatLogs: String
    let cleanerCatDeveloper: String
    let cleanerCatTrash: String
    let cleanerLeftoversNote: String
    let cleanerLoginItemsNote: String
    let cleanerTrashNote: String
    let cleanerTrashConfirmTitle: String
    let cleanerTrashConfirmMessage: String
    let cleanerTrashConfirmButton: String
    let cleanerCatDeviceBackups: String
    let cleanerDeviceBackupsCaption: String
    let cleanerCatPackageCaches: String
    let cleanerPackageCachesCaption: String
    let cleanerCatCodingConversations: String
    let cleanerCodingConversationsCaptionFormat: String  // + age in days
    let cleanerCodingConversationAgeLabel: String
    let cleanerCodingConversationsRisk: String
    let cleanerCatScreenshots: String
    let cleanerScreenshotsCaptionFormat: String
    let cleanerScreenshotsSettingCaption: String
    let cleanerScreenshotsAfterFormat: String
    let cleanerNothingFound: String
    let cleanerClean: String
    let cleanerDoneNote: String
    let cleanerAgain: String
    let cleanerRevealInFinder: String
    let cleanerPanelCaption: String
    let cleanerSafeSection: String
    let cleanerOptionalSection: String
    let cleanerCatOtherCaches: String
    let cleanerCachesCaption: String
    let cleanerLogsCaption: String
    let cleanerDeveloperCaption: String
    let cleanerLoginItemsCaption: String
    let cleanerLeftoversCaption: String
    let cleanerOtherCachesCaption: String
    let cleanerCatBrowserCaches: String
    let cleanerBrowserCachesCaption: String
    let cleanerCatBrowserSiteData: String
    let cleanerBrowserSiteDataCaption: String
    let cleanerBrowserAccessPendingReason: String
    let cleanerSkippedBrowsersFormat: String
    let cleanerNotificationSkippedBrowsersFormat: String
    let cleanerCleanSizeFormat: String      // + size string
    let cleanerScheduleTitle: String
    let cleanerScheduleOff: String
    let cleanerScheduleDaily: String
    let cleanerScheduleWeekly: String
    let cleanerScheduleCaption: String
    let cleanerScheduleLastFormat: String   // + size string
    let cleanerAutoNotificationFormat: String  // + size string
    let cleanerScheduleNextFormat: String   // + relative date and time
    let cleanerScheduleRanFormat: String    // + relative date and time
    let cleanerSchedulePostponed: String
    let cleanerScheduleNotifyToggle: String
    let cleanerAbortAll: String
    let cleanerAutoRunning: String
    let cleanerAutoInterrupted: String
    let cleanerNotifDenied: String
    let cleanerNotifOpenSettings: String
    let launchAtLoginNeedsApplications: String
    let launchAtLoginNeedsApproval: String
    let ocrRemoveLineBreaksToggle: String
    let ocrRemoveLineBreaksCaption: String
    let ocrQRToggle: String
    let ocrQRCaption: String
    let ocrQRCopied: String
    let ocrShowMenuOnShortcut: String
    let qrResultTitle: String
    let qrResultCopy: String
    let qrResultOpen: String
    let highlightsTitle: String
    let highlightsTitleClipboardRedesign: String
    let highlightsTitleWindowLayout: String
    let highlightsTitleQuitProtection: String
    let highlightsTitleRecorderBlur: String
    let highlightsCaptionDockPreview: String
    let highlightsCaptionScreenshot: String
    let highlightsCaptionSnippetLibrary: String
    let highlightsCaptionCapturePalette: String
    let highlightsCaptionClipboardRedesign: String
    let highlightsCaptionWindowLayout: String
    let highlightsCaptionQuitProtection: String
    let highlightsCaptionRecorderBlur: String
    let highlightsConfigure: String
    let highlightsTry: String
    let highlightsSeeAll: String
    let switcherCurrentSpaceOnly: String
    let switcherCurrentSpaceOnlyCaption: String
    let mixerSoundEffectsOutputTitle: String
    let mixerSoundEffectsOutputTooltip: String
    let monitorOpenActivityMonitor: String
    let dockClickHide: String
    let dockClickHideCaption: String
    let monitorMemoryMetricLabel: String
    let memoryMetricUsed: String
    let memoryMetricApp: String
    let keepAwakeRightClickToggle: String
    let keepAwakeRightClickToggleCaption: String
    let urlCleanerRulesTitle: String
    let urlCleanerRulesCaption: String
    let urlCleanerRulesCoverageCaption: String
    let urlCleanerRulesAllSites: String
    let urlCleanerRulesCountSingular: String
    let urlCleanerRulesCountPluralFormat: String   // + count
    let urlCleanerRulesAddSite: String
    let urlCleanerRulesParameterPlaceholder: String
    let urlCleanerRulesMatchCaption: String
    let urlCleanerRulesAddButton: String
    let urlCleanerRulesRemoveButton: String
    let urlCleanerRulesRemoveSiteButton: String
    let urlCleanerRemovedFormat: String            // + comma separated names
    let switcherSearchPin: String
    let switcherSearchPinCaption: String
    let invertVerticalScroll: String
    let invertHorizontalScroll: String
    let scrollHorizontalName: String
    let scrollHorizontalModifierLabel: String
    let scrollHorizontalCommandKey: String
    let scrollHorizontalCaption: String
    let switcherShowShortcutHints: String
    let switcherShowShortcutHintsCaption: String
    let uninstallerHomebrewPackageFormat: String
    let focusFollowsMouseName: String
    let focusFollowsMouseCaption: String
    let focusFollowsMouseDelay: String
    let focusFollowsMouseRaise: String
    let focusFollowsMouseWaitForStop: String
    let switcherMinimizedPlacementLabel: String
    let switcherTreatHiddenAppsLikeMinimized: String
    let switcherMinimizedPlacementNormal: String
    let switcherMinimizedPlacementEnd: String
    let switcherMinimizedPlacementHidden: String
    let switcherShowFullscreenWindows: String
    let switcherScreenPlacementLabel: String
    let switcherScreenPlacementPointer: String
    let switcherScreenPlacementMenuBar: String
    let switcherScreenPlacementActiveWindow: String
    let switcherScreenPlacementCaption: String
    let switcherCurrentDisplayOnly: String
    let switcherCurrentDisplayOnlyCaption: String
    let smoothScrollResponseLabel: String
    let smoothScrollCoastLabel: String
    let mouseAccelerationName: String
    let mouseAccelerationCaption: String
    let linearScrollName: String
    let linearScrollCaption: String
    let linearScrollLinesLabel: String
    let spacesOrderName: String
    let spacesOrderCaption: String

    // MARK: Space map
    let spaceInventoryVolumeTotal: String
    let spaceInventoryVolumeFree: String
    let spaceInventoryVolumeUsed: String
    let spaceInventoryVolumeUnavailable: String
    let spaceInventoryLowSpace: String
    let spaceInventoryRankingTitle: String
    let spaceInventorySummaryTitle: String
    let spaceInventorySummaryPartial: String
    let spaceInventoryDeniedFormat: String           // + path, + reason
    let spaceInventoryDeniedAccess: String
    let spaceInventoryDeniedUnavailable: String
    let spaceInventoryPartialMark: String
    let spaceInventoryEmpty: String
    let spaceInventoryCancelled: String

    // MARK: Large and old files
    let largeFilesTitle: String
    let largeFilesOpen: String
    let largeFilesCaption: String
    let largeFilesAgeLabel: String
    let largeFilesSizeLabel: String
    let largeFilesSettingsCaption: String
    let largeFilesBackToResults: String
    let largeFilesBackToStart: String
    let largeFilesThresholdsFormat: String      // + days, + size string
    let largeFilesSearch: String
    let largeFilesSearching: String
    let largeFilesEmpty: String
    let largeFilesResultTitle: String
    let largeFilesGroupFormat: String           // + count, + size string
    let largeFilesCancelled: String
    let largeFilesQuickLook: String
    let largeFilesReportTitle: String
    let largeFilesReportSummaryFormat: String   // + moved, + not moved
    let largeFilesMovedFormat: String           // + file name
    let largeFilesRefusedFormat: String         // + file name
    let largeFilesFailedFormat: String          // + file name
    let largeFilesRemove: String
    let largeFilesConfirmTitle: String
    let largeFilesConfirmMessageFormat: String  // + count, + size string
    let largeFilesSelectedFormat: String        // + marked, + total, + size string
    let spaceInventoryMeasuredTotal: String
}

// MARK: - Português (Brasil)

extension Strings {
    static let ptBR = Strings(
        statusIdleTooltip: "Hexa: suspensão normal",
        statusActiveUntil: "Hexa: ativo até",
        statusActiveIndefinite: "Hexa: ativo indefinidamente",
        menuEnableAwake: "Ativar manter acordado",
        menuDisableAwake: "Desativar manter acordado",
        menuActivateFor: "Ativar por…",
        menuSettings: "Ajustes…",
        menuAbout: "Sobre o Hexa",
        menuQuit: "Sair do Hexa",
        menuHide: "Ocultar o Hexa",
        menuHideOthers: "Ocultar Outros",
        menuShowAll: "Mostrar Tudo",
        menuEdit: "Editar",
        menuUndo: "Desfazer",
        menuRedo: "Refazer",
        actionClear: "Limpar",
        actionRemove: "Remover",
        actionBack: "Voltar",
        actionSearch: "Buscar",
        actionMute: "Silenciar",
        actionUnmute: "Reativar som",
        actionPlay: "Reproduzir",
        actionPause: "Pausar",
        menuCut: "Recortar",
        menuCopy: "Copiar",
        menuPaste: "Colar",
        menuSelectAll: "Selecionar Tudo",
        menuWindow: "Janela",
        menuMinimize: "Minimizar",
        menuZoom: "Zoom",
        menuClose: "Fechar",

        minutes15: "15 minutos",
        minutes30: "30 minutos",
        hour1: "1 hora",
        hours2: "2 horas",
        hours4: "4 horas",
        hours8: "8 horas",
        indefinitely: "Indefinidamente",
        indefinite: "Indefinida",

        panelSettings: "Ajustes",
        panelQuit: "Sair",
        panelHotkeyHint: "Atalho alterna",

        keepAwakeTitle: "Manter acordado",
        keepAwakeEndsIn: "Termina em",
        keepAwakeUntilDisabled: "Ativo até você desativar",
        keepAwakeNormalRules: "O Mac segue as regras normais de energia",
        keepAwakeUntilLabel: "Até",
        keepAwakeUntilStart: "Iniciar",
        keepAwakeOptions: "Opções",
        notchMixerOptions: "Opções",
        ocrTextRecognitionSection: "Reconhecimento de texto",
        mediaOutputParamsSection: "Parâmetros de saída",
        cleanerAutomationSection: "Automatização",
        cleanerAutoOrganizeSection: "Organização automática",
        keepAwakeMouseJiggle: "Mover cursor levemente",
        keepAwakeMouseJiggleCaption: "Durante uma sessão, move o cursor um pouco no intervalo escolhido.",
        keepAwakeMouseJiggleInterval: "Intervalo",
        keepAwakeBatteryLimit: "Limite de bateria",
        keepAwakeBatteryLimitNever: "Nunca",
        keepAwakeBatteryLimitCaption: "Na bateria, com esse nível ou menos, a sessão termina e as automações não começam.",
        durationLabel: "Duração",
        clamshellTitle: "Continuar com a tampa fechada",
        clamshellOnCaption: "Suspensão totalmente desativada. Atenção à energia",
        clamshellNeedsSession: "Será aplicada sempre que “Manter acordado” estiver ativo",
        clamshellReady: "Pronto. Liga e desliga sem senha",
        clamshellNeedsPassword: "Pedirá a senha de administrador uma vez",

        systemSection: "Sistema",
        temperatures: "Temperaturas",
        cpuLabel: "CPU",
        gpuLabel: "GPU",
        batteryLabel: "Bateria",
        usageSection: "Uso de hardware",
        memorySection: "Memória",
        memoryPressure: "Pressão",
        memorySwapUsed: "Swap em uso",
        memoryCompressed: "Comprimida",
        memoryCachedFiles: "Arquivos em cache",
        pressureNormal: "Normal",
        pressureWarning: "Atenção",
        pressureCritical: "Crítico",
        monitorUnavailable: "Sensores indisponíveis neste Mac",
        energyAppsTitle: "Uso significativo de energia",
        energyAppsIdle: "Sem uso significativo de energia",

        notifySessionEndedTitle: "Sessão encerrada",
        notifySessionEndedBody: "O tempo acabou. O Mac voltará a suspender normalmente.",
        notifyBatteryTitle: "Hexa desativado",
        notifyBatteryBody: "Bateria baixa. A suspensão normal foi restaurada para proteger a carga.",
        adminPromptClamshellOn: "O Hexa precisa da sua senha para manter o Mac ativo com a tampa fechada.",
        adminPromptClamshellOff: "O Hexa precisa da sua senha para reativar a suspensão normal do Mac.",
        adminPromptRecover: "O Hexa foi encerrado com a suspensão do Mac desativada. Digite a senha para restaurar a suspensão normal.",
        sleepRestorePending: "A suspensão do Mac ficou desativada pela última sessão. Restaure para o Mac voltar a suspender normalmente.",
        sleepRestoreAction: "Restaurar suspensão",
        adminPromptSudoersInstall: "O Hexa vai criar uma regra restrita (somente pmset disablesleep) para alternar a tampa fechada sem pedir senha.",
        adminPromptSudoersRemove: "O Hexa vai remover a regra de tampa fechada sem senha.",

        settingsTitle: "Ajustes do Hexa",
        tabGeneral: "Geral",
        tabEnergy: "Energia",
        tabMouse: "Mouse e Trackpad",
        tabSwitcher: "Alternador",
        tabAdvanced: "Avançado",
        tabAbout: "Sobre",
        tabReleaseNotes: "Novidades",
        releaseNotesOnUpdateToggle: "Mostrar novidades ao atualizar",
        minimalWindowPreviews: "Prévias minimalistas",
        minimalWindowPreviewsCaption: "Oculta títulos, botões e detalhes decorativos nas prévias do Dock e do alternador. A seleção continua visível.",
        settingsGroupFeatures: "Recursos",
        advancedResetSection: "Permissões",
        advancedResetDescription: "Remove todas as permissões que você concedeu ao Hexa (Acessibilidade, Gravação de Tela, Acesso Total ao Disco e outras), o item de início e a regra de tampa fechada. Útil para começar do zero ou antes de desinstalar. O app continua instalado.",
        advancedClearButton: "Limpar todas as permissões",
        advancedCleared: "Permissões limpas.",
        advancedClearFailed: "Não foi possível remover algumas permissões ou a regra de tampa fechada. Tente de novo e permita o pedido de senha, se ele aparecer.",
        advancedClearConfirmTitle: "Limpar todas as permissões?",
        advancedClearConfirmBody: "Os recursos que dependem de permissão vão parar de funcionar até você conceder de novo. As suas configurações são mantidas.",
        advancedUninstallSection: "Desinstalar",
        advancedUninstallDescription: "Devolve ao macOS tudo o que o Hexa mudou, apaga os ajustes, move os caches, os dados e o próprio app para a Lixeira e fecha o Hexa.",
        advancedUninstallRecommended: "Para remover o Hexa por completo, com integrações do sistema, dados e ajustes, use esta desinstalação embutida.",
        advancedUninstallButton: "Desinstalar o Hexa completamente",
        advancedUninstallConfirmTitle: "Desinstalar o Hexa?",
        advancedUninstallConfirmBody: "O Hexa vai devolver as ventoinhas ao sistema e remover o helper delas, remover o item de login, restaurar o repouso, remover a regra sem senha da tampa fechada e devolver os atalhos do macOS que assumiu. Depois apaga os ajustes, move os caches, os dados e o próprio app para a Lixeira e fecha. O macOS pode pedir sua senha.",
        advancedUninstallFailedTitle: "A desinstalação parou",
        advancedUninstallFailedBody: "O Hexa não conseguiu devolver ao sistema o repouso, a regra sem senha da tampa fechada ou as ventoinhas. O app não foi removido. Tente de novo e permita o pedido de senha, se ele aparecer.",
        advancedUninstallTrashFailedBody: "O Hexa devolveu ao sistema o que tinha mudado e apaga os ajustes ao fechar, mas não conseguiu ir para a Lixeira. Arraste o app para a Lixeira.",

        launchAtLogin: "Iniciar junto com o Mac",
        languageLabel: "Idioma",
        menuBarSection: "Barra de menus",
        showCountdown: "Mostrar tempo restante ao lado do ícone",
        globalHotkeySection: "Atalho global",
        hotkeyToggle: "Ativar atalho para “Manter acordado”",
        hotkeyCaption: "Funciona em qualquer app, sem permissões extras.",

        sessionSection: "Sessão",
        defaultDurationLabel: "Duração padrão",
        keepAwakeAutoStart: "Manter acordado ao abrir o Hexa",
        keepAwakeAutoStartCaption: "Inicia uma sessão com a duração padrão.",
        clamshellSection: "Tampa fechada",
        configuring: "Configurando…",
        sudoersFailed: "Não foi possível ativar a tampa fechada. Tente de novo.",
        clamshellExplanation: "“Continuar com a tampa fechada” desativa completamente a suspensão enquanto “Manter acordado” estiver ativo e é revertido automaticamente quando a sessão termina ou o app é encerrado. Prefira usá-lo conectado à energia.",

        scrollSection: "Rolagem",
        invertMouseScroll: "Inverter rolagem do mouse",
        invertMouseScrollCaption: "Inverte a direção da roda do mouse.",
        scrollTrackpadNote: "O trackpad não muda: continua com a rolagem natural do macOS.",
        scrollActiveNow: "Invertendo a rolagem do mouse agora",
        mouseNavigationActiveNow: "Botões laterais ativos agora",
        smoothScrollName: "Rolagem suave",
        smoothScrollCaption: "Transforma cada passo da rodinha do mouse em um deslize curto e macio. O trackpad não muda.",
        smoothScrollStepLabel: "Velocidade da rolagem",
        mouseNavigationSection: "Navegação",
        mouseNavigationEnable: "Usar botões laterais para voltar e avançar",
        mouseNavigationCaption: "Converte os botões Voltar e Avançar do mouse em comandos de navegação no Finder, navegadores e apps compatíveis.",
        middleClickSection: "Botão do meio no trackpad",
        middleClickEnable: "Clique com três dedos vira botão do meio",
        middleClickEnableCaption: "Pressionar o trackpad com três dedos funciona como o clique da rodinha do mouse: abre links em nova aba, fecha abas e tudo mais que o botão do meio faz.",
        middleClickDragConflict: "O arrastar com três dedos do macOS está ativado e usa três dedos, então clique com quatro dedos para o clique do meio. Para usar três, desative-o nos Ajustes do Sistema em Acessibilidade, Controle do Cursor, Opções do Trackpad.",
        middleClickNoTrackpad: "Não é possível ler os toques no trackpad. Conecte um trackpad compatível.",
        middleClickTapPicker: "Toque leve também clica",
        middleClickTapOff: "Desligado",
        middleClickTapThreeFingers: "3 dedos",
        middleClickTapFourFingers: "4 dedos",
        middleClickTapCaption: "Um toque leve com esse número de dedos, sem pressionar, também dispara o clique do meio. Deslizar nunca conta. Se o toque de três dedos do macOS estiver atribuído à Busca, desative-o para os dois não abrirem juntos.",
        quickToolsTab: "Painel rápido",
        quickToolShortcutToggle: "Atalho global",
        ocrName: "Copiar texto da tela",
        ocrCaption: "Selecione uma área da tela e o texto reconhecido é copiado, pronto para colar.",
        ocrCopied: "Texto copiado",
        ocrNoText: "Nenhum texto encontrado",
        ocrClipboardChanged: "Não copiado: a área de transferência mudou durante o reconhecimento",
        colorPickerName: "Conta-gotas de cor",
        colorPickerCaption: "Capture a cor de qualquer pixel da tela e copie no formato que preferir.",
        colorPickerFormatLabel: "Formato copiado",
        colorPickerBareHexToggle: "Copiar sem o prefixo #",
        colorPickerPickNow: "Capturar cor",
        micMuteName: "Silenciar microfone",
        micUnmuteName: "Reativar microfone",
        micMuteCaption: "Corta o microfone do Mac com um clique ou atalho, valendo para qualquer app.",
        micMutedHUD: "Microfone silenciado",
        micUnmutedHUD: "Silenciamento desativado",
        micMutePartialHUD: "Alguns microfones não puderam ser silenciados",
        micUnmutePartialHUD: "Alguns microfones continuam silenciados",
        micMuteMenuBarToggle: "Mostrar na barra de menus enquanto silenciado",
        micMuteMenuBarCaption: "Um microfone cortado em vermelho aparece ao lado do ícone do app na barra de menus enquanto este recurso o silencia.",
        launcherName: "Painel rápido",
        launcherCaption: "Um painel flutuante com suas ferramentas favoritas, aberto por atalho de qualquer lugar.",
        launcherOpenNow: "Abrir painel rápido",
        launcherEditHint: "Use o botão de ajustes para escolher, ocultar e arrastar as ferramentas.",
        launcherEmptyState: "Todas as ferramentas estão ocultas. Use o botão de ajustes para trazê-las de volta.",
        launcherAddSection: "Adicionar de volta",
        launcherKeysHint: "Setas navegam, Enter abre, 1 a 9 abrem direto",

        switcherSection: "Alternador de janelas",
        switcherEnable: "Usar o alternador do Hexa",
        switcherEnableCaption: "Troque de app ou janela, inclusive janelas minimizadas e várias janelas do mesmo app.",
        switcherUsageHint: "Segure o atalho para navegar; solte para ativar a janela. Shift ou ← volta; W fecha a janela; Q encerra o app; Esc cancela.",
        switcherNoWindows: "Nenhuma janela aberta",
        switcherIconRowMode: "Mostrar %@ com ícones grandes",
        switcherIconRowModeCaption: "Mostra um ícone por app com os previews das janelas do app acima.",
        switcherSimpleModeCaption: "Mostra ícones de apps e títulos das janelas, sem previews nem captura da tela pelo alternador.",
        switcherShortcutHintApps: "Apps",
        switcherShortcutHintWindows: "Janelas",
        switcherWindowShortcutCaption: "Abre um seletor das janelas do app em primeiro plano. Com o seletor aberto, pula entre as janelas do app selecionado.",
        switcherTakeOverSystemShortcuts: "Substituir ⌘Tab e ⌘` do macOS",
        switcherTakeOverSystemShortcutsCaption: "Desativa os atalhos correspondentes de apps e janelas do macOS somente enquanto o alternador do Hexa estiver ativo. Todos os apps abertos continuam acessíveis.",
        switcherAppearanceDelay: "Atraso de exibição",
        switcherAppearanceDelayCaption: "Quanto tempo o atalho precisa ficar pressionado antes de o alternador aparecer.",
        switcherInstantSelection: "Seleção instantânea",
        switcherInstantSelectionCaption: "Move o destaque e a rolagem imediatamente ao navegar por apps e janelas.",
        switcherMergeTabs: "Mostrar uma entrada por app",
        switcherMergeTabsCaption: "Junta todas as janelas de um app em uma só entrada no alternador, em vez de uma por janela.",
        switcherWindowlessApps: "Apps sem janela aberta",
        switcherWindowlessAppsCaption: "Escolhe quais apps que estão abertos sem nenhuma janela aparecem no alternador.",
        switcherWindowlessAppsOff: "Não mostrar",
        switcherWindowlessAppsFinder: "Só o Finder",
        switcherWindowlessAppsAll: "Todos os apps",
        switcherNoOpenWindow: "Sem janela aberta",
        switcherOtherDesktop: "Outra Mesa",
        dockPreviewName: "Dock Preview",
        dockPreviewEnable: "Pré-visualizar janelas no Dock",
        dockPreviewEnableCaption: "Passe o mouse em um app aberto no Dock para ver suas janelas e clique na que quiser abrir.",
        dockPreviewCurrentSpaceOnlyCaption: "Quando desligado, mostra janelas de todas as mesas. Escolher uma janela em outra mesa leva você até ela.",
        dockPreviewBackgroundOpacity: "Fundo do painel",
        dockPreviewBackgroundOpacityCaption: "Diminua para ver mais do que está atrás do painel.",
        dockPreviewOpenDelay: "Atraso de abertura",
        dockPreviewOpenDelayCaption: "Quanto tempo o ponteiro precisa ficar sobre um ícone antes de o painel abrir.",
        dockPreviewQuitAppOnClose: "Encerrar o app com o botão ×",
        dockPreviewQuitAppOnCloseCaption: "No Dock Preview, × encerra o app inteiro em vez de fechar apenas aquela janela.",
        dockPreviewKeepDockVisible: "Manter Dock visível (experimental)",
        dockPreviewKeepDockVisibleCaption: "Suspende o ocultamento automático enquanto o preview está aberto e restaura ao sair. Pode reajustar janelas. Se o app for interrompido, reabra-o para restaurar o Dock.",
        dockPreviewOrderByCreation: "Ordenar janelas por criação",
        dockPreviewOrderByCreationCaption: "Mostra primeiro as janelas mais antigas em vez das usadas mais recentemente.",
        dockClickMinimize: "Clicar no Dock minimiza",
        dockClickMinimizeCaption: "As janelas do app ativo são minimizadas ao clicar no ícone dele no Dock. Clique de novo para trazê-las de volta.",
        dockClickCycleWindows: "Clicar no Dock alterna janelas",
        dockClickCycleWindowsCaption: "Clique no ícone do Dock do app ativo para alternar entre suas janelas, como ⌘`.",
        dockPreviewActiveNow: "Ativo no Dock",
        dockPreviewDockUnavailable: "Não foi possível ler os itens do Dock.",
        dockPreviewAutohideBeta: "Beta. Você pode encontrar alguns bugs.",
        dockPreviewOpenWindow: "Abrir janela",
        dockPreviewCloseWindow: "Fechar janela",
        dockPreviewMinimizeWindow: "Minimizar janela",
        dockPreviewRestoreWindow: "Restaurar janela",
        dockPreviewPinPanel: "Fixar prévia",
        dockPreviewUnpinPanel: "Desfixar prévia",
        dockPreviewPinned: "Fixado",
        dockPreviewClosePanel: "Fechar prévia",
        dockPreviewPreviousWindow: "Janela anterior",
        dockPreviewNextWindow: "Próxima janela",

        cutPasteName: "Recortar e colar",
        cutPasteEnable: "Recortar e colar arquivos no Finder",
        cutPasteEnableCaption: "Use ⌘X para recortar e ⌘V para mover arquivos e pastas no Finder.",
        cutPasteShowHUD: "Mostrar painel flutuante",
        cutPasteShowHUDCaption: "Exibe um indicador com os arquivos recortados enquanto o Finder estiver ativo.",
        cutPasteHowTitle: "Como usar",
        cutPasteStep1: "Selecione itens no Finder e pressione ⌘X para recortá-los.",
        cutPasteStep2: "Abra a pasta de destino e pressione ⌘V para movê-los para lá.",
        cutPasteTextNote: "Em campos de texto (como ao renomear), ⌘X e ⌘V continuam funcionando normalmente.",
        cutPasteActiveNow: "Pronto para recortar no Finder",
        cutPasteAutomationNote: "Na primeira vez, o macOS pede permissão para controlar o Finder.",
        cutReadyTitle: "Recortado",
        cutReadyHint: "na pasta de destino para mover",
        cutCancel: "Cancelar recorte",
        cutDoneTitle: "Movido!",
        cutMovedSingular: "1 item movido",
        cutMovedPluralFormat: "%d itens movidos",
        cutSomeFailed: "Alguns itens não puderam ser movidos",
        cutMovingTitle: "Movendo…",
        cutMovingCountFormat: "%d de %d",

        autoQuitName: "Encerrar ao fechar",
        autoQuitEnable: "Encerrar o app ao fechar a última janela",
        autoQuitEnableCaption: "Fechar a última janela de um app também o encerra.",
        autoQuitActiveNow: "Ativo agora",
        autoQuitHowTitle: "Como funciona",
        autoQuitStep1: "Feche a última janela de um app (⌘W ou o botão vermelho).",
        autoQuitStep2: "O app é encerrado sozinho. Diálogos de “salvar?” continuam aparecendo.",
        autoQuitPredictableNote: "Apps que normalmente rodam sem janela nunca são encerrados.",
        autoQuitOngoingWorkNote: "Alguns apps fecham a última janela e continuam trabalhando, como um gravador de tela depois que a captura começa. Esses também são encerrados, a menos que estejam na lista de exceções.",
        autoQuitExceptionsTitle: "Exceções",
        autoQuitExceptionsCaption: "Apps nesta lista continuam abertos mesmo sem nenhuma janela.",
        autoQuitExceptionsEmpty: "Nenhuma exceção",
        autoQuitAddApp: "Adicionar app…",

        uninstallerName: "Desinstalador",
        uninstallerEnableCaption: "Remove um app junto com os caches, preferências, logs e resíduos que ele deixa para trás.",
        uninstallerStep1: "Arraste um app para os Ajustes ou escolha um da lista.",
        uninstallerStep2: "Revise os arquivos encontrados e quanto espaço ocupam.",
        uninstallerStep3: "Mova o que quiser para a Lixeira. Nada é apagado de forma definitiva.",
        uninstallerMenuItem: "Desinstalar um app…",
        uninstallerDropTitle: "Arraste um app aqui",
        uninstallerDropSubtitle: "ou escolha um para analisar",
        uninstallerChoose: "Escolher app…",
        uninstallerPickerTitle: "Escolher app",
        uninstallerPickerSearch: "Buscar apps",
        uninstallerPickerEmpty: "Nenhum app encontrado",
        uninstallerEmptyNote: "Nada é removido sem a sua confirmação.",
        uninstallerFDANote: "Conceda Acesso Total ao Disco para uma análise mais completa.",
        uninstallerFDAGrant: "Conceder acesso…",
        uninstallerFDAHint: "Ative o Hexa na lista. Se ele não aparecer, clique no + e escolha o Hexa em Aplicativos. O acesso só vale depois de reabrir o app.",
        uninstallerFDARelaunch: "Reabrir agora",
        uninstallerScanning: "Analisando arquivos…",
        loadingMessage: "Carregando…",
        uninstallerRemoving: "Movendo para a Lixeira…",
        uninstallerFoundTitle: "encontrado",
        uninstallerSelectedFormat: "%d de %d selecionados",
        uninstallerRemove: "Mover para a Lixeira",
        uninstallerCancel: "Cancelar",
        uninstallerConfirmationExpired: "Esta confirmação não é mais válida. Revise os itens atuais e confirme de novo.",
        uninstallerQuitTitle: "Fechar o app para remover?",
        uninstallerQuitBodyFormat: "%@ está aberto. O Hexa vai pedir que ele feche antes de mover o app para a Lixeira. Se houver alterações não salvas, o app pode pedir para você salvá-las.",
        uninstallerQuitAndRemove: "Fechar e remover",
        uninstallerForceQuitTitle: "O app não fechou",
        uninstallerForceQuitBodyFormat: "%@ continua aberto e pode estar esperando você salvar. Forçar o encerramento descarta as alterações não salvas. Para salvar antes, cancele e volte ao app.",
        uninstallerForceQuitAndRemove: "Forçar e remover",
        uninstallerTerminalContinue: "Já rodei no Terminal",
        uninstallerTerminalStillInstalled: "O app ainda está no disco. Termine o comando no Terminal e tente de novo.",
        uninstallerDoneTitle: "Pronto!",
        movedToTrashFormat: "%@ na Lixeira, ainda ocupando espaço até esvaziá-la",
        freedPermanentlyFormat: "%@ liberados",
        uninstallerSomeFailed: "Alguns itens não puderam ser movidos para a Lixeira.",
        uninstallerFailedNeedsFDA: "Os dados de apps em área restrita só podem ser movidos com Acesso Total ao Disco. A senha de administrador não substitui essa permissão.",
        uninstallerFailedMoreFormat: "e mais %d",
        uninstallerAnother: "Desinstalar outro",
        uninstallerCatApp: "Aplicativo",
        uninstallerCatSupport: "Suporte",
        uninstallerCatCaches: "Caches",
        uninstallerCatPreferences: "Preferências",
        uninstallerCatContainers: "Contêineres",
        uninstallerCatLogs: "Logs",
        uninstallerCatState: "Estado salvo",
        uninstallerCatOther: "Outros",
        uninstallerHiddenHomeLegend: "pode conter dados e configurações seus",
        uninstallerSystemExtensionNote: "Este app instala uma extensão do sistema. O macOS pede a sua confirmação em Ajustes do Sistema para removê-la. Os arquivos selecionados vão para a Lixeira.",
        uninstallerLoginItemNote: "Este app registra um item de início. Se ele continuar em Ajustes do Sistema depois da remoção, desligue-o lá. Os arquivos selecionados vão para a Lixeira.",
        uninstallerAdminUnloadPrompt: "O Hexa precisa descarregar um serviço deste app antes de movê-lo para a Lixeira.",
        spaceInventoryTitle: "Onde está o espaço",
        spaceInventoryLegend: "Só informativo. O Hexa mede estas pastas e não remove nada daqui.",
        spaceInventoryModelsCaption: "Modelos locais de IA",
        spaceInventoryToolsCaption: "Dados de ferramentas de código com índice (sem remoção)",
        spaceInventoryVMsCaption: "Imagens de máquinas virtuais",
        spaceInventorySimulatorsTitle: "Simuladores do Xcode",
        spaceInventorySimulatorsScope: "todos os simuladores, incluindo os indisponíveis",
        spaceInventorySimulatorNote: "Para apagar só os indisponíveis, rode este comando no Terminal:",
        spaceInventorySimulatorWarning: "Permanente: o comando não usa a Lixeira e não pode ser desfeito.",
        spaceInventoryMeasure: "Calcular",
        uninstallerSelectionUnavailable: "Selecione um aplicativo que possa ser removido no Finder ou escolha outro na lista.",
        uninstallerRefusedSystemApp: "Aplicativos do macOS fazem parte do sistema e não podem ser removidos.",
        uninstallerRefusedNestedApp: "Este aplicativo faz parte de outro pacote. Selecione o aplicativo principal para removê-lo.",
        uninstallerRefusedSelfApp: "O hexa está em execução e não pode desinstalar a si mesmo.",
        uninstallerClearSelection: "Limpar seleção",

        urlCleanerName: "Limpar URL",
        urlCleanerEnable: "Limpar URLs ao copiar",
        urlCleanerEnableCaption: "Remove os parâmetros de rastreamento de um link assim que ele chega à área de transferência.",
        urlCleanerActiveNow: "Ativo agora",
        urlCleanerManualTitle: "Limpar agora",
        urlCleanerInputPlaceholder: "Cole uma URL",
        urlCleanerOutputPlaceholder: "A URL limpa aparece aqui",
        urlCleanerCleanButton: "Limpar",
        urlCleanerPasteButton: "Colar",
        urlCleanerCopyButton: "Copiar",
        urlCleanerClearButton: "Limpar campo",
        urlCleanerNoURL: "Cole uma URL válida.",
        urlCleanerNoChange: "Nada para limpar.",
        urlCleanerCleaned: "URL limpa.",
        urlCleanerCopied: "Copiado.",
        urlCleanerLocalNote: "Local. Sem rede.",

        homebrewTrustTitle: "Tap ainda não confiável",
        homebrewTrustCaption: "O Homebrew agora pede sua confirmação antes de usar taps de terceiros. Confie em %@ para continuar.",
        homebrewTrustButton: "Confiar e continuar",
        homebrewGroupDependencies: "Agrupar dependências",
        homebrewUninstall: "Desinstalar",
        homebrewAllPackages: "pacotes",
        homebrewOpenTerminal: "Abrir Terminal",
        homebrewCancelOperation: "Cancelar",
        homebrewClearLog: "Limpar log",
        homebrewConfirmUninstallTitle: "Desinstalar pelo Homebrew?",
        homebrewConfirmUninstallBodyFormat: "O Homebrew vai desinstalar %@. Arquivos de configuração podem permanecer no sistema.",
        homebrewTerminalFallback: "Esta operação precisa do Terminal para pedir a senha de administrador. O Hexa não captura senhas.",
        homebrewOperationUninstallFormat: "Desinstalando %@",
        homebrewOperationUpgradeAll: "Atualizando pacotes",
        homebrewOperationUninstalledFormat: "%@ desinstalado.",
        homebrewOperationUpgradedAll: "Pacotes atualizados.",
        homebrewOperationFailedFormat: "Não foi possível concluir %@.",
        homebrewOperationCancelled: "Operação cancelada.",
        homebrewOperationPreparing: "Preparando…",
        homebrewOperationDownloading: "Baixando arquivos…",
        homebrewOperationUninstalling: "Removendo arquivos…",
        homebrewOperationUpgrading: "Atualizando arquivos…",
        homebrewOperationFinalizing: "Finalizando…",
        homebrewOperationRefreshing: "Atualizando lista…",
        homebrewOperationTerminal: "Continue no Terminal.",
        homebrewOperationElapsedFormat: "%@ decorridos",
        homebrewOperationShowDetails: "Mostrar detalhes",
        homebrewOperationHideDetails: "Ocultar detalhes",
        homebrewOperationTechnicalLog: "Detalhes técnicos",
        homebrewOperationProgressUnknown: "O Homebrew ainda não informou uma porcentagem.",

        mediaName: "Mídia",
        mediaEnableCaption: "Comprima vídeos, converta e processe imagens, crie GIFs e extraia texto localmente.",
        mediaLocalNote: "Local. Sem rede.",
        mediaToolVideo: "Vídeo",
        mediaToolGIF: "GIF",
        mediaToolImage: "Imagem",
        mediaToolText: "Texto",
        mediaSelectFile: "Escolher arquivo",
        mediaDropHint: "Arraste um arquivo aqui ou clique para escolher.",
        mediaOutput: "Saída",
        mediaOutputAutomatic: "Automática",
        mediaChooseOutput: "Destino",
        mediaStartVideo: "Comprimir vídeo",
        mediaStartGIF: "Criar GIF",
        mediaStartImage: "Processar imagem",
        mediaStartConvertPDF: "Converter em PDF",
        mediaStartText: "Extrair texto",
        mediaCancel: "Cancelar",
        mediaStartTime: "Início",
        mediaEndTime: "Fim",
        mediaQuality: "Qualidade",
        mediaCompressionLow: "Alta",
        mediaCompressionMedium: "Média",
        mediaCompressionHigh: "Baixa",
        mediaCompressionLowDescription: "Alta fidelidade, arquivo maior",
        mediaCompressionMediumDescription: "Equilíbrio entre fidelidade e tamanho do arquivo",
        mediaCompressionHighDescription: "Baixa fidelidade, arquivo menor",
        mediaMaxSize: "Tamanho",
        mediaSizingResolution: "Resolução",
        mediaSizingFileSize: "Tamanho do arquivo",
        mediaTargetSize: "Tamanho alvo",
        mediaTargetSizeHint: "A resolução se ajusta para ficar abaixo do limite.",
        mediaErrorTargetTooSmall: "Tamanho alvo pequeno demais para este clipe. Encurte-o ou aumente o limite.",
        mediaErrorGIFTooLongFormat: "Um GIF pode ter até %d segundos",
        mediaMegabytesSuffix: " MB",
        mediaWidth: "Largura",
        mediaFPS: "FPS",
        mediaKeepAudio: "Manter áudio",
        mediaCodec: "Codec",
        mediaFormat: "Formato",
        mediaStripMetadata: "Remover metadados",
        mediaLoopGIF: "Repetir GIF",
        mediaOCRMode: "OCR",
        mediaOCRAccurate: "Preciso",
        mediaOCRFast: "Rápido",
        mediaLanguageCorrection: "Correção de idioma",
        mediaTextOutputNote: "O texto extraído pode ser copiado e salvo em TXT.",
        mediaRunning: "Processando",
        mediaCompleted: "Concluído",
        mediaCancelled: "Cancelado.",
        mediaStatusNotice: "Status",
        mediaOpenInFinder: "Mostrar",
        mediaCopyText: "Copiar texto",
        mediaRunAgain: "Rodar de novo",
        mediaEmptyText: "Nenhum texto encontrado.",
        mediaResultSavedFormat: "Salvo como %@",
        mediaResultSizeFormat: "%@ para %@",
        mediaResultGrewCaption: "O arquivo convertido ficou maior que o original.",
        mediaErrorNoFile: "Escolha um arquivo primeiro.",
        mediaErrorNoVideo: "Este arquivo não tem trilha de vídeo.",
        mediaErrorSameOutput: "Escolha um destino diferente do arquivo original.",
        mediaErrorUnsupported: "Formato não suportado pelo macOS.",

        extraBrightnessName: "Brilho extra",
        extraBrightnessCaption: "Usa a reserva HDR da tela para passar do brilho máximo. Consome mais bateria e o Mac pode esquentar.",
        extraBrightnessUnsupported: "Disponível apenas em telas XDR, como as dos MacBook Pro de 14 e 16 polegadas.",
        shelfHotkeyLabel: "Atalho",

        breakdownMeasuring: "Medindo…",

        mixerSection: "Mixer de volume",
        mixerEmpty: "Apps que usam áudio aparecem aqui",
        mixerUnavailable: "Disponível a partir do macOS 14.4",
        mixerPermissionBody: "Para ajustar o volume por app, permita “Gravação de Tela e Áudio do Sistema” nos Ajustes do Sistema. O áudio nunca é gravado.",
        mixerResetTooltip: "Voltar para 100%",
        mixerOutputDefault: "Padrão",
        mixerOutputCurrent: "atual",
        mixerOutputUnavailable: "Saída indisponível",
        mixerOutputFallback: "Usando o padrão até esse dispositivo voltar.",
        mixerBypassedCaption: "Este app controla o próprio áudio.",
        mixerOutputTooltip: "Escolher saída",
        mixerAirPlayChooseSpeaker: "Escolher alto-falante AirPlay…",
        mixerSystemOutputTitle: "Saída",
        mixerSystemOutputNoDevices: "Nenhuma saída encontrada",
        mixerSystemOutputTooltip: "Escolher saída do sistema",
        mixerSystemOutputErrorFormat: "Não foi possível trocar: %@",
        mixerLowerOnHeadphonesDisconnect: "Baixar volume ao desconectar fones",
        mixerLowerOnHeadphonesDisconnectCaption: "Ajusta a saída quando fones com fio ou Bluetooth desconectam.",
        mixerHeadphonesDisconnectVolume: "Volume ao desconectar",
        preciseVolumeRollerEnable: "Volume mais preciso no controle",
        preciseVolumeRollerCaption: "Transforma roletes e teclas de volume em passos menores.",
        preciseVolumeRollerTapFailed: "Não foi possível ouvir as teclas de volume.",
        mixerInputTitle: "Microfone",
        mixerInputNoDevices: "Nenhum microfone encontrado",
        mixerInputUnavailable: "Microfone indisponível",
        mixerInputFallback: "Usando o padrão até esse microfone voltar.",
        mixerInputTooltip: "Escolher microfone",
        mixerInputErrorFormat: "Não foi possível trocar: %@",
        mixerVisibleApps: "Apps na lista",
        mixerAllShown: "Todos",
        mixerHiddenCountLabel: "Escondidos",
        mixerHideFromList: "Esconder da lista",
        audioPrioritySection: "Prioridade dos dispositivos de áudio",
        audioPriorityOutputEnable: "Trocar automaticamente para a saída de áudio com maior prioridade",
        audioPriorityInputEnable: "Trocar automaticamente para o microfone de maior prioridade",
        audioPriorityOutputList: "Prioridade das saídas de áudio",
        audioPriorityInputList: "Prioridade dos microfones",
        audioPriorityMoveUp: "Mover para cima",
        audioPriorityMoveDown: "Mover para baixo",
        audioPriorityUnavailable: "Indisponível",
        audioPriorityCurrent: "Em uso",
        audioPriorityCaption: "Os dispositivos são selecionados por ordem de prioridade. Quando um dispositivo de maior prioridade é conectado, ele passa a ser usado. Quando o dispositivo ativo é desconectado, o próximo disponível é selecionado.",

        updatesSection: "Atualizações",
        autoCheckToggle: "Procurar atualizações automaticamente",
        betaBadgeLabel: "Beta",
        checkNowButton: "Procurar agora",
        updateChecking: "Procurando…",
        updateUpToDate: "Você está na versão mais recente.",
        updateInstallButton: "Baixar e instalar",
        updateFailedPrefix: "Não foi possível verificar:",
        updateLastChecked: "Última verificação:",
        menuCheckUpdates: "Procurar atualizações de apps…",

        permissionRequired: "Permissão necessária",
        permissionAccessibility: "Acessibilidade",
        permissionScreenRecording: "Gravação de Tela",
        permissionGranted: "Concedida",
        permissionMissing: "Não concedida",
        permissionOpenSettings: "Abrir Ajustes do Sistema…",
        permissionRequest: "Conceder acesso",
        permissionRestartNote: "O macOS pode pedir para reabrir o app depois de conceder.",
        secureInputTitle: "A entrada segura está ativa",
        secureInputHeldFormat: "%@ está mantendo-a ativa, então o Hexa não consegue digitar por você. Saia do campo de senha do app, ou encerre-o, para liberá-la.",
        secureInputUnattributed: "Nenhum app em execução a reivindica. Encerre a sessão e entre novamente para limpá-la.",
        secureInputUnidentified: "Não foi possível identificar o app que a está mantendo ativa, então o Hexa não consegue digitar por você.",
        secureInputRevealFormat: "Mostrar %@",

        aboutDescription: "Utilitário modular de sistema para macOS.\nGerenciamento de energia, telemetria de hardware, manutenção e ferramentas rápidas.",
        versionPrefix: "Versão",
        reviewIntro: "Rever introdução",
        reviewHighlights: "Rever notas da versão",
        viewOnGitHub: "Repositório no GitHub",
        downloadLatestRelease: "Baixar a versão mais recente",

        obContinue: "Continuar",
        obBack: "Voltar",
        obStepWelcomeTitle: "Bem-vindo ao Hexa",
        obStepWelcomeBody: "O Hexa é um utilitário modular de macOS. Tudo funciona sob demanda, e o app não tem telemetria.",
        obWelcomeBullet1Title: "Controle de energia",
        obWelcomeBullet1Body: "Gerenciamento de suspensão e operação contínua sob demanda.",
        obWelcomeBullet2Title: "Monitoramento do sistema",
        obWelcomeBullet2Body: "Monitoramento em tempo real de hardware, temperaturas e pressão de memória.",
        obWelcomeBullet3Title: "Manutenção e utilitários",
        obWelcomeBullet3Body: "Desinstalação completa de aplicativos, limpeza de sistema e controle de processos.",
        obStepModulesTitle: "Módulos",
        obStepModulesBody: "Escolha o que este Mac executa. O que você desligar aqui sai da barra de menus e dos Ajustes, e pode ser religado depois nos Ajustes.",
        obStepPermissionsTitle: "Permissões",
        obStepPermissionsBody: "São as permissões exigidas pelos módulos que você manteve ligados. O Hexa só pede ao macOS quando você solicitar.",
        obStepDoneTitle: "Configuração concluída",
        obStepDoneBody: "O Hexa está ativo e pronto para uso.",
        obDoneHint: "Acesse o ícone do Hexa na barra de menus no canto superior da tela.",
        obFinish: "Concluir",
        obPermissionPendingNote: "Não concedida. O Hexa pede de novo quando o módulo precisar.",
        obRedoOnboarding: "Refazer a configuração",
        obWhatsNewTitle: "Notas da versão",
        releaseNotesUnavailable: "As notas desta versão não estão disponíveis.",
        obWhatsNewFallback: "Esta versão inclui aprimoramentos de desempenho e correções de estabilidade.",

        tabMonitor: "Monitor",
        monitorMenuBarSection: "Na barra de menus",
        monitorMenuBarCaption: "Escolha o que aparece ao lado do ícone na barra de menus.",
        monitorCombineTemperatures: "Combinar uso e temperatura",
        monitorCombineTemperaturesCaption: "Quando uso e temperatura do mesmo item estiverem ativos, mostra tudo em um bloco só.",
        monitorSeparateMenuBarMetrics: "Separar métricas em itens próprios",
        monitorSeparateMenuBarMetricsCaption: "Separa os blocos ativos na barra de menus e mantém uso e temperatura juntos quando combinar estiver ativo.",
        monitorNetworkUploadFirst: "Upload acima do download",
        monitorShowCPU: "CPU",
        monitorShowMemory: "Memória",
        monitorShowNetwork: "Rede",
        monitorShowPowerLabel: "Energia",
        monitorIntervalLabel: "Atualizar a cada",
        monitorInterval1: "1 segundo",
        monitorInterval2: "2 segundos",
        monitorInterval5: "5 segundos",
        monitorPanelSection: "No painel",
        panelNavigationMode: "Navegar por seções no painel",
        panelNavigationCaption: "Mostra uma seção por vez. Escolha Lista para ver tudo em uma rolagem contínua.",
        panelFooterSections: "Seções",
        panelFooterList: "Lista",
        betaBadge: "BETA",
        betaFeatureWarning: "Beta. Você pode encontrar alguns bugs.",

        networkSection: "Rede",
        networkIPAddresses: "Endereços IP",
        networkLocalIP: "IPv4 local",
        networkDownload: "Download",
        networkUpload: "Upload",
        networkThisSession: "Nesta sessão",
        networkMeasuring: "Medindo…",
        networkApps: "Apps usando rede",
        networkAppsIdle: "Nenhum app usando rede agora",

        diskSection: "Discos",
        diskUsed: "usado",
        diskFree: "livre",
        diskMenuBarStyleLabel: "Exibição do disco",
        diskMenuBarUsedPercentage: "Porcentagem usada",
        diskMenuBarAvailableSpace: "Espaço disponível",
        diskMenuBarUsedSpace: "Espaço usado",
        diskAvailable: "disponível",
        diskPurgeable: "purgável",
        diskInternal: "Interno",
        diskExternal: "Externo",
        diskSelect: "Selecionar disco",
        diskRead: "Leitura",
        diskWrite: "Escrita",
        diskSMARTStatus: "Status",
        diskSMARTUnavailable: "SMART indisponível para este disco",
        diskTotalRead: "Total lido",
        diskTotalWritten: "Total escrito",
        diskTemperature: "Temperatura",
        diskHealth: "Saúde",
        diskPowerCycles: "Ciclos",
        diskPowerOnHours: "Horas ligado",
        diskUnsafeShutdowns: "Desligamentos inseguros",
        diskMediaErrors: "Erros de mídia",
        diskEject: "Ejetar",
        diskEjectAll: "Ejetar todos",
        diskEjecting: "Ejetando…",
        diskReadyToRemove: "Pronto para remover",
        diskEjectFailed: "Não foi possível ejetar",
        diskEjectSiblingsTitleFormat: "Ejetar \"%@\" também ejeta outros volumes",
        diskEjectSiblingsMessageFormat: "Estes volumes estão no mesmo disco e saem junto: %@.",
        diskProtectionCaption: "Ejete antes de desconectar.",
        diskNoExternal: "Nenhum disco externo pronto para ejeção.",
        diskOpenInFinder: "Abrir",
        diskStorageSettings: "Armazenamento",
        diskNoDisks: "Nenhum disco montado encontrado.",

        powerSection: "Energia",
        powerSystem: "Sistema",
        powerAdapter: "Adaptador",
        powerBattery: "Bateria",
        powerCharging: "Carregando",
        powerOnBattery: "Na bateria",
        powerPluggedIn: "Na tomada",
        powerUnavailable: "Métricas de energia indisponíveis neste Mac",
        powerAdapterMaxFormat: "%@ máx.",
        monitorShowGPU: "GPU",
        monitorShowCPUTemperature: "Temperatura da CPU",
        monitorShowGPUTemperature: "Temperatura da GPU",
        monitorShowBatteryTemperature: "Temperatura da bateria",
        monitorShowPeripheralBattery: "Bateria dos periféricos",
        peripheralBatteryNoDevices: "Nenhum periférico encontrado",

        obStepMenuBarTitle: "Métricas na barra de menus",
        obStepMenuBarBody: "Escolha o que mostrar ao lado do ícone. A prévia acima muda em tempo real.",
        obStepMenuBarNote: "Novidade: blocos de Rede e Energia e gráficos no painel. Ajuste tudo depois em Ajustes › Monitor.",
        monitorMenuBarPresetLabel: "Estilo",
        menuBarPresetReadable: "Legível",
        menuBarPresetDense: "Denso",
        menuBarSpacingLabel: "Espaçamento na barra",
        menuBarSpacingStandard: "Padrão",
        menuBarSpacingCompact: "Compacto",
        menuBarHideIconToggle: "Ocultar o ícone do app enquanto houver métricas",
        menuBarHideIconCaption: "O ícone só volta quando as métricas saem da barra. Atualização pronta e “Manter acordado” ativo não o trazem de volta.",
        monitorLabelStyleLabel: "Rótulos",
        menuBarLabelStyleCompact: "Compactos",
        menuBarLabelStyleClassic: "Clássicos",
        monitorMemoryStyleLabel: "Mostrar memória como",
        monitorMemoryPressureDot: "Ponto de pressão",
        memoryStyleDot: "Ponto",
        memoryStylePercent: "%",
        memoryStyleBoth: "Ambos",
        systemUptime: "Ativo há",
        batteryCharge: "Carga",
        powerHealth: "Saúde da bateria",
        powerCycles: "Ciclos",
        speedTestRun: "Testar velocidade",
        speedTestAgain: "Testar de novo",
        speedTestLatency: "Latência",
        speedTestTesting: "Testando…",
        speedTestFailed: "Falha no teste",

        disclosureExpanded: "Expandido",
        disclosureCollapsed: "Recolhido",
        panelHideItem: "Ocultar do painel",
        panelShowItem: "Mostrar no painel",
        panelHiddenItem: "Oculto",
        monitorItemUptime: "Tempo ativo",
        monitorItemNetSpeed: "Velocidade ao vivo",
        monitorItemNetTotals: "Totais da sessão",
        monitorItemNetTest: "Teste de velocidade",
        monitorItemDiskUsage: "Uso do disco",
        monitorItemDiskActivity: "Atividade ao vivo",
        monitorItemDiskSMART: "SMART",
        monitorItemDiskProtection: "Proteção externa",
        monitorItemDiskTools: "Ferramentas",
        monitorPanelConfigHint: "Abra um bloco para escolher o que ele mostra.",
        monitorOrderHint: "Arraste para reordenar as seções do painel e use o olho para mostrar ou ocultar cada uma.",
        obStepPanelTitle: "O que aparece no painel",
        obStepPanelBody: "Abra cada bloco e escolha exatamente o que mostrar quando você clica no ícone.",
        obStepPanelNavigationTitle: "Painel por seções",
        obStepPanelNavigationBody: "O painel agora pode mostrar uma seção por vez. Você pode mudar entre Seções e Lista nos Ajustes.",

        cleaningMenuItem: "Modo de limpeza",
        utilitiesSection: "Utilidades",
        quickControlsSection: "Controles",
        panelCategoryWindows: "Janelas",
        panelCategoryInput: "Mouse e teclado",
        panelCategoryFiles: "Arquivos",
        windowMaximizeName: "Maximizar janelas",
        windowMaximizeCaption: "O botão verde maximiza sem criar outro Espaço.",
        windowMaximizeActiveNow: "Ativo no botão verde",
        windowMaximizeNeedsAccessibility: "Precisa de Acessibilidade para funcionar.",
        keyDebounceName: "Debounce",
        keyDebounceEnable: "Filtrar teclas duplicadas",
        keyDebounceCaption: "Filtra toques duplicados muito rápidos.",
        keyDebounceActiveNow: "Filtro ativo",
        keyDebounceGlobalWindow: "Janela global",
        keyDebouncePerKeySection: "Teclas específicas",
        keyDebouncePerKeyCaption: "Valores por tecla substituem a janela global. Use 0 ms para não filtrar uma tecla.",
        keyDebounceKeyLabel: "Tecla",
        keyDebounceWindowLabel: "Janela",
        keyDebounceAddKey: "Adicionar tecla",
        keyDebounceNoOverrides: "Nenhuma tecla específica configurada.",
        keyDebounceRemoveKey: "Remover tecla",
        cleaningPanelCaption: "Bloqueio do teclado para higienização segura.",
        cleaningOverlayTitle: "Teclado bloqueado para limpeza",
        cleaningOverlaySubtitle: "Pressione Esc 5 vezes consecutivas para desbloquear",
        cleaningOverlayUnlock: "Desbloquear teclado",
        cleaningOverlayMouseHint: "Mouse e trackpad permanecem operacionais.",
        cleaningKeepScreenVisibleToggle: "Manter tela visível",
        cleaningKeepScreenVisibleCaption: "Exibe um indicador discreto no canto da tela sem escurecer a exibição.",
        cleaningStartNow: "Bloquear teclado",
        cleaningNeedsAxTitle: "Permissão de Acessibilidade necessária",
        cleaningNeedsAxBody: "Para bloquear a entrada do teclado, conceda acesso em Ajustes do Sistema > Privacidade e Segurança > Acessibilidade.",

        tabSupport: "Apoiar",
        shortcutsPageCaption: "Configure os atalhos globais de teclado atribuídos aos módulos do Hexa.",
        shortcutsPageTitle: "Atalhos de teclado",
        settingsSearchPlaceholder: "Buscar ajustes",
        donateHeading: "Apoio ao desenvolvimento",
        donateMessage: "O Hexa é um projeto independente e de código aberto. Caso deseje apoiar a continuidade do utilitário, você pode contribuir via Buy Me a Coffee.",
        donateButton: "Apoiar no Buy Me a Coffee",
        donateThanks: "Agradecemos pelo apoio ao projeto.",
        supportIntroTitle: "Apoio ao desenvolvimento",
        supportIntroMessage: "Caso deseje contribuir financeiramente com o projeto, utilize o Buy Me a Coffee.",
        supportIntroStarButton: "Acessar repositório no GitHub",
        supportIntroStarMessage: "Código aberto no GitHub. Deixe uma estrela para apoiar o projeto.",
        supportIntroCoffeeButton: "Apoiar no Buy Me a Coffee",
        supportIntroLaterButton: "Agora não",
        supportIntroDoneButton: "Concluir",
        discordIntroTitle: "A comunidade do Hexa no Discord está começando",
        discordIntroMessage: "A comunidade do Hexa é nova e ainda está em desenvolvimento. Entre desde o começo para conhecer outros usuários e ajudar a construir um espaço acolhedor em torno do app.",
        discordIntroJoinButton: "Entrar na comunidade no Discord",
        communityIntroTitle: "Vem ver antes de todo mundo",
        communityIntroMessage: "Quem já me seguia no X viu várias novidades desta atualização antes de todo mundo. Lá eu posto prévias do que vem depois e mostro como funciona, para você já saber o básico antes mesmo da atualização sair. Segue lá e veja o que vem depois!",
        communityIntroFollowButton: "Seguir @hexa no X",
        showMenuBarIcon: "Exibir ícone na barra de menus",
        menuBarIconStillHiddenTitle: "Ícone não visível na barra de menus",
        menuBarIconStillHiddenBody: "O item foi registrado, mas o macOS não reservou espaço visível na barra de menus. Reduza os itens ativos na barra para liberar espaço.",
        menuBarIconManagerHintFormat: "%@ está ativo e pode estar gerenciando o item na seção oculta. Configure %@ para exibir o Hexa de forma permanente.",
        menuBarIconDisallowedBody: "O macOS restringiu a exibição do Hexa na barra de menus. Em Ajustes do Sistema > Central de Controle, autorize a exibição do Hexa.",
        shortcutRecording: "Pressione o novo atalho",
        shortcutReset: "Redefinir",
        shortcutNone: "Nenhum",
        shortcutClear: "Remover atalho",
        shortcutInvalid: "Use pelo menos Control, Option ou Command junto com uma tecla.",
        shortcutPressKeys: "Pressione",
        shortcutEscapeHint: "Esc cancela.",
        shortcutDeleteHint: "Delete remove.",
        shortcutNotCaptured: "Nada foi capturado. O macOS ou outro app já usa essa combinação. Tente outra.",
        shortcutConflictFormat: "Este atalho já está em uso por %@.",
        shortcutTakeOverOffer: "O macOS usa %@ em um atalho próprio.",
        shortcutTakeOverAction: "Assumir enquanto o Hexa estiver aberto",
        shortcutTakeOverCaption: "O macOS recupera a tecla quando você sai do Hexa ou desliga este recurso. Se o Hexa fechar de outro jeito, a tecla volta quando você abrir o Hexa de novo.",
        shortcutTakeOverDismiss: "Não assumir",
        shortcutUnavailable: "O macOS recusou este atalho. Escolha outro.",
        switcherUsageHintFormat: "Segure %@ para navegar; solte para ativar a janela. Shift ou ← volta; W fecha a janela; Q encerra o app; Esc cancela.",
        musicBlockSection: "Teclas de mídia",
        musicBlockTitle: "Impedir que o Música abra sozinho",
        musicBlockCaption: "Bloqueia a abertura do app de música após detectar uma tecla de mídia. Requer acesso à Acessibilidade. Comandos de fones sem uma tecla detectada são preservados.",
        musicBlockUnavailable: "Esta proteção está indisponível agora. Desligue e ligue a opção para tentar novamente.",
        musicBlockReplacementLabel: "Abrir no lugar",
        musicBlockReplacementNone: "Nenhum",
        musicBlockReplacementBlocked: "O Música e o iTunes são os apps bloqueados, então não podem abrir no lugar. Escolha outro app.",
        musicBlockChooseApp: "Escolher app…",
        musicBlockPlayReplacement: "Reproduzir após abrir o app substituto",
        cleanerName: "Limpeza",
        cleanerIntroTitle: "Limpe o lixo do Mac",
        cleanerIntroCaption: "Procura restos de apps desinstalados, caches, registros e a Lixeira. Você revisa tudo antes e os itens removidos vão para a Lixeira.",
        cleanerScan: "Verificar",
        cleanerScanning: "Verificando…",
        cleanerCleaning: "Limpando…",
        cleanerCatLeftovers: "Restos de apps desinstalados",
        cleanerCatLoginItems: "Itens de início órfãos",
        cleanerCatCaches: "Caches",
        cleanerCatLogs: "Registros",
        cleanerCatDeveloper: "Lixo de desenvolvimento",
        cleanerCatTrash: "Lixeira",
        cleanerLeftoversNote: "Encontrados por análise e começam desmarcados. Confira o caminho antes de marcar.",
        cleanerLoginItemsNote: "A entrada em Itens de Início some depois de reiniciar o Mac.",
        cleanerTrashNote: "Esvaziar a Lixeira é permanente.",
        cleanerTrashConfirmTitle: "Esvaziar a Lixeira?",
        cleanerTrashConfirmMessage: "O que estava na Lixeira na varredura será apagado de vez e não poderá ser recuperado. O que entrou na Lixeira depois fica lá.",
        cleanerTrashConfirmButton: "Limpar e esvaziar",
        cleanerCatDeviceBackups: "Backups de iPhone",
        cleanerDeviceBackupsCaption: "Backups antigos de iPhone e iPad ocupam boa parte do que o macOS chama de Outros. Remova só os que você não precisa mais; um novo backup é feito quando o aparelho for conectado de novo.",
        cleanerCatPackageCaches: "Caches de pacotes",
        cleanerPackageCachesCaption: "Pacotes baixados por npm, Gradle, Dart, uv e Puppeteer, buscados de novo quando necessários. Vão para a Lixeira, e o próximo build ou instalação precisa baixá-los outra vez; builds offline podem falhar. Nada vem selecionado.",
        cleanerCatCodingConversations: "Conversas antigas do Claude Code",
        cleanerCodingConversationsCaptionFormat: "Conversas do Claude Code sem atividade há mais de %d dias. Cada uma vai para a Lixeira junto com a pasta de arquivos auxiliares.",
        cleanerCodingConversationAgeLabel: "Listar conversas",
        cleanerCodingConversationsRisk: "A conversa não volta ao histórico da ferramenta sem restaurar da Lixeira.",
        cleanerCatScreenshots: "Capturas de tela esquecidas",
        cleanerScreenshotsCaptionFormat: "Capturas de tela que você não abre há %d dias e que ainda têm o nome e a pasta que o macOS deu. As que você renomeou ou moveu nunca aparecem aqui.",
        cleanerScreenshotsSettingCaption: "A varredura lista, desmarcadas e com o tamanho total, as capturas de tela que você não abre há esse tempo.",
        cleanerScreenshotsAfterFormat: "Após %d dias",
        cleanerNothingFound: "Nada para limpar. Seu Mac está em ordem.",
        cleanerClean: "Limpar",
        cleanerDoneNote: "Os itens foram para a Lixeira e podem ser recuperados de lá.",
        cleanerAgain: "Verificar de novo",
        cleanerRevealInFinder: "Mostrar no Finder",
        cleanerPanelCaption: "Restos de apps, caches e logs",
        cleanerSafeSection: "Limpeza segura",
        cleanerOptionalSection: "Opcional, revise antes",
        cleanerCatOtherCaches: "Outros caches",
        cleanerCachesCaption: "Arquivos temporários que os apps refazem sozinhos.",
        cleanerLogsCaption: "Registros antigos de diagnóstico.",
        cleanerDeveloperCaption: "Restos de compilações e simuladores do Xcode.",
        cleanerLoginItemsCaption: "Entradas de início deixadas por apps que não existem mais.",
        cleanerLeftoversCaption: "Arquivos deixados por apps que você desinstalou.",
        cleanerOtherCachesCaption: "Seguro apagar, nada quebra. Apps podem abrir mais devagar na primeira vez e conteúdo baixado, como músicas offline, baixa de novo.",
        cleanerCatBrowserCaches: "Caches de navegadores",
        cleanerBrowserCachesCaption: "Arquivos temporários e dados baixados que os navegadores refazem sozinhos.",
        cleanerCatBrowserSiteData: "Cookies e dados de sites",
        cleanerBrowserSiteDataCaption: "Dados locais de sites e sessões ativas. Você precisará fazer login novamente nos sites.",
        cleanerBrowserAccessPendingReason: "O acesso a perfis de navegadores requer permissão de Acesso Total ao Disco.",
        cleanerSkippedBrowsersFormat: "%@ está em uso e foi pulado.",
        cleanerNotificationSkippedBrowsersFormat: "Navegadores em uso foram pulados.",
        cleanerCleanSizeFormat: "Limpar %@",
        cleanerScheduleTitle: "Limpeza automática",
        cleanerScheduleOff: "Desativada",
        cleanerScheduleDaily: "Diária",
        cleanerScheduleWeekly: "Semanal",
        cleanerScheduleCaption: "Limpa sozinha só a parte segura no horário escolhido e manda tudo para a Lixeira.",
        cleanerScheduleLastFormat: "A última limpeza automática enviou %@ para a Lixeira.",
        cleanerAutoNotificationFormat: "%@ enviados para a Lixeira.",
        cleanerScheduleNextFormat: "Próxima limpeza %@.",
        cleanerScheduleRanFormat: "Última limpeza automática %@.",
        cleanerSchedulePostponed: "Adiada: há uma revisão manual aberta na Limpeza. Conclua ou cancele para a limpeza automática rodar hoje.",
        cleanerScheduleNotifyToggle: "Avisar quando terminar",
        cleanerAbortAll: "Abortar tudo",
        cleanerAutoRunning: "Limpeza automática em andamento",
        cleanerAutoInterrupted: "A limpeza automática foi interrompida antes de terminar.",
        cleanerNotifDenied: "As notificações do Hexa estão desativadas no sistema.",
        cleanerNotifOpenSettings: "Abrir Ajustes de Notificações…",
        launchAtLoginNeedsApplications: "O app está rodando de um lugar que não permite abrir no login. Arraste o Hexa para a pasta Aplicativos, abra de lá e ligue de novo.",
        launchAtLoginNeedsApproval: "O item de login está registrado, mas o macOS ainda precisa da sua aprovação. Nos Ajustes do Sistema, permita que o Hexa abra no login e funcione em segundo plano.",
        ocrRemoveLineBreaksToggle: "Remover quebras de linha",
        ocrRemoveLineBreaksCaption: "Remove as quebras de linha para que o texto copiado seja colado como um único parágrafo.",
        ocrQRToggle: "Ler QR codes",
        ocrQRCaption: "Se a área tiver um QR code, o conteúdo dele aparece para copiar ou abrir.",
        ocrQRCopied: "QR code copiado",
        ocrShowMenuOnShortcut: "Mostrar menu de OCR ao usar o atalho de teclado",
        qrResultTitle: "QR code",
        qrResultCopy: "Copiar",
        qrResultOpen: "Abrir link",
        highlightsTitle: "Novidades desta versão",
        highlightsTitleClipboardRedesign: "Novo visual da área de transferência",
        highlightsTitleWindowLayout: "Organização de janelas",
        highlightsTitleQuitProtection: "Proteção de ⌘Q e ⌘W",
        highlightsTitleRecorderBlur: "Desfoque no gravador de tela",
        highlightsCaptionDockPreview: "O Dock Preview agora funciona com a ampliação do Dock ligada",
        highlightsCaptionScreenshot: "A captura de tela ganhou uma lupa de pixels e leitura de QR codes",
        highlightsCaptionSnippetLibrary: "Um menu de snippets com busca digita qualquer snippet direto no cursor",
        highlightsCaptionCapturePalette: "Um único atalho agora abre uma paleta flutuante para capturas, gravações, texto na tela e cores com ajustes por perto.",
        highlightsCaptionClipboardRedesign: "O histórico agora abre como uma paleta compacta, com linhas limpas e prévia sob demanda para ler ou editar o item completo.",
        highlightsCaptionWindowLayout: "Use o anel direcional com atalho e ponteiro para posicionar janelas, ou arraste até as bordas da tela para encaixar com margens personalizadas.",
        highlightsCaptionQuitProtection: "Evite fechar aplicativos ou janelas por engano exigindo segurar a tecla, tocar duas vezes ou usar um atalho extra, ajustável por aplicativo.",
        highlightsCaptionRecorderBlur: "Oculte dados confidenciais, senhas e informações privadas em qualquer trecho do seu vídeo gravado antes de salvar ou exportar.",
        highlightsConfigure: "Configurar",
        highlightsTry: "Experimentar",
        highlightsSeeAll: "Ver todas as mudanças",
        switcherCurrentSpaceOnly: "Mostrar só a Mesa atual",
        switcherCurrentSpaceOnlyCaption: "Mostra no alternador apenas as janelas da Mesa em que você está. Escolher uma janela nunca leva você para outra Mesa.",
        mixerSoundEffectsOutputTitle: "Sons do sistema",
        mixerSoundEffectsOutputTooltip: "Escolher onde alertas e efeitos sonoros tocam",
        monitorOpenActivityMonitor: "Abrir o Monitor de Atividade",
        dockClickHide: "Clicar no Dock oculta o app",
        dockClickHideCaption: "O app ativo é ocultado ao clicar no ícone dele no Dock. Clique de novo para trazê-lo de volta.",
        monitorMemoryMetricLabel: "Medir memória como",
        memoryMetricUsed: "Memória usada",
        memoryMetricApp: "Memória de apps",
        keepAwakeRightClickToggle: "Clique com o botão direito no ícone da barra de menus para alternar “Manter acordado”",
        keepAwakeRightClickToggleCaption: "Substitui o menu de contexto do clique com o botão direito.",
        urlCleanerRulesTitle: "Regras de limpeza",
        urlCleanerRulesCaption: "Um site anexa estes parâmetros aos próprios links de compartilhamento para rastrear de onde o link veio. Ligado, o nome é removido ao limpar um link; desligado, ele permanece. Os nomes que você adicionar podem ser excluídos.",
        urlCleanerRulesCoverageCaption: "A lista cobre os diferentes caminhos de compartilhamento de um site (a página, o app, uma sala ao vivo), por isso é longa; um link real costuma carregar apenas dois a quatro deles.",
        urlCleanerRulesAllSites: "Todos os sites",
        urlCleanerRulesCountSingular: "1 parâmetro",
        urlCleanerRulesCountPluralFormat: "%d parâmetros",
        urlCleanerRulesAddSite: "Adicionar site",
        urlCleanerRulesParameterPlaceholder: "Nome do parâmetro",
        urlCleanerRulesMatchCaption: "Escreva o nome à esquerda do = , como utm_source. Um nome que corresponde tira aquele parâmetro do link e deixa o resto como está.",
        urlCleanerRulesAddButton: "Adicionar",
        urlCleanerRulesRemoveButton: "Excluir nome",
        urlCleanerRulesRemoveSiteButton: "Desativar todas as regras deste site",
        urlCleanerRemovedFormat: "Removidos %@",
        switcherSearchPin: "Fixar busca com S",
        switcherSearchPinCaption: "S inicia uma busca e fixa o alternador aberto, assim digitar não produz mais caracteres especiais quando o atalho usa ⌥, e uma busca que comece com Q ou W não fecha a janela nem encerra o app por engano.",
        invertVerticalScroll: "Inverter rolagem vertical",
        invertHorizontalScroll: "Inverter rolagem horizontal",
        scrollHorizontalName: "Rolar na horizontal segurando uma tecla",
        scrollHorizontalModifierLabel: "Tecla modificadora",
        scrollHorizontalCommandKey: "Command",
        scrollHorizontalCaption: "Mantenha apenas a tecla escolhida pressionada para rolar a roda vertical do mouse na horizontal. Outras combinações de teclas não são alteradas.",
        switcherShowShortcutHints: "Mostrar dicas de atalhos",
        switcherShowShortcutHintsCaption: "Exibe os atalhos de apps e janelas abaixo dos ícones.",
        uninstallerHomebrewPackageFormat: "%@ também será removido do Homebrew.",
        focusFollowsMouseName: "Foco ao passar o mouse",
        focusFollowsMouseCaption: "Coloca em foco a janela sob o ponteiro.",
        focusFollowsMouseDelay: "Atraso ao passar o mouse",
        focusFollowsMouseRaise: "Trazer a janela para frente",
        focusFollowsMouseWaitForStop: "Esperar o ponteiro parar",
        switcherMinimizedPlacementLabel: "Janelas minimizadas",
        switcherTreatHiddenAppsLikeMinimized: "Tratar apps ocultos como janelas minimizadas",
        switcherMinimizedPlacementNormal: "Ordem normal",
        switcherMinimizedPlacementEnd: "Colocar no final",
        switcherMinimizedPlacementHidden: "Ocultar",
        switcherShowFullscreenWindows: "Mostrar janelas em tela cheia",
        switcherScreenPlacementLabel: "Mostrar em",
        switcherScreenPlacementPointer: "Tela com o ponteiro",
        switcherScreenPlacementMenuBar: "Tela com a barra de menus",
        switcherScreenPlacementActiveWindow: "Tela com a janela ativa",
        switcherScreenPlacementCaption: "Em qual tela o alternador abre quando há mais de uma conectada.",
        switcherCurrentDisplayOnly: "Mostrar só a tela atual",
        switcherCurrentDisplayOnlyCaption: "Mostra apenas as janelas da tela sob o cursor. Se essa tela não tiver janelas, o alternador não abre.",
        smoothScrollResponseLabel: "Resposta",
        smoothScrollCoastLabel: "Inércia",
        mouseAccelerationName: "Desativar aceleração do mouse",
        mouseAccelerationCaption: "Remove a aceleração do cursor para os mouses conectados. A configuração anterior volta ao desligar esta opção ou sair do Hexa.",
        linearScrollName: "Rolagem linear",
        linearScrollCaption: "Cada passo da rodinha do mouse rola a mesma distância, não importa a velocidade do giro. O trackpad não muda.",
        linearScrollLinesLabel: "Linhas por passo",
        spacesOrderName: "Manter os Espaços em ordem fixa",
        spacesOrderCaption: "Impede que o macOS reorganize os Espaços pelo uso mais recente, para que fiquem na ordem que você definiu. A configuração anterior volta ao desligar esta opção. O Dock pode reiniciar uma vez para aplicar a mudança.",

        spaceInventoryVolumeTotal: "Total do volume",
        spaceInventoryVolumeFree: "Livre",
        spaceInventoryVolumeUsed: "Usado",
        spaceInventoryVolumeUnavailable: "Não foi possível ler a capacidade do volume. Nada foi assumido como zero.",
        spaceInventoryLowSpace: "Menos de 10% livres. As maiores pastas aparecem destacadas no ranking abaixo.",
        spaceInventoryRankingTitle: "Maiores pastas",
        spaceInventorySummaryTitle: "Dados do sistema (estimativa do Hexa)",
        spaceInventorySummaryPartial: "Cobertura parcial: o Hexa soma só o primeiro nível de ~/Library e nunca calcula este valor pelo que sobra no volume.",
        spaceInventoryDeniedFormat: "%@: %@",
        spaceInventoryDeniedAccess: "acesso recusado pelo macOS",
        spaceInventoryDeniedUnavailable: "pasta não pôde ser lida",
        spaceInventoryPartialMark: "parcial",
        spaceInventoryEmpty: "Nenhuma pasta elegível foi encontrada para medir.",
        spaceInventoryCancelled: "Medição cancelada. O mapa mostra o que já foi medido.",

        largeFilesTitle: "Arquivos grandes e antigos",
        largeFilesOpen: "Abrir lista",
        largeFilesCaption: "Lista os arquivos do seu Mac por tamanho e idade. Nada vem marcado: só vai para a Lixeira o que você marcar e confirmar.",
        largeFilesAgeLabel: "Mais antigos que",
        largeFilesSizeLabel: "Maiores que",
        largeFilesSettingsCaption: "A busca usa os dois limites juntos. A próxima busca já respeita o que está salvo aqui.",
        largeFilesBackToResults: "Voltar aos resultados",
        largeFilesBackToStart: "Voltar ao início",
        largeFilesThresholdsFormat: "%d dias e %@ ou mais",
        largeFilesSearch: "Buscar agora",
        largeFilesSearching: "Procurando na sua pasta pessoal. Você pode cancelar e ficar com o que já foi encontrado.",
        largeFilesEmpty: "Nenhum arquivo atende aos dois limites agora.",
        largeFilesResultTitle: "Encontrados",
        largeFilesGroupFormat: "%d arquivos, %@ no total",
        largeFilesCancelled: "Busca cancelada. A lista mostra o que já foi encontrado.",
        largeFilesQuickLook: "Visualizar",
        largeFilesReportTitle: "Resultado da remoção",
        largeFilesReportSummaryFormat: "%d movidos, %d não movidos",
        largeFilesMovedFormat: "%@: movido para a Lixeira",
        largeFilesRefusedFormat: "%@: não é mais o mesmo arquivo, nada foi movido",
        largeFilesFailedFormat: "%@: não foi possível mover, o arquivo continua no lugar",
        largeFilesRemove: "Mover para a Lixeira",
        largeFilesConfirmTitle: "Mover para a Lixeira?",
        largeFilesConfirmMessageFormat: "%d arquivos, %@ no total. Os itens vão para a Lixeira do macOS e podem ser recuperados até você esvaziá-la.",
        largeFilesSelectedFormat: "%d de %d arquivos, %@ marcados",
        spaceInventoryMeasuredTotal: "Total medido"
    )
}

// MARK: - English (US)

extension Strings {
    static let enUS = Strings(
        statusIdleTooltip: "Hexa: normal sleep",
        statusActiveUntil: "Hexa: awake until",
        statusActiveIndefinite: "Hexa: awake indefinitely",
        menuEnableAwake: "Enable keep awake",
        menuDisableAwake: "Disable keep awake",
        menuActivateFor: "Activate for…",
        menuSettings: "Settings…",
        menuAbout: "About Hexa",
        menuQuit: "Quit Hexa",
        menuHide: "Hide Hexa",
        menuHideOthers: "Hide Others",
        menuShowAll: "Show All",
        menuEdit: "Edit",
        menuUndo: "Undo",
        menuRedo: "Redo",
        actionClear: "Clear",
        actionRemove: "Remove",
        actionBack: "Back",
        actionSearch: "Search",
        actionMute: "Mute",
        actionUnmute: "Unmute",
        actionPlay: "Play",
        actionPause: "Pause",
        menuCut: "Cut",
        menuCopy: "Copy",
        menuPaste: "Paste",
        menuSelectAll: "Select All",
        menuWindow: "Window",
        menuMinimize: "Minimize",
        menuZoom: "Zoom",
        menuClose: "Close",

        minutes15: "15 minutes",
        minutes30: "30 minutes",
        hour1: "1 hour",
        hours2: "2 hours",
        hours4: "4 hours",
        hours8: "8 hours",
        indefinitely: "Indefinitely",
        indefinite: "Indefinite",

        panelSettings: "Settings",
        panelQuit: "Quit",
        panelHotkeyHint: "Shortcut toggles",

        keepAwakeTitle: "Keep awake",
        keepAwakeEndsIn: "Ends in",
        keepAwakeUntilDisabled: "Active until you turn it off",
        keepAwakeNormalRules: "The Mac follows its normal energy rules",
        keepAwakeUntilLabel: "Until",
        keepAwakeUntilStart: "Start",
        keepAwakeOptions: "Options",
        notchMixerOptions: "Options",
        ocrTextRecognitionSection: "Text recognition",
        mediaOutputParamsSection: "Output parameters",
        cleanerAutomationSection: "Automation",
        cleanerAutoOrganizeSection: "Automatic organization",
        keepAwakeMouseJiggle: "Move pointer slightly",
        keepAwakeMouseJiggleCaption: "During a session, moves the pointer a little at the chosen interval.",
        keepAwakeMouseJiggleInterval: "Interval",
        keepAwakeBatteryLimit: "Battery limit",
        keepAwakeBatteryLimitNever: "Never",
        keepAwakeBatteryLimitCaption: "On battery, at or below this level, the session ends and automations do not start.",
        durationLabel: "Duration",
        clamshellTitle: "Keep going with the lid closed",
        clamshellOnCaption: "Sleep fully disabled. Mind the power",
        clamshellNeedsSession: "Applied whenever “Keep awake” is active",
        clamshellReady: "Ready. Toggles without a password",
        clamshellNeedsPassword: "Will ask for the administrator password once",

        systemSection: "System",
        temperatures: "Temperatures",
        cpuLabel: "CPU",
        gpuLabel: "GPU",
        batteryLabel: "Battery",
        usageSection: "Hardware usage",
        memorySection: "Memory",
        memoryPressure: "Pressure",
        memorySwapUsed: "Swap used",
        memoryCompressed: "Compressed",
        memoryCachedFiles: "Cached files",
        pressureNormal: "Normal",
        pressureWarning: "Caution",
        pressureCritical: "Critical",
        monitorUnavailable: "Sensors unavailable on this Mac",
        energyAppsTitle: "Apps using significant energy",
        energyAppsIdle: "No significant energy use",

        notifySessionEndedTitle: "Session ended",
        notifySessionEndedBody: "Time is up. The Mac will sleep normally again.",
        notifyBatteryTitle: "Hexa disabled",
        notifyBatteryBody: "Low battery. Normal sleep was restored to protect the charge.",
        adminPromptClamshellOn: "Hexa needs your password to keep the Mac going with the lid closed.",
        adminPromptClamshellOff: "Hexa needs your password to restore the Mac’s normal sleep.",
        adminPromptRecover: "Hexa quit while the Mac’s sleep was disabled. Enter the password to restore normal sleep.",
        sleepRestorePending: "The last session left the Mac’s sleep disabled. Restore it so the Mac can sleep again.",
        sleepRestoreAction: "Restore sleep",
        adminPromptSudoersInstall: "Hexa will create a restricted rule (pmset disablesleep only) to toggle closed-lid mode without asking for a password.",
        adminPromptSudoersRemove: "Hexa will remove the password-free closed-lid rule.",

        settingsTitle: "Hexa Settings",
        tabGeneral: "General",
        tabEnergy: "Energy",
        tabMouse: "Mouse & Trackpad",
        tabSwitcher: "Switcher",
        tabAdvanced: "Advanced",
        tabAbout: "About",
        tabReleaseNotes: "What’s New",
        releaseNotesOnUpdateToggle: "Show what’s new after updating",
        minimalWindowPreviews: "Minimal previews",
        minimalWindowPreviewsCaption: "Hide titles, buttons and decorative details in Dock and switcher previews. The selection stays visible.",
        settingsGroupFeatures: "Resources",
        advancedResetSection: "Permissions",
        advancedResetDescription: "Removes every permission you granted Hexa (Accessibility, Screen Recording, Full Disk Access and others), the login item and the closed-lid rule. Useful to start fresh or before uninstalling. The app stays installed.",
        advancedClearButton: "Clear all permissions",
        advancedCleared: "Permissions cleared.",
        advancedClearFailed: "Some permissions or the closed-lid rule could not be removed. Try again and allow the password request if it appears.",
        advancedClearConfirmTitle: "Clear all permissions?",
        advancedClearConfirmBody: "Features that need permissions will stop working until you grant them again. Your settings are kept.",
        advancedUninstallSection: "Uninstall",
        advancedUninstallDescription: "Gives back to macOS everything Hexa changed, erases its settings, moves its caches, its data and the app itself to the Trash, and quits Hexa.",
        advancedUninstallRecommended: "To remove Hexa completely, including system integrations, data and settings, use this built-in uninstall.",
        advancedUninstallButton: "Uninstall Hexa completely",
        advancedUninstallConfirmTitle: "Uninstall Hexa?",
        advancedUninstallConfirmBody: "Hexa will hand the fans back to the system and remove their helper, remove the login item, restore sleep, remove the password-free closed-lid rule and give back the macOS shortcuts it took over. Then it erases its settings, moves its caches, its data and the app itself to the Trash, and quits. macOS may ask for your password.",
        advancedUninstallFailedTitle: "Uninstall stopped",
        advancedUninstallFailedBody: "Hexa could not give sleep, the password-free closed-lid rule or the fans back to the system. The app was not removed. Try again and allow the password request if it appears.",
        advancedUninstallTrashFailedBody: "Hexa gave back everything it changed and erases its settings when it quits, but it could not move itself to the Trash. Drag the app to the Trash.",

        launchAtLogin: "Launch at login",
        languageLabel: "Language",
        menuBarSection: "Menu bar",
        showCountdown: "Show remaining time next to the icon",
        globalHotkeySection: "Global shortcut",
        hotkeyToggle: "Enable shortcut for “Keep awake”",
        hotkeyCaption: "Works in any app, no extra permissions.",

        sessionSection: "Session",
        defaultDurationLabel: "Default duration",
        keepAwakeAutoStart: "Keep Awake when Hexa opens",
        keepAwakeAutoStartCaption: "Starts a session with the default duration.",
        clamshellSection: "Closed lid",
        configuring: "Configuring…",
        sudoersFailed: "Couldn’t turn on closed-lid mode. Try again.",
        clamshellExplanation: "“Keep going with the lid closed” fully disables sleep while “Keep awake” is active and is reverted automatically when the session ends or the app quits. Prefer using it plugged in.",

        scrollSection: "Scrolling",
        invertMouseScroll: "Invert mouse scrolling",
        invertMouseScrollCaption: "Reverses the mouse wheel direction.",
        scrollTrackpadNote: "The trackpad is untouched: it keeps macOS natural scrolling.",
        scrollActiveNow: "Inverting mouse scrolling right now",
        mouseNavigationActiveNow: "Side buttons active right now",
        smoothScrollName: "Smooth scrolling",
        smoothScrollCaption: "Turns each mouse wheel step into a short, gentle glide. The trackpad is not affected.",
        smoothScrollStepLabel: "Scrolling speed",
        mouseNavigationSection: "Navigation",
        mouseNavigationEnable: "Use side buttons for Back and Forward",
        mouseNavigationCaption: "Turns the mouse Back and Forward buttons into navigation commands in Finder, browsers and compatible apps.",
        middleClickSection: "Trackpad middle click",
        middleClickEnable: "Three-finger click acts as middle click",
        middleClickEnableCaption: "Pressing the trackpad with three fingers works like a mouse wheel click: open links in a new tab, close tabs and everything else the middle button does.",
        middleClickDragConflict: "macOS three-finger drag is turned on and uses three fingers, so click with four fingers for the middle click. To use three, turn three-finger drag off in System Settings under Accessibility, Pointer Control, Trackpad Options.",
        middleClickNoTrackpad: "Can’t read trackpad touches. Connect a supported trackpad.",
        middleClickTapPicker: "A light tap also clicks",
        middleClickTapOff: "Off",
        middleClickTapThreeFingers: "3 fingers",
        middleClickTapFourFingers: "4 fingers",
        middleClickTapCaption: "A light tap with that many fingers, without pressing, also fires the middle click. Sliding never counts. If the macOS three-finger tap is assigned to Look Up, turn it off so both do not fire together.",
        quickToolsTab: "Quick panel",
        quickToolShortcutToggle: "Global shortcut",
        ocrName: "Copy text from screen",
        ocrCaption: "Select an area of the screen and the recognized text is copied, ready to paste.",
        ocrCopied: "Text copied",
        ocrNoText: "No text found",
        ocrClipboardChanged: "Not copied: the clipboard changed during recognition",
        colorPickerName: "Color picker",
        colorPickerCaption: "Grab the color of any pixel on screen and copy it in your favorite format.",
        colorPickerFormatLabel: "Copied format",
        colorPickerBareHexToggle: "Copy without the # prefix",
        colorPickerPickNow: "Pick color",
        micMuteName: "Mute microphone",
        micUnmuteName: "Unmute microphone",
        micMuteCaption: "Cuts the Mac’s microphone with a click or shortcut, across every app.",
        micMutedHUD: "Microphone muted",
        micUnmutedHUD: "Mute off",
        micMutePartialHUD: "Some microphones could not be muted",
        micUnmutePartialHUD: "Some microphones are still muted",
        micMuteMenuBarToggle: "Show in the menu bar while muted",
        micMuteMenuBarCaption: "A red crossed-out mic appears beside the app’s icon in the menu bar while this feature mutes it.",
        launcherName: "Quick panel",
        launcherCaption: "A floating panel with your favorite tools, summoned by a shortcut from anywhere.",
        launcherOpenNow: "Open quick panel",
        launcherEditHint: "Use the tune button to choose, hide and drag the tools around.",
        launcherEmptyState: "All tools are hidden. Use the tune button to add them back.",
        launcherAddSection: "Add back",
        launcherKeysHint: "Arrows navigate, Enter opens, 1 to 9 open directly",

        switcherSection: "Window switcher",
        switcherEnable: "Use the Hexa switcher",
        switcherEnableCaption: "Switch between apps and windows, including minimized windows and multiple windows from the same app.",
        switcherUsageHint: "Hold the shortcut to navigate; release to activate the window. Shift or ← goes back; W closes the window; Q quits the app; Esc cancels.",
        switcherNoWindows: "No open windows",
        switcherIconRowMode: "Show %@ with large icons",
        switcherIconRowModeCaption: "Shows one icon per app with that app’s window previews above it.",
        switcherSimpleModeCaption: "Shows app icons and window titles, without previews or screen capture by the switcher.",
        switcherShortcutHintApps: "Apps",
        switcherShortcutHintWindows: "Windows",
        switcherWindowShortcutCaption: "Opens a switcher for the frontmost app’s windows. While the switcher is open, jumps between the selected app’s windows.",
        switcherTakeOverSystemShortcuts: "Replace macOS ⌘Tab and ⌘`",
        switcherTakeOverSystemShortcutsCaption: "Disables the matching macOS app and window shortcuts only while Hexa’s switcher is active. All running apps stay reachable.",
        switcherAppearanceDelay: "Appearance delay",
        switcherAppearanceDelayCaption: "How long the shortcut must be held before the switcher appears.",
        switcherInstantSelection: "Instant selection",
        switcherInstantSelectionCaption: "Moves the highlight and scroll position immediately as you browse apps and windows.",
        switcherMergeTabs: "Show one entry per app",
        switcherMergeTabsCaption: "Collapses all of an app’s windows into one entry in the switcher, instead of one entry per window.",
        switcherWindowlessApps: "Apps with no open window",
        switcherWindowlessAppsCaption: "Chooses which running apps with no window at all show up in the switcher.",
        switcherWindowlessAppsOff: "Do not show",
        switcherWindowlessAppsFinder: "Finder only",
        switcherWindowlessAppsAll: "All apps",
        switcherNoOpenWindow: "No open window",
        switcherOtherDesktop: "Other desktop",
        dockPreviewName: "Dock Preview",
        dockPreviewEnable: "Preview windows from the Dock",
        dockPreviewEnableCaption: "Hover over an open app in the Dock to see its windows, then click the one you want.",
        dockPreviewCurrentSpaceOnlyCaption: "When off, shows windows from all desktops. Choosing a window on another desktop takes you there.",
        dockPreviewBackgroundOpacity: "Panel background",
        dockPreviewBackgroundOpacityCaption: "Turn it down to see more of what sits behind the panel.",
        dockPreviewOpenDelay: "Open delay",
        dockPreviewOpenDelayCaption: "How long the pointer has to rest on an icon before its panel opens.",
        dockPreviewQuitAppOnClose: "Quit the app with the × button",
        dockPreviewQuitAppOnCloseCaption: "In Dock Preview, × quits the whole app instead of closing only that window.",
        dockPreviewKeepDockVisible: "Keep Dock visible (experimental)",
        dockPreviewKeepDockVisibleCaption: "Pauses auto-hide while the preview is open and restores it when you leave. May resize windows. If the app is interrupted, reopen it to restore the Dock.",
        dockPreviewOrderByCreation: "Order windows by creation time",
        dockPreviewOrderByCreationCaption: "Show older windows first instead of the ones you used most recently.",
        dockClickMinimize: "Click the Dock icon to minimize",
        dockClickMinimizeCaption: "The active app’s windows minimize when you click its Dock icon. Click again to bring them back.",
        dockClickCycleWindows: "Click the Dock icon to cycle windows",
        dockClickCycleWindowsCaption: "Click an active app’s Dock icon to rotate through its windows, like ⌘`.",
        dockPreviewActiveNow: "Active in the Dock",
        dockPreviewDockUnavailable: "Could not read Dock items.",
        dockPreviewAutohideBeta: "Beta. You may run into some bugs.",
        dockPreviewOpenWindow: "Open window",
        dockPreviewCloseWindow: "Close window",
        dockPreviewMinimizeWindow: "Minimize window",
        dockPreviewRestoreWindow: "Restore window",
        dockPreviewPinPanel: "Pin preview",
        dockPreviewUnpinPanel: "Unpin preview",
        dockPreviewPinned: "Pinned",
        dockPreviewClosePanel: "Close preview",
        dockPreviewPreviousWindow: "Previous window",
        dockPreviewNextWindow: "Next window",

        cutPasteName: "Cut & paste",
        cutPasteEnable: "Cut & paste files in Finder",
        cutPasteEnableCaption: "Use ⌘X to cut and ⌘V to move files and folders in Finder.",
        cutPasteShowHUD: "Show floating panel",
        cutPasteShowHUDCaption: "Display a floating indicator with the cut files while Finder is active.",
        cutPasteHowTitle: "How to use",
        cutPasteStep1: "Select items in Finder and press ⌘X to cut them.",
        cutPasteStep2: "Open the destination folder and press ⌘V to move them there.",
        cutPasteTextNote: "In text fields (like when renaming), ⌘X and ⌘V keep working as usual.",
        cutPasteActiveNow: "Ready to cut in Finder",
        cutPasteAutomationNote: "The first time, macOS asks for permission to control Finder.",
        cutReadyTitle: "Cut",
        cutReadyHint: "in the destination folder to move",
        cutCancel: "Cancel cut",
        cutDoneTitle: "Moved!",
        cutMovedSingular: "1 item moved",
        cutMovedPluralFormat: "%d items moved",
        cutSomeFailed: "Some items couldn’t be moved",
        cutMovingTitle: "Moving…",
        cutMovingCountFormat: "%d of %d",

        autoQuitName: "Quit on close",
        autoQuitEnable: "Quit an app when its last window closes",
        autoQuitEnableCaption: "Closing an app’s last window also quits it.",
        autoQuitActiveNow: "Active now",
        autoQuitHowTitle: "How it works",
        autoQuitStep1: "Close an app’s last window (⌘W or the red button).",
        autoQuitStep2: "The app quits on its own. “Save changes?” dialogs still appear.",
        autoQuitPredictableNote: "Apps that normally run without a window are never quit.",
        autoQuitOngoingWorkNote: "Some apps close their last window while they keep working, such as a screen recorder once capture starts. Those are quit too, unless they are on the Exceptions list.",
        autoQuitExceptionsTitle: "Exceptions",
        autoQuitExceptionsCaption: "Apps on this list stay open even with no windows.",
        autoQuitExceptionsEmpty: "No exceptions",
        autoQuitAddApp: "Add app…",

        uninstallerName: "Uninstaller",
        uninstallerEnableCaption: "Removes an app together with the caches, preferences, logs and leftovers it leaves behind.",
        uninstallerStep1: "Drag an app onto Settings, or pick one from the list.",
        uninstallerStep2: "Review the files found and how much space they take.",
        uninstallerStep3: "Move what you want to the Trash. Nothing is deleted permanently.",
        uninstallerMenuItem: "Uninstall an app…",
        uninstallerDropTitle: "Drag an app here",
        uninstallerDropSubtitle: "or choose one to scan",
        uninstallerChoose: "Choose app…",
        uninstallerPickerTitle: "Choose app",
        uninstallerPickerSearch: "Search apps",
        uninstallerPickerEmpty: "No apps found",
        uninstallerEmptyNote: "Nothing is removed without your confirmation.",
        uninstallerFDANote: "Grant Full Disk Access for a more thorough scan.",
        uninstallerFDAGrant: "Grant access…",
        uninstallerFDAHint: "Turn Hexa on in the list. If it isn’t there, click + and pick Hexa from Applications. Access only applies after you reopen the app.",
        uninstallerFDARelaunch: "Relaunch now",
        uninstallerScanning: "Scanning files…",
        loadingMessage: "Loading…",
        uninstallerRemoving: "Moving to the Trash…",
        uninstallerFoundTitle: "found",
        uninstallerSelectedFormat: "%d of %d selected",
        uninstallerRemove: "Move to Trash",
        uninstallerCancel: "Cancel",
        uninstallerConfirmationExpired: "This confirmation is no longer valid. Review the current items and confirm again.",
        uninstallerQuitTitle: "Quit the app to remove it?",
        uninstallerQuitBodyFormat: "%@ is open. Hexa will ask it to quit before moving the app to the Trash. If there are unsaved changes, the app may ask you to save them.",
        uninstallerQuitAndRemove: "Quit and Remove",
        uninstallerForceQuitTitle: "The app did not quit",
        uninstallerForceQuitBodyFormat: "%@ is still open and may be waiting for you to save. Force quitting discards unsaved changes. To save first, cancel and go back to the app.",
        uninstallerForceQuitAndRemove: "Force Quit and Remove",
        uninstallerTerminalContinue: "I ran it in Terminal",
        uninstallerTerminalStillInstalled: "The app is still on disk. Finish the command in Terminal and try again.",
        uninstallerDoneTitle: "Done!",
        movedToTrashFormat: "%@ in the Trash, still taking up space until you empty it",
        freedPermanentlyFormat: "%@ freed",
        uninstallerSomeFailed: "Some items couldn’t be moved to the Trash.",
        uninstallerFailedNeedsFDA: "Sandboxed app data can only be moved with Full Disk Access. The administrator password does not stand in for it.",
        uninstallerFailedMoreFormat: "and %d more",
        uninstallerAnother: "Uninstall another",
        uninstallerCatApp: "Application",
        uninstallerCatSupport: "Support",
        uninstallerCatCaches: "Caches",
        uninstallerCatPreferences: "Preferences",
        uninstallerCatContainers: "Containers",
        uninstallerCatLogs: "Logs",
        uninstallerCatState: "Saved state",
        uninstallerCatOther: "Other",
        uninstallerHiddenHomeLegend: "may contain your own data and settings",
        uninstallerSystemExtensionNote: "This app installs a system extension. macOS asks you to confirm its removal in System Settings. The files you select still go to the Trash.",
        uninstallerLoginItemNote: "This app registers a login item. If it remains in System Settings after removal, turn it off there. The files you select still go to the Trash.",
        uninstallerAdminUnloadPrompt: "Hexa needs to unload a service of this app before moving it to the Trash.",
        spaceInventoryTitle: "Where the space is",
        spaceInventoryLegend: "Information only. Hexa measures these folders and removes nothing from here.",
        spaceInventoryModelsCaption: "Local AI models",
        spaceInventoryToolsCaption: "Coding tool data with an index (no removal)",
        spaceInventoryVMsCaption: "Virtual machine images",
        spaceInventorySimulatorsTitle: "Xcode simulators",
        spaceInventorySimulatorsScope: "all simulators, including unavailable ones",
        spaceInventorySimulatorNote: "To delete only the unavailable simulators, run this command in Terminal:",
        spaceInventorySimulatorWarning: "Permanent: the command does not use the Trash and cannot be undone.",
        spaceInventoryMeasure: "Calculate",
        uninstallerSelectionUnavailable: "Select an app that can be removed in Finder, or choose another from the list.",
        uninstallerRefusedSystemApp: "macOS apps are part of the system and cannot be removed.",
        uninstallerRefusedNestedApp: "This app lives inside another app bundle. Select the main app to remove it.",
        uninstallerRefusedSelfApp: "hexa is currently running and cannot uninstall itself.",
        uninstallerClearSelection: "Clear Selection",

        urlCleanerName: "Clean URL",
        urlCleanerEnable: "Clean URLs as you copy them",
        urlCleanerEnableCaption: "Removes tracking parameters from a link the moment it reaches the clipboard.",
        urlCleanerActiveNow: "Active now",
        urlCleanerManualTitle: "Clean now",
        urlCleanerInputPlaceholder: "Paste a URL",
        urlCleanerOutputPlaceholder: "The clean URL appears here",
        urlCleanerCleanButton: "Clean",
        urlCleanerPasteButton: "Paste",
        urlCleanerCopyButton: "Copy",
        urlCleanerClearButton: "Clear field",
        urlCleanerNoURL: "Paste a valid URL.",
        urlCleanerNoChange: "Nothing to clean.",
        urlCleanerCleaned: "URL cleaned.",
        urlCleanerCopied: "Copied.",
        urlCleanerLocalNote: "Local. No network.",

        homebrewTrustTitle: "Tap not trusted yet",
        homebrewTrustCaption: "Homebrew now asks for your confirmation before using third party taps. Trust %@ to continue.",
        homebrewTrustButton: "Trust and continue",
        homebrewGroupDependencies: "Group dependencies",
        homebrewUninstall: "Uninstall",
        homebrewAllPackages: "packages",
        homebrewOpenTerminal: "Open Terminal",
        homebrewCancelOperation: "Cancel",
        homebrewClearLog: "Clear log",
        homebrewConfirmUninstallTitle: "Uninstall with Homebrew?",
        homebrewConfirmUninstallBodyFormat: "Homebrew will uninstall %@. Configuration files may remain on the system.",
        homebrewTerminalFallback: "This operation needs Terminal to ask for the administrator password. Hexa does not capture passwords.",
        homebrewOperationUninstallFormat: "Uninstalling %@",
        homebrewOperationUpgradeAll: "Updating packages",
        homebrewOperationUninstalledFormat: "%@ uninstalled.",
        homebrewOperationUpgradedAll: "Packages updated.",
        homebrewOperationFailedFormat: "Could not finish %@.",
        homebrewOperationCancelled: "Operation cancelled.",
        homebrewOperationPreparing: "Preparing…",
        homebrewOperationDownloading: "Downloading files…",
        homebrewOperationUninstalling: "Removing files…",
        homebrewOperationUpgrading: "Updating files…",
        homebrewOperationFinalizing: "Finishing…",
        homebrewOperationRefreshing: "Refreshing list…",
        homebrewOperationTerminal: "Continue in Terminal.",
        homebrewOperationElapsedFormat: "%@ elapsed",
        homebrewOperationShowDetails: "Show details",
        homebrewOperationHideDetails: "Hide details",
        homebrewOperationTechnicalLog: "Technical details",
        homebrewOperationProgressUnknown: "Homebrew has not reported a percentage yet.",

        mediaName: "Media",
        mediaEnableCaption: "Compress videos, convert and process images, make GIFs and extract text locally.",
        mediaLocalNote: "Local. No network.",
        mediaToolVideo: "Video",
        mediaToolGIF: "GIF",
        mediaToolImage: "Image",
        mediaToolText: "Text",
        mediaSelectFile: "Choose file",
        mediaDropHint: "Drop a file here or click to choose one.",
        mediaOutput: "Output",
        mediaOutputAutomatic: "Automatic",
        mediaChooseOutput: "Destination",
        mediaStartVideo: "Compress video",
        mediaStartGIF: "Make GIF",
        mediaStartImage: "Process image",
        mediaStartConvertPDF: "Convert to PDF",
        mediaStartText: "Extract text",
        mediaCancel: "Cancel",
        mediaStartTime: "Start",
        mediaEndTime: "End",
        mediaQuality: "Quality",
        mediaCompressionLow: "High",
        mediaCompressionMedium: "Medium",
        mediaCompressionHigh: "Low",
        mediaCompressionLowDescription: "High fidelity, larger file",
        mediaCompressionMediumDescription: "Balance between fidelity and file size",
        mediaCompressionHighDescription: "Low fidelity, smaller file",
        mediaMaxSize: "Size",
        mediaSizingResolution: "Resolution",
        mediaSizingFileSize: "File size",
        mediaTargetSize: "Target size",
        mediaTargetSizeHint: "Resolution adapts to stay under the limit.",
        mediaErrorTargetTooSmall: "Target size too small for this clip. Trim it or raise the limit.",
        mediaErrorGIFTooLongFormat: "A GIF can be up to %d seconds long",
        mediaMegabytesSuffix: " MB",
        mediaWidth: "Width",
        mediaFPS: "FPS",
        mediaKeepAudio: "Keep audio",
        mediaCodec: "Codec",
        mediaFormat: "Format",
        mediaStripMetadata: "Remove metadata",
        mediaLoopGIF: "Loop GIF",
        mediaOCRMode: "OCR",
        mediaOCRAccurate: "Accurate",
        mediaOCRFast: "Fast",
        mediaLanguageCorrection: "Language correction",
        mediaTextOutputNote: "Extracted text can be copied and saved as TXT.",
        mediaRunning: "Processing",
        mediaCompleted: "Done",
        mediaCancelled: "Cancelled.",
        mediaStatusNotice: "Status",
        mediaOpenInFinder: "Show",
        mediaCopyText: "Copy text",
        mediaRunAgain: "Run again",
        mediaEmptyText: "No text found.",
        mediaResultSavedFormat: "Saved as %@",
        mediaResultSizeFormat: "%@ to %@",
        mediaResultGrewCaption: "The converted file came out larger than the original.",
        mediaErrorNoFile: "Choose a file first.",
        mediaErrorNoVideo: "This file has no video track.",
        mediaErrorSameOutput: "Choose a destination different from the original file.",
        mediaErrorUnsupported: "Format not supported by macOS.",

        extraBrightnessName: "Extra brightness",
        extraBrightnessCaption: "Uses the display’s HDR headroom to go past the maximum brightness. Uses more battery and the Mac can run warm.",
        extraBrightnessUnsupported: "Available only on XDR displays, such as the ones on the 14 and 16 inch MacBook Pro.",
        shelfHotkeyLabel: "Shortcut",

        breakdownMeasuring: "Measuring…",

        mixerSection: "Volume mixer",
        mixerEmpty: "Apps that use audio show up here",
        mixerUnavailable: "Available on macOS 14.4 and later",
        mixerPermissionBody: "To adjust per-app volume, allow “Screen & System Audio Recording” in System Settings. Audio is never recorded.",
        mixerResetTooltip: "Reset to 100%",
        mixerOutputDefault: "Default",
        mixerOutputCurrent: "current",
        mixerOutputUnavailable: "Output unavailable",
        mixerOutputFallback: "Using default until this device returns.",
        mixerBypassedCaption: "This app manages its own audio.",
        mixerOutputTooltip: "Choose output",
        mixerAirPlayChooseSpeaker: "Choose AirPlay speaker…",
        mixerSystemOutputTitle: "Output",
        mixerSystemOutputNoDevices: "No outputs found",
        mixerSystemOutputTooltip: "Choose system output",
        mixerSystemOutputErrorFormat: "Could not switch: %@",
        mixerLowerOnHeadphonesDisconnect: "Lower volume when headphones disconnect",
        mixerLowerOnHeadphonesDisconnectCaption: "Adjusts output when wired or Bluetooth headphones disconnect.",
        mixerHeadphonesDisconnectVolume: "Volume after disconnect",
        preciseVolumeRollerEnable: "Use finer volume steps",
        preciseVolumeRollerCaption: "Turns volume wheels and keys into smaller system volume steps.",
        preciseVolumeRollerTapFailed: "Could not listen for volume keys.",
        mixerInputTitle: "Microphone",
        mixerInputNoDevices: "No microphones found",
        mixerInputUnavailable: "Microphone unavailable",
        mixerInputFallback: "Using default until this microphone returns.",
        mixerInputTooltip: "Choose microphone",
        mixerInputErrorFormat: "Could not switch: %@",
        mixerVisibleApps: "Apps in the list",
        mixerAllShown: "All",
        mixerHiddenCountLabel: "Hidden",
        mixerHideFromList: "Hide from the list",
        audioPrioritySection: "Audio priority",
        audioPriorityOutputEnable: "Automatically switch to the highest-priority output",
        audioPriorityInputEnable: "Automatically switch to the highest-priority microphone",
        audioPriorityOutputList: "Output priority",
        audioPriorityInputList: "Microphone priority",
        audioPriorityMoveUp: "Move up",
        audioPriorityMoveDown: "Move down",
        audioPriorityUnavailable: "Unavailable",
        audioPriorityCurrent: "Current",
        audioPriorityCaption: "Devices are selected in priority order. When a higher-priority device connects, it becomes active. When the active one disconnects, the next available takes over.",

        updatesSection: "Updates",
        autoCheckToggle: "Check for updates automatically",
        betaBadgeLabel: "Beta",
        checkNowButton: "Check now",
        updateChecking: "Checking…",
        updateUpToDate: "You’re on the latest version.",
        updateInstallButton: "Download and install",
        updateFailedPrefix: "Couldn’t check:",
        updateLastChecked: "Last checked:",
        menuCheckUpdates: "Check for app updates…",

        permissionRequired: "Permission required",
        permissionAccessibility: "Accessibility",
        permissionScreenRecording: "Screen Recording",
        permissionGranted: "Granted",
        permissionMissing: "Not granted",
        permissionOpenSettings: "Open System Settings…",
        permissionRequest: "Grant access",
        permissionRestartNote: "macOS may ask to reopen the app after granting.",
        secureInputTitle: "Secure input is on",
        secureInputHeldFormat: "%@ is holding it, so Hexa cannot type for you. Dismiss its password field, or quit it, to release it.",
        secureInputUnattributed: "No running app claims it. Log out and back in to clear it.",
        secureInputUnidentified: "The app holding it could not be identified, so Hexa cannot type for you.",
        secureInputRevealFormat: "Show %@",

        aboutDescription: "Modular system utility for macOS.\nPower management, hardware telemetry, system maintenance, and quick controls.",
        versionPrefix: "Version",
        reviewIntro: "Review introduction",
        reviewHighlights: "Review release notes",
        viewOnGitHub: "GitHub Repository",
        downloadLatestRelease: "Download latest release",

        obContinue: "Continue",
        obBack: "Back",
        obStepWelcomeTitle: "Welcome to Hexa",
        obStepWelcomeBody: "Hexa is a modular macOS utility. Everything runs on demand, and the app has no telemetry.",
        obWelcomeBullet1Title: "Power management",
        obWelcomeBullet1Body: "Configurable sleep prevention and continuous operation on demand.",
        obWelcomeBullet2Title: "System monitoring",
        obWelcomeBullet2Body: "Real-time monitoring of hardware utilization, temperatures, and memory pressure.",
        obWelcomeBullet3Title: "Maintenance and tools",
        obWelcomeBullet3Body: "Application uninstaller, system cleaning, and process control tools.",
        obStepModulesTitle: "Modules",
        obStepModulesBody: "Choose what this Mac runs. A module turned off here leaves the menu bar and Settings, and can be turned back on later in Settings.",
        obStepPermissionsTitle: "Permissions",
        obStepPermissionsBody: "These are the permissions required by the modules you kept on. Hexa asks macOS only when you request one.",
        obStepDoneTitle: "Setup complete",
        obStepDoneBody: "Hexa is active and ready for use.",
        obDoneHint: "Access the Hexa icon in the menu bar at the top of your screen.",
        obFinish: "Finish",
        obPermissionPendingNote: "Not granted. Hexa asks again when the module needs it.",
        obRedoOnboarding: "Run setup again",
        obWhatsNewTitle: "Release notes",
        releaseNotesUnavailable: "Release notes are not available for this version.",
        obWhatsNewFallback: "This release includes performance improvements and stability updates.",

        tabMonitor: "Monitor",
        monitorMenuBarSection: "In the menu bar",
        monitorMenuBarCaption: "Choose what appears next to the icon in the menu bar.",
        monitorCombineTemperatures: "Combine usage and temperature",
        monitorCombineTemperaturesCaption: "When usage and temperature for the same item are enabled, show them in one block.",
        monitorSeparateMenuBarMetrics: "Separate metrics into their own items",
        monitorSeparateMenuBarMetricsCaption: "Separates active blocks in the menu bar and keeps usage and temperature together when combine is on.",
        monitorNetworkUploadFirst: "Upload above download",
        monitorShowCPU: "CPU",
        monitorShowMemory: "Memory",
        monitorShowNetwork: "Network",
        monitorShowPowerLabel: "Power",
        monitorIntervalLabel: "Update every",
        monitorInterval1: "1 second",
        monitorInterval2: "2 seconds",
        monitorInterval5: "5 seconds",
        monitorPanelSection: "In the panel",
        panelNavigationMode: "Navigate panel by sections",
        panelNavigationCaption: "Shows one section at a time. Choose List to see everything in one continuous scroll.",
        panelFooterSections: "Sections",
        panelFooterList: "List",
        betaBadge: "BETA",
        betaFeatureWarning: "Beta. You may run into some bugs.",

        networkSection: "Network",
        networkIPAddresses: "IP addresses",
        networkLocalIP: "Local IPv4",
        networkDownload: "Download",
        networkUpload: "Upload",
        networkThisSession: "This session",
        networkMeasuring: "Measuring…",
        networkApps: "Apps using network",
        networkAppsIdle: "No apps using network now",

        diskSection: "Disks",
        diskUsed: "used",
        diskFree: "free",
        diskMenuBarStyleLabel: "Disk display",
        diskMenuBarUsedPercentage: "Used percentage",
        diskMenuBarAvailableSpace: "Available space",
        diskMenuBarUsedSpace: "Used space",
        diskAvailable: "available",
        diskPurgeable: "purgeable",
        diskInternal: "Internal",
        diskExternal: "External",
        diskSelect: "Select disk",
        diskRead: "Read",
        diskWrite: "Write",
        diskSMARTStatus: "Status",
        diskSMARTUnavailable: "SMART unavailable for this disk",
        diskTotalRead: "Total read",
        diskTotalWritten: "Total written",
        diskTemperature: "Temperature",
        diskHealth: "Health",
        diskPowerCycles: "Power cycles",
        diskPowerOnHours: "Power on hours",
        diskUnsafeShutdowns: "Unsafe shutdowns",
        diskMediaErrors: "Media errors",
        diskEject: "Eject",
        diskEjectAll: "Eject all",
        diskEjecting: "Ejecting…",
        diskReadyToRemove: "Ready to remove",
        diskEjectFailed: "Could not eject",
        diskEjectSiblingsTitleFormat: "Ejecting \"%@\" also ejects other volumes",
        diskEjectSiblingsMessageFormat: "These volumes are on the same disk and will be ejected too: %@.",
        diskProtectionCaption: "Eject before unplugging.",
        diskNoExternal: "No external disk ready to eject.",
        diskOpenInFinder: "Open",
        diskStorageSettings: "Storage",
        diskNoDisks: "No mounted disks found.",

        powerSection: "Power",
        powerSystem: "System",
        powerAdapter: "Adapter",
        powerBattery: "Battery",
        powerCharging: "Charging",
        powerOnBattery: "On battery",
        powerPluggedIn: "Plugged in",
        powerUnavailable: "Power metrics unavailable on this Mac",
        powerAdapterMaxFormat: "%@ max",
        monitorShowGPU: "GPU",
        monitorShowCPUTemperature: "CPU temperature",
        monitorShowGPUTemperature: "GPU temperature",
        monitorShowBatteryTemperature: "Battery temperature",
        monitorShowPeripheralBattery: "Peripheral battery",
        peripheralBatteryNoDevices: "No devices found",

        obStepMenuBarTitle: "Metrics in the menu bar",
        obStepMenuBarBody: "Pick what to show next to the icon. The preview above updates live.",
        obStepMenuBarNote: "New: Network and Power blocks and graphs in the panel. Fine-tune it all later in Settings › Monitor.",
        monitorMenuBarPresetLabel: "Style",
        menuBarPresetReadable: "Readable",
        menuBarPresetDense: "Dense",
        menuBarSpacingLabel: "Menu bar spacing",
        menuBarSpacingStandard: "Standard",
        menuBarSpacingCompact: "Compact",
        menuBarHideIconToggle: "Hide the app icon while metrics are shown",
        menuBarHideIconCaption: "The icon only returns when metrics leave the bar. A ready update or a running “Keep awake” does not bring it back.",
        monitorLabelStyleLabel: "Labels",
        menuBarLabelStyleCompact: "Compact",
        menuBarLabelStyleClassic: "Classic",
        monitorMemoryStyleLabel: "Show memory as",
        monitorMemoryPressureDot: "Pressure dot",
        memoryStyleDot: "Dot",
        memoryStylePercent: "%",
        memoryStyleBoth: "Both",
        systemUptime: "Up for",
        batteryCharge: "Charge",
        powerHealth: "Battery health",
        powerCycles: "Cycles",
        speedTestRun: "Speed test",
        speedTestAgain: "Test again",
        speedTestLatency: "Latency",
        speedTestTesting: "Testing…",
        speedTestFailed: "Test failed",

        disclosureExpanded: "Expanded",
        disclosureCollapsed: "Collapsed",
        panelHideItem: "Hide from panel",
        panelShowItem: "Show in panel",
        panelHiddenItem: "Hidden",
        monitorItemUptime: "Uptime",
        monitorItemNetSpeed: "Live speed",
        monitorItemNetTotals: "Session totals",
        monitorItemNetTest: "Speed test",
        monitorItemDiskUsage: "Disk usage",
        monitorItemDiskActivity: "Live activity",
        monitorItemDiskSMART: "SMART",
        monitorItemDiskProtection: "External protection",
        monitorItemDiskTools: "Tools",
        monitorPanelConfigHint: "Open a block to choose what it shows.",
        monitorOrderHint: "Drag to reorder the panel sections and use the eye to show or hide each one.",
        obStepPanelTitle: "What’s in the panel",
        obStepPanelBody: "Open each block and pick exactly what shows when you click the icon.",
        obStepPanelNavigationTitle: "Section-based panel",
        obStepPanelNavigationBody: "The panel can now show one section at a time. You can switch between Sections and List in Settings.",

        cleaningMenuItem: "Cleaning Mode",
        utilitiesSection: "Utilities",
        quickControlsSection: "Controls",
        panelCategoryWindows: "Windows",
        panelCategoryInput: "Mouse and keyboard",
        panelCategoryFiles: "Files",
        windowMaximizeName: "Maximize windows",
        windowMaximizeCaption: "The green button maximizes without creating another Space.",
        windowMaximizeActiveNow: "Green button override active",
        windowMaximizeNeedsAccessibility: "Needs Accessibility to work.",
        keyDebounceName: "Debounce",
        keyDebounceEnable: "Filter duplicate keys",
        keyDebounceCaption: "Filters very fast duplicate key presses.",
        keyDebounceActiveNow: "Filter active",
        keyDebounceGlobalWindow: "Global window",
        keyDebouncePerKeySection: "Specific keys",
        keyDebouncePerKeyCaption: "Per-key values override the global window. Use 0 ms to stop filtering a key.",
        keyDebounceKeyLabel: "Key",
        keyDebounceWindowLabel: "Window",
        keyDebounceAddKey: "Add key",
        keyDebounceNoOverrides: "No specific keys configured.",
        keyDebounceRemoveKey: "Remove key",
        cleaningPanelCaption: "Locks the keyboard for safe cleaning.",
        cleaningOverlayTitle: "Keyboard locked for cleaning",
        cleaningOverlaySubtitle: "Press Escape 5 times to unlock",
        cleaningOverlayUnlock: "Unlock keyboard",
        cleaningOverlayMouseHint: "Mouse and trackpad remain operational.",
        cleaningKeepScreenVisibleToggle: "Keep screen visible",
        cleaningKeepScreenVisibleCaption: "Shows a discreet indicator on screen without full dimming.",
        cleaningStartNow: "Lock keyboard",
        cleaningNeedsAxTitle: "Accessibility permission required",
        cleaningNeedsAxBody: "To block keyboard input, grant access in System Settings > Privacy & Security > Accessibility.",

        tabSupport: "Support",
        shortcutsPageCaption: "Configure global keyboard shortcuts assigned to Hexa modules.",
        shortcutsPageTitle: "Keyboard shortcuts",
        settingsSearchPlaceholder: "Search settings",
        donateHeading: "Development Support",
        donateMessage: "Hexa is an independent and open-source utility. If you would like to support the ongoing development of the project, contributions via Buy Me a Coffee are welcome.",
        donateButton: "Support on Buy Me a Coffee",
        donateThanks: "Thank you for supporting the project.",
        supportIntroTitle: "Development Support",
        supportIntroMessage: "If you wish to financially support the project, Buy Me a Coffee is available.",
        supportIntroStarButton: "View repository on GitHub",
        supportIntroStarMessage: "Open source on GitHub. Star the repository to support the project.",
        supportIntroCoffeeButton: "Support on Buy Me a Coffee",
        supportIntroLaterButton: "Not now",
        supportIntroDoneButton: "Done",
        discordIntroTitle: "The Hexa Discord community is just getting started",
        discordIntroMessage: "The Hexa community is new and still being built. Join early to meet other users and help build a welcoming space around the app.",
        discordIntroJoinButton: "Join the Discord community",
        communityIntroTitle: "See it before everyone else",
        communityIntroMessage: "People who already followed me on X saw several changes in this update before anyone else. I post previews of what is coming and show how it works, so you already know the basics before the update ships. Follow along and see what comes next!",
        communityIntroFollowButton: "Follow @hexa on X",
        showMenuBarIcon: "Display menu bar icon",
        menuBarIconStillHiddenTitle: "Icon not visible in menu bar",
        menuBarIconStillHiddenBody: "The menu bar item was created, but macOS has not allocated visible space. Reduce active menu bar items to make room.",
        menuBarIconManagerHintFormat: "%@ is active and may be hiding the item. Configure %@ to keep Hexa visible.",
        menuBarIconDisallowedBody: "macOS restricted Hexa from the menu bar. In System Settings > Control Center, enable Hexa.",
        shortcutRecording: "Press the new shortcut",
        shortcutReset: "Reset",
        shortcutNone: "None",
        shortcutClear: "Remove shortcut",
        shortcutInvalid: "Use at least Control, Option or Command with a key.",
        shortcutPressKeys: "Press keys",
        shortcutEscapeHint: "Escape cancels.",
        shortcutDeleteHint: "Delete clears.",
        shortcutNotCaptured: "Nothing was captured. macOS or another app already uses that combination. Try another one.",
        shortcutConflictFormat: "This shortcut is already used by %@.",
        shortcutTakeOverOffer: "macOS uses %@ for one of its own shortcuts.",
        shortcutTakeOverAction: "Take over while Hexa runs",
        shortcutTakeOverCaption: "macOS gets the key back when you quit Hexa or turn this feature off. If Hexa closes any other way, the key comes back when you open Hexa again.",
        shortcutTakeOverDismiss: "Don’t take over",
        shortcutUnavailable: "macOS rejected this shortcut. Choose another one.",
        switcherUsageHintFormat: "Hold %@ to navigate; release to activate the window. Shift or ← goes back; W closes the window; Q quits the app; Esc cancels.",
        musicBlockSection: "Media keys",
        musicBlockTitle: "Stop Music from opening on its own",
        musicBlockCaption: "Blocks the music app opening after a detected media key. Requires Accessibility access. Headphone commands without a detected key are left alone.",
        musicBlockUnavailable: "This protection is unavailable right now. Turn it off and on to try again.",
        musicBlockReplacementLabel: "Open instead",
        musicBlockReplacementNone: "None",
        musicBlockReplacementBlocked: "Music and iTunes are the apps being blocked, so they can’t open instead. Choose another app.",
        musicBlockChooseApp: "Choose app…",
        musicBlockPlayReplacement: "Play after opening replacement",
        cleanerName: "Cleaner",
        cleanerIntroTitle: "Clean up your Mac",
        cleanerIntroCaption: "Scans for leftovers from uninstalled apps, caches, logs and the Trash. You review everything first and removed items go to the Trash.",
        cleanerScan: "Scan",
        cleanerScanning: "Scanning…",
        cleanerCleaning: "Cleaning…",
        cleanerCatLeftovers: "Leftovers from uninstalled apps",
        cleanerCatLoginItems: "Orphaned startup items",
        cleanerCatCaches: "Caches",
        cleanerCatLogs: "Logs",
        cleanerCatDeveloper: "Developer junk",
        cleanerCatTrash: "Trash",
        cleanerLeftoversNote: "Found by analysis and left unchecked. Check the path before ticking.",
        cleanerLoginItemsNote: "The entry under Login Items disappears after restarting the Mac.",
        cleanerTrashNote: "Emptying the Trash is permanent.",
        cleanerTrashConfirmTitle: "Empty the Trash?",
        cleanerTrashConfirmMessage: "What was in the Trash at scan time will be deleted for good and cannot be recovered. Anything that reached the Trash later stays there.",
        cleanerTrashConfirmButton: "Clean and empty",
        cleanerCatDeviceBackups: "iPhone backups",
        cleanerDeviceBackupsCaption: "Old iPhone and iPad backups take a big slice of the storage macOS calls Other. Remove only the ones you no longer need; a new backup is made when you plug the device in again.",
        cleanerCatPackageCaches: "Package caches",
        cleanerPackageCachesCaption: "Packages downloaded by npm, Gradle, Dart, uv and Puppeteer, fetched again when needed. They go to the Trash, and the next build or install must download them again; offline builds can fail. Nothing is selected.",
        cleanerCatCodingConversations: "Old Claude Code conversations",
        cleanerCodingConversationsCaptionFormat: "Claude Code conversations with no activity for more than %d days. Each one goes to the Trash together with its helper folder.",
        cleanerCodingConversationAgeLabel: "List conversations",
        cleanerCodingConversationsRisk: "A conversation does not return to the tool's history unless you restore it from the Trash.",
        cleanerCatScreenshots: "Forgotten screenshots",
        cleanerScreenshotsCaptionFormat: "Screenshots you have not opened in %d days that still have the name and folder macOS gave them. Ones you renamed or moved never show up here.",
        cleanerScreenshotsSettingCaption: "The scan lists the screenshots you have not opened for this long, unchecked, with their total size.",
        cleanerScreenshotsAfterFormat: "After %d days",
        cleanerNothingFound: "Nothing to clean. Your Mac is tidy.",
        cleanerClean: "Clean",
        cleanerDoneNote: "Items went to the Trash and can be recovered from there.",
        cleanerAgain: "Scan again",
        cleanerRevealInFinder: "Reveal in Finder",
        cleanerPanelCaption: "App leftovers, caches and logs",
        cleanerSafeSection: "Safe cleanup",
        cleanerOptionalSection: "Optional, review first",
        cleanerCatOtherCaches: "Other caches",
        cleanerCachesCaption: "Temporary files apps rebuild on their own.",
        cleanerLogsCaption: "Old diagnostic logs.",
        cleanerDeveloperCaption: "Xcode build and simulator leftovers.",
        cleanerLoginItemsCaption: "Startup entries left by apps that no longer exist.",
        cleanerLeftoversCaption: "Files left behind by apps you uninstalled.",
        cleanerOtherCachesCaption: "Safe to remove, nothing breaks. Apps may open slower once and downloaded content, like offline music, downloads again.",
        cleanerCatBrowserCaches: "Browser caches",
        cleanerBrowserCachesCaption: "Temporary files and downloaded data that browsers rebuild on their own.",
        cleanerCatBrowserSiteData: "Cookies and site data",
        cleanerBrowserSiteDataCaption: "Local website data and active sessions. You will need to sign in again to websites.",
        cleanerBrowserAccessPendingReason: "Access to browser profiles requires Full Disk Access permission.",
        cleanerSkippedBrowsersFormat: "%@ is in use and was skipped.",
        cleanerNotificationSkippedBrowsersFormat: "Browsers in use were skipped.",
        cleanerCleanSizeFormat: "Clean %@",
        cleanerScheduleTitle: "Automatic cleanup",
        cleanerScheduleOff: "Off",
        cleanerScheduleDaily: "Daily",
        cleanerScheduleWeekly: "Weekly",
        cleanerScheduleCaption: "Cleans only the safe part on its own at the chosen time and sends everything to the Trash.",
        cleanerScheduleLastFormat: "The last automatic cleanup sent %@ to the Trash.",
        cleanerAutoNotificationFormat: "%@ sent to the Trash.",
        cleanerScheduleNextFormat: "Next cleanup %@.",
        cleanerScheduleRanFormat: "Last automatic cleanup %@.",
        cleanerSchedulePostponed: "Postponed: a manual Cleaner review is open. Finish or cancel it so the automatic cleanup can run today.",
        cleanerScheduleNotifyToggle: "Notify when done",
        cleanerAbortAll: "Abort all",
        cleanerAutoRunning: "Automatic cleanup running",
        cleanerAutoInterrupted: "Automatic cleanup was interrupted before it finished.",
        cleanerNotifDenied: "Hexa notifications are turned off in the system.",
        cleanerNotifOpenSettings: "Open Notification Settings…",
        launchAtLoginNeedsApplications: "The app is running from a place that cannot open at login. Drag Hexa to the Applications folder, open it from there and turn this on again.",
        launchAtLoginNeedsApproval: "The login item is registered, but macOS still needs your approval. In System Settings, allow Hexa to open at login and to run in the background.",
        ocrRemoveLineBreaksToggle: "Remove line breaks",
        ocrRemoveLineBreaksCaption: "Removes line breaks so copied text pastes as one paragraph.",
        ocrQRToggle: "Read QR codes",
        ocrQRCaption: "If the area has a QR code, its content is shown to copy or open.",
        ocrQRCopied: "QR code copied",
        ocrShowMenuOnShortcut: "Show OCR menu when using the keyboard shortcut",
        qrResultTitle: "QR code",
        qrResultCopy: "Copy",
        qrResultOpen: "Open link",
        highlightsTitle: "New in this update",
        highlightsTitleClipboardRedesign: "Redesigned clipboard",
        highlightsTitleWindowLayout: "Window Layout",
        highlightsTitleQuitProtection: "Quit and close protection",
        highlightsTitleRecorderBlur: "Recording privacy blur",
        highlightsCaptionDockPreview: "Dock Preview now works with Dock magnification turned on",
        highlightsCaptionScreenshot: "The screenshot tool gained a pixel loupe and QR code reading",
        highlightsCaptionSnippetLibrary: "A searchable snippet menu types any snippet right at your cursor",
        highlightsCaptionCapturePalette: "One shortcut now opens a floating palette for screenshots, recordings, screen text and colors with nearby controls.",
        highlightsCaptionClipboardRedesign: "Clipboard history now opens as a compact palette with uncluttered rows and an on-demand preview for reading or editing the full item.",
        highlightsCaptionWindowLayout: "Position windows with the directional ring using a shortcut and pointer, or drag to screen edges to snap with custom gaps.",
        highlightsCaptionQuitProtection: "Avoid quitting apps or closing windows by accident with a hold, a double press or an extra modifier, customizable per app.",
        highlightsCaptionRecorderBlur: "Hide private details, passwords and sensitive areas anywhere across your recorded video before sharing or exporting.",
        highlightsConfigure: "Set up",
        highlightsTry: "Try it",
        highlightsSeeAll: "See all changes",
        switcherCurrentSpaceOnly: "Show only the current desktop",
        switcherCurrentSpaceOnlyCaption: "Lists only windows from the desktop you are on. Picking a window never moves you to another desktop.",
        mixerSoundEffectsOutputTitle: "System sounds",
        mixerSoundEffectsOutputTooltip: "Choose where alerts and sound effects play",
        monitorOpenActivityMonitor: "Open Activity Monitor",
        dockClickHide: "Click the Dock icon to hide the app",
        dockClickHideCaption: "The active app hides when you click its Dock icon. Click again to bring it back.",
        monitorMemoryMetricLabel: "Measure memory as",
        memoryMetricUsed: "Memory Used",
        memoryMetricApp: "App Memory",
        keepAwakeRightClickToggle: "Right-click the menu bar icon to toggle Keep Awake",
        keepAwakeRightClickToggleCaption: "Replaces the right-click context menu.",
        urlCleanerRulesTitle: "Cleaning rules",
        urlCleanerRulesCaption: "A site attaches these parameters to its own share links to track where the link came from. Switched on, a name is removed when a link is cleaned; switched off, it stays. Names you add can be deleted.",
        urlCleanerRulesCoverageCaption: "The list covers a site’s different share paths (the web page, the app, a live room), which is why it is long; a real link usually carries only two to four of them.",
        urlCleanerRulesAllSites: "All sites",
        urlCleanerRulesCountSingular: "1 parameter",
        urlCleanerRulesCountPluralFormat: "%d parameters",
        urlCleanerRulesAddSite: "Add a site",
        urlCleanerRulesParameterPlaceholder: "Parameter name",
        urlCleanerRulesMatchCaption: "Write the name to the left of the = , like utm_source. A name that matches takes that one parameter out of the link and leaves the rest as it was.",
        urlCleanerRulesAddButton: "Add",
        urlCleanerRulesRemoveButton: "Delete name",
        urlCleanerRulesRemoveSiteButton: "Turn off every rule for this site",
        urlCleanerRemovedFormat: "Removed %@",
        switcherSearchPin: "Pin search with S",
        switcherSearchPinCaption: "S starts a search and pins the switcher open, so typing no longer produces special characters when your shortcut uses ⌥, and a search starting with Q or W no longer closes the window or quits the app by mistake.",
        invertVerticalScroll: "Invert vertical scrolling",
        invertHorizontalScroll: "Invert horizontal scrolling",
        scrollHorizontalName: "Scroll sideways while holding a key",
        scrollHorizontalModifierLabel: "Modifier key",
        scrollHorizontalCommandKey: "Command",
        scrollHorizontalCaption: "Hold only the selected modifier to scroll the vertical mouse wheel horizontally. Other key combinations are unchanged.",
        switcherShowShortcutHints: "Show shortcut hints",
        switcherShowShortcutHintsCaption: "Shows the app and window shortcuts below the icons.",
        uninstallerHomebrewPackageFormat: "%@ will also be removed from Homebrew.",
        focusFollowsMouseName: "Focus follows mouse",
        focusFollowsMouseCaption: "Focuses the window under the pointer.",
        focusFollowsMouseDelay: "Hover delay",
        focusFollowsMouseRaise: "Bring the window to the front",
        focusFollowsMouseWaitForStop: "Wait for the pointer to stop",
        switcherMinimizedPlacementLabel: "Minimized windows",
        switcherTreatHiddenAppsLikeMinimized: "Treat hidden apps like minimized windows",
        switcherMinimizedPlacementNormal: "Normal ordering",
        switcherMinimizedPlacementEnd: "Place at end",
        switcherMinimizedPlacementHidden: "Hide",
        switcherShowFullscreenWindows: "Show fullscreen windows",
        switcherScreenPlacementLabel: "Show on",
        switcherScreenPlacementPointer: "Display with the pointer",
        switcherScreenPlacementMenuBar: "Display with the menu bar",
        switcherScreenPlacementActiveWindow: "Display with the active window",
        switcherScreenPlacementCaption: "Which display the switcher opens on when more than one is connected.",
        switcherCurrentDisplayOnly: "Show only the current display",
        switcherCurrentDisplayOnlyCaption: "Lists only windows on the display under the pointer. If that display has no windows, the switcher does not open.",
        smoothScrollResponseLabel: "Response",
        smoothScrollCoastLabel: "Coast",
        mouseAccelerationName: "Disable mouse acceleration",
        mouseAccelerationCaption: "Removes pointer acceleration for connected mice. Your previous setting returns when this is turned off or Hexa quits.",
        linearScrollName: "Linear scrolling",
        linearScrollCaption: "Every notch of the mouse wheel scrolls the same distance, no matter how fast it spins. The trackpad is not affected.",
        linearScrollLinesLabel: "Lines per step",
        spacesOrderName: "Keep Spaces in a fixed order",
        spacesOrderCaption: "Stops macOS from rearranging Spaces by most recent use, so they stay in the order you set. Your previous setting returns when this is turned off. The Dock may restart once to apply the change.",

        spaceInventoryVolumeTotal: "Volume total",
        spaceInventoryVolumeFree: "Free",
        spaceInventoryVolumeUsed: "Used",
        spaceInventoryVolumeUnavailable: "The volume capacity could not be read. Nothing was assumed to be zero.",
        spaceInventoryLowSpace: "Less than 10 percent free. The largest folders are highlighted in the ranking below.",
        spaceInventoryRankingTitle: "Largest folders",
        spaceInventorySummaryTitle: "System data (Hexa estimate)",
        spaceInventorySummaryPartial: "Partial coverage: Hexa adds up only the top level of ~/Library and never derives this value from what is left on the volume.",
        spaceInventoryDeniedFormat: "%@: %@",
        spaceInventoryDeniedAccess: "access denied by macOS",
        spaceInventoryDeniedUnavailable: "folder could not be read",
        spaceInventoryPartialMark: "partial",
        spaceInventoryEmpty: "No folder was eligible for measurement.",
        spaceInventoryCancelled: "Measurement cancelled. The map shows what was measured so far.",

        largeFilesTitle: "Large and old files",
        largeFilesOpen: "Open list",
        largeFilesCaption: "Lists the files of your Mac by size and age. Nothing is marked: only what you mark and confirm goes to the Trash.",
        largeFilesAgeLabel: "Older than",
        largeFilesSizeLabel: "Larger than",
        largeFilesSettingsCaption: "The search uses both limits together. The next search follows what is saved here.",
        largeFilesBackToResults: "Back to results",
        largeFilesBackToStart: "Back to start",
        largeFilesThresholdsFormat: "%d days and %@ or more",
        largeFilesSearch: "Search now",
        largeFilesSearching: "Searching your home folder. You can cancel and keep what was found so far.",
        largeFilesEmpty: "No file meets both limits right now.",
        largeFilesResultTitle: "Found",
        largeFilesGroupFormat: "%d files, %@ in total",
        largeFilesCancelled: "Search cancelled. The list shows what was found so far.",
        largeFilesQuickLook: "Quick Look",
        largeFilesReportTitle: "Removal result",
        largeFilesReportSummaryFormat: "%d moved, %d not moved",
        largeFilesMovedFormat: "%@: moved to the Trash",
        largeFilesRefusedFormat: "%@: no longer the same file, nothing was moved",
        largeFilesFailedFormat: "%@: could not be moved, the file stays where it was",
        largeFilesRemove: "Move to the Trash",
        largeFilesConfirmTitle: "Move to the Trash?",
        largeFilesConfirmMessageFormat: "%d files, %@ in total. The items go to the macOS Trash and can be recovered until you empty it.",
        largeFilesSelectedFormat: "%d of %d files, %@ marked",
        spaceInventoryMeasuredTotal: "Measured total"
    )
}
