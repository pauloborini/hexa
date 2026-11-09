// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import SwiftUI

enum MetricDetailKind: String, Equatable, Hashable, Identifiable {
    case cpu, gpu, memory, network, disk, battery, power, fan, connectedDevices

    var id: String { rawValue }

    var panelSection: PanelSectionID {
        switch self {
        case .cpu, .gpu, .memory, .connectedDevices:
            return .system
        case .network:
            return .network
        case .disk:
            return .disk
        case .battery, .power:
            return .power
        case .fan:
            return .fanControl
        }
    }

    var symbolName: String {
        switch self {
        case .cpu: return "cpu"
        case .gpu: return "rectangle.connected.to.line.below"
        case .memory: return "memorychip"
        case .network: return "network"
        case .disk: return "internaldrive"
        case .battery: return "battery.100"
        case .power: return "powerplug.fill"
        case .fan: return "fanblades"
        case .connectedDevices: return "cable.connector"
        }
    }

    var monitorNeeds: SystemMonitorPanelNeeds {
        switch self {
        case .cpu:
            return SystemMonitorPanelNeeds(cpu: true, cpuTemperature: true)
        case .gpu:
            return SystemMonitorPanelNeeds(gpu: true, gpuTemperature: true)
        case .memory:
            return SystemMonitorPanelNeeds(memory: true)
        case .network:
            return SystemMonitorPanelNeeds(network: true)
        case .disk:
            return SystemMonitorPanelNeeds(disk: true)
        case .battery:
            if PowerSampler.hasInternalBattery {
                return SystemMonitorPanelNeeds(power: true,
                                               battery: true,
                                               peripheralBattery: true,
                                               batteryTemperature: true)
            }
            return SystemMonitorPanelNeeds(peripheralBattery: true)
        case .power:
            return SystemMonitorPanelNeeds(power: true, peripheralBattery: true)
        case .fan:
            return SystemMonitorPanelNeeds(fanSpeed: true)
        case .connectedDevices:
            return SystemMonitorPanelNeeds(connectedDevices: true)
        }
    }

    func title(_ s: Strings) -> String {
        switch self {
        case .cpu: return s.cpuLabel
        case .gpu: return s.gpuLabel
        case .memory: return s.memorySection
        case .network: return s.networkSection
        case .disk: return s.diskSection
        case .battery: return s.batteryLabel
        case .power: return s.powerSection
        case .fan: return FeatureStrings.fanControl(L10n.shared.language).menuBarTitle
        case .connectedDevices: return FeatureStrings.connectedDevices(L10n.shared.language).title
        }
    }

    var processKind: BreakdownKind? {
        switch self {
        case .cpu: return .cpu
        case .gpu: return .gpu
        case .memory: return .memory
        case .power: return .energy
        case .network: return .network
        case .disk, .battery, .fan, .connectedDevices: return nil
        }
    }
}

extension MenuBarMetric {
    var detailKind: MetricDetailKind {
        switch self {
        case .cpu, .cpuTemperature:
            return .cpu
        case .gpu, .gpuTemperature:
            return .gpu
        case .memory:
            return .memory
        case .network:
            return .network
        case .diskUsage, .diskActivity:
            return .disk
        case .battery, .batteryTemperature, .peripheralBattery:
            return .battery
        case .batteryTime, .power:
            return .power
        case .fanSpeed:
            return .fan
        case .connectedDevices:
            return .connectedDevices
        }
    }
}

struct ActivityMonitorButton: View {
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        HexaIconButton(icon: "arrow.up.forward.app",
                       label: l10n.s.monitorOpenActivityMonitor,
                       variant: .small) {
            let fallback = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
            let url = NSWorkspace.shared
                .urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") ?? fallback
            NSWorkspace.shared.open(url)
        }
        .help(l10n.s.monitorOpenActivityMonitor)
    }
}

