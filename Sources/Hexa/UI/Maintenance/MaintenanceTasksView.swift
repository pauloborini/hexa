// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import SwiftUI

struct MaintenanceTasksView: View {
    @ObservedObject private var service = MaintenanceTasksService.shared
    @ObservedObject private var l10n = L10n.shared
    /// Execução que inclui tarefa destrutiva, à espera da confirmação.
    @State private var pendingRun: PendingRun?

    private struct PendingRun {
        let tasks: [MaintenanceTaskID]
        let batch: Bool
    }

    private var strings: MaintenanceTasksFeatureStrings { FeatureStrings.maintenanceTasks(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.l) {
            summaryRow
                .padding(.bottom, HexaTheme.Spacing.s)
            tasksList
            footerActions
        }
        .padding(.horizontal, HexaTheme.Spacing.xxl)
        .onAppear {
            service.refreshLocalSnapshots()
        }
        .alert(strings.confirmRunTitle,
               isPresented: Binding(get: { pendingRun != nil },
                                    set: { if !$0 { pendingRun = nil } }),
               presenting: pendingRun) { run in
            Button(l10n.s.uninstallerCancel, role: .cancel) {}
            Button(strings.executeButton, role: .destructive) {
                if run.batch {
                    service.runSelected()
                } else if let id = run.tasks.first {
                    service.runTask(id)
                }
            }
        } message: { run in
            Text(run.tasks.compactMap { id in
                taskEffect(for: id).map { taskTitle(for: id) + ": " + $0 }
            }.joined(separator: "\n\n"))
        }
    }

    /// Roda direto o que não apaga dados; o resto passa pela confirmação.
    private func request(_ tasks: [MaintenanceTaskID], batch: Bool) {
        if tasks.contains(where: \.isDestructive) {
            pendingRun = PendingRun(tasks: tasks, batch: batch)
        } else if batch {
            service.runSelected()
        } else if let id = tasks.first {
            service.runTask(id)
        }
    }

