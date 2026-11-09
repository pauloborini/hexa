// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import SwiftUI

/// The "Menu Bar" settings page: segmented into two internal tabs so the user
/// can configure the macOS menu bar item in one tab and the command center
/// popover (monitoring cards and quick actions) in the other.
struct MenuBarSettings: View {
    enum Tab: Int, CaseIterable {
        case menuBar
        case commandCenter
    }

    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var state = FeatureWorkspaceState.shared

    @AppStorage(DefaultsKey.menuBarCombineTemperatures) private var combineTemperatures = true
    @AppStorage(DefaultsKey.menuBarSeparateMetrics) private var separateMetrics = false
    @AppStorage(DefaultsKey.menuBarMetricSpacing) private var metricSpacing = "standard"
    @AppStorage(DefaultsKey.menuBarMetricAppearance) private var metricAppearance = "values"
    @AppStorage(DefaultsKey.menuBarHideIconWithMetrics) private var hideIconWithMetrics = false
    @AppStorage(DefaultsKey.showCountdown) private var showCountdown = false
    @AppStorage(DefaultsKey.keepAwakeRightClickToggle) private var keepAwakeRightClick = false

    // Command center quick actions visibility
    @AppStorage(DefaultsKey.panelShowKeepAwake) private var showKeepAwake = true
    @AppStorage(DefaultsKey.panelUtilityScreenshot) private var showScreenshot = true
    @AppStorage(DefaultsKey.panelUtilityScreenOCR) private var showScreenOCR = true
    @AppStorage(DefaultsKey.panelUtilityCleaner) private var showCleaner = true
    @AppStorage(DefaultsKey.panelUtilityUninstaller) private var showUninstaller = true
    @AppStorage(DefaultsKey.panelUtilityAppUpdates) private var showAppUpdates = true
    @AppStorage(DefaultsKey.panelUtilityPortManager) private var showPortManager = true
    @AppStorage(DefaultsKey.panelUtilityKillProcess) private var showKillProcess = true
    @AppStorage(DefaultsKey.panelUtilityPurgeMemory) private var showPurgeMemory = true
    @AppStorage(DefaultsKey.panelUtilityFlushDNS) private var showFlushDNS = true
    @AppStorage(DefaultsKey.panelQuickBrightness) private var showQuickBrightness = true

    // Command center monitoring cards
    @AppStorage(DefaultsKey.monitorShowSystem) private var showSystem = true
    @AppStorage(DefaultsKey.panelShowFanControl) private var showFanControl = true
    @AppStorage(DefaultsKey.monitorSysFans) private var showFanSpeed = true
    @AppStorage(DefaultsKey.monitorShowMixer) private var showMixer = true
    @AppStorage(DefaultsKey.panelShowBrightness) private var showBrightness = true
    @AppStorage(DefaultsKey.monitorShowPower) private var showPower = true
    @AppStorage(DefaultsKey.monitorShowDisk) private var showDisk = true

