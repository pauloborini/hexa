// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

struct PanelPortManagerView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = PortManagerService.shared
    @Environment(\.notchPresentation) private var inNotch
    @State private var pending: PortManagerEntry?
    @State private var force = false

    var onClose: () -> Void

    private var strings: PortManagerFeatureStrings { FeatureStrings.portManager(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            header
            controls
            if service.refreshFailed {
                Label(strings.loadFailed, hexaIcon: "exclamationmark.triangle")
                    .font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .panelCard()
            }
            entriesList
        }
        .onAppear {
            PanelInteractionState.shared.viewKeepsPopoverOpen = true
            service.refresh()
        }
        .onDisappear {
            PanelInteractionState.shared.viewKeepsPopoverOpen = false
            dismissTermination()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .alert(pending.map { String(format: strings.terminateFormat, $0.processName) } ?? "",
               isPresented: terminationConfirmationPresented) {
            Button(l10n.s.uninstallerCancel, role: .cancel) { dismissTermination() }
            Button(force ? strings.forceKill : strings.kill, role: .destructive) {
                if let pending { service.terminate(pending, force: force) }
                dismissTermination()
            }
        } message: {
            Text(String(format: strings.terminateMessageFormat,
                        pending?.port ?? 0, pending?.pid ?? 0))
        }
    }

    private var header: some View {
        HexaPanelHeader(title: strings.title, icon: "network") {
            HexaIconButton(icon: "gearshape",
                           label: l10n.s.menuSettings,
                           variant: .small) {
                SettingsRouter.shared.page = .portManager
                FeatureWorkspaceWindow.shared.show(.portManager)
            }
            .help(l10n.s.menuSettings)
            HexaIconButton(icon: "xmark.circle.fill",
                           label: l10n.s.uninstallerCancel,
                           variant: .small,
                           action: onClose)
            .help(l10n.s.uninstallerCancel)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            HStack {
                Text(strings.listeningCaption)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                Spacer()
                HexaIconButton(icon: "arrow.clockwise",
                               label: strings.refresh,
                               variant: .small) {
                    service.refresh()
                }
                .help(strings.refresh)
            }
            HStack(spacing: HexaTheme.Spacing.s) {
                HexaIcons.image("magnifyingglass").foregroundStyle(HexaTheme.fgSecondary)
                TextField(strings.filter, text: $service.query)
                    .textFieldStyle(.plain)
                    .font(.hexa(.label))
                Spacer(minLength: 0)
                Text(String(format: strings.openFormat, service.filteredEntries.count))
                    .font(.hexa(.micro))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(HexaTheme.Spacing.s)
            .background(HexaTheme.surfaceInset, in: RoundedRectangle(cornerRadius: HexaTheme.Radius.control))
            // Mesmo escopo declarado na página de workspace: lsof sem privilégio
            // lista só os listeners TCP do usuário atual.
            Text(strings.scopeNote)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .panelCard()
    }

    @ViewBuilder
    private var entriesList: some View {
        if service.filteredEntries.isEmpty {
            if service.refreshFailed {
                EmptyView()
            } else if service.hasLoadedOnce {
                emptyState
            } else {
                loadingState
            }
        } else {
            // Lista plana: a rolagem acontece no nível do painel, fora do
            // elemento, reativa ao tamanho disponível.
            LazyVStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                ForEach(service.filteredEntries) { entry in
                    portRow(entry)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: HexaTheme.Spacing.xs) {
            HexaIcons.image("network.slash", size: 16)
                .foregroundStyle(HexaTheme.fgTertiary)
            Text(strings.empty)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
            Text(strings.emptyHint)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgTertiary)
            Text(strings.scopeNote)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if !service.query.isEmpty {
                Button(strings.clearSearch) { service.query = "" }
                    .buttonStyle(HexaActionButtonStyle())
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, HexaTheme.Spacing.m)
        .panelCard()
    }

    private var loadingState: some View {
        HexaBusyState(variant: .compact, message: l10n.s.loadingMessage)
            .panelCard()
    }

    private func portRow(_ entry: PortManagerEntry) -> some View {
        let blocked = entry.startedAt == nil || KillProcessService.isProtected(pid: entry.pid, name: entry.processName)
        return HStack(spacing: HexaTheme.Spacing.s) {
            HexaIcons.image("network", size: 11)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgPrimary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                HStack(spacing: HexaTheme.Spacing.xs) {
                    Text("\(entry.port)")
                        .font(.hexa(.label))
                    if PortManagerSupport.listensOnAllInterfaces(entry.address) {
                        PortManagerAllInterfacesBadge(strings: strings, showsLabel: false)
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
                    Button(strings.kill) { confirmTermination(entry, force: false) }
                        .buttonStyle(HexaActionButtonStyle()).controlSize(.mini)
                        .disabled(blocked)
                        .help(reasonText(for: entry).isEmpty ? strings.kill : reasonText(for: entry))
                    Menu {
                        Button(strings.forceKill) { confirmTermination(entry, force: true) }
                            .disabled(blocked)
                        Divider()
                        PortManagerRowActions(entry: entry, language: l10n.language)
                    } label: {
                        HexaIcons.image("ellipsis")
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(minWidth: 44)
                    .help(reasonText(for: entry).isEmpty ? strings.forceKill : reasonText(for: entry))
                    .accessibilityLabel(String(format: strings.rowActionsFormat, entry.processName))
                }
                .buttonStyle(HexaActionButtonStyle())
                .controlSize(.small)
                .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.vertical, HexaTheme.Spacing.xs)
        .padding(.horizontal, HexaTheme.Spacing.xs)
        .background(HexaTheme.surfaceInset, in: RoundedRectangle(cornerRadius: HexaTheme.Radius.control))
        .contentShape(Rectangle())
        .contextMenu {
            PortManagerRowActions(entry: entry, language: l10n.language)
        }
    }

    /// Reason the row's termination actions are blocked, shown as tooltip.
    /// Empty when the row can be terminated.
    private func reasonText(for entry: PortManagerEntry) -> String {
        if entry.startedAt == nil { return strings.helpIdentityUnavailable }
        if KillProcessService.isProtected(pid: entry.pid, name: entry.processName) { return strings.helpSystemProtected }
        return ""
    }

    private var terminationConfirmationPresented: Binding<Bool> {
        Binding {
            pending != nil
        } set: { isPresented in
            if !isPresented { dismissTermination() }
        }
    }

    private func presentTermination(_ entry: PortManagerEntry, force: Bool) {
        self.force = force
        pending = entry
        PanelInteractionState.shared.isPresentingPopoverModal = true
    }

    private func dismissTermination() {
        pending = nil
        PanelInteractionState.shared.isPresentingPopoverModal = false
    }

    /// The alert would hang from the island as a sheet; there it asks on its own.
    private func confirmTermination(_ entry: PortManagerEntry, force: Bool) {
        guard inNotch else {
            presentTermination(entry, force: force)
            return
        }
        DispatchQueue.main.async {
            guard NSAlert.confirmAboveIsland(String(format: strings.terminateFormat, entry.processName),
                                             message: String(format: strings.terminateMessageFormat, entry.port, entry.pid),
                                             action: force ? strings.forceKill : strings.kill, destructive: true,
                                             cancel: l10n.s.uninstallerCancel) else { return }
            service.terminate(entry, force: force)
        }
    }
}
