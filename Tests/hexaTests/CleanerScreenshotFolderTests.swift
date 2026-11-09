// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Pins which folders the screenshot search accepts. The check is pure string
/// logic on a fake home, so the real home and file system are never touched.
final class CleanerScreenshotFolderTests: XCTestCase {
    private let home = "/Users/tester"

    private var iCloudDesktop: String {
        home + "/Library/Mobile Documents/com~apple~CloudDocs/Desktop"
    }

    private var iCloudDocuments: String {
        home + "/Library/Mobile Documents/com~apple~CloudDocs/Documents"
    }

    func testICloudDesktopAndDocumentsAreAccepted() {
        XCTAssertTrue(CleanerSupport.isSafeScreenshotFolder(iCloudDesktop, home: home))
        XCTAssertTrue(CleanerSupport.isSafeScreenshotFolder(iCloudDocuments, home: home))
    }

    func testBareVolumeRootIsRejectedButVolumeSubfolderIsAccepted() {
        XCTAssertFalse(CleanerSupport.isSafeScreenshotFolder("/Volumes/ExternalDrive", home: home))
        XCTAssertTrue(CleanerSupport.isSafeScreenshotFolder("/Volumes/ExternalDrive/Shots", home: home))
        XCTAssertFalse(CleanerSupport.isSafeScreenshotFolder("/Volumes", home: home))
    }

    func testLibraryTreesAndCloudDocsRootAndSubfoldersAreRejected() {
        XCTAssertFalse(CleanerSupport.isSafeScreenshotFolder(home + "/Library/Application Support/X", home: home))
        XCTAssertFalse(CleanerSupport.isSafeScreenshotFolder(home + "/Library/Mobile Documents/com~apple~CloudDocs", home: home))
        XCTAssertFalse(CleanerSupport.isSafeScreenshotFolder(iCloudDesktop + "/Sub", home: home))
    }

    func testSystemFoldersAndHomeRootAreRejected() {
        XCTAssertFalse(CleanerSupport.isSafeScreenshotFolder("/Library/X", home: home))
        XCTAssertFalse(CleanerSupport.isSafeScreenshotFolder(home, home: home))
    }
}
