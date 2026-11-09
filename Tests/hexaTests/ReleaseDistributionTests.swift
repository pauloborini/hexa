// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

final class ReleaseDistributionTests: XCTestCase {
    func testDownloadURLTargetsLatestGitHubRelease() {
        XCTAssertEqual(AppInfo.downloadURL.absoluteString,
                       "https://github.com/pauloborini/hexa/releases/latest")
    }

    func testSidebarCanSelectReleaseNotes() {
        let state = FeatureWorkspaceState()

        state.selectSystem(.releaseNotes)

        XCTAssertEqual(state.systemDestination, .releaseNotes)
        XCTAssertEqual(state.destination, .releaseNotes)
    }

    func testReleaseNotesUseOnlyTheSelectedLanguage() throws {
        let changelog = try String(contentsOf: changelogURL, encoding: .utf8)
        let portuguese = ReleaseNotes.notes(for: "0.1.0", changelog: changelog, language: .ptBR)
        let english = ReleaseNotes.notes(for: "0.1.0", changelog: changelog, language: .enUS)
        let portugueseText = portuguese.sections.flatMap { $0.bulletItems + $0.paragraphItems }.joined(separator: " ")
        let englishText = english.sections.flatMap { $0.bulletItems + $0.paragraphItems }.joined(separator: " ")

        XCTAssertTrue(portugueseText.contains("Primeira versão"))
        XCTAssertFalse(portugueseText.contains("Initial release"))
        XCTAssertTrue(englishText.contains("Initial release"))
        XCTAssertFalse(englishText.contains("Primeira versão"))
    }

    func testReleaseNotesExistInAllSupportedLanguages() throws {
        let changelog = try String(contentsOf: changelogURL, encoding: .utf8)

        for language in AppLanguage.allCases {
            let notes = ReleaseNotes.notes(for: "0.1.0", changelog: changelog, language: language)
            XCTAssertFalse(notes.sections.isEmpty, "Missing release notes for \(language.rawValue)")
        }
    }

    func testMissingReleaseNotesRemainEmpty() throws {
        let changelog = try String(contentsOf: changelogURL, encoding: .utf8)
        let notes = ReleaseNotes.notes(for: "9.9.9", changelog: changelog, language: .ptBR)

        XCTAssertTrue(notes.sections.isEmpty)
    }

    func testNewReleaseLabelsExistInAllSupportedLanguages() {
        for language in AppLanguage.allCases {
            let strings = Strings.localized(language)
            XCTAssertFalse(strings.downloadLatestRelease.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                           "Missing download label for \(language.rawValue)")
            XCTAssertFalse(strings.releaseNotesUnavailable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                           "Missing unavailable message for \(language.rawValue)")
        }
    }

    private var changelogURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("CHANGELOG.md")
    }
}
