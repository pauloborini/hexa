// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Pins the clean entry guard: a clean starts only from `.results`, and a
/// second call while a pass is in flight changes nothing. Fixtures are
/// scratch files under the temporary directory. Their category is
/// `.packageCaches`, whose removal rule accepts only the real home's package
/// cache subpaths, so every fixture is refused before any move is attempted:
/// the real home, Finder, launchctl and the Trash are never reached.
final class CleanerReentrancyTests: XCTestCase {
    /// Writes `count` fixture files under a unique scratch folder and returns
    /// them as selected items. The folder is removed when the test ends.
    private func makeItems(count: Int) throws -> [JunkCleaner.Item] {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hexa-cleanerreentrancy-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return try (0..<count).map { index in
            let url = root.appendingPathComponent("entry-\(index)")
            try Data(count: 4096).write(to: url)
            return JunkCleaner.Item(url: url, category: .packageCaches, size: 4096,
                                    detail: "fixture", recommended: true)
        }
    }

    func testCleanIsIgnoredOutsideTheResultsPhase() throws {
        let cleaner = JunkCleaner.shared
        addTeardownBlock { cleaner.reset() }
        let items = try makeItems(count: 2)
        let phases: [JunkCleaner.Phase] = [
            .idle,
            .scanning,
            .cleaning,
            .done(movedToTrash: 1, freedPermanently: 0, failed: 0),
        ]

        for phase in phases {
            cleaner.items = items
            cleaner.setPhaseForTesting(phase)
            cleaner.cleanSelected(escalate: false)

            XCTAssertEqual(cleaner.phase, phase, "\(phase)")
            XCTAssertEqual(cleaner.items.map(\.id), items.map(\.id), "\(phase)")
        }
    }

    func testOverlappingCallFromAnotherThreadIsRejectedAndThePassRunsOnce() throws {
        let cleaner = JunkCleaner.shared
        addTeardownBlock { cleaner.reset() }
        let items = try makeItems(count: 3)
        cleaner.items = items
        cleaner.setPhaseForTesting(.results)

        // Every published phase is recorded on the thread that publishes it.
        // An accepted call publishes `.cleaning` exactly once, so the count
        // of `.cleaning` publications is the number of passes started.
        let lock = NSLock()
        var cleaningPublished = 0
        var finished: JunkCleaner.Phase?
        let completed = expectation(description: "the single pass completes")
        let subscription = cleaner.$phase.sink { phase in
            lock.lock()
            defer { lock.unlock() }
            switch phase {
            case .cleaning:
                cleaningPublished += 1
            case .done:
                finished = phase
                completed.fulfill()
            default:
                break
            }
        }
        defer { subscription.cancel() }

        // First call, from the main thread: accepted, starts the one pass.
        cleaner.cleanSelected(escalate: false)
        XCTAssertEqual(cleaner.phase, .cleaning)

        // Second call, from another thread while the first pass is in flight.
        // The main thread blocks until that call returns, so the pass cannot
        // publish its completion first; the phase must still be `.cleaning`.
        let secondReturned = DispatchSemaphore(value: 0)
        var phaseAfterSecond: JunkCleaner.Phase?
        var idsAfterSecond: [UUID] = []
        DispatchQueue.global(qos: .userInitiated).async {
            cleaner.cleanSelected(escalate: false)
            phaseAfterSecond = cleaner.phase
            idsAfterSecond = cleaner.items.map(\.id)
            secondReturned.signal()
        }
        XCTAssertEqual(secondReturned.wait(timeout: .now() + 30), .success)
        XCTAssertEqual(phaseAfterSecond, .cleaning)
        XCTAssertEqual(idsAfterSecond, items.map(\.id))

        // Let the single pass finish on the main run loop.
        wait(for: [completed], timeout: 30)
        lock.lock()
        let published = cleaningPublished
        let result = finished
        lock.unlock()

        XCTAssertEqual(published, 1, "exactly one pass may start")
        // Each fixture is refused by the removal rule, so the single pass
        // reports three failures and nothing moved.
        XCTAssertEqual(result, .done(movedToTrash: 0, freedPermanently: 0, failed: 3))
        XCTAssertTrue(cleaner.items.isEmpty)
        XCTAssertTrue(items.allSatisfy { FileManager.default.fileExists(atPath: $0.url.path) })
    }

    func testSimultaneousCallsFromBackgroundThreadsStartExactlyOnePass() throws {
        let cleaner = JunkCleaner.shared
        addTeardownBlock { cleaner.reset() }
        let items = try makeItems(count: 3)
        cleaner.items = items
        cleaner.setPhaseForTesting(.results)

        // Same recording as the test above: each `.cleaning` publication is
        // one pass started, and every `.done` is kept so a second completion
        // would show up as an extra entry.
        let lock = NSLock()
        var cleaningPublished = 0
        var donePublished: [JunkCleaner.Phase] = []
        let completed = expectation(description: "the single pass completes")
        let subscription = cleaner.$phase.sink { phase in
            lock.lock()
            defer { lock.unlock() }
            switch phase {
            case .cleaning:
                cleaningPublished += 1
            case .done:
                donePublished.append(phase)
                if donePublished.count == 1 { completed.fulfill() }
            default:
                break
            }
        }
        defer { subscription.cancel() }

        // Both calls wait on one start gate, then run from background threads
        // at the same moment. The main thread only waits for them to return,
        // so the pass cannot publish its completion before both calls are done.
        let gate = DispatchSemaphore(value: 0)
        let returned = DispatchGroup()
        for _ in 0..<2 {
            returned.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                gate.wait()
                cleaner.cleanSelected(escalate: false)
                returned.leave()
            }
        }
        gate.signal()
        gate.signal()
        XCTAssertEqual(returned.wait(timeout: .now() + 30), .success)

        // Let the single pass finish on the main run loop.
        wait(for: [completed], timeout: 30)
        lock.lock()
        let started = cleaningPublished
        let finished = donePublished
        lock.unlock()

        XCTAssertEqual(started, 1, "exactly one pass may start")
        // Each fixture is refused by the removal rule, so the single pass
        // reports three failures and nothing moved.
        XCTAssertEqual(finished, [.done(movedToTrash: 0, freedPermanently: 0, failed: 3)])
        XCTAssertTrue(cleaner.items.isEmpty)
        XCTAssertTrue(items.allSatisfy { FileManager.default.fileExists(atPath: $0.url.path) })
    }
}
