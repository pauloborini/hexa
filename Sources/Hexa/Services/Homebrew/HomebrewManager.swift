// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Combine
import Darwin
import Foundation

final class HomebrewManager: ObservableObject {
    static let shared = HomebrewManager()

    @Published private(set) var brewPath: String?
    @Published private(set) var isLoadingInstalled = false
    @Published private(set) var operation: HomebrewOperation?
    /// Operation-status contract: a read-only view of the running or finished
    /// brew action. Consumed by the Uninstall module (AppUninstaller) to detect
    /// a removal it handed to brew; writing and control stay exclusive to the
    /// App Updates module, which owns this manager.
    @Published private(set) var operationStatus: HomebrewOperationStatus?
    @Published private(set) var log = ""
    @Published private(set) var errorMessage: String?
    @Published private(set) var terminalFallbackCommand: String?
    /// A third-party tap Homebrew refused to load until the user trusts it,
    /// with the interrupted work retried right after the one-click trust.
    @Published private(set) var untrustedTap: String?
    @Published private(set) var isTrustingTap = false
    private var untrustedTapRetry: (() -> Void)?

    /// Serializes every brew command, reads and mutations; never enter it synchronously from the lane itself.
    static let lane = DispatchQueue(label: "com.hexa.homebrew", qos: .userInitiated)
    private let workQueue = HomebrewManager.lane
    private var activeGroup: HomebrewProcessGroup?
    private var cancelRequested = false
    private var installedCaskRecords: [HomebrewCaskRecord] = []
    private var installedCaskRecordsFetchedAt: Date?
    private var ownershipLoads: [String: [(HomebrewPackage?) -> Void]] = [:]
    private var completedOperationCleanup: DispatchWorkItem?

    var isBusy: Bool {
        isLoadingInstalled || operation != nil
    }

    private init() {
        brewPath = detectBrewPath()
    }

    /// - Parameter clearingError: pass `false` when refreshing straight after a
    ///   failed operation, so the reason that operation gave is still on screen
    ///   while the fresh state loads.
    func refreshInstalled(clearingError: Bool = true) {
        guard let brewPath = detectBrewPath() else {
            self.brewPath = nil
            installedCaskRecords = []
            installedCaskRecordsFetchedAt = nil
            if clearingError { errorMessage = nil }
            return
        }
        self.brewPath = brewPath
        isLoadingInstalled = true
        if clearingError { errorMessage = nil }
        clearUntrustedTap()
        let command = HomebrewCommandBuilder.installed(brewPath: brewPath)
        run(command) { [weak self] status, output in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoadingInstalled = false
                guard status == 0 else {
                    if let tap = HomebrewCommandBuilder.untrustedTapName(fromOutput: output) {
                        self.presentUntrustedTap(tap) { [weak self] in self?.refreshInstalled() }
                    } else {
                        self.errorMessage = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    return
                }
                self.installedCaskRecords = HomebrewParser.parseInstalledCaskRecords(output)
                self.installedCaskRecordsFetchedAt = Date()
            }
        }
    }

    func uninstall(_ package: HomebrewPackage) {
        perform(.uninstall, package: package)
    }

    /// Looks up whether Homebrew owns this exact app bundle. The cached
    /// installed catalog is reused when fresh; otherwise one read-only command
    /// answers every concurrent request for the same path.
    func packageManagingApplication(at url: URL,
                                    completion: @escaping (HomebrewPackage?) -> Void) {
        let path = url.standardizedFileURL.path
        if let fetchedAt = installedCaskRecordsFetchedAt,
           Date().timeIntervalSince(fetchedAt) < 60 {
            completion(HomebrewOwnershipSupport.packageManagingApplication(
                atPath: path,
                installed: installedCaskRecords
            ))
            return
        }
        if ownershipLoads[path] != nil {
            ownershipLoads[path]?.append(completion)
            return
        }
        ownershipLoads[path] = [completion]
        guard let brewPath = brewPath ?? detectBrewPath() else {
            finishOwnershipLoad(path: path, package: nil)
            return
        }
        self.brewPath = brewPath
        run(HomebrewCommandBuilder.installed(brewPath: brewPath)) { [weak self] status, output in
            DispatchQueue.main.async {
                guard let self else { return }
                let records = status == 0 ? HomebrewParser.parseInstalledCaskRecords(output) : []
                if status == 0 {
                    self.installedCaskRecords = records
                    self.installedCaskRecordsFetchedAt = Date()
                }
                let package = HomebrewOwnershipSupport.packageManagingApplication(
                    atPath: path,
                    installed: records
                )
                self.finishOwnershipLoad(path: path, package: package)
            }
        }
    }

