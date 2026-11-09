// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import SwiftUI
import EventKit

struct NotchSettings: View {
    let workspaceFeature: AppFeature
    /// The tab the workspace's sidebar picked.
    var workspaceTab: NotchSettingsTab? = nil
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var notch = NotchService.shared
    @ObservedObject private var workspace = FeatureWorkspaceState.shared
    @AppStorage(DefaultsKey.notchGesturesEnabled) private var gesturesEnabled = true
    @AppStorage(DefaultsKey.notchKeyboardLight) private var keyboardLight = true
    @AppStorage(DefaultsKey.notchNotificationsEnabled) private var notificationsEnabled = true
    @AppStorage(DefaultsKey.notchDismissNativeNotifications) private var dismissNativeNotifications = false
    @AppStorage(DefaultsKey.notchTimerEnabled) private var timerEnabled = true
    @AppStorage(DefaultsKey.notchTimerSoundEnabled) private var timerSoundEnabled = true
    @AppStorage(DefaultsKey.notchHideTimerCountdown) private var hideTimerCountdown = false
    @AppStorage(DefaultsKey.notchAccessoriesEnabled) private var accessoriesEnabled = true
    @AppStorage(DefaultsKey.notchCalendarEnabled) private var calendarEnabled = true
    @AppStorage(DefaultsKey.notchCalendarCountdown) private var calendarCountdown = false
    @AppStorage(DefaultsKey.notchCalendarTimeLeft) private var calendarTimeLeft = false
    @AppStorage(DefaultsKey.notchWatchEnabled) private var watchEnabled = true
    @AppStorage(DefaultsKey.notchDownloadsEnabled) private var downloadsEnabled = true
    @AppStorage(DefaultsKey.notchLyricsEnabled) private var lyricsEnabled = true
    @AppStorage(DefaultsKey.notchLyricsOnline) private var lyricsOnline = false
    @AppStorage(DefaultsKey.notchQueueEnabled) private var queueEnabled = true
    @AppStorage(DefaultsKey.notchLiveEqualizer) private var liveEqualizer = false
    @AppStorage(DefaultsKey.notchEnabled) private var enabled = false
    @AppStorage(DefaultsKey.notchDisplay) private var display = NotchDisplay.automatic.rawValue
    @AppStorage(DefaultsKey.notchSilhouette) private var silhouette = NotchSilhouette.capsule.rawValue
    @AppStorage(DefaultsKey.notchOpenOnHover) private var hover = false
    @AppStorage(DefaultsKey.notchHideInFullscreen) private var hideInFullscreen = false
    @AppStorage(DefaultsKey.notchHideUntilHover) private var hideUntilHover = false
    @AppStorage(DefaultsKey.notchCoversMenus) private var coversMenus = true
    @AppStorage(DefaultsKey.notchHoverDelay) private var hoverDelay = NotchSupport.defaultHoverDelay
    @AppStorage(DefaultsKey.notchReturnHome) private var returnHome = false
    @AppStorage(DefaultsKey.notchHomeModule) private var homeModule = NotchModule.controls.rawValue
    @AppStorage(DefaultsKey.notchOpensActivity) private var opensActivity = true
    @AppStorage(DefaultsKey.notchHiddenModules) private var hidden = ""
    @AppStorage(DefaultsKey.notchModuleOrder) private var order = ""
    @AppStorage(DefaultsKey.notchVolume) private var volume = true
    @AppStorage(DefaultsKey.notchBrightness) private var brightness = true
    @AppStorage(DefaultsKey.notchBattery) private var battery = true
    @AppStorage(DefaultsKey.notchCapture) private var capture = true
    @AppStorage(DefaultsKey.notchTrackChange) private var trackChange = true
    @AppStorage(DefaultsKey.notchShowPlayingMusic) private var showPlayingMusic = false
    @AppStorage(DefaultsKey.notchIncludeOtherPlayers) private var includeOtherPlayers = true
    @AppStorage(DefaultsKey.notchIdleContent) private var idle = NotchIdleContent.none.rawValue
    @AppStorage(DefaultsKey.notchHiddenControls) private var hiddenControls = NotchControlItem.defaultHidden
    @AppStorage(DefaultsKey.notchShowInCaptures) private var showInCaptures = true
    @AppStorage(DefaultsKey.notchLockScreen) private var lockScreen = false
    @AppStorage(DefaultsKey.notchLockSounds) private var lockSounds = false
    @AppStorage(DefaultsKey.notchSize) private var size = NotchSize.spacious.rawValue
    @AppStorage(DefaultsKey.notchOutlineEnabled) private var outlineEnabled = false
    @AppStorage(DefaultsKey.notchCustomWidth) private var customWidth = NotchSize.defaultWidth
    @AppStorage(DefaultsKey.notchCustomHeight) private var customHeight = NotchSize.defaultHeight
    @AppStorage(DefaultsKey.notchCapsuleFitWidth) private var capsuleFitWidth = 0.0
    @AppStorage(DefaultsKey.notchCapsuleFitHeight) private var capsuleFitHeight = 0.0
    @AppStorage(DefaultsKey.notchCapsuleFitDrop) private var capsuleFitDrop = 0.0
    @AppStorage(DefaultsKey.notchHapticFeedback) private var hapticFeedback = true
    @AppStorage(DefaultsKey.notchTranslucentBackground) private var translucentBackground = false
    @AppStorage(DefaultsKey.notchCaptureControls) private var captureControls = true
    @AppStorage(DefaultsKey.notchAppPanel) private var appPanel = false
    @AppStorage(DefaultsKey.notchHidesMenuBarIcon) private var hidesMenuBarIcon = false
    @AppStorage(DefaultsKey.notchKeepAwakeActivity) private var keepAwakeActivity = false
    @AppStorage(DefaultsKey.brightnessControlEnabled) private var brightnessControlEnabled = false
    @AppStorage(DefaultsKey.notchHoverExpands) private var hoverExpand = true
    @AppStorage(DefaultsKey.notchQuickAccessLayout) private var accessData = Data()
    @State private var tab = NotchSettingsTab.content
    @State private var selectedModule = NotchModule.controls
    /// Counts the section requests taken from the workspace search, so the page scrolls to the section.
    @State private var sectionReveals = 0
    @State private var draggingModule: NotchModule?
    /// The width the page's cards get, read from the column so the preview
    /// scales the island to the room it really has.
    @State private var contentWidth = FeatureWorkspaceMetrics.contentWidth
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private var text: NotchStrings { FeatureStrings.notch(l10n.language) }
    private var editor: NotchEditorStrings { FeatureStrings.notchEditor(l10n.language) }
    private var experience: NotchExperienceStrings { FeatureStrings.notchExperience(l10n.language) }
    /// Scroll target of the chosen section's header.
    private static let sectionAnchor = "notch.content.section"

