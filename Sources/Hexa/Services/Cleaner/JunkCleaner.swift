// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import Combine

/// Finds junk the Mac accumulates — leftovers of uninstalled apps, orphaned
/// startup items, caches, logs, developer build junk, the Trash, forgotten
/// screenshots — lets the user review every single path with its size, and
/// moves what they confirm to the Trash. Nothing is deleted in place,
/// nothing is touched while the scan runs, and nothing runs at all until the
/// user opens the tool.
///
/// The safety model, in order of importance:
/// 1. Review first. Every item shows its full path and size before anything
///    happens, and uncertain finds start unchecked.
/// 2. Trash, not delete. Every removal is a reversible move to the Trash
///    (the Trash category itself is the one explicit exception).
/// 3. Never guess against a living app. A leftover needs a bundle shaped
///    name, or a shared-container wrapper that leaves one, whose owner is
///    not installed, not running, not registered, not Apple, and not in the
///    same vendor namespace as any installed identifier. Container metadata
///    may name that owner. A display name or a vendor folder is never proof.
/// 4. Scoped roots only. Items come from fixed, well known junk locations,
///    plus the top level of the screenshot folders, where only files macOS
///    itself marked as screen captures are ever considered. The general
///    scan never enters another app's support tree; symbolic links are
///    never followed and each item is bound to its observed file identity.
final class JunkCleaner: ObservableObject {
    static let shared = JunkCleaner()

    enum Phase: Equatable {
        case idle
        case scanning
        case results
        case cleaning
        case done(movedToTrash: Int64, freedPermanently: Int64, failed: Int)
    }

    struct Item: Identifiable, Equatable {
        let id = UUID()
        let url: URL
        let category: CleanerSupport.Category
        let size: Int64
        /// A short secondary line: the owning bundle identifier or label.
        let detail: String
        let fileIdentity: UninstallerSupport.FileIdentity?
        /// Whether this find is safe enough to clean without a second look.
        /// Recommended items start selected and live in the safe section of
        /// the interface; the rest wait unchecked under optional.
        let recommended: Bool
        var include: Bool
        /// The folder a Claude Code conversation travels with; nil for every
        /// other find. Its identity is fixed at scan time, like the item's own.
        let companion: URL?
        let companionIdentity: UninstallerSupport.FileIdentity?
        /// The Trash entries the scan counted, for the Trash row only; the
        /// removal reaches these and nothing that arrived later.
        let trashEntries: [TrashEntry]
        /// Browser key matching BrowserJunk.definitions
        let browserKey: String?
        /// Display name for browser (e.g. "Google Chrome")
        let browserName: String?
        /// Specific targets to be trashed for browser items
        let browserTargets: [BrowserJunk.Target]

        var name: String { browserName ?? url.lastPathComponent }

        init(url: URL, category: CleanerSupport.Category, size: Int64,
             detail: String, recommended: Bool, companion: URL? = nil,
             trashEntries: [TrashEntry] = [],
             browserKey: String? = nil, browserName: String? = nil,
             browserTargets: [BrowserJunk.Target] = []) {
            self.url = url
            self.category = category
            self.size = size
            self.detail = detail
            self.fileIdentity = UninstallerSupport.fileIdentity(at: url)
            self.recommended = recommended
            self.include = recommended
            self.companion = companion
            self.companionIdentity = companion.flatMap { UninstallerSupport.fileIdentity(at: $0) }
            self.trashEntries = trashEntries
            self.browserKey = browserKey
            self.browserName = browserName
            self.browserTargets = browserTargets
        }

        static func == (lhs: Item, rhs: Item) -> Bool {
            lhs.id == rhs.id && lhs.include == rhs.include
        }
    }

    /// A visible Trash entry as the scan saw it: its name and file identity.
    struct TrashEntry: Equatable {
        let name: String
        let identity: UninstallerSupport.FileIdentity?
    }

    /// An item a clean could not remove, kept with its reason so the result
    /// can say what stayed behind. Each item appears at most once per clean.
    struct FailedItem: Identifiable, Equatable {
        let id = UUID()
        let url: URL
        let category: CleanerSupport.Category
        /// A fixed English reason for the failure. Internal: no view shows it.
        let reason: String
    }

    @Published private(set) var phase: Phase = .idle
    /// Guards the check-and-start of a clean: the `.results` check, the
    /// selection and the move to `.cleaning` happen under one lock.
    private let phaseLock = NSLock()
    @Published var items: [Item] = []
    /// The items the last clean could not remove. Filled when a clean ends;
    /// cleared by a new scan and by reset.
    @Published private(set) var failedItems: [FailedItem] = []
    /// Browser names that were skipped during the last clean because they were running.
    @Published private(set) var skippedBrowsers: [String] = []
    /// The category currently being scanned, for the progress line.
    @Published private(set) var scanningCategory: CleanerSupport.Category?
    /// Published signal indicating browser access permission is pending.
    @Published private(set) var browserAccessPending: Bool = false

    /// Seam for running applications: injectable for testing.
    static var runningBundleIDs: () -> Set<String> = {
        Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
    }

    /// Seam for moving to trash: injectable for testing.
    static var trashRunner: (URL) throws -> Void = { url in
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    /// Test seam: sets skippedBrowsers directly.
    func setSkippedBrowsersForTesting(_ skipped: [String]) {
        self.skippedBrowsers = skipped
    }
    /// Informational rows of "Onde está o espaço", measured only when the user
    /// presses "Calcular". Nil until then. They have no selection and never
    /// enter `items`, so no clean reaches them.
    @Published private(set) var spaceInventory: [SpaceInventoryRow]?
    /// The measured space map of the same surface: the largest folders, the
    /// refusals met, the volume figures and the estimated system data. Filled
    /// folder by folder while the request runs, so the section fills in instead
    /// of waiting for the end. Nil until the first request.
    @Published private(set) var spaceMap: SpaceMap?
    /// True while a requested measurement runs off the main thread.
    @Published private(set) var spaceInventoryIsComputing = false
    /// The pass a measurement belongs to. Every write compares it, so a stale
    /// callback from an older run never lands on a newer one.
    private(set) var spaceInventoryToken = UUID()
    /// The run that last published `spaceMap`. A cancel only marks that map
    /// partial when this equals the run being stopped, so a remesure that has
    /// not published yet cannot relabel a completed ranking.
    private var spaceMapPublishedToken: UUID?
    /// Lets a running measurement see a reset; the token only guards what reaches the main thread.
    private(set) var spaceInventoryCancellation: CleanerSupport.ScanCancellation?

    /// The pass this instance runs, and the gate that keeps the Cleaner's
    /// passes apart. The app shares one gate; tests pass their own.
    private let passHolder: CleanerPassGate.Holder
    private let gate: CleanerPassGate

    init(passHolder: CleanerPassGate.Holder = .manual, gate: CleanerPassGate = .shared) {
        self.passHolder = passHolder
        self.gate = gate
    }

    /// Changes each time a clean starts or is reset, so a clean that finishes
    /// late cannot land on a newer state.
    private(set) var cleanToken = UUID()
    /// Lets a running clean's background loop see an abort.
    private var cleanCancellation: CleanerSupport.ScanCancellation?

    /// Serializes scans so a re-scan started while one runs is ignored.
    private var scanToken = UUID()
    /// Lets the running scan's background loop see a cancel; the token only
    /// guards what reaches the main thread.
    private var scanCancellation: CleanerSupport.ScanCancellation?

    var selectedSize: Int64 { items.filter(\.include).reduce(0) { $0 + $1.size } }
    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
    var selectedCount: Int { items.filter(\.include).count }

    func items(in category: CleanerSupport.Category) -> [Item] {
        items.filter { $0.category == category }
    }

    func setInclude(_ include: Bool, for id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].include = include
    }

    func setInclude(_ include: Bool, forCategory category: CleanerSupport.Category) {
        for index in items.indices where items[index].category == category {
            items[index].include = include
        }
    }

    /// Ends whatever this instance runs: a scan, a measurement or a clean.
    /// Their results are dropped when they arrive, and the pass gives up the
    /// Cleaner gate. A move already under way finishes on its own.
    func reset() {
        scanToken = UUID()
        scanCancellation?.cancel()
        scanCancellation = nil
        cleanToken = UUID()
        cleanCancellation?.cancel()
        cleanCancellation = nil
        items = []
        failedItems = []
        skippedBrowsers = []
        browserAccessPending = false
        clearSpaceInventory()
        clearLargeFiles()
        scanningCategory = nil
        phase = .idle
        gate.release(passHolder)
    }

    /// Test seam: sets the published phase without running a scan.
    func setPhaseForTesting(_ phase: Phase) { self.phase = phase }

