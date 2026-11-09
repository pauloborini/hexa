// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Pins the package manager cache rules: only the six exact subpaths under
/// the home folder are ever accepted, a symbolic link never is, every find is
/// born unchecked, a scan lists only the present non-empty subpaths, and an
/// unattended pass with nothing selected moves nothing. Every test runs on a
/// scratch home under the temporary directory; the real home is never read.
final class PackageCachePolicyTests: XCTestCase {
    private let expectedSubpaths = [
        ".npm/_cacache",
        ".gradle/caches",
        ".gradle/wrapper/dists",
        ".pub-cache/hosted",
        ".cache/uv",
        ".cache/puppeteer",
    ]

    /// A unique scratch home under the system temporary directory, removed
    /// when the test ends.
    private func makeFixtureHome() throws -> String {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hexa-packagecache-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root.standardizedFileURL.path
    }

    /// Writes a file of exactly `bytes` zero bytes under `home`, creating the
    /// folders above it.
    private func write(_ bytes: Int, to relativePath: String, in home: String) throws {
        let url = URL(fileURLWithPath: home + "/" + relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data(count: bytes).write(to: url)
    }

    func testPolicyAcceptsExactlyTheSixSubpaths() throws {
        let home = try makeFixtureHome()

        XCTAssertEqual(CleanerPolicy.packageCacheSubpaths, expectedSubpaths)
        for subpath in expectedSubpaths {
            try write(1, to: subpath + "/entry", in: home)
            let url = URL(fileURLWithPath: home + "/" + subpath, isDirectory: true)
            XCTAssertTrue(CleanerPolicy.isPackageCacheRemovalAllowed(url, home: home), subpath)
        }
    }

    func testPolicyRejectsRootsConfigurationExecutablesAndChildren() throws {
        let home = try makeFixtureHome()
        try write(1, to: ".gradle/gradle.properties", in: home)
        try write(1, to: ".pub-cache/bin/dart", in: home)
        try write(1, to: ".npm/package.json", in: home)
        try write(1, to: ".gradle/caches/modules/entry", in: home)
        let rejected = [
            "",
            ".gradle",
            ".gradle/gradle.properties",
            ".pub-cache",
            ".pub-cache/bin",
            ".npm",
            ".npm/package.json",
            ".gradle/caches/modules",
        ]

        for relativePath in rejected {
            let url = URL(fileURLWithPath: relativePath.isEmpty ? home : home + "/" + relativePath)
            XCTAssertFalse(CleanerPolicy.isPackageCacheRemovalAllowed(url, home: home), relativePath)
        }
    }

    func testPolicyRejectsASymbolicLinkSittingAtAnAllowedSubpath() throws {
        let home = try makeFixtureHome()
        let target = URL(fileURLWithPath: home + "/elsewhere", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: home + "/.npm", withIntermediateDirectories: true)
        let link = URL(fileURLWithPath: home + "/.npm/_cacache", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        XCTAssertFalse(CleanerPolicy.isPackageCacheRemovalAllowed(link, home: home))
    }

    func testScannedItemsAreBornUnselectedAndAnUnattendedPassMovesNothing() throws {
        let home = try makeFixtureHome()
        try write(4096, to: ".npm/_cacache/content/a", in: home)
        try write(4096, to: ".cache/uv/archive/b", in: home)

        let items = JunkCleaner.scanPackageCaches(home: home)

        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items.allSatisfy { !$0.include && !$0.recommended && $0.category == .packageCaches })

        // The unattended pass cleans only what is selected. Nothing is, so
        // the clean must leave every fixture file in place.
        JunkCleaner.shared.items = items
        JunkCleaner.shared.setPhaseForTesting(.results)
        addTeardownBlock { JunkCleaner.shared.reset() }
        JunkCleaner.shared.cleanSelected(escalate: false)

        XCTAssertTrue(FileManager.default.fileExists(atPath: home + "/.npm/_cacache/content/a"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: home + "/.cache/uv/archive/b"))
    }

    func testScanListsExactlyThePresentNonEmptySubpathsWithTheirByteTotals() throws {
        let home = try makeFixtureHome()
        try write(8192, to: ".npm/_cacache/content/a", in: home)
        try write(4096, to: ".npm/_cacache/index", in: home)
        try write(16384, to: ".gradle/caches/modules/entry", in: home)
        try write(4096, to: ".cache/uv/archive/b", in: home)
        // Outside the six subpaths: never offered.
        try write(4096, to: ".pub-cache/bin/dart", in: home)
        try write(4096, to: ".gradle/gradle.properties", in: home)
        // Present but empty: no bytes, so not offered.
        try FileManager.default.createDirectory(atPath: home + "/.gradle/wrapper/dists",
                                                withIntermediateDirectories: true)

        let items = JunkCleaner.scanPackageCaches(home: home)

        XCTAssertEqual(items.map(\.detail), [".gradle/caches", ".npm/_cacache", ".cache/uv"])
        XCTAssertEqual(items.map(\.size), [16384, 12288, 4096])
    }
}
