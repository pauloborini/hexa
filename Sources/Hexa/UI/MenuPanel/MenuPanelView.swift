// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import Combine
import SwiftUI

extension Notification.Name {
    static let menuPanelWillShow = Notification.Name("HexaMenuPanelWillShow")
}

struct MenuPanelFocusRequest: Equatable {
    let target: MenuPanelFocusTarget
    let serial: Int
}

enum MenuPanelFocusTarget: Equatable {
    case normal
    case section(PanelSectionID)
    case metric(MetricDetailKind)
}

final class MenuPanelFocus: ObservableObject {
    static let shared = MenuPanelFocus()

    @Published private(set) var request: MenuPanelFocusRequest?
    @Published private(set) var activeMetric: MetricDetailKind?
    @Published private(set) var isSwitchingMetricAnchor = false
    @Published private(set) var popoverIsVisible = false
    private var serial = 0

    private init() {}

    func showNormalPanel() {
        serial += 1
        activeMetric = nil
        request = MenuPanelFocusRequest(target: .normal, serial: serial)
    }

    func focus(_ section: PanelSectionID) {
        serial += 1
        activeMetric = nil
        request = MenuPanelFocusRequest(target: .section(section), serial: serial)
    }

    func focus(_ metric: MetricDetailKind) {
        serial += 1
        activeMetric = metric
        request = MenuPanelFocusRequest(target: .metric(metric), serial: serial)
    }

    func clearMetricFocus() {
        activeMetric = nil
    }

    func setSwitchingMetricAnchor(_ switching: Bool) {
        isSwitchingMetricAnchor = switching
    }

    func setPopoverVisible(_ visible: Bool) {
        guard popoverIsVisible != visible else { return }
        popoverIsVisible = visible
    }
}

/// App panel embedded in the Dynamic Island (`MenuPanelView(notchSize:)`):
/// keep-awake controls, the volume mixer and the system monitor. The menu bar
/// popover is `QuickControlPanel`, not this view.
struct MenuPanelView: View {
    var notchSize: CGSize? = nil
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var panelFocus = MenuPanelFocus.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(DefaultsKey.monitorShowMixer) private var showMixer = true
    @AppStorage(DefaultsKey.monitorShowSystem) private var showSystem = true
    @AppStorage(DefaultsKey.monitorShowNetwork) private var showNetwork = true
    @AppStorage(DefaultsKey.monitorShowDisk) private var showDisk = true
    @AppStorage(DefaultsKey.monitorShowPower) private var showPower = true
    @AppStorage(DefaultsKey.monitorSysFans) private var sysFans = true
    @AppStorage(DefaultsKey.panelShowFanControl) private var showFanControl = true
    @AppStorage(DefaultsKey.panelShowKeepAwake) private var showKeepAwake = true
    @AppStorage(DefaultsKey.panelShowBrightness) private var showBrightness = true
    @AppStorage(DefaultsKey.brightnessControlEnabled) private var brightnessEnabled = false
    @AppStorage(DefaultsKey.panelShowUtilities) private var showUtilities = true
    @AppStorage(DefaultsKey.panelSectionOrder) private var sectionOrderRaw = ""
    @State private var selectedDomain: HexaDomain = (PanelLayout.order.first ?? .keepAwake).domain
    @State private var selectedSection: PanelSectionID = PanelLayout.order.first ?? .keepAwake
    @State private var selectedMetric: MetricDetailKind?
    @FocusState private var focusedSection: PanelSectionID?

    /// Cap the panel to the usable screen height so it never overflows the menu
    /// bar; taller content scrolls inside. Measured against the display the
    /// menu bar icon is on, which is not always the one holding the key window.
    /// The popover's window is the panel plus 13 pt for the arrow and 13 pt
    /// below it, and a window taller than the usable height makes AppKit open
    /// the popover beside the icon instead of under it. The cap leaves those
    /// 26 pt and 2 more.
    private var maxHeight: CGFloat {
        let anchored = PanelInteractionState.shared.anchorScreen
            .flatMap { anchor in anchor.isStillAttached ? anchor : nil }
        return max(360, ((anchored ?? NSScreen.withMenuBar)?.visibleFrame.height ?? 760) - 28)
    }

