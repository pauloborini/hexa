// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Pins the sidebar search routing: each query maps to the sidebar row it shows and to the
/// internal tab, tool, metric or section that row opens. Uses fresh `FeatureWorkspaceState`
/// instances, not `shared`, and restores the Media tool preference it touches.
final class FeatureSidebarSearchRoutingTests: XCTestCase {
    private let language = AppLanguage.ptBR
    private let monitorKinds: [MetricDetailKind] = [.cpu, .gpu, .memory, .network, .disk, .power]
    private var savedMediaTool: String?

    override func setUp() {
        super.setUp()
        savedMediaTool = UserDefaults.standard.string(forKey: DefaultsKey.mediaLastTool)
    }

    override func tearDown() {
        if let savedMediaTool {
            UserDefaults.standard.set(savedMediaTool, forKey: DefaultsKey.mediaLastTool)
        } else {
            UserDefaults.standard.removeObject(forKey: DefaultsKey.mediaLastTool)
        }
        super.tearDown()
    }

    private func routes(_ query: String) -> [SidebarSearchRoute] {
        SidebarSearchRoute.routes(for: query, language: language, monitorKinds: monitorKinds,
                                  isAvailable: { _ in true })
    }

    func testEmptyQueryRoutesNothing() {
        XCTAssertTrue(routes("").isEmpty)
    }

    func testPermissionsSearchOpensPermissionsTab() {
        let route = routes("Permissões").first { $0.system == .featureHub }
        XCTAssertEqual(route?.featureHubTab, 1)
        let state = FeatureWorkspaceState()
        state.applySidebarSearchTabs(route)
        XCTAssertEqual(state.featureHubTab, 1)
    }

    func testPermissionNameSearchOpensPermissionsTab() {
        let route = routes("Gravação de tela").first { $0.system == .featureHub }
        XCTAssertEqual(route?.featureHubTab, 1)
    }

    func testCommandCenterSearchOpensCommandCenterTab() {
        let route = routes("Central de comando").first { $0.system == .menuBar }
        XCTAssertEqual(route?.menuBarTab, .commandCenter)
        let state = FeatureWorkspaceState()
        state.applySidebarSearchTabs(route)
        XCTAssertEqual(state.menuBarTab, .commandCenter)
    }

    /// The label "Conversor de GIF" has no string in the catalog; the existing segment label "GIF" is the query.
    func testGIFSearchOpensGIFTool() {
        let route = routes("GIF").first { $0.feature == .mediaTools }
        XCTAssertEqual(route?.mediaTool, .gifMaker)
        let state = FeatureWorkspaceState()
        state.applySidebarSearchTabs(route)
        XCTAssertEqual(state.mediaTool, .gifMaker)
    }

    func testTimerSearchOpensContentSectionWithTimer() {
        let route = routes("Temporizador").first { $0.feature == .notch }
        XCTAssertEqual(route?.notchTab, .content)
        XCTAssertEqual(route?.notchContentSection, .timer)
        let state = FeatureWorkspaceState()
        state.applySidebarSearchTabs(route)
        XCTAssertEqual(state.notchTab, .content)
        XCTAssertEqual(state.notchContentSection, .timer)
    }

    /// The pt-BR title of the Watch module is "Observar" (`NotchWatchStrings`), not "Vigia".
    func testWatchSearchOpensContentSectionWithWatch() {
        let route = routes("Observar").first { $0.feature == .notch }
        XCTAssertEqual(route?.notchTab, .content)
        XCTAssertEqual(route?.notchContentSection, .watch)
    }

    /// Every section of the island opens on the Content tab, where its options are, as the Timer does.
    func testEverySectionSearchOpensContent() {
        for module in NotchModule.allCases where module != .tools {
            let route = routes(module.title(language)).first { $0.feature == .notch && $0.notchContentSection == module }
            XCTAssertEqual(route?.notchTab, .content, "\(module)")
        }
    }

    func testGPUSearchRoutesToGPUMetric() {
        let route = routes("GPU").first { $0.feature == .monitorGPU }
        XCTAssertEqual(route?.metric, .gpu)
    }

