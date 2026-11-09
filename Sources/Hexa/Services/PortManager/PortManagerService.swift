// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Darwin
import Foundation

final class PortManagerService: ObservableObject {
    static let shared = PortManagerService()
    /// Refresh cadence the page uses while visible. The service runs no timer of its own.
    static let automaticRefreshInterval: TimeInterval = 5
    @Published private(set) var entries: [PortManagerEntry] = []
    @Published var query = ""
    @Published private(set) var isRefreshing = false
    @Published private(set) var hasLoadedOnce = false
    @Published private(set) var refreshFailed = false
    /// Moment of the last successful snapshot. A failed snapshot keeps the previous value.
    @Published private(set) var lastRefreshedAt: Date?
    /// Set when a process this page asked to end outlived the request. Shown
    /// here, by the page that asked, and never by the Kill Process page.
    @Published var terminateFailed = false

    var filteredEntries: [PortManagerEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return entries }
        return entries.filter { "\($0.port) \($0.processName) \($0.pid) \($0.address)".lowercased().contains(q) }
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        refreshFailed = false
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Self.snapshot()
            DispatchQueue.main.async {
                if let result {
                    self.entries = result
                    self.hasLoadedOnce = true
                    self.lastRefreshedAt = Date()
                }
                self.refreshFailed = result == nil
                self.isRefreshing = false
            }
        }
    }

    func terminate(_ entry: PortManagerEntry, force: Bool) {
        guard AppFeature.killProcess.isAvailable, let startedAt = entry.startedAt else { return }
        KillProcessService.shared.kill(pid: entry.pid,
                                       name: entry.processName,
                                       startedAt: startedAt,
                                       path: entry.path,
                                       force: force) { [weak self] failed in
            if failed { self?.terminateFailed = true }
            self?.refresh()
        }
    }

    static func snapshot() -> [PortManagerEntry]? {
        let result = Shell.run("/usr/sbin/lsof", ["-nP", "+c0", "-iTCP", "-sTCP:LISTEN", "-F", "pcnPT"])
        // Negative status means Shell.run hit its own timeout — always bail.
        guard result.status >= 0,
              !PortManagerSupport.lsofFailed(status: result.status, output: result.output)
        else { return nil }
        var captured: [pid_t: (startedAt: UInt64, path: String)?] = [:]
        let parsed = PortManagerSupport.parseLsof(result.output).map { entry -> PortManagerEntry in
            // The identity is captured once per pid after lsof and is fully
            // revalidated at termination. A pid reused between the lsof run
            // and this capture is not formally excluded.
            let identity: (startedAt: UInt64, path: String)?
            if let known = captured[entry.pid] {
                identity = known
            } else {
                identity = captureIdentity(pid: entry.pid)
                captured.updateValue(identity, forKey: entry.pid)
            }
            // The identity is either complete and consistent, or absent.
            var startedAt: UInt64?
            var path: String?
            if let identity, PortManagerSupport.processNameMatches(entry.processName,
                                                                   executablePath: identity.path) {
                startedAt = identity.startedAt
                path = identity.path
            }
            return PortManagerEntry(port: entry.port,
                                    protocolName: entry.protocolName,
                                    address: entry.address,
                                    pid: entry.pid,
                                    processName: entry.processName,
                                    startedAt: startedAt,
                                    path: path)
        }
        // lsof exits 1 when no listening sockets are found or when it prints a
        // warning. Both cases yield a clean result: an empty list or the parsed rows.
        // A timeout or an error message with no process field failed above.
        return parsed
    }

    /// Reads the start time and executable path of a listening pid. The start
    /// time is read again after the path, so a process that exits during the
    /// capture yields no identity.
    private static func captureIdentity(pid: pid_t) -> (startedAt: UInt64, path: String)? {
        guard let startedAt = KillProcessService.startTime(for: pid),
              let path = executablePath(pid: pid),
              KillProcessService.startTime(for: pid) == startedAt else { return nil }
        return (startedAt, path)
    }

    private static func executablePath(pid: pid_t) -> String? {
        var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        guard proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count)) > 0 else { return nil }
        return String(cString: pathBuffer)
    }
}