    var body: some View {
        Group {
            if let notchSize {
                embeddedPanel(size: notchSize)
            } else if selectedMetric != nil {
                metricPanel
            } else {
                navigablePanel
            }
        }
        // Superfície de vidro na raiz do conteúdo do popover: cobre 100% do
        // balão (topo e lateral direita incluídos, cantos no recorte do
        // próprio popover). O painel embutido no notch mantém a superfície
        // do host.
        .modifier(PopoverRootSurface(isEmbeddedInNotch: notchSize != nil))
        .font(.hexa(.body))
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82), value: selectedMetric)
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82), value: selectedDomain)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: activeSection)
        .onAppear {
            applyFocus(panelFocus.request)
            selectedDomain = activeSection.domain
            // The sudo probe belongs to an installed Keep Awake on show.
            if PanelLayout.isVisibleInPanel(.keepAwake) {
                KeepAwakeManager.shared.refreshPasswordlessStatus()
            }
            syncMonitorSampling()
        }
        .onReceive(NotificationCenter.default.publisher(for: .menuPanelWillShow)) { _ in
            syncMonitorSampling()
        }
        .onDisappear {
            if !panelFocus.isSwitchingMetricAnchor {
                SystemMonitor.shared.setMenuPanelNeeds(.none)
            }
        }
        .onChange(of: monitorNeeds) { _, _ in
            syncMonitorSampling()
        }
        .onChange(of: sysFans) { _, _ in
            syncMonitorSampling()
        }
        .onChange(of: panelFocus.request) { _, request in
            applyFocus(request)
        }
        .onChange(of: selectedSection) { _, section in
            if selectedDomain != section.domain {
                selectedDomain = section.domain
            }
        }
        .onChange(of: focusedSection) { _, section in
            if let section { selectedSection = section }
        }
    }

    private var monitorNeeds: SystemMonitorPanelNeeds {
        if let selectedMetric {
            return selectedMetric.monitorNeeds
        }
        guard selectedDomain == .telemetry else {
            return .none
        }
        switch activeSection {
        case .system:
            return SystemMonitorPanelNeeds(
                system: true,
                fanSpeed: sysFans && AppFeature.fanControl.isAvailable
            )
        case .fanControl:
            return SystemMonitorPanelNeeds(fanSpeed: true)
        case .network: return SystemMonitorPanelNeeds(network: true)
        case .disk: return SystemMonitorPanelNeeds(disk: true)
        case .power: return SystemMonitorPanelNeeds(power: true, peripheralBattery: true)
        default: return .none
        }
    }

    private func syncMonitorSampling() {
        SystemMonitor.shared.setMenuPanelNeeds(monitorNeeds)
    }

    private func applyFocus(_ request: MenuPanelFocusRequest?) {
        guard let request else { return }
        switch request.target {
        case .normal:
            selectedMetric = nil
        case .section(let section):
            guard isSectionVisible(section) else { return }
            selectedMetric = nil
            selectedSection = section
            selectedDomain = section.domain
            focusedSection = section
        case .metric(let metric):
            focusedSection = nil
            selectedMetric = metric
            selectedSection = metric.panelSection
            selectedDomain = metric.panelSection.domain
        }
    }

    private func clearMetricSelection() {
        if let metric = selectedMetric {
            selectedSection = metric.panelSection
            selectedDomain = metric.panelSection.domain
        }
        selectedMetric = nil
        MenuPanelFocus.shared.clearMetricFocus()
    }

    /// Uses the same sections and actions inside an existing surface. The
    /// host already supplies the title and material; one native scroll view
    /// keeps long sections usable without nesting two scroll regions.
    /// This is the only reachable branch: the only call site passes `notchSize`.
    private func embeddedPanel(size: CGSize) -> some View {
        VStack(spacing: HexaTheme.Spacing.m) {
            Group {
                if let selectedMetric {
                    HexaBreadcrumbHeader(metric: selectedMetric) {
                        clearMetricSelection()
                    }
                } else {
                    HexaDomainNav(
                        selectedDomain: $selectedDomain,
                        selectedSection: $selectedSection,
                        visibleSections: visibleSections,
                        isEmbeddedInNotch: true
                    )
                }
            }
            OverlayScrollView {
                Group {
                    if let selectedMetric { MetricDetailView(kind: selectedMetric) }
                    else { section(for: activeSection, collapsible: false) }
                }
                .frame(maxWidth: .infinity)
                .environment(\.notchPresentation, true)
                .environment(\.colorScheme, .dark)
            }
            .frame(width: size.width, height: max(0, size.height - (hasSecondaryDomainNavigation ? 124 : 96)))
            HexaPanelFooter(isEmbeddedInNotch: true)
        }
        .frame(width: size.width, height: size.height, alignment: .top)
    }

    /// Painel de dimensões ESTÁVEIS: largura e altura fixas (limitadas pela
    /// tela); trocar de domínio, seção ou expandir opções rola o conteúdo
    /// dentro da área fixa, sem redimensionar o popover.
    private var fixedPanelHeight: CGFloat {
        min(maxHeight, HexaPanelMetrics.panelHeight)
    }

    /// Unreachable in the current call graph: `body` uses this branch only when
    /// `notchSize` is nil, and the only call site always passes it. Kept in place.
    private var navigablePanel: some View {
        HexaPanelContainer(
            height: fixedPanelHeight,
            rail: {
                HexaDomainRail(
                    selectedDomain: $selectedDomain,
                    selectedSection: railSectionSelection,
                    visibleSections: visibleSections
                )
            },
            header: {
                header
            },
            content: {
                GeometryReader { proxy in
                    OverlayScrollView {
                        VStack(alignment: .leading, spacing: HexaTheme.Spacing.m) {
                            section(for: activeSection, collapsible: false)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(width: HexaPanelMetrics.contentWidth, height: proxy.size.height)
                }
                .padding(HexaPanelMetrics.padding)
                .background(HexaTheme.surfaceBase)
            },
            footer: {
                HexaPanelFooter()
            }
        )
    }

    /// Unreachable in the current call graph: `body` uses this branch only when
    /// `notchSize` is nil, and the only call site always passes it. Kept in place.
    private var metricPanel: some View {
        HexaPanelContainer(
            height: fixedPanelHeight,
            rail: {
                HexaDomainRail(
                    selectedDomain: $selectedDomain,
                    selectedSection: railSectionSelection,
                    visibleSections: visibleSections
                )
            },
            header: {
                header
            },
            content: {
                if let selectedMetric {
                    VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                        HexaBreadcrumbHeader(metric: selectedMetric) {
                            clearMetricSelection()
                        }
                        .padding(.horizontal, HexaPanelMetrics.padding)
                        .padding(.top, HexaPanelMetrics.padding)

                        GeometryReader { proxy in
                            OverlayScrollView {
                                MetricDetailView(kind: selectedMetric)
                                    .frame(maxWidth: .infinity)
                            }
                            .frame(width: HexaPanelMetrics.contentWidth, height: proxy.size.height)
                        }
                        .padding(.horizontal, HexaPanelMetrics.padding)
                    }
                    .background(HexaTheme.surfaceBase)
                }
            },
            footer: {
                HexaPanelFooter()
            }
        )
    }

    /// Seleção de seção vinda da rail: sai de um detalhe de métrica aberto
    /// antes de trocar a seção (a rail fica visível nos dois modos).
    private var railSectionSelection: Binding<PanelSectionID> {
        Binding(
            get: { selectedSection },
            set: { newValue in
                if selectedMetric != nil {
                    selectedMetric = nil
                    MenuPanelFocus.shared.clearMetricFocus()
                }
                selectedSection = newValue
            }
        )
    }

    /// The major sections in the user's saved order. Reading `sectionOrderRaw`
    /// (the @AppStorage backing) establishes the dependency so reordering in
    /// Settings refreshes the live panel; PanelLayout fills in any sections the
    /// saved order omits.
    private var orderedSections: [PanelSectionID] {
        _ = sectionOrderRaw
        return PanelLayout.order
    }

    private var visibleSections: [PanelSectionID] {
        orderedSections.filter(isSectionVisible)
    }

    private var activeSection: PanelSectionID {
        visibleSections.contains(selectedSection) ? selectedSection : (visibleSections.first ?? .keepAwake)
    }

    private var hasSecondaryDomainNavigation: Bool {
        let inDomain = visibleSections.filter { selectedDomain.sections.contains($0) }
        return inDomain.count > 1
    }

    /// Renders the section for an id, honoring its "show in panel" toggle. Each
    /// section self-hides when it has nothing to show, so the order is stable
    /// whether or not a section is currently populated.
    @ViewBuilder
    private func section(for id: PanelSectionID, collapsible: Bool = true) -> some View {
        switch id {
        case .keepAwake: KeepAwakeCard(collapsible: collapsible)
        case .brightness: if showBrightness { BrightnessSection(collapsible: collapsible) }
        case .mixer: if showMixer { MixerSection(collapsible: collapsible) }
        case .system: if showSystem { SystemSection(collapsible: collapsible) }
        case .network: if showNetwork { NetworkSection(collapsible: collapsible) }
        case .disk: if showDisk { DiskSection(collapsible: collapsible) }
        case .power: if showPower { PowerSection(collapsible: collapsible) }
        case .fanControl:
            // The popover retains its host after closing; detach the curve editor
            // so cooling heartbeats cannot keep laying out an unseen panel.
            if showFanControl, notchSize != nil || panelFocus.popoverIsVisible {
                FanControlSection(collapsible: collapsible)
            }
        case .utilities: UtilitiesSection(collapsible: collapsible)
        }
    }

    /// The rule lives in PanelLayout; reading the @AppStorage values here is
    /// what keeps the tabs refreshing when Settings flips one of them.
    private func isSectionVisible(_ id: PanelSectionID) -> Bool {
        _ = (showKeepAwake, showBrightness, brightnessEnabled, showMixer, showSystem, showNetwork,
             showDisk, showPower, showFanControl, showUtilities)
        return PanelLayout.isVisibleInPanel(id)
    }

    private var header: some View {
        MenuPanelHeader()
    }
}

/// Superfície de vidro na raiz do conteúdo do popover (Fase 2, fresta):
/// aplicada no nível mais externo do hosting view, com a safe area do balão
/// no escopo, o fundo cobre a janela inteira (topo e lateral direita
/// incluídos). O painel embutido no notch preserva a superfície do host.
private struct PopoverRootSurface: ViewModifier {
    let isEmbeddedInNotch: Bool

    func body(content: Content) -> some View {
        if isEmbeddedInNotch {
            content
        } else {
            // Accent taupe ambiente no popover (mesmo padrão de FeatureWorkspace
            // e Ajustes): controles nativos sem tint explícito não caem no azul
            // de sistema. O painel embutido no notch mantém o tint do host.
            content
                .panelGlassSurface()
                .tint(HexaTheme.accentSolid)
        }
    }
}

