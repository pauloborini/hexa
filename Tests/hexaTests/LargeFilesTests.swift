// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import Combine
import XCTest

@testable import Hexa

/// Pins the service behind "Arquivos grandes e antigos": the home-only search
/// with both thresholds, the exclusions that keep system folders, packages,
/// hidden entries, links and cloud placeholders out, the identity revalidation
/// before each move to the Trash, and the states the surface shows (loading,
/// error, empty). Every test runs on a scratch home under the temporary
/// directory; the real home is never searched and the real Trash is never
/// written, because every removal goes through an injected seam.
final class LargeFilesTests: XCTestCase {
    /// A guard for the test itself, never a product deadline: the search has no
    /// deadline of its own, so a loaded machine may take longer than a minute.
    private static let testDeadline: TimeInterval = 600

    private static let deadlineMessage =
        "the search must finish within the test guard of \(Int(testDeadline)) s, "
        + "which only exists in the test: the product has no deadline"

    // MARK: - Fixtures

    /// A unique scratch home under the system temporary directory, removed when
    /// the test ends.
    private func makeHome() throws -> String {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hexa-largefiles-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let path = root.standardizedFileURL.path
        addTeardownBlock { try? FileManager.default.removeItem(atPath: path) }
        return path
    }

    /// Writes a file of `bytes` zero bytes under `home` and dates it `daysAgo`
    /// days back, so the age threshold has something to judge.
    @discardableResult
    private func write(_ bytes: Int, to relativePath: String, in home: String,
                       daysAgo: Int = 0) throws -> URL {
        let url = URL(fileURLWithPath: home + "/" + relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data(count: bytes).write(to: url)
        if daysAgo > 0 {
            let date = Date().addingTimeInterval(-TimeInterval(daysAgo) * 86_400)
            try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
        }
        return url
    }

    /// Dates an existing entry `daysAgo` days back, so the age threshold has
    /// something to judge.
    private func backdate(_ relativePath: String, in home: String, daysAgo: Int) throws {
        let date = Date().addingTimeInterval(-TimeInterval(daysAgo) * 86_400)
        try FileManager.default.setAttributes([.modificationDate: date],
                                              ofItemAtPath: home + "/" + relativePath)
    }

    /// A fresh defaults suite, so a stored choice never reaches the real app.
    private var defaultsLock: DefaultsSuiteLock?

    private func makeDefaults(_ slot: Int = 0) throws -> UserDefaults {
        if defaultsLock == nil {
            defaultsLock = DefaultsSuiteLock("large-files")
            addTeardownBlock { self.defaultsLock = nil }
        }
        let suiteName = "hexaTests.large-files.\(slot)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        return defaults
    }

    private func thresholds(ageDays: Int = 180,
                            megabytes: Int = 1) -> LargeFiles.Thresholds {
        LargeFiles.Thresholds(ageDays: ageDays,
                              minimumBytes: Int64(megabytes) * LargeFiles.Thresholds.megabyte)
    }

    private func search(_ home: String,
                        thresholds: LargeFiles.Thresholds,
                        cancellation: CleanerSupport.ScanCancellation? = nil)
        -> LargeFiles.SearchResult {
        LargeFiles.search(home: home, thresholds: thresholds, cancellation: cancellation)
    }

    /// Requests the on-demand search and waits for its list, the way the
    /// surface does. A nil `thresholds` keeps the persisted choice, so a test
    /// can prove the search reads what the user saved.
    private func measure(_ cleaner: JunkCleaner, home: String,
                         thresholds chosen: LargeFiles.Thresholds?,
                         defaults: UserDefaults = .standard) throws -> LargeFiles.SearchResult {
        cleaner.measureLargeFiles(home: home, thresholds: chosen, defaults: defaults)
        XCTAssertTrue(cleaner.largeFilesIsComputing, "the request starts the search")
        let deadline = Date().addingTimeInterval(Self.testDeadline)
        while cleaner.largeFilesIsComputing, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        XCTAssertFalse(cleaner.largeFilesIsComputing, Self.deadlineMessage)
        return try XCTUnwrap(cleaner.largeFiles)
    }

    /// Waits for the report of a confirmed removal.
    private func waitForRemoval(_ cleaner: JunkCleaner) throws -> [LargeFiles.RemovalReport] {
        let deadline = Date().addingTimeInterval(Self.testDeadline)
        while cleaner.largeFilesRemoval == nil, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        return try XCTUnwrap(cleaner.largeFilesRemoval, Self.deadlineMessage)
    }

    /// The source of a file of this repository, for the rules only the code of
    /// the walk itself can prove.
    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests/hexaTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repository root
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    private func makeCleaner() -> JunkCleaner {
        let cleaner = JunkCleaner()
        addTeardownBlock { cleaner.reset() }
        return cleaner
    }

    /// The source between two markers, so a rule about one piece of the view is
    /// checked without the rest of the file answering for it.
    private func block(in source: String, from start: String, to end: String) throws -> String {
        let startRange = try XCTUnwrap(source.range(of: start), "missing \(start)")
        let endRange = try XCTUnwrap(source.range(of: end, range: startRange.upperBound..<source.endIndex),
                                     "missing \(end) after \(start)")
        return String(source[startRange.lowerBound..<endRange.lowerBound])
    }

    // MARK: - AC-2.1.1: both thresholds, and the saved choice is the one used

    func testThresholdsAndInitialSelection() throws {
        let home = try makeHome()
        let oldBig = try write(3_000_000, to: "docs/tese.pdf", in: home, daysAgo: 400)
        try write(2_000, to: "docs/nota.txt", in: home, daysAgo: 400)
        try write(3_000_000, to: "docs/recente.mp4", in: home, daysAgo: 1)

        let result = search(home, thresholds: thresholds(ageDays: 180, megabytes: 2))
        XCTAssertEqual(result.candidates.map(\.id), [oldBig.standardizedFileURL.path],
                       "old and small, and big and new, are both out")
        XCTAssertFalse(result.cancelled)
        XCTAssertTrue(result.denied.isEmpty)

        // The size of a file is read the way the Cleaner reads it.
        let candidate = try XCTUnwrap(result.candidates.first)
        XCTAssertEqual(candidate.size, JunkCleaner.directorySize(of: oldBig, fm: .default))
        XCTAssertFalse(candidate.isPackage)

        // Nothing starts marked, and the group starts collapsed.
        XCTAssertFalse(Mirror(reflecting: candidate).children.contains { $0.label == "include" },
                       "a candidate carries no selection: the user marks what they want")
        let cleaner = makeCleaner()
        let published = try measure(cleaner, home: home, thresholds: thresholds(ageDays: 180, megabytes: 2))
        XCTAssertFalse(cleaner.largeFilesExpanded, "the result group starts collapsed")
        XCTAssertTrue(cleaner.items.isEmpty, "the list never enters the Cleaner's own items")
        XCTAssertEqual(published.candidates.count, 1)

        // The search reads the saved thresholds, not the defaults of D9: this
        // file is only offered when the user saved 30 days and 100 MB.
        let big = try write(105_000_000, to: "docs/backup.zip", in: home, daysAgo: 120)
        XCTAssertFalse(search(home, thresholds: .standard).candidates.contains { $0.id == big.standardizedFileURL.path },
                       "the defaults of D9 would skip this file")
        let saved = try makeDefaults()
        saved.set(30, forKey: DefaultsKey.cleanerLargeFileAgeDays)
        saved.set(100, forKey: DefaultsKey.cleanerLargeFileSizeMegabytes)
        let persisted = try measure(makeCleaner(), home: home, thresholds: nil, defaults: saved)
        XCTAssertEqual(persisted.candidates.map(\.id), [big.standardizedFileURL.path],
                       "the search must use the thresholds the user saved")
    }

    // MARK: - AC-2.1.1 and CN8: the exclusions, and a package as one item

    func testExclusionsAndPackages() throws {
        let home = try makeHome()
        let outside = try makeHome()

        let visible = try write(3_000_000, to: "projects/large.mov", in: home, daysAgo: 400)
        // Hidden entry, both as a folder and as a file.
        try write(3_000_000, to: ".hidden/large.bin", in: home, daysAgo: 400)
        try write(3_000_000, to: "projects/.secreto.bin", in: home, daysAgo: 400)
        // System folders of the home, and this app's own data.
        try write(3_000_000, to: "Library/Caches/large.bin", in: home, daysAgo: 400)
        try write(3_000_000, to: "Library/Application Support/hexa/store.bin", in: home, daysAgo: 400)
        try write(3_000_000, to: "Applications/large.bin", in: home, daysAgo: 400)
        // The Trash.
        try write(3_000_000, to: ".Trash/large.bin", in: home, daysAgo: 400)
        // A package is one item, and its contents are never offered.
        let package = URL(fileURLWithPath: home + "/Fotos.photoslibrary", isDirectory: true)
        try write(3_000_000, to: "Fotos.photoslibrary/originals/large.heic", in: home, daysAgo: 400)
        try backdate("Fotos.photoslibrary", in: home, daysAgo: 400)
        // Links are neither listed nor followed, so nothing outside the home is
        // ever reached.
        let outsideFile = try write(3_000_000, to: "externo.bin", in: outside, daysAgo: 400)
        try FileManager.default.createSymbolicLink(atPath: home + "/link.bin",
                                                   withDestinationPath: outsideFile.path)
        try FileManager.default.createSymbolicLink(atPath: home + "/linkdir",
                                                   withDestinationPath: outside)

        let result = search(home, thresholds: thresholds(ageDays: 180, megabytes: 2))
        let paths = result.candidates.map(\.id)

        XCTAssertEqual(paths.sorted(), [package.standardizedFileURL.path, visible.standardizedFileURL.path].sorted(),
                       "only the user's own file and the whole package are offered")
        XCTAssertFalse(paths.contains { $0.contains(".photoslibrary/") },
                       "a package is never decomposed")
        XCTAssertFalse(paths.contains { $0.contains("link") }, "a link is never offered")
        XCTAssertTrue(paths.allSatisfy { $0.hasPrefix(home + "/") },
                      "nothing outside the home is offered")
        XCTAssertFalse(paths.contains(outsideFile.standardizedFileURL.path))

        // The reasons are named, so the surface can explain them later.
        let homeURL = URL(fileURLWithPath: home, isDirectory: true)
        XCTAssertEqual(LargeFiles.exclusion(for: URL(fileURLWithPath: home + "/.Trash/x"), home: homeURL, values: nil), .trash)
        XCTAssertEqual(LargeFiles.exclusion(for: URL(fileURLWithPath: home + "/Library/x"), home: homeURL, values: nil), .systemDirectory)
        XCTAssertEqual(LargeFiles.exclusion(for: URL(fileURLWithPath: home + "/Library/Application Support/hexa/x"), home: homeURL, values: nil), .ownData)
        XCTAssertEqual(LargeFiles.exclusion(for: URL(fileURLWithPath: home + "/link.bin"), home: homeURL, values: nil), .symbolicLink)
        XCTAssertEqual(LargeFiles.exclusion(for: URL(fileURLWithPath: home + "/.hidden/x"), home: homeURL, values: nil), .hidden)
        XCTAssertEqual(LargeFiles.exclusion(for: URL(fileURLWithPath: outside + "/externo.bin"), home: homeURL, values: nil), .outsideHome)
        XCTAssertNil(LargeFiles.exclusion(for: visible, home: homeURL, values: nil))

        // A cloud item is only offered with its current version on disk.
        XCTAssertTrue(LargeFiles.isCloudPlaceholder(isUbiquitous: true, status: .notDownloaded))
        XCTAssertTrue(LargeFiles.isCloudPlaceholder(isUbiquitous: true, status: .downloaded),
                      "an outdated copy is not the file the age threshold judges")
        XCTAssertFalse(LargeFiles.isCloudPlaceholder(isUbiquitous: false, status: .notDownloaded))
        XCTAssertFalse(LargeFiles.isCloudPlaceholder(isUbiquitous: true,
                                                     status: URLUbiquitousItemDownloadingStatus.current))
    }

    // MARK: - AC-2.1.2: only the confirmed item moves, a swapped item is refused

    func testConfirmedTrashAndFailures() throws {
        let home = try makeHome()
        let first = try write(3_000_000, to: "docs/primeiro.bin", in: home, daysAgo: 400)
        let second = try write(3_000_000, to: "docs/segundo.bin", in: home, daysAgo: 400)
        let plan = thresholds(ageDays: 180, megabytes: 2)
        let found = search(home, thresholds: plan)
        XCTAssertEqual(found.candidates.count, 2)

        let firstCandidate = try XCTUnwrap(found.candidates.first { $0.id == first.standardizedFileURL.path })
        let secondCandidate = try XCTUnwrap(found.candidates.first { $0.id == second.standardizedFileURL.path })

        var trashed: [URL] = []
        let reports = LargeFiles.trash([firstCandidate], confirmed: true, home: home,
                                       thresholds: plan, trash: { trashed.append($0) })
        XCTAssertEqual(trashed.map(\.standardizedFileURL.path), [first.standardizedFileURL.path],
                       "only the confirmed item reaches the Trash")
        XCTAssertEqual(reports.count, 1)
        XCTAssertEqual(reports.first?.outcome, .movedToTrash(size: firstCandidate.size))

        // The same file replaced by another one of the same name and size: a
        // different inode is not what the user reviewed, so it is refused and
        // reported, and it never reaches the Trash.
        try FileManager.default.removeItem(at: second)
        try write(3_000_000, to: "docs/segundo.bin", in: home, daysAgo: 400)
        var swappedTrashed: [URL] = []
        let swapped = LargeFiles.trash([secondCandidate], confirmed: true, home: home,
                                       thresholds: plan, trash: { swappedTrashed.append($0) })
        XCTAssertTrue(swappedTrashed.isEmpty, "a replaced file must never reach the Trash")
        XCTAssertEqual(swapped.map(\.outcome), [.refused])

        // A file replaced by a symbolic link is refused too.
        let third = try write(3_000_000, to: "docs/terceiro.bin", in: home, daysAgo: 400)
        let thirdCandidate = try XCTUnwrap(search(home, thresholds: plan).candidates
            .first { $0.id == third.standardizedFileURL.path })
        try FileManager.default.removeItem(at: third)
        try FileManager.default.createSymbolicLink(atPath: third.path,
                                                   withDestinationPath: first.path)
        var linkedTrashed: [URL] = []
        let linked = LargeFiles.trash([thirdCandidate], confirmed: true, home: home,
                                      thresholds: plan, trash: { linkedTrashed.append($0) })
        XCTAssertTrue(linkedTrashed.isEmpty, "a link must never reach the Trash")
        XCTAssertEqual(linked.map(\.outcome), [.refused])

        // The same proof through the service: the seam receives exactly the
        // marked URL, and what moved leaves the list while what stayed is kept.
        let cleaner = makeCleaner()
        let list = try measure(cleaner, home: home, thresholds: plan)
        let target = try XCTUnwrap(list.candidates.first)
        var serviceTrashed: [URL] = []
        cleaner.trashLargeFiles(ids: [target.id], confirmed: true, home: home,
                                thresholds: plan, trash: { serviceTrashed.append($0) })
        let serviceReports = try waitForRemoval(cleaner)
        XCTAssertEqual(serviceTrashed.map(\.standardizedFileURL.path), [target.url.standardizedFileURL.path])
        XCTAssertEqual(serviceReports.count, 1)
        XCTAssertFalse(serviceReports[0].isFailure)
        XCTAssertFalse(cleaner.largeFiles?.candidates.contains { $0.id == target.id } ?? true,
                       "what moved is gone from the list")
    }

    // MARK: - AC-2.1.3: nothing is marked, and no confirmation means no move

    func testNoUnconfirmedTrash() throws {
        let home = try makeHome()
        try write(3_000_000, to: "docs/a.bin", in: home, daysAgo: 400)
        try write(3_000_000, to: "docs/b.bin", in: home, daysAgo: 400)
        let plan = thresholds(ageDays: 180, megabytes: 2)
        let found = search(home, thresholds: plan)
        XCTAssertEqual(found.candidates.count, 2)

        var trashed: [URL] = []
        let reports = LargeFiles.trash(found.candidates, confirmed: false, home: home,
                                       thresholds: plan, trash: { trashed.append($0) })
        XCTAssertTrue(trashed.isEmpty, "without a confirmation nothing moves")
        XCTAssertTrue(reports.isEmpty)

        // The service refuses the same way, and the list keeps both items.
        let cleaner = makeCleaner()
        let list = try measure(cleaner, home: home, thresholds: plan)
        var serviceTrashed: [URL] = []
        cleaner.trashLargeFiles(ids: Set(list.candidates.map(\.id)), confirmed: false, home: home,
                                thresholds: plan, trash: { serviceTrashed.append($0) })
        let deadline = Date().addingTimeInterval(1)
        while Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
        XCTAssertTrue(serviceTrashed.isEmpty)
        XCTAssertNil(cleaner.largeFilesRemoval)
        XCTAssertEqual(cleaner.largeFiles?.candidates.count, 2, "an unconfirmed removal keeps the list")
    }

    // MARK: - AC-2.1.4: entries, a back that restores the origin, inspection

    func testNavigationAndInspection() throws {
        let view = try source("Sources/Hexa/UI/Cleaner/CleanerView.swift")

        // An entry control in the idle state, in both its flavours, and in the
        // results state: the list is reachable without a scan.
        let workspaceIdle = try block(in: view, from: "private var workspaceIdleState",
                                      to: "private var compactIdleState")
        XCTAssertTrue(workspaceIdle.contains("largeFilesEntry(from: .idle)"),
                      "the idle screen offers the list")
        let compactIdle = try block(in: view, from: "private var compactIdleState",
                                    to: "private var automaticRunLine")
        XCTAssertTrue(compactIdle.contains("largeFilesEntry(from: .idle)"),
                      "the compact idle screen offers the list")
        let results = try block(in: view, from: "private var resultsState",
                                to: "private var resultsHeader")
        XCTAssertTrue(results.contains("largeFilesEntry(from: .results)"),
                      "the results screen offers the list")
        XCTAssertTrue(view.contains("} else if largeFilesOrigin != nil {"),
                      "the list is an internal route of the Cleaner, not a phase of a scan")

        // Back restores the origin. The route only drops itself: the Cleaner's
        // phase, its items and their selection are never reset.
        let close = try block(in: view, from: "private func closeLargeFiles",
                              to: "private func startLargeFilesSearch")
        XCTAssertTrue(close.contains("largeFilesOrigin = nil"))
        for forbidden in ["reset()", "cleanSelected", ".scan("] {
            XCTAssertFalse(close.contains(forbidden),
                           "Back must restore the origin instead of restarting the Cleaner: \(forbidden)")
        }
        let header = try block(in: view, from: "private var largeFilesHeader",
                               to: "private var largeFilesBackTitle")
        XCTAssertTrue(header.contains("{ closeLargeFiles() }"), "the Back button closes the route")
        let backTitle = try block(in: view, from: "private var largeFilesBackTitle",
                                  to: "private var largeFilesThresholdsLine")
        XCTAssertTrue(backTitle.contains("largeFilesOrigin == .results"),
                      "the origin is remembered and decides where Back returns to")

        // Each row carries the four fields and the two inspection actions, and
        // both receive the chosen item.
        let row = try block(in: view, from: "private func largeFilesRow",
                            to: "private func largeFilesReport")
        XCTAssertTrue(row.contains("candidate.name"), "the row shows the name")
        XCTAssertTrue(row.contains("abbreviateHome(candidate.url)"), "the row shows the path")
        XCTAssertTrue(row.contains("Self.byteString(candidate.size)"), "the row shows the size")
        XCTAssertTrue(row.contains("Self.largeFilesDate(candidate.modified)"), "the row shows the date")
        XCTAssertTrue(row.contains("revealInFinder(candidate.url)"), "Finder receives the chosen item")
        XCTAssertTrue(row.contains("LargeFilesQuickLook.show(candidate.url)"),
                      "Quick Look receives the chosen item")
        XCTAssertFalse(row.contains("trashLargeFiles"), "a row never removes anything")

        // The group starts collapsed and nothing is marked by the app.
        let group = try block(in: view, from: "private func largeFilesGroup",
                              to: "private func largeFilesRow")
        XCTAssertTrue(group.contains("if cleaner.largeFilesExpanded {"),
                      "the rows of the group start collapsed")
        XCTAssertFalse(group.contains("largeFilesMarked.insert("),
                       "opening the group never marks an item")

        // The two thresholds live in Settings, with the fixed choices of the
        // policy and the day label the screenshot picker already uses.
        let settings = try block(in: view, from: "private var settingsContent",
                                 to: "private var scheduleSection")
        XCTAssertTrue(settings.contains("largeFilesThresholdsSection"))
        for key in ["DefaultsKey.cleanerLargeFileAgeDays", "DefaultsKey.cleanerLargeFileSizeMegabytes"] {
            XCTAssertTrue(view.contains("@AppStorage(\(key))"),
                          "\(key) is the saved choice the picker writes")
        }
        let thresholds = try block(in: view, from: "private var largeFilesThresholdsSection",
                                   to: "private static func largeFileSizeLabel")
        XCTAssertTrue(thresholds.contains("CleanerPolicy.largeFileAgeChoices"),
                      "the age offers the fixed choices")
        XCTAssertTrue(thresholds.contains("CleanerPolicy.largeFileSizeChoicesMegabytes"),
                      "the size offers the fixed choices")
        XCTAssertTrue(thresholds.contains("String(format: l10n.s.cleanerScreenshotsAfterFormat, days)"),
                      "the day label is written like the screenshot picker")
        XCTAssertTrue(view.contains("formatter.countStyle = .binary"),
                      "the sizes read as 100 MB, 500 MB, 1 GB and 5 GB")

        // No new surface: the list never becomes a module, a sidebar entry or a
        // window of its own.
        for feature in AppFeature.allCases {
            XCTAssertFalse(feature.rawValue.lowercased().contains("largefile"),
                           "no module was added for the list: \(feature.rawValue)")
            XCTAssertFalse(feature.rawValue.lowercased().contains("spacemap"),
                           "no module was added for the map: \(feature.rawValue)")
        }
        for forbidden in ["WindowGroup(", "NSWindow(", "NSPanel(", "Window("] {
            XCTAssertFalse(view.contains(forbidden), "the list must not open a separate window: \(forbidden)")
        }
    }

    // MARK: - AC-2.1.5: every new text in all fifteen languages

    func testAllLocalizations() throws {
        XCTAssertEqual(AppLanguage.allCases.count, 15)
        // The typographic dash the project forbids in generated text, spelled
        // out so this file carries no literal of it.
        let emDash = "\u{2014}"

        // The keys are read from the struct itself, so a key nobody translated
        // fails here instead of shipping as a blank label.
        let sources = try allLocalizationSources()
        let declaration = try XCTUnwrap(sources["Sources/Hexa/Core/Localization.swift"])
        let declared = try declaredLargeFileKeys(in: declaration)
        XCTAssertFalse(declared.isEmpty, "the struct declares the new keys")

        // One declaration plus one argument per language: fifteen constructors
        // and the declaration must agree.
        let everything = sources.values.joined(separator: "\n")
        for key in declared {
            XCTAssertEqual(everything.components(separatedBy: "\(key):").count - 1, 16,
                           "\(key) must be declared and present in all fifteen languages")
        }

        for language in AppLanguage.allCases {
            let values = stringValues(of: Strings.localized(language))
            for key in declared {
                let value = values[key] ?? ""
                XCTAssertFalse(value.isEmpty, "\(key) is empty in \(language.rawValue)")
                XCTAssertFalse(value.contains(emDash),
                               "\(key) carries an em dash in \(language.rawValue)")
            }
        }

        // The formats take the arguments the surface passes, so a translator
        // cannot drop a placeholder.
        let placeholders: [String: Int] = [
            "largeFilesThresholdsFormat": 2,
            "largeFilesGroupFormat": 2,
            "largeFilesReportSummaryFormat": 2,
            "largeFilesConfirmMessageFormat": 2,
            "largeFilesSelectedFormat": 3,
            "largeFilesMovedFormat": 1,
            "largeFilesRefusedFormat": 1,
            "largeFilesFailedFormat": 1,
        ]
        for language in AppLanguage.allCases {
            let strings = Strings.localized(language)
            let values = stringValues(of: strings)
            for (key, count) in placeholders {
                let value = values[key] ?? ""
                XCTAssertEqual(value.components(separatedBy: "%").count - 1, count,
                               "\(key) keeps its \(count) placeholders in \(language.rawValue)")
            }
        }
    }

    /// The source of every file of the language base, keyed by its repository
    /// path: the two constructors of `Localization.swift` plus the thirteen
    /// files of `Localizations/`.
    private func allLocalizationSources() throws -> [String: String] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests/hexaTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repository root
        let directory = root.appendingPathComponent("Sources/Hexa/Core/Localizations")
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix("Strings+") && $0.hasSuffix(".swift") }
            .sorted()
        XCTAssertEqual(names.count, 13,
                       "fifteen languages: two in Localization.swift and thirteen here")

