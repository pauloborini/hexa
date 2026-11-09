// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Pins the shared-data ownership rule of the Uninstaller for related leftovers.
/// A related leftover owned by one app is not removable when another installed
/// app shares its vendor prefix; exact matches keep the bundle identifier rule.
/// The apps are described by paths and bundle identifiers only. No file is
/// read or written.
final class UninstallTests: XCTestCase {
    private let photoshop = URL(fileURLWithPath: "/Applications/Photoshop.app")
    private let illustrator = URL(fileURLWithPath: "/Applications/Illustrator.app")

    /// The leftover keeps ownership only when both checks used by removal pass:
    /// the owner is exclusive and no vendor sibling shares its data.
    private func keepsOwnership(bundleID: String,
                                confidence: UninstallerSupport.LeftoverMatch,
                                selectedURL: URL,
                                knownApplications: [(url: URL, bundleID: String)]) -> Bool {
        let exclusive = UninstallerSupport.exclusiveBundleIDs([bundleID],
                                                              selectedURL: selectedURL,
                                                              knownApplications: knownApplications)
        let shared = UninstallerSupport.vendorDataIsShared(bundleID: bundleID,
                                                           confidence: confidence,
                                                           selectedURL: selectedURL,
                                                           knownApplications: knownApplications)
        return exclusive.contains(bundleID) && !shared
    }

    // MARK: DoD 1: a related leftover shared with a vendor sibling is not kept

    func testRelatedLeftoverWithVendorSiblingIsNotKept() {
        let known = [(url: photoshop, bundleID: "com.adobe.Photoshop"),
                     (url: illustrator, bundleID: "com.adobe.Illustrator")]

        XCTAssertTrue(UninstallerSupport.exclusiveBundleIDs(["com.adobe.Photoshop"],
                                                            selectedURL: photoshop,
                                                            knownApplications: known)
                        .contains("com.adobe.Photoshop"),
                      "no other app uses the bundle identifier itself")
        XCTAssertTrue(UninstallerSupport.vendorDataIsShared(bundleID: "com.adobe.Photoshop",
                                                            confidence: .related,
                                                            selectedURL: photoshop,
                                                            knownApplications: known))
        XCTAssertFalse(keepsOwnership(bundleID: "com.adobe.Photoshop", confidence: .related,
                                      selectedURL: photoshop, knownApplications: known))
    }

    func testVendorPrefixIsCaseInsensitiveAndExactComponents() {
        let known = [(url: photoshop, bundleID: "com.adobe.Photoshop"),
                     (url: URL(fileURLWithPath: "/Applications/Stock.app"),
                      bundleID: "com.adobestock.Stock")]

        XCTAssertFalse(UninstallerSupport.vendorDataIsShared(bundleID: "com.adobe.Photoshop",
                                                             confidence: .related,
                                                             selectedURL: photoshop,
                                                             knownApplications: known),
                       "com.adobestock is a different vendor, not a sibling")
        XCTAssertTrue(UninstallerSupport.vendorDataIsShared(
            bundleID: "COM.ADOBE.photoshop", confidence: .related,
            selectedURL: photoshop,
            knownApplications: [(url: illustrator, bundleID: "com.adobe.Illustrator")]))
    }

    // MARK: DoD 2: an exact leftover keeps the bundle identifier rule

    func testExactLeftoverWithVendorSiblingStaysExclusive() {
        let known = [(url: photoshop, bundleID: "com.adobe.Photoshop"),
                     (url: illustrator, bundleID: "com.adobe.Illustrator")]

        XCTAssertFalse(UninstallerSupport.vendorDataIsShared(bundleID: "com.adobe.Photoshop",
                                                             confidence: .exact,
                                                             selectedURL: photoshop,
                                                             knownApplications: known))
        XCTAssertTrue(keepsOwnership(bundleID: "com.adobe.Photoshop", confidence: .exact,
                                     selectedURL: photoshop, knownApplications: known))
    }

    // MARK: DoD 3: a second copy with the same bundle identifier is still not exclusive

    func testSecondCopyWithSameBundleIDKeepsTodaysBehavior() {
        let copy = URL(fileURLWithPath: "/Volumes/Backup/Photoshop.app")
        let known = [(url: photoshop, bundleID: "com.adobe.Photoshop"),
                     (url: copy, bundleID: "com.adobe.Photoshop")]

        XCTAssertFalse(UninstallerSupport.sharedDataIsExclusive(
            selectedURL: photoshop, bundleID: "com.adobe.Photoshop", knownApplications: known))
        XCTAssertFalse(keepsOwnership(bundleID: "com.adobe.Photoshop", confidence: .exact,
                                      selectedURL: photoshop, knownApplications: known))
        XCTAssertFalse(keepsOwnership(bundleID: "com.adobe.Photoshop", confidence: .related,
                                      selectedURL: photoshop, knownApplications: known))
    }

    // MARK: The selected app is never its own vendor sibling

