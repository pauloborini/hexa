// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Pins the scheduler's isolation from the interface singleton: automatic
/// passes run on `CleanerScheduler.shared.engine`, a cleaner separate from
/// `JunkCleaner.shared`, which the Cleaner view observes. The test only checks
/// identity and the initial state. It never runs a scan or a clean, so the
/// real home, Finder, launchctl and the Trash are never reached.
final class CleanerSchedulerIsolationTests: XCTestCase {
    func testSchedulerEngineIsNotTheInterfaceSingleton() {
        XCTAssertFalse(CleanerScheduler.shared.engine === JunkCleaner.shared)
    }

    func testSchedulerEngineStartsIdle() {
        XCTAssertEqual(CleanerScheduler.shared.engine.phase, .idle)
    }
}
