// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Pins the parsing of real Homebrew JSON output against the shapes the
/// commands emit. Fixture provenance: the JSON blocks below follow the
/// documented shape of `brew outdated --json=v2` and `brew info --json=v2`
/// for casks (Homebrew 4.x: objects under the "formulae" and "casks" keys,
/// with the fields the parser reads), kept inline so the suite never needs
/// `brew` installed, a network or the user's disk.
final class HomebrewParserTests: XCTestCase {
    // Shape of `brew outdated --json=v2` (fields consumed by
    // HomebrewParser.parseOutdatedItem).
    func testParsesOutdatedFormulaeAndCasks() throws {
        let outdatedJSON = """
        {
          "formulae": [
            { "name": "wget", "current_version": "1.25.0",
              "installed_versions": ["1.24.5"], "pinned": false }
          ],
          "casks": [
            { "token": "iterm2", "current_version": "3.5.13",
              "installed_versions": ["3.5.11"], "pinned": true }
          ]
        }
        """
        let updates = try HomebrewParser.parseOutdatedJSON(Data(outdatedJSON.utf8))
        XCTAssertEqual(updates.count, 2)
        let wget = try XCTUnwrap(updates["formula:wget"])
        XCTAssertEqual(wget.currentVersion, "1.25.0")
        XCTAssertEqual(wget.installedVersions, ["1.24.5"])
        XCTAssertFalse(wget.isPinned)
        let iterm2 = try XCTUnwrap(updates["cask:iterm2"])
        XCTAssertTrue(iterm2.isPinned)
        XCTAssertEqual(iterm2.kind, .cask)
    }

    func testOutdatedSkipsEntriesWithoutCurrentVersion() throws {
        let json = """
        { "formulae": [
            { "name": "wget", "installed_versions": ["1.24.5"] },
            { "name": "git", "current_version": "2.51.0", "installed_versions": ["2.50.1"] }
          ] }
        """
        let updates = try HomebrewParser.parseOutdatedJSON(Data(json.utf8))
        XCTAssertEqual(updates.map(\.key), ["formula:git"])
    }

    func testOutdatedOutputWithPreamble() throws {
        let noisy = "==>\nsome progress noise\n" + """
        { "formulae": [ { "name": "git", "current_version": "2.51.0",
          "installed_versions": ["2.50.1"] } ] }
        """
        let updates = try HomebrewParser.parseOutdatedCommandOutput(noisy)
        XCTAssertEqual(updates.count, 1)
        XCTAssertEqual(updates["formula:git"]?.currentVersion, "2.51.0")
    }

    func testInstalledCaskRecordsTraceAppBundles() throws {
        // Shape of `brew info --json=v2 --cask iterm2`: artifacts list the
        // app bundles the cask drops into /Applications.
        let json = """
        { "casks": [
            { "token": "iterm2", "name": ["iTerm2"], "installed": "3.5.11",
              "artifacts": [
                { "app": [ { "source": "iTerm2.app",
                              "target": "/Applications/iTerm2.app" } ] }
              ] }
          ] }
        """
        let records = HomebrewParser.parseInstalledCaskRecords(json)
        XCTAssertEqual(records.count, 1)
        let record = try XCTUnwrap(records.first)
        XCTAssertEqual(record.token, "iterm2")
        XCTAssertEqual(record.displayName, "iTerm2")
        XCTAssertEqual(record.installedVersion, "3.5.11")
        XCTAssertEqual(record.appFileNames, ["iTerm2.app"])
        XCTAssertEqual(record.appPaths, ["/Applications/iTerm2.app"])
    }

    func testPackageMatchFollowsTheInstallSymlink() throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("hexa-brew-link-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let bundle = root.appendingPathComponent("Real.app", isDirectory: true)
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        let link = root.appendingPathComponent("Link.app")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: bundle)
        let record = HomebrewCaskRecord(token: "real",
                                        displayName: "Real",
                                        installedVersion: "1",
                                        appFileNames: ["Link.app"],
                                        appPaths: [link.path])

        let match = HomebrewOwnershipSupport.packageManagingApplication(
            atPath: bundle.path, installed: [record])
        XCTAssertEqual(match?.name, "real")

        let other = HomebrewCaskRecord(token: "other",
                                       displayName: "Other",
                                       installedVersion: "1",
                                       appFileNames: ["Other.app"],
                                       appPaths: [root.appendingPathComponent("Other.app").path])
        XCTAssertNil(HomebrewOwnershipSupport.packageManagingApplication(
            atPath: bundle.path, installed: [other]))
    }
}
