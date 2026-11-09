// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import SwiftUI

struct DiskSection: View {
    @Environment(\.featureWorkspacePresentation) private var featureWorkspacePresentation
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var monitor = SystemMonitor.shared
    @ObservedObject private var protection = DiskProtectionService.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.notchPresentation) private var notchPresentation
    var collapsible = true
    var selectedDiskIDBinding: Binding<String?>? = nil
    @AppStorage(DefaultsKey.monitorGraphDisk) private var showGraph = true
    @AppStorage(DefaultsKey.monitorInterval) private var monitorInterval = 2
    @AppStorage(DefaultsKey.monitorDiskUsage) private var diskUsage = true
    @AppStorage(DefaultsKey.monitorDiskActivity) private var diskActivity = true
    @AppStorage(DefaultsKey.monitorDiskSMART) private var diskSMART = true
    @AppStorage(DefaultsKey.monitorDiskProtection) private var diskProtection = true
    @AppStorage(DefaultsKey.monitorDiskTools) private var diskTools = true
    @AppStorage(DefaultsKey.panelDiskOrder) private var diskOrderRaw = ""
    @AppStorage(DefaultsKey.temperatureUnit) private var temperatureUnit = TemperatureUnit.celsius.rawValue
    @State private var draggingBlock: Block?
    @State private var localSelectedDiskID: String?

    private enum Block: String, PanelOrderItem { case usage, activity, smart, protection, tools }

    var body: some View {
        Group {
            if featureWorkspacePresentation {
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.l) {
                    MonitorHero(kind: .disk,
                                disk: selectedDisk,
                                context: selectedDisk?.name,
                                graphLegend: "\(l10n.s.diskRead) / \(l10n.s.diskWrite)",
                                windowText: MonitorHero.windowText(
                                    samples: max(monitor.snapshot.diskReadHistory.count, monitor.snapshot.diskWriteHistory.count),
                                    interval: Defaults.sanitizedMonitorInterval(monitorInterval),
                                    format: MonitorExperienceStrings.localized(l10n.language).graphWindowFormat))
                        .panelCard()
                    // Without disks the hero reports it once read; no empty card while waiting.
                    if !disks.isEmpty || !monitor.hasReading {
                        HexaCard {
                            cardContent(editing: false)
                        }
                    }
                }
            } else {
                PanelSection(.disk, title: l10n.s.diskSection, collapsible: collapsible,
                             supportsEditing: true,
                             resetAction: resetPanelDefaults) { editing in
                    cardContent(editing: editing)
                        .panelCard()
                }
            }
        }
        .onAppear(perform: ensureSelectedDisk)
        .onChange(of: disks.map(\.id)) { _, _ in ensureSelectedDisk() }
    }

    private func cardContent(editing: Bool) -> some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            if disks.isEmpty {
                if monitor.hasReading {
                    Text(l10n.s.diskNoDisks)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgTertiary)
                } else {
                    HexaBusyState(variant: .compact, message: l10n.s.loadingMessage)
                }
            } else {
                diskSelector
                if let selected = selectedDisk {
                    ForEach(blocks(editing: editing), id: \.self) { block in
                        HairlineDivider()
                        PanelReorderableItem(item: block,
                                             isEnabled: editing,
                                             order: blockOrderBinding,
                                             dragging: $draggingBlock) {
                            HStack(alignment: .top, spacing: HexaTheme.Spacing.s) {
                                if editing {
                                    PanelDragHandle()
                                }
                                blockContent(block, disk: selected, editing: editing)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
            }
        }
    }

    private var disks: [DiskDeviceReading] {
        monitor.snapshot.disk?.devices ?? []
    }

    /// Seleção do binding da sessão (aba do workspace); sem binding, a memória local do painel.
    private var selectedDiskID: String? {
        get { selectedDiskIDBinding?.wrappedValue ?? localSelectedDiskID }
        nonmutating set {
            if let selectedDiskIDBinding { selectedDiskIDBinding.wrappedValue = newValue }
            else { localSelectedDiskID = newValue }
        }
    }

    /// Primeiro disco interno; sem disco interno, o primeiro da lista.
    private var defaultDisk: DiskDeviceReading? {
        disks.first(where: \.isInternal) ?? disks.first
    }

    private var selectedDisk: DiskDeviceReading? {
        if let selectedDiskID,
           let disk = disks.first(where: { $0.id == selectedDiskID }) {
            return disk
        }
        return defaultDisk
    }

    private var ejectableDisks: [DiskDeviceReading] {
        protection.ejectableDisks(from: disks)
    }

    private func ensureSelectedDisk() {
        guard !disks.isEmpty else {
            selectedDiskID = nil
            return
        }
        if selectedDiskID == nil || !disks.contains(where: { $0.id == selectedDiskID }) {
            selectedDiskID = defaultDisk?.id
        }
    }

    private var orderedBlocks: [Block] {
        _ = diskOrderRaw
        return PanelLayout.itemOrder(Block.self, key: DefaultsKey.panelDiskOrder)
    }

    private var blockOrderBinding: Binding<[Block]> {
        Binding {
            orderedBlocks
        } set: { newValue in
            PanelLayout.setItemOrder(newValue, key: DefaultsKey.panelDiskOrder)
        }
    }

    private func blocks(editing: Bool) -> [Block] {
        // Activity lives in the hero; eject is merged into the tools block.
        if featureWorkspacePresentation { return [.usage, .smart, .tools] }
        return editing ? orderedBlocks : orderedBlocks.filter(isVisible)
    }

    private func isVisible(_ block: Block) -> Bool {
        switch block {
        case .usage: return diskUsage
        case .activity: return diskActivity
        case .smart: return diskSMART
        case .protection: return diskProtection
        case .tools: return diskTools
        }
    }

    private func resetPanelDefaults() {
        PanelLayout.resetItemOrder(key: DefaultsKey.panelDiskOrder)
        diskOrderRaw = ""
        diskUsage = true
        diskActivity = true
        diskSMART = true
        diskProtection = true
        diskTools = true
    }

    @ViewBuilder
    private func blockContent(_ block: Block, disk: DiskDeviceReading, editing: Bool) -> some View {
        switch block {
        case .usage: usageBlock(disk: disk, editing: editing)
        case .activity: activityBlock(disk: disk, editing: editing)
        case .smart: smartBlock(disk: disk, editing: editing)
        case .protection: protectionBlock(disk: disk, editing: editing)
        case .tools: toolsBlock(disk: disk, editing: editing)
        }
    }

    @ViewBuilder
    private var diskSelector: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            Text(l10n.s.diskSelect)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgTertiary)
            LazyVGrid(columns: diskSelectorColumns, alignment: .center, spacing: HexaTheme.Spacing.xs) {
                ForEach(disks) { disk in
                    diskSelectorButton(for: disk)
                }
            }
            .padding(.vertical, 1) // geometria de plataforma (spec §4): evita clipagem da hairline do grid
        }
    }

    private var diskSelectorColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 96, maximum: 138), spacing: HexaTheme.Spacing.xs, alignment: .center)]
    }

    private func diskSelectorButton(for disk: DiskDeviceReading) -> some View {
        HStack(spacing: 0) {
            Button {
                selectedDiskID = disk.id
            } label: {
                HStack(spacing: HexaTheme.Spacing.xs) {
                    HexaIcons.image(disk.isInternal ? "internaldrive" : "externaldrive", size: 11)
                        .font(.hexa(.label))
                    VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                        HStack(spacing: HexaTheme.Spacing.xs) {
                            Text(disk.name)
                                .font(.hexa(.body))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            if disk.id == selectedDisk?.id {
                                HexaIcons.image("checkmark", size: 11)
                                    .font(.hexa(.label))
                                    .foregroundStyle(HexaTheme.fgPrimary)
                            }
                        }
                        Text("\(MetricFormat.percent(disk.usedFraction)) \(l10n.s.diskUsed)")
                            .font(.hexa(.data))
                            .foregroundStyle(HexaTheme.fgSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.leading, HexaTheme.Spacing.s)
                .padding(.trailing, disk.canEject ? 2 : 8) // geometria de plataforma (spec §4): gutter compensa overlay do botão de ejeção
                .padding(.vertical, HexaTheme.Spacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(disk.id == selectedDisk?.id ? .isSelected : [])
            if disk.canEject {
                DiskSelectorEjectButton(state: protection.state(for: disk),
                                        idleHelp: l10n.s.diskEject,
                                        busyHelp: l10n.s.diskEjecting,
                                        readyHelp: l10n.s.diskReadyToRemove,
                                        failedHelp: l10n.s.diskEjectFailed) {
                    protection.eject(disk, aboveIsland: notchPresentation)
                }
                .padding(.trailing, HexaTheme.Spacing.xs)
            }
        }
        .background(selectorBackground(for: disk))
        .clipShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
    }

    private func selectorBackground(for disk: DiskDeviceReading) -> some ShapeStyle {
        disk.id == selectedDisk?.id ? HexaTheme.selectionBg : HexaTheme.surfaceInset
    }

    @ViewBuilder
    private func usageBlock(disk: DiskDeviceReading, editing: Bool) -> some View {
        if !featureWorkspacePresentation && !diskUsage {
            PanelHiddenItemRow(title: l10n.s.monitorItemDiskUsage,
                               systemImage: "internaldrive",
                               isVisible: $diskUsage)
        } else {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                blockHeader(l10n.s.monitorItemDiskUsage, editing: editing, visible: $diskUsage)
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                    diskTitleRow(disk)
                    UsageBar(fraction: disk.usedFraction, height: 6, elevatedThreshold: 0.75, criticalThreshold: 0.9, animated: true)
                    HStack(spacing: HexaTheme.Spacing.xs) {
                        Text("\(MetricFormat.percent(disk.usedFraction)) \(l10n.s.diskUsed)")
                        Spacer()
                        Text("\(MetricFormat.diskBytes(disk.freeBytes)) \(l10n.s.diskAvailable)")
                    }
                    .font(.hexa(.data))
                    .monospacedDigit()
                    .foregroundStyle(HexaTheme.fgSecondary)
                    HStack(spacing: HexaTheme.Spacing.xs) {
                        Text("\(MetricFormat.diskBytes(disk.usedBytes)) / \(MetricFormat.diskBytes(disk.totalBytes))")
                        if let purgeable = disk.purgeableBytes, purgeable >= 500_000_000 {
                            Spacer()
                            Text("\(MetricFormat.diskBytes(purgeable)) \(l10n.s.diskPurgeable)")
                        }
                    }
                    .font(.hexa(.data))
                    .monospacedDigit()
                    .foregroundStyle(HexaTheme.fgTertiary)
                }
            }
        }
    }

    @ViewBuilder
    private func activityBlock(disk: DiskDeviceReading, editing: Bool) -> some View {
        if !featureWorkspacePresentation && !diskActivity {
            PanelHiddenItemRow(title: l10n.s.monitorItemDiskActivity,
                               systemImage: "arrow.up.arrow.down",
                               isVisible: $diskActivity)
        } else {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                blockHeader(l10n.s.monitorItemDiskActivity, editing: editing, visible: $diskActivity)
                HStack(spacing: HexaTheme.Spacing.s) {
                    rateColumn(icon: "arrow.down",
                               label: l10n.s.diskRead,
                               value: disk.readBytesPerSec,
                               color: PanelMetricColor.cyan(for: colorScheme))
                    HairlineDivider(vertical: true).frame(height: 28)
                    rateColumn(icon: "arrow.up",
                               label: l10n.s.diskWrite,
                               value: disk.writeBytesPerSec,
                               color: PanelMetricColor.pink(for: colorScheme))
                }
                if showGraph, monitor.snapshot.diskReadHistory.count >= 2 {
                    graph
                }
                HStack(spacing: HexaTheme.Spacing.xs) {
                    Text(l10n.s.networkThisSession)
                        .font(.hexa(.body))
                        .foregroundStyle(HexaTheme.fgTertiary)
                    Spacer()
                    Text("↓ \(MetricFormat.diskBytes(disk.totalReadBytes ?? 0))  ↑ \(MetricFormat.diskBytes(disk.totalWrittenBytes ?? 0))")
                        .font(.hexa(.data))
                        .foregroundStyle(HexaTheme.fgSecondary)
                }
            }
        }
    }

    private var graph: some View {
        let read = monitor.snapshot.diskReadHistory
        let write = monitor.snapshot.diskWriteHistory
        let peak = MetricFormat.graphCeiling(max(read.max() ?? 0, write.max() ?? 0, 1), unitStep: 1024)
        return ZStack {
            Sparkline(values: read, color: PanelMetricColor.cyan(for: colorScheme), maxValue: peak, showsZeroBaseline: true)
            Sparkline(values: write,
                      color: PanelMetricColor.pink(for: colorScheme),
                      maxValue: peak,
                      fillOpacity: 0,
                      dashed: true)
        }
        .frame(height: 30)
        .graphCeilingLabel(MetricFormat.bytesPerSec(peak))
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

    @ViewBuilder
    private func smartBlock(disk: DiskDeviceReading, editing: Bool) -> some View {
        if !featureWorkspacePresentation && !diskSMART {
            PanelHiddenItemRow(title: l10n.s.monitorItemDiskSMART,
                               systemImage: "checkmark.shield",
                               isVisible: $diskSMART)
        } else {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                blockHeader(l10n.s.monitorItemDiskSMART, editing: editing, visible: $diskSMART)
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                    diskTitleRow(disk, showsTags: !featureWorkspacePresentation && !diskUsage)
                    if let smart = disk.smart {
                        smartRows(smart)
                    } else {
                        Text(l10n.s.diskSMARTUnavailable)
                            .font(.hexa(.body))
                            .foregroundStyle(HexaTheme.fgTertiary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func smartRows(_ smart: DiskSMARTReading) -> some View {
        if let status = smart.status {
            smartRow(l10n.s.diskSMARTStatus, status)
        }
        if let written = smart.totalWrittenBytes {
            smartRow(l10n.s.diskTotalWritten, MetricFormat.diskBytesPrecise(written))
        }
        if let read = smart.totalReadBytes {
            smartRow(l10n.s.diskTotalRead, MetricFormat.diskBytesPrecise(read))
        }
        if let temp = smart.temperatureCelsius {
            smartRow(l10n.s.diskTemperature, MetricFormat.temperature(temp, unit: displayTemperatureUnit))
        }
        if let health = smart.healthPercent {
            smartRow(l10n.s.diskHealth, "\(health)%")
        }
        if let cycles = smart.powerCycles {
            smartRow(l10n.s.diskPowerCycles, "\(cycles)")
        }
        if let hours = smart.powerOnHours {
            smartRow(l10n.s.diskPowerOnHours, "\(hours)")
        }
    }

    private func smartRow(_ label: String, _ value: String) -> some View {
        HexaKeyValueRow(label: label, value: value)
    }

    @ViewBuilder
    private func protectionBlock(disk: DiskDeviceReading, editing: Bool) -> some View {
        if !featureWorkspacePresentation && !diskProtection {
            PanelHiddenItemRow(title: l10n.s.monitorItemDiskProtection,
                               systemImage: "eject",
                               isVisible: $diskProtection)
        } else {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                blockHeader(l10n.s.monitorItemDiskProtection, editing: editing, visible: $diskProtection)
                ejectControls(disk: disk)
            }
        }
    }

    /// Eject, eject-all and their caption. The panel protection block and the
    /// workspace tools block render these same controls, so their states match.
    @ViewBuilder
    private func ejectControls(disk: DiskDeviceReading) -> some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            Button {
                protection.eject(disk, aboveIsland: notchPresentation)
            } label: {
                Label(l10n.s.diskEject, hexaIcon: "eject.fill")
                    .font(.hexa(.label))
            }
            .buttonStyle(HexaActionButtonStyle())
            .controlSize(.small)
            .disabled(!disk.canEject || protection.state(for: disk) == .ejecting)

            Button {
                protection.ejectAll(disks)
            } label: {
                Label(l10n.s.diskEjectAll, hexaIcon: "eject.fill")
                    .font(.hexa(.label))
            }
            .buttonStyle(HexaActionButtonStyle())
            .controlSize(.small)
            .disabled(ejectableDisks.isEmpty)
        }
        Text(disk.canEject ? ejectCaption(for: disk) : l10n.s.diskNoExternal)
            .font(.hexa(.label))
            .foregroundStyle(disk.canEject ? ejectCaptionColor(for: disk) : HexaTheme.fgSecondary)
            .lineLimit(2)
    }

    private func ejectCaption(for disk: DiskDeviceReading) -> String {
        switch protection.state(for: disk) {
        case .ejecting: return l10n.s.diskEjecting
        case .ready: return l10n.s.diskReadyToRemove
        case .failed: return l10n.s.diskEjectFailed
        case .none: return l10n.s.diskProtectionCaption
        }
    }

    private func ejectCaptionColor(for disk: DiskDeviceReading) -> Color {
        switch protection.state(for: disk) {
        case .ready: return HexaTheme.statusOk
        case .failed: return HexaTheme.statusDanger
        default: return HexaTheme.fgSecondary
        }
    }

    @ViewBuilder
    private func toolsBlock(disk: DiskDeviceReading, editing: Bool) -> some View {
        if !featureWorkspacePresentation && !diskTools {
            PanelHiddenItemRow(title: l10n.s.monitorItemDiskTools,
                               systemImage: "folder.badge.gearshape",
                               isVisible: $diskTools)
        } else {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                blockHeader(l10n.s.monitorItemDiskTools, editing: editing, visible: $diskTools)
                if featureWorkspacePresentation {
                    Text(MonitorExperienceStrings.localized(l10n.language).diskEject)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgTertiary)
                    ejectControls(disk: disk)
                }
                HStack(spacing: HexaTheme.Spacing.s) {
                    Text(disk.name)
                        .font(.hexa(.label))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button {
                        NSWorkspace.shared.open(URL(fileURLWithPath: disk.mountPath))
                    } label: {
                        Label(l10n.s.diskOpenInFinder, hexaIcon: "folder")
                            .font(.hexa(.label))
                    }
                    .buttonStyle(HexaActionButtonStyle())
                    .controlSize(.small)
                }
                Button {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Storage-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label(l10n.s.diskStorageSettings, hexaIcon: "gearshape")
                        .font(.hexa(.label))
                }
                .buttonStyle(HexaActionButtonStyle())
                .controlSize(.small)
            }
        }
    }

    private func diskTitleRow(_ disk: DiskDeviceReading, showsTags: Bool = true) -> some View {
        HStack(spacing: HexaTheme.Spacing.xs) {
            HexaIcons.image(disk.isInternal ? "internaldrive" : "externaldrive", size: 11)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
            Text(disk.name)
                .font(.hexa(.label))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            if showsTags {
                if let fileSystem = disk.fileSystem {
                    titleTag(fileSystem)
                }
                titleTag(disk.isInternal ? l10n.s.diskInternal : l10n.s.diskExternal)
            }
        }
    }

    private func titleTag(_ text: String) -> some View {
        Text(text)
            .font(.hexa(.micro))
            .foregroundStyle(HexaTheme.fgSecondary)
            .padding(.horizontal, HexaTheme.Spacing.xs)
            .padding(.vertical, 2) // geometria de plataforma (spec §4): ajuste vertical da tag em cápsula
            .background(Capsule().fill(HexaTheme.surfaceInset))
    }

    private func blockHeader(_ title: String, editing: Bool, visible: Binding<Bool>) -> some View {
        HStack(spacing: HexaTheme.Spacing.xs) {
            Text(title)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgTertiary)
            Spacer(minLength: 0)
            if editing {
                PanelInlineHideButton(isVisible: visible)
            }
        }
    }

    private var displayTemperatureUnit: TemperatureUnit {
        TemperatureUnit(rawValue: temperatureUnit) ?? .celsius
    }
}
