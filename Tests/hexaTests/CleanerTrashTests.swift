// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Pins the Trash row's removal: `emptyTrash(at:scanned:)` removes exactly the
/// scanned entries of the folder it is given, through FileManager. Every fixture lives
/// in a scratch folder under the temporary directory. The real home, the real
/// Trash, Finder and launchctl are never reached: the default URL is never
/// passed, and `.trash` is never run through `cleanSelected`.
final class CleanerTrashTests: XCTestCase {
    private let fm = FileManager.default

    /// Creates a unique scratch root. When the test ends, write access is
    /// restored on every folder inside it (a read-only folder cannot be
    /// deleted), and then the whole root is removed.
    private func makeScratchRoot() throws -> URL {
        let root = fm.temporaryDirectory
            .appendingPathComponent("hexa-cleanertrash-\(UUID().uuidString)", isDirectory: true)
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
        try Data(count: bytes).write(to: url)
    }

    func testEmptyTrashRemovesVisibleEntriesAndKeepsHiddenOnes() throws {
        let trash = try makeScratchRoot().appendingPathComponent("trash", isDirectory: true)
        try fm.createDirectory(at: trash, withIntermediateDirectories: true)
        let first = trash.appendingPathComponent("first.txt")
        let second = trash.appendingPathComponent("second.txt")
        let hidden = trash.appendingPathComponent(".DS_Store")
        try writeFile(first, bytes: 10_000)
        try writeFile(second, bytes: 20_000)
        try writeFile(hidden, bytes: 4_096)

        let expected = JunkCleaner.directorySize(of: first, fm: fm)
            + JunkCleaner.directorySize(of: second, fm: fm)
        XCTAssertGreaterThan(expected, 0)

        let outcomes = JunkCleaner.emptyTrash(at: trash, scanned: JunkCleaner.scannedTrashEntries(in: trash))
        let totals = CleanerSupport.removalTotals(outcomes)

        XCTAssertEqual(outcomes.count, 2)
        XCTAssertEqual(totals.freedPermanently, expected)
        XCTAssertEqual(totals.failed, 0)
        XCTAssertFalse(fm.fileExists(atPath: first.path))
        XCTAssertFalse(fm.fileExists(atPath: second.path))
        XCTAssertTrue(fm.fileExists(atPath: hidden.path))
    }

    func testMissingTrashOrOnlyHiddenEntriesProduceNoOutcomes() throws {
        let root = try makeScratchRoot()
        let missing = root.appendingPathComponent("missing", isDirectory: true)
        XCTAssertEqual(JunkCleaner.emptyTrash(at: missing, scanned: JunkCleaner.scannedTrashEntries(in: missing)), [])

        let trash = root.appendingPathComponent("trash", isDirectory: true)
        try fm.createDirectory(at: trash, withIntermediateDirectories: true)
        let hidden = trash.appendingPathComponent(".DS_Store")
        try writeFile(hidden, bytes: 4_096)

        XCTAssertEqual(JunkCleaner.emptyTrash(at: trash, scanned: JunkCleaner.scannedTrashEntries(in: trash)), [])
        XCTAssertTrue(fm.fileExists(atPath: hidden.path))
    }

    func testSymbolicLinkStandingInForTheTrashIsRefusedAndTargetIsKept() throws {
        let root = try makeScratchRoot()
        let target = root.appendingPathComponent("link-target", isDirectory: true)
        try fm.createDirectory(at: target, withIntermediateDirectories: true)
        let kept = target.appendingPathComponent("kept.txt")
        try writeFile(kept, bytes: 4_096)
        let link = root.appendingPathComponent("trash-link")
        try fm.createSymbolicLink(at: link, withDestinationURL: target)

        let outcomes = JunkCleaner.emptyTrash(at: link, scanned: JunkCleaner.scannedTrashEntries(in: link))

        XCTAssertEqual(outcomes, [.failed])
        XCTAssertTrue(fm.fileExists(atPath: kept.path))
        XCTAssertTrue(UninstallerSupport.isSymbolicLink(link))
    }

    func testEntriesThatCannotBeRemovedReportFailedAndStayOnDisk() throws {
        let trash = try makeScratchRoot().appendingPathComponent("trash", isDirectory: true)
        try fm.createDirectory(at: trash, withIntermediateDirectories: true)
        let first = trash.appendingPathComponent("first.txt")
        let second = trash.appendingPathComponent("second.txt")
        try writeFile(first, bytes: 4_096)
        try writeFile(second, bytes: 4_096)
        // Read-only folder: its entries cannot be unlinked. The teardown restores access.
        try fm.setAttributes([.posixPermissions: 0o555], ofItemAtPath: trash.path)

        let outcomes = JunkCleaner.emptyTrash(at: trash, scanned: JunkCleaner.scannedTrashEntries(in: trash))

        XCTAssertEqual(outcomes, [.failed, .failed])
        XCTAssertEqual(CleanerSupport.removalTotals(outcomes).freedPermanently, 0)
        XCTAssertTrue(fm.fileExists(atPath: first.path))
        XCTAssertTrue(fm.fileExists(atPath: second.path))
    }

    // ISSUE-201: what reached the Trash after the scan, new or under a scanned
    // name, is never removed.
    func testEntriesThatArrivedAfterTheScanStay() throws {
        let trash = try makeScratchRoot().appendingPathComponent("trash", isDirectory: true)
        try fm.createDirectory(at: trash, withIntermediateDirectories: true)
        let scannedFile = trash.appendingPathComponent("scanned.txt")
        let replaced = trash.appendingPathComponent("replaced.txt")
        try writeFile(scannedFile, bytes: 4_096)
        try writeFile(replaced, bytes: 4_096)
        let scanned = JunkCleaner.scannedTrashEntries(in: trash)

        let late = trash.appendingPathComponent("late.txt")
        try writeFile(late, bytes: 4_096)
        try fm.removeItem(at: replaced)
        try writeFile(replaced, bytes: 8_192)

        let outcomes = JunkCleaner.emptyTrash(at: trash, scanned: scanned)

        XCTAssertEqual(outcomes.count, 1)
        XCTAssertFalse(fm.fileExists(atPath: scannedFile.path))
        XCTAssertTrue(fm.fileExists(atPath: late.path))
        XCTAssertTrue(fm.fileExists(atPath: replaced.path))
    }
}
