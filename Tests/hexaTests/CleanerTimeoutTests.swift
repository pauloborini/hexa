// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Pins the opt-in AppleScript timeout. The scripts use only `error`, `delay`
/// and a constant return: no application is targeted, so Finder and the Trash
/// are never touched.
final class CleanerTimeoutTests: XCTestCase {
    func testTimedSourceBoundsEveryAppleEventInWholeSeconds() {
        XCTAssertEqual(AppleScriptRunner.timedSource("return 1", timeout: 120),
                       "with timeout of 120 seconds\nreturn 1\nend timeout")
        XCTAssertEqual(AppleScriptRunner.timedSource("return 1", timeout: 0.1),
                       "with timeout of 1 seconds\nreturn 1\nend timeout")
        XCTAssertEqual(AppleScriptRunner.timedSource("return 1", timeout: 2.5),
                       "with timeout of 3 seconds\nreturn 1\nend timeout")
    }

    func testTimedRunReportsAnExpiredAppleEventAsTimeout() {
        let result = AppleScriptRunner.runDetailed("error number -1712", timeout: 5)

        XCTAssertFalse(result.ok)
        XCTAssertEqual(result.errorNumber, AppleScriptRunner.timeoutErrorNumber)
        XCTAssertEqual(result.message, AppleScriptRunner.timeoutMessage)
        XCTAssertEqual(result.message, "timeout")
        XCTAssertEqual(result.output, "")
    }

    func testTimedRunWaitsForTheScriptInsteadOfAbandoningIt() {
        // `with timeout` bounds Apple Events only, so a local delay runs to the
        // end and nothing is left executing after the call returns.
        let result = AppleScriptRunner.run("delay 0.2\nreturn \"done\"", timeout: 0.1)

        XCTAssertTrue(result.ok)
        XCTAssertEqual(result.output, "done")
    }

    func testTimedRunReturnsTheResultWhenTheScriptFinishesInTime() {
        let result = AppleScriptRunner.run("return \"ok\"", timeout: 5)

        XCTAssertTrue(result.ok)
        XCTAssertEqual(result.output, "ok")
    }

    func testUntimedRunStillReturnsTheScriptResult() {
        let result = AppleScriptRunner.run("return \"ok\"")

        XCTAssertTrue(result.ok)
        XCTAssertEqual(result.output, "ok")
    }
}
