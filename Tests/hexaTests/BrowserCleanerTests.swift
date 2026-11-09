// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest
import Combine
@testable import Hexa

final class BrowserCleanerTests: XCTestCase {
    private let fm = FileManager.default

    private func makeScratchHome() throws -> URL {
        let root = fm.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("hexa-browsercleaner-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { [fm] in
            if let walk = fm.enumerator(at: root, includingPropertiesForKeys: nil) {
                for case let url as URL in walk {
                    try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
                }
            }
            try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.path)
            try? fm.removeItem(at: root)
        }
        return root
    }

    private func writeFile(_ url: URL, bytes: Int) throws {
        let dir = url.deletingLastPathComponent()
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(count: bytes).write(to: url)
    }

    private func writeDirWithFile(_ dirURL: URL, fileName: String, bytes: Int) throws {
        try fm.createDirectory(at: dirURL, withIntermediateDirectories: true)
        let file = dirURL.appendingPathComponent(fileName)
        try Data(count: bytes).write(to: file)
    }

    private func cleanAndWait(_ cleaner: JunkCleaner, items: [JunkCleaner.Item]) -> JunkCleaner.Phase? {
        cleaner.items = items
        cleaner.setPhaseForTesting(.results)
        var finished: JunkCleaner.Phase?
        let completed = expectation(description: "the clean completes")
        let subscription = cleaner.$phase.sink { phase in
            if case .done = phase {
                finished = phase
                completed.fulfill()
            }
        }
        cleaner.cleanSelected(escalate: false)
        wait(for: [completed], timeout: 10)
        subscription.cancel()
        return finished
    }

    // MARK: - Plan 01 Tests

    /// AC-01.1.1: Com fixture sob home contendo Chrome (Default + Profile 1 com caches)
    /// e Firefox (um perfil), BrowserJunk.detect devolve exatamente Google Chrome e Firefox,
    /// um achado por navegador, perfis agregados na mesma entrada.
    func testDetectionAggregatesProfilesPerBrowser() throws {
        let home = try makeScratchHome()

        // Setup Chrome: Default and Profile 1 with caches
        let chromeDefaultCache = home.appendingPathComponent("Library/Application Support/Google/Chrome/Default/Cache", isDirectory: true)
        try writeDirWithFile(chromeDefaultCache, fileName: "data.bin", bytes: 2048)

        let chromeP1Cache = home.appendingPathComponent("Library/Application Support/Google/Chrome/Profile 1/Code Cache", isDirectory: true)
        try writeDirWithFile(chromeP1Cache, fileName: "js.bin", bytes: 4096)

        // Setup Firefox: one profile with cache2
        let firefoxProfile = home.appendingPathComponent("Library/Application Support/Firefox/Profiles/test.default", isDirectory: true)
        let firefoxCookies = firefoxProfile.appendingPathComponent("cookies.sqlite")
        try writeFile(firefoxCookies, bytes: 1024)

        let firefoxCache = home.appendingPathComponent("Library/Caches/Firefox/Profiles/test.default/cache2", isDirectory: true)
        try writeDirWithFile(firefoxCache, fileName: "entries", bytes: 8192)

        let detected = BrowserJunk.detect(home: home.path)

        // Must detect exactly 2 browsers (Chrome and Firefox)
        XCTAssertEqual(detected.count, 2, "Expected exactly 2 detected browsers")

        let chrome = try XCTUnwrap(detected.first { $0.id == "com.google.Chrome" })
        XCTAssertEqual(chrome.displayName, "Google Chrome")
        // Profiles must be aggregated under a single finding
        XCTAssertEqual(chrome.profileURLs.count, 2, "Chrome must aggregate Default and Profile 1")

        let firefox = try XCTUnwrap(detected.first { $0.id == "org.mozilla.firefox" })
        XCTAssertEqual(firefox.displayName, "Firefox")
        XCTAssertEqual(firefox.profileURLs.count, 1)

        // Other browsers must be absent
        let absentIDs = ["company.thebrowser.Browser", "com.microsoft.edgemac", "com.brave.Browser", "com.operasoftware.Opera", "com.vivaldi.Vivaldi", "com.apple.Safari"]
        for id in absentIDs {
            XCTAssertFalse(detected.contains { $0.id == id }, "Browser \(id) should not be detected without root")
        }
    }

    /// AC-01.1.2: Definições fora da tabela não são detectadas: fixture com pasta
    /// Library/Application Support/NavegadorQualquer produz zero achados.
    func testDetectionIgnoresUnknownFolders() throws {
        let home = try makeScratchHome()

        let unknownCache = home.appendingPathComponent("Library/Application Support/NavegadorQualquer/Default/Cache", isDirectory: true)
        try writeDirWithFile(unknownCache, fileName: "cache.bin", bytes: 4096)

        let detected = BrowserJunk.detect(home: home.path)
        XCTAssertTrue(detected.isEmpty, "Unknown directories outside registered table must not be detected")
    }

    /// AC-01.2.1: scanItems devolve alvos de cache separados de dados de sites,
    /// tamanhos somados coerentes com directorySize, e accessPending quando raiz ilegível.
    func testTargetsAndSizesAndPending() throws {
        let home = try makeScratchHome()

        // Chrome setup
        let chromeDefaultCache = home.appendingPathComponent("Library/Application Support/Google/Chrome/Default/Cache", isDirectory: true)
        try writeDirWithFile(chromeDefaultCache, fileName: "data.bin", bytes: 10_000)

        let chromeDefaultCookies = home.appendingPathComponent("Library/Application Support/Google/Chrome/Default/Cookies")
        try writeFile(chromeDefaultCookies, bytes: 5_000)

        let chromeP1CodeCache = home.appendingPathComponent("Library/Application Support/Google/Chrome/Profile 1/Code Cache", isDirectory: true)
        try writeDirWithFile(chromeP1CodeCache, fileName: "code.bin", bytes: 20_000)

        let chromeP1LocalStorage = home.appendingPathComponent("Library/Application Support/Google/Chrome/Profile 1/Local Storage", isDirectory: true)
        try writeDirWithFile(chromeP1LocalStorage, fileName: "local.bin", bytes: 15_000)

        // Firefox setup
        let firefoxProfile = home.appendingPathComponent("Library/Application Support/Firefox/Profiles/my.profile", isDirectory: true)
        let firefoxCookies = firefoxProfile.appendingPathComponent("cookies.sqlite")
        try writeFile(firefoxCookies, bytes: 7_000)

        let firefoxCache = home.appendingPathComponent("Library/Caches/Firefox/Profiles/my.profile/cache2", isDirectory: true)
        try writeDirWithFile(firefoxCache, fileName: "cache.bin", bytes: 30_000)

        let results = BrowserJunk.scanItems(home: home.path)
        XCTAssertEqual(results.count, 2)

        let chromeResult = try XCTUnwrap(results.first { $0.id == "com.google.Chrome" })
        XCTAssertFalse(chromeResult.accessPending)

        // Partition checks: cache vs site data
        XCTAssertEqual(chromeResult.cacheTargets.count, 2)
        XCTAssertTrue(chromeResult.cacheTargets.contains { $0.url.path.hasSuffix("Default/Cache") })
        XCTAssertTrue(chromeResult.cacheTargets.contains { $0.url.path.hasSuffix("Profile 1/Code Cache") })

        XCTAssertEqual(chromeResult.siteDataTargets.count, 2)
        XCTAssertTrue(chromeResult.siteDataTargets.contains { $0.url.path.hasSuffix("Default/Cookies") })
        XCTAssertTrue(chromeResult.siteDataTargets.contains { $0.url.path.hasSuffix("Profile 1/Local Storage") })

        let expectedChromeCacheSize = JunkCleaner.directorySize(of: chromeDefaultCache, fm: fm)
            + JunkCleaner.directorySize(of: chromeP1CodeCache, fm: fm)
        let expectedChromeSiteDataSize = JunkCleaner.directorySize(of: chromeDefaultCookies, fm: fm)
            + JunkCleaner.directorySize(of: chromeP1LocalStorage, fm: fm)

        XCTAssertEqual(chromeResult.cacheSize, expectedChromeCacheSize)
        XCTAssertEqual(chromeResult.siteDataSize, expectedChromeSiteDataSize)

        let firefoxResult = try XCTUnwrap(results.first { $0.id == "org.mozilla.firefox" })
        XCTAssertFalse(firefoxResult.accessPending)
        XCTAssertEqual(firefoxResult.cacheTargets.count, 1)
        XCTAssertTrue(firefoxResult.cacheTargets.contains { $0.url.path.hasSuffix("my.profile/cache2") })
        XCTAssertEqual(firefoxResult.siteDataTargets.count, 1)
        XCTAssertTrue(firefoxResult.siteDataTargets.contains { $0.url.path.hasSuffix("cookies.sqlite") })

        // Now test accessPending: mark Chrome's root unreadable
        let chromeRoot = home.appendingPathComponent("Library/Application Support/Google/Chrome")
        try fm.setAttributes([.posixPermissions: 0o000], ofItemAtPath: chromeRoot.path)

        let pendingResults = BrowserJunk.scanItems(home: home.path)
        let pendingChrome = try XCTUnwrap(pendingResults.first { $0.id == "com.google.Chrome" })
        XCTAssertTrue(pendingChrome.accessPending, "Unreadable root must yield accessPending == true")
        XCTAssertTrue(pendingChrome.cacheTargets.isEmpty)
        XCTAssertTrue(pendingChrome.siteDataTargets.isEmpty)
        XCTAssertEqual(pendingChrome.cacheSize, 0)
        XCTAssertEqual(pendingChrome.siteDataSize, 0)

        let normalFirefox = try XCTUnwrap(pendingResults.first { $0.id == "org.mozilla.firefox" })
        XCTAssertFalse(normalFirefox.accessPending, "Unaffected browser should not report accessPending")
        XCTAssertFalse(normalFirefox.cacheTargets.isEmpty)
    }

    // MARK: - Plan 02 Tests

    /// AC-02.1.1: Itens construídos com .browserCaches nascem recommended == true e include == true;
    /// com .browserSiteData, recommended == false e include == false; os alvos presos ao item carregam a identidade lida na construção.
    func testItemBirthFlagsPerCategory() throws {
        let home = try makeScratchHome()
        let chromeRoot = home.appendingPathComponent("Library/Application Support/Google/Chrome", isDirectory: true)
        let cacheFile = chromeRoot.appendingPathComponent("Default/Cache/data.bin")
        try writeFile(cacheFile, bytes: 1024)

        let cacheTarget = BrowserJunk.Target(url: cacheFile)
        XCTAssertNotNil(cacheTarget.identity)

        let cacheItem = JunkCleaner.Item(
            url: chromeRoot,
            category: .browserCaches,
            size: 1024,
            detail: "Google Chrome",
            recommended: CleanerPolicy.precheckBrowserCaches,
            browserKey: "com.google.Chrome",
            browserName: "Google Chrome",
            browserTargets: [cacheTarget]
        )

        XCTAssertTrue(cacheItem.recommended, "browserCaches must be recommended by policy")
        XCTAssertTrue(cacheItem.include, "browserCaches must start included")
        XCTAssertEqual(cacheItem.browserTargets.first?.identity, cacheTarget.identity)

        let cookiesFile = chromeRoot.appendingPathComponent("Default/Cookies")
        try writeFile(cookiesFile, bytes: 512)
        let siteDataTarget = BrowserJunk.Target(url: cookiesFile)

        let siteDataItem = JunkCleaner.Item(
            url: chromeRoot,
            category: .browserSiteData,
            size: 512,
            detail: "Google Chrome",
            recommended: CleanerPolicy.precheckBrowserSiteData,
            browserKey: "com.google.Chrome",
            browserName: "Google Chrome",
            browserTargets: [siteDataTarget]
        )

        XCTAssertFalse(siteDataItem.recommended, "browserSiteData must not be recommended by policy")
        XCTAssertFalse(siteDataItem.include, "browserSiteData must start unincluded")
        XCTAssertEqual(siteDataItem.browserTargets.first?.identity, siteDataTarget.identity)
    }

    /// AC-02.2.1: A guarda recusa: item de navegador cujo alvo é a raiz do perfil; alvo fora dos subpaths previstos (ex.: History);
    /// symlink no lugar do alvo; alvo cuja identidade em disco difere da capturada.
    func testGuardRefusesRootUnexpectedSymlinkIdentity() throws {
        let home = try makeScratchHome()
        let chromeRoot = home.appendingPathComponent("Library/Application Support/Google/Chrome", isDirectory: true)
        try fm.createDirectory(at: chromeRoot, withIntermediateDirectories: true)

        var trashedCount = 0
        let originalRunner = JunkCleaner.trashRunner
        JunkCleaner.trashRunner = { _ in trashedCount += 1 }
        addTeardownBlock { JunkCleaner.trashRunner = originalRunner }

        // 1. Target is profile root itself
        let rootTarget = BrowserJunk.Target(url: chromeRoot)
        let rootItem = JunkCleaner.Item(
            url: chromeRoot, category: .browserCaches, size: 100, detail: "Chrome",
            recommended: CleanerPolicy.precheckBrowserCaches,
            browserKey: "com.google.Chrome", browserName: "Google Chrome",
            browserTargets: [rootTarget]
        )
        XCTAssertFalse(JunkCleaner.mayRemove(rootItem), "mayRemove must reject profile root as target")
        let rootOutcomes = JunkCleaner.trashBrowserTargets(rootItem)
        XCTAssertEqual(rootOutcomes, [.failed])
        XCTAssertEqual(trashedCount, 0)

        // 2. Target is unexpected subpath (History)
        let historyURL = chromeRoot.appendingPathComponent("Default/History")
        try writeFile(historyURL, bytes: 200)
        let historyTarget = BrowserJunk.Target(url: historyURL)
        let historyItem = JunkCleaner.Item(
            url: chromeRoot, category: .browserCaches, size: 200, detail: "Chrome",
            recommended: CleanerPolicy.precheckBrowserCaches,
            browserKey: "com.google.Chrome", browserName: "Google Chrome",
            browserTargets: [historyTarget]
        )
        XCTAssertFalse(JunkCleaner.mayRemove(historyItem), "mayRemove must reject unexpected subpath (History)")
        let historyOutcomes = JunkCleaner.trashBrowserTargets(historyItem)
        XCTAssertEqual(historyOutcomes, [.failed])
        XCTAssertEqual(trashedCount, 0)

        // 3. Target is a symlink
        let outsideDir = home.appendingPathComponent("outside", isDirectory: true)
        try fm.createDirectory(at: outsideDir, withIntermediateDirectories: true)
        let symlinkURL = chromeRoot.appendingPathComponent("Default/Cache")
        try fm.createDirectory(at: symlinkURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.createSymbolicLink(at: symlinkURL, withDestinationURL: outsideDir)

        let symlinkTarget = BrowserJunk.Target(url: symlinkURL)
        let symlinkItem = JunkCleaner.Item(
            url: chromeRoot, category: .browserCaches, size: 200, detail: "Chrome",
            recommended: CleanerPolicy.precheckBrowserCaches,
            browserKey: "com.google.Chrome", browserName: "Google Chrome",
            browserTargets: [symlinkTarget]
        )
        XCTAssertFalse(JunkCleaner.mayRemove(symlinkItem), "mayRemove must reject symlinks")
        let symlinkOutcomes = JunkCleaner.trashBrowserTargets(symlinkItem)
        XCTAssertEqual(symlinkOutcomes, [.failed])
        XCTAssertEqual(trashedCount, 0)

        // 4. Target with identity mismatch
        let validDir = chromeRoot.appendingPathComponent("Default/GPUCache", isDirectory: true)
        try writeDirWithFile(validDir, fileName: "data.bin", bytes: 300)
        let fakeIdentity = UninstallerSupport.FileIdentity(device: 9999, inode: 88888)
        let mismatchTarget = BrowserJunk.Target(url: validDir, identity: fakeIdentity)
        let mismatchItem = JunkCleaner.Item(
            url: chromeRoot, category: .browserCaches, size: 300, detail: "Chrome",
            recommended: CleanerPolicy.precheckBrowserCaches,
            browserKey: "com.google.Chrome", browserName: "Google Chrome",
            browserTargets: [mismatchTarget]
        )
        XCTAssertFalse(JunkCleaner.mayRemove(mismatchItem), "mayRemove must reject identity mismatch")
        let mismatchOutcomes = JunkCleaner.trashBrowserTargets(mismatchItem)
        XCTAssertEqual(mismatchOutcomes, [CleanerSupport.RemovalOutcome.failed])
        XCTAssertEqual(trashedCount, 0)
    }

    /// AC-02.2.2: Com fixture de dois navegadores (A e B) e seleção só de A: cleanSelected move exatamente os alvos de A,
    /// zero alvos de B, raízes de perfil e arquivos fora dos alvos intactos; totais somam tamanho real movido; falha parcial
    /// registra item em failedItems como not fully moved sem rollback.
    func testRemovalIsDiscriminatingPerBrowser() throws {
        let home = try makeScratchHome()

        let originalRunning = JunkCleaner.runningBundleIDs
        JunkCleaner.runningBundleIDs = { [] }
        addTeardownBlock { JunkCleaner.runningBundleIDs = originalRunning }

        // Setup Browser A (Chrome)
        let chromeRoot = home.appendingPathComponent("Library/Application Support/Google/Chrome", isDirectory: true)
        let chromeCacheDir = chromeRoot.appendingPathComponent("Default/Cache", isDirectory: true)
        try writeDirWithFile(chromeCacheDir, fileName: "data.bin", bytes: 5000)

        let chromeHistory = chromeRoot.appendingPathComponent("Default/History")
        try writeFile(chromeHistory, bytes: 2000)

        let chromeBookmarks = chromeRoot.appendingPathComponent("Default/Bookmarks")
        try writeFile(chromeBookmarks, bytes: 1500)

        // Setup Browser B (Firefox)
        let firefoxRoot = home.appendingPathComponent("Library/Application Support/Firefox/Profiles/p1", isDirectory: true)
        let firefoxCookies = firefoxRoot.appendingPathComponent("cookies.sqlite")
        try writeFile(firefoxCookies, bytes: 4000)

        let firefoxCacheDir = home.appendingPathComponent("Library/Caches/Firefox/Profiles/p1/cache2", isDirectory: true)
        try writeDirWithFile(firefoxCacheDir, fileName: "b.bin", bytes: 8000)

        var trashedURLs: [URL] = []
        let originalTrash = JunkCleaner.trashRunner
        JunkCleaner.trashRunner = { url in
            trashedURLs.append(url)
            try FileManager.default.removeItem(at: url)
        }
        addTeardownBlock { JunkCleaner.trashRunner = originalTrash }

        let chromeTarget = BrowserJunk.Target(url: chromeCacheDir)
        let expectedSizeA = JunkCleaner.directorySize(of: chromeCacheDir, fm: fm)
        var chromeItem = JunkCleaner.Item(
            url: chromeRoot, category: .browserCaches, size: expectedSizeA, detail: "Chrome",
            recommended: CleanerPolicy.precheckBrowserCaches,
            browserKey: "com.google.Chrome", browserName: "Google Chrome",
            browserTargets: [chromeTarget]
        )
        chromeItem.include = true

        let firefoxTarget = BrowserJunk.Target(url: firefoxCacheDir)
        let expectedSizeB = JunkCleaner.directorySize(of: firefoxCacheDir, fm: fm)
        var firefoxItem = JunkCleaner.Item(
            url: firefoxRoot, category: .browserCaches, size: expectedSizeB, detail: "Firefox",
            recommended: CleanerPolicy.precheckBrowserCaches,
            browserKey: "org.mozilla.firefox", browserName: "Firefox",
            browserTargets: [firefoxTarget]
        )
        firefoxItem.include = false // B is NOT selected

        let cleaner = JunkCleaner(gate: CleanerPassGate())
        let phase = cleanAndWait(cleaner, items: [chromeItem, firefoxItem])

        guard case .done(let moved, let freed, let failed) = phase else {
            return XCTFail("Expected .done phase")
        }

        XCTAssertEqual(moved, expectedSizeA, "Should move exactly A's selected size")
        XCTAssertEqual(freed, 0)
        XCTAssertEqual(failed, 0)

        // Check disk state:
        XCTAssertFalse(fm.fileExists(atPath: chromeCacheDir.path), "A's cache target must be removed")
        XCTAssertTrue(fm.fileExists(atPath: chromeRoot.path), "A's profile root must remain intact")
        XCTAssertTrue(fm.fileExists(atPath: chromeHistory.path), "A's History must remain intact")
        XCTAssertTrue(fm.fileExists(atPath: chromeBookmarks.path), "A's Bookmarks must remain intact")

        XCTAssertTrue(fm.fileExists(atPath: firefoxCacheDir.path), "B's cache target must NOT be touched")
        XCTAssertTrue(fm.fileExists(atPath: firefoxCookies.path), "B's site data must NOT be touched")
        XCTAssertTrue(fm.fileExists(atPath: firefoxRoot.path), "B's root must NOT be touched")

        // Now test partial failure on an item with 2 exact target folders:
        let cache1 = chromeRoot.appendingPathComponent("Default/Cache", isDirectory: true)
        let cache2 = chromeRoot.appendingPathComponent("Default/Code Cache", isDirectory: true)
        try writeDirWithFile(cache1, fileName: "part1.bin", bytes: 1000)
        try writeDirWithFile(cache2, fileName: "part2.bin", bytes: 2000)

        let expectedMovedPart1 = JunkCleaner.directorySize(of: cache1, fm: fm)

        JunkCleaner.trashRunner = { url in
            if url.lastPathComponent == "Code Cache" {
                throw NSError(domain: "test", code: 1, userInfo: nil)
            }
            try FileManager.default.removeItem(at: url)
        }

        var multiTargetItem = JunkCleaner.Item(
            url: chromeRoot, category: .browserCaches, size: 3000, detail: "Chrome",
            recommended: CleanerPolicy.precheckBrowserCaches,
            browserKey: "com.google.Chrome", browserName: "Google Chrome",
            browserTargets: [BrowserJunk.Target(url: cache1), BrowserJunk.Target(url: cache2)]
        )
        multiTargetItem.include = true

        let partialCleaner = JunkCleaner(gate: CleanerPassGate())
        let partialPhase = cleanAndWait(partialCleaner, items: [multiTargetItem])

        guard case .done(let partialMoved, _, let partialFailed) = partialPhase else {
            return XCTFail("Expected .done for partial failure")
        }

        XCTAssertEqual(partialMoved, expectedMovedPart1, "Part 1 should be counted as moved")
        XCTAssertEqual(partialFailed, 1, "Part 2 failure should be recorded")
        XCTAssertFalse(fm.fileExists(atPath: cache1.path), "Part 1 was moved without rollback")
        XCTAssertTrue(fm.fileExists(atPath: cache2.path), "Part 2 stayed behind")

        let failedItem = try XCTUnwrap(partialCleaner.failedItems.first)
        XCTAssertEqual(failedItem.reason, "not fully moved to the Trash")
    }

    /// AC-02.3.1: Adversarial: com seam devolvendo bundle de A como rodando, cleanSelected sobre A e B remove zero alvos de A,
    /// move B normalmente, skippedBrowsers == [A.displayName], e .done não conta A como falha.
    func testRunningBrowserIsSkippedAndReported() throws {
        let home = try makeScratchHome()

        let chromeRoot = home.appendingPathComponent("Library/Application Support/Google/Chrome", isDirectory: true)
        let chromeCacheDir = chromeRoot.appendingPathComponent("Default/Cache", isDirectory: true)
        try writeDirWithFile(chromeCacheDir, fileName: "a.bin", bytes: 3000)

        let firefoxRoot = home.appendingPathComponent("Library/Application Support/Firefox/Profiles/p1", isDirectory: true)
        try fm.createDirectory(at: firefoxRoot, withIntermediateDirectories: true)
        let firefoxCacheDir = home.appendingPathComponent("Library/Caches/Firefox/Profiles/p1/cache2", isDirectory: true)
        try writeDirWithFile(firefoxCacheDir, fileName: "b.bin", bytes: 4000)

        var trashedURLs: [URL] = []
        let originalTrash = JunkCleaner.trashRunner
        JunkCleaner.trashRunner = { url in
            trashedURLs.append(url)
            try FileManager.default.removeItem(at: url)
        }
        addTeardownBlock { JunkCleaner.trashRunner = originalTrash }

        let originalRunning = JunkCleaner.runningBundleIDs
        // Set Chrome as running
        JunkCleaner.runningBundleIDs = { ["com.google.Chrome"] }
        addTeardownBlock { JunkCleaner.runningBundleIDs = originalRunning }

        var itemA = JunkCleaner.Item(
            url: chromeRoot, category: .browserCaches, size: 3000, detail: "Chrome",
            recommended: CleanerPolicy.precheckBrowserCaches,
            browserKey: "com.google.Chrome", browserName: "Google Chrome",
            browserTargets: [BrowserJunk.Target(url: chromeCacheDir)]
        )
        itemA.include = true

        var itemB = JunkCleaner.Item(
            url: firefoxRoot, category: .browserCaches, size: 4000, detail: "Firefox",
            recommended: CleanerPolicy.precheckBrowserCaches,
            browserKey: "org.mozilla.firefox", browserName: "Firefox",
            browserTargets: [BrowserJunk.Target(url: firefoxCacheDir)]
        )
        itemB.include = true

        let expectedSizeB = JunkCleaner.directorySize(of: firefoxCacheDir, fm: fm)

        let cleaner = JunkCleaner(gate: CleanerPassGate())
        let phase = cleanAndWait(cleaner, items: [itemA, itemB])

        guard case .done(let moved, let freed, let failed) = phase else {
            return XCTFail("Expected .done phase")
        }

        XCTAssertEqual(moved, expectedSizeB, "Only B was cleaned")
        XCTAssertEqual(freed, 0)
        XCTAssertEqual(failed, 0, "Skipped browser A is NOT a failure")

        // A's files must NOT be touched
        XCTAssertTrue(fm.fileExists(atPath: chromeCacheDir.path), "A must not be touched")
        // B's files must be removed
        XCTAssertFalse(fm.fileExists(atPath: firefoxCacheDir.path), "B must be removed")

        // skippedBrowsers reports Google Chrome
        XCTAssertEqual(cleaner.skippedBrowsers, ["Google Chrome"])
        XCTAssertTrue(cleaner.failedItems.isEmpty, "Skipped browser must not appear in failedItems")
    }

    /// AC-02.3.2: Totais e canal coerentes: skippedBrowsers é sobrescrito a cada limpeza e zerado por scan/reset.
    func testSkippedListIsAbsolutePerPass() throws {
        let home = try makeScratchHome()
        let firefoxRoot = home.appendingPathComponent("Library/Application Support/Firefox/Profiles/p1", isDirectory: true)
        let firefoxCacheDir = home.appendingPathComponent("Library/Caches/Firefox/Profiles/p1/cache2", isDirectory: true)
        try writeDirWithFile(firefoxCacheDir, fileName: "b.bin", bytes: 2000)

        let originalTrash = JunkCleaner.trashRunner
        JunkCleaner.trashRunner = { try FileManager.default.removeItem(at: $0) }
        addTeardownBlock { JunkCleaner.trashRunner = originalTrash }

        let originalRunning = JunkCleaner.runningBundleIDs
        JunkCleaner.runningBundleIDs = { [] }
        addTeardownBlock { JunkCleaner.runningBundleIDs = originalRunning }

        let cleaner = JunkCleaner(gate: CleanerPassGate())

        // 1. Simulate previous skippedBrowsers
        cleaner.setSkippedBrowsersForTesting(["Google Chrome", "Arc"])
        XCTAssertEqual(cleaner.skippedBrowsers, ["Google Chrome", "Arc"])

        // 2. Run clean with NO running browsers
        var itemB = JunkCleaner.Item(
            url: firefoxRoot, category: .browserCaches, size: 2000, detail: "Firefox",
            recommended: CleanerPolicy.precheckBrowserCaches,
            browserKey: "org.mozilla.firefox", browserName: "Firefox",
            browserTargets: [BrowserJunk.Target(url: firefoxCacheDir)]
        )
        itemB.include = true

        _ = cleanAndWait(cleaner, items: [itemB])

        // skippedBrowsers must be completely overwritten by the new pass (absolute write)
        XCTAssertEqual(cleaner.skippedBrowsers, [], "Previous skipped browsers must not leak to new pass")

        // 3. Test reset() zeroes skippedBrowsers
        cleaner.setSkippedBrowsersForTesting(["Opera"])
        XCTAssertEqual(cleaner.skippedBrowsers, ["Opera"])
        cleaner.reset()
        XCTAssertEqual(cleaner.skippedBrowsers, [], "reset() must clear skippedBrowsers")
    }

    // MARK: - Plan 03 Tests

    /// AC-03.1.1: scan(attended: true) e scan(attended: false) produzem par de itens por navegador,
    /// tamanhos somados, sem duplicação de raízes reivindicadas em caches genéricos.
    func testScanProducesBrowserItemsBothAttendsNoDuplication() throws {
        let home = try makeScratchHome()

        // Browser 1: Chrome (with 2 profiles)
        let chromeP1Cache = home.appendingPathComponent("Library/Application Support/Google/Chrome/Default/Cache")
        let chromeP1Site = home.appendingPathComponent("Library/Application Support/Google/Chrome/Default/Cookies")
        let chromeP2Cache = home.appendingPathComponent("Library/Application Support/Google/Chrome/Profile 1/Cache")
        try writeDirWithFile(chromeP1Cache, fileName: "c1.bin", bytes: 2048)
        try writeDirWithFile(chromeP2Cache, fileName: "c2.bin", bytes: 4096)
        try writeFile(chromeP1Site, bytes: 1024)

        // Claimed cache root for Chrome in ~/Library/Caches
        let chromeCacheRoot = home.appendingPathComponent("Library/Caches/Google/Chrome/Default/Cache")
        try writeDirWithFile(chromeCacheRoot, fileName: "root_cache.bin", bytes: 2048)

        // Browser 2: Firefox (one profile)
        let firefoxProfile = home.appendingPathComponent("Library/Application Support/Firefox/Profiles/user.default")
        let firefoxCache = home.appendingPathComponent("Library/Caches/Firefox/Profiles/user.default/cache2")
        let firefoxSite = firefoxProfile.appendingPathComponent("cookies.sqlite")
        try writeDirWithFile(firefoxCache, fileName: "f_cache.bin", bytes: 8192)
        try writeFile(firefoxSite, bytes: 2048)

        // Browser 3: Orphan Caches folder without profile (e.g. Opera cache without profile)
        let operaCacheOnly = home.appendingPathComponent("Library/Caches/com.operasoftware.Opera")
        try writeDirWithFile(operaCacheOnly, fileName: "opera.bin", bytes: 1024)

        for attended in [true, false] {
            let cleaner = JunkCleaner(gate: CleanerPassGate())
            let scanCompleted = expectation(description: "scan completed for attended=\(attended)")
            var subscription: AnyCancellable?
            subscription = cleaner.$phase.dropFirst().sink { phase in
                if case .results = phase {
                    scanCompleted.fulfill()
                }
            }

            cleaner.scan(attended: attended, home: home.path)
            wait(for: [scanCompleted], timeout: 10)
            subscription?.cancel()

            // Verify Chrome & Firefox browser items
            let browserCacheItems = cleaner.items.filter { $0.category == .browserCaches }
            let browserSiteItems = cleaner.items.filter { $0.category == .browserSiteData }

            XCTAssertEqual(browserCacheItems.count, 2, "Should have 2 browser cache items (Chrome, Firefox)")
            XCTAssertEqual(browserSiteItems.count, 2, "Should have 2 browser site data items (Chrome, Firefox)")

            // Verify recommendation defaults
            XCTAssertTrue(browserCacheItems.allSatisfy(\.recommended), "Browser cache items must be recommended")
            XCTAssertTrue(browserCacheItems.allSatisfy(\.include), "Browser cache items must be included by default")
            XCTAssertTrue(browserSiteItems.allSatisfy { !$0.recommended }, "Browser site data items must NOT be recommended")
            XCTAssertTrue(browserSiteItems.allSatisfy { !$0.include }, "Browser site data items must NOT be included by default")

            // No generic cache row may contain or sit inside a browser target.
            let genericCaches = cleaner.items.filter { $0.category == .caches }
            let browserTargets = (browserCacheItems + browserSiteItems)
                .flatMap(\.browserTargets)
                .map { $0.url.standardizedFileURL.path }
            for cacheItem in genericCaches {
                let path = cacheItem.url.standardizedFileURL.path
                XCTAssertFalse(browserTargets.contains { path == $0 || $0.hasPrefix(path + "/") || path.hasPrefix($0 + "/") },
                               "Generic cache row must not overlap a browser target: \(path)")
            }

            // Opera had no profile: no browser item; its orphan cache root stays reachable in generic caches.
            XCTAssertFalse(browserCacheItems.contains { $0.browserKey == "com.operasoftware.Opera" })
        }
    }

    /// AC-03.2.1: Grupos nas seções corretas, marcação inicial e paridade categoria<->grupo.
    func testDisplayGroupsSectionBirthAndParity() throws {
        let home = try makeScratchHome()
        let chromeRoot = home.appendingPathComponent("Library/Application Support/Google/Chrome")
        let firefoxRoot = home.appendingPathComponent("Library/Application Support/Firefox")

        let item1 = JunkCleaner.Item(
            url: chromeRoot, category: .browserCaches, size: 1000, detail: "Chrome",
            recommended: CleanerPolicy.precheckBrowserCaches,
            browserKey: "com.google.Chrome", browserName: "Google Chrome"
        )
        let item2 = JunkCleaner.Item(
            url: chromeRoot, category: .browserSiteData, size: 500, detail: "Chrome",
            recommended: CleanerPolicy.precheckBrowserSiteData,
            browserKey: "com.google.Chrome", browserName: "Google Chrome"
        )
        let item3 = JunkCleaner.Item(
            url: firefoxRoot, category: .browserCaches, size: 2000, detail: "Firefox",
            recommended: CleanerPolicy.precheckBrowserCaches,
            browserKey: "org.mozilla.firefox", browserName: "Firefox"
        )
        let item4 = JunkCleaner.Item(
            url: firefoxRoot, category: .browserSiteData, size: 1500, detail: "Firefox",
            recommended: CleanerPolicy.precheckBrowserSiteData,
            browserKey: "org.mozilla.firefox", browserName: "Firefox"
        )

        let cleaner = JunkCleaner(gate: CleanerPassGate())
        cleaner.items = [item1, item2, item3, item4]

        // Verify initial include states:
        XCTAssertTrue(item1.include)
        XCTAssertFalse(item2.include)
        XCTAssertTrue(item3.include)
        XCTAssertFalse(item4.include)

        // Section and category<->group wiring: exactly one group owns each
        // browser category, in the right section. A category without a group
        // would count in the header total without ever being visible.
        let cacheGroups = CleanerView.DisplayGroup.allCases.filter { $0.categories.contains(.browserCaches) }
        let siteDataGroups = CleanerView.DisplayGroup.allCases.filter { $0.categories.contains(.browserSiteData) }
        XCTAssertEqual(cacheGroups.count, 1, "Exactly one display group must own .browserCaches")
        XCTAssertEqual(siteDataGroups.count, 1, "Exactly one display group must own .browserSiteData")
        XCTAssertTrue(cacheGroups[0].isSafe, "Browser caches group must live in the safe section")
        XCTAssertFalse(siteDataGroups[0].isSafe, "Site data group must live in the judgment section")

        // Parity: every published browser item belongs to a visible group's category
        let allBrowserItems = cleaner.items.filter { $0.category == .browserCaches || $0.category == .browserSiteData }
        XCTAssertEqual(allBrowserItems.count, 4)
        for item in allBrowserItems {
            XCTAssertTrue(CleanerView.DisplayGroup.allCases.contains { $0.categories.contains(item.category) },
                          "Item of category \(item.category) has no display group")
        }
    }

    /// AC-03.2.2: composição da linha de pulado no doneState (helper de produção).
    func testDoneStateComposesSkippedLine() {
        let strings = L10n.shared.s
        for browser in ["Google Chrome", "Firefox", "Brave Browser"] {
            let line = CleanerView.skippedBrowserLine(browser, strings: strings)
            XCTAssertTrue(line.contains(browser), "Line must name the skipped browser")
            XCTAssertTrue(line.contains("pulado") || line.contains("skipped"))
        }
    }

    /// AC-03.2.4: scanningDetail resolve categoria de navegador para o grupo correspondente.
    func testScanningDetailResolvesBrowserGroup() {
        // The exact expression scanningDetail uses to map category -> group
        XCTAssertEqual(CleanerView.DisplayGroup.allCases.first { $0.categories.contains(.browserCaches) },
                       CleanerView.DisplayGroup.browserCaches)
        XCTAssertEqual(CleanerView.DisplayGroup.allCases.first { $0.categories.contains(.browserSiteData) },
                       CleanerView.DisplayGroup.browserSiteData)

        let strings = L10n.shared.s
        XCTAssertFalse(strings.cleanerCatBrowserCaches.isEmpty)
        XCTAssertFalse(strings.cleanerCatBrowserSiteData.isEmpty)
        XCTAssertFalse(strings.cleanerBrowserCachesCaption.isEmpty)
        XCTAssertFalse(strings.cleanerBrowserSiteDataCaption.isEmpty)
    }

    /// AC-03.2.5: browserAccessPending é publicado quando raiz de perfil não pode ser lida.
    func testPendingRendersNoteNotEmpty() throws {
        let home = try makeScratchHome()
        let chromeProfile = home.appendingPathComponent("Library/Application Support/Google/Chrome", isDirectory: true)
        try fm.createDirectory(at: chromeProfile, withIntermediateDirectories: true)
        // Set permissions 0o000 so it cannot be read
        try fm.setAttributes([.posixPermissions: 0o000], ofItemAtPath: chromeProfile.path)

        let cleaner = JunkCleaner(gate: CleanerPassGate())
        let scanExp = expectation(description: "scan finishes")
        var sub: AnyCancellable?
        sub = cleaner.$phase.dropFirst().sink { phase in
            if case .results = phase {
                scanExp.fulfill()
            }
        }

        cleaner.scan(attended: true, home: home.path)
        wait(for: [scanExp], timeout: 20)
        sub?.cancel()

        XCTAssertTrue(cleaner.browserAccessPending, "browserAccessPending must be published when browser root is unreadable")
        XCTAssertTrue(cleaner.items.filter { $0.category == .browserCaches || $0.category == .browserSiteData }.isEmpty,
                      "No browser items produced when access is pending")

        let strings = L10n.shared.s
        XCTAssertFalse(strings.cleanerBrowserAccessPendingReason.isEmpty)
    }

    // MARK: - Closeout regressions (M11 F)

    /// Safari keeps its cache and site data in the sandbox container on
    /// current macOS; the item must reach those paths and the guard must
    /// accept them.
    func testSafariIncludesContainerCacheAndSiteData() throws {
        let home = try makeScratchHome()
        let safariRoot = home.appendingPathComponent("Library/Safari", isDirectory: true)
        try fm.createDirectory(at: safariRoot, withIntermediateDirectories: true)
        try writeFile(safariRoot.appendingPathComponent("LocalStorage/entry.bin"), bytes: 128)

        let containerCache = home.appendingPathComponent(
            "Library/Containers/com.apple.Safari/Data/Library/Caches/com.apple.Safari",
            isDirectory: true)
        try writeDirWithFile(containerCache, fileName: "Cache.db", bytes: 4096)

        let websiteDataRoot = home.appendingPathComponent(
            "Library/Containers/com.apple.Safari/Data/Library/WebKit/WebsiteData",
            isDirectory: true)
        let websiteData = websiteDataRoot.appendingPathComponent("Default", isDirectory: true)
        try writeDirWithFile(websiteData, fileName: "origin.bin", bytes: 2048)

        let cookies = home.appendingPathComponent(
            "Library/Containers/com.apple.Safari/Data/Library/Cookies/Cookies.binarycookies")
        try writeFile(cookies, bytes: 512)

        let results = BrowserJunk.scanItems(home: home.path)
        let safari = try XCTUnwrap(results.first { $0.id == "com.apple.Safari" })
        XCTAssertFalse(safari.accessPending)
        XCTAssertTrue(safari.cacheTargets.contains {
            $0.url.standardizedFileURL.path == containerCache.standardizedFileURL.path
        }, "Safari container cache must be a target")
        XCTAssertGreaterThan(safari.cacheSize, 0)
        XCTAssertTrue(safari.siteDataTargets.contains {
            $0.url.standardizedFileURL.path == websiteDataRoot.standardizedFileURL.path
        }, "Safari container WebsiteData must be a target")
        XCTAssertTrue(safari.siteDataTargets.contains {
            $0.url.standardizedFileURL.path == cookies.standardizedFileURL.path
        }, "Safari container cookies must be a target")
        XCTAssertGreaterThan(safari.siteDataSize, 0)

        let cacheItem = JunkCleaner.Item(
            url: safari.rootURL, category: .browserCaches, size: safari.cacheSize,
            detail: safari.rootURL.path,
            recommended: CleanerPolicy.precheckBrowserCaches,
            browserKey: safari.id, browserName: safari.displayName,
            browserTargets: safari.cacheTargets)
        let siteItem = JunkCleaner.Item(
            url: safari.rootURL, category: .browserSiteData, size: safari.siteDataSize,
            detail: safari.rootURL.path,
            recommended: CleanerPolicy.precheckBrowserSiteData,
            browserKey: safari.id, browserName: safari.displayName,
            browserTargets: safari.siteDataTargets)
        XCTAssertTrue(JunkCleaner.mayRemove(cacheItem), "Guard must accept the container cache root")
        XCTAssertTrue(JunkCleaner.mayRemove(siteItem), "Guard must accept the container site data")
    }

    private func scanAndWait(_ cleaner: JunkCleaner, home: URL, attended: Bool = true) {
        let done = expectation(description: "scan finishes")
        var sub: AnyCancellable?
        sub = cleaner.$phase.dropFirst().sink { phase in
            if case .results = phase { done.fulfill() }
        }
        cleaner.scan(attended: attended, home: home.path)
        wait(for: [done], timeout: 20)
        sub?.cancel()
    }

    /// A generic cache row must never contain (or be contained by) a browser
    /// cache target: the same bytes cannot count twice, and the generic row
    /// cannot move a browser target a second time. A vendor folder that holds
    /// a browser root must still offer its other children.
    func testGenericCachesDoNotOverlapBrowserCacheTargets() throws {
        let home = try makeScratchHome()

        let chromeProfile = home.appendingPathComponent("Library/Application Support/Google/Chrome/Default", isDirectory: true)
        try fm.createDirectory(at: chromeProfile, withIntermediateDirectories: true)
        try writeFile(chromeProfile.appendingPathComponent("Cookies"), bytes: 512)

        let chromeCache = home.appendingPathComponent("Library/Caches/Google/Chrome/Default/Cache", isDirectory: true)
        try writeDirWithFile(chromeCache, fileName: "cache.bin", bytes: 4096)

        let siblingCache = home.appendingPathComponent("Library/Caches/Google/AndroidStudio2026.2.1", isDirectory: true)
        try writeDirWithFile(siblingCache, fileName: "studio.bin", bytes: 2048)

        let cleaner = JunkCleaner(gate: CleanerPassGate())
        scanAndWait(cleaner, home: home)

        let browserTargets = cleaner.items
            .filter { $0.category == .browserCaches || $0.category == .browserSiteData }
            .flatMap(\.browserTargets)
            .map { $0.url.standardizedFileURL.path }
        XCTAssertFalse(browserTargets.isEmpty)

        let generic = cleaner.items.filter { $0.category == .caches }
        for item in generic {
            let path = item.url.standardizedFileURL.path
            for target in browserTargets {
                XCTAssertFalse(path == target || target.hasPrefix(path + "/") || path.hasPrefix(target + "/"),
                               "Generic cache row \(path) overlaps browser target \(target)")
            }
        }

        XCTAssertTrue(generic.contains { $0.url.standardizedFileURL.path == siblingCache.standardizedFileURL.path },
                      "A non-browser cache inside a browser vendor folder must stay offered")
    }

    /// A browser root with no installed profile keeps its row in the generic
    /// caches instead of disappearing from the Cleaner.
    func testUnusedBrowserCacheRootStaysInGenericCaches() throws {
        let home = try makeScratchHome()
        let operaCache = home.appendingPathComponent("Library/Caches/com.operasoftware.Opera", isDirectory: true)
        try writeDirWithFile(operaCache, fileName: "old.bin", bytes: 1024)

        let cleaner = JunkCleaner(gate: CleanerPassGate())
        scanAndWait(cleaner, home: home)

        XCTAssertFalse(cleaner.items.contains { $0.category == .browserCaches || $0.category == .browserSiteData },
                       "No profile means no browser item")
        XCTAssertTrue(cleaner.items.contains {
            $0.url.standardizedFileURL.path == operaCache.standardizedFileURL.path
        }, "An orphan browser cache root must stay reachable in some category; items: \(cleaner.items.map { ($0.category.rawValue, $0.url.path) })")
    }

    /// The guard accepts only targets anchored to a registered profile or
    /// cache root, never any path that ends with a known subpath name.
    func testGuardRefusesTargetOutsideRegisteredBrowserRoots() throws {
        let home = try makeScratchHome()
        let chromeRoot = home.appendingPathComponent("Library/Application Support/Google/Chrome", isDirectory: true)
        try fm.createDirectory(at: chromeRoot, withIntermediateDirectories: true)

        let foreignCookies = home.appendingPathComponent("Library/Application Support/SomeOtherApp/Cookies")
        try writeFile(foreignCookies, bytes: 512)

        let item = JunkCleaner.Item(
            url: chromeRoot, category: .browserCaches, size: 512, detail: "Chrome",
            recommended: CleanerPolicy.precheckBrowserCaches,
            browserKey: "com.google.Chrome", browserName: "Google Chrome",
            browserTargets: [BrowserJunk.Target(url: foreignCookies)]
        )

        XCTAssertFalse(JunkCleaner.mayRemove(item),
                       "A target outside the registered browser roots must be refused")
    }

    /// Site data targets must not contain one another: a parent and its child
    /// would count the same bytes twice and move them twice.
    func testBrowserTargetsDoNotNest() throws {
        let home = try makeScratchHome()
        let profile = home.appendingPathComponent("Library/Application Support/Firefox/Profiles/p1", isDirectory: true)
        let storageDefault = profile.appendingPathComponent("storage/default", isDirectory: true)
        try writeDirWithFile(storageDefault, fileName: "idb.bin", bytes: 1024)
        try writeDirWithFile(profile.appendingPathComponent("storage", isDirectory: true), fileName: "other.bin", bytes: 512)
        try writeFile(profile.appendingPathComponent("cookies.sqlite"), bytes: 256)

        let results = BrowserJunk.scanItems(home: home.path)
        let firefox = try XCTUnwrap(results.first { $0.id == "org.mozilla.firefox" })
        let paths = firefox.siteDataTargets.map { $0.url.standardizedFileURL.path }
        for a in paths {
            for b in paths where a != b {
                XCTAssertFalse(a.hasPrefix(b + "/"), "Target \(a) nests inside \(b)")
            }
        }
    }
}
