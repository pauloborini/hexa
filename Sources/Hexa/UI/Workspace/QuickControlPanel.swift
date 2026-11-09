// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import FanControlCore
import SwiftUI

/// Consulta e atalhos rápidos. Operações completas abrem a janela de funcionalidades.
struct QuickControlPanel: View {
    @FocusState private var focusedMetric: MetricDetailKind?
    @FocusState private var focusedShortcut: String?
    @FocusState private var focusedMaintenance: MaintenanceTaskID?
    @FocusState private var focusedDisplayID: CGDirectDisplayID?
    @FocusState private var keepAwakeFocused: Bool
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var monitor = SystemMonitor.shared
    @ObservedObject private var fanService = FanControlService.shared
    @ObservedObject private var awake = KeepAwakeManager.shared
    @ObservedObject private var panel = MenuPanelFocus.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var protection = DiskProtectionService.shared
    @ObservedObject private var maintenance = MaintenanceTasksService.shared
    @ObservedObject private var brightness = BrightnessService.shared
    @ObservedObject private var permissions = Permissions.shared
    @State private var selectedDisplayID: CGDirectDisplayID?
    @State private var contentHeight: CGFloat = 0
    @State private var headerHeight: CGFloat = 0
    @State private var footerHeight: CGFloat = 0

    @AppStorage(DefaultsKey.temperatureUnit) private var temperatureUnit = TemperatureUnit.celsius.rawValue
    @AppStorage(DefaultsKey.monitorShowSystem) private var showSystem = true
    @AppStorage(DefaultsKey.monitorSysFans) private var showFans = true
    @AppStorage(DefaultsKey.monitorShowDisk) private var showDisk = true
    @AppStorage(DefaultsKey.monitorShowPower) private var showPower = true

    // Quick shortcuts
    @AppStorage(DefaultsKey.panelShowKeepAwake) private var showAwake = true
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
    @AppStorage(DefaultsKey.brightnessControlEnabled) private var brightnessControlEnabled = false
    @AppStorage(DefaultsKey.brightnessOSDEnabled) private var brightnessOSDEnabled = false

    private var text: WorkspaceStrings { .localized(l10n.language) }
    private var appearance: MenuBarAppearanceStrings { FeatureStrings.menuBarAppearance(l10n.language) }
    private var snapshot: SystemSnapshot { monitor.snapshot }

    /// Gravação de Tela ausente: o atalho de captura avisa antes do clique.
    /// Nada é pedido ao abrir o popover; o serviço de captura pede na hora em
    /// que roda, como já faz.
    private var screenCapturePermissionMissing: Bool { !permissions.screenRecording }

    /// Aviso dos atalhos de captura, montado com o vocabulário de permissão
    /// que o painel e os ajustes já usam.
    private var screenCapturePermissionWarning: String? {
        screenCapturePermissionMissing
            ? "\(l10n.s.permissionRequired): \(l10n.s.permissionScreenRecording)"
            : nil
    }

    /// Primeira leitura ainda não chegou: o lugar da faixa de status vira um
    /// estado de carregamento, em vez de traços. O estado é publicado pelo
    /// monitor, sem timer nem leitura nova.
    private var awaitsFirstReading: Bool {
        !monitor.hasReading && hasStatusFeatures
    }

    /// Altura útil do popover inteiro: a tela em que o ícone está ancorado,
    /// menos o espaço que a janela do popover usa para a seta. Medir contra a
    /// tela ancorada evita abrir o popover ao lado do ícone.
    private var availablePanelHeight: CGFloat {
        max(320, ((PanelInteractionState.shared.anchorScreen ?? NSScreen.withMenuBar)?.visibleFrame.height ?? 760) - 28)
    }

    /// Teto do corpo: a altura útil menos o cabeçalho e o rodapé medidos. O teto
    /// desconta o cromo porque o popover inteiro precisa caber na tela, não só o
    /// corpo. Sem isso, cabeçalho e rodapé somados ao corpo estouram a tela e o
    /// AppKit pode posicionar o popover ao lado do ícone.
    private var maxContentHeight: CGFloat {
        max(0, availablePanelHeight - headerHeight - footerHeight)
    }

    /// Só o corpo rola quando passa do teto; cabeçalho e rodapé ficam fora.
    private var scrollsBody: Bool { contentHeight > maxContentHeight + 0.5 }

