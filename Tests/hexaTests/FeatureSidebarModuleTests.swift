// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Pins the pure sidebar module model: each member maps to its module, the
/// remembered member wins only while it is an available member of that module,
/// and features outside the modules never resolve to one.
final class FeatureSidebarModuleTests: XCTestCase {

    // MARK: Mapping

    func testEachMemberMapsToItsModule() {
        for module in SidebarModule.allCases {
            for member in module.members {
                XCTAssertEqual(SidebarModule.module(containing: member), module)
            }
        }
    }

    func testFeatureOutsideModulesHasNoModule() {
        XCTAssertNil(SidebarModule.module(containing: .mixer))
        XCTAssertNil(SidebarModule.module(containing: .mediaTools))
        XCTAssertNil(SidebarModule.module(containing: .monitorCPU))
        XCTAssertNil(SidebarModule.module(containing: .notch))
    }

    func testModuleGroups() {
        XCTAssertEqual(SidebarModule.maintenance.group, .tools)
        XCTAssertEqual(SidebarModule.processesAndPorts.group, .tools)
        XCTAssertEqual(SidebarModule.screenCapture.group, .tools)
        XCTAssertEqual(SidebarModule.energyAndDisplay.group, .energyDisplay)
    }

    func testMaintenanceMembers() {
        XCTAssertEqual(SidebarModule.maintenance.members, [.cleaner, .maintenanceTasks, .uninstaller, .appUpdates])
    }

    // MARK: Available members

    func testOneMemberOffReturnsTheOther() {
        let available = SidebarModule.processesAndPorts.availableMembers { $0 != .killProcess }
        XCTAssertEqual(available, [.portManager])
    }

    func testBothMembersOffReturnsEmpty() {
        XCTAssertTrue(SidebarModule.screenCapture.availableMembers { _ in false }.isEmpty)
    }

    func testAvailableMembersKeepOrder() {
        let available = SidebarModule.energyAndDisplay.availableMembers { _ in true }
        XCTAssertEqual(available, [.keepAwake, .brightness])
    }

    // MARK: Default member

    func testDefaultMemberUsesRememberedWhenAvailable() {
        let result = SidebarModule.screenCapture.defaultMember(remembered: .screenOCR) { _ in true }
        XCTAssertEqual(result, .screenOCR)
    }

    func testDefaultMemberFallsBackToFirstAvailableWhenRememberedUnavailable() {
        let result = SidebarModule.screenCapture.defaultMember(remembered: .screenshot) { $0 != .screenshot }
        XCTAssertEqual(result, .screenOCR)
    }

    func testDefaultMemberIsNilWhenNothingAvailable() {
        XCTAssertNil(SidebarModule.energyAndDisplay.defaultMember(remembered: .keepAwake) { _ in false })
    }

    func testDefaultMemberIgnoresRememberedFromAnotherModule() {
        let result = SidebarModule.processesAndPorts.defaultMember(remembered: .screenshot) { _ in true }
        XCTAssertEqual(result, .killProcess)
    }

    func testDefaultMemberWithoutRememberedUsesFirstAvailable() {
        let result = SidebarModule.energyAndDisplay.defaultMember(remembered: nil) { $0 != .keepAwake }
        XCTAssertEqual(result, .brightness)
    }

    func testMaintenanceAvailableMembersFilter() {
        let available = SidebarModule.maintenance.availableMembers { $0 != .uninstaller }
        XCTAssertEqual(available, [.cleaner, .maintenanceTasks, .appUpdates])
    }

    func testMaintenanceDefaultMemberWithRemembered() {
        let result = SidebarModule.maintenance.defaultMember(remembered: .appUpdates) { _ in true }
        XCTAssertEqual(result, .appUpdates)
    }
}
