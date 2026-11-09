// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Pins the two leftover holes: a group container and a direct iCloud
/// container are offered, unchecked, only when the name leaves a bundle
/// identifier whose owner is dead. A display name, a vendor folder, a nested
/// path and a protected identifier stay out. Every test uses a scratch home.
/// The real home and this Mac's registrations are never read.
final class CleanerLeftoverTests: XCTestCase {
    private func makeHome() throws -> String {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hexa-cleaner-leftover-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root.standardizedFileURL.path
    }

    private func makeDirectory(_ relativePath: String, in home: String) throws {
        try FileManager.default.createDirectory(atPath: home + "/" + relativePath,
                                                withIntermediateDirectories: true)
    }

    private func writeGroupMetadata(_ identifier: String, in folder: String, home: String) throws {
        let url = URL(fileURLWithPath: home + "/" + folder, isDirectory: true)
            .appendingPathComponent(".com.apple.containermanagerd.metadata.plist")
        let data = try PropertyListSerialization.data(
            fromPropertyList: ["MCMMetadataIdentifier": identifier],
            format: .xml,
            options: 0)
        try data.write(to: url)
    }

    /// `registered` stands in for Launch Services. The system library is not walked.
    private func scan(_ home: String,
                      installed: Set<String> = [],
                      registered: Set<String> = []) -> [JunkCleaner.Item] {
        JunkCleaner.scanLeftovers(
            installed: installed,
            home: home,
            includeSystemLibrary: false,
            isRegistered: { registered.contains($0.lowercased()) })
    }

    private func details(_ items: [JunkCleaner.Item]) -> Set<String> {
        Set(items.map(\.detail))
    }

    // MARK: Accept: dead owner, unchecked

    func testAbsentGroupAndICloudContainersAreUncheckedLeftovers() throws {
        let home = try makeHome()
        let folders = [
            "Library/Group Containers/group.com.absentvendor.editor",
            "Library/Group Containers/systemgroup.com.absentvendor.widget",
            "Library/Group Containers/ZZZZZ99999.com.absentvendor.panel",
            "Library/Application Support/group.com.absentvendor.notes",
            "Library/Containers/group.com.absentvendor.drawer",
            "Library/Application Support/com.absentvendor.legacy",
            "Library/Mobile Documents/iCloud~com~absentvendor~reader",
            "Library/Mobile Documents/iCloud~com.absentvendor.writer",
            "Library/Mobile Documents/com.absentvendor.archive",
        ]
        for folder in folders {
            try makeDirectory(folder, in: home)
        }
        // A child inside an accepted container is not its own leftover.
        try makeDirectory(
            "Library/Group Containers/group.com.absentvendor.editor/Inner/com.othervendor.nested",
            in: home)
        try makeDirectory(
            "Library/Mobile Documents/iCloud~com~absentvendor~reader/com.othervendor.nested",
            in: home)

        let found = scan(home)

        XCTAssertFalse(CleanerPolicy.precheckLeftovers)
        XCTAssertEqual(details(found), [
            "com.absentvendor.editor",
            "com.absentvendor.widget",
            "com.absentvendor.panel",
            "com.absentvendor.notes",
            "com.absentvendor.drawer",
            "com.absentvendor.legacy",
            "com.absentvendor.reader",
            "com.absentvendor.writer",
            "com.absentvendor.archive",
        ])
        XCTAssertTrue(found.allSatisfy {
            $0.category == .leftovers && $0.recommended == false && $0.include == false
        })
        XCTAssertEqual(found.filter { $0.detail == "com.absentvendor.editor" }.map(\.name),
                       ["group.com.absentvendor.editor"])
        XCTAssertEqual(found.filter { $0.detail == "com.absentvendor.reader" }.map(\.name),
                       ["iCloud~com~absentvendor~reader"])
    }

    func testGroupMetadataNamesTheOwnerWhenTheFolderNameIsNotAnIdentifier() throws {
        let home = try makeHome()
        let folder = "Library/Group Containers/E5C2A1B0-1111-4222-8333-444444444444"
        try makeDirectory(folder, in: home)
        try writeGroupMetadata("group.com.absentvendor.editor", in: folder, home: home)
        try makeDirectory("Library/Group Containers/Notes", in: home)

        let found = scan(home)

        XCTAssertEqual(found.map(\.detail), ["com.absentvendor.editor"])
        XCTAssertEqual(found.map(\.name), ["E5C2A1B0-1111-4222-8333-444444444444"])
        XCTAssertFalse(found[0].include)
    }

    // MARK: Refuse: living vendor, registration, plain names, nesting

