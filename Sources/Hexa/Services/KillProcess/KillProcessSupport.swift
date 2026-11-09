// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import Darwin
import Foundation

/// Pure helpers for the Kill Process feature: protected system processes and
/// safety boundaries.
enum KillProcessSupport {
    static func numberComesBefore(_ lhs: Double,
                                  _ rhs: Double,
                                  lhsPID: pid_t,
                                  rhsPID: pid_t,
                                  ascending: Bool) -> Bool {
        if lhs == rhs { return lhsPID < rhsPID }
        return ascending ? lhs < rhs : lhs > rhs
    }

    static func nameComesBefore(_ lhs: String,
                                _ rhs: String,
                                lhsPID: pid_t,
                                rhsPID: pid_t,
                                ascending: Bool) -> Bool {
        let comparison = lhs.localizedCaseInsensitiveCompare(rhs)
        if comparison == .orderedSame { return lhsPID < rhsPID }
        return ascending ? comparison == .orderedAscending : comparison == .orderedDescending
    }

    /// AppKit's `terminate()` and `forceTerminate()` return false when the
    /// termination request was not sent. Only that case may fall back to a
    /// POSIX signal; an accepted request is already in progress and must not
    /// be signalled.
    static func fallsBackToSignal(afterAppTerminateAccepted accepted: Bool) -> Bool {
        !accepted
    }

    /// Makes a process name safe to show in the administrator prompt: drops
    /// control characters and bidi formatting marks, collapses whitespace,
    /// caps the length at 64 characters, and falls back to "?" when nothing
    /// is left.
    static func sanitizedPromptName(_ name: String) -> String {
        let bidiMarks: Set<UInt32> = [0x061C, 0x200E, 0x200F, 0x2066, 0x2067, 0x2068, 0x2069]
        let kept = name.unicodeScalars.filter { scalar in
            if scalar.properties.generalCategory == .control { return false }
            if bidiMarks.contains(scalar.value) { return false }
            if (0x202A...0x202E).contains(scalar.value) { return false }
            return true
        }
        let collapsed = String(String.UnicodeScalarView(kept))
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        let limited = String(collapsed.prefix(64))
            .trimmingCharacters(in: .whitespaces)
        return limited.isEmpty ? "?" : limited
    }

    /// Every descendant of `root` from a flat parent table, breadth first so
    /// the caller can reverse it and kill deepest first. A pid is visited
    /// once, so a self-parenting or circular row cannot loop, and the total
    /// is capped well above any real process tree.
    static func descendants(of root: pid_t, parents: [(pid: pid_t, ppid: pid_t)]) -> [pid_t] {
        var children: [pid_t: [pid_t]] = [:]
        for row in parents {
            children[row.ppid, default: []].append(row.pid)
        }
        var result: [pid_t] = []
        var seen: Set<pid_t> = [root]
        var frontier = [root]
        while !frontier.isEmpty, result.count < 4096 {
            var next: [pid_t] = []
            for parent in frontier {
                for child in children[parent] ?? [] where seen.insert(child).inserted {
                    next.append(child)
                }
            }
            result.append(contentsOf: next)
            frontier = next
        }
        return result
    }

    /// Why a row may not be signalled, or nil when it may. A critical system
    /// process wins over a row without identity: the stronger reason is the
    /// one worth showing. A row with no kernel start time has nothing to
    /// verify before the signal, so it is locked exactly like a system one.
    static func protectionReason(isSystemProtected: Bool,
                                 hasIdentity: Bool) -> KillProcessEntry.ProtectionReason? {
        if isSystemProtected { return .systemProcess }
        if !hasIdentity { return .identityUnavailable }
        return nil
    }

    /// Rows a group kill may signal. `groupMembers` holds the owner and every
    /// helper folded into the row, so a protected helper is dropped here
    /// instead of being handed to the kill path. An ungrouped row expands to
    /// itself, which keeps the caller free of a special case.
    static func groupKillTargets(for entry: KillProcessEntry) -> [KillProcessEntry] {
        if entry.groupedCount > 1, !entry.groupMembers.isEmpty {
            return entry.groupMembers.filter { !$0.isProtected }
        }
        return entry.isProtected ? [] : [entry]
    }

