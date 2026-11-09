// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import Combine
import CoreServices

/// Finds which of the installed apps have a newer version waiting, in one
/// list, and updates the ones the person picks.
///
/// Managed apps can be updated in place or handed to the store. Other apps
/// are compared conservatively with a public online catalog and only opened,
/// leaving their own updater in control.
///
/// Nothing runs at rest. The scan happens strictly on demand when the person opens
/// the list or asks for it.
final class AppUpdatesService: ObservableObject {
    static let shared = AppUpdatesService()

    @Published private(set) var items: [AppUpdatesSupport.Item] = []
    @Published private(set) var rules: [AppUpdatesSupport.UpdateRule] = []
    /// Latest scan, including skipped versions, so removing a rule needs no network work.
    private var allItems: [AppUpdatesSupport.Item] = []
    @Published private(set) var isChecking = false
    @Published private(set) var lastCheck: Date?
    /// Rows the person ticked. New findings arrive ticked, so the common
    /// case is one click.
    @Published var selection: Set<String> = []
    /// False means package-managed apps cannot be updated from this list.
    @Published private(set) var packageManagerAvailable = false
    /// False means the online source failed, so an empty list is incomplete.
    @Published private(set) var onlineCatalogAvailable = true
    @Published private(set) var appStoreAvailable = true
    @Published private(set) var uncheckedAppNames: [String] = []
    /// A check finished in THIS process. The time of the last check survives
    /// relaunches, but its findings do not, so nothing may claim the Mac is
    /// up to date until a scan has actually run here.
    @Published private(set) var hasCheckedThisSession = false
    @Published private(set) var lastError: String?

