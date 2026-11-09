// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import SwiftUI

/// The app update list, shared by the Settings page and the menu bar panel so
/// both look and behave the same. `compact` shrinks it for the panel.
struct AppUpdatesListView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var updates = AppUpdatesService.shared
    @ObservedObject private var homebrew = HomebrewManager.shared
    @AppStorage(DefaultsKey.appUpdatesIncludeOnlineCatalog)
    private var includeOnlineCatalog = true
    @AppStorage(DefaultsKey.appUpdatesIncludeAppStore)
    private var includeAppStore = true
    @State private var showOperationDetails = false
    @State private var rulesExpanded = false
    var compact = false

    private var text: AppUpdateStrings { FeatureStrings.appUpdates(l10n.language) }
    private var isBusy: Bool { updates.isChecking || homebrew.operation != nil }
    private var storeCoverageIncomplete: Bool {
        includeAppStore && !updates.appStoreAvailable
    }
    private var coverageIncomplete: Bool {
        updates.hasCheckedThisSession
            && !updates.isChecking
            && (storeCoverageIncomplete || (includeOnlineCatalog && !updates.onlineCatalogAvailable))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? HexaTheme.Spacing.s : HexaTheme.Spacing.l) {
            VStack(alignment: .leading, spacing: compact ? HexaTheme.Spacing.s : HexaTheme.Spacing.m) {
                summaryRow
                    .padding(.bottom, compact ? 0 : HexaTheme.Spacing.m)
                if updates.items.isEmpty {
                    emptyState
                } else {
                    if updates.selectableCount > 0 { selectionBar }
                    list
                    if updates.selectableCount > 0 { updateButton }
                }
            }
            if !updates.rules.isEmpty { rulesSection }
            if coverageIncomplete {
                incompleteCheck
            }
            if let status = homebrew.operationStatus {
                HomebrewOperationStatusView(status: status,
                                            log: homebrew.log,
                                            terminalFallbackCommand: homebrew.terminalFallbackCommand,
                                            compact: compact,
                                            showDetails: $showOperationDetails,
                                            onCancel: homebrew.cancelOperation,
                                            onClear: homebrew.clearLog,
                                            onOpenTerminal: homebrew.openTerminalFallback)
                    .padding(HexaTheme.Spacing.xs)
                // An upgrade from this list stopped on an untrusted tap; the
                // card trusts it and runs the same upgrade again.
                if status.action == .upgradeAll, let tap = homebrew.untrustedTap {
                    HomebrewTrustCard(tap: tap, compact: compact)
                    if let error = homebrew.errorMessage, !error.isEmpty {
                        HexaStatusNote(message: error, icon: "exclamationmark.triangle.fill")
                            .lineLimit(3)
                    }
                }
            }
            if let error = updates.lastError, !error.isEmpty {
                HexaStatusNote(message: error, icon: "exclamationmark.triangle.fill")
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Header

    private var summaryRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: HexaTheme.Spacing.s) {
            // No title here: both hosts already name the tool right above,
            // and repeating it made the card read like a second window.
            Text(lastCheckLine)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
            Spacer(minLength: 0)
            Button {
                updates.check(forceCatalogRefresh: true)
            } label: {
                if updates.isChecking {
                    HStack(spacing: HexaTheme.Spacing.xs) {
                        ProgressView().controlSize(.mini)
                        Text(text.checking)
                    }
                    .font(compact ? .hexa(.label) : .hexa(.body))
                } else {
                    Label(text.checkNow, hexaIcon: "arrow.clockwise")
                        .font(compact ? .hexa(.label) : .hexa(.body))
                }
            }
            .buttonStyle(HexaActionButtonStyle())
            .controlSize(.small)
            .disabled(isBusy)
        }
    }

    private var lastCheckLine: String {
        guard let last = updates.lastCheck else { return text.neverChecked }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        // Named style so a check that just ran reads "now" instead of the
        // literal "in 0 seconds".
        formatter.dateTimeStyle = .named
        return String(format: text.lastCheckFormat,
                      formatter.localizedString(for: last, relativeTo: Date()))
    }

    // MARK: - States

    @ViewBuilder
    private var emptyState: some View {
        // Primeira leitura desta sessão: ainda não há resultado para afirmar nada.
        if updates.isChecking, !updates.hasCheckedThisSession {
            HexaBusyState(variant: .compact, message: text.checking)
        } else {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                if updates.hasCheckedThisSession, !updates.isChecking {
                    Label(coverageIncomplete ? text.partialUpToDate
                          : (updates.rules.isEmpty ? text.upToDate : text.noVisibleUpdates),
                          hexaIcon: coverageIncomplete || !updates.rules.isEmpty
                              ? "info.circle" : "checkmark.circle.fill")
                        .font(compact ? .hexa(.label) : .hexa(.body))
                        .foregroundStyle(coverageIncomplete || !updates.rules.isEmpty
                                         ? HexaTheme.fgSecondary : HexaTheme.statusOk)
                }
                Text(text.coverageNote)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var incompleteCheck: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            HexaStatusNote(message: text.incompleteCheck, icon: "exclamationmark.triangle.fill")
            if !updates.uncheckedAppNames.isEmpty {
                Text(updates.uncheckedAppNames.joined(separator: ", "))
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .lineLimit(compact ? 3 : nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .help(updates.uncheckedAppNames.joined(separator: ", "))
            }
            Text(text.onlineUnavailable)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if storeCoverageIncomplete {
                Button(text.openAppStore) { updates.openAppStoreUpdates() }
                    .buttonStyle(.link)
                    .font(.hexa(.label))
            }
        }
    }

    // MARK: - Rules

    private var rulesSection: some View {
        HexaDisclosure(isExpanded: $rulesExpanded) {
            Text(text.rulesTitle).font(.hexa(.label))
        } content: {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                Text(text.rulesHint)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if compact {
                    OverlayScrollView { ruleRows }
                        .frame(height: CGFloat(min(updates.rules.count, 3)) * 54)
                } else {
                    ruleRows
                }
            }
            .padding(.top, HexaTheme.Spacing.xs)
        }
        .font(.hexa(.label))
    }

    private var ruleRows: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            ForEach(updates.rules) { rule in
                HStack(spacing: HexaTheme.Spacing.s) {
                    VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                        Text(rule.name).fontWeight(.medium).lineLimit(1)
                        Text(rule.version.map { String(format: text.skippedVersionFormat, $0) }
                             ?? text.excludedApp)
                            .foregroundStyle(HexaTheme.fgSecondary)
                            .lineLimit(1)
                    }
                    .help(rule.bundleID)
                    Spacer(minLength: 0)
                    Button(text.removeRule) { updates.removeRule(rule) }
                        .buttonStyle(HexaActionButtonStyle())
                        .controlSize(.small)
                        .disabled(isBusy)
                        .accessibilityLabel("\(text.removeRule): \(rule.name)")
                }
                .frame(height: compact ? 48 : nil)
            }
        }
    }

    // MARK: - Selection

    private var selectionBar: some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            Button(text.selectAll) { updates.selectAll() }
                .disabled(updates.selectedCount == updates.selectableCount)
            Button(text.clearSelection) { updates.selectNone() }
                .disabled(updates.selectedCount == 0)
            Spacer(minLength: 0)
        }
        .buttonStyle(.link)
        .font(.hexa(.label))
    }

    @ViewBuilder
    private var list: some View {
        let apps = updates.items.filter { $0.packageKind != .formula }
        let formulas = updates.items.filter { $0.packageKind == .formula }
        let rows = LazyVStack(alignment: .leading, spacing: Self.compactRowSpacing) {
            ForEach(apps) { item in
                row(item)
            }
            if !formulas.isEmpty {
                // Own micro-labelled section (DEC-1): CLI tools read as brew
                // formulae, not as apps, without a separate badge per row.
                SectionLabel(text.formulaSection)
                    .padding(.top, HexaTheme.Spacing.xs)
                ForEach(formulas) { item in
                    row(item)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        if compact {
            // Height lands on whole rows, so the list never ends with half a
            // row peeking out of the panel. The formula label takes a row of
            // its own in the estimate.
            let rowCount = apps.count + (formulas.isEmpty ? 0 : 1)
            OverlayScrollView { rows }
                .frame(height: Self.compactHeight(rowCount: rowCount))
        } else {
            rows
        }
    }

    private static let compactRowHeight: CGFloat = 40
    private static let compactRowSpacing: CGFloat = HexaTheme.Spacing.xs
    private static let compactVisibleRows = 4

    static func compactHeight(rowCount: Int) -> CGFloat {
        let visible = min(max(rowCount, 1), compactVisibleRows)
        return CGFloat(visible) * compactRowHeight
            + CGFloat(visible - 1) * compactRowSpacing
    }

    private func row(_ item: AppUpdatesSupport.Item) -> some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            if item.isSelectable {
                Toggle(isOn: Binding(get: { updates.selection.contains(item.id) },
                                     set: { _ in updates.toggle(item) })) {
                    EmptyView()
                }
                .labelsHidden()
                .toggleStyle(.checkbox)
                .accessibilityLabel(item.name)
            } else {
                Color.clear
                    .frame(width: 14, height: 14)
                    .accessibilityHidden(true)
            }

            if item.packageKind == .formula {
                HexaIcons.image("terminal")
                    .resizable()
                    .scaledToFit()
                    .frame(width: compact ? 22 : 26, height: compact ? 22 : 26)
                    .foregroundStyle(HexaTheme.fgSecondary)
            } else {
                Image(nsImage: icon(for: item))
                    .resizable()
                    .frame(width: compact ? 22 : 26, height: compact ? 22 : 26)
            }

            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                HStack(spacing: HexaTheme.Spacing.xs) {
                    Text(item.name)
                        .font(compact ? .hexa(.label) : .hexa(.body))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(sourceBadge(for: item))
                        .font(.hexa(.micro))
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .padding(.horizontal, HexaTheme.Spacing.xs)
                        .padding(.vertical, 1) // geometria de plataforma (spec §4): inset de badge
                        .background(RoundedRectangle(cornerRadius: HexaTheme.Radius.control).fill(HexaTheme.surfaceInset))
                }
                Text(item.versionSummary)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)

            Button {
                updates.update(item)
            } label: {
                Text(actionTitle(for: item))
                    .font(.hexa(.label))
            }
            .buttonStyle(HexaActionButtonStyle())
            .controlSize(.small)
            .disabled(isBusy)
            .help(actionHint(for: item))
        }
        .padding(.horizontal, HexaTheme.Spacing.s)
        .padding(.vertical, HexaTheme.Spacing.xs)
        .frame(height: compact ? Self.compactRowHeight : nil)
        .background(
            RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                .fill(HexaTheme.surfaceInset)
        )
        .contextMenu {
            if item.bundleID != nil {
                Button(String(format: text.skipVersionFormat, item.latestVersion)) {
                    updates.skipVersion(item)
                }
                .disabled(isBusy)
                Button(text.excludeApp) { updates.excludeApp(item) }
                    .disabled(isBusy)
            }
        }
    }

    private func icon(for item: AppUpdatesSupport.Item) -> NSImage {
        guard let path = item.bundlePath, FileManager.default.fileExists(atPath: path) else {
            return NSWorkspace.shared.icon(for: .applicationBundle)
        }
        return NSWorkspace.shared.icon(forFile: path)
    }

    private func sourceBadge(for item: AppUpdatesSupport.Item) -> String {
        switch item.source {
        case .packageManager: return text.homebrewBadge
        case .appStore: return text.appStoreBadge
        case .onlineCatalog: return text.onlineBadge
        }
    }

    private func actionTitle(for item: AppUpdatesSupport.Item) -> String {
        switch item.source {
        case .packageManager: return text.updateOne
        case .appStore: return text.appStoreBadge
        case .onlineCatalog: return text.openApp
        }
    }

    private func actionHint(for item: AppUpdatesSupport.Item) -> String {
        switch item.source {
        case .packageManager: return text.updateOne
        case .appStore: return text.storeHint
        case .onlineCatalog: return text.openAppHint
        }
    }

    // MARK: - Primary action

    @ViewBuilder
    private var updateButton: some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            Button {
                updates.updateSelected()
            } label: {
                Text(String(format: text.updateSelectedFormat, updates.selectedCount))
                    .font(compact ? .hexa(.label) : .hexa(.body))
                    .frame(maxWidth: compact ? .infinity : nil)
            }
            .buttonStyle(HexaActionButtonStyle())
            .controlSize(compact ? .small : .regular)
            .disabled(updates.selectedCount == 0 || isBusy)
            if !compact {
                Spacer(minLength: 0)
            }
        }
    }
}
