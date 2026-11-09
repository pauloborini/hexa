// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

struct PortManagerView: View {
    @ObservedObject private var service = PortManagerService.shared
    @State private var pending: PortManagerEntry?
    @State private var force = false
    @State private var refreshTimer: Timer?
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.controlActiveState) private var controlActiveState

    private var strings: PortManagerFeatureStrings { FeatureStrings.portManager(l10n.language) }

    /// Why a row cannot be terminated from this page. Rendered as a tag next to
    /// the port and as the tooltip of the actions that are therefore disabled.
    private enum RowBlock {
        case identityUnavailable
        case systemProtected
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            HairlineDivider()
            // A failed snapshot keeps the previous rows, so the page says the
            // list is stale instead of silently showing older data.
            if service.refreshFailed && !service.entries.isEmpty {
                failureBanner
            }
            if service.filteredEntries.isEmpty {
                if !service.hasLoadedOnce {
                    if service.refreshFailed {
                        failureState
                    } else {
                        loadingState
                    }
                } else if service.refreshFailed && service.entries.isEmpty {
                    // The last good snapshot was empty and the new read failed:
                    // saying "no ports" here would report a failed read as a fact.
                    failureState
                } else {
                    emptyState
                }
            } else {
                OverlayScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(service.filteredEntries) { entry in portRow(entry) }
                    }
                    .padding(.horizontal, HexaTheme.Spacing.l)
                    .padding(.bottom, HexaTheme.Spacing.pageGap)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            service.refresh()
            updateTimer(for: controlActiveState)
        }
        // A failure that lands after the page closed is dropped, not shown later.
        .onDisappear {
            stopTimer()
            service.terminateFailed = false
        }
        .onChange(of: controlActiveState) { _, newValue in
            updateTimer(for: newValue)
        }
        .alert(pending.map { String(format: strings.terminateFormat, $0.processName) } ?? "",
               isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })) {
            Button(l10n.s.uninstallerCancel, role: .cancel) { pending = nil }
            Button(force ? strings.forceKill : strings.kill, role: .destructive) {
                if let pending { service.terminate(pending, force: force) }
                pending = nil
            }
        } message: {
            Text(String(format: strings.terminateMessageFormat,
                        pending?.port ?? 0, pending?.pid ?? 0))
        }
        .alert(FeatureStrings.killProcess(l10n.language).killFailedTitle,
               isPresented: $service.terminateFailed) {
            Button(l10n.s.buttonOK) {}
        } message: {
            Text(FeatureStrings.killProcess(l10n.language).killFailedMessage)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            HStack(spacing: HexaTheme.Spacing.s) {
                HexaIcons.image("magnifyingglass").foregroundStyle(HexaTheme.fgSecondary)
                TextField(strings.filter, text: $service.query).textFieldStyle(.plain)
                Spacer(minLength: 0)
                Text(String(format: strings.openFormat, service.filteredEntries.count))
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(HexaTheme.Spacing.s)
            .background(HexaTheme.surfaceInset, in: RoundedRectangle(cornerRadius: HexaTheme.Radius.control))

            // lsof runs without privilege, so the list only holds this user's TCP
            // listeners. Stated once here instead of on every row.
            Text(strings.scopeNote)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let lastUpdatedText {
                Text(lastUpdatedText)
                    .font(.hexa(.micro))
                    .foregroundStyle(HexaTheme.fgTertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, HexaTheme.Spacing.l)
        .padding(.top, HexaTheme.Spacing.l)
        .padding(.bottom, HexaTheme.Spacing.s)
    }

    private var lastUpdatedText: String? {
        guard let date = service.lastRefreshedAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: l10n.language.rawValue)
        formatter.unitsStyle = .short
        return String(format: strings.updatedFormat,
                      formatter.localizedString(for: date, relativeTo: Date()))
    }

    // MARK: States

    private var failureBanner: some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            Label(strings.loadFailed, hexaIcon: "exclamationmark.triangle")
                .font(.hexa(.body)).foregroundStyle(HexaTheme.fgSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(strings.refresh) { service.refresh() }
                .buttonStyle(HexaActionButtonStyle())
                .controlSize(.small)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(HexaTheme.Spacing.m)
    }

    private var failureState: some View {
        VStack(spacing: HexaTheme.Spacing.s) {
            HexaIcons.image("exclamationmark.triangle", size: 25)
                .foregroundStyle(HexaTheme.fgTertiary)
            HexaStatusNote(message: strings.loadFailed, icon: nil, tone: .neutral)
                .multilineTextAlignment(.center)
            Button(strings.refresh) { service.refresh() }
                .buttonStyle(HexaActionButtonStyle())
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: HexaTheme.Spacing.s) {
            HexaIcons.image("network.slash", size: 25).foregroundStyle(HexaTheme.fgTertiary)
            Text(strings.empty).font(.hexa(.body)).foregroundStyle(HexaTheme.fgSecondary)
            Text(strings.emptyHint).font(.hexa(.label)).foregroundStyle(HexaTheme.fgTertiary)
            if !service.query.isEmpty {
                Button(strings.clearSearch) { service.query = "" }
                    .buttonStyle(HexaActionButtonStyle())
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingState: some View {
        HexaBusyState(variant: .compact, message: l10n.s.loadingMessage)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Rows

    private func portRow(_ entry: PortManagerEntry) -> some View {
        let block = blockReason(for: entry)
        return HStack(spacing: HexaTheme.Spacing.s) {
            HexaIcons.image("network", size: 11)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgPrimary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                HStack(spacing: HexaTheme.Spacing.xs) {
                    Text("\(entry.port)")
                        .font(.hexa(.body))
                    if let block {
                        HexaStateTag(block == .identityUnavailable ? strings.tagIdentityUnavailable
                                                                   : strings.tagSystemProtected,
                                     kind: .neutral)
                            .help(reasonHelp(for: entry))
                    }
                    if PortManagerSupport.listensOnAllInterfaces(entry.address) {
                        PortManagerAllInterfacesBadge(strings: strings)
                    }
                }
                Text(entry.processName)
                    .font(.hexa(.label))
                    .lineLimit(1)
                Text(strings.pidAddress(pid: entry.pid, address: entry.address))
                    .font(.hexa(.micro))
                    .foregroundStyle(HexaTheme.fgTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 4)
            if AppFeature.killProcess.isAvailable {
                HStack(spacing: HexaTheme.Spacing.xs) {
                    Button(strings.kill) { force = false; pending = entry }
                        .disabled(block != nil)
                        .help(reasonHelp(for: entry))
                    Menu {
                        Button(strings.forceKill) { force = true; pending = entry }
                            .disabled(block != nil)
                        Divider()
                        PortManagerRowActions(entry: entry, language: l10n.language)
                    } label: {
                        HexaIcons.image("ellipsis")
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(minWidth: 44)
                    .help(reasonHelp(for: entry))
                    .accessibilityLabel(String(format: strings.rowActionsFormat, entry.processName))
                }
                .buttonStyle(HexaActionButtonStyle())
                .controlSize(.small)
                .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.vertical, HexaTheme.Spacing.xs)
        .contentShape(Rectangle())
        .contextMenu {
            PortManagerRowActions(entry: entry, language: l10n.language)
        }
    }

    /// A row is blocked when it has no identity to verify at termination or when
    /// the process is one of the system's own critical processes.
    private func blockReason(for entry: PortManagerEntry) -> RowBlock? {
        if entry.identityUnavailable { return .identityUnavailable }
        if KillProcessService.isProtected(pid: entry.pid, name: entry.processName) { return .systemProtected }
        return nil
    }

    /// Tooltip for the actions blocked by `blockReason(for:)`, and empty when the
    /// row can be terminated.
    private func reasonHelp(for entry: PortManagerEntry) -> String {
        guard let block = blockReason(for: entry) else { return "" }
        switch block {
        case .identityUnavailable: return strings.helpIdentityUnavailable
        case .systemProtected: return strings.helpSystemProtected
        }
    }

    // MARK: Freshness

    /// Ticks only while this page is open AND its window is active, so the list
    /// reads live without polling `lsof` in the background. The interval is the
    /// service's own freshness interval, so every tick does real work.
    private func updateTimer(for state: ControlActiveState) {
        guard state != .inactive else {
            stopTimer()
            return
        }
        guard refreshTimer == nil else { return }
        service.refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: PortManagerService.automaticRefreshInterval,
                                            repeats: true) { _ in
            service.refresh()
        }
    }

    private func stopTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

struct PortManagerRowActions: View {
    let entry: PortManagerEntry
    let language: AppLanguage

    var body: some View {
        let strings = FeatureStrings.portManager(language)
        Button(strings.copyPort) { copy(String(entry.port)) }
        Button(FeatureStrings.killProcess(language).copyPID) { copy(String(entry.pid)) }
        Button(strings.copyAddress) { copy(entry.address) }
        if let url = PortManagerSupport.browserURL(for: entry) {
            Divider()
            Button(strings.openInBrowser) {
                if !NSWorkspace.shared.open(url) { NSSound.beep() }
            }
        }
    }

    private func copy(_ value: String) {
        GeneralPasteboardAccess.shared.async({
            NSPasteboard.general.clearContents()
            return NSPasteboard.general.setString(value, forType: .string)
        }, then: { copied in
            if !copied { NSSound.beep() }
        })
    }
}

/// Marks a listener bound to every interface, so the rows other machines on the
/// network may reach stand out from the local-only ones. Local rows stay unmarked.
struct PortManagerAllInterfacesBadge: View {
    let strings: PortManagerFeatureStrings
    var showsLabel = true

    var body: some View {
        if showsLabel {
            HexaStateTag(strings.allInterfaces, kind: .warning)
                .help(strings.allInterfacesHelp)
        } else {
            // Panel rows have no room for the label: the icon carries the mark
            // and the full text stays in the tooltip and the accessibility label.
            HexaIcons.image("exclamationmark", size: 11)
                .foregroundStyle(HexaTheme.fgSecondary)
                .help(strings.allInterfacesHelp)
                .accessibilityLabel(Text(strings.allInterfaces))
        }
    }
}
