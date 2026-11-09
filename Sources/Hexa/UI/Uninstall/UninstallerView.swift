// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// The uninstaller, embedded as a Settings page: drop an app (or pick one),
/// review the leftover files it found with their sizes, then move the selected
/// ones to the Trash and see the space recovered.
struct UninstallerView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var uninstaller = AppUninstaller.shared
    @ObservedObject private var homebrew = HomebrewManager.shared
    @ObservedObject private var permissions = Permissions.shared
    @State private var dropTargeted = false
    @State private var showingAppPicker = false
    @State private var pendingHomebrewRemoval: AppUninstaller.HomebrewRemovalConfirmation?
    @State private var pendingQuitNames: [String] = []
    @State private var showHomebrewDetails = false

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .alert(l10n.s.homebrewConfirmUninstallTitle,
                   isPresented: Binding(get: { pendingHomebrewRemoval != nil },
                                        set: { if !$0 { pendingHomebrewRemoval = nil } }),
                   presenting: pendingHomebrewRemoval) { confirmation in
                Button(l10n.s.uninstallerCancel, role: .cancel) {}
                Button(l10n.s.homebrewUninstall, role: .destructive) {
                    pendingHomebrewRemoval = nil
                    uninstaller.removeSelectedWithHomebrew(confirmation: confirmation)
                }
            } message: { confirmation in
                Text(String(format: l10n.s.homebrewConfirmUninstallBodyFormat, confirmation.package.displayName))
            }
            .alert(l10n.s.uninstallerQuitTitle,
                   isPresented: Binding(get: { !pendingQuitNames.isEmpty },
                                        set: { if !$0 { pendingQuitNames = [] } })) {
                Button(l10n.s.uninstallerCancel, role: .cancel) {}
                Button(l10n.s.uninstallerQuitAndRemove, role: .destructive) {
                    pendingQuitNames = []
                    uninstaller.removeSelected(quitConfirmed: true)
                }
            } message: {
                Text(String(format: l10n.s.uninstallerQuitBodyFormat, pendingQuitNames.joined(separator: ", ")))
            }
            .alert(l10n.s.uninstallerForceQuitTitle,
                   isPresented: Binding(get: { !uninstaller.appsThatDidNotQuit.isEmpty },
                                        set: { if !$0 { uninstaller.keepRunningApps() } })) {
                Button(l10n.s.uninstallerCancel, role: .cancel) { uninstaller.keepRunningApps() }
                Button(l10n.s.uninstallerForceQuitAndRemove, role: .destructive) {
                    uninstaller.forceQuitAndRemove()
                }
            } message: {
                Text(String(format: l10n.s.uninstallerForceQuitBodyFormat,
                            uninstaller.appsThatDidNotQuit.joined(separator: ", ")))
            }
    }

    @ViewBuilder
    private var content: some View {
        switch uninstaller.phase {
        case .empty: emptyState
        case .scanning: busyState(l10n.s.uninstallerScanning)
        case .results: resultsState
        case .removing: busyState(l10n.s.uninstallerRemoving)
        case let .done(movedToTrash, freedPermanently, failed):
            doneState(movedToTrash: movedToTrash, freedPermanently: freedPermanently, failed: failed)
        }
    }

    // MARK: Empty / drop

    private var emptyState: some View {
        OverlayScrollView {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xxl) {
                HexaCard {
                    VStack(alignment: .leading, spacing: HexaTheme.Spacing.m) {
                        dropZone
                        if let error = uninstaller.errorMessage, !error.isEmpty {
                            HexaStatusNote(message: error, icon: "exclamationmark.triangle.fill")
                        }
                        Text(l10n.s.uninstallerEmptyNote)
                            .font(.hexa(.label))
                            .foregroundStyle(HexaTheme.fgTertiary)
                        if !permissions.fullDiskAccess {
                            HairlineDivider()
                            FullDiskAccessNote()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, HexaTheme.Spacing.pageGap)
        }
        .sheet(isPresented: $showingAppPicker) {
            AppPickerView {
                showingAppPicker = false
            } onSelect: { url in
                showingAppPicker = false
                uninstaller.select(appURL: url)
            } loadApps: { UninstallerSupport.offeredApplications() }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let app = urls.first(where: { $0.pathExtension == "app" }) ?? urls.first else { return false }
            return uninstaller.select(appURL: app)
        } isTargeted: { dropTargeted = $0 }
    }

    private var dropZone: some View {
        HStack(spacing: HexaTheme.Spacing.m) {
            HexaIcons.image("arrow.down.app", size: 16)
                .foregroundStyle(dropTargeted ? HexaTheme.fgPrimary : HexaTheme.fgSecondary)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                Text(l10n.s.uninstallerDropTitle)
                    .font(.hexa(.body))
                    .foregroundStyle(HexaTheme.fgPrimary)
                Text(l10n.s.uninstallerDropSubtitle)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
            Spacer(minLength: 0)
            Button(l10n.s.uninstallerChoose) { choose() }
                .buttonStyle(HexaActionButtonStyle())
                .controlSize(.regular)
        }
        .padding(HexaTheme.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: HexaTheme.Radius.panel, style: .continuous)
                .strokeBorder(
                    dropTargeted ? HexaTheme.fgPrimary : HexaTheme.borderHairline,
                    style: StrokeStyle(lineWidth: 1, dash: dropTargeted ? [6, 4] : [])
                )
                .background(
                    RoundedRectangle(cornerRadius: HexaTheme.Radius.panel, style: .continuous)
                        .fill(dropTargeted ? HexaTheme.fgPrimary.opacity(0.06) : HexaTheme.surfaceInset)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.panel, style: .continuous))
        .onTapGesture { choose() }
    }

    // MARK: Busy

    private func busyState(_ message: String) -> some View {
        HexaBusyState(
            variant: .workspace,
            message: message,
            actionTitle: uninstaller.phase == .scanning ? l10n.s.uninstallerCancel : nil,
            action: uninstaller.phase == .scanning ? { uninstaller.reset() } : nil
        ) {
            if let target = uninstaller.target {
                HStack(spacing: HexaTheme.Spacing.s) {
                    Image(nsImage: target.icon).resizable().frame(width: 18, height: 18)
                    Text(target.name).font(.hexa(.body))
                }
            }
        }
    }

    // MARK: Results

    private var resultsState: some View {
        VStack(spacing: 0) {
            targetHeader
            if !uninstaller.items.isEmpty {
                selectionBar
            }
            HairlineDivider()
            OverlayScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(AppUninstaller.Category.allCases, id: \.self) { category in
                        let group = uninstaller.items.filter { $0.category == category }
                        if !group.isEmpty {
                            Section {
                                ForEach(group) { item in row(item) }
                            } header: {
                                sectionTitle(label(for: category))
                                    .padding(.top, HexaTheme.Spacing.s)
                                    .padding(.bottom, HexaTheme.Spacing.xs)
                            }
                        }
                    }
                }
                .padding(.horizontal, HexaTheme.Spacing.l)
                .padding(.bottom, HexaTheme.Spacing.pageGap)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            HairlineDivider()
            removalNotices
            homebrewStatus
            footer
        }
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
        .font(.hexa(.label))
        .padding(.horizontal, HexaTheme.Spacing.l)
        .padding(.bottom, HexaTheme.Spacing.s)
    }

    private var targetHeader: some View {
        HStack(spacing: HexaTheme.Spacing.m) {
            if let target = uninstaller.target {
                Image(nsImage: target.icon).resizable().frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                    Text(target.name).font(.hexa(.heading))
                    Text(target.bundleID ?? target.url.path)
                        .font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
                        .lineLimit(1).truncationMode(.middle)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: HexaTheme.Spacing.xs) {
                Text(Self.byteString(uninstaller.totalSize))
                    .font(.hexa(.heading))
                Text(l10n.s.uninstallerFoundTitle).font(.hexa(.micro)).foregroundStyle(HexaTheme.fgSecondary)
            }
            HexaIconButton(icon: "xmark.circle.fill",
                           label: l10n.s.uninstallerCancel,
                           variant: .regular,
                           action: { uninstaller.reset() })
                .disabled(uninstaller.isRemovingWithHomebrew)
        }
        .padding(HexaTheme.Spacing.l)
    }

    private func row(_ item: AppUninstaller.Leftover) -> some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            Toggle("", isOn: includeBinding(item)).labelsHidden().toggleStyle(.checkbox)
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable().frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                Text(item.name).font(.hexa(.body)).lineLimit(1).truncationMode(.middle)
                HStack(spacing: HexaTheme.Spacing.xs) {
                    if item.confidence == .related {
                        Label(l10n.s.cleanerOptionalSection, hexaIcon: "questionmark.circle")
                            .foregroundStyle(HexaTheme.statusWarning)
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
            Spacer()
            HexaIconButton(icon: "folder",
                           label: l10n.s.cleanerRevealInFinder,
                           variant: .small,
                           action: { NSWorkspace.shared.activateFileViewerSelecting([item.url]) })
                .help(l10n.s.cleanerRevealInFinder)
            Text(Self.byteString(item.size))
                .font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
                .monospacedDigit()
        }
        .padding(.vertical, 2) // geometria de plataforma (spec §4): densidade de linha de lista
    }

    private var footer: some View {
        HexaResultsFooter(
            secondaryTitle: l10n.s.uninstallerCancel,
            secondaryAction: { uninstaller.reset() },
            secondaryDisabled: uninstaller.isRemovingWithHomebrew,
            primaryTitle: removeButtonTitle,
            primaryAction: {
                if let confirmation = uninstaller.homebrewRemovalConfirmation {
                    pendingHomebrewRemoval = confirmation
                } else if !uninstaller.appsQuitBySelection.isEmpty {
                    pendingQuitNames = uninstaller.appsQuitBySelection
                } else {
                    uninstaller.removeSelected()
                }
            },
            primaryDisabled: !uninstaller.items.contains(where: \.include)
                             || (uninstaller.selectedHomebrewPackage != nil && homebrew.isBusy)
        ) {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                Text(String(format: l10n.s.uninstallerSelectedFormat,
                            uninstaller.items.filter(\.include).count, uninstaller.items.count))
                    .font(.hexa(.body))
                Text(Self.byteString(uninstaller.selectedSize))
                    .font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
            }
        }
    }

    private var removeButtonTitle: String {
        uninstaller.selectedHomebrewPackage == nil ? l10n.s.uninstallerRemove : l10n.s.homebrewUninstall
    }

    @ViewBuilder
    private var removalNotices: some View {
        if uninstaller.removalNotices.contains(.systemExtension) {
            HexaStatusNote(message: l10n.s.uninstallerSystemExtensionNote,
                           icon: "exclamationmark.triangle.fill")
                .padding(.horizontal, HexaTheme.Spacing.l)
                .padding(.vertical, HexaTheme.Spacing.s)
        }
        if uninstaller.removalNotices.contains(.loginItem) {
            HexaStatusNote(message: l10n.s.uninstallerLoginItemNote,
                           icon: "exclamationmark.triangle.fill")
                .padding(.horizontal, HexaTheme.Spacing.l)
                .padding(.vertical, HexaTheme.Spacing.s)
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
                                            compact: false,
                                            showDetails: $showHomebrewDetails,
                                            onCancel: homebrew.cancelOperation,
                                            onClear: homebrew.clearLog,
                                            onOpenTerminal: homebrew.openTerminalFallback)
                    .padding(HexaTheme.Spacing.m)
                if let tap = homebrew.untrustedTap {
                    HomebrewTrustCard(tap: tap)
                        .padding(.horizontal, HexaTheme.Spacing.m)
                        .padding(.bottom, HexaTheme.Spacing.m)
                }
                if let error = uninstaller.errorMessage ?? homebrew.errorMessage, !error.isEmpty {
                    HexaStatusNote(message: error, icon: "exclamationmark.triangle.fill")
                        .padding(.horizontal, HexaTheme.Spacing.m)
                        .padding(.bottom, HexaTheme.Spacing.m)
                }
            } else {
                Label(String(format: l10n.s.uninstallerHomebrewPackageFormat, package.displayName),
                      hexaIcon: "shippingbox")
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .padding(.horizontal, HexaTheme.Spacing.l)
                    .padding(.vertical, HexaTheme.Spacing.s)
            }
            if uninstaller.homebrewAwaitingTerminal?.id == package.id {
                Button(l10n.s.uninstallerTerminalContinue) {
                    uninstaller.continueAfterTerminal()
                }
                .buttonStyle(HexaActionButtonStyle())
                .padding(.horizontal, HexaTheme.Spacing.m)
                .padding(.bottom, HexaTheme.Spacing.m)
            }
            HairlineDivider()
        }
    }

    // MARK: Done

    private func doneState(movedToTrash: Int64, freedPermanently: Int64,
                           failed: [AppUninstaller.Leftover]) -> some View {
        VStack(spacing: HexaTheme.Spacing.l) {
            Spacer()
            HexaIcons.image(UninstallerSupport.doneSymbol(hasLeftovers: !failed.isEmpty), size: 54)
                .foregroundStyle(failed.isEmpty ? HexaTheme.statusOk : HexaTheme.statusWarning)
            Text(l10n.s.uninstallerDoneTitle).font(.hexa(.display(20)))
            if movedToTrash > 0 {
                Text(String(format: l10n.s.movedToTrashFormat, Self.byteString(movedToTrash)))
                    .font(.hexa(.body)).foregroundStyle(HexaTheme.fgSecondary)
            }
            if freedPermanently > 0 {
                Text(String(format: l10n.s.freedPermanentlyFormat, Self.byteString(freedPermanently)))
                    .font(.hexa(.body)).foregroundStyle(HexaTheme.fgSecondary)
            }
            if movedToTrash > 0 {
                Text(l10n.s.cleanerDoneNote)
                    .font(.hexa(.label)).foregroundStyle(HexaTheme.fgTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
            if !failed.isEmpty {
                UninstallFailureNote(items: failed).frame(width: 360)
            }
            Button(l10n.s.uninstallerAnother) { uninstaller.reset() }
                .controlSize(.large)
                .buttonStyle(HexaActionButtonStyle())
                .padding(.top, HexaTheme.Spacing.xs)
            Spacer()
        }
        .padding(HexaTheme.Spacing.xxl)
    }

    // MARK: Helpers

    private func includeBinding(_ item: AppUninstaller.Leftover) -> Binding<Bool> {
        Binding(
            get: { uninstaller.items.first(where: { $0.id == item.id })?.include ?? false },
            set: { uninstaller.setInclude($0, for: item.id) }
        )
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