    private var summaryRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: HexaTheme.Spacing.s) {
            Text(lastAnalysisLine)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)

            Spacer(minLength: 0)

            Button {
                service.reanalyze()
            } label: {
                Label(strings.reanalyzeButton, hexaIcon: "arrow.clockwise")
                    .font(.hexa(.body))
            }
            .buttonStyle(HexaActionButtonStyle())
            .controlSize(.small)
            .disabled(service.isRunning)
        }
    }

    private var lastAnalysisLine: String {
        guard let last = service.lastAnalysis else { return strings.neverAnalyzed }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        return String(format: strings.lastAnalysisFormat,
                      formatter.localizedString(for: last, relativeTo: Date()))
    }

    private var tasksList: some View {
        VStack(spacing: HexaTheme.Spacing.s) {
            ForEach(service.items) { item in
                taskRow(item)
            }
        }
    }

    private func taskRow(_ item: MaintenanceTaskItem) -> some View {
        HexaCard {
            HStack(alignment: .center, spacing: HexaTheme.Spacing.m) {
                Toggle("", isOn: Binding(
                    get: { item.isSelected },
                    set: { _ in service.toggleSelection(for: item.id) }
                ))
                .labelsHidden()
                .toggleStyle(.checkbox)
                .disabled(service.isRunning)
                .accessibilityLabel(taskTitle(for: item.id))

                HexaIcons.image(item.id.symbolName, size: HexaIconMetrics.standard)
                    .foregroundStyle(HexaTheme.fgPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: HexaTheme.Spacing.xs) {
                        Text(taskTitle(for: item.id))
                            .font(.hexa(.body))
                            .foregroundStyle(HexaTheme.fgPrimary)

                        infoButton(for: item.id)
                    }

                    if item.id == .freePurgeable {
                        // O efeito fica visível também depois de medir o espaço.
                        HStack(spacing: HexaTheme.Spacing.xs) {
                            if item.detail == nil, service.isReadingLocalSnapshots {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(HexaTheme.fgSecondary)
                                    .accessibilityLabel(l10n.s.loadingMessage)
                            }
                            Text([item.detail, taskDescription(for: item.id)].compactMap { $0 }.joined(separator: " · "))
                                .font(.hexa(.label))
                                .foregroundStyle(HexaTheme.fgSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        Text(taskDescription(for: item.id))
                            .font(.hexa(.label))
                            .foregroundStyle(HexaTheme.fgSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                statusOrActionView(item)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func statusOrActionView(_ item: MaintenanceTaskItem) -> some View {
        switch item.status {
        case .idle:
            Button(action: { request([item.id], batch: false) }) {
                Text(strings.executeButton)
            }
            .buttonStyle(HexaActionButtonStyle(variant: .secondary))
            .controlSize(.small)
            .disabled(service.isRunning)

        case .running:
            ProgressView()
                .controlSize(.small)
                .tint(HexaTheme.fgSecondary)

        case .success:
            HexaStateTag(taskSuccessLabel(for: item.id), kind: .ok)

        case .failure:
            HexaStateTag(strings.statusFailed, kind: .danger)

        case .cancelled:
            HexaStateTag(strings.statusCancelled, kind: .warning)

        case .nothingFreed:
            HexaStateTag(strings.statusNothingFreed, kind: .warning)
        }
    }

    private func infoButton(for id: MaintenanceTaskID) -> some View {
        HexaIcons.image("info.circle", size: HexaIconMetrics.small)
            .foregroundStyle(HexaTheme.fgTertiary)
            .help(taskTooltip(for: id))
    }

    private var footerActions: some View {
        HStack {
            let selectedCount = service.items.filter(\.isSelected).count
            Text(String(format: strings.selectedCountFormat, selectedCount, service.items.count))
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)

            Spacer()

            if service.isRunning {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, HexaTheme.Spacing.s)
            }

            if service.isRunningBatch {
                Button(action: { service.stopAfterCurrent() }) {
                    Text(strings.stopButton)
                }
                .buttonStyle(HexaActionButtonStyle(variant: .secondary))
                .disabled(service.stopRequested)
            }

            Button(action: { request(service.items.filter(\.isSelected).map(\.id), batch: true) }) {
                Text(strings.runSelectedButton)
            }
            .buttonStyle(HexaActionButtonStyle(variant: .primary))
            .disabled(service.isRunning || selectedCount == 0)
        }
    }

    private func taskSuccessLabel(for id: MaintenanceTaskID) -> String {
        switch id {
        case .flushDNS:
            return strings.statusDNSFlushed
        case .freePurgeable:
            return strings.statusPurgeableFreed
        case .purgeInactiveMemory:
            return strings.statusMemoryFreed
        case .rebuildLaunchServices:
            return strings.statusLaunchServicesRebuilt
        case .rebuildSpotlight:
            return strings.statusSpotlightReindexed
        case .cleanupHomebrew:
            return strings.statusHomebrewCleaned
        }
    }

    private func taskTitle(for id: MaintenanceTaskID) -> String {
        switch id {
        case .flushDNS:
            return strings.taskFlushDNSTitle
        case .freePurgeable:
            return strings.taskFreePurgeableTitle
        case .purgeInactiveMemory:
            return strings.taskPurgeMemoryTitle
        case .rebuildLaunchServices:
            return strings.taskLaunchServicesTitle
        case .rebuildSpotlight:
            return strings.taskSpotlightTitle
        case .cleanupHomebrew:
            return strings.taskHomebrewCleanupTitle
        }
    }

    private func taskDescription(for id: MaintenanceTaskID) -> String {
        switch id {
        case .flushDNS:
            return strings.taskFlushDNSDesc
        case .freePurgeable:
            return strings.effectFreePurgeable
        case .purgeInactiveMemory:
            return strings.taskPurgeMemoryDesc
        case .rebuildLaunchServices:
            return strings.taskLaunchServicesDesc
        case .rebuildSpotlight:
            return strings.taskSpotlightDesc
        case .cleanupHomebrew:
            return strings.taskHomebrewCleanupDesc
        }
    }

    private func taskEffect(for id: MaintenanceTaskID) -> String? {
        switch id {
        case .freePurgeable:
            return strings.effectFreePurgeable
        case .rebuildSpotlight:
            return strings.effectSpotlight
        case .cleanupHomebrew:
            return strings.effectHomebrew
        case .flushDNS, .purgeInactiveMemory, .rebuildLaunchServices:
            return nil
        }
    }

    private func taskTooltip(for id: MaintenanceTaskID) -> String {
        switch id {
        case .flushDNS:
            return strings.taskFlushDNSTooltip
        case .freePurgeable:
            return strings.taskFreePurgeableTooltip
        case .purgeInactiveMemory:
            return strings.taskPurgeMemoryTooltip
        case .rebuildLaunchServices:
            return strings.taskLaunchServicesTooltip
        case .rebuildSpotlight:
            return strings.taskSpotlightTooltip
        case .cleanupHomebrew:
            return strings.taskHomebrewCleanupTooltip
        }
    }
}
