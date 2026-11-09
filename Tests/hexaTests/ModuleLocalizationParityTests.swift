// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Pina a paridade de texto visível dos módulos do escopo (DEC-001) nas 15 línguas
/// (CN4, INV5, VC2). Cada catálogo é percorrido por inteiro: campo vazio ou só
/// com espaços em qualquer idioma reprova. Não usa `hubTitle`, que lê
/// `L10n.shared.language` e esconderia buracos.
final class ModuleLocalizationParityTests: XCTestCase {
    private static let expectedCodes: Set<String> = [
        "en-US", "pt-BR", "tr", "ru", "es", "sk", "de", "fr", "it", "ja", "ko", "uk", "zh-Hans", "zh-TW", "zh-HK",
    ]

    /// Campos `String` de `Strings` pertencentes às seções do censo: painel
    /// keep awake, monitor (ajustes, rede, disco, energia e itens do painel),
    /// uninstaller, Cleaner, mídia, mixer, Homebrew, `keepAwake*`/`clamshell*`
    /// de Energia e todos os `ocr*`.
    private static let sharedStringsKeyPaths: [KeyPath<Strings, String>] = [
        \.keepAwakeTitle, \.keepAwakeEndsIn, \.keepAwakeUntilDisabled, \.keepAwakeNormalRules,
        \.keepAwakeUntilLabel, \.keepAwakeUntilStart, \.keepAwakeOptions, \.notchMixerOptions,
        \.ocrTextRecognitionSection, \.mediaOutputParamsSection, \.cleanerAutomationSection,
        \.cleanerAutoOrganizeSection, \.keepAwakeMouseJiggle, \.keepAwakeMouseJiggleCaption,
        \.keepAwakeMouseJiggleInterval, \.keepAwakeBatteryLimit, \.keepAwakeBatteryLimitNever,
        \.keepAwakeBatteryLimitCaption, \.durationLabel, \.clamshellTitle, \.clamshellOnCaption,
        \.clamshellNeedsSession, \.clamshellReady, \.clamshellNeedsPassword, \.sleepRestorePending,
        \.sleepRestoreAction, \.systemSection, \.temperatures,
        \.cpuLabel, \.gpuLabel, \.batteryLabel, \.usageSection, \.memorySection, \.memoryPressure,
        \.memorySwapUsed, \.memoryCompressed, \.memoryCachedFiles, \.pressureNormal, \.pressureWarning,
        \.pressureCritical, \.monitorUnavailable, \.energyAppsTitle, \.energyAppsIdle, \.uninstallerName,
        \.uninstallerEnableCaption, \.uninstallerStep1, \.uninstallerStep2, \.uninstallerStep3,
        \.uninstallerMenuItem, \.uninstallerDropTitle, \.uninstallerDropSubtitle, \.uninstallerChoose,
        \.uninstallerPickerTitle, \.uninstallerPickerSearch, \.uninstallerPickerEmpty, \.uninstallerEmptyNote,
        \.uninstallerFDANote, \.uninstallerFDAGrant, \.uninstallerFDAHint, \.uninstallerFDARelaunch,
        \.uninstallerScanning, \.uninstallerRemoving, \.uninstallerFoundTitle, \.uninstallerSelectedFormat,
        \.uninstallerRemove, \.uninstallerCancel, \.uninstallerConfirmationExpired, \.uninstallerQuitTitle,
        \.uninstallerQuitBodyFormat, \.uninstallerQuitAndRemove, \.uninstallerForceQuitTitle,
        \.uninstallerForceQuitBodyFormat, \.uninstallerForceQuitAndRemove, \.uninstallerTerminalContinue,
        \.uninstallerTerminalStillInstalled, \.uninstallerDoneTitle, \.movedToTrashFormat,
        \.freedPermanentlyFormat, \.uninstallerSomeFailed, \.uninstallerFailedNeedsFDA,
        \.uninstallerFailedMoreFormat, \.uninstallerAnother, \.uninstallerCatApp, \.uninstallerCatSupport,
        \.uninstallerCatCaches, \.uninstallerCatPreferences, \.uninstallerCatContainers, \.uninstallerCatLogs,
        \.uninstallerCatState, \.uninstallerCatOther, \.uninstallerHiddenHomeLegend,
        \.uninstallerSystemExtensionNote, \.uninstallerLoginItemNote, \.uninstallerAdminUnloadPrompt,
        \.spaceInventoryTitle, \.spaceInventoryLegend, \.spaceInventoryModelsCaption,
        \.spaceInventoryToolsCaption, \.spaceInventoryVMsCaption, \.spaceInventorySimulatorsTitle,
        \.spaceInventorySimulatorsScope, \.spaceInventorySimulatorNote, \.spaceInventorySimulatorWarning,
        \.spaceInventoryMeasure, \.uninstallerSelectionUnavailable, \.uninstallerRefusedSystemApp,
        \.uninstallerRefusedNestedApp, \.uninstallerRefusedSelfApp, \.uninstallerClearSelection,
        \.cleanerName, \.cleanerIntroTitle, \.cleanerIntroCaption, \.cleanerScan, \.cleanerScanning,
        \.cleanerCleaning, \.cleanerCatLeftovers, \.cleanerCatLoginItems, \.cleanerCatCaches,
        \.cleanerCatLogs, \.cleanerCatDeveloper, \.cleanerCatTrash, \.cleanerLeftoversNote,
        \.cleanerLoginItemsNote, \.cleanerTrashNote, \.cleanerTrashConfirmTitle, \.cleanerTrashConfirmMessage,
        \.cleanerTrashConfirmButton, \.cleanerCatDeviceBackups, \.cleanerDeviceBackupsCaption,
        \.cleanerCatPackageCaches, \.cleanerPackageCachesCaption, \.cleanerCatCodingConversations,
        \.cleanerCodingConversationsCaptionFormat, \.cleanerCodingConversationAgeLabel,
        \.cleanerCodingConversationsRisk, \.cleanerCatScreenshots, \.cleanerScreenshotsCaptionFormat,
        \.cleanerScreenshotsSettingCaption, \.cleanerScreenshotsAfterFormat, \.cleanerNothingFound,
        \.cleanerClean, \.cleanerDoneNote, \.cleanerAgain, \.cleanerRevealInFinder, \.cleanerPanelCaption,
        \.cleanerSafeSection, \.cleanerOptionalSection, \.cleanerCatOtherCaches, \.cleanerCachesCaption,
        \.cleanerLogsCaption, \.cleanerDeveloperCaption, \.cleanerLoginItemsCaption,
        \.cleanerLeftoversCaption, \.cleanerOtherCachesCaption, \.cleanerCatBrowserCaches,
        \.cleanerBrowserCachesCaption, \.cleanerCatBrowserSiteData, \.cleanerBrowserSiteDataCaption,
        \.cleanerBrowserAccessPendingReason, \.cleanerSkippedBrowsersFormat,
        \.cleanerNotificationSkippedBrowsersFormat, \.cleanerCleanSizeFormat, \.cleanerScheduleTitle,
        \.cleanerScheduleOff, \.cleanerScheduleDaily, \.cleanerScheduleWeekly, \.cleanerScheduleCaption,
        \.cleanerScheduleLastFormat, \.cleanerAutoNotificationFormat, \.cleanerScheduleNextFormat,
        \.cleanerScheduleRanFormat, \.cleanerSchedulePostponed, \.cleanerScheduleNotifyToggle,
        \.cleanerAbortAll, \.cleanerAutoRunning, \.cleanerAutoInterrupted, \.cleanerNotifDenied,
        \.cleanerNotifOpenSettings, \.launchAtLoginNeedsApplications, \.launchAtLoginNeedsApproval,
        \.ocrRemoveLineBreaksToggle, \.ocrRemoveLineBreaksCaption, \.ocrQRToggle, \.ocrQRCaption,
        \.ocrQRCopied, \.ocrShowMenuOnShortcut, \.qrResultTitle, \.qrResultCopy, \.qrResultOpen,
        \.highlightsTitle, \.highlightsTitleClipboardRedesign, \.highlightsTitleWindowLayout,
        \.highlightsTitleQuitProtection, \.highlightsTitleRecorderBlur, \.highlightsCaptionDockPreview,
        \.highlightsCaptionScreenshot, \.highlightsCaptionSnippetLibrary, \.highlightsCaptionCapturePalette,
        \.highlightsCaptionClipboardRedesign, \.highlightsCaptionWindowLayout,
        \.highlightsCaptionQuitProtection, \.highlightsCaptionRecorderBlur, \.highlightsConfigure,
        \.highlightsTry, \.highlightsSeeAll, \.switcherCurrentSpaceOnly, \.switcherCurrentSpaceOnlyCaption,
        \.mixerSoundEffectsOutputTitle, \.mixerSoundEffectsOutputTooltip,
        \.monitorOpenActivityMonitor, \.dockClickHide, \.dockClickHideCaption, \.monitorMemoryMetricLabel,
        \.memoryMetricUsed, \.memoryMetricApp, \.keepAwakeRightClickToggle,
        \.keepAwakeRightClickToggleCaption, \.urlCleanerRulesTitle, \.urlCleanerRulesCaption,
        \.urlCleanerRulesCoverageCaption, \.urlCleanerRulesAllSites, \.urlCleanerRulesCountSingular,
        \.urlCleanerRulesCountPluralFormat, \.urlCleanerRulesAddSite, \.urlCleanerRulesParameterPlaceholder,
        \.urlCleanerRulesMatchCaption, \.urlCleanerRulesAddButton, \.urlCleanerRulesRemoveButton,
        \.urlCleanerRulesRemoveSiteButton, \.urlCleanerRemovedFormat, \.switcherSearchPin,
        \.switcherSearchPinCaption, \.invertVerticalScroll, \.invertHorizontalScroll, \.scrollHorizontalName,
        \.scrollHorizontalModifierLabel, \.scrollHorizontalCommandKey, \.scrollHorizontalCaption,
        \.switcherShowShortcutHints, \.switcherShowShortcutHintsCaption, \.uninstallerHomebrewPackageFormat,
        \.focusFollowsMouseName, \.focusFollowsMouseCaption, \.focusFollowsMouseDelay,
        \.focusFollowsMouseRaise, \.focusFollowsMouseWaitForStop, \.switcherMinimizedPlacementLabel,
        \.switcherTreatHiddenAppsLikeMinimized, \.switcherMinimizedPlacementNormal,
        \.switcherMinimizedPlacementEnd, \.switcherMinimizedPlacementHidden, \.switcherShowFullscreenWindows,
        \.switcherScreenPlacementLabel, \.switcherScreenPlacementPointer, \.switcherScreenPlacementMenuBar,
        \.switcherScreenPlacementActiveWindow, \.switcherScreenPlacementCaption, \.switcherCurrentDisplayOnly,
        \.switcherCurrentDisplayOnlyCaption, \.smoothScrollResponseLabel, \.smoothScrollCoastLabel,
        \.mouseAccelerationName, \.mouseAccelerationCaption, \.linearScrollName, \.linearScrollCaption,
        \.linearScrollLinesLabel, \.spacesOrderName, \.spacesOrderCaption, \.mediaName, \.mediaEnableCaption,
        \.mediaLocalNote, \.mediaToolVideo, \.mediaToolGIF, \.mediaToolImage, \.mediaToolText,
        \.mediaSelectFile, \.mediaDropHint, \.mediaOutput, \.mediaOutputAutomatic, \.mediaChooseOutput,
        \.mediaStartVideo, \.mediaStartGIF, \.mediaStartImage, \.mediaStartConvertPDF, \.mediaStartText,
        \.mediaCancel, \.mediaStartTime, \.mediaEndTime, \.mediaQuality, \.mediaCompressionLow,
        \.mediaCompressionMedium, \.mediaCompressionHigh, \.mediaCompressionLowDescription,
        \.mediaCompressionMediumDescription, \.mediaCompressionHighDescription, \.mediaMaxSize,
        \.mediaSizingResolution, \.mediaSizingFileSize, \.mediaTargetSize, \.mediaTargetSizeHint,
        \.mediaErrorTargetTooSmall, \.mediaErrorGIFTooLongFormat, \.mediaMegabytesSuffix, \.mediaWidth,
        \.mediaFPS, \.mediaKeepAudio, \.mediaCodec, \.mediaFormat, \.mediaStripMetadata, \.mediaLoopGIF,
        \.mediaOCRMode, \.mediaOCRAccurate, \.mediaOCRFast, \.mediaLanguageCorrection, \.mediaTextOutputNote,
        \.mediaRunning, \.mediaCompleted, \.mediaCancelled, \.mediaStatusNotice, \.mediaOpenInFinder,
        \.mediaCopyText, \.mediaRunAgain, \.mediaEmptyText, \.mediaResultSavedFormat, \.mediaResultSizeFormat,
        \.mediaResultGrewCaption, \.mediaErrorNoFile, \.mediaErrorNoVideo, \.mediaErrorSameOutput,
        \.mediaErrorUnsupported, \.mixerSection, \.mixerEmpty, \.mixerUnavailable, \.mixerPermissionBody,
        \.mixerResetTooltip, \.mixerOutputDefault, \.mixerOutputCurrent, \.mixerOutputUnavailable,
        \.mixerOutputFallback, \.mixerBypassedCaption, \.mixerOutputTooltip, \.mixerAirPlayChooseSpeaker,
        \.mixerSystemOutputTitle, \.mixerSystemOutputNoDevices, \.mixerSystemOutputTooltip,
        \.mixerSystemOutputErrorFormat, \.mixerLowerOnHeadphonesDisconnect,
        \.mixerLowerOnHeadphonesDisconnectCaption, \.mixerHeadphonesDisconnectVolume,
        \.preciseVolumeRollerEnable, \.preciseVolumeRollerCaption, \.preciseVolumeRollerTapFailed,
        \.mixerInputTitle, \.mixerInputNoDevices, \.mixerInputUnavailable, \.mixerInputFallback,
        \.mixerInputTooltip, \.mixerInputErrorFormat, \.mixerVisibleApps, \.mixerAllShown,
        \.mixerHiddenCountLabel, \.mixerHideFromList, \.homebrewTrustTitle, \.homebrewTrustCaption,
        \.homebrewTrustButton, \.homebrewGroupDependencies, \.homebrewUninstall, \.homebrewAllPackages,
        \.homebrewOpenTerminal, \.homebrewCancelOperation, \.homebrewClearLog,
        \.homebrewConfirmUninstallTitle, \.homebrewConfirmUninstallBodyFormat, \.homebrewTerminalFallback,
        \.homebrewOperationUninstallFormat, \.homebrewOperationUpgradeAll,
        \.homebrewOperationUninstalledFormat, \.homebrewOperationUpgradedAll, \.homebrewOperationFailedFormat,
        \.homebrewOperationCancelled, \.homebrewOperationPreparing, \.homebrewOperationDownloading,
        \.homebrewOperationUninstalling, \.homebrewOperationUpgrading, \.homebrewOperationFinalizing,
        \.homebrewOperationRefreshing, \.homebrewOperationTerminal, \.homebrewOperationElapsedFormat,
        \.homebrewOperationShowDetails, \.homebrewOperationHideDetails, \.homebrewOperationTechnicalLog,
        \.homebrewOperationProgressUnknown, \.keepAwakeAutoStart, \.keepAwakeAutoStartCaption,
        \.clamshellSection, \.clamshellExplanation, \.ocrName, \.ocrCaption, \.ocrCopied, \.ocrNoText,
        \.ocrClipboardChanged,
        \.tabMonitor, \.monitorMenuBarSection, \.monitorMenuBarCaption, \.monitorCombineTemperatures,
        \.monitorCombineTemperaturesCaption, \.monitorSeparateMenuBarMetrics,
        \.monitorSeparateMenuBarMetricsCaption, \.monitorNetworkUploadFirst, \.monitorShowCPU,
        \.monitorShowMemory, \.monitorShowNetwork, \.monitorShowPowerLabel, \.monitorIntervalLabel,
        \.monitorInterval1, \.monitorInterval2, \.monitorInterval5, \.monitorPanelSection,
        \.panelNavigationMode, \.panelNavigationCaption, \.panelFooterSections, \.panelFooterList,
        \.betaBadge, \.betaFeatureWarning, \.networkSection, \.networkIPAddresses, \.networkLocalIP,
        \.networkDownload, \.networkUpload, \.networkThisSession, \.networkMeasuring, \.networkApps,
        \.networkAppsIdle, \.diskSection, \.diskUsed, \.diskFree, \.diskMenuBarStyleLabel,
        \.diskMenuBarUsedPercentage, \.diskMenuBarAvailableSpace, \.diskMenuBarUsedSpace, \.diskAvailable,
        \.diskPurgeable, \.diskInternal, \.diskExternal, \.diskSelect, \.diskRead, \.diskWrite,
        \.diskSMARTStatus, \.diskSMARTUnavailable, \.diskTotalRead, \.diskTotalWritten, \.diskTemperature,
        \.diskHealth, \.diskPowerCycles, \.diskPowerOnHours, \.diskUnsafeShutdowns, \.diskMediaErrors,
        \.diskEject, \.diskEjectAll, \.diskEjecting, \.diskReadyToRemove, \.diskEjectFailed,
        \.diskEjectSiblingsTitleFormat, \.diskEjectSiblingsMessageFormat, \.diskProtectionCaption,
        \.diskNoExternal, \.diskOpenInFinder, \.diskStorageSettings, \.diskNoDisks, \.powerSection,
        \.powerSystem, \.powerAdapter, \.powerBattery, \.powerCharging, \.powerOnBattery, \.powerPluggedIn,
        \.powerUnavailable, \.monitorShowGPU, \.monitorShowCPUTemperature, \.monitorShowGPUTemperature,
        \.monitorShowBatteryTemperature, \.monitorShowPeripheralBattery, \.peripheralBatteryNoDevices,
        \.monitorMenuBarPresetLabel, \.menuBarPresetReadable, \.menuBarPresetDense, \.menuBarSpacingLabel,
        \.menuBarSpacingStandard, \.menuBarSpacingCompact, \.menuBarHideIconToggle, \.menuBarHideIconCaption,
        \.monitorLabelStyleLabel, \.menuBarLabelStyleCompact, \.menuBarLabelStyleClassic,
        \.monitorMemoryStyleLabel, \.monitorMemoryPressureDot, \.memoryStyleDot, \.memoryStylePercent,
        \.memoryStyleBoth, \.systemUptime, \.batteryCharge, \.powerHealth, \.powerCycles, \.speedTestRun,
        \.speedTestAgain, \.speedTestLatency, \.speedTestTesting, \.speedTestFailed, \.disclosureExpanded,
        \.disclosureCollapsed, \.panelHideItem, \.panelShowItem, \.panelHiddenItem, \.monitorItemUptime,
        \.monitorItemNetSpeed, \.monitorItemNetTotals, \.monitorItemNetTest, \.monitorItemDiskUsage,
        \.monitorItemDiskActivity, \.monitorItemDiskSMART, \.monitorItemDiskProtection,
        \.monitorItemDiskTools, \.monitorPanelConfigHint, \.monitorOrderHint,
        \.actionClear, \.actionMute, \.actionPause, \.actionSearch, \.actionUnmute, \.adminPromptClamshellOff,
        \.adminPromptRecover, \.adminPromptSudoersRemove, \.advancedUninstallFailedTitle,
        \.advancedUninstallTrashFailedBody, \.betaBadgeLabel, \.breakdownMeasuring, \.configuring, \.hour1, \.hours2,
        \.hours4, \.hours8, \.indefinite, \.indefinitely, \.largeFilesAgeLabel, \.largeFilesBackToResults,
        \.largeFilesBackToStart, \.largeFilesCancelled, \.largeFilesCaption, \.largeFilesConfirmMessageFormat,
        \.largeFilesConfirmTitle, \.largeFilesEmpty, \.largeFilesFailedFormat, \.largeFilesGroupFormat,
        \.largeFilesMovedFormat, \.largeFilesOpen, \.largeFilesQuickLook, \.largeFilesRefusedFormat,
        \.largeFilesRemove, \.largeFilesReportSummaryFormat, \.largeFilesReportTitle, \.largeFilesResultTitle,
        \.largeFilesSearch, \.largeFilesSearching, \.largeFilesSelectedFormat, \.largeFilesSettingsCaption,
        \.largeFilesSizeLabel, \.largeFilesThresholdsFormat, \.largeFilesTitle, \.minutes15, \.minutes30,
        \.powerAdapterMaxFormat, \.showCountdown, \.sudoersFailed,
    ]

