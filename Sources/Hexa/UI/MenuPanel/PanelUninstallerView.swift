// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Compact uninstaller flow for the menu panel. It reuses AppUninstaller so the
/// scan and removal rules stay identical to the larger Settings page.
struct PanelUninstallerView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var uninstaller = AppUninstaller.shared
    @ObservedObject private var homebrew = HomebrewManager.shared
    @Environment(\.notchPresentation) private var inNotch
    @State private var dropTargeted = false
    @State private var showingAppPicker = false
    @State private var pendingHomebrewRemoval: AppUninstaller.HomebrewRemovalConfirmation?
    @State private var pendingQuitNames: [String] = []
    @State private var showHomebrewDetails = false

    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            header
            content
        }
        .dropDestination(for: URL.self) { urls, _ in
            let selected = selectFirstApp(from: urls)
            if selected {
                showingAppPicker = false
            }
            return selected
        } isTargeted: { dropTargeted = $0 }
        .onAppear { PanelInteractionState.shared.viewKeepsPopoverOpen = true }
        .onDisappear {
            PanelInteractionState.shared.viewKeepsPopoverOpen = false
            dismissHomebrewRemovalConfirmation()
        }
        .alert(l10n.s.homebrewConfirmUninstallTitle,
               isPresented: homebrewRemovalConfirmationPresented,
               presenting: pendingHomebrewRemoval) { confirmation in
            Button(l10n.s.uninstallerCancel, role: .cancel) {
                dismissHomebrewRemovalConfirmation()
            }
            Button(l10n.s.homebrewUninstall, role: .destructive) {
                uninstaller.removeSelectedWithHomebrew(confirmation: confirmation)
                dismissHomebrewRemovalConfirmation()
            }
        } message: { confirmation in
            Text(String(format: l10n.s.homebrewConfirmUninstallBodyFormat, confirmation.package.displayName))
        }
        .alert(l10n.s.uninstallerQuitTitle,
               isPresented: Binding(get: { !pendingQuitNames.isEmpty },
                                    set: { if !$0 { dismissQuitConfirmation() } })) {
            Button(l10n.s.uninstallerCancel, role: .cancel) {
                dismissQuitConfirmation()
            }
            Button(l10n.s.uninstallerQuitAndRemove, role: .destructive) {
                dismissQuitConfirmation()
                uninstaller.removeSelected(quitConfirmed: true)
            }
        } message: {
            Text(String(format: l10n.s.uninstallerQuitBodyFormat, pendingQuitNames.joined(separator: ", ")))
        }
        .alert(l10n.s.uninstallerForceQuitTitle,
               isPresented: Binding(get: { !inNotch && !uninstaller.appsThatDidNotQuit.isEmpty },
                                    set: { if !$0 { uninstaller.keepRunningApps() } })) {
            Button(l10n.s.uninstallerCancel, role: .cancel) { uninstaller.keepRunningApps() }
            Button(l10n.s.uninstallerForceQuitAndRemove, role: .destructive) {
                uninstaller.forceQuitAndRemove()
            }
        } message: {
            Text(String(format: l10n.s.uninstallerForceQuitBodyFormat,
                        uninstaller.appsThatDidNotQuit.joined(separator: ", ")))
        }
        .onChange(of: uninstaller.appsThatDidNotQuit) { _, names in
            guard !names.isEmpty else {
                if pendingHomebrewRemoval == nil, pendingQuitNames.isEmpty {
                    PanelInteractionState.shared.isPresentingPopoverModal = false
                }
                return
            }
            guard inNotch else {
                PanelInteractionState.shared.isPresentingPopoverModal = true
                return
            }
            // The alert would hang from the island as a sheet; there it asks on its own.
            DispatchQueue.main.async {
                let force = NSAlert.confirmAboveIsland(
                    l10n.s.uninstallerForceQuitTitle,
                    message: String(format: l10n.s.uninstallerForceQuitBodyFormat, names.joined(separator: ", ")),
                    action: l10n.s.uninstallerForceQuitAndRemove, destructive: true,
                    cancel: l10n.s.uninstallerCancel)
                if force { uninstaller.forceQuitAndRemove() } else { uninstaller.keepRunningApps() }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch uninstaller.phase {
        case .empty:
            if showingAppPicker {
                appPickerState
            } else {
                emptyState
            }
        case .scanning: busyState(l10n.s.uninstallerScanning)
        case .results: resultsState
        case .removing: busyState(l10n.s.uninstallerRemoving)
        case let .done(movedToTrash, freedPermanently, failed):
            doneState(movedToTrash: movedToTrash, freedPermanently: freedPermanently, failed: failed)
        }
    }

    private var header: some View {
        HexaPanelHeader(title: l10n.s.uninstallerName, icon: "trash") {
            HexaIconButton(icon: "xmark.circle.fill",
                           label: l10n.s.uninstallerCancel,
                           variant: .small) {
                // Closing means cancel: a scan left running would come back
                // on the next open. A removal in progress is left alone.
                if uninstaller.phase == .scanning { uninstaller.reset() }
                onClose()
            }
            .help(l10n.s.uninstallerCancel)
        }
    }

    private var emptyState: some View {
        VStack(spacing: HexaTheme.Spacing.s) {
            dropZone

            if let error = uninstaller.errorMessage, !error.isEmpty {
                HexaStatusNote(message: error, icon: "exclamationmark.triangle.fill")
            }

            Button {
                choose()
            } label: {
                Label(l10n.s.uninstallerChoose, hexaIcon: "plus.app")
                    .font(.hexa(.label))
            }
            .buttonStyle(HexaActionButtonStyle())
            .controlSize(.small)

            Text(l10n.s.uninstallerEmptyNote)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if !permissions.fullDiskAccess {
                FullDiskAccessNote(compact: true)
            }
        }
        .panelCard()
    }

    private var appPickerState: some View {
        AppPickerView(compact: true) {
            showingAppPicker = false
        } onSelect: { url in
            showingAppPicker = false
            uninstaller.select(appURL: url)
        } loadApps: { UninstallerSupport.offeredApplications() }
        .panelCard()
    }

    private var dropZone: some View {
        RoundedRectangle(cornerRadius: HexaTheme.Radius.panel, style: .continuous)
            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            .foregroundStyle(dropTargeted ? HexaTheme.fgPrimary : HexaTheme.fgSecondary.opacity(0.35))
            .background(
                RoundedRectangle(cornerRadius: HexaTheme.Radius.panel, style: .continuous)
                    .fill(dropTargeted ? HexaTheme.selectionBg : HexaTheme.surfaceInset)
            )
            .frame(height: 108)
            .overlay(
                VStack(spacing: HexaTheme.Spacing.xs) {
                    HexaIcons.image("arrow.down.app", size: 28)
                        .foregroundStyle(dropTargeted ? HexaTheme.fgPrimary : HexaTheme.fgSecondary)
                    Text(l10n.s.uninstallerDropTitle)
                        .font(.hexa(.body))
                    Text(l10n.s.uninstallerDropSubtitle)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, HexaTheme.Spacing.m)
            )
            .animation(.easeOut(duration: 0.15), value: dropTargeted)
    }

    private func busyState(_ message: String) -> some View {
        HexaBusyState(variant: .compact,
                      message: message,
                      detail: uninstaller.target?.name,
                      actionTitle: uninstaller.phase == .scanning ? l10n.s.uninstallerCancel : nil,
                      action: uninstaller.phase == .scanning ? { uninstaller.reset() } : nil)
            .panelCard()
    }

    private var resultsState: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            targetHeader
            if !uninstaller.items.isEmpty {
                selectionBar
            }
            HairlineDivider()
            leftoverList
            HairlineDivider()
            removalNotices
            homebrewStatus
            footer
        }
        .panelCard()
    }

    private var selectionBar: some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            Button(l10n.s.menuSelectAll) { uninstaller.selectAll() }
                .disabled(uninstaller.items.allSatisfy(\.include))
            Button(l10n.s.uninstallerClearSelection) { uninstaller.selectNone() }
                .disabled(!uninstaller.items.contains(where: \.include))
            Spacer(minLength: 0)
        }
        .buttonStyle(.link)
        .font(.hexa(.micro))
    }

    private var targetHeader: some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            if let target = uninstaller.target {
                Image(nsImage: target.icon)
                    .resizable()
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                    Text(target.name)
                        .font(.hexa(.body))
                        .lineLimit(1)
                    Text(target.bundleID ?? target.url.path)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: HexaTheme.Spacing.xs) {
                Text(Self.byteString(uninstaller.totalSize))
                    .font(.hexa(.data))
                Text(l10n.s.uninstallerFoundTitle)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
            HexaIconButton(icon: "xmark.circle.fill",
                           label: l10n.s.uninstallerCancel,
                           variant: .small) {
                uninstaller.reset()
            }
            .disabled(uninstaller.isRemovingWithHomebrew)
        }
    }

    private var leftoverList: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            ForEach(AppUninstaller.Category.allCases, id: \.self) { category in
                let group = uninstaller.items.filter { $0.category == category }
                if !group.isEmpty {
                    categoryGroup(group, category: category)
                }
            }
        }
    }

    private func categoryGroup(_ group: [AppUninstaller.Leftover],
                               category: AppUninstaller.Category) -> some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            SectionLabel(label(for: category))
            ForEach(group) { item in
                row(item)
            }
        }
    }

    private func row(_ item: AppUninstaller.Leftover) -> some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            Toggle("", isOn: includeBinding(item))
                .labelsHidden()
                .toggleStyle(.checkbox)
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .frame(width: 17, height: 17)
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                Text(item.name)
                    .font(.hexa(.label))
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: HexaTheme.Spacing.xs) {
                    if item.confidence == .related {
                        HexaIcons.image("questionmark.circle")
                            .foregroundStyle(HexaTheme.statusWarning)
                            .help(l10n.s.cleanerOptionalSection)
                            .accessibilityLabel(l10n.s.cleanerOptionalSection)
                    }
                    Text(prettyPath(item.url))
                        .foregroundStyle(HexaTheme.fgTertiary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                .font(.hexa(.label))
                if UninstallerSupport.isHiddenHomeRoot(item.url, home: NSHomeDirectory()) {
                    Text(l10n.s.uninstallerHiddenHomeLegend)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgSecondary)
                }
            }
            Spacer(minLength: 0)
            HexaIconButton(icon: "folder",
                           label: l10n.s.cleanerRevealInFinder,
                           variant: .small) {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }
            .help(l10n.s.cleanerRevealInFinder)
            Text(Self.byteString(item.size))
                .font(.hexa(.data))
                .foregroundStyle(HexaTheme.fgSecondary)
        }
        .frame(minHeight: 24)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            HStack {
                Text(String(format: l10n.s.uninstallerSelectedFormat,
                            uninstaller.items.filter(\.include).count, uninstaller.items.count))
                    .font(.hexa(.label))
                Spacer()
                Text(Self.byteString(uninstaller.selectedSize))
                    .font(.hexa(.data))
                    .monospacedDigit()
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
            HStack {
                Button(l10n.s.uninstallerCancel) {
                    uninstaller.reset()
                }
                .controlSize(.small)
                .disabled(uninstaller.isRemovingWithHomebrew)
                Spacer()
                Button {
                    if let confirmation = uninstaller.homebrewRemovalConfirmation {
                        presentHomebrewRemovalConfirmation(confirmation)
                    } else if !uninstaller.appsQuitBySelection.isEmpty {
                        presentQuitConfirmation(uninstaller.appsQuitBySelection)
                    } else {
                        uninstaller.removeSelected()
                    }
                } label: {
                    Label(removeButtonTitle, hexaIcon: "trash")
                        .font(.hexa(.label))
                        .lineLimit(1)
                }
                .buttonStyle(HexaActionButtonStyle())
                .controlSize(.small)
                .disabled(!uninstaller.items.contains(where: \.include)
                          || (uninstaller.selectedHomebrewPackage != nil && homebrew.isBusy))
            }
        }
    }

    private var removeButtonTitle: String {
        uninstaller.selectedHomebrewPackage == nil ? l10n.s.uninstallerRemove : l10n.s.homebrewUninstall
    }

    private var homebrewRemovalConfirmationPresented: Binding<Bool> {
        Binding {
            pendingHomebrewRemoval != nil
        } set: { isPresented in
            if !isPresented { dismissHomebrewRemovalConfirmation() }
        }
    }

    private func presentHomebrewRemovalConfirmation(_ confirmation: AppUninstaller.HomebrewRemovalConfirmation) {
        // The alert would hang from the island as a sheet; there it asks on its own.
        guard !inNotch else {
            DispatchQueue.main.async {
                guard NSAlert.confirmAboveIsland(l10n.s.homebrewConfirmUninstallTitle,
                                                 message: String(format: l10n.s.homebrewConfirmUninstallBodyFormat,
                                                                 confirmation.package.displayName),
                                                 action: l10n.s.homebrewUninstall, destructive: true,
                                                 cancel: l10n.s.uninstallerCancel) else { return }
                uninstaller.removeSelectedWithHomebrew(confirmation: confirmation)
            }
            return
        }
        PanelInteractionState.shared.isPresentingPopoverModal = true
        pendingHomebrewRemoval = confirmation
    }

    private func dismissHomebrewRemovalConfirmation() {
        pendingHomebrewRemoval = nil
        PanelInteractionState.shared.isPresentingPopoverModal = false
    }

    private func presentQuitConfirmation(_ names: [String]) {
        // The alert would hang from the island as a sheet; there it asks on its own.
        guard !inNotch else {
            DispatchQueue.main.async {
                guard NSAlert.confirmAboveIsland(l10n.s.uninstallerQuitTitle,
                                                 message: String(format: l10n.s.uninstallerQuitBodyFormat,
                                                                 names.joined(separator: ", ")),
                                                 action: l10n.s.uninstallerQuitAndRemove, destructive: true,
                                                 cancel: l10n.s.uninstallerCancel) else { return }
                uninstaller.removeSelected(quitConfirmed: true)
            }
            return
        }
        PanelInteractionState.shared.isPresentingPopoverModal = true
        pendingQuitNames = names
    }

    private func dismissQuitConfirmation() {
        pendingQuitNames = []
        PanelInteractionState.shared.isPresentingPopoverModal = false
    }

    @ViewBuilder
    private var removalNotices: some View {
        if uninstaller.removalNotices.contains(.systemExtension) {
            HexaStatusNote(message: l10n.s.uninstallerSystemExtensionNote,
                           icon: "exclamationmark.triangle.fill")
        }
        if uninstaller.removalNotices.contains(.loginItem) {
            HexaStatusNote(message: l10n.s.uninstallerLoginItemNote,
                           icon: "exclamationmark.triangle.fill")
        }
    }

    @ViewBuilder
    private var homebrewStatus: some View {
        if let package = uninstaller.selectedHomebrewPackage {
            if let status = homebrew.operationStatus,
               status.action == .uninstall,
               status.package?.id == package.id {
                HomebrewOperationStatusView(status: status,
                                            log: homebrew.log,
                                            terminalFallbackCommand: homebrew.terminalFallbackCommand,
                                            compact: true,
                                            showDetails: $showHomebrewDetails,
                                            onCancel: homebrew.cancelOperation,
                                            onClear: homebrew.clearLog,
                                            onOpenTerminal: homebrew.openTerminalFallback)
                if let tap = homebrew.untrustedTap {
                    HomebrewTrustCard(tap: tap, compact: true)
                }
                if let error = uninstaller.errorMessage ?? homebrew.errorMessage, !error.isEmpty {
                    HexaStatusNote(message: error, icon: "exclamationmark.triangle.fill")
                }
            } else {
                Label(String(format: l10n.s.uninstallerHomebrewPackageFormat, package.displayName),
                      hexaIcon: "shippingbox")
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if uninstaller.homebrewAwaitingTerminal?.id == package.id {
                Button(l10n.s.uninstallerTerminalContinue) {
                    uninstaller.continueAfterTerminal()
                }
                .buttonStyle(HexaActionButtonStyle())
                .controlSize(.small)
            }
            HairlineDivider()
        }
    }

    private func doneState(movedToTrash: Int64, freedPermanently: Int64,
                           failed: [AppUninstaller.Leftover]) -> some View {
        VStack(spacing: HexaTheme.Spacing.s) {
            HexaIcons.image(UninstallerSupport.doneSymbol(hasLeftovers: !failed.isEmpty), size: 32)
                .foregroundStyle(failed.isEmpty ? HexaTheme.statusOk : HexaTheme.statusWarning)
            Text(l10n.s.uninstallerDoneTitle)
                .font(.hexa(.heading))
            if movedToTrash > 0 {
                Text(String(format: l10n.s.movedToTrashFormat, Self.byteString(movedToTrash)))
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
            if freedPermanently > 0 {
                Text(String(format: l10n.s.freedPermanentlyFormat, Self.byteString(freedPermanently)))
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
            if movedToTrash > 0 {
                Text(l10n.s.cleanerDoneNote)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgTertiary)
                    .multilineTextAlignment(.center)
            }
            if !failed.isEmpty {
                UninstallFailureNote(items: failed, compact: true)
            }
            Button(l10n.s.uninstallerAnother) {
                uninstaller.reset()
            }
            .buttonStyle(HexaActionButtonStyle())
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .panelCard()
    }

    private func includeBinding(_ item: AppUninstaller.Leftover) -> Binding<Bool> {
        Binding(
            get: { uninstaller.items.first(where: { $0.id == item.id })?.include ?? false },
            set: { uninstaller.setInclude($0, for: item.id) }
        )
    }

    private func selectFirstApp(from urls: [URL]) -> Bool {
        guard let app = urls.first(where: { $0.pathExtension == "app" }) ?? urls.first else {
            return false
        }
        return uninstaller.select(appURL: app)
    }

    private func choose() {
        uninstaller.clearErrorMessage()
        showingAppPicker = true
    }

    private func prettyPath(_ url: URL) -> String {
        url.deletingLastPathComponent().path
            .replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    private func label(for category: AppUninstaller.Category) -> String {
        switch category {
        case .app: return l10n.s.uninstallerCatApp
        case .support: return l10n.s.uninstallerCatSupport
        case .caches: return l10n.s.uninstallerCatCaches
        case .preferences: return l10n.s.uninstallerCatPreferences
        case .containers: return l10n.s.uninstallerCatContainers
        case .logs: return l10n.s.uninstallerCatLogs
        case .state: return l10n.s.uninstallerCatState
        case .other: return l10n.s.uninstallerCatOther
        }
    }

    private static func byteString(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
