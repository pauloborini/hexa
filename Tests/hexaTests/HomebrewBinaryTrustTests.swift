// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import Darwin
import XCTest

@testable import Hexa

/// Pins the ownership and permission checks applied to a brew binary before
/// the app runs it. Each case builds its own files under a unique temporary
/// directory that is removed in tearDown.
final class HomebrewBinaryTrustTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hexa-brew-trust-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try setPermissions(0o755, at: root)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testOwnedExecutableInTrustedDirectoryIsTrusted() throws {
        try XCTSkipIf(temporaryChainHasWorldWritableDirectory(),
                      "The temporary directory chain contains a world-writable ancestor, so the positive case cannot hold on this machine.")
        let directory = try makeDirectory(named: "ok", mode: 0o755)
        let binary = try makeFile(named: "brew", in: directory, mode: 0o755)
        XCTAssertEqual(HomebrewCommandBuilder.trustedBrewPath(candidates: [binary]), binary)
    }

    func testWorldWritableBinaryIsRejected() throws {
        let directory = try makeDirectory(named: "file-mode", mode: 0o755)
        let binary = try makeFile(named: "brew", in: directory, mode: 0o777)
        XCTAssertNil(HomebrewCommandBuilder.trustedBrewPath(candidates: [binary]))
    }

    func testBinaryInWorldWritableDirectoryIsRejected() throws {
        let directory = try makeDirectory(named: "dir-mode", mode: 0o777)
        let binary = try makeFile(named: "brew", in: directory, mode: 0o755)
        XCTAssertNil(HomebrewCommandBuilder.trustedBrewPath(candidates: [binary]))
    }

    func testMissingCandidateIsSkipped() throws {
        try XCTSkipIf(temporaryChainHasWorldWritableDirectory(),
                      "The temporary directory chain contains a world-writable ancestor, so the positive case cannot hold on this machine.")
        let directory = try makeDirectory(named: "missing", mode: 0o755)
        let missing = directory.appendingPathComponent("absent-brew").path
        let binary = try makeFile(named: "brew", in: directory, mode: 0o755)
        XCTAssertEqual(HomebrewCommandBuilder.trustedBrewPath(candidates: [missing, binary]), binary)
    }

    func testSymlinkToWorldWritableTargetIsRejected() throws {
        let directory = try makeDirectory(named: "symlink", mode: 0o755)
        let target = try makeFile(named: "target", in: directory, mode: 0o777)
        let link = directory.appendingPathComponent("brew").path
        try FileManager.default.createSymbolicLink(atPath: link, withDestinationPath: target)
        XCTAssertNil(HomebrewCommandBuilder.trustedBrewPath(candidates: [link]))
    }

    // MARK: - Helpers

    private func makeDirectory(named name: String, mode: Int) throws -> URL {
        let url = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try setPermissions(mode, at: url)
        return url
    }

    private func makeFile(named name: String, in directory: URL, mode: Int) throws -> String {
        let url = directory.appendingPathComponent(name)
        try Data("#!/bin/sh\n".utf8).write(to: url)
        try setPermissions(mode, at: url)
        return url.path
    }

    private func setPermissions(_ mode: Int, at url: URL) throws {
        try FileManager.default.setAttributes([.posixPermissions: mode], ofItemAtPath: url.path)
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
