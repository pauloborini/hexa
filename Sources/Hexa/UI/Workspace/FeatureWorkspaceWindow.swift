// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import SwiftUI

enum WorkspaceSystemDestination: String, Hashable, CaseIterable {
    case general
    case menuBar
    case featureHub
    case shortcuts
    case advanced
    case about
    case releaseNotes
}

enum WorkspaceDestination: Hashable {
    case feature(AppFeature)
    case general
    case menuBar
    case featureHub
    case shortcuts
    case advanced
    case about
    case releaseNotes

    var systemDestination: WorkspaceSystemDestination? {
        switch self {
        case .feature: return nil
        case .general: return .general
        case .menuBar: return .menuBar
        case .featureHub: return .featureHub
        case .shortcuts: return .shortcuts
        case .advanced: return .advanced
        case .about: return .about
        case .releaseNotes: return .releaseNotes
        }
    }

    var feature: AppFeature? {
        if case .feature(let f) = self { return f }
        return nil
    }
}

/// Destino de um resultado da busca da sidebar: a linha que aparece e a aba interna que ela abre.
/// Campo nil mantém a memória de sessão atual. Tipo de valor, sem estado nem persistência.
struct SidebarSearchRoute: Equatable {
    /// Funcionalidade da linha; nil quando o resultado é uma tela do sistema.
    var feature: AppFeature?
    /// Tela do sistema da linha; nil para funcionalidades.
    var system: WorkspaceSystemDestination?
    var menuBarTab: MenuBarSettings.Tab?
    var featureHubTab: Int?
    var mediaTool: MediaTool?
    var notchTab: NotchSettingsTab?
    var notchContentSection: NotchModule?
    var metric: MetricDetailKind?

    /// Destinos alcançados pela consulta, na ordem de exibição. Função pura: só lê os textos que já
    /// existem no idioma; `isAvailable` descarta funcionalidades desligadas.
    static func routes(for query: String,
                       language: AppLanguage,
                       monitorKinds: [MetricDetailKind],
                       isAvailable: (AppFeature) -> Bool) -> [SidebarSearchRoute] {
        guard !query.isEmpty else { return [] }
        func matches(_ text: String) -> Bool { text.localizedStandardContains(query) }
        let s = Strings.localized(language)
        let hub = FeatureStrings.hub(language)
        let menuBar = FeatureStrings.menuBarAppearance(language)
        let workspace = WorkspaceStrings.localized(language)
        var routes: [SidebarSearchRoute] = []

        // Telas do sistema: Geral, Atalhos, Avançado, Sobre, mais abas de Barra de menus e Recursos.
        if matches(s.tabGeneral) {
            routes.append(SidebarSearchRoute(system: .general))
        }
        if matches(s.shortcutsPageTitle) {
            routes.append(SidebarSearchRoute(system: .shortcuts))
        }
        if matches(s.tabAdvanced) {
            routes.append(SidebarSearchRoute(system: .advanced))
        }
        if matches(s.tabAbout) {
            routes.append(SidebarSearchRoute(system: .about))
        }
        if matches(s.tabReleaseNotes) {
            routes.append(SidebarSearchRoute(system: .releaseNotes))
        }
        if matches(menuBar.tabCommandCenter) {
            routes.append(SidebarSearchRoute(system: .menuBar, menuBarTab: .commandCenter))
        }
        if matches(menuBar.tabMenuBar) {
            routes.append(SidebarSearchRoute(system: .menuBar, menuBarTab: .menuBar))
        }
        if matches(hub.tabFeatures) {
            routes.append(SidebarSearchRoute(system: .featureHub, featureHubTab: 0))
        }
        let permissionNames: [String] = [
            hub.tabPermissions,
            hub.permAccessibility,
            hub.permScreenRecording,
            hub.permFullDisk,
            hub.permFilesAndFolders,
            hub.permNotifications,
            hub.permAutomationFinder,
            hub.permAutomationTerminal,
            FeatureStrings.notchMusicExtras(language).automationPermission,
            hub.permAudioCapture,
            hub.permAppManagement,
            FeatureStrings.notchCalendar(language).title,
            hub.permBluetooth,
        ]
        if permissionNames.contains(where: matches) {
            routes.append(SidebarSearchRoute(system: .featureHub, featureHubTab: 1))
        }

        // Monitor: cada métrica disponível abre a própria página.
        for kind in monitorKinds where (matches(kind.title(s)) || (kind == .power && matches(s.batteryLabel))) && isAvailable(kind.workspaceFeature) {
            routes.append(SidebarSearchRoute(feature: kind.workspaceFeature, metric: kind))
        }

        // Ferramentas de mídia: cada segmento, ou seu nome longo de busca, abre a ferramenta.
        if isAvailable(.mediaTools) {
            for tool in MediaTool.allCases where matches(tool.segmentTitle(s)) || matches(mediaSearchAlias(tool, hub: hub)) {
                routes.append(SidebarSearchRoute(feature: .mediaTools, mediaTool: tool))
            }
        }

        // Dynamic Island: abas, e seções internas (cada seção abre no Conteúdo, onde ficam as suas opções).
        if isAvailable(.notch) {
            for tab in NotchSettingsTab.allCases where matches(tab.title(language)) {
                routes.append(SidebarSearchRoute(feature: .notch, notchTab: tab))
            }
            for module in NotchModule.allCases where module != .tools && matches(module.title(language)) {
                routes.append(SidebarSearchRoute(feature: .notch, notchTab: .content, notchContentSection: module))
            }
        }

        // Módulos agrupados: rótulo curto da aba, título e descrição do membro.
        for module in SidebarModule.allCases {
            for member in module.availableMembers(isAvailable: isAvailable) {
                let short = member == .screenshot ? workspace.capture : member.hubTitle(s, hub: hub)
                let labels = [short, member.hubTitle(s, hub: hub), member.hubDescription(hub)]
                if labels.contains(where: matches) {
                    routes.append(SidebarSearchRoute(feature: member))
                }
            }
        }
        return routes
    }