    /// Upgrades exactly the casks asked for, through the same single
    /// operation lane as every other Homebrew action, so the app never runs
    /// two package commands at once. Used by the app update list, where the
    /// person picks which apps to update.
    func upgradeCasks(_ tokens: [String]) {
        guard operation == nil,
              let brewPath = brewPath ?? detectBrewPath(),
              let command = HomebrewCommandBuilder.upgradeCasks(brewPath: brewPath, tokens: tokens) else {
            return
        }
        perform(.upgradeAll, package: nil, command: command)
    }

    /// Upgrades exactly the CLI formulae asked for, through the same single
    /// operation lane as every other Homebrew action. The app update list
    /// chains this after its cask upgrade for a mixed selection.
    func upgradeFormulas(_ tokens: [String]) {
        guard operation == nil,
              let brewPath = brewPath ?? detectBrewPath(),
              let command = HomebrewCommandBuilder.upgradeFormulas(brewPath: brewPath, tokens: tokens) else {
            return
        }
        perform(.upgradeAll, package: nil, command: command)
    }

    func cancelOperation() {
        guard operation != nil else { return }
        cancelRequested = true
        activeGroup?.terminateGroup()
        appendLog("\nCancelled.\n")
    }

    func clearLog() {
        completedOperationCleanup?.cancel()
        completedOperationCleanup = nil
        log = ""
        terminalFallbackCommand = nil
        if operation == nil {
            operationStatus = nil
        }
    }

    func openTerminalFallback() {
        guard let command = terminalFallbackCommand else { return }
        openTerminal(command: command)
    }

