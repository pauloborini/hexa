// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Pins what a clean keeps about the items it could not remove. Each item
/// that fails is recorded in `failedItems` with its path, category and a
/// reason, while `items` is still emptied as before. Every item here is one
/// whose removal fails: a path that does not exist, and a path under
/// `/System` that the safety guard refuses. Escalation is off, so no Finder
/// call or administrator prompt can happen. The real home, the real Trash,
/// Finder and launchctl are never reached, and no existing file is ever used
/// as an item.
final class CleanerFailedItemsTests: XCTestCase {
    /// A fresh cleaner per test: never the shared instance.
    private func makeCleaner() -> JunkCleaner {
        JunkCleaner()
    }

    /// Runs one clean with escalation off and waits on the main run loop for
    /// its `.done` phase. The completion block publishes `failedItems` before
    /// the phase, so the lists are final when this returns.
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
        wait(for: [completed], timeout: 30)
        subscription.cancel()
        return finished
    }

    func testFailedItemsKeepPathCategoryAndReasonAfterACleanEnds() {
        let cleaner = makeCleaner()
        let root = URL(fileURLWithPath: "/System/Library/hexa-cleaner-failed-items-\(UUID().uuidString)", isDirectory: true)
        let refused = JunkCleaner.Item(
            url: root.appendingPathComponent("refused.bin"),
            category: .caches, size: 4096, detail: "fixture", recommended: true)
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("hexa-cleanerfailed-\(UUID().uuidString)", isDirectory: true)
        let missing = JunkCleaner.Item(
            url: scratch.appendingPathComponent("never-created.bin"),
            category: .packageCaches, size: 4096, detail: "fixture", recommended: true)

        let phase = cleanAndWait(cleaner, items: [missing, refused])

        guard case .done(let moved, let freed, let failed) = phase else {
            return XCTFail("the clean did not end in .done: \(String(describing: phase))")
        }
        XCTAssertEqual(moved, 0)
        XCTAssertEqual(freed, 0)
        XCTAssertEqual(failed, 2)

        XCTAssertEqual(cleaner.failedItems.map(\.url), [missing.url, refused.url])
        XCTAssertEqual(cleaner.failedItems.map(\.category), [.packageCaches, .caches])
        XCTAssertEqual(cleaner.failedItems.count, 2)
        for entry in cleaner.failedItems {
            XCTAssertFalse(entry.reason.isEmpty, entry.url.path)
        }
    }

    func testItemsStayEmptyAfterACleanEnds() {
        let cleaner = makeCleaner()
        let missing = JunkCleaner.Item(
            url: FileManager.default.temporaryDirectory
                .appendingPathComponent("hexa-cleanerfailed-\(UUID().uuidString)/never-created.bin"),
            category: .packageCaches, size: 4096, detail: "fixture", recommended: true)

        let phase = cleanAndWait(cleaner, items: [missing])

        XCTAssertEqual(phase, .done(movedToTrash: 0, freedPermanently: 0, failed: 1))
        XCTAssertTrue(cleaner.items.isEmpty)
        XCTAssertEqual(cleaner.failedItems.map(\.url), [missing.url])
    }

    func testResetClearsFailedItems() {
        let cleaner = makeCleaner()
        let missing = JunkCleaner.Item(
            url: FileManager.default.temporaryDirectory
                .appendingPathComponent("hexa-cleanerfailed-\(UUID().uuidString)/never-created.bin"),
            category: .packageCaches, size: 4096, detail: "fixture", recommended: true)

        _ = cleanAndWait(cleaner, items: [missing])
        XCTAssertEqual(cleaner.failedItems.count, 1)

        cleaner.reset()

        XCTAssertTrue(cleaner.failedItems.isEmpty)
        XCTAssertTrue(cleaner.items.isEmpty)
        XCTAssertEqual(cleaner.phase, .idle)
    }
}
