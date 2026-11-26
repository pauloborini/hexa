// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import Combine
import CoreServices
import Darwin
import os.log
import Security

/// Finds the files an app leaves around — caches, preferences, logs, support
/// folders, containers, preference panes, plugins — and removes only what you
/// pick. Ordinary files go to the Trash; after an extra confirmation, a
/// package-managed app is delegated to its package manager before the remaining
/// choices go to the Trash.
final class AppUninstaller: ObservableObject {
    static let shared = AppUninstaller()
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "hexa",
                                    category: "uninstaller")

    enum Phase: Equatable {
        case empty
        case scanning
        case results
        case removing
        case done(movedToTrash: Int64, freedPermanently: Int64, failed: [Leftover])
    }

    struct Target: Equatable {
        let name: String
        let bundleID: String?
        let url: URL
        let icon: NSImage

        static func == (lhs: Target, rhs: Target) -> Bool { lhs.url == rhs.url }
    }

    enum Category: Int, CaseIterable {
        case app, support, caches, preferences, containers, logs, state, other

        var sortRank: Int { rawValue }
    }

    struct Leftover: Identifiable, Equatable {
        let id = UUID()
        let url: URL
        let category: Category
        let size: Int64
        let ownerBundleID: String?
        let ownerGroupID: String?
        let evidenceBundleID: String?
        let confidence: UninstallerSupport.LeftoverMatch
        let fileIdentity: UninstallerSupport.FileIdentity
        var include: Bool = false
        /// The scanned target that attributed this leftover. Nil only in tests
        /// and installer aliases synthesized after a bundle is already gone.
        var targetURL: URL? = nil
        var targetName: String? = nil

        var name: String { url.lastPathComponent }

        static func == (lhs: Leftover, rhs: Leftover) -> Bool {
            lhs.id == rhs.id && lhs.include == rhs.include
        }
    }

    @Published private(set) var phase: Phase = .empty
    @Published private(set) var targets: [Target] = []
    @Published private(set) var errorMessage: String?
    @Published var items: [Leftover] = []
    /// The first target, kept as the compact representation callers already
    /// use while the batch-aware UI reads `targets`.
    var target: Target? { targets.first }
    private var allowedRemovalPaths = Set<String>()
    private var targetStates: [TargetState] = []
    private var homebrewRemovalSize: Int64 = 0
    private var homebrewRemovedApplicationPaths = Set<String>()
    private var homebrewRemovalObservation: AnyCancellable?
    private var pendingHomebrewTerminalConfirmation: HomebrewRemovalConfirmation?
    /// The package batch whose `brew uninstall` the user was sent to finish
    /// in Terminal; the screen offers to recheck and go on with the leftovers.
    @Published private(set) var homebrewAwaitingTerminal = false
    /// Names of target apps that did not quit when asked. Removal waits for a
    /// second answer before force quitting them.
    @Published private(set) var appsThatDidNotQuit: [String] = []
    @Published private(set) var removalNotices = Set<UninstallerSupport.RemovalNotice>()
    private var scanCancellation: UninstallerSupport.ScanCancellation?

    private typealias InstallLink = (url: URL, identity: UninstallerSupport.FileIdentity, bundlePath: String)

    private struct TargetState {
        let target: Target
        let fileIdentity: UninstallerSupport.FileIdentity
        let infoIdentity: UninstallerSupport.FileIdentity
        let installLink: InstallLink?
        /// TeamIDs read at scan time. Removal needs them once the bundle is gone.
        var teamIDs: Set<String>
        var homebrewPackage: HomebrewPackage?

        var key: String { target.url.standardizedFileURL.path }
    }

    private struct ScanOutcome {
        let state: TargetState
        let items: [Leftover]
        let notices: Set<UninstallerSupport.RemovalNotice>
    }

    struct ScanCandidate {
        let url: URL
        let category: Category
        let ownerBundleID: String?
        let ownerGroupID: String?
        let evidenceBundleID: String?
        let confidence: UninstallerSupport.LeftoverMatch
        var include: Bool
    }

    private init() {}

    var selectedSize: Int64 { items.filter(\.include).reduce(0) { $0 + $1.size } }
    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }

    private func targetKey(for item: Leftover) -> String? {
        item.targetURL?.standardizedFileURL.path
    }

    var selectedHomebrewPackages: [HomebrewPackage] {
        let selectedTargetKeys = Set(items.filter { $0.category == .app && $0.include }
            .compactMap { targetKey(for: $0) })
        guard !selectedTargetKeys.isEmpty else { return [] }
        return Self.uniqueHomebrewPackages(
            targetPackages: targetStates.map { HomebrewTargetPackage(targetPath: $0.key, package: $0.homebrewPackage) },
            selectedTargetKeys: selectedTargetKeys)
    }

    var isRemovingWithHomebrew: Bool {
        let selectedIDs = Set(selectedHomebrewPackages.map(\.id))
        guard !selectedIDs.isEmpty,
              // Read-only status, per the consumption contract documented on
              // HomebrewManager.operationStatus.
              let status = HomebrewManager.shared.operationStatus else { return false }
        return status.action == .uninstall
            && !selectedIDs.isDisjoint(with: Set(status.packages.map(\.id)))
            && status.isActive
    }

    var isRemoving: Bool {
        phase == .removing || isRemovingWithHomebrew
    }

    struct HomebrewTargetPackage {
        let targetPath: String
        let package: HomebrewPackage?
    }

    static func uniqueHomebrewPackages(targetPackages: [HomebrewTargetPackage],
                                       selectedTargetKeys: Set<String>) -> [HomebrewPackage] {
        var seen = Set<String>()
        return targetPackages.compactMap { target in
            guard selectedTargetKeys.contains(target.targetPath),
                  let package = target.package,
                  seen.insert(package.id).inserted else { return nil }
            return package
        }
    }

    static func homebrewTargetPathsByPackage(targetPackages: [HomebrewTargetPackage],
                                             packageIDs: Set<String>) -> [String: [String]] {
        targetPackages.reduce(into: [:]) { result, target in
            guard let package = target.package, packageIDs.contains(package.id) else { return }
            result[package.id, default: []].append(target.targetPath)
        }
    }

    static func homebrewConfirmationTargetPaths(targetPackages: [HomebrewTargetPackage],
                                                packages: [HomebrewPackage],
                                                selectedTargetKeys: Set<String>) -> [String: [String]]? {
        let paths = homebrewTargetPathsByPackage(targetPackages: targetPackages,
                                                 packageIDs: Set(packages.map(\.id)))
        guard paths.count == packages.count,
              paths.values.allSatisfy({ targetPaths in
                  targetPaths.allSatisfy(selectedTargetKeys.contains)
              }) else { return nil }
        return paths
    }

    static func interruptedHomebrewTargetPathsToReconcile(targetPaths: [String],
                                                          alreadyRemoved: Set<String>,
                                                          isAbsent: (String) -> Bool) -> [String] {
        targetPaths.filter { !alreadyRemoved.contains($0) && isAbsent($0) }
    }

    /// What the Homebrew confirmation showed, since the panel, Settings and the
    /// command bar share this uninstaller and can change it while it is open.
    struct HomebrewRemovalConfirmation {
        let packages: [HomebrewPackage]
        let targetPathsByPackage: [String: [String]]
        let selectedIDs: Set<UUID>

        var packageDisplayNames: String {
            packages.map(\.displayName).joined(separator: ", ")
        }
    }

    var homebrewRemovalConfirmation: HomebrewRemovalConfirmation? {
        guard phase == .results, !isRemoving else { return nil }
        let packages = selectedHomebrewPackages
        guard !packages.isEmpty else { return nil }
        let selectedTargetKeys = Set(items.filter { $0.category == .app && $0.include }
            .compactMap { targetKey(for: $0) })
        guard let targetPaths = Self.homebrewConfirmationTargetPaths(
            targetPackages: targetStates.map { HomebrewTargetPackage(targetPath: $0.key, package: $0.homebrewPackage) },
            packages: packages,
            selectedTargetKeys: selectedTargetKeys) else { return nil }
        return HomebrewRemovalConfirmation(packages: packages,
                                           targetPathsByPackage: targetPaths,
                                           selectedIDs: Set(items.filter(\.include).map(\.id)))
    }

    // MARK: - Selection & scan

    static func refusalMessage(for refusal: UninstallerSupport.SelectionRefusal,
                               strings: Strings = L10n.shared.s) -> String {
        switch refusal {
        case .systemApp:
            return strings.uninstallerRefusedSystemApp
        case .nestedApp:
            return strings.uninstallerRefusedNestedApp
        case .selfApp:
            return strings.uninstallerRefusedSelfApp
        case .unidentifiedOrProtected:
            return strings.uninstallerSelectionUnavailable
        }
    }

    func clearErrorMessage() {
        errorMessage = nil
    }

    func reportInvalidHomebrewConfirmation() {
        errorMessage = L10n.shared.s.uninstallerConfirmationExpired
    }

    /// Reads one app bundle and starts scanning for its leftovers.
    @discardableResult
    func select(appURL: URL) -> Bool {
        select(appURLs: [appURL])
    }

    /// Reads every accepted app bundle and starts one user-requested scan.
    /// The batch is all-or-nothing: a refused app never makes a valid app
    /// carry an error the person did not answer.
    @discardableResult
    func select(appURLs requestedURLs: [URL]) -> Bool {
        guard !isRemoving else { return false }
        var inputs: [(requestedURL: URL, selection: UninstallerSupport.Selection)] = []
        var seen = Set<String>()
        for appURL in requestedURLs {
            let selection: UninstallerSupport.Selection
            switch UninstallerSupport.evaluateSelection(for: appURL) {
            case let .success(resolved):
                selection = resolved
            case let .failure(refusal):
                errorMessage = Self.refusalMessage(for: refusal)
                return false
            }
            guard seen.insert(selection.url.standardizedFileURL.path).inserted else { continue }
            inputs.append((appURL, selection))
        }
        guard !inputs.isEmpty else {
            errorMessage = L10n.shared.s.uninstallerSelectionUnavailable
            return false
        }

        scanCancellation?.cancel()
        homebrewRemovalObservation?.cancel()
        homebrewRemovalObservation = nil
        removalNotices = []
        homebrewRemovalSize = 0
        homebrewRemovedApplicationPaths = []
        pendingHomebrewTerminalConfirmation = nil
        homebrewAwaitingTerminal = false
        appsThatDidNotQuit = []
        items = []
        allowedRemovalPaths = []
        errorMessage = nil

        let states: [TargetState] = inputs.map { input in
            var name = FileManager.default.displayName(atPath: input.requestedURL.path)
            if name.hasSuffix(".app") { name.removeLast(4) }
            let target = Target(name: name,
                                bundleID: input.selection.bundleID,
                                url: input.selection.url,
                                icon: NSWorkspace.shared.icon(forFile: input.requestedURL.path))
            let link: InstallLink? = input.selection.installLink.flatMap { url in
                guard let identity = UninstallerSupport.fileIdentity(at: url) else { return nil }
                return (url, identity, input.selection.url.path)
            }
            return TargetState(target: target,
                               fileIdentity: input.selection.identity,
                               infoIdentity: input.selection.infoIdentity,
                               installLink: link,
                               teamIDs: [],
                               homebrewPackage: nil)
        }
        targetStates = states
        targets = states.map(\.target)

        // A new selection supersedes any scan still running, even for the
        // same apps, so only this scan can deliver results.
        let cancellation = UninstallerSupport.ScanCancellation()
        scanCancellation = cancellation
        phase = .scanning

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var outcomes: [ScanOutcome] = []
            for state in states {
                guard !cancellation.isCancelled else { return }
                if let outcome = Self.scanOutcome(for: state, cancellation: cancellation) {
                    outcomes.append(outcome)
                }
            }
            guard !cancellation.isCancelled, outcomes.count == states.count else { return }
            let merged = Self.mergedLeftovers(from: outcomes)
            DispatchQueue.main.async {
                guard let self, self.scanIsCurrent(outcomes, cancellation: cancellation) else { return }
                self.resolveHomebrewPackages(outcomes: outcomes,
                                             states: outcomes.map(\.state),
                                             merged: merged,
                                             cancellation: cancellation,
                                             index: 0)
            }
        }
        return true
    }

    /// The per-target scan used by both single-app and batch selections.
    /// Everything here is user-requested work already running on the scan
    /// queue; nothing schedules or repeats it afterwards.
    private static func scanOutcome(for state: TargetState,
                                    cancellation: UninstallerSupport.ScanCancellation) -> ScanOutcome? {
        let selectedURL = state.target.url
        guard let bundleID = state.target.bundleID else { return nil }
        let ownedBundleIDs = allBundleIDs(in: selectedURL, fm: .default, cancellation: cancellation)
        guard !cancellation.isCancelled else { return nil }
        // Where the bundle sits does not decide whether its Library data
        // is its own. A second installed copy still blocks the claim.
        let knownApplications = knownApplicationURLs(candidateBundleIDs: ownedBundleIDs, cancellation: cancellation)
        guard !cancellation.isCancelled else { return nil }
        let knownApplicationIDs = applicationBundleIdentifiers(in: knownApplications, cancellation: cancellation)
        guard !cancellation.isCancelled else { return nil }
        let exclusiveBundleIDs = exclusiveOwnedBundleIDs(
            in: selectedURL, candidates: ownedBundleIDs,
            knownApplicationIDs: knownApplicationIDs, cancellation: cancellation)
        guard !cancellation.isCancelled else { return nil }
        let signing = signingIdentity(in: selectedURL, requireValidSignature: true, cancellation: cancellation)
        guard !cancellation.isCancelled else { return nil }
        let exclusiveGroupIDs = exclusiveGroupIDs(
            signing.groupIDs, selectedTeamIDs: signing.teamIDs,
            selectedURL: selectedURL, knownApplications: knownApplications, cancellation: cancellation)
        guard !cancellation.isCancelled else { return nil }
        let notices = UninstallerSupport.removalNotices(in: selectedURL)
        guard !cancellation.isCancelled else { return nil }
        let found = collect(appURL: selectedURL,
                            primaryBundleID: bundleID,
                            exclusiveBundleIDs: exclusiveBundleIDs,
                            teamIDs: signing.teamIDs,
                            exclusiveGroupIDs: exclusiveGroupIDs,
                            cancellation: cancellation)
            .map { item in
                var item = item
                item.targetURL = selectedURL
                item.targetName = state.target.name
                return item
            }
        guard !cancellation.isCancelled else { return nil }
        var scannedState = state
        scannedState.teamIDs = signing.teamIDs
        return ScanOutcome(state: scannedState, items: found, notices: notices)
    }

    /// Merges target scans without showing the same file twice. An exact
    /// ownership match wins over a weaker name relation when both targets
    /// reach the same path.
    private static func mergedLeftovers(from outcomes: [ScanOutcome]) -> [Leftover] {
        var merged: [Leftover] = []
        var indexByPath: [String: Int] = [:]
        for outcome in outcomes {
            for item in outcome.items {
                let key = item.url.standardizedFileURL.path
                if let existing = indexByPath[key] {
                    if merged[existing].confidence == .related && item.confidence == .exact {
                        merged[existing] = item
                    }
                } else {
                    indexByPath[key] = merged.count
                    merged.append(item)
                }
            }
        }
        return merged.sorted { ($0.category.sortRank, -$0.size) < ($1.category.sortRank, -$1.size) }
    }

    private func scanIsCurrent(_ outcomes: [ScanOutcome],
                               cancellation: UninstallerSupport.ScanCancellation) -> Bool {
        guard !cancellation.isCancelled, phase == .scanning else { return false }
        return targetStates.map(\.key) == outcomes.map(\.state.key)
    }

    /// Homebrew ownership is resolved one target at a time. The first answer
    /// warms the manager's short-lived installed-cask cache, so the rest of
    /// the batch does not repeat the read-only catalog command.
    private func resolveHomebrewPackages(outcomes: [ScanOutcome],
                                         states: [TargetState],
                                         merged: [Leftover],
                                         cancellation: UninstallerSupport.ScanCancellation,
                                         index: Int) {
        guard scanIsCurrent(outcomes, cancellation: cancellation) else { return }
        guard index < states.count else {
            commitScan(outcomes: outcomes, states: states, merged: merged, cancellation: cancellation)
            return
        }
        let state = states[index]
        HomebrewManager.shared.packageManagingApplication(at: state.target.url) { [weak self] package in
            guard let self, self.scanIsCurrent(outcomes, cancellation: cancellation) else { return }
            guard Self.applicationIdentityMatches(state.target.url,
                                                  appIdentity: state.fileIdentity,
                                                  infoIdentity: state.infoIdentity) else {
                self.reset()
                return
            }
            var nextStates = states
            nextStates[index].homebrewPackage = package
            self.resolveHomebrewPackages(outcomes: outcomes,
                                         states: nextStates,
                                         merged: merged,
                                         cancellation: cancellation,
                                         index: index + 1)
        }
    }

    private func commitScan(outcomes: [ScanOutcome],
                            states: [TargetState],
                            merged: [Leftover],
                            cancellation: UninstallerSupport.ScanCancellation) {
        guard scanIsCurrent(outcomes, cancellation: cancellation) else { return }
        for state in states {
            guard Self.applicationIdentityMatches(state.target.url,
                                                  appIdentity: state.fileIdentity,
                                                  infoIdentity: state.infoIdentity) else {
                reset()
                return
            }
        }
        items = merged
        removalNotices = Set(outcomes.flatMap(\.notices))
        targetStates = states
        allowedRemovalPaths = Set(merged.map { $0.url.standardizedFileURL.path })
        scanCancellation = nil
        phase = .results
    }

    func setInclude(_ include: Bool, for id: UUID) {
        guard !isRemoving else { return }
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].include = include
    }

    func selectAll() {
        guard !isRemoving else { return }
        for index in items.indices { items[index].include = true }
    }

    func selectNone() {
        guard !isRemoving else { return }
        for index in items.indices { items[index].include = false }
    }

    func reset() {
        guard !isRemoving else { return }
        scanCancellation?.cancel()
        scanCancellation = nil
        targets = []
        targetStates = []
        removalNotices = []
        homebrewRemovalSize = 0
        homebrewRemovedApplicationPaths = []
        homebrewRemovalObservation?.cancel()
        homebrewRemovalObservation = nil
        pendingHomebrewTerminalConfirmation = nil
        homebrewAwaitingTerminal = false
        appsThatDidNotQuit = []
        items = []
        allowedRemovalPaths = []
        errorMessage = nil
        phase = .empty
    }

    // MARK: - Removal

    /// Target apps whose bundle is part of the current removal selection.
    private func targetStatesQuitBySelection() -> [TargetState] {
        let keys = Set(items.filter { $0.category == .app && $0.include }
            .compactMap { targetKey(for: $0) })
        return targetStates.filter { keys.contains($0.key) }
    }

    /// The target apps and any background apps embedded inside them that are
    /// running now. Embedded helpers do not always share the main bundle ID.
    private func runningTargetApplications(in states: [TargetState]) -> [NSRunningApplication] {
        let targetURLs = states.map(\.target.url)
        var seen = Set<pid_t>()
        return NSWorkspace.shared.runningApplications.filter { app in
            guard seen.insert(app.processIdentifier).inserted else { return false }
            return targetURLs.contains { targetURL in
                app.bundleURL?.resolvingSymlinksInPath().standardizedFileURL == targetURL
                    || UninstallerSupport.isNestedBundle(app.bundleURL, in: targetURL)
            }
        }
    }

    /// Names of the running apps a removal of the current selection would
    /// quit. Only a selected app bundle (or something inside it) quits them;
    /// leftovers alone never touch a process.
    var appsQuitBySelection: [String] {
        let states = targetStatesQuitBySelection()
        guard !states.isEmpty else { return [] }
        return runningTargetApplications(in: states).map { app in
            app.localizedName ?? states.first?.target.name ?? ""
        }
    }

    /// `quitConfirmed` is the user's yes to quitting the running apps; without
    /// it a selection that needs one of them closed does nothing.
    func removeSelected(quitConfirmed: Bool = false) {
        guard phase == .results, !isRemoving else { return }
        let chosen = items.filter(\.include)
        guard !chosen.isEmpty else { return }
        // Only moving a bundle needs its app closed.
        let statesToQuit = targetStatesQuitBySelection()
        let runningAppsToTerminate = runningTargetApplications(in: statesToQuit)
        guard runningAppsToTerminate.isEmpty || quitConfirmed else { return }
        appsThatDidNotQuit = []
        phase = .removing
        runningAppsToTerminate.forEach { $0.terminate() }

        let allowedPaths = allowedRemovalPaths
        let states = targetStates
        let alreadyFreed = homebrewRemovalSize
        let packageRemovedApplicationPaths = homebrewRemovedApplicationPaths
        let adminPrompt = L10n.shared.s.uninstallerAdminUnloadPrompt

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if !runningAppsToTerminate.isEmpty {
                let deadline = Date().addingTimeInterval(2.5)
                while Date() < deadline {
                    let stillRunning = runningAppsToTerminate.filter { !$0.isTerminated }
                    if stillRunning.isEmpty { break }
                    Thread.sleep(forTimeInterval: 0.1)
                }
                // An app still open may be asking to save a document. Nothing
                // moves; force quitting waits for a second answer.
                let stillRunning = runningAppsToTerminate.filter { !$0.isTerminated }
                if !stillRunning.isEmpty {
                    DispatchQueue.main.async {
                        guard let self, self.phase == .removing else { return }
                        self.phase = .results
                        self.appsThatDidNotQuit = stillRunning.map {
                            $0.localizedName ?? $0.bundleURL?.deletingPathExtension().lastPathComponent ?? ""
                        }.filter { !$0.isEmpty }
                    }
                    return
                }
            }

            let fallbackTargetKey = states.count == 1 ? states[0].key : nil
            let keyForItem: (Leftover) -> String? = { item in
                item.targetURL?.standardizedFileURL.path ?? fallbackTargetKey
            }
            let batchLookupBundleIDs = Set(chosen.compactMap(\.ownerBundleID))
                .union(Set(chosen.compactMap(\.evidenceBundleID)))
            var knownApplicationsCache: [URL]?
            var knownApplicationIDsCache: [(url: URL, bundleID: String)]?
            func knownApplicationsSnapshot() -> ([URL], [(url: URL, bundleID: String)]) {
                if let knownApplicationsCache, let knownApplicationIDsCache {
                    return (knownApplicationsCache, knownApplicationIDsCache)
                }
                let applications = Self.knownApplicationURLs(candidateBundleIDs: batchLookupBundleIDs)
                let identifiers = Self.applicationBundleIdentifiers(in: applications)
                knownApplicationsCache = applications
                knownApplicationIDsCache = identifiers
                return (applications, identifiers)
            }

            var outcomes: [UninstallerSupport.RemovalOutcome] = [.removedPermanently(size: alreadyFreed)]
            var failed: [Leftover] = []
            var targetKeysWithChosenItems = Set<String>()

            for state in states {
                let targetChosen = chosen.filter { keyForItem($0) == state.key }
                guard !targetChosen.isEmpty else { continue }
                targetKeysWithChosenItems.insert(state.key)
                let targetURL = state.target.url
                let candidateBundleIDs = Set(targetChosen.compactMap(\.ownerBundleID))
                let candidateGroupIDs = Set(targetChosen.compactMap(\.ownerGroupID))
                let evidenceBundleIDs = Set(targetChosen.compactMap(\.evidenceBundleID))

                let targetIsOriginal = Self.applicationIdentityMatches(
                    targetURL,
                    appIdentity: state.fileIdentity,
                    infoIdentity: state.infoIdentity)
                let targetWasRemovedByPackageManager = packageRemovedApplicationPaths.contains(state.key)
                    && UninstallerSupport.isConfirmedAbsent(at: targetURL)
                let mayClaimSharedData = targetIsOriginal || targetWasRemovedByPackageManager
                let knownApplications: [URL]
                let knownApplicationIDs: [(url: URL, bundleID: String)]
                if mayClaimSharedData {
                    (knownApplications, knownApplicationIDs) = knownApplicationsSnapshot()
                } else {
                    knownApplications = []
                    knownApplicationIDs = []
                }
                let exclusiveBundleIDs = mayClaimSharedData
                    ? Self.exclusiveOwnedBundleIDs(
                        in: targetURL, candidates: candidateBundleIDs,
                        knownApplicationIDs: knownApplicationIDs,
                        requiresCurrentOwnership: !targetWasRemovedByPackageManager)
                    : []
                let exclusiveEvidenceBundleIDs = mayClaimSharedData
                    ? UninstallerSupport.exclusiveBundleIDs(
                        evidenceBundleIDs, selectedURL: targetURL,
                        knownApplications: knownApplicationIDs)
                    : []
                let currentSigning: (teamIDs: Set<String>, groupIDs: Set<String>)
                if targetIsOriginal {
                    currentSigning = Self.signingIdentity(
                        in: targetURL, requireValidSignature: true)
                } else if targetWasRemovedByPackageManager {
                    currentSigning = (state.teamIDs, candidateGroupIDs)
                } else {
                    currentSigning = ([], [])
                }
                let currentGroupIDs = currentSigning.groupIDs.intersection(candidateGroupIDs)
                let exclusiveGroupIDs = mayClaimSharedData
                    ? Self.exclusiveGroupIDs(currentGroupIDs,
                                             selectedTeamIDs: currentSigning.teamIDs,
                                             selectedURL: targetURL,
                                             knownApplications: knownApplications)
                    : []

                // Ownership depends on the sets computed above, so the check stays
                // here and reaches the removal seam as a closure. Only leftovers
                // are asked; the seam never consults it for the app bundle.
                let keepsOwnership: (Leftover) -> Bool = { item in
                    if let groupID = item.ownerGroupID {
                        return exclusiveGroupIDs.contains(groupID)
                    }
                    if let bundleID = item.ownerBundleID {
                        let evidenceIsExclusive = item.evidenceBundleID.map(
                            exclusiveEvidenceBundleIDs.contains) ?? true
                        let sharedWithVendorSibling = UninstallerSupport.vendorDataIsShared(
                            bundleID: bundleID, confidence: item.confidence,
                            selectedURL: targetURL, knownApplications: knownApplicationIDs)
                        return exclusiveBundleIDs.contains(bundleID)
                            && evidenceIsExclusive
                            && !sharedWithVendorSibling
                    }
                    return false
                }
                let isStillSafe: (Leftover) -> Bool = { item in
                    Self.removalIsStillSafe(item.url,
                                            expectedIdentity: item.fileIdentity,
                                            allowedPaths: allowedPaths,
                                            targetURL: targetURL)
                }
                let removal = Self.removeChosen(targetChosen, keepsOwnership: keepsOwnership,
                                                isStillSafe: isStillSafe,
                                                installLink: state.installLink,
                                                runAdmin: { targets in
                    guard let command = UninstallerSupport.privilegedBootoutCommand(targets: targets) else {
                        return false
                    }
                    return AdminShell.runSync(command, prompt: adminPrompt)
                })
                outcomes.append(contentsOf: removal.outcomes)
                failed.append(contentsOf: removal.failed)
            }

            // When Homebrew took the whole selected payload of a target, there
            // is no target batch left for removeChosen to clean the install
            // alias. The alias still goes only after the bundle is gone.
            for state in states where packageRemovedApplicationPaths.contains(state.key)
                && !targetKeysWithChosenItems.contains(state.key) {
                Self.trashInstallLinkIfBundleIsGone(state.installLink, failed: &failed,
                                                    trash: { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) },
                                                    finderTrash: { AppUninstaller.trashViaFinder($0) })
            }

            let totals = UninstallerSupport.removalTotals(outcomes)
            DispatchQueue.main.async {
                // The user may have dismissed the flow while files moved.
                guard let self, self.phase == .removing else { return }
                let kept = Self.leftoversKeptAfterRemoval(failed)
                self.items = kept.items
                self.allowedRemovalPaths = kept.allowedPaths
                self.phase = .done(movedToTrash: totals.movedToTrash,
                                   freedPermanently: totals.freedPermanently,
                                   failed: failed)
            }
        }
    }

    /// The second answer for apps that did not quit: force quit them (unsaved
    /// changes are lost) and go on with the removal.
    func forceQuitAndRemove() {
        guard phase == .results, !appsThatDidNotQuit.isEmpty,
              items.contains(where: { $0.category == .app && $0.include }) else { return }
        appsThatDidNotQuit = []
        runningTargetApplications(in: targetStatesQuitBySelection()).forEach { $0.forceTerminate() }
        removeSelected(quitConfirmed: true)
    }

    /// Leaves the apps that did not quit running; nothing was removed.
    func keepRunningApps() {
        appsThatDidNotQuit = []
    }

    /// Runs the removal again for the leftovers that failed last time, and only
    /// them. Does nothing unless the last removal ended with failures.
    func retryFailed() {
        // While a Homebrew package is selected, the Homebrew flow owns removals, as in the UI.
        guard case let .done(_, _, failed) = phase, !failed.isEmpty, !isRemoving,
              selectedHomebrewPackages.isEmpty else { return }
        let kept = Self.leftoversKeptAfterRemoval(failed)
        items = kept.items
        allowedRemovalPaths = kept.allowedPaths
        // The size the first run freed is already reported in its done state.
        homebrewRemovalSize = 0
        phase = .results
        removeSelected()
    }

    /// What the list keeps after a removal: the failed leftovers, still
    /// selected, and the standardized paths they may be removed under.
    static func leftoversKeptAfterRemoval(_ failed: [Leftover])
        -> (items: [Leftover], allowedPaths: Set<String>) {
        let kept = failed.map { leftover -> Leftover in
            var leftover = leftover
            leftover.include = true
            return leftover
        }
        return (kept, Set(kept.map { $0.url.standardizedFileURL.path }))
    }

    /// The order removal runs in: leftovers first, each in its current order,
    /// then the app bundle. `removeChosen` holds the bundle back until every
    /// leftover is settled.
    static func removalOrder(_ items: [Leftover]) -> [Leftover] {
        items.filter { $0.category != .app } + items.filter { $0.category == .app }
    }

    /// Removes the chosen items in two stages. The leftovers go first, each
    /// through the ownership check, the safety guard, the agent unload and the
    /// trash, then one Finder batch for what the trash could not move. The app
    /// bundle goes last, and only when no selected leftover ended in `failed`;
    /// otherwise every bundle still present is appended to `failed` and stays
    /// in place.
    /// `trash` and `finderTrash` are injectable so tests never touch the real
    /// Trash, /Applications or AppleScript. `runAdmin` defaults to refusal:
    /// a privileged job stays in place unless the caller supplies the prompt.
    static func removeChosen(
        _ chosen: [Leftover],
        keepsOwnership: (Leftover) -> Bool,
        isStillSafe: (Leftover) -> Bool,
        installLink: (url: URL, identity: UninstallerSupport.FileIdentity, bundlePath: String)? = nil,
        privilegedLocation: (URL) -> Bool = { UninstallerSupport.isPrivilegedLaunchLocation($0) },
        privilegedTarget: (URL) -> String? = { UninstallerSupport.privilegedServiceTarget(for: $0) },
        runAdmin: ([String]) -> Bool = { _ in false },
        trash: (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) },
        finderTrash: ([URL]) -> Void = { AppUninstaller.trashViaFinder($0) }
    ) -> (outcomes: [UninstallerSupport.RemovalOutcome], failed: [Leftover]) {
        var outcomes: [UninstallerSupport.RemovalOutcome] = []
        var failed: [Leftover] = []
        let ordered = removalOrder(chosen)
        let leftovers = ordered.filter { $0.category != .app }
        let bundles = ordered.filter { $0.category == .app }
        let requested = privilegedBootoutTargets(in: leftovers.filter {
            keepsOwnership($0) && isStillSafe($0)
        },
                                                 privilegedLocation: privilegedLocation,
                                                 privilegedTarget: privilegedTarget)
        let unloadedPrivileged: Set<String>
        if requested.isEmpty {
            unloadedPrivileged = []
        } else if runAdmin(requested) {
            unloadedPrivileged = Set(requested)
        } else {
            unloadedPrivileged = []
        }

        let stubbornLeftovers = trashPass(leftovers, keepsOwnership: keepsOwnership,
                                          isStillSafe: isStillSafe,
                                          unloadedPrivileged: unloadedPrivileged,
                                          privilegedLocation: privilegedLocation,
                                          privilegedTarget: privilegedTarget,
                                          trash: trash,
                                          outcomes: &outcomes, failed: &failed)
        finderPass(stubbornLeftovers, isStillSafe: isStillSafe, finderTrash: finderTrash,
                   outcomes: &outcomes, failed: &failed)

        // Gate: the bundle waits for every leftover, Finder batch included.
        guard failed.isEmpty else {
            // A bundle already gone names no call of ours, so it enters no total.
            failed.append(contentsOf: bundles.filter {
                !UninstallerSupport.isConfirmedAbsent(at: $0.url)
            })
            trashInstallLinkIfBundleIsGone(installLink, failed: &failed,
                                           trash: trash, finderTrash: finderTrash)
            return (outcomes, failed)
        }
        let stubbornBundles = trashPass(bundles, keepsOwnership: { _ in true },
                                        isStillSafe: isStillSafe,
                                        unloadedPrivileged: unloadedPrivileged,
                                        privilegedLocation: privilegedLocation,
                                        privilegedTarget: privilegedTarget,
                                        trash: trash,
                                        outcomes: &outcomes, failed: &failed)
        finderPass(stubbornBundles, isStillSafe: isStillSafe, finderTrash: finderTrash,
                   outcomes: &outcomes, failed: &failed)
        trashInstallLinkIfBundleIsGone(installLink, failed: &failed,
                                       trash: trash, finderTrash: finderTrash)
        return (outcomes, failed)
    }

    /// Service targets that need one administrator bootout before their files
    /// can move. A symlink is never one of them.
    private static func privilegedBootoutTargets(
        in items: [Leftover],
        privilegedLocation: (URL) -> Bool,
        privilegedTarget: (URL) -> String?
    ) -> [String] {
        let targets = items.compactMap { item -> String? in
            guard privilegedLocation(item.url),
                  !UninstallerSupport.isSymbolicLink(item.url) else { return nil }
            return privilegedTarget(item.url)
        }
        return Array(Set(targets)).sorted()
    }

    /// After the bundle itself is gone, remove the alias the person picked.
    /// A bundle that failed, or that is still on disk, keeps its alias.
    private static func trashInstallLinkIfBundleIsGone(
        _ installLink: (url: URL, identity: UninstallerSupport.FileIdentity, bundlePath: String)?,
        failed: inout [Leftover],
        trash: (URL) throws -> Void,
        finderTrash: ([URL]) -> Void
    ) {
        guard let installLink else { return }
        let bundle = URL(fileURLWithPath: installLink.bundlePath).standardizedFileURL
        let bundleFailed = failed.contains {
            $0.category == .app && $0.url.standardizedFileURL.path == bundle.path
        }
        guard !bundleFailed, UninstallerSupport.isConfirmedAbsent(at: bundle) else { return }
        if var failure = removeInstallLink(url: installLink.url,
                                           identity: installLink.identity,
                                           trash: trash,
                                           finderTrash: finderTrash) {
            // The alias is synthesized after the scan, so carry the target
            // association a retry needs to put it back in the right batch.
            failure.targetURL = bundle
            failure.targetName = bundle.deletingPathExtension().lastPathComponent
            failed.append(failure)
        }
    }

    /// Moves one install alias to the Trash. Returns it only when it is still
    /// the same symlink afterwards.
    private static func removeInstallLink(
        url: URL,
        identity: UninstallerSupport.FileIdentity,
        trash: (URL) throws -> Void,
        finderTrash: ([URL]) -> Void
    ) -> Leftover? {
        guard UninstallerSupport.installLinkIsStillTheOne(url, identity: identity) else { return nil }
        do {
            try trash(url)
        } catch {
            if UninstallerSupport.entryExists(at: url) {
                finderTrash([url])
            }
        }
        guard UninstallerSupport.installLinkIsStillTheOne(url, identity: identity) else { return nil }
        return Leftover(url: url, category: .app, size: 0,
                        ownerBundleID: nil, ownerGroupID: nil, evidenceBundleID: nil,
                        confidence: .exact, fileIdentity: identity, include: true)
    }

    /// One per-item pass. Returns the items the trash left in place, for the
    /// Finder batch that follows the pass.
    private static func trashPass(_ items: [Leftover],
                                  keepsOwnership: (Leftover) -> Bool,
                                  isStillSafe: (Leftover) -> Bool,
                                  unloadedPrivileged: Set<String>,
                                  privilegedLocation: (URL) -> Bool,
                                  privilegedTarget: (URL) -> String?,
                                  trash: (URL) throws -> Void,
                                  outcomes: inout [UninstallerSupport.RemovalOutcome],
                                  failed: inout [Leftover]) -> [Leftover] {
        var stubborn: [Leftover] = []
        for item in items {
            guard keepsOwnership(item) else {
                // Same absence rule as the safety guard below: a confirmed
                // absence enters no total.
                if !UninstallerSupport.isConfirmedAbsent(at: item.url) {
                    failed.append(item)
                }
                continue
            }
            guard isStillSafe(item) else {
                // The package manager or another pass may have taken the path.
                // A confirmed absence names no call of ours that removed the
                // item, so it enters no total; a still-present path, or one
                // we can no longer read, stays a failure.
                if !UninstallerSupport.isConfirmedAbsent(at: item.url) {
                    failed.append(item)
                }
                continue
            }
            // A root-owned agent, daemon or helper stays until one
            // administrator bootout has confirmed the job is gone.
            if privilegedLocation(item.url) {
                guard let target = privilegedTarget(item.url),
                      unloadedPrivileged.contains(target) else {
                    if !UninstallerSupport.isConfirmedAbsent(at: item.url) {
                        failed.append(item)
                    }
                    continue
                }
            }
            // Unload a user agent first. If launchd still holds the job,
            // the plist stays where it is and the item counts as failed.
            guard Self.unloadAgentBeforeTrash(item.url) else {
                failed.append(item)
                continue
            }
            switch UninstallerSupport.trashUserLockedObject(
                item.url, identity: item.fileIdentity,
                isStillSafe: { isStillSafe(item) }, trash: trash) {
            case .moved:
                outcomes.append(.movedToTrash(size: item.size))
                continue
            case .failed:
                failed.append(item)
                continue
            case .notLocked:
                break
            }
            do {
                try trash(item.url)
                outcomes.append(.movedToTrash(size: item.size))
            } catch {
                // Absence here names no call of ours that removed the item,
                // so it enters no total.
                if UninstallerSupport.entryExists(at: item.url) {
                    stubborn.append(item)
                } else if !UninstallerSupport.isConfirmedAbsent(at: item.url) {
                    failed.append(item)
                }
            }
        }
        return stubborn
    }

    /// Items we lack rights for (root-owned apps, /Library files) go through
    /// Finder, which shows the administrator prompt and moves them to the Trash
    /// exactly like a drag would. One batch, one prompt; afterwards whatever
    /// still exists counts as failed.
    private static func finderPass(_ stubborn: [Leftover],
                                   isStillSafe: (Leftover) -> Bool,
                                   finderTrash: ([URL]) -> Void,
                                   outcomes: inout [UninstallerSupport.RemovalOutcome],
                                   failed: inout [Leftover]) {
        guard !stubborn.isEmpty else { return }
        let stillSafe = stubborn.filter { item in
            var info = stat()
            return isStillSafe(item) && lstat(item.url.path, &info) == 0
                && UInt32(info.st_flags) & UInt32(UF_IMMUTABLE) == 0
        }
        failed.append(contentsOf: stubborn.filter { item in
            !stillSafe.contains(where: { $0.id == item.id })
                && !UninstallerSupport.isConfirmedAbsent(at: item.url)
        })
        if !stillSafe.isEmpty {
            finderTrash(stillSafe.map(\.url))
        }
        for item in stillSafe {
            if UninstallerSupport.isConfirmedAbsent(at: item.url) {
                // Finder's delete moves to the Trash, never removes for good.
                outcomes.append(.movedToTrash(size: item.size))
            } else {
                failed.append(item)
            }
        }
    }

    /// After Homebrew has removed the package receipts and app artifacts,
    /// clean only the other items the person selected. The apps themselves are
    /// excluded so this flow never tries to remove the same bundle twice.
    func removeSelectedWithHomebrew(confirmation: HomebrewRemovalConfirmation) {
        let currentPackages = selectedHomebrewPackages
        let confirmedIDs = Set(confirmation.packages.map(\.id))
        let currentIDs = Set(currentPackages.map(\.id))
        let currentTargetPaths = Self.homebrewTargetPathsByPackage(
            targetPackages: targetStates.map { HomebrewTargetPackage(targetPath: $0.key, package: $0.homebrewPackage) },
            packageIDs: currentIDs)
        guard phase == .results, !isRemoving,
              confirmedIDs == currentIDs,
              confirmation.targetPathsByPackage == currentTargetPaths,
              Set(items.filter(\.include).map(\.id)) == confirmation.selectedIDs else {
            QuickToolHUD.show(icon: "exclamationmark.circle",
                              message: L10n.shared.s.uninstallerConfirmationExpired)
            return
        }
        let manager = HomebrewManager.shared
        // Read-only observation of the status contract documented on
        // HomebrewManager.operationStatus; the brew run itself stays driven
        // by HomebrewManager.
        guard manager.operation == nil else { return }
        errorMessage = nil
        pendingHomebrewTerminalConfirmation = nil
        homebrewAwaitingTerminal = false
        manager.clearLog()
        homebrewRemovalObservation?.cancel()
        homebrewRemovalObservation = manager.$operationStatus
            .compactMap { $0 }
            .filter { $0.action == .uninstall && Set($0.packages.map(\.id)) == confirmedIDs }
            .sink { [weak self] status in
                guard status.result != .running else { return }
                // An untrusted tap stops the run; trusting it from the card
                // runs the same uninstall again, which this keeps watching.
                if status.result == .failed, manager.untrustedTap != nil {
                    self?.errorMessage = nil
                    return
                }
                self?.homebrewRemovalObservation?.cancel()
                self?.homebrewRemovalObservation = nil
                if status.result != .succeeded {
                    self?.reconcileInterruptedHomebrewRemoval(confirmation: confirmation)
                }
                if status.result == .succeeded {
                    self?.errorMessage = nil
                    self?.finishRemovalAfterHomebrew(confirmation: confirmation)
                } else if status.result == .cancelled {
                    self?.errorMessage = L10n.shared.s.homebrewOperationCancelled
                } else if status.result == .needsTerminal {
                    self?.errorMessage = L10n.shared.s.homebrewTerminalFallback
                    self?.pendingHomebrewTerminalConfirmation = confirmation
                    self?.homebrewAwaitingTerminal = true
                } else {
                    let err = status.lastActivity ?? manager.errorMessage
                    self?.errorMessage = (err?.isEmpty == false) ? err : String(format: L10n.shared.s.homebrewOperationFailedFormat, confirmation.packageDisplayNames)
                }
            }
        if confirmation.packages.count == 1, let package = confirmation.packages.first {
            manager.uninstall(package)
        } else {
            manager.uninstallCasks(confirmation.packages)
        }
    }

    /// After the user ran the uninstall in Terminal: once every app bundle in
    /// the batch is confirmed gone, goes on with the leftovers still selected,
    /// as if brew had finished here.
    func continueAfterTerminal() {
        guard let confirmation = pendingHomebrewTerminalConfirmation,
              phase == .results, !isRemoving else { return }
        for package in confirmation.packages {
            guard let targetPaths = confirmation.targetPathsByPackage[package.id] else { return }
            for targetPath in targetPaths {
                guard UninstallerSupport.isConfirmedAbsent(at: URL(fileURLWithPath: targetPath)) else {
                    QuickToolHUD.show(icon: "exclamationmark.circle",
                                      message: L10n.shared.s.uninstallerTerminalStillInstalled)
                    return
                }
            }
        }
        pendingHomebrewTerminalConfirmation = nil
        homebrewAwaitingTerminal = false
        errorMessage = nil
        finishRemovalAfterHomebrew(confirmation: confirmation)
    }

    private func reconcileInterruptedHomebrewRemoval(confirmation: HomebrewRemovalConfirmation) {
        for package in confirmation.packages {
            let candidates = confirmation.targetPathsByPackage[package.id] ?? []
            let targetPaths = Self.interruptedHomebrewTargetPathsToReconcile(
                targetPaths: candidates,
                alreadyRemoved: homebrewRemovedApplicationPaths,
                isAbsent: { path in
                    guard let index = targetStates.firstIndex(where: { $0.key == path }) else { return false }
                    return UninstallerSupport.isConfirmedAbsent(at: targetStates[index].target.url)
                })
            for targetPath in targetPaths {
                guard let stateIndex = targetStates.firstIndex(where: { $0.key == targetPath }) else { continue }
                homebrewRemovedApplicationPaths.insert(targetPath)
                targetStates[stateIndex].homebrewPackage = nil
                guard let app = items.first(where: {
                    $0.category == .app && targetKey(for: $0) == targetPath
                }) else { continue }
                if app.include { homebrewRemovalSize += app.size }
                setInclude(false, for: app.id)
            }
        }
    }

    private func finishRemovalAfterHomebrew(confirmation: HomebrewRemovalConfirmation) {
        guard phase == .results else { return }
        var lookupFailed: [Leftover] = []

        let alreadyReconciled = homebrewRemovedApplicationPaths
        var removals: [(targetPath: String, stateIndex: Int, app: Leftover)] = []
        for package in confirmation.packages {
            for targetPath in confirmation.targetPathsByPackage[package.id] ?? [] {
                guard !alreadyReconciled.contains(targetPath) else { continue }
                guard let stateIndex = targetStates.firstIndex(where: { $0.key == targetPath }),
                      let app = items.first(where: {
                          $0.category == .app && $0.include && targetKey(for: $0) == targetPath
                      }) else {
                    errorMessage = L10n.shared.s.uninstallerConfirmationExpired
                    return
                }
                removals.append((targetPath, stateIndex, app))
            }
        }

        for removal in removals {
            let targetURL = targetStates[removal.stateIndex].target.url
            // Completion is published before the stored status stops reading as
            // active. Clear the package before changing the guarded selection,
            // and credit the app only after its absence is confirmed.
            homebrewRemovedApplicationPaths.insert(removal.targetPath)
            targetStates[removal.stateIndex].homebrewPackage = nil
            setInclude(false, for: removal.app.id)
            if UninstallerSupport.isConfirmedAbsent(at: targetURL) {
                homebrewRemovalSize += removal.app.size
            } else if UninstallerSupport.entryExists(at: targetURL) {
                // Package removal succeeded but left the bundle. Re-select only
                // the app so removeSelected can finish it under the package
                // flag, counting size once when it is actually gone.
                setInclude(true, for: removal.app.id)
            } else {
                // A failed lookup is not proof of removal. Keep the failure visible.
                homebrewRemovedApplicationPaths.remove(removal.targetPath)
                setInclude(true, for: removal.app.id)
                lookupFailed.append(removal.app)
            }
        }

        guard lookupFailed.isEmpty else {
            phase = .done(movedToTrash: 0, freedPermanently: homebrewRemovalSize,
                          failed: lookupFailed)
            return
        }
        if items.contains(where: \.include) {
            removeSelected()
        } else {
            var linkFailed: [Leftover] = []
            for state in targetStates where homebrewRemovedApplicationPaths.contains(state.key) {
                Self.trashInstallLinkIfBundleIsGone(state.installLink, failed: &linkFailed,
                                                    trash: { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) },
                                                    finderTrash: { AppUninstaller.trashViaFinder($0) })
            }
            phase = .done(movedToTrash: 0, freedPermanently: homebrewRemovalSize,
                          failed: linkFailed)
        }
    }

    /// Asks Finder to trash `urls`. Finder owns the privilege elevation (the
    /// standard administrator prompt) and the result is a reversible move to
    /// the Trash, never a permanent delete. Waits for the user to answer the
    /// prompt, up to `finderTrashTimeout`; a cancel simply leaves the items in
    /// place. Past the limit the script itself gives up, so no execution is
    /// left behind, and every item still present is reported as failed: the
    /// removal never stays stuck on a Finder that does not answer. Each path
    /// has its own `try` block, so a failure on one item does not stop the
    /// next. Failures are logged by category and error number only, never by
    /// path.
    private static func trashViaFinder(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        guard AppleScriptRunner.consentToAutomate(bundleID: "com.apple.finder") else { return }
        // In-process Apple Events (see AppleScriptRunner): the Finder Automation
        // consent is attributed to this app and re-requested if it was lost,
        // instead of a fragile osascript subprocess. Paths are embedded as
        // escaped string literals (no argv).
        let result = AppleScriptRunner.runDetailed(finderTrashScript(for: urls))
        let records = finderTrashRecords(from: result.output, count: urls.count)
        let failures: [FinderTrashFailure?] = result.ok
            ? finderTrashFailures(from: result.output, count: urls.count)
            : Array(repeating: .ioError, count: urls.count)
        for (index, failure) in failures.enumerated() {
            guard let failure else { continue }
            let number = result.ok ? records[index].flatMap(finderTrashErrorNumber) : result.errorNumber
            log.error("Finder trash failed for item \(index + 1, privacy: .public): \(String(describing: failure), privacy: .public), AppleScript error \(number.map(String.init) ?? "none", privacy: .public)")
        }
    }

    /// Room for the administrator prompt Finder may show for the batch.
    static let finderTrashTimeout: TimeInterval = 180

    /// Why Finder did not move one path to the Trash.
    enum FinderTrashFailure: Equatable {
        case cancelled
        case consentDenied
        case ioError
    }

    /// The script for one Finder batch. The POSIX file references are built
    /// before the Finder `tell` block, then each path gets its own `try` block
    /// whose handler records the result and does not re-raise. The script
    /// returns one line per path, in input order: "ok" or "error <number>".
    /// Each Finder event waits at most `finderTrashTimeout`; once one times out
    /// (-1712) the paths after it are not sent and record the same error.
    static func finderTrashScript(for urls: [URL]) -> String {
        var lines = ["set hexaTrashLog to \"\"", "set hexaTrashTimedOut to false"]
        for (index, url) in urls.enumerated() {
            lines.append("set hexaTrashItem\(index) to POSIX file \(AppleScriptRunner.literal(url.path))")
        }
        lines += ["tell application \"Finder\"", "with timeout of \(Int(finderTrashTimeout)) seconds"]
        for index in urls.indices {
            lines += [
                "if hexaTrashTimedOut then",
                "set hexaTrashLog to hexaTrashLog & \"error -1712\" & linefeed",
                "else",
                "try",
                "delete hexaTrashItem\(index)",
                "set hexaTrashLog to hexaTrashLog & \"ok\" & linefeed",
                "on error hexaTrashMessage number hexaTrashNumber",
                "if hexaTrashNumber is -1712 then set hexaTrashTimedOut to true",
                "set hexaTrashLog to hexaTrashLog & \"error \" & hexaTrashNumber & linefeed",
                "end try",
                "end if",
            ]
        }
        lines += ["end timeout", "end tell", "return hexaTrashLog"]
        return lines.joined(separator: "\n")
    }

    /// One entry per path: nil when Finder moved it, otherwise why it did not.
    /// A missing or unreadable line counts as `.ioError`, the conservative choice.
    static func finderTrashFailures(from output: String, count: Int) -> [FinderTrashFailure?] {
        finderTrashRecords(from: output, count: count).map { (record: String?) -> FinderTrashFailure? in
            guard let record else { return .ioError }
            if record == "ok" { return nil }
            guard let number = finderTrashErrorNumber(record) else { return .ioError }
            return finderTrashFailure(errorNumber: number)
        }
    }

    /// Maps an AppleScript error number from Finder to a failure category.
    static func finderTrashFailure(errorNumber: Int) -> FinderTrashFailure {
        switch errorNumber {
        case -128: return .cancelled
        case -1743, -1744: return .consentDenied
        default: return .ioError
        }
    }

    /// The raw result line for each path, or nil where no line exists.
    private static func finderTrashRecords(from output: String, count: Int) -> [String?] {
        let lines = output.components(separatedBy: "\n")
        return (0..<count).map { (index: Int) -> String? in
            index < lines.count ? lines[index].trimmingCharacters(in: .whitespaces) : nil
        }
    }

    /// The number in an "error <number>" result line, or nil for any other line.
    private static func finderTrashErrorNumber(_ record: String) -> Int? {
        guard record.hasPrefix("error ") else { return nil }
        return Int(record.dropFirst("error ".count))
    }

    // MARK: - Scanning

    private static func collect(appURL: URL,
                                primaryBundleID: String,
                                exclusiveBundleIDs: Set<String>,
                                teamIDs: Set<String>,
                                exclusiveGroupIDs: Set<String>,
                                cancellation: UninstallerSupport.ScanCancellation) -> [Leftover] {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        var paths = [ScanCandidate(url: appURL, category: .app,
                                   ownerBundleID: nil, ownerGroupID: nil,
                                   evidenceBundleID: nil,
                                   confidence: .exact, include: false)]
        let displayNames = appNames(of: appURL)
        let identity = UninstallerSupport.identity(
            primaryBundleID: primaryBundleID,
            bundleIDs: exclusiveBundleIDs,
            displayNames: displayNames,
            teamIDs: teamIDs,
            groupIDs: exclusiveGroupIDs
        )
        let allowedRoots = scanRoots(home: home)

        for folder in UninstallerSupport.searchFolders(
            home: URL(fileURLWithPath: home, isDirectory: true),
            darwinCache: darwinUserDirectory(_CS_DARWIN_USER_CACHE_DIR),
            darwinTemp: darwinUserDirectory(_CS_DARWIN_USER_TEMP_DIR)
        ) {
            guard !cancellation.isCancelled else { return [] }
            appendMatches(in: folder, identity: identity, fm: fm, cancellation: cancellation, into: &paths)
        }
        guard !cancellation.isCancelled else { return [] }
        appendSpotlightMatches(identity: identity, roots: spotlightRoots(home: home),
                               fm: fm, cancellation: cancellation, into: &paths)
        guard !cancellation.isCancelled else { return [] }
        // A hidden home folder named after the app. It needs the same exclusive
        // bundle identifier every other claim on this app's data needs.
        if exclusiveBundleIDs.contains(primaryBundleID) {
            paths += hiddenHomeCandidates(
                home: home,
                appNames: Set(displayNames.map { $0.lowercased() }),
                ownerBundleID: primaryBundleID, cancellation: cancellation,
                otherAppNames: { otherApplicationNames(excluding: appURL, cancellation: cancellation) })
        }

        guard !cancellation.isCancelled else { return [] }
        // Last line of defense: nothing outside the scanned roots (or the app
        // bundle itself) may ever reach the removal list.
        let appPath = appURL.standardizedFileURL.path
        let safe = dedupe(paths).filter { candidate in
            guard !cancellation.isCancelled else { return false }
            let path = candidate.url.standardizedFileURL.path
            guard UninstallerSupport.removalObjectIsSafe(candidate.url) else { return false }
            if path == appPath { return true }
            guard let root = allowedRoots.first(where: { path.hasPrefix($0.path + "/") }) else {
                return hiddenHomeRemovalIsSafe(candidate.url, home: home)
            }
            return UninstallerSupport.removalPathIsSafe(candidate.url, within: root, allowItemUserLock: true)
        }
        guard !cancellation.isCancelled else { return [] }
        let result = safe
            .compactMap { candidate -> Leftover? in
                // Sizing walks every folder found; stop there too.
                guard !cancellation.isCancelled,
                      let fileIdentity = UninstallerSupport.fileIdentity(at: candidate.url) else {
                    return nil
                }
                let size = directorySize(of: candidate.url, fm: fm, cancellation: cancellation)
                guard !cancellation.isCancelled else { return nil }
                return Leftover(url: candidate.url, category: candidate.category,
                                size: size,
                                ownerBundleID: candidate.ownerBundleID,
                                ownerGroupID: candidate.ownerGroupID,
                                evidenceBundleID: candidate.evidenceBundleID,
                                confidence: candidate.confidence,
                                fileIdentity: fileIdentity,
                                include: candidate.include && !UninstallerSupport.userLockEligible(at: candidate.url))
            }
            .sorted { ($0.category.sortRank, -$0.size) < ($1.category.sortRank, -$1.size) }
        return cancellation.isCancelled ? [] : result
    }

    private static func appendMatches(in folder: UninstallerSupport.SearchFolder,
                                      identity: UninstallerSupport.Identity,
                                      fm: FileManager,
                                      cancellation: UninstallerSupport.ScanCancellation,
                                      into paths: inout [ScanCandidate]) {
        let listings = dirListings(at: folder.url, remainingDepth: folder.extraChildDepth, fm: fm, cancellation: cancellation)
        guard !cancellation.isCancelled, !listings.isEmpty else { return }
        let category = category(for: folder.kind)
        let matchingIdentity: UninstallerSupport.Identity
        if folder.requiresSignedGroup {
            matchingIdentity = UninstallerSupport.Identity(
                bundleIDs: [], nameTokens: [], teamIDs: [], groupIDs: identity.groupIDs)
        } else {
            matchingIdentity = folder.allowsNameMatches
                ? identity : UninstallerSupport.technicalIdentity(identity)
        }
        var claimed = Set<String>()
        for hit in UninstallerSupport.leftoverHitRecords(
            listings: listings,
            identity: matchingIdentity,
            extraChildDepth: folder.extraChildDepth,
            crashReporter: folder.crashReporter
        ) {
            guard !cancellation.isCancelled else { return }
            claimed.insert(hit.path)
            appendHit(hit, folder: folder.url, category: category, identity: matchingIdentity,
                      crashReporter: folder.crashReporter, into: &paths)
        }
        guard folder.readsContainerMetadata else { return }
        for listing in listings where !claimed.contains(listing.name) {
            guard !cancellation.isCancelled else { return }
            let url = folder.url.appendingPathComponent(listing.name)
            guard let identifier = containerMetadataIdentifier(at: url) else { continue }
            let match = UninstallerSupport.containerMetadataMatches(identifier, identity: matchingIdentity)
            guard match != .none else { continue }
            claimed.insert(listing.name)
            let groupID = UninstallerSupport.matchingGroupID(identifier, identity: matchingIdentity)
                ?? UninstallerSupport.matchingGroupID(listing.name, identity: matchingIdentity)
            let owner = groupID == nil
                ? (UninstallerSupport.ownerBundleID(for: identifier, identity: matchingIdentity)
                    ?? UninstallerSupport.ownerBundleID(for: listing.name, identity: matchingIdentity)
                    ?? matchingIdentity.bundleIDs.min(by: { $0.count < $1.count }))
                : nil
            guard owner != nil || groupID != nil else { continue }
            let evidence = groupID == nil
                ? UninstallerSupport.verifiedBundleID(identifier) : nil
            paths.append(ScanCandidate(url: url, category: category,
                                       ownerBundleID: owner, ownerGroupID: groupID,
                                       evidenceBundleID: evidence,
                                       confidence: match, include: false))
        }
    }

    private static func appendHit(_ hit: UninstallerSupport.Hit,
                                  folder: URL,
                                  category: Category,
                                  identity: UninstallerSupport.Identity,
                                  crashReporter: Bool,
                                  into paths: inout [ScanCandidate]) {
        let relative = hit.path
        let name = (relative as NSString).lastPathComponent
        let identifier = hit.bundleIdentifier
            ?? CleanerSupport.bundleIDCandidate(fromEntryName: name)
        let groupID = identifier.flatMap {
            UninstallerSupport.matchingGroupID($0, identity: identity)
        } ?? UninstallerSupport.matchingGroupID(name, identity: identity)
        let owner = groupID == nil
            ? (identifier.flatMap { UninstallerSupport.ownerBundleID(for: $0, identity: identity) }
                ?? UninstallerSupport.ownerBundleID(for: name, identity: identity,
                                                crashReporter: crashReporter)
                ?? identity.bundleIDs.min(by: { $0.count < $1.count }))
            : nil
        guard owner != nil || groupID != nil else { return }
        let url = relative.split(separator: "/").reduce(folder) {
            $0.appendingPathComponent(String($1))
        }
        paths.append(ScanCandidate(url: url, category: category,
                                   ownerBundleID: owner, ownerGroupID: groupID,
                                   evidenceBundleID: groupID == nil ? identifier : nil,
                                   confidence: hit.confidence,
                                   include: false))
    }

    private static func dirListings(at url: URL,
                                    remainingDepth: Int,
                                    fm: FileManager,
                                    cancellation: UninstallerSupport.ScanCancellation) -> [UninstallerSupport.DirListing] {
        guard !cancellation.isCancelled else { return [] }
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey]
        guard let entries = try? fm.contentsOfDirectory(at: url,
                                                        includingPropertiesForKeys: Array(keys),
                                                        options: []) else { return [] }
        return entries.compactMap { entry -> UninstallerSupport.DirListing? in
            guard !cancellation.isCancelled else { return nil }
            let name = entry.lastPathComponent
            guard !name.hasPrefix(".") else { return nil }
            let values = try? entry.resourceValues(forKeys: keys)
            guard !cancellation.isCancelled, values?.isSymbolicLink != true else { return nil }
            var children: [UninstallerSupport.DirListing] = []
            if remainingDepth > 0, values?.isDirectory == true {
                children = dirListings(at: entry, remainingDepth: remainingDepth - 1, fm: fm, cancellation: cancellation)
            }
            guard !cancellation.isCancelled else { return nil }
            let bundleIdentifier = packageExtensions.contains(entry.pathExtension.lowercased())
                ? UninstallerSupport.verifiedBundleID(Bundle(url: entry)?.bundleIdentifier)
                : nil
            return UninstallerSupport.DirListing(name: name, children: children,
                                                  bundleIdentifier: bundleIdentifier)
        }
    }

    private static func containerMetadataIdentifier(at url: URL) -> String? {
        let metadata = url.appendingPathComponent(".com.apple.containermanagerd.metadata.plist")
        guard let dict = NSDictionary(contentsOf: metadata) as? [String: Any] else { return nil }
        return dict["MCMMetadataIdentifier"] as? String
    }

    private static func appendSpotlightMatches(identity: UninstallerSupport.Identity,
                                               roots: [URL],
                                               fm: FileManager,
                                               cancellation: UninstallerSupport.ScanCancellation,
                                               into paths: inout [ScanCandidate]) {
        guard !cancellation.isCancelled else { return }
        guard let expression = UninstallerSupport.leftoverSpotlightExpression(identity: identity)
        else { return }
        let scopes = roots.map(\.path).filter { !cancellation.isCancelled && fm.fileExists(atPath: $0) }
        guard !cancellation.isCancelled, !scopes.isEmpty,
              let query = MDQueryCreate(kCFAllocatorDefault, expression as CFString, nil, nil)
        else { return }
        MDQuerySetMaxCount(query, 200)
        MDQuerySetSearchScope(query, scopes as CFArray, 0)
        guard !cancellation.isCancelled,
              MDQueryExecute(query, CFOptionFlags(kMDQuerySynchronous.rawValue)),
              !cancellation.isCancelled else { return }
        let count = min(MDQueryGetResultCount(query), 200)
        var added = 0
        for index in 0..<count {
            guard !cancellation.isCancelled else { return }
            guard added < 80,
                  let raw = MDQueryGetResultAtIndex(query, index) else { continue }
            let item = unsafeBitCast(raw, to: MDItem.self)
            guard let path = MDItemCopyAttribute(item, kMDItemPath) as? String,
                  UninstallerSupport.leftoverSpotlightPathIsAllowed(path, roots: roots)
            else { continue }
            let url = URL(fileURLWithPath: path)
            let matchingIdentity = UninstallerSupport.spotlightIdentity(for: path, identity: identity)
            let match = UninstallerSupport.leftoverMatch(
                url.lastPathComponent, identity: matchingIdentity)
            guard match != .none else { continue }
            let groupID = UninstallerSupport.matchingGroupID(
                url.lastPathComponent, identity: matchingIdentity)
            let evidence = groupID == nil
                ? CleanerSupport.bundleIDCandidate(fromEntryName: url.lastPathComponent) : nil
            let owner = groupID == nil
                ? (UninstallerSupport.ownerBundleID(
                    for: evidence ?? url.lastPathComponent, identity: matchingIdentity)
                    ?? matchingIdentity.bundleIDs.min(by: { $0.count < $1.count }))
                : nil
            guard owner != nil || groupID != nil else { continue }
            paths.append(ScanCandidate(url: url, category: category(forPath: path),
                                       ownerBundleID: owner, ownerGroupID: groupID,
                                       evidenceBundleID: evidence,
                                       confidence: match, include: false))
            added += 1
        }
    }

    private static func category(forPath path: String) -> Category {
        if path.contains("/Caches") { return .caches }
        if path.contains("/Preferences") { return .preferences }
        if path.contains("/Group Containers") || path.contains("/Containers") { return .containers }
        if path.contains("/Logs") { return .logs }
        if path.contains("/Saved Application State") { return .state }
        if path.contains("/Application Support") { return .support }
        return .other
    }

    private static func codeSigningIdentity(at appURL: URL,
                                            requireValidSignature: Bool)
        -> (teamIDs: Set<String>, groupIDs: Set<String>) {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(appURL as CFURL, [], &staticCode) == errSecSuccess,
              let staticCode else { return ([], []) }
        if requireValidSignature,
           SecStaticCodeCheckValidity(staticCode, [], nil) != errSecSuccess {
            return ([], [])
        }
        var info: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(staticCode, flags, &info) == errSecSuccess,
              let info else { return ([], []) }
        let dict = info as NSDictionary
        var teamIDs: Set<String> = []
        if let team = dict[kSecCodeInfoTeamIdentifier] as? String {
            teamIDs.insert(team)
        }
        var groupIDs: Set<String> = []
        if let entitlements = dict[kSecCodeInfoEntitlementsDict] as? [String: Any],
           let groups = entitlements["com.apple.security.application-groups"] as? [String] {
            groupIDs.formUnion(groups.filter { !$0.isEmpty })
        }
        return (teamIDs, groupIDs)
    }

    /// Main app plus owned executable extensions. Resource bundles and
    /// arbitrary nested apps are excluded because their identifiers may be
    /// shared by unrelated products.
    private static func signingIdentity(in appURL: URL,
                                        requireValidSignature: Bool,
                                        cancellation: UninstallerSupport.ScanCancellation? = nil)
        -> (teamIDs: Set<String>, groupIDs: Set<String>) {
        guard cancellation?.isCancelled != true else { return ([], []) }
        if requireValidSignature, !codeSignatureIsValid(at: appURL) {
            return ([], [])
        }
        guard cancellation?.isCancelled != true else { return ([], []) }
        var result = codeSigningIdentity(at: appURL,
                                         requireValidSignature: requireValidSignature)
        let fm = FileManager.default
        guard cancellation?.isCancelled != true else { return ([], []) }
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey]
        guard let enumerator = fm.enumerator(at: appURL,
                                             includingPropertiesForKeys: Array(keys),
                                             options: [.skipsHiddenFiles],
                                             errorHandler: nil) else { return result }
        var inspected = 0
        while cancellation?.isCancelled != true,
              let url = enumerator.nextObject() as? URL {
            let values = try? url.resourceValues(forKeys: keys)
            if values?.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }
            guard cancellation?.isCancelled != true else { return ([], []) }
            guard values?.isDirectory == true,
                  ownedEmbeddedCode(url, in: appURL) else { continue }
            inspected += 1
            guard inspected <= 256 else { break }
            let nested = codeSigningIdentity(at: url,
                                             requireValidSignature: requireValidSignature)
            result.teamIDs.formUnion(nested.teamIDs)
            result.groupIDs.formUnion(nested.groupIDs)
        }
        return result
    }

    private static func codeSignatureIsValid(at url: URL) -> Bool {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode) == errSecSuccess,
              let staticCode else { return false }
        return SecStaticCodeCheckValidity(staticCode, [], nil) == errSecSuccess
    }

    /// An unsigned bundle is readable (it reports errSecCSUnsigned and owns
    /// nothing). A bundle whose signing data cannot be read is not.
    private static func codeSignatureIsReadable(at url: URL) -> Bool {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode) == errSecSuccess,
              let staticCode else { return false }
        var info: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        let status = SecCodeCopySigningInformation(staticCode, flags, &info)
        return status == errSecSuccess || status == errSecCSUnsigned
    }

    private static func category(for kind: UninstallerSupport.Kind) -> Category {
        switch kind {
        case .support: return .support
        case .caches: return .caches
        case .preferences: return .preferences
        case .containers: return .containers
        case .logs: return .logs
        case .state: return .state
        case .other: return .other
        }
    }

    private static func knownApplicationURLs(candidateBundleIDs: Set<String>,
                                             cancellation: UninstallerSupport.ScanCancellation? = nil) -> [URL] {
        guard cancellation?.isCancelled != true else { return [] }
        var urls = InstalledApps.installedApplications(includeSystemApplications: true).map(\.url)
        guard cancellation?.isCancelled != true else { return [] }
        urls += NSWorkspace.shared.runningApplications.compactMap(\.bundleURL)
        for id in candidateBundleIDs {
            guard cancellation?.isCancelled != true else { return [] }
            urls += NSWorkspace.shared.urlsForApplications(withBundleIdentifier: id)
        }
        var seen = Set<String>()
        return urls.compactMap { url in
            guard cancellation?.isCancelled != true else { return nil }
            let resolved = url.resolvingSymlinksInPath().standardizedFileURL
            guard resolved.pathExtension.caseInsensitiveCompare("app") == .orderedSame,
                  FileManager.default.fileExists(atPath: resolved.path),
                  seen.insert(resolved.path).inserted else { return nil }
            return resolved
        }
    }

    private static func exclusiveOwnedBundleIDs(in selectedURL: URL,
                                                candidates: Set<String>,
                                                knownApplicationIDs: [(url: URL, bundleID: String)],
                                                requiresCurrentOwnership: Bool = true,
                                                cancellation: UninstallerSupport.ScanCancellation? = nil) -> Set<String> {
        var eligible = candidates
        if requiresCurrentOwnership {
            let current = allBundleIDs(in: selectedURL, fm: .default, cancellation: cancellation)
            eligible = Set(candidates.filter { candidate in
                current.contains(where: {
                    $0.caseInsensitiveCompare(candidate) == .orderedSame
                })
            })
        }
        guard cancellation?.isCancelled != true else { return [] }
        return UninstallerSupport.exclusiveBundleIDs(eligible,
                                                     selectedURL: selectedURL,
                                                     knownApplications: knownApplicationIDs)
    }

    private static func applicationBundleIdentifiers(in applications: [URL],
                                                     cancellation: UninstallerSupport.ScanCancellation? = nil)
        -> [(url: URL, bundleID: String)] {
        let fm = FileManager.default
        return applications.flatMap { url -> [(url: URL, bundleID: String)] in
            guard cancellation?.isCancelled != true else { return [] }
            return allBundleIDs(in: url, fm: fm, cancellation: cancellation).map { (url, $0) }
        }
    }

    private static func exclusiveGroupIDs(_ candidates: Set<String>,
                                          selectedTeamIDs: Set<String>,
                                          selectedURL: URL,
                                          knownApplications: [URL],
                                          cancellation: UninstallerSupport.ScanCancellation? = nil) -> Set<String> {
        guard cancellation?.isCancelled != true, !candidates.isEmpty else { return [] }
        let selectedPath = selectedURL.resolvingSymlinksInPath().standardizedFileURL.path
        var neighbors: [(teamIDs: Set<String>, groupIDs: Set<String>, readable: Bool)] = []
        for url in knownApplications {
            guard cancellation?.isCancelled != true else { return [] }
            let path = url.resolvingSymlinksInPath().standardizedFileURL.path
            guard path != selectedPath, !path.hasPrefix(selectedPath + "/") else { continue }
            let signing = signingIdentity(in: url, requireValidSignature: false, cancellation: cancellation)
            guard cancellation?.isCancelled != true else { return [] }
            neighbors.append((signing.teamIDs, signing.groupIDs, codeSignatureIsReadable(at: url)))
        }
        return UninstallerSupport.exclusiveSignedGroupIDs(
            candidates, selectedTeamIDs: selectedTeamIDs, neighbors: neighbors)
    }

    private static func removalIsStillSafe(_ url: URL,
                                           expectedIdentity: UninstallerSupport.FileIdentity,
                                           allowedPaths: Set<String>,
                                           targetURL: URL?) -> Bool {
        let path = url.standardizedFileURL.path
        guard allowedPaths.contains(path), let targetURL,
              UninstallerSupport.fileIdentity(at: url) == expectedIdentity,
              UninstallerSupport.removalObjectIsSafe(url) else { return false }
        if path == targetURL.standardizedFileURL.path {
            return !UninstallerSupport.isSymbolicLink(url)
        }
        let home = NSHomeDirectory()
        guard let root = scanRoots(home: home).first(where: {
            path.hasPrefix($0.path + "/")
        }) else { return hiddenHomeRemovalIsSafe(url, home: home) }
        return UninstallerSupport.removalPathIsSafe(url, within: root, allowItemUserLock: true)
    }

    /// Unloads a user launch agent before its plist is trashed, so the job
    /// does not respawn or hold files during removal. Returns false when
    /// launchd still reports the job as loaded; the plist must then stay.
    /// Anything that is not a plist with a valid Label under the user's
    /// LaunchAgents folder returns true without a launchctl call.
    static func unloadAgentBeforeTrash(
        _ plistURL: URL,
        home: String = NSHomeDirectory(),
        run: ([String]) -> (status: Int32, output: String) = { Shell.run("/bin/launchctl", $0) }
    ) -> Bool {
        guard plistURL.pathExtension == "plist",
              plistURL.path.hasPrefix(home + "/Library/LaunchAgents/") else { return true }
        guard let plist = NSDictionary(contentsOf: plistURL) as? [String: Any],
              let label = plist["Label"] as? String, !label.isEmpty,
              !label.contains("/"), !label.contains("..") else { return true }
        let target = "gui/\(getuid())/\(label)"
        // One bootout and one print, no polling. A job that was never loaded
        // makes bootout exit nonzero, which is expected and ignored.
        _ = run(["bootout", target])
        return run(["print", target]).status != 0
    }

    static func applicationIdentityMatches(
        _ url: URL,
        appIdentity: UninstallerSupport.FileIdentity?,
        infoIdentity: UninstallerSupport.FileIdentity?
    ) -> Bool {
        guard let appIdentity, let infoIdentity,
              UninstallerSupport.fileIdentity(at: url) == appIdentity,
              let infoURL = UninstallerSupport.infoPlistURL(for: url) else { return false }
        return UninstallerSupport.fileIdentity(at: infoURL) == infoIdentity
            && UninstallerSupport.removalPathIsSafe(infoURL, within: url, allowRootUserLock: true)
    }

    private static func allBundleIDs(in appURL: URL, fm: FileManager,
                                     cancellation: UninstallerSupport.ScanCancellation? = nil) -> Set<String> {
        guard cancellation?.isCancelled != true else { return [] }
        var result = Set<String>()
        if let primary = UninstallerSupport.verifiedBundleID(UninstallerSupport.bundleIdentifier(for: appURL, fm: fm)) {
            result.insert(primary)
        }
        guard cancellation?.isCancelled != true else { return [] }
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey]
        guard let enumerator = fm.enumerator(at: appURL,
                                             includingPropertiesForKeys: Array(keys),
                                             options: [.skipsHiddenFiles],
                                             errorHandler: nil) else { return result }
        var inspected = 0
        while cancellation?.isCancelled != true,
              let url = enumerator.nextObject() as? URL {
            let values = try? url.resourceValues(forKeys: keys)
            if values?.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }
            guard cancellation?.isCancelled != true else { return [] }
            guard values?.isDirectory == true,
                  ownedEmbeddedCode(url, in: appURL),
                  let id = UninstallerSupport.verifiedBundleID(UninstallerSupport.bundleIdentifier(for: url, fm: fm))
            else { continue }
            inspected += 1
            guard inspected <= 256 else { break }
            result.insert(id)
        }
        return result
    }

    private static func ownedEmbeddedCode(_ url: URL, in appURL: URL) -> Bool {
        switch url.pathExtension.lowercased() {
        case "appex", "xpc":
            return true
        case "app":
            let loginItems = appURL.appendingPathComponent(
                "Contents/Library/LoginItems", isDirectory: true).standardizedFileURL.path
            return url.standardizedFileURL.path.hasPrefix(loginItems + "/")
        default:
            return false
        }
    }

    private static let packageExtensions: Set<String> = [
        "app", "appex", "bundle", "framework", "plugin", "webplugin",
        "prefpane", "qlgenerator", "mdimporter", "service", "saver",
        "colorpicker", "wdgt", "component", "vst", "vst3", "clap", "dpm",
        "aaxplugin", "dictionary", "action", "workflow", "mailbundle",
    ]

    private static func scanRoots(home: String) -> [URL] {
        var roots = [
            URL(fileURLWithPath: home + "/Library", isDirectory: true),
            URL(fileURLWithPath: "/Library", isDirectory: true),
            URL(fileURLWithPath: home + "/.config", isDirectory: true),
            URL(fileURLWithPath: home + "/.cache", isDirectory: true),
            URL(fileURLWithPath: home + "/.local/share", isDirectory: true),
            URL(fileURLWithPath: "/private/var/db/receipts", isDirectory: true),
            URL(fileURLWithPath: "/Users/Shared/Library", isDirectory: true),
        ]
        if let cache = darwinUserDirectory(_CS_DARWIN_USER_CACHE_DIR) { roots.append(cache) }
        if let temp = darwinUserDirectory(_CS_DARWIN_USER_TEMP_DIR) { roots.append(temp) }
        return roots.map(\.standardizedFileURL)
    }

    /// The barrier for a path outside every scan root: only a hidden folder
    /// directly under home, in the `.<token>` form, passes. Home itself, any
    /// deeper path and every other direct child are refused.
    static func hiddenHomeRemovalIsSafe(_ url: URL, home: String) -> Bool {
        UninstallerSupport.isHiddenHomeRoot(url, home: home)
            && UninstallerSupport.removalPathIsSafe(
                url, within: URL(fileURLWithPath: home, isDirectory: true), allowItemUserLock: true)
    }

    /// The hidden home folders `~/.<token>` the app may own. The token is one
    /// of the app's names, compared lowercased and otherwise exactly, and is
    /// refused when another installed app answers to it too. Each match must
    /// be a real directory directly under home. Results start related and
    /// unchecked.
    static func hiddenHomeCandidates(home: String,
                                     appNames: Set<String>,
                                     ownerBundleID: String,
                                     cancellation: UninstallerSupport.ScanCancellation? = nil,
                                     otherAppNames: () -> Set<String>) -> [ScanCandidate] {
        let fm = FileManager.default
        let homeURL = URL(fileURLWithPath: home, isDirectory: true)
        var others: Set<String>?
        var found: [ScanCandidate] = []
        guard cancellation?.isCancelled != true else { return [] }
        for name in (try? fm.contentsOfDirectory(atPath: home)) ?? [] {
            guard cancellation?.isCancelled != true else { return [] }
            guard let token = UninstallerSupport.hiddenHomeToken(folderName: name),
                  appNames.contains(token) else { continue }
            let url = homeURL.appendingPathComponent(name, isDirectory: true)
            var isDirectory: ObjCBool = false
            guard !UninstallerSupport.isSymbolicLink(url),
                  fm.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }
            guard cancellation?.isCancelled != true else { return [] }
            if others == nil { others = otherAppNames() }
            guard cancellation?.isCancelled != true else { return [] }
            guard others?.contains(token) != true else { continue }
            found.append(ScanCandidate(url: url, category: .support,
                                       ownerBundleID: ownerBundleID, ownerGroupID: nil,
                                       evidenceBundleID: nil,
                                       confidence: .related, include: false))
        }
        return found
    }

    /// The names an app answers to: its display names and its executable.
    private static func appNames(of appURL: URL) -> [String] {
        let bundle = Bundle(url: appURL)
        let info = UninstallerSupport.infoDictionary(for: appURL)
        let bundleName = (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? (info?["CFBundleName"] as? String)
        let bundleDisplayName = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (info?["CFBundleDisplayName"] as? String)
        var names = UninstallerSupport.displayNames(
            localizedName: FileManager.default.displayName(atPath: appURL.path),
            fileName: appURL.lastPathComponent,
            bundleName: bundleName,
            bundleDisplayName: bundleDisplayName
        )
        if let executable = (bundle?.object(forInfoDictionaryKey: "CFBundleExecutable") as? String)
            ?? (info?["CFBundleExecutable"] as? String) {
            names.append(executable)
        }
        return names
    }

    /// Lowercased names of every installed app except the selected one. It is
    /// read only when a hidden folder already matches the selected app.
    private static func otherApplicationNames(excluding appURL: URL,
                                              cancellation: UninstallerSupport.ScanCancellation? = nil) -> Set<String> {
        guard cancellation?.isCancelled != true else { return [] }
        let selectedPath = appURL.standardizedFileURL.path
        let apps = InstalledApps.installedApplications(includeSystemApplications: true)
        var names = Set<String>()
        for app in apps where app.url.standardizedFileURL.path != selectedPath {
            guard cancellation?.isCancelled != true else { return [] }
            names.formUnion(appNames(of: app.url).map { $0.lowercased() })
        }
        return names
    }

    private static func spotlightRoots(home: String) -> [URL] {
        [
            URL(fileURLWithPath: home + "/Library", isDirectory: true),
            URL(fileURLWithPath: "/Library", isDirectory: true),
            URL(fileURLWithPath: "/Users/Shared/Library", isDirectory: true),
        ].map(\.standardizedFileURL)
    }

    private static func darwinUserDirectory(_ name: Int32) -> URL? {
        let length = confstr(name, nil, 0)
        guard length > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: length)
        guard confstr(name, &buffer, length) > 0 else { return nil }
        return URL(fileURLWithPath: String(cString: buffer), isDirectory: true)
            .resolvingSymlinksInPath().standardizedFileURL
    }

    /// Drops exact duplicates and any path nested inside another already found.
    /// An exact match upgrades a related one already recorded at the same path.
    private static func dedupe(_ paths: [ScanCandidate]) -> [ScanCandidate] {
        var seen = Set<String>()
        var roots: [String] = []
        var out: [ScanCandidate] = []
        let exactPaths = paths.filter { $0.confidence == .exact }
            .map { $0.url.standardizedFileURL.path }
        for candidate in paths.sorted(by: { $0.url.path.count < $1.url.path.count }) {
            let path = candidate.url.standardizedFileURL.path
            if candidate.confidence == .related,
               exactPaths.contains(where: { $0.hasPrefix(path + "/") }) {
                continue
            }
            if let index = out.firstIndex(where: { $0.url.standardizedFileURL.path == path }) {
                let include = out[index].include || candidate.include
                if out[index].confidence != .exact, candidate.confidence == .exact {
                    out[index] = candidate
                }
                out[index].include = include
                continue
            }
            if seen.contains(path) { continue }
            if roots.contains(where: { path.hasPrefix($0 + "/") }) { continue }
            seen.insert(path)
            roots.append(path)
            out.append(candidate)
        }
        return out
    }

    private static func directorySize(of url: URL, fm: FileManager,
                                      cancellation: UninstallerSupport.ScanCancellation? = nil) -> Int64 {
        guard cancellation?.isCancelled != true else { return 0 }
        if UninstallerSupport.isSymbolicLink(url) {
            guard cancellation?.isCancelled != true else { return 0 }
            return fileSize(url)
        }
        guard cancellation?.isCancelled != true else { return 0 }
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        guard cancellation?.isCancelled != true else { return 0 }
        if !isDir.boolValue { return fileSize(url) }

        var total: Int64 = 0
        if let enumerator = fm.enumerator(at: url,
                                          includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
                                          options: [], errorHandler: nil) {
            while cancellation?.isCancelled != true,
                  let item = enumerator.nextObject() as? URL {
                guard cancellation?.isCancelled != true else { break }
                if UninstallerSupport.isSymbolicLink(item) {
                    enumerator.skipDescendants()
                    continue
                }
                guard cancellation?.isCancelled != true else { break }
                total += fileSize(item)
            }
        }
        return total
    }

    private static func fileSize(_ url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
        return Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
    }
}