    /// Nome longo da ferramenta para o índice da busca (ex.: "Conversor de GIF"). Não é rótulo visível.
    private static func mediaSearchAlias(_ tool: MediaTool, hub: FeatureHubStrings) -> String {
        switch tool {
        case .videoCompressor: return hub.searchMediaVideo
        case .gifMaker: return hub.searchMediaGIF
        case .imageCompressor: return hub.searchMediaImage
        case .textExtractor: return hub.searchMediaText
        }
    }
}

final class FeatureWorkspaceState: ObservableObject {
    static let shared = FeatureWorkspaceState()

    @Published var destination: WorkspaceDestination = .feature(.mixer)
    @Published var feature: AppFeature = .mixer
    @Published var systemDestination: WorkspaceSystemDestination? = nil
    @Published var featureSettingsMode = false

    /// The Dynamic Island tab picked in the workspace header, shown while `feature` is `.notch`.
    @Published var notchTab: NotchSettingsTab = .content
    /// Módulo interno da Dynamic Island casado pela busca da sidebar: só memória de sessão, sem DefaultsKey.
    @Published var notchContentSection: NotchModule?
    @Published var metric: MetricDetailKind = .cpu
    /// Disco escolhido na aba Disco do Monitor: só memória de sessão, sem DefaultsKey.
    @Published var selectedDiskID: String?
    /// Aba de Barra de menus e de Recursos e membro do segmento de Mídia: só memória de sessão.
    @Published var menuBarTab: MenuBarSettings.Tab = .menuBar
    @Published var featureHubTab = 0
    /// Espelho da chave `DefaultsKey.mediaLastTool`: não há persistência própria, a leitura e a escrita vão para ela.
    var mediaTool: MediaTool {
        get { MediaSupport.sanitizedTool(UserDefaults.standard.string(forKey: DefaultsKey.mediaLastTool) ?? "") }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: DefaultsKey.mediaLastTool) }
    }
    @Published var visible = false
    @Published var showsSettings = false {
        didSet {
            guard showsSettings != oldValue else { return }
            if showsSettings {
                if systemDestination == nil {
                    if SettingsRouter.shared.page == .menuBar {
                        selectSystem(.menuBar)
                    } else if SettingsRouter.shared.page == .features {
                        selectSystem(.featureHub)
                    } else if SettingsRouter.shared.page == .shortcuts {
                        selectSystem(.shortcuts)
                    } else if SettingsRouter.shared.page == .advanced {
                        selectSystem(.advanced)
                    } else if SettingsRouter.shared.page == .about {
                        selectSystem(.about)
                    } else if SettingsRouter.shared.page == .mixer {
                        destination = .feature(.mixer)
                        feature = .mixer
                        featureSettingsMode = true
                    } else {
                        selectSystem(.general)
                    }
                }
            } else {
                if systemDestination != nil {
                    systemDestination = nil
                    destination = .feature(feature)
                }
            }
        }
    }
    @Published var monitorTabIsSettings = false
    /// Último membro aberto de cada módulo da sidebar; a linha do módulo reabre esse membro.
    private(set) var rememberedModuleMember: [SidebarModule: AppFeature] = [:]

    func selectFeature(_ feature: AppFeature) {
        self.feature = feature
        self.systemDestination = nil
        self.destination = .feature(feature)
        self.featureSettingsMode = false
        self.showsSettings = false
        if let module = SidebarModule.module(containing: feature) {
            rememberedModuleMember[module] = feature
        }
    }

    /// Troca de métrica do Monitor: `metric` e `feature` andam juntos, para o título, o subtítulo e o conteúdo baterem.
    func selectMonitorMetric(_ kind: MetricDetailKind) {
        metric = kind
        selectFeature(kind.workspaceFeature)
    }

    /// Aplica as abas que o destino da busca define. Campo nil preserva a memória atual.
    func applySidebarSearchTabs(_ route: SidebarSearchRoute?) {
        guard let route else { return }
        if let menuBarTab = route.menuBarTab { self.menuBarTab = menuBarTab }
        if let featureHubTab = route.featureHubTab { self.featureHubTab = featureHubTab }
        if let mediaTool = route.mediaTool { self.mediaTool = mediaTool }
        if let notchTab = route.notchTab {
            self.notchTab = notchTab
            notchContentSection = route.notchContentSection
        }
    }

    /// Abre a funcionalidade escolhida na sidebar, com o destino da busca que casou com ela (se houver).
    /// Com métrica (da busca ou da linha do Monitor), a funcionalidade segue a métrica. Buscar uma métrica
    /// do Monitor sempre sai dos Ajustes dele; sem busca, os Ajustes só saem quando a linha não era o Monitor aberto.
    func openSidebarFeature(_ feature: AppFeature,
                            route: SidebarSearchRoute?,
                            monitorKind: MetricDetailKind?,
                            keepsMonitorSettings: Bool) {
        applySidebarSearchTabs(route)
        if let kind = route?.metric ?? monitorKind {
            selectMonitorMetric(kind)
        } else {
            selectFeature(feature)
        }
        if route?.metric != nil || !keepsMonitorSettings {
            monitorTabIsSettings = false
        }
    }

    func selectSystem(_ system: WorkspaceSystemDestination) {
        self.systemDestination = system
        switch system {
        case .general:
            self.destination = .general
            SettingsRouter.shared.page = .general
        case .menuBar:
            self.destination = .menuBar
            SettingsRouter.shared.page = .menuBar
        case .featureHub:
            self.destination = .featureHub
            SettingsRouter.shared.page = .features
        case .shortcuts:
            self.destination = .shortcuts
            SettingsRouter.shared.page = .shortcuts
        case .advanced:
            self.destination = .advanced
            SettingsRouter.shared.page = .advanced
        case .about:
            self.destination = .about
            SettingsRouter.shared.page = .about
        case .releaseNotes:
            self.destination = .releaseNotes
            SettingsRouter.shared.page = .about
        }
        self.featureSettingsMode = false
        self.showsSettings = true
    }

    func selectSystemDestination(_ system: WorkspaceSystemDestination) {
        selectSystem(system)
    }

    func selectDestination(_ destination: WorkspaceDestination) {
        switch destination {
        case .feature(let f): selectFeature(f)
        case .general: selectSystem(.general)
        case .menuBar: selectSystem(.menuBar)
        case .featureHub: selectSystem(.featureHub)
        case .shortcuts: selectSystem(.shortcuts)
        case .advanced: selectSystem(.advanced)
        case .about: selectSystem(.about)
        case .releaseNotes: selectSystem(.releaseNotes)
        }
    }
}

