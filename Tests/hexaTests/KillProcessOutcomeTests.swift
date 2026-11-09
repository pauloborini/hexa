// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Covers the pure decisions behind the kill fallback and the administrator
/// cancel classification. Nothing here opens a dialog, sends a signal, or
/// touches launchctl, Trash, or the real home directory.
final class KillProcessOutcomeTests: XCTestCase {

    // MARK: - AppKit termination request not sent

    func testAppTerminateNotSentFallsBackToSignal() {
        XCTAssertTrue(KillProcessSupport.fallsBackToSignal(afterAppTerminateAccepted: false))
    }

    func testAcceptedAppTerminateDoesNotFallBackToSignal() {
        XCTAssertFalse(KillProcessSupport.fallsBackToSignal(afterAppTerminateAccepted: true))
    }

    // MARK: - Administrator request classification

    func testZeroStatusIsGranted() {
        XCTAssertEqual(AdminShell.outcome(status: 0, output: ""), .granted)
    }

    func testUserCancelIsCancelled() {
        XCTAssertEqual(
            AdminShell.outcome(status: 1, output: "execution error: User canceled. (-128)"),
            .cancelled
        )
    }

    func testOtherScriptErrorIsFailed() {
        XCTAssertEqual(AdminShell.outcome(status: 1, output: "execution error: falha (1)"), .failed)
    }

    func testNonZeroStatusWithoutOutputIsFailed() {
        XCTAssertEqual(AdminShell.outcome(status: 1, output: ""), .failed)
    }

    func testSimilarErrorCodeIsNotCancel() {
        XCTAssertEqual(AdminShell.outcome(status: 1, output: "execution error: x. (-1280)"), .failed)
    }

    // MARK: - Administrator prompt name sanitization

    func testControlCharactersAreRemoved() {
        XCTAssertEqual(KillProcessSupport.sanitizedPromptName("\nfoo\r\t"), "foo")
    }

    func testNameIsCappedAt64Characters() {
        let result = KillProcessSupport.sanitizedPromptName(String(repeating: "a", count: 100))
        XCTAssertEqual(result.count, 64)
    }

    func testBidiOverrideIsRemoved() {
        XCTAssertEqual(KillProcessSupport.sanitizedPromptName("a\u{202E}b"), "ab")
    }

    func testEmptyNameFallsBackToQuestionMark() {
        XCTAssertEqual(KillProcessSupport.sanitizedPromptName(""), "?")
        XCTAssertEqual(KillProcessSupport.sanitizedPromptName("  \n "), "?")
    }

    func testWhitespaceRunsCollapseToSingleSpace() {
        XCTAssertEqual(KillProcessSupport.sanitizedPromptName("a   b"), "a b")
    }

    func testAccentedNameIsPreserved() {
        XCTAssertEqual(KillProcessSupport.sanitizedPromptName("Café"), "Café")
    }
}
