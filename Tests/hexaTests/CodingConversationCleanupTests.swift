// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Pins the old Claude Code conversation rules: a conversation is a
/// transcript plus its folder, aged by the newest change in the pair; only
/// UUID named children of a project are candidates; the desktop app's
/// references and unreadable metadata keep conversations out; removal refuses
/// outside paths, symbolic links and changed files; and an unattended pass
/// never searches. Every test runs on a scratch home under the temporary
/// directory. The real home, its Claude folders and its metadata are never read.
final class CodingConversationCleanupTests: XCTestCase {
    private let uuidOld = "2f1c9d7e-0a7b-4c1e-9f3a-6b2d8e4f1a01"
    private let uuidRecent = "2f1c9d7e-0a7b-4c1e-9f3a-6b2d8e4f1a02"
    private let uuidMixed = "2f1c9d7e-0a7b-4c1e-9f3a-6b2d8e4f1a03"
    private let uuidShallow = "2f1c9d7e-0a7b-4c1e-9f3a-6b2d8e4f1a05"
    private let uuidMoved = "2f1c9d7e-0a7b-4c1e-9f3a-6b2d8e4f1a06"
    private let uuidLinked = "2f1c9d7e-0a7b-4c1e-9f3a-6b2d8e4f1a07"
    private let uuidReferenced = "2f1c9d7e-0a7b-4c1e-9f3a-6b2d8e4f1a08"
    private let uuidDeletedName = "2f1c9d7e-0a7b-4c1e-9f3a-6b2d8e4f1a09"

    private let projects = ".claude/projects"
    private let metadata = "Library/Application Support/Claude/claude-code-sessions/acct/org"

    /// A unique scratch home under the system temporary directory, removed
    /// when the test ends.
    private func makeFixtureHome() throws -> String {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hexa-conversations-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root.standardizedFileURL.path
    }

