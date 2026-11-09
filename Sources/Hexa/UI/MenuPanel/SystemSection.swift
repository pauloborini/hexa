// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Which per-app breakdown is expanded in the System section.
enum BreakdownKind: Hashable {
    case cpu, gpu, memory, energy, network

    func processRefreshInterval(configuredMonitorInterval: Int) -> TimeInterval {
        switch self {
        case .cpu, .gpu, .energy:
            return TimeInterval(Defaults.sanitizedMonitorInterval(configuredMonitorInterval))
        case .memory, .network:
            return 4
        }
    }
}

/// The "System" section of the panel: component temperatures, hardware usage
/// and memory pressure, only the readings that matter, presented cleanly.
/// Tapping CPU, GPU or Memory expands the top consumers of that resource.
struct SystemSection: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var monitor = SystemMonitor.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var collapsible = true
    @FocusState private var focusedBreakdown: BreakdownKind?
    @State private var expanded: BreakdownKind?
    @State private var breakdownRows: [ProcessUsage] = []
    @State private var breakdownIsLoading = false
    @State private var lastBreakdownRefresh = Date.distantPast
    private let breakdownLimit = 15
    @AppStorage(DefaultsKey.monitorInterval) private var monitorInterval = 2
    @AppStorage(DefaultsKey.monitorGraphCPU) private var graphCPU = true
    @AppStorage(DefaultsKey.monitorGraphGPU) private var graphGPU = true
    @AppStorage(DefaultsKey.monitorGraphMemory) private var graphMemory = true
    @AppStorage(DefaultsKey.temperatureUnit) private var temperatureUnit = TemperatureUnit.celsius.rawValue
    @AppStorage(DefaultsKey.monitorSysTemps) private var sysTemps = true
    @AppStorage(DefaultsKey.monitorSysCPU) private var sysCPU = true
    @AppStorage(DefaultsKey.monitorSysGPU) private var sysGPU = true
    @AppStorage(DefaultsKey.monitorSysMemory) private var sysMemory = true
    @AppStorage(DefaultsKey.monitorSysUptime) private var sysUptime = true
    @AppStorage(DefaultsKey.monitorSysFans) private var sysFans = true
    @AppStorage(DefaultsKey.panelSystemOrder) private var systemOrderRaw = ""
    @State private var draggingBlock: Block?

    var body: some View {
        PanelSection(.system, title: l10n.s.systemSection, collapsible: collapsible,
                     supportsEditing: true,
                     resetAction: resetPanelDefaults) { editing in
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                let currentBlocks = awaitingFirstReading ? [] : blocks(editing: editing)
                if awaitingFirstReading {
                    HexaBusyState(variant: .compact, message: l10n.s.loadingMessage)
                }
                ForEach(Array(currentBlocks.enumerated()), id: \.element) { index, block in
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
            .panelCard()
        }
        .onReceive(monitor.$snapshot) { _ in
            guard let kind = expanded,
                  Date().timeIntervalSince(lastBreakdownRefresh) >= kind.processRefreshInterval(
                      configuredMonitorInterval: monitorInterval
                  ) * 0.8
            else { return }
            refreshBreakdown()
        }
        .onDisappear {
            expanded = nil
            breakdownRows = []
            breakdownIsLoading = false
        }
    }

    /// Card subsections, in order, filtered by the per-item toggles (and whether a
    /// battery exists). Drives divider interleaving so only rendered blocks get one.
    private enum Block: String, PanelOrderItem { case temps, usage, memory, uptime, fans }

    // Hub availability per metric family: an unavailable metric leaves the
    // card entirely, including the edit-mode hidden rows.
    private var cpuAvailable: Bool { AppFeature.monitorCPU.isAvailable }
    private var gpuAvailable: Bool { AppFeature.monitorGPU.isAvailable }
    private var memoryAvailable: Bool { AppFeature.monitorMemory.isAvailable }
    private var fansAvailable: Bool { AppFeature.fanControl.isAvailable }

    private var usageVisible: Bool {
        (sysCPU && cpuAvailable) || (sysGPU && gpuAvailable)
    }

    private var visibleBlocks: [Block] {
        orderedBlocks.filter { isBlockAvailable($0) && isVisible($0) }
    }

    /// Uptime is not sampled, so only a sampled block on screen waits for the first snapshot.
    private var awaitingFirstReading: Bool {
        !monitor.hasReading && visibleBlocks.contains { $0 != .uptime }
    }

    private func blocks(editing: Bool) -> [Block] {
        editing ? orderedBlocks.filter(isBlockAvailable) : visibleBlocks
    }

    private func isBlockAvailable(_ block: Block) -> Bool {
        switch block {
        case .temps, .usage: return cpuAvailable || gpuAvailable
        case .memory: return memoryAvailable
        case .uptime: return true
        case .fans: return fansAvailable
        }
    }

    private var orderedBlocks: [Block] {
        _ = systemOrderRaw
        return PanelLayout.itemOrder(Block.self, key: DefaultsKey.panelSystemOrder)
    }

    private var blockOrderBinding: Binding<[Block]> {
        Binding {
            orderedBlocks
        } set: { newValue in
            PanelLayout.setItemOrder(newValue, key: DefaultsKey.panelSystemOrder)
        }
    }

    private func isVisible(_ block: Block) -> Bool {
        switch block {
        case .temps: return sysTemps
        case .usage: return usageVisible
        case .memory: return sysMemory
        case .uptime: return sysUptime
        case .fans: return sysFans
        }
    }

    private func resetPanelDefaults() {
        PanelLayout.resetItemOrder(key: DefaultsKey.panelSystemOrder)
        systemOrderRaw = ""
        sysTemps = true
        sysCPU = true
        sysGPU = true
        sysMemory = true
        sysUptime = true
        sysFans = true
    }

    @ViewBuilder
    private func blockContent(_ block: Block, editing: Bool) -> some View {
        switch block {
        case .temps: temperatureGrid(editing: editing)
        case .usage: usageRows(editing: editing)
        case .memory: memoryRows(editing: editing)
        case .uptime: uptimeRow(editing: editing)
        case .fans: fansBlock(editing: editing)
        }
    }

    // MARK: Per-app breakdown

    private func toggleBreakdown(_ kind: BreakdownKind) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            if expanded == kind {
                expanded = nil
                breakdownRows = []
                breakdownIsLoading = false
            } else {
                expanded = kind
                breakdownRows = ProcessUsageService.shared.cachedTop(kind, limit: breakdownLimit) ?? []
                refreshBreakdown()
            }
        }
    }

    private func refreshBreakdown() {
        guard let kind = expanded else { return }
        lastBreakdownRefresh = Date()
        breakdownIsLoading = breakdownRows.isEmpty
        let sampleInterval = percentageSampleInterval
        let cpuPercentage = monitor.snapshot.cpuUsage.map { $0 * 100 }
        let gpuPercentage = monitor.snapshot.gpuUsage.map { $0 * 100 }
        DispatchQueue.global(qos: .utility).async {
            let rows = ProcessUsageService.shared.top(kind,
                                                      limit: breakdownLimit,
                                                      sampleInterval: sampleInterval,
                                                      cpuPercentage: cpuPercentage,
                                                      gpuPercentage: gpuPercentage)
            DispatchQueue.main.async {
                guard expanded == kind else { return }
                breakdownIsLoading = false
                if !rows.isEmpty || breakdownRows.isEmpty {
                    breakdownRows = rows
                }
            }
        }
    }

    private var percentageSampleInterval: TimeInterval {
        TimeInterval(Defaults.sanitizedMonitorInterval(monitorInterval))
    }

    @ViewBuilder
    private func breakdownList(for kind: BreakdownKind) -> some View {
        if expanded == kind {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                if breakdownRows.isEmpty, breakdownIsLoading {
                    HexaBusyState(variant: .compact, message: l10n.s.breakdownMeasuring)
                } else if breakdownRows.isEmpty {
                    Text(emptyBreakdownText(for: kind))
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgTertiary)
                        .padding(.leading, HexaTheme.Spacing.xxl)
                } else {
                    ForEach(breakdownRows) { row in
                        ProcessUsageRow(row: row,
                                        value: breakdownValue(row, for: kind),
                                        iconSize: 14,
                                        leadingPadding: 38)
                    }
                }
            }
        }
    }

    private func emptyBreakdownText(for kind: BreakdownKind) -> String {
        kind == .energy ? l10n.s.energyAppsIdle : MonitorExperienceStrings.localized(l10n.language).noApps
    }

    private func breakdownValue(_ row: ProcessUsage, for kind: BreakdownKind) -> String {
        kind == .memory ? formatMemory(UInt64(row.value))
                        : String(format: "%.1f%%", locale: MetricFormat.locale, row.value)
    }

    // MARK: Temperatures

    @ViewBuilder
    private func temperatureGrid(editing: Bool) -> some View {
        if !sysTemps {
            PanelHiddenItemRow(title: l10n.s.temperatures,
                               systemImage: "thermometer.medium",
                               isVisible: $sysTemps)
        } else {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                HStack(spacing: HexaTheme.Spacing.xs) {
                    subsectionLabel(l10n.s.temperatures)
                    Spacer(minLength: 0)
                    if editing {
                        PanelInlineHideButton(isVisible: $sysTemps)
                    }
                }
                HStack(spacing: HexaTheme.Spacing.s) {
                    if cpuAvailable {
                        temperatureCell(icon: "cpu", label: l10n.s.cpuLabel,
                                        value: monitor.snapshot.cpuTemperature)
                    }
                    if gpuAvailable {
                        temperatureCell(icon: "memorychip", label: l10n.s.gpuLabel,
                                        value: monitor.snapshot.gpuTemperature)
                    }
                }
                if monitor.snapshot.cpuTemperature == nil,
                   monitor.snapshot.gpuTemperature == nil {
                    Text(l10n.s.monitorUnavailable)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgTertiary)
                }
            }
        }
    }

    private func temperatureCell(icon: String, label: String, value: Double?) -> some View {
        VStack(spacing: HexaTheme.Spacing.xs) {
            HStack(spacing: HexaTheme.Spacing.xs) {
                HexaIcons.image(icon, size: 9)
                    .foregroundStyle(HexaTheme.fgSecondary)
                Text(label)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
            Text(value.map { MetricFormat.temperature($0, unit: displayTemperatureUnit) } ?? "-")
                .font(.hexa(.heading))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, HexaTheme.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                .fill(HexaTheme.surfaceInset)
        )
    }

    private var displayTemperatureUnit: TemperatureUnit {
        TemperatureUnit(rawValue: temperatureUnit) ?? .celsius
    }

    // MARK: Hardware usage

    private func usageRows(editing: Bool) -> some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            HStack(spacing: HexaTheme.Spacing.xs) {
                subsectionLabel(l10n.s.usageSection)
                Spacer(minLength: 0)
                if !editing {
                    ActivityMonitorButton()
                }
            }
            if sysCPU, cpuAvailable {
                usageRow(label: l10n.s.cpuLabel, fraction: monitor.snapshot.cpuUsage,
                         kind: .cpu, editing: editing, visible: $sysCPU)
                if graphCPU, monitor.snapshot.cpuHistory.count >= 2 {
                    Sparkline(values: monitor.snapshot.cpuHistory,
                              color: PanelMetricColor.cyan(for: colorScheme),
                              maxValue: 1,
                              showsZeroBaseline: true)
                        .frame(height: 30)
                        .graphCeilingLabel(MetricFormat.percent(1))
                }
                breakdownList(for: .cpu)
            } else if editing, cpuAvailable {
                PanelHiddenItemRow(title: l10n.s.cpuLabel, systemImage: "cpu", isVisible: $sysCPU)
            }
            if sysGPU, gpuAvailable {
                usageRow(label: l10n.s.gpuLabel, fraction: monitor.snapshot.gpuUsage,
                         kind: .gpu, editing: editing, visible: $sysGPU)
                if graphGPU, monitor.snapshot.gpuHistory.count >= 2 {
                    Sparkline(values: monitor.snapshot.gpuHistory,
                              color: PanelMetricColor.cyan(for: colorScheme),
                              maxValue: 1,
                              showsZeroBaseline: true)
                        .frame(height: 30)
                        .graphCeilingLabel(MetricFormat.percent(1))
                }
                breakdownList(for: .gpu)
            } else if editing, gpuAvailable {
                PanelHiddenItemRow(title: l10n.s.gpuLabel, systemImage: "memorychip", isVisible: $sysGPU)
            }
        }
    }

    // MARK: Uptime

    @ViewBuilder
    private func uptimeRow(editing: Bool) -> some View {
        if !sysUptime {
            PanelHiddenItemRow(title: l10n.s.monitorItemUptime, systemImage: "clock", isVisible: $sysUptime)
        } else {
            HStack(spacing: HexaTheme.Spacing.xs) {
                HexaIcons.image("clock", size: 9)
                    .foregroundStyle(HexaTheme.fgSecondary)
                Text("\(l10n.s.systemUptime) \(Self.uptimeString())")
                    .font(.hexa(.body))
                    .foregroundStyle(HexaTheme.fgSecondary)
                Spacer()
                if editing {
                    PanelInlineHideButton(isVisible: $sysUptime)
                }
            }
        }
    }

    // MARK: Fans

    @ViewBuilder
    private func fansBlock(editing: Bool) -> some View {
        let fanStrings = FeatureStrings.fanControl(l10n.language)
        if !sysFans {
            PanelHiddenItemRow(title: fanStrings.title,
                               systemImage: "fanblades",
                               isVisible: $sysFans)
        } else {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                HStack(spacing: HexaTheme.Spacing.xs) {
                    subsectionLabel(fanStrings.title)
                    Spacer(minLength: 0)
                    if editing {
                        PanelInlineHideButton(isVisible: $sysFans)
                    } else {
                        HexaIconButton(icon: "fanblades.fill",
                                       label: fanStrings.title,
                                       variant: .small) {
                            MenuPanelFocus.shared.focus(.fanControl)
                        }
                        .help(fanStrings.title)
                    }
                }
                let speeds = monitor.snapshot.fanSpeeds
                if !speeds.isEmpty {
                    HStack(spacing: HexaTheme.Spacing.s) {
                        ForEach(Array(speeds.enumerated()), id: \.offset) { index, rpm in
                            fanCell(index: index, rpm: rpm, strings: fanStrings, editing: editing)
                        }
                    }
                } else if !SystemMonitor.fanTelemetryAvailable {
                    // The monitor's own reading is the only source here: Fan
                    // Control's snapshot is fresh only while its panel is open.
                    Text(fanStrings.noFans)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgTertiary)
                } else {
                    Text(l10n.s.breakdownMeasuring)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgTertiary)
                }
            }
        }
    }

    @ViewBuilder
    private func fanCell(index: Int, rpm: Double, strings: FanControlFeatureStrings, editing: Bool) -> some View {
        if editing {
            fanCellContent(index: index, rpm: rpm, strings: strings)
        } else {
            Button {
                MenuPanelFocus.shared.focus(.fanControl)
            } label: {
                fanCellContent(index: index, rpm: rpm, strings: strings)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(strings.title)
        }
    }

    private func fanCellContent(index: Int, rpm: Double, strings: FanControlFeatureStrings) -> some View {
        VStack(spacing: HexaTheme.Spacing.xs) {
            HStack(spacing: HexaTheme.Spacing.xs) {
                HexaIcons.image("fanblades", size: 9)
                    .foregroundStyle(HexaTheme.fgSecondary)
                Text(String(format: strings.fanNameFormat, index + 1))
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
            Text(String(format: strings.rpmFormat, Int(rpm.rounded())))
                .font(.hexa(.heading))
                .monospacedDigit()
                .foregroundStyle(HexaTheme.fgPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, HexaTheme.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                .fill(HexaTheme.surfaceInset)
        )
    }

    static func uptimeString() -> String {
        let total = SystemInfo.wallClockUptimeSeconds() ?? Int(ProcessInfo.processInfo.systemUptime)
        return MetricFormat.uptime(total)
    }

    private static let memoryFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter
    }()

    private func usageRow(label: String, fraction: Double?, kind: BreakdownKind,
                          editing: Bool, visible: Binding<Bool>) -> some View {
        Group {
            if editing {
                usageRowContent(label: label, fraction: fraction, kind: kind, isInteractive: false) {
                    PanelInlineHideButton(isVisible: visible)
                }
            } else {
                Button {
                    toggleBreakdown(kind)
                } label: {
                    usageRowContent(label: label, fraction: fraction, kind: kind, isInteractive: true) {
                        EmptyView()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focused($focusedBreakdown, equals: kind)
                .overlay { breakdownFocusRing(kind) }
                .accessibilityValue(expanded == kind ? l10n.s.disclosureExpanded : l10n.s.disclosureCollapsed)
            }
        }
    }

    private func breakdownFocusRing(_ kind: BreakdownKind) -> some View {
        RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
            .strokeBorder(focusedBreakdown == kind ? HexaTheme.focusRing : .clear, lineWidth: 2)
            .padding(1) // geometria de plataforma (spec §4): offset de foco
    }

    private func usageRowContent<Trailing: View>(label: String, fraction: Double?,
                                                 kind: BreakdownKind, isInteractive: Bool,
                                                 @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            HexaIcons.image("chevron.right", size: 10)
                .font(.hexa(.micro))
                .foregroundStyle(HexaTheme.fgSecondary)
                .rotationEffect(.degrees(expanded == kind ? 90 : 0))
                .opacity(isInteractive ? 1 : 0.35)
            Text(label)
                .font(.hexa(.body))
                .foregroundStyle(HexaTheme.fgSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 52, alignment: .leading)
            UsageBar(fraction: fraction ?? 0)
            Text(fraction.map { String(format: "%.0f%%", locale: MetricFormat.locale, $0 * 100) } ?? "-")
                .font(.hexa(.data))
                .frame(width: 38, alignment: .trailing)
            trailing()
        }
    }

    // MARK: Memory

    @ViewBuilder
    private func memoryRows(editing: Bool) -> some View {
        if !sysMemory {
            PanelHiddenItemRow(title: l10n.s.memorySection,
                               systemImage: "memorychip.fill",
                               isVisible: $sysMemory)
        } else {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                HStack(spacing: HexaTheme.Spacing.xs) {
                    subsectionLabel(l10n.s.memorySection)
                    Spacer(minLength: 0)
                    if editing {
                        PanelInlineHideButton(isVisible: $sysMemory)
                    }
                }
                if editing {
                    memoryRowContent(isInteractive: false)
                } else {
                    Button {
                        toggleBreakdown(.memory)
                    } label: {
                        memoryRowContent(isInteractive: true)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .focused($focusedBreakdown, equals: .memory)
                    .overlay { breakdownFocusRing(.memory) }
                    .accessibilityValue(expanded == .memory ? l10n.s.disclosureExpanded : l10n.s.disclosureCollapsed)
                }
                memorySecondaryRow(l10n.s.memoryCompressed, monitor.snapshot.memoryCompressed)
                memorySecondaryRow(l10n.s.memoryCachedFiles, monitor.snapshot.memoryCached)
                memorySecondaryRow(l10n.s.memorySwapUsed, monitor.snapshot.memorySwapUsed)
                let memoryHistory = MonitorMemoryMetric.current.history(in: monitor.snapshot)
                if graphMemory, memoryHistory.count >= 2 {
                    Sparkline(values: memoryHistory,
                              color: PanelMetricColor.mint(for: colorScheme),
                              maxValue: 1,
                              showsZeroBaseline: true)
                        .frame(height: 30)
                        .graphCeilingLabel(MetricFormat.percent(1))
                }
                breakdownList(for: .memory)
            }
        }
    }

    @ViewBuilder
    private func memorySecondaryRow(_ title: String, _ bytes: UInt64?) -> some View {
        if let bytes {
            HStack(spacing: HexaTheme.Spacing.s) {
                Text(title)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                Spacer()
                Text(formatMemory(bytes))
                    .font(.hexa(.data))
                    .monospacedDigit()
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
            .padding(.leading, HexaTheme.Spacing.l)
        }
    }

    private func memoryRowContent(isInteractive: Bool) -> some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            HexaIcons.image("chevron.right", size: 10)
                .font(.hexa(.micro))
                .foregroundStyle(HexaTheme.fgSecondary)
                .rotationEffect(.degrees(expanded == .memory ? 90 : 0))
                .opacity(isInteractive ? 1 : 0.35)
            Text(l10n.s.memoryPressure)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
            PressureIndicator(pressure: monitor.snapshot.memoryPressure)
            Spacer()
            let memoryValue = MonitorMemoryMetric.current.value(in: monitor.snapshot)
            if let used = memoryValue, let total = monitor.snapshot.memoryTotal {
                Text("\(formatMemory(used)) / \(formatMemory(total))")
                    .font(.hexa(.data))
                    .monospacedDigit()
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
        }
    }

    private func subsectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.hexa(.label))
            .foregroundStyle(HexaTheme.fgSecondary)
    }

    private func formatMemory(_ bytes: UInt64) -> String {
        Self.memoryFormatter.string(fromByteCount: Int64(bytes))
    }
}