    private let workQueue = DispatchQueue(label: "com.hexa.appupdates", qos: .utility)
    private lazy var lookupSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 20
        return URLSession(configuration: configuration)
    }()
    private lazy var catalogSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.timeoutIntervalForRequest = 10
        // The catalog is a few megabytes even compressed; a slow link needs
        // more than the 20 seconds a single lookup gets.
        configuration.timeoutIntervalForResource = 90
        return URLSession(configuration: configuration)
    }()
    private var scanGeneration = 0
    private var sourceRefreshPending = false
    private var knownIDs = Set<String>()
    /// The person was sent elsewhere to finish an update, so the list is
    /// about to be wrong until it is read again.
    private(set) var updateHandoffPending = false
    private var onlineCatalogCache: (loadedAt: Date, entries: [AppUpdatesSupport.CatalogEntry])?
    /// Alive only while an upgrade this service started is running, so the
    /// list refreshes itself even when no window is on screen to notice.
    private var upgradeObserver: AnyCancellable?
    /// Second stage of a mixed upgrade, run once the cask operation ends.
    private var pendingFormulaTokens: [String] = []

    private init() {
        let stamp = UserDefaults.standard.double(forKey: DefaultsKey.appUpdatesLastCheck)
        lastCheck = stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
        rules = AppUpdatesSupport.decodedRules(
            UserDefaults.standard.string(forKey: DefaultsKey.appUpdatesRules))
    }

    // MARK: - Lifecycle

    func syncWithPreferences() {
        reloadRules()
    }

    func stop() {
    }

    // MARK: - Checking

    /// A source switch changes the answer. Let an in-flight scan finish its
    /// read, discard that answer and immediately run once with the new choice.
    func sourceSelectionDidChange() {
        if isChecking {
            sourceRefreshPending = true
        } else {
            check()
        }
    }

    /// Scans the enabled sources strictly on demand. Only an explicit Check
    /// now downloads the online catalog again; other scans reuse the copy
    /// read within the last hour.
    func check(forceCatalogRefresh: Bool = false) {
        guard AppFeature.appUpdates.isAvailable else { return }
        if isChecking {
            return
        }
        reloadRules()
        let checkedRules = rules
        isChecking = true
        lastError = nil
        scanGeneration += 1
        let generation = scanGeneration
        let includeHomebrewApps = UserDefaults.standard.bool(
            forKey: DefaultsKey.appUpdatesIncludeHomebrewApps)
        let includeAppStore = UserDefaults.standard.bool(forKey: DefaultsKey.appUpdatesIncludeAppStore)
        let includeOnlineCatalog = UserDefaults.standard.bool(
            forKey: DefaultsKey.appUpdatesIncludeOnlineCatalog)
        let country = Locale.current.region?.identifier

        workQueue.async { [weak self] in
            guard let self else { return }
            let apps = AppUpdatesSupport.checkedApps(
                Self.scanInstalledApps(includePublisherFeeds: includeOnlineCatalog), rules: checkedRules)
            let packageResult = includeHomebrewApps || includeOnlineCatalog
                ? self.packageManagerFindings(apps: apps, includeUpdates: includeHomebrewApps)
                : PackageResult(items: [], coveredPaths: [], available: true,
                                onlineCoverageAvailable: true)
            let coveredPaths = packageResult.coveredPaths
            let storeCandidates = includeAppStore
                ? AppUpdatesSupport.appStoreCandidates(
                    apps: apps, coveredPaths: Set(packageResult.items.compactMap(\.bundlePath)))
                : []
            let onlineCandidates = includeOnlineCatalog
                && packageResult.onlineCoverageAvailable
                ? AppUpdatesSupport.onlineCatalogCandidates(apps: apps, coveredPaths: coveredPaths)
                : []
            let os = ProcessInfo.processInfo.operatingSystemVersion
            let operatingSystemVersion = "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
            let group = DispatchGroup()
            var storeResult = SourceResult(items: [], available: true)
            var feedResult = SourceResult(items: [], available: true)
            var onlineResult = SourceResult(
                items: [],
                available: !includeOnlineCatalog || packageResult.onlineCoverageAvailable,
                uncheckedApps: includeOnlineCatalog && !packageResult.onlineCoverageAvailable
                    ? AppUpdatesSupport.onlineCatalogCandidates(apps: apps, coveredPaths: coveredPaths)
                    : [])

            group.enter()
            self.storeFindings(for: storeCandidates,
                               country: country,
                               operatingSystemVersion: operatingSystemVersion) {
                storeResult = $0
                group.leave()
            }
            if includeOnlineCatalog, onlineResult.available {
                group.enter()
                self.publisherFindings(for: onlineCandidates,
                                       operatingSystemVersion: operatingSystemVersion) {
                    feedResult = $0
                    group.leave()
                }
                group.enter()
                self.onlineCatalogFindings(for: onlineCandidates,
                                           operatingSystemVersion: operatingSystemVersion,
                                           forceRefresh: forceCatalogRefresh) {
                    onlineResult = $0
                    group.leave()
                }
            }
            group.notify(queue: self.workQueue) {
                let resolvedFeed = feedResult.resolvingCatalogFallback(
                    checkedPaths: onlineResult.checkedPaths, candidates: onlineCandidates)
                DispatchQueue.main.async {
                    guard generation == self.scanGeneration else { return }
                    self.finishCheck(items: AppUpdatesSupport.merged(packageResult.items,
                                                                     storeResult.items,
                                                                     resolvedFeed.items,
                                                                     onlineResult.items.filter {
                                                                         !resolvedFeed.checkedPaths.contains($0.bundlePath ?? "")
                                                                     }),
                                     packageManagerAvailable: packageResult.available,
                                     onlineCatalogAvailable: onlineResult.available && resolvedFeed.available,
                                     appStoreAvailable: storeResult.available,
                                     uncheckedAppNames: AppUpdatesSupport.uncheckedAppNames(
                                        storeResult.uncheckedApps + resolvedFeed.uncheckedApps + onlineResult.uncheckedApps,
                                        checkedPaths: resolvedFeed.checkedPaths))
                }
            }
        }
    }

    private func finishCheck(items scannedItems: [AppUpdatesSupport.Item],
                             packageManagerAvailable available: Bool,
                             onlineCatalogAvailable catalogAvailable: Bool,
                             appStoreAvailable storeAvailable: Bool,
                             uncheckedAppNames: [String]) {
        // The feature can be switched off in the hub while a scan is in
        // flight; its findings belong to a surface that no longer exists.
        guard AppFeature.appUpdates.isAvailable else {
            isChecking = false
            sourceRefreshPending = false
            return
        }
        if sourceRefreshPending {
            sourceRefreshPending = false
            isChecking = false
            check()
            return
        }
        allItems = scannedItems
        let newItems = AppUpdatesSupport.visibleItems(scannedItems, rules: rules)
        selection = AppUpdatesSupport.reconciledSelection(previous: selection,
                                                          knownIDs: knownIDs,
                                                          items: newItems)
        knownIDs = Set(newItems.map(\.id))
        items = newItems
        packageManagerAvailable = available
        onlineCatalogAvailable = catalogAvailable
        appStoreAvailable = storeAvailable
        self.uncheckedAppNames = uncheckedAppNames
        hasCheckedThisSession = true
        isChecking = false
        let now = Date()
        lastCheck = now
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: DefaultsKey.appUpdatesLastCheck)
        UserDefaults.standard.set(newItems.count, forKey: DefaultsKey.appUpdatesLastCount)
    }

    private static func announcedIDs() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: DefaultsKey.appUpdatesNotifiedIDs) ?? [])
    }

    private static func saveAnnouncedIDs(_ ids: Set<String>) {
        UserDefaults.standard.set(ids.sorted(), forKey: DefaultsKey.appUpdatesNotifiedIDs)
    }

    // MARK: - Package manager source

    private struct PackageResult {
        let items: [AppUpdatesSupport.Item]
        let coveredPaths: Set<String>
        let available: Bool
        let onlineCoverageAvailable: Bool
    }

    private func packageManagerFindings(apps: [AppUpdatesSupport.InstalledApp],
                                        includeUpdates: Bool) -> PackageResult {
        guard let brewPath = HomebrewCommandBuilder.trustedBrewPath() else {
            return PackageResult(items: [], coveredPaths: [], available: !includeUpdates,
                                 onlineCoverageAvailable: true)
        }
        let installedOutput = Self.runBrewCommand(HomebrewCommandBuilder.installed(brewPath: brewPath),
                                                  environment: HomebrewEnvironment.forBrew)
        let records = installedOutput.status == 0
            ? HomebrewParser.parseInstalledCaskRecords(installedOutput.output)
            : []
        let coveredPaths = Set(records.compactMap {
            AppUpdatesSupport.packageBundle(for: $0, apps: apps)?.path
        })
        guard includeUpdates else {
            return PackageResult(items: [], coveredPaths: coveredPaths, available: true,
                                 onlineCoverageAvailable: installedOutput.status == 0)
        }
        let outdatedOutput = Self.runBrewCommand(
            HomebrewCommandBuilder.outdatedCasksIncludingSelfUpdating(brewPath: brewPath),
            environment: HomebrewEnvironment.forBrew)
        let outdatedFormulasOutput = Self.runBrewCommand(
            HomebrewCommandBuilder.outdatedFormulas(brewPath: brewPath),
            environment: HomebrewEnvironment.forBrew)
        guard installedOutput.status == 0, outdatedOutput.status == 0,
              outdatedFormulasOutput.status == 0 else {
            let failure = [outdatedFormulasOutput, outdatedOutput, installedOutput]
                .first { $0.status != 0 }
            let message = failure.map { HomebrewProgressParser.visibleError(from: $0.output) } ?? ""
            DispatchQueue.main.async { [weak self] in
                self?.lastError = message.isEmpty ? nil : message
            }
            return PackageResult(items: [], coveredPaths: coveredPaths, available: true,
                                 onlineCoverageAvailable: installedOutput.status == 0)
        }
        let updates = (try? HomebrewParser.parseOutdatedCommandOutput(outdatedOutput.output)) ?? [:]
        let formulaOutdated = (try? HomebrewParser.parseOutdatedCommandOutput(outdatedFormulasOutput.output)) ?? [:]
        let mergedUpdates = updates.merging(formulaOutdated) { first, _ in first }
        let items = AppUpdatesSupport.packageUpdates(
            outdated: Array(mergedUpdates.values),
            installed: records,
            ignoredTokens: Self.ownPackageTokens,
            apps: apps.filter { !$0.version.isEmpty })
        + AppUpdatesSupport.formulaUpdates(
            outdated: Array(mergedUpdates.values),
            ignoredTokens: Self.ownPackageTokens)
        return PackageResult(items: items, coveredPaths: coveredPaths, available: true,
                             onlineCoverageAvailable: true)
    }

    // MARK: - App Store source

    private func storeFindings(for candidates: [AppUpdatesSupport.InstalledApp],
                               country: String?,
                               operatingSystemVersion: String,
                               completion: @escaping (SourceResult) -> Void) {
        storeEntries(for: candidates, country: country, preferStoreIDs: true) { entries in
            let missing = candidates.filter { entries[$0.bundleID] == nil && $0.storeID != nil }
            self.storeEntries(for: missing, country: country, preferStoreIDs: false) { fallback in
                let merged = entries.merging(fallback) { first, _ in first }
                completion(SourceResult(
                    items: AppUpdatesSupport.appStoreUpdates(apps: candidates,
                                                            storeVersions: merged,
                                                            operatingSystemVersion: operatingSystemVersion),
                    available: AppUpdatesSupport.hasStoreCoverage(bundleIDs: candidates.map(\.bundleID),
                                                                 entries: merged),
                    uncheckedApps: candidates.filter { merged[$0.bundleID] == nil }))
            }
        }
    }

    private func storeEntries(for candidates: [AppUpdatesSupport.InstalledApp],
                              country: String?, preferStoreIDs: Bool,
                              completion: @escaping ([String: AppUpdatesSupport.StoreEntry]) -> Void) {
        guard !candidates.isEmpty else {
            completion([:])
            return
        }
        let groups = Dictionary(grouping: candidates) { preferStoreIDs && $0.storeID != nil }
        var merged: [String: AppUpdatesSupport.StoreEntry] = [:]
        let group = DispatchGroup()
        let lock = NSLock()

        for (useIDs, apps) in groups {
            for start in stride(from: 0, to: apps.count, by: AppUpdatesSupport.storeLookupBatchSize) {
                let batch = Array(apps[start..<min(start + AppUpdatesSupport.storeLookupBatchSize, apps.count)])
                let lookup = useIDs
                    ? AppUpdatesSupport.storeIDLookupURL(ids: batch.compactMap(\.storeID), country: country)
                    : AppUpdatesSupport.storeLookupURL(bundleIDs: batch.map(\.bundleID), country: country)
                guard let url = lookup else { continue }
                group.enter()
                lookupSession.dataTask(with: url) { data, response, error in
                    defer { group.leave() }
                    let body = error == nil ? data : nil
                    let statusCode = (response as? HTTPURLResponse)?.statusCode
                    let entries = useIDs
                        ? AppUpdatesSupport.storeMetadataResponse(body, statusCode: statusCode)
                        : AppUpdatesSupport.storeLookupResponse(body, statusCode: statusCode)
                    lock.lock()
                    merged.merge(entries) { _, new in new }
                    lock.unlock()
                }.resume()
            }
        }

        group.notify(queue: workQueue) { completion(merged) }
    }

    // MARK: - Online catalog source

    private struct SourceResult {
        let items: [AppUpdatesSupport.Item]
        let available: Bool
        var checkedPaths: Set<String> = []
        var uncheckedApps: [AppUpdatesSupport.InstalledApp] = []
        var catalogFallbackPaths: Set<String> = []

        func resolvingCatalogFallback(checkedPaths catalogPaths: Set<String>,
                                      candidates: [AppUpdatesSupport.InstalledApp]) -> SourceResult {
            let missing = catalogFallbackPaths.subtracting(catalogPaths)
            return SourceResult(items: items, available: available && missing.isEmpty,
                                checkedPaths: checkedPaths,
                                uncheckedApps: uncheckedApps + candidates.filter { missing.contains($0.path) })
        }
    }

    private static let onlineCatalogCacheLifetime: TimeInterval = 60 * 60

    private func publisherFindings(for candidates: [AppUpdatesSupport.InstalledApp],
                                   operatingSystemVersion: String,
                                   completion: @escaping (SourceResult) -> Void) {
        var grouped: [AppUpdateFeedSupport.Feed: [AppUpdatesSupport.InstalledApp]] = [:]
        for app in candidates {
            if let feed = app.updateFeed { grouped[feed, default: []].append(app) }
        }
        let feeds = Array(grouped)
        var items: [AppUpdatesSupport.Item] = []
        var checkedPaths = Set<String>()
        var uncheckedPaths = Set<String>()
        var catalogFallbackPaths = Set<String>()
        var complete = true
        let deadline = Date().addingTimeInterval(60)
        var kernelBytes = [CChar](repeating: 0, count: 256)
        var kernelSize = kernelBytes.count
        let kernelVersion = sysctlbyname("kern.osrelease", &kernelBytes, &kernelSize, nil, 0) == 0
            ? String(cString: kernelBytes) : ""
        #if arch(arm64)
        let architecture = "arm64"
        #else
        let architecture = "x86_64"
        #endif

        // Four at a time, coalesced by URL, with a ceiling for the whole pass.
        // All accumulated results are confined to workQueue.
        func checkBatch(_ start: Int) {
            guard start < feeds.count, Date() < deadline else {
                // A feed the deadline cut off was not checked, so keep its apps named.
                uncheckedPaths.formUnion(feeds[start...].flatMap { $0.value.map(\.path) })
                completion(SourceResult(items: items, available: complete && start >= feeds.count,
                                        checkedPaths: checkedPaths,
                                        uncheckedApps: candidates.filter {
                                            uncheckedPaths.contains($0.path)
                                        }, catalogFallbackPaths: catalogFallbackPaths))
                return
            }
            let end = min(start + 4, feeds.count)
            let group = DispatchGroup()
            for (feed, apps) in feeds[start..<end] {
                group.enter()
                AppUpdateFeedLoader.load(feed.url) { loadResult in
                    self.workQueue.async {
                        defer { group.leave() }
                        let findings = AppUpdateFeedSupport.findings(
                            loadResult: loadResult, format: feed.format, apps: apps,
                            operatingSystemVersion: operatingSystemVersion,
                            kernelVersion: kernelVersion, architecture: architecture)
                        items.append(contentsOf: findings.items)
                        checkedPaths.formUnion(findings.checkedPaths)
                        uncheckedPaths.formUnion(findings.uncheckedPaths)
                        catalogFallbackPaths.formUnion(findings.catalogFallbackPaths)
                        complete = complete && findings.complete
                    }
                }
            }
            group.notify(queue: self.workQueue) { checkBatch(end) }
        }
        checkBatch(0)
    }

    private func onlineCatalogFindings(for candidates: [AppUpdatesSupport.InstalledApp],
                                       operatingSystemVersion: String,
                                       forceRefresh: Bool,
                                       completion: @escaping (SourceResult) -> Void) {
        guard !candidates.isEmpty else {
            completion(SourceResult(items: [], available: true))
            return
        }

        let now = Date()
        if !forceRefresh, let cache = onlineCatalogCache {
            let age = now.timeIntervalSince(cache.loadedAt)
            if age >= 0, age < Self.onlineCatalogCacheLifetime {
                completion(onlineResult(candidates: candidates,
                                        catalog: cache.entries,
                                        operatingSystemVersion: operatingSystemVersion))
                return
            }
        }

        var request = URLRequest(url: AppUpdatesSupport.onlineCatalogURL)
        if forceRefresh { request.cachePolicy = .reloadIgnoringLocalCacheData }
        catalogSession.dataTask(with: request) { [weak self] data, response, _ in
            guard let self else { return }
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            self.workQueue.async {
                guard let entries = AppUpdatesSupport.parseOnlineCatalogResponse(
                    data, statusCode: statusCode) else {
                    completion(SourceResult(items: [], available: false, uncheckedApps: candidates))
                    return
                }
                self.onlineCatalogCache = (Date(), entries)
                completion(self.onlineResult(candidates: candidates,
                                             catalog: entries,
                                             operatingSystemVersion: operatingSystemVersion))
            }
        }.resume()
    }

    private func onlineResult(candidates: [AppUpdatesSupport.InstalledApp],
                              catalog: [AppUpdatesSupport.CatalogEntry],
                              operatingSystemVersion: String) -> SourceResult {
        let findings = AppUpdatesSupport.onlineCatalogFindings(
            apps: candidates, catalog: catalog,
            operatingSystemVersion: operatingSystemVersion,
            ignoredTokens: Self.ownPackageTokens)
        return SourceResult(items: findings.items, available: true,
                            checkedPaths: findings.checkedPaths)
    }

    // MARK: - Update rules

    func skipVersion(_ item: AppUpdatesSupport.Item) {
        guard !AppUpdatesSupport.isUncomparable(item.latestVersion) else { return }
        setRule(for: item, version: item.latestVersion)
    }

    func excludeApp(_ item: AppUpdatesSupport.Item) {
        setRule(for: item, version: nil)
    }

    private func setRule(for item: AppUpdatesSupport.Item, version: String?) {
        guard !isChecking, let bundleID = item.bundleID, !bundleID.isEmpty,
              items.contains(item) else { return }
        let rule = AppUpdatesSupport.UpdateRule(bundleID: bundleID, name: item.name, version: version)
        saveRules(rules.filter { $0.bundleID != bundleID } + [rule])
    }

    func removeRule(_ rule: AppUpdatesSupport.UpdateRule) {
        guard !isChecking, rules.contains(rule) else { return }
        saveRules(rules.filter { $0.id != rule.id })
        // An excluded app was not queried in later scans. Do not invent a current
        // result or launch a full scan just to remove its rule; Check now remains available.
        if rule.version == nil { hasCheckedThisSession = false }
    }

    private func saveRules(_ newRules: [AppUpdatesSupport.UpdateRule]) {
        guard let raw = AppUpdatesSupport.encodedRules(newRules) else { return }
        rules = newRules
        UserDefaults.standard.set(raw, forKey: DefaultsKey.appUpdatesRules)
        applyRules()
    }

    /// Settings restore and reset use the same preference as the panel.
    private func reloadRules() {
        let restored = AppUpdatesSupport.decodedRules(
            UserDefaults.standard.string(forKey: DefaultsKey.appUpdatesRules))
        guard restored != rules else { return }
        rules = restored
        hasCheckedThisSession = false
        if isChecking { sourceRefreshPending = true }
        applyRules()
    }

    private func applyRules() {
        let visible = AppUpdatesSupport.visibleItems(allItems, rules: rules)
        selection = AppUpdatesSupport.reconciledSelection(previous: selection,
                                                          knownIDs: knownIDs, items: visible)
        knownIDs = Set(visible.map(\.id))
        items = visible
        UserDefaults.standard.set(visible.count, forKey: DefaultsKey.appUpdatesLastCount)
        Self.saveAnnouncedIDs(Self.announcedIDs().intersection(knownIDs))
    }

    // MARK: - Acting on the list

    var selectedCount: Int { selection.count }
    var selectableCount: Int { items.filter(\.isSelectable).count }

    func selectAll() {
        selection = Set(items.filter(\.isSelectable).map(\.id))
    }

    func selectNone() {
        selection = []
    }

    func toggle(_ item: AppUpdatesSupport.Item) {
        guard item.isSelectable, items.contains(item) else { return }
        if selection.contains(item.id) {
            selection.remove(item.id)
        } else {
            selection.insert(item.id)
        }
    }

    /// Updates what the person ticked: the package manager installs its share
    /// in one command, and the store apps hand off to the App Store, which is
    /// as far as any app can go there.
    func updateSelected() {
        let caskTokens = AppUpdatesSupport.packageTokens(in: items, selection: selection, kind: .cask)
        let formulaTokens = AppUpdatesSupport.packageTokens(in: items, selection: selection, kind: .formula)
        if !caskTokens.isEmpty || !formulaTokens.isEmpty {
            startUpgrade(caskTokens: caskTokens, formulaTokens: formulaTokens)
        }
        if let page = AppUpdatesSupport.singleStorePage(in: items, selection: selection),
           let url = URL(string: page) {
            handOff(url)
        } else if AppUpdatesSupport.hasStoreSelection(in: items, selection: selection) {
            openAppStoreUpdates()
        }
    }

    func update(_ item: AppUpdatesSupport.Item) {
        guard items.contains(item) else { return }
        switch item.source {
        case .packageManager:
            guard let token = item.token else { return }
            if item.packageKind == .formula {
                startUpgrade(caskTokens: [], formulaTokens: [token])
            } else {
                startUpgrade(caskTokens: [token], formulaTokens: [])
            }
        case .appStore:
            if let page = item.storePage, let url = URL(string: page) {
                handOff(url)
            } else {
                openAppStoreUpdates()
            }
        case .onlineCatalog:
            guard let path = item.bundlePath else { return }
            handOff(URL(fileURLWithPath: path))
        }
    }

    func openAppStoreUpdates() {
        guard let url = URL(string: "macappstore://showUpdatesPage") else { return }
        handOff(url)
    }

    /// The destination installs its own update, so open it and tell the truth
    /// again the moment the person is back.
    private func handOff(_ url: URL) {
        updateHandoffPending = true
        if !NSWorkspace.shared.open(url) {
            updateHandoffPending = false
        }
    }

    /// Watches the upgrade to its end and re-reads the list, so a row leaves
    /// on its own instead of waiting for someone to press Check now. With a
    /// mixed selection the stages queue: casks first, CLI formulae after, the
    /// second starting only when the single operation lane is free again. A
    /// failed stage stops the chain and just re-reads the list.
    private func startUpgrade(caskTokens: [String], formulaTokens: [String]) {
        pendingFormulaTokens = formulaTokens
        upgradeObserver = HomebrewManager.shared.$operationStatus
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self, let status, status.result != .running,
                      !Self.awaitsTapTrust(status) else { return }
                self.upgradeObserver = nil
                guard status.action == .upgradeAll, status.result == .succeeded,
                      !self.pendingFormulaTokens.isEmpty else {
                    self.pendingFormulaTokens = []
                    self.check()
                    return
                }
                self.runFormulaStage()
            }
        if !caskTokens.isEmpty {
            HomebrewManager.shared.upgradeCasks(caskTokens)
            if HomebrewManager.shared.operation == nil {
                upgradeObserver = nil
                pendingFormulaTokens = []
                check()
            }
        } else {
            runFormulaStage()
        }
    }

    /// A stage stopped on an untrusted tap stays watched: trusting it from the
    /// list runs the same command again, and that run decides how the chain
    /// goes on.
    private static func awaitsTapTrust(_ status: HomebrewOperationStatus) -> Bool {
        status.action == .upgradeAll && status.result == .failed
            && HomebrewManager.shared.untrustedTap != nil
    }

    /// Second stage of a mixed upgrade: the cask operation has ended, so the
    /// lane is free for the formula command.
    private func runFormulaStage() {
        let tokens = pendingFormulaTokens
        pendingFormulaTokens = []
        upgradeObserver = HomebrewManager.shared.$operationStatus
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let status, status.result != .running,
                      !Self.awaitsTapTrust(status) else { return }
                self?.upgradeObserver = nil
                self?.check()
            }
        HomebrewManager.shared.upgradeFormulas(tokens)
        // The lane guard (busy lane or missing brew) can silently refuse the
        // stage, leaving the observer armed with nothing to watch and the
        // list never re-read. When nothing started, tear the chain down and
        // refresh so the rows reflect reality.
        if HomebrewManager.shared.operation == nil {
            upgradeObserver = nil
            pendingFormulaTokens = []
            check()
        }
    }

    func reveal(_ item: AppUpdatesSupport.Item) {
        guard let path = item.bundlePath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    /// After a package upgrade finishes the list is stale, so it re-checks
    /// without touching the schedule.
    func refreshAfterUpgrade() {
        check()
    }

    /// What a surface calls when it appears. It scans again when the answer
    /// could have changed behind the app's back: nothing read yet in this
    /// process, an update just finished elsewhere, or the last answer is
    /// simply old. Otherwise reopening the panel costs nothing.
    func checkIfNeeded() {
        reloadRules()
        guard AppUpdatesSupport.shouldRecheck(hasCheckedThisSession: hasCheckedThisSession,
                                              handoffPending: updateHandoffPending,
                                              lastCheck: lastCheck,
                                              now: Date()) else { return }
        check()
    }

    /// Called when the app comes back to the front. Returning from an updater
    /// is the moment the list is most likely to be stale, and the window the
    /// person left behind is buried because this app has no Dock icon.
    func applicationBecameActive() {
        guard updateHandoffPending else { return }
        checkIfNeeded()
    }

    /// True while the app should reopen the window the update hand-off left
    /// behind. Reading it clears the flag, so the window is restored once.
    func consumeUpdateHandoffReturn() -> Bool {
        guard updateHandoffPending else { return false }
        updateHandoffPending = false
        return true
    }

    // MARK: - Scanning the Applications folders

    /// Reads the normal Applications folders plus shallow app results from
    /// Spotlight in the user's home, all off the main thread.
    private static func scanInstalledApps(includePublisherFeeds: Bool) -> [AppUpdatesSupport.InstalledApp] {
        InstalledApps.applicationScanPaths(
            folderPaths: folderApplicationPaths(),
            spotlightPaths: spotlightApplicationPaths(),
            homeDirectory: NSHomeDirectory()
        ).compactMap { scannedApp(at: URL(fileURLWithPath: $0), includePublisherFeeds: includePublisherFeeds) }
    }

    private static func folderApplicationPaths() -> [String] {
        let fm = FileManager.default
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications",
                                                                          isDirectory: true),
        ]
        var paths: [String] = []
        for root in roots where fm.fileExists(atPath: root.path) {
            guard let enumerator = fm.enumerator(at: root,
                                                 includingPropertiesForKeys: [.isDirectoryKey],
                                                 options: [.skipsPackageDescendants]) else { continue }
            for case let url as URL in enumerator {
                guard url.pathExtension == "app" else { continue }
                paths.append(url.path)
            }
        }
        return paths
    }

    private static func spotlightApplicationPaths() -> [String] {
        let command = HomebrewCommand(
            executable: "/usr/bin/mdfind",
            arguments: ["-onlyin", NSHomeDirectory(),
                        "kMDItemContentType == 'com.apple.application-bundle'"])
        let result = runCommand(command)
        guard result.status == 0 else { return [] }
        return result.output.split(separator: "\n").map(String.init)
    }

    private static func scannedApp(at url: URL, includePublisherFeeds: Bool) -> AppUpdatesSupport.InstalledApp? {
        let infoURL = url.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: Any] else { return nil }
        guard let bundleID = plist["CFBundleIdentifier"] as? String,
              !isOwnBundle(bundleID) else { return nil }
        let version = (plist["CFBundleShortVersionString"] as? String)
            ?? (plist["CFBundleVersion"] as? String) ?? ""
        var name = url.deletingPathExtension().lastPathComponent
        if let display = plist["CFBundleDisplayName"] as? String, !display.isEmpty {
            name = display
        }
        // A store purchase always carries its receipt inside the bundle; it
        // is the only reliable marker macOS gives.
        let hasReceipt = FileManager.default.fileExists(
            atPath: url.appendingPathComponent("Contents/_MASReceipt/receipt").path)
        let metadata = hasReceipt ? MDItemCreate(nil, url.path as CFString) : nil
        let storeID = metadata.flatMap {
            MDItemCopyAttribute($0, "kMDItemAppStoreAdamID" as CFString) as? NSNumber
        }.map(\.stringValue)
        var updateFeed: AppUpdateFeedSupport.Feed?
        if includePublisherFeeds, !hasReceipt {
            let configurationURL = url.appendingPathComponent("Contents/Resources/app-update.yml")
            let configurationSize = (try? configurationURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
            let configuration = configurationSize.map { $0 <= 64 * 1_024 } == true
                ? (try? String(contentsOf: configurationURL, encoding: .utf8)) : nil
            updateFeed = AppUpdateFeedSupport.feed(info: plist, configuration: configuration)
        }
        return AppUpdatesSupport.InstalledApp(name: name,
                                              bundleID: bundleID,
                                              path: url.standardizedFileURL.path,
                                              version: version,
                                              isFromAppStore: hasReceipt,
                                              buildVersion: plist["CFBundleVersion"] as? String ?? "",
                                              storeID: storeID,
                                              updateFeed: updateFeed)
    }

    /// This app never lists itself, in any of its builds: letting the
    /// package manager replace the running bundle is not safe. Only its own
    /// identifiers match, so third-party ids that merely share the prefix stay.
    private static func isOwnBundle(_ bundleID: String) -> Bool {
        bundleID == Bundle.main.bundleIdentifier || bundleID == "io.github.pauloborini.hexa"
            || bundleID.hasPrefix("io.github.pauloborini.hexa.")
    }

    private static let ownPackageTokens: Set<String> = ["hexa", "hexa@beta", "hexa-beta"]

    /// The package manager refreshes its own catalog on the way, which can sit
    /// on a slow network. A ceiling keeps a stalled command from leaving the
    /// check spinning for the rest of the session; the next check simply tries
    /// again.
    private static let commandTimeout: TimeInterval = 120
    private static let commandOutputLimit = 32 * 1_024 * 1_024

    private static func runCommand(_ command: HomebrewCommand,
                                   environment: [String: String]? = nil) -> (status: Int32, output: String) {
        let result = BoundedProcessRunner.run(command.executable, command.arguments,
                                              timeout: commandTimeout,
                                              maxOutputBytes: commandOutputLimit,
                                              environment: environment)
        return (result.status, String(decoding: result.output, as: UTF8.self))
    }

    /// Homebrew commands wait on the brew lane so a scan never overlaps a brew mutation.
    private static func runBrewCommand(_ command: HomebrewCommand,
                                       environment: [String: String]) -> (status: Int32, output: String) {
        HomebrewManager.lane.sync { runCommand(command, environment: environment) }
    }
}
