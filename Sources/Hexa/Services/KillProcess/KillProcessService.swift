// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import Darwin
import Foundation

/// One row of the live process list: either a single process, or - when
/// grouping is on - a responsible app with every helper process it owns
/// folded into it (`groupedCount > 1`).
struct KillProcessEntry: Identifiable, Equatable {
    /// Why a row cannot be signalled. A row with no kernel start time has no
    /// identity to verify before a signal, so it is protected exactly like a
    /// critical system process.
    enum ProtectionReason: Equatable {
        case systemProcess, identityUnavailable
    }

    let pid: pid_t
    let ppid: pid_t
    let name: String
    let path: String
    let cpuPercent: Double
    let memoryBytes: Double
    let isRegularApp: Bool
    let bundleURL: URL?
    let groupedCount: Int
    let isProtected: Bool
    /// Kernel start time in microseconds. A PID alone is reusable and is not a
    /// safe identity for a destructive action confirmed from an old row.
    let startedAt: UInt64?
    /// Every process folded into a grouped row, the owner included, so the
    /// search can find a helper hidden inside its app's row. Empty when the
    /// row is a single process.
    var groupMembers: [KillProcessEntry] = []
    /// Nil when the row may be signalled. Kept next to `isProtected` so the
    /// view can explain why a row is locked instead of only greying it out.
    var protectionReason: ProtectionReason? = nil

    var id: pid_t { pid }
}

struct KillProcessAlert: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

/// Lists every running process (via `ps`, the same source
/// `ProcessUsageService` uses for the resource breakdown) and kills,
/// force-kills, restarts, or tears down whole process trees. Backs both the
/// Kill Process settings page and its Command Bar rows, which share this
/// service's cache instead of shelling out twice.
final class KillProcessService: ObservableObject {
    static let shared = KillProcessService()

    enum SortBy: String {
        case cpu, memory, name, pid
    }

    enum ProcessFilterScope: String, CaseIterable {
        case all, apps
    }

    /// `quitRequested`: a regular app accepted AppKit's quit request. The app
    /// owns the outcome from there (it may ask to save, and the user may
    /// cancel), so it is not checked for survival.
    enum DirectKillResult {
        case killed, quitRequested, alreadyGone, needsAdmin, failed, stale
    }

    /// Identity tuple checked before every signal. A PID is reusable, so the
    /// start time and the executable path must both still match.
    struct KillTarget {
        let pid: pid_t
        let startedAt: UInt64
        /// Executable path read when the target was identified. Only checked
        /// when it contains "/", the same convention `currentStartTime` uses.
        let expectedPath: String?
    }

    private struct AdminKillTarget {
        let target: KillTarget
        let startDescription: String
    }

    @Published private(set) var entries: [KillProcessEntry] = []
    @Published var query: String = ""
    @Published var errorAlert: KillProcessAlert?
    @Published private(set) var filterScope: ProcessFilterScope = .all
    @Published private(set) var sortBy: SortBy
    @Published private(set) var sortAscending: Bool
    @Published private(set) var groupRelated: Bool
    @Published private(set) var isRefreshing = false
    /// True once a `ps` snapshot has completed successfully at least once, so
    /// the view can tell "still loading for the first time" apart from
    /// "search matched nothing" - both look like an empty `entries` array
    /// otherwise.
    @Published private(set) var hasLoadedOnce = false
    /// True when the last `ps` snapshot failed. The list keeps the rows it
    /// already had, so the view needs this flag to say the data is stale
    /// instead of pretending the refresh worked.
    @Published private(set) var refreshFailed = false
    /// When a genuine snapshot last replaced `entries`. A failed snapshot
    /// leaves it untouched, so a "last updated" label never counts a hiccup.
    @Published private(set) var lastRefreshedAt: Date?

    private let cacheLock = NSLock()
    private var lastRefresh: TimeInterval = 0
    private let cacheFreshSeconds: TimeInterval = 3

