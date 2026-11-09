// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import CoreGraphics
import XCTest
@testable import Hexa

/// Pure rules: no status items, no Accessibility grant and no private API.
final class MenuBarHidingTests: XCTestCase {
    private func item(_ bundle: String?, x: CGFloat, width: CGFloat = 24) -> MenuBarHidingInventoryItem {
        MenuBarHidingInventoryItem(bundleIdentifier: bundle,
                                   frame: CGRect(x: x, y: 0, width: width, height: 24))
    }

    private let separator = CGRect(x: 1300, y: 0, width: 20, height: 24)

    func testItemsOnEitherSideOfTheArrowUseTheTwoSections() {
        let layout = MenuBarHidingLayoutResolver.resolve(
            inventory: [item("com.previouslyAlwaysHidden", x: 900), item("com.hidden", x: 1100),
                        item("com.visible", x: 1400)],
            separatorFrame: separator, isLeftToRight: true, excludingBundle: nil)
        XCTAssertEqual(layout.sections, ["com.previouslyAlwaysHidden": .hidden,
                                         "com.hidden": .hidden,
                                         "com.visible": .visible])
    }

    func testRightToLeftIsMirrored() {
        let rtlSeparator = CGRect(x: 300, y: 0, width: 20, height: 24)
        let layout = MenuBarHidingLayoutResolver.resolve(
            inventory: [item("com.visible", x: 200), item("com.hidden", x: 450), item("com.oldSection", x: 700)],
            separatorFrame: rtlSeparator, isLeftToRight: false, excludingBundle: nil)
        XCTAssertEqual(layout.sections, ["com.visible": .visible,
                                         "com.hidden": .hidden,
                                         "com.oldSection": .hidden])
    }

    func testTheMostVisibleItemWinsForABundle() {
        let layout = MenuBarHidingLayoutResolver.resolve(
            inventory: [item("com.split", x: 1100), item("com.split", x: 1400),
                        item("com.pair", x: 900), item("com.pair", x: 1100)],
            separatorFrame: separator, isLeftToRight: true, excludingBundle: nil)
        XCTAssertEqual(layout.sections["com.split"], .visible)
        XCTAssertEqual(layout.sections["com.pair"], .hidden)
    }

    func testOwnSystemAndUnidentifiedItemsAreSkipped() {
        let layout = MenuBarHidingLayoutResolver.resolve(
            inventory: [item("io.github.pauloborini.hexa", x: 1100), item("com.apple.MenuBarAgent", x: 1100),
                        item(nil, x: 1100), item("com.app", x: 1100)],
            separatorFrame: separator, isLeftToRight: true,
            excludingBundle: "io.github.pauloborini.hexa")
        XCTAssertEqual(layout.sections, ["com.app": .hidden])
    }

    func testBundlesAreFilteredAndSorted() {
        let layout = MenuBarHidingLayout(sections: ["b": .visible, "a": .visible, "c": .hidden])
        XCTAssertEqual(layout.bundles(in: [.visible]), ["a", "b"])
        XCTAssertEqual(layout.bundles(in: [.visible, .hidden]), ["a", "b", "c"])
    }

    func testTheRehideDelayOptionsAndDefault() {
        XCTAssertEqual(MenuBarHidingRehideDelay.defaultValue, .fiveSeconds)
        XCTAssertNil(MenuBarHidingRehideDelay.instant.seconds)
        XCTAssertEqual(MenuBarHidingRehideDelay.fiveSeconds.seconds, 5)
        XCTAssertEqual(MenuBarHidingRehideDelay.tenSeconds.seconds, 10)
    }

    func testLegacyPreferenceMigrationKeepsTheModuleEnabled() {
        let domain = "MenuBarHidingTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(true, forKey: "menuBarHidingAlwaysHidden")
        defaults.set(true, forKey: DefaultsKey.menuBarHidingEnabled)

        Defaults.migrateLegacyMenuBarHidingPreference(in: defaults)

        XCTAssertNil(defaults.object(forKey: "menuBarHidingAlwaysHidden"))
        XCTAssertTrue(defaults.bool(forKey: DefaultsKey.menuBarHidingEnabled))
    }

