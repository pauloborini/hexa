// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import AppKit
import SwiftUI
import XCTest

@testable import Hexa

/// Fixa as regras do marcador de primeira execução, do roteiro de 4 passos, do
/// fechamento da tela e das duas superfícies que a reabrem (CN1, CN5, CN6, CN7,
/// VC1, VC2, INV2, INV4, INV7, INV8).
final class OnboardingProgressTests: XCTestCase {
    private var suiteLock: DefaultsSuiteLock?
    private var suiteName = ""
    private var defaults: UserDefaults!
    private var previousLanguage: AppLanguage!

    override func setUp() {
        super.setUp()
        suiteLock = DefaultsSuiteLock("onboarding-progress")
        suiteName = "hexaTests.onboarding-progress"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        previousLanguage = L10n.shared.language
        WindowActivationPolicy.resetForTesting()
        PermissionGuideOverlay.suppressed = false
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        L10n.shared.language = previousLanguage
        WindowActivationPolicy.resetForTesting()
        PermissionGuideOverlay.suppressed = false
        suiteLock = nil
        super.tearDown()
    }

    // MARK: - AC-2.1.1

    /// A ausência da chave é "nunca começou": a tela aparece no primeiro passo.
    /// Um passo gravado retoma nele; a conclusão não abre mais a tela.
    func testFirstRunDecision() {
        XCTAssertNil(OnboardingProgress.step(in: defaults), "Sem a chave, a leitura precisa ser nil")
        XCTAssertTrue(OnboardingProgress.shouldPresent(in: defaults),
                      "Sem a chave, a primeira execução precisa apresentar a tela")
        XCTAssertEqual(OnboardingProgress.resumeStep(in: defaults), .welcome)

        for step in [OnboardingStep.welcome, .modules, .permissions] {
            OnboardingProgress.record(step, in: defaults)
            XCTAssertTrue(OnboardingProgress.shouldPresent(in: defaults),
                          "O roteiro interrompido em \(step) precisa reabrir a tela")
            XCTAssertEqual(OnboardingProgress.resumeStep(in: defaults), step)
        }

        OnboardingProgress.record(.done, in: defaults)
        XCTAssertFalse(OnboardingProgress.shouldPresent(in: defaults),
                       "Depois da conclusão a tela não abre mais")
        XCTAssertEqual(OnboardingProgress.resumeStep(in: defaults), .done)
    }

    // MARK: - AC-2.1.2

    /// A chave não é default registrado: registrada, ela devolveria `0` em vez
    /// de ausente e "nunca começou" ficaria indistinguível do primeiro passo.
    func testMarkerIsNotARegisteredDefault() {
        XCTAssertNil(Defaults.registeredDefaults[DefaultsKey.onboardingStep],
                     "O marcador não pode ser um default registrado")
        OnboardingProgress.record(.modules, in: defaults)
        XCTAssertNil(Defaults.registeredDefaults[DefaultsKey.onboardingStep],
                     "Gravar o marcador não pode registrá-lo")
    }

    // MARK: - AC-2.1.3

    /// A apresentação respeita a guarda do arranque que morreu, e a pergunta é
    /// feita dentro do bloco do próximo turno do run loop, depois da menu bar.
    func testPreviousRunGuard() throws {
        XCTAssertFalse(OnboardingProgress.shouldPresent(in: defaults, skipStartupWindows: true),
                       "Arranque anterior interrompido não pode abrir a tela")
        XCTAssertTrue(OnboardingProgress.shouldPresent(in: defaults, skipStartupWindows: false))
        OnboardingProgress.record(.done, in: defaults)
        XCTAssertFalse(OnboardingProgress.shouldPresent(in: defaults, skipStartupWindows: false))

        let source = try source("Sources/Hexa/App/AppDelegate.swift")
        let launchBlock = try XCTUnwrap(source.range(of: "DispatchQueue.main.async { [weak self] in"),
                                        "O bloco do próximo turno do run loop não existe mais")
        let guardLine = try XCTUnwrap(source.range(of: "let skipStartupWindows = startupOfPreviousRunDidNotFinish"))
        let presentation = try XCTUnwrap(
            source.range(of: "OnboardingProgress.shouldPresent(skipStartupWindows: skipStartupWindows)"),
            "O AppDelegate não pergunta ao marcador se a tela deve aparecer")
        XCTAssertGreaterThan(presentation.lowerBound, launchBlock.lowerBound,
                             "A apresentação precisa acontecer dentro do bloco do próximo turno")
        XCTAssertGreaterThan(presentation.lowerBound, guardLine.lowerBound,
                             "A apresentação precisa usar a guarda do arranque interrompido")
    }