/// Janela compartilhada por operações e Ajustes. Fechada ou minimizada, não
/// mantém views de operação nem demanda de telemetria.
final class FeatureWorkspaceWindow: NSObject, NSWindowDelegate {
    static let shared = FeatureWorkspaceWindow()
    private var window: NSWindow?
    private var holdsActivation = false
    var presentationWindow: NSWindow? { window }

    func show(_ feature: AppFeature? = nil, metric: MetricDetailKind? = nil, notchTab: NotchSettingsTab? = nil) {
        let state = FeatureWorkspaceState.shared
        state.showsSettings = false
        state.systemDestination = nil
        if let feature {
            state.selectFeature(feature)
        } else {
            state.destination = .feature(state.feature)
        }
        if let notchTab {
            state.notchTab = notchTab
        }
        present(feature, metric: metric, notchTab: notchTab)
    }

    func showSettings(_ destination: WorkspaceSystemDestination = .general) {
        FeatureWorkspaceState.shared.selectSystem(destination)
        present()
    }

    /// Opens the Features hub positioned directly on the Permissions tab.
    func openPermissionsHub() {
        SettingsRouter.shared.pendingPermissionsTab = true
        FeatureWorkspaceState.shared.selectSystem(.featureHub)
        present()
    }

    private func present(_ feature: AppFeature? = nil, metric: MetricDetailKind? = nil, notchTab: NotchSettingsTab? = nil) {
        let state = FeatureWorkspaceState.shared
        if let feature {
            state.selectFeature(feature)
            let metrics: [MetricDetailKind] = [.cpu, .gpu, .memory, .network, .disk, .power]
            if let kind = metrics.first(where: { $0.workspaceFeature == feature }) {
                state.metric = kind
                state.monitorTabIsSettings = false
            }
        }
        if let metric {
            state.metric = metric
            state.selectFeature(metric.workspaceFeature)
            state.monitorTabIsSettings = false
        }
        if let notchTab {
            state.notchTab = notchTab
        }
        if state.systemDestination == nil, !state.feature.isAvailable {
            guard let available = AppFeature.allCases.first(where: \.isAvailable) else {
                SettingsRouter.shared.page = .features
                state.selectSystem(.featureHub)
                present()
                return
            }
            state.selectFeature(available)
        }
        if window == nil {
            // O container AppKit é dono da geometria da janela. SwiftUI
            // dimensiona o conteúdo sem reescrever os limites nativos.
            let availableArea = NSScreen.main?.visibleFrame.size ?? .zero
            let initialSize = SettingsWindowSupport.initialContentSize(savedHeight: 0, availableArea: availableArea)
            let container = NSView(frame: NSRect(origin: .zero, size: initialSize))
            let host = NSHostingView(rootView: FeatureWorkspaceView())
            host.sizingOptions = []
            host.frame = container.bounds
            host.autoresizingMask = [.width, .height]
            container.addSubview(host)
            let result = NSWindow(contentRect: container.frame,
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                                  backing: .buffered, defer: false)
            result.contentView = container
            result.titleVisibility = .hidden
            result.titlebarAppearsTransparent = true
            result.titlebarSeparatorStyle = .none
            result.isMovableByWindowBackground = true
            result.isReleasedWhenClosed = false
            result.isRestorable = false
            result.tabbingMode = .disallowed
            let limits = SettingsWindowSupport.contentSizeLimits(availableArea: availableArea)
            result.contentMinSize = limits.min
            result.contentMaxSize = limits.max
            // Largura travada em 800 e piso de 690 quando a tela comporta; em
            // tela menor o tamanho é truncado pela área útil, sem regravar a
            // preferência salva.
            let savedHeight = UserDefaults.standard.double(forKey: DefaultsKey.settingsWindowHeight)
            result.setContentSize(SettingsWindowSupport.initialContentSize(savedHeight: savedHeight,
                                                                          availableArea: availableArea))
            result.delegate = self
            result.center()
            result.setFrame(SettingsWindowSupport.fittedFrame(frame: result.frame,
                                                              visibleFrame: NSScreen.main?.visibleFrame ?? .zero),
                            display: false)
            window = result
        } else if let window {
            fitWindowToScreen(window)
        }
        window?.title = "hexa"
        if window?.isMiniaturized == true { window?.deminiaturize(nil) }
        state.visible = true
        syncSettingsVisibility()
        retainActivation()
        appDelegate()?.closePopover(reason: .action)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    /// Reencaixa a janela na tela corrente derivando o tamanho da preferência
    /// salva, nunca do frame vivo truncado: restaura 800 e a altura salva
    /// quando a tela comporta e trunca quando não comporta. Não escreve defaults.
    private func fitWindowToScreen(_ window: NSWindow) {
        let area = (window.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        let limits = SettingsWindowSupport.contentSizeLimits(availableArea: area.size)
        window.contentMinSize = limits.min
        window.contentMaxSize = limits.max
        let savedHeight = UserDefaults.standard.double(forKey: DefaultsKey.settingsWindowHeight)
        window.setContentSize(SettingsWindowSupport.initialContentSize(savedHeight: savedHeight,
                                                                      availableArea: area.size))
        window.setFrame(SettingsWindowSupport.fittedFrame(frame: window.frame, visibleFrame: area), display: false)
    }

    func windowDidChangeScreen(_ notification: Notification) {
        guard let window else { return }
        fitWindowToScreen(window)
    }

    func windowWillClose(_ notification: Notification) {
        suspend()
        releaseActivation()
    }
    func windowDidMiniaturize(_ notification: Notification) { suspend() }
    func windowDidDeminiaturize(_ notification: Notification) {
        FeatureWorkspaceState.shared.visible = true
        syncSettingsVisibility()
    }
    func windowDidChangeOcclusionState(_ notification: Notification) {
        FeatureWorkspaceState.shared.visible = window?.occlusionState.contains(.visible) == true && window?.isMiniaturized == false
        syncSettingsVisibility()
        if !FeatureWorkspaceState.shared.visible { SystemMonitor.shared.setWorkspaceNeeds(.none) }
    }
    func windowDidEndLiveResize(_ notification: Notification) {
        guard let size = window?.contentView?.frame.size,
              SettingsWindowSupport.isValidContentSize(width: Double(size.width), height: Double(size.height)) else { return }
        UserDefaults.standard.set(Double(size.width), forKey: DefaultsKey.settingsWindowWidth)
        UserDefaults.standard.set(Double(size.height), forKey: DefaultsKey.settingsWindowHeight)
    }

    private func suspend() {
        FeatureWorkspaceState.shared.visible = false
        syncSettingsVisibility()
        SystemMonitor.shared.setWorkspaceNeeds(.none)
        // A view de detalhe de rede registra demanda com menuPanel = false e,
        // com a janela apenas ocultada, onDisappear não dispara. Revoga a
        // demanda ao suspender para não amostrar processos em background.
        let state = FeatureWorkspaceState.shared
        if state.systemDestination == nil, state.metric == .network {
            ProcessUsageService.shared.stopNonPanelNetworkMonitoring()
        }
    }
    func syncSettingsVisibility() {
        let state = FeatureWorkspaceState.shared
        let visible = state.visible && (state.showsSettings || state.systemDestination != nil)
        SettingsWindowVisibility.shared.set(visible)
        SecureInputMonitor.shared.setSettingsWindowOpen(visible)
    }

    /// A janela de telas precisa permanecer alcançável pelo Dock, como o
    /// onboarding. Minimizar não devolve a política: o ícone é o caminho de
    /// volta. Só o fechamento devolve.
    private func retainActivation() {
        guard !holdsActivation else { return }
        holdsActivation = true
        WindowActivationPolicy.retain()
    }

    private func releaseActivation() {
        guard holdsActivation else { return }
        holdsActivation = false
        WindowActivationPolicy.release()
    }

}

extension MetricDetailKind {
    var workspaceFeature: AppFeature {
        switch self {
        case .cpu: return .monitorCPU
        case .gpu: return .monitorGPU
        case .memory: return .monitorMemory
        case .network: return .monitorNetwork
        case .disk: return .monitorDisk
        case .battery, .power: return .monitorPower
        case .fan: return .fanControl
        case .connectedDevices: return .connectedDevices
        }
    }
}

private struct FeatureWorkspacePresentationKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var featureWorkspacePresentation: Bool {
        get { self[FeatureWorkspacePresentationKey.self] }
        set { self[FeatureWorkspacePresentationKey.self] = newValue }
    }
}