    private var needs: SystemMonitorPanelNeeds {
        guard panel.popoverIsVisible else { return .none }
        return SystemMonitorPanelNeeds(disk: showDisk && AppFeature.monitorDisk.isAvailable,
                                       power: showPower && AppFeature.monitorPower.isAvailable,
                                       cpu: showSystem && AppFeature.monitorCPU.isAvailable,
                                       memory: showSystem && AppFeature.monitorMemory.isAvailable,
                                       cpuTemperature: showSystem && AppFeature.monitorCPU.isAvailable,
                                       gpuTemperature: showSystem && AppFeature.monitorGPU.isAvailable,
                                       fanSpeed: showFans && AppFeature.fanControl.isAvailable && SystemMonitor.fanTelemetryAvailable)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: HexaTheme.Spacing.s) {
                BrandMark(width: HexaTheme.Spacing.xxl, tint: HexaTheme.fgPrimary)
                HexaTheme.wordmark(size: HexaTheme.Spacing.xxl)
                Spacer()
                Text(ProcessInfo.processInfo.hostName.components(separatedBy: ".").first ?? "Mac")
                    .font(.hexa(.body)).foregroundStyle(HexaTheme.fgSecondary).lineLimit(1)
            }
            .padding(.horizontal, HexaTheme.Spacing.l)
            .padding(.top, HexaTheme.Spacing.l)
            .padding(.bottom, HexaTheme.Spacing.m)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }

            if hasPanelBody {
                if scrollsBody {
                    ScrollView(.vertical) {
                        bodyContent
                    }
                    .frame(height: maxContentHeight)
                } else {
                    bodyContent
                }
            }

            // Divisor e ação medidos juntos: o teto do corpo desconta essa altura.
            VStack(spacing: 0) {
                HairlineDivider()

                // Open Hexa action
                HStack(spacing: HexaTheme.Spacing.m) {
                    Button {
                        appDelegate()?.closePopover()
                        FeatureWorkspaceWindow.shared.show()
                    } label: {
                        HStack(spacing: HexaTheme.Spacing.s) {
                            Text(text.open).lineLimit(1)
                            Spacer(minLength: HexaTheme.Spacing.s)
                            HexaIcons.image("arrow.up.right")
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(HexaActionButtonStyle())
                }
                .padding(HexaTheme.Spacing.l)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { footerHeight = $0 }
        }
        .frame(width: FeatureWorkspaceMetrics.quickWidth)
        .font(.hexa(.body)).foregroundStyle(HexaTheme.fgPrimary)
        .background(HexaTheme.surfaceRaised)
        .onAppear { syncNeeds() }
        .onChange(of: needs) { _, _ in syncNeeds() }
        .onReceive(NotificationCenter.default.publisher(for: .menuPanelWillShow)) { _ in syncNeeds() }
        .onDisappear { SystemMonitor.shared.setMenuPanelNeeds(.none) }
    }

    // MARK: - Body composition

    /// Corpo do popover em faixas de largura total: status, ações, brilho e,
    /// por último, os discos. A altura é medida aqui para que só esta área
    /// role quando passar do teto.
    private var bodyContent: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.m) {
            if awaitsFirstReading {
                HexaBusyState(variant: .compact, message: l10n.s.breakdownMeasuring)
            } else if !statusReadings.isEmpty {
                statusBand
            }

            if hasActionRows {
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                    sectionTitle(appearance.quickActionsSection)
                    VStack(alignment: .leading, spacing: HexaTheme.Spacing.m) {
                        keepAwakeRow
                        quickShortcutsSection
                    }
                }
            }

            quickBrightnessCard

            if !awaitsFirstReading {
                diskStrip
            }
        }
        .padding(.horizontal, HexaTheme.Spacing.l)
        .padding(.bottom, HexaTheme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
    }

    /// Linhas de ação visíveis: Keep Awake e a grade de atalhos.
    private var hasActionRows: Bool {
        (showAwake && AppFeature.keepAwake.isAvailable) || hasGridShortcuts
    }

    /// O corpo aparece quando há qualquer faixa para mostrar. Discos entram
    /// pela disponibilidade da feature, mesmo antes da primeira leitura.
    private var hasPanelBody: Bool {
        hasStatusFeatures || hasDiskEnabled || hasActionRows || hasQuickBrightness
    }

    /// Features de status armadas. A faixa aparece com traços enquanto a
    /// primeira leitura não chega.
    private var hasStatusFeatures: Bool {
        (showSystem && (AppFeature.monitorCPU.isAvailable
                        || AppFeature.monitorGPU.isAvailable
                        || AppFeature.monitorMemory.isAvailable))
            || (showFans && AppFeature.fanControl.isAvailable && SystemMonitor.fanTelemetryAvailable)
            || (showPower && AppFeature.monitorPower.isAvailable)
    }

    private var hasDiskEnabled: Bool {
        showDisk && AppFeature.monitorDisk.isAvailable
    }

    // MARK: - Status band

    /// Uma leitura da faixa de status. O complemento é a temperatura do sensor
    /// que a métrica já acompanha; não há leitura nova.
    private struct StatusReading {
        let kind: MetricDetailKind
        let label: String
        let value: String
        let detail: String?
        let statusIcon: String?
        let accessibilityDetail: String?
    }

    /// Leituras visíveis na ordem CPU, GPU, memória, ventoinhas e
    /// bateria/energia. A GPU só entra quando o sensor já entregou a leitura.
    private var statusReadings: [StatusReading] {
        var items: [StatusReading] = []

        if showSystem, AppFeature.monitorCPU.isAvailable {
            items.append(StatusReading(
                kind: .cpu,
                label: MetricDetailKind.cpu.title(l10n.s),
                value: snapshot.cpuUsage.map(MetricFormat.percent) ?? "–",
                detail: snapshot.cpuTemperature.map { MetricFormat.temperatureCompact($0, unit: displayUnit) },
                statusIcon: nil,
                accessibilityDetail: nil))
        }

        if showSystem, AppFeature.monitorGPU.isAvailable, let temperature = snapshot.gpuTemperature {
            items.append(StatusReading(
                kind: .gpu,
                label: MetricDetailKind.gpu.title(l10n.s),
                value: MetricFormat.temperatureCompact(temperature, unit: displayUnit),
                detail: nil,
                statusIcon: nil,
                accessibilityDetail: nil))
        }

        if showSystem, AppFeature.monitorMemory.isAvailable {
            items.append(StatusReading(
                kind: .memory,
                label: MetricDetailKind.memory.title(l10n.s),
                value: snapshot.memoryUsed.map(MetricFormat.bytes) ?? "–",
                detail: snapshot.memoryTotal.map { "/ " + MetricFormat.bytes($0) },
                statusIcon: nil,
                accessibilityDetail: nil))
        }

        if showFans, AppFeature.fanControl.isAvailable, SystemMonitor.fanTelemetryAvailable {
            items.append(StatusReading(
                kind: .fan,
                label: fanStrings.fanCompactTitle,
                value: fanValue,
                detail: fanDetail,
                statusIcon: nil,
                accessibilityDetail: nil))
        }

        if showPower, AppFeature.monitorPower.isAvailable {
            if PowerSampler.hasInternalBattery {
                items.append(StatusReading(
                    kind: .battery,
                    label: MetricDetailKind.battery.title(l10n.s),
                    value: snapshot.power?.chargePercent.map { "\($0)%" } ?? "–",
                    detail: snapshot.batteryTemperature.map { MetricFormat.temperatureCompact($0, unit: displayUnit) },
                    statusIcon: powerStatusIcon,
                    accessibilityDetail: powerDetail))
            } else {
                items.append(StatusReading(
                    kind: .power,
                    label: MetricDetailKind.power.title(l10n.s),
                    value: snapshot.power?.systemWatts.map(MetricFormat.watts) ?? "–",
                    detail: nil,
                    statusIcon: nil,
                    accessibilityDetail: l10n.s.powerSystem))
            }
        }

        return items
    }

    /// Unidade de temperatura exibida no painel.
    private var displayUnit: TemperatureUnit {
        TemperatureUnit(rawValue: temperatureUnit) ?? .celsius
    }

    /// Temperatura SMART do disco interno, exibida no cabeçalho do bloco de discos.
    private var internalDiskTemperature: Double? {
        snapshot.disk?.devices.first(where: \.isInternal)?.smart?.temperatureCelsius
    }

    /// Faixa de status de largura total: uma célula por leitura, com
    /// divisórias hairline. Cada célula abre o detalhe da métrica no workspace.
    private var statusBand: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(statusReadings.enumerated()), id: \.offset) { index, reading in
                if index > 0 {
                    HairlineDivider(vertical: true)
                        .frame(height: HexaTheme.Spacing.xxl)
                        .frame(maxHeight: .infinity)
                }
                statusReadingCell(reading)
            }
        }
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, HexaTheme.Spacing.s)
        .background(HexaTheme.surfaceInset, in: RoundedRectangle(cornerRadius: HexaTheme.Radius.control))
        .overlay {
            RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                .strokeBorder(HexaTheme.borderHairline, lineWidth: HexaTheme.hairline)
        }
    }

    /// Célula da faixa: ícone e rótulo presos no topo; valor e, quando existe,
    /// a temperatura ou o total formam o bloco de informação, centralizado na
    /// altura que sobra abaixo do rótulo. O anel de foco acompanha o botão.
    private func statusReadingCell(_ reading: StatusReading) -> some View {
        Button {
            appDelegate()?.closePopover()
            FeatureWorkspaceWindow.shared.show(metric: reading.kind)
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: HexaTheme.Spacing.xs) {
                    HexaIcons.image(reading.kind.symbolName, size: 10)
                        .foregroundStyle(HexaTheme.fgSecondary)
                    Text(reading.label)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(.bottom, HexaTheme.Spacing.xs)

                Spacer(minLength: 0)

                VStack(spacing: HexaTheme.Spacing.xs) {
                    HStack(spacing: HexaTheme.Spacing.xs) {
                        Text(reading.value)
                            .font(.hexa(.data))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        if let statusIcon = reading.statusIcon {
                            HexaIcons.image(statusIcon, size: 10)
                                .foregroundStyle(HexaTheme.fgSecondary)
                        }
                    }
                    if let detail = reading.detail {
                        Text(detail)
                            .font(.hexa(.micro))
                            .foregroundStyle(HexaTheme.fgSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($focusedMetric, equals: reading.kind)
        .overlay {
            if focusedMetric == reading.kind {
                RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                    .strokeBorder(HexaTheme.focusRing, lineWidth: 2)
                    .padding(1)
            }
        }
        .accessibilityLabel([reading.label, reading.value, reading.detail ?? "", reading.accessibilityDetail ?? ""]
            .filter { !$0.isEmpty }
            .joined(separator: ", "))
    }

    // MARK: - Disks

    /// Discos no rodapé do corpo: até três colunas por linha; a grade quebra
    /// para a linha seguinte quando há mais volumes. A cauda cresce sem
    /// empurrar as ações.
    @ViewBuilder
    private var diskStrip: some View {
        if showDisk, AppFeature.monitorDisk.isAvailable, let disks = snapshot.disk?.devices, !disks.isEmpty {
            let columnCount = min(Self.diskColumnCount, disks.count)
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                HStack(spacing: HexaTheme.Spacing.xs) {
                    HexaIcons.image("internaldrive", size: 10)
                        .foregroundStyle(HexaTheme.fgSecondary)
                    Text(l10n.s.diskSection)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgSecondary)
                    if let temperature = internalDiskTemperature {
                        Text(MetricFormat.temperatureCompact(temperature, unit: displayUnit))
                            .font(.hexa(.label))
                            .foregroundStyle(HexaTheme.fgSecondary)
                            .monospacedDigit()
                            .accessibilityLabel("\(l10n.s.diskSection) \(l10n.s.diskTemperature) \(MetricFormat.temperature(temperature, unit: displayUnit))")
                    }
                }
                LazyVGrid(columns: diskColumns(count: columnCount), alignment: .leading, spacing: HexaTheme.Spacing.s) {
                    ForEach(Array(disks.enumerated()), id: \.element.id) { index, disk in
                        quickDiskColumn(disk)
                            .overlay(alignment: .leading) {
                                if index % columnCount != 0 {
                                    Rectangle()
                                        .fill(HexaTheme.borderHairline)
                                        .frame(width: HexaTheme.hairline)
                                        .offset(x: -HexaTheme.Spacing.xs)
                                }
                            }
                    }
                }
            }
            .padding(HexaTheme.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HexaTheme.surfaceInset, in: RoundedRectangle(cornerRadius: HexaTheme.Radius.control))
            .overlay {
                RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                    .strokeBorder(HexaTheme.borderHairline, lineWidth: HexaTheme.hairline)
            }
        }
    }

    private static let diskColumnCount = 3
    private func diskColumns(count: Int) -> [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: HexaTheme.Spacing.s),
              count: count)
    }

    private func quickDiskColumn(_ disk: DiskDeviceReading) -> some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            HStack(spacing: HexaTheme.Spacing.xs) {
                Text(disk.name)
                    .font(.hexa(.label))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: HexaTheme.Spacing.xs)
                if disk.canEject {
                    DiskSelectorEjectButton(state: protection.state(for: disk),
                                            idleHelp: l10n.s.diskEject,
                                            busyHelp: l10n.s.diskEjecting,
                                            readyHelp: l10n.s.diskReadyToRemove,
                                            failedHelp: l10n.s.diskEjectFailed) {
                        protection.eject(disk)
                    }
                }
            }
            UsageBar(fraction: disk.usedFraction, elevatedThreshold: 0.75, criticalThreshold: 0.9)
            HStack(spacing: HexaTheme.Spacing.xs) {
                Text("\(MetricFormat.percent(disk.usedFraction)) \(l10n.s.diskUsed)")
                    .lineLimit(1)
                Spacer(minLength: HexaTheme.Spacing.xs)
                Text("\(MetricFormat.diskBytes(disk.freeBytes)) \(l10n.s.diskAvailable)")
                    .lineLimit(1)
            }
            .font(.hexa(.micro))
            .monospacedDigit()
            .foregroundStyle(HexaTheme.fgSecondary)
            .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Keep Awake

    /// Keep Awake como primeira ação do popover: linha inteira, com a leitura
    /// do tempo restante quando a sessão está ativa. A duração escolhida fica
    /// no menu de contexto e no workspace, não no popover.
    @ViewBuilder
    private var keepAwakeRow: some View {
        if showAwake, AppFeature.keepAwake.isAvailable {
            Button {
                awake.toggle()
            } label: {
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                    HStack(spacing: HexaTheme.Spacing.s) {
                        HexaIcons.image(awake.isActive ? "cup.and.saucer.fill" : "cup.and.saucer", size: 13)
                            .font(.hexa(.body))
                            .foregroundStyle(awake.isActive ? HexaTheme.awakeActive : HexaTheme.fgSecondary)
                            .frame(width: 18)
                        Text(l10n.s.keepAwakeTitle)
                            .font(.hexa(.body))
                            .foregroundStyle(HexaTheme.fgPrimary)
                            .lineLimit(1)
                        Spacer(minLength: HexaTheme.Spacing.s)
                        Circle()
                            .fill(awake.isActive ? HexaTheme.awakeActive : HexaTheme.fgSecondary.opacity(0.3))
                            .frame(width: 7, height: 7)
                    }
                    keepAwakeSessionLine
                }
                .padding(.horizontal, HexaTheme.Spacing.m)
                .padding(.vertical, HexaTheme.Spacing.s)
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                .background(awake.isActive ? HexaTheme.awakeActive.opacity(0.12) : HexaTheme.surfaceInset,
                            in: RoundedRectangle(cornerRadius: HexaTheme.Radius.control))
                .overlay {
                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                        .strokeBorder(awake.isActive ? HexaTheme.awakeActive.opacity(0.4) : HexaTheme.borderHairline,
                                      lineWidth: HexaTheme.hairline)
                }
                .overlay {
                    if keepAwakeFocused {
                        RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                            .strokeBorder(HexaTheme.focusRing, lineWidth: 2)
                            .padding(1)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focused($keepAwakeFocused)
            .accessibilityValue(keepAwakeAccessibilityValue)
            .accessibilityAddTraits(awake.isActive ? .isSelected : [])
        }
    }

    /// Mesmas frases da segunda linha, em texto simples para o VoiceOver: a
    /// linha visual é um `TimelineView` e não serve como valor. Inativa não
    /// tem valor.
    private var keepAwakeAccessibilityValue: String {
        guard awake.isActive else { return "" }
        if awake.sessionTrigger == .automation {
            return FeatureStrings.keepAwakeAutomation(l10n.language).activeStatus(for: awake.activeAutomationConditions)
        }
        if let end = awake.endDate {
            return "\(l10n.s.keepAwakeEndsIn) \(KeepAwakeCard.remainingText(until: end))"
        }
        return l10n.s.keepAwakeUntilDisabled
    }

    /// Mesma leitura do card de Keep Awake. Inativa não tem segunda linha.
    private var keepAwakeSessionLine: some View {
        Group {
            if awake.isActive {
                if awake.sessionTrigger == .automation {
                    Text(FeatureStrings.keepAwakeAutomation(l10n.language).activeStatus(for: awake.activeAutomationConditions))
                } else if let end = awake.endDate {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text("\(l10n.s.keepAwakeEndsIn) \(KeepAwakeCard.remainingText(until: end))")
                    }
                } else {
                    Text(l10n.s.keepAwakeUntilDisabled)
                }
            }
        }
        .font(.hexa(.label))
        .foregroundStyle(HexaTheme.fgSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Quick Shortcuts

    /// Grade de atalhos sem Keep Awake: ele é a primeira linha das ações.
    private var hasGridShortcuts: Bool {
        (showScreenshot && AppFeature.screenshot.isAvailable)
            || (showScreenOCR && AppFeature.screenOCR.isAvailable)
            || (showCleaner && AppFeature.cleaner.isAvailable)
            || (showUninstaller && AppFeature.uninstaller.isAvailable)
            || (showAppUpdates && AppFeature.appUpdates.isAvailable)
            || (showPortManager && AppFeature.portManager.isAvailable)
            || (showKillProcess && AppFeature.killProcess.isAvailable)
            || (showPurgeMemory && AppFeature.maintenanceTasks.isAvailable)
            || (showFlushDNS && AppFeature.maintenanceTasks.isAvailable)
    }

    @ViewBuilder
    private var quickShortcutsSection: some View {
        if hasGridShortcuts {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: HexaTheme.Spacing.s) {
                if showScreenshot, AppFeature.screenshot.isAvailable {
                    quickShortcutButton(
                        icon: "camera.viewfinder",
                        title: FeatureStrings.screenshot(l10n.language).pageTitle,
                        warning: screenCapturePermissionWarning
                    ) {
                        appDelegate()?.closePopover()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            ScreenshotService.shared.capture()
                        }
                    }
                }
                if showScreenOCR, AppFeature.screenOCR.isAvailable {
                    quickShortcutButton(
                        icon: "text.viewfinder",
                        title: l10n.s.ocrName,
                        warning: screenCapturePermissionWarning
                    ) {
                        appDelegate()?.closePopover()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            ScreenTextService.shared.capture()
                        }
                    }
                }
                if showCleaner, AppFeature.cleaner.isAvailable {
                    quickShortcutButton(
                        icon: "sparkles",
                        title: l10n.s.cleanerName
                    ) {
                        appDelegate()?.closePopover()
                        FeatureWorkspaceWindow.shared.show(.cleaner)
                    }
                }
                if showUninstaller, AppFeature.uninstaller.isAvailable {
                    quickShortcutButton(
                        icon: "trash",
                        title: l10n.s.uninstallerName
                    ) {
                        appDelegate()?.closePopover()
                        FeatureWorkspaceWindow.shared.show(.uninstaller)
                    }
                }
                if showAppUpdates, AppFeature.appUpdates.isAvailable {
                    quickShortcutButton(
                        icon: "arrow.triangle.2.circlepath",
                        title: FeatureStrings.appUpdates(l10n.language).pageTitle
                    ) {
                        appDelegate()?.closePopover()
                        FeatureWorkspaceWindow.shared.show(.appUpdates)
                    }
                }
                if showPortManager, AppFeature.portManager.isAvailable {
                    quickShortcutButton(
                        icon: "point.3.connected.trianglepath.dotted",
                        title: FeatureStrings.portManager(l10n.language).title
                    ) {
                        appDelegate()?.closePopover()
                        FeatureWorkspaceWindow.shared.show(.portManager)
                    }
                }
                if showKillProcess, AppFeature.killProcess.isAvailable {
                    quickShortcutButton(
                        icon: "xmark.octagon",
                        title: FeatureStrings.killProcess(l10n.language).pageTitle
                    ) {
                        appDelegate()?.closePopover()
                        FeatureWorkspaceWindow.shared.show(.killProcess)
                    }
                }
                if showPurgeMemory, AppFeature.maintenanceTasks.isAvailable {
                    maintenanceShortcutButton(.purgeInactiveMemory,
                                              title: FeatureStrings.maintenanceTasks(l10n.language).taskPurgeMemoryTitle)
                }
                if showFlushDNS, AppFeature.maintenanceTasks.isAvailable {
                    maintenanceShortcutButton(.flushDNS,
                                              title: FeatureStrings.maintenanceTasks(l10n.language).taskFlushDNSTitle)
                }
            }
        }
    }

    /// `warning` marca o atalho com a permissão ausente antes do clique. O
    /// glifo fica à direita do título, e não no lugar do ícone da ferramenta:
    /// a 42 pt de altura o ícone é o que identifica a ação (captura ou OCR).
    @ViewBuilder
    private func quickShortcutButton(icon: String,
                                     title: String,
                                     warning: String? = nil,
                                     action: @escaping () -> Void) -> some View {
        let button = Button(action: action) {
            HStack(spacing: HexaTheme.Spacing.s) {
                HexaIcons.image(icon, size: 13)
                    .font(.hexa(.body))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .frame(width: 18)
                Text(title)
                    .font(.hexa(.body))
                    .foregroundStyle(HexaTheme.fgPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if warning != nil {
                    HexaIcons.image("exclamationmark.triangle", size: 11)
                        .font(.hexa(.body))
                        .foregroundStyle(HexaTheme.statusWarning)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, HexaTheme.Spacing.m)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(HexaTheme.surfaceInset, in: RoundedRectangle(cornerRadius: HexaTheme.Radius.control))
            .overlay {
                RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                    .strokeBorder(HexaTheme.borderHairline, lineWidth: HexaTheme.hairline)
            }
            .overlay {
                if focusedShortcut == icon {
                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                        .strokeBorder(HexaTheme.focusRing, lineWidth: 2)
                        .padding(1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($focusedShortcut, equals: icon)

        if let warning {
            button
                .help(warning)
                .accessibilityHint(warning)
        } else {
            button
        }
    }

    /// Valor anunciado pelo VoiceOver: o mesmo estado que o ícone do botão já
    /// mostra. Estados terminais vêm do catálogo de manutenção; enquanto roda,
    /// esse catálogo não tem campo próprio, então o valor reaproveita o texto
    /// de processamento que já existe em todos os idiomas.
    private func maintenanceAccessibilityValue(for status: MaintenanceTaskStatus) -> String {
        let strings = FeatureStrings.maintenanceTasks(l10n.language)
        switch status {
        case .idle: return ""
        case .running: return l10n.s.mediaRunning
        case .success: return strings.statusSuccess
        case .failure: return strings.statusFailed
        case .cancelled: return strings.statusCancelled
        case .nothingFreed: return strings.statusNothingFreed
        }
    }

    /// Botão de manutenção de um toque. O ícone mostra o andamento e o resultado da última execução.
    private func maintenanceShortcutButton(_ id: MaintenanceTaskID, title: String) -> some View {
        let status = maintenance.items.first(where: { $0.id == id })?.status ?? .idle
        return Button {
            maintenance.runTask(id)
        } label: {
            HStack(spacing: HexaTheme.Spacing.s) {
                switch status {
                case .running:
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 18)
                case .success:
                    HexaIcons.image("checkmark.circle", size: 13)
                        .font(.hexa(.body))
                        .foregroundStyle(HexaTheme.statusOk)
                        .frame(width: 18)
                case .failure:
                    HexaIcons.image("exclamationmark.triangle", size: 13)
                        .font(.hexa(.body))
                        .foregroundStyle(HexaTheme.statusDanger)
                        .frame(width: 18)
                case .idle, .cancelled, .nothingFreed:
                    HexaIcons.image(id.symbolName, size: 13)
                        .font(.hexa(.body))
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .frame(width: 18)
                }
                Text(title)
                    .font(.hexa(.body))
                    .foregroundStyle(HexaTheme.fgPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, HexaTheme.Spacing.m)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(HexaTheme.surfaceInset, in: RoundedRectangle(cornerRadius: HexaTheme.Radius.control))
            .overlay {
                RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                    .strokeBorder(HexaTheme.borderHairline, lineWidth: HexaTheme.hairline)
            }
            .overlay {
                if focusedMaintenance == id {
                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                        .strokeBorder(HexaTheme.focusRing, lineWidth: 2)
                        .padding(1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($focusedMaintenance, equals: id)
        .disabled(maintenance.isRunning)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityValue(maintenanceAccessibilityValue(for: status))
    }

    // MARK: - Brightness

    /// Telas ativas que suportam ajuste de brilho.
    private var adjustableDisplays: [BrightnessDisplay] {
        brightness.displays.filter { $0.isActive && $0.method != nil }
    }

    /// Tela sob a âncora do popover, mapeada para o ID de display do brilho (mesmo mapeamento do `BrightnessService`).
    private var anchorDisplayID: CGDirectDisplayID? {
        guard let screen = PanelInteractionState.shared.anchorScreen else { return nil }
        return (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    /// Tela ativa para controle no atalho rápido. Ordem: a escolhida nesta sessão (só se ainda ativa),
    /// a sob a âncora do popover, a embutida e, por fim, a primeira. A escolha não é persistida.
    private var quickBrightnessDisplay: BrightnessDisplay? {
        let displays = adjustableDisplays
        guard !displays.isEmpty else { return nil }
        if let selectedDisplayID, let found = displays.first(where: { $0.id == selectedDisplayID }) {
            return found
        }
        if let anchorDisplayID, let found = displays.first(where: { $0.id == anchorDisplayID }) {
            return found
        }
        return displays.first(where: \.isBuiltIn) ?? displays.first
    }

    /// O slider depende do controle de brilho estar ligado nos ajustes; sem ele, o card não aparece.
    private var hasQuickBrightness: Bool {
        showQuickBrightness && AppFeature.brightness.isAvailable && brightnessControlEnabled
            && quickBrightnessDisplay != nil
    }

    @ViewBuilder
    private var quickBrightnessCard: some View {
        if hasQuickBrightness, let display = quickBrightnessDisplay {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                if !adjustableDisplays.isEmpty {
                    HStack(alignment: .center, spacing: HexaTheme.Spacing.xs) {
                        ForEach(adjustableDisplays) { item in
                            let isSelected = item.id == display.id
                            Button {
                                selectedDisplayID = item.id
                            } label: {
                                HStack(spacing: HexaTheme.Spacing.xs) {
                                    HexaIcons.image(item.isBuiltIn ? "laptopcomputer" : "display", size: 10)
                                        .foregroundStyle(isSelected ? HexaTheme.fgPrimary : HexaTheme.fgSecondary)
                                    Text(item.name)
                                        .font(.hexa(.label))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .truncationMode(.tail)
                                        .foregroundStyle(isSelected ? HexaTheme.fgPrimary : HexaTheme.fgSecondary)
                                }
                                .padding(.horizontal, HexaTheme.Spacing.s)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(height: HexaTheme.Density.rowCompact)
                                .background(
                                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                                        .fill(isSelected ? HexaTheme.selectionBg : Color.clear)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                                        .strokeBorder(isSelected ? HexaTheme.accentSolid : HexaTheme.borderHairline,
                                                      lineWidth: isSelected ? 1.5 : HexaTheme.hairline)
                                }
                                .overlay {
                                    if focusedDisplayID == item.id {
                                        RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                                            .strokeBorder(HexaTheme.focusRing, lineWidth: 2)
                                            .padding(1)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .focused($focusedDisplayID, equals: item.id)
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel(item.name)
                            .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                HStack(spacing: HexaTheme.Spacing.s) {
                    Slider(value: Binding(get: { display.brightness },
                                          set: { brightness.setBrightness($0, for: display.id,
                                                                         showOSD: brightnessOSDEnabled) }),
                           in: 0...1)
                        .controlSize(.small)
                        .disabled(brightness.isDisplayPending(display.id))
                        .accessibilityLabel(display.name)
                    Text("\(Int((display.brightness * 100).rounded()))%")
                        .font(.hexa(.data))
                        .monospacedDigit()
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .frame(minWidth: 38, alignment: .trailing)
                }
            }
            .padding(HexaTheme.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HexaTheme.surfaceInset, in: RoundedRectangle(cornerRadius: HexaTheme.Radius.control))
            .overlay {
                RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                    .strokeBorder(HexaTheme.borderHairline, lineWidth: HexaTheme.hairline)
            }
            .onAppear { brightness.refresh() }
        }
    }

    private var powerDetail: String {
        guard let power = snapshot.power else { return l10n.s.powerUnavailable }
        if power.isCharging { return l10n.s.powerCharging }
        return power.externalConnected ? l10n.s.powerPluggedIn : l10n.s.powerOnBattery
    }

    /// Raio carregando, tomada conectada sem carregar. Na bateria fica sem ícone (estado normal).
    private var powerStatusIcon: String? {
        guard let power = snapshot.power else { return nil }
        if power.isCharging { return "bolt.fill" }
        return power.externalConnected ? "powerplug" : nil
    }

    private var fanStrings: FanControlFeatureStrings {
        FeatureStrings.fanControl(l10n.language)
    }

    private var fanValue: String {
        let speeds = !snapshot.fanSpeeds.isEmpty ? snapshot.fanSpeeds : fanService.snapshot.fans.map(\.actualRPM)
        guard let first = speeds.first else { return "–" }
        let rpm = speeds.count > 1 ? (speeds.max() ?? first) : first
        return String(format: fanStrings.rpmFormat, Int(rpm.rounded()))
    }

    private var fanDetail: String {
        if fanService.snapshot.isCooling {
            switch fanService.snapshot.configuration?.mode {
            case .manual:
                return fanStrings.manualControl
            case .curve:
                return fanStrings.customCurve
            default:
                return fanStrings.fanAutoShort
            }
        }
        return fanStrings.fanAutoShort
    }

    private func syncNeeds() { SystemMonitor.shared.setMenuPanelNeeds(needs) }
}
