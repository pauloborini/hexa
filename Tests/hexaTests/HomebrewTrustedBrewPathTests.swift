// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import Darwin
import XCTest

@testable import Hexa

/// Checks `trustedBrewPath` against a fake brew, so the suite never starts the
/// real brew. Every case builds its files under a unique temporary directory
/// that is removed in tearDown.
final class HomebrewTrustedBrewPathTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hexa-trusted-brew-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.path)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testFakeBrewIsAcceptedByTrustedBrewPath() throws {
        try XCTSkipIf(temporaryChainHasWorldWritableDirectory(),
                      "The temporary directory chain contains a world-writable ancestor, so the positive case cannot hold on this machine.")
        let brew = try makeFakeBrew()
        XCTAssertEqual(HomebrewCommandBuilder.trustedBrewPath(candidates: [brew]), brew)
    }

    // MARK: - Helpers

    private func makeFakeBrew() throws -> String {
        let directory = root.appendingPathComponent("brew bin", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
        let url = directory.appendingPathComponent("brew")
        try Data("#!/bin/sh\necho 'Homebrew 0.0.0-test'\n".utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url.path
    }

    /// True when the temporary directory or one of its ancestors is
    /// world-writable (or cannot be stat'ed), which the positive cases cannot
    /// tolerate.
    private func temporaryChainHasWorldWritableDirectory() -> Bool {
        var path = root.path
        while true {
            var info = stat()
            guard stat(path, &info) == 0 else { return true }
            if info.st_mode & S_IWOTH != 0 { return true }
            if path == "/" { return false }
            path = (path as NSString).deletingLastPathComponent
        }
    }
}
