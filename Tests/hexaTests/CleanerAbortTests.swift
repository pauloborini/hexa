// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Pins the total abort. Reset ends a scan or a clean in flight: the gate is
/// given back at once, a clean stops before its next item, and the Trash is
/// not emptied past the entry that was next. A result that arrives after the
/// abort is dropped. The clean fixtures are the refused `.packageCaches` files
/// of `CleanerPassGateTests`, and the Trash is always a scratch folder, so the
/// real Trash, Finder and the real home are never modified.
final class CleanerAbortTests: XCTestCase {
    private let fm = FileManager.default

    /// A guard for the test itself, never a product deadline: the measurement
    /// has no deadline of its own, so a loaded machine may take far longer than
    /// a minute to finish. Same guard as `SpaceInventoryTests.testDeadline`.
    private static let testDeadline: TimeInterval = 600

    /// Said when a wait runs past the guard, so a failure names the guard
    /// instead of reading like a product timeout.
    private static let deadlineMessage =
        "the measurement must finish within the test guard of \(Int(testDeadline)) s, "
        + "which only exists in the test: the product has no deadline"

    /// A unique scratch folder under the temporary directory, removed when the test ends.
    private func makeScratchRoot() -> URL {
        let root = fm.temporaryDirectory
            .appendingPathComponent("hexa-cleanerabort-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }

    /// Writes `count` refused fixture files and returns them as selected items.
    private func makeItems(count: Int) throws -> [JunkCleaner.Item] {
        let root = makeScratchRoot()
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        return try (0..<count).map { index in
            let url = root.appendingPathComponent("entry-\(index)")
            try Data(count: 4096).write(to: url)
            return JunkCleaner.Item(url: url, category: .packageCaches, size: 4096,
                                    detail: "fixture", recommended: true)
        }
    }

    /// A scratch folder that stands in for the Trash, with `entries` files in it.
    private func makeTrash(entries: Int) throws -> URL {
        let trash = makeScratchRoot().appendingPathComponent("trash", isDirectory: true)
        try fm.createDirectory(at: trash, withIntermediateDirectories: true)
        for index in 0..<entries {
            try Data(count: 1024).write(to: trash.appendingPathComponent("entry-\(index)"))
        }
        return trash
    }

    func testAbortDuringAScanReleasesTheGateAndDropsTheScan() {
        let gate = CleanerPassGate()
        let cleaner = JunkCleaner(passHolder: .manual, gate: gate)
        let home = makeScratchRoot()

        cleaner.scan(attended: false, home: home.path)
        XCTAssertEqual(cleaner.phase, .scanning)
        XCTAssertEqual(gate.holder, .manual, "a scan holds the gate")

        // The main thread does not run its loop between the scan and the
        // abort, so the scan cannot have published its results yet.
        cleaner.reset()
        XCTAssertEqual(cleaner.phase, .idle)
        XCTAssertNil(gate.holder, "the abort gives the gate back at once")

        // Let the abandoned scan finish. Its results must not reach the idle cleaner.
        RunLoop.main.run(until: Date().addingTimeInterval(2))
        XCTAssertEqual(cleaner.phase, .idle)
        XCTAssertTrue(cleaner.items.isEmpty)
    }

    func testAbortDuringACleanReleasesTheGateAtOnce() throws {
        let gate = CleanerPassGate()
        let cleaner = JunkCleaner(passHolder: .manual, gate: gate)
        cleaner.items = try makeItems(count: 2)
        cleaner.setPhaseForTesting(.results)

        cleaner.cleanSelected(escalate: false)
        XCTAssertEqual(cleaner.phase, .cleaning)
        XCTAssertEqual(gate.holder, .manual)

        cleaner.reset()
        XCTAssertEqual(cleaner.phase, .idle)
        XCTAssertNil(gate.holder)

        RunLoop.main.run(until: Date().addingTimeInterval(1))
        XCTAssertEqual(cleaner.phase, .idle)
        XCTAssertTrue(cleaner.failedItems.isEmpty)
    }

    func testTheCompletionOfAnAbortedCleanCannotEndANewerPass() throws {
        let gate = CleanerPassGate()
        let cleaner = JunkCleaner(passHolder: .manual, gate: gate)
        cleaner.items = try makeItems(count: 2)
        cleaner.setPhaseForTesting(.results)

        cleaner.cleanSelected(escalate: false)
        // The background clean finishes while the main thread is blocked here,
        // so its completion waits in the main queue, not yet applied.
        Thread.sleep(forTimeInterval: 0.5)
        cleaner.reset()
        // A newer pass of this instance is in progress when the old completion runs.
        cleaner.setPhaseForTesting(.cleaning)
        RunLoop.main.run(until: Date().addingTimeInterval(1))

        XCTAssertEqual(cleaner.phase, .cleaning,
                       "the aborted clean's completion must not end the newer pass")
        XCTAssertTrue(cleaner.failedItems.isEmpty)
    }

    func testEmptyingTheTrashStopsBeforeTheNextEntryOnceAborted() throws {
        let trash = try makeTrash(entries: 3)
        var checks = 0

        // The first entry is removed; the abort is reported before the second.
        let outcomes = JunkCleaner.emptyTrash(at: trash, scanned: JunkCleaner.scannedTrashEntries(in: trash), isCancelled: {
            checks += 1
            return checks > 1
        })

        XCTAssertEqual(outcomes.count, 1)
        let remaining = try fm.contentsOfDirectory(atPath: trash.path)
        XCTAssertEqual(remaining.count, 2)
    }

    func testEmptyingTheTrashRemovesNothingWhenAbortedFirst() throws {
        let trash = try makeTrash(entries: 2)

        let outcomes = JunkCleaner.emptyTrash(at: trash, scanned: JunkCleaner.scannedTrashEntries(in: trash), isCancelled: { true })

        XCTAssertTrue(outcomes.isEmpty)
        let remaining = try fm.contentsOfDirectory(atPath: trash.path)
        XCTAssertEqual(remaining.count, 2)
    }

    func testCancellingAMeasurementKeepsTheRowsMeasuredBefore() throws {
        let cleaner = JunkCleaner(passHolder: .manual, gate: CleanerPassGate())
        let withCodex = makeScratchRoot()
        let codex = withCodex.appendingPathComponent(".codex", isDirectory: true)
        try fm.createDirectory(at: codex, withIntermediateDirectories: true)
        try Data(count: 1024).write(to: codex.appendingPathComponent("session.bin"))
        let empty = makeScratchRoot()
        try fm.createDirectory(at: empty, withIntermediateDirectories: true)
        // An empty applications folder: the map's third root, so the walk never measures the real /Applications.
        let applications = makeScratchRoot()
        try fm.createDirectory(at: applications, withIntermediateDirectories: true)

        // A first measurement completes, so there is a row to keep.
        cleaner.measureSpaceInventory(home: withCodex.path, applications: applications.path)
        let completeDeadline = Date().addingTimeInterval(Self.testDeadline)
        while cleaner.spaceInventoryIsComputing, Date() < completeDeadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        XCTAssertFalse(cleaner.spaceInventoryIsComputing, Self.deadlineMessage)
        let measured = try XCTUnwrap(cleaner.spaceInventory)
        XCTAssertFalse(measured.isEmpty, "the fixture must yield a row to keep")

        // A second measurement, over a home with nothing in it, is cancelled before it lands.
        cleaner.measureSpaceInventory(home: empty.path, applications: applications.path)
        let cancellation = try XCTUnwrap(cleaner.spaceInventoryCancellation)
        cleaner.cancelSpaceInventory()

        XCTAssertTrue(cancellation.isCancelled)
        XCTAssertFalse(cleaner.spaceInventoryIsComputing)
        XCTAssertEqual(cleaner.spaceInventory, measured, "the rows measured before the cancel stay")

        // Let the cancelled measurement finish: its empty rows must not replace the kept ones.
        RunLoop.main.run(until: Date().addingTimeInterval(1))
        XCTAssertEqual(cleaner.spaceInventory, measured)
    }
}
