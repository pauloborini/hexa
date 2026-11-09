// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Pins the hidden home folder rule of the Uninstaller: `~/.<token>` is offered
/// only when the token is one of the app's own names, compared lowercased and
/// otherwise exactly; no other installed app answers to it; no protected root
/// is claimed; and the removal barrier accepts only that exact form. Every test
/// runs on a scratch home under the temporary directory. The real home is never
/// read.
final class HiddenHomeLeftoverTests: XCTestCase {
    /// A unique scratch home under the system temporary directory, removed
    /// when the test ends.
    private func makeFixtureHome() throws -> String {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hexa-hidden-home-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root.standardizedFileURL.path
    }

    private func makeDirectory(_ relativePath: String, in home: String) throws {
        try FileManager.default.createDirectory(atPath: home + "/" + relativePath,
                                                withIntermediateDirectories: true)
    }

    private func candidates(_ home: String,
                            names: Set<String>,
                            others: Set<String> = []) -> [AppUninstaller.ScanCandidate] {
        AppUninstaller.hiddenHomeCandidates(home: home, appNames: names,
                                            ownerBundleID: "com.example.app",
                                            otherAppNames: { others })
    }

    // MARK: DoD 1 and 6: a matching folder is offered, related and unchecked

    func testAppNamedAfterAHiddenFolderYieldsAnUncheckedRelatedCandidate() throws {
        let home = try makeFixtureHome()
        try makeDirectory(".cursor", in: home)

        let found = candidates(home, names: ["cursor"])

        XCTAssertEqual(found.map { $0.url.lastPathComponent }, [".cursor"])
        XCTAssertEqual(found.first?.confidence, .related)
        XCTAssertEqual(found.first?.include, false, "nothing is pre-selected")
        XCTAssertEqual(found.first?.category, .support)
        XCTAssertEqual(found.first?.ownerBundleID, "com.example.app")
    }

    func testMatchIsCaseInsensitiveAndTheRealFolderNameIsKept() throws {
        let home = try makeFixtureHome()
        try makeDirectory(".Gemini", in: home)

        XCTAssertEqual(candidates(home, names: ["gemini"]).map { $0.url.lastPathComponent },
                       [".Gemini"])
    }

    // MARK: DoD 2: protected roots are never offered

    func testSshAndGnupgAreNeverOffered() throws {
        let home = try makeFixtureHome()
        try makeDirectory(".ssh", in: home)
        try makeDirectory(".gnupg", in: home)

        XCTAssertTrue(candidates(home, names: ["ssh", "gnupg"]).isEmpty)
        XCTAssertNil(UninstallerSupport.hiddenHomeToken(folderName: ".ssh"))
        XCTAssertNil(UninstallerSupport.hiddenHomeToken(folderName: ".gnupg"))
    }

    func testToolConfigAndTrashRootsAreNeverClaimed() throws {
        let home = try makeFixtureHome()
        let roots = [".Trash", ".config", ".cache", ".local", ".docker", ".npm", ".gradle", ".pub-cache"]
        for root in roots {
            try makeDirectory(root, in: home)
        }

        let names = Set(roots.map { String($0.dropFirst()).lowercased() })
        XCTAssertTrue(candidates(home, names: names).isEmpty)
        for root in roots {
            XCTAssertNil(UninstallerSupport.hiddenHomeToken(folderName: root), root)
        }
    }

    // MARK: DoD 3: the token is the exact name, with no other normalization

    func testAntigravityIDEDoesNotClaimGeminiOrADashedFolder() throws {
        let home = try makeFixtureHome()
        try makeDirectory(".gemini", in: home)
        try makeDirectory(".antigravity-ide", in: home)

        // Spaces are not turned into dashes: "Antigravity IDE" claims neither
        // ".antigravity-ide" nor ".gemini".
        XCTAssertTrue(candidates(home, names: ["antigravity ide"]).isEmpty)
        // The exact token still matches when it is the same text.
        XCTAssertEqual(candidates(home, names: ["antigravity-ide"]).map { $0.url.lastPathComponent },
                       [".antigravity-ide"])
    }

    func testTokenRulesOnFolderNames() {
        XCTAssertEqual(UninstallerSupport.hiddenHomeToken(folderName: ".Cursor"), "cursor")
        XCTAssertNil(UninstallerSupport.hiddenHomeToken(folderName: "Cursor"))
        XCTAssertNil(UninstallerSupport.hiddenHomeToken(folderName: "."))
        XCTAssertNil(UninstallerSupport.hiddenHomeToken(folderName: ".."))
    }

    // MARK: DoD 4: a token another installed app claims offers nothing

    func testTokenSharedWithAnotherInstalledAppOffersNothing() throws {
        let home = try makeFixtureHome()
        try makeDirectory(".cursor", in: home)

        XCTAssertTrue(candidates(home, names: ["cursor"], others: ["cursor", "other app"]).isEmpty)
        XCTAssertEqual(candidates(home, names: ["cursor"], others: ["other app"]).count, 1)
    }

    func testSymbolicLinkIsNotOffered() throws {
        let home = try makeFixtureHome()
        try makeDirectory("elsewhere", in: home)
        try FileManager.default.createSymbolicLink(atPath: home + "/.cursor",
                                                   withDestinationPath: home + "/elsewhere")

        XCTAssertTrue(candidates(home, names: ["cursor"]).isEmpty)
    }

    // MARK: DoD 5: the root barrier accepts only the direct, exact form

    func testRootBarrierRefusesPathsDeeperThanADirectHomeChild() throws {
        let home = try makeFixtureHome()
        try makeDirectory(".cursor/extensions/one", in: home)
        try makeDirectory(".ssh", in: home)
        try makeDirectory("Library/Caches/app", in: home)
        let homeURL = URL(fileURLWithPath: home, isDirectory: true)

        XCTAssertTrue(AppUninstaller.hiddenHomeRemovalIsSafe(
            homeURL.appendingPathComponent(".cursor"), home: home))
        XCTAssertFalse(AppUninstaller.hiddenHomeRemovalIsSafe(
            homeURL.appendingPathComponent(".cursor/extensions"), home: home))
        XCTAssertFalse(AppUninstaller.hiddenHomeRemovalIsSafe(
            homeURL.appendingPathComponent(".cursor/extensions/one"), home: home))
        XCTAssertFalse(AppUninstaller.hiddenHomeRemovalIsSafe(homeURL, home: home),
                       "the home folder is never a removal root")
        XCTAssertFalse(AppUninstaller.hiddenHomeRemovalIsSafe(
            homeURL.appendingPathComponent(".ssh"), home: home))
        XCTAssertFalse(AppUninstaller.hiddenHomeRemovalIsSafe(
            homeURL.appendingPathComponent("Library"), home: home))
    }
}