    func testSelectedAppAndItsNestedBundlesAreNotSiblings() {
        let nested = photoshop.appendingPathComponent("Contents/Helpers/Helper.app")
        let known = [(url: photoshop, bundleID: "com.adobe.Photoshop"),
                     (url: nested, bundleID: "com.adobe.Photoshop.Helper")]

        XCTAssertFalse(UninstallerSupport.vendorDataIsShared(bundleID: "com.adobe.Photoshop",
                                                             confidence: .related,
                                                             selectedURL: photoshop,
                                                             knownApplications: known))
    }

    // MARK: DATA-02 (a): a neighbor sharing the selected TeamID claims the group

    private let editorGroup = "group.com.acme.editor"
    private let acmeTeam = "ABCDE12345"

    func testNeighborWithSameTeamIDClaimsGroupWithoutOverlap() {
        let exclusive = UninstallerSupport.exclusiveSignedGroupIDs(
            [editorGroup], selectedTeamIDs: [acmeTeam],
            neighbors: [(teamIDs: [acmeTeam], groupIDs: [], readable: true)])

        XCTAssertFalse(exclusive.contains(editorGroup))
    }

    // MARK: DATA-02 (b): an unreadable neighbor claims every candidate group

    func testUnreadableNeighborMakesGroupNotExclusive() {
        let exclusive = UninstallerSupport.exclusiveSignedGroupIDs(
            [editorGroup], selectedTeamIDs: [acmeTeam],
            neighbors: [(teamIDs: [], groupIDs: [], readable: false)])

        XCTAssertFalse(exclusive.contains(editorGroup))
    }

    // MARK: DATA-02 (c): shared group folders keep their signed-group protection

    func testGroupContainersRequireSignedGroupAndNoBundleOwner() {
        let home = URL(fileURLWithPath: "/Users/tester", isDirectory: true)
        let groupFolders = UninstallerSupport.searchFolders(home: home, darwinCache: nil,
                                                            darwinTemp: nil)
            .filter { $0.url.lastPathComponent == "Group Containers"
                && $0.url.path.hasPrefix("/Users/tester/Library/") }

        XCTAssertEqual(groupFolders.count, 1)
        XCTAssertEqual(groupFolders.first?.requiresSignedGroup, true)

        let groupOnly = UninstallerSupport.Identity(bundleIDs: [], nameTokens: [],
                                                    teamIDs: [], groupIDs: [editorGroup])
        XCTAssertNil(UninstallerSupport.ownerBundleID(for: "com.acme.editor", identity: groupOnly))
        XCTAssertNil(UninstallerSupport.ownerBundleID(for: "com.acme.editor.helper",
                                                      identity: groupOnly))
    }

    // MARK: DATA-02 (d): no shared group or TeamID keeps the group exclusive

    func testGroupStaysExclusiveWithReadableUnrelatedNeighbors() {
        let exclusive = UninstallerSupport.exclusiveSignedGroupIDs(
            [editorGroup], selectedTeamIDs: [acmeTeam],
            neighbors: [(teamIDs: [], groupIDs: [], readable: true),
                        (teamIDs: ["ZZZZZ99999"], groupIDs: ["group.com.other"], readable: true)])

        XCTAssertEqual(exclusive, [editorGroup])
    }

    func testNeighborNamingTheGroupStillClaimsIt() {
        let exclusive = UninstallerSupport.exclusiveSignedGroupIDs(
            [editorGroup], selectedTeamIDs: [acmeTeam],
            neighbors: [(teamIDs: [], groupIDs: [editorGroup], readable: true)])

        XCTAssertEqual(exclusive, [])
    }

    // MARK: ARCH-01: kernel protection flags refuse selection and removal

    func testKernelProtectionMaskRecognizesOnlyLockFlags() {
        // sys/stat.h: SF_RESTRICTED, SF_IMMUTABLE, UF_IMMUTABLE; UF_HIDDEN is unrelated.
        XCTAssertTrue(UninstallerSupport.hasKernelProtection(flags: 0x0008_0000))
        XCTAssertTrue(UninstallerSupport.hasKernelProtection(flags: 0x0002_0000))
        XCTAssertTrue(UninstallerSupport.hasKernelProtection(flags: 0x0000_0002))
        XCTAssertFalse(UninstallerSupport.hasKernelProtection(flags: 0))
        XCTAssertFalse(UninstallerSupport.hasKernelProtection(flags: 0x0000_8000))
    }

