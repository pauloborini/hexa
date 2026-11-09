// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import Darwin
import Foundation
import XCTest

@testable import Hexa

/// Covers the identity tuple (pid, start time, executable path) that gates
/// every direct signal. Each test owns one `/bin/sleep` child and signals
/// nothing else. Only static helpers are used; no shared service, defaults,
/// launchctl, Trash, or admin shell.
final class KillProcessIdentityTests: XCTestCase {

    private func launchSleep() throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["60"]
        try process.run()
        return process
    }

    /// Ends the test's own child if it is still running, then reaps it.
    private func reap(_ process: Process) {
        if process.isRunning {
            process.terminate()
        }
        process.waitUntilExit()
    }

    /// Start time as the service reads it, so the tuple uses the real value.
    private func realStartTime(of process: Process) throws -> UInt64 {
        try XCTUnwrap(KillProcessService.startTime(for: process.processIdentifier))
    }

    func testStalePathReturnsStaleAndLeavesChildAlive() throws {
        let child = try launchSleep()
        defer { reap(child) }
        let pid = child.processIdentifier
        let target = KillProcessService.KillTarget(pid: pid,
                                                   startedAt: try realStartTime(of: child),
                                                   expectedPath: "/usr/bin/false")

        XCTAssertEqual(KillProcessService.attemptDirectKill(target: target, force: false), .stale)
        XCTAssertEqual(Darwin.kill(pid, 0), 0, "O filho deve seguir vivo: nenhum sinal foi enviado")
        XCTAssertTrue(child.isRunning)
    }

    func testStartTimeOffByOneMicrosecondReturnsStaleAndLeavesChildAlive() throws {
        let child = try launchSleep()
        defer { reap(child) }
        let pid = child.processIdentifier
        let target = KillProcessService.KillTarget(pid: pid,
                                                   startedAt: try realStartTime(of: child) + 1,
                                                   expectedPath: "/bin/sleep")

        XCTAssertEqual(KillProcessService.attemptDirectKill(target: target, force: false), .stale)
        XCTAssertEqual(Darwin.kill(pid, 0), 0, "O filho deve seguir vivo: nenhum sinal foi enviado")
        XCTAssertTrue(child.isRunning)
    }

    func testMatchingIdentityKillsChild() throws {
        let child = try launchSleep()
        defer { reap(child) }
        let target = KillProcessService.KillTarget(pid: child.processIdentifier,
                                                   startedAt: try realStartTime(of: child),
                                                   expectedPath: "/bin/sleep")

        XCTAssertEqual(KillProcessService.attemptDirectKill(target: target, force: false), .killed)
        child.waitUntilExit()
        XCTAssertEqual(child.terminationReason, .uncaughtSignal)
        XCTAssertEqual(child.terminationStatus, SIGTERM)
    }
}