    /// Writes a file of exactly `bytes` zero bytes under `home`.
    private func write(_ bytes: Int, to relativePath: String, in home: String) throws {
        let url = URL(fileURLWithPath: home + "/" + relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data(count: bytes).write(to: url)
    }

    private func writeText(_ text: String, to relativePath: String, in home: String) throws {
        let url = URL(fileURLWithPath: home + "/" + relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    /// Sets the modification date of every listed entry to `days` ago.
    private func backdate(_ relativePaths: [String], in home: String, days: Int) throws {
        let date = Date().addingTimeInterval(-TimeInterval(days) * 86_400)
        for relativePath in relativePaths {
            try FileManager.default.setAttributes([.modificationDate: date],
                                                  ofItemAtPath: home + "/" + relativePath)
        }
    }

    /// One conversation entirely older than 100 days: a 4 KiB transcript and a
    /// folder holding an 8 KiB file. Its summed size is 12 KiB.
    private func makeOldConversation(_ uuid: String, in home: String) throws {
        try write(4096, to: "\(projects)/p1/\(uuid).jsonl", in: home)
        try write(8192, to: "\(projects)/p1/\(uuid)/sub/part.json", in: home)
        try backdate(["\(projects)/p1/\(uuid).jsonl", "\(projects)/p1/\(uuid)",
                      "\(projects)/p1/\(uuid)/sub", "\(projects)/p1/\(uuid)/sub/part.json"],
                     in: home, days: 100)
    }

    private func scan(_ home: String, days: Int = 30) -> [JunkCleaner.Item] {
        JunkCleaner.scanCodingConversations(olderThanDays: days, home: home)
    }

    // MARK: DoD 1: candidates, age, names, and the off switch

    func testPairAgedByItsNewestChangeWithItsSummedSize() throws {
        let home = try makeFixtureHome()
        try makeOldConversation(uuidOld, in: home)
        // A folder with something changed today is not old, even though its
        // transcript is.
        try write(4096, to: "\(projects)/p1/\(uuidMixed).jsonl", in: home)
        try write(4096, to: "\(projects)/p1/\(uuidMixed)/sub/recent.json", in: home)
        try backdate(["\(projects)/p1/\(uuidMixed).jsonl"], in: home, days: 100)

        let items = scan(home)

        XCTAssertEqual(items.map(\.name), ["\(uuidOld).jsonl"])
        XCTAssertEqual(items.first?.size, 4096 + 8192)
        XCTAssertEqual(items.first?.companion?.lastPathComponent, uuidOld)
    }

    func testMemoryNonUUIDNamesAndDisabledAgeNeverAppear() throws {
        let home = try makeFixtureHome()
        try makeOldConversation(uuidOld, in: home)
        // The project's memory folder, and a transcript inside it: never candidates.
        try write(4096, to: "\(projects)/p1/memory/\(uuidRecent).jsonl", in: home)
        try write(4096, to: "\(projects)/p1/memory/MEMORY.md", in: home)
        try backdate(["\(projects)/p1/memory/\(uuidRecent).jsonl", "\(projects)/p1/memory/MEMORY.md",
                      "\(projects)/p1/memory"], in: home, days: 100)
        // A transcript whose name is not a UUID.
        try write(4096, to: "\(projects)/p1/notes.jsonl", in: home)
        try backdate(["\(projects)/p1/notes.jsonl"], in: home, days: 100)

        XCTAssertEqual(scan(home).map(\.name), ["\(uuidOld).jsonl"])
        XCTAssertTrue(scan(home, days: 0).isEmpty, "age 0 disables the search")
    }

    // MARK: DoD 2: born unchecked, and an unattended pass moves nothing

    func testItemsAreBornUncheckedAndUnattendedPassMovesNothing() throws {
        let home = try makeFixtureHome()
        try makeOldConversation(uuidOld, in: home)
        let items = scan(home)
        XCTAssertEqual(items.count, 1)
        XCTAssertTrue(items.allSatisfy { !$0.include && !$0.recommended && $0.category == .codingConversations })

        // The attended flag decides whether the search runs at all. The
        // unattended pass gets 0, even when the preference says 30.
        // Fixed domain: removePersistentDomain empties it but keeps the .plist.
        let suiteName = "hexaTests.coding-conversations"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(30, forKey: DefaultsKey.cleanerCodingConversationAgeDays)
        XCTAssertEqual(JunkCleaner.codingConversationSearchDays(attended: false, defaults: defaults), 0)
        XCTAssertEqual(JunkCleaner.codingConversationSearchDays(attended: true, defaults: defaults), 30)

        // The unattended pass cleans only what is selected. Nothing is, so the
        // conversation must stay where it is.
        JunkCleaner.shared.items = items
        JunkCleaner.shared.setPhaseForTesting(.results)
        addTeardownBlock { JunkCleaner.shared.reset() }
        JunkCleaner.shared.cleanSelected(escalate: false)

        XCTAssertTrue(FileManager.default.fileExists(atPath: home + "/\(projects)/p1/\(uuidOld).jsonl"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: home + "/\(projects)/p1/\(uuidOld)/sub/part.json"))
    }

    // MARK: DoD 2b: the real scan entry point, unattended and attended

    /// Runs the real scan on the shared cleaner over `home` and waits for its
    /// results. The scan hops back to the main queue, so the run loop is
    /// pumped until the phase settles.
    private func runScan(attended: Bool, home: String) throws -> [JunkCleaner.Item] {
        let cleaner = JunkCleaner.shared
        cleaner.reset()
        addTeardownBlock { cleaner.reset() }
        cleaner.scan(attended: attended, home: home)
        let deadline = Date().addingTimeInterval(60)
        while cleaner.phase != .results, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        XCTAssertEqual(cleaner.phase, .results, "the scan must finish within a minute")
        return cleaner.items
    }

    func testUnattendedScanFindsNoConversationWhileAttendedScanFindsIt() throws {
        let home = try makeFixtureHome()
        try makeOldConversation(uuidOld, in: home)

        let unattended = try runScan(attended: false, home: home)
        XCTAssertFalse(unattended.contains { $0.category == .codingConversations },
                       "an unattended scan must not offer any conversation")

        // Positive control: the same fixture, scanned attended, offers the pair.
        // The age comes from the preference. The default is registered for
        // this process only, which writes nothing to disk; a user who turned
        // the category off skips the control instead of failing it.
        UserDefaults.standard.register(defaults: [
            DefaultsKey.cleanerCodingConversationAgeDays: CleanerPolicy.defaultCodingConversationAgeDays,
        ])
        try XCTSkipIf(JunkCleaner.codingConversationSearchDays(attended: true) == 0,
                      "the conversation age preference is off, so the attended control cannot run")

        let attended = try runScan(attended: true, home: home)
        let conversations = attended.filter { $0.category == .codingConversations }
        XCTAssertEqual(conversations.map(\.name), ["\(uuidOld).jsonl"])
        XCTAssertTrue(conversations.allSatisfy { $0.url.path.hasPrefix(home) })
    }

    // MARK: DoD 3: removal refuses outside paths, symbolic links and changed files

    func testRemovalRulesRefuseOutsidePathsSymbolicLinksAndChangedFiles() throws {
        let home = try makeFixtureHome()
        let root = home + "/" + projects
        func allowed(_ url: URL, identity: UninstallerSupport.FileIdentity?) -> Bool {
            CleanerPolicy.isCodingConversationRemovalAllowed(
                url, companion: nil, projectsRoot: root,
                transcriptIdentity: identity, companionIdentity: nil)
        }

        // Control: a UUID transcript directly inside a project, unchanged.
        try write(4096, to: "\(projects)/p1/\(uuidOld).jsonl", in: home)
        let inside = URL(fileURLWithPath: root + "/p1/\(uuidOld).jsonl")
        XCTAssertTrue(allowed(inside, identity: UninstallerSupport.fileIdentity(at: inside)))

        // Outside ~/.claude/projects/<project>/.
        try write(4096, to: ".claude/elsewhere/p1/\(uuidRecent).jsonl", in: home)
        let outside = URL(fileURLWithPath: home + "/.claude/elsewhere/p1/\(uuidRecent).jsonl")
        XCTAssertFalse(allowed(outside, identity: UninstallerSupport.fileIdentity(at: outside)))

        // Directly under the projects folder, with no project between.
        try write(4096, to: "\(projects)/\(uuidShallow).jsonl", in: home)
        let shallow = URL(fileURLWithPath: root + "/\(uuidShallow).jsonl")
        XCTAssertFalse(allowed(shallow, identity: UninstallerSupport.fileIdentity(at: shallow)))

        // A symbolic link standing where a transcript should be.
        try write(4096, to: "real/\(uuidLinked).jsonl", in: home)
        try FileManager.default.createDirectory(atPath: root + "/p2", withIntermediateDirectories: true)
        let link = URL(fileURLWithPath: root + "/p2/\(uuidLinked).jsonl")
        try FileManager.default.createSymbolicLink(
            at: link, withDestinationURL: URL(fileURLWithPath: home + "/real/\(uuidLinked).jsonl"))
        XCTAssertFalse(allowed(link, identity: UninstallerSupport.fileIdentity(at: link)))

        // Changed after the scan: the old file is moved aside (which keeps its
        // inode alive) and a new file takes its name, so the identity differs.
        try write(4096, to: "\(projects)/p1/\(uuidMoved).jsonl", in: home)
        let moved = URL(fileURLWithPath: root + "/p1/\(uuidMoved).jsonl")
        let recorded = UninstallerSupport.fileIdentity(at: moved)
        try FileManager.default.moveItem(at: moved, to: URL(fileURLWithPath: home + "/moved-aside.jsonl"))
        try write(4096, to: "\(projects)/p1/\(uuidMoved).jsonl", in: home)
        XCTAssertFalse(allowed(moved, identity: recorded))
    }

    // MARK: DoD 4: desktop references and fail-safe metadata

    func testReferencedConversationsAreExcludedAndMissingMetadataExcludesNothing() throws {
        let home = try makeFixtureHome()
        for uuid in [uuidOld, uuidReferenced, uuidDeletedName] { try makeOldConversation(uuid, in: home) }
        // Metadata names the first by cliSessionId and the third by a deleted_ name.
        try writeText("{\"cliSessionId\": \"\(uuidReferenced)\", \"title\": \"x\"}",
                      to: "\(metadata)/local_1.json", in: home)
        try write(0, to: "\(metadata)/deleted_\(uuidDeletedName)", in: home)

        XCTAssertEqual(Set(scan(home).map(\.name)), ["\(uuidOld).jsonl"])

        // Without any metadata folder nothing is excluded.
        let bare = try makeFixtureHome()
        for uuid in [uuidOld, uuidReferenced, uuidDeletedName] { try makeOldConversation(uuid, in: bare) }
        XCTAssertEqual(scan(bare).count, 3)
    }

    func testUnparseableMetadataOffersNoConversationAtAll() throws {
        let home = try makeFixtureHome()
        for uuid in [uuidOld, uuidReferenced] { try makeOldConversation(uuid, in: home) }
        try writeText("{ not json", to: "\(metadata)/local_bad.json", in: home)

        XCTAssertTrue(scan(home).isEmpty)
    }

    func testUnreadableMetadataFolderOffersNoConversationAtAll() throws {
        let home = try makeFixtureHome()
        for uuid in [uuidOld, uuidReferenced] { try makeOldConversation(uuid, in: home) }
        try writeText("{\"cliSessionId\": \"\(uuidReferenced)\"}", to: "\(metadata)/local_1.json", in: home)
        let sessions = home + "/Library/Application Support/Claude/claude-code-sessions"
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: sessions)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: sessions)
        }

        XCTAssertTrue(scan(home).isEmpty)
    }
}
