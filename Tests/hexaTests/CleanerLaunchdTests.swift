// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import Foundation
import XCTest

@testable import Hexa

/// Pins the launchd retirement that runs before a login item plist is trashed.
/// Every launchctl call goes through `JunkCleaner.launchctlRunner`, which each
/// test replaces with a recorder and restores afterwards. Plists live in
/// scratch folders under the temporary directory. The real home, the real
/// /Library/LaunchAgents and the real /Library/LaunchDaemons are only ever
/// named as strings: they are never read, written or passed to launchctl.
final class CleanerLaunchdTests: XCTestCase {
    private let fm = FileManager.default
    private let uid: uid_t = 501
    private let fakeHome = "/Users/hexa-test-home"
    private var calls: [[String]] = []

    /// Swaps the runner for a recorder and restores the original when the
    /// test ends, so the real /bin/launchctl is never reached.
    private func installRecorder() {
        let original = JunkCleaner.launchctlRunner
        addTeardownBlock {
            JunkCleaner.launchctlRunner = original
        }
        JunkCleaner.launchctlRunner = { [weak self] arguments in
            self?.calls.append(arguments)
        }
    }

    /// Creates a unique scratch root that is removed when the test ends.
    private func makeScratchRoot() throws -> URL {
        let root = fm.temporaryDirectory
            .appendingPathComponent("hexa-cleanerlaunchd-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { [fm] in
            try? fm.removeItem(at: root)
        }
        return root
    }

    /// Writes a plist with the given `Label` (or without one when nil).
    private func writePlist(_ url: URL, label: String?) throws {
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var dictionary: [String: Any] = [:]
        if let label {
            dictionary["Label"] = label
        }
        let data = try PropertyListSerialization.data(
            fromPropertyList: dictionary, format: .xml, options: 0)
        try data.write(to: url)
    }

    // DoD (a): a valid label under a stand-in agent folder reaches the GUI domain.
    func testLaunchAgentUnderStandInRootBootsOutInGUIDomain() throws {
        let root = try makeScratchRoot()
        let agents = root.appendingPathComponent("LaunchAgents", isDirectory: true)
        let plist = agents.appendingPathComponent("com.example.helper.plist")
        try writePlist(plist, label: "com.example.helper")
        installRecorder()

        JunkCleaner.bootoutUserAgent(plist, agentRoots: [agents.path + "/"], uid: uid)

        XCTAssertEqual(calls, [["bootout", "gui/501/com.example.helper"]])
    }

    // DoD (a): the pure function, with the real /Library/LaunchAgents prefix and a fake path.
    func testPureFunctionAcceptsDirectChildOfSystemLaunchAgents() {
        let roots = JunkCleaner.launchAgentRoots(home: fakeHome)

        XCTAssertEqual(
            JunkCleaner.bootoutArguments(
                plistPath: "/Library/LaunchAgents/com.example.helper.plist",
                label: "com.example.helper", uid: uid, agentRoots: roots),
            ["bootout", "gui/501/com.example.helper"])
        XCTAssertEqual(
            JunkCleaner.bootoutArguments(
                plistPath: fakeHome + "/Library/LaunchAgents/com.example.helper.plist",
                label: "com.example.helper", uid: uid, agentRoots: roots),
            ["bootout", "gui/501/com.example.helper"])
    }

    // DoD (a) boundary: nested plists and sibling prefixes are not direct children.
    func testPureFunctionRejectsNestedAndSiblingPaths() {
        let roots = JunkCleaner.launchAgentRoots(home: fakeHome)

        XCTAssertNil(JunkCleaner.bootoutArguments(
            plistPath: "/Library/LaunchAgents/nested/com.example.helper.plist",
            label: "com.example.helper", uid: uid, agentRoots: roots))
        XCTAssertNil(JunkCleaner.bootoutArguments(
            plistPath: "/Library/LaunchAgentsOther/com.example.helper.plist",
            label: "com.example.helper", uid: uid, agentRoots: roots))
    }

