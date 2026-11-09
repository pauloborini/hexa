// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

struct ProcessUsageRow: View {
    let row: ProcessUsage
    let value: String
    var iconSize: CGFloat = 15
    var leadingPadding: CGFloat = 0

    @Environment(\.notchPresentation) private var inNotch
    @ObservedObject private var l10n = L10n.shared
    /// Inside the island a failed force quit shows on this row for a few
    /// seconds instead of a modal.
    @State private var forceQuitFailedAt: Date?

    var body: some View {
        Group {
            if AppFeature.killProcess.isAvailable {
                activatableContent
                    .contextMenu {
                        Button(FeatureStrings.killProcess(l10n.language).forceKillButton,
                               role: .destructive) {
                            ProcessUsageActions.confirmForceQuit(row, inNotch: inNotch) {
                                showForceQuitFailure()
                            }
                        }
                        .disabled(!ProcessUsageActions.canForceQuit(row))
                    }
            } else {
                activatableContent
            }
        }
        .help(row.name)
    }

    private var activatableContent: some View {
        Group {
            if ProcessUsageService.shared.canActivate(row) {
                Button {
                    ProcessUsageService.shared.activate(row)
                } label: {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    private var content: some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            Image(nsImage: ResponsibleProcess.icon(for: row.pid))
                .resizable()
                .frame(width: iconSize, height: iconSize)
            Text(row.name)
                .font(.hexa(.body))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            if forceQuitFailedAt != nil {
                Text(FeatureStrings.killProcess(l10n.language).killFailedTitle)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.statusWarning)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .transition(.opacity)
            } else {
                Text(value)
                    .font(.hexa(.data))
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
        }
        .contentShape(Rectangle())
        .padding(.leading, leadingPadding)
        .animation(.easeOut(duration: 0.15), value: forceQuitFailedAt)
    }

    private func showForceQuitFailure() {
        let shownAt = Date()
        forceQuitFailedAt = shownAt
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            // A later failure keeps its own few seconds.
            if forceQuitFailedAt == shownAt { forceQuitFailedAt = nil }
        }
    }
}

enum ProcessUsageActions {
    static func canForceQuit(_ row: ProcessUsage) -> Bool {
        guard AppFeature.killProcess.isAvailable,
              let startedAt = row.startedAt,
              let path = row.executablePath,
              KillProcessService.startTime(for: row.pid) == startedAt,
              KillProcessService.executablePath(for: row.pid) == path,
              let executable = executableName(row.pid) else { return false }
        return !KillProcessSupport.isProtected(pid: row.pid, name: executable)
            && !KillProcessSupport.isProtected(pid: row.pid, name: row.name)
    }

    static func confirmForceQuit(_ row: ProcessUsage, inNotch: Bool,
                                 onFailureInNotch: @escaping () -> Void) {
        guard canForceQuit(row), let startedAt = row.startedAt else { return }
        let strings = FeatureStrings.killProcess(L10n.shared.language)
        let title = String(format: strings.confirmForceKillFormat, row.name)
        let cancel = L10n.shared.s.uninstallerCancel
        if inNotch {
            DispatchQueue.main.async {
                guard NSAlert.confirmAboveIsland(title, message: "", action: strings.forceKillButton,
                                                 destructive: true, cancel: cancel) else { return }
                forceQuit(row, startedAt: startedAt, inNotch: true, onFailureInNotch: onFailureInNotch)
            }
            return
        }
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = title
        alert.addButton(withTitle: strings.forceKillButton).hasDestructiveAction = true
        alert.addButton(withTitle: cancel).keyEquivalent = "\u{1b}"
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        forceQuit(row, startedAt: startedAt, inNotch: false, onFailureInNotch: onFailureInNotch)
    }

    private static func forceQuit(_ row: ProcessUsage, startedAt: UInt64, inNotch: Bool,
                                  onFailureInNotch: @escaping () -> Void) {
        guard canForceQuit(row), let path = row.executablePath else { return }
        KillProcessService.shared.kill(pid: row.pid, name: row.name, startedAt: startedAt,
                                       path: path, force: true) { failed in
            guard failed else { return }
            if inNotch { onFailureInNotch() } else { reportForceQuitFailure() }
        }
    }

    /// The failure is shown by the list that asked, never later by the Kill
    /// Process page. Inside the island a plain alert would open below the
    /// island's window, so there the row itself says it for a few seconds.
    private static func reportForceQuitFailure() {
        let strings = FeatureStrings.killProcess(L10n.shared.language)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = strings.killFailedTitle
        alert.informativeText = strings.killFailedMessage
        alert.addButton(withTitle: L10n.shared.s.buttonOK)
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private static func executableName(_ pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        guard proc_name(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(cString: buffer)
    }
}