/// Header of the rail layout only (`navigablePanel` and `metricPanel`), which is
/// unreachable in the current call graph. Kept in place.
private struct MenuPanelHeader: View {
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        ZStack {
            // PanelHeader (spec §7): lockup marca + wordmark CENTRALIZADO e
            // maior; sem slot de estado (o hash/versão saiu do painel).
            HStack(spacing: HexaTheme.Spacing.m) {
                BrandMark(width: HexaPanelMetrics.headerBrandSize, tint: markTint)
                HexaTheme.wordmark(size: HexaPanelMetrics.headerWordmarkSize)
                    .foregroundStyle(HexaTheme.fgPrimary)
            }
            .frame(maxWidth: .infinity)

            if AppInfo.isBeta {
                HStack {
                    Spacer()
                    HexaStateTag(l10n.s.betaBadgeLabel, kind: .warning)
                }
                .padding(.trailing, HexaTheme.Spacing.m)
            }
        }
        .frame(height: HexaPanelMetrics.headerHeight)
        .background(HexaTheme.surfaceBase)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var markTint: Color {
        HexaTheme.fgPrimary
    }
}

enum UtilityPanelItem: String, PanelOrderItem, Identifiable {
    // Case order IS the default panel order (PanelLayout.itemOrder falls back
    // to allCases). Screenshot leads; existing orders that predate it
    // are migrated once without disturbing the rest of the user's layout.
    case screenshot, appUpdates, cleaner, media, uninstaller, screenOCR, portManager

    var id: String { rawValue }

    /// The hub feature behind the tile; off in the hub removes it everywhere,
    /// including the edit and hidden lists.
    var feature: AppFeature {
        switch self {
        case .appUpdates: return .appUpdates
        case .media: return .mediaTools
        case .uninstaller: return .uninstaller
        case .cleaner: return .cleaner
        case .screenOCR: return .screenOCR
        case .screenshot: return .screenshot
        case .portManager: return .portManager
        }
    }
}

struct UtilitiesSection: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @State private var showUninstaller = false
    @State private var showCleanerPanel = false
    @State private var showAppUpdatesPanel = false
    @State private var showMediaPanel = false
    @State private var showRecentCapturesPanel = false
    @State private var showPortManagerPanel = false
    @AppStorage(DefaultsKey.panelUtilityUninstaller) private var showUninstallerAction = true
    @AppStorage(DefaultsKey.panelUtilityCleaner) private var showCleanerAction = true
    @AppStorage(DefaultsKey.panelUtilityAppUpdates) private var showAppUpdates = true
    @AppStorage(DefaultsKey.panelUtilityMedia) private var showMedia = true
    @AppStorage(DefaultsKey.panelUtilityScreenOCR) private var showScreenOCR = true
    @AppStorage(DefaultsKey.panelUtilityScreenshot) private var showScreenshot = true
    @AppStorage(DefaultsKey.panelUtilityPortManager) private var showPortManager = true
    @AppStorage(DefaultsKey.panelUtilityOrder) private var utilityOrderRaw = ""
    @State private var draggingItem: UtilityPanelItem?
    var collapsible = true

    var body: some View {
        PanelSection(.utilities, title: l10n.s.utilitiesSection, collapsible: collapsible,
                     supportsEditing: true,
                     editButtonVisible: !isHostingUtility,
                     resetAction: resetPanelDefaults) { editing in
            if showUninstaller {
                PanelUninstallerView {
                    showUninstaller = false
                }
            } else if showCleanerPanel {
                PanelCleanerView {
                    showCleanerPanel = false
                }
            } else if showMediaPanel {
                PanelMediaView {
                    PanelInteractionState.shared.viewKeepsPopoverOpen = false
                    showMediaPanel = false
                }
            } else if showRecentCapturesPanel {
                PanelRecentCapturesView {
                    PanelInteractionState.shared.viewKeepsPopoverOpen = false
                    showRecentCapturesPanel = false
                }
            } else if showAppUpdatesPanel {
                PanelAppUpdatesView {
                    PanelInteractionState.shared.viewKeepsPopoverOpen = false
                    showAppUpdatesPanel = false
                }
            } else if showPortManagerPanel {
                PanelPortManagerView {
                    PanelInteractionState.shared.viewKeepsPopoverOpen = false
                    showPortManagerPanel = false
                }
            } else {
                PanelRowGroup(items: items(editing: editing), showsDragHandles: editing) { item in
                    PanelReorderableItem(item: item,
                                         isEnabled: editing,
                                         previewsAsCard: true,
                                         order: itemOrderBinding,
                                         dragging: $draggingItem) {
                        itemView(item, editing: editing)
                    }
                }
            }
        }
        .onChange(of: hostedUtilityKeepsPopoverOpen) { _, keepsOpen in
            PanelInteractionState.shared.viewKeepsPopoverOpen = keepsOpen
        }
        .onChange(of: hostedSettingsPage) { _, page in
            PanelInteractionState.shared.hostedSettingsPage = page
        }
        .onDisappear {
            // Another section, or a metric, replacing this one takes the
            // tool off screen with it; a closed panel does not, and keeps it.
            PanelInteractionState.shared.viewKeepsPopoverOpen = false
            PanelInteractionState.shared.hostedSettingsPage = nil
        }
    }

    /// The Settings page that belongs to whichever tool the section is
    /// showing, derived from the same state as `isHostingUtility` so every
    /// hosted tool is covered by the one list. Mirrored by the `onChange`
    /// beside it, and cleared only where this section leaves the screen.
    private var hostedSettingsPage: SettingsPage? {
        if showUninstaller { return .uninstaller }
        if showCleanerPanel { return .cleaner }
        if showMediaPanel { return .media }
        if showRecentCapturesPanel { return .screenshot }
        if showAppUpdatesPanel { return .appUpdates }
        if showPortManagerPanel { return .portManager }
        return nil
    }

    /// True while the section is showing one of the tools instead of its own
    /// list. A hosted tool turns the panel into a work surface, so clicks
    /// elsewhere in the app must not dismiss it.
    private var isHostingUtility: Bool {
        showUninstaller || showCleanerPanel || showMediaPanel
            || showRecentCapturesPanel || showAppUpdatesPanel || showPortManagerPanel
    }

    /// Homebrew browsing behaves like an ordinary popover. Other hosted tools
    /// intentionally span interaction with apps and windows outside the panel.
    private var hostedUtilityKeepsPopoverOpen: Bool {
        isHostingUtility
    }

    private var orderedItems: [UtilityPanelItem] {
        _ = utilityOrderRaw
        return PanelLayout.itemOrder(UtilityPanelItem.self, key: DefaultsKey.panelUtilityOrder)
    }

    private var itemOrderBinding: Binding<[UtilityPanelItem]> {
        Binding {
            orderedItems
        } set: { newValue in
            PanelLayout.setItemOrder(newValue, key: DefaultsKey.panelUtilityOrder)
        }
    }

    private func items(editing: Bool) -> [UtilityPanelItem] {
        orderedItems.filter { $0.feature.isAvailable && (editing || isVisible($0)) }
    }

    private func isVisible(_ item: UtilityPanelItem) -> Bool {
        switch item {
        case .appUpdates: return showAppUpdates
        case .media: return showMedia
        case .uninstaller: return showUninstallerAction
        case .cleaner: return showCleanerAction
        case .screenOCR: return showScreenOCR
        case .screenshot: return showScreenshot
        case .portManager: return showPortManager
        }
    }

    @ViewBuilder
    private func itemView(_ item: UtilityPanelItem, editing: Bool) -> some View {
        switch item {
        case .appUpdates:
            UtilityActionButton(title: FeatureStrings.appUpdates(l10n.language).pageTitle,
                                caption: FeatureStrings.appUpdates(l10n.language).panelCaption,
                                systemImage: "arrow.triangle.2.circlepath",
                                isEditing: editing,
                                showsDragHandle: true,
                                visibility: $showAppUpdates,
                                action: {
                                    showAppUpdatesPanel = true
                                })
        case .media:
            UtilityActionButton(title: l10n.s.mediaName,
                                caption: l10n.s.mediaEnableCaption,
                                systemImage: "photo.on.rectangle.angled",
                                isEditing: editing,
                                showsDragHandle: true,
                                visibility: $showMedia,
                                action: {
                                    showMediaPanel = true
                                })
        case .uninstaller:
            UtilityActionButton(title: l10n.s.uninstallerName,
                                caption: l10n.s.uninstallerEnableCaption,
                                systemImage: "trash",
                                isEditing: editing,
                                showsDragHandle: true,
                                visibility: $showUninstallerAction,
                                action: {
                                    showUninstaller = true
                                })
        case .cleaner:
            UtilityActionButton(title: l10n.s.cleanerName,
                                caption: l10n.s.cleanerPanelCaption,
                                systemImage: "sparkles",
                                isEditing: editing,
                                showsDragHandle: true,
                                visibility: $showCleanerAction,
                                action: {
                                    showCleanerPanel = true
                                })
        case .screenOCR:
            UtilityActionButton(title: l10n.s.ocrName,
                                caption: ocrCaption,
                                systemImage: "text.viewfinder",
                                isEditing: editing,
                                showsDragHandle: true,
                                visibility: $showScreenOCR,
                                needsAttention: !permissions.screenRecording,
                                permissionButtonTitle: l10n.s.permissionRequest,
                                permissionAction: permissions.screenRecording ? nil : grantScreenRecordingPermission,
                                shortcutHint: shortcutHint(.screenOCR),
                                action: {
                                    appDelegate()?.closePopover()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        ScreenTextService.shared.capture()
                                    }
                                })
        case .screenshot:
            UtilityActionButton(title: FeatureStrings.screenshot(l10n.language).pageTitle,
                                caption: screenshotCaption,
                                systemImage: "camera.viewfinder",
                                isEditing: editing,
                                showsDragHandle: true,
                                visibility: $showScreenshot,
                                needsAttention: !permissions.screenRecording,
                                permissionButtonTitle: l10n.s.permissionRequest,
                                permissionAction: permissions.screenRecording ? nil : grantScreenRecordingPermission,
                                shortcutHint: shortcutHint(.screenshot),
                                accessoryTitle: FeatureStrings.recentCaptures(l10n.language).title,
                                accessorySystemImage: "clock.arrow.circlepath",
                                accessoryAction: showRecentCaptures,
                                action: {
                                    appDelegate()?.closePopover()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        ScreenshotService.shared.capture()
                                    }
                                })
        case .portManager:
            UtilityActionButton(title: FeatureStrings.portManager(l10n.language).title,
                                caption: FeatureStrings.portManager(l10n.language).listeningCaption,
                                systemImage: "point.3.connected.trianglepath.dotted",
                                isEditing: editing,
                                showsDragHandle: true,
                                visibility: $showPortManager,
                                action: { showPortManagerPanel = true })
        }
    }

    /// The row's key hint: only when the shortcut is actually REGISTERED,
    /// using the same gates the services use (the clipboard needs both the
    /// feature and its shortcut toggle), so the badge never advertises a
    /// combo that does nothing.
    private func shortcutHint(_ role: GlobalShortcutRole) -> String? {
        guard role.isAvailable(using: { $0.isAvailable }),
              role.requiredEnableKeys.allSatisfy({ UserDefaults.standard.bool(forKey: $0) })
        else { return nil }
        return role.savedShortcut.displayString
    }

    private var ocrCaption: String {
        permissions.screenRecording
            ? l10n.s.ocrCaption
            : "\(l10n.s.permissionRequired): \(l10n.s.permissionScreenRecording)"
    }

    private var screenshotCaption: String {
        permissions.screenRecording
            ? FeatureStrings.screenshot(l10n.language).panelCaption
            : "\(l10n.s.permissionRequired): \(l10n.s.permissionScreenRecording)"
    }

    private func grantScreenRecordingPermission() {
        Permissions.shared.requestScreenRecording()
    }

    private func showRecentCaptures() {
        showRecentCapturesPanel = true
    }

    private func resetPanelDefaults() {
        PanelLayout.resetItemOrder(key: DefaultsKey.panelUtilityOrder)
        utilityOrderRaw = ""
        showAppUpdates = true
        showMedia = true
        showUninstallerAction = true
        showCleanerAction = true
        showScreenOCR = true
        showScreenshot = true
        showPortManager = true
    }
}

