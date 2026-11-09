// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Eligibility uses pure parsing and comparison on in-memory feed fixtures,
/// so the suite never touches the network or the real bundle scanner.
final class AppUpdateFeedVersionTests: XCTestCase {
    private static func feedReleases(_ itemFields: String) -> [AppUpdateFeedSupport.Release] {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
          <channel>
            <item>
        \(itemFields)
              <enclosure url="https://downloads.example.com/Hexa.zip" type="application/octet-stream"/>
            </item>
          </channel>
        </rss>
        """
        return AppUpdateFeedSupport.releases(data: Data(xml.utf8), format: .appcast) ?? []
    }

    private static func installed(version: String, build: String = "") -> AppUpdatesSupport.InstalledApp {
        AppUpdatesSupport.InstalledApp(name: "Hexa", bundleID: "com.example.hexa", path: "/Applications/Hexa.app",
                                       version: version, isFromAppStore: false, buildVersion: build)
    }

    private static func update(_ app: AppUpdatesSupport.InstalledApp,
                               _ releases: [AppUpdateFeedSupport.Release]) -> AppUpdatesSupport.Item? {
        AppUpdateFeedSupport.update(app: app, releases: releases, format: .appcast,
                                    operatingSystemVersion: "14.5", kernelVersion: "23.5.0", architecture: "arm64")
    }

    func testFeedBuildDoesNotBeatInstalledMarketingVersionWithoutDistinctBuild() {
        let releases = Self.feedReleases("""
              <sparkle:version>1820</sparkle:version>
              <sparkle:shortVersionString>1.0.0</sparkle:shortVersionString>
        """)
        XCTAssertNil(Self.update(Self.installed(version: "1.0.0"), releases))
        XCTAssertNil(Self.update(Self.installed(version: "1.0.0", build: "1.0.0"), releases))
    }

    func testMarketingVersionUpdateIsEligibleWithoutDistinctBuild() {
        let releases = Self.feedReleases("""
              <sparkle:version>1821</sparkle:version>
              <sparkle:shortVersionString>1.0.1</sparkle:shortVersionString>
        """)
        let item = Self.update(Self.installed(version: "1.0.0"), releases)
        XCTAssertEqual(item?.installedVersion, "1.0.0")
        XCTAssertEqual(item?.latestVersion, "1.0.1")
    }

    func testMinimumInstalledVersionIsComparedWithMarketingVersionWithoutDistinctBuild() {
        let blocked = Self.feedReleases("""
              <sparkle:version>1821</sparkle:version>
              <sparkle:shortVersionString>1.0.1</sparkle:shortVersionString>
              <sparkle:minimumUpdateVersion>1.0.5</sparkle:minimumUpdateVersion>
        """)
        XCTAssertNil(Self.update(Self.installed(version: "1.0.0"), blocked))

        let allowed = Self.feedReleases("""
              <sparkle:version>1821</sparkle:version>
              <sparkle:shortVersionString>1.0.1</sparkle:shortVersionString>
              <sparkle:minimumUpdateVersion>1.0.0</sparkle:minimumUpdateVersion>
        """)
        XCTAssertNotNil(Self.update(Self.installed(version: "1.0.0"), allowed))
    }

    func testEntryWithoutMarketingVersionIsDiscardedWithoutDistinctBuild() {
        let releases = Self.feedReleases("""
              <sparkle:version>1821</sparkle:version>
        """)
        XCTAssertEqual(releases.first?.displayVersion, "")
        XCTAssertNil(Self.update(Self.installed(version: "1.0.0"), releases))
    }

    func testEntryWithoutMarketingVersionIsDiscardedWithDistinctBuild() {
        let releases = Self.feedReleases("""
              <sparkle:version>1821</sparkle:version>
        """)
        XCTAssertEqual(releases.first?.displayVersion, "")
        XCTAssertNil(Self.update(Self.installed(version: "1.0.0", build: "1819"), releases))
    }

    func testBuildComparisonStillEligibleWithDistinctBuild() {
        let releases = Self.feedReleases("""
              <sparkle:version>1820</sparkle:version>
              <sparkle:shortVersionString>1.0.0</sparkle:shortVersionString>
        """)
        let item = Self.update(Self.installed(version: "1.0.0", build: "1819"), releases)
        XCTAssertEqual(item?.installedVersion, "1.0.0 (1819)")
        XCTAssertEqual(item?.latestVersion, "1.0.0 (1820)")
    }

    func testBuildComparisonNotEligibleWithDistinctBuild() {
        let releases = Self.feedReleases("""
              <sparkle:version>1820</sparkle:version>
              <sparkle:shortVersionString>1.0.0</sparkle:shortVersionString>
        """)
        XCTAssertNil(Self.update(Self.installed(version: "1.0.0", build: "1820"), releases))
    }

    func testComparePartHandlesNumberedPrereleaseSuffixesAntisymmetrically() {
        XCTAssertEqual(AppUpdatesSupport.compare("1.0beta10", "1.0beta9"), .orderedDescending)
        XCTAssertEqual(AppUpdatesSupport.compare("1.0beta9", "1.0beta10"), .orderedAscending)
        XCTAssertTrue(AppUpdatesSupport.isNewer("1.0beta10", than: "1.0beta9"))
        XCTAssertFalse(AppUpdatesSupport.isNewer("1.0beta9", than: "1.0beta10"))
        XCTAssertTrue(AppUpdatesSupport.isNewer("1.0-beta10", than: "1.0-beta9"))
        XCTAssertEqual(AppUpdatesSupport.compare("1.0Beta10", "1.0beta10"), .orderedSame)
        XCTAssertFalse(AppUpdatesSupport.isNewer("1.0Beta10", than: "1.0beta10"))
    }
}