    @discardableResult
    private func openTerminal(command: String) -> Bool {
        let source = """
        tell application "Terminal"
            activate
            do script \(AppleScriptRunner.literal(command))
        end tell
        """
        // In-process Apple Events (see AppleScriptRunner): the Terminal Automation
        // consent is attributed to this app and re-requested if it was lost,
        // instead of a fragile osascript subprocess. Same permission as before.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = AppleScriptRunner.run(source)
            if !result.ok {
                DispatchQueue.main.async {
                    self?.errorMessage = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        return true
    }

    private func perform(_ action: HomebrewOperation.Action,
                         package: HomebrewPackage?,
                         command commandOverride: HomebrewCommand? = nil) {
        guard operation == nil else { return }
        guard let brewPath = brewPath ?? detectBrewPath() else { return }
        guard let command = commandOverride
                ?? standardCommand(for: action, package: package, brewPath: brewPath) else { return }
        operation = HomebrewOperation(action: action, package: package)
        operationStatus = HomebrewOperationStatus(action: action,
                                                  package: package,
                                                  phase: initialPhase(for: action),
                                                  result: .running,
                                                  progressFraction: nil,
                                                  startedAt: Date(),
                                                  finishedAt: nil,
                                                  lastActivity: nil)
        terminalFallbackCommand = nil
        errorMessage = nil
        clearUntrustedTap()
        cancelRequested = false
        completedOperationCleanup?.cancel()
        completedOperationCleanup = nil
        log = ""
        runStreaming(command,
                     onOutput: { [weak self] chunk in
                         self?.appendLog(chunk)
                         self?.updateOperationStatus(from: chunk, action: action)
                     }) { [weak self] status, output in
            DispatchQueue.main.async {
                guard let self else { return }
                self.activeGroup = nil
                self.operation = nil
                if status == 0 {
                    self.markOperationComplete(result: .succeeded,
                                               phase: .refreshing,
                                               activity: nil)
                    self.refreshInstalled()
                } else if self.cancelRequested {
                    self.markOperationComplete(result: .cancelled,
                                               phase: self.operationStatus?.phase ?? .finalizing,
                                               activity: nil)
                    self.refreshInstalled(clearingError: false)
                } else if HomebrewCommandBuilder.needsTerminalFallback(output: output) {
                    self.terminalFallbackCommand = HomebrewCommandBuilder.shellCommand(command)
                    self.markOperationComplete(result: .needsTerminal,
                                               phase: self.operationStatus?.phase ?? .finalizing,
                                               activity: HomebrewProgressParser.visibleError(from: output))
                    // Same partly-done case: `upgrade` moves the formulae, then a
                    // cask asks for a password and brew stops there.
                    self.refreshInstalled(clearingError: false)
                } else if let tap = HomebrewCommandBuilder.untrustedTapName(fromOutput: output) {
                    // The retry repeats the exact command, so a cask selection
                    // never widens into a plain `brew upgrade`.
                    self.presentUntrustedTap(tap) { [weak self] in
                        self?.perform(action, package: package, command: commandOverride)
                    }
                    self.markOperationComplete(result: .failed,
                                               phase: self.operationStatus?.phase ?? .finalizing,
                                               activity: nil)
                    // No refresh here: `refreshInstalled` calls `clearUntrustedTap()`,
                    // which would drop the prompt and retry closure just installed.
                } else {
                    let message = HomebrewProgressParser.visibleError(from: output)
                    self.errorMessage = message.isEmpty ? output.trimmingCharacters(in: .whitespacesAndNewlines) : message
                    self.markOperationComplete(result: .failed,
                                               phase: self.operationStatus?.phase ?? .finalizing,
                                               activity: self.errorMessage)
                    // brew reports a run as failed when it could not do all of it,
                    // not only when it did none of it: one disabled package makes
                    // `upgrade` skip that one, upgrade the rest and still exit
                    // non-zero. Re-read regardless, or the panel keeps showing the
                    // versions from before a run that moved most of them.
                    self.refreshInstalled(clearingError: false)
                }
                self.cancelRequested = false
            }
        }
    }

    private func finishOwnershipLoad(path: String, package: HomebrewPackage?) {
        let completions = ownershipLoads.removeValue(forKey: path) ?? []
        completions.forEach { $0(package) }
    }

    private func standardCommand(for action: HomebrewOperation.Action,
                                 package: HomebrewPackage?,
                                 brewPath: String) -> HomebrewCommand? {
        switch action {
        case .uninstall:
            guard let package,
                  HomebrewCommandBuilder.isValidToken(package.name) else { return nil }
            return HomebrewCommandBuilder.uninstall(brewPath: brewPath, package: package)
        case .upgradeAll:
            // Callers pass the exact cask or formula command.
            return nil
        }
    }

    private func updateOperationStatus(from chunk: String, action: HomebrewOperation.Action) {
        guard var status = operationStatus, status.isActive else { return }
        if let phase = HomebrewProgressParser.phase(in: chunk, action: action) {
            status.phase = phase
        }
        if let progress = HomebrewProgressParser.progressFraction(in: chunk) {
            status.progressFraction = progress
        }
        if let activity = HomebrewProgressParser.activity(in: chunk) {
            status.lastActivity = activity
        }
        operationStatus = status
    }

    private func initialPhase(for action: HomebrewOperation.Action) -> HomebrewOperationPhase {
        switch action {
        case .upgradeAll:
            return .preparing
        case .uninstall:
            return .uninstalling
        }
    }

    private func markOperationComplete(result: HomebrewOperationResult,
                                       phase: HomebrewOperationPhase,
                                       activity: String?) {
        guard var status = operationStatus else { return }
        status.result = result
        status.phase = phase
        status.finishedAt = Date()
        if result == .succeeded {
            status.progressFraction = 1
        }
        if let activity, !activity.isEmpty {
            status.lastActivity = activity
        }
        operationStatus = status
        scheduleCompletedOperationCleanup(result: result,
                                          targetID: status.targetID,
                                          finishedAt: status.finishedAt)
    }

    private func scheduleCompletedOperationCleanup(result: HomebrewOperationResult,
                                                   targetID: String,
                                                   finishedAt: Date?) {
        completedOperationCleanup?.cancel()
        guard result != .running,
              let finishedAt else { return }
        let delay: TimeInterval
        let clearsWholeStatus: Bool
        switch result {
        case .succeeded:
            delay = 8
            clearsWholeStatus = true
        case .cancelled:
            delay = 6
            clearsWholeStatus = true
        case .failed, .needsTerminal:
            delay = 20
            clearsWholeStatus = false
        case .running:
            return
        }

        let item = DispatchWorkItem { [weak self] in
            guard let self,
                  self.operation == nil,
                  self.operationStatus?.targetID == targetID,
                  self.operationStatus?.finishedAt == finishedAt else { return }
            self.log = ""
            if clearsWholeStatus {
                self.terminalFallbackCommand = nil
                self.operationStatus = nil
            }
            self.completedOperationCleanup = nil
        }
        completedOperationCleanup = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    /// One click on the trust card: marks the tap as trusted for Homebrew
    /// and picks the interrupted work back up.
    func trustTapAndContinue() {
        guard let tap = untrustedTap, !isTrustingTap,
              HomebrewCommandBuilder.isValidToken(tap),
              let brewPath = brewPath ?? detectBrewPath() else { return }
        isTrustingTap = true
        let retry = untrustedTapRetry
        run(HomebrewCommandBuilder.trustTap(brewPath: brewPath, tap: tap)) { [weak self] status, output in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isTrustingTap = false
                guard status == 0 else {
                    self.errorMessage = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    return
                }
                self.clearUntrustedTap()
                retry?()
            }
        }
    }

    private func presentUntrustedTap(_ tap: String, retry: @escaping () -> Void) {
        untrustedTap = tap
        untrustedTapRetry = retry
        errorMessage = nil
    }

    private func clearUntrustedTap() {
        untrustedTap = nil
        untrustedTapRetry = nil
    }

    private func detectBrewPath() -> String? {
        HomebrewCommandBuilder.trustedBrewPath()
    }

    /// Timeout for read-only Homebrew commands (info, search, outdated).
    /// These are normally fast, but a hung NFS share or locked database can
    /// make them stall indefinitely.
    private static let brewReadTimeout: TimeInterval = 30
    /// Install/upgrade/uninstall run on the same serial queue as every read, so a
    /// hung one must end eventually. A big download, a source build and a copy into
    /// Applications are all slow but never silent, so the bound is on silence: a cap
    /// on total time would end work that was still going.
    private static let brewSilenceTimeout: TimeInterval = 15 * 60
    private static let processTerminationGrace: TimeInterval = 2

    /// SIGTERM is cooperative. Escalate only when a command ignores it so a
    /// cancelled or timed-out operation cannot keep the serial queue forever.
    private static func stop(_ process: Process, finished: DispatchSemaphore) {
        guard process.isRunning else { return }
        let initialPid = process.processIdentifier
        process.terminate()
        if finished.wait(timeout: .now() + processTerminationGrace) == .timedOut,
           process.isRunning {
            let pid = process.processIdentifier > 0 ? process.processIdentifier : initialPid
            guard pid > 0 else { return }
            kill(pid, SIGKILL)
            _ = finished.wait(timeout: .now() + processTerminationGrace)
        }
    }

    /// Called on `workQueue` only: the first `HomebrewEnvironment.forBrew` read
    /// waits on the login shell.
    private static func makeProcess(_ command: HomebrewCommand) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = command.arguments
        process.environment = HomebrewEnvironment.forBrew
        return process
    }

    private func run(_ command: HomebrewCommand,
                     completion: @escaping (_ status: Int32, _ output: String) -> Void) {
        workQueue.async {
            let process = Self.makeProcess(command)
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            var data = Data()
            let lock = NSLock()
            let drained = DispatchSemaphore(value: 0)
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                guard !chunk.isEmpty else {
                    handle.readabilityHandler = nil
                    drained.signal()
                    return
                }
                lock.lock()
                data.append(chunk)
                lock.unlock()
            }
            let finished = DispatchSemaphore(value: 0)
            process.terminationHandler = { _ in finished.signal() }
            do {
                try process.run()
            } catch {
                pipe.fileHandleForReading.readabilityHandler = nil
                completion(-1, error.localizedDescription)
                return
            }
            if finished.wait(timeout: .now() + Self.brewReadTimeout) == .timedOut {
                Self.stop(process, finished: finished)
            }
            _ = drained.wait(timeout: .now() + 1)
            pipe.fileHandleForReading.readabilityHandler = nil
            try? pipe.fileHandleForReading.close()
            lock.lock()
            let output = String(data: data, encoding: .utf8) ?? ""
            lock.unlock()
            completion(process.isRunning ? -1 : process.terminationStatus, output)
        }
    }

    private func runStreaming(_ command: HomebrewCommand,
                              onOutput: @escaping (String) -> Void,
                              completion: @escaping (_ status: Int32, _ output: String) -> Void) {
        workQueue.async { [weak self] in
            let group: HomebrewProcessGroup
            do {
                group = try HomebrewProcessGroup.start(
                    command,
                    environment: HomebrewEnvironment.forBrew,
                    abortsWhenPartialLine: HomebrewCommandBuilder.isPendingTerminalPrompt
                ) { chunk in
                    DispatchQueue.main.async { onOutput(chunk) }
                }
            } catch {
                completion(-1, error.localizedDescription)
                return
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.activeGroup = group
                if self.cancelRequested { group.terminateGroup() }
            }
            while !group.waitForExit(timeout: Self.brewSilenceTimeout) {
                if group.silence >= Self.brewSilenceTimeout {
                    group.terminateGroup()
                    _ = group.waitForExit(timeout: Self.processTerminationGrace + 1)
                    break
                }
            }
            group.drainOutput()
            completion(group.status, group.output)
        }
    }

    private func appendLog(_ text: String) {
        log.append(text)
    }
}