    // DoD (b): LaunchDaemons never reach launchctl, with the default roots.
    func testPureFunctionRejectsLaunchDaemonsWithDefaultRoots() {
        XCTAssertNil(JunkCleaner.bootoutArguments(
            plistPath: "/Library/LaunchDaemons/com.example.daemon.plist",
            label: "com.example.daemon", uid: uid,
            agentRoots: JunkCleaner.launchAgentRoots(home: fakeHome)))
    }

    // DoD (b): a stand-in LaunchDaemons folder that is not in the roots makes no call.
    func testLaunchDaemonsStandInProducesNoLaunchctlCall() throws {
        let root = try makeScratchRoot()
        let daemons = root.appendingPathComponent("LaunchDaemons", isDirectory: true)
        let plist = daemons.appendingPathComponent("com.example.daemon.plist")
        try writePlist(plist, label: "com.example.daemon")
        installRecorder()

        JunkCleaner.bootoutUserAgent(plist, agentRoots: [root.appendingPathComponent("LaunchAgents").path + "/"], uid: uid)
        JunkCleaner.bootoutUserAgent(plist, home: root.path, uid: uid)

        XCTAssertEqual(calls, [])
    }

    // DoD (c): labels with "/", labels with "..", and empty labels make no call.
    func testUnsafeLabelsProduceNoLaunchctlCall() throws {
        let root = try makeScratchRoot()
        let agents = root.appendingPathComponent("LaunchAgents", isDirectory: true)
        let unsafeLabels = ["com.example/evil", "com.example..evil", ""]
        installRecorder()

        for (index, label) in unsafeLabels.enumerated() {
            let plist = agents.appendingPathComponent("unsafe-\(index).plist")
            try writePlist(plist, label: label)
            JunkCleaner.bootoutUserAgent(plist, agentRoots: [agents.path + "/"], uid: uid)
        }

        XCTAssertEqual(calls, [])
    }

    // DoD (c): the pure function rejects the same labels, and a missing label.
    func testPureFunctionRejectsUnsafeAndMissingLabels() {
        let roots = JunkCleaner.launchAgentRoots(home: fakeHome)
        let path = "/Library/LaunchAgents/com.example.helper.plist"

        XCTAssertNil(JunkCleaner.bootoutArguments(plistPath: path, label: "com.example/evil", uid: uid, agentRoots: roots))
        XCTAssertNil(JunkCleaner.bootoutArguments(plistPath: path, label: "com.example..evil", uid: uid, agentRoots: roots))
        XCTAssertNil(JunkCleaner.bootoutArguments(plistPath: path, label: "", uid: uid, agentRoots: roots))
        XCTAssertNil(JunkCleaner.bootoutArguments(plistPath: path, label: nil, uid: uid, agentRoots: roots))
    }

    // DoD (d): a plist under the stand-in home agent folder, passed as `home`.
    func testHomeLaunchAgentProducesSameBootoutAsBefore() throws {
        let root = try makeScratchRoot()
        let plist = root.appendingPathComponent("Library/LaunchAgents/com.example.helper.plist")
        try writePlist(plist, label: "com.example.helper")
        installRecorder()

        JunkCleaner.bootoutUserAgent(plist, home: root.path, uid: uid)

        XCTAssertEqual(calls, [["bootout", "gui/501/com.example.helper"]])
    }

    // ISSUE-200: a relative ProgramArguments[0] without Program resolves in
    // launchd's standard path; one that does not resolve is never an orphan.
    func testRelativeProgramArgumentResolvesInStandardPathOrStaysUndecidable() {
        XCTAssertEqual(CleanerSupport.executablePaths(inLaunchPlist: ["ProgramArguments": ["sh", "/x/backup.sh"]]),
                       ["/bin/sh"])
        let unresolved: [[String: Any]] = [
            ["ProgramArguments": ["hexa-no-such-tool-\(UUID().uuidString)"]],
            ["ProgramArguments": ["bin/backup"]]
        ]
        for plist in unresolved {
            let executables = CleanerSupport.executablePaths(inLaunchPlist: plist)
            XCTAssertEqual(executables, [])
            XCTAssertFalse(CleanerSupport.launchPlistIsRemovableOrphan(
                label: "local.backup", executables: executables, executableExists: { _ in false }))
        }
    }
}