    var body: some View {
        HexaScreenScaffold(
            title: l10n.s.menuBarSection,
            subtitle: state.menuBarTab == .menuBar ? l10n.s.monitorMenuBarCaption : appearanceStrings.commandCenterCaption,
            scrolls: true,
            pinned: {
                HexaSegmentControl(
                    [appearanceStrings.tabMenuBar, appearanceStrings.tabCommandCenter],
                    selection: Binding(
                        get: { state.menuBarTab.rawValue },
                        set: { if let tab = Tab(rawValue: $0) { state.menuBarTab = tab } }
                    )
                )
            }
        ) {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.l) {
                switch state.menuBarTab {
                case .menuBar:
                    menuBarCard
                    menuBarStyleCard
                case .commandCenter:
                    panelMetricsCard
                    if AppFeature.mixer.isAvailable || AppFeature.brightness.isAvailable {
                        islandPanelCard
                    }
                    quickShortcutsCard
                }
            }
            .padding(.horizontal, HexaTheme.Spacing.xxl)
            .id(state.menuBarTab)
        }
        .toggleStyle(HexaSwitchStyle())
        .onAppear {
            metricAppearance = Defaults.sanitizedMenuBarMetricAppearance(metricAppearance)
        }
    }

    private var appearanceStrings: MenuBarAppearanceStrings {
        FeatureStrings.menuBarAppearance(l10n.language)
    }

    private var appearance: MenuBarMetricAppearance {
        MenuBarMetricAppearance(rawValue: Defaults.sanitizedMenuBarMetricAppearance(metricAppearance)) ?? .values
    }

    /// The readings that can sit in the menu bar, as tiles in the order they appear there.
    private var menuBarCard: some View {
        HexaSection(appearanceStrings.barReadingsSection) {
            MenuBarMetricsPreview()
            HairlineDivider()
            Text(l10n.s.monitorMenuBarCaption)
                .font(.hexa(.body))
                .foregroundStyle(HexaTheme.fgSecondary)
                .fixedSize(horizontal: false, vertical: true)
            MenuBarMetricTiles()
            Text(FeatureStrings.notchEditor(l10n.language).reorderHint)
                .hexaCaption()
        }
    }

    private var menuBarStyleCard: some View {
        HexaSection(appearanceStrings.label) {
            HStack(spacing: HexaTheme.Spacing.s) {
                MenuBarStyleChoice(appearance: .values, title: appearanceStrings.values,
                                   selected: appearance == .values) { metricAppearance = "values" }
                MenuBarStyleChoice(appearance: .bars, title: appearanceStrings.bars,
                                   selected: appearance == .bars) { metricAppearance = "bars" }
            }
            Text(appearanceStrings.caption)
                .hexaCaption()
            if appearance == .bars {
                MenuBarUsageBarSettings(strings: appearanceStrings)
            } else {
                SettingsRow(symbol: "thermometer.medium", title: l10n.s.monitorCombineTemperatures,
                            caption: l10n.s.monitorCombineTemperaturesCaption) {
                    Toggle(l10n.s.monitorCombineTemperatures, isOn: $combineTemperatures).labelsHidden()
                }
            }
            HairlineDivider()
            SettingsRow(symbol: "arrow.left.and.right", title: l10n.s.menuBarSpacingLabel) {
                Picker(l10n.s.menuBarSpacingLabel, selection: $metricSpacing) {
                    Text(l10n.s.menuBarSpacingStandard).tag("standard")
                    Text(l10n.s.menuBarSpacingCompact).tag("compact")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            SettingsRow(symbol: "eye.slash", title: l10n.s.menuBarHideIconToggle,
                        caption: l10n.s.menuBarHideIconCaption) {
                Toggle(l10n.s.menuBarHideIconToggle, isOn: $hideIconWithMetrics).labelsHidden()
            }
            SettingsRow(symbol: "rectangle.split.3x1", title: l10n.s.monitorSeparateMenuBarMetrics,
                        caption: appearance.allowsCombinedTemperatures
                            ? l10n.s.monitorSeparateMenuBarMetricsCaption : nil) {
                Toggle(l10n.s.monitorSeparateMenuBarMetrics, isOn: $separateMetrics).labelsHidden()
            }
            if AppFeature.keepAwake.isAvailable {
                HairlineDivider()
                SettingsRow(symbol: "timer", title: l10n.s.showCountdown) {
                    Toggle(l10n.s.showCountdown, isOn: $showCountdown).labelsHidden()
                }
                SettingsRow(symbol: "cursorarrow.click.2", title: l10n.s.keepAwakeRightClickToggle,
                            caption: l10n.s.keepAwakeRightClickToggleCaption) {
                    Toggle(l10n.s.keepAwakeRightClickToggle, isOn: $keepAwakeRightClick).labelsHidden()
                }
            }
        }
    }

    /// Centralized quick actions shown in the command center popover.
    private var quickShortcutsCard: some View {
        HexaSection(appearanceStrings.quickActionsSection) {
            if AppFeature.keepAwake.isAvailable {
                SettingsRow(symbol: "cup.and.saucer.fill", title: l10n.s.keepAwakeTitle) {
                    Toggle(l10n.s.keepAwakeTitle, isOn: $showKeepAwake).labelsHidden()
                }
            }
            if AppFeature.screenshot.isAvailable {
                SettingsRow(symbol: "camera.viewfinder", title: FeatureStrings.screenshot(l10n.language).pageTitle) {
                    Toggle(FeatureStrings.screenshot(l10n.language).pageTitle, isOn: $showScreenshot).labelsHidden()
                }
            }
            if AppFeature.screenOCR.isAvailable {
                SettingsRow(symbol: "text.viewfinder", title: l10n.s.ocrName) {
                    Toggle(l10n.s.ocrName, isOn: $showScreenOCR).labelsHidden()
                }
            }
            if AppFeature.cleaner.isAvailable {
                SettingsRow(symbol: "sparkles", title: l10n.s.cleanerName) {
                    Toggle(l10n.s.cleanerName, isOn: $showCleaner).labelsHidden()
                }
            }
            if AppFeature.uninstaller.isAvailable {
                SettingsRow(symbol: "trash", title: l10n.s.uninstallerName) {
                    Toggle(l10n.s.uninstallerName, isOn: $showUninstaller).labelsHidden()
                }
            }
            if AppFeature.appUpdates.isAvailable {
                SettingsRow(symbol: "arrow.triangle.2.circlepath", title: FeatureStrings.appUpdates(l10n.language).pageTitle) {
                    Toggle(FeatureStrings.appUpdates(l10n.language).pageTitle, isOn: $showAppUpdates).labelsHidden()
                }
            }
            if AppFeature.portManager.isAvailable {
                SettingsRow(symbol: "point.3.connected.trianglepath.dotted", title: FeatureStrings.portManager(l10n.language).title) {
                    Toggle(FeatureStrings.portManager(l10n.language).title, isOn: $showPortManager).labelsHidden()
                }
            }
            if AppFeature.killProcess.isAvailable {
                SettingsRow(symbol: "xmark.octagon", title: FeatureStrings.killProcess(l10n.language).pageTitle) {
                    Toggle(FeatureStrings.killProcess(l10n.language).pageTitle, isOn: $showKillProcess).labelsHidden()
                }
            }
            if AppFeature.maintenanceTasks.isAvailable {
                SettingsRow(symbol: "memorychip", title: FeatureStrings.maintenanceTasks(l10n.language).taskPurgeMemoryTitle) {
                    Toggle(FeatureStrings.maintenanceTasks(l10n.language).taskPurgeMemoryTitle, isOn: $showPurgeMemory).labelsHidden()
                }
                SettingsRow(symbol: "network", title: FeatureStrings.maintenanceTasks(l10n.language).taskFlushDNSTitle) {
                    Toggle(FeatureStrings.maintenanceTasks(l10n.language).taskFlushDNSTitle, isOn: $showFlushDNS).labelsHidden()
                }
            }
            if AppFeature.brightness.isAvailable {
                SettingsRow(symbol: "display", title: FeatureStrings.brightness(l10n.language).pageTitle) {
                    Toggle(FeatureStrings.brightness(l10n.language).pageTitle, isOn: $showQuickBrightness).labelsHidden()
                }
            }
        }
    }

    /// Centralized monitoring cards shown at the top of the command center popover.
    private var panelMetricsCard: some View {
        HexaSection(appearanceStrings.monitoringCardsSection) {
            if AppFeature.monitorCPU.isAvailable || AppFeature.monitorMemory.isAvailable {
                SettingsRow(symbol: "cpu", title: l10n.s.systemSection) {
                    Toggle(l10n.s.systemSection, isOn: $showSystem).labelsHidden()
                }
            }
            if AppFeature.fanControl.isAvailable {
                let fanTitle = FeatureStrings.fanControl(l10n.language).fanCompactTitle
                SettingsRow(symbol: "fanblades", title: fanTitle) {
                    // One switch for both fan surfaces: the command center's RPM card
                    // reads monitorSysFans, the panel's FanControl section the other key.
                    Toggle(fanTitle, isOn: Binding(get: { showFanSpeed },
                                                   set: { showFanSpeed = $0; showFanControl = $0 }))
                        .labelsHidden()
                }
            }
            if AppFeature.monitorPower.isAvailable {
                SettingsRow(symbol: "bolt.fill", title: l10n.s.powerSection) {
                    Toggle(l10n.s.powerSection, isOn: $showPower).labelsHidden()
                }
            }
            if AppFeature.monitorDisk.isAvailable {
                SettingsRow(symbol: "internaldrive", title: l10n.s.diskSection) {
                    Toggle(l10n.s.diskSection, isOn: $showDisk).labelsHidden()
                }
            }
        }
    }

    /// Sections the Dynamic Island panel shows, separate from the command center cards.
    private var islandPanelCard: some View {
        HexaSection(appearanceStrings.islandPanelSection) {
            if AppFeature.mixer.isAvailable {
                SettingsRow(symbol: "slider.vertical.3", title: l10n.s.mixerSection) {
                    Toggle(l10n.s.mixerSection, isOn: $showMixer).labelsHidden()
                }
            }
            if AppFeature.brightness.isAvailable {
                let brightnessTitle = FeatureStrings.brightness(l10n.language).pageTitle
                SettingsRow(symbol: "sun.max.fill", title: brightnessTitle) {
                    Toggle(brightnessTitle, isOn: $showBrightness).labelsHidden()
                }
            }
        }
    }
}

/// Values or bars, each drawn the way the menu bar would draw a CPU reading.
private struct MenuBarStyleChoice: View {
    let appearance: MenuBarMetricAppearance
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: HexaTheme.Spacing.s) {
                mockup
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(HexaTheme.surfaceInset, in: RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
                Text(title)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgPrimary)
            }
            .padding(HexaTheme.Spacing.s)
            .frame(maxWidth: .infinity)
            .background(selected ? HexaTheme.selectionBg : HexaTheme.surfaceInset,
                        in: RoundedRectangle(cornerRadius: HexaTheme.Radius.panel, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: HexaTheme.Radius.panel, style: .continuous)
                    .strokeBorder(selected ? HexaTheme.accentSolid : .clear, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.panel, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var mockup: some View {
        switch appearance {
        case .values:
            HStack(spacing: HexaTheme.Spacing.s) {
                block(label: "CPU", value: "42%")
                block(label: "RAM", value: "61%")
            }
        case .bars:
            HStack(spacing: HexaTheme.Spacing.s) {
                bar(label: "CPU", fraction: 0.42)
                bar(label: "RAM", fraction: 0.61)
            }
        }
    }

    private func block(label: String, value: String) -> some View {
        VStack(spacing: -1) {
            Text(label)
                .font(.hexa(.micro))
            Text(value)
                .font(.hexa(.body))
        }
        .foregroundStyle(HexaTheme.fgPrimary)
    }

    private func bar(label: String, fraction: CGFloat) -> some View {
        HStack(spacing: HexaTheme.Spacing.xs) {
            VStack(spacing: -1.8) {
                ForEach(Array(label.enumerated()), id: \.offset) { _, character in
                    Text(String(character))
                        .font(.hexa(.micro))
                }
            }
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 2.2, style: .continuous)
                    .stroke(HexaTheme.fgPrimary, lineWidth: 1.15)
                RoundedRectangle(cornerRadius: 1.2, style: .continuous)
                    .fill(HexaTheme.accentSolid)
                    .frame(width: 4.8, height: 13.8 * fraction)
                    .padding(.bottom, 2.1)
            }
            .frame(width: 9, height: 18)
        }
        .foregroundStyle(HexaTheme.fgPrimary)
    }
}

