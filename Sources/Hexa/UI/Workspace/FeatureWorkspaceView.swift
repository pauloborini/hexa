// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import SwiftUI

typealias AboutSettingsView = AboutSettings

struct FeatureWorkspaceView: View {
    @ObservedObject private var state = FeatureWorkspaceState.shared
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @State private var search = ""
    /// Mesma chave que o `MediaWorkspaceView` observa: a troca no segmento fixo reaplica os efeitos lá.
    @AppStorage(DefaultsKey.mediaLastTool) private var mediaLastTool = MediaTool.videoCompressor.rawValue
    /// Chaves lidas também pelo `ScreenshotService`: o resumo da Operação precisa
    /// acompanhar a escolha feita em Ajustes.
    @AppStorage(DefaultsKey.screenshotDefaultAction) private var screenshotDefaultActionRaw = ScreenshotDefaultAction.save.rawValue
    @AppStorage(DefaultsKey.screenshotCopyToClipboard) private var screenshotCopyToClipboard = false
    @AppStorage(DefaultsKey.screenshotAutoSaveToFolder) private var screenshotAutoSaveToFolder = false

    private var text: WorkspaceStrings { .localized(l10n.language) }
    private var hub: FeatureHubStrings { FeatureStrings.hub(l10n.language) }
    private let monitorFeatures: [AppFeature] = [.monitorCPU, .monitorGPU, .monitorMemory, .monitorNetwork, .monitorDisk, .monitorPower]
    private var isMonitor: Bool { state.systemDestination == nil && monitorFeatures.contains(state.feature) }
    private var isDynamicIsland: Bool { state.systemDestination == nil && state.feature == .notch }
    private let notchTabs = NotchSettingsTab.allCases
    private var title: String {
        if let module = activeModule { return moduleTitle(module) }
        return isMonitor ? l10n.s.tabMonitor : state.feature.hubTitle(l10n.s, hub: hub)
    }
    /// Módulo com dois ou mais membros disponíveis na seleção atual: o cabeçalho mostra o título do
    /// módulo e o segmento de membros. Nil para funcionalidade simples, telas do sistema e Monitor.
    private var activeModule: SidebarModule? {
        guard state.systemDestination == nil,
              let module = SidebarModule.module(containing: state.feature),
              module.availableMembers(isAvailable: { $0.isAvailable }).count >= 2 else { return nil }
        return module
    }
    private var monitorKinds: [MetricDetailKind] {
        let base: [MetricDetailKind] = [.cpu, .gpu, .memory, .network, .disk, .power]
        return base.filter { $0.workspaceFeature.isAvailable }
    }
    /// Destinos da busca da sidebar: a linha que casa e a aba interna que ela abre.
    private var searchRoutes: [SidebarSearchRoute] {
        SidebarSearchRoute.routes(for: search, language: l10n.language, monitorKinds: monitorKinds,
                                  isAvailable: { $0.isAvailable })
    }
    private var needs: SystemMonitorPanelNeeds {
        guard state.visible, state.systemDestination == nil, state.feature.isAvailable else { return .none }
        if isMonitor {
            if state.monitorTabIsSettings { return .none }
            return state.metric.monitorNeeds
        }
        if state.feature == .connectedDevices { return MetricDetailKind.connectedDevices.monitorNeeds }
        return .none
    }
    /// Subtítulo do scaffold da operação: segue a aba ou a métrica visível, não a descrição geral do recurso.
    private var subtitle: String {
        if isMonitor {
            if state.monitorTabIsSettings {
                return FeatureStrings.settingsPages(l10n.language).monitorDescription
            }
            return state.metric.workspaceFeature.hubDescription(hub)
        }
        if isDynamicIsland {
            let editor = FeatureStrings.notchEditor(l10n.language)
            switch state.notchTab {
            case .appearance: return FeatureStrings.notchExperience(l10n.language).appearanceHint
            case .content: return editor.sectionsHint
            case .activity: return editor.activityHint
            case .behavior: return editor.behaviorHint
            }
        }
        if state.feature == .mediaTools {
            switch state.mediaTool {
            case .videoCompressor: return hub.mediaVideoDescription
            case .gifMaker: return hub.mediaGIFDescription
            case .imageCompressor: return hub.mediaImageDescription
            case .textExtractor: return hub.mediaTextDescription
            }
        }
        if state.featureSettingsMode {
            switch state.feature {
            case .mixer:
                return FeatureStrings.generalSettings(l10n.language).sectionMixer
            case .appUpdates:
                return FeatureStrings.appUpdates(l10n.language).caption
            case .cleaner:
                return hub.cleanerSettingsDescription
            case .screenshot:
                return hub.screenshotSettingsDescription
            case .screenOCR:
                return hub.screenOCRSettingsDescription
            default:
                break
            }
        }
        return state.feature.hubDescription(hub)
    }