    /// Buscar GPU estando nos Ajustes do Monitor sai dos Ajustes e abre a métrica GPU.
    func testGPUSearchLeavesMonitorSettings() {
        let state = FeatureWorkspaceState()
        state.selectFeature(.monitorCPU)
        state.monitorTabIsSettings = true
        let route = routes("GPU").first { $0.feature == .monitorGPU }
        state.openSidebarFeature(.monitorCPU, route: route, monitorKind: .cpu, keepsMonitorSettings: true)
        XCTAssertFalse(state.monitorTabIsSettings)
        XCTAssertEqual(state.metric, .gpu)
        XCTAssertEqual(state.feature, .monitorGPU)
    }

    /// Sem busca, clicar no Monitor já aberto mantém os Ajustes.
    func testMonitorRowWithoutSearchKeepsMonitorSettings() {
        let state = FeatureWorkspaceState()
        state.selectFeature(.monitorCPU)
        state.monitorTabIsSettings = true
        state.openSidebarFeature(.monitorCPU, route: nil, monitorKind: .cpu, keepsMonitorSettings: true)
        XCTAssertTrue(state.monitorTabIsSettings)
        XCTAssertEqual(state.metric, .cpu)
    }

    func testSearchWithoutRouteKeepsRememberedTabs() {
        let state = FeatureWorkspaceState()
        state.featureHubTab = 1
        state.applySidebarSearchTabs(nil)
        XCTAssertEqual(state.featureHubTab, 1)
    }

    /// "Conversor de GIF" é nome longo só do índice da busca; abre a mesma ferramenta GIF.
    func testGIFConverterAliasOpensGIFTool() {
        let route = routes("Conversor de GIF").first { $0.feature == .mediaTools }
        XCTAssertEqual(route?.mediaTool, .gifMaker)
        let state = FeatureWorkspaceState()
        state.applySidebarSearchTabs(route)
        XCTAssertEqual(state.mediaTool, .gifMaker)
    }

    func testVideoCompressorAliasOpensVideoTool() {
        let route = routes("Compressor de vídeo").first { $0.feature == .mediaTools }
        XCTAssertEqual(route?.mediaTool, .videoCompressor)
    }

    func testImageCompressorAliasOpensImageTool() {
        let route = routes("Compressor de imagem").first { $0.feature == .mediaTools }
        XCTAssertEqual(route?.mediaTool, .imageCompressor)
    }

    func testTextExtractorAliasOpensTextTool() {
        let route = routes("Extrator de texto").first { $0.feature == .mediaTools }
        XCTAssertEqual(route?.mediaTool, .textExtractor)
    }

    /// "Catálogo" é a primeira aba de Recursos (antes "Módulos"); a busca devolve a aba 0.
    func testCatalogSearchOpensCatalogTab() {
        let route = routes("Catálogo").first { $0.system == .featureHub }
        XCTAssertEqual(route?.featureHubTab, 0)
        let state = FeatureWorkspaceState()
        state.featureHubTab = 1
        state.applySidebarSearchTabs(route)
        XCTAssertEqual(state.featureHubTab, 0)
    }

    func testGeneralSearchOpensGeneralSystemPage() {
        XCTAssertTrue(routes("Geral").contains { $0.system == .general })
    }

    func testShortcutsSearchOpensShortcutsSystemPage() {
        let title = Strings.localized(language).shortcutsPageTitle
        XCTAssertTrue(routes("Atalhos").contains { $0.system == .shortcuts })
        XCTAssertTrue(routes(title).contains { $0.system == .shortcuts })
    }

    func testPermissionSearchOpensPermissionsTab() {
        let route = routes("Bluetooth").first { $0.system == .featureHub }
        XCTAssertEqual(route?.featureHubTab, 1)
    }

    /// ISSUE-681: câmera e microfone saíram das permissões; a busca não leva mais à aba.
    func testCameraAndMicrophoneSearchDoNotOpenPermissionsTab() {
        XCTAssertFalse(routes("Câmera").contains { $0.system == .featureHub && $0.featureHubTab == 1 })
        XCTAssertFalse(routes("Microfone").contains { $0.system == .featureHub && $0.featureHubTab == 1 })
    }
}