    func testVendorSiblingInstalledOrOwnerRegisteredHidesTheLeftover() throws {
        let home = try makeHome()
        try makeDirectory("Library/Group Containers/group.com.absentvendor.editor", in: home)
        try makeDirectory("Library/Mobile Documents/iCloud~com~absentvendor~reader", in: home)

        XCTAssertTrue(scan(home, installed: ["com.absentvendor.helper"]).isEmpty,
                      "an installed app of the same vendor keeps both")
        XCTAssertTrue(scan(home, installed: ["com.absentvendor"]).isEmpty,
                      "a family prefix keeps both")
        XCTAssertTrue(scan(home, installed: ["com.absentvendor.editor.helper"]).isEmpty,
                      "an embedded helper of the same identifier keeps both")
        XCTAssertTrue(scan(home, registered: [
            "com.absentvendor.editor", "com.absentvendor.reader",
        ]).isEmpty, "a registration of the owner keeps it")

        let otherVendor = scan(home, installed: ["com.othervendor.app"])
        XCTAssertEqual(details(otherVendor), [
            "com.absentvendor.editor", "com.absentvendor.reader",
        ])

        let onlyEditorRegistered = scan(home, registered: ["com.absentvendor.editor"])
        XCTAssertEqual(details(onlyEditorRegistered), ["com.absentvendor.reader"])
    }

    func testDisplayNamesVendorFoldersAndNestedPathsStayOut() throws {
        let home = try makeHome()
        let refused = [
            "Library/Application Support/Adobe",
            "Library/Application Support/Google",
            "Library/Application Support/Editor",
            "Library/Application Support/editor",
            "Library/Application Support/Adobe/com.absentvendor.editor",
            "Library/Caches/Google/com.absentvendor.editor",
            "Library/Containers/Vendor/com.absentvendor.editor",
            "Library/Group Containers/Editor",
            "Library/Group Containers/group.Editor",
            "Library/Group Containers/ZZZZZ99999.Editor",
            "Library/Group Containers/group.com.apple.notes",
            "Library/Group Containers/group.io.github.pauloborini.hexa.cleaner",
            "Library/Group Containers/group.org.sparkle-project.Sparkle",
            "Library/Mobile Documents/com~apple~CloudDocs",
            "Library/Mobile Documents/Adobe",
            "Library/Mobile Documents/iCloud~Adobe",
            "Library/Mobile Documents/iCloud~",
            "Library/Mobile Documents/CloudDocs/iCloud~com~absentvendor~editor",
            "Library/Mobile Documents/iCloud~com~apple~mail",
        ]
        for folder in refused {
            try makeDirectory(folder, in: home)
        }
        try makeDirectory("elsewhere", in: home)
        try FileManager.default.createSymbolicLink(
            atPath: home + "/Library/Group Containers/group.com.absentvendor.ghost",
            withDestinationPath: home + "/elsewhere")
        try FileManager.default.createSymbolicLink(
            atPath: home + "/Library/Mobile Documents/iCloud~com~absentvendor~ghost",
            withDestinationPath: home + "/elsewhere")
        // Positive control: the same scan still sees a direct identifier.
        try makeDirectory("Library/Group Containers/group.com.absentvendor.editor", in: home)

        let found = scan(home)

        XCTAssertEqual(details(found), ["com.absentvendor.editor"])
        XCTAssertEqual(found.map(\.name), ["group.com.absentvendor.editor"])
    }

    func testProtectedBundleIDRequiresDotBoundaryForSharedInfrastructure() {
        let thirdPartyIDs = [
            "com.segmentfault.reader",
            "io.sentrybox.Mac",
            "org.swiftbar.app",
            "com.amplitudex.player",
        ]
        for id in thirdPartyIDs {
            XCTAssertFalse(CleanerSupport.isProtectedBundleID(id), "expected \(id) not to be protected")
            XCTAssertEqual(UninstallerSupport.verifiedBundleID(id), id)
        }

        let protectedIDs = [
            "com.apple.Finder",
            "io.github.pauloborini.hexa",
            "io.github.pauloborini.hexa.dev",
            "com.segment",
            "com.segment.analytics",
            "io.sentry",
            "io.sentry.crash",
            "org.swift",
            "org.swift.swiftpm",
            "org.sparkle-project.Sparkle",
        ]
        for id in protectedIDs {
            XCTAssertTrue(CleanerSupport.isProtectedBundleID(id), "expected \(id) to be protected")
            XCTAssertNil(UninstallerSupport.verifiedBundleID(id))
        }
    }

    func testBundleIDCandidateStripsOnlyOneSuffix() {
        XCTAssertEqual(CleanerSupport.bundleIDCandidate(fromEntryName: "com.maker.App.savedState"), "com.maker.App")
        XCTAssertEqual(CleanerSupport.bundleIDCandidate(fromEntryName: "org.swiftbar.app.plist"), "org.swiftbar.app")
        XCTAssertEqual(CleanerSupport.bundleIDCandidate(fromEntryName: "com.maker.tool.plist"), "com.maker.tool")
    }
}
