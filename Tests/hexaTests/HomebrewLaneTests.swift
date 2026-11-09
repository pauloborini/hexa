// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import Foundation
import XCTest

@testable import Hexa

/// Checks that the brew lane runs one block at a time, using plain blocks only:
/// no brew, no network and no timers beyond the short sleep inside the block.
final class HomebrewLaneTests: XCTestCase {
    private final class ConcurrencyProbe: @unchecked Sendable {
        private let lock = NSLock()
        private var active = 0
        private(set) var maxConcurrent = 0
        private(set) var completed = 0

        func enter() {
            lock.lock()
            active += 1
            maxConcurrent = max(maxConcurrent, active)
            lock.unlock()
        }

        func leave() {
            lock.lock()
            active -= 1
            completed += 1
            lock.unlock()
        }
    }

    func testLaneRunsOneBlockAtATime() {
        let probe = ConcurrencyProbe()
        let group = DispatchGroup()
        for _ in 0..<2 {
            DispatchQueue.global().async(group: group) {
                HomebrewManager.lane.sync {
                    probe.enter()
                    Thread.sleep(forTimeInterval: 0.1)
                    probe.leave()
                }
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)
        XCTAssertEqual(probe.completed, 2)
        XCTAssertEqual(probe.maxConcurrent, 1)
    }
}
