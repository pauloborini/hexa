// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Pins the in-session tab memory of `FeatureWorkspaceState`: the selected tab of
/// each segmented page, the Dynamic Island tab, the Monitor metric and the remembered
/// module member survive a sidebar switch. Uses a fresh instance, not `shared`.
final class FeatureWorkspaceStateTabsTests: XCTestCase {

    func testDefaultsStartOnFirstTabs() {
        let state = FeatureWorkspaceState()
        XCTAssertEqual(state.menuBarTab, .menuBar)
        XCTAssertEqual(state.featureHubTab, 0)
        XCTAssertEqual(state.notchTab, .content)
        XCTAssertEqual(state.metric, .cpu)
    }

    /// The Dynamic Island page opens on Content and lists Appearance, Activity and Behavior in this order.
    func testNotchTabsStartOnContentInExperienceOrder() {
        XCTAssertEqual(NotchSettingsTab.allCases, [.content, .appearance, .activity, .behavior])
        let titles = NotchSettingsTab.allCases.map { $0.title(.ptBR) }
        XCTAssertEqual(titles, ["Conteúdo", "Aparência", "Atividade", "Comportamento"])
    }

    func testMenuBarTabSurvivesSidebarSwitch() {
        let state = FeatureWorkspaceState()
        state.menuBarTab = .commandCenter
        state.selectFeature(.mixer)
        state.selectFeature(.monitorCPU)
        XCTAssertEqual(state.menuBarTab, .commandCenter)
    }

    func testFeatureHubTabSurvivesSidebarSwitch() {
        let state = FeatureWorkspaceState()
        state.featureHubTab = 1
        state.selectFeature(.keepAwake)
        state.selectFeature(.notch)
        XCTAssertEqual(state.featureHubTab, 1)
    }

    func testNotchTabSurvivesSidebarSwitch() {
        let state = FeatureWorkspaceState()
        state.notchTab = .activity
        state.selectFeature(.mixer)
        state.selectFeature(.notch)
        XCTAssertEqual(state.notchTab, .activity)
    }

    func testMetricSurvivesSidebarSwitch() {
        let state = FeatureWorkspaceState()
        state.metric = .memory
        state.selectFeature(.mixer)
        state.selectFeature(.monitorCPU)
        XCTAssertEqual(state.metric, .memory)
    }

    func testRememberedModuleMemberSurvivesSidebarSwitch() {
        let state = FeatureWorkspaceState()
        state.selectFeature(.killProcess)
        state.selectFeature(.mixer)
        XCTAssertEqual(state.rememberedModuleMember[.processesAndPorts], .killProcess)
    }

    func testStopAndRestartNonPanelNetworkMonitoringRearmsDemand() {
        let service = ProcessUsageService.shared
        let owner = UUID()
        service.stopNetworkMonitoring(force: true)
        defer { service.stopNetworkMonitoring(owner: owner) }

        service.startNetworkMonitoring(owner: owner, menuPanel: false)
        XCTAssertTrue(service.networkMonitoringIsWarmingUp)

        service.stopNonPanelNetworkMonitoring()
        XCTAssertFalse(service.networkMonitoringIsWarmingUp)

        service.startNetworkMonitoring(owner: owner, menuPanel: false)
        XCTAssertTrue(service.networkMonitoringIsWarmingUp)

        service.stopNetworkMonitoring(owner: owner)
        XCTAssertFalse(service.networkMonitoringIsWarmingUp)
    }
}
