// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// The "Power" card: how much the Mac is drawing overall, from the adapter, and
/// to/from the battery. Rows that the hardware cannot report are simply hidden;
/// a Mac that reports nothing shows a short note instead.
struct PowerSection: View {
    @Environment(\.featureWorkspacePresentation) private var featureWorkspacePresentation
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var monitor = SystemMonitor.shared
    @ObservedObject private var permissions = Permissions.shared
    @Environment(\.colorScheme) private var colorScheme
    var collapsible = true
    @AppStorage(DefaultsKey.monitorGraphPower) private var showGraph = true
    @AppStorage(DefaultsKey.monitorInterval) private var monitorInterval = 2
    @AppStorage(DefaultsKey.monitorSysBattery) private var showCharge = true
    @AppStorage(DefaultsKey.monitorPwrTemperature) private var showTemperature = true
    @AppStorage(DefaultsKey.monitorGraphBattery) private var graphBattery = true
    @AppStorage(DefaultsKey.temperatureUnit) private var temperatureUnit = TemperatureUnit.celsius.rawValue
    @AppStorage(DefaultsKey.monitorPwrSystem) private var pwrSystem = true
    @AppStorage(DefaultsKey.monitorPwrAdapter) private var pwrAdapter = true
    @AppStorage(DefaultsKey.monitorPwrBattery) private var pwrBattery = true
    @AppStorage(DefaultsKey.monitorPwrTimeRemaining) private var pwrTimeRemaining = true
    @AppStorage(DefaultsKey.monitorPwrHealth) private var pwrHealth = true
    @AppStorage(DefaultsKey.panelPowerOrder) private var powerOrderRaw = ""
    @State private var draggingBlock: Block?

