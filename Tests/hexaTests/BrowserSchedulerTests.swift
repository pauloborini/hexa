// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest
import Combine
@testable import Hexa

final class BrowserSchedulerTests: XCTestCase {
    private var fm: FileManager!
    private var scratchHome: URL!

    override func setUp() {
        super.setUp()
        fm = FileManager.default
        let tempBase = fm.temporaryDirectory.resolvingSymlinksInPath()
        scratchHome = tempBase.appendingPathComponent("BrowserSchedulerTests-\(UUID().uuidString)")
        try? fm.createDirectory(at: scratchHome, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let scratchHome {
            try? fm.removeItem(at: scratchHome)
        }
        super.tearDown()
    }

    // MARK: - AC-03.4.1 Notification composition

    func testNotificationSentencesIncludeSkippedWhenPresent() {
        let strings = L10n.shared.s

        // 1. With moved > 0, no failed, no skipped: exactly moved sentence
        let movedOnly = CleanerScheduler.formatNotificationBody(
            movedToTrash: 1024 * 1024,
            failed: 0,
            skippedBrowsers: [],
            strings: strings
        )
        XCTAssertEqual(movedOnly.count, 1)
        XCTAssertTrue(movedOnly[0].contains("1 MB") || movedOnly[0].contains("1,048,576") || movedOnly[0].contains("1"))

        // 2. With moved > 0, skipped browsers present, failed > 0: [moved, skipped, failed]
        let withSkippedAndFailed = CleanerScheduler.formatNotificationBody(
            movedToTrash: 2048 * 1024,
            failed: 2,
            skippedBrowsers: ["Google Chrome", "Brave Browser"],
            strings: strings
        )
        XCTAssertEqual(withSkippedAndFailed.count, 3)
        XCTAssertEqual(withSkippedAndFailed[1], strings.cleanerNotificationSkippedBrowsersFormat)
        XCTAssertEqual(withSkippedAndFailed[2], strings.uninstallerSomeFailed)

        // 3. With moved == 0, failed == 0, skipped present: only skipped sentence
        let skippedOnly = CleanerScheduler.formatNotificationBody(
            movedToTrash: 0,
            failed: 0,
            skippedBrowsers: ["Safari"],
            strings: strings
        )
        XCTAssertEqual(skippedOnly, [strings.cleanerNotificationSkippedBrowsersFormat])

        // 4. With moved == 0, failed == 0, no skipped: nothing found sentence
        let nothingFound = CleanerScheduler.formatNotificationBody(
            movedToTrash: 0,
            failed: 0,
            skippedBrowsers: [],
            strings: strings
        )
        XCTAssertEqual(nothingFound, [strings.cleanerNothingFound])
    }

    // MARK: - AC-03.3.1 Automatic pass cleans cache and skips running

    func testAutomaticPassCleansCacheSkipsRunning() {
        let originalRunning = JunkCleaner.runningBundleIDs
        let originalTrash = JunkCleaner.trashRunner
        addTeardownBlock {
            JunkCleaner.runningBundleIDs = originalRunning
            JunkCleaner.trashRunner = originalTrash
        }

        // Browser A: Google Chrome (stopped)
        // Profile root: Library/Application Support/Google/Chrome/Default
        // Cache target: Library/Caches/Google/Chrome/Default/Cache/data_cache.bin
        let chromeProfile = scratchHome.appendingPathComponent("Library/Application Support/Google/Chrome/Default")
        let chromeCache = scratchHome.appendingPathComponent("Library/Caches/Google/Chrome/Default/Cache")
        let chromeSiteData = chromeProfile.appendingPathComponent("Cookies")
        try! fm.createDirectory(at: chromeProfile, withIntermediateDirectories: true)
        try! fm.createDirectory(at: chromeCache, withIntermediateDirectories: true)
        let chromeCacheFile = chromeCache.appendingPathComponent("data_cache.bin")
        try! "chrome_cache_content".write(to: chromeCacheFile, atomically: true, encoding: .utf8)
        try! "chrome_cookie_content".write(to: chromeSiteData, atomically: true, encoding: .utf8)

        // Browser B: Brave Browser (running)
        // Profile root: Library/Application Support/BraveSoftware/Brave-Browser/Default
        // Cache target: Library/Caches/BraveSoftware/Brave-Browser/Default/Cache/brave_cache.bin
        let braveProfile = scratchHome.appendingPathComponent("Library/Application Support/BraveSoftware/Brave-Browser/Default")
        let braveCache = scratchHome.appendingPathComponent("Library/Caches/BraveSoftware/Brave-Browser/Default/Cache")
        try! fm.createDirectory(at: braveProfile, withIntermediateDirectories: true)
        try! fm.createDirectory(at: braveCache, withIntermediateDirectories: true)
        let braveCacheFile = braveCache.appendingPathComponent("brave_cache.bin")
        try! "brave_cache_content".write(to: braveCacheFile, atomically: true, encoding: .utf8)

        // Set running bundle IDs to include Brave, but not Chrome
        JunkCleaner.runningBundleIDs = { ["com.brave.Browser"] }

        var trashedURLs: [URL] = []
        JunkCleaner.trashRunner = { url in
            trashedURLs.append(url)
            try FileManager.default.removeItem(at: url)
        }

        let engine = JunkCleaner(passHolder: .automatic, gate: CleanerPassGate())

        // 1. Scan unattended (attended: false)
        let scanExp = expectation(description: "scan finishes")
        var scanCancellable: AnyCancellable?
        scanCancellable = engine.$phase.dropFirst().sink { phase in
            if case .results = phase {
                scanExp.fulfill()
            }
        }
        engine.scan(attended: false, home: scratchHome.path)
        wait(for: [scanExp], timeout: 20)
        scanCancellable?.cancel()

        // Verify items produced:
        // Caches recommended = true; site data recommended = false
        let cacheItems = engine.items.filter { $0.category == .browserCaches }
        let siteDataItems = engine.items.filter { $0.category == .browserSiteData }
        XCTAssertFalse(cacheItems.isEmpty, "Cache items should be produced for browsers")
        XCTAssertTrue(cacheItems.allSatisfy(\.recommended), "Browser caches must be prechecked (recommended)")
        XCTAssertTrue(siteDataItems.allSatisfy { !$0.recommended }, "Browser site data must not be recommended")

        // 2. Run cleanSelected(escalate: false) as automatic cleanup does
        let cleanExp = expectation(description: "clean finishes")
        var cleanCancellable: AnyCancellable?
        cleanCancellable = engine.$phase.dropFirst().sink { phase in
            if case .done = phase {
                cleanExp.fulfill()
            }
        }
        engine.cleanSelected(escalate: false)
        wait(for: [cleanExp], timeout: 20)
        cleanCancellable?.cancel()

        // 3. Verify outcomes:
        // - Chrome cache target was trashed
        XCTAssertTrue(trashedURLs.contains(where: { $0.path.contains("Google/Chrome") }),
                      "Stopped browser (Chrome) cache targets should be trashed")
        // - Brave cache target was NOT trashed (running)
        XCTAssertFalse(trashedURLs.contains(where: { $0.path.contains("Brave-Browser") }),
                       "Running browser (Brave) targets should NOT be trashed")
        // - Site data was NOT trashed
        XCTAssertFalse(trashedURLs.contains(where: { $0.path.contains("Cookies") }),
                       "Browser site data targets should NOT be trashed during automatic pass")
        // - Skipped browsers recorded in engine
        XCTAssertEqual(engine.skippedBrowsers, ["Brave Browser"],
                       "Engine must report running browser in skippedBrowsers")
    }
}