    // MARK: - Mechanism

    func testTheEngineFollowsTheOperatingSystem() {
        XCTAssertEqual(MenuBarHidingEngineKind.forOperatingSystem(majorVersion: 14), .separatorLength)
        XCTAssertEqual(MenuBarHidingEngineKind.forOperatingSystem(majorVersion: 26), .separatorLength)
        XCTAssertEqual(MenuBarHidingEngineKind.forOperatingSystem(majorVersion: 27), .visibilityRestriction)
    }

    func testCollapsedLengthCoversTheWidestDisplayAndStaysCapped() {
        XCTAssertEqual(MenuBarHidingSupport.collapsedLength(screenWidths: [1728, 3440]), 6880)
        XCTAssertEqual(MenuBarHidingSupport.collapsedLength(screenWidths: [800]), 1600)
        XCTAssertEqual(MenuBarHidingSupport.collapsedLength(screenWidths: [100, 200]), 500)
        XCTAssertEqual(MenuBarHidingSupport.collapsedLength(screenWidths: [10_000]), 10_000,
                       "macOS caps a status item at 10,000 points")
    }

    func testSeparatorLengthIsZeroWhenDisabled() {
        XCTAssertEqual(MenuBarHidingSupport.separatorLength(expanded: true, enabled: false,
                                                            collapsedLength: 5000), 0)
        XCTAssertEqual(MenuBarHidingSupport.separatorLength(expanded: false, enabled: false,
                                                            collapsedLength: 5000), 0)
        XCTAssertEqual(MenuBarHidingSupport.separatorLength(expanded: true, enabled: true,
                                                            collapsedLength: 5000), 20)
        XCTAssertEqual(MenuBarHidingSupport.separatorLength(expanded: false, enabled: true,
                                                            collapsedLength: 5000), 5000)
    }

    // MARK: - Allow-list

    func testAllowListHidesOnlyTheHiddenSection() {
        let layout = MenuBarHidingLayout(sections: ["com.keep": .visible, "com.hidden": .hidden])
        XCTAssertEqual(MenuBarHidingSupport.restrictionAllowList(
            layout: layout, unreadBundles: [], readAnyItem: true), ["com.keep"])
    }

    func testAllowListRefusesAReadThatSawNothing() {
        XCTAssertNil(MenuBarHidingSupport.restrictionAllowList(
            layout: MenuBarHidingLayout(sections: [:]), unreadBundles: [], readAnyItem: false))
    }

    func testAllowListKeepsUnreadAppsVisible() {
        let layout = MenuBarHidingLayout(sections: ["com.keep": .visible, "com.hidden": .hidden])
        XCTAssertEqual(MenuBarHidingSupport.restrictionAllowList(
            layout: layout, unreadBundles: ["com.slow"], readAnyItem: true), ["com.keep", "com.slow"])
    }

    func testActivationAllowListKeepsTheChevronAppVisible() {
        XCTAssertEqual(
            MenuBarHidingSupport.activationAllowList(
                bundles: ["com.keep", "com.slow"], ownBundle: "io.github.pauloborini.hexa"),
            ["com.apple.MenuBarAgent", "com.apple.controlcenter", "com.apple.systemuiserver",
             "com.keep", "com.slow", "io.github.pauloborini.hexa"])
    }

    func testVisibilityRestrictionRequiresDeveloperIDCertificate() {
        XCTAssertTrue(MenuBarHidingSupport.isDeveloperIDCertificateSubject(
            "Developer ID Application: Hexa (TL39VUL8DC)"))
        XCTAssertFalse(MenuBarHidingSupport.isDeveloperIDCertificateSubject(
            "Apple Development: Hexa (27RWXCA9XW)"))
        XCTAssertFalse(MenuBarHidingSupport.isDeveloperIDCertificateSubject(nil))
    }
}