    // MARK: - CN5 (prova do cenário)

    /// Concluir o roteiro grava o valor de conclusão, devolve o app à menu bar e
    /// a tela não volta nas execuções seguintes.
    func testCompletionStopsTheScreen() {
        OnboardingProgress.record(.done, in: defaults)
        XCTAssertEqual(defaults.integer(forKey: DefaultsKey.onboardingStep),
                       OnboardingStep.done.rawValue)
        XCTAssertFalse(OnboardingProgress.shouldPresent(in: defaults))
        XCTAssertEqual(OnboardingModel(defaults: defaults).step, .done)
        XCTAssertEqual(OnboardingProgress.resumeStep(in: defaults), .done)
    }

    // MARK: - AC-2.1.4

    /// O marcador viaja com o backup: um Mac restaurado com a conclusão não
    /// repete a tela, e um roteiro interrompido volta no ponto gravado.
    func testMarkerTravelsWithTheBackup() throws {
        XCTAssertTrue(SettingsBackupSupport.exportKeys().contains(DefaultsKey.onboardingStep),
                      "O marcador de primeira execução precisa viajar no backup")

        let completed = try XCTUnwrap(SettingsBackupSupport.sanitizedSettings(from: [
            SettingsBackupSupport.formatVersionKey: 1,
            SettingsBackupSupport.settingsKey: [DefaultsKey.onboardingStep: 3],
        ]))
        XCTAssertEqual(completed[DefaultsKey.onboardingStep] as? Int, OnboardingStep.done.rawValue)
        for (key, value) in completed { defaults.set(value, forKey: key) }
        XCTAssertFalse(OnboardingProgress.shouldPresent(in: defaults),
                       "Um backup com a conclusão não pode reabrir a tela")

        let interrupted = try XCTUnwrap(SettingsBackupSupport.sanitizedSettings(from: [
            SettingsBackupSupport.formatVersionKey: 1,
            SettingsBackupSupport.settingsKey: [DefaultsKey.onboardingStep: 2],
        ]))
        for (key, value) in interrupted { defaults.set(value, forKey: key) }
        XCTAssertEqual(OnboardingProgress.resumeStep(in: defaults), .permissions,
                       "Um backup com roteiro interrompido retoma no passo gravado")
    }

    // MARK: - AC-2.2.1

    /// Quatro passos na ordem decidida: avançar grava o novo passo no marcador,
    /// voltar move o passo sem regravar o ponto de retomada.
    func testStepMachine() {
        XCTAssertEqual(OnboardingStep.allCases, [.welcome, .modules, .permissions, .done],
                       "O roteiro tem exatamente os quatro passos, nesta ordem")

        let model = OnboardingModel(defaults: defaults)
        XCTAssertEqual(model.step, .welcome)
        XCTAssertFalse(model.isRedoing)

        model.advance()
        XCTAssertEqual(model.step, .modules)
        XCTAssertEqual(OnboardingProgress.step(in: defaults), .modules,
                       "Avançar precisa gravar o novo passo no marcador")

        model.advance()
        XCTAssertEqual(OnboardingProgress.step(in: defaults), .permissions)

        model.back()
        XCTAssertEqual(model.step, .modules)
        XCTAssertEqual(OnboardingProgress.step(in: defaults), .permissions,
                       "Voltar não regrava o ponto de retomada")

        model.advance()
        model.advance()
        XCTAssertEqual(model.step, .done)
        XCTAssertEqual(OnboardingProgress.step(in: defaults), .done)

        model.advance()
        XCTAssertEqual(model.step, .done, "O roteiro para no último passo")

        for _ in OnboardingStep.allCases { model.back() }
        XCTAssertEqual(model.step, .welcome, "O roteiro para no primeiro passo")
    }

    // MARK: - AC-2.2.3