    var body: some View {
        Group {
            if featureWorkspacePresentation {
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.l) {
                    MonitorHero(kind: .power,
                                windowText: MonitorHero.windowText(
                                    samples: monitor.snapshot.systemPowerHistory.count,
                                    interval: Defaults.sanitizedMonitorInterval(monitorInterval),
                                    format: MonitorExperienceStrings.localized(l10n.language).graphWindowFormat))
                        .panelCard()
                    HexaCard {
                        cardContent(editing: false)
                    }
                }
            } else {
                PanelSection(.power, title: l10n.s.powerSection, collapsible: collapsible,
                             supportsEditing: true,
                             resetAction: resetPanelDefaults) { editing in
                    cardContent(editing: editing)
                        .panelCard()
                }
            }
        }
    }

    private func cardContent(editing: Bool) -> some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            if blocks(editing: editing).isEmpty {
                if monitor.hasReading {
                    Text(l10n.s.powerUnavailable)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgTertiary)
                } else {
                    HexaBusyState(variant: .compact, message: l10n.s.loadingMessage)
                }
            }
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
            if featureWorkspacePresentation, permissions.bluetooth == .denied {
                HexaStatusNote(message: MonitorExperienceStrings.localized(l10n.language).bluetoothDenied,
                               tone: .neutral)
            }
            // Bluetooth accessories add their battery only after the user asks;
            // until then the list holds what IOKit reads.
            if !editing, permissions.bluetooth == .undetermined,
               Permissions.hasUsageDescription("NSBluetoothAlwaysUsageDescription") {
                HexaAccessButton(icon: "dot.radiowaves.left.and.right",
                                 title: FeatureStrings.hub(l10n.language).bluetoothBatteryRequest) {
                    permissions.requestBluetooth()
                }
                .controlSize(.small)
            }
        }
    }

    private enum Block: String, PanelOrderItem { case charge, temperature, system, adapter, battery, remaining, health, peripherals }

    private var orderedBlocks: [Block] {
        _ = powerOrderRaw
        return PanelLayout.itemOrder(Block.self, key: DefaultsKey.panelPowerOrder)
    }

    private var blockOrderBinding: Binding<[Block]> {
        Binding {
            orderedBlocks
        } set: { newValue in
            PanelLayout.setItemOrder(newValue, key: DefaultsKey.panelPowerOrder)
        }
    }

    private func blocks(editing: Bool) -> [Block] {
        if featureWorkspacePresentation {
            // Charge and system watts live in the hero above the card.
            return [.temperature, .adapter, .battery, .remaining, .health, .peripherals]
                .filter { isAvailable($0) && hasData($0) }
        }
        let available = orderedBlocks.filter(isAvailable)
        return available.filter { isVisible($0) || (editing && !isEnabled($0)) }
    }

    private func isAvailable(_ block: Block) -> Bool {
        switch block {
        case .system, .adapter: return true
        case .peripherals: return !monitor.snapshot.peripheralBatteries.isEmpty
        case .charge, .temperature, .battery, .remaining, .health: return PowerSampler.hasInternalBattery
        }
    }

    /// Workspace only: a block without a reading is dropped, so no empty block or
    /// stray divider remains. Mirrors the data conditions of `isVisible`, minus the
    /// panel's show/hide keys.
    private func hasData(_ block: Block) -> Bool {
        switch block {
        case .temperature:
            return PowerSampler.hasInternalBattery && monitor.snapshot.batteryTemperature != nil
        case .peripherals:
            return !monitor.snapshot.peripheralBatteries.isEmpty
        case .charge, .system:
            return false
        case .adapter, .battery, .remaining, .health:
            break
        }
        guard let power = monitor.snapshot.power, !power.isEmpty else { return false }
        switch block {
        case .adapter: return power.externalConnected && power.adapterWatts != nil
        case .battery: return power.hasBattery && power.batteryWatts != nil
        case .remaining: return power.hasBattery && !power.externalConnected && !power.isCharging
        case .health: return power.healthPercent != nil
        case .charge, .temperature, .system, .peripherals: return false
        }
    }

    private func isEnabled(_ block: Block) -> Bool {
        switch block {
        case .charge: return showCharge
        case .temperature: return showTemperature
        case .system: return pwrSystem
        case .adapter: return pwrAdapter
        case .battery: return pwrBattery
        case .remaining: return pwrTimeRemaining
        case .health: return pwrHealth
        case .peripherals: return true
        }
    }

    private func isVisible(_ block: Block) -> Bool {
        switch block {
        case .charge: return showCharge && monitor.snapshot.power?.chargePercent != nil
        case .temperature: return showTemperature && monitor.snapshot.batteryTemperature != nil
        case .peripherals: return !monitor.snapshot.peripheralBatteries.isEmpty
        default: break
        }
        guard let power = monitor.snapshot.power, !power.isEmpty else { return false }
        switch block {
        case .charge, .temperature, .peripherals: return false
        case .system: return pwrSystem && power.systemWatts != nil
        case .adapter: return pwrAdapter && power.externalConnected && power.adapterWatts != nil
        case .battery: return pwrBattery && power.hasBattery && power.batteryWatts != nil
        case .remaining:
            return pwrTimeRemaining && power.hasBattery
                && !power.externalConnected && !power.isCharging
        case .health: return pwrHealth && power.healthPercent != nil
        }
    }

    @ViewBuilder
    private func blockContent(_ block: Block, editing: Bool) -> some View {
        let power = monitor.snapshot.power
        switch block {
        case .charge:
            if showCharge || featureWorkspacePresentation {
                batteryUsageRow(editing: editing)
            } else if editing {
                PanelHiddenItemRow(title: l10n.s.batteryCharge, systemImage: "battery.100", isVisible: $showCharge)
            }
        case .temperature:
            if (showTemperature || featureWorkspacePresentation), let value = monitor.snapshot.batteryTemperature {
                row(icon: "thermometer.medium", color: HexaTheme.fgSecondary,
                    label: l10n.s.monitorShowBatteryTemperature,
                    value: MetricFormat.temperature(value, unit: TemperatureUnit(rawValue: temperatureUnit) ?? .celsius),
                    visible: $showTemperature, editing: editing)
            } else if editing && !showTemperature {
                PanelHiddenItemRow(title: l10n.s.monitorShowBatteryTemperature,
                                   systemImage: "thermometer.medium", isVisible: $showTemperature)
            }
        case .peripherals:
            peripheralBatteryRows
        case .system:
            if (pwrSystem || featureWorkspacePresentation), let watts = power?.systemWatts {
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                    row(icon: "bolt.fill", color: PanelMetricColor.orange(for: colorScheme),
                        label: l10n.s.powerSystem, value: MetricFormat.watts(watts),
                        visible: $pwrSystem, editing: editing)
                    if showGraph, monitor.snapshot.systemPowerHistory.count >= 2 {
                        let peak = MetricFormat.graphCeiling(monitor.snapshot.systemPowerHistory.max() ?? 0,
                                                             unitStep: 1000)
                        Sparkline(values: monitor.snapshot.systemPowerHistory,
                                  color: PanelMetricColor.orange(for: colorScheme),
                                  maxValue: peak,
                                  showsZeroBaseline: true)
                            .frame(height: 30)
                            .graphCeilingLabel(MetricFormat.watts(peak))
                    }
                }
            } else if editing && !pwrSystem {
                PanelHiddenItemRow(title: l10n.s.powerSystem,
                                   systemImage: "bolt.fill",
                                   isVisible: $pwrSystem)
            }
        case .adapter:
            if (pwrAdapter || featureWorkspacePresentation), let power, power.externalConnected, let adapter = power.adapterWatts {
                row(icon: "powerplug.fill", color: PanelMetricColor.cyan(for: colorScheme),
                    label: l10n.s.powerAdapter, value: MetricFormat.watts(adapter),
                    caption: adapterCaption(power),
                    visible: $pwrAdapter, editing: editing)
            } else if editing && !pwrAdapter {
                PanelHiddenItemRow(title: l10n.s.powerAdapter,
                                   systemImage: "powerplug.fill",
                                   isVisible: $pwrAdapter)
            }
        case .battery:
            if (pwrBattery || featureWorkspacePresentation), power?.hasBattery == true, let flow = power?.batteryWatts {
                row(icon: flow >= 0 ? "battery.100.bolt" : "battery.50",
                    color: flow >= 0 ? PanelMetricColor.green(for: colorScheme) : HexaTheme.fgSecondary,
                    label: l10n.s.powerBattery,
                    value: MetricFormat.watts(abs(flow)),
                    caption: flow >= 0 ? l10n.s.powerCharging : l10n.s.powerOnBattery,
                    visible: $pwrBattery, editing: editing)
            } else if editing && !pwrBattery {
                PanelHiddenItemRow(title: l10n.s.powerBattery,
                                   systemImage: "battery.100.bolt",
                                   isVisible: $pwrBattery)
            }
        case .health:
            if (pwrHealth || featureWorkspacePresentation), let power, let health = power.healthPercent {
                row(icon: "heart.fill", color: PanelMetricColor.pink(for: colorScheme),
                    label: l10n.s.powerHealth,
                    value: "\(Int(health.rounded()))%",
                    caption: power.cycleCount.map { "\($0) \(l10n.s.powerCycles)" },
                    visible: $pwrHealth, editing: editing)
            } else if editing && !pwrHealth {
                PanelHiddenItemRow(title: l10n.s.powerHealth,
                                   systemImage: "heart.fill",
                                   isVisible: $pwrHealth)
            }
        case .remaining:
            if (pwrTimeRemaining || featureWorkspacePresentation), let power, power.hasBattery,
               !power.externalConnected, !power.isCharging {
                let strings = FeatureStrings.batteryTime(l10n.language)
                let value = power.timeRemainingSeconds.flatMap(BatteryTimeSupport.formatted)
                row(icon: "clock", color: PanelMetricColor.green(for: colorScheme),
                    label: strings.title,
                    value: value ?? "...",
                    caption: value == nil ? strings.calculating : strings.systemEstimate,
                    visible: $pwrTimeRemaining, editing: editing)
            } else if editing && !pwrTimeRemaining {
                PanelHiddenItemRow(title: FeatureStrings.batteryTime(l10n.language).title,
                                   systemImage: "clock",
                                   isVisible: $pwrTimeRemaining)
            }
        }
    }

    private func subsectionLabel(_ text: String) -> some View {
        Text(text).font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
    }

    /// External power earns the bolt whether or not a charge is running, so a
    /// Mac held at a limit is not drawn as one on its own battery.
    private var batteryUsageSymbol: String {
        switch BatteryPowerSupport.state(isCharging: monitor.snapshot.power?.isCharging ?? false,
                                         externalConnected: monitor.snapshot.power?.externalConnected ?? false,
                                         hasBattery: monitor.snapshot.power?.hasBattery ?? true) {
        case .charging, .externalPower: return "bolt.fill"
        case .onBattery, .unavailable: return "battery.100"
        }
    }

    @ViewBuilder
    private func batteryUsageRow(editing: Bool) -> some View {
        if let charge = monitor.snapshot.power?.chargePercent {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                HStack(spacing: HexaTheme.Spacing.s) {
                    HexaIcons.image(batteryUsageSymbol, size: 9)
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .frame(width: 10)
                    Text(l10n.s.batteryLabel)
                        .font(.hexa(.body))
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(width: 52, alignment: .leading)
                    UsageBar(fraction: Double(charge) / 100, tint: chargeTint(charge))
                    Text("\(charge)%")
                        .font(.hexa(.data))
                        .frame(width: 38, alignment: .trailing)
                    if editing {
                        PanelInlineHideButton(isVisible: $showCharge)
                    }
                }
                if graphBattery, monitor.snapshot.batteryHistory.count >= 2 {
                    Sparkline(values: monitor.snapshot.batteryHistory,
                              color: PanelMetricColor.green(for: colorScheme),
                              maxValue: 1,
                              showsZeroBaseline: true)
                        .frame(height: 30)
                        .graphCeilingLabel(MetricFormat.percent(1))
                }
                EnergyAppsBreakdown()
            }
        }
    }

    private var peripheralBatteryRows: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            subsectionLabel(featureWorkspacePresentation
                            ? MonitorExperienceStrings.localized(l10n.language).accessories
                            : l10n.s.monitorShowPeripheralBattery)
            ForEach(PeripheralBatterySupport.sorted(monitor.snapshot.peripheralBatteries).prefix(5)) { device in
                HStack(spacing: HexaTheme.Spacing.s) {
                    HexaIcons.image(peripheralIcon(for: device.kind), size: 9)
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .frame(width: 10)
                    Text(device.name)
                        .font(.hexa(.body))
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 8)
                    Text("\(device.percent)%")
                        .font(.hexa(.data))
                }
            }
            let extra = max(0, monitor.snapshot.peripheralBatteries.count - 5)
            if extra > 0 {
                Text("+\(extra)")
                    .font(.hexa(.data))
                    .foregroundStyle(HexaTheme.fgTertiary)
            }
        }
    }

    private func peripheralIcon(for kind: PeripheralBatteryKind) -> String {
        switch kind {
        case .keyboard: return "keyboard"
        case .mouse: return "computermouse"
        case .trackpad: return "rectangle.and.hand.point.up.left"
        case .audio: return "headphones"
        case .device: return "battery.100"
        }
    }

    private func chargeTint(_ charge: Int) -> Color {
        if charge < 20 { return PanelMetricColor.red(for: colorScheme) }
        if charge < 40 { return PanelMetricColor.yellow(for: colorScheme) }
        return PanelMetricColor.green(for: colorScheme)
    }

    private func resetPanelDefaults() {
        PanelLayout.resetItemOrder(key: DefaultsKey.panelPowerOrder)
        powerOrderRaw = ""
        showCharge = true
        showTemperature = true
        pwrSystem = true
        pwrAdapter = true
        pwrBattery = true
        pwrTimeRemaining = true
        pwrHealth = true
    }

    private func adapterCaption(_ power: PowerReading) -> String {
        if let rated = power.adapterMaxWatts {
            return String(format: l10n.s.powerAdapterMaxFormat, MetricFormat.watts(rated))
        }
        return l10n.s.powerPluggedIn
    }

    private func row(icon: String, color: Color, label: String, value: String, caption: String? = nil,
                     visible: Binding<Bool>, editing: Bool) -> some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            HexaIcons.image(icon, size: 11)
                .foregroundStyle(color)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                Text(label)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                if let caption {
                    Text(caption)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgSecondary)
                }
            }
            Spacer(minLength: HexaTheme.Spacing.s)
            Text(value)
                .font(.hexa(.data))
                .contentTransition(.numericText())
                .frame(minWidth: 44, alignment: .trailing)
            if editing {
                PanelInlineHideButton(isVisible: visible)
            }
        }
    }
}