    var body: some View {
        workspace
            .background(HexaTheme.surfaceBase)
            .ignoresSafeArea(.container, edges: .top)
            .onChange(of: state.showsSettings) { _, _ in
                FeatureWorkspaceWindow.shared.syncSettingsVisibility()
                syncNeeds()
            }
            .onChange(of: state.systemDestination) { _, _ in
                FeatureWorkspaceWindow.shared.syncSettingsVisibility()
                syncNeeds()
            }
    }

    private var workspace: some View {
        HStack(alignment: .top, spacing: 0) {
            sidebar
                .frame(width: FeatureWorkspaceMetrics.sidebarWidth)
                .frame(maxHeight: .infinity)
                .fixedSize(horizontal: true, vertical: false)
            if state.visible {
                mainContent
            } else {
                Spacer()
            }
        }
        .frame(width: FeatureWorkspaceMetrics.width, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(HexaTheme.surfaceBase)
        .font(.hexa(.body))
        .foregroundStyle(HexaTheme.fgPrimary)
        .tint(HexaTheme.accentSolid)
        .onAppear { reconcile(); syncNeeds() }
        .onChange(of: state.feature) { _, _ in
            syncNeeds()
        }
        .onChange(of: state.monitorTabIsSettings) { _, _ in syncNeeds() }
        .onChange(of: state.visible) { _, _ in syncNeeds() }
        .onChange(of: needs) { _, _ in syncNeeds() }
        .onChange(of: features.revision) { _, _ in reconcile() }
        .onDisappear { SystemMonitor.shared.setWorkspaceNeeds(.none) }
    }

    @ViewBuilder
    private var mainContent: some View {
        if let system = state.systemDestination {
            systemContent(for: system)
                .frame(width: FeatureWorkspaceMetrics.width - FeatureWorkspaceMetrics.sidebarWidth)
                .frame(maxHeight: .infinity, alignment: .topLeading)
                .fixedSize(horizontal: true, vertical: false)
                .clipped()
                .environment(\.featureWorkspacePresentation, true)
        } else if state.feature.isAvailable {
            // Scaffold único da coluna direita: largura travada no
            // espaço complementar (580pt), imutável e incompressível (spec §7).
            HexaScreenScaffold(
                title: title,
                subtitle: subtitle,
                scrolls: operationScrolls,
                trailing: { headerTrailing },
                pinned: { pinnedTabs },
                content: {
                    operation
                        .id(isMonitor ? (state.monitorTabIsSettings ? "monitor-settings" : state.metric.rawValue) : (isDynamicIsland ? "notch-\(state.notchTab)" : (state.featureSettingsMode ? "\(state.feature.rawValue)-settings" : state.feature.rawValue)))
                })
                .frame(width: FeatureWorkspaceMetrics.width - FeatureWorkspaceMetrics.sidebarWidth)
                .frame(maxHeight: .infinity, alignment: .topLeading)
                .fixedSize(horizontal: true, vertical: false)
                .clipped()
                .environment(\.featureWorkspacePresentation, true)
        } else {
            Spacer()
        }
    }

    @ViewBuilder
    private func systemContent(for destination: WorkspaceSystemDestination) -> some View {
        switch destination {
        case .general:
            GeneralSettings()
        case .menuBar:
            MenuBarSettings()
        case .featureHub:
            FeatureHubSettings()
        case .shortcuts:
            ShortcutsSettings()
        case .advanced:
            AdvancedSettings()
        case .about:
            AboutSettingsView()
        case .releaseNotes:
            ReleaseNotesSettings()
        }
    }

    @ViewBuilder private var headerTrailing: some View {
        if isMonitor {
            settingsToggle(isOn: state.monitorTabIsSettings) { state.monitorTabIsSettings.toggle() }
        } else if state.feature == .mixer {
            settingsToggle(isOn: state.featureSettingsMode) { state.featureSettingsMode.toggle() }
        } else if state.feature == .cleaner {
            if activeModule != nil {
                settingsToggle(isOn: state.featureSettingsMode) { state.featureSettingsMode.toggle() }
            } else {
                HexaSegmentControl(
                    [text.operation, l10n.s.panelSettings],
                    selection: Binding(
                        get: { state.featureSettingsMode ? 1 : 0 },
                        set: { state.featureSettingsMode = ($0 == 1) }
                    )
                )
                .fixedSize()
            }
        } else if state.feature == .appUpdates {
            if activeModule != nil {
                settingsToggle(isOn: state.featureSettingsMode) { state.featureSettingsMode.toggle() }
            } else {
                HexaSegmentControl(
                    [text.operation, l10n.s.panelSettings],
                    selection: Binding(
                        get: { state.featureSettingsMode ? 1 : 0 },
                        set: { state.featureSettingsMode = ($0 == 1) }
                    )
                )
                .fixedSize()
            }
        } else if state.feature == .screenshot || state.feature == .screenOCR {
            settingsToggle(isOn: state.featureSettingsMode) { state.featureSettingsMode.toggle() }
        } else if state.feature == .killProcess {
            let killStrings = FeatureStrings.killProcess(l10n.language)
            HexaIconButton(
                icon: "arrow.clockwise",
                label: killStrings.refreshTooltip,
                variant: .small,
                action: { KillProcessService.shared.refresh(force: true) }
            )
            .help(killStrings.refreshTooltip)
        } else if state.feature == .portManager {
            let portStrings = FeatureStrings.portManager(l10n.language)
            HexaIconButton(
                icon: "arrow.clockwise",
                label: portStrings.refresh,
                variant: .small,
                action: { PortManagerService.shared.refresh() }
            )
            .help(portStrings.refresh)
        } else if isDynamicIsland {
            NotchActivationControl()
        }
    }

    /// Alternância Operação/Ajustes do slot `trailing` em telas com `pinned`: ícone + rótulo, com o estado
    /// ativo no fundo `selectionBg` (mesmo papel do segmento selecionado). Mesma altura do segmento compacto.
    private func settingsToggle(isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: HexaTheme.Spacing.xs) {
                HexaIcons.image("gearshape", size: HexaIconMetrics.small)
                Text(l10n.s.panelSettings)
                    .font(.hexa(.label))
                    .lineLimit(1)
            }
            .padding(.horizontal, HexaTheme.Spacing.m)
            .frame(height: HexaTheme.Density.rowCompact)
            .foregroundStyle(isOn ? HexaTheme.fgPrimary : HexaTheme.fgSecondary)
            .background(
                RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                    .fill(isOn ? HexaTheme.selectionBg : HexaTheme.surfaceInset)
            )
            .contentShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.control))
        }
        .buttonStyle(.plain)
        .fixedSize()
        .help(l10n.s.panelSettings)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    private var mediaToolBinding: Binding<MediaTool> {
        Binding(
            get: { MediaSupport.sanitizedTool(mediaLastTool) },
            set: { mediaLastTool = $0.rawValue }
        )
    }

    @ViewBuilder private var pinnedTabs: some View {
        if state.feature == .mediaTools {
            MediaToolPicker(selection: mediaToolBinding)
        } else if let module = activeModule {
            let members = module.availableMembers(isAvailable: { $0.isAvailable })
            HexaSegmentControl(members.map { memberLabel($0) }, selection: Binding(
                get: { members.firstIndex(of: state.feature) ?? 0 },
                set: { index in
                    guard members.indices.contains(index) else { return }
                    selectModuleMember(members[index])
                }))
        } else if isMonitor {
            // Em Ajustes o segmento continua presente, com todos os itens desabilitados: a altura do cabeçalho não muda.
            HexaSegmentControl(monitorKinds.map { $0.title(l10n.s) },
                               disabled: state.monitorTabIsSettings ? Set(monitorKinds.indices) : [],
                               selection: Binding(
                get: { monitorKinds.firstIndex(of: state.metric) ?? 0 },
                set: { index in
                    guard monitorKinds.indices.contains(index) else { return }
                    state.selectMonitorMetric(monitorKinds[index])
                }))
        } else if isDynamicIsland {
            HexaSegmentControl(notchTabs.map { $0.title(l10n.language) }, selection: Binding(
                get: { notchTabs.firstIndex(of: state.notchTab) ?? 0 },
                set: { index in
                    guard notchTabs.indices.contains(index) else { return }
                    state.notchTab = notchTabs[index]
                }))
        }
    }

    /// Rótulo de um membro de módulo no segmento `pinned`: rótulo curto onde o nome da funcionalidade é longo.
    private func memberLabel(_ member: AppFeature) -> String {
        switch member {
        case .maintenanceTasks: return hub.tabMaintenanceTasks
        case .killProcess: return hub.tabProcesses
        case .portManager: return hub.tabPorts
        case .screenOCR: return hub.tabScreenText
        default: return member.hubTitle(l10n.s, hub: hub)
        }
    }

    /// Abre o membro escolhido no segmento do módulo. `selectFeature` zera o modo Ajustes;
    /// ele é restaurado apenas quando o membro destino suporta modo de ajustes.
    private func selectModuleMember(_ member: AppFeature) {
        let supportsSettings: Bool
        switch member {
        case .cleaner, .appUpdates, .screenshot, .screenOCR:
            supportsSettings = true
        default:
            supportsSettings = false
        }
        let keepsSettings = supportsSettings && state.featureSettingsMode
        state.selectFeature(member)
        state.featureSettingsMode = keepsSettings
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.m) {
                HStack(spacing: HexaTheme.Spacing.s) {
                    BrandMark(width: HexaTheme.Spacing.xxl, tint: HexaTheme.fgPrimary)
                    HexaTheme.wordmark(size: HexaTheme.Spacing.xxl)
                }
                .padding(.top, FeatureWorkspaceMetrics.workspaceTopInset)
                .padding(.horizontal, HexaTheme.Spacing.xl)
                HexaSidebarSearchField(query: $search, placeholder: text.search)
            }
            .padding(.bottom, HexaTheme.Spacing.s)

            OverlayScrollView {
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                    // Lista reta: sem cabeçalho de grupo. Os grupos do catálogo
                    // ordenam as linhas, mas não as subdividem.
                    ForEach(FeatureGroup.allCases, id: \.self) { group in
                        ForEach(sidebarEntries(group), id: \.self) { entry in sidebarEntryRow(entry) }
                    }
                    // Fim da lista: respiro de altura fixa que rola com o
                    // conteúdo; a última linha não cola na borda.
                    Spacer().frame(height: HexaTheme.Spacing.xs)
                }
                .padding(.horizontal, HexaTheme.Spacing.s)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            systemSection
        }
        .frame(width: FeatureWorkspaceMetrics.sidebarWidth)
        .frame(maxHeight: .infinity)
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(1)
        .background(HexaTheme.surfaceRaised)
        .overlay(alignment: .trailing) {
            Rectangle().fill(HexaTheme.borderHairline).frame(width: HexaTheme.hairline)
        }
    }

    private var systemItems: [(destination: WorkspaceSystemDestination, title: String)] {
        [
            (.general, l10n.s.tabGeneral),
            (.menuBar, l10n.s.menuBarSection),
            (.featureHub, l10n.s.settingsGroupFeatures),
            (.shortcuts, l10n.s.shortcutsPageTitle),
            (.advanced, l10n.s.tabAdvanced),
            (.about, l10n.s.tabAbout),
            (.releaseNotes, l10n.s.tabReleaseNotes),
        ]
    }

    private var filteredSystemItems: [(destination: WorkspaceSystemDestination, title: String)] {
        let routes = searchRoutes
        return systemItems.filter { item in
            search.isEmpty
                || item.title.localizedStandardContains(search)
                || routes.contains { $0.system == item.destination }
        }
    }

    @ViewBuilder private var systemSection: some View {
        let items = filteredSystemItems
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HairlineDivider()
                VStack(alignment: .leading, spacing: 2) {
                    Text(text.system).hexaSectionLabel()
                        .padding(.horizontal, HexaTheme.Spacing.m)
                        .padding(.top, HexaTheme.Spacing.s)
                        .padding(.bottom, HexaTheme.Spacing.xs)
                    ForEach(items, id: \.destination) { item in
                        sidebarSystemRow(item.destination, title: item.title)
                    }
                }
                .padding(.horizontal, HexaTheme.Spacing.s)
                .padding(.bottom, HexaTheme.Spacing.s)
            }
        }
    }

    private func sidebarSystemRow(_ destination: WorkspaceSystemDestination, title: String) -> some View {
        let selected = state.systemDestination == destination
        return HexaSidebarRow(title: title, selected: selected) {
            state.applySidebarSearchTabs(searchRoutes.first { $0.system == destination })
            state.selectSystem(destination)
        }
    }

    private func sidebarFeatures(_ group: FeatureGroup) -> [AppFeature] {
        let routes = searchRoutes
        if group == .dynamicIsland {
            guard AppFeature.notch.isAvailable else { return [] }
            let matchesSearch = search.isEmpty
                || AppFeature.notch.hubTitle(l10n.s, hub: hub).localizedStandardContains(search)
                || NotchSettingsTab.allCases.contains { $0.title(l10n.language).localizedStandardContains(search) }
                || routes.contains { $0.feature == .notch }
            return matchesSearch ? [.notch] : []
        }
        var result = AppFeature.features(in: group).filter(\.isAvailable)
        if group == .monitor {
            result.removeAll { monitorFeatures.contains($0) }
            if let first = monitorFeatures.first(where: \.isAvailable) { result.insert(first, at: 0) }
        }
        return result.filter { feature in
            guard !search.isEmpty else { return true }
            if monitorFeatures.contains(feature) {
                if l10n.s.tabMonitor.localizedStandardContains(search) { return true }
                return monitorKinds.contains { $0.title(l10n.s).localizedStandardContains(search) }
            }
            return feature.hubTitle(l10n.s, hub: hub).localizedStandardContains(search)
                || routes.contains { $0.feature == feature }
        }
    }

    private func sidebarRow(_ feature: AppFeature) -> some View {
        let selected = state.systemDestination == nil && (feature == state.feature || (isMonitor && monitorFeatures.contains(feature)))
        let title = monitorFeatures.contains(feature) ? l10n.s.tabMonitor : feature.hubTitle(l10n.s, hub: hub)
        return HexaSidebarRow(title: title, selected: selected) {
            openSidebarFeature(feature)
        }
    }

    /// Destino da busca que casa com a linha: a própria funcionalidade ou, no Monitor, qualquer métrica dele.
    private func searchRoute(for feature: AppFeature) -> SidebarSearchRoute? {
        let group = monitorFeatures.contains(feature) ? monitorFeatures : [feature]
        return searchRoutes.first { route in route.feature.map { group.contains($0) } ?? false }
    }

    /// Abre a funcionalidade que vai de fato aparecer: a aba interna, a métrica e a seção vêm do destino da busca.
    private func openSidebarFeature(_ feature: AppFeature) {
        let wasMonitor = isMonitor
        // Linha do Monitor reabre a última métrica; a busca (route) continua prevalecendo em FeatureWorkspaceState.
        let monitorKind = monitorFeatures.contains(feature)
            ? (monitorKinds.contains(state.metric) ? state.metric : monitorKinds.first)
            : monitorKinds.first(where: { $0.workspaceFeature == feature })
        state.openSidebarFeature(feature,
                                 route: searchRoute(for: feature),
                                 monitorKind: monitorKind,
                                 keepsMonitorSettings: wasMonitor && monitorFeatures.contains(feature))
    }

    /// Entrada da lista de um grupo: funcionalidade simples ou módulo com dois ou mais membros disponíveis.
    private enum SidebarEntry: Hashable {
        case feature(AppFeature)
        case module(SidebarModule)
    }

    /// Entradas do grupo. Dynamic Island e Monitor seguem `sidebarFeatures`; os demais grupos
    /// colapsam cada módulo numa linha, na posição do primeiro membro disponível.
    private func sidebarEntries(_ group: FeatureGroup) -> [SidebarEntry] {
        if group == .dynamicIsland || group == .monitor {
            return sidebarFeatures(group).map { SidebarEntry.feature($0) }
        }
        var entries: [SidebarEntry] = []
        var handledModules: Set<SidebarModule> = []
        let routes = searchRoutes
        for feature in AppFeature.features(in: group).filter(\.isAvailable) {
            guard let module = SidebarModule.module(containing: feature) else {
                if sidebarMatches(feature.hubTitle(l10n.s, hub: hub))
                    || routes.contains(where: { $0.feature == feature }) {
                    entries.append(.feature(feature))
                }
                continue
            }
            guard handledModules.insert(module).inserted else { continue }
            let members = module.availableMembers(isAvailable: { $0.isAvailable })
            if members.count >= 2 {
                // O título do módulo também casa a busca, mesmo quando nenhum membro casa.
                let matches = search.isEmpty
                    || moduleTitle(module).localizedStandardContains(search)
                    || members.contains { member in
                        member.hubTitle(l10n.s, hub: hub).localizedStandardContains(search)
                            || routes.contains { $0.feature == member }
                    }
                if matches { entries.append(.module(module)) }
            } else if let member = members.first,
                      sidebarMatches(member.hubTitle(l10n.s, hub: hub))
                        || routes.contains(where: { $0.feature == member }) {
                entries.append(.feature(member))
            }
        }
        return entries
    }

    private func sidebarMatches(_ title: String) -> Bool {
        search.isEmpty || title.localizedStandardContains(search)
    }

    @ViewBuilder private func sidebarEntryRow(_ entry: SidebarEntry) -> some View {
        switch entry {
        case .feature(let feature): sidebarRow(feature)
        case .module(let module): sidebarModuleRow(module)
        }
    }

    private func sidebarModuleRow(_ module: SidebarModule) -> some View {
        let isAvailable: (AppFeature) -> Bool = { $0.isAvailable }
        let members = module.availableMembers(isAvailable: isAvailable)
        let selected = state.systemDestination == nil && members.contains(state.feature)
        return HexaSidebarRow(title: moduleTitle(module), selected: selected) {
            // Busca com membro casando abre esse membro; senão, o lembrado ou o primeiro disponível.
            let searched = search.isEmpty ? nil : searchRoutes.compactMap(\.feature).first { members.contains($0) }
            if let member = searched ?? module.defaultMember(remembered: state.rememberedModuleMember[module], isAvailable: isAvailable) {
                openSidebarFeature(member)
            }
        }
    }

    private func moduleTitle(_ module: SidebarModule) -> String {
        switch module {
        case .maintenance: return hub.moduleMaintenance
        case .processesAndPorts: return hub.processesAndPorts
        case .screenCapture: return hub.moduleScreenCapture
        case .energyAndDisplay: return hub.modulePowerDisplay
        }
    }

    @ViewBuilder private var operation: some View {
        if isMonitor {
            if state.monitorTabIsSettings {
                MonitorSettings(embedded: true)
            } else {
                scroll {
                    switch state.metric {
                    case .network: NetworkSection(collapsible: false)
                    case .disk: DiskSection(collapsible: false, selectedDiskIDBinding: $state.selectedDiskID)
                    case .battery, .power: PowerSection(collapsible: false)
                    default: MetricDetailView(kind: state.metric).id(state.metric)
                    }
                }
            }
        } else {
            switch state.feature {
            case .mixer:
                if state.featureSettingsMode {
                    scroll { GeneralToolSettings(anchor: .mixer, embedded: true) }
                } else {
                    scroll { MixerSection(collapsible: false, settingsMode: true) }
                }
            case .keepAwake: scroll { KeepAwakeCard(collapsible: false) }
            case .brightness: scroll { BrightnessSection(collapsible: false) }
            case .fanControl: scroll { FanControlSection(collapsible: false) }
            case .connectedDevices: scroll { MetricDetailView(kind: .connectedDevices) }
            case .cleaner: CleanerView(settingsMode: state.featureSettingsMode).padding(.horizontal, HexaTheme.Spacing.xxl)
            case .maintenanceTasks: MaintenanceTasksView()
            case .uninstaller: UninstallerView().padding(.horizontal, HexaTheme.Spacing.xxl)
            case .killProcess: KillProcessView().padding(.horizontal, HexaTheme.Spacing.xxl)
            case .portManager: PortManagerView().padding(.horizontal, HexaTheme.Spacing.xxl)
            case .dockDisplayLock: DockDisplayLockView()
            case .menuBarHiding: MenuBarHidingView()
            case .mediaTools: MediaWorkspaceView(compact: false, toolPickerHoisted: true).padding(.horizontal, HexaTheme.Spacing.xxl)
            case .appUpdates:
                if state.featureSettingsMode {
                    AppUpdatesSettings(embedded: true)
                } else {
                    scroll { AppUpdatesListView().onAppear { AppUpdatesService.shared.checkIfNeeded() } }
                }
            case .screenshot:
                if state.featureSettingsMode {
                    ScreenshotCaptureSettings(embedded: true)
                } else {
                    screenshotPage
                        .padding(.horizontal, HexaTheme.Spacing.xxl)
                }
            case .screenOCR:
                if state.featureSettingsMode {
                    ScreenTextCaptureSettings(embedded: true)
                } else {
                    scroll {
                        // Sem rótulo: o título da página já está no scaffold (DEC-017).
                        HexaCard {
                            Text(state.feature.hubDescription(hub)).foregroundStyle(HexaTheme.fgSecondary)
                            Button(l10n.s.ocrName) { ScreenTextService.shared.capture() }.buttonStyle(HexaActionButtonStyle())
                        }
                    }
                }
            case .notch:
                NotchSettings(workspaceFeature: .notch, workspaceTab: state.notchTab)
            default:
                NotchSettings(workspaceFeature: state.feature, workspaceTab: state.notchTab)
            }
        }
    }

    /// Mesmo desenho do Desinstalador: seções `HexaSection` (rótulo fora do cartão).
    /// A rolagem é do scaffold.
    private var screenshotPage: some View {
        let strings = FeatureStrings.screenshot(l10n.language)
        return VStack(alignment: .leading, spacing: HexaTheme.Spacing.l) {
            // Sem rótulo: o título da página já está no scaffold (DEC-017).
            HexaCard {
                HStack(spacing: HexaTheme.Spacing.s) {
                    Button {
                        ScreenshotService.shared.capture()
                    } label: {
                        Label(strings.captureButton, hexaIcon: "camera.viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                    Button {
                        ScreenshotService.shared.captureScrolling()
                    } label: {
                        Label(strings.scrollingCaptureButton, hexaIcon: "rectangle.stack")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(HexaActionButtonStyle())
                .controlSize(.large)
                Text(afterCaptureSummary(strings))
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
            HexaSection(FeatureStrings.recentCaptures(l10n.language).title) {
                RecentCapturesView(onClose: nil)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Resumo honesto do que acontece depois da captura, lido das mesmas
    /// chaves que o serviço usa.
    private func afterCaptureSummary(_ strings: ScreenshotFeatureStrings) -> String {
        let action = ScreenshotDefaultAction(rawValue: screenshotDefaultActionRaw) ?? .none
        let primary: String
        switch action {
        case .none: primary = strings.defaultActionNone
        case .save: primary = strings.saveButton
        case .saveAndCopy: primary = strings.defaultActionSaveAndCopy
        case .copy: primary = strings.copyButton
        case .edit: primary = strings.editButton
        }
        var parts = [primary]
        if screenshotCopyToClipboard && !action.copiesToClipboard { parts.append(strings.copyButton) }
        if screenshotAutoSaveToFolder && !action.savesFile { parts.append(strings.saveButton) }
        return String(format: strings.afterCaptureSummaryFormat, parts.joined(separator: " + "))
    }

    /// Telas com lista ou rodapé próprio (Limpeza, Desinstalador, Portas,
    /// Processos, Mídia) mantêm a rolagem interna; o resto rola no scaffold.
    private var operationScrolls: Bool {
        if isMonitor { return !state.monitorTabIsSettings }
        if state.featureSettingsMode {
            switch state.feature {
            case .cleaner, .appUpdates, .screenshot, .screenOCR:
                return false
            default:
                break
            }
        }
        switch state.feature {
        case .mixer, .keepAwake, .brightness, .fanControl, .connectedDevices,
             .appUpdates, .screenshot, .screenOCR, .maintenanceTasks, .menuBarHiding:
            return true
        default:
            return false
        }
    }

    private func scroll<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xl) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, HexaTheme.Spacing.xxl)
    }
    private func syncNeeds() { SystemMonitor.shared.setWorkspaceNeeds(needs) }
    private func reconcile() {
        if AppFeature.dynamicIslandExtensions.contains(state.feature) {
            state.feature = .notch
            if state.systemDestination == nil {
                state.destination = .feature(.notch)
            }
        }
        // Membro desligado de um módulo que ainda tem outro disponível: abre o membro padrão do módulo.
        if !state.feature.isAvailable, let module = SidebarModule.module(containing: state.feature),
           let member = module.defaultMember(remembered: state.rememberedModuleMember[module], isAvailable: { $0.isAvailable }) {
            if state.systemDestination == nil {
                state.selectFeature(member)
            } else {
                // Em tela do sistema, só a funcionalidade muda; a tela aberta não é trocada.
                state.feature = member
            }
        }
        if !state.feature.isAvailable, let first = AppFeature.allCases.first(where: \.isAvailable) {
            state.feature = first
            if state.systemDestination == nil {
                state.destination = .feature(first)
            }
        }
        if isMonitor, !monitorKinds.contains(state.metric), let first = monitorKinds.first { state.selectMonitorMetric(first) }
        if isDynamicIsland, !notchTabs.contains(state.notchTab), let first = notchTabs.first { state.notchTab = first }
    }
}