extension MenuBarMetric: PanelOrderItem {}

/// The menu bar readings as tiles: drag to put them in order, click the
/// checkmark to show or hide one.
private struct MenuBarMetricTiles: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @AppStorage(DefaultsKey.menuBarMetricOrder) private var metricOrder = ""
    @State private var order: [MenuBarMetric] = MenuBarMetric.order(in: .standard)
    @State private var dragging: MenuBarMetric?

    var body: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            LazyVGrid(columns: monitorTokenColumns, spacing: HexaTheme.Spacing.s) {
                ForEach(visibleOrder) { metric in
                    PanelReorderableItem(item: metric, order: $order, dragging: $dragging) {
                        MenuBarMetricTile(metric: metric)
                    }
                }
            }
            .monitorTokenGroup()
        }
        .onAppear { order = MenuBarMetric.order(in: .standard) }
        .onChange(of: order) { _, order in
            if order != MenuBarMetric.order(in: .standard) { MenuBarMetric.setOrder(order) }
        }
        .onChange(of: metricOrder) { _, _ in order = MenuBarMetric.order(in: .standard) }
    }

    private var visibleOrder: [MenuBarMetric] {
        order.filter { $0.feature.isAvailable && $0.isAvailableOnCurrentHardware }
    }
}

/// One reading, backed by its own key so the preview above updates immediately.
private struct MenuBarMetricTile: View {
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.colorScheme) private var colorScheme
    let metric: MenuBarMetric
    @AppStorage private var shown: Bool
    @AppStorage(DefaultsKey.menuBarMemoryStyle) private var memoryStyle = "percent"
    @AppStorage(DefaultsKey.menuBarNetworkUploadFirst) private var uploadFirst = false
    @AppStorage(DiskMenuBarStyle.defaultsKey) private var diskStyle = DiskMenuBarStyle.percent

    init(metric: MenuBarMetric) {
        self.metric = metric
        _shown = AppStorage(wrappedValue: false, metric.defaultsKey)
    }

    var body: some View {
        MonitorToken(symbol: metric.symbolName, title: metric.title(l10n.s), included: $shown,
                     options: options, optionsSummary: optionsSummary)
    }

    private var optionsSummary: String {
        switch metric {
        case .memory:
            return Defaults.sanitizedMenuBarMemoryStyle(memoryStyle) != "percent"
                ? l10n.s.monitorMemoryPressureDot : MediaImageConverterStrings.localized(l10n.language).moreOptions
        case .network: return uploadFirst ? "↑ ↓" : "↓ ↑"
        case .diskUsage:
            switch diskStyle {
            case DiskMenuBarStyle.free: return l10n.s.diskMenuBarAvailableSpace
            case DiskMenuBarStyle.used: return l10n.s.diskMenuBarUsedSpace
            default: return l10n.s.diskMenuBarUsedPercentage
            }
        default: return ""
        }
    }

    private var options: AnyView? {
        switch metric {
        case .memory:
            return AnyView(MonitorTokenOption(
                symbol: "circle.fill",
                title: l10n.s.monitorMemoryPressureDot,
                tint: PanelMetricColor.green(for: colorScheme),
                isOn: Binding(get: { Defaults.sanitizedMenuBarMemoryStyle(memoryStyle) != "percent" },
                              set: { memoryStyle = $0 ? "both" : "percent" })))
        case .network:
            return AnyView(MonitorTokenOption(symbol: "arrow.up.arrow.down",
                                                 title: l10n.s.monitorNetworkUploadFirst,
                                                 isOn: $uploadFirst))
        case .diskUsage:
            return AnyView(Picker(l10n.s.diskMenuBarStyleLabel, selection: $diskStyle) {
                Text(l10n.s.diskMenuBarUsedPercentage).tag(DiskMenuBarStyle.percent)
                Text(l10n.s.diskMenuBarAvailableSpace).tag(DiskMenuBarStyle.free)
                Text(l10n.s.diskMenuBarUsedSpace).tag(DiskMenuBarStyle.used)
            }
            .pickerStyle(.menu))
        default:
            return nil
        }
    }
}

