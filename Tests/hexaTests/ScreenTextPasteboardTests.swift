// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

final class ScreenTextPasteboardTests: XCTestCase {
    func testRecognizedTextDoesNotOverwriteChangedPasteboard() {
        XCTAssertTrue(
            QuickToolsSupport.shouldCopyRecognizedText(
                recognitionGeneration: 3,
                currentGeneration: 3,
                initialPasteboardChangeCount: 10,
                currentPasteboardChangeCount: 10
            )
        )
        XCTAssertFalse(
            QuickToolsSupport.shouldCopyRecognizedText(
                recognitionGeneration: 3,
                currentGeneration: 3,
                initialPasteboardChangeCount: 10,
                currentPasteboardChangeCount: 11
            )
        )
        XCTAssertFalse(
            QuickToolsSupport.shouldCopyRecognizedText(
                recognitionGeneration: 3,
                currentGeneration: 4,
                initialPasteboardChangeCount: 10,
                currentPasteboardChangeCount: 10
            )
        )
    }
}
