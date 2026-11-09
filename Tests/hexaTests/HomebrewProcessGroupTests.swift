// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import Darwin
import XCTest

@testable import Hexa

/// Exercises the process group directly with a shell fake, so the suite never
/// starts brew, touches the network or the user's disk.
final class HomebrewProcessGroupTests: XCTestCase {
    private let environment = ["PATH": "/usr/bin:/bin"]

    private func groupExists(_ pgid: pid_t) -> Bool {
        kill(-pgid, 0) == 0
    }

    /// True once signal 0 reports that no process has the pid, or the group id when negative.
    private func isGone(_ target: pid_t) -> Bool {
        kill(target, 0) == -1 && errno == ESRCH
    }

    func testTerminateGroupEndsChildrenOfTheLeader() throws {
        // Variant of the DoD fake: the leader backgrounds a child and prints its pid,
        // so the test can prove that the group signal reaches a child, not only the leader.
        let command = HomebrewCommand(executable: "/bin/sh",
                                      arguments: ["-c", "sleep 30 & echo $!; sleep 30; wait"])
        let collected = OutputBox()
        let group = try HomebrewProcessGroup.start(command, environment: environment) { chunk in
            collected.append(chunk)
        }
        let pgid = group.processGroupID
        addTeardownBlock {
            if kill(-pgid, 0) == 0 { kill(-pgid, SIGKILL) }
            if let stray = collected.firstPid(), kill(stray, 0) == 0 { kill(stray, SIGKILL) }
        }

        let pidDeadline = Date().addingTimeInterval(5.0)
        var childPid: pid_t?
        while Date() < pidDeadline {
            if let pid = collected.firstPid() {
                childPid = pid
                break
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        guard let child = childPid else {
            XCTFail("the leader should print the pid of its background child")
            return
        }

        XCTAssertEqual(kill(child, 0), 0, "the background child should be alive before termination")
        XCTAssertTrue(groupExists(pgid), "the leader and its background child should share the group")

        // The check window below is 2 s. A grace longer than that means only SIGTERM can satisfy the check,
        // so the later SIGKILL escalation cannot make it pass.
        group.terminateGroup(grace: 5)

        // A child killed by SIGTERM can stay a zombie until its parent or launchd reaps it,
        // and kill(_, 0) still succeeds on a zombie, so the 2 s deadline covers that reap.
        let deadline = Date().addingTimeInterval(2.0)
        while Date() < deadline {
            if isGone(-pgid) && isGone(child) { break }
            Thread.sleep(forTimeInterval: 0.05)
        }
        XCTAssertTrue(isGone(-pgid), "SIGTERM to the group should end the process group within 2 s")
        XCTAssertTrue(isGone(child), "SIGTERM to the group should end the background child within 2 s")
        XCTAssertTrue(group.waitForExit(timeout: 2), "the leader should be reaped after SIGTERM")
    }

    func testOutputAndStatusAreReported() throws {
        let command = HomebrewCommand(executable: "/bin/sh",
                                      arguments: ["-c", "echo hi; exit 3"])
        let group = try HomebrewProcessGroup.start(command, environment: environment) { _ in }

        XCTAssertTrue(group.waitForExit(timeout: 5))
        group.drainOutput(timeout: 2)
        XCTAssertEqual(group.status, 3)
        XCTAssertTrue(group.output.contains("hi"))
    }
}

/// Collects output chunks from the reader queue. The lock guards them against the test thread.
private final class OutputBox {
    private let lock = NSLock()
    private var text = ""

    func append(_ chunk: String) {
        lock.lock()
        defer { lock.unlock() }
        text += chunk
    }

    /// The first newline-terminated line that parses as a pid, if one has been printed.
    func firstPid() -> pid_t? {
        lock.lock()
        let snapshot = text
        lock.unlock()
        // The last component may be a partial line, so only complete lines are considered.
        let completeLines = snapshot.components(separatedBy: "\n").dropLast()
        return completeLines.lazy.compactMap { pid_t($0.trimmingCharacters(in: .whitespaces)) }.first
    }
}
