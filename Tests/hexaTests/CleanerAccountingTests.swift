// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Pins the accounting of one clean: only bytes removed for good count as
/// freed, bytes moved to the Trash are reported apart, and an item with no
/// confirmed removal enters no total. The totals are pure values; the absence
/// check runs only on a scratch folder under the temporary directory.
final class CleanerAccountingTests: XCTestCase {
    private let gib: Int64 = 1 << 30

    func testEmptiedTrashIsFreedWhileMovedBytesStayReportedAsMoved() {
        let totals = CleanerSupport.removalTotals([
            .removedPermanently(size: gib),
            .movedToTrash(size: 2 * gib),
        ])

        XCTAssertEqual(totals.freedPermanently, gib)
        XCTAssertEqual(totals.movedToTrash, 2 * gib)
        XCTAssertEqual(totals.failed, 0)
    }

    func testOnlyMovedBytesFreeNothingPermanently() {
        let totals = CleanerSupport.removalTotals([.movedToTrash(size: 2 * gib)])

        XCTAssertEqual(totals.freedPermanently, 0)
        XCTAssertEqual(totals.movedToTrash, 2 * gib)
    }

    func testFailedItemEntersNoSizeTotal() {
        let totals = CleanerSupport.removalTotals([.failed, .movedToTrash(size: 5)])

        XCTAssertEqual(totals.failed, 1)
        XCTAssertEqual(totals.movedToTrash, 5)
        XCTAssertEqual(totals.freedPermanently, 0)
    }

    func testHomebrewRemovalCountsAsPermanent() {
        let totals = UninstallerSupport.removalTotals([.removedPermanently(size: 3 * gib)])

        XCTAssertEqual(totals.freedPermanently, 3 * gib)
        XCTAssertEqual(totals.movedToTrash, 0)
    }

    func testMovedLeftoverCountsAsMovedAndNotAsFreed() {
        let totals = UninstallerSupport.removalTotals([
            .removedPermanently(size: 3 * gib),
            .movedToTrash(size: 4_096),
        ])

        XCTAssertEqual(totals.freedPermanently, 3 * gib)
        XCTAssertEqual(totals.movedToTrash, 4_096)
    }

    // MARK: Confirmed absence (Finder branch classification)

    /// A unique scratch folder under the system temporary directory, removed
    /// when the test ends. Never a real user path.
    private func makeScratchDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hexa-accounting-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }

    func testConfirmedAbsenceIsFalseForAnExistingFile() throws {
        let file = try makeScratchDirectory().appendingPathComponent("present.txt")
        try Data("x".utf8).write(to: file)

        XCTAssertFalse(UninstallerSupport.isConfirmedAbsent(at: file))
    }

    func testConfirmedAbsenceIsTrueForAMissingPath() throws {
        let root = try makeScratchDirectory()

        XCTAssertTrue(UninstallerSupport.isConfirmedAbsent(at: root.appendingPathComponent("missing.txt")))
    }

    func testConfirmedAbsenceIsFalseForADanglingSymlink() throws {
        let root = try makeScratchDirectory()
        let link = root.appendingPathComponent("dangling")
        try FileManager.default.createSymbolicLink(
            at: link, withDestinationURL: root.appendingPathComponent("no-target"))

        XCTAssertFalse(UninstallerSupport.isConfirmedAbsent(at: link))
    }
}
