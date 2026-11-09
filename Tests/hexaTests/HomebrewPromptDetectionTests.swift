// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import Darwin
import XCTest

@testable import Hexa

/// Covers the early abort on a pending password prompt with shell fakes, so the
/// suite never starts brew or answers a real prompt.
final class HomebrewPromptDetectionTests: XCTestCase {
    private let environment = ["PATH": "/usr/bin:/bin"]

    private func start(_ script: String,
                       abortsWhenPartialLine: @escaping (String) -> Bool = { _ in false }) throws -> HomebrewProcessGroup {
        let command = HomebrewCommand(executable: "/bin/sh", arguments: ["-c", script])
        let group = try HomebrewProcessGroup.start(command, environment: environment,
                                                   abortsWhenPartialLine: abortsWhenPartialLine) { _ in }
        let pgid = group.processGroupID
        addTeardownBlock {
            if kill(-pgid, 0) == 0 { kill(-pgid, SIGKILL) }
        }
        return group
    }

    func testPendingPasswordPromptAbortsWithinOneSecond() throws {
        let group = try start(#"printf "Password:"; sleep 30"#,
                              abortsWhenPartialLine: HomebrewCommandBuilder.isPendingTerminalPrompt)

        XCTAssertTrue(group.waitForExit(timeout: 1), "a pending prompt should end the group within 1 s")
        XCTAssertNotEqual(group.status, 0, "the group should end by signal, not by a clean exit")
        group.drainOutput(timeout: 2)
        XCTAssertTrue(HomebrewCommandBuilder.needsTerminalFallback(output: group.output))
    }

    func testCompletedLineDoesNotAbort() throws {
        let group = try start("echo \"sudo: completed line\"; sleep 1; echo finished",
                              abortsWhenPartialLine: HomebrewCommandBuilder.isPendingTerminalPrompt)

        XCTAssertTrue(group.waitForExit(timeout: 5))
        group.drainOutput(timeout: 2)
        XCTAssertEqual(group.status, 0)
        XCTAssertTrue(group.output.contains("finished"))
    }

    func testStdinIsDevNull() throws {
        // A pipe that never closes would block `cat` and hang this test until the timeout.
        let group = try start("cat; echo done")

        XCTAssertTrue(group.waitForExit(timeout: 5))
        group.drainOutput(timeout: 2)
        XCTAssertEqual(group.status, 0)
        XCTAssertTrue(group.output.contains("done"))
    }

    func testPartialLinePredicate() {
        XCTAssertTrue(HomebrewCommandBuilder.isPendingTerminalPrompt(partialLine: "Password:"))
        XCTAssertTrue(HomebrewCommandBuilder.isPendingTerminalPrompt(partialLine: "sudo:"))
        XCTAssertFalse(HomebrewCommandBuilder.isPendingTerminalPrompt(partialLine: ""))
        XCTAssertFalse(HomebrewCommandBuilder.isPendingTerminalPrompt(partialLine: "Downloading 50%"))
    }
}
