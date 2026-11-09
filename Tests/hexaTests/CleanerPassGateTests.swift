// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Pins the Cleaner-wide pass gate: the first pass takes it, the other kind
/// is refused until it is released, and a reset of one kind cannot free the
/// other. Every test builds its own gate, so none depends on another. The
/// fixtures are scratch files in the `.packageCaches` category, which the
/// removal rule refuses, so nothing moves and the real home, Finder,
/// launchctl and the Trash are never reached.
final class CleanerPassGateTests: XCTestCase {
    /// Writes `count` scratch files under a unique folder and returns them as
    /// selected items. The folder is removed when the test ends.
    private func makeItems(count: Int) throws -> [JunkCleaner.Item] {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hexa-cleanerpassgate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return try (0..<count).map { index in
            let url = root.appendingPathComponent("entry-\(index)")
            try Data(count: 4096).write(to: url)
            return JunkCleaner.Item(url: url, category: .packageCaches, size: 4096,
                                    detail: "fixture", recommended: true)
        }
    }

    /// Pumps the main run loop until the clean reports `.done`, then returns the phase.
    private func waitForCleanToEnd(_ cleaner: JunkCleaner) -> JunkCleaner.Phase {
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline {
            if case .done = cleaner.phase { break }
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        return cleaner.phase
    }

    func testTheFirstRequesterTakesAFreeGate() {
        let gate = CleanerPassGate()
        XCTAssertNil(gate.holder)

        XCTAssertTrue(gate.acquire(.automatic))

        XCTAssertEqual(gate.holder, .automatic)
    }

    func testTheOtherKindIsRefusedWhileTheGateIsHeld() {
        let gate = CleanerPassGate()
        XCTAssertTrue(gate.acquire(.manual))

        XCTAssertFalse(gate.acquire(.automatic))
        XCTAssertEqual(gate.holder, .manual)
    }

    func testTheHolderMayAcquireAgain() {
        let gate = CleanerPassGate()
        XCTAssertTrue(gate.acquire(.manual))

        XCTAssertTrue(gate.acquire(.manual))
        XCTAssertEqual(gate.holder, .manual)
    }

    func testReleaseByTheOtherKindChangesNothing() {
        let gate = CleanerPassGate()
        XCTAssertTrue(gate.acquire(.automatic))

        gate.release(.manual)

        XCTAssertEqual(gate.holder, .automatic)
    }

    func testReleaseFreesTheGateForTheOtherKind() {
        let gate = CleanerPassGate()
        XCTAssertTrue(gate.acquire(.manual))

        gate.release(.manual)

        XCTAssertNil(gate.holder)
        XCTAssertTrue(gate.acquire(.automatic))
    }

    func testAScanIsRefusedWhileTheAutomaticPassHoldsTheGate() {
        let gate = CleanerPassGate()
        XCTAssertTrue(gate.acquire(.automatic))
        let manual = JunkCleaner(passHolder: .manual, gate: gate)

        manual.scan(attended: false)

        XCTAssertEqual(manual.phase, .idle)
        XCTAssertEqual(gate.holder, .automatic)
    }

    func testACleanIsRefusedWhileTheAutomaticPassHoldsTheGate() throws {
        let gate = CleanerPassGate()
        XCTAssertTrue(gate.acquire(.automatic))
        let manual = JunkCleaner(passHolder: .manual, gate: gate)
        let items = try makeItems(count: 2)
        manual.items = items
        manual.setPhaseForTesting(.results)

        manual.cleanSelected(escalate: false)

        XCTAssertEqual(manual.phase, .results)
        XCTAssertEqual(manual.items.map(\.id), items.map(\.id))
        XCTAssertEqual(gate.holder, .automatic)
    }

    func testResetFreesOnlyTheGateOfItsOwnKind() {
        let gate = CleanerPassGate()
        XCTAssertTrue(gate.acquire(.automatic))
        let manual = JunkCleaner(passHolder: .manual, gate: gate)

        manual.reset()
        XCTAssertEqual(gate.holder, .automatic)

        let automatic = JunkCleaner(passHolder: .automatic, gate: gate)
        automatic.reset()
        XCTAssertNil(gate.holder)
    }

    func testAFinishedCleanReleasesTheGate() throws {
        let gate = CleanerPassGate()
        let cleaner = JunkCleaner(passHolder: .manual, gate: gate)
        cleaner.items = try makeItems(count: 2)
        cleaner.setPhaseForTesting(.results)

        cleaner.cleanSelected(escalate: false)
        XCTAssertEqual(gate.holder, .manual, "a clean holds the gate while it runs")

        XCTAssertEqual(waitForCleanToEnd(cleaner),
                       .done(movedToTrash: 0, freedPermanently: 0, failed: 2))
        XCTAssertNil(gate.holder, "a finished clean gives the gate back")
    }
}