// Internal (not private): the quick toggles tab builds its rows from the same
// component, so every action row in the panel looks and behaves the same.
struct UtilityActionButton: View {
    let title: String
    let caption: String
    let systemImage: String
    var badge: String? = nil
    var isEditing = false
    var showsDragHandle = false
    var visibility: Binding<Bool>? = nil
    var needsAttention = false
    /// The caption reports something happening now or warns about a side
    /// effect (a recording's time, a failed action, the Finder restarting),
    /// so it stays on the row the way a permission note does. Any other
    /// caption only describes the tool.
    var captionStaysVisible = false
    var permissionButtonTitle: String? = nil
    var permissionAction: (() -> Void)? = nil
    /// The feature's enabled global shortcut, shown as a quiet key hint so
    /// the panel row doubles as a reminder that the keyboard path exists.
    var shortcutHint: String? = nil
    var accessoryTitle: String? = nil
    var accessorySystemImage: String? = nil
    var accessoryAction: (() -> Void)? = nil
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Group {
            if isEditing {
                rowContent(showChevron: false)
                    .panelRowInsets()
            } else if permissionAction != nil || accessoryAction != nil {
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                    if permissionAction != nil {
                        rowContent(showChevron: false)
                    } else {
                        mainButton
                    }
                    VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                        if permissionAction != nil {
                            permissionButton
                        }
                        accessoryButton
                    }
                    .padding(.leading, HexaTheme.Spacing.xxl)
                }
                .panelRowInsets()
            } else {
                Button(action: action) {
                    rowContent(showChevron: true)
                        .panelRowInsets()
                        .background(PanelRowHighlight(isVisible: hovering))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hovering = $0 }
            }
        }
        .panelRowDescription(showsCaption ? nil : caption)
    }

    /// The panel is where tools are used, and the Features page and Settings
    /// explain them. A plain description waits in the tooltip and the
    /// VoiceOver help, so the list stays one line per tool. It comes back in
    /// edit mode, where deciding what to keep is the whole point.
    private var showsCaption: Bool {
        needsAttention || captionStaysVisible || isEditing
    }

    private var mainButton: some View {
        Button(action: action) {
            rowContent(showChevron: true)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var accessoryButton: some View {
        if let accessoryTitle, let accessoryAction {
            Button(action: accessoryAction) {
                Label(accessoryTitle, hexaIcon: accessorySystemImage ?? "clock")
                    .font(.hexa(.micro))
            }
            .buttonStyle(HexaActionButtonStyle())
            .controlSize(.mini)
        }
    }

    private func rowContent(showChevron: Bool) -> some View {
        HStack(spacing: PanelRowMetrics.iconSpacing) {
            if isEditing && showsDragHandle {
                PanelDragHandle()
            }
            HexaIcons.image(systemImage, size: 15)
                .font(.hexa(.heading))
                .foregroundStyle(iconColor)
                .frame(width: PanelRowMetrics.iconWidth)
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                HStack(spacing: HexaTheme.Spacing.xs) {
                    Text(title)
                        .font(.hexa(.body))
                        .foregroundStyle(isHiddenInEditor ? HexaTheme.fgSecondary : HexaTheme.fgPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if let badge {
                        PanelBetaBadge(text: badge)
                    }
                }
                if showsCaption {
                    Text(caption)
                        .font(.hexa(.label))
                        .foregroundStyle(captionColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            if isEditing, let visibility {
                if !visibility.wrappedValue {
                    PanelHiddenBadge()
                }
                PanelInlineHideButton(isVisible: visibility)
            } else {
                if let shortcutHint {
                    Text(shortcutHint)
                        .font(.hexa(.micro))
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .padding(.horizontal, HexaTheme.Spacing.xs)
                        .padding(.vertical, 2) // geometria de plataforma (spec §4): ajuste vertical do badge de atalho
                        .background(
                            RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                                .fill(HexaTheme.surfaceInset)
                        )
                }
                if showChevron {
                    HexaIcons.image("chevron.right", size: 10)
                        .font(.hexa(.micro))
                        .foregroundStyle(HexaTheme.fgTertiary)
                }
            }
        }
    }

    private var permissionButton: some View {
        Button {
            permissionAction?()
        } label: {
            Label(permissionButtonTitle ?? "", hexaIcon: "hand.raised.fill")
                .font(.hexa(.label))
        }
        .buttonStyle(HexaActionButtonStyle())
        .controlSize(.mini)
    }

    private var iconColor: Color {
        if isHiddenInEditor { return HexaTheme.fgSecondary }
        return needsAttention ? HexaTheme.statusWarning : HexaTheme.fgSecondary
    }

    private var captionColor: Color {
        if isHiddenInEditor { return HexaTheme.fgSecondary.opacity(0.55) }
        return needsAttention ? HexaTheme.statusWarning : HexaTheme.fgSecondary
    }

    private var isHiddenInEditor: Bool {
        isEditing && visibility?.wrappedValue == false
    }
}


// MARK: - Grouped rows

/// Spacing shared by the rows inside a `PanelRowGroup`. The insets match
/// the padding of the other panel cards, so a row's text lines up with
/// them, and separators start under the titles rather than the icons.
enum PanelRowMetrics {
    static let iconWidth: CGFloat = 22
    static let iconSpacing: CGFloat = 9
    static let dragHandleWidth: CGFloat = 16

    static func horizontalInset(island: Bool) -> CGFloat { island ? 12 : 10 }

    static func verticalInset(island: Bool) -> CGFloat { island ? 10 : 8 }

    static func separatorInset(island: Bool) -> CGFloat {
        horizontalInset(island: island) + iconWidth + iconSpacing
    }
}

/// One card for a list of panel rows, split by hairlines the way the mixer
/// lists its apps: a long list reads as one block instead of a stack of
/// separate boxes, and every row stays its own target.
struct PanelRowGroup<Item: Hashable, Row: View>: View {
    let items: [Item]
    /// Edit mode puts a drag handle before every icon, so the separators
    /// move over with the titles.
    var showsDragHandles = false
    @ViewBuilder let row: (Item) -> Row
    @Environment(\.notchPresentation) private var notchPresentation

    var body: some View {
        if !items.isEmpty {
            rows
        }
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element) { index, item in
                if index > 0 {
                    HairlineDivider()
                        .padding(.vertical, HexaTheme.Spacing.xs)
                        .padding(.leading, PanelRowMetrics.separatorInset(island: notchPresentation)
                                    + (showsDragHandles ? PanelRowMetrics.dragHandleWidth + PanelRowMetrics.iconSpacing : 0))
                        .padding(.trailing, PanelRowMetrics.horizontalInset(island: notchPresentation))
                }
                row(item)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelCard(interactive: false, padded: false)
    }
}

/// The hover fill of a tappable row, inset from the group's edges so it
/// never crosses the rounded corners of the card around it.
struct PanelRowHighlight: View {
    let isVisible: Bool
    @Environment(\.notchPresentation) private var notchPresentation

    var body: some View {
        RoundedRectangle(cornerRadius: notchPresentation ? HexaTheme.Radius.notch : HexaTheme.Radius.control, style: .continuous)
            .fill(HexaTheme.fgPrimary
                .opacity(isVisible ? (notchPresentation ? 0.08 : 0.06) : 0))
            .padding(notchPresentation ? 4 : 3) // geometria de plataforma (spec §4): gutter do fill de hover em relação aos cantos do cartão
    }
}

private struct PanelRowInsets: ViewModifier {
    @Environment(\.notchPresentation) private var notchPresentation

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, PanelRowMetrics.horizontalInset(island: notchPresentation))
            .padding(.vertical, PanelRowMetrics.verticalInset(island: notchPresentation))
    }
}

private struct PanelSubRowInsets: ViewModifier {
    @Environment(\.notchPresentation) private var notchPresentation

    func body(content: Content) -> some View {
        content
            .padding(.leading, PanelRowMetrics.separatorInset(island: notchPresentation))
            .padding(.trailing, PanelRowMetrics.horizontalInset(island: notchPresentation))
            .padding(.bottom, PanelRowMetrics.verticalInset(island: notchPresentation))
    }
}

extension View {
    /// The padding a row gets inside a `PanelRowGroup`.
    func panelRowInsets() -> some View {
        modifier(PanelRowInsets())
    }

    /// An option that belongs to the row above it, such as the switcher's
    /// large icons, lined up under that row's title.
    func panelSubRowInsets() -> some View {
        modifier(PanelSubRowInsets())
    }

    /// A row's description as its tooltip, and through it the VoiceOver
    /// help, whenever the row does not print it. An empty help keeps the
    /// row one view while its caption comes and goes, so a switch that turns
    /// on into a permission note is not rebuilt mid-animation.
    func panelRowDescription(_ description: String?) -> some View {
        help(description ?? "")
    }
}

/// A small "Beta" pill, used to flag a control as still experimental.
struct PanelBetaBadge: View {
    let text: String

    var body: some View {
        HexaStateTag(text, kind: .warning)
    }
}

// MARK: - Overlay scroll container


// MARK: - Keep awake

struct KeepAwakeCard: View {
    @Environment(\.featureWorkspacePresentation) private var workspacePresentation
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var awake = KeepAwakeManager.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(DefaultsKey.defaultDuration) private var defaultDuration: Int = 0
    @AppStorage(DefaultsKey.keepAwakeAutoStart) private var keepAwakeAutoStart = false
    @AppStorage(DefaultsKey.keepAwakeAllowDisplaySleep) private var keepAwakeAllowDisplaySleep = false
    @AppStorage(DefaultsKey.keepAwakeExternalDisplay) private var keepAwakeExternalDisplay = false
    @AppStorage(DefaultsKey.keepAwakeConnectedToPower) private var keepAwakeConnectedToPower = false
    @AppStorage(DefaultsKey.keepAwakeRunningApps) private var keepAwakeRunningApps = false
    @AppStorage(DefaultsKey.keepAwakePauseWhenLocked) private var keepAwakePauseWhenLocked = false
    @AppStorage(DefaultsKey.keepAwakeMouseJiggleEnabled) private var keepAwakeMouseJiggle = false
    @AppStorage(DefaultsKey.keepAwakeMouseJiggleInterval) private var keepAwakeMouseJiggleInterval = 5
    @AppStorage(DefaultsKey.batteryLimit) private var batteryLimit = 10
    @State private var optionsExpanded = false
    @State private var automationExpanded = false
    /// The last started end time, which the popover opens on.
    @AppStorage(DefaultsKey.keepAwakeUntilTime) private var savedUntilTime = 0.0
    /// An edit not started yet; only starting saves it, so the switch keeps
    /// restarting the session that actually ran.
    @State private var untilDraft: Date?
    /// Only a laptop reports a lid, and only a laptop can keep going with it
    /// closed. Desktops hide the row instead of offering a rule with no effect.
    private static let hasLid = BrightnessService.lidClosed() != nil

    /// Only the hour and minute matter; `resolvedUntilDate` picks the next one.
    private var untilTime: Binding<Date> {
        Binding(
            get: {
                untilDraft ?? (savedUntilTime > 0 ? Date(timeIntervalSinceReferenceDate: savedUntilTime)
                    : Date().addingTimeInterval(3600))
            },
            set: { untilDraft = $0 }
        )
    }
    var collapsible = true

    var body: some View {
        Group {
            if workspacePresentation {
                workspaceControls
            } else {
                panelSection
            }
        }
        .onAppear {
            defaultDuration = Defaults.sanitizedDefaultDuration(defaultDuration)
            keepAwakeMouseJiggleInterval = Defaults.sanitizedKeepAwakeMouseJiggleInterval(keepAwakeMouseJiggleInterval)
            batteryLimit = Defaults.sanitizedBatteryLimit(batteryLimit)
        }
    }

    private var workspaceControls: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.l) {
            HexaSection(l10n.s.keepAwakeTitle) {
                sessionContent
            }
            HexaSection(l10n.s.keepAwakeOptions) {
                workspaceOptions
            }
        }
    }

    /// The session itself: state, switch, duration choices and the one hint
    /// that moves the user forward. The countdown lives here only, so a chip
    /// stays a control instead of a second clock.
    private var sessionContent: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.m) {
            HStack {
                statusLine
                Spacer(minLength: 8)
                if awake.isActive, awake.endDate != nil {
                    HStack(spacing: HexaTheme.Spacing.xs) {
                        ForEach([15, 30, 60], id: \.self) { minutes in
                            Button("+" + DurationPicker.shortTitle(for: minutes, l10n.s, l10n.language)) {
                                awake.extend(minutes: minutes)
                            }
                            .buttonStyle(KeepAwakeChipStyle())
                            .fixedSize()
                        }
                    }
                }
                Toggle(l10n.s.keepAwakeTitle, isOn: activeBinding)
                    .toggleStyle(HexaSwitchStyle(activeTint: HexaTheme.awakeActive))
                    .labelsHidden()
            }

            HairlineDivider()

            durationChoices

            TimelineView(.periodic(from: .now, by: 30)) { _ in
                if let percent = awake.batteryProtectionPercent() {
                    HexaStatusNote(message: batteryNote(percent), icon: "battery.25percent")
                } else if !awake.isActive {
                    Text(chipHint)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgTertiary)
                }
            }
        }
    }

    private var durationChoices: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: HexaTheme.Spacing.xs) {
                ForEach(DurationPicker.choices, id: \.self, content: durationChip)
                untilChip
            }
            VStack(spacing: HexaTheme.Spacing.xs) {
                HStack(spacing: HexaTheme.Spacing.xs) {
                    ForEach(DurationPicker.choices.prefix(4), id: \.self, content: durationChip)
                }
                HStack(spacing: HexaTheme.Spacing.xs) {
                    ForEach(DurationPicker.choices.dropFirst(4), id: \.self, content: durationChip)
                    untilChip
                }
            }
        }
    }

    private var workspaceOptions: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.m) {
            compactOptionToggle(
                icon: "display",
                title: displaySleepStrings.allowDisplaySleep,
                isOn: $keepAwakeAllowDisplaySleep
            )

            HairlineDivider()

            compactOptionToggle(
                icon: "play.circle",
                title: l10n.s.keepAwakeAutoStart,
                isOn: $keepAwakeAutoStart
            )
            defaultDurationRow

            HairlineDivider()

            compactOptionToggle(
                icon: "cursorarrow.motionlines",
                title: l10n.s.keepAwakeMouseJiggle,
                isOn: $keepAwakeMouseJiggle,
                errorText: mouseJiggleNeedsAccessibility ? mouseJiggleCaption : nil
            )
            if keepAwakeMouseJiggle {
                mouseJiggleIntervalRow
                if mouseJiggleNeedsAccessibility {
                    HexaAccessButton(icon: "hand.raised.fill",
                                     title: l10n.s.permissionRequest) {
                        grantAccessibility()
                    }
                }
            }

            if PowerSampler.hasInternalBattery {
                HairlineDivider()
                batteryLimitRow
            }

            HairlineDivider()

            automationBlock

            if Self.hasLid {
                HairlineDivider()
                optionRow(title: l10n.s.clamshellTitle,
                          caption: clamshellCaption,
                          isOn: $awake.clamshellPreferred,
                          disabled: awake.clamshellSetupInProgress,
                          captionIsError: awake.clamshellSetupFailed)
                sleepRestoreRow
            }
        }
    }

    /// Shows the duration the switch will use, which is the last chip picked
    /// until the user sets one here. Without it the auto-start caption pointed
    /// at a value with no control anywhere.
    private var defaultDurationRow: some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            HexaIcons.image("clock", size: 11)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
                .frame(width: 15)
            Text(l10n.s.defaultDurationLabel)
                .font(.hexa(.label))
            Spacer(minLength: 8)
            Picker(l10n.s.defaultDurationLabel, selection: $defaultDuration) {
                ForEach(DurationPicker.choices, id: \.self) { minutes in
                    Text(DurationPicker.title(for: minutes, l10n.s)).tag(minutes)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
            .fixedSize()
        }
    }

    @ViewBuilder
    private var automationBlock: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            Label(automationStrings.automationSection, hexaIcon: "bolt.fill")
                .font(.hexa(.label)).foregroundStyle(HexaTheme.fgPrimary)
            if awake.automationSuppressedUntilConditionsClear {
                HexaStatusNote(message: automationStrings.automationPaused, icon: "pause.circle")
            }
            KeepAwakeAutomationEditor(compact: false)
            compactOptionToggle(
                icon: "lock.fill",
                title: automationStrings.pauseWhenLockedToggle,
                isOn: $keepAwakePauseWhenLocked
            )
        }
    }

    private var panelSection: some View {
        PanelSection(.keepAwake, title: l10n.s.keepAwakeTitle, collapsible: collapsible) {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                HStack {
                    if awake.isActive, awake.endDate != nil {
                        ViewThatFits(in: .horizontal) {
                            statusLine.fixedSize()
                            Color.clear.frame(width: 0, height: 0)
                        }
                        Spacer(minLength: 4)
                        HStack(spacing: HexaTheme.Spacing.xs) {
                            ForEach([15, 30, 60], id: \.self) { minutes in
                                Button("+" + DurationPicker.shortTitle(for: minutes, l10n.s, l10n.language)) {
                                    awake.extend(minutes: minutes)
                                }
                                .buttonStyle(KeepAwakeChipStyle())
                                .fixedSize()
                            }
                        }
                    } else {
                        statusLine
                        Spacer(minLength: 4)
                    }
                    Toggle(l10n.s.keepAwakeTitle, isOn: activeBinding)
                        .toggleStyle(HexaSwitchStyle(activeTint: HexaTheme.awakeActive))
                        .labelsHidden()
                }

                durationChoices

                TimelineView(.periodic(from: .now, by: 30)) { _ in
                    if let percent = awake.batteryProtectionPercent() {
                        HexaStatusNote(message: batteryNote(percent), icon: "battery.25percent")
                    } else if !awake.isActive {
                        Text(chipHint)
                            .font(.hexa(.label))
                            .foregroundStyle(HexaTheme.fgTertiary)
                    }
                }

                optionsDisclosure

                if Self.hasLid {
                    HairlineDivider()

                    optionRow(title: l10n.s.clamshellTitle,
                              caption: clamshellCaption,
                              isOn: $awake.clamshellPreferred,
                              disabled: awake.clamshellSetupInProgress,
                              captionIsError: awake.clamshellSetupFailed)

                    sleepRestoreRow
                }
            }
            .panelCard()
        }
    }

    private var optionsDisclosure: some View {
        HexaDisclosure(isExpanded: $optionsExpanded) {
            Text(l10n.s.keepAwakeOptions).font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
        } content: {
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                    compactOptionToggle(
                        icon: "display",
                        title: displaySleepStrings.allowDisplaySleep,
                        isOn: $keepAwakeAllowDisplaySleep
                    )
                    compactOptionToggle(
                        icon: "play.circle",
                        title: l10n.s.keepAwakeAutoStart,
                        isOn: $keepAwakeAutoStart
                    )
                    defaultDurationRow
                    compactOptionToggle(
                        icon: "cursorarrow.motionlines",
                        title: l10n.s.keepAwakeMouseJiggle,
                        isOn: $keepAwakeMouseJiggle,
                        errorText: mouseJiggleNeedsAccessibility ? mouseJiggleCaption : nil
                    )
                    if keepAwakeMouseJiggle {
                        mouseJiggleIntervalRow
                        if mouseJiggleNeedsAccessibility {
                            HexaAccessButton(icon: "hand.raised.fill",
                                             title: l10n.s.permissionRequest) {
                                grantAccessibility()
                            }
                        }
                    }
                    automationDisclosure
                }


        }
    }

    private var automationDisclosure: some View {
        HexaDisclosure(isExpanded: $automationExpanded) {
            HStack(spacing: HexaTheme.Spacing.s) {
                Label(automationStrings.automationSection, hexaIcon: "bolt.fill")
                    .font(.hexa(.label)).foregroundStyle(HexaTheme.fgPrimary)
                automationSummaryBadges
            }
        } content: {
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                    if awake.automationSuppressedUntilConditionsClear {
                        HexaStatusNote(message: automationStrings.automationPaused, icon: "pause.circle")
                    }
                    KeepAwakeAutomationEditor(compact: true)
                    compactOptionToggle(
                        icon: "lock.fill",
                        title: automationStrings.pauseWhenLockedToggle,
                        isOn: $keepAwakePauseWhenLocked
                    )
                }


        }
    }

    @ViewBuilder
    private var automationSummaryBadges: some View {
        if !keepAwakeExternalDisplay,
           !keepAwakeConnectedToPower,
           !keepAwakeRunningApps,
           !keepAwakePauseWhenLocked {
            Text(automationStrings.automationOff)
                .font(.hexa(.micro))
                .foregroundStyle(HexaTheme.fgTertiary)
        } else {
            HStack(spacing: HexaTheme.Spacing.xs) {
                if keepAwakeExternalDisplay {
                    automationSystemBadge("display")
                }
                if keepAwakeConnectedToPower {
                    automationSystemBadge("powerplug.fill")
                }
                if keepAwakeRunningApps {
                    automationSystemBadge("app.fill")
                }
                if keepAwakePauseWhenLocked {
                    automationSystemBadge("lock.fill")
                }
            }
        }
    }

    private func automationSystemBadge(_ icon: String) -> some View {
        HexaIcons.image(icon, size: 10)
            .font(.hexa(.micro))
            .foregroundStyle(HexaTheme.fgPrimary)
            .frame(width: 17, height: 17)
            .background(Circle().fill(HexaTheme.selectionBg))
    }

    private func compactOptionToggle(icon: String,
                                     title: String,
                                     isOn: Binding<Bool>,
                                     errorText: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            HStack(spacing: HexaTheme.Spacing.s) {
                HexaIcons.image(icon, size: 11)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .frame(width: 15)
                Text(title)
                    .font(.hexa(.label))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Toggle(title, isOn: isOn)
                    .toggleStyle(HexaSwitchStyle())
                    .labelsHidden()
            }
            if let errorText {
                Text(errorText)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.statusDanger)
                    .padding(.leading, HexaTheme.Spacing.xl)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var mouseJiggleIntervalRow: some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            Text(l10n.s.keepAwakeMouseJiggleInterval)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
            Spacer(minLength: 0)
            KeepAwakeMouseJiggleIntervalPicker(selection: $keepAwakeMouseJiggleInterval)
        }
    }

    /// Ends a session and holds automations back on battery at or below the
    /// chosen level; the battery watch reads it on every check.
    private var batteryLimitRow: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            HStack(spacing: HexaTheme.Spacing.s) {
                HexaIcons.image("battery.25percent", size: 11)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .frame(width: 15)
                Text(l10n.s.keepAwakeBatteryLimit)
                    .font(.hexa(.label))
                Spacer(minLength: 8)
                Picker(l10n.s.keepAwakeBatteryLimit, selection: $batteryLimit) {
                    ForEach(Defaults.allowedBatteryLimits, id: \.self) { limit in
                        Text(limit == 0 ? l10n.s.keepAwakeBatteryLimitNever : "\(limit)%").tag(limit)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .fixedSize()
            }
            Text(l10n.s.keepAwakeBatteryLimitCaption)
                .hexaCaption()
                .padding(.leading, HexaTheme.Spacing.xl)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var mouseJiggleNeedsAccessibility: Bool {
        keepAwakeMouseJiggle && !permissions.accessibility
    }

    private var mouseJiggleCaption: String {
        mouseJiggleNeedsAccessibility
            ? "\(l10n.s.permissionRequired): \(l10n.s.permissionAccessibility)"
            : l10n.s.keepAwakeMouseJiggleCaption
    }

    private var statusLine: some View {
        Group {
            if awake.isActive {
                if awake.sessionTrigger == .automation {
                    Text(automationStrings.activeStatus(for: awake.activeAutomationConditions))
                } else if let end = awake.endDate {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text("\(l10n.s.keepAwakeEndsIn) \(Self.remainingText(until: end))")
                    }
                } else {
                    Text(l10n.s.keepAwakeUntilDisabled)
                }
            } else {
                Text(l10n.s.keepAwakeNormalRules)
            }
        }
        .font(.hexa(.label))
        .foregroundStyle(HexaTheme.fgSecondary)
    }

    private func durationChip(_ minutes: Int) -> some View {
        let selected = manualSession && awake.sessionMinutes == minutes
        return Button {
            if selected {
                awake.toggle()
            } else {
                awake.activate(minutes: minutes)
            }
        } label: {
            Text(DurationPicker.shortTitle(for: minutes, l10n.s, l10n.language))
        }
        .buttonStyle(KeepAwakeChipStyle(isSelected: selected))
        .accessibilityLabel(DurationPicker.title(for: minutes, l10n.s))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var untilChip: some View {
        KeepAwakeEndTimePicker(selection: untilTime,
                               activeEnd: manualSession && awake.sessionMinutes == nil ? awake.endDate : nil,
                               onStop: { awake.toggle() }) {
            awake.activate(until: KeepAwakeAutomationSupport.resolvedUntilDate(picked: untilTime.wrappedValue, now: Date()))
            untilDraft = nil
        }
    }

    private var manualSession: Bool {
        awake.isActive && awake.sessionTrigger == .manual
    }

    private func batteryNote(_ percent: Int) -> String {
        switch l10n.language {
        case .enUS: return "Battery at \(percent)%. Plug in or lower the battery limit to start"
        case .ptBR: return "Bateria em \(percent)%. Conecte o carregador ou reduza o limite de bateria para iniciar"
        case .tr: return "Pil %\(percent). Başlatmak için şarja takın veya pil sınırını düşürün"
        case .ru: return "Заряд \(percent)%. Подключите питание или снизьте порог заряда, чтобы начать"
        case .es: return "Batería al \(percent) %. Conecta el cargador o baja el límite de batería para empezar"
        case .sk: return "Batéria na \(percent) %. Pripojte napájanie alebo znížte limit batérie a spustite"
        case .de: return "Batterie bei \(percent) %. Zum Starten Netzteil anschließen oder Batteriegrenze senken"
        case .fr: return "Batterie à \(percent)\u{00A0}%. Brancher le chargeur ou baisser la limite de batterie pour démarrer"
        case .it: return "Batteria al \(percent)%. Collega l’alimentatore o abbassa il limite della batteria per iniziare"
        case .ja: return "バッテリー残量 \(percent)%。電源に接続するかバッテリーの下限を下げると開始できます"
        case .ko: return "배터리 \(percent)%. 전원을 연결하거나 배터리 한도를 낮추면 시작할 수 있습니다"
        case .uk: return "Заряд \(percent)%. Підключіть живлення або знизьте поріг заряду, щоб почати"
        case .zhHans: return "电量 \(percent)%。接通电源或调低电量下限即可开始"
        case .zhTW, .zhHK: return "電量 \(percent)%。接上電源或調低電量下限即可開始"
        }
    }

    private var chipHint: String {
        switch l10n.language {
        case .enUS: return "Click a chip to start. Click it again to stop"
        case .ptBR: return "Clique em um chip para iniciar. Clique de novo para parar"
        case .tr: return "Başlatmak için bir çipe tıklayın. Durdurmak için tekrar tıklayın"
        case .ru: return "Нажмите на чип, чтобы начать. Нажмите снова, чтобы остановить"
        case .es: return "Haz clic en un chip para empezar. Vuelve a hacer clic para detener"
        case .sk: return "Kliknutím na čip spustíte. Ďalším kliknutím zastavíte"
        case .de: return "Chip anklicken zum Starten. Erneut anklicken zum Beenden"
        case .fr: return "Cliquer sur une puce pour démarrer. Cliquer à nouveau pour arrêter"
        case .it: return "Fai clic su un chip per iniziare. Fai di nuovo clic per fermare"
        case .ja: return "チップをクリックで開始、もう一度クリックで停止"
        case .ko: return "칩을 클릭하면 시작하고, 다시 클릭하면 멈춥니다"
        case .uk: return "Натисніть на чип, щоб почати. Натисніть ще раз, щоб зупинити"
        case .zhHans: return "点按一个标签即可开始，再次点按即可停止"
        case .zhTW, .zhHK: return "點按一個標籤即可開始，再次點按即可停止"
        }
    }

    private var automationStrings: KeepAwakeAutomationStrings {
        FeatureStrings.keepAwakeAutomation(l10n.language)
    }

    private var displaySleepStrings: KeepAwakeDisplaySleepStrings {
        FeatureStrings.keepAwakeDisplaySleep(l10n.language)
    }

    private var clamshellCaption: String {
        if awake.clamshellSetupInProgress {
            return l10n.s.configuring
        }
        if awake.clamshellSetupFailed {
            return l10n.s.sudoersFailed
        }
        if awake.clamshellActive {
            return l10n.s.clamshellOnCaption
        }
        if awake.clamshellPreferred {
            return l10n.s.clamshellNeedsSession
        }
        return awake.passwordlessClamshell ? l10n.s.clamshellReady : l10n.s.clamshellNeedsPassword
    }

    /// O reparo adiado do arranque: aviso e botão só enquanto a suspensão do
    /// sistema continua desativada esperando a senha da pessoa.
    @ViewBuilder
    private var sleepRestoreRow: some View {
        if awake.sleepRestorePending {
            HexaStatusNote(message: l10n.s.sleepRestorePending, icon: "moon.zzz")
            HexaAccessButton(icon: "moon.zzz", title: l10n.s.sleepRestoreAction) {
                awake.restoreSleepNow()
            }
        }
    }

    private var activeBinding: Binding<Bool> {
        Binding(
            get: { awake.isActive },
            set: { on in
                if on {
                    awake.startLastPick()
                } else if awake.isActive {
                    awake.toggle()
                }
            }
        )
    }

    private func grantAccessibility() {
        Permissions.shared.requestAccessibility()
    }

    private func optionRow(title: String,
                           caption: String?,
                           isOn: Binding<Bool>,
                           disabled: Bool,
                           captionIsError: Bool = false) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                Text(title)
                    .font(.hexa(.label))
                if let caption {
                    Text(caption)
                        .font(.hexa(.label))
                        .foregroundStyle(captionIsError ? HexaTheme.statusDanger : HexaTheme.fgSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 8)
            Toggle(title, isOn: isOn)
                .toggleStyle(HexaSwitchStyle())
                .labelsHidden()
                .disabled(disabled)
        }
    }

    /// "1 h 05 min" style countdown, shared with the Energy page's status line.
    static func remainingText(until end: Date) -> String {
        let total = max(0, Int(end.timeIntervalSinceNow))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 { return String(format: "%d h %02d min", hours, minutes) }
        if minutes > 0 { return String(format: "%d min %02d s", minutes, seconds) }
        return "\(seconds) s"
    }
}

