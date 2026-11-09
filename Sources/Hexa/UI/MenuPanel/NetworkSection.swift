// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// The "Network" card: live download/upload speed, a history graph and the
/// totals moved this session.
struct NetworkSection: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var monitor = SystemMonitor.shared
    @ObservedObject private var speed = SpeedTest.shared
    @StateObject private var addresses = NetworkAddressService()
    @Environment(\.notchPresentation) private var notchPresentation
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.featureWorkspacePresentation) private var featureWorkspacePresentation
    var collapsible = true
    @AppStorage(DefaultsKey.monitorGraphNetwork) private var showGraph = true
    @AppStorage(DefaultsKey.monitorInterval) private var monitorInterval = 2
    @AppStorage(DefaultsKey.monitorNetSpeed) private var netSpeed = true
    @AppStorage(DefaultsKey.monitorNetApps) private var netApps = true
    @AppStorage(DefaultsKey.monitorNetTotals) private var netTotals = true
    @AppStorage(DefaultsKey.monitorNetTest) private var netTest = true
    @AppStorage(DefaultsKey.monitorNetAddresses) private var netAddresses = true
    @AppStorage(DefaultsKey.panelNetworkOrder) private var networkOrderRaw = ""
    @State private var draggingBlock: Block?
    @State private var appRows: [ProcessUsage] = []
    @State private var appRowsLoading = false
    @State private var lastAppRefresh = Date.distantPast
    @State private var appRefreshSerial = 0
    @State private var networkMonitoringActive = false
    @State private var networkDemandID = UUID()
    private let appLimit = 6

    var body: some View {
        Group {
            if featureWorkspacePresentation {
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.l) {
                    MonitorHero(kind: .network,
                                graphLegend: "\(l10n.s.networkDownload) / \(l10n.s.networkUpload)",
                                windowText: MonitorHero.windowText(
                                    samples: max(monitor.snapshot.netDownHistory.count, monitor.snapshot.netUpHistory.count),
                                    interval: Defaults.sanitizedMonitorInterval(monitorInterval),
                                    format: MonitorExperienceStrings.localized(l10n.language).graphWindowFormat))
                        .panelCard()
                    HexaCard {
                        cardContent(editing: false)
                    }
                }
            } else {
                PanelSection(.network, title: l10n.s.networkSection, collapsible: collapsible,
                             supportsEditing: true,
                             resetAction: resetPanelDefaults) { editing in
                    cardContent(editing: editing)
                        .panelCard()
                }
            }
        }
        .onAppear {
            if featureWorkspacePresentation || netApps {
                startNetworkMonitoringIfNeeded()
            }
            refreshAppRows(force: true, delay: 0.2)
        }
        .onReceive(NotificationCenter.default.publisher(for: .menuPanelWillShow)) { _ in
            guard !notchPresentation, (featureWorkspacePresentation || netApps) else { return }
            startNetworkMonitoringIfNeeded()
            refreshAppRows(force: true, delay: 0.2)
        }
        .onReceive(FeatureWorkspaceState.shared.$visible) { visible in
            guard featureWorkspacePresentation else { return }
            if visible {
                if netApps {
                    startNetworkMonitoringIfNeeded()
                }
                refreshAppRows(force: true, delay: 0.2)
            } else {
                stopNetworkMonitoringIfNeeded()
            }
        }
        .onReceive(monitor.$snapshot) { _ in
            refreshAppRows(force: false, delay: 0.2)
        }
        .onChange(of: netApps) { _, visible in
            guard !featureWorkspacePresentation else { return }
            if visible {
                startNetworkMonitoringIfNeeded()
                refreshAppRows(force: true, delay: 0.2)
            } else {
                appRefreshSerial &+= 1
                appRows = []
                appRowsLoading = false
                stopNetworkMonitoringIfNeeded()
            }
        }
        .onDisappear {
            SpeedTest.shared.cancel(owner: networkDemandID)
            appRefreshSerial &+= 1
            appRows = []
            appRowsLoading = false
            stopNetworkMonitoringIfNeeded()
        }
    }

    private func cardContent(editing: Bool) -> some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            ForEach(Array(blocks(editing: editing).enumerated()), id: \.element) { index, block in
                if index > 0 { HairlineDivider() }
                PanelReorderableItem(item: block,
                                     isEnabled: editing,
                                     order: blockOrderBinding,
                                     dragging: $draggingBlock) {
                    HStack(alignment: .top, spacing: HexaTheme.Spacing.s) {
                        if editing {
                            PanelDragHandle()
                        }
                        blockContent(block, editing: editing)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private enum Block: String, PanelOrderItem { case speed, apps, totals, addresses, test }

    private var visibleBlocks: [Block] {
        if featureWorkspacePresentation {
            // Speed lives in the hero above the card.
            return [.apps, .totals, .addresses, .test]
        }
        return orderedBlocks.filter(isVisible)
    }

    private func blocks(editing: Bool) -> [Block] {
        editing ? orderedBlocks : visibleBlocks
    }

    private var orderedBlocks: [Block] {
        _ = networkOrderRaw
        return PanelLayout.itemOrder(Block.self, key: DefaultsKey.panelNetworkOrder)
    }

    private var blockOrderBinding: Binding<[Block]> {
        Binding {
            orderedBlocks
        } set: { newValue in
            PanelLayout.setItemOrder(newValue, key: DefaultsKey.panelNetworkOrder)
        }
    }

    private func isVisible(_ block: Block) -> Bool {
        switch block {
        case .speed: return netSpeed
        case .apps: return netApps
        case .totals: return netTotals
        case .addresses: return netAddresses
        case .test: return netTest
        }
    }

    private func resetPanelDefaults() {
        PanelLayout.resetItemOrder(key: DefaultsKey.panelNetworkOrder)
        networkOrderRaw = ""
        netSpeed = true
        netApps = true
        netTotals = true
        netAddresses = true
        netTest = true
    }

    @ViewBuilder
    private func blockContent(_ block: Block, editing: Bool) -> some View {
        switch block {
        case .speed: speedBlock(editing: editing)
        case .apps: appUsageBlock(editing: editing)
        case .totals: totalsRow(editing: editing)
        case .addresses: NetworkAddressBlock(service: addresses, isVisible: $netAddresses, editing: editing)
        case .test: speedTestRow(editing: editing)
        }
    }

    @ViewBuilder
    private func appUsageBlock(editing: Bool) -> some View {
        if !featureWorkspacePresentation && !netApps {
            PanelHiddenItemRow(title: l10n.s.networkApps,
                               systemImage: "list.bullet.rectangle",
                               isVisible: $netApps)
        } else {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                HStack(spacing: HexaTheme.Spacing.xs) {
                    Text(l10n.s.networkApps)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgTertiary)
                    Spacer(minLength: 0)
                    if editing {
                        PanelInlineHideButton(isVisible: $netApps)
                    }
                }
                if appRows.isEmpty {
                    Text(appRowsLoading ? l10n.s.breakdownMeasuring : l10n.s.networkAppsIdle)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgTertiary)
                } else {
                    ForEach(appRows) { row in
                        ProcessUsageRow(row: row,
                                        value: networkValue(row),
                                        iconSize: 14)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func speedBlock(editing: Bool) -> some View {
        if !featureWorkspacePresentation && !netSpeed {
            PanelHiddenItemRow(title: l10n.s.monitorItemNetSpeed,
                               systemImage: "arrow.down",
                               isVisible: $netSpeed)
        } else {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                if editing {
                    HStack {
                        Spacer(minLength: 0)
                        PanelInlineHideButton(isVisible: $netSpeed)
                    }
                }
                HStack(spacing: HexaTheme.Spacing.s) {
                    rateColumn(icon: "arrow.down",
                               label: l10n.s.networkDownload,
                               value: monitor.snapshot.netDownBytesPerSec,
                               color: PanelMetricColor.cyan(for: colorScheme))
                    HairlineDivider(vertical: true).frame(height: 28)
                    rateColumn(icon: "arrow.up",
                               label: l10n.s.networkUpload,
                               value: monitor.snapshot.netUpBytesPerSec,
                               color: PanelMetricColor.green(for: colorScheme))
                }
                if showGraph, monitor.snapshot.netDownHistory.count >= 2 {
                    graph
                }
            }
        }
    }

    private func rateColumn(icon: String, label: String, value: Double?, color: Color) -> some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            HexaIcons.image(icon, size: 13)
                .font(.hexa(.body))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                Text(value.map { MetricFormat.bytesPerSec($0) } ?? l10n.s.networkMeasuring)
                    .font(.hexa(.body))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(label)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Download (filled) and upload (dashed line) share one scale so they compare fairly.
    private var graph: some View {
        let down = monitor.snapshot.netDownHistory
        let up = monitor.snapshot.netUpHistory
        let peak = MetricFormat.graphCeiling(max(down.max() ?? 0, up.max() ?? 0, 1), unitStep: 1024)
        return ZStack {
            Sparkline(values: down, color: PanelMetricColor.cyan(for: colorScheme), maxValue: peak, showsZeroBaseline: true)
            Sparkline(values: up,
                      color: PanelMetricColor.green(for: colorScheme),
                      maxValue: peak,
                      fillOpacity: 0,
                      dashed: true)
        }
        .frame(height: 30)
        .graphCeilingLabel(MetricFormat.bytesPerSec(peak))
    }

    @ViewBuilder
    private func totalsRow(editing: Bool) -> some View {
        if !featureWorkspacePresentation && !netTotals {
            PanelHiddenItemRow(title: l10n.s.monitorItemNetTotals,
                               systemImage: "sum",
                               isVisible: $netTotals)
        } else {
            HexaKeyValueRow(label: l10n.s.networkThisSession,
                            value: monitor.snapshot.netTotalDown.flatMap { down in
                                monitor.snapshot.netTotalUp.map { up in
                                    "↓\(MetricFormat.bytes(down))  ↑\(MetricFormat.bytes(up))"
                                }
                            },
                            trailing: {
                                if editing {
                                    PanelInlineHideButton(isVisible: $netTotals)
                                }
                            })
        }
    }

    /// On-demand internet speed test (latency, download, upload).
    @ViewBuilder
    private func speedTestRow(editing: Bool) -> some View {
        if !featureWorkspacePresentation && !netTest {
            PanelHiddenItemRow(title: l10n.s.monitorItemNetTest,
                               systemImage: "gauge.with.dots.needle.67percent",
                               isVisible: $netTest)
        } else {
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
                            .contentTransition(.numericText())
                    }
                    if editing {
                        PanelInlineHideButton(isVisible: $netTest)
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
        }
    }

    private func mbps(_ value: Double) -> String {
        value >= 100 ? String(format: "%.0f", locale: MetricFormat.locale, value)
                     : String(format: "%.1f", locale: MetricFormat.locale, value)
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

    private func refreshAppRows(force: Bool, delay: TimeInterval = 0) {
        guard featureWorkspacePresentation || netApps else { return }
        if force {
            if let cached = ProcessUsageService.shared.cachedTop(.network, limit: appLimit) {
                appRows = cached
                appRowsLoading = false
            } else {
                appRows = []
                appRowsLoading = true
            }
        }
        guard force || Date().timeIntervalSince(lastAppRefresh) > 2 else { return }
        lastAppRefresh = Date()

        appRefreshSerial &+= 1
        let serial = appRefreshSerial
        let run = {
            guard self.appRefreshSerial == serial, (self.featureWorkspacePresentation || self.netApps) else { return }
            self.appRowsLoading = self.appRows.isEmpty
            DispatchQueue.global(qos: .utility).async {
                let rows = ProcessUsageService.shared.top(.network, limit: appLimit)
                let isWarmingUp = ProcessUsageService.shared.networkMonitoringIsWarmingUp
                DispatchQueue.main.async {
                    guard self.appRefreshSerial == serial, (self.featureWorkspacePresentation || self.netApps) else { return }
                    self.appRowsLoading = rows.isEmpty && isWarmingUp
                    if !rows.isEmpty || self.appRows.isEmpty {
                        self.appRows = rows
                    }
                    if rows.isEmpty && isWarmingUp {
                        self.refreshAppRows(force: true, delay: 1.0)
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

    private func networkValue(_ row: ProcessUsage) -> String {
        let down = row.networkDownBytesPerSec ?? 0
        let up = row.networkUpBytesPerSec ?? 0
        return "↓\(MetricFormat.bytesPerSecCompact(down)) ↑\(MetricFormat.bytesPerSecCompact(up))"
    }
}

/// The local address block. Nothing here leaves the machine.
private struct NetworkAddressBlock: View {
    @ObservedObject var service: NetworkAddressService
    @Binding var isVisible: Bool
    var editing: Bool
    @Environment(\.featureWorkspacePresentation) private var featureWorkspacePresentation
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        if !featureWorkspacePresentation && !isVisible {
            PanelHiddenItemRow(title: l10n.s.networkIPAddresses,
                               systemImage: "network", isVisible: $isVisible)
        } else {
            HStack(alignment: .top, spacing: HexaTheme.Spacing.xs) {
                Text(l10n.s.networkLocalIP)
                    .font(.hexa(.body))
                    .foregroundStyle(HexaTheme.fgTertiary)
                Spacer()
                // Nothing connected: the panel leaves the value out, like the totals block.
                // The workspace names the gap instead.
                if !service.localAddresses.isEmpty {
                    Text(service.localAddresses.joined(separator: "\n"))
                        .font(.hexa(.data))
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .textSelection(.enabled)
                } else if featureWorkspacePresentation {
                    Text(MonitorExperienceStrings.localized(l10n.language).noLocalAddress)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgTertiary)
                }
                if editing { PanelInlineHideButton(isVisible: $isVisible) }
            }
            // The interfaces are read only while this line is on screen: a
            // hidden block or a collapsed card costs nothing per snapshot.
            .onAppear { service.refreshLocalAddresses() }
            .onReceive(SystemMonitor.shared.$snapshot) { _ in service.refreshLocalAddresses() }
            .onDisappear { service.cancel() }
        }
    }
}