    private var restartObserver: NSObjectProtocol?
    private var pendingRestartPID: pid_t?
    private var pendingRestartURL: URL?

    private init() {
        sortBy = SortBy(rawValue: UserDefaults.standard.string(forKey: DefaultsKey.killProcessSortBy) ?? "cpu") ?? .cpu
        sortAscending = UserDefaults.standard.bool(forKey: DefaultsKey.killProcessSortAscending)
        groupRelated = UserDefaults.standard.bool(forKey: DefaultsKey.killProcessGroupRelated)
    }

    var sortedEntries: [KillProcessEntry] {
        let ascending = sortAscending
        return entries.sorted { lhs, rhs in
            switch sortBy {
            case .cpu:
                return KillProcessSupport.numberComesBefore(lhs.cpuPercent, rhs.cpuPercent,
                                                            lhsPID: lhs.pid, rhsPID: rhs.pid,
                                                            ascending: ascending)
            case .memory:
                return KillProcessSupport.numberComesBefore(lhs.memoryBytes, rhs.memoryBytes,
                                                            lhsPID: lhs.pid, rhsPID: rhs.pid,
                                                            ascending: ascending)
            case .name:
                return KillProcessSupport.nameComesBefore(lhs.name, rhs.name,
                                                          lhsPID: lhs.pid, rhsPID: rhs.pid,
                                                          ascending: ascending)
            case .pid:
                return KillProcessSupport.numberComesBefore(Double(lhs.pid), Double(rhs.pid),
                                                            lhsPID: lhs.pid, rhsPID: rhs.pid,
                                                            ascending: ascending)
            }
        }
    }