    static func normalizedStartDescription(_ value: String) -> String? {
        let normalized = value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !normalized.isEmpty,
              normalized.range(of: "^[A-Za-z0-9: ]+$", options: .regularExpression) != nil
        else { return nil }
        return normalized
    }

    /// Protects kernel, launchd, critical macOS daemons, vital window/session
    /// infrastructure, and the app's own process from being terminated.
    static func isProtected(pid: pid_t, name: String = "", path: String = "") -> Bool {
        if pid <= 1 || pid == ProcessInfo.processInfo.processIdentifier { return true }
        // The real binary path is always read, so a caller-supplied name or path
        // can only add protection, never hide a protected process.
        var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        var resolvedPath = ""
        if proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count)) > 0 {
            resolvedPath = String(cString: pathBuffer)
        }
        var names = [name, (resolvedPath as NSString).lastPathComponent]
        var paths = [path, resolvedPath]
        if resolvedPath.isEmpty,
           name.trimmingCharacters(in: .whitespaces).isEmpty,
           path.trimmingCharacters(in: .whitespaces).isEmpty,
           let app = NSRunningApplication(processIdentifier: pid) {
            names.append(app.localizedName ?? "")
            paths.append(app.executableURL?.path ?? "")
        }
        let lowerNames = names.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        let lowerPaths = paths.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        let protectedNames: Set<String> = [
            "kernel_task", "launchd", "windowserver", "loginwindow",
            "hexa", "hexa (developer)", "hexadeveloper",
            "securityd", "opendirectoryd", "coreauthd", "diskarbitrationd",
            "syspolicyd", "powerd", "logd", "notifyd", "fseventsd", "distnoted",
            "configd", "mdnsresponder", "coreaudiod", "bluetoothd", "tccd", "trustd",
            "runningboardd", "containermanagerd", "systemstatusd", "diagnosticd"
        ]
        if lowerNames.contains(where: { protectedNames.contains($0) }) ||
           lowerPaths.contains(where: { protectedNames.contains($0) }) {
            return true
        }
        let protectedPathSuffixes: [String] = [
            "/windowserver", "/loginwindow", "/launchd",
            "/securityd", "/opendirectoryd", "/coreauthd",
            "/diskarbitrationd", "/syspolicyd", "/powerd",
            "/logd", "/notifyd", "/fseventsd", "/distnoted"
        ]
        if lowerPaths.contains(where: { lowerPath in
            protectedPathSuffixes.contains(where: { lowerPath.hasSuffix($0) })
        }) {
            return true
        }
        // Own bundle: the running hexa instance and any helper binary inside it.
        // The parent PID is not a criterion: launchd-spawned helpers such as
        // FanControlHelper have ppid 1.
        if isProtectedBundle(identifier: NSRunningApplication(processIdentifier: pid)?.bundleIdentifier,
                             ownIdentifier: Bundle.main.bundleIdentifier) {
            return true
        }
        if isInsideAppBundle(path: resolvedPath, bundlePath: Bundle.main.bundleURL.path) {
            return true
        }
        return false
    }

    /// True when a running app shares hexa's bundle identifier. A nil value on
    /// either side never protects.
    static func isProtectedBundle(identifier: String?, ownIdentifier: String?) -> Bool {
        guard let identifier, !identifier.isEmpty,
              let ownIdentifier, !ownIdentifier.isEmpty
        else { return false }
        return identifier == ownIdentifier
    }

    /// True when `path` is a file below `bundlePath`. The trailing "/" keeps
    /// "/Applications/hexa.app2/x" from matching "/Applications/hexa.app".
    static func isInsideAppBundle(path: String, bundlePath: String) -> Bool {
        let lowerPath = path.lowercased()
        var lowerBundle = bundlePath.lowercased()
        guard !lowerPath.isEmpty, !lowerBundle.isEmpty else { return false }
        if !lowerBundle.hasSuffix("/") { lowerBundle += "/" }
        return lowerPath.hasPrefix(lowerBundle)
    }
}