private struct EnergyAppsBreakdown: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var monitor = SystemMonitor.shared
    @AppStorage(DefaultsKey.monitorInterval) private var monitorInterval = 2
    @State private var expanded = false
    @State private var rows: [ProcessUsage] = []
    @State private var loading = false
    @State private var lastRefresh = Date.distantPast
    @State private var requestID = UUID()

    var body: some View {
        HexaDisclosure(isExpanded: Binding(
            get: { expanded },
            set: { value in
                expanded = value
                requestID = UUID()
                if value {
                    rows = ProcessUsageService.shared.cachedTop(.energy, limit: 15) ?? []
                    refresh()
                } else {
                    rows = []
                }
            }
        )) {
            Text(l10n.s.energyAppsTitle).font(.hexa(.label))
        } content: {
                if rows.isEmpty {
                    Text(loading ? l10n.s.breakdownMeasuring : l10n.s.energyAppsIdle)
                        .foregroundStyle(HexaTheme.fgTertiary)
                } else {
                    ForEach(rows) { row in
                        ProcessUsageRow(row: row,
                                        value: String(format: "%.1f%%", locale: MetricFormat.locale, row.value),
                                        iconSize: 14, leadingPadding: 16)
                    }
                }
        }
        .font(.hexa(.label))
        .foregroundStyle(HexaTheme.fgSecondary)
        .onReceive(monitor.$snapshot) { _ in
            guard expanded, !loading,
                  Date().timeIntervalSince(lastRefresh) >= Double(Defaults.sanitizedMonitorInterval(monitorInterval))
            else { return }
            refresh()
        }
        .onDisappear {
            expanded = false
            requestID = UUID()
            rows = []
            loading = false
        }
    }

    private func refresh() {
        lastRefresh = Date()
        loading = true
        let currentRequest = requestID
        let interval = Double(Defaults.sanitizedMonitorInterval(monitorInterval))
        DispatchQueue.global(qos: .utility).async {
            let result = ProcessUsageService.shared.top(.energy, limit: 15, sampleInterval: interval)
            DispatchQueue.main.async {
                guard expanded, requestID == currentRequest else { return }
                loading = false
                if !result.isEmpty || rows.isEmpty { rows = result }
            }
        }
    }
}