/// Thin capacity bar for CPU/GPU/Disk usage.
struct UsageBar: View {
    @Environment(\.colorScheme) private var colorScheme
    let fraction: Double
    var tint: Color? = nil
    var height: CGFloat = 5
    var elevatedThreshold: Double = 0.6
    var criticalThreshold: Double = 0.85
    var animated: Bool = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(HexaTheme.surfaceInset)
                Capsule()
                    .fill(tint ?? barColor)
                    .frame(width: max(3, proxy.size.width * min(1, max(0, fraction))))
                    .animation(animated ? .easeOut(duration: 0.4) : nil, value: fraction)
            }
        }
        .frame(height: height)
    }

    private var barColor: Color {
        switch fraction {
        case ..<elevatedThreshold: return PanelMetricColor.cyan(for: colorScheme)
        case ..<criticalThreshold: return PanelMetricColor.yellow(for: colorScheme)
        default: return PanelMetricColor.red(for: colorScheme)
        }
    }
}

/// Etiqueta compacta de pressão de memória via HexaStateTag (spec §7).
struct PressureIndicator: View {
    @ObservedObject private var l10n = L10n.shared
    let pressure: MemoryPressure

    var body: some View {
        HexaStateTag(label, kind: kind)
    }

    private var kind: HexaStateTag.Kind {
        switch pressure {
        case .normal: return .ok
        case .warning: return .warning
        case .critical: return .danger
        case .unknown: return .neutral
        }
    }

    private var label: String {
        switch pressure {
        case .normal: return l10n.s.pressureNormal
        case .warning: return l10n.s.pressureWarning
        case .critical: return l10n.s.pressureCritical
        case .unknown: return "-"
        }
    }
}