/// Session durations shared by the panel chips and Settings.
enum DurationPicker {
    /// The offered durations in minutes; 0 keeps the session open until it
    /// is switched off.
    static let choices = [15, 30, 60, 120, 240, 480, 0]

    static func title(for minutes: Int, _ s: Strings) -> String {
        switch minutes {
        case 15: return s.minutes15
        case 30: return s.minutes30
        case 60: return s.hour1
        case 120: return s.hours2
        case 240: return s.hours4
        case 480: return s.hours8
        default: return s.indefinite
        }
    }

    /// Chip-sized label ("15m", "1h" in English), localized by Foundation.
    static func shortTitle(for minutes: Int, _ s: Strings, _ language: AppLanguage) -> String {
        guard minutes > 0 else { return "∞" }
        let formatter = DateComponentsFormatter()
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: language.rawValue)
        formatter.calendar = calendar
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute]
        return formatter.string(from: TimeInterval(minutes * 60)) ?? title(for: minutes, s)
    }
}

/// Capsule chip used for the Keep awake presets and extensions.
struct KeepAwakeChipStyle: ButtonStyle {
    var isSelected = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.hexa(.data))
            .lineLimit(1)
            .foregroundStyle(isSelected ? HexaTheme.fgPrimary : HexaTheme.fgSecondary)
            .padding(.horizontal, HexaTheme.Spacing.s)
            .frame(minHeight: 22)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(isSelected
                ? HexaTheme.selectionBg
                : HexaTheme.fgPrimary.opacity(configuration.isPressed ? 0.16 : 0.07)))
            .contentShape(Capsule())
    }
}

struct KeepAwakeMouseJiggleIntervalPicker: View {
    @Binding var selection: Int

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(Defaults.allowedKeepAwakeMouseJiggleIntervals, id: \.self) { minutes in
                Text(Self.label(for: minutes)).tag(minutes)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .controlSize(.small)
        .fixedSize()
    }

    static func label(for minutes: Int) -> String {
        "\(minutes) min"
    }
}