    // MARK: - language coverage

    func testAppLanguageRawValuesMatchTheFifteenCodes() {
        XCTAssertEqual(AppLanguage.allCases.count, 15)
        XCTAssertEqual(Set(AppLanguage.allCases.map(\.rawValue)), Self.expectedCodes)
    }

    // MARK: - module catalogs

    func testEveryVisibleModuleKeyExistsInAllFifteenLanguages() {
        var holes: [String] = []
        var checked = 0

        for language in AppLanguage.allCases {
            let catalogs: [(String, Any)] = [
                ("appUpdates", FeatureStrings.appUpdates(language)),
                ("notch", FeatureStrings.notch(language)),
                ("maintenanceTasks", FeatureStrings.maintenanceTasks(language)),
                ("brightness", FeatureStrings.brightness(language)),
                ("killProcess", FeatureStrings.killProcess(language)),
                ("portManager", FeatureStrings.portManager(language)),
                ("screenshot", FeatureStrings.screenshot(language)),
                ("notchMusicExtras", FeatureStrings.notchMusicExtras(language)),
                ("notchActivities", FeatureStrings.notchActivities(language)),
                ("notchCalendar", FeatureStrings.notchCalendar(language)),
                ("notchWatch", FeatureStrings.notchWatch(language)),
                ("notchEditor", FeatureStrings.notchEditor(language)),
                ("notchExperience", FeatureStrings.notchExperience(language)),
                ("notchNotifications", FeatureStrings.notchNotifications(language)),
                ("notchGestures", FeatureStrings.notchGestures(language)),
                ("notchLockScreen", FeatureStrings.notchLockScreen(language)),
                ("mixer", FeatureStrings.mixer(language)),
                ("keepAwakeAutomation", FeatureStrings.keepAwakeAutomation(language)),
                ("keepAwakeDisplaySleep", FeatureStrings.keepAwakeDisplaySleep(language)),
                ("recentCaptures", FeatureStrings.recentCaptures(language)),
                ("fanControl", FeatureStrings.fanControl(language)),
                ("monitorLayout", FeatureStrings.monitorLayout(language)),
                ("batteryTime", FeatureStrings.batteryTime(language)),
                ("connectedDevices", FeatureStrings.connectedDevices(language)),
                ("mediaImageConverter", MediaImageConverterStrings.localized(language)),
                ("menuBarHiding", FeatureStrings.menuBarHiding(language)),
            ]
            for (catalog, value) in catalogs {
                for child in Mirror(reflecting: value).children {
                    guard let text = child.value as? String else { continue }
                    checked += 1
                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        holes.append("\(language.rawValue) \(catalog).\(child.label ?? "?")")
                    }
                }
            }

            let hubTitle = FeatureStrings.hub(language).titleMaintenanceTasks
            checked += 1
            if hubTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                holes.append("\(language.rawValue) hub.titleMaintenanceTasks")
            }

