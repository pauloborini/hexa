// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import SwiftUI

/// Kill Process, embedded as a Settings page: a live, searchable list of
/// every running process with kill, force-kill, kill-all, kill-tree, and
/// restart actions.
struct KillProcessView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = KillProcessService.shared
    @Environment(\.controlActiveState) private var controlActiveState
    @State private var refreshTimer: Timer?
    @State private var pendingAction: PendingAction?
    /// Row order captured while the pointer is over the list. A refresh every
    /// three seconds would otherwise reorder rows under the pointer and make
    /// the action the user is about to click land on another process. Only
    /// the order is frozen; the CPU and memory values stay live.
    @State private var frozenOrder: [pid_t] = []

    private var strings: KillProcessFeatureStrings { FeatureStrings.killProcess(l10n.language) }

    private enum PendingAction {
        case kill(KillProcessEntry, force: Bool)
        case killAll(name: String, force: Bool)
        case killGroup(KillProcessEntry)
        case killTree(KillProcessEntry, force: Bool)
        case restart(KillProcessEntry)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            HairlineDivider()
            if service.refreshFailed && service.hasLoadedOnce {
                staleNote
            }
            columnHeader
            HairlineDivider()
            list
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            service.refresh(force: true)
            updateTimer(for: controlActiveState)
        }
        .onDisappear { stopTimer() }
        .onChange(of: controlActiveState) { _, newValue in
            updateTimer(for: newValue)
        }
        // Any input that redefines the list releases the frozen order, so the
        // new result set appears at once instead of waiting for the pointer.
        .onChange(of: service.query) { _, _ in frozenOrder = [] }
        .onChange(of: service.filterScope) { _, _ in frozenOrder = [] }
        .onChange(of: service.sortBy) { _, _ in frozenOrder = [] }
        .onChange(of: service.sortAscending) { _, _ in frozenOrder = [] }
        .onChange(of: service.groupRelated) { _, _ in frozenOrder = [] }
        .alert(alertTitle,
               isPresented: Binding(get: { pendingAction != nil }, set: { if !$0 { pendingAction = nil } }),
               presenting: pendingAction) { action in
            Button(l10n.s.uninstallerCancel, role: .cancel) {}
            Button(confirmButtonTitle(action), role: .destructive) {
                perform(action)
                pendingAction = nil
            }
        } message: { action in
            Text(alertMessage(for: action))
        }
        .alert(service.errorAlert?.title ?? "",
               isPresented: Binding(
                   get: { service.errorAlert != nil },
                   set: { if !$0 { service.errorAlert = nil } }
               )) {
            Button(l10n.s.buttonOK) {
                service.errorAlert = nil
            }
        } message: {
            Text(service.errorAlert?.message ?? "")
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.m) {
            HStack(spacing: HexaTheme.Spacing.s) {
                HexaIcons.image("magnifyingglass").foregroundStyle(HexaTheme.fgSecondary)
                TextField(strings.searchPlaceholder, text: $service.query)
                    .textFieldStyle(.plain)
                    .layoutPriority(1)
                Spacer(minLength: HexaTheme.Spacing.s)
                Text(countText)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(HexaTheme.Spacing.s)
            .background(HexaTheme.surfaceInset, in: RoundedRectangle(cornerRadius: HexaTheme.Radius.control))

            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                Text(strings.optionsTitle)
                    .font(.hexa(.micro))
                    .foregroundStyle(HexaTheme.accentText)
                HStack(spacing: HexaTheme.Spacing.s) {
                    HexaSegmentControl([(KillProcessService.ProcessFilterScope.all, strings.filterAll),
                                        (KillProcessService.ProcessFilterScope.apps, strings.filterApps)],
                                       selection: scopeBinding)
                    Spacer(minLength: HexaTheme.Spacing.s)
                    Toggle(strings.groupToggle, isOn: groupBinding)
                        .toggleStyle(TrailingSwitchToggleStyle())
                        .help(strings.groupCaption)
                }
            }

            // Replaces the spinner that used to sit in the search field: a
            // timestamp says how old the frozen snapshot really is.
            if let lastUpdatedText {
                Text(lastUpdatedText)
                    .font(.hexa(.micro))
                    .foregroundStyle(HexaTheme.fgTertiary)
            }
        }
        .padding(HexaTheme.Spacing.l)
    }

    /// Counts what the list actually shows: groups when grouping is on, so the
    /// number matches the rows instead of the hidden helpers inside them.
    private var countText: String {
        let format = service.groupRelated ? strings.groupCountFormat : strings.processCountFormat
        return String(format: format, service.filteredEntries.count)
    }

    private var lastUpdatedText: String? {
        guard let date = service.lastRefreshedAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: l10n.language.rawValue)
        formatter.unitsStyle = .short
        return String(format: strings.updatedFormat, formatter.localizedString(for: date, relativeTo: Date()))
    }

    private var scopeBinding: Binding<KillProcessService.ProcessFilterScope> {
        Binding(
            get: { service.filterScope },
            set: { service.setFilterScope($0) }
        )
    }

    private var groupBinding: Binding<Bool> {
        Binding(get: { service.groupRelated }, set: { service.setGroupRelated($0) })
    }

    // MARK: Column header

    /// Shared widths keep each heading aligned with its data and action column.
    private var processColumns: [GridItem] {
        let gap = HexaTheme.Spacing.s
        return [
            GridItem(.flexible(minimum: 140), spacing: gap, alignment: .leading),
            GridItem(.fixed(52), spacing: gap, alignment: .trailing),
            GridItem(.fixed(72), spacing: gap, alignment: .trailing),
            GridItem(.fixed(56), spacing: gap, alignment: .trailing),
            GridItem(.flexible(minimum: 152, maximum: 176), alignment: .trailing)
        ]
    }

    private var columnHeader: some View {
        LazyVGrid(columns: processColumns, alignment: .leading, spacing: 0) {
            HStack(spacing: HexaTheme.Spacing.s) {
                Color.clear.frame(width: 22, height: 1)
                columnHeaderButton(strings.columnProcess, column: .name, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            columnHeaderButton(strings.columnCPU, column: .cpu)
            columnHeaderButton(strings.columnMemory, column: .memory)
            columnHeaderButton(strings.columnPID, column: .pid)
            Color.clear.frame(maxWidth: .infinity).frame(height: 1).accessibilityHidden(true)
        }
        .padding(.horizontal, HexaTheme.Spacing.l)
        .padding(.vertical, HexaTheme.Spacing.xs)
    }

    private func columnHeaderButton(
        _ title: String,
        column: KillProcessService.SortBy,
        alignment: Alignment = .trailing
    ) -> some View {
        Button {
            service.toggleSort(column)
        } label: {
            HStack(spacing: HexaTheme.Spacing.xs) {
                Text(title)
                if service.sortBy == column {
                    HexaIcons.image(service.sortAscending ? "chevron.up" : "chevron.down", size: 10)
                        .font(.hexa(.micro))
                }
            }
            .frame(maxWidth: .infinity, alignment: alignment)
        }
        .buttonStyle(.plain)
        .font(.hexa(.label))
        .foregroundStyle(HexaTheme.fgSecondary)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(sortDirectionText(for: column)))
        .accessibilityAddTraits(service.sortBy == column ? .isSelected : [])
    }

    /// Read only for the active column: the direction of a column that is not
    /// sorting anything is not a state worth announcing.
    private func sortDirectionText(for column: KillProcessService.SortBy) -> String {
        guard service.sortBy == column else { return "" }
        return service.sortAscending ? strings.sortAscending : strings.sortDescending
    }

    // MARK: List

    @ViewBuilder
    private var list: some View {
        if !service.hasLoadedOnce && service.refreshFailed {
            // Nothing to keep showing yet, so the failure takes the page
            // instead of a spinner that would never stop.
            loadFailureState
        } else if service.filteredEntries.isEmpty {
            // A transient ps hiccup no longer clears `entries` (KillProcessService
            // keeps the last good snapshot), so an empty list here means either
            // the very first load hasn't landed yet, or a search genuinely
            // matched nothing - two different messages, not one.
            if service.hasLoadedOnce {
                emptyState
            } else {
                loadingState
            }
        } else {
            OverlayScrollView {
                LazyVGrid(columns: processColumns, alignment: .leading, spacing: 0) {
                    ForEach(listEntries) { entry in row(entry) }
                }
                .padding(.horizontal, HexaTheme.Spacing.l)
                .padding(.bottom, HexaTheme.Spacing.pageGap)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onHover { hovering in
                frozenOrder = hovering ? service.filteredEntries.map(\.id) : []
            }
        }
    }

    /// Rows in the order the pointer saw them while the pointer is inside the
    /// list; the live order otherwise.
    private var listEntries: [KillProcessEntry] {
        guard !frozenOrder.isEmpty else { return service.filteredEntries }
        let rank = Dictionary(uniqueKeysWithValues: frozenOrder.enumerated().map { ($1, $0) })
        return service.filteredEntries.sorted { lhs, rhs in
            let left = rank[lhs.id] ?? Int.max
            let right = rank[rhs.id] ?? Int.max
            // PIDs break ties so a row that appeared mid-hover still lands in
            // a deterministic place instead of wherever the sort put it.
            if left != right { return left < right }
            return lhs.id < rhs.id
        }
    }

    private var emptyState: some View {
        VStack(spacing: HexaTheme.Spacing.s) {
            HexaIcons.image("magnifyingglass", size: 25).foregroundStyle(HexaTheme.fgTertiary)
            Text(strings.emptyStateTitle).font(.hexa(.body)).foregroundStyle(HexaTheme.fgSecondary)
            Text(strings.emptyStateHint).font(.hexa(.label)).foregroundStyle(HexaTheme.fgTertiary)
            if !service.query.isEmpty {
                Button(strings.clearSearch) { service.query = "" }
                    .buttonStyle(HexaActionButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadFailureState: some View {
        VStack(spacing: HexaTheme.Spacing.m) {
            HexaIcons.image("exclamationmark.triangle", size: 25).foregroundStyle(HexaTheme.fgTertiary)
            HexaStatusNote(message: strings.loadFailed, icon: nil, tone: .neutral)
            Button(strings.retryLoad) { service.refresh(force: true) }
                .buttonStyle(HexaActionButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// A failure after a good snapshot keeps the rows on screen and says they
    /// are old, instead of blanking a list the user is still reading.
    private var staleNote: some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            HexaStatusNote(message: strings.loadFailed, icon: "exclamationmark.triangle", tone: .neutral)
            Spacer(minLength: HexaTheme.Spacing.s)
            Button(strings.retryLoad) { service.refresh(force: true) }
                .buttonStyle(HexaActionButtonStyle())
                .controlSize(.small)
        }
        .padding(.horizontal, HexaTheme.Spacing.l)
        .padding(.vertical, HexaTheme.Spacing.s)
    }

    private var loadingState: some View {
        HexaBusyState(variant: .compact, message: l10n.s.loadingMessage)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func row(_ entry: KillProcessEntry) -> some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            Image(nsImage: ResponsibleProcess.icon(for: entry.pid))
                .resizable().frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                HStack(spacing: HexaTheme.Spacing.xs) {
                    Text(entry.name).font(.hexa(.body)).lineLimit(1).truncationMode(.middle)
                    if entry.groupedCount > 1 {
                        Text(String(format: strings.groupBadgeFormat, entry.groupedCount))
                            .font(.hexa(.label)).foregroundStyle(HexaTheme.fgTertiary)
                            .lineLimit(1).fixedSize(horizontal: true, vertical: false)
                    }
                    // Why the row is locked, in the row itself: a greyed button
                    // alone does not tell the user what to do next.
                    if let reason = entry.protectionReason {
                        HexaStateTag(reason == .systemProcess
                                     ? strings.tagSystemProtected
                                     : strings.tagIdentityUnavailable,
                                     kind: .neutral)
                            .fixedSize()
                            .help(reason == .systemProcess
                                  ? strings.helpSystemProtected
                                  : strings.helpIdentityUnavailable)
                    }
                }
                Text(entry.path)
                    .font(.hexa(.label)).foregroundStyle(HexaTheme.fgTertiary)
                    .lineLimit(1).truncationMode(.head)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2) // geometria de plataforma (spec §4): respiro de linha com controle small

        dataCell(String(format: "%.1f%%", locale: MetricFormat.locale, entry.cpuPercent))
        dataCell(MetricFormat.bytes(UInt64(max(0, entry.memoryBytes))))
        dataCell(String(entry.pid))

        HStack(spacing: HexaTheme.Spacing.s) {
            Button(strings.killButton) {
                pendingAction = .kill(entry, force: false)
            }
            .frame(minWidth: 44)
            .disabled(entry.isProtected)
            .help(reasonHelp(for: entry))
            Menu {
                Button(strings.forceKillButton) { pendingAction = .kill(entry, force: true) }
                    .disabled(entry.isProtected)
                    .help(reasonHelp(for: entry))
                if entry.groupedCount > 1 {
                    Button(strings.killGroupButton) { pendingAction = .killGroup(entry) }
                        .disabled(entry.isProtected)
                } else {
                    Button(String(format: strings.killAllFormat, entry.name)) {
                        pendingAction = .killAll(name: entry.name, force: false)
                    }
                    .disabled(entry.isProtected)
                }
                Button(strings.killTreeButton) { pendingAction = .killTree(entry, force: false) }
                    .disabled(entry.isProtected)
                if service.canRestart(entry) {
                    Button(strings.restartButton) { pendingAction = .restart(entry) }
                }
                Divider()
                Button(strings.copyPID) { copy(String(entry.pid)) }
                Button(strings.copyPath) { copy(entry.path) }
            } label: {
                HexaIcons.image("ellipsis")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(minWidth: 44)
            .accessibilityLabel(String(format: strings.rowActionsFormat, entry.name))
        }
        .buttonStyle(HexaActionButtonStyle())
        .controlSize(.small)
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.vertical, 2) // geometria de plataforma (spec §4): respiro de linha com controle small
    }

    private func dataCell(_ value: String) -> some View {
        Text(value)
            .font(.hexa(.data))
            .foregroundStyle(HexaTheme.fgSecondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.vertical, 2)
    }

    /// Tooltip for a disabled control: empty when the row is free to signal.
    private func reasonHelp(for entry: KillProcessEntry) -> String {
        switch entry.protectionReason {
        case .systemProcess: return strings.helpSystemProtected
        case .identityUnavailable: return strings.helpIdentityUnavailable
        case nil: return ""
        }
    }

    // MARK: Confirmation

    private var alertTitle: String {
        guard let pendingAction else { return "" }
        switch pendingAction {
        case let .kill(entry, force):
            return String(format: force ? strings.confirmForceKillFormat : strings.confirmKillFormat, entry.name)
        case let .killAll(name, _):
            return String(format: strings.confirmKillAllFormat, name)
        case let .killGroup(entry):
            return String(format: strings.confirmKillGroupFormat, entry.groupedCount, entry.name)
        case let .killTree(entry, _):
            return String(format: strings.confirmKillTreeFormat, entry.name)
        case let .restart(entry):
            return String(format: strings.confirmRestartFormat, entry.name)
        }
    }

    private func alertMessage(for action: PendingAction) -> String {
        switch action {
        case let .kill(entry, _):
            // A grouped row signals only its owner; the helpers folded into it
            // are not ended, which the row alone does not make clear.
            guard entry.groupedCount > 1 else { return entry.path }
            let note = String(format: strings.groupedKillNoteFormat, entry.name, entry.groupedCount - 1)
            return entry.path + "\n\n" + note
        case let .killGroup(entry):
            // The group action is the one that really reaches the helpers, so
            // it says so instead of leaving the count to the title alone.
            let note = String(format: strings.groupKillMessageFormat, entry.groupedCount - 1)
            return entry.path + "\n\n" + note
        case let .killTree(entry, _): return entry.path
        case let .restart(entry): return entry.path
        case .killAll: return ""
        }
    }

    private func confirmButtonTitle(_ action: PendingAction) -> String {
        switch action {
        case let .kill(_, force): return force ? strings.forceKillButton : strings.killButton
        case .killAll: return strings.killButton
        case .killGroup: return strings.killGroupButton
        case .killTree: return strings.killTreeButton
        case .restart: return strings.restartButton
        }
    }

    private func perform(_ action: PendingAction) {
        switch action {
        case let .kill(entry, force): service.kill(entry, force: force)
        case let .killAll(name, force): service.killAll(named: name, force: force)
        case let .killGroup(entry): service.killGroup(entry, force: false)
        case let .killTree(entry, force): service.killTree(entry, force: force)
        case let .restart(entry): service.restart(entry)
        }
    }

    // MARK: Helpers

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    /// Ticks only while this page is open AND its window is key, so the
    /// CPU/memory columns read live without polling `ps` in the background -
    /// neither while some other Settings page is showing, nor while this one
    /// is open but not the focused window.
    /// The interval matches the service's own freshness cache exactly, so
    /// every tick does real work instead of a third of them being no-ops.
    private func updateTimer(for state: ControlActiveState) {
        guard state != .inactive else {
            stopTimer()
            return
        }
        guard refreshTimer == nil else { return }
        service.refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            service.refresh()
        }
    }

    private func stopTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