private struct MenuBarUsageBarSettings: View {
    let strings: MenuBarAppearanceStrings

    @AppStorage(DefaultsKey.menuBarUsageBarNormalColor) private var normalColor = MenuBarUsageBarSupport.defaultNormalColor
    @AppStorage(DefaultsKey.menuBarUsageBarElevatedColor) private var elevatedColor = MenuBarUsageBarSupport.defaultElevatedColor
    @AppStorage(DefaultsKey.menuBarUsageBarCriticalColor) private var criticalColor = MenuBarUsageBarSupport.defaultCriticalColor
    @AppStorage(DefaultsKey.menuBarUsageBarMediumThreshold) private var mediumThreshold = MenuBarUsageBarSupport.defaultMediumThreshold
    @AppStorage(DefaultsKey.menuBarUsageBarHighThreshold) private var highThreshold = MenuBarUsageBarSupport.defaultHighThreshold

    var body: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            Text(strings.customize)
                .font(.hexa(.body))

            ColorPicker(strings.normalColor,
                        selection: colorBinding($normalColor,
                                                fallback: MenuBarUsageBarSupport.defaultNormalColor),
                        supportsOpacity: false)
            ColorPicker(strings.mediumColor,
                        selection: colorBinding($elevatedColor,
                                                fallback: MenuBarUsageBarSupport.defaultElevatedColor),
                        supportsOpacity: false)
            ColorPicker(strings.highColor,
                        selection: colorBinding($criticalColor,
                                                fallback: MenuBarUsageBarSupport.defaultCriticalColor),
                        supportsOpacity: false)