        var sources: [String: String] = [:]
        sources["Sources/Hexa/Core/Localization.swift"] =
            try source("Sources/Hexa/Core/Localization.swift")
        for name in names {
            let path = "Sources/Hexa/Core/Localizations/\(name)"
            sources[path] = try source(path)
        }
        return sources
    }

    /// The key names the `Strings` struct declares for the list, read from the
    /// declaration itself.
    private func declaredLargeFileKeys(in source: String) throws -> [String] {
        let structStart = try XCTUnwrap(source.range(of: "\nstruct Strings {"))
        let structEnd = try XCTUnwrap(source.range(of: "\n}\n",
                                                   range: structStart.upperBound..<source.endIndex),
                                      "the struct must close at column zero")
        let body = source[structStart.upperBound..<structEnd.lowerBound]
        return body.split(separator: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("let largeFiles"),
                  let colon = trimmed.firstIndex(of: ":") else { return nil }
            return String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 4)..<colon])
        }
    }

    /// The string values of one language, keyed by the name of the property.
    private func stringValues(of strings: Strings) -> [String: String] {
        var values: [String: String] = [:]
        for child in Mirror(reflecting: strings).children {
            guard let label = child.label, let value = child.value as? String else { continue }
            values[label] = value
        }
        return values
    }

    // MARK: - AC-2.1.6: a running search shows loading, and stale lists never land

    func testLoading() throws {
        let home = try makeHome()
        try write(3_000_000, to: "docs/a.bin", in: home, daysAgo: 400)
        let plan = thresholds(ageDays: 180, megabytes: 2)
        let cleaner = makeCleaner()

        XCTAssertFalse(cleaner.largeFilesIsComputing, "nothing searches before the request")
        XCTAssertNil(cleaner.largeFiles)

        cleaner.measureLargeFiles(home: home, thresholds: plan)
        XCTAssertTrue(cleaner.largeFilesIsComputing, "the surface shows the search in progress")
        let deadline = Date().addingTimeInterval(Self.testDeadline)
        while cleaner.largeFilesIsComputing, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        XCTAssertFalse(cleaner.largeFilesIsComputing, Self.deadlineMessage)
        XCTAssertEqual(cleaner.largeFiles?.candidates.count, 1)

        // A snapshot of a superseded run never publishes over the current list.
        let stale = LargeFiles.SearchResult.empty
        cleaner.publishLargeFiles(stale, token: UUID())
        XCTAssertEqual(cleaner.largeFiles?.candidates.count, 1,
                       "an obsolete list must not replace the current one")
        cleaner.publishLargeFiles(stale, token: cleaner.largeFilesToken)
        XCTAssertEqual(cleaner.largeFiles?.candidates.count, 0, "the current run still publishes")

        // On the surface: the search in progress is shown, and the Trash is not
        // offered while a result a running search can still replace is on screen.
        let view = try source("Sources/Hexa/UI/Cleaner/CleanerView.swift")
        let states = try block(in: view, from: "private var largeFilesStates",
                               to: "private func largeFilesDenials")
        XCTAssertTrue(states.contains("ProgressView()"), "a requested search shows progress")
        XCTAssertTrue(states.contains("l10n.s.largeFilesSearching"))
        XCTAssertTrue(states.contains("if state == .empty {"),
                      "an empty list is shown only once the search finished")

        // What the surface shows for each combination of the published values.
        XCTAssertEqual(CleanerView.largeFilesListState(isComputing: true, result: nil), .searching)
        XCTAssertEqual(CleanerView.largeFilesListState(isComputing: true, result: .empty), .searching)
        XCTAssertEqual(CleanerView.largeFilesListState(isComputing: false, result: .empty), .empty)
        XCTAssertEqual(CleanerView.largeFilesListState(isComputing: false, result: nil), .listing)

        // The removal is disabled while the search runs and while a batch is in
        // flight, so a click is never dropped without the user knowing.
        XCTAssertTrue(CleanerView.largeFilesRemovalIsDisabled(marked: 2, isComputing: true,
                                                             isRemovalPending: false))
        XCTAssertTrue(CleanerView.largeFilesRemovalIsDisabled(marked: 2, isComputing: false,
                                                             isRemovalPending: true))
        XCTAssertTrue(CleanerView.largeFilesRemovalIsDisabled(marked: 0, isComputing: false,
                                                             isRemovalPending: false))
        XCTAssertFalse(CleanerView.largeFilesRemovalIsDisabled(marked: 2, isComputing: false,
                                                              isRemovalPending: false))
        let footer = try block(in: view, from: "private var largeFilesFooter",
                               to: "private var largeFilesSelectionSummary")
        XCTAssertTrue(footer.contains("isComputing: cleaner.largeFilesIsComputing"))
        XCTAssertTrue(footer.contains("isRemovalPending: largeFilesRemovalPending"))
    }

    // MARK: - AC-2.1.7: a refusal is a failure, never an empty result or a success

    func testErrors() throws {
        let home = try makeHome()
        try write(3_000_000, to: "docs/legivel.bin", in: home, daysAgo: 400)
        try write(3_000_000, to: "fechada/ilegivel.bin", in: home, daysAgo: 400)
        let refusedRoot = home + "/fechada"
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: refusedRoot)
        addTeardownBlock {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: refusedRoot)
        }

        let plan = thresholds(ageDays: 180, megabytes: 2)
        var found = search(home, thresholds: plan)
        if found.denied.isEmpty {
            // Running as a user who can read everything (root): the denial is
            // then impossible to build here, and only the move failure below
            // applies.
            XCTAssertEqual(geteuid(), 0, "a readable folder under a non-root user is a broken fixture")
        } else {
            // The walk reports the folder it could not read, in the app's own
            // terms, and never turns the refusal into an empty list.
            let denial = try XCTUnwrap(found.denied.first)
            XCTAssertEqual(denial.reason, .accessDenied)
            XCTAssertTrue(LargeFiles.isInside(denial.url.standardizedFileURL.path, refusedRoot),
                          "the refused path is named: \(denial.url.path)")
            XCTAssertEqual(found.candidates.count, 1, "a refusal does not hide the readable candidates")
        }

        // A move that fails is a failure per item, never a success.
        let cleaner = makeCleaner()
        found = try measure(cleaner, home: home, thresholds: plan)
        let target = try XCTUnwrap(found.candidates.first)
        struct MoveError: Error {}
        cleaner.trashLargeFiles(ids: [target.id], confirmed: true, home: home,
                                thresholds: plan, trash: { _ in throw MoveError() })
        let reports = try waitForRemoval(cleaner)
        XCTAssertEqual(reports.map(\.outcome), [.failed])
        XCTAssertTrue(reports[0].isFailure)
        XCTAssertNotNil(cleaner.largeFiles?.candidates.first { $0.id == target.id },
                        "an item that stayed must stay in the list")

        // On the surface: a refused path is shown with its reason, and the
        // report shows a failure as a failure.
        let view = try source("Sources/Hexa/UI/Cleaner/CleanerView.swift")
        let denials = try block(in: view, from: "private func largeFilesDenials",
                                to: "private func largeFilesGroup")
        XCTAssertTrue(denials.contains("l10n.s.spaceInventoryDeniedFormat"))
        XCTAssertTrue(denials.contains("spaceInventoryDenialReason(denial.reason)"),
                      "each refusal carries the path and the reason")
        XCTAssertTrue(denials.contains("HexaTheme.statusWarning"),
                      "a refusal is painted as a warning, never as a result")

        let report = try block(in: view, from: "private func largeFilesReport",
                               to: "private var largeFilesFooter")
        XCTAssertTrue(report.contains("case .refused:"))
        XCTAssertTrue(report.contains("case .failed:"))
        XCTAssertTrue(report.contains("report.isFailure ? HexaTheme.statusWarning"),
                      "what failed is painted as a failure")
        XCTAssertTrue(report.contains("l10n.s.largeFilesReportSummaryFormat"))
        XCTAssertEqual(view.components(separatedBy: "largeFilesMovedFormat").count - 1, 1,
                       "the moved wording is used only for an item that moved")
    }

    // MARK: - AC-2.1.8: an empty search is a result, not a search still running

    func testEmpty() throws {
        let home = try makeHome()
        try write(2_000, to: "docs/pequeno.txt", in: home, daysAgo: 400)

        let result = search(home, thresholds: thresholds(ageDays: 180, megabytes: 2))
        XCTAssertTrue(result.isEmpty)
        XCTAssertTrue(result.candidates.isEmpty)
        XCTAssertTrue(result.denied.isEmpty)
        XCTAssertFalse(result.cancelled)

        let cleaner = makeCleaner()
        let published = try measure(cleaner, home: home, thresholds: thresholds(ageDays: 180, megabytes: 2))
        XCTAssertTrue(published.isEmpty)
        XCTAssertFalse(cleaner.largeFilesIsComputing,
                       "an empty list is a result, not a search still pending")

        // On the surface: an empty result is rendered as empty, never as a
        // search still running.
        XCTAssertEqual(CleanerView.largeFilesListState(isComputing: false, result: published), .empty)
        XCTAssertEqual(CleanerView.largeFilesListState(isComputing: true, result: published), .searching)

        let view = try source("Sources/Hexa/UI/Cleaner/CleanerView.swift")
        let states = try block(in: view, from: "private var largeFilesStates",
                               to: "private func largeFilesDenials")
        XCTAssertTrue(states.contains("l10n.s.largeFilesEmpty"), "an empty list says it is empty")
        XCTAssertTrue(states.contains("if state == .empty {"),
                      "the empty text is guarded by the finished state, so it is never a spinner")
    }

    // MARK: - Cancellation: nothing lands after the fact

    func testCancellation() throws {
        let home = try makeHome()
        try write(3_000_000, to: "docs/a.bin", in: home, daysAgo: 400)
        let plan = thresholds(ageDays: 180, megabytes: 2)

        // A cancelled walk lists nothing further and says it was cancelled.
        let stopped = CleanerSupport.ScanCancellation()
        stopped.cancel()
        let cancelled = search(home, thresholds: plan, cancellation: stopped)
        XCTAssertTrue(cancelled.cancelled)
        XCTAssertTrue(cancelled.candidates.isEmpty)

        // A cancelled run keeps what it found and marks it partial; a late
        // callback of the superseded run publishes nothing, and reset clears
        // everything. The new run has already dropped the rows of the superseded
        // one, so the late callback carries a result with rows: it must not bring
        // them back.
        let cleaner = makeCleaner()
        let superseded = try measure(cleaner, home: home, thresholds: plan)
        let staleToken = cleaner.largeFilesToken
        cleaner.measureLargeFiles(home: home, thresholds: plan)
        let running = try XCTUnwrap(cleaner.largeFilesCancellation)
        cleaner.cancelLargeFiles()
        XCTAssertTrue(running.isCancelled, "the cancel reaches the running walk")
        XCTAssertFalse(cleaner.largeFilesIsComputing)
        XCTAssertEqual(cleaner.largeFiles?.cancelled, true)
        XCTAssertEqual(cleaner.largeFiles?.candidates.count, 0,
                       "the cancelled run found nothing and shows no obsolete rows")
        cleaner.publishLargeFiles(superseded, token: staleToken)
        XCTAssertEqual(cleaner.largeFiles?.candidates.count, 0,
                       "a superseded run must not publish after the cancel")
        XCTAssertEqual(cleaner.largeFiles?.cancelled, true)

        cleaner.reset()
        XCTAssertNil(cleaner.largeFiles)
        XCTAssertNil(cleaner.largeFilesRemoval)
        XCTAssertFalse(cleaner.largeFilesIsComputing)
        XCTAssertFalse(cleaner.largeFilesExpanded)

        // A Cleaner scan starts with no list of its own.
        cleaner.measureLargeFiles(home: home, thresholds: plan)
        cleaner.scan(attended: false, home: home)
        XCTAssertNil(cleaner.largeFiles, "a scan clears the list it does not own")
    }

    // MARK: - A removal during a running search moves nothing and never reappears

    func testRemovalDuringRunningSearchMovesNothing() throws {
        let home = try makeHome()
        let target = try write(3_000_000, to: "docs/durante.bin", in: home, daysAgo: 400)
        let plan = thresholds(ageDays: 180, megabytes: 2)
        let cleaner = makeCleaner()
        let list = try measure(cleaner, home: home, thresholds: plan)
        let candidate = try XCTUnwrap(list.candidates.first { $0.id == target.standardizedFileURL.path })

        // A second search starts. Its snapshots can still list the item the user
        // confirms now, so the confirmation must not run against the list yet.
        cleaner.measureLargeFiles(home: home, thresholds: plan)
        XCTAssertTrue(cleaner.largeFilesIsComputing, "the second search is running")
        var trashed: [URL] = []
        cleaner.trashLargeFiles(ids: [candidate.id], confirmed: true, home: home,
                                thresholds: plan, trash: { trashed.append($0) })
        let deadline = Date().addingTimeInterval(Self.testDeadline)
        while cleaner.largeFilesIsComputing, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        XCTAssertFalse(cleaner.largeFilesIsComputing, Self.deadlineMessage)
        XCTAssertTrue(trashed.isEmpty, "a removal during a running search must not reach the Trash")
        XCTAssertNil(cleaner.largeFilesRemoval, "nothing moved, so no removal is reported")
        XCTAssertTrue(FileManager.default.fileExists(atPath: target.path), "the file stays where it was")
        XCTAssertNotNil(cleaner.largeFiles?.candidates.first { $0.id == candidate.id },
                        "the finished list still offers the file that did not move")

        // Once the search has finished, the same confirmation works normally,
        // and what moved does not come back in the list.
        cleaner.trashLargeFiles(ids: [candidate.id], confirmed: true, home: home,
                                thresholds: plan, trash: { trashed.append($0) })
        let reports = try waitForRemoval(cleaner)
        XCTAssertEqual(trashed.map(\.standardizedFileURL.path), [target.standardizedFileURL.path])
        XCTAssertEqual(reports.map(\.outcome), [.movedToTrash(size: candidate.size)])
        XCTAssertFalse(cleaner.largeFiles?.candidates.contains { $0.id == candidate.id } ?? true,
                       "what moved is gone from the list")
    }

    /// A Trash seam that parks its first call until the test releases it, so a
    /// confirmed batch can be held in flight while the test drives the surface.
    /// Later calls are recorded and return at once.
    private final class ParkedTrash {
        private let lock = NSLock()
        private var calls: [String] = []
        private let parked = DispatchSemaphore(value: 0)
        private let released = DispatchSemaphore(value: 0)

        var paths: [String] {
            lock.lock()
            defer { lock.unlock() }
            return calls
        }

        func trash(_ url: URL) {
            lock.lock()
            calls.append(url.standardizedFileURL.path)
            let isFirst = calls.count == 1
            lock.unlock()
            guard isFirst else { return }
            parked.signal()
            _ = released.wait(timeout: .now() + 60)
        }

        /// True once the first call is parked; false when the bounded wait expires.
        func waitUntilParked(timeout: TimeInterval) -> Bool {
            parked.wait(timeout: .now() + timeout) == .success
        }

        func release() { released.signal() }
    }

    // MARK: - A batch in flight is never overlapped by a search or a second batch

    func testSearchAndSecondBatchWaitForRunningBatch() throws {
        let home = try makeHome()
        let moving = try write(3_000_000, to: "docs/lote-a.bin", in: home, daysAgo: 400)
        let staying = try write(3_000_000, to: "docs/lote-b.bin", in: home, daysAgo: 400)
        let plan = thresholds(ageDays: 180, megabytes: 2)
        let cleaner = makeCleaner()
        let list = try measure(cleaner, home: home, thresholds: plan)
        XCTAssertEqual(list.candidates.count, 2)
        let movingId = moving.standardizedFileURL.path
        let stayingId = staying.standardizedFileURL.path
        let listedBefore = list.candidates.map(\.id)

        // The first batch starts and is parked inside the seam: it is in flight.
        let parked = ParkedTrash()
        addTeardownBlock { parked.release() }
        let guardTimeout: TimeInterval = 30
        cleaner.trashLargeFiles(ids: [movingId], confirmed: true, home: home,
                                thresholds: plan, trash: { parked.trash($0) })
        XCTAssertTrue(parked.waitUntilParked(timeout: guardTimeout), "the batch reaches the Trash seam")

        // A search requested now must not start: a walk could publish the item
        // the batch is moving. Nothing changes state.
        cleaner.measureLargeFiles(home: home, thresholds: plan)
        XCTAssertFalse(cleaner.largeFilesIsComputing, "a search must not start while a batch moves items")
        XCTAssertEqual(cleaner.largeFiles?.candidates.map(\.id), listedBefore,
                       "the list is unchanged while the batch runs")

        // A second confirmed batch while the first runs is refused: it moves nothing.
        cleaner.trashLargeFiles(ids: [stayingId], confirmed: true, home: home,
                                thresholds: plan, trash: { parked.trash($0) })

        // Release the first batch and wait for its report, bounded by the guard.
        parked.release()
        let deadline = Date().addingTimeInterval(guardTimeout)
        while cleaner.largeFilesRemoval == nil, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        let reports = try XCTUnwrap(cleaner.largeFilesRemoval,
                                    "the batch reports its removal once it finishes")

        XCTAssertEqual(parked.paths, [movingId], "exactly one move: the item of the first batch")
        XCTAssertEqual(reports.map(\.id), [movingId])
        XCTAssertFalse(reports[0].isFailure)
        XCTAssertFalse(cleaner.largeFiles?.candidates.contains { $0.id == movingId } ?? true,
                       "what moved is gone from the list")
        XCTAssertTrue(cleaner.largeFiles?.candidates.contains { $0.id == stayingId } ?? false,
                      "the item the refused batch named is still offered")
        XCTAssertTrue(FileManager.default.fileExists(atPath: staying.path), "the refused item stays where it was")
    }

    // MARK: - A scan during a running batch keeps the report and never resurrects the list

    /// Waits for the report of a removal for at most `timeout` seconds and
    /// returns what it holds, so a missing report fails at the bound.
    private func waitForReport(_ cleaner: JunkCleaner,
                               timeout: TimeInterval) -> [LargeFiles.RemovalReport]? {
        let deadline = Date().addingTimeInterval(timeout)
        while cleaner.largeFilesRemoval == nil, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        return cleaner.largeFilesRemoval
    }

    func testScanDuringRunningBatchKeepsReportWithoutResurrectingList() throws {
        let home = try makeHome()
        let moving = try write(3_000_000, to: "docs/lote-scan.bin", in: home, daysAgo: 400)
        let plan = thresholds(ageDays: 180, megabytes: 2)
        let cleaner = makeCleaner()
        let list = try measure(cleaner, home: home, thresholds: plan)
        let movingId = moving.standardizedFileURL.path
        let candidate = try XCTUnwrap(list.candidates.first { $0.id == movingId })

        // The batch is parked inside the seam, so it is in flight. Once released,
        // the seam removes the file as the Trash would, so a later search cannot
        // find it on disk.
        let parked = ParkedTrash()
        addTeardownBlock { parked.release() }
        let guardTimeout: TimeInterval = 30
        cleaner.trashLargeFiles(ids: [candidate.id], confirmed: true, home: home, thresholds: plan,
                                trash: { url in
                                    parked.trash(url)
                                    try? FileManager.default.removeItem(at: url)
                                })
        XCTAssertTrue(parked.waitUntilParked(timeout: guardTimeout), "the batch reaches the Trash seam")

        // A scan starts while the batch is in flight. It clears the list, which
        // rotates the search token; the report of the batch must still arrive.
        cleaner.scan(attended: false, home: home)
        XCTAssertNil(cleaner.largeFiles, "the scan clears the list")

        parked.release()
        let reports = try XCTUnwrap(waitForReport(cleaner, timeout: guardTimeout),
                                    "the batch reports its removal even after a scan")
        XCTAssertEqual(parked.paths, [movingId], "exactly one move: the item of the batch")
        // The report names the moved file by its name: its id is derived from the
        // path after the move, which a symlinked temporary root can change.
        XCTAssertEqual(reports.map(\.url.lastPathComponent), ["lote-scan.bin"])
        XCTAssertEqual(reports.map(\.outcome), [.movedToTrash(size: candidate.size)])
        XCTAssertNil(cleaner.largeFiles, "the report never recreates the list the scan cleared")

        // A later search reads the disk again and no longer offers the moved file.
        let later = try measure(cleaner, home: home, thresholds: plan)
        XCTAssertFalse(later.candidates.contains { $0.name == "lote-scan.bin" },
                       "a later list does not resurrect the moved file")
        XCTAssertFalse(FileManager.default.fileExists(atPath: moving.path))
    }

    // MARK: - The stored thresholds are always one of the fixed choices

    func testSanitizedThresholdsAndPersistedChoice() throws {
        // The fixed choices of D13.
        XCTAssertEqual(CleanerPolicy.largeFileAgeChoices, [30, 90, 180, 365])
        XCTAssertEqual(CleanerPolicy.largeFileSizeChoicesMegabytes, [100, 500, 1024, 5120])

        // A stored value is brought to the nearest choice, never kept.
        XCTAssertEqual(CleanerPolicy.sanitizedLargeFileAgeDays(180), 180)
        XCTAssertEqual(CleanerPolicy.sanitizedLargeFileAgeDays(0), 30)
        XCTAssertEqual(CleanerPolicy.sanitizedLargeFileAgeDays(200), 180)
        XCTAssertEqual(CleanerPolicy.sanitizedLargeFileAgeDays(1000), 365)
        XCTAssertEqual(CleanerPolicy.sanitizedLargeFileSizeMegabytes(300), 100)
        XCTAssertEqual(CleanerPolicy.sanitizedLargeFileSizeMegabytes(800), 1024)
        XCTAssertEqual(CleanerPolicy.sanitizedLargeFileSizeMegabytes(2048), 1024)
        XCTAssertEqual(CleanerPolicy.sanitizedLargeFileSizeMegabytes(999_999), 5120)
        // The extremes of Int, reachable from a restored backup or defaults write,
        // are answered at the ends without overflowing.
        XCTAssertEqual(CleanerPolicy.sanitizedLargeFileAgeDays(Int.min), 30)
        XCTAssertEqual(CleanerPolicy.sanitizedLargeFileAgeDays(Int.max), 365)
        XCTAssertEqual(CleanerPolicy.sanitizedLargeFileSizeMegabytes(Int.min), 100)
        XCTAssertEqual(CleanerPolicy.sanitizedLargeFileSizeMegabytes(Int.max), 5120)

        // A key that was never written falls back to 180 days and 500 MB.
        let fresh = try makeDefaults()
        XCTAssertEqual(LargeFiles.Thresholds.persisted(in: fresh), LargeFiles.Thresholds.standard)
        XCTAssertEqual(LargeFiles.Thresholds.standard.ageDays, 180)
        XCTAssertEqual(LargeFiles.Thresholds.standard.minimumBytes, 500 * LargeFiles.Thresholds.megabyte)

        // A restored backup cannot inject an arbitrary number.
        let restored = try makeDefaults(1)
        restored.set(7, forKey: DefaultsKey.cleanerLargeFileAgeDays)
        restored.set(999_999, forKey: DefaultsKey.cleanerLargeFileSizeMegabytes)
        XCTAssertEqual(LargeFiles.Thresholds.persisted(in: restored),
                       LargeFiles.Thresholds(ageDays: 30, minimumBytes: 5120 * LargeFiles.Thresholds.megabyte))

        let extreme = try makeDefaults(2)
        extreme.set(Int.min, forKey: DefaultsKey.cleanerLargeFileAgeDays)
        extreme.set(Int.max, forKey: DefaultsKey.cleanerLargeFileSizeMegabytes)
        XCTAssertEqual(LargeFiles.Thresholds.persisted(in: extreme),
                       LargeFiles.Thresholds(ageDays: 30, minimumBytes: 5120 * LargeFiles.Thresholds.megabyte))

        // Both thresholds, at their exact boundary.
        let plan = LargeFiles.Thresholds(ageDays: 180, minimumBytes: 1000)
        let now = Date()
        let oldest = now.addingTimeInterval(-180 * 86_400)
        XCTAssertTrue(plan.accepts(size: 1000, modified: oldest, now: now))
        XCTAssertFalse(plan.accepts(size: 999, modified: oldest, now: now))
        XCTAssertFalse(plan.accepts(size: 1000, modified: oldest.addingTimeInterval(1), now: now))
        XCTAssertFalse(plan.accepts(size: 0, modified: oldest, now: now))
    }

    // MARK: - F1, F2, F3 and the edge cases: the surface never shows the wrong list

    /// The states block of the list, where the rules of what is drawn live.
    private func listStatesSource() throws -> String {
        let view = try source("Sources/Hexa/UI/Cleaner/CleanerView.swift")
        return try block(in: view, from: "private var largeFilesStates",
                         to: "private func largeFilesDenials")
    }

    /// F1: a search cancelled before its first match, with no list published
    /// before it, still publishes a result, so the surface says it was cancelled.
    func testCancelledSearchWithNothingFoundIsPublished() throws {
        let home = try makeHome()
        try write(3_000_000, to: "docs/a.bin", in: home, daysAgo: 400)
        let plan = thresholds(ageDays: 180, megabytes: 2)

        let cleaner = makeCleaner()
        XCTAssertNil(cleaner.largeFiles, "nothing is published before the first search")
        cleaner.measureLargeFiles(home: home, thresholds: plan)
        XCTAssertTrue(cleaner.largeFilesIsComputing)
        cleaner.cancelLargeFiles()
        XCTAssertFalse(cleaner.largeFilesIsComputing)
        let published = try XCTUnwrap(cleaner.largeFiles,
                                      "a cancelled search publishes its result even when it found nothing")
        XCTAssertTrue(published.cancelled)
        XCTAssertTrue(published.candidates.isEmpty)

        // The surface says it was cancelled: neither a blank list nor the empty headline.
        let state = CleanerView.largeFilesListState(isComputing: false, result: published)
        XCTAssertEqual(state, .cancelled)
        XCTAssertNotEqual(state, .empty, "a cancelled search is not an empty result")
        let states = try listStatesSource()
        XCTAssertTrue(states.contains("if result.cancelled {"), "the cancelled notice is drawn from the result")
        XCTAssertTrue(states.contains("l10n.s.largeFilesCancelled"))
        XCTAssertTrue(states.contains("l10n.s.largeFilesCaption"),
                      "a list with no result yet says what it is, it is never blank")
    }

    /// F3: a new search drops the rows of the previous one before it publishes,
    /// so an obsolete row is never relabelled as this run's partial list.
    func testNewSearchDropsThePreviousRowsBeforePublishing() throws {
        let home = try makeHome()
        try write(3_000_000, to: "docs/antigo.bin", in: home, daysAgo: 400)
        let plan = thresholds(ageDays: 180, megabytes: 2)

        let cleaner = makeCleaner()
        let earlier = try measure(cleaner, home: home, thresholds: plan)
        let previous = try XCTUnwrap(earlier.candidates.first)

        // The new search starts with the loading state only.
        cleaner.measureLargeFiles(home: home, thresholds: plan)
        XCTAssertTrue(cleaner.largeFilesIsComputing)
        XCTAssertNil(cleaner.largeFiles, "the previous rows are dropped when the new search starts")
        XCTAssertEqual(CleanerView.largeFilesListState(isComputing: true, result: nil), .searching)

        // Cancelled before its first match: the obsolete row does not come back.
        cleaner.cancelLargeFiles()
        let partial = try XCTUnwrap(cleaner.largeFiles)
        XCTAssertTrue(partial.cancelled)
        XCTAssertTrue(partial.candidates.isEmpty, "this run found nothing, so nothing is listed")
        XCTAssertFalse(partial.candidates.contains { $0.id == previous.id },
                       "an obsolete row never reappears as this run's result")

        // The clearing sits on the start path of the search, before any walk runs.
        let cleanerSource = try source("Sources/Hexa/Services/Cleaner/JunkCleaner.swift")
        let start = try block(in: cleanerSource, from: "func measureLargeFiles", to: "func cancelLargeFiles")
        XCTAssertTrue(start.contains("largeFiles = nil"), "the new run drops the list it replaces")
    }

    /// F2: an unreadable home is a refusal, never the empty headline. The empty
    /// headline is only for a finished search with nothing found and nothing refused.
    func testRefusalIsNeverTheEmptyHeadline() throws {
        let home = try makeHome()
        let missing = home + "/nao-existe"
        let plan = thresholds(ageDays: 180, megabytes: 2)

        let cleaner = makeCleaner()
        let refused = try measure(cleaner, home: missing, thresholds: plan)
        XCTAssertTrue(refused.candidates.isEmpty)
        XCTAssertFalse(refused.denied.isEmpty, "the unreadable home is reported as a refusal")
        XCTAssertFalse(refused.cancelled)
        let state = CleanerView.largeFilesListState(isComputing: false, result: refused)
        XCTAssertEqual(state, .refused)
        XCTAssertNotEqual(state, .empty, "a refusal is never the empty headline")

        // A refusal that comes with a cancel is still a refusal.
        let cancelledRefusal = LargeFiles.SearchResult(candidates: [], denied: refused.denied, cancelled: true)
        XCTAssertEqual(CleanerView.largeFilesListState(isComputing: false, result: cancelledRefusal), .refused)

        // Only a finished search with nothing found, nothing refused and no cancel is empty.
        XCTAssertEqual(CleanerView.largeFilesListState(isComputing: false,
                                                       result: LargeFiles.SearchResult.empty), .empty)

        let states = try listStatesSource()
        XCTAssertTrue(states.contains("if state == .empty {"))
        XCTAssertTrue(states.contains("largeFilesDenials(result)"),
                      "refusals are drawn whatever the candidates are")
    }

    /// Edge: the Trash recovers when a second batch reports the same as the first.
    /// Every delivered report is counted, so the pending flag ends on delivery.
    func testReportEqualToThePreviousOneStillEndsTheBatch() throws {
        let home = try makeHome()
        try write(3_000_000, to: "docs/falha.bin", in: home, daysAgo: 400)
        let plan = thresholds(ageDays: 180, megabytes: 2)
        let cleaner = makeCleaner()
        let list = try measure(cleaner, home: home, thresholds: plan)
        let target = try XCTUnwrap(list.candidates.first)
        struct MoveError: Error {}

        var deliveries = 0
        let subscription = cleaner.$largeFilesRemoval.dropFirst().sink { report in
            if report != nil { deliveries += 1 }
        }
        addTeardownBlock { subscription.cancel() }
        let limit = Date().addingTimeInterval(Self.testDeadline)
        func waitForDeliveries(_ count: Int) {
            while deliveries < count, Date() < limit {
                RunLoop.main.run(until: Date().addingTimeInterval(0.02))
            }
        }

        // Both batches fail the same way and leave the same item, so both reports
        // are equal: a comparison of the value would see no change the second time.
        cleaner.trashLargeFiles(ids: [target.id], confirmed: true, home: home, thresholds: plan,
                                trash: { _ in throw MoveError() })
        waitForDeliveries(1)
        let first = cleaner.largeFilesRemoval
        XCTAssertNotNil(first)
        cleaner.trashLargeFiles(ids: [target.id], confirmed: true, home: home, thresholds: plan,
                                trash: { _ in throw MoveError() })
        waitForDeliveries(2)
        XCTAssertEqual(deliveries, 2, "every batch delivers its report, equal or not")
        XCTAssertEqual(cleaner.largeFilesRemoval, first, "the second report equals the first one")

        // The surface ends its pending state on the delivery, never on a change of the value.
        let view = try source("Sources/Hexa/UI/Cleaner/CleanerView.swift")
        let body = try block(in: view, from: "var body: some View {", to: "@ViewBuilder")
        XCTAssertTrue(body.contains(".onReceive(cleaner.$largeFilesRemoval.dropFirst())"),
                      "the report of every batch clears the pending flag")
        XCTAssertFalse(view.contains("onChange(of: cleaner.largeFilesRemoval)"),
                       "a change of the value alone never clears the pending flag")
    }

    /// Edge: while a confirmed batch still moves items, Search now is not
    /// actionable, and neither closing nor reopening the list releases the hold.
    func testSearchAndTrashAreHeldWhileABatchMoves() throws {
        let view = try source("Sources/Hexa/UI/Cleaner/CleanerView.swift")

        let control = try block(in: view, from: "private var largeFilesSearchControl",
                                to: "private var largeFilesStates")
        XCTAssertTrue(control.contains(".disabled(cleaner.largeFilesIsComputing || largeFilesRemovalPending)"),
                      "Search now is not actionable while a confirmed batch is in flight")
        XCTAssertTrue(control.contains("if cleaner.largeFilesIsComputing || largeFilesRemovalPending {"),
                      "a batch in flight shows progress, not only a disabled trigger")
        XCTAssertTrue(control.contains("ProgressView()"),
                      "the in-flight removal shows a progress indicator")

        let remove = try block(in: view, from: "private func removeMarkedLargeFiles",
                               to: "private var largeFilesMarkedCandidates")
        XCTAssertTrue(remove.contains("!cleaner.largeFilesIsComputing"),
                      "the pending flag is set only for a batch the service will run")

        let close = try block(in: view, from: "private func closeLargeFiles",
                              to: "private func startLargeFilesSearch")
        XCTAssertFalse(close.contains("largeFilesRemovalPending = false"),
                       "closing the list keeps a batch in flight holding the Trash and the search")
        let start = try block(in: view, from: "private func startLargeFilesSearch",
                              to: "private static let largeFilesDateFormatter")
        XCTAssertFalse(start.contains("largeFilesRemovalPending = false"),
                       "reopening the list keeps a batch in flight holding the Trash and the search")
    }

    // MARK: - Nothing searches in the background, and the list never cleans

    func testNoBackgroundSearch() throws {
        let largeFiles = try source("Sources/Hexa/Services/Cleaner/LargeFiles.swift")
        let cleaner = try source("Sources/Hexa/Services/Cleaner/JunkCleaner.swift")

        for forbidden in ["Timer", "asyncAfter", "CleanerScheduler", "cleanSelected"] {
            XCTAssertFalse(largeFiles.contains(forbidden),
                           "the search must not carry \(forbidden)")
        }
        let start = try XCTUnwrap(cleaner.range(of: "func measureLargeFiles"))
        let end = cleaner.range(of: "func cancelLargeFiles", range: start.lowerBound..<cleaner.endIndex)
        let body = String(cleaner[start.lowerBound..<(end?.lowerBound ?? cleaner.endIndex)])
        for forbidden in ["Timer", "asyncAfter", "deadline", "timeout", "CleanerScheduler"] {
            XCTAssertFalse(body.contains(forbidden), "the search must not carry \(forbidden)")
        }

        // The removal path goes to the Trash seam and nothing else.
        let trashStart = try XCTUnwrap(largeFiles.range(of: "static func trash("))
        let trashBody = String(largeFiles[trashStart.lowerBound...])
        XCTAssertTrue(trashBody.contains("try trash(candidate.url)"))
        XCTAssertFalse(trashBody.contains("removeItem"), "nothing is deleted in place")
        XCTAssertFalse(trashBody.contains("emptyTrash"))
    }
}