struct MetricDetailView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var monitor = SystemMonitor.shared
    @ObservedObject private var speed = SpeedTest.shared
    @Environment(\.notchPresentation) private var notchPresentation
    @Environment(\.featureWorkspacePresentation) private var featureWorkspacePresentation
    @AppStorage(DefaultsKey.temperatureUnit) private var temperatureUnit = TemperatureUnit.celsius.rawValue
    @AppStorage(DefaultsKey.monitorInterval) private var monitorInterval = 2
    let kind: MetricDetailKind
    @State private var processRows: [ProcessUsage] = []
    @State private var processRowsLoading = false
    @State private var lastProcessRefresh = Date.distantPast
    @State private var refreshSerial = 0
    @State private var networkMonitoringActive = false
    @State private var networkDemandID = UUID()
    private let processLimit = 15

    var body: some View {
        VStack(alignment: .leading,
               spacing: featureWorkspacePresentation ? HexaTheme.Spacing.l : HexaTheme.Spacing.s) {
            MonitorHero(kind: kind,
                        context: heroContext,
                        graphLegend: heroLegend,
                        windowText: heroWindowText)
                .panelCard()
            detailCard
            if kind == .network {
                speedTestCard
            }
            if kind == .fan, AppFeature.fanControl.isAvailable {
                fanControlCard
            }
            if kind.processKind != nil {
                processCard
            }
        }
        .onAppear {
            if kind == .network {
                startNetworkMonitoringIfNeeded()
            }
            refreshProcessRows(force: true, delay: 0.2)
        }
        .onChange(of: kind) { oldKind, newKind in
            if oldKind == .network, newKind != .network {
                stopNetworkMonitoringIfNeeded()
            } else if oldKind != .network, newKind == .network {
                startNetworkMonitoringIfNeeded()
            }
            refreshProcessRows(force: true, delay: 0.2)
        }
        .onReceive(NotificationCenter.default.publisher(for: .menuPanelWillShow)) { _ in
            guard !notchPresentation, kind == .network else { return }
            startNetworkMonitoringIfNeeded()
            refreshProcessRows(force: true, delay: 0.2)
        }
        .onReceive(FeatureWorkspaceState.shared.$visible) { visible in
            guard featureWorkspacePresentation, kind == .network else { return }
            if visible {
                startNetworkMonitoringIfNeeded()
                refreshProcessRows(force: true, delay: 0.2)
            } else {
                stopNetworkMonitoringIfNeeded()
            }
        }
        .onReceive(monitor.$snapshot) { _ in refreshProcessRows(force: false) }
        .onDisappear {
            SpeedTest.shared.cancel(owner: networkDemandID)
            refreshSerial &+= 1
            processRows = []
            processRowsLoading = false
            stopNetworkMonitoringIfNeeded()
        }
    }

    private var heroContext: String? {
        guard kind == .disk else { return nil }
        return primaryDisk(from: monitor.snapshot.disk)?.name
    }

    private var heroLegend: String? {
        switch kind {
        case .network:
            return "\(l10n.s.networkDownload) / \(l10n.s.networkUpload)"
        case .disk:
            return "\(l10n.s.diskRead) / \(l10n.s.diskWrite)"
        default:
            return nil
        }
    }

    private var heroWindowText: String? {
        let snapshot = monitor.snapshot
        let samples: Int
        switch kind {
        case .cpu:
            samples = snapshot.cpuHistory.count
        case .gpu:
            samples = snapshot.gpuHistory.count
        case .memory:
            samples = MonitorMemoryMetric.current.history(in: snapshot).count
        case .network:
            samples = snapshot.netDownHistory.count
        case .disk:
            samples = snapshot.diskReadHistory.count
        case .battery:
            guard PowerSampler.hasInternalBattery else { return nil }
            samples = snapshot.batteryHistory.count
        case .power:
            samples = snapshot.systemPowerHistory.count
        case .fan, .connectedDevices:
            return nil
        }
        return MonitorHero.windowText(
            samples: samples,
            interval: Defaults.sanitizedMonitorInterval(monitorInterval),
            format: MonitorExperienceStrings.localized(l10n.language).graphWindowFormat)
    }

    @ViewBuilder
    private var detailCard: some View {
        // Snapshot rows read "unavailable", "no devices" or "-" until the first publish.
        if !monitor.hasReading, kind != .cpu, kind != .gpu {
            HexaBusyState(variant: .compact, message: l10n.s.loadingMessage)
                .panelCard()
        } else if !detailRows.isEmpty {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                ForEach(detailRows) { row in
                    detailRow(row)
                }
            }
            .panelCard()
        }
    }

    private var speedTestCard: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            HStack(spacing: HexaTheme.Spacing.s) {
                if speed.isRunning {
                    ProgressView().controlSize(.small)
                    Text(l10n.s.speedTestTesting)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgSecondary)
                } else {
                    Button {
                        speed.start(owner: networkDemandID)
                    } label: {
                        Label(speed.downloadMbps == nil ? l10n.s.speedTestRun : l10n.s.speedTestAgain,
                              hexaIcon: "gauge.with.dots.needle.67percent")
                            .font(.hexa(.label))
                    }
                    .buttonStyle(HexaActionButtonStyle())
                    .controlSize(.small)
                }
                Spacer()
                if let down = speed.downloadMbps, let up = speed.uploadMbps {
                    Text("↓\(mbps(down)) ↑\(mbps(up)) Mbps")
                        .font(.hexa(.data))
                }
            }
            if case .failed = speed.phase {
                Text(l10n.s.speedTestFailed)
                    .font(.hexa(.body))
                    .foregroundStyle(HexaTheme.statusDanger)
            } else if let latency = speed.latencyMs {
                Text("\(l10n.s.speedTestLatency): \(Int(latency.rounded())) ms")
                    .font(.hexa(.data))
                    .foregroundStyle(HexaTheme.fgTertiary)
            }
        }
        .panelCard()
    }

    private var fanControlCard: some View {
        let strings = FeatureStrings.fanControl(l10n.language)
        return VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            HStack(spacing: HexaTheme.Spacing.s) {
                HexaIcons.image("fanblades.fill", size: 14)
                    .foregroundStyle(HexaTheme.fgSecondary)
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                    Text(strings.title)
                        .font(.hexa(.body))
                        .foregroundStyle(HexaTheme.fgPrimary)
                    Text(strings.hubDescription)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgSecondary)
                }
                Spacer(minLength: 0)
                Button {
                    if FeatureWorkspaceState.shared.visible {
                        FeatureWorkspaceWindow.shared.show(.fanControl)
                    } else {
                        MenuPanelFocus.shared.focus(.fanControl)
                    }
                } label: {
                    Text(strings.title)
                        .font(.hexa(.label))
                }
                .buttonStyle(HexaActionButtonStyle())
                .controlSize(.small)
            }
        }
        .panelCard()
    }

    private var processCard: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            HStack(spacing: HexaTheme.Spacing.xs) {
                Text(processTitle)
                    .font(.hexa(.body))
                    .foregroundStyle(HexaTheme.fgTertiary)
                Spacer(minLength: 0)
                ActivityMonitorButton()
            }
            if processRows.isEmpty {
                Text(processRowsLoading ? l10n.s.breakdownMeasuring : emptyProcessText)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgTertiary)
            } else {
                ForEach(processRows) { row in
                    ProcessUsageRow(row: row, value: processValue(row))
                }
            }
        }
        .panelCard()
    }

    private var detailRows: [MetricDetailRow] {
        let snapshot = monitor.snapshot
        switch kind {
        case .cpu:
            return [
                row(l10n.s.systemUptime, SystemSection.uptimeString()),
            ]
        case .gpu:
            return []
        case .memory:
            var rows = [
                row(l10n.s.memoryPressure, pressureText(snapshot.memoryPressure), showsPressure: true),
            ]
            if let compressed = snapshot.memoryCompressed {
                rows.append(row(l10n.s.memoryCompressed, formatMemory(compressed)))
            }
            if let cached = snapshot.memoryCached {
                rows.append(row(l10n.s.memoryCachedFiles, formatMemory(cached)))
            }
            if let swapUsed = snapshot.memorySwapUsed {
                rows.append(row(l10n.s.memorySwapUsed, formatMemory(swapUsed)))
            }
            return rows
        case .network:
            return [
                row(l10n.s.networkThisSession, sessionNetworkText(snapshot)),
            ]
        case .disk:
            guard let disk = primaryDisk(from: snapshot.disk) else { return [] }
            var rows: [MetricDetailRow] = [
                row(MonitorExperienceStrings.localized(l10n.language).diskCapacity,
                    "\(MetricFormat.diskBytes(disk.usedBytes)) / \(MetricFormat.diskBytes(disk.totalBytes))"),
            ]
            if let purgeable = disk.purgeableBytes, purgeable >= 500_000_000 {
                rows.append(row(l10n.s.diskPurgeable, MetricFormat.diskBytes(purgeable)))
            }
            return rows
        case .battery:
            let power = snapshot.power
            var rows: [MetricDetailRow] = []
            if PowerSampler.hasInternalBattery {
                rows.append(contentsOf: [
                    row(l10n.s.powerBattery, batteryFlowText(power)),
                    row(l10n.s.temperatures, snapshot.batteryTemperature.map(formatTemperature) ?? l10n.s.monitorUnavailable),
                    row(l10n.s.powerHealth, power?.healthPercent.map { "\(Int($0.rounded()))%" } ?? "-"),
                    row(l10n.s.powerCycles, power?.cycleCount.map(String.init) ?? "-"),
                ])
            }
            if snapshot.peripheralBatteries.isEmpty {
                rows.append(row(l10n.s.monitorShowPeripheralBattery,
                                l10n.s.peripheralBatteryNoDevices,
                                wrapsValue: true))
            } else {
                for device in PeripheralBatterySupport.sorted(snapshot.peripheralBatteries).prefix(5) {
                    rows.append(row(device.name, "\(device.percent)%"))
                }
            }
            return rows
        case .power:
            let power = snapshot.power
            var rows = [
                row(l10n.s.powerAdapter, adapterText(power)),
            ]
            if PowerSampler.hasInternalBattery {
                rows.append(row(l10n.s.powerBattery, batteryFlowText(power)))
                if let power, power.hasBattery,
                   !power.externalConnected, !power.isCharging {
                    let strings = FeatureStrings.batteryTime(l10n.language)
                    rows.append(row(strings.title,
                                    power.timeRemainingSeconds.flatMap(BatteryTimeSupport.formatted)
                                        ?? strings.calculating))
                }
            }
            return rows
        case .fan:
            let strings = FeatureStrings.fanControl(l10n.language)
            guard !snapshot.fanSpeeds.isEmpty else {
                return [row(strings.menuBarTitle, l10n.s.monitorUnavailable)]
            }
            return snapshot.fanSpeeds.enumerated().map { index, rpm in
                row(String(format: strings.fanNameFormat, index + 1),
                    String(format: strings.rpmFormat, Int(rpm.rounded())))
            }
        case .connectedDevices:
            let strings = FeatureStrings.connectedDevices(l10n.language)
            guard !snapshot.connectedDevices.isEmpty else {
                return [row(strings.noDevices, "")]
            }
            return snapshot.connectedDevices.map { device in
                row(id: device.id,
                    device.name.isEmpty ? strings.unnamedDevice : device.name,
                    device.vendorName ?? "",
                    symbolName: "cable.connector")
            }
        }
    }

    private var emptyProcessText: String {
        switch kind {
        case .power: return l10n.s.energyAppsIdle
        case .network: return l10n.s.networkAppsIdle
        default: return MonitorExperienceStrings.localized(l10n.language).noApps
        }
    }

    private var processTitle: String {
        switch kind {
        case .power: return l10n.s.energyAppsTitle
        case .network: return l10n.s.networkApps
        default: return MonitorExperienceStrings.localized(l10n.language).usageByApp
        }
    }

    @ViewBuilder
    private func detailRow(_ row: MetricDetailRow) -> some View {
        if row.wrapsValue {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                Text(row.title)
                    .font(.hexa(.body))
                    .foregroundStyle(HexaTheme.fgSecondary)
                Text(row.value)
                    .font(.hexa(.body))
                    .foregroundStyle(HexaTheme.fgPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            HStack(spacing: HexaTheme.Spacing.s) {
                if let symbolName = row.symbolName {
                    HexaIcons.image(symbolName, size: 12)
                        .font(.hexa(.body))
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .frame(width: 14)
                }
                Text(row.title)
                    .font(.hexa(.body))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if row.showsPressure, case .memory = kind {
                    PressureIndicator(pressure: monitor.snapshot.memoryPressure)
                } else {
                    Text(row.value)
                        .font(.hexa(.data))
                        .foregroundStyle(HexaTheme.fgPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }

    private func row(id: String? = nil,
                     _ title: String,
                     _ value: String,
                     showsPressure: Bool = false,
                     wrapsValue: Bool = false,
                     symbolName: String? = nil) -> MetricDetailRow {
        MetricDetailRow(id: id ?? title,
                        title: title,
                        value: value,
                        showsPressure: showsPressure,
                        wrapsValue: wrapsValue,
                        symbolName: symbolName)
    }

    private func refreshProcessRows(force: Bool, delay: TimeInterval = 0) {
        guard let processKind = kind.processKind else { return }
        if force {
            if let cached = ProcessUsageService.shared.cachedTop(processKind, limit: processLimit) {
                processRows = cached
                processRowsLoading = false
            } else {
                processRows = []
                processRowsLoading = true
            }
        }
        guard force || Date().timeIntervalSince(lastProcessRefresh) >= processKind.processRefreshInterval(
            configuredMonitorInterval: monitorInterval
        ) * 0.8
        else { return }

        refreshSerial &+= 1
        let serial = refreshSerial
        let sampleInterval = percentageSampleInterval
        let cpuPercentage = monitor.snapshot.cpuUsage.map { $0 * 100 }
        let gpuPercentage = monitor.snapshot.gpuUsage.map { $0 * 100 }
        let run = {
            guard self.refreshSerial == serial,
                  self.kind.processKind == processKind else { return }
            self.lastProcessRefresh = Date()
            self.processRowsLoading = self.processRows.isEmpty
            DispatchQueue.global(qos: .utility).async {
                let rows = ProcessUsageService.shared.top(processKind,
                                                          limit: processLimit,
                                                          sampleInterval: sampleInterval,
                                                          cpuPercentage: cpuPercentage,
                                                          gpuPercentage: gpuPercentage)
                let isWarmingUp = processKind == .network && ProcessUsageService.shared.networkMonitoringIsWarmingUp
                DispatchQueue.main.async {
                    guard self.refreshSerial == serial,
                          self.kind.processKind == processKind else { return }
                    self.processRowsLoading = rows.isEmpty && isWarmingUp
                    if !rows.isEmpty || self.processRows.isEmpty {
                        self.processRows = rows
                    }
                    if rows.isEmpty && isWarmingUp {
                        self.refreshProcessRows(force: true, delay: 1.0)
                    }
                }
            }
        }
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: run)
        } else {
            run()
        }
    }

    private var percentageSampleInterval: TimeInterval {
        TimeInterval(Defaults.sanitizedMonitorInterval(monitorInterval))
    }

    private func startNetworkMonitoringIfNeeded() {
        networkMonitoringActive = true
        ProcessUsageService.shared.startNetworkMonitoring(owner: networkDemandID, menuPanel: !notchPresentation && !featureWorkspacePresentation)
    }

    private func stopNetworkMonitoringIfNeeded() {
        guard networkMonitoringActive else { return }
        networkMonitoringActive = false
        ProcessUsageService.shared.stopNetworkMonitoring(owner: networkDemandID)
    }

    private func processValue(_ row: ProcessUsage) -> String {
        switch kind {
        case .memory:
            return formatMemory(UInt64(row.value))
        case .network:
            let down = row.networkDownBytesPerSec ?? 0
            let up = row.networkUpBytesPerSec ?? 0
            return "↓\(MetricFormat.bytesPerSecCompact(down)) ↑\(MetricFormat.bytesPerSecCompact(up))"
        default:
            return String(format: "%.1f%%", locale: MetricFormat.locale, row.value)
        }
    }

    private func primaryDisk(from reading: DiskReading?) -> DiskDeviceReading? {
        guard let devices = reading?.devices, !devices.isEmpty else { return nil }
        return devices.first(where: { $0.isInternal }) ?? devices.first
    }

    private func formatTemperature(_ celsius: Double) -> String {
        MetricFormat.temperature(celsius, unit: displayTemperatureUnit)
    }

    private var displayTemperatureUnit: TemperatureUnit {
        TemperatureUnit(rawValue: temperatureUnit) ?? .celsius
    }

    private func formatMemory(_ bytes: UInt64) -> String {
        Self.memoryFormatter.string(fromByteCount: Int64(bytes))
    }

    private func pressureText(_ pressure: MemoryPressure) -> String {
        switch pressure {
        case .normal: return l10n.s.pressureNormal
        case .warning: return l10n.s.pressureWarning
        case .critical: return l10n.s.pressureCritical
        case .unknown: return "-"
        }
    }

    private func sessionNetworkText(_ snapshot: SystemSnapshot) -> String {
        guard let down = snapshot.netTotalDown, let up = snapshot.netTotalUp else { return "-" }
        return "↓\(MetricFormat.bytes(down))  ↑\(MetricFormat.bytes(up))"
    }

    private func adapterText(_ power: PowerReading?) -> String {
        guard let power else { return "-" }
        if power.externalConnected, let adapter = power.adapterWatts {
            return MetricFormat.watts(adapter)
        }
        if power.externalConnected { return l10n.s.powerPluggedIn }
        return "-"
    }

    private func batteryFlowText(_ power: PowerReading?) -> String {
        guard let flow = power?.batteryWatts else { return "-" }
        let label = flow >= 0 ? l10n.s.powerCharging : l10n.s.powerOnBattery
        return "\(MetricFormat.watts(abs(flow))) · \(label)"
    }

    private func mbps(_ value: Double) -> String {
        value >= 100 ? String(format: "%.0f", locale: MetricFormat.locale, value)
                     : String(format: "%.1f", locale: MetricFormat.locale, value)
    }

    private static let memoryFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter
    }()
}

private struct MetricDetailRow: Identifiable {
    let id: String
    let title: String
    let value: String
    var showsPressure = false
    var wrapsValue = false
    var symbolName: String?
}