    private var configuration: [String] {
        [String(enabled), String(calendarEnabled), String(calendarCountdown), String(calendarTimeLeft), String(notificationsEnabled), String(dismissNativeNotifications), String(gesturesEnabled), String(lyricsEnabled), String(lyricsOnline), String(queueEnabled), String(liveEqualizer), String(showPlayingMusic), String(includeOtherPlayers), idle, hiddenControls, size,
         String(timerEnabled), String(timerSoundEnabled), String(hideTimerCountdown), String(accessoriesEnabled), String(outlineEnabled), String(customWidth), String(customHeight), String(capsuleFitWidth), String(capsuleFitHeight), String(capsuleFitDrop), String(hapticFeedback), String(captureControls), String(appPanel), String(hoverExpand), String(hideUntilHover), String(hideInFullscreen), String(coversMenus), display, silhouette, String(hover), hidden, order, String(volume),
         String(brightness), String(keyboardLight), String(battery), String(capture), String(trackChange), String(showInCaptures), String(returnHome), homeModule, String(opensActivity), String(watchEnabled), String(downloadsEnabled), String(keepAwakeActivity)]
    }

    private var access: Binding<NotchQuickAccessConfiguration> {
        Binding(get: { NotchQuickAccessConfiguration.stored() }, set: { accessData = $0.encoded })
    }

    private var orderedModules: [NotchModule] {
        let stored = order.split(separator: ",").compactMap { NotchModule(rawValue: String($0)) }
        var seen = Set<NotchModule>()
        return (stored + NotchModule.allCases).filter { $0 != .tools && seen.insert($0).inserted }
    }