    /// Stops a measurement still running and keeps the figures measured so far,
    /// marked as partial. A stale callback of the stopped run is dropped by the
    /// token comparison in `publishSpaceMap`. Nothing is marked when no run is
    /// under way, or when the stopped run has not published yet: a finished map
    /// of a previous run stays the complete result it was.
    func cancelSpaceInventory() {
        let runToken = spaceInventoryToken
        let stoppedARun = spaceInventoryIsComputing
        spaceInventoryToken = UUID()
        spaceInventoryCancellation?.cancel()
        spaceInventoryCancellation = nil
        spaceInventoryIsComputing = false
        if stoppedARun, spaceMapPublishedToken == runToken {
            spaceMap = spaceMap?.markedCancelled()
        }
    }

    /// Drops the measured inventory and cancels a measurement still running.
    private func clearSpaceInventory() {
        cancelSpaceInventory()
        spaceInventory = nil
        spaceMap = nil
        spaceMapPublishedToken = nil
    }

    /// The only writer of `spaceMap`: a snapshot from a run that is no longer
    /// current never publishes. Internal so the test can hand it a snapshot
    /// built for a run that was already stopped.
    func publishSpaceMap(_ snapshot: SpaceMap, token: UUID) {
        guard spaceInventoryToken == token else { return }
        spaceMap = snapshot
        spaceMapPublishedToken = token
    }

    // MARK: - Large and old files

    /// The user's own list of large and old files. Nil until the user asks for
    /// one: nothing searches in the background. It carries no selection and
    /// never enters `items`, so no clean of the categories can reach it, and
    /// every candidate starts unmarked by construction.
    @Published private(set) var largeFiles: LargeFiles.SearchResult?
    /// True while a requested search runs off the main thread: the surface
    /// shows the search in progress instead of an empty list.
    @Published private(set) var largeFilesIsComputing = false
    /// The result group starts collapsed, and a new search collapses it again.
    /// Nothing is ever marked for the user.
    @Published var largeFilesExpanded = false
    /// What the last confirmed removal did to each item: moved, refused or
    /// failed. Nil until one runs.
    @Published private(set) var largeFilesRemoval: [LargeFiles.RemovalReport]?
    /// The search a publication belongs to. Every write compares it, so a stale
    /// callback of a superseded run never lands on a newer one.
    private(set) var largeFilesToken = UUID()
    /// Lets a running search see a cancel; the token only guards what reaches
    /// the main thread.
    private(set) var largeFilesCancellation: CleanerSupport.ScanCancellation?
    /// True from the moment a confirmed batch is handed to the background until
    /// its report is handled on the main queue, whatever its outcome. Not
    /// published: it only gates the two entry points, so a search cannot publish
    /// an item a batch is moving, and a second batch cannot overwrite the first
    /// one's report.
    private var largeFilesRemovalInFlight = false

