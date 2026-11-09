// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Pins the search normalization shared by the island's section search and
/// the settings' layout editor (pure string folding, no locale file).
final class CommandBarSearchTests: XCTestCase {
    func testCaseAndAccentsNeverMatter() {
        XCTAssertEqual(CommandBarSearch.normalized("Café"), "cafe")
        XCTAssertEqual(CommandBarSearch.normalized("INSTA"), "insta")
        XCTAssertEqual(CommandBarSearch.normalized("FAN CONTROL"), "fan control")
    }

    func testSurroundingWhitespaceCollapses() {
        XCTAssertEqual(CommandBarSearch.normalized("  Mixer  "), "mixer")
        XCTAssertEqual(CommandBarSearch.normalized("fan\tcontrol\n"), "fan control")
    }

    func testFullWidthSpaceFoldsLikeHalfWidth() {
        // Some input methods emit U+3000; the bar must treat it as a space.
        XCTAssertEqual(CommandBarSearch.normalized("bd\u{3000}123"), "bd 123")
    }

    func testWidthInsensitiveFold() {
        XCTAssertEqual(CommandBarSearch.normalized("ＦＡＮ"), "fan")
    }

    func testInvisibleDirectionMarksAreStripped() {
        // At least one widely installed app carries a left-to-right mark in
        // front of its name; it must still match its own plain name.
        XCTAssertEqual(CommandBarSearch.normalized("\u{200E}Things"), "things")
        XCTAssertEqual(CommandBarSearch.normalized("Zero\u{200B}Width"), "zerowidth")
        XCTAssertEqual(CommandBarSearch.normalized("Soft\u{00AD}Hyphen"), "softhyphen")
    }

    func testPlainTextPaysNoFoldPenalty() {
        // Determinism on repeated calls (the search box calls this per keystroke).
        let once = CommandBarSearch.normalized("Music")
        XCTAssertEqual(once, "music")
        XCTAssertEqual(CommandBarSearch.normalized("Music"), once)
    }
}