    @ViewBuilder
    private var accessHint: some View {
        if enabled, AppFeature.notch.isAvailable, !(hover && hideUntilHover), !notch.geometry.isNotched, !permissions.accessibility {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                Text(text.menuBarAccessHint)
                    .font(.hexa(.body)).foregroundStyle(HexaTheme.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                PermissionRow(kind: .accessibility)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var notchContent: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xl) {
            if tab == .content {
                contentEditor
            } else {
                pageScroll
            }
        }
        .frame(maxWidth: FeatureWorkspaceMetrics.scaffoldWidth, alignment: .topLeading)
        .clipped()
        // Papel tipográfico base da página (spec §3).
        .font(.hexa(.body))
    }

    var body: some View {
        notchContent
            .onChange(of: configuration) { _, _ in sync() }
            .onChange(of: accessData) { _, _ in NotchService.shared.schedulePreferenceSync() }
            .onChange(of: tab) { _, _ in draggingModule = nil }
            .onAppear {
                selectWorkspaceFeature()
                consumeWorkspaceTab()
            }
            .onChange(of: workspaceTab) { _, _ in consumeWorkspaceTab() }
            .onAppear(perform: consumeContentSection)
            .onChange(of: workspace.notchContentSection) { _, _ in consumeContentSection() }
    }

    /// The workspace search can name a section of the island. The Content tab
    /// selects it and scrolls to it; the request is cleared once it is taken.
    private func consumeContentSection() {
        guard workspaceFeature == .notch, let module = workspace.notchContentSection else { return }
        workspace.notchContentSection = nil
        chooseModule(module)
        selectTab(.content)
        sectionReveals += 1
    }

    /// The workspace's sidebar picks the tab, which the page then shows.
    private func consumeWorkspaceTab() {
        guard workspaceFeature == .notch, let workspaceTab else { return }
        tab = workspaceTab
    }

    private var pageScroll: some View {
        OverlayScrollView {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.l) {
                accessHint
                switch tab {
                case .appearance: appearancePage
                case .content: EmptyView()
                case .activity: activityPage
                case .behavior: behaviorPage
                }
            }
            .frame(maxWidth: FeatureWorkspaceMetrics.contentWidth, alignment: .leading)
            .padding(.horizontal, HexaTheme.Spacing.xxl)
            .padding(.bottom, HexaTheme.Spacing.pageGap)
        }
        .frame(maxWidth: FeatureWorkspaceMetrics.scaffoldWidth, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .id(tab)
    }

    /// A janela operacional seleciona conteúdo local, sem consumir a navegação de Ajustes.
    private func selectWorkspaceFeature() {
        guard workspaceFeature != .notch else { return }
        if let module = NotchModule.allCases.first(where: { moduleFeature($0) == workspaceFeature }) {
            chooseModule(module)
            tab = .content
        } else {
            switch workspaceFeature {
            case .notchLyrics, .notchQueue, .notchLiveEqualizer:
                selectedModule = .music
                tab = .content
            case .notchAccessories: tab = .activity
            case .notchGestures: tab = .behavior
            default: tab = .appearance
            }
        }
    }

    private func sync() {
        NotchService.shared.schedulePreferenceSync()
        if !NotchLyricsSupport.isEnabled() { NotchLyricsService.shared.stop() }
        NotchMusicService.shared.syncQueuePreference()
        if AppFeature.brightness.isAvailable { BrightnessService.shared.syncWithPreferences() }
    }

    /// A aba Aparência: a ilha no tamanho e na superfície escolhidos, e o que
    /// muda numa tela sem câmera. A prévia é a mesma das outras abas, na
    /// página de controles, que é a que o tamanho redimensiona.
    private var appearancePage: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.l) {
            NotchPreviewStage(mode: .page(.controls), enabled: enabled)
                .frame(height: NotchPreviewStage.height(for: .page(.controls), width: contentWidth))
            HexaSection(text.size) {
                SettingsChoiceRow(symbol: "rectangle.expand.vertical", title: experience.sizePreset, selection: sizeSelection, options: [
                    (NotchSize.compact.rawValue, text.compact),
                    (NotchSize.spacious.rawValue, text.spacious),
                    (NotchSize.custom.rawValue, text.custom),
                ])
                if size == NotchSize.custom.rawValue {
                    // One grid starts both sliders at the same edge in every language.
                    Grid(alignment: .leading, horizontalSpacing: HexaTheme.Spacing.m, verticalSpacing: HexaTheme.Spacing.s) {
                        dimensionSlider(text.width, value: $customWidth, range: NotchSize.widthRange, fallback: NotchSize.defaultWidth)
                        dimensionSlider(text.maximumHeight, value: $customHeight, range: NotchSize.heightRange, fallback: NotchSize.defaultHeight)
                    }
                    Text(text.sizeHint).font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
                }
            }
            HexaSection(experience.surface) {
                switchRow("drop.halffull", text.translucentBackground,
                          caption: text.translucentBackgroundHint,
                          isOn: $translucentBackground)
                switchRow("capsule", text.showOutline, isOn: $outlineEnabled)
            }
            // Only a display without a camera can float the island.
            if NotchSupport.hasDisplayWithoutNotch {
                HexaSection(text.withoutNotch) {
                    SettingsChoiceRow(symbol: "capsule", title: text.withoutNotch, selection: $silhouette, options: [
                        (NotchSilhouette.capsule.rawValue, text.capsuleShape),
                        (NotchSilhouette.notch.rawValue, text.notchShape),
                    ])
                }
                if NotchSilhouette(rawValue: silhouette) ?? .capsule == .capsule {
                    HexaSection(text.capsuleFit) {
                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                            // Even widths keep the capsule centred on whole points.
                            fitSlider(text.width, card: text.capsuleFit, value: $capsuleFitWidth,
                                      range: NotchCapsuleFit.widthRange, step: 2)
                            fitSlider(text.height, card: text.capsuleFit, value: $capsuleFitHeight,
                                      range: NotchCapsuleFit.heightRange, step: 1)
                            fitSlider(text.fromTop, card: text.capsuleFit, value: $capsuleFitDrop,
                                      range: NotchCapsuleFit.dropRange, step: 1)
                        }
                        Text(text.capsuleFitHint).font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { contentWidth = $0 }
    }

    /// Choosing Custom starts from the size the current preset really draws,
    /// not from the stored custom values that preset never used.
    private var sizeSelection: Binding<String> {
        Binding(get: { size }, set: { newValue in
            if newValue == NotchSize.custom.rawValue, let preset = NotchSize(rawValue: size), preset != .custom {
                let width = NotchLayout.preferredWidth(preset, custom: CGFloat(customWidth))
                var geometry = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                                             safeAreaTop: 32, cameraWidth: 210,
                                             layout: preset, menuBarHeight: 24,
                                             customWidth: Double(width), customHeight: customHeight)
                // The preset draws the shortcut bar too, so the seeded height must include it.
                geometry.quickAccessBottomInset = NotchQuickAccessLayout(count: NotchQuickAccessConfiguration.current().buttons.count,
                                                                        width: geometry.contentWidth).reservedHeight
                let height = geometry.expandedSize(module: .controls).height
                customWidth = NotchSize.clamped(Double(width), to: NotchSize.widthRange, fallback: NotchSize.defaultWidth)
                customHeight = NotchSize.clamped(Double(height), to: NotchSize.heightRange, fallback: NotchSize.defaultHeight)
            }
            size = newValue
        })
    }

    /// A ilha inteira em uma página: a prévia da seção escolhida no topo, como
    /// nas outras abas, o que a ilha mostra, a seção com as opções dela e a
    /// barra de atalhos com que ela abre. Enquanto uma seção é arrastada, a
    /// prévia mostra a galeria em que ela vai cair.
    private var contentEditor: some View {
        ScrollViewReader { reader in
            OverlayScrollView {
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.l) {
                    accessHint
                    if !enabled {
                        HexaStatusNote(message: text.enableHint, icon: "power", tone: .neutral)
                    }
                    let module = selectedModule
                    let available = module.isAvailable()
                    let mode: NotchPreviewStage.Mode = draggingModule == nil ? .page(module) : .explore
                    // A prévia fica acima da grade, então a moldura mantém a
                    // altura da página em qualquer modo: se mudasse no arrasto,
                    // a grade se deslocaria sob o ponteiro.
                    NotchPreviewStage(mode: mode, hidden: !isShown(module), enabled: enabled)
                        .frame(height: NotchPreviewStage.height(for: .page(module), width: contentWidth))
                    sectionBar()
                    NotchSectionHeader(module: module, shown: isShown(module),
                                       reason: available ? nil : moduleFeature(module).map(enableFeatureReason) ?? text.disabled) {
                        showFeature(moduleFeature(module))
                    }
                    .id(Self.sectionAnchor)
                    if available, hasOptions(module) {
                        HexaCard { moduleOptions(module) }
                    } else if available {
                        Text(editor.noOptions).font(.hexa(.body)).foregroundStyle(HexaTheme.fgSecondary)
                    }
                    HexaSection(experience.shortcutBar) {
                        NotchLayoutEditor(configuration: access)
                    }
                }
                .frame(maxWidth: FeatureWorkspaceMetrics.contentWidth, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { contentWidth = $0 }
                .padding(.horizontal, HexaTheme.Spacing.xxl)
                .padding(.bottom, HexaTheme.Spacing.pageGap)
            }
            .frame(maxWidth: FeatureWorkspaceMetrics.scaffoldWidth, maxHeight: .infinity, alignment: .topLeading)
            .clipped()
            .id(selectedModule.rawValue)
            .onChange(of: sectionReveals) { _, _ in reader.scrollTo(Self.sectionAnchor, anchor: .top) }
        }
    }

    /// Every section in the island's order, in a compact wrapping grid: the
    /// box that shows it, its name, a drag and a menu to reorder. Choosing one
    /// opens its options below. Adaptive columns replace a horizontal strip
    /// that was too thin to scroll reliably.
    private func sectionBar() -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: HexaTheme.Spacing.xs)],
                  spacing: HexaTheme.Spacing.xs) {
            ForEach(orderedModules) { module in
                NotchSectionListRow(module: module, included: moduleBinding(module), available: module.isAvailable(),
                                    selected: selectedModule == module,
                                    pinned: module == .controls,
                                    order: Binding(get: { orderedModules },
                                                   set: { order = $0.map(\.rawValue).joined(separator: ",") }),
                                    dragging: $draggingModule,
                                    select: { chooseModule(module) },
                                    moveUp: { moveSection(module, by: -1) },
                                    moveDown: { moveSection(module, by: 1) })
                    .id(module)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The same one-place reorder the drag does, for the keyboard and for a
    /// window too narrow to drag in.
    private func moveSection(_ module: NotchModule, by offset: Int) {
        var items = orderedModules
        guard let index = items.firstIndex(of: module), items.indices.contains(index + offset) else { return }
        items.swapAt(index, index + offset)
        order = items.map(\.rawValue).joined(separator: ",")
    }

    private func isShown(_ module: NotchModule) -> Bool {
        module.isAvailable() && moduleBinding(module).wrappedValue
    }

    /// The mixer, the system page, tools and captures arrange themselves in the island.
    private func hasOptions(_ module: NotchModule) -> Bool {
        ![.mixer, .system, .tools, .captures].contains(module)
    }

    @ViewBuilder private func moduleOptions(_ module: NotchModule) -> some View {
        switch module {
        case .controls:
            let primary = [NotchControlItem.music, .volume, .brightness]
            HStack(spacing: HexaTheme.Spacing.s) {
                ForEach(primary) { item in
                    toggleCard(item.title(l10n), symbol: item.symbol, value: controlBinding(item), available: item.isAvailable(),
                               reason: controlReason(item),
                               unavailableAction: controlUnavailableAction(item))
                }
            }
        case .music:
            let music = FeatureStrings.notchMusicExtras(l10n.language)
            switchRow("play.rectangle", music.includeOtherPlayers, isOn: $includeOtherPlayers)
            switchRow("text.quote", music.enableLyrics, isOn: $lyricsEnabled)
                .disabled(!AppFeature.notchLyrics.isAvailable)
            if lyricsEnabled, AppFeature.notchLyrics.isAvailable {
                switchRow("globe", music.online, caption: music.onlineHint, isOn: $lyricsOnline)
                    .padding(.leading, settingsRowTextInset)
            }
            switchRow("list.bullet", music.enableQueue, caption: music.queueDescription, isOn: $queueEnabled)
                .disabled(!AppFeature.notchQueue.isAvailable)
            switchRow("waveform", music.liveEqualizer,
                      caption: NotchAudioLevelSupport.isSupported ? music.liveEqualizerHint : music.liveEqualizerUnavailable,
                      isOn: $liveEqualizer)
                .disabled(!NotchAudioLevelSupport.isSupported || !AppFeature.notchLiveEqualizer.isAvailable)
        case .notifications:
            let notifications = FeatureStrings.notchNotifications(l10n.language)
            // DEC-032: offered only where the original can be moved, not closed.
            if NotchNotificationSupport.movesNativeWindow {
                switchRow("bell.slash", notifications.hideSystemBanner, caption: notifications.hideSystemBannerHint,
                          isOn: $dismissNativeNotifications)
            }
            if notificationsEnabled, !permissions.accessibility { PermissionRow(kind: .accessibility) }
        case .downloads:
            NotchDownloadsSettingsControls()
                .toggleStyle(TrailingSwitchToggleStyle())
        case .calendar:
            let calendar = FeatureStrings.notchCalendar(l10n.language)
            Text(calendar.permission).font(.hexa(.body)).foregroundStyle(HexaTheme.fgSecondary)
            if permissions.calendarAccess == .fullAccess {
                HexaStateTag(l10n.s.permissionGranted, kind: .ok)
            } else {
                HexaAccessButton(icon: "calendar", title: calendar.allow, action: permissions.requestCalendar)
                    .disabled(permissions.requestingCalendar)
                HexaAccessButton(icon: "calendar", title: calendar.settings, action: permissions.openCalendarSettings)
            }
            HairlineDivider()
            switchRow("calendar.badge.clock", calendar.countdown, caption: calendar.countdownHint,
                      isOn: $calendarCountdown)
            switchRow("hourglass", calendar.timeLeft, caption: calendar.timeLeftHint, isOn: $calendarTimeLeft)
            if permissions.calendarAccess == .fullAccess { NotchCalendarSelection() }
        case .timer:
            let activities = FeatureStrings.notchActivities(l10n.language)
            switchRow("eye.slash", activities.hideTimerCountdown,
                      isOn: $hideTimerCountdown)
                .disabled(!AppFeature.notchTimer.isAvailable)
            switchRow("speaker.wave.2", activities.soundEnabled, isOn: $timerSoundEnabled)
                .disabled(!AppFeature.notchTimer.isAvailable)
        case .files:
            if AppFeature.mediaTools.isAvailable {
                Text(FeatureStrings.notchFiles(l10n.language).optimizeDropHint)
                    .font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
            }
        case .captures:
            EmptyView()
        case .watch:
            NotchWatchSettingsControls()
                .toggleStyle(TrailingSwitchToggleStyle())
        case .mixer, .system, .tools:
            EmptyView()
        }
    }

    /// A ilha fechada: a prévia do que ela mostra em repouso, a escolha desse
    /// conteúdo e as atividades que só aparecem nela.
    private var activityPage: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.l) {
            NotchPreviewStage(mode: .resting, enabled: enabled)
                .frame(height: NotchPreviewStage.height(for: .resting, width: contentWidth))
            Text(restingStateSummary)
                .font(.hexa(.body)).foregroundStyle(HexaTheme.fgSecondary)
            HexaSection(experience.restingPreview) {
                SettingsChoiceRow(symbol: "moon.zzz", title: editor.resting, selection: restingBinding, options: restingOptions)
                switchRow("music.note", editor.autoNowPlaying,
                          caption: opensActivity ? editor.autoNowPlayingHint : editor.autoNowPlayingClosedHint,
                          isOn: $showPlayingMusic)
                switchRow("livephoto", editor.openActivity, caption: editor.openActivityHint, isOn: $opensActivity)
                if restingChoice == .music, !showPlayingMusic {
                    Text(editor.idleMusicNeedsOptInHint)
                        .font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
                }
            }
            let activities = FeatureStrings.notchActivities(l10n.language)
            HexaSection(activities.keepAwakeActivity) {
                switchRow(NotchControlItem.keepAwake.symbol, l10n.s.keepAwakeTitle,
                          caption: activities.keepAwakeActivityHint, isOn: $keepAwakeActivity)
                    .disabled(!AppFeature.keepAwake.isAvailable)
            }
            HexaSection(editor.feedback) {
                let volumeAvailable = AppFeature.mixer.isAvailable
                let brightnessAvailable = AppFeature.brightness.isAvailable && brightnessControlEnabled
                let keyboardLightAvailable = AppFeature.brightness.isAvailable && BrightnessService.keyboardLightIsSupported
                // A Mac without a battery has no battery notices, so that card
                // is left out rather than shown waiting for Power.
                let hasBattery = PowerSampler.hasInternalBattery
                let batteryAvailable = AppFeature.monitorPower.isAvailable
                let accessoriesAvailable = AppFeature.notchAccessories.isAvailable && AppFeature.monitorPower.isAvailable
                let capturesAvailable = AppFeature.screenshot.isAvailable && NotchSupport.modules().contains(.captures)
                let musicAvailable = NotchSupport.modules().contains(.music)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: HexaTheme.Spacing.s)], spacing: HexaTheme.Spacing.s) {
                    toggleCard(text.indicatorVolume, symbol: "speaker.wave.2", value: $volume, available: volumeAvailable,
                               reason: enableFeatureReason(.mixer),
                               unavailableAction: { showFeature(.mixer) })
                    toggleCard(text.indicatorBrightness, symbol: "sun.max", value: $brightness, available: brightnessAvailable,
                               reason: AppFeature.brightness.isAvailable ? editor.enableSetting(FeatureStrings.brightness(l10n.language).enable) : enableFeatureReason(.brightness),
                               unavailableAction: {
                                   if AppFeature.brightness.isAvailable {
                                       FeatureWorkspaceWindow.shared.show(.brightness)
                                   } else {
                                       showFeature(.brightness)
                                   }
                               })
                    toggleCard(FeatureStrings.brightness(l10n.language).keyboardLight, symbol: "light.max", value: $keyboardLight,
                              available: keyboardLightAvailable,
                              reason: !AppFeature.brightness.isAvailable ? enableFeatureReason(.brightness) : editor.keyboardLightUnavailable,
                              unavailableAction: !AppFeature.brightness.isAvailable ? { showFeature(.brightness) } : nil)
                    if hasBattery {
                        toggleCard(text.battery, symbol: "battery.75percent", value: $battery, available: batteryAvailable,
                                   reason: enableFeatureReason(.monitorPower),
                                   unavailableAction: { showFeature(.monitorPower) })
                    }
                    toggleCard(FeatureStrings.notchActivities(l10n.language).accessories, symbol: "headphones", value: $accessoriesEnabled,
                              available: accessoriesAvailable,
                              reason: enableFeatureReason(AppFeature.monitorPower.isAvailable ? .notchAccessories : .monitorPower),
                              unavailableAction: {
                                  showFeature(AppFeature.monitorPower.isAvailable ? .notchAccessories : .monitorPower)
                              })
                    toggleCard(text.indicatorCaptures, symbol: "camera.viewfinder", value: $capture, available: capturesAvailable,
                               reason: AppFeature.screenshot.isAvailable ? editor.showPage(text.captures) : enableFeatureReason(.screenshot),
                               unavailableAction: {
                                   if AppFeature.screenshot.isAvailable { showModule(.captures) }
                                   else { showFeature(.screenshot) }
                               })
                    toggleCard(text.newTrack, symbol: "music.note", value: $trackChange, available: musicAvailable,
                               reason: editor.showPage(text.music),
                               unavailableAction: { showModule(.music) })
                }
                if accessoriesEnabled { Text(FeatureStrings.notchActivities(l10n.language).accessoryDescription).font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary) }
                if enabled, (volume || brightness || keyboardLight), !permissions.accessibility { PermissionRow(kind: .accessibility) }
            }
            let locked = FeatureStrings.notchLockScreen(l10n.language)
            HexaSection(locked.title) {
                switchRow("lock.display", locked.show, caption: locked.showHint, isOn: $lockScreen)
                switchRow("speaker.wave.2", locked.sounds, caption: locked.soundsHint, isOn: $lockSounds)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { contentWidth = $0 }
    }

    /// Como a ilha abre, onde ela aparece, para onde cada coisa abre e o que
    /// ela nunca mostra.
    private var behaviorPage: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.l) {
            HexaSection(editor.opening) {
                SettingsMenuRow(symbol: "cursorarrow", title: experience.openingMode, selection: openingBinding) {
                    Text(editor.clickOpen).tag(0)
                    Text(editor.hoverPreview).tag(1)
                    Text(editor.hoverExpand).tag(2)
                    Text(editor.hiddenUntilHover).tag(3)
                }
                if hover { hoverDelayControl }
                switchRow("hand.draw", FeatureStrings.notchGestures(l10n.language).title,
                          caption: gesturesEnabled ? FeatureStrings.notchGestures(l10n.language).hint : nil,
                          isOn: $gesturesEnabled)
                    .disabled(!AppFeature.notchGestures.isAvailable)
                switchRow("waveform.path", text.hapticFeedback, caption: text.hapticHint, isOn: $hapticFeedback)
                SettingsRow(symbol: "arrow.uturn.backward", title: editor.reopening) {
                    Picker(editor.reopening, selection: Binding(get: {
                        guard returnHome else { return "" }
                        return NotchModule(rawValue: homeModule) != nil
                            || NotchReopeningDestination(rawValue: homeModule) != nil
                            ? homeModule : NotchModule.controls.rawValue
                    }, set: { value in
                        returnHome = !value.isEmpty
                        if returnHome { homeModule = value }
                    })) {
                        Text(editor.lastPage).tag("")
                        Text(text.panel).tag(NotchReopeningDestination.appPanel.rawValue)
                        Text(text.sectionsTitle).tag(NotchReopeningDestination.explore.rawValue)
                        ForEach(NotchSupport.modules()) { module in
                            Text(module.title(l10n.language)).tag(module.rawValue)
                        }
                        if let saved = NotchModule(rawValue: homeModule), !NotchSupport.modules().contains(saved) {
                            Text(saved.title(l10n.language)).tag(homeModule).disabled(true)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }
            HexaSection(text.display) {
                switchRow("arrow.up.left.and.arrow.down.right", text.hideInFullscreen, isOn: $hideInFullscreen)
                switchRow("menubar.rectangle", text.coverMenus, caption: text.coverMenusHint, isOn: $coversMenus)
                // A mode this version no longer offers is treated as automatic, as the island does.
                SettingsMenuRow(symbol: "display.2", title: experience.displayPlacement, selection: displayBinding) {
                    Text(text.automatic).tag(NotchDisplay.automatic.rawValue)
                    Text(text.builtIn).tag(NotchDisplay.builtIn.rawValue)
                    Text(text.mainDisplay).tag(NotchDisplay.main.rawValue)
                    Text(text.followPointer).tag(NotchDisplay.pointer.rawValue)
                    Text(text.allDisplays).tag(NotchDisplay.all.rawValue)
                }
                if showsResolvedDisplay {
                    Text(String(format: experience.displayResolvedFormat, resolvedDisplayName))
                        .font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, settingsRowTextInset)
                }
            }
            HexaSection(editor.destinations) {
                destination(text.panel, symbol: "bubble.middle.top", value: $appPanel)
                Text(editor.appPanelHint).font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
                destination(experience.captureControlsLabel, symbol: "camera.viewfinder", value: $captureControls)
            }
            HexaSection(l10n.s.menuBarSection) {
                switchRow("menubar.rectangle", editor.hideMenuBarIcon, caption: editor.hideMenuBarIconHint,
                          isOn: $hidesMenuBarIcon)
            }
            HexaSection(editor.privacy) {
                switchRow("camera.viewfinder", text.showInCaptures, isOn: $showInCaptures)
            }
        }
    }

    private var hoverDelayControl: some View {
        let value = Binding(get: { NotchSupport.sanitizedHoverDelay(hoverDelay) },
                            set: { hoverDelay = NotchSupport.sanitizedHoverDelay($0) })
        let formatted = String(format: editor.activationTimeFormat, locale: Locale(identifier: l10n.language.rawValue), value.wrappedValue)
        return VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            HStack {
                Text(editor.activationTime)
                Spacer()
                Text(formatted).monospacedDigit().foregroundStyle(HexaTheme.fgSecondary)
            }
            Slider(value: value, in: NotchSupport.hoverDelayRange, step: 0.05) {
                Text(editor.activationTime)
            }.labelsHidden().accessibilityValue(formatted)
            Text(editor.activationTimeHint).font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The four ways the island opens, as one choice over the three settings behind it.
    /// Choosing a way sets only the settings that way needs, as the tiles did.
    private var openingBinding: Binding<Int> {
        Binding(get: {
            guard hover else { return 0 }
            if hideUntilHover { return 3 }
            return hoverExpand ? 2 : 1
        }, set: { mode in
            switch mode {
            case 0: hideUntilHover = false; hover = false
            case 1: hideUntilHover = false; hover = true; hoverExpand = false
            case 2: hideUntilHover = false; hover = true; hoverExpand = true
            default: hover = true; hoverExpand = true; hideUntilHover = true
            }
        })
    }

    private var displayBinding: Binding<String> {
        Binding(get: { (NotchDisplay(rawValue: display) ?? .automatic).rawValue }, set: { display = $0 })
    }

    /// Fixed placements name the display they land on; the two that follow the
    /// pointer already say it in the menu.
    private var showsResolvedDisplay: Bool {
        switch NotchDisplay(rawValue: display) ?? .automatic {
        case .automatic, .builtIn, .main: return true
        case .pointer, .all: return false
        }
    }

    /// The display the island will use for the chosen placement, read from the
    /// screens themselves so the row says where it lands instead of asking again.
    private var resolvedDisplayName: String {
        switch NotchDisplay(rawValue: display) ?? .automatic {
        case .automatic:
            let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
                ?? NSScreen.withMenuBar ?? NSScreen.main
            return screen?.localizedName ?? text.automatic
        case .builtIn:
            let screen = NSScreen.screens.first(where: { CGDisplayIsBuiltin($0.notchDisplayID) != 0 })
            return screen?.localizedName ?? text.builtIn
        case .main:
            return NSScreen.withMenuBar?.localizedName ?? text.mainDisplay
        case .pointer:
            return text.followPointer
        case .all:
            return text.allDisplays
        }
    }

    private func enableFeatureReason(_ feature: AppFeature) -> String {
        editor.enableFeature(feature.hubTitle(l10n.s, hub: FeatureStrings.hub(l10n.language)))
    }

    /// The Features hub, where a switched-off feature comes back. Inside the
    /// feature workspace the router alone changes nothing (Settings is not
    /// the visible surface), so the window itself switches to its embedded
    /// Settings, which the same request lands on the hub page (ISSUE-069).
    private func showFeature(_ feature: AppFeature?) {
        SettingsRouter.shared.request(FeatureSettingsDestination(.features), targetFeature: feature)
        FeatureWorkspaceState.shared.showsSettings = true
    }

    private func showModule(_ module: NotchModule) {
        chooseModule(module)
        selectTab(.content)
    }

    private func chooseModule(_ module: NotchModule) {
        selectedModule = module == .tools ? .controls : module
    }

    /// Troca a aba da página e avisa o sidebar da janela de funcionalidades:
    /// sem isso, o sidebar continua destacando a aba anterior.
    private func selectTab(_ newTab: NotchSettingsTab) {
        guard newTab != tab else { return }
        tab = newTab
        FeatureWorkspaceState.shared.notchTab = newTab
    }

    /// A control that opens a page is off while that page is hidden, or while
    /// the feature behind it is disabled; the others follow their feature.
    private func controlReason(_ item: NotchControlItem) -> String {
        switch item.setupRequirement {
        case .feature(let feature): return enableFeatureReason(feature)
        case .page(let module, let feature): return pageReason(module, feature: feature)
        case .none: return text.disabled
        }
    }

    private func controlUnavailableAction(_ item: NotchControlItem) -> (() -> Void)? {
        switch item.setupRequirement {
        case .feature(let feature):
            return { showFeature(feature) }
        case .page(let module, let feature):
            return {
                if let feature, !feature.isAvailable { showFeature(feature) }
                else { showModule(module) }
            }
        case .none: return nil
        }
    }

    /// The one feature a page needs; Captures and System accept any of several.
    private func moduleFeature(_ module: NotchModule) -> AppFeature? {
        switch module {
        case .controls, .music, .captures, .system, .tools: return nil
        case .mixer: return .mixer
        case .files: return .mediaTools
        case .calendar: return .notchCalendar
        case .notifications: return .notchNotifications
        case .timer: return .notchTimer
        case .downloads: return .notchDownloads
        case .watch: return .notchWatch
        }
    }

    private func pageReason(_ module: NotchModule, feature: AppFeature?) -> String {
        if let feature, !feature.isAvailable { return enableFeatureReason(feature) }
        return editor.showPage(module.title(l10n.language))
    }

    private func toggleCard(_ title: String, symbol: String, value: Binding<Bool>, available: Bool, reason: String? = nil,
                            unavailableAction: (() -> Void)? = nil) -> some View {
        NotchEditorItem(symbol: symbol, title: title, included: value, available: available,
                        unavailableReason: available ? nil : reason ?? text.disabled,
                        unavailableAction: unavailableAction) {
            value.wrappedValue.toggle()
        }
    }

    /// What the closed island rests with. A saved battery reading on a Mac
    /// without a battery, or a saved track without the Music section, rests empty.
    private var restingChoice: NotchIdleContent {
        let choice: NotchIdleContent = NotchIdleContent(rawValue: idle) ?? .none
        if choice == .battery, !PowerSampler.hasInternalBattery { return .none }
        if choice == .music, !NotchSupport.modules().contains(.music) { return .none }
        return choice
    }

    private var restingBinding: Binding<String> {
        Binding(get: { restingChoice.rawValue }, set: { idle = $0 })
    }

    private var restingOptions: [(String, String)] {
        var items = [(NotchIdleContent.none.rawValue, text.idleNone)]
        if PowerSampler.hasInternalBattery {
            items.append((NotchIdleContent.battery.rawValue, text.battery))
        }
        if NotchSupport.modules().contains(.music) {
            items.append((NotchIdleContent.music.rawValue, text.music))
        }
        return items
    }

    /// The resting choice in one line under the preview: the same title the
    /// choosing row offers, so the two never disagree.
    private var restingStateSummary: String {
        restingOptions.first(where: { $0.0 == restingChoice.rawValue })?.1 ?? text.idleNone
    }

    private func destination(_ title: String, symbol: String, value: Binding<Bool>, available: Bool = true) -> some View {
        SettingsChoiceRow(symbol: symbol, title: title, selection: value, options: [
            (true, text.title),
            (false, editor.separate),
        ]).disabled(!available)
    }

    /// An option with its icon, one line and a switch, like every other page.
    private func switchRow(_ symbol: String, _ title: String, caption: String? = nil, isOn: Binding<Bool>) -> some View {
        SettingsRow(symbol: symbol, title: title, caption: caption) {
            Toggle(title, isOn: isOn).labelsHidden().toggleStyle(HexaSwitchStyle())
        }
    }

    private func dimensionSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, fallback: Double) -> some View {
        let bounded = Binding(get: { NotchSize.clamped(value.wrappedValue, to: range, fallback: fallback) },
                              set: { value.wrappedValue = NotchSize.clamped($0, to: range, fallback: fallback) })
        return GridRow {
            // The slider carries the name for VoiceOver.
            Text(title).fixedSize().accessibilityHidden(true)
            Slider(value: bounded, in: range, step: 10) { Text(title) }.labelsHidden()
            Text(String(format: experience.pointsFormat, Int(bounded.wrappedValue)))
                .monospacedDigit().foregroundStyle(HexaTheme.fgSecondary).frame(width: 38)
        }
    }

    /// A correction around zero, signed so the untouched value reads as none.
    private func fitSlider(_ title: String, card: String, value: Binding<Double>, range: ClosedRange<Double>,
                           step: Double) -> some View {
        let bounded = Binding(get: { NotchSize.clamped(value.wrappedValue, to: range, fallback: 0) },
                              set: { value.wrappedValue = NotchSize.clamped($0, to: range, fallback: 0) })
        let formatted = bounded.wrappedValue.formatted(.number.sign(strategy: .always(includingZero: false))
            .precision(.fractionLength(0...1)).locale(Locale(identifier: l10n.language.rawValue)))
        let points = String(format: experience.pointsFormat, Int(bounded.wrappedValue.rounded()))
        return GridRow {
            Text(title).fixedSize().accessibilityHidden(true)
            // Other cards have sliders with the same names.
            Slider(value: bounded, in: range, step: step) { Text("\(card), \(title)") }.labelsHidden()
                .accessibilityValue(formatted)
            Text(points).monospacedDigit().foregroundStyle(HexaTheme.fgSecondary).frame(width: 38)
        }
    }
    private func controlBinding(_ item: NotchControlItem) -> Binding<Bool> {
        Binding {
            !hiddenControls.split(separator: ",").contains(Substring(item.rawValue))
        } set: { shown in
            var values = Set(hiddenControls.split(separator: ",").map(String.init))
            if shown { values.remove(item.rawValue) } else { values.insert(item.rawValue) }
            hiddenControls = values.sorted().joined(separator: ",")
        }
    }

    private func moduleBinding(_ module: NotchModule) -> Binding<Bool> {
        // Controls is the island's default interface and is never hidden (DEC-039).
        guard module != .controls else { return .constant(true) }
        return Binding {
            (module != .timer || timerEnabled)
                && (module != .calendar || calendarEnabled) && (module != .notifications || notificationsEnabled)
                && (module != .watch || watchEnabled)
                && (module != .downloads || downloadsEnabled)
                && !hidden.split(separator: ",").contains(Substring(module.rawValue))
        } set: { shown in
            if module == .timer { timerEnabled = shown }
            if module == .calendar { calendarEnabled = shown }
            if module == .notifications { notificationsEnabled = shown }
            if module == .watch { watchEnabled = shown }
            if module == .downloads { downloadsEnabled = shown }
            var values = Set(hidden.split(separator: ",").map(String.init))
            if shown { values.remove(module.rawValue) } else { values.insert(module.rawValue) }
            hidden = values.sorted().joined(separator: ",")
        }
    }

}

/// Ativação da ilha no cabeçalho da página, fora das abas: uma vez ligada,
/// o switch não precisa reaparecer em cada segmento.
struct NotchActivationControl: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchEnabled) private var enabled = false

    private var text: NotchStrings { FeatureStrings.notch(l10n.language) }

    var body: some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            HexaIconButton(icon: "arrow.up.forward.app", label: text.open, variant: .small) {
                NotchService.shared.open()
            }
            .disabled(!enabled)
            .help(text.open)
            Toggle(text.enable, isOn: $enabled)
                .labelsHidden()
                .toggleStyle(HexaSwitchStyle())
                .disabled(!AppFeature.notch.isAvailable)
                .accessibilityLabel(text.enable)
                .help(text.enableHint)
        }
        .fixedSize()
    }
}