    /// Searches the home folder for the large and old files of the user, with
    /// the thresholds they saved. Only an explicit request calls this: one run
    /// per call, off the main thread, with no timer and no polling. It refuses
    /// to start while a confirmed batch is moving items, so no snapshot can list
    /// an item that is about to leave. A new search drops the list it replaces.
    func measureLargeFiles(home: String = NSHomeDirectory(),
                           thresholds: LargeFiles.Thresholds? = nil,
                           defaults: UserDefaults = .standard) {
        guard !largeFilesIsComputing, !largeFilesRemovalInFlight else { return }
        let token = UUID()
        largeFilesToken = token
        largeFilesIsComputing = true
        largeFilesExpanded = false
        largeFilesRemoval = nil
        // The rows of the previous search are dropped here: until this run
        // publishes its own snapshot, the surface shows the loading state only.
        largeFiles = nil
        let cancellation = CleanerSupport.ScanCancellation()
        largeFilesCancellation = cancellation
        let chosen = thresholds ?? LargeFiles.Thresholds.persisted(in: defaults)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = LargeFiles.search(home: home, thresholds: chosen,
                                           cancellation: cancellation) { snapshot in
                DispatchQueue.main.async { [weak self] in
                    self?.publishLargeFiles(snapshot, token: token)
                }
            }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.largeFilesToken == token else { return }
                self.largeFiles = result
                self.largeFilesCancellation = nil
                self.largeFilesIsComputing = false
            }
        }
    }

    /// Stops a search still running and keeps what it found so far, marked as
    /// partial. A cancel that found nothing still publishes an empty partial
    /// result, so the surface can say it was cancelled instead of showing
    /// nothing. A stale callback of the stopped run is dropped by the token
    /// comparison in `publishLargeFiles`. Nothing is marked when no run is
    /// under way: a finished list stays the complete result it was.
    func cancelLargeFiles() {
        let stoppedARun = largeFilesIsComputing
        largeFilesToken = UUID()
        largeFilesCancellation?.cancel()
        largeFilesCancellation = nil
        largeFilesIsComputing = false
        if stoppedARun {
            largeFiles = (largeFiles ?? LargeFiles.SearchResult.empty).markedCancelled()
        }
    }

    /// The only writer of `largeFiles`: a snapshot from a run that is no longer
    /// current never publishes. Internal so the test can hand it a snapshot
    /// built for a run that was already stopped.
    func publishLargeFiles(_ snapshot: LargeFiles.SearchResult, token: UUID) {
        guard largeFilesToken == token else { return }
        largeFiles = snapshot
    }

    /// Drops the list and cancels a search still running.
    private func clearLargeFiles() {
        cancelLargeFiles()
        largeFiles = nil
        largeFilesRemoval = nil
        largeFilesExpanded = false
    }

    /// Moves the confirmed selection to the Trash, one item at a time. Only the
    /// ids given here can move, and only a confirmation moves anything: without
    /// it the call does nothing. Each item is revalidated right before its move
    /// by `LargeFiles.trash`, which also refuses a link or a replaced file, and
    /// `trashRunner` is the only way to the Trash. The Cleaner's own selection,
    /// its pass gate and its scheduler are never touched. While a search still
    /// runs nothing moves: its snapshots may still list items already moved, so
    /// the confirmation is dropped and the user confirms again on the finished list.
    /// Only one batch runs at a time: a confirmation while one is in flight is dropped.
    func trashLargeFiles(ids: Set<String>, confirmed: Bool,
                         home: String = NSHomeDirectory(),
                         thresholds: LargeFiles.Thresholds? = nil,
                         defaults: UserDefaults = .standard,
                         trash: @escaping (URL) throws -> Void = JunkCleaner.trashRunner) {
        guard confirmed, !ids.isEmpty, !largeFilesIsComputing, !largeFilesRemovalInFlight,
              let found = largeFiles else { return }
        let chosen = found.candidates.filter { ids.contains($0.id) }
        guard !chosen.isEmpty else { return }
        let plan = thresholds ?? LargeFiles.Thresholds.persisted(in: defaults)
        largeFilesRemovalInFlight = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let reports = LargeFiles.trash(chosen, confirmed: confirmed, home: home,
                                           thresholds: plan, trash: trash)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.largeFilesRemovalInFlight = false
                // The report does not depend on the search token: the move
                // happened on disk, so the user is told even when a scan or a
                // reset cleared the list meanwhile. It never recreates a list.
                self.largeFilesRemoval = reports
                // What moved is gone from the list; what stayed is still there
                // to be read with its failure.
                let moved = Set(reports.filter { !$0.isFailure }.map(\.id))
                if let current = self.largeFiles {
                    self.largeFiles = LargeFiles.SearchResult(
                        candidates: current.candidates.filter { !moved.contains($0.id) },
                        denied: current.denied, cancelled: current.cancelled)
                }
            }
        }
    }

    // MARK: - Scan

    /// `attended: false` is a pass nobody watches: it skips the screenshot
    /// search, which reads the user's own folders and can ask for access.
    func scan(attended: Bool, home: String = NSHomeDirectory()) {
        guard phase != .scanning else { return }
        // A scan is a pass: it starts only when the gate is free or already ours.
        guard gate.acquire(passHolder) else { return }
        let token = UUID()
        scanToken = token
        scanCancellation?.cancel()
        let cancellation = CleanerSupport.ScanCancellation()
        scanCancellation = cancellation
        items = []
        failedItems = []
        skippedBrowsers = []
        browserAccessPending = false
        clearSpaceInventory()
        clearLargeFiles()
        phase = .scanning
        let screenshots = attended ? Self.screenshotSearch() : nil
        let conversationDays = Self.codingConversationSearchDays(attended: attended)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard !cancellation.isCancelled else { return }
            let installed = Self.installedBundleIDs()
            // A path claimed by the leftover scan must not reappear under
            // caches or logs: one path, one row, one decision.
            var claimed = Set<String>()
            // One browser walk per scan: the cache and the site data items
            // are two views of the same measurement.
            var browserResults: [BrowserJunk.BrowserScanResult]?
            let categories: [(CleanerSupport.Category, () -> [Item])] = [
                (.leftovers, {
                    let found = Self.scanLeftovers(installed: installed, home: home)
                    claimed.formUnion(found.map { $0.url.standardizedFileURL.path })
                    return found
                }),
                (.loginItems, { Self.scanOrphanedLaunchPlists(installed: installed) }),
                (.browserCaches, {
                    let results = BrowserJunk.scanItems(home: home)
                    browserResults = results
                    claimed.formUnion(BrowserJunk.claimedCacheRoots(for: results, home: home))
                    if results.contains(where: \.accessPending) {
                        DispatchQueue.main.async { [weak self] in
                            guard let self, self.scanToken == token else { return }
                            self.browserAccessPending = true
                        }
                    }
                    return results.filter { !$0.accessPending }.map { res in
                        Item(
                            url: res.rootURL,
                            category: .browserCaches,
                            size: res.cacheSize,
                            detail: res.rootURL.path,
                            recommended: CleanerPolicy.precheckBrowserCaches,
                            browserKey: res.id,
                            browserName: res.displayName,
                            browserTargets: res.cacheTargets
                        )
                    }
                }),
                (.browserSiteData, {
                    let results = browserResults ?? BrowserJunk.scanItems(home: home)
                    return results.filter { !$0.accessPending }.map { res in
                        Item(
                            url: res.rootURL,
                            category: .browserSiteData,
                            size: res.siteDataSize,
                            detail: res.rootURL.path,
                            recommended: CleanerPolicy.precheckBrowserSiteData,
                            browserKey: res.id,
                            browserName: res.displayName,
                            browserTargets: res.siteDataTargets
                        )
                    }
                }),
                (.caches, { Self.scanCaches(excluding: claimed, home: home) }),
                (.logs, { Self.scanLogs(excluding: claimed) }),
                (.developer, { Self.scanDeveloperJunk() }),
                (.trash, { Self.scanTrash() }),
                (.deviceBackups, { Self.scanDeviceBackups() }),
                (.packageCaches, { Self.scanPackageCaches(home: home) }),
            ] + (screenshots.map { search in
                [(.screenshots, { Self.scanScreenshots(in: search.folders, days: search.days) })]
            } ?? []) + (conversationDays > 0 ? [(.codingConversations, { Self.scanCodingConversations(olderThanDays: conversationDays, home: home) })] : [])
            for (category, run) in categories {
                guard !cancellation.isCancelled else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.scanToken == token else { return }
                    self.scanningCategory = category
                }
                let found = run()
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.scanToken == token else { return }
                    self.items.append(contentsOf: found)
                }
            }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.scanToken == token else { return }
                self.scanCancellation = nil
                self.scanningCategory = nil
                self.phase = .results
            }
        }
    }

    // MARK: - Space inventory

    /// Measures the "Onde está o espaço" surface: the space map, published
    /// folder by folder while it runs, and the fixed block of known locations.
    /// Only an explicit user request calls this: one run per call, off the main
    /// thread, with no timer and no polling. The current cleanable items keep
    /// their overlap rule, so no byte is counted twice.
    func measureSpaceInventory(home: String = NSHomeDirectory(),
                               applications: String = "/Applications") {
        guard !spaceInventoryIsComputing else { return }
        let token = UUID()
        spaceInventoryToken = token
        spaceInventoryIsComputing = true
        let cancellation = CleanerSupport.ScanCancellation()
        spaceInventoryCancellation = cancellation
        let claimedItems = items
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let map = SpaceInventory.map(home: home, applications: applications,
                                         cancellation: cancellation) { snapshot in
                DispatchQueue.main.async { [weak self] in
                    self?.publishSpaceMap(snapshot, token: token)
                }
            }
            DispatchQueue.main.async { [weak self] in
                self?.publishSpaceMap(map, token: token)
            }
            let rows = SpaceInventory.rows(home: home, excluding: claimedItems,
                                           cancellation: cancellation)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.spaceInventoryToken == token else { return }
                self.spaceInventory = rows
                self.spaceInventoryIsComputing = false
            }
        }
    }

    // MARK: - Clean

    /// `escalate: false` leaves whatever the Trash move refused in place
    /// instead of handing it to Finder, which is an administrator password
    /// prompt. No default: each caller says whether someone is there to answer.
    func cleanSelected(escalate: Bool) {
        // Only a reviewed result starts a pass. A call while one is in flight
        // (phase .cleaning) or from any other phase changes nothing. The check,
        // the selection and the transition run in one critical section, so
        // overlapping calls cannot both start a pass. The pass itself runs
        // below, after the lock is released.
        let started: (chosen: [Item], token: UUID, cancellation: CleanerSupport.ScanCancellation)? = phaseLock.withLock {
            guard phase == .results else { return nil }
            let selected = items.filter(\.include)
            guard !selected.isEmpty else { return nil }
            // The gate is taken in the same critical section as the move to
            // .cleaning, so a pass the other kind holds does not start.
            guard gate.acquire(passHolder) else { return nil }
            let token = UUID()
            let cancellation = CleanerSupport.ScanCancellation()
            cleanToken = token
            cleanCancellation = cancellation
            phase = .cleaning
            return (selected, token, cancellation)
        }
        guard let started else { return }
        let chosen = started.chosen
        let token = started.token
        let cancellation = started.cancellation

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fm = FileManager.default
            // One installed-apps oracle for the whole pass, and only when the
            // selection can ask for it: building it walks the application
            // folders, and `mayRemove` reads it under `.leftovers` alone, so a
            // clean without leftover rows must not pay for the walk. Nothing
            // can install an app mid-clean that this pass would have to
            // respect. `stubborn` is a subset of `chosen`, so the second and
            // third passes are covered by the same test.
            let installed = chosen.contains { $0.category == .leftovers }
                ? Self.installedBundleIDs() : []
            var outcomes: [CleanerSupport.RemovalOutcome] = []
            // Each stubborn item keeps the reason it failed its first move,
            // so the reason survives into `failedItems` if it stays behind.
            var stubborn: [(item: Item, reason: String)] = []
            var failures: [FailedItem] = []

            let running = Self.runningBundleIDs()
            var skippedBrowserNames: [String] = []
            var skippedBrowserKeys: Set<String> = []

            for item in chosen where item.category == .browserCaches || item.category == .browserSiteData {
                guard let key = item.browserKey, !skippedBrowserKeys.contains(key) else { continue }
                if let def = BrowserJunk.definitions.first(where: { $0.id == key }) {
                    let isRunning = def.bundleIDs.contains { running.contains($0) }
                    if isRunning {
                        skippedBrowserKeys.insert(key)
                        let name = item.browserName ?? def.displayName
                        if !skippedBrowserNames.contains(name) {
                            skippedBrowserNames.append(name)
                        }
                    }
                }
            }

            let activeChosen = chosen.filter { item in
                if (item.category == .browserCaches || item.category == .browserSiteData),
                   let key = item.browserKey,
                   skippedBrowserKeys.contains(key) {
                    return false
                }
                return true
            }

            // Emptying the Trash MUST come first: the row means the Trash as
            // it was scanned. Running it after the moves would silently wipe
            // the very items this clean just made recoverable, which reads
            // as "nothing ever went to the Trash".
            if let trashRow = activeChosen.first(where: { $0.category == .trash }) {
                let trashOutcomes = Self.emptyTrash(scanned: trashRow.trashEntries,
                                                    isCancelled: { cancellation.isCancelled })
                outcomes += trashOutcomes
                // The Trash row has no item of its own, so its failures are
                // recorded against the row once.
                if trashOutcomes.contains(.failed) {
                    failures.append(FailedItem(url: trashRow.url, category: .trash,
                                               reason: "some Trash entries could not be removed"))
                }
            }

            for item in activeChosen where item.category != .trash {
                // An abort stops before the next item.
                guard !cancellation.isCancelled else { return }
                if item.category == .browserCaches || item.category == .browserSiteData {
                    guard Self.mayRemove(item, installed: installed) else {
                        outcomes.append(.failed)
                        failures.append(FailedItem(url: item.url, category: item.category,
                                                   reason: "refused by the safety guard"))
                        continue
                    }
                    let browserOutcomes = Self.trashBrowserTargets(item, trash: Self.trashRunner)
                    outcomes += browserOutcomes
                    if browserOutcomes.contains(.failed) {
                        failures.append(FailedItem(url: item.url, category: item.category,
                                                   reason: "not fully moved to the Trash"))
                    }
                    continue
                }
                if item.category == .codingConversations {
                    // A refusal by the safety guard is reported as a refusal;
                    // only a move that started and failed is "not fully moved".
                    guard Self.mayRemove(item, installed: installed) else {
                        outcomes.append(.failed)
                        failures.append(FailedItem(url: item.url, category: item.category,
                                                   reason: "refused by the safety guard"))
                        continue
                    }
                    let conversation = Self.trashConversation(item)
                    outcomes += conversation
                    if conversation.contains(.failed) {
                        failures.append(FailedItem(url: item.url, category: item.category,
                                                   reason: "not fully moved to the Trash"))
                    }
                    continue
                }
                guard Self.mayRemove(item, installed: installed) else {
                    outcomes.append(.failed)
                    failures.append(FailedItem(url: item.url, category: item.category,
                                               reason: "refused by the safety guard"))
                    continue
                }
                if item.category == .loginItems {
                    // Retire the job first so nothing keeps running from a
                    // plist that is about to leave; then the regular move.
                    Self.bootoutUserAgent(item.url)
                    guard Self.mayRemove(item, installed: installed) else {
                        outcomes.append(.failed)
                        failures.append(FailedItem(url: item.url, category: item.category,
                                                   reason: "refused by the safety guard"))
                        continue
                    }
                }
                do {
                    try fm.trashItem(at: item.url, resultingItemURL: nil)
                    outcomes.append(.movedToTrash(size: item.size))
                } catch {
                    stubborn.append((item, "could not be moved to the Trash: \(error.localizedDescription)"))
                }
            }

            // Root owned files (system LaunchDaemons and friends) go through
            // Finder, which shows the standard administrator prompt and moves
            // them to the Trash exactly like a drag would. One batch, one
            // prompt; a cancel leaves them in place and they count as failed.
            if !escalate {
                // Unattended pass: nobody can answer the prompt, so they
                // stay put and count as failed.
                outcomes += Array(repeating: CleanerSupport.RemovalOutcome.failed, count: stubborn.count)
                failures += stubborn.map {
                    FailedItem(url: $0.item.url, category: $0.item.category, reason: $0.reason)
                }
            } else if !stubborn.isEmpty {
                // An aborted pass never starts the administrator step.
                guard !cancellation.isCancelled else { return }
                let stillSafe = stubborn.filter { Self.mayRemove($0.item, installed: installed) }
                let refused = stubborn.filter { entry in
                    !stillSafe.contains(where: { $0.item.id == entry.item.id })
                }
                outcomes += Array(repeating: CleanerSupport.RemovalOutcome.failed, count: refused.count)
                failures += refused.map {
                    FailedItem(url: $0.item.url, category: $0.item.category, reason: "refused by the safety guard")
                }
                Self.trashViaFinder(stillSafe.map(\.item.url))
                for entry in stillSafe {
                    if UninstallerSupport.isConfirmedAbsent(at: entry.item.url) {
                        outcomes.append(.movedToTrash(size: entry.item.size))
                    } else {
                        outcomes.append(.failed)
                        failures.append(FailedItem(url: entry.item.url, category: entry.item.category,
                                                   reason: "not removed by Finder"))
                    }
                }
            }

            let totals = CleanerSupport.removalTotals(outcomes)
            let unremoved = failures
            DispatchQueue.main.async { [weak self] in
                // The token decides, not the phase: a clean that an abort ended
                // must not land on a newer clean of this same instance.
                guard let self, self.cleanToken == token, self.phase == .cleaning else { return }
                self.skippedBrowsers = skippedBrowserNames
                self.cleanCancellation = nil
                self.failedItems = unremoved
                self.items = []
                self.gate.release(self.passHolder)
                self.phase = .done(movedToTrash: totals.movedToTrash,
                                   freedPermanently: totals.freedPermanently,
                                   failed: totals.failed)
            }
        }
    }

    /// Exact match guard against ever removing a critical root, even if a
    /// scanner bug produced one. Items are already scoped by construction;
    /// this is the last line of defense.
    static func mayRemove(_ item: Item, installed: Set<String> = []) -> Bool {
        let url = item.url
        let path = url.standardizedFileURL.path
        let home = NSHomeDirectory()
        let critical: Set<String> = [
            "/", "/Applications", "/Library", "/System", "/Users", "/usr",
            "/bin", "/sbin", "/etc", "/var", "/private", "/opt",
            home, home + "/Library", home + "/Documents", home + "/Desktop",
            home + "/Downloads", home + "/Pictures", home + "/Music", home + "/Movies",
        ]
        guard !critical.contains(path),
              !url.lastPathComponent.lowercased().hasSuffix(".localized"),
              let expectedIdentity = item.fileIdentity,
              UninstallerSupport.fileIdentity(at: url) == expectedIdentity,
              !UninstallerSupport.isSymbolicLink(url),
              url.resolvingSymlinksInPath().standardizedFileURL.path == path else { return false }

        switch item.category {
        case .leftovers:
            guard isDirectLeftoverRootChild(url),
                  CleanerSupport.bundleIDCandidate(fromEntryName: item.detail) != nil,
                  !CleanerSupport.isProtectedBundleID(item.detail),
                  !hasLivingOwner(item.detail, installed: installed) else { return false }

        case .caches:
            let cachesRoot = URL(fileURLWithPath: home + "/Library/Caches", isDirectory: true)
            let isDirect = CleanerSupport.isDirectChild(url, of: cachesRoot)
            // A vendor folder holding a claimed browser root is offered as its
            // children; only a direct child of a registered vendor is allowed
            // one level below Caches.
            let isVendorChild = BrowserJunk.vendorCacheRoots(home: home).contains { vendorPath in
                CleanerSupport.isDirectChild(url, of: URL(fileURLWithPath: vendorPath, isDirectory: true))
            }
            guard (isDirect || isVendorChild),
                  !CleanerPolicy.isExcludedCacheEntry(url.lastPathComponent) else { return false }

        case .logs:
            let logsRoot = URL(fileURLWithPath: home + "/Library/Logs", isDirectory: true)
            let isDirectLogChild = CleanerSupport.isDirectChild(url, of: logsRoot)
            let isDiagnosticReports = path == (home + "/Library/Logs/DiagnosticReports")
            guard (isDirectLogChild || isDiagnosticReports),
                  !CleanerPolicy.isExcludedCacheEntry(url.lastPathComponent) else { return false }

        case .developer:
            let allowedDevPaths = Set(CleanerPolicy.developerJunkPaths.map { home + $0 })
            guard allowedDevPaths.contains(path) else { return false }

        case .deviceBackups:
            let backupRoot = URL(fileURLWithPath: home + "/Library/Application Support/MobileSync/Backup", isDirectory: true)
            guard CleanerSupport.isDirectChild(url, of: backupRoot) else { return false }

        case .loginItems:
            let allowedRoots = [home + "/Library/LaunchAgents", "/Library/LaunchAgents", "/Library/LaunchDaemons"]
            let isUnderAllowedRoot = allowedRoots.contains { root in
                CleanerSupport.isDirectChild(url, of: URL(fileURLWithPath: root, isDirectory: true))
            }
            guard isUnderAllowedRoot, url.pathExtension.lowercased() == "plist" else { return false }

        case .packageCaches:
            guard CleanerPolicy.isPackageCacheRemovalAllowed(url, home: home) else { return false }

        case .codingConversations:
            guard CleanerPolicy.isCodingConversationRemovalAllowed(
                url, companion: item.companion, projectsRoot: home + "/.claude/projects",
                transcriptIdentity: item.fileIdentity, companionIdentity: item.companionIdentity)
            else { return false }

        case .screenshots:
            guard isScreenshotFolderChild(url),
                  CleanerSupport.isValidScreenshotExtension(url.pathExtension),
                  isScreenCapture(url) else { return false }

        case .browserCaches, .browserSiteData:
            guard let key = item.browserKey,
                  let def = BrowserJunk.definitions.first(where: { $0.id == key }),
                  !item.browserTargets.isEmpty else { return false }

            var effectiveHome = home
            for subpath in def.profileRootSubpaths {
                if let range = path.range(of: "/" + subpath) {
                    effectiveHome = String(path[..<range.lowerBound])
                    break
                }
            }
            let homeURL = URL(fileURLWithPath: effectiveHome)

            for target in item.browserTargets {
                let targetURL = target.url
                let targetPath = targetURL.standardizedFileURL.path
                guard !critical.contains(targetPath),
                      targetURL != url,
                      !path.hasPrefix(targetPath + "/"),
                      BrowserJunk.isSubpathAllowed(targetURL, for: def, under: homeURL),
                      !UninstallerSupport.isSymbolicLink(targetURL),
                      targetURL.resolvingSymlinksInPath().standardizedFileURL.path == targetPath,
                      let expectedID = target.identity,
                      UninstallerSupport.fileIdentity(at: targetURL) == expectedID else {
                    return false
                }
            }
            return true

        case .trash:
            // Emptying Trash is only executed via emptyTrash(); individual trashing is forbidden.
            return false
        }

        // Depth guard: anything this shallow is a root of some kind, never junk.
        return url.pathComponents.count >= 4
    }

    /// Moves each validated browser target to the Trash using the provided closure.
    static func trashBrowserTargets(_ item: Item,
                                    trash: (URL) throws -> Void = JunkCleaner.trashRunner) -> [CleanerSupport.RemovalOutcome] {
        guard mayRemove(item, installed: []) else { return [.failed] }
        let fm = FileManager.default
        var outcomes: [CleanerSupport.RemovalOutcome] = []

        for target in item.browserTargets {
            let targetURL = target.url
            guard fm.fileExists(atPath: targetURL.path) else {
                continue
            }
            let size = directorySize(of: targetURL, fm: fm)
            do {
                try trash(targetURL)
                outcomes.append(.movedToTrash(size: size))
            } catch {
                outcomes.append(.failed)
            }
        }
        return outcomes
    }

    /// A conversation leaves as a pair: its folder first, then its transcript.
    /// Each part is counted at the size it had when it moved, so a pair that
    /// only half moved reports exactly that half. Nothing is deleted in place.
    private static func trashConversation(_ item: Item) -> [CleanerSupport.RemovalOutcome] {
        guard mayRemove(item, installed: []) else { return [.failed] }
        let fm = FileManager.default
        var outcomes: [CleanerSupport.RemovalOutcome] = []
        var trashedFolder: (original: URL, inTrash: URL)?
        if let folder = item.companion {
            let folderSize = directorySize(of: folder, fm: fm)
            var resulting: NSURL?
            do {
                try fm.trashItem(at: folder, resultingItemURL: &resulting)
            } catch {
                return [.failed]
            }
            outcomes.append(.movedToTrash(size: folderSize))
            if let inTrash = resulting as URL? {
                trashedFolder = (folder, inTrash)
            }
        }
        let transcriptSize = fileSize(item.url)
        do {
            try fm.trashItem(at: item.url, resultingItemURL: nil)
            outcomes.append(.movedToTrash(size: transcriptSize))
        } catch {
            // The pair moves together (DEC-020): a transcript that stays puts its
            // folder back, so the conversation is whole on disk, not half in the
            // Trash. Only a folder that cannot come back is reported as moved.
            if let trashedFolder,
               (try? fm.moveItem(at: trashedFolder.inTrash, to: trashedFolder.original)) != nil {
                return [.failed]
            }
            outcomes.append(.failed)
        }
        return outcomes
    }

    private static func trashViaFinder(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        guard AppleScriptRunner.consentToAutomate(bundleID: "com.apple.finder") else { return }
        let targets = urls
            .map { "set end of targets to POSIX file \(AppleScriptRunner.literal($0.path))" }
            .joined(separator: "\n")
        let source = """
        set targets to {}
        \(targets)
        tell application "Finder" to delete targets
        """
        // The administrator prompt can wait for the user, so the limit is 120 seconds.
        // An expired call leaves the result unknown, which is why callers verify with isConfirmedAbsent.
        _ = AppleScriptRunner.run(source, timeout: 120)
    }

    /// Emptying the Trash is the one permanent action here, clearly labeled
    /// in the interface. It removes only the entries of the Trash folder that
    /// the scan counted and that still carry the identity the scan saw,
    /// through FileManager; whatever arrived later stays. The system-wide
    /// command is not used, because it covers the Trash of every mounted
    /// volume, not only this folder. `isCancelled` is read before each entry,
    /// so an abort stops the removal early.
    static func emptyTrash(
        at trash: URL = URL(fileURLWithPath: NSHomeDirectory() + "/.Trash", isDirectory: true),
        scanned: [TrashEntry],
        isCancelled: () -> Bool = { false }
    ) -> [CleanerSupport.RemovalOutcome] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: trash.path) else { return [] }
        // A symbolic link standing in for the Trash is never followed.
        guard !UninstallerSupport.isSymbolicLink(trash) else { return [.failed] }
        var outcomes: [CleanerSupport.RemovalOutcome] = []
        for scannedEntry in scanned {
            guard !isCancelled() else { break }
            let entry = trash.appendingPathComponent(scannedEntry.name)
            // Gone since the scan, or replaced by a newer entry of the same
            // name: not what the user reviewed, so it is left alone.
            guard let identity = scannedEntry.identity,
                  UninstallerSupport.fileIdentity(at: entry) == identity else { continue }
            // Measured before removal, so only bytes that are actually gone count.
            let size = directorySize(of: entry, fm: fm)
            do {
                try fm.removeItem(at: entry)
                outcomes.append(.removedPermanently(size: size))
            } catch {
                outcomes.append(.failed)
            }
        }
        return outcomes
    }

    /// Unloads a user launch agent before its plist is trashed, so the job
    /// does not keep running until logout. Best effort: a plist that was
    /// never loaded simply makes launchctl exit nonzero, which is fine.
    /// Only the GUI domain of the current user is addressed, never `system/`.
    /// LaunchDaemons plists need root and never reach launchctl from here.
    static func bootoutUserAgent(
        _ plistURL: URL,
        home: String = NSHomeDirectory(),
        agentRoots: [String]? = nil,
        uid: uid_t = getuid()
    ) {
        let roots = agentRoots ?? launchAgentRoots(home: home)
        guard let plist = NSDictionary(contentsOf: plistURL) as? [String: Any],
              let arguments = bootoutArguments(plistPath: plistURL.path,
                                               label: plist["Label"] as? String,
                                               uid: uid, agentRoots: roots) else { return }
        // A plist that was never loaded makes launchctl complain; that is
        // expected and not worth a line in anyone's console, and the bounded
        // executor keeps a wedged launchctl from holding the thread forever.
        launchctlRunner(arguments)
    }

    /// The folders whose launch agent plists may be retired: the user's own
    /// and the machine-wide one. Both are reached through the GUI domain of
    /// the current user, which needs no root.
    static func launchAgentRoots(home: String = NSHomeDirectory()) -> [String] {
        [home + "/Library/LaunchAgents/", "/Library/LaunchAgents/"]
    }

    /// The launchctl arguments that retire a plist's job, or nil when the
    /// plist is not a direct child of one of `agentRoots` or its label is not
    /// a safe single component. Pure: it reads nothing and runs nothing.
    static func bootoutArguments(
        plistPath: String,
        label: String?,
        uid: uid_t,
        agentRoots: [String]
    ) -> [String]? {
        let isDirectChild = agentRoots.contains { root in
            guard root.hasSuffix("/"), plistPath.hasPrefix(root) else { return false }
            let name = plistPath.dropFirst(root.count)
            return !name.isEmpty && !name.contains("/")
        }
        guard isDirectChild, let label, !label.isEmpty,
              !label.contains("/"), !label.contains("..") else { return nil }
        return ["bootout", "gui/\(uid)/\(label)"]
    }

    /// Runs one launchctl call. Production uses the bounded executor; tests
    /// swap in a recorder so that no real launchctl is ever reached.
    static var launchctlRunner: ([String]) -> Void = { arguments in
        _ = Shell.run("/bin/launchctl", arguments, timeout: 5)
    }

    // MARK: - Installed apps oracle

    /// Every bundle identifier that must be treated as
    /// alive: apps found in the application folders (three levels deep,
    /// covering subfolders and suites), everything currently running, and
    /// login item helpers nested inside those apps.
    private static func installedBundleIDs() -> Set<String> {
        var ids = Set<String>()
        let fm = FileManager.default
        let roots = ["/Applications", "/System/Applications",
                     NSHomeDirectory() + "/Applications"]

        func remember(app url: URL) {
            if let id = Bundle(url: url)?.bundleIdentifier {
                ids.insert(id.lowercased())
            }
        }

        func collect(at url: URL, depth: Int) {
            guard depth > 0 else { return }
            let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey]
            guard let entries = try? fm.contentsOfDirectory(at: url,
                                                            includingPropertiesForKeys: Array(keys),
                                                            options: [.skipsHiddenFiles]) else { return }
            for entry in entries {
                let values = try? entry.resourceValues(forKeys: keys)
                guard values?.isSymbolicLink != true, values?.isDirectory == true else { continue }
                if entry.pathExtension.caseInsensitiveCompare("app") == .orderedSame {
                    remember(app: entry)
                    collect(at: entry.appendingPathComponent("Contents/Library/LoginItems"), depth: 1)
                } else {
                    collect(at: entry, depth: depth - 1)
                }
            }
        }

        for root in roots {
            collect(at: URL(fileURLWithPath: root), depth: 3)
        }
        for app in NSWorkspace.shared.runningApplications {
            if let id = app.bundleIdentifier { ids.insert(id.lowercased()) }
            if let url = app.bundleURL { remember(app: url) }
        }
        return ids
    }

    /// The final say on whether a candidate identifier has a living owner:
    /// the collected set (family match), the vendor namespace rule (suites
    /// and updaters share a namespace with sibling identifiers), and Launch
    /// Services, which knows apps registered anywhere on disk.
    private static func hasLivingOwner(
        _ candidate: String,
        installed: Set<String>,
        isRegistered: (String) -> Bool = { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }
    ) -> Bool {
        if CleanerSupport.isOwned(candidate: candidate, byInstalled: installed) { return true }
        if CleanerSupport.sharesVendorNamespace(candidate: candidate, withInstalled: installed) { return true }
        return isRegistered(candidate)
    }

    // MARK: - Category scanners

    /// Library locations where uninstalled apps leave data behind. Only direct
    /// children are eligible. Group containers qualify when removing the
    /// wrapper leaves a bundle identifier. Mobile Documents is not in this
    /// list: only the user library is scanned, and only its direct children.
    /// A selected app's Uninstaller can prove deeper ownership; the general
    /// Cleaner cannot safely infer it.
    private static let leftoverRoots: [(path: String, usesContainerMetadata: Bool)] = [
        ("Application Support", false),
        ("Caches", false),
        ("Preferences", false),
        ("Preferences/ByHost", false),
        ("Saved Application State", false),
        ("HTTPStorages", false),
        ("WebKit", false),
        ("Logs", false),
        ("Containers", true),
        ("Group Containers", true),
        ("Cookies", false),
        ("PreferencePanes", false),
        ("Internet Plug-Ins", false),
        ("Services", false),
        ("QuickLook", false),
        ("Spotlight", false),
        ("Input Methods", false),
        ("Screen Savers", false),
        ("ColorPickers", false),
        ("Widgets", false),
        ("Address Book Plug-Ins", false),
        ("Contextual Menu Items", false),
        ("Safari/Extensions", false),
        ("Automator", false),
        ("CoreImage", false),
        ("Dictionaries", false),
        ("Components", false),
        ("Audio/Plug-Ins", false),
    ]

    private static func isDirectLeftoverRootChild(_ url: URL) -> Bool {
        let home = NSHomeDirectory()
        let underKnownRoot = [home + "/Library", "/Library"].contains { library in
            leftoverRoots.contains { root in
                CleanerSupport.isDirectChild(
                    url,
                    of: URL(fileURLWithPath: library + "/" + root.path, isDirectory: true)
                )
            }
        }
        if underKnownRoot { return true }
        return CleanerSupport.isDirectChild(
            url,
            of: URL(fileURLWithPath: home + "/Library/Mobile Documents", isDirectory: true)
        )
    }

    /// Direct children of the known Library roots, plus direct children of
    /// `~/Library/Mobile Documents`. Nothing below a child is a candidate.
    /// `includeSystemLibrary` and `isRegistered` exist so a test can point at
    /// a scratch home without reading this Mac's registrations.
    static func scanLeftovers(
        installed: Set<String>,
        home: String = NSHomeDirectory(),
        includeSystemLibrary: Bool = true,
        isRegistered: (String) -> Bool = { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }
    ) -> [Item] {
        let fm = FileManager.default
        var libraries = [home + "/Library"]
        if includeSystemLibrary {
            libraries.append("/Library")
        }
        var found: [Item] = []
        for library in libraries {
            for root in leftoverRoots {
                let dir = library + "/" + root.path
                appendLeftovers(in: dir,
                                usesContainerMetadata: root.usesContainerMetadata,
                                installed: installed,
                                isRegistered: isRegistered,
                                fm: fm,
                                into: &found)
            }
        }
        appendLeftovers(in: home + "/Library/Mobile Documents",
                        usesContainerMetadata: false,
                        installed: installed,
                        isRegistered: isRegistered,
                        fm: fm,
                        into: &found,
                        ownerFrom: { entry, _ in
                            CleanerSupport.iCloudContainerOwner(fromEntryName: entry)
                        })
        return sorted(found)
    }

    private static func appendLeftovers(in dir: String,
                                        usesContainerMetadata: Bool,
                                        installed: Set<String>,
                                        isRegistered: (String) -> Bool,
                                        fm: FileManager,
                                        into found: inout [Item],
                                        ownerFrom: ((String, URL) -> String?)? = nil) {
        let root = URL(fileURLWithPath: dir, isDirectory: true)
        let keys: Set<URLResourceKey> = [.isSymbolicLinkKey]
        guard let entries = try? fm.contentsOfDirectory(at: root,
                                                        includingPropertiesForKeys: Array(keys),
                                                        options: []) else { return }
        for url in entries {
            let entry = url.lastPathComponent
            guard !entry.hasPrefix(".") else { continue }
            let values = try? url.resourceValues(forKeys: keys)
            guard values?.isSymbolicLink != true else { continue }
            // A custom reader that declines a name must not fall through to the
            // Library parser. Mobile Documents only accepts its own name forms.
            let owner: String?
            if let ownerFrom {
                owner = ownerFrom(entry, url)
            } else {
                owner = leftoverOwner(entry: entry, url: url,
                                      usesContainerMetadata: usesContainerMetadata)
            }
            if let owner {
                if CleanerSupport.isProtectedBundleID(owner)
                    || hasLivingOwner(owner, installed: installed, isRegistered: isRegistered) {
                    continue
                }
                found.append(Item(url: url, category: .leftovers,
                                  size: directorySize(of: url, fm: fm),
                                  detail: owner,
                                  recommended: CleanerPolicy.precheckLeftovers))
            }
        }
    }

    private static func leftoverOwner(entry: String,
                                      url: URL,
                                      usesContainerMetadata: Bool) -> String? {
        // Finder uses this suffix for display names, not application ownership.
        guard !entry.lowercased().hasSuffix(".localized") else { return nil }
        if usesContainerMetadata, let owner = containerOwner(at: url) {
            return owner
        }
        return CleanerSupport.leftoverOwnerIdentifier(fromEntryName: entry)
    }

    /// The owning bundle identifier of a container folder, from the metadata
    /// the container manager writes inside it. A shared-container wrapper in
    /// that identifier is removed; what remains still has to be a bundle
    /// identifier.
    private static func containerOwner(at url: URL) -> String? {
        let metadata = url.appendingPathComponent(".com.apple.containermanagerd.metadata.plist")
        guard let dict = NSDictionary(contentsOf: metadata),
              let owner = dict["MCMMetadataIdentifier"] as? String else { return nil }
        return CleanerSupport.leftoverOwnerIdentifier(fromEntryName: owner)
    }

    /// Launch agents and daemons whose every referenced executable is gone
    /// and whose label has no living owner: the classic ghost that keeps a
    /// deleted app listed under Login Items and Extensions.
    private static func scanOrphanedLaunchPlists(installed: Set<String>) -> [Item] {
        let fm = FileManager.default
        let roots = [NSHomeDirectory() + "/Library/LaunchAgents",
                     "/Library/LaunchAgents",
                     "/Library/LaunchDaemons"]
        var found: [Item] = []
        for root in roots {
            guard let entries = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for entry in entries where entry.hasSuffix(".plist") {
                let url = URL(fileURLWithPath: root).appendingPathComponent(entry)
                guard !UninstallerSupport.isSymbolicLink(url) else { continue }
                guard let plist = NSDictionary(contentsOfFile: url.path) as? [String: Any] else { continue }
                let label = plist["Label"] as? String
                let executables = CleanerSupport.executablePaths(inLaunchPlist: plist)
                guard CleanerSupport.launchPlistIsRemovableOrphan(
                    label: label,
                    executables: executables,
                    // A missing binary on an external volume is inconclusive
                    // (the volume may just be unmounted), so it counts as
                    // present and the plist is left alone.
                    executableExists: { $0.hasPrefix("/Volumes/") || fm.fileExists(atPath: $0) }) else { continue }
                // Second signal: the label itself must not belong to anything
                // installed either (a moved binary is not an uninstalled app).
                if let label, hasLivingOwner(label, installed: installed) { continue }
                found.append(Item(url: url, category: .loginItems,
                                  size: directorySize(of: url, fm: fm),
                                  detail: label ?? entry,
                                  recommended: CleanerPolicy.precheckLoginItems))
            }
        }
        return sorted(found)
    }

    private static func scanCaches(excluding claimed: Set<String>, home: String = NSHomeDirectory()) -> [Item] {
        let fm = FileManager.default
        let dir = home + "/Library/Caches"
        guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { return [] }
        var found: [Item] = []
        for entry in entries where !entry.hasPrefix(".") {
            guard !CleanerPolicy.isExcludedCacheEntry(entry) else { continue }
            let url = URL(fileURLWithPath: dir).appendingPathComponent(entry)
            let path = url.standardizedFileURL.path
            guard !claimed.contains(path) else { continue }
            // A vendor folder that holds a claimed browser root cannot stay as
            // one row: its size would count the browser cache twice and moving
            // it would move that cache again. The unclaimed children keep
            // their own rows, so no other path leaves the list.
            if claimed.contains(where: { $0.hasPrefix(path + "/") }) {
                guard let children = try? fm.contentsOfDirectory(atPath: url.path) else { continue }
                for child in children where !child.hasPrefix(".") {
                    let childURL = url.appendingPathComponent(child)
                    let childPath = childURL.standardizedFileURL.path
                    guard !claimed.contains(childPath),
                          !claimed.contains(where: { $0.hasPrefix(childPath + "/") }),
                          !CleanerPolicy.isExcludedCacheEntry(child) else { continue }
                    let size = directorySize(of: childURL, fm: fm)
                    guard size > 0 else { continue }
                    found.append(Item(url: childURL, category: .caches, size: size,
                                      detail: child,
                                      recommended: CleanerPolicy.precheckCacheEntry(child)))
                }
                continue
            }
            let size = directorySize(of: url, fm: fm)
            guard size > 0 else { continue }
            found.append(Item(url: url, category: .caches, size: size,
                              detail: entry,
                              recommended: CleanerPolicy.precheckCacheEntry(entry)))
        }
        return sorted(found)
    }

    private static func scanLogs(excluding claimed: Set<String>) -> [Item] {
        let fm = FileManager.default
        var found: [Item] = []
        let logsDir = NSHomeDirectory() + "/Library/Logs"
        if let entries = try? fm.contentsOfDirectory(atPath: logsDir) {
            for entry in entries where entry != "DiagnosticReports"
                && !entry.hasPrefix(".")
                && !CleanerPolicy.isExcludedCacheEntry(entry) {
                let url = URL(fileURLWithPath: logsDir).appendingPathComponent(entry)
                guard !claimed.contains(url.standardizedFileURL.path) else { continue }
                let size = directorySize(of: url, fm: fm)
                guard size > 0 else { continue }
                found.append(Item(url: url, category: .logs, size: size,
                                  detail: entry, recommended: CleanerPolicy.precheckLogs))
            }
        }
        let reports = logsDir + "/DiagnosticReports"
        let reportsURL = URL(fileURLWithPath: reports)
        let reportsSize = directorySize(of: reportsURL, fm: fm)
        if reportsSize > 0 {
            found.append(Item(url: reportsURL, category: .logs, size: reportsSize,
                              detail: "DiagnosticReports", recommended: CleanerPolicy.precheckLogs))
        }
        return sorted(found)
    }

    private static func scanDeveloperJunk() -> [Item] {
        let fm = FileManager.default
        var found: [Item] = []
        for path in CleanerPolicy.developerJunkPaths {
            let url = URL(fileURLWithPath: NSHomeDirectory() + path)
            guard fm.fileExists(atPath: url.path) else { continue }
            let size = directorySize(of: url, fm: fm)
            guard size > 0 else { continue }
            found.append(Item(url: url, category: .developer, size: size,
                              detail: url.lastPathComponent,
                              recommended: CleanerPolicy.precheckDeveloper))
        }
        return sorted(found)
    }

    /// Old iPhone and iPad backups under MobileSync: with caches, the other
    /// classic tenant of the storage macOS files under "Other". They are the
    /// user's safety net, so every find starts unchecked and names the
    /// device and the backup date. Without Full Disk Access the folder is
    /// unreadable and nothing is offered.
    private static func scanDeviceBackups() -> [Item] {
        let fm = FileManager.default
        let root = NSHomeDirectory() + "/Library/Application Support/MobileSync/Backup"
        guard let entries = try? fm.contentsOfDirectory(atPath: root) else { return [] }
        var found: [Item] = []
        for entry in entries where !entry.hasPrefix(".") {
            let url = URL(fileURLWithPath: root).appendingPathComponent(entry)
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }
            let size = directorySize(of: url, fm: fm)
            guard size > 0 else { continue }
            let info = NSDictionary(contentsOf: url.appendingPathComponent("Info.plist"))
            let device = info?["Device Name"] as? String
            let date = (info?["Last Backup Date"] as? Date).map {
                DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .none)
            }
            let detail = [device, date].compactMap { $0 }.joined(separator: ", ")
            found.append(Item(url: url, category: .deviceBackups, size: size,
                              detail: detail.isEmpty ? entry : detail,
                              recommended: CleanerPolicy.precheckDeviceBackups))
        }
        return sorted(found)
    }

    /// Package manager download caches at their exact subpaths. Only present,
    /// non-empty folders are offered, and every find starts unchecked. The
    /// home parameter exists so the scan can run against a fixture.
    static func scanPackageCaches(home: String = NSHomeDirectory()) -> [Item] {
        let fm = FileManager.default
        var found: [Item] = []
        for subpath in CleanerPolicy.packageCacheSubpaths {
            let url = URL(fileURLWithPath: home + "/" + subpath, isDirectory: true)
            guard fm.fileExists(atPath: url.path),
                  !UninstallerSupport.isSymbolicLink(url) else { continue }
            let size = directorySize(of: url, fm: fm)
            guard size > 0 else { continue }
            found.append(Item(url: url, category: .packageCaches, size: size,
                              detail: subpath,
                              recommended: CleanerPolicy.precheckPackageCaches))
        }
        return sorted(found)
    }

    /// The age, in days, the conversation search runs with, or 0 when it must
    /// not run. An unattended pass never searches, whatever the preference
    /// says, so the scheduler cannot reach these conversations.
    static func codingConversationSearchDays(attended: Bool,
                                             defaults: UserDefaults = .standard) -> Int {
        guard attended else { return 0 }
        return CleanerPolicy.sanitizedScreenshotAgeDays(
            defaults.integer(forKey: DefaultsKey.cleanerCodingConversationAgeDays))
    }

    /// Old Claude Code conversations under `<home>/.claude/projects/<project>/`.
    /// A conversation is `<uuid>.jsonl` with its `<uuid>/` folder, and its age is
    /// the newest modification anywhere in that pair. Conversations the desktop
    /// app still references are left out. Metadata that cannot be read fails
    /// safe: no conversation is offered at all.
    static func scanCodingConversations(olderThanDays days: Int,
                                        home: String = NSHomeDirectory()) -> [Item] {
        guard days > 0, let referenced = desktopReferencedConversations(home: home) else { return [] }
        let fm = FileManager.default
        let projectsPath = home + "/.claude/projects"
        let root = URL(fileURLWithPath: projectsPath, isDirectory: true)
        guard let projects = try? fm.contentsOfDirectory(atPath: projectsPath) else { return [] }
        let cutoff = Date().addingTimeInterval(-TimeInterval(days) * 86_400)
        var found: [Item] = []
        for project in projects where !project.hasPrefix(".") {
            let projectURL = root.appendingPathComponent(project, isDirectory: true)
            guard !UninstallerSupport.isSymbolicLink(projectURL),
                  let entries = try? fm.contentsOfDirectory(atPath: projectURL.path) else { continue }
            for entry in entries where entry.hasSuffix(".jsonl") {
                let uuid = String(entry.dropLast(".jsonl".count))
                guard CleanerSupport.isUUIDName(uuid), !referenced.contains(uuid.lowercased()) else { continue }
                let transcript = projectURL.appendingPathComponent(entry)
                let folder = projectURL.appendingPathComponent(uuid, isDirectory: true)
                var isDirectory: ObjCBool = false
                let folderExists = fm.fileExists(atPath: folder.path, isDirectory: &isDirectory)
                // Something named like the folder that is not a plain folder is not ours to judge.
                if folderExists, !isDirectory.boolValue || UninstallerSupport.isSymbolicLink(folder) { continue }
                let companion = folderExists ? folder : nil
                guard !UninstallerSupport.isSymbolicLink(transcript),
                      let activity = lastActivity(of: transcript, folder: companion),
                      activity <= cutoff else { continue }
                let size = fileSize(transcript) + (companion.map { Self.directorySize(of: $0, fm: fm) } ?? 0)
                found.append(Item(url: transcript, category: .codingConversations, size: size,
                                  detail: project, recommended: CleanerPolicy.precheckCodingConversations,
                                  companion: companion))
            }
        }
        return sorted(found)
    }

    /// The newest modification time in a conversation: its transcript and
    /// everything under its folder. nil when any part cannot be read, so the
    /// conversation is skipped rather than guessed at.
    private static func lastActivity(of transcript: URL, folder: URL?) -> Date? {
        guard let transcriptDate = modificationDate(of: transcript) else { return nil }
        guard let folder else { return transcriptDate }
        var newest = transcriptDate
        var unreadable = false
        guard let enumerator = FileManager.default.enumerator(
            at: folder, includingPropertiesForKeys: [.contentModificationDateKey], options: [],
            errorHandler: { _, _ in
                unreadable = true
                return true
            }) else { return nil }
        for case let url as URL in enumerator {
            guard let date = modificationDate(of: url) else { return nil }
            newest = max(newest, date)
        }
        return unreadable ? nil : newest
    }

    private static func modificationDate(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    /// Session ids the Claude desktop app still references, read only for
    /// `cliSessionId` and the names of `deleted_` files. Nothing is printed,
    /// logged or stored. nil means the metadata exists but cannot be read or
    /// parsed, and the caller then offers no conversation at all.
    static func desktopReferencedConversations(home: String) -> Set<String>? {
        let fm = FileManager.default
        let rootPath = home + "/Library/Application Support/Claude/claude-code-sessions"
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: rootPath, isDirectory: &isDirectory) else { return [] }
        guard isDirectory.boolValue else { return nil }
        var unreadable = false
        guard let enumerator = fm.enumerator(
            at: URL(fileURLWithPath: rootPath, isDirectory: true),
            includingPropertiesForKeys: [.isRegularFileKey], options: [],
            errorHandler: { _, _ in
                unreadable = true
                return true
            }) else { return nil }
        var referenced = Set<String>()
        for case let url as URL in enumerator {
            let name = url.lastPathComponent
            if name.hasPrefix("deleted_") {
                let remainder = String(name.dropFirst("deleted_".count))
                let uuid = URL(fileURLWithPath: remainder).deletingPathExtension().lastPathComponent
                if CleanerSupport.isUUIDName(uuid) { referenced.insert(uuid.lowercased()) }
            } else if name.hasPrefix("local_"), name.hasSuffix(".json"),
                      (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                guard let data = try? Data(contentsOf: url),
                      let session = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
                else { return nil }
                if let raw = session["cliSessionId"] {
                    guard let id = raw as? String else { return nil }
                    referenced.insert(id.lowercased())
                }
            }
        }
        return unreadable ? nil : referenced
    }

    /// The folders and age of the forgotten screenshot search, or nil when
    /// the user turned it off.
    private static func screenshotSearch() -> (folders: [URL], days: Int)? {
        let days = CleanerPolicy.sanitizedScreenshotAgeDays(
            UserDefaults.standard.integer(forKey: DefaultsKey.cleanerScreenshotAgeDays))
        guard days > 0 else { return nil }
        return (screenshotFolders(), days)
    }

    /// Where macOS saves screenshots and, when its screenshot tool is
    /// installed, where this app saves its own.
    private static func screenshotFolders() -> [URL] {
        let home = NSHomeDirectory()
        let location = CFPreferencesCopyAppValue("location" as CFString,
                                                 "com.apple.screencapture" as CFString) as? String
        var paths = [CleanerSupport.screenshotFolder(location: location, home: home)]
        if AppFeature.screenshot.isAvailable {
            let stored = UserDefaults.standard.string(forKey: DefaultsKey.screenshotSaveFolder) ?? ""
            let candidate = stored.isEmpty ? home + "/Desktop" : (stored as NSString).expandingTildeInPath
            if CleanerSupport.isSafeScreenshotFolder(candidate, home: home) {
                paths.append(candidate)
            } else {
                paths.append(home + "/Desktop")
            }
        }
        var seen = Set<String>()
        return paths
            // The real path: the removal guard refuses anything reached
            // through a symbolic link.
            .map { URL(fileURLWithPath: $0, isDirectory: true).resolvingSymlinksInPath().standardizedFileURL }
            .filter { CleanerSupport.isSafeScreenshotFolder($0.path, home: home) && seen.insert($0.path).inserted }
    }

    private static func isScreenshotFolderChild(_ url: URL) -> Bool {
        screenshotFolders().contains { CleanerSupport.isDirectChild(url, of: $0) }
    }

    /// Screenshots nobody touched for `days`: only the top level of the
    /// screenshot folders, only files macOS itself marked as captures, and
    /// only under the dated name they were saved with. Moving or renaming
    /// one is a decision about it, so it never shows up again. Without
    /// access to a folder nothing from it is offered.
    private static func scanScreenshots(in folders: [URL], days: Int) -> [Item] {
        let fm = FileManager.default
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey,
                                         .creationDateKey, .contentModificationDateKey]
        let now = Date()
        var found: [Item] = []
        for folder in folders {
            guard let entries = try? fm.contentsOfDirectory(at: folder,
                                                            includingPropertiesForKeys: Array(keys),
                                                            options: [.skipsHiddenFiles]) else { continue }
            for url in entries {
                guard let values = try? url.resourceValues(forKeys: keys),
                      values.isRegularFile == true, values.isSymbolicLink != true,
                      CleanerSupport.isValidScreenshotExtension(url.pathExtension),
                      let created = values.creationDate,
                      isScreenCapture(url),
                      CleanerSupport.screenshotKeepsDefaultName(url.lastPathComponent,
                                                                created: created) else { continue }
                let lastUsed = extendedAttribute(CleanerSupport.lastUsedDateAttribute, of: url)
                    .flatMap(CleanerSupport.lastUsedDate(fromAttribute:))
                guard CleanerSupport.isForgottenScreenshot(created: created,
                                                           modified: values.contentModificationDate,
                                                           lastUsed: lastUsed,
                                                           now: now, days: days) else { continue }
                let size = fileSize(url)
                guard size > 0 else { continue }
                found.append(Item(url: url, category: .screenshots, size: size,
                                  detail: DateFormatter.localizedString(from: created,
                                                                        dateStyle: .medium,
                                                                        timeStyle: .none),
                                  recommended: CleanerPolicy.precheckScreenshots))
            }
        }
        return sorted(found)
    }

    private static func isScreenCapture(_ url: URL) -> Bool {
        extendedAttribute(CleanerSupport.screenCaptureAttribute, of: url)
            .map(CleanerSupport.isScreenCaptureFlag) ?? false
    }

    private static func extendedAttribute(_ name: String, of url: URL) -> Data? {
        url.withUnsafeFileSystemRepresentation { path -> Data? in
            guard let path else { return nil }
            let length = getxattr(path, name, nil, 0, 0, XATTR_NOFOLLOW)
            guard length > 0, length <= 4096 else { return nil }
            var data = Data(count: length)
            let read = data.withUnsafeMutableBytes {
                getxattr(path, name, $0.baseAddress, length, 0, XATTR_NOFOLLOW)
            }
            return read == length ? data : nil
        }
    }

    /// The names the user can see in a Trash folder, or nil when the folder
    /// cannot be listed. Hidden bookkeeping files such as .DS_Store are left out.
    private static func visibleTrashEntries(in trash: URL, fm: FileManager) -> [String]? {
        guard let entries = try? fm.contentsOfDirectory(atPath: trash.path) else { return nil }
        return entries.filter { !$0.hasPrefix(".") }
    }

    /// The visible Trash entries with their identities, as the scan records
    /// them for the removal.
    static func scannedTrashEntries(in trash: URL) -> [TrashEntry] {
        (visibleTrashEntries(in: trash, fm: FileManager.default) ?? []).map {
            TrashEntry(name: $0, identity: UninstallerSupport.fileIdentity(at: trash.appendingPathComponent($0)))
        }
    }

    private static func scanTrash() -> [Item] {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: NSHomeDirectory() + "/.Trash")
        // Only what the user can see in the Trash counts: an "empty" Trash
        // still carries hidden bookkeeping files (.DS_Store), and offering
        // to empty those reads as a lie.
        let entries = scannedTrashEntries(in: url)
        guard !entries.isEmpty else { return [] }
        let size = entries.reduce(Int64(0)) {
            $0 + directorySize(of: url.appendingPathComponent($1.name), fm: fm)
        }
        guard size > 0 else { return [] }
        return [Item(url: url, category: .trash, size: size,
                     detail: "", recommended: false, trashEntries: entries)]
    }

    // MARK: - Helpers

    private static func sorted(_ items: [Item]) -> [Item] {
        items.sorted { $0.size > $1.size }
    }

    static func directorySize(of url: URL, fm: FileManager,
                              cancellation: CleanerSupport.ScanCancellation? = nil) -> Int64 {
        if UninstallerSupport.isSymbolicLink(url) { return 0 }
        guard cancellation?.isCancelled != true else { return 0 }
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        if !isDir.boolValue { return fileSize(url) }
        var total: Int64 = 0
        if let enumerator = fm.enumerator(at: url,
                                          includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
                                          options: [], errorHandler: nil) {
            for case let item as URL in enumerator {
                autoreleasepool { }
                guard cancellation?.isCancelled != true else { break }
                if UninstallerSupport.isSymbolicLink(item) {
                    enumerator.skipDescendants()
                    continue
                }
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