            for (key, text) in [("autoSaveToggleTitle", ScreenshotFeatureStrings.autoSaveToggleTitle(language)),
                                ("zoomResetAccessibilityLabel", ScreenshotFeatureStrings.zoomResetAccessibilityLabel(language))] {
                checked += 1
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    holes.append("\(language.rawValue) screenshot.\(key)")
                }
            }

            let strings = Strings.localized(language)
            for keyPath in Self.sharedStringsKeyPaths {
                checked += 1
                if strings[keyPath: keyPath].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    holes.append("\(language.rawValue) \(String(describing: keyPath))")
                }
            }
        }

        XCTAssertGreaterThan(checked, 0, "censo vazio: o teste não percorreu nenhum campo")
        XCTAssertTrue(holes.isEmpty, "campos ausentes ou vazios:\n" + holes.joined(separator: "\n"))
    }

    /// Textos de features que saíram do app não voltam por um catálogo. O
    /// nome do campo é o identificador, então o censo acima não os pegaria.
    func testRemovedFeatureStringsAreGoneFromEveryLanguage() {
        let removedStrings = [
            "previewSizeLabel", "previewSizeNormal", "previewSizeLarge",
            "previewSizeXLarge", "previewSizeSmall",
            "pastePlainName", "pastePlainCaption",
        ]
        var found: [String] = []
        for language in AppLanguage.allCases {
            for child in Mirror(reflecting: Strings.localized(language)).children {
                guard let label = child.label, removedStrings.contains(label) else { continue }
                found.append("\(language.rawValue) Strings.\(label)")
            }
            for child in Mirror(reflecting: FeatureStrings.hub(language)).children {
                guard child.label == "descPastePlain" else { continue }
                found.append("\(language.rawValue) hub.descPastePlain")
            }
        }
        XCTAssertTrue(found.isEmpty, "textos de features removidas seguem nos catálogos:\n"
            + found.joined(separator: "\n"))
    }
}
