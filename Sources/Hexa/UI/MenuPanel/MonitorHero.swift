// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Header card shared by the Monitor tabs: kind icon, optional context, primary
/// and secondary readings, and the history graph with its legend and window.
/// The caller wraps it in `panelCard()`; the hero adds no surface of its own.
struct MonitorHero: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var monitor = SystemMonitor.shared
    @AppStorage(DefaultsKey.temperatureUnit) private var temperatureUnit = TemperatureUnit.celsius.rawValue
    @Environment(\.colorScheme) private var colorScheme

    let kind: MetricDetailKind
    var disk: DiskDeviceReading? = nil
    var context: String? = nil
    var graphLegend: String? = nil
    var windowText: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            HStack(alignment: .firstTextBaseline, spacing: HexaTheme.Spacing.s) {
                HexaIcons.image(kind.symbolName, size: 15)
                    .font(.hexa(.heading))
                    .foregroundStyle(summaryColor)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                    if let context {
                        Text(context)
                            .font(.hexa(.label))
                            .foregroundStyle(HexaTheme.fgSecondary)
                    }
                    Text(primaryValue)
                        .font(.hexa(.display(28)))
                        .monospacedDigit()
                    Text(secondaryValue)
                        .font(.hexa(.body))
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            graphSection
        }
    }

    // MARK: - Window

    /// "Last 4 min" style text for the graph, derived from samples and interval.
    static func windowText(samples: Int, interval: Int, format: String) -> String? {
        guard samples >= 2, interval > 0 else { return nil }
        let seconds = samples * interval
        let value: String
        if seconds < 60 {
            value = String(format: "%d s", seconds)
        } else {
            let minutes = Int((Double(seconds) / 60).rounded())
            value = String(format: "%d min", minutes)
        }
        return String(format: format, value)
    }

    // MARK: - Graph

    /// The graph and its legend row form one accessible element when a graph
    /// exists, so the legend and window are announced once, in the graph label.
    @ViewBuilder
    private var graphSection: some View {
        if let graph = graphSpec {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                graphCanvas(graph)
                legendRow
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityGraphLabel(ceiling: graph.ceiling))
        } else {
            legendRow
        }
    }

    private func graphCanvas(_ graph: MonitorGraphSpec) -> some View {
        ZStack {
            Sparkline(values: graph.solid,
                      color: graph.solidColor,
                      maxValue: graph.maxValue,
                      showsZeroBaseline: true)
            if let dashed = graph.dashed {
                Sparkline(values: dashed,
                          color: graph.dashedColor,
                          maxValue: graph.maxValue,
                          fillOpacity: 0,
                          dashed: true)
            }
        }
        .frame(height: 38)
        .graphCeilingLabel(graph.ceiling)
    }

    @ViewBuilder
    private var legendRow: some View {
        if graphLegend != nil || windowText != nil {
            HStack(spacing: HexaTheme.Spacing.s) {
                if let graphLegend {
                    Text(graphLegend)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgTertiary)
                }
                Spacer(minLength: 0)
                if let windowText {
                    Text(windowText)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgTertiary)
                }
            }
        }
    }

    private func accessibilityGraphLabel(ceiling: String) -> String {
        [kind.title(l10n.s), windowText, graphLegend, ceiling]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var graphSpec: MonitorGraphSpec? {
        let snapshot = monitor.snapshot
        switch kind {
        case .cpu:
            return singleGraph(snapshot.cpuHistory)
        case .gpu:
            return singleGraph(snapshot.gpuHistory)
        case .memory:
            return singleGraph(MonitorMemoryMetric.current.history(in: snapshot))
        case .battery:
            guard PowerSampler.hasInternalBattery else { return nil }
            return singleGraph(snapshot.batteryHistory)
        case .power:
            let peak = MetricFormat.graphCeiling(snapshot.systemPowerHistory.max() ?? 0, unitStep: 1000)
            return singleGraph(snapshot.systemPowerHistory,
                               maxValue: peak,
                               ceiling: MetricFormat.watts(peak))
        case .network:
            let down = snapshot.netDownHistory
            let up = snapshot.netUpHistory
            guard down.count >= 2 || up.count >= 2 else { return nil }
            let peak = MetricFormat.graphCeiling(max(down.max() ?? 0, up.max() ?? 0, 1), unitStep: 1024)
            return MonitorGraphSpec(solid: down,
                                    solidColor: PanelMetricColor.cyan(for: colorScheme),
                                    dashed: up,
                                    dashedColor: PanelMetricColor.green(for: colorScheme),
                                    maxValue: peak,
                                    ceiling: MetricFormat.bytesPerSec(peak))
        case .disk:
            let read = snapshot.diskReadHistory
            let write = snapshot.diskWriteHistory
            guard read.count >= 2 || write.count >= 2 else { return nil }
            let peak = MetricFormat.graphCeiling(max(read.max() ?? 0, write.max() ?? 0, 1), unitStep: 1024)
            return MonitorGraphSpec(solid: read,
                                    solidColor: summaryColor,
                                    dashed: write,
                                    dashedColor: PanelMetricColor.pink(for: colorScheme),
                                    maxValue: peak,
                                    ceiling: MetricFormat.bytesPerSec(peak))
        case .fan, .connectedDevices:
            return nil
        }
    }

    private func singleGraph(_ values: [Double],
                             maxValue: Double = 1,
                             ceiling: String = MetricFormat.percent(1)) -> MonitorGraphSpec? {
        guard values.count >= 2 else { return nil }
        return MonitorGraphSpec(solid: values,
                                solidColor: summaryColor,
                                maxValue: maxValue,
                                ceiling: ceiling)
    }

    // MARK: - Readings

    private var primaryValue: String {
        let s = l10n.s
        let snapshot = monitor.snapshot
        switch kind {
        case .cpu:
            return snapshot.cpuUsage.map(MetricFormat.percent) ?? s.breakdownMeasuring
        case .gpu:
            return snapshot.gpuUsage.map(MetricFormat.percent) ?? s.breakdownMeasuring
        case .memory:
            guard let used = MonitorMemoryMetric.current.value(in: snapshot),
                  let total = snapshot.memoryTotal, total > 0 else { return s.breakdownMeasuring }
            return MetricFormat.percent(Double(used) / Double(total))
        case .network:
            return snapshot.netDownBytesPerSec.map(MetricFormat.bytesPerSecCompact) ?? s.breakdownMeasuring
        case .disk:
            guard let disk = resolvedDisk else { return monitor.hasReading ? s.diskNoDisks : s.breakdownMeasuring }
            return MetricFormat.percent(disk.usedFraction)
        case .battery:
            if PowerSampler.hasInternalBattery {
                return snapshot.power?.chargePercent.map { "\($0)%" } ?? s.breakdownMeasuring
            }
            return PeripheralBatterySupport.sorted(snapshot.peripheralBatteries).first
                .map { "\($0.percent)%" } ?? s.breakdownMeasuring
        case .power:
            guard let power = snapshot.power else { return s.breakdownMeasuring }
            return power.systemWatts.map(MetricFormat.wattsCompact) ?? s.powerUnavailable
        case .fan:
            guard let rpm = snapshot.fanSpeeds.first else {
                return monitor.hasReading ? s.monitorUnavailable : s.breakdownMeasuring
            }
            return String(format: FeatureStrings.fanControl(l10n.language).rpmFormat, Int(rpm.rounded()))
        case .connectedDevices:
            guard monitor.hasReading else { return s.breakdownMeasuring }
            return "\(snapshot.connectedDevices.count)"
        }
    }

    private var secondaryValue: String {
        let s = l10n.s
        let snapshot = monitor.snapshot
        switch kind {
        case .cpu:
            return thermalText(temperature: snapshot.cpuTemperature, usage: snapshot.cpuUsage)
        case .gpu:
            return thermalText(temperature: snapshot.gpuTemperature, usage: snapshot.gpuUsage)
        case .memory:
            guard let used = MonitorMemoryMetric.current.value(in: snapshot),
                  let total = snapshot.memoryTotal else { return s.breakdownMeasuring }
            return "\(formatMemory(used)) / \(formatMemory(total))"
        case .network:
            guard let up = snapshot.netUpBytesPerSec else { return s.breakdownMeasuring }
            return "\(s.networkUpload) \(MetricFormat.bytesPerSecCompact(up))"
        case .disk:
            guard let disk = resolvedDisk else { return monitor.hasReading ? s.diskNoDisks : s.breakdownMeasuring }
            return "\(MetricFormat.diskBytes(disk.freeBytes)) \(s.diskAvailable)"
        case .battery:
            if PowerSampler.hasInternalBattery {
                guard monitor.hasReading else { return s.breakdownMeasuring }
                return powerStateText(BatteryPowerSupport.state(
                    isCharging: snapshot.power?.isCharging ?? false,
                    externalConnected: snapshot.power?.externalConnected ?? false,
                    hasBattery: true))
            }
            return PeripheralBatterySupport.sorted(snapshot.peripheralBatteries).first?.name
                ?? s.peripheralBatteryNoDevices
        case .power:
            return powerSubtitle(snapshot.power)
        case .fan:
            let strings = FeatureStrings.fanControl(l10n.language)
            return snapshot.fanSpeeds.isEmpty
                ? strings.menuBarTitle
                : String(format: strings.fanNameFormat, 1)
        case .connectedDevices:
            return FeatureStrings.connectedDevices(l10n.language).formattedCount(snapshot.connectedDevices.count)
        }
    }

    private func thermalText(temperature: Double?, usage: Double?) -> String {
        if let temperature { return formatTemperature(temperature) }
        return usage == nil ? l10n.s.breakdownMeasuring : l10n.s.monitorUnavailable
    }

    /// The disk the hero reports: the one supplied by the caller, else the
    /// internal volume first, else the first mounted volume.
    private var resolvedDisk: DiskDeviceReading? {
        if let disk { return disk }
        let devices = monitor.snapshot.disk?.devices ?? []
        return devices.first(where: { $0.isInternal }) ?? devices.first
    }

    private var summaryColor: Color {
        switch kind {
        case .cpu, .gpu, .network, .fan, .connectedDevices:
            return PanelMetricColor.cyan(for: colorScheme)
        case .memory:
            return PanelMetricColor.mint(for: colorScheme)
        case .disk:
            return PanelMetricColor.yellow(for: colorScheme)
        case .battery:
            return PanelMetricColor.green(for: colorScheme)
        case .power:
            return PanelMetricColor.orange(for: colorScheme)
        }
    }

    private func formatTemperature(_ celsius: Double) -> String {
        MetricFormat.temperature(celsius, unit: TemperatureUnit(rawValue: temperatureUnit) ?? .celsius)
    }

    private func formatMemory(_ bytes: UInt64) -> String {
        Self.memoryFormatter.string(fromByteCount: Int64(bytes))
    }

    private func powerSubtitle(_ power: PowerReading?) -> String {
        let s = l10n.s
        guard let power else { return monitor.hasReading ? s.powerUnavailable : s.breakdownMeasuring }
        if power.externalConnected { return s.powerPluggedIn }
        if power.hasBattery { return s.powerOnBattery }
        return s.powerUnavailable
    }

    private func powerStateText(_ state: BatteryPowerSupport.State) -> String {
        let s = l10n.s
        switch state {
        case .charging: return s.powerCharging
        case .externalPower: return s.powerPluggedIn
        case .onBattery: return s.powerOnBattery
        case .unavailable: return s.powerUnavailable
        }
    }

    private static let memoryFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter
    }()
}

/// Series and scale of one history graph. `dashed` is the secondary series
/// (upload, write) drawn over the same scale without a fill.
private struct MonitorGraphSpec {
    let solid: [Double]
    let solidColor: Color
    var dashed: [Double]? = nil
    var dashedColor: Color = .clear
    let maxValue: Double
    let ceiling: String
}