    var filteredEntries: [KillProcessEntry] {
        let base = filterScope == .apps ? sortedEntries.filter(\.isRegularApp) : sortedEntries
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return base }
        let matches = { (entry: KillProcessEntry) in
            entry.name.lowercased().contains(needle) ||
            String(entry.pid) == needle ||
            entry.path.lowercased().contains(needle)
        }
        return base.filter { matches($0) || $0.groupMembers.contains(where: matches) }
    }

    func setFilterScope(_ scope: ProcessFilterScope) {
        filterScope = scope
    }

    /// Column-header sorting: clicking the active column flips direction,
    /// clicking a different one switches to it at that column's natural
    /// default direction (highest-first for CPU/memory/PID, A-Z for name).
    func toggleSort(_ value: SortBy) {
        if sortBy == value {
            sortAscending.toggle()
        } else {
            sortBy = value
            sortAscending = value == .name
        }
        UserDefaults.standard.set(sortBy.rawValue, forKey: DefaultsKey.killProcessSortBy)
        UserDefaults.standard.set(sortAscending, forKey: DefaultsKey.killProcessSortAscending)
    }

    func setGroupRelated(_ value: Bool) {
        groupRelated = value
        UserDefaults.standard.set(value, forKey: DefaultsKey.killProcessGroupRelated)
        refresh(force: true)
    }

    /// Refreshes the process list off the main thread and republishes on the
    /// main thread. `force` bypasses the freshness cache, so a kill's
    /// reconciling refresh and an explicit tap of the refresh button always
    /// see the current state. `completion` always fires on the main thread,
    /// even when the cache was already fresh, so a caller that needs the
    /// current snapshot (the Command Bar's lazy load) can sequence off it
    /// instead of guessing at a delay.
    func refresh(force: Bool = false, completion: (() -> Void)? = nil) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.refresh(force: force, completion: completion) }
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        cacheLock.lock()
        let fresh = !force && now - lastRefresh < cacheFreshSeconds
        cacheLock.unlock()
        guard !fresh else {
            completion?()
            return
        }

        isRefreshing = true
        let grouped = groupRelated
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let rows = Self.snapshot(grouped: grouped)
            DispatchQueue.main.async {
                guard let self else {
                    completion?()
                    return
                }
                // A failed or empty `ps` call (transient - a timeout under
                // load, a hiccup) must never wipe a list that was already
                // showing good data; only a genuine snapshot replaces it.
                if let rows {
                    self.entries = rows
                    self.hasLoadedOnce = true
                    self.lastRefreshedAt = Date()
                }
                self.refreshFailed = rows == nil
                self.isRefreshing = false
                self.cacheLock.lock()
                self.lastRefresh = ProcessInfo.processInfo.systemUptime
                self.cacheLock.unlock()
                completion?()
            }
        }
    }

    // MARK: - Kill

    func kill(_ entry: KillProcessEntry, force: Bool) {
        guard !entry.isProtected, let target = Self.target(for: entry) else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let batch = self.killBatch([target], force: force, adminPromptProcessName: entry.name)
            self.finishKill(removed: batch.removed)
            if Self.anySurvives([target], force: force, excluding: batch.unverified) {
                self.reportKillFailure()
            }
        }
    }

    /// Kills a process identified by its pid, name, and kernel start time.
    /// This is the shared safe path for rows supplied by another feature.
    /// `completion` runs on the main thread with `true` when the process
    /// outlived the request. The caller shows that failure on its own
    /// surface; nothing is left in `errorAlert` for the Kill Process page.
    func kill(pid: pid_t,
              name: String,
              startedAt: UInt64,
              path: String? = nil,
              force: Bool,
              completion: ((_ failed: Bool) -> Void)? = nil) {
        guard !Self.isProtected(pid: pid, name: name) else {
            completion?(false)
            return
        }
        let target = KillTarget(pid: pid, startedAt: startedAt, expectedPath: path)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let batch = self.killBatch([target], force: force, adminPromptProcessName: name)
            self.finishKill(removed: batch.removed)
            let failed = Self.anySurvives([target], force: force, excluding: batch.unverified)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                completion?(failed)
            }
        }
    }

    /// Kills every currently listed process sharing this exact name.
    func killAll(named name: String, force: Bool) {
        let targets = entries.filter { $0.name == name && !$0.isProtected }
            .compactMap(Self.target(for:))
        guard !targets.isEmpty else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let batch = self.killBatch(targets, force: force, adminPromptProcessName: name)
            self.finishKill(removed: batch.removed)
            if Self.anySurvives(targets, force: force, excluding: batch.unverified) {
                self.reportKillFailure()
            }
        }
    }

    /// Kills every process folded into a grouped row - the owner and its
    /// helpers - skipping the ones the list protects. Rows with no verified
    /// identity are dropped, so the same snapshot cannot signal a recycled PID.
    func killGroup(_ entry: KillProcessEntry, force: Bool) {
        let targets = KillProcessSupport.groupKillTargets(for: entry)
            .compactMap(Self.target(for:))
        guard !targets.isEmpty else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let batch = self.killBatch(targets, force: force, adminPromptProcessName: entry.name)
            self.finishKill(removed: batch.removed)
            if Self.anySurvives(targets, force: force, excluding: batch.unverified) {
                self.reportKillFailure()
            }
        }
    }

    /// Kills a process together with every descendant, deepest first, so a
    /// parent never outlives children it might otherwise try to restart.
    func killTree(_ entry: KillProcessEntry, force: Bool) {
        guard !entry.isProtected, let root = Self.target(for: entry) else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            guard Self.identityMatches(root) else { return }
            let descendants = Self.descendants(of: entry.pid)
                .filter { !Self.isProtected(pid: $0.pid) }
                .compactMap { Self.currentTarget(pid: $0.pid, expectedParent: $0.ppid) }
            let targets = Array(descendants.reversed()) + [root]
            let batch = self.killBatch(targets, force: force, adminPromptProcessName: entry.name)
            self.finishKill(removed: batch.removed)
            if Self.anySurvives(targets, force: force, excluding: batch.unverified) {
                self.reportKillFailure()
            }
        }
    }

    /// True when a signalled target still runs once its grace window closes.
    /// A SIGTERM handler can take a moment to exit, so the identity is
    /// checked again until every target is gone or the window closes, instead
    /// of one look after a fixed delay. Runs off the main thread.
    ///
    /// `unverified` lists pids that are expected to survive: an administrator
    /// prompt the user dismissed (never signalled), or a regular app that took
    /// a quit request (it may ask to save, and the user may cancel the quit).
    private static func anySurvives(_ targets: [KillTarget],
                                    force: Bool,
                                    excluding unverified: Set<pid_t>) -> Bool {
        let watched = targets.filter { !unverified.contains($0.pid) }
        let deadline = Date().addingTimeInterval(force ? 1 : 3)
        while watched.contains(where: identityMatches) {
            guard Date() < deadline else { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return false
    }

    /// Sends the direct-kill signal to every pid, then escalates every pid
    /// that came back EPERM through a single `AdminShell` prompt, so killing
    /// several processes owned by another user asks for the password once.
    private func killBatch(_ targets: [KillTarget],
                           force: Bool,
                           adminPromptProcessName: String) -> (removed: Set<pid_t>, unverified: Set<pid_t>) {
        var removed = Set<pid_t>()
        var unverified = Set<pid_t>()
        var needsAdmin: [AdminKillTarget] = []
        for target in targets {
            guard !Self.isProtected(pid: target.pid), Self.identityMatches(target) else { continue }
            switch Self.attemptDirectKill(target: target, force: force) {
            case .killed, .alreadyGone:
                removed.insert(target.pid)
            case .quitRequested:
                removed.insert(target.pid)
                unverified.insert(target.pid)
            case .needsAdmin:
                // pid 0, 1, and -1 address groups or launchd, never a single
                // user process, so they never reach the elevated command.
                guard target.pid > 1 else { continue }
                if let description = Self.currentStartDescription(pid: target.pid),
                   Self.identityMatches(target) {
                    needsAdmin.append(AdminKillTarget(target: target,
                                                      startDescription: description))
                }
            case .failed, .stale:
                break
            }
        }
        guard !needsAdmin.isEmpty else { return (removed, unverified) }

        let signalFlag = force ? "-9" : "-15"
        let command = needsAdmin.map { candidate in
            let pid = candidate.target.pid
            return "if [ \"$(LC_ALL=C /bin/ps -p \(pid) -o lstart= | /usr/bin/xargs)\" = '\(candidate.startDescription)' ]; then /bin/kill \(signalFlag) \(pid); fi"
        }.joined(separator: "; ")
        let prompt = String(format: FeatureStrings.killProcess(L10n.shared.language).adminPromptFormat,
                            KillProcessSupport.sanitizedPromptName(adminPromptProcessName))
        switch AdminShell.runSyncOutcome(command, prompt: prompt) {
        case .granted:
            for candidate in needsAdmin {
                removed.insert(candidate.target.pid)
            }
        case .cancelled:
            for candidate in needsAdmin {
                unverified.insert(candidate.target.pid)
            }
        case .failed:
            break
        }
        return (removed, unverified)
    }

    static func attemptDirectKill(target: KillTarget, force: Bool) -> DirectKillResult {
        guard identityMatches(target) else { return .stale }
        let pid = target.pid
        if let running = NSRunningApplication(processIdentifier: pid),
           !running.isTerminated, running.activationPolicy == .regular {
            guard identityMatches(target) else { return .stale }
            let accepted = force ? running.forceTerminate() : running.terminate()
            // AppKit reported that the request was not sent: fall through to the
            // POSIX signal below, which re-checks identity before it sends anything.
            guard KillProcessSupport.fallsBackToSignal(afterAppTerminateAccepted: accepted) else {
                return force ? .killed : .quitRequested
            }
        }
        let signal = force ? SIGKILL : SIGTERM
        guard identityMatches(target) else { return .stale }
        if Darwin.kill(pid, signal) == 0 { return .killed }
        switch errno {
        case EPERM: return .needsAdmin
        case ESRCH: return .alreadyGone
        default: return .failed
        }
    }

    /// Removes killed rows immediately so the list feels responsive, then
    /// reconciles with a real `ps` snapshot shortly after - long enough for
    /// the kernel to have reaped the process, short enough nobody notices
    /// the wait.
    private func finishKill(removed: Set<pid_t>) {
        DispatchQueue.main.async {
            if !removed.isEmpty {
                self.entries.removeAll { removed.contains($0.pid) }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refresh(force: true)
        }
    }

    /// Every descendant of `pid`, walked in memory from a single `ps` parent
    /// table. The BFS used to run `pgrep -P` once per pid it had found, so
    /// tearing down a tree of a few hundred processes forked that many short
    /// lived helpers one after another - seconds of stalling while the list
    /// had already dropped the rows.
    ///
    /// Each descendant comes with the parent it had in that same table, so the
    /// capture can verify the parent before it trusts the pid.
    ///
    /// A grandchild forked between this snapshot and the signal is missed;
    /// the per-pid `pgrep` walk raced the same way, and `killBatch` still
    /// re-checks every target's identity before it signals anything.
    private static func descendants(of pid: pid_t) -> [(pid: pid_t, ppid: pid_t)] {
        let listing = Shell.run("/bin/ps", ["-eo", "pid,ppid"])
        guard listing.status == 0 else { return [] }
        let parents: [(pid: pid_t, ppid: pid_t)] = listing.output
            .split(separator: "\n").dropFirst().compactMap { line in
                let columns = line.split(separator: " ", omittingEmptySubsequences: true)
                guard columns.count >= 2, let child = pid_t(columns[0]),
                      let parent = pid_t(columns[1]) else { return nil }
                return (child, parent)
            }
        let parentOf = Dictionary(parents.map { ($0.pid, $0.ppid) },
                                  uniquingKeysWith: { first, _ in first })
        return KillProcessSupport.descendants(of: pid, parents: parents).compactMap { child in
            parentOf[child].map { (pid: child, ppid: $0) }
        }
    }

    // MARK: - Restart

    func canRestart(_ entry: KillProcessEntry) -> Bool {
        !entry.isProtected && entry.bundleURL != nil && entry.startedAt != nil
    }

    /// Terminates the app, waits for the real termination notification (not
    /// a fixed delay), then relaunches it - the same sequence
    /// `CommandBarService.restart` uses for its own restart row.
    ///
    /// The quit request can sit behind the app's own "save changes?" dialog
    /// for as long as the user takes, and the user may cancel the quit there.
    /// Neither is a failure, so the relaunch waits up to `restartWindow` and
    /// then is quietly forgotten, so a much later quit does not reopen the app.
    func restart(_ entry: KillProcessEntry) {
        guard !entry.isProtected,
              let url = entry.bundleURL,
              let target = Self.target(for: entry) else { return }
        cancelPendingRestart()
        pendingRestartPID = entry.pid
        pendingRestartURL = url
        restartObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let terminated = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  terminated.processIdentifier == self?.pendingRestartPID else { return }
            self?.completeRestart()
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Self.attemptDirectKill(target: target, force: false)
            switch result {
            case .failed, .needsAdmin, .stale:
                DispatchQueue.main.async {
                    self?.cancelPendingRestart()
                    self?.reportKillFailure()
                }
            case .alreadyGone:
                DispatchQueue.main.async {
                    self?.completeRestart()
                }
            case .killed, .quitRequested:
                break
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.restartWindow) { [weak self] in
            guard self?.pendingRestartPID == entry.pid else { return }
            self?.cancelPendingRestart()
        }
    }

    private static let restartWindow: TimeInterval = 120

    private func completeRestart() {
        guard let url = pendingRestartURL else {
            cancelPendingRestart()
            return
        }
        cancelPendingRestart()
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
            if let error {
                self?.reportKillFailure(message: error.localizedDescription)
            }
            self?.refresh(force: true)
        }
    }

    private func cancelPendingRestart() {
        if let restartObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(restartObserver)
        }
        restartObserver = nil
        pendingRestartPID = nil
        pendingRestartURL = nil
    }

    private func reportKillFailure(message: String? = nil) {
        DispatchQueue.main.async {
            let strings = FeatureStrings.killProcess(L10n.shared.language)
            self.errorAlert = KillProcessAlert(
                title: strings.killFailedTitle,
                message: (message?.isEmpty == false ? message : nil) ?? strings.killFailedMessage
            )
        }
    }

    // MARK: - Protected Processes

    static func isProtected(pid: pid_t, name: String = "", path: String = "") -> Bool {
        KillProcessSupport.isProtected(pid: pid, name: name, path: path)
    }

    static func startTime(for pid: pid_t) -> UInt64? {
        currentStartTime(pid: pid)
    }

    /// The kernel executable path, captured with `startTime(for:)` by rows
    /// that other features hand to `kill(pid:name:startedAt:path:force:)`.
    static func executablePath(for pid: pid_t) -> String? {
        processPath(pid: pid)
    }

    private static func target(for entry: KillProcessEntry) -> KillTarget? {
        guard let startedAt = entry.startedAt else { return nil }
        return KillTarget(pid: entry.pid, startedAt: startedAt, expectedPath: entry.path)
    }

    /// Captures a descendant's identity. The parent comes from the `ps` table
    /// that found the pid, and the path is read now because that table has
    /// none. A descendant whose path cannot be read is skipped: its identity
    /// could not be verified, so it is never signalled.
    private static func currentTarget(pid: pid_t, expectedParent: pid_t) -> KillTarget? {
        guard let path = processPath(pid: pid),
              let startedAt = currentStartTime(pid: pid,
                                               expectedParent: expectedParent,
                                               expectedPath: path) else { return nil }
        return KillTarget(pid: pid, startedAt: startedAt, expectedPath: path)
    }

    private static func identityMatches(_ target: KillTarget) -> Bool {
        currentStartTime(pid: target.pid, expectedPath: target.expectedPath) == target.startedAt
    }

    /// Single source of process identity. Returns the start time in
    /// microseconds only when the pid still exists, the optional parent and
    /// path (checked when `expectedPath` contains "/") match, and the process
    /// is not a zombie. A zombie has exited and is only waiting to be reaped,
    /// so it reports no start time and cannot be signalled.
    private static func currentStartTime(pid: pid_t,
                                         expectedParent: pid_t? = nil,
                                         expectedPath: String? = nil) -> UInt64? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        if info.pbi_status == UInt32(SZOMB) { return nil }
        if let expectedParent, pid_t(info.pbi_ppid) != expectedParent { return nil }
        if let expectedPath, expectedPath.contains("/") {
            guard processPath(pid: pid) == expectedPath else { return nil }
        }
        return info.pbi_start_tvsec &* 1_000_000 &+ info.pbi_start_tvusec
    }

    private static func processPath(pid: pid_t) -> String? {
        var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        guard proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count)) > 0 else { return nil }
        return String(cString: pathBuffer)
    }

    private static func currentStartDescription(pid: pid_t) -> String? {
        let result = Shell.run("/usr/bin/env", ["LC_ALL=C", "/bin/ps", "-p", String(pid),
                                                "-o", "lstart="])
        guard result.status == 0 else { return nil }
        return KillProcessSupport.normalizedStartDescription(result.output)
    }

    // MARK: - Snapshot

    /// Nil on a failed or clearly-wrong snapshot (a timed-out or non-zero
    /// `ps`, or zero rows parsed - never legitimately true on a running Mac),
    /// so a transient hiccup can be told apart from an actually-empty list.
    private static func snapshot(grouped: Bool) -> [KillProcessEntry]? {
        let result = Shell.run("/bin/ps", ["-eo", "pid,ppid,pcpu,rss,comm"])
        guard result.status == 0 else { return nil }
        let rows = parsePS(result.output)
        guard !rows.isEmpty else { return nil }
        return (grouped ? groupedByApp(rows) : rows).sorted { $0.cpuPercent > $1.cpuPercent }
    }

    /// Lines look like "  437     1  12.5  20480 /System/Library/.../WindowServer".
    ///
    /// The `comm` column is only a name for display: it is the path the
    /// process was started with (a symlink, a relative path, a rewritten
    /// title), not the binary the kernel runs. The row's path and the identity
    /// checked before every signal come from the kernel path instead. A row
    /// whose kernel path cannot be read gets no identity, so it is protected.
    private static func parsePS(_ output: String) -> [KillProcessEntry] {
        var rows: [KillProcessEntry] = []
        for line in output.split(separator: "\n").dropFirst() {
            let columns = line.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
            guard columns.count == 5,
                  let pid = pid_t(columns[0]), pid > 0,
                  let ppid = pid_t(columns[1]),
                  let cpu = Double(columns[2])
            else { continue }
            let rss = Double(columns[3]) ?? 0
            let commandPath = String(columns[4]).trimmingCharacters(in: .whitespaces)
            let shortName = commandPath.contains("/")
                ? (commandPath as NSString).lastPathComponent : commandPath
            let running = NSRunningApplication(processIdentifier: pid)
            let kernelPath = processPath(pid: pid)
            let startedAt = kernelPath.flatMap {
                currentStartTime(pid: pid, expectedParent: ppid, expectedPath: $0)
            }
            let systemProtected = isProtected(pid: pid, name: shortName, path: commandPath)
            let reason = KillProcessSupport.protectionReason(isSystemProtected: systemProtected,
                                                             hasIdentity: startedAt != nil)
            rows.append(KillProcessEntry(
                pid: pid,
                ppid: ppid,
                name: ResponsibleProcess.displayName(pid: pid, fallback: shortName),
                path: kernelPath ?? commandPath,
                cpuPercent: cpu,
                memoryBytes: rss * 1024,
                isRegularApp: running?.activationPolicy == .regular,
                bundleURL: running?.bundleURL,
                groupedCount: 1,
                isProtected: reason != nil,
                startedAt: startedAt,
                protectionReason: reason))
        }
        return rows
    }

    /// Folds helper processes under the app responsible for them, summing
    /// their CPU/memory - the same grouping `ProcessUsageService` applies to
    /// the resource breakdown, reused here via `ResponsibleProcess`.
    private static func groupedByApp(_ rows: [KillProcessEntry]) -> [KillProcessEntry] {
        var byOwner: [pid_t: [KillProcessEntry]] = [:]
        for row in rows {
            byOwner[ResponsibleProcess.owner(of: row.pid), default: []].append(row)
        }
        return byOwner.compactMap { owner, members in
            guard let primary = members.first(where: { $0.pid == owner }) else { return nil }
            let running = NSRunningApplication(processIdentifier: owner)
            // The owner's own row already decided the reason, and that check
            // also carries the `comm` path, which the row's kernel path no
            // longer repeats. Only an owner missing from the snapshot has to
            // be classified here.
            let systemProtected = isProtected(pid: owner, name: primary.name, path: primary.path)
            let reason = primary.protectionReason
                ?? KillProcessSupport.protectionReason(isSystemProtected: systemProtected,
                                                       hasIdentity: primary.startedAt != nil)
            return KillProcessEntry(
                pid: owner,
                ppid: primary.ppid,
                name: ResponsibleProcess.displayName(pid: owner, fallback: primary.name),
                path: primary.path,
                cpuPercent: members.reduce(0) { $0 + $1.cpuPercent },
                memoryBytes: members.reduce(0) { $0 + $1.memoryBytes },
                isRegularApp: running?.activationPolicy == .regular,
                bundleURL: running?.bundleURL,
                groupedCount: members.count,
                isProtected: reason != nil,
                startedAt: primary.startedAt,
                groupMembers: members.count > 1 ? members : [],
                protectionReason: reason)
        }
    }
}