            HairlineDivider()

            Stepper(value: mediumBinding, in: 1...99) {
                HStack {
                    Text(strings.mediumFrom)
                    Spacer()
                    Text("\(mediumThreshold)%")
                        .monospacedDigit()
                }
            }
            Stepper(value: highBinding, in: 2...100) {
                HStack {
                    Text(strings.highFrom)
                    Spacer()
                    Text("\(highThreshold)%")
                        .monospacedDigit()
                }
            }
        }
        .onAppear(perform: sanitize)
    }

    private var mediumBinding: Binding<Int> {
        Binding(get: { mediumThreshold },
                set: { mediumThreshold = min(max(1, $0), max(1, highThreshold - 1)) })
    }

    private var highBinding: Binding<Int> {
        Binding(get: { highThreshold },
                set: { highThreshold = min(100, max(mediumThreshold + 1, $0)) })
    }

    private func colorBinding(_ storage: Binding<String>, fallback: String) -> Binding<Color> {
        Binding {
            let rgb = MenuBarUsageBarSupport.rgb(for: storage.wrappedValue, fallback: fallback)
            return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
        } set: { color in
            guard let converted = NSColor(color).usingColorSpace(.sRGB) else { return }
            storage.wrappedValue = MenuBarUsageBarSupport.hex(red: Double(converted.redComponent),
                                                              green: Double(converted.greenComponent),
                                                              blue: Double(converted.blueComponent))
        }
    }

    private func sanitize() {
        normalColor = MenuBarUsageBarSupport.sanitizedColorHex(normalColor,
                                                               fallback: MenuBarUsageBarSupport.defaultNormalColor)
        elevatedColor = MenuBarUsageBarSupport.sanitizedColorHex(elevatedColor,
                                                                 fallback: MenuBarUsageBarSupport.defaultElevatedColor)
        criticalColor = MenuBarUsageBarSupport.sanitizedColorHex(criticalColor,
                                                                 fallback: MenuBarUsageBarSupport.defaultCriticalColor)
        let thresholds = MenuBarUsageBarSupport.thresholds(medium: mediumThreshold,
                                                           high: highThreshold)
        mediumThreshold = thresholds.medium
        highThreshold = thresholds.high
    }
}
