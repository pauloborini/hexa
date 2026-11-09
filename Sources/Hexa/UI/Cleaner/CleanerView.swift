// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Quartz
import SwiftUI

/// The junk cleaner, built for one glance: a safe section that is fully
/// selected and ready for a single click, and an optional section that
/// starts unchecked and collapsed for whoever wants to dig. Every group has
/// a plain language explanation; the file by file detail lives one chevron
/// away instead of in your face. Hosted by the menu bar panel and the quick
/// panel.
struct CleanerView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var cleaner = JunkCleaner.shared
    @ObservedObject private var passGate = CleanerPassGate.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(DefaultsKey.cleanerScheduleFrequency) private var scheduleFrequencyRaw = "off"
    @AppStorage(DefaultsKey.cleanerScheduleHour) private var scheduleHour = 9
    @AppStorage(DefaultsKey.cleanerScheduleMinute) private var scheduleMinute = 0
    @AppStorage(DefaultsKey.cleanerScheduleWeekday) private var scheduleWeekday = 2
    @AppStorage(DefaultsKey.cleanerLastAutoRun) private var lastAutoRun = 0.0
    @AppStorage(DefaultsKey.cleanerLastAutoMovedToTrash) private var lastAutoMovedToTrash = 0
    @AppStorage(DefaultsKey.cleanerLastAutoFailed) private var lastAutoFailed = 0
    @AppStorage(DefaultsKey.cleanerScheduleNotify) private var scheduleNotify = true
    @AppStorage(DefaultsKey.cleanerScreenshotAgeDays)
    private var screenshotAgeDays = CleanerPolicy.defaultScreenshotAgeDays
    @AppStorage(DefaultsKey.cleanerCodingConversationAgeDays)
    private var codingConversationAgeDays = CleanerPolicy.defaultCodingConversationAgeDays
    @AppStorage(DefaultsKey.cleanerLargeFileAgeDays)
    private var largeFileAgeDays = CleanerPolicy.defaultLargeFileAgeDays
    @AppStorage(DefaultsKey.cleanerLargeFileSizeMegabytes)
    private var largeFileSizeMegabytes = CleanerPolicy.defaultLargeFileSizeMegabytes
    @ObservedObject private var scheduler = CleanerScheduler.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The panel hosted card starts folded; the Settings page shows it open.
    @State private var scheduleExpanded = false
    @State private var expandedGroups: Set<DisplayGroup.ID> = []
    /// Emptying the Trash is the Cleaner's one permanent action, so a clean
    /// that includes it asks first.
    @State private var confirmingTrash = false
    /// Where the large and old files list was opened from. Nil means the
    /// Cleaner itself is on screen. The route is view only: the Cleaner's
    /// phase, its items and their selection are never reset by opening or
    /// leaving the list, so Back lands on the exact state it was opened from.
    @State private var largeFilesOrigin: LargeFilesOrigin?
    /// Marked rows of the list. Empty when the list opens and after every
    /// search: nothing is ever marked for the user.
    @State private var largeFilesMarked: Set<String> = []
    /// True from the confirmation until the batch reports back, so a second
    /// click on the Trash, and a new search, are held instead of silently
    /// dropped. Closing the list does not clear it: the batch still runs.
    @State private var largeFilesRemovalPending = false
    @State private var confirmingLargeFilesRemoval = false
    /// Whether the space map is open from the idle screen. Like the list's route
    /// it is view only: opening it measures nothing, and leaving it stops only
    /// the reading the map was showing.
    @State private var spaceMapOpen = false
    /// Tightens paddings for the panel and launcher.
    var compact = false
    var settingsMode = false

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .onAppear {
                CleanerScheduler.shared.setSurfaceVisible(true)
            }
            .onDisappear {
                CleanerScheduler.shared.setSurfaceVisible(false)
                // Leaving the surface stops the reading: nothing keeps measuring
                // for a screen nobody sees.
                cleaner.cancelSpaceInventory()
                cleaner.cancelLargeFiles()
            }
            // Every delivered report ends the batch, even one equal to the report
            // before it, which a change of the value would miss. The first value
            // is the report already published, so it is dropped.
            .onReceive(cleaner.$largeFilesRemoval.dropFirst()) { report in
                if report != nil { largeFilesRemovalPending = false }
            }
    }

    @ViewBuilder
    private var content: some View {
        if settingsMode {
            settingsContent
        } else if largeFilesOrigin != nil {
            largeFilesScreen
        } else if spaceMapOpen {
            spaceMapScreen
        } else {
            switch cleaner.phase {
            case .idle: settingsScrolling(idleState)
            case .scanning: settingsScrolling(busyState(l10n.s.cleanerScanning, detail: scanningDetail))
            case .results: resultsState
            case .cleaning: settingsScrolling(busyState(l10n.s.cleanerCleaning, detail: nil))
            case let .done(movedToTrash, freedPermanently, failed):
                settingsScrolling(doneState(movedToTrash: movedToTrash,
                                            freedPermanently: freedPermanently, failed: failed))
            }
        }
    }

    /// On the Settings page (non-compact) every detail sits inside the
    /// workspace's scroll container; the compact panel keeps the plain
    /// layout, with each state sizing to its own content.
    @ViewBuilder
    private func settingsScrolling(_ view: some View) -> some View {
        if compact {
            view
        } else {
            OverlayScrollView {
                view
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, HexaTheme.Spacing.pageGap)
            }
        }
    }



    private var scanningDetail: String? {
        cleaner.scanningCategory.flatMap { category in
            DisplayGroup.allCases.first { $0.categories.contains(category) }
        }.map(title(for:))
    }

    // MARK: Display groups

    /// How the raw finds are presented: safe groups first, fully selected;
    /// judgment calls under optional, unchecked and collapsed.
    enum DisplayGroup: Int, CaseIterable, Identifiable {
        case loginItems, safeCaches, browserCaches, logs, developer
        case leftovers, otherCaches, browserSiteData, deviceBackups, screenshots, packageCaches, codingConversations, trash

        var id: Int { rawValue }

        var isSafe: Bool {
            switch self {
            case .loginItems, .safeCaches, .browserCaches, .logs, .developer: return true
            case .leftovers, .otherCaches, .browserSiteData, .deviceBackups, .screenshots, .packageCaches, .codingConversations, .trash:
                return false
            }
        }

        var categories: [CleanerSupport.Category] {
            switch self {
            case .loginItems: return [.loginItems]
            case .safeCaches, .otherCaches: return [.caches]
            case .browserCaches: return [.browserCaches]
            case .browserSiteData: return [.browserSiteData]
            case .logs: return [.logs]
            case .developer: return [.developer]
            case .leftovers: return [.leftovers]
            case .deviceBackups: return [.deviceBackups]
            case .screenshots: return [.screenshots]
            case .packageCaches: return [.packageCaches]
            case .codingConversations: return [.codingConversations]
            case .trash: return [.trash]
            }
        }

        var icon: String {
            switch self {
            case .loginItems: return "power"
            case .safeCaches: return "archivebox"
            case .browserCaches, .browserSiteData: return "globe"
            case .logs: return "doc.text"
            case .developer: return "hammer"
            case .leftovers: return "puzzlepiece"
            case .otherCaches: return "internaldrive"
            case .deviceBackups: return "iphone"
            case .screenshots: return "camera.viewfinder"
            case .packageCaches: return "shippingbox"
            case .codingConversations: return "bubble.left.and.bubble.right"
            case .trash: return "trash"
            }
        }
    }

    private func items(for group: DisplayGroup) -> [JunkCleaner.Item] {
        switch group {
        case .safeCaches: return cleaner.items.filter { $0.category == .caches && $0.recommended }
        case .otherCaches: return cleaner.items.filter { $0.category == .caches && !$0.recommended }
        default: return cleaner.items.filter { group.categories.contains($0.category) }
        }
    }

    private func title(for group: DisplayGroup) -> String {
        switch group {
        case .loginItems: return l10n.s.cleanerCatLoginItems
        case .safeCaches: return l10n.s.cleanerCatCaches
        case .browserCaches: return l10n.s.cleanerCatBrowserCaches
        case .logs: return l10n.s.cleanerCatLogs
        case .developer: return l10n.s.cleanerCatDeveloper
        case .leftovers: return l10n.s.cleanerCatLeftovers
        case .otherCaches: return l10n.s.cleanerCatOtherCaches
        case .browserSiteData: return l10n.s.cleanerCatBrowserSiteData
        case .deviceBackups: return l10n.s.cleanerCatDeviceBackups
        case .screenshots: return l10n.s.cleanerCatScreenshots
        case .packageCaches: return l10n.s.cleanerCatPackageCaches
        case .codingConversations: return l10n.s.cleanerCatCodingConversations
        case .trash: return l10n.s.cleanerCatTrash
        }
    }

    private func caption(for group: DisplayGroup) -> String {
        switch group {
        case .loginItems: return l10n.s.cleanerLoginItemsCaption
        case .safeCaches: return l10n.s.cleanerCachesCaption
        case .browserCaches: return l10n.s.cleanerBrowserCachesCaption
        case .logs: return l10n.s.cleanerLogsCaption
        case .developer: return l10n.s.cleanerDeveloperCaption
        case .leftovers: return l10n.s.cleanerLeftoversCaption
        case .otherCaches: return l10n.s.cleanerOtherCachesCaption
        case .browserSiteData: return l10n.s.cleanerBrowserSiteDataCaption
        case .deviceBackups: return l10n.s.cleanerDeviceBackupsCaption
        case .screenshots:
            return String(format: l10n.s.cleanerScreenshotsCaptionFormat,
                          CleanerPolicy.sanitizedScreenshotAgeDays(screenshotAgeDays))
        case .packageCaches: return l10n.s.cleanerPackageCachesCaption
        case .codingConversations:
            return String(format: l10n.s.cleanerCodingConversationsCaptionFormat,
                          CleanerPolicy.sanitizedScreenshotAgeDays(codingConversationAgeDays))
        case .trash: return l10n.s.cleanerTrashNote
        }
    }

    // MARK: Idle

    private var idleState: some View {
        Group {
            if compact {
                compactIdleState
            } else {
                workspaceIdleState
            }
        }
    }

    // MARK: Settings Mode

    private var settingsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.l) {
                scheduleSection
                screenshotsSection
                codingConversationsSection
                largeFilesThresholdsSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, HexaTheme.Spacing.pageGap)
        }
    }

    private var scheduleSection: some View {
        HexaSection(l10n.s.cleanerAutomationSection) {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.m) {
                HStack(spacing: HexaTheme.Spacing.s) {
                    HexaIcons.image("clock").foregroundStyle(HexaTheme.fgSecondary)
                    Text(l10n.s.cleanerScheduleTitle)
                        .font(.hexa(.body))
                    Spacer()
                    frequencyPicker
                }
                if scheduleFrequency != .off {
                    HairlineDivider()
                    scheduleDetails
                }
                Text(l10n.s.cleanerScheduleCaption)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .modifier(ScheduleChangeSync(notify: $scheduleNotify,
                                         frequency: $scheduleFrequencyRaw,
                                         hour: $scheduleHour,
                                         minute: $scheduleMinute,
                                         weekday: $scheduleWeekday))
        }
    }

    private var screenshotsSection: some View {
        HexaSection(l10n.s.cleanerAutoOrganizeSection) {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.m) {
                HStack(spacing: HexaTheme.Spacing.s) {
                    HexaIcons.image("camera.viewfinder").foregroundStyle(HexaTheme.fgSecondary)
                    Text(l10n.s.cleanerCatScreenshots)
                        .font(.hexa(.body))
                    Spacer()
                    Picker("", selection: $screenshotAgeDays) {
                        ForEach(screenshotAgeChoices, id: \.self) { days in
                            Text(days == 0
                                 ? l10n.s.cleanerScheduleOff
                                 : String(format: l10n.s.cleanerScreenshotsAfterFormat, days))
                                .tag(days)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                Text(l10n.s.cleanerScreenshotsSettingCaption)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Claude Code conversations by age, with the same picker as the
    /// screenshots. Nothing is listed until a manual scan runs, and nothing
    /// is ever checked by default.
    private var codingConversationsSection: some View {
        HexaSection(l10n.s.cleanerCatCodingConversations) {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.m) {
                HStack(spacing: HexaTheme.Spacing.s) {
                    HexaIcons.image(DisplayGroup.codingConversations.icon).foregroundStyle(HexaTheme.fgSecondary)
                    Text(l10n.s.cleanerCodingConversationAgeLabel)
                        .font(.hexa(.body))
                    Spacer()
                    Picker("", selection: $codingConversationAgeDays) {
                        ForEach(codingConversationAgeChoices, id: \.self) { days in
                            Text(days == 0
                                 ? l10n.s.cleanerScheduleOff
                                 : String(format: l10n.s.cleanerScreenshotsAfterFormat, days))
                                .tag(days)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                Text(l10n.s.cleanerCodingConversationsRisk)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The two figures that make a file "large and old", as the panel and the
    /// page already show the screenshot age. The search reads the saved choice
    /// when it starts, so the next search follows what is chosen here.
    private var largeFilesThresholdsSection: some View {
        HexaSection(l10n.s.largeFilesTitle) {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.m) {
                HStack(spacing: HexaTheme.Spacing.s) {
                    HexaIcons.image("calendar")
                        .foregroundStyle(HexaTheme.fgSecondary)
                    Text(l10n.s.largeFilesAgeLabel)
                        .font(.hexa(.body))
                    Spacer()
                    Picker("", selection: $largeFileAgeDays) {
                        ForEach(CleanerPolicy.largeFileAgeChoices, id: \.self) { days in
                            Text(String(format: l10n.s.cleanerScreenshotsAfterFormat, days))
                                .tag(days)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                HairlineDivider()
                HStack(spacing: HexaTheme.Spacing.s) {
                    HexaIcons.image("internaldrive")
                        .foregroundStyle(HexaTheme.fgSecondary)
                    Text(l10n.s.largeFilesSizeLabel)
                        .font(.hexa(.body))
                    Spacer()
                    Picker("", selection: $largeFileSizeMegabytes) {
                        ForEach(CleanerPolicy.largeFileSizeChoicesMegabytes, id: \.self) { megabytes in
                            Text(Self.largeFileSizeLabel(megabytes)).tag(megabytes)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                Text(l10n.s.largeFilesSettingsCaption)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The offered sizes written as the fixed choices read: 100 MB, 500 MB,
    /// 1 GB and 5 GB. The measured sizes keep the app's own byte string.
    private static func largeFileSizeLabel(_ megabytes: Int) -> String {
        largeFileSizeFormatter.string(fromByteCount: Int64(megabytes) * LargeFiles.Thresholds.megabyte)
    }

    private static let largeFileSizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.isAdaptive = false
        return formatter
    }()

    /// Where the large and old files list was opened from. It is remembered so
    /// Back returns there and says where it goes.
    enum LargeFilesOrigin: Hashable {
        case idle, results
    }

    /// What the list shows for a published result. Pure, so the surface and the
    /// test agree on the state without reading the body of the view. A running
    /// search is never a result. The empty headline is only for a finished
    /// search with nothing found, nothing refused and no cancel: a refusal or a
    /// cancel is shown as such, never as an empty result.
    enum LargeFilesListState: Equatable {
        case searching, empty, refused, cancelled, listing
    }

    static func largeFilesListState(isComputing: Bool,
                                    result: LargeFiles.SearchResult?) -> LargeFilesListState {
        if isComputing { return .searching }
        // No published result yet: a list without rows, never the empty headline.
        guard let result else { return .listing }
        if !result.candidates.isEmpty { return .listing }
        if !result.denied.isEmpty { return .refused }
        if result.cancelled { return .cancelled }
        return .empty
    }

    /// The Trash is offered only when something is marked and nothing else is
    /// running: a search in flight can still replace the list, and a batch in
    /// flight would drop a second click without telling the user.
    static func largeFilesRemovalIsDisabled(marked: Int, isComputing: Bool,
                                            isRemovalPending: Bool) -> Bool {
        marked == 0 || isComputing || isRemovalPending
    }

    /// Off plus the offered ages, and the stored value when it came from
    /// elsewhere (a restored backup) and is not one of them.
    private var codingConversationAgeChoices: [Int] {
        var choices = CleanerPolicy.screenshotAgeChoices
        let current = CleanerPolicy.sanitizedScreenshotAgeDays(codingConversationAgeDays)
        if current > 0, !choices.contains(current) {
            choices.append(current)
            choices.sort()
        }
        return [0] + choices
    }

    private var workspaceIdleState: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xxl) {
            HexaCard {
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.m) {
                    Text(l10n.s.cleanerIntroCaption)
                        .font(.hexa(.body))
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(l10n.s.cleanerScan) { cleaner.scan(attended: true) }
                        .controlSize(.regular)
                        .buttonStyle(HexaActionButtonStyle())
                        .disabled(passGate.holder == .automatic)

                    if passGate.holder == .automatic {
                        automaticRunLine
                    }

                    HairlineDivider()
                    largeFilesEntry(from: .idle)
                    HairlineDivider()
                    spaceMapEntry

                    if !permissions.fullDiskAccess {
                        HairlineDivider()
                        FullDiskAccessNote(compact: false)
                    }
                }
            }
        }
    }

    private var compactIdleState: some View {
        VStack(spacing: HexaTheme.Spacing.m) {
            Text(l10n.s.cleanerIntroTitle)
                .font(.hexa(.heading))
            Text(l10n.s.cleanerIntroCaption)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 380)
            Button(l10n.s.cleanerScan) { cleaner.scan(attended: true) }
                .controlSize(.large)
                .buttonStyle(HexaActionButtonStyle())
                .disabled(passGate.holder == .automatic)
            if passGate.holder == .automatic {
                automaticRunLine
            }
            largeFilesEntry(from: .idle)
                .frame(maxWidth: 380)
            spaceMapEntry
                .frame(maxWidth: 380)
            scheduleCard
            screenshotsCard
            if !permissions.fullDiskAccess {
                FullDiskAccessNote(compact: compact).frame(maxWidth: 380)
            }
        }
        .padding(HexaTheme.Spacing.m)
        .frame(maxWidth: .infinity)
    }

    /// Shown while the scheduled pass holds the gate. The manual scan waits
    /// for it, and Abort all ends it.
    private var automaticRunLine: some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            ProgressView()
                .controlSize(.small)
            Text(l10n.s.cleanerAutoRunning)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
            Spacer(minLength: HexaTheme.Spacing.s)
            Button(l10n.s.cleanerAbortAll) { scheduler.abortAutomaticRun() }
                .buttonStyle(HexaActionButtonStyle())
        }
        .frame(maxWidth: 380)
    }

    // MARK: Forgotten screenshots

    /// Off plus the offered ages, and the stored value when it came from
    /// elsewhere (a restored backup) and is not one of them.
    private var screenshotAgeChoices: [Int] {
        var choices = CleanerPolicy.screenshotAgeChoices
        let current = CleanerPolicy.sanitizedScreenshotAgeDays(screenshotAgeDays)
        if current > 0, !choices.contains(current) {
            choices.append(current)
            choices.sort()
        }
        return [0] + choices
    }

    /// How old an untouched screenshot must be to be listed, or off. The
    /// Settings page explains it; the panel keeps it to one line.
    private var screenshotsCard: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            HStack(spacing: HexaTheme.Spacing.s) {
                HexaIcons.image("camera.viewfinder").foregroundStyle(HexaTheme.fgSecondary)
                Text(l10n.s.cleanerCatScreenshots)
                    .font(.hexa(.body))
                Spacer()
                Picker("", selection: $screenshotAgeDays) {
                    ForEach(screenshotAgeChoices, id: \.self) { days in
                        Text(days == 0
                             ? l10n.s.cleanerScheduleOff
                             : String(format: l10n.s.cleanerScreenshotsAfterFormat, days))
                            .tag(days)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
            if !compact {
                Text(l10n.s.cleanerScreenshotsSettingCaption)
                    .font(.hexa(.micro))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(HexaTheme.Spacing.l)
        .frame(maxWidth: 380)
        .hexaCardSurface(increaseContrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast)
    }

    // MARK: Automatic cleanup

    private var scheduleFrequency: CleanerSchedule.Frequency {
        CleanerSchedule.Frequency.sanitized(scheduleFrequencyRaw)
    }

    /// Whether the user's clock runs on twelve hours (6 PM) or twenty four
    /// (18:00); the pickers follow whatever the Mac is set to.
    private static let uses12HourClock: Bool = {
        let format = DateFormatter.dateFormat(fromTemplate: "j", options: 0,
                                              locale: Locale.current) ?? ""
        return format.contains("a")
    }()

    private static let dayPeriodSymbols: (am: String, pm: String) = {
        let formatter = DateFormatter()
        return (formatter.amSymbol ?? "AM", formatter.pmSymbol ?? "PM")
    }()

    /// The stored hour split for the twelve hour pickers: hour, then
    /// minutes, then AM or PM.
    private var scheduleHour12Binding: Binding<Int> {
        Binding(
            get: { CleanerSchedule.hour12Components(fromHour24: scheduleHour).hour12 },
            set: { newValue in
                let isPM = CleanerSchedule.hour12Components(fromHour24: scheduleHour).isPM
                scheduleHour = CleanerSchedule.hour24(hour12: newValue, isPM: isPM)
            }
        )
    }

    private var schedulePMBinding: Binding<Bool> {
        Binding(
            get: { CleanerSchedule.hour12Components(fromHour24: scheduleHour).isPM },
            set: { isPM in
                let hour12 = CleanerSchedule.hour12Components(fromHour24: scheduleHour).hour12
                scheduleHour = CleanerSchedule.hour24(hour12: hour12, isPM: isPM)
            }
        )
    }

    /// Five minute steps, plus the stored value when it falls off the grid.
    private var minuteChoices: [Int] {
        var minutes = Array(stride(from: 0, through: 55, by: 5))
        if !minutes.contains(scheduleMinute), (0...59).contains(scheduleMinute) {
            minutes.append(scheduleMinute)
            minutes.sort()
        }
        return minutes
    }

    private static let nextRunFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    private var scheduleSummary: String {
        switch scheduleFrequency {
        case .off: return l10n.s.cleanerScheduleOff
        case .daily: return l10n.s.cleanerScheduleDaily
        case .weekly: return l10n.s.cleanerScheduleWeekly
        }
    }

    private var frequencyPicker: some View {
        Picker("", selection: $scheduleFrequencyRaw) {
            Text(l10n.s.cleanerScheduleOff).tag(CleanerSchedule.Frequency.off.rawValue)
            Text(l10n.s.cleanerScheduleDaily).tag(CleanerSchedule.Frequency.daily.rawValue)
            Text(l10n.s.cleanerScheduleWeekly).tag(CleanerSchedule.Frequency.weekly.rawValue)
        }
        .labelsHidden()
        .fixedSize()
    }

    /// The schedule in one small card: a frequency and, once it is on, the
    /// weekday and time as plain menus, a live "next cleanup" line proving
    /// the schedule armed, and the notification choice with its permission
    /// state in the open. Hosted in the panels the card folds to one quiet
    /// line with the current state; the Settings page shows it whole.
    @ViewBuilder
    private var scheduleCard: some View {
        if compact {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    var transaction = Transaction(animation: nil)
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        scheduleExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: HexaTheme.Spacing.s) {
                        HexaIcons.image(scheduleExpanded ? "chevron.down" : "chevron.right", size: 10)
                            .font(.hexa(.micro))
                            .foregroundStyle(HexaTheme.fgSecondary)
                            .frame(width: 9)
                        HexaIcons.image("clock").foregroundStyle(HexaTheme.fgSecondary)
                        Text(l10n.s.cleanerScheduleTitle)
                            .font(.hexa(.body))
                        Spacer()
                        Text(scheduleSummary)
                            .font(.hexa(.micro))
                            .foregroundStyle(HexaTheme.fgSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(HexaTheme.Spacing.m)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if scheduleExpanded {
                    VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                        HStack { frequencyPicker; Spacer() }
                        scheduleDetails
                        Text(l10n.s.cleanerScheduleCaption)
                            .font(.hexa(.micro))
                            .foregroundStyle(HexaTheme.fgSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, HexaTheme.Spacing.m)
                    .padding(.top, HexaTheme.Spacing.xs)
                    .padding(.bottom, HexaTheme.Spacing.m)
                }
            }
            .frame(maxWidth: 380)
            .hexaCardSurface(increaseContrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast)
            .modifier(ScheduleChangeSync(notify: $scheduleNotify,
                                         frequency: $scheduleFrequencyRaw,
                                         hour: $scheduleHour,
                                         minute: $scheduleMinute,
                                         weekday: $scheduleWeekday))
        } else {
            fullScheduleCard
        }
    }

    private var fullScheduleCard: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            HStack(spacing: HexaTheme.Spacing.s) {
                HexaIcons.image("clock").foregroundStyle(HexaTheme.fgSecondary)
                Text(l10n.s.cleanerScheduleTitle)
                    .font(.hexa(.body))
                Spacer()
                frequencyPicker
            }
            scheduleDetails
            Text(l10n.s.cleanerScheduleCaption)
                .font(.hexa(.micro))
                .foregroundStyle(HexaTheme.fgSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(HexaTheme.Spacing.l)
        .frame(maxWidth: 380)
        .hexaCardSurface(increaseContrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast)
        .modifier(ScheduleChangeSync(notify: $scheduleNotify,
                                     frequency: $scheduleFrequencyRaw,
                                     hour: $scheduleHour,
                                     minute: $scheduleMinute,
                                     weekday: $scheduleWeekday))
    }

    @ViewBuilder
    private var scheduleDetails: some View {
        if scheduleFrequency != .off {
                // The menu panel is too narrow for the weekday beside the time
                // in most languages, and a row wider than the panel shifts all
                // of its content past the left edge, so the weekday then takes
                // its own row.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: HexaTheme.Spacing.xs) {
                        weekdayPicker
                        timePickers
                        Spacer()
                    }
                    VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                        weekdayPicker
                        HStack(spacing: HexaTheme.Spacing.xs) {
                            timePickers
                            Spacer()
                        }
                    }
                }
                Toggle(l10n.s.cleanerScheduleNotifyToggle, isOn: $scheduleNotify)
                    .toggleStyle(.checkbox)
                    .font(.hexa(.label))
                if scheduleNotify, permissions.notifications == .denied {
                    Text(l10n.s.cleanerNotifDenied)
                        .font(.hexa(.micro))
                        .foregroundStyle(HexaTheme.statusWarning)
                        .fixedSize(horizontal: false, vertical: true)
                    HexaAccessButton(icon: "gearshape",
                                     title: l10n.s.cleanerNotifOpenSettings,
                                     action: {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                            NSWorkspace.shared.open(url)
                        }
                    })
                }
                if let next = scheduler.nextFire {
                    Text(String(format: l10n.s.cleanerScheduleNextFormat,
                                Self.nextRunFormatter.string(from: next)))
                        .font(.hexa(.micro))
                        .foregroundStyle(HexaTheme.fgSecondary)
                }
                if scheduler.postponedSince != nil {
                    Text(l10n.s.cleanerSchedulePostponed)
                        .font(.hexa(.micro))
                        .foregroundStyle(HexaTheme.statusWarning)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if lastAutoRun > 0 {
                    Text(lastRunLine)
                        .font(.hexa(.micro))
                        .foregroundStyle(HexaTheme.fgTertiary)
                }
        }
    }

    @ViewBuilder
    private var weekdayPicker: some View {
        if scheduleFrequency == .weekly {
            Picker("", selection: $scheduleWeekday) {
                ForEach(1...7, id: \.self) { day in
                    Text(Calendar.current.standaloneWeekdaySymbols[day - 1].capitalized)
                        .tag(day)
                }
            }
            .labelsHidden()
            .fixedSize()
        }
    }

    /// The hour, the minutes and, on a twelve hour clock, AM or PM.
    @ViewBuilder
    private var timePickers: some View {
        if Self.uses12HourClock {
            Picker("", selection: scheduleHour12Binding) {
                ForEach(1...12, id: \.self) { hour in
                    Text(String(hour)).tag(hour)
                }
            }
            .labelsHidden()
            .fixedSize()
        } else {
            Picker("", selection: $scheduleHour) {
                ForEach(0..<24, id: \.self) { hour in
                    Text(String(hour)).tag(hour)
                }
            }
            .labelsHidden()
            .fixedSize()
        }
        Picker("", selection: $scheduleMinute) {
            ForEach(minuteChoices, id: \.self) { minute in
                Text(String(format: ":%02d", minute)).tag(minute)
            }
        }
        .labelsHidden()
        .fixedSize()
        if Self.uses12HourClock {
            Picker("", selection: schedulePMBinding) {
                Text(Self.dayPeriodSymbols.am).tag(false)
                Text(Self.dayPeriodSymbols.pm).tag(true)
            }
            .labelsHidden()
            .fixedSize()
        }
    }

    /// The schedule card's reactions, shared by the folded and full forms:
    /// keep the scheduler armed with the latest picks and ask for notification
    /// permission on opt in. The answer arrives through
    /// `Permissions.notifications`, which the request itself refreshes.
    private struct ScheduleChangeSync: ViewModifier {
        @Binding var notify: Bool
        @Binding var frequency: String
        @Binding var hour: Int
        @Binding var minute: Int
        @Binding var weekday: Int

        func body(content: Content) -> some View {
            content
                .onChange(of: frequency) { _, picked in
                    CleanerScheduler.shared.syncWithPreferences()
                    // The notice ships on, so arming a schedule is where the
                    // permission is asked; a decided one shows no prompt.
                    if notify, picked != CleanerSchedule.Frequency.off.rawValue {
                        Permissions.shared.requestNotifications()
                    }
                }
                .onChange(of: hour) { _, _ in CleanerScheduler.shared.syncWithPreferences() }
                .onChange(of: minute) { _, _ in CleanerScheduler.shared.syncWithPreferences() }
                .onChange(of: weekday) { _, _ in CleanerScheduler.shared.syncWithPreferences() }
                .onChange(of: notify) { _, wanted in
                    if wanted { Permissions.shared.requestNotifications() }
                }
        }
    }

    private var lastRunLine: String {
        let ranAt = Self.nextRunFormatter.string(from: Date(timeIntervalSince1970: lastAutoRun))
        let line = lastAutoMovedToTrash > 0
            ? String(format: l10n.s.cleanerScheduleLastFormat, Self.byteString(Int64(lastAutoMovedToTrash)))
            : String(format: l10n.s.cleanerScheduleRanFormat, ranAt)
        // A pass that moved nothing still reads as a normal run unless what it left is said.
        return lastAutoFailed > 0 ? line + " " + l10n.s.uninstallerSomeFailed : line
    }

    // MARK: Busy

    /// Scanning and cleaning share one exit: Abort all ends the pass at once.
    private func busyState(_ message: String, detail: String?) -> some View {
        HexaBusyState(
            variant: compact ? .compact : .workspace,
            message: message,
            detail: detail,
            actionTitle: l10n.s.cleanerAbortAll,
            action: { cleaner.reset() }
        )
    }

    // MARK: Results

    private var resultsState: some View {
        VStack(spacing: 0) {
            resultsHeader
            HairlineDivider()
            OverlayScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if cleaner.items.isEmpty && !cleaner.browserAccessPending {
                        VStack(spacing: HexaTheme.Spacing.s) {
                            HexaIcons.image("checkmark.seal", size: 34)
                                .foregroundStyle(HexaTheme.statusOk)
                            Text(l10n.s.cleanerNothingFound)
                                .font(.hexa(.body))
                                .foregroundStyle(HexaTheme.fgSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, HexaTheme.Spacing.l)
                    }
                    if cleaner.browserAccessPending {
                        FullDiskAccessNote(compact: compact, reason: l10n.s.cleanerBrowserAccessPendingReason)
                            .padding(.vertical, HexaTheme.Spacing.s)
                    }
                    section(l10n.s.cleanerSafeSection, groups: DisplayGroup.allCases.filter(\.isSafe))
                    section(l10n.s.cleanerOptionalSection, groups: DisplayGroup.allCases.filter { !$0.isSafe })
                    largeFilesEntry(from: .results)
                        .padding(HexaTheme.Spacing.m)
                        .hexaSectionCard(padded: false)
                        .padding(.bottom, HexaTheme.Spacing.s)
                    spaceInventorySection
                }
                .padding(.horizontal, HexaTheme.Spacing.l)
                .padding(.bottom, HexaTheme.Spacing.pageGap)
            }
            // The LazyVStack paints no background, so the panel keeps its
            // translucent material (the old `.scrollContentBackground`
            // semantics) without the list's indicator over the content.
            .frame(maxWidth: .infinity, minHeight: compact ? 280 : 0, maxHeight: .infinity)
            if !cleaner.items.isEmpty {
                HairlineDivider()
                resultsFooter
            }
        }
    }

    private var resultsHeader: some View {
        HStack(spacing: HexaTheme.Spacing.m) {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                Text(l10n.s.cleanerName).font(.hexa(.heading))
                Text("\(Self.byteString(cleaner.totalSize)) \(l10n.s.uninstallerFoundTitle)")
                    .font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
            }
            Spacer()
            HexaIconButton(icon: "xmark.circle.fill",
                           label: l10n.s.uninstallerCancel,
                           variant: .regular,
                           action: { cleaner.reset() })
        }
        .padding(compact ? HexaTheme.Spacing.m : HexaTheme.Spacing.l)
    }

    @ViewBuilder
    private func section(_ header: String, groups: [DisplayGroup]) -> some View {
        let visible = groups.filter { !items(for: $0).isEmpty }
        if !visible.isEmpty {
            Section {
                ForEach(visible) { group in groupRow(group) }
            } header: {
                sectionTitle(header)
                    .padding(.top, HexaTheme.Spacing.s)
                    .padding(.bottom, HexaTheme.Spacing.xs)
            }
        }
    }

    private func isGroupExpanded(_ group: DisplayGroup) -> Bool {
        expandedGroups.contains(group.id)
    }

    private func toggleGroupExpanded(_ group: DisplayGroup) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            if expandedGroups.contains(group.id) {
                expandedGroups.remove(group.id)
            } else {
                expandedGroups.insert(group.id)
            }
        }
    }

    private func groupRow(_ group: DisplayGroup) -> some View {
        let group_items = items(for: group)
        let isExpanded = isGroupExpanded(group)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                Button {
                    toggleGroupExpanded(group)
                } label: {
                    HexaIcons.image("chevron.right", size: 10)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 12, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, HexaTheme.Spacing.s)
                .padding(.top, 2)
                .accessibilityValue(isExpanded ? l10n.s.disclosureExpanded : l10n.s.disclosureCollapsed)

                Toggle("", isOn: groupBinding(group))
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                    .padding(.top, 1)
                    .padding(.trailing, HexaTheme.Spacing.s)

                Button {
                    toggleGroupExpanded(group)
                } label: {
                    HStack(alignment: .top, spacing: HexaTheme.Spacing.s) {
                        HexaIcons.image(group.icon, size: 14)
                            .foregroundStyle(HexaTheme.fgSecondary)
                            .frame(width: 20)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                            Text(title(for: group)).font(.hexa(.body))
                            Text(caption(for: group))
                                .font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Text(Self.byteString(group_items.reduce(0) { $0 + $1.size }))
                            .font(.hexa(.data)).foregroundStyle(HexaTheme.fgSecondary).monospacedDigit()
                            .padding(.top, 2)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, HexaTheme.Spacing.xs)

            if isExpanded {
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                    if group == .leftovers {
                        Text(l10n.s.cleanerLeftoversNote)
                            .font(.hexa(.micro))
                            .foregroundStyle(HexaTheme.statusWarning)
                    }
                    if group == .loginItems {
                        Text(l10n.s.cleanerLoginItemsNote)
                            .font(.hexa(.micro))
                            .foregroundStyle(HexaTheme.fgSecondary)
                    }
                    if group == .codingConversations {
                        Text(l10n.s.cleanerCodingConversationsRisk)
                            .font(.hexa(.micro))
                            .foregroundStyle(HexaTheme.statusWarning)
                    }
                    ForEach(group_items) { item in itemRow(item) }
                }
                .padding(.leading, 12 + HexaTheme.Spacing.s)
                .padding(.bottom, HexaTheme.Spacing.xs)
                .transition(reduceMotion ? .identity : .opacity)
            }
        }
        // Cartão leve por grupo: o acordeão fica dentro do mesmo cartão. Usa o
        // desenho de superfície do hexa com respiro próprio (sem o 16 do cartão
        // de página) para os grupos não ficarem grudados nem aninhados demais.
        .padding(.horizontal, HexaTheme.Spacing.m)
        .padding(.vertical, HexaTheme.Spacing.xs)
        .hexaSectionCard(padded: false)
        .padding(.bottom, HexaTheme.Spacing.s)
    }

    private func itemRow(_ item: JunkCleaner.Item) -> some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            Toggle("", isOn: includeBinding(item)).labelsHidden().toggleStyle(.checkbox)
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                Text(item.name).font(.hexa(.label)).lineLimit(1).truncationMode(.middle)
                Text(prettyPath(item.url))
                    .font(.hexa(.label)).foregroundStyle(HexaTheme.fgTertiary)
                    .lineLimit(1).truncationMode(.head)
            }
            Spacer()
            Text(Self.byteString(item.size))
                .font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
                .monospacedDigit()
        }
        .padding(.leading, HexaTheme.Spacing.s)
        .padding(.vertical, 1) // geometria de plataforma (spec §4): densidade de linha de lista
        .contextMenu {
            Button(l10n.s.cleanerRevealInFinder) {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }
        }
    }

    /// "Onde está o espaço": informational only. The volume figures, the ranking
    /// of the largest folders, the refused paths and the estimated system data
    /// are measured on request and fill in folder by folder. The fixed block of
    /// known locations stays below them, unchanged. Nothing here has a checkbox
    /// and nothing here removes: the map only reads.
    private var spaceInventorySection: some View {
        Section {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                spaceInventoryVolume
                spaceInventoryMeasured
                spaceInventoryMeasureControl
                if let map = cleaner.spaceMap {
                    spaceInventoryRanking(map)
                    spaceInventoryDenials(map)
                    spaceInventoryNotes(map)
                }
                spaceInventoryFixedBlock
            }
            .padding(.bottom, HexaTheme.Spacing.s)
        } header: {
            sectionTitle(l10n.s.spaceInventoryTitle)
                .padding(.top, HexaTheme.Spacing.s)
                .padding(.bottom, HexaTheme.Spacing.xs)
        }
    }

    /// Total, free and used of the home volume. A read that failed says so and
    /// shows no zero.
    @ViewBuilder
    private var spaceInventoryVolume: some View {
        if let volume = cleaner.spaceMap?.volume {
            if let total = volume.total, let free = volume.free, let used = volume.used {
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                    spaceInventoryFigure(l10n.s.spaceInventoryVolumeTotal, total)
                    spaceInventoryFigure(l10n.s.spaceInventoryVolumeFree, free)
                    spaceInventoryFigure(l10n.s.spaceInventoryVolumeUsed, used)
                    if volume.lowSpace {
                        Text(l10n.s.spaceInventoryLowSpace)
                            .font(.hexa(.micro))
                            .foregroundStyle(HexaTheme.statusWarning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                Text(l10n.s.spaceInventoryVolumeUnavailable)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func spaceInventoryFigure(_ label: String, _ bytes: Int64) -> some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            Text(label)
                .font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
            Spacer()
            Text(Self.byteString(bytes))
                .font(.hexa(.label)).foregroundStyle(HexaTheme.fgPrimary)
                .monospacedDigit()
        }
    }

    /// The measured total: the sum of the folders the map shows. It sits apart
    /// from the volume figures, which describe the volume and not what was
    /// measured, and it appears once a map exists.
    @ViewBuilder
    private var spaceInventoryMeasured: some View {
        if let map = cleaner.spaceMap {
            spaceInventoryFigure(l10n.s.spaceInventoryMeasuredTotal, map.measuredTotal)
                .padding(.top, HexaTheme.Spacing.xs)
        }
    }

    /// The ten largest measured folders, largest first. A folder whose contents
    /// could not be read in full carries the partial mark. On low space the three
    /// largest carry the warning color on their size, as the low-space note says.
    @ViewBuilder
    private func spaceInventoryRanking(_ map: SpaceMap) -> some View {
        if !map.ranking.isEmpty {
            let highlightCount = map.volume.lowSpace ? 3 : 0
            Text(l10n.s.spaceInventoryRankingTitle)
                .font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
                .padding(.top, HexaTheme.Spacing.xs)
            ForEach(Array(map.ranking.enumerated()), id: \.element.id) { index, entry in
                HStack(spacing: HexaTheme.Spacing.s) {
                    VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                        Text(entry.url.lastPathComponent)
                            .font(.hexa(.body))
                        Text(abbreviateHome(entry.url))
                            .font(.hexa(.label)).foregroundStyle(HexaTheme.fgTertiary)
                            .lineLimit(1).truncationMode(.head)
                    }
                    Spacer()
                    if entry.partial {
                        Text(l10n.s.spaceInventoryPartialMark)
                            .font(.hexa(.micro)).foregroundStyle(HexaTheme.statusWarning)
                    }
                    Text(Self.byteString(entry.size))
                        .font(.hexa(.label))
                        .foregroundStyle(index < highlightCount ? HexaTheme.statusWarning : HexaTheme.fgSecondary)
                        .monospacedDigit()
                }
                .padding(.vertical, HexaTheme.Spacing.xs)
            }
        }
    }

    /// The paths the walk could not read, each with the reason it failed.
    @ViewBuilder
    private func spaceInventoryDenials(_ map: SpaceMap) -> some View {
        ForEach(map.denials) { denial in
            Text(String(format: l10n.s.spaceInventoryDeniedFormat,
                        abbreviateHome(denial.url),
                        spaceInventoryDenialReason(denial.reason)))
                .font(.hexa(.micro)).foregroundStyle(HexaTheme.statusWarning)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The cancelled mark, the estimated system data with its coverage note and
    /// the empty result. The empty result is said only when nothing was measured
    /// or refused and no cancel ended the walk: a cancel has its own mark. The
    /// estimate is Hexa's own sum and never the volume's residual.
    @ViewBuilder
    private func spaceInventoryNotes(_ map: SpaceMap) -> some View {
        if map.cancelled {
            Text(l10n.s.spaceInventoryCancelled)
                .font(.hexa(.micro)).foregroundStyle(HexaTheme.statusWarning)
                .fixedSize(horizontal: false, vertical: true)
        }
        if let summary = map.systemData {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                HStack(spacing: HexaTheme.Spacing.s) {
                    Text(l10n.s.spaceInventorySummaryTitle)
                        .font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
                    Spacer()
                    Text(Self.byteString(summary.size))
                        .font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
                        .monospacedDigit()
                }
                if summary.partial {
                    Text(l10n.s.spaceInventorySummaryPartial)
                        .font(.hexa(.micro)).foregroundStyle(HexaTheme.fgTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, HexaTheme.Spacing.xs)
        }
        if map.isEmpty, !map.cancelled {
            Text(l10n.s.spaceInventoryEmpty)
                .font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The fixed block of known locations, unchanged: same legend, same rows,
    /// same group captions and the same simulator notice, now below the ranking.
    private var spaceInventoryFixedBlock: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            Text(l10n.s.spaceInventoryLegend)
                .hexaCaption()
            ForEach(SpaceInventory.Group.allCases, id: \.self) { group in
                let lines = spaceInventoryLines.filter { $0.location.group == group }
                if !lines.isEmpty {
                    if let caption = spaceInventoryGroupCaption(group) {
                        Text(caption)
                            .font(.hexa(.label))
                            .foregroundStyle(HexaTheme.fgSecondary)
                    }
                    ForEach(lines) { line in spaceInventoryRow(line) }
                }
            }
        }
        .padding(.top, HexaTheme.Spacing.xs)
    }

    private func spaceInventoryDenialReason(_ reason: SpaceMapDenial.Reason) -> String {
        switch reason {
        case .accessDenied: return l10n.s.spaceInventoryDeniedAccess
        case .unavailable: return l10n.s.spaceInventoryDeniedUnavailable
        }
    }

    private func abbreviateHome(_ url: URL) -> String {
        url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    /// One line of the section. `size` is nil until the user measures.
    private struct SpaceInventoryLine: Identifiable {
        let location: SpaceInventory.Location
        let url: URL
        let size: Int64?

        var id: SpaceInventory.Location { location }
    }

    /// The measured rows once "Calcular" has run; otherwise every fixed
    /// location by its path, with no sizes and no disk read.
    private var spaceInventoryLines: [SpaceInventoryLine] {
        if let rows = cleaner.spaceInventory {
            return rows.map { SpaceInventoryLine(location: $0.location, url: $0.url, size: $0.size) }
        }
        let home = NSHomeDirectory()
        return SpaceInventory.Location.allCases.map {
            SpaceInventoryLine(location: $0, url: SpaceInventory.url(for: $0, home: home), size: nil)
        }
    }

    /// Runs the measurement once per press. The spinner shows while it runs;
    /// nothing starts by itself.
    private var spaceInventoryMeasureControl: some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            Button(l10n.s.spaceInventoryMeasure) { cleaner.measureSpaceInventory() }
                .buttonStyle(HexaActionButtonStyle())
                .disabled(cleaner.spaceInventoryIsComputing)
            if cleaner.spaceInventoryIsComputing {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(l10n.s.breakdownMeasuring)
                // Stops only the measurement: the reviewed list stays as it is.
                Button(l10n.s.uninstallerCancel) { cleaner.cancelSpaceInventory() }
                    .buttonStyle(HexaActionButtonStyle())
            }
        }
    }

    private func spaceInventoryRow(_ line: SpaceInventoryLine) -> some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            HStack(spacing: HexaTheme.Spacing.s) {
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                    Text(spaceInventoryName(line.location))
                        .font(.hexa(.body))
                    Text(prettyPath(line.url))
                        .font(.hexa(.label)).foregroundStyle(HexaTheme.fgTertiary)
                        .lineLimit(1).truncationMode(.head)
                }
                Spacer()
                if let size = line.size {
                    Text(Self.byteString(size))
                        .font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
                        .monospacedDigit()
                    HexaIconButton(icon: "folder",
                                   label: l10n.s.cleanerRevealInFinder,
                                   variant: .small,
                                   action: { revealInFinder(line.url) })
                        .help(l10n.s.cleanerRevealInFinder)
                }
            }
            if line.location == .simulators {
                Text(l10n.s.spaceInventorySimulatorsScope)
                    .font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
                Text(l10n.s.spaceInventorySimulatorNote)
                    .font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
                // Text to copy only: no process is started from this string.
                Text("xcrun simctl delete unavailable")
                    .font(.hexa(.label)).foregroundStyle(HexaTheme.fgPrimary)
                    .textSelection(.enabled)
                Text(l10n.s.spaceInventorySimulatorWarning)
                    .font(.hexa(.micro)).foregroundStyle(HexaTheme.statusWarning)
            }
        }
        .padding(.vertical, HexaTheme.Spacing.xs)
    }

    private func spaceInventoryGroupCaption(_ group: SpaceInventory.Group) -> String? {
        switch group {
        case .models: return l10n.s.spaceInventoryModelsCaption
        case .tools: return l10n.s.spaceInventoryToolsCaption
        case .vms: return l10n.s.spaceInventoryVMsCaption
        case .simulators: return nil
        }
    }

    /// Product names are proper nouns and stay as written; only the simulator
    /// row has words to translate.
    private func spaceInventoryName(_ location: SpaceInventory.Location) -> String {
        switch location {
        case .lmStudio: return "LM Studio"
        case .ollama: return "Ollama"
        case .huggingFace: return "Hugging Face"
        case .cursor: return "Cursor"
        case .codex: return "Codex"
        case .zcode: return "ZCode"
        case .gemini: return "Gemini / Antigravity"
        case .claudeVMs: return "Claude"
        case .simulators: return l10n.s.spaceInventorySimulatorsTitle
        }
    }

    /// Opens the folder in Finder only while it still exists. Nothing else opens.
    private func revealInFinder(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: Space map route

    /// The way into the space map from the idle screen. Opening it shows the map
    /// as it is: nothing is read or measured until the map's own "Calcular".
    private var spaceMapEntry: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            HStack(spacing: HexaTheme.Spacing.s) {
                HexaIcons.image("internaldrive")
                    .foregroundStyle(HexaTheme.fgSecondary)
                Button(l10n.s.spaceInventoryTitle) { openSpaceMap() }
                    .buttonStyle(HexaActionButtonStyle())
                Spacer(minLength: HexaTheme.Spacing.s)
            }
            Text(l10n.s.spaceInventoryLegend)
                .hexaCaption()
        }
    }

    /// The map on its own surface, inside the Cleaner: the same section as the
    /// results, with no window and no new tab. Only the route differs.
    private var spaceMapScreen: some View {
        VStack(spacing: 0) {
            spaceMapHeader
            HairlineDivider()
            OverlayScrollView {
                spaceInventorySection
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, HexaTheme.Spacing.l)
                    .padding(.top, HexaTheme.Spacing.m)
                    .padding(.bottom, HexaTheme.Spacing.pageGap)
            }
            .frame(maxWidth: .infinity, minHeight: compact ? 280 : 0, maxHeight: .infinity)
        }
    }

    private var spaceMapHeader: some View {
        HStack(spacing: HexaTheme.Spacing.m) {
            Spacer()
            // The section below carries the map's own title.
            Button(l10n.s.largeFilesBackToStart) { closeSpaceMap() }
                .buttonStyle(HexaActionButtonStyle())
        }
        .padding(compact ? HexaTheme.Spacing.m : HexaTheme.Spacing.l)
    }

    /// Opens the map and nothing else: no measurement starts on open.
    private func openSpaceMap() {
        spaceMapOpen = true
    }

    /// Back drops the route and stops a reading still running, as leaving the
    /// surface does. It never resets the Cleaner: its phase, items and selection
    /// are left as they were.
    private func closeSpaceMap() {
        spaceMapOpen = false
        cleaner.cancelSpaceInventory()
    }

    // MARK: Large and old files

    /// The way into the list, on the idle screen and on the results. One press
    /// opens the list and starts its search: nothing is read before the
    /// gesture, and the list is reachable without having run a scan.
    private func largeFilesEntry(from origin: LargeFilesOrigin) -> some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            HStack(spacing: HexaTheme.Spacing.s) {
                HexaIcons.image("text.magnifyingglass")
                    .foregroundStyle(HexaTheme.fgSecondary)
                Text(l10n.s.largeFilesTitle)
                    .font(.hexa(.body))
                Spacer(minLength: HexaTheme.Spacing.s)
                Button(l10n.s.largeFilesOpen) { openLargeFiles(from: origin) }
                    .buttonStyle(HexaActionButtonStyle())
            }
            Text(l10n.s.largeFilesCaption)
                .hexaCaption()
        }
    }

    /// The list itself, inside the Cleaner: same surface, no window and no new
    /// tab. The route lives in `largeFilesOrigin`, so the Cleaner behind it
    /// keeps its phase, its items and their selection.
    private var largeFilesScreen: some View {
        VStack(spacing: 0) {
            largeFilesHeader
            HairlineDivider()
            OverlayScrollView {
                LazyVStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                    largeFilesSearchControl
                    largeFilesStates
                }
                .padding(.horizontal, HexaTheme.Spacing.l)
                .padding(.top, HexaTheme.Spacing.m)
                .padding(.bottom, HexaTheme.Spacing.pageGap)
            }
            .frame(maxWidth: .infinity, minHeight: compact ? 280 : 0, maxHeight: .infinity)
            HairlineDivider()
            largeFilesFooter
        }
        .alert(l10n.s.largeFilesConfirmTitle, isPresented: $confirmingLargeFilesRemoval) {
            Button(l10n.s.uninstallerCancel, role: .cancel) {}
            Button(l10n.s.largeFilesRemove, role: .destructive) { removeMarkedLargeFiles() }
        } message: {
            Text(largeFilesConfirmationMessage)
        }
    }

    private var largeFilesHeader: some View {
        HStack(spacing: HexaTheme.Spacing.m) {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                Text(l10n.s.largeFilesTitle).font(.hexa(.heading))
                Text(largeFilesThresholdsLine)
                    .font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
            }
            Spacer()
            Button(largeFilesBackTitle) { closeLargeFiles() }
                .buttonStyle(HexaActionButtonStyle())
        }
        .padding(compact ? HexaTheme.Spacing.m : HexaTheme.Spacing.l)
    }

    private var largeFilesBackTitle: String {
        largeFilesOrigin == .results ? l10n.s.largeFilesBackToResults : l10n.s.largeFilesBackToStart
    }

    /// The two limits the search reads, written the way Settings shows them.
    private var largeFilesThresholdsLine: String {
        String(format: l10n.s.largeFilesThresholdsFormat,
               CleanerPolicy.sanitizedLargeFileAgeDays(largeFileAgeDays),
               Self.largeFileSizeLabel(CleanerPolicy.sanitizedLargeFileSizeMegabytes(
                   largeFileSizeMegabytes)))
    }

    /// Runs the search once per press and once when the list opens. The cancel
    /// stops only the running walk: what it found stays as a partial list. The
    /// search is held while a walk runs and while a confirmed batch still moves
    /// items, because the service refuses both without a word.
    private var largeFilesSearchControl: some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            Button(l10n.s.largeFilesSearch) { startLargeFilesSearch() }
                .buttonStyle(HexaActionButtonStyle())
                .disabled(cleaner.largeFilesIsComputing || largeFilesRemovalPending)
            if cleaner.largeFilesIsComputing || largeFilesRemovalPending {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(l10n.s.loadingMessage)
            }
            if cleaner.largeFilesIsComputing {
                Button(l10n.s.uninstallerCancel) { cleaner.cancelLargeFiles() }
                    .buttonStyle(HexaActionButtonStyle())
            }
        }
    }

    /// Loading, the found rows, the refused paths, the partial mark, the empty
    /// result and the report of the last removal. A failure is always shown as
    /// a failure, a cancel is always shown as a cancel, and the empty headline
    /// is drawn only for a finished search with nothing found and nothing refused.
    @ViewBuilder
    private var largeFilesStates: some View {
        let state = Self.largeFilesListState(isComputing: cleaner.largeFilesIsComputing,
                                             result: cleaner.largeFiles)
        if state == .searching {
            HStack(spacing: HexaTheme.Spacing.s) {
                ProgressView()
                    .controlSize(.small)
                Text(l10n.s.largeFilesSearching)
                    .font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
            }
            .padding(.vertical, HexaTheme.Spacing.xs)
        }
        if let result = cleaner.largeFiles {
            if result.candidates.isEmpty {
                if state == .empty {
                    Text(l10n.s.largeFilesEmpty)
                        .font(.hexa(.body)).foregroundStyle(HexaTheme.fgSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, HexaTheme.Spacing.xs)
                }
            } else {
                largeFilesGroup(result)
            }
            largeFilesDenials(result)
            if result.cancelled {
                Text(l10n.s.largeFilesCancelled)
                    .font(.hexa(.micro)).foregroundStyle(HexaTheme.statusWarning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else if state == .listing {
            // No result yet, for example when a scheduled pass cleared the list
            // while it was open: the list says what it is, it is never blank.
            Text(l10n.s.largeFilesCaption)
                .hexaCaption()
        }
        if let reports = cleaner.largeFilesRemoval {
            largeFilesReport(reports)
        }
    }

    /// Every refusal the walk could read, with the path and the reason, in the
    /// same words the map uses.
    @ViewBuilder
    private func largeFilesDenials(_ result: LargeFiles.SearchResult) -> some View {
        ForEach(result.denied) { denial in
            Text(String(format: l10n.s.spaceInventoryDeniedFormat,
                        abbreviateHome(denial.url),
                        spaceInventoryDenialReason(denial.reason)))
                .font(.hexa(.micro)).foregroundStyle(HexaTheme.statusWarning)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The found rows under one header that starts collapsed and carries the
    /// count and the total size. Nothing inside is marked by the app.
    private func largeFilesGroup(_ result: LargeFiles.SearchResult) -> some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    cleaner.largeFilesExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: HexaTheme.Spacing.s) {
                    HexaIcons.image("chevron.right")
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .rotationEffect(.degrees(cleaner.largeFilesExpanded ? 90 : 0))
                    VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                        Text(l10n.s.largeFilesResultTitle).font(.hexa(.body))
                        Text(String(format: l10n.s.largeFilesGroupFormat,
                                    result.candidates.count, Self.byteString(result.totalSize)))
                            .font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(cleaner.largeFilesExpanded ? l10n.s.disclosureExpanded
                                                           : l10n.s.disclosureCollapsed)

            if cleaner.largeFilesExpanded {
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                    ForEach(result.candidates) { candidate in largeFilesRow(candidate) }
                }
                .padding(.leading, HexaTheme.Spacing.m)
                .transition(reduceMotion ? .identity : .opacity)
            }
        }
        .padding(HexaTheme.Spacing.m)
        .hexaSectionCard(padded: false)
    }

    /// One row: name, path, size and modification date, with Finder and Quick
    /// Look for the item the user is reading. Neither action removes anything.
    private func largeFilesRow(_ candidate: LargeFiles.Candidate) -> some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            Toggle("", isOn: largeFilesMarkBinding(candidate))
                .labelsHidden()
                .toggleStyle(.checkbox)
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                Text(candidate.name)
                    .font(.hexa(.label)).lineLimit(1).truncationMode(.middle)
                Text(abbreviateHome(candidate.url))
                    .font(.hexa(.label)).foregroundStyle(HexaTheme.fgTertiary)
                    .lineLimit(1).truncationMode(.head)
                Text(Self.largeFilesDate(candidate.modified))
                    .font(.hexa(.micro)).foregroundStyle(HexaTheme.fgTertiary)
            }
            Spacer()
            Text(Self.byteString(candidate.size))
                .font(.hexa(.data)).foregroundStyle(HexaTheme.fgSecondary)
                .monospacedDigit()
            HexaIconButton(icon: "folder",
                           label: l10n.s.cleanerRevealInFinder,
                           variant: .small,
                           action: { revealInFinder(candidate.url) })
                .help(l10n.s.cleanerRevealInFinder)
            HexaIconButton(icon: "eye",
                           label: l10n.s.largeFilesQuickLook,
                           variant: .small,
                           action: { LargeFilesQuickLook.show(candidate.url) })
                .help(l10n.s.largeFilesQuickLook)
        }
        .padding(.vertical, HexaTheme.Spacing.xs)
    }

    /// What the confirmed batch did to each item. What failed is never written
    /// as a success: each item carries its own outcome and its own reason.
    private func largeFilesReport(_ reports: [LargeFiles.RemovalReport]) -> some View {
        let moved = reports.filter { !$0.isFailure }.count
        let notMoved = reports.filter(\.isFailure).count
        return VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            Text(l10n.s.largeFilesReportTitle).font(.hexa(.body))
            Text(String(format: l10n.s.largeFilesReportSummaryFormat, moved, notMoved))
                .font(.hexa(.label))
                .foregroundStyle(notMoved == 0 ? HexaTheme.fgSecondary : HexaTheme.statusWarning)
            ForEach(reports) { report in
                Text(largeFilesReportLine(report))
                    .font(.hexa(.micro))
                    .foregroundStyle(report.isFailure ? HexaTheme.statusWarning : HexaTheme.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, HexaTheme.Spacing.s)
    }

    private func largeFilesReportLine(_ report: LargeFiles.RemovalReport) -> String {
        switch report.outcome {
        case .movedToTrash:
            return String(format: l10n.s.largeFilesMovedFormat, report.url.lastPathComponent)
        case .refused:
            return String(format: l10n.s.largeFilesRefusedFormat, report.url.lastPathComponent)
        case .failed:
            return String(format: l10n.s.largeFilesFailedFormat, report.url.lastPathComponent)
        }
    }

    private var largeFilesFooter: some View {
        HexaResultsFooter(
            contentPadding: compact ? HexaTheme.Spacing.m : HexaTheme.Spacing.l,
            primaryTitle: l10n.s.largeFilesRemove,
            primaryAction: { confirmingLargeFilesRemoval = true },
            primaryDisabled: Self.largeFilesRemovalIsDisabled(
                marked: largeFilesMarkedCandidates.count,
                isComputing: cleaner.largeFilesIsComputing,
                isRemovalPending: largeFilesRemovalPending),
            primaryControlSize: .large
        ) {
            Text(largeFilesSelectionSummary)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
        }
    }

    /// Count and total size of what is marked, before anything moves.
    private var largeFilesSelectionSummary: String {
        String(format: l10n.s.largeFilesSelectedFormat,
               largeFilesMarkedCandidates.count,
               cleaner.largeFiles?.candidates.count ?? 0,
               Self.byteString(largeFilesMarkedCandidates.reduce(0) { $0 + $1.size }))
    }

    private var largeFilesConfirmationMessage: String {
        String(format: l10n.s.largeFilesConfirmMessageFormat,
               largeFilesMarkedCandidates.count,
               Self.byteString(largeFilesMarkedCandidates.reduce(0) { $0 + $1.size }))
    }

    /// Only what is marked, and only after the confirmation. The service reads
    /// the saved thresholds again and revalidates every item before its move.
    private func removeMarkedLargeFiles() {
        let marked = Set(largeFilesMarkedCandidates.map(\.id))
        // The flag is set only when the service will run the batch: a refusal
        // with no batch behind it would hold the Trash and the search for good.
        guard !marked.isEmpty, !cleaner.largeFilesIsComputing else { return }
        largeFilesRemovalPending = true
        cleaner.trashLargeFiles(ids: marked, confirmed: true)
        largeFilesMarked = []
    }

    private var largeFilesMarkedCandidates: [LargeFiles.Candidate] {
        (cleaner.largeFiles?.candidates ?? []).filter { largeFilesMarked.contains($0.id) }
    }

    private func largeFilesMarkBinding(_ candidate: LargeFiles.Candidate) -> Binding<Bool> {
        Binding(
            get: { largeFilesMarked.contains(candidate.id) },
            set: { marked in
                if marked {
                    largeFilesMarked.insert(candidate.id)
                } else {
                    largeFilesMarked.remove(candidate.id)
                }
            }
        )
    }

    private func openLargeFiles(from origin: LargeFilesOrigin) {
        largeFilesOrigin = origin
        startLargeFilesSearch()
    }

    /// Back only drops the route: the Cleaner's phase, its items and their
    /// selection were never touched, so it lands exactly where it was opened.
    /// A batch still moving items keeps the Trash and the search held: its
    /// report clears the flag, not the route.
    private func closeLargeFiles() {
        largeFilesOrigin = nil
        largeFilesMarked = []
        cleaner.cancelLargeFiles()
    }

    /// One walk per press, with the thresholds saved in Settings. Nothing is
    /// marked when it starts, and the group starts collapsed.
    private func startLargeFilesSearch() {
        largeFilesMarked = []
        cleaner.measureLargeFiles()
    }

    private static let largeFilesDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static func largeFilesDate(_ date: Date) -> String {
        largeFilesDateFormatter.string(from: date)
    }

    private var resultsFooter: some View {
        HexaResultsFooter(
            contentPadding: compact ? HexaTheme.Spacing.m : HexaTheme.Spacing.l,
            secondaryTitle: l10n.s.uninstallerCancel,
            secondaryAction: { cleaner.reset() },
            primaryTitle: String(format: l10n.s.cleanerCleanSizeFormat,
                                 Self.byteString(cleaner.selectedSize)),
            primaryAction: {
                if cleaner.items.contains(where: { $0.category == .trash && $0.include }) {
                    confirmingTrash = true
                } else {
                    cleaner.cleanSelected(escalate: true)
                }
            },
            primaryDisabled: cleaner.selectedCount == 0,
            primaryControlSize: .large
        ) {
            Text(String(format: l10n.s.uninstallerSelectedFormat,
                        cleaner.selectedCount, cleaner.items.count))
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
        }
        .alert(l10n.s.cleanerTrashConfirmTitle, isPresented: $confirmingTrash) {
            Button(l10n.s.uninstallerCancel, role: .cancel) {}
            Button(l10n.s.cleanerTrashConfirmButton, role: .destructive) {
                cleaner.cleanSelected(escalate: true)
            }
        } message: {
            Text(l10n.s.cleanerTrashConfirmMessage)
        }
    }

    // MARK: Done

    private func doneState(movedToTrash: Int64, freedPermanently: Int64, failed: Int) -> some View {
        VStack(spacing: HexaTheme.Spacing.l) {
            Spacer(minLength: compact ? 20 : 0)
            HexaIcons.image("checkmark.circle.fill", size: compact ? 40 : 54)
                .foregroundStyle(HexaTheme.statusOk)
            Text(l10n.s.uninstallerDoneTitle).font(compact ? .hexa(.heading) : .hexa(.display(20)))
            if movedToTrash > 0 {
                Text(String(format: l10n.s.movedToTrashFormat, Self.byteString(movedToTrash)))
                    .font(.hexa(.body)).foregroundStyle(HexaTheme.fgSecondary)
            }
            if freedPermanently > 0 {
                Text(String(format: l10n.s.freedPermanentlyFormat, Self.byteString(freedPermanently)))
                    .font(.hexa(.body)).foregroundStyle(HexaTheme.fgSecondary)
            }
            if movedToTrash > 0 {
                Text(l10n.s.cleanerDoneNote)
                    .font(.hexa(.label)).foregroundStyle(HexaTheme.fgTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
            if failed > 0 {
                Text(l10n.s.uninstallerSomeFailed)
                    .font(.hexa(.label)).foregroundStyle(HexaTheme.statusWarning)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, HexaTheme.Spacing.xxl)
            }
            if !cleaner.skippedBrowsers.isEmpty {
                ForEach(cleaner.skippedBrowsers, id: \.self) { browser in
                    Text(Self.skippedBrowserLine(browser, strings: l10n.s))
                        .font(.hexa(.label)).foregroundStyle(HexaTheme.statusWarning)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, HexaTheme.Spacing.xxl)
                }
            }
            Button(l10n.s.cleanerAgain) { cleaner.reset() }
                .buttonStyle(HexaActionButtonStyle())
                .controlSize(.large)
                .padding(.top, HexaTheme.Spacing.xs)
            Spacer(minLength: compact ? 20 : 0)
        }
        .padding(compact ? HexaTheme.Spacing.m : HexaTheme.Spacing.xxl)
        .frame(maxWidth: .infinity, minHeight: compact ? 0 : 320)
    }

    // MARK: Helpers

    private func includeBinding(_ item: JunkCleaner.Item) -> Binding<Bool> {
        Binding(
            get: { cleaner.items.first(where: { $0.id == item.id })?.include ?? false },
            set: { cleaner.setInclude($0, for: item.id) }
        )
    }

    private func groupBinding(_ group: DisplayGroup) -> Binding<Bool> {
        Binding(
            get: {
                let group_items = items(for: group)
                return !group_items.isEmpty && group_items.allSatisfy(\.include)
            },
            set: { include in
                for item in items(for: group) {
                    cleaner.setInclude(include, for: item.id)
                }
            }
        )
    }

    private func prettyPath(_ url: URL) -> String {
        url.deletingLastPathComponent().path
            .replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    private static func byteString(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// Pure line composition for one browser the last clean skipped because
    /// it was running; the results footer renders one line per skipped name.
    static func skippedBrowserLine(_ browser: String, strings: Strings) -> String {
        String(format: strings.cleanerSkippedBrowsersFormat, browser)
    }
}

/// The cleaner hosted inside the menu panel or the quick panel, with the
/// shared header and close affordance of the other hosted utilities.
struct PanelCleanerView: View {
    @ObservedObject private var l10n = L10n.shared
    var onClose: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            HexaPanelHeader(title: l10n.s.cleanerName, icon: "sparkles") {
                if let onClose {
                    HexaIconButton(icon: "xmark", label: l10n.s.menuClose, variant: .small) {
                        // Closing means cancel: a scan left running would come
                        // back on the next open. Cleaning in progress is left alone.
                        let cleaner = JunkCleaner.shared
                        if cleaner.phase == .scanning { cleaner.reset() }
                        onClose()
                    }
                    .help(l10n.s.menuClose)
                }
            }
            CleanerView(compact: true)
        }
        .onAppear { PanelInteractionState.shared.viewKeepsPopoverOpen = true }
        .onDisappear { PanelInteractionState.shared.viewKeepsPopoverOpen = false }
    }
}

/// Quick Look for one item of the large files list, on the user's gesture
/// only. The panel is macOS's own: the app points it at the URL that was
/// chosen and nothing watches the file afterwards, so no read starts by
/// itself.
final class LargeFilesQuickLook: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    private static let shared = LargeFilesQuickLook()

    private var previewed: URL?

    static func show(_ url: URL) {
        shared.present(url)
    }

    private func present(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path),
              let panel = QLPreviewPanel.shared() else { return }
        previewed = url
        panel.dataSource = self
        panel.delegate = self
        panel.makeKeyAndOrderFront(nil)
        panel.reloadData()
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewed == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        previewed as NSURL?
    }
}
