import XCTest
@testable import Hexa

final class PermissionGuideSupportTests: XCTestCase {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests/hexaTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repo root
    }

    func testGuideConfigByKind() {
        // AC-3.1.1: Config by kind resolves name, steps, watcher and relaunch requirements
        let lang = AppLanguage.enUS

        let axConfig = PermissionGuideConfig.config(for: .accessibility, language: lang)
        XCTAssertFalse(axConfig.permissionName.isEmpty)
        XCTAssertEqual(axConfig.watcher, .published(.accessibility))
        XCTAssertFalse(axConfig.requiresRelaunchOnGrant)

        let srConfig = PermissionGuideConfig.config(for: .screenRecording, language: lang)
        XCTAssertFalse(srConfig.permissionName.isEmpty)
        XCTAssertEqual(srConfig.watcher, .published(.screenRecording))
        XCTAssertTrue(srConfig.requiresRelaunchOnGrant)

        let fdaConfig = PermissionGuideConfig.config(for: .fullDiskAccess, language: lang)
        XCTAssertFalse(fdaConfig.permissionName.isEmpty)
        XCTAssertEqual(fdaConfig.watcher, .published(.fullDiskAccess))
        XCTAssertTrue(fdaConfig.requiresRelaunchOnGrant)

        let finderConfig = PermissionGuideConfig.config(for: .automationFinder, language: lang)
        XCTAssertFalse(finderConfig.permissionName.isEmpty)
        XCTAssertEqual(finderConfig.watcher, .activeRecheck)
        XCTAssertFalse(finderConfig.requiresRelaunchOnGrant)

        let termConfig = PermissionGuideConfig.config(for: .automationTerminal, language: lang)
        XCTAssertFalse(termConfig.permissionName.isEmpty)
        XCTAssertEqual(termConfig.watcher, .activeRecheck)
        XCTAssertFalse(termConfig.requiresRelaunchOnGrant)

        let playConfig = PermissionGuideConfig.config(for: .automationPlayback(name: "Music"), language: lang)
        XCTAssertTrue(playConfig.permissionName.contains("Music"))
        XCTAssertEqual(playConfig.watcher, .activeRecheck)
        XCTAssertFalse(playConfig.requiresRelaunchOnGrant)
    }

    func testNamesInEveryLanguage() {
        // AC-3.3.3: Every kind resolves a non-empty name and non-empty steps across all 15 languages
        let testKinds: [PermissionKind] = [
            .accessibility,
            .screenRecording,
            .fullDiskAccess,
            .automationFinder,
            .automationTerminal,
            .automationPlayback(name: nil),
            .automationPlayback(name: "TestApp")
        ]

        for lang in AppLanguage.allCases {
            for kind in testKinds {
                let config = PermissionGuideConfig.config(for: kind, language: lang)
                XCTAssertFalse(config.permissionName.trimmingCharacters(in: .whitespaces).isEmpty,
                               "Nome vazio para \(kind) no idioma \(lang.rawValue)")
                XCTAssertFalse(config.stepOpen.trimmingCharacters(in: .whitespaces).isEmpty,
                               "stepOpen vazio para \(kind) no idioma \(lang.rawValue)")
                XCTAssertFalse(config.stepToggle.trimmingCharacters(in: .whitespaces).isEmpty,
                               "stepToggle vazio para \(kind) no idioma \(lang.rawValue)")
                XCTAssertFalse(config.stepReturn.trimmingCharacters(in: .whitespaces).isEmpty,
                               "stepReturn vazio para \(kind) no idioma \(lang.rawValue)")
            }
        }
    }

    func testWatcherWithoutTimer() {
        // AC-3.1.3: Automação usa re-check por didBecomeActive; FDA e AX/SR usam publisher; nenhum timer
        let automationKinds: [PermissionKind] = [
            .automationFinder,
            .automationTerminal,
            .automationPlayback(name: nil)
        ]

        for kind in automationKinds {
            let config = PermissionGuideConfig.config(for: kind, language: .enUS)
            XCTAssertEqual(config.watcher, .activeRecheck, "Automação deve usar .activeRecheck sem timer")
        }

        let fdaConfig = PermissionGuideConfig.config(for: .fullDiskAccess, language: .enUS)
        XCTAssertEqual(fdaConfig.watcher, .published(.fullDiskAccess))
    }

    func testRequestFlowOnlyWhenUndetermined() {
        // AC-3.2.1: the portal offers the consent button only while the answer is pending
        XCTAssertTrue(AutomationConsentFlow.canAsk(Permissions.AutomationStatus.undetermined))
        for status: Permissions.AutomationStatus? in [.granted, .denied, .notDeterminable, nil] {
            XCTAssertFalse(AutomationConsentFlow.canAsk(status), "Sem botão de consent para \(String(describing: status))")
        }
        XCTAssertTrue(AutomationConsentFlow.canAsk(NotchMusicAutomation.Access.consent))
        for access: NotchMusicAutomation.Access? in [.granted, .denied, .unavailable, nil] {
            XCTAssertFalse(AutomationConsentFlow.canAsk(access), "Sem botão de consent para \(String(describing: access))")
        }
    }

    func testConsentRunsOffMainAndRefusalShowsGuide() {
        // AC-3.2.1 (concorrência) + AC-3.1.2: consent fora da main; negativa abre o cartão do alvo na main
        for target in Permissions.AutomationTarget.allCases {
            let asked = expectation(description: "consent \(target)")
            let shown = expectation(description: "guide \(target)")
            let refreshed = expectation(description: "refresh \(target)")
            AutomationConsentFlow.request(target, consent: { bundleID in
                XCTAssertFalse(Thread.isMainThread, "consentToAutomate bloqueia: nunca na main")
                XCTAssertEqual(bundleID, target.rawValue)
                asked.fulfill()
                return false
            }, showGuide: { kind in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertEqual(kind, AutomationConsentFlow.guideKind(for: target))
                shown.fulfill()
            }, completion: {
                XCTAssertTrue(Thread.isMainThread)
                refreshed.fulfill()
            })
            wait(for: [asked, refreshed, shown], timeout: 2, enforceOrder: true)
        }
        XCTAssertEqual(AutomationConsentFlow.guideKind(for: .finder), .automationFinder)
        XCTAssertEqual(AutomationConsentFlow.guideKind(for: .terminal), .automationTerminal)
    }

    func testGrantedConsentShowsNoGuide() {
        // AC-3.1.2 (lado concedido): consent concedido refresca e não abre o cartão
        let refreshed = expectation(description: "refresh")
        AutomationConsentFlow.request(.terminal, consent: { _ in true },
                                      showGuide: { kind in XCTFail("Cartão aberto com consent concedido: \(kind)") },
                                      completion: { refreshed.fulfill() })
        wait(for: [refreshed], timeout: 2)
        let settle = expectation(description: "settle")
        DispatchQueue.main.async { settle.fulfill() }
        wait(for: [settle], timeout: 1)
    }

    func testDeniedConsentShowsGuide() {
        // AC-3.1.2 (Player): só a negativa real abre o cartão; concessão ou prompt não executado, não
        XCTAssertEqual(AutomationConsentFlow.playbackGuide(consentGranted: false, appName: "Music"),
                       .automationPlayback(name: "Music"))
        XCTAssertNil(AutomationConsentFlow.playbackGuide(consentGranted: true, appName: "Music"))
        XCTAssertNil(AutomationConsentFlow.playbackGuide(consentGranted: nil, appName: "Music"))
    }

    func testFullDiskAccessRequestShowsGuide() throws {
        // AC-3.1.1 (disparo): o pedido de FDA abre o cartão de FDA antes de abrir os Ajustes
        let source = try String(contentsOf: repoRoot.appendingPathComponent("Sources/Hexa/Core/Permissions.swift"), encoding: .utf8)
        let body = try XCTUnwrap(source.components(separatedBy: "func requestFullDiskAccess() {").dropFirst().first)
            .components(separatedBy: "\n    func ").first ?? ""
        XCTAssertTrue(body.contains("PermissionGuideOverlay.shared.show(for: .fullDiskAccess)"),
                      "requestFullDiskAccess precisa disparar o cartão guia de FDA")
    }

    func testNoProactiveRequest() throws {
        // AC-3.3.1 / CN5 / INV3: nenhum pedido de permissão em init, onAppear, task, Timer ou ativação do app
        let request = try NSRegularExpression(pattern:
            #"requestAccessibility\(|requestScreenRecording\(|requestFullDiskAccess\(|requestCalendar\(|requestBluetooth\(|requestNotifications\(|consentToAutomate\(|requestAutomationAccess\(|AutomationConsentFlow\.request\(|PermissionGuideOverlay\.shared\.show\("#)
        let enclosing = try NSRegularExpression(pattern: #"\bfunc\s+\w+|\binit\(|\bvar \w+: some View"#)
        let proactive = try NSRegularExpression(pattern: #"\.onAppear|\.task\s*\{|\bTimer\b|didBecomeActiveNotification|\binit\("#)
        func matches(_ regex: NSRegularExpression, _ line: String) -> Bool {
            regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil
        }

        let sources = repoRoot.appendingPathComponent("Sources/Hexa")
        let files = try XCTUnwrap(FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil))
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        var callSites = 0
        for file in files {
            let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n")
            for (index, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//"), matches(request, line),
                      !line.contains("func requestAutomationAccess"), !line.contains("static func request(") else { continue }
                callSites += 1
                var start = index
                while start > 0, !matches(enclosing, lines[start]) { start -= 1 }
                let context = lines[start...index].filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                let offender = context.first { matches(proactive, $0) }
                XCTAssertNil(offender, "Pedido proativo em \(file.lastPathComponent):\(index + 1): \(offender ?? "")")
            }
        }
        XCTAssertGreaterThan(callSites, 20, "A varredura precisa encontrar os call sites reais")
    }

    func testNoExitPath() throws {
        // AC-3.3.2: Nenhum caminho no boundary de permissão contém NSApp.terminate, exit( ou fatalError(
        let boundaryFiles = [
            "Sources/Hexa/Core/Permissions.swift",
            "Sources/Hexa/UI/PermissionGuideOverlay.swift",
            "Sources/Hexa/UI/Settings/FeatureHubSettings.swift",
            "Sources/Hexa/UI/Settings/AboutSettings.swift",
            "Sources/Hexa/Services/Notch/NotchMusicService.swift",
            "Sources/Hexa/Services/ShellSupport.swift"
        ]

        let forbiddenPatterns = [
            "NSApp.terminate",
            "exit(",
            "fatalError("
        ]

        for relPath in boundaryFiles {
            let fileURL = repoRoot.appendingPathComponent(relPath)
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            for pattern in forbiddenPatterns {
                XCTAssertFalse(content.contains(pattern),
                               "Padrão proibido [\(pattern)] encontrado em \(relPath)")
            }
        }
    }
}