    /// A tela resolve o texto a cada render a partir do objeto observado: não
    /// existe cópia do catálogo nem do idioma guardada na view, e a mesma view
    /// hospedada e viva troca o desenho quando o idioma do app muda.
    func testLanguageFollowsTheApp() throws {
        let source = try source("Sources/Hexa/UI/Onboarding/OnboardingView.swift")
        XCTAssertTrue(source.contains("@ObservedObject private var l10n = L10n.shared"),
                      "A tela precisa observar o idioma do app")
        XCTAssertTrue(source.contains("private var strings: Strings { l10n.s }"),
                      "O texto precisa ser resolvido no render, a partir do objeto observado")
        for captured in ["= L10n.shared.s", "Strings.localized(", "let language", "let strings"] {
            XCTAssertFalse(source.contains(captured),
                           "A tela não pode guardar o idioma nem o catálogo (\(captured))")
        }
        for key in ["strings.obStepWelcomeTitle", "strings.obStepWelcomeBody",
                    "strings.obStepDoneTitle", "strings.obStepDoneBody", "strings.obDoneHint"] {
            XCTAssertTrue(source.contains(key), "A tela não lê \(key) do catálogo observado")
        }
        XCTAssertNotEqual(Strings.localized(.enUS).obStepWelcomeTitle,
                          Strings.localized(.ptBR).obStepWelcomeTitle,
                          "O catálogo que a tela lê precisa mudar com o idioma")

        // A view que está na tela, hospedada de verdade, desenha o texto novo
        // sem ser recriada: o desenho de en-US e o de pt-BR não são iguais.
        HexaTheme.registerFonts()
        L10n.shared.language = .enUS
        let model = OnboardingModel(defaults: defaults, isRedoing: true)
        let host = NSHostingView(rootView: OnboardingView(model: model) {})
        host.frame = NSRect(origin: .zero,
                            size: NSSize(width: FeatureWorkspaceMetrics.scaffoldWidth,
                                         height: FeatureWorkspaceMetrics.height))
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let english = try XCTUnwrap(render(host), "A tela não desenhou o passo de boas-vindas")
        XCTAssertEqual(try XCTUnwrap(render(host)), english,
                       "O desenho da tela precisa ser determinístico para a comparação valer")

        L10n.shared.language = .ptBR
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let portuguese = try XCTUnwrap(render(host), "A tela não desenhou depois da troca de idioma")
        XCTAssertNotEqual(english, portuguese,
                          "A tela aberta precisa trocar o texto quando o idioma do app muda")
    }

    private func render(_ host: NSHostingView<OnboardingView>) -> Data? {
        host.layoutSubtreeIfNeeded()
        guard let representation = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
        host.cacheDisplay(in: host.bounds, to: representation)
        return representation.tiffRepresentation
    }

    // MARK: - AC-2.2.4

    /// Marcador inválido não impede a tela: fora da faixa ou de outro tipo, a
    /// leitura devolve nil e o roteiro abre no primeiro passo.
    func testInvalidMarkerFallsBackToWelcome() {
        let invalid: [Any] = [99, -1, "2", true, 1.5, [0]]
        for value in invalid {
            defaults.set(value, forKey: DefaultsKey.onboardingStep)
            XCTAssertNil(OnboardingProgress.step(in: defaults),
                         "O valor \(value) não é um passo válido")
            XCTAssertTrue(OnboardingProgress.shouldPresent(in: defaults),
                          "O valor \(value) não pode impedir a tela de abrir")
            XCTAssertEqual(OnboardingProgress.resumeStep(in: defaults), .welcome)
            XCTAssertEqual(OnboardingModel(defaults: defaults).step, .welcome)
        }
    }

    // MARK: - AC-2.2.5