    private func makeFixtureApp() throws -> (root: URL, bundle: URL) {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("hexa-arch01-\(UUID().uuidString)", isDirectory: true)
        let bundle = root.appendingPathComponent("Fixture.app", isDirectory: true)
        let contents = bundle.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let info: [String: Any] = ["CFBundleIdentifier": "com.example.hexa-arch01",
                                   "CFBundleName": "Fixture",
                                   "CFBundlePackageType": "APPL"]
        let data = try PropertyListSerialization.data(fromPropertyList: info,
                                                      format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))
        return (root, bundle)
    }

    func testUserImmutableBundleIsNotSelectedNorSafeToRemove() throws {
        let (root, bundle) = try makeFixtureApp()
        defer {
            try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: bundle.path)
            try? FileManager.default.removeItem(at: root)
        }
        let infoURL = bundle.appendingPathComponent("Contents/Info.plist")

        XCTAssertNotNil(UninstallerSupport.selection(for: bundle), "control: no flags set")
        XCTAssertTrue(UninstallerSupport.removalPathIsSafe(infoURL, within: bundle))

        try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: bundle.path)

        XCTAssertNil(UninstallerSupport.selection(for: bundle))
        XCTAssertFalse(UninstallerSupport.removalPathIsSafe(infoURL, within: bundle))
    }

    // MARK: FLOW-01: user agents are unloaded before their plist is trashed

    /// Records every launchctl call in order and answers with fixed statuses.
    /// No real launchctl runs: the tests never load, bootstrap, or print a job.
    private final class FakeLaunchctl {
        private(set) var calls: [[String]] = []
        private let bootoutStatus: Int32
        private let printStatus: Int32

        init(bootoutStatus: Int32 = 3, printStatus: Int32 = 113) {
            self.bootoutStatus = bootoutStatus
            self.printStatus = printStatus
        }

        func run(_ args: [String]) -> (status: Int32, output: String) {
            calls.append(args)
            return (args.first == "print" ? printStatus : bootoutStatus, "")
        }
    }

    /// A fake home under the temporary folder, with an empty LaunchAgents folder.
    private func makeFakeHome() throws -> URL {
        let home = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("hexa-flow01-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: home.appendingPathComponent("Library/LaunchAgents", isDirectory: true),
            withIntermediateDirectories: true)
        return home
    }

    private func writePlist(_ dict: [String: Any], to url: URL) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: dict,
                                                      format: .xml, options: 0)
        try data.write(to: url)
    }

    func testUserAgentIsBootedOutBeforePrintCheckAndMayBeTrashed() throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let plist = home.appendingPathComponent("Library/LaunchAgents/com.example.flow01.plist")
        try writePlist(["Label": "com.example.flow01"], to: plist)
        let fake = FakeLaunchctl(bootoutStatus: 3, printStatus: 113)

        XCTAssertTrue(AppUninstaller.unloadAgentBeforeTrash(plist, home: home.path, run: fake.run))

        let target = "gui/\(getuid())/com.example.flow01"
        XCTAssertEqual(fake.calls, [["bootout", target], ["print", target]])
    }

    func testNoLaunchctlCallOutsideAgentsOrWithoutValidLabel() throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let agents = home.appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        let preferences = home.appendingPathComponent("Library/Preferences", isDirectory: true)
        try FileManager.default.createDirectory(at: preferences, withIntermediateDirectories: true)
        let cases: [(name: String, url: URL, dict: [String: Any])] = [
            ("label with slash", agents.appendingPathComponent("slash.plist"),
             ["Label": "com.example/evil"]),
            ("label with dotdot", agents.appendingPathComponent("dots.plist"),
             ["Label": "com.example..evil"]),
            ("plist outside LaunchAgents", preferences.appendingPathComponent("outside.plist"),
             ["Label": "com.example.outside"]),
            ("plist without Label", agents.appendingPathComponent("nolabel.plist"),
             ["Program": "/bin/true"]),
            ("non-plist file", agents.appendingPathComponent("agent.txt"),
             ["Label": "com.example.txt"]),
        ]

        for testCase in cases {
            try writePlist(testCase.dict, to: testCase.url)
            let fake = FakeLaunchctl()
            XCTAssertTrue(AppUninstaller.unloadAgentBeforeTrash(
                testCase.url, home: home.path, run: fake.run), testCase.name)
            XCTAssertTrue(fake.calls.isEmpty, testCase.name)
        }
    }

    func testStillLoadedAgentKeepsItsPlist() throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let plist = home.appendingPathComponent("Library/LaunchAgents/com.example.loaded.plist")
        try writePlist(["Label": "com.example.loaded"], to: plist)
        // print exits 0 while launchd still holds the job loaded.
        let fake = FakeLaunchctl(bootoutStatus: 0, printStatus: 0)

        XCTAssertFalse(AppUninstaller.unloadAgentBeforeTrash(plist, home: home.path, run: fake.run))
        XCTAssertEqual(fake.calls.count, 2)
    }

    // MARK: FLOW-02: the app bundle goes last

    private struct InjectedTrashFailure: Error {}

    /// Records the injected trash and Finder calls. The trash deletes the file
    /// unless its path is listed as failing; the Finder fake moves nothing, so
    /// stubborn items stay in place. Neither reaches the real Trash or AppleScript.
    /// Before each trash call, the paths in `deletesOnTrash` other than that
    /// call's own target are removed, as if another process took them.
    private final class FakeTrash {
        private(set) var trashCalls: [URL] = []
        private(set) var finderBatches: [[URL]] = []
        private let failingPaths: Set<String>
        private let deletesOnTrash: [URL]

        init(failingPaths: Set<String> = [], deletesOnTrash: [URL] = []) {
            self.failingPaths = failingPaths
            self.deletesOnTrash = deletesOnTrash
        }

        func trash(_ url: URL) throws {
            trashCalls.append(url)
            for other in deletesOnTrash where other != url
                && FileManager.default.fileExists(atPath: other.path) {
                try FileManager.default.removeItem(at: other)
            }
            if failingPaths.contains(url.path) { throw InjectedTrashFailure() }
            try FileManager.default.removeItem(at: url)
        }

        func finder(_ urls: [URL]) {
            finderBatches.append(urls)
        }
    }

    private func makeLeftover(_ url: URL,
                              _ category: AppUninstaller.Category) -> AppUninstaller.Leftover {
        AppUninstaller.Leftover(url: url, category: category, size: 1,
                                ownerBundleID: nil, ownerGroupID: nil, evidenceBundleID: nil,
                                confidence: .exact,
                                fileIdentity: UninstallerSupport.FileIdentity(device: 0, inode: 0))
    }

    /// A temporary folder holding a fake app bundle and two leftover files.
    private func makeRemovalFixture() throws -> (root: URL, app: URL, support: URL, cache: URL) {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("hexa-flow02-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let app = root.appendingPathComponent("Fixture.app", isDirectory: true)
        let support = root.appendingPathComponent("support.dat")
        let cache = root.appendingPathComponent("cache.dat")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: support)
        try Data("x".utf8).write(to: cache)
        return (root, app, support, cache)
    }

    func testRemovalOrderPutsAppBundleLast() {
        let base = URL(fileURLWithPath: "/tmp/hexa-flow02-order")
        let cases: [(input: [AppUninstaller.Category], expected: [AppUninstaller.Category])] = [
            ([.app], [.app]),
            ([.support, .app], [.support, .app]),
            ([.app, .support], [.support, .app]),
            ([.caches, .app, .other], [.caches, .other, .app]),
        ]
        for testCase in cases {
            let items = testCase.input.enumerated().map {
                makeLeftover(base.appendingPathComponent("item\($0.offset)"), $0.element)
            }
            XCTAssertEqual(AppUninstaller.removalOrder(items).map(\.category), testCase.expected,
                           "\(testCase.input)")
        }
    }

    func testFailedLeftoverKeepsTheBundleInPlace() throws {
        let fixture = try makeRemovalFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let fake = FakeTrash(failingPaths: [fixture.support.path])
        let items = [makeLeftover(fixture.app, .app), makeLeftover(fixture.support, .support)]

        let result = AppUninstaller.removeChosen(items, keepsOwnership: { _ in true },
                                                 isStillSafe: { _ in true },
                                                 trash: fake.trash, finderTrash: fake.finder)

        XCTAssertEqual(fake.trashCalls, [fixture.support], "the bundle is never trashed")
        XCTAssertEqual(fake.finderBatches, [[fixture.support]], "the bundle never reaches Finder")
        XCTAssertEqual(result.failed.map(\.url), [fixture.support, fixture.app])
        XCTAssertEqual(result.outcomes, [])
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.support.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.app.path))
    }

    func testBundleIsTrashedOnceAfterEveryLeftover() throws {
        let fixture = try makeRemovalFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let fake = FakeTrash()
        let items = [makeLeftover(fixture.app, .app),
                     makeLeftover(fixture.support, .support),
                     makeLeftover(fixture.cache, .caches)]

        let result = AppUninstaller.removeChosen(items, keepsOwnership: { _ in true },
                                                 isStillSafe: { _ in true },
                                                 trash: fake.trash, finderTrash: fake.finder)

        XCTAssertEqual(fake.trashCalls, [fixture.support, fixture.cache, fixture.app])
        XCTAssertEqual(fake.finderBatches, [], "no Finder call when every trash succeeds")
        XCTAssertTrue(result.failed.isEmpty)
        XCTAssertEqual(result.outcomes, [.movedToTrash(size: 1), .movedToTrash(size: 1),
                                         .movedToTrash(size: 1)])
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.app.path))
    }

    func testAbsentBundleIsNotReportedWhenALeftoverFails() throws {
        let fixture = try makeRemovalFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        try FileManager.default.removeItem(at: fixture.app)
        let fake = FakeTrash(failingPaths: [fixture.support.path])
        let items = [makeLeftover(fixture.app, .app), makeLeftover(fixture.support, .support)]

        let result = AppUninstaller.removeChosen(items, keepsOwnership: { _ in true },
                                                 isStillSafe: { _ in true },
                                                 trash: fake.trash, finderTrash: fake.finder)

        XCTAssertEqual(result.failed.map(\.url), [fixture.support])
        XCTAssertEqual(fake.trashCalls, [fixture.support], "the absent bundle is never trashed")
    }

    func testRefusedLeftoverKeepsTheBundleInPlace() throws {
        let fixture = try makeRemovalFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let fake = FakeTrash()
        let items = [makeLeftover(fixture.app, .app), makeLeftover(fixture.support, .support)]

        let result = AppUninstaller.removeChosen(items,
                                                 keepsOwnership: { $0.url != fixture.support },
                                                 isStillSafe: { _ in true },
                                                 trash: fake.trash, finderTrash: fake.finder)

        XCTAssertEqual(result.failed.map(\.url), [fixture.support, fixture.app])
        XCTAssertEqual(fake.trashCalls, [])
        XCTAssertEqual(fake.finderBatches, [])
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.app.path))
    }

    func testLeftoverRefusedByOwnershipDoesNotCloseTheGate() throws {
        let fixture = try makeRemovalFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        try FileManager.default.removeItem(at: fixture.support)
        let fake = FakeTrash()
        let items = [makeLeftover(fixture.app, .app), makeLeftover(fixture.support, .support)]

        let result = AppUninstaller.removeChosen(items,
                                                 keepsOwnership: { $0.url != fixture.support },
                                                 isStillSafe: { _ in true },
                                                 trash: fake.trash, finderTrash: fake.finder)

        XCTAssertTrue(result.failed.isEmpty, "an absent leftover refused by ownership is not a failure")
        XCTAssertEqual(fake.trashCalls, [fixture.app])
        XCTAssertEqual(fake.finderBatches, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.app.path))
    }

    func testLeftoverGoneBeforeFinderBatchIsNotReported() throws {
        let fixture = try makeRemovalFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        // The support file fails to trash, stays, and is removed by another
        // process during the cache trash, before the Finder batch runs.
        let fake = FakeTrash(failingPaths: [fixture.support.path],
                             deletesOnTrash: [fixture.support])
        let items = [makeLeftover(fixture.support, .support),
                     makeLeftover(fixture.cache, .caches),
                     makeLeftover(fixture.app, .app)]

        let result = AppUninstaller.removeChosen(items, keepsOwnership: { _ in true },
                                                 isStillSafe: {
                                                     FileManager.default.fileExists(atPath: $0.url.path)
                                                 },
                                                 trash: fake.trash, finderTrash: fake.finder)

        XCTAssertTrue(result.failed.isEmpty)
        XCTAssertEqual(fake.finderBatches, [], "an absent leftover names no Finder call")
        XCTAssertEqual(fake.trashCalls, [fixture.support, fixture.cache, fixture.app])
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.app.path))
    }

    /// A symlink whose target is missing: fileExists reads it as absent, lstat does not.
    private func makeDanglingLink(in root: URL) throws -> URL {
        let link = root.appendingPathComponent("dangling.link")
        try FileManager.default.createSymbolicLink(
            at: link, withDestinationURL: root.appendingPathComponent("missing-target"))
        return link
    }

    func testEntryExistsSeesDanglingLinkButNotMissingPath() throws {
        let fixture = try makeRemovalFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let link = try makeDanglingLink(in: fixture.root)

        XCTAssertFalse(FileManager.default.fileExists(atPath: link.path))
        XCTAssertTrue(UninstallerSupport.entryExists(at: link))
        XCTAssertFalse(UninstallerSupport.entryExists(
            at: fixture.root.appendingPathComponent("never-created")))
    }

    func testConfirmedAbsenceIsTrueForMissingPathAndFalseForDanglingLink() throws {
        let fixture = try makeRemovalFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let link = try makeDanglingLink(in: fixture.root)

        XCTAssertTrue(UninstallerSupport.isConfirmedAbsent(
            at: fixture.root.appendingPathComponent("never-created")))
        XCTAssertFalse(UninstallerSupport.isConfirmedAbsent(at: link))
    }

    func testDanglingLinkThatTrashCannotMoveReachesFinderAndFails() throws {
        let fixture = try makeRemovalFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let link = try makeDanglingLink(in: fixture.root)
        let fake = FakeTrash(failingPaths: [link.path])
        let items = [makeLeftover(link, .support)]

        let result = AppUninstaller.removeChosen(items, keepsOwnership: { _ in true },
                                                 isStillSafe: { _ in true },
                                                 trash: fake.trash, finderTrash: fake.finder)

        XCTAssertEqual(fake.finderBatches, [[link]], "a surviving dangling link gets the Finder fallback")
        XCTAssertEqual(result.failed.map(\.url), [link])
        XCTAssertEqual(result.outcomes, [])
    }

    /// The Finder batch is one script with one `try` block per path. Paths are
    /// embedded as escaped literals, so a quote or backslash cannot end the
    /// string early. Expected text is hard-coded with fixed sample paths; the
    /// escaping helper is not reused. Only the builder is called; no script runs.
    func testFinderTrashScriptHasOneTellAndOneHandlerPerPath() {
        let plain = URL(fileURLWithPath: "/Library/Caches/com.example.app")
        let tricky = URL(fileURLWithPath: "/Library/Application Support/Say \"hi\"\\there")
        let script = AppUninstaller.finderTrashScript(for: [plain, tricky])

        XCTAssertEqual(occurrences(of: "tell application \"Finder\"", in: script), 1)
        XCTAssertEqual(occurrences(of: "on error", in: script), 2)
        // ISSUE-232: the script bounds its own wait, so no execution is abandoned.
        XCTAssertEqual(occurrences(of: "with timeout of 180 seconds", in: script), 1)
        XCTAssertTrue(script.contains("POSIX file \"/Library/Caches/com.example.app\""))
        XCTAssertTrue(script.contains("POSIX file \"/Library/Application Support/Say \\\"hi\\\"\\\\there\""))
        XCTAssertFalse(script.contains("with administrator privileges"))
    }

    /// Per-item isolation: each path has its own `try` ... `end try` pair and
    /// its own `on error` handler. No handler re-raises, so the only `return`
    /// is the final one and no bare `error` statement appears.
    func testFinderTrashScriptIsolatesEachPathInItsOwnTry() {
        let urls = (1...3).map { URL(fileURLWithPath: "/tmp/hexa-finder-\($0)") }
        let script = AppUninstaller.finderTrashScript(for: urls)
        let lines = script.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        XCTAssertEqual(lines.filter { $0 == "try" }.count, 3)
        XCTAssertEqual(lines.filter { $0 == "end try" }.count, 3)
        XCTAssertEqual(lines.filter { $0.hasPrefix("on error ") }.count, 3)
        XCTAssertEqual(lines.filter { $0.hasPrefix("return") }.count, 1)
        XCTAssertEqual(lines.filter { $0 == "error" || $0.hasPrefix("error ") }.count, 0)
    }

    func testFinderTrashFailureMapsCancelConsentAndIoError() {
        XCTAssertEqual(AppUninstaller.finderTrashFailure(errorNumber: -128), .cancelled)
        XCTAssertEqual(AppUninstaller.finderTrashFailure(errorNumber: -1743), .consentDenied)
        XCTAssertEqual(AppUninstaller.finderTrashFailure(errorNumber: -1744), .consentDenied)
        XCTAssertEqual(AppUninstaller.finderTrashFailure(errorNumber: -43), .ioError)
        XCTAssertEqual(AppUninstaller.finderTrashFailure(errorNumber: -1700), .ioError)
    }

    /// One entry per path in input order. A line that is missing counts as an
    /// I/O failure, and a whole call with no output marks every path failed.
    func testFinderTrashFailuresReadOneLinePerPathAndMissingLineIsIoError() {
        XCTAssertEqual(AppUninstaller.finderTrashFailures(from: "ok\nerror -128\n", count: 3),
                       [nil, .cancelled, .ioError])
        XCTAssertEqual(AppUninstaller.finderTrashFailures(from: "", count: 2),
                       [.ioError, .ioError])
    }

    // MARK: OPEX-02: failed leftovers stay for a retry

    /// The list keeps only the failed items, selected again, and their paths.
    /// The inputs start unselected, as scan results do, to show the flag is set.
    func testLeftoversKeptAfterRemovalKeepsFailedItemsSelectedWithTheirPaths() {
        let base = URL(fileURLWithPath: "/tmp/hexa-opex02-kept")
        let failed = [makeLeftover(base.appendingPathComponent("a.dat"), .support),
                      makeLeftover(base.appendingPathComponent("b.dat"), .caches)]
        XCTAssertFalse(failed.contains(where: \.include))

        let kept = AppUninstaller.leftoversKeptAfterRemoval(failed)

        XCTAssertEqual(kept.items.map(\.id), failed.map(\.id))
        XCTAssertTrue(kept.items.allSatisfy(\.include))
        XCTAssertEqual(kept.allowedPaths, Set(failed.map { $0.url.standardizedFileURL.path }))
    }

    /// A retry offers only the failed subset: a path that did not fail is not
    /// kept, so the safety gate refuses it on the next run. The instance method
    /// `retryFailed()` installs this same result before it calls removal.
    func testRetryScopeExcludesEveryPathThatDidNotFail() {
        let base = URL(fileURLWithPath: "/tmp/hexa-opex02-retry")
        let app = makeLeftover(base.appendingPathComponent("Fixture.app"), .app)
        let cache = makeLeftover(base.appendingPathComponent("cache.dat"), .caches)
        let support = makeLeftover(base.appendingPathComponent("support.dat"), .support)

        let kept = AppUninstaller.leftoversKeptAfterRemoval([support])

        XCTAssertEqual(kept.items.map(\.id), [support.id])
        XCTAssertEqual(kept.allowedPaths, [support.url.standardizedFileURL.path])
        XCTAssertFalse(kept.allowedPaths.contains(app.url.standardizedFileURL.path))
        XCTAssertFalse(kept.allowedPaths.contains(cache.url.standardizedFileURL.path))
    }

    /// A removal with no failures leaves nothing to retry.
    func testFullSuccessKeepsNoItemsAndNoPaths() {
        let kept = AppUninstaller.leftoversKeptAfterRemoval([])

        XCTAssertTrue(kept.items.isEmpty)
        XCTAssertTrue(kept.allowedPaths.isEmpty)
    }

    func testSymlinkSelectionResolvesToTheBundle() throws {
        let (root, bundle) = try makeFixtureApp()
        defer { try? FileManager.default.removeItem(at: root) }
        let link = root.appendingPathComponent("Link.app")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: bundle)

        let selected = UninstallerSupport.selection(for: link)
        XCTAssertEqual(selected?.url.standardizedFileURL.path, bundle.standardizedFileURL.path)
        XCTAssertEqual(selected?.installLink?.standardizedFileURL.path, link.standardizedFileURL.path)
        XCTAssertNil(UninstallerSupport.selection(for: bundle)?.installLink)
    }

    func testSymlinkToANonBundleIsRefused() throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("hexa-link-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("note.txt")
        try Data("x".utf8).write(to: file)
        let link = root.appendingPathComponent("Note.app")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)

        XCTAssertNil(UninstallerSupport.selection(for: link))
    }

    func testInstallLinkIsTrashedOnlyAfterTheBundleIsGone() throws {
        let (root, bundle) = try makeFixtureApp()
        defer { try? FileManager.default.removeItem(at: root) }
        let link = root.appendingPathComponent("Link.app")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: bundle)
        let identity = try XCTUnwrap(UninstallerSupport.fileIdentity(at: link))
        let kept = FakeTrash(failingPaths: [bundle.path])
        let keptResult = AppUninstaller.removeChosen(
            [makeLeftover(bundle, .app)],
            keepsOwnership: { _ in true },
            isStillSafe: { _ in true },
            installLink: (link, identity, bundle.path),
            trash: kept.trash,
            finderTrash: kept.finder)
        XCTAssertEqual(kept.trashCalls, [bundle])
        XCTAssertEqual(keptResult.failed.map(\.url), [bundle])
        XCTAssertTrue(FileManager.default.fileExists(atPath: link.path))

        let removed = FakeTrash()
        let removedResult = AppUninstaller.removeChosen(
            [makeLeftover(bundle, .app)],
            keepsOwnership: { _ in true },
            isStillSafe: { _ in true },
            installLink: (link, identity, bundle.path),
            trash: removed.trash,
            finderTrash: removed.finder)
        XCTAssertEqual(removed.trashCalls, [bundle, link])
        XCTAssertTrue(removedResult.failed.isEmpty)
    }

    func testRemovalNoticesNeedARealExtensionOrLoginItem() throws {
        let (root, bundle) = try makeFixtureApp()
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertTrue(UninstallerSupport.removalNotices(in: bundle).isEmpty)

        let library = bundle.appendingPathComponent("Contents/Library", isDirectory: true)
        let extensions = library.appendingPathComponent("SystemExtensions", isDirectory: true)
        let loginItems = library.appendingPathComponent("LoginItems", isDirectory: true)
        try FileManager.default.createDirectory(at: extensions, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: loginItems, withIntermediateDirectories: true)
        XCTAssertTrue(UninstallerSupport.removalNotices(in: bundle).isEmpty)

        try FileManager.default.createDirectory(
            at: extensions.appendingPathComponent("Fixture.systemextension", isDirectory: true),
            withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: loginItems.appendingPathComponent("Helper.app", isDirectory: true),
            withIntermediateDirectories: true)
        XCTAssertEqual(UninstallerSupport.removalNotices(in: bundle), [.systemExtension, .loginItem])
    }

    func testPrivilegedServiceTargetUsesTheRightDomain() {
        XCTAssertEqual(
            UninstallerSupport.privilegedServiceTarget(
                path: "/Library/LaunchDaemons/com.example.helper.plist",
                label: "com.example.helper", uid: 501),
            "system/com.example.helper")
        XCTAssertEqual(
            UninstallerSupport.privilegedServiceTarget(
                path: "/Library/LaunchAgents/com.example.agent.plist",
                label: "com.example.agent", uid: 501),
            "gui/501/com.example.agent")
        XCTAssertEqual(
            UninstallerSupport.privilegedServiceTarget(
                path: "/Library/PrivilegedHelperTools/com.example.helper",
                label: "com.example.helper", uid: 501),
            "system/com.example.helper")
        XCTAssertNil(UninstallerSupport.privilegedServiceTarget(
            path: "/Users/me/Library/LaunchAgents/com.example.agent.plist",
            label: "com.example.agent", uid: 501))
        XCTAssertNil(UninstallerSupport.privilegedServiceTarget(
            path: "/Library/LaunchDaemons/evil.plist",
            label: "com.example/evil", uid: 501))
    }

    func testPrivilegedBootoutCommandRefusesUnsafeTargets() throws {
        XCTAssertNil(UninstallerSupport.privilegedBootoutCommand(targets: []))
        XCTAssertNil(UninstallerSupport.privilegedBootoutCommand(targets: ["system/com.evil;rm"]))
        let command = try XCTUnwrap(UninstallerSupport.privilegedBootoutCommand(
            targets: ["gui/501/com.example.agent", "system/com.example.helper"]))
        XCTAssertTrue(command.contains("/bin/launchctl bootout 'system/com.example.helper'"))
        XCTAssertTrue(command.contains("/bin/launchctl print 'gui/501/com.example.agent'"))
        XCTAssertFalse(command.contains(";rm"))
    }

    func testPrivilegedDaemonStaysWhenTheAdministratorRefuses() throws {
        let fixture = try makeRemovalFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let daemon = fixture.root.appendingPathComponent("daemon.plist")
        try writePlist(["Label": "com.example.flow01"], to: daemon)
        let fake = FakeTrash()
        var prompts: [[String]] = []

        let refused = AppUninstaller.removeChosen(
            [makeLeftover(daemon, .other)],
            keepsOwnership: { _ in true },
            isStillSafe: { _ in true },
            privilegedLocation: { $0 == daemon },
            privilegedTarget: { _ in "system/com.example.flow01" },
            runAdmin: { targets in
                prompts.append(targets)
                return false
            },
            trash: fake.trash,
            finderTrash: fake.finder)

        XCTAssertEqual(prompts, [["system/com.example.flow01"]])
        XCTAssertTrue(fake.trashCalls.isEmpty)
        XCTAssertEqual(refused.failed.map(\.url), [daemon])
        XCTAssertTrue(FileManager.default.fileExists(atPath: daemon.path))
    }

    func testPrivilegedDaemonIsTrashedAfterTheAdministratorAgrees() throws {
        let fixture = try makeRemovalFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let daemon = fixture.root.appendingPathComponent("daemon.plist")
        try writePlist(["Label": "com.example.flow01"], to: daemon)
        let fake = FakeTrash()

        let removed = AppUninstaller.removeChosen(
            [makeLeftover(daemon, .other)],
            keepsOwnership: { _ in true },
            isStillSafe: { _ in true },
            privilegedLocation: { $0 == daemon },
            privilegedTarget: { _ in "system/com.example.flow01" },
            runAdmin: { _ in true },
            trash: fake.trash,
            finderTrash: fake.finder)

        XCTAssertEqual(fake.trashCalls, [daemon])
        XCTAssertTrue(removed.failed.isEmpty)
    }

    private func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    func testWrapperAppBundleIsSelectedAndMatchesIdentity() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hexa-wrapper-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let wrapperApp = root.appendingPathComponent("FixtureMobile.app", isDirectory: true)
        let payloadApp = wrapperApp
            .appendingPathComponent("Wrapper", isDirectory: true)
            .appendingPathComponent("Payload.app", isDirectory: true)
        try FileManager.default.createDirectory(at: payloadApp, withIntermediateDirectories: true)
        let infoURL = payloadApp.appendingPathComponent("Info.plist")
        try writePlist([
            "CFBundleIdentifier": "com.example.mobileapp",
            "CFBundleName": "FixtureMobile",
            "CFBundleExecutable": "FixtureMobile",
        ], to: infoURL)
        try FileManager.default.createSymbolicLink(
            atPath: wrapperApp.appendingPathComponent("WrappedBundle").path,
            withDestinationPath: "Wrapper/Payload.app"
        )

        let selection = try XCTUnwrap(UninstallerSupport.selection(for: wrapperApp))
        XCTAssertEqual(selection.bundleID, "com.example.mobileapp")
        XCTAssertTrue(UninstallerSupport.removalPathIsSafe(infoURL, within: wrapperApp))
        XCTAssertTrue(AppUninstaller.applicationIdentityMatches(
            wrapperApp,
            appIdentity: selection.identity,
            infoIdentity: selection.infoIdentity
        ))
    }

    func testEvaluateSelectionRefusalReasons() throws {
        XCTAssertEqual(
            UninstallerSupport.evaluateSelection(
                for: URL(fileURLWithPath: "/System/Applications/Calculator.app")
            ),
            .failure(.systemApp)
        )
        XCTAssertEqual(
            UninstallerSupport.evaluateSelection(for: Bundle.main.bundleURL),
            .failure(.selfApp)
        )
        XCTAssertEqual(
            UninstallerSupport.evaluateSelection(
                for: URL(fileURLWithPath: "/Applications/Foo.app/Contents/Library/LoginItems/Helper.app")
            ),
            .failure(.nestedApp)
        )

        let plainDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hexa-refusal-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: plainDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: plainDir) }
        XCTAssertEqual(
            UninstallerSupport.evaluateSelection(for: plainDir),
            .failure(.unidentifiedOrProtected)
        )
    }
}
