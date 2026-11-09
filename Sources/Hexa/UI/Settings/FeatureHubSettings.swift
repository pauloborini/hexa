// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import EventKit
import SwiftUI

/// The Features hub. One switch per feature, grouped in plain language: off
/// means the feature disappears from the whole app (Settings, panel, menu
/// bar, shortcuts) and costs nothing; its configuration is kept for its
/// return. The Permissions tab is the transparency portal: what each system
/// permission does, which features use it right now, and a gentle nudge when
/// one is granted with nothing using it.
struct FeatureHubSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var router = SettingsRouter.shared
    @ObservedObject private var state = FeatureWorkspaceState.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Tracks the feature-target request currently being revealed, so a
    /// delayed retry from an older request cannot act after a newer one has
    /// already taken over (same convention as `SettingsSectionFocusModifier`).
    @State private var revealID = UUID()
    /// The row briefly tinted after a search or Command Bar selection lands
    /// on it, mirroring the section highlight `SettingsSectionFocusModifier`
    /// gives an ordinary page anchor.
    @State private var highlightedFeature: AppFeature?
    @State private var expandedGroups = Set(FeatureGroup.allCases)
    @State private var islandExtensionsExpanded = true
    /// Installed switches never once turned on, read when the page appears
    /// and after every install change rather than on every redraw.
    @State private var neverUsed: [AppFeature] = []
    /// The batch just uninstalled from that card, kept for its Undo.
    @State private var recentlyUninstalled: [AppFeature] = []

    /// Below this, the offer would be more to read than it saves.
    private static let neverUsedMinimum = 3

    private enum Tab { case features, permissions }

    private var tab: Tab { state.featureHubTab == 0 ? .features : .permissions }

    private var hub: FeatureHubStrings { FeatureStrings.hub(l10n.language) }

    /// Consumes a one-shot request to open directly on the Permissions tab.
    /// Called on every onAppear so a navigation that arrives while the hub is
    /// already visible still takes effect.
    private func consumePendingPermissionsTab() {
        guard router.pendingPermissionsTab else { return }
        router.pendingPermissionsTab = false
        state.featureHubTab = 1
    }

    var body: some View {
        ScrollViewReader { proxy in
            content
                .onAppear {
                    consumePendingPermissionsTab()
                    refreshNeverUsed()
                    revealPendingFeatureTarget(using: proxy)
                }
                .onChange(of: router.requestID) { _, _ in
                    consumePendingPermissionsTab()
                    revealPendingFeatureTarget(using: proxy)
                }
                .onChange(of: features.revision) { _, _ in
                    // The offer appears and leaves on the same curve as the switch that changed it.
                    withAnimation(.easeOut(duration: 0.22)) { refreshNeverUsed() }
                }
        }
    }

    private var content: some View {
        HexaScreenScaffold(
            title: hub.pageTitle,
            subtitle: tab == .features ? hub.intro : hub.permissionsIntro,
            scrolls: false,
            pinned: {
                HexaSegmentControl([hub.tabFeatures, hub.tabPermissions],
                                   selection: Binding(
                                       get: { state.featureHubTab },
                                       set: { state.featureHubTab = $0 }
                                   ))
            }
        ) {
            // The lazy stack has to be the scroll view's own content.
            // Nested in a plain stack, it resized that stack each time a
            // card came into view: scrolling stalled for up to a second, and the
            // layout could keep redoing itself until Settings froze.
            OverlayScrollView {
                LazyVStack(alignment: .leading, spacing: HexaTheme.Spacing.l) {
                    if tab == .features {
                        summaryCard
                        neverUsedCard
                        dynamicIslandCard
                        ForEach(FeatureGroup.allCases.filter { $0 != .dynamicIsland }, id: \.self) { group in
                            groupCard(group)
                        }
                        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                            Text(hub.footerNote)
                                .hexaCaption()
                            Text(hub.energyHelp)
                                .hexaCaption()
                        }
                    } else {
                        HexaCard {
                            PermissionsPortalSections(hub: hub)
                        }
                    }
                }
                .padding(.horizontal, HexaTheme.Spacing.xxl)
                .padding(.bottom, HexaTheme.Spacing.pageGap)
            }
            // Floats over the top of the list instead of taking a row in it: a row
            // inserted above the visible area moves every row under it. The notice
            // shows whichever tab is open, since uninstalling anything must not be missed.
            .overlay(alignment: .top) {
                if features.needsRestartToUnload {
                    restartCard
                        .padding(.horizontal, HexaTheme.Spacing.xxl)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    /// Consumes a pending Feature Hub target: switches off the Permissions
    /// tab if needed and scrolls the requested row into view. Retried once
    /// after the first run-loop turn, the same allowance
    /// `SettingsSectionFocusModifier` gives a freshly installed Form to
    /// register its row identities.
    private func revealPendingFeatureTarget(using proxy: ScrollViewProxy) {
        guard let request = router.pendingFeatureTarget else { return }
        router.consumeFeatureTarget(id: request.id)
        revealID = request.id
        if tab == .permissions { state.featureHubTab = 0 }
        if request.feature.group == .dynamicIsland {
            if request.feature != .notch { islandExtensionsExpanded = true }
        } else {
            expandedGroups.insert(request.feature.group)
        }
        DispatchQueue.main.async {
            guard self.revealID == request.id else { return }
            proxy.scrollTo(request.feature.group, anchor: .top)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                guard self.revealID == request.id else { return }
                reveal(request.feature, using: proxy)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    guard self.revealID == request.id else { return }
                    reveal(request.feature, using: proxy)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    guard self.revealID == request.id else { return }
                    clearHighlight()
                }
            }
        }
    }

    private func reveal(_ feature: AppFeature, using proxy: ScrollViewProxy) {
        if reduceMotion {
            proxy.scrollTo(feature, anchor: .center)
            highlightedFeature = feature
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(feature, anchor: .center)
                highlightedFeature = feature
            }
        }
    }

    private func clearHighlight() {
        if reduceMotion {
            highlightedFeature = nil
        } else {
            withAnimation(.easeOut(duration: 0.25)) {
                highlightedFeature = nil
            }
        }
    }

    private var restartCard: some View {
        HStack(spacing: HexaTheme.Spacing.m) {
            HexaIcons.image("arrow.clockwise.circle.fill", size: 24)
                .foregroundStyle(HexaTheme.statusWarning)
            Text(hub.restartNote)
                .font(.hexa(.body))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            Button(hub.restartButton) {
                FeatureRuntime.shared.relaunchApp()
            }
            .buttonStyle(HexaActionButtonStyle())
        }
        .padding(HexaTheme.Spacing.l)
        .background(HexaTheme.selectionBg,
                    in: RoundedRectangle(cornerRadius: HexaTheme.Radius.panel, style: .continuous))
        // Opaque base under the tint, so the rows scrolling beneath do not show through.
        .background(HexaTheme.surfaceBase,
                    in: RoundedRectangle(cornerRadius: HexaTheme.Radius.panel, style: .continuous))
    }

    /// The tally as a bar. Installing and uninstalling stay on each row's
    /// own switch: no bulk actions here.
    private var summaryCard: some View {
        HexaCard {
            HStack(spacing: HexaTheme.Spacing.m) {
                Text(String(format: hub.activeCountFormat,
                            features.availableCount, features.installableCount))
                    .font(.hexa(.heading))
                Spacer(minLength: 12)
            }
            InstalledShareBar(installed: features.availableCount, total: features.installableCount)
        }
    }

    /// Installed switches that were never once turned on, offered as one
    /// batch. People come to this page to manage the app, so the offer waits
    /// here instead of interrupting anywhere else. Keep ends it for these
    /// features, and Undo puts back exactly what left.
    @ViewBuilder
    private var neverUsedCard: some View {
        if !recentlyUninstalled.isEmpty {
            HexaSection(hub.neverUsedTitle) {
                HStack(spacing: HexaTheme.Spacing.m) {
                    HexaIcons.image("checkmark.circle.fill", size: 20)
                        .foregroundStyle(HexaTheme.statusOk)
                        .accessibilityHidden(true)
                    Text(hub.footerNote)
                        .font(.hexa(.body))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 12)
                    Button(l10n.s.menuUndo, action: undoNeverUsedUninstall)
                        .buttonStyle(HexaActionButtonStyle())
                }
            }
        } else if neverUsed.count >= Self.neverUsedMinimum {
            HexaSection(hub.neverUsedTitle) {
                Text(String(format: hub.neverUsedMessageFormat,
                            neverUsed.map { $0.hubTitle(l10n.s, hub: hub) }.joined(separator: ", ")))
                    .font(.hexa(.body))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: HexaTheme.Spacing.s) {
                    Spacer(minLength: 0)
                    Button(hub.neverUsedKeep, action: keepNeverUsed)
                        .buttonStyle(HexaActionButtonStyle())
                    Button(hub.neverUsedUninstall, action: uninstallNeverUsed)
                        .buttonStyle(HexaActionButtonStyle())
                }
            }
        }
    }

    private func refreshNeverUsed() {
        neverUsed = FeatureRuntime.shared.neverSwitchedOnFeatures()
    }

    private func uninstallNeverUsed() {
        // Read again at the click: a switch turned on in the panel since the
        // page appeared takes its feature out of the batch.
        let stillUnused = Set(FeatureRuntime.shared.neverSwitchedOnFeatures())
        let batch = neverUsed.filter(stillUnused.contains)
        guard !batch.isEmpty else {
            refreshNeverUsed()
            return
        }
        recentlyUninstalled = batch
        withAnimation(.easeOut(duration: 0.22)) {
            FeatureRuntime.shared.setAvailable(batch, false)
        }
    }

    /// Changing one's mind is also an answer to the offer, so the features
    /// that come back are kept and never offered again. None of them was
    /// ever on, and the reinstall leaves their switches off too.
    private func undoNeverUsedUninstall() {
        let batch = recentlyUninstalled
        recentlyUninstalled = []
        FeatureRuntime.shared.keep(batch)
        withAnimation(.easeOut(duration: 0.22)) {
            FeatureRuntime.shared.setAvailable(batch, true, enablingFirstInstalls: false)
        }
    }

    private func keepNeverUsed() {
        FeatureRuntime.shared.keep(neverUsed)
        withAnimation(.easeOut(duration: 0.22)) {
            refreshNeverUsed()
        }
    }

    /// The island stays near the top, with its additions in a group the user
    /// can close when they want a shorter catalog.
    private var dynamicIslandCard: some View {
        let members = AppFeature.features(in: .dynamicIsland)
        let installed = members.filter(\.isAvailable).count
        return VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            // Same inset, height and chevron column as the collapsible group headers,
            // so the title, count and bar line up. The chevron stays hidden: the island
            // does not collapse.
            HStack(spacing: HexaTheme.Spacing.s) {
                groupHeader(.dynamicIsland, installed: installed, total: members.count)
                HexaIcons.image("chevron.right", size: 11).hidden()
            }
            .padding(.horizontal, HexaTheme.Spacing.s)
            .frame(height: HexaTheme.Density.rowCompact)
            HexaCard {
                FeatureHubRow(feature: .notch, hub: hub,
                              isHighlighted: highlightedFeature == .notch)
                    .id(AppFeature.notch)
                HexaDisclosure(
                    isExpanded: $islandExtensionsExpanded
                ) {
                    Text(FeatureStrings.notch(l10n.language).modules)
                        .font(.hexa(.body))
                } content: {
                    VStack(spacing: 0) {
                        ForEach(members.filter { $0 != .notch }, id: \.self) { feature in
                            FeatureHubRow(feature: feature, hub: hub,
                                          isHighlighted: highlightedFeature == feature)
                                .id(feature)
                            if feature != members.last {
                                HairlineDivider().padding(.leading, HexaTheme.Spacing.s)
                            }
                        }
                    }
                }
            }
        }
        .id(FeatureGroup.dynamicIsland)
    }

    /// Groups start open; LazyVStack builds distant groups as they enter view.
    /// Closing a group removes its feature rows until the user reopens it.
    /// DEC-017: o header do grupo fica FORA do cartão (mesma anatomia do
    /// cartão da ilha); o disclosure permanece, com o HexaCard como conteúdo.
    /// Sem recuo: o cartão tem a mesma margem do cartão da ilha.
    private func groupCard(_ group: FeatureGroup) -> some View {
        let members = AppFeature.features(in: group)
        let installed = members.filter(\.isAvailable).count
        return HexaDisclosure(isExpanded: Binding(
            get: { expandedGroups.contains(group) },
            set: { expanded in
                if expanded { expandedGroups.insert(group) }
                else { expandedGroups.remove(group) }
            }
        ), indentsContent: false) {
            groupHeader(group, installed: installed, total: members.count)
        } content: {
            HexaCard {
                VStack(spacing: 0) {
                    ForEach(members, id: \.self) { feature in
                        FeatureHubRow(
                            feature: feature,
                            hub: hub,
                            isHighlighted: highlightedFeature == feature
                        )
                        .id(feature)
                        if feature != members.last {
                            HairlineDivider().padding(.leading, HexaTheme.Spacing.s)
                        }
                    }
                    if group == .monitor,
                       !FeatureVisibilitySupport.monitorFeatures.contains(where: \.isAvailable) {
                        Text(hub.monitorAllOffNote)
                            .font(.hexa(.label))
                            .foregroundStyle(HexaTheme.fgSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .id(group)
    }

    private func groupHeader(_ group: FeatureGroup, installed: Int, total: Int) -> some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            SectionLabel(title: groupTitle(group))
            Spacer(minLength: 12)
            Text("\(installed)/\(total)")
                .font(.hexa(.data))
                .foregroundStyle(HexaTheme.fgSecondary)
            InstalledShareBar(installed: installed, total: total)
                .controlSize(.small)
                .frame(width: 64)
        }
    }

    private func groupTitle(_ group: FeatureGroup) -> String {
        switch group {
        case .sound: return hub.groupSound
        case .energyDisplay: return hub.groupEnergyDisplay
        case .tools: return hub.groupTools
        case .dynamicIsland: return FeatureStrings.notch(l10n.language).title
        case .monitor: return hub.groupMonitor
        }
    }
}

/// The installed share as the system's own bar, the one picture of "how
/// much of this is on" that needs no reading. Shared with the first-run module
/// step, whose group line shows its share the same way this page's header does.
struct InstalledShareBar: View {
    let installed: Int
    let total: Int

    var body: some View {
        // Barra de progresso: indicador de forma em fg.secondary (spec §5),
        // nunca accent.
        ProgressView(value: Double(min(installed, total)), total: Double(max(total, 1)))
            .progressViewStyle(.linear)
            .tint(HexaTheme.fgSecondary)
    }
}

// MARK: - Feature row

/// Icon, name and one line about the feature; small icons for the
/// permissions it can use and what it keeps alive; and the install switch.
/// An installed feature with a page of its own opens it from the row.
private struct FeatureHubRow: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @State private var confirmingExtensions = false
    @State private var hovering = false
    @State private var showingMetadata = false
    let feature: AppFeature
    let hub: FeatureHubStrings
    var isHighlighted: Bool = false

    private var installed: Bool { feature.isAvailable }

    private var opensSettings: Bool { installed && feature.hasNavigableSettingsDestination }

    /// Extensions still installed under this row's feature; only the Dynamic
    /// Island has any. They do nothing without it, so its uninstall asks
    /// whether they leave too.
    private var installedExtensions: [AppFeature] {
        feature == .notch ? AppFeature.dynamicIslandExtensions.filter(\.isAvailable) : []
    }

    /// Set only while this Mac cannot run the feature and it is not yet
    /// installed, so an install that predates the check keeps an ordinary
    /// row with its settings and the switch reachable.
    private var unsupportedReason: String? { feature.installBlockedReason }

    private var accessibilityTitle: String {
        let title = feature.hubTitle(l10n.s, hub: hub)
        return feature.isBeta ? "\(title). \(l10n.s.betaFeatureWarning)" : title
    }

    /// The switch reads availability itself, so it only moves once the
    /// runtime has flipped; the Dynamic Island asks about its extensions
    /// before leaving, and the switch springs back if that is cancelled.
    private var installBinding: Binding<Bool> {
        Binding(get: { installed }, set: { wanted in
            if !wanted, !installedExtensions.isEmpty {
                confirmingExtensions = true
            } else {
                flip(to: wanted)
            }
        })
    }

    var body: some View {
        HStack(spacing: HexaTheme.Spacing.m) {
            if opensSettings {
                Button {
                    FeatureWorkspaceState.shared.selectFeature(feature)
                    let isMonitorSettingsFeature = [
                        AppFeature.monitorCPU, .monitorGPU, .monitorMemory,
                        .monitorNetwork, .monitorDisk, .monitorPower,
                    ].contains(feature)
                    if isMonitorSettingsFeature {
                        FeatureWorkspaceState.shared.monitorTabIsSettings = true
                    } else if feature.hasNavigableSettingsDestination,
                              feature != .fanControl, feature != .connectedDevices {
                        FeatureWorkspaceState.shared.featureSettingsMode = true
                    }
                    SettingsRouter.shared.request(feature.settingsDestination,
                                                  sidebarFeature: feature)
                } label: {
                    rowContent(showsChevron: true)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(accessibilityTitle). \(feature.hubDescription(hub))")
                .accessibilityAddTraits(.isLink)
                .accessibilityRemoveTraits(.isButton)
            } else {
                rowContent(showsChevron: false)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(accessibilityTitle). \(feature.hubDescription(hub))")
                    .opacity(unsupportedReason == nil ? 1 : 0.4)
                    .saturation(unsupportedReason == nil ? 1 : 0)
            }
            metadata
            installSwitch
        }
        .padding(.vertical, HexaTheme.Spacing.s)
        .padding(.horizontal, HexaTheme.Spacing.s)
        .background(rowFill, in: RoundedRectangle(cornerRadius: HexaTheme.Radius.panel, style: .continuous))
        .onHover { hovering = $0 }
        .alert(hub.notchUninstallTitle, isPresented: $confirmingExtensions) {
            Button(hub.notchUninstallWithExtensions) { flip(to: false, alongside: installedExtensions) }
            Button(hub.notchUninstallKeepExtensions) { flip(to: false) }
            Button(l10n.s.uninstallerCancel, role: .cancel) {}
        } message: {
            Text(String(format: hub.notchUninstallMessageFormat,
                        installedExtensions.map { $0.hubTitle(l10n.s, hub: hub) }
                            .joined(separator: ", ")))
        }
    }

    private var rowFill: Color {
        if isHighlighted { return HexaTheme.selectionBg }
        return hovering && opensSettings ? HexaTheme.fgPrimary.opacity(0.04) : Color.clear
    }

    private func rowContent(showsChevron: Bool) -> some View {
        HStack(spacing: HexaTheme.Spacing.m) {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                HStack(spacing: HexaTheme.Spacing.xs) {
                    Text(feature.hubTitle(l10n.s, hub: hub))
                        .font(.hexa(.body))
                        .foregroundStyle(installed ? HexaTheme.fgPrimary : HexaTheme.fgSecondary)
                    if feature.isBeta {
                        HexaStateTag(l10n.s.betaBadge, kind: .warning)
                            .accessibilityHidden(true)
                    }
                }
                Text(feature.hubDescription(hub))
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if showsChevron {
                HexaIcons.image("chevron.forward", size: 11)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgTertiary)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// Use a readable label instead of a row of tiny, unexplained symbols.
    @ViewBuilder
    private var metadata: some View {
        if !feature.permissions.isEmpty {
            let explanation = feature.permissions.map { $0.name(hub) }
                .joined(separator: "\n")
            Button(hub.tabPermissions) {
                showingMetadata.toggle()
            }
            .buttonStyle(.plain)
            .font(.hexa(.label))
            .foregroundStyle(HexaTheme.fgSecondary)
            .help(explanation)
            .accessibilityLabel(explanation)
            .popover(isPresented: $showingMetadata) {
                // Symbols differ in width, so a centered icon column keeps the texts aligned.
                Grid(alignment: .leading, horizontalSpacing: HexaTheme.Spacing.s, verticalSpacing: HexaTheme.Spacing.s) {
                    ForEach(feature.permissions, id: \.self) { permission in
                        GridRow {
                            HexaIcons.image(permission.symbolName)
                                .gridColumnAlignment(.center)
                                .accessibilityHidden(true)
                            Text(permission.name(hub))
                        }
                    }
                }
                .padding(HexaTheme.Spacing.m)
            }
        }
    }

    @ViewBuilder
    private var installSwitch: some View {
        let toggle = Toggle(accessibilityTitle, isOn: installBinding)
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        if let reason = unsupportedReason {
            // .help() never fires on a disabled control, so the tooltip
            // has to sit on this wrapper. Flattening it loses the only
            // place the reason is shown.
            HStack(spacing: 0) {
                toggle.disabled(true)
            }
            .help(reason)
            .accessibilityLabel("\(accessibilityTitle). \(reason)")
        } else {
            toggle
        }
    }

    private func flip(to install: Bool, alongside companions: [AppFeature] = []) {
        withAnimation(.easeOut(duration: 0.22)) {
            FeatureRuntime.shared.setAvailable([feature] + companions, install)
        }
    }
}

// MARK: - Permissions portal

struct PermissionsPortalSections: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var music = NotchMusicService.shared
    let hub: FeatureHubStrings
    let visiblePermissions: [AppPermission]
    @State private var automation: [Permissions.AutomationTarget: Permissions.AutomationStatus] = [:]
    @State private var pollingDemandID = UUID()

    init(hub: FeatureHubStrings,
         visiblePermissions: [AppPermission] = AppPermission.allCases.filter { permission in
             AppFeature.allCases.contains { $0.permissions.contains(permission) }
         }) {
        self.hub = hub
        self.visiblePermissions = visiblePermissions
    }

    /// macOS keeps every Automation target under one Settings pane, so the
    /// portal shows them as one row with a line per target.
    static let automationPermissions: [AppPermission] = [.automationFinder, .automationTerminal, .automationPlayback]
    /// Permissions no app can ask for: macOS asks the first time a feature
    /// reaches what they protect.
    static let osPromptedPermissions: [AppPermission] = [.filesAndFolders, .appManagement, .audioCapture]

    /// Full Disk Access already covers the folders Files and Folders guards,
    /// so that row only matters while Full Disk Access is off.
    static func shownPermissions(_ permissions: [AppPermission], fullDiskAccess: Bool) -> [AppPermission] {
        permissions.filter { $0 != .filesAndFolders || !fullDiskAccess }
    }

    private var shown: [AppPermission] {
        Self.shownPermissions(visiblePermissions, fullDiskAccess: permissions.fullDiskAccess)
    }

    private var directPermissions: [AppPermission] {
        shown.filter {
            !Self.automationPermissions.contains($0) && !Self.osPromptedPermissions.contains($0)
        }
    }

    private var automationRows: [AppPermission] {
        shown.filter { Self.automationPermissions.contains($0) }
    }

    private var osPromptedRows: [AppPermission] {
        shown.filter { Self.osPromptedPermissions.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.m) {
            ForEach(directPermissions, id: \.self) { permission in
                row(permission)
                if permission != directPermissions.last || !automationRows.isEmpty {
                    HairlineDivider().padding(.leading, HexaTheme.Spacing.xxl)
                }
            }
            if !automationRows.isEmpty {
                PermissionAutomationGroup(hub: hub,
                                          statuses: automationRows.map(status(for:))) {
                    ForEach(automationRows, id: \.self) { permission in
                        row(permission, nested: true)
                    }
                }
            }
            if !osPromptedRows.isEmpty {
                if !directPermissions.isEmpty || !automationRows.isEmpty {
                    HairlineDivider()
                }
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                    SectionLabel(hub.osPromptedTitle)
                    Text(hub.osPromptedCaption).hexaCaption()
                }
                ForEach(osPromptedRows, id: \.self) { permission in
                    row(permission)
                    if permission != osPromptedRows.last {
                        HairlineDivider().padding(.leading, HexaTheme.Spacing.xxl)
                    }
                }
            }
        }
        .onAppear {
            // Statuses that only refresh at launch/activation get a fresh
            // read the moment the portal shows; automation is checked off the
            // main thread because the AE round trip can block briefly.
            permissions.refresh()
            if visiblePermissions.contains(.accessibility)
                || visiblePermissions.contains(.screenRecording) {
                permissions.setActivePermissionSurface(pollingDemandID, visible: true)
            }
            readAutomation()
        }
        .onDisappear {
            permissions.setActivePermissionSurface(pollingDemandID, visible: false)
        }
    }

    private func row(_ permission: AppPermission, nested: Bool = false) -> some View {
        PermissionPortalRow(permission: permission,
                            hub: hub,
                            status: status(for: permission),
                            finderAutomation: automation[.finder],
                            terminalAutomation: automation[.terminal],
                            refreshAutomation: readAutomation,
                            isReading: isReading(permission),
                            nested: nested)
    }

    private func readAutomation() {
        DispatchQueue.global(qos: .userInitiated).async {
            let finder = Permissions.automationStatus(for: .finder)
            let terminal = Permissions.automationStatus(for: .terminal)
            DispatchQueue.main.async {
                automation = [.finder: finder, .terminal: terminal]
            }
        }
    }

    /// Automação de Finder e Terminal só tem resposta depois da leitura fora da
    /// thread principal; antes dela o dicionário não tem entrada para o alvo.
    private func isReading(_ permission: AppPermission) -> Bool {
        switch permission {
        case .automationFinder: return automation[.finder] == nil
        case .automationTerminal: return automation[.terminal] == nil
        default: return false
        }
    }

    /// Os leitores de estado que o Portal já usava, agora explícitos: a leitura
    /// de Automação é a que o próprio Portal lê fora da thread principal.
    private var readers: PermissionPortalRow.Readers {
        .live(finderAutomation: automation[.finder], terminalAutomation: automation[.terminal])
    }

    /// O Portal delega a leitura ao mapeamento extraído, que devolve exatamente
    /// o mesmo resultado de antes. O estado do player lê o serviço de música
    /// observado por esta view, como sempre leu.
    private func status(for permission: AppPermission) -> PermissionPortalRow.Status {
        switch permission {
        case .automationPlayback:
            return PermissionPortalRow.playbackStatus(for: music.automationAvailability?.access)
        default:
            return PermissionPortalRow.status(for: permission, readers: readers)
        }
    }
}

struct PermissionPortalRow: View {
    enum Status: Equatable { case granted, missing, unknown }

    /// Os leitores de estado de cada permissão, explícitos para que o
    /// mapeamento continue testável sem tocar os singletons do app.
    /// `live` é a leitura de produção, a mesma de antes da extração.
    struct Readers {
        var accessibility: Bool
        var screenRecording: Bool
        var fullDiskAccess: Bool
        var notifications: Permissions.NotificationPermissionState
        var calendarAccess: EKAuthorizationStatus
        var bluetooth: Permissions.BluetoothPermissionState
        var finderAutomation: Permissions.AutomationStatus?
        var terminalAutomation: Permissions.AutomationStatus?
        var playbackAccess: NotchMusicAutomation.Access?
        /// Só toca o mixer quando ele está instalado, como antes da extração.
        var audioCaptureNeedsPermission: Bool

        static func live(finderAutomation: Permissions.AutomationStatus?,
                         terminalAutomation: Permissions.AutomationStatus?) -> Readers {
            let permissions = Permissions.shared
            return Readers(accessibility: permissions.accessibility,
                           screenRecording: permissions.screenRecording,
                           fullDiskAccess: permissions.fullDiskAccess,
                           notifications: permissions.notifications,
                           calendarAccess: permissions.calendarAccess,
                           bluetooth: permissions.bluetooth,
                           finderAutomation: finderAutomation,
                           terminalAutomation: terminalAutomation,
                           playbackAccess: NotchMusicService.shared.automationAvailability?.access,
                           audioCaptureNeedsPermission: AppFeature.mixer.isAvailable
                               && AppVolumeMixer.shared.needsPermission)
        }
    }

    static func playbackStatus(for access: NotchMusicAutomation.Access?) -> Status {
        switch access {
        case .granted:
            return .granted
        case .consent, .denied:
            return .missing
        case .unavailable, .none:
            return .unknown
        }
    }

    /// O mapeamento de estado do Portal, numa função pura: `.unknown` continua
    /// sendo o rótulo honesto onde o macOS não expõe o estado, e não vira
    /// pendente.
    static func status(for permission: AppPermission, readers: Readers) -> Status {
        switch permission {
        case .accessibility: return readers.accessibility ? .granted : .missing
        case .screenRecording: return readers.screenRecording ? .granted : .missing
        case .fullDiskAccess: return readers.fullDiskAccess ? .granted : .missing
        case .filesAndFolders:
            // Whether a protected folder is reachable depends on what the
            // feature doing the reading touches; nothing reads it up front.
            return .unknown
        case .notifications:
            switch readers.notifications {
            case .granted: return .granted
            case .denied, .undetermined: return .missing
            case .unknown: return .unknown
            }
        case .automationFinder: return automationStatus(readers.finderAutomation)
        case .automationTerminal: return automationStatus(readers.terminalAutomation)
        case .automationPlayback: return playbackStatus(for: readers.playbackAccess)
        case .audioCapture:
            // No public check exists for system audio capture; the mixer
            // reports a failed tap, which is the one readable signal.
            return readers.audioCaptureNeedsPermission ? .missing : .unknown
        case .calendar:
            return readers.calendarAccess == .fullAccess ? .granted : .missing
        case .appManagement:
            // macOS has no public preflight API for this permission. The
            // system records the app only after its first protected write.
            return .unknown
        case .bluetooth:
            switch readers.bluetooth {
            case .granted: return .granted
            case .denied, .undetermined: return .missing
            case .unknown: return .unknown
            }
        }
    }

    /// Um destino de Automação que não pôde ser consultado lê como não
    /// verificável, nunca como pendente.
    static func automationStatus(_ status: Permissions.AutomationStatus?) -> Status {
        switch status {
        case .granted: return .granted
        case .denied, .undetermined: return .missing
        case .notDeterminable, .none: return .unknown
        }
    }

    /// Se o macOS ainda aceita um pedido para a permissão. É a regra de
    /// `hasRequestFlow`, agora pura e com os leitores injetados: sempre para
    /// Acessibilidade, Gravação de Tela e Acesso Total ao Disco; conforme o
    /// estado para Notificações, Calendário, Bluetooth e Automações; nunca para
    /// Arquivos e Pastas, Captura de Áudio e Gerenciamento de Apps.
    static func canAskAgain(for permission: AppPermission, readers: Readers) -> Bool {
        switch permission {
        case .accessibility, .screenRecording, .fullDiskAccess: return true
        case .notifications: return readers.notifications == .undetermined
        case .calendar: return readers.calendarAccess == .notDetermined
            || readers.calendarAccess == .writeOnly
        case .bluetooth: return readers.bluetooth == .undetermined
        // macOS only shows the consent prompt while the answer is undetermined;
        // once denied, the switch in System Settings is the only way back.
        case .automationFinder: return AutomationConsentFlow.canAsk(readers.finderAutomation)
        case .automationTerminal: return AutomationConsentFlow.canAsk(readers.terminalAutomation)
        case .automationPlayback: return AutomationConsentFlow.canAsk(readers.playbackAccess)
        case .filesAndFolders, .audioCapture, .appManagement: return false
        }
    }

    @ObservedObject private var l10n = L10n.shared
    let permission: AppPermission
    let hub: FeatureHubStrings
    let status: Status
    let finderAutomation: Permissions.AutomationStatus?
    let terminalAutomation: Permissions.AutomationStatus?
    let refreshAutomation: () -> Void
    /// A lista de "quem usa" injetada. `nil` mantém o cálculo de sempre do
    /// Portal (quem usa a permissão agora); o passo de permissões injeta os
    /// módulos instalados que a exigem.
    var usedByNames: [String]? = nil
    /// Leitura pedida e ainda sem resposta: o chip mostra progresso, e não
    /// "não verificável", que seria um veredito antes da hora.
    var isReading = false
    /// A target inside the Automation group: the group carries the tile and
    /// the System Settings button, shared by every target.
    var nested = false

    var body: some View {
        HStack(alignment: .top, spacing: HexaTheme.Spacing.m) {
            // The tile wears the status color, so a glance down the list
            // shows what is granted before any word is read.
            if !nested {
                PermissionStatusTile(symbol: permission.symbolName, color: statusColor)
            }
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                HStack(spacing: HexaTheme.Spacing.s) {
                    Text(permission.name(hub))
                        .font(.hexa(.body))
                    statusChip
                }
                Text(permission.explainer(hub))
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(usedByLine)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                if status == .granted, usedByNames == nil, activeFeatures.isEmpty {
                    unusedCard
                }
                HStack(spacing: HexaTheme.Spacing.s) {
                    if OnboardingPermissionSet.showsGrantAction(for: status, canAskAgain: canAskAgain) {
                        HexaAccessButton(icon: accessIcon, title: hub.requestButton) {
                            request()
                        }
                    }
                    if !nested {
                        HexaAccessButton(icon: "gearshape", title: hub.openSystemSettings) {
                            openSystemSettings()
                        }
                    }
                }
                .controlSize(.small)
                .padding(.top, HexaTheme.Spacing.xs)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var activeFeatures: [AppFeature] {
        AppFeature.activeFeatures(using: permission).filter {
            permission != .notifications || $0 != .monitorPower || PowerSampler.hasInternalBattery
        }
    }

    private var usedByLine: String {
        let names = usedByNames ?? activeFeatures.map { $0.hubTitle(l10n.s, hub: hub) }
        guard !names.isEmpty else { return hub.usedByNone }
        return String(format: hub.usedByFormat, names.joined(separator: ", "))
    }

    @ViewBuilder
    private var statusChip: some View {
        if isReading {
            HStack(spacing: HexaTheme.Spacing.xs) {
                ProgressView()
                    .controlSize(.small)
                Text(l10n.s.loadingMessage)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(l10n.s.loadingMessage)
        } else {
            // Estado com dot colorido e texto neutro (HexaStateTag); "unknown"
            // não é um estado dos status.*: fica em texto discreto, sem cor.
            switch status {
            case .granted:
                HexaStateTag(chipText, kind: .ok)
            case .missing:
                HexaStateTag(chipText, kind: .warning)
            case .unknown:
                Text(chipText)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgTertiary)
            }
        }
    }

    /// Icon for the actions that leave the app for a system surface; the
    /// permission's own subject where the catalog has one, gearshape otherwise.
    private var accessIcon: String {
        switch permission {
        case .accessibility: return "accessibility"
        case .screenRecording: return "video"
        case .audioCapture: return "mic"
        default: return "gearshape"
        }
    }

    private var statusColor: Color { Self.color(for: status) }

    static func color(for status: Status) -> Color {
        switch status {
        case .granted: return HexaTheme.statusOk
        case .missing: return HexaTheme.statusWarning
        case .unknown: return HexaTheme.fgTertiary
        }
    }

    private var chipText: String {
        switch status {
        case .granted: return hub.statusGranted
        case .missing: return hub.statusMissing
        case .unknown: return hub.statusUnknown
        }
    }

    private var unusedCard: some View {
        Text(hub.unusedBanner)
            .font(.hexa(.label))
            .foregroundStyle(HexaTheme.fgSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(HexaTheme.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                    .fill(HexaTheme.surfaceInset)
            )
    }

    /// A linha pergunta ao mapeamento se o macOS ainda aceita um pedido, com os
    /// leitores de produção. A decisão em si mora em `canAskAgain(for:readers:)`.
    private var canAskAgain: Bool {
        Self.canAskAgain(for: permission,
                         readers: .live(finderAutomation: finderAutomation,
                                        terminalAutomation: terminalAutomation))
    }

    private func request() {
        switch permission {
        case .accessibility: Permissions.shared.requestAccessibility()
        case .screenRecording: Permissions.shared.requestScreenRecording()
        case .fullDiskAccess: Permissions.shared.requestFullDiskAccess()
        case .notifications:
            Permissions.shared.requestNotifications()
        case .calendar: Permissions.shared.requestCalendar()
        case .bluetooth:
            Permissions.shared.requestBluetooth()
        case .automationFinder:
            AutomationConsentFlow.request(.finder, completion: refreshAutomation)
        case .automationTerminal:
            AutomationConsentFlow.request(.terminal, completion: refreshAutomation)
        case .automationPlayback:
            NotchMusicService.shared.requestAutomationAccess()
        case .filesAndFolders, .audioCapture, .appManagement:
            break
        }
    }

    private func openSystemSettings() {
        switch permission {
        case .accessibility: Permissions.shared.openAccessibilitySettings()
        case .screenRecording: Permissions.shared.openScreenRecordingSettings()
        case .fullDiskAccess: Permissions.shared.openFullDiskAccessSettings()
        case .filesAndFolders: Permissions.shared.openFilesAndFoldersSettings()
        case .notifications: Permissions.shared.openNotificationSettings()
        case .automationFinder, .automationTerminal, .automationPlayback: Permissions.shared.openAutomationSettings()
        case .audioCapture: Permissions.shared.openAudioCaptureSettings()
        case .calendar: Permissions.shared.openCalendarSettings()
        case .appManagement: Permissions.shared.openAppManagementSettings()
        case .bluetooth: Permissions.shared.openBluetoothSettings()
        }
    }
}

/// The square that leads a permission row, in the color of its status.
struct PermissionStatusTile: View {
    let symbol: String
    let color: Color

    var body: some View {
        HexaIcons.image(symbol, size: 13)
            .font(.hexa(.body))
            .foregroundStyle(color)
            .frame(width: 30, height: 30)
            .background(color.opacity(0.14),
                        in: RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
    }
}

/// Every Automation target in one row. macOS lists them under one Settings
/// pane, so one button reaches all of them; each target keeps its own line
/// with its status and, while macOS still accepts it, its own request.
struct PermissionAutomationGroup<Targets: View>: View {
    let hub: FeatureHubStrings
    let statuses: [PermissionPortalRow.Status]
    @ViewBuilder let targets: () -> Targets

    static func combinedStatus(_ statuses: [PermissionPortalRow.Status]) -> PermissionPortalRow.Status {
        if statuses.contains(.missing) { return .missing }
        if !statuses.isEmpty, statuses.allSatisfy({ $0 == .granted }) { return .granted }
        return .unknown
    }

    var body: some View {
        HStack(alignment: .top, spacing: HexaTheme.Spacing.m) {
            PermissionStatusTile(symbol: AppPermission.automationFinder.symbolName,
                                 color: PermissionPortalRow.color(for: Self.combinedStatus(statuses)))
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                Text(hub.permAutomation)
                    .font(.hexa(.body))
                Text(hub.explainAutomation)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                targets()
                HexaAccessButton(icon: "gearshape", title: hub.openSystemSettings) {
                    Permissions.shared.openAutomationSettings()
                }
                .controlSize(.small)
            }
        }
    }
}

// MARK: - Titles, descriptions and permission names

extension AppFeature {
    /// Titles reuse the strings users already see across the app; only names
    /// with no clean existing form live in the hub strings.
    func hubTitle(_ s: Strings, hub: FeatureHubStrings) -> String {
        switch self {
        case .mixer: return s.mixerSection
        case .keepAwake: return s.keepAwakeTitle
        case .brightness: return FeatureStrings.brightness(L10n.shared.language).pageTitle
        case .mediaTools: return s.mediaName
        case .cleaner: return s.cleanerName
        case .maintenanceTasks: return hub.titleMaintenanceTasks
        case .uninstaller: return s.uninstallerName
        case .killProcess: return FeatureStrings.killProcess(L10n.shared.language).pageTitle
        case .portManager: return FeatureStrings.portManager(L10n.shared.language).title
        case .appUpdates: return FeatureStrings.appUpdates(L10n.shared.language).pageTitle
        case .screenshot: return FeatureStrings.screenshot(L10n.shared.language).pageTitle
        case .screenOCR: return s.ocrName
        case .dockDisplayLock: return FeatureStrings.dockDisplayLock(L10n.shared.language).title
        case .menuBarHiding: return FeatureStrings.menuBarHiding(L10n.shared.language).title
        case .notchGestures: return FeatureStrings.notchGestures(L10n.shared.language).title
        case .notchTimer: return FeatureStrings.notchActivities(L10n.shared.language).timer
        case .notchAccessories: return FeatureStrings.notchActivities(L10n.shared.language).accessories
        case .notchNotifications: return FeatureStrings.notchNotifications(L10n.shared.language).title
        case .notchLyrics: return FeatureStrings.notchMusicExtras(L10n.shared.language).lyrics
        case .notchQueue: return FeatureStrings.notchMusicExtras(L10n.shared.language).queue
        case .notchLiveEqualizer: return FeatureStrings.notchMusicExtras(L10n.shared.language).liveEqualizer
        case .notchDownloads: return FeatureStrings.notchFiles(L10n.shared.language).downloadsTitle
        case .notchCalendar: return FeatureStrings.notchCalendar(L10n.shared.language).title
        case .notchWatch: return FeatureStrings.notchWatch(L10n.shared.language).title
        case .notch: return FeatureStrings.notch(L10n.shared.language).title
        case .monitorCPU: return s.monitorShowCPU
        case .monitorGPU: return s.monitorShowGPU
        case .monitorMemory: return s.monitorShowMemory
        case .monitorNetwork: return s.monitorShowNetwork
        case .monitorDisk: return s.diskSection
        case .monitorPower: return s.powerSection
        case .connectedDevices: return FeatureStrings.connectedDevices(L10n.shared.language).title
        case .fanControl: return FeatureStrings.fanControl(L10n.shared.language).title
        }
    }

    func hubDescription(_ hub: FeatureHubStrings) -> String {
        switch self {
        case .mixer: return hub.descMixer
        case .keepAwake: return hub.descKeepAwake
        case .brightness: return FeatureStrings.brightness(L10n.shared.language).hubDescription
        case .mediaTools: return hub.descMediaTools
        case .cleaner: return hub.descCleaner
        case .maintenanceTasks: return hub.descMaintenanceTasks
        case .uninstaller: return hub.descUninstaller
        case .killProcess: return FeatureStrings.killProcess(L10n.shared.language).hubDescription
        case .portManager: return FeatureStrings.portManager(L10n.shared.language).hubDescription
        case .appUpdates: return FeatureStrings.appUpdates(L10n.shared.language).hubDescription
        case .screenshot: return FeatureStrings.screenshot(L10n.shared.language).hubDescription
        case .screenOCR: return hub.descScreenOCR
        case .dockDisplayLock: return FeatureStrings.dockDisplayLock(L10n.shared.language).hubDescription
        case .menuBarHiding: return FeatureStrings.menuBarHiding(L10n.shared.language).hubDescription
        case .notchGestures: return FeatureStrings.notchGestures(L10n.shared.language).description
        case .notchTimer: return FeatureStrings.notchActivities(L10n.shared.language).timerDescription
        case .notchAccessories: return FeatureStrings.notchActivities(L10n.shared.language).accessoryDescription
        case .notchNotifications: return FeatureStrings.notchNotifications(L10n.shared.language).description
        case .notchLyrics: return FeatureStrings.notchMusicExtras(L10n.shared.language).lyricsDescription
        case .notchQueue: return FeatureStrings.notchMusicExtras(L10n.shared.language).queueDescription
        case .notchLiveEqualizer: return FeatureStrings.notchMusicExtras(L10n.shared.language).liveEqualizerDescription
        case .notchDownloads: return FeatureStrings.notchFiles(L10n.shared.language).downloadsDescription
        case .notchCalendar: return FeatureStrings.notchCalendar(L10n.shared.language).description
        case .notchWatch: return FeatureStrings.notchWatch(L10n.shared.language).description
        case .notch: return FeatureStrings.notch(L10n.shared.language).description
        case .monitorCPU: return hub.descMonitorCPU
        case .monitorGPU: return hub.descMonitorGPU
        case .monitorMemory: return hub.descMonitorMemory
        case .monitorNetwork: return hub.descMonitorNetwork
        case .monitorDisk: return hub.descMonitorDisk
        case .monitorPower: return hub.descMonitorPower
        case .connectedDevices: return FeatureStrings.connectedDevices(L10n.shared.language).hubDescription
        case .fanControl: return FeatureStrings.fanControl(L10n.shared.language).hubDescription
        }
    }
}

extension AppPermission {
    func name(_ hub: FeatureHubStrings) -> String {
        switch self {
        case .accessibility: return hub.permAccessibility
        case .screenRecording: return hub.permScreenRecording
        case .fullDiskAccess: return hub.permFullDisk
        case .filesAndFolders: return hub.permFilesAndFolders
        case .notifications: return hub.permNotifications
        case .automationFinder: return hub.permAutomationFinder
        case .automationTerminal: return hub.permAutomationTerminal
        case .automationPlayback: return FeatureStrings.notchMusicExtras(L10n.shared.language).automationPermission
        case .audioCapture: return hub.permAudioCapture
        case .calendar: return FeatureStrings.notchCalendar(L10n.shared.language).title
        case .appManagement: return hub.permAppManagement
        case .bluetooth: return hub.permBluetooth
        }
    }

    func explainer(_ hub: FeatureHubStrings) -> String {
        switch self {
        case .accessibility: return hub.explainAccessibility
        case .screenRecording: return hub.explainScreenRecording
        case .fullDiskAccess: return hub.explainFullDisk
        case .filesAndFolders: return hub.explainFilesAndFolders
        case .notifications: return hub.explainNotifications
        case .automationFinder: return hub.explainAutomationFinder
        case .automationTerminal: return hub.explainAutomationTerminal
        case .automationPlayback: return FeatureStrings.notchMusicExtras(L10n.shared.language).automationExplanation
        case .audioCapture: return hub.explainAudioCapture
        case .calendar: return FeatureStrings.notchCalendar(L10n.shared.language).permission
        case .appManagement: return hub.explainAppManagement
        case .bluetooth: return hub.explainBluetooth
        }
    }
}