    /// A tela é construída com os tokens e primitivos do design system: nenhum
    /// literal de cor, fonte, raio ou espaçamento.
    func testViewBuildsWithTheDesignSystem() throws {
        let source = try source("Sources/Hexa/UI/Onboarding/OnboardingView.swift")
        for primitive in ["HexaScreenScaffold", "HexaCard", "HexaActionButtonStyle",
                          "HairlineDivider", "BrandBadge", "HexaTheme.wordmark",
                          "HexaTheme.Spacing.", "HexaTheme.fg", ".hexa("] {
            XCTAssertTrue(source.contains(primitive), "A tela não consome \(primitive)")
        }
        let forbidden = [
            "Color(", "NSColor(", "Color(hex:", ".font(.system", "Font(",
            "spacing: 0", "spacing: 1", "spacing: 2", "spacing: 3", "spacing: 4", "spacing: 5", "spacing: 6", "spacing: 8",
            "cornerRadius: 0", "cornerRadius: 1", "cornerRadius: 2", "cornerRadius: 4", "cornerRadius: 6", "cornerRadius: 8", "cornerRadius: 10",
            "padding(.top, 0", "padding(.top, 1", "padding(.top, 2", "padding(.top, 4", "padding(.top, 8", "padding(.top, 16",
            "padding(.leading, 0", "padding(.leading, 1", "padding(.leading, 2", "padding(.leading, 4", "padding(.leading, 8",
            "lineWidth: 1", "frame(width: 1", "frame(height: 1", "frame(width: 2", "frame(height: 2",
        ]
        for literal in forbidden {
            XCTAssertFalse(source.contains(literal),
                           "A tela tem literal de design system (\(literal))")
        }
        // Todo número do código da view vem de um token, de um ícone ou da marca.
        let code = source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        let numbers = try NSRegularExpression(pattern: #"(?<![A-Za-z0-9_.])[0-9]+(?:\.[0-9]+)?"#)
            .matches(in: code, range: NSRange(code.startIndex..., in: code))
            .map { (code as NSString).substring(with: $0.range) }
        let allowed: Set<String> = ["56", "22"]
        for number in numbers {
            XCTAssertTrue(allowed.contains(number),
                          "Número solto na tela (\(number)): use um token ou uma marca")
        }
    }

    // MARK: - AC-2.3.3

    /// O fechamento devolve só o que a tela pediu: com a captura de tela ainda
    /// segurando a política, o app continua regular, e a demanda de permissão e
    /// o cartão flutuante voltam ao estado anterior. O descarte do objeto não
    /// libera nada uma segunda vez.
    func testCloseReleasesEverything() throws {
        var applied: [NSApplication.ActivationPolicy] = []
        var policy = NSApplication.ActivationPolicy.accessory
        WindowActivationPolicy.apply = { applied.append($0); policy = $0; return true }
        WindowActivationPolicy.current = { policy }

        var released: [UUID] = []
        var session: OnboardingWindowSession? = OnboardingWindowSession { released.append($0) }
        let demand = try XCTUnwrap(session?.permissionDemandID)

        // A captura de tela já mantinha a política promovida.
        WindowActivationPolicy.retain()
        XCTAssertEqual(WindowActivationPolicy.retentionCountForTesting, 1)
        XCTAssertEqual(policy, .regular)

        session?.begin()
        XCTAssertEqual(WindowActivationPolicy.retentionCountForTesting, 2)
        XCTAssertTrue(PermissionGuideOverlay.suppressed,
                      "O cartão flutuante de permissão fica suprimido enquanto a tela existe")
        XCTAssertEqual(policy, .regular)

        session?.end()
        XCTAssertFalse(PermissionGuideOverlay.suppressed,
                       "O cartão flutuante volta a ser permitido no fechamento")
        XCTAssertEqual(released, [demand], "A demanda de permissão é liberada no fechamento")
        XCTAssertEqual(WindowActivationPolicy.retentionCountForTesting, 1,
                       "O fechamento devolve só a retenção da tela")
        XCTAssertEqual(policy, .regular,
                       "A retenção da captura de tela não pode ser zerada pelo fechamento")

        session = nil
        XCTAssertEqual(WindowActivationPolicy.retentionCountForTesting, 1,
                       "O descarte da tela não pode liberar a política de novo")
        XCTAssertEqual(policy, .regular)
        XCTAssertEqual(released, [demand], "O descarte não pode liberar a demanda de novo")

        WindowActivationPolicy.release()
        XCTAssertEqual(WindowActivationPolicy.retentionCountForTesting, 0)
        XCTAssertEqual(policy, .accessory)
        XCTAssertEqual(applied, [.regular, .accessory],
                       "A política muda só nas travessias de 0 para 1 e de 1 para 0")

        // O padrão do salto é o AppKit de verdade: sem esta linha, o balanço
        // acima provaria só as closures do teste, e não o sink de produção.
        let policySource = try source("Sources/Hexa/Services/QuickTools/WindowActivationPolicy.swift")
        XCTAssertTrue(policySource.contains(
            "static var apply: (NSApplication.ActivationPolicy) -> Bool = { NSApp.setActivationPolicy($0) }"),
                      "O salto de produção precisa ser o NSApp.setActivationPolicy")
        XCTAssertTrue(policySource.contains(
            "static var current: () -> NSApplication.ActivationPolicy = { NSApp.activationPolicy() }"),
                      "A leitura de produção precisa ser a política do NSApp")
    }

    /// Nada da tela roda em fundo: nenhum timer, sondagem, notificação, laço
    /// assíncrono ou saída do app no código da tela.
    func testCloseLeavesNothingAlive() throws {
        let files = ["OnboardingWindow.swift", "OnboardingModel.swift", "OnboardingView.swift"]
        let forbidden = ["Timer(", "DispatchSourceTimer", ".asyncAfter", "DispatchQueue",
                         "Task {", "Task.detached", "NotificationCenter", "exit(",
                         "NSApp.terminate", "fatalError", "abort(", "while true"]
        for file in files {
            let source = try source("Sources/Hexa/UI/Onboarding/\(file)")
            for symbol in forbidden {
                XCTAssertFalse(source.contains(symbol),
                               "\(file) cria trabalho em fundo ou sai do app (\(symbol))")
            }
        }
    }

    // MARK: - AC-2.4.1

    /// O botão da tela Sobre abre a mesma janela e o mesmo roteiro, no primeiro
    /// passo, com o estado real de cada módulo.
    func testRedoOpensTheSameGuide() throws {
        let about = try source("Sources/Hexa/UI/Settings/AboutSettings.swift")
        XCTAssertTrue(about.contains("OnboardingWindow.shared.show(isRedoing: true)"),
                      "O botão da tela Sobre precisa abrir a janela de boas-vindas")
        XCTAssertTrue(about.contains("l10n.s.obRedoOnboarding"),
                      "O botão precisa do texto de reexecução do catálogo")

        let window = try source("Sources/Hexa/UI/Onboarding/OnboardingWindow.swift")
        XCTAssertTrue(window.contains("NSHostingView(rootView: OnboardingView(model: model)"),
                      "A reexecução abre a mesma view do primeiro uso")
        XCTAssertTrue(window.contains("OnboardingModel(isRedoing: isRedoing)"),
                      "O roteiro da reexecução é o mesmo modelo")

        let model = OnboardingModel(defaults: defaults, isRedoing: true)
        XCTAssertEqual(model.step, .welcome, "A reexecução abre no primeiro passo")
        XCTAssertTrue(model.isRedoing)
        XCTAssertEqual(OnboardingStep.allCases.count, 4)
    }

    // MARK: - AC-2.4.2

    /// A reexecução não regrava o ponto de retomada antes do passo de
    /// concluído; ao chegar lá, grava a conclusão como qualquer roteiro.
    func testRedoOnlyRecordsCompletion() {
        OnboardingProgress.record(.permissions, in: defaults)

        let model = OnboardingModel(defaults: defaults, isRedoing: true)
        XCTAssertEqual(model.step, .welcome)
        XCTAssertEqual(OnboardingProgress.step(in: defaults), .permissions,
                       "Abrir a reexecução não pode regravar o ponto de retomada")

        model.advance()
        XCTAssertEqual(model.step, .modules)
        XCTAssertEqual(OnboardingProgress.step(in: defaults), .permissions)

        model.advance()
        XCTAssertEqual(OnboardingProgress.step(in: defaults), .permissions)

        model.advance()
        XCTAssertEqual(model.step, .done)
        XCTAssertEqual(OnboardingProgress.step(in: defaults), .done,
                       "Concluir a reexecução grava a conclusão")
        XCTAssertFalse(OnboardingProgress.shouldPresent(in: defaults))
    }

    // MARK: - Leitura do repositório

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests/hexaTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // raiz do repo
    }

    private func source(_ relativePath: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
