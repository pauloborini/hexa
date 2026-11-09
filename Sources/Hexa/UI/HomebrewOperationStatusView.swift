// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import SwiftUI

struct HomebrewOperationStatusView: View {
    @ObservedObject private var l10n = L10n.shared

    let status: HomebrewOperationStatus
    let log: String
    let terminalFallbackCommand: String?
    let compact: Bool
    @Binding var showDetails: Bool
    var onCancel: () -> Void
    var onClear: () -> Void
    var onOpenTerminal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? HexaTheme.Spacing.s : HexaTheme.Spacing.s) {
            header
            progressArea
            if let activity = status.lastActivity, !activity.isEmpty {
                Text(activity)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .lineLimit(compact ? 2 : 3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if status.result == .needsTerminal {
                terminalFallback
            }
            if !log.isEmpty {
                HexaDisclosure(isExpanded: $showDetails) {
                    Text(showDetails ? l10n.s.homebrewOperationHideDetails : l10n.s.homebrewOperationShowDetails)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgSecondary)
                } content: {
                    technicalLog
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: HexaTheme.Spacing.s) {
            ZStack {
                Circle()
                    .fill(HexaTheme.surfaceInset)
                HexaIcons.image(iconName)
                    .font(compact ? .hexa(.label) : .hexa(.body))
                    .foregroundStyle(iconColor)
            }
            .frame(width: compact ? 22 : 28, height: compact ? 22 : 28)

            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                Text(title)
                    .font(compact ? .hexa(.label) : .hexa(.body))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: HexaTheme.Spacing.xs) {
                    if status.isActive {
                        Text(phaseText)
                        HairlineDivider(vertical: true).frame(height: 12)
                    }
                    TimelineView(.periodic(from: status.startedAt, by: 1)) { context in
                        Text(String(format: l10n.s.homebrewOperationElapsedFormat,
                                    elapsedText(now: context.date)))
                    }
                }
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
            }
            Spacer(minLength: 0)
            if status.isActive {
                Button(l10n.s.homebrewCancelOperation) {
                    onCancel()
                }
                .buttonStyle(HexaActionButtonStyle())
                .controlSize(.mini)
            } else {
                Button(l10n.s.homebrewClearLog) {
                    onClear()
                }
                .buttonStyle(HexaActionButtonStyle())
                .controlSize(.mini)
            }
        }
    }

    @ViewBuilder
    private var progressArea: some View {
        if status.isActive {
            if let fraction = status.progressFraction {
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
                    .tint(HexaTheme.fgSecondary)
            } else {
                HomebrewIndeterminateProgressBar()
                Text(l10n.s.homebrewOperationProgressUnknown)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgTertiary)
                    .lineLimit(1)
            }
        } else if status.result == .succeeded {
            ProgressView(value: 1)
                .progressViewStyle(.linear)
                    .tint(HexaTheme.fgSecondary)
        }
    }

    private var terminalFallback: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            Label(l10n.s.homebrewTerminalFallback, hexaIcon: "terminal")
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if terminalFallbackCommand != nil {
                HStack(spacing: HexaTheme.Spacing.s) {
                    Button(l10n.s.homebrewOpenTerminal) {
                        onOpenTerminal()
                    }
                    .buttonStyle(HexaActionButtonStyle())
                    Button {
                        copy(terminalFallbackCommand)
                    } label: {
                        Label(l10n.s.menuCopy, hexaIcon: "doc.on.doc")
                    }
                    .buttonStyle(HexaActionButtonStyle())
                }
                .controlSize(.small)
            }
        }
    }

    private var technicalLog: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            HStack(spacing: HexaTheme.Spacing.s) {
                Text(l10n.s.homebrewOperationTechnicalLog)
                    .font(.hexa(.data))
                    .foregroundStyle(HexaTheme.fgTertiary)
                Spacer(minLength: 0)
                Button {
                    copy(log)
                } label: {
                    Label(l10n.s.menuCopy, hexaIcon: "doc.on.doc")
                }
                .buttonStyle(HexaActionButtonStyle())
                .controlSize(.mini)
                .disabled(log.isEmpty)
            }
            OverlayScrollView {
                Text(log.isEmpty ? " " : log)
                    .font(.hexa(.data))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: compact ? 58 : 96)
        }
    }

    private var title: String {
        switch status.result {
        case .running:
            if status.action == .upgradeAll {
                return l10n.s.homebrewOperationUpgradeAll
            }
            return String(format: runningTitleFormat, packageDisplayName)
        case .succeeded:
            if status.action == .upgradeAll {
                return l10n.s.homebrewOperationUpgradedAll
            }
            return String(format: succeededTitleFormat, packageDisplayName)
        case .failed:
            return String(format: l10n.s.homebrewOperationFailedFormat, packageDisplayName)
        case .cancelled:
            return l10n.s.homebrewOperationCancelled
        case .needsTerminal:
            return l10n.s.homebrewOperationTerminal
        }
    }

    private var phaseText: String {
        switch status.result {
        case .cancelled:
            return l10n.s.homebrewOperationCancelled
        case .failed:
            return String(format: l10n.s.homebrewOperationFailedFormat, packageDisplayName)
        case .needsTerminal:
            return l10n.s.homebrewOperationTerminal
        case .running, .succeeded:
            switch status.phase {
            case .preparing: return l10n.s.homebrewOperationPreparing
            case .downloading: return l10n.s.homebrewOperationDownloading
            case .uninstalling: return l10n.s.homebrewOperationUninstalling
            case .upgrading: return l10n.s.homebrewOperationUpgrading
            case .finalizing: return l10n.s.homebrewOperationFinalizing
            case .refreshing: return l10n.s.homebrewOperationRefreshing
            }
        }
    }

    private var runningTitleFormat: String {
        switch status.action {
        case .uninstall: return l10n.s.homebrewOperationUninstallFormat
        case .upgradeAll: return l10n.s.homebrewOperationUpgradeAll
        }
    }

    private var succeededTitleFormat: String {
        switch status.action {
        case .uninstall: return l10n.s.homebrewOperationUninstalledFormat
        case .upgradeAll: return l10n.s.homebrewOperationUpgradedAll
        }
    }

    private var packageDisplayName: String {
        status.package?.displayName ?? l10n.s.homebrewAllPackages
    }

    private var iconName: String {
        switch status.result {
        case .running: return status.action.runningSystemImage
        case .succeeded: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .cancelled: return "xmark.circle.fill"
        case .needsTerminal: return "terminal.fill"
        }
    }

    private var iconColor: Color {
        switch status.result {
        case .running: return HexaTheme.fgSecondary
        case .succeeded: return HexaTheme.statusOk
        case .failed, .needsTerminal: return HexaTheme.statusWarning
        case .cancelled: return HexaTheme.fgSecondary
        }
    }

    private func elapsedText(now: Date) -> String {
        let end = status.finishedAt ?? now
        let seconds = max(Int(end.timeIntervalSince(status.startedAt)), 0)
        if seconds < 60 {
            return "\(seconds)s"
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)min"
        }
        let hours = minutes / 60
        return "\(hours)h \(minutes % 60)min"
    }

    private func copy(_ text: String?) {
        guard let text, !text.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

private struct HomebrewIndeterminateProgressBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = -0.35

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(HexaTheme.borderHairline)
                Capsule()
                    .fill(HexaTheme.focusRing)
                    .frame(width: max(geometry.size.width * 0.34, 36))
                    .offset(x: offset * geometry.size.width)
            }
            .clipped()
        }
        .frame(height: 5)
        .onAppear {
            offset = reduceMotion ? 0.33 : -0.35
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) {
                offset = 1.05
            }
        }
    }
}
