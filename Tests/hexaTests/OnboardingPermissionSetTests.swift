// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import EventKit
import XCTest

@testable import Hexa

/// Fixa o passo de permissões da primeira execução: a lista é a união real das
/// permissões dos módulos instalados (VC4, CN3), o pedido do macOS sai só do
/// gesto do usuário (INV5) e a recusa não tira a tela nem a ação da linha
/// (CN4, INV6). A regra antiga de permissões do onboarding sai do catálogo
/// (LEG2).
final class OnboardingPermissionSetTests: XCTestCase {
    private var suiteLock: DefaultsSuiteLock?
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteLock = DefaultsSuiteLock("onboarding-permissions")
        suiteName = "hexaTests.onboarding-permissions"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        WindowActivationPolicy.resetForTesting()
        PermissionGuideOverlay.suppressed = false
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        WindowActivationPolicy.resetForTesting()
        PermissionGuideOverlay.suppressed = false
        suiteLock = nil
        super.tearDown()
    }

    // MARK: - AC-4.1.1

    /// Com o Cleaner e o Desinstalador instalados, a lista exigida traz Acesso
    /// Total ao Disco e as duas Automações; com eles desinstalados, a lista
    /// perde as três. A regra antiga devolvia lista vazia para os dois.
    func testRequiredPermissions() {
        let installed: [AppFeature] = [.cleaner, .uninstaller]
        let required = OnboardingPermissionSet.required(for: installed)

        XCTAssertEqual(required,
                       [.fullDiskAccess, .filesAndFolders, .notifications, .automationFinder, .automationTerminal],
                       "A lista precisa ser a união real das permissões dos dois módulos")
        for permission in [AppPermission.fullDiskAccess, .automationFinder, .automationTerminal] {
            XCTAssertTrue(required.contains(permission),
                          "\(permission.rawValue) é exigida por um módulo instalado e sumiu da lista")
        }
        XCTAssertFalse(required.contains(.accessibility),
                       "Nenhum dos dois módulos pede Acessibilidade")
        XCTAssertFalse(required.contains(.screenRecording),
                       "Nenhum dos dois módulos pede Gravação de Tela")

        let withoutThem = OnboardingPermissionSet.required(for: [.mediaTools, .monitorCPU])
        XCTAssertTrue(withoutThem.isEmpty, "Desinstalar os dois módulos esvazia a lista")
        for permission in [AppPermission.fullDiskAccess, .automationFinder, .automationTerminal] {
            XCTAssertFalse(withoutThem.contains(permission),
                           "\(permission.rawValue) sobreviveu à desinstalação do módulo que a exigia")
        }
    }

    // MARK: - AC-4.2.6

    /// Sem nenhum módulo instalado exigindo permissão, a lista é vazia: o passo
    /// mostra o texto do estado vazio em vez de uma seção sem linhas.
    func testRequiredIsEmptyWithoutModules() {
        XCTAssertTrue(OnboardingPermissionSet.required(for: []).isEmpty)
        XCTAssertTrue(OnboardingPermissionSet.required(for: [.killProcess, .portManager]).isEmpty,
                      "Kill Process e Port Manager não exigem permissão nenhuma")
    }

    // MARK: - AC-4.1.2

    /// A lista não repete permissão, vem na ordem do catálogo do Portal e traz
    /// só permissões que algum recurso instalado exige.
    func testListHasNoDuplicatesAndKeepsCatalogOrder() {
        let required = OnboardingPermissionSet.required(for: AppFeature.allCases)

        XCTAssertEqual(required, AppPermission.allCases,
                       "Com todos os recursos instalados a lista é o catálogo inteiro, na ordem dele")
        XCTAssertEqual(Set(required).count, required.count, "A lista não pode repetir permissão")
        for permission in required {
            XCTAssertTrue(AppFeature.allCases.contains { $0.permissions.contains(permission) },
                          "\(permission.rawValue) não é exigida por nenhum recurso do catálogo")
        }
    }

    // MARK: - AC-4.1.3

    /// O mapeamento extraído devolve o mesmo estado que o Portal devolvia: o
    /// que o macOS não expõe continua não verificável, e não pendente.
    func testStatusMappingIsUnchanged() {
        XCTAssertEqual(PermissionPortalRow.status(for: .accessibility, readers: readers(accessibility: true)),
                       .granted)
        XCTAssertEqual(PermissionPortalRow.status(for: .accessibility, readers: readers(accessibility: false)),
                       .missing)
        XCTAssertEqual(PermissionPortalRow.status(for: .screenRecording, readers: readers(screenRecording: true)),
                       .granted)
        XCTAssertEqual(PermissionPortalRow.status(for: .fullDiskAccess, readers: readers(fullDiskAccess: true)),
                       .granted)

        XCTAssertEqual(PermissionPortalRow.status(for: .filesAndFolders, readers: readers()), .unknown)
        XCTAssertEqual(PermissionPortalRow.status(for: .appManagement, readers: readers()), .unknown)

        XCTAssertEqual(PermissionPortalRow.status(for: .notifications, readers: readers(notifications: .granted)),
                       .granted)
        XCTAssertEqual(PermissionPortalRow.status(for: .notifications, readers: readers(notifications: .denied)),
                       .missing)
        XCTAssertEqual(PermissionPortalRow.status(for: .notifications, readers: readers(notifications: .undetermined)),
                       .missing)
        XCTAssertEqual(PermissionPortalRow.status(for: .notifications, readers: readers(notifications: .unknown)),
                       .unknown)

        XCTAssertEqual(PermissionPortalRow.status(for: .automationFinder, readers: readers(finder: .granted)),
                       .granted)
        XCTAssertEqual(PermissionPortalRow.status(for: .automationFinder, readers: readers(finder: .denied)),
                       .missing)
        XCTAssertEqual(PermissionPortalRow.status(for: .automationFinder, readers: readers(finder: .undetermined)),
                       .missing)
        XCTAssertEqual(PermissionPortalRow.status(for: .automationFinder, readers: readers(finder: .notDeterminable)),
                       .unknown)
        XCTAssertEqual(PermissionPortalRow.status(for: .automationFinder, readers: readers(finder: nil)), .unknown)
        XCTAssertEqual(PermissionPortalRow.status(for: .automationTerminal, readers: readers(terminal: .denied)),
                       .missing)

        XCTAssertEqual(PermissionPortalRow.status(for: .automationPlayback, readers: readers(playback: .granted)),
                       .granted)
        XCTAssertEqual(PermissionPortalRow.status(for: .automationPlayback, readers: readers(playback: .denied)),
                       .missing)
        XCTAssertEqual(PermissionPortalRow.status(for: .automationPlayback, readers: readers(playback: .unavailable)),
                       .unknown)
        XCTAssertEqual(PermissionPortalRow.status(for: .automationPlayback, readers: readers(playback: nil)),
                       .unknown)

        XCTAssertEqual(PermissionPortalRow.status(for: .audioCapture, readers: readers(audioCapture: true)),
                       .missing)
        XCTAssertEqual(PermissionPortalRow.status(for: .audioCapture, readers: readers(audioCapture: false)),
                       .unknown)

        XCTAssertEqual(PermissionPortalRow.status(for: .calendar, readers: readers(calendar: .fullAccess)), .granted)
        XCTAssertEqual(PermissionPortalRow.status(for: .calendar, readers: readers(calendar: .denied)), .missing)
        XCTAssertEqual(PermissionPortalRow.status(for: .bluetooth, readers: readers(bluetooth: .granted)), .granted)
        XCTAssertEqual(PermissionPortalRow.status(for: .bluetooth, readers: readers(bluetooth: .unknown)), .unknown)
    }

    /// A explicação compartilhada não atribui ao hexa o gerenciamento de
    /// janelas que saiu do produto e cita os usos atuais da permissão.
    func testAccessibilityExplanationNamesLiveCapabilities() {
        let expected: [AppLanguage: String] = [
            .ko: "Hexa가 전역 단축키를 사용하고 앱별 음량, 화면 밝기, 키보드 조명을 제어할 수 있게 합니다.",
            .enUS: "Allows Hexa to use global shortcuts and control per-app volume, screen brightness, and keyboard lighting.",
            .ptBR: "Permite que o Hexa use atalhos globais e controle o volume por aplicativo, o brilho da tela e a luz do teclado.",
            .tr: "Hexa'nın genel kısayolları kullanmasını; uygulama başına ses düzeyini, ekran parlaklığını ve klavye ışığını kontrol etmesini sağlar.",
            .ru: "Позволяет Hexa использовать глобальные сочетания клавиш и управлять громкостью приложений, яркостью экрана и подсветкой клавиатуры.",
            .es: "Permite que Hexa use atajos globales y controle el volumen de cada app, el brillo de la pantalla y la iluminación del teclado.",
            .sk: "Umožňuje aplikácii Hexa používať globálne skratky a ovládať hlasitosť aplikácií, jas obrazovky a podsvietenie klávesnice.",
            .de: "Ermöglicht Hexa globale Kurzbefehle sowie die Steuerung der Lautstärke pro App, der Bildschirmhelligkeit und der Tastaturbeleuchtung.",
            .fr: "Permet à Hexa d’utiliser des raccourcis globaux et de contrôler le volume par app, la luminosité de l’écran et le rétroéclairage du clavier.",
            .it: "Permette a Hexa di usare scorciatoie globali e controllare il volume per app, la luminosità dello schermo e la retroilluminazione della tastiera.",
            .ja: "Hexaがグローバルショートカットを使い、アプリごとの音量、画面の明るさ、キーボードのバックライトを制御できるようにします。",
            .zhHans: "允许 Hexa 使用全局快捷键，并控制各个应用的音量、屏幕亮度和键盘背光。",
            .zhHK: "允許 Hexa 使用全域快速鍵，並控制各個 App 的音量、螢幕亮度和鍵盤背光。",
            .zhTW: "允許 Hexa 使用全域快速鍵，並控制各個應用程式的音量、螢幕亮度和鍵盤背光。",
            .uk: "Дозволяє Hexa використовувати глобальні сполучення клавіш і керувати гучністю програм, яскравістю екрана та підсвічуванням клавіатури."
        ]

        XCTAssertEqual(Set(expected.keys), Set(AppLanguage.allCases))
        for language in AppLanguage.allCases {
            XCTAssertEqual(FeatureStrings.hub(language).explainAccessibility, expected[language],
                           "A explicação de Acessibilidade divergiu em \(language.rawValue)")
        }
    }

    /// O Portal consome o mapeamento extraído e a decisão do botão de conceder:
    /// sem essas chamadas a extração seria código morto e a prova acima não
    /// diria nada sobre a tela.
    func testPortalDelegatesToTheExtractedMapping() throws {
        let source = try source("Sources/Hexa/UI/Settings/FeatureHubSettings.swift")
        XCTAssertTrue(source.contains("PermissionPortalRow.status(for: permission, readers: readers)"),
                      "O Portal precisa ler o estado pelo mapeamento extraído")
        XCTAssertTrue(source.contains("OnboardingPermissionSet.showsGrantAction(for: status, canAskAgain: canAskAgain)"),
                      "O botão de conceder da linha precisa da decisão única")
    }

    // MARK: - AC-4.1.4

    /// A regra antiga não existe mais no código, e nenhuma referência sobrou.
    func testLegacyRuleIsGone() throws {
        let thisFile = URL(fileURLWithPath: #filePath).lastPathComponent
        for url in try swiftFiles() where url.lastPathComponent != thisFile {
            let text = try String(contentsOf: url, encoding: .utf8)
            XCTAssertFalse(text.contains(Self.legacyRule),
                           "A regra antiga sobreviveu em \(url.path)")
        }
    }

    // MARK: - AC-4.2.1

    /// A lista exigida é recalculada a partir do que está instalado agora: não
    /// há memória entre visitas, e desinstalar o Cleaner tira as permissões que
    /// só ele exigia.
    func testListIsRecomputedOnEntry() throws {
        let withCleaner = OnboardingPermissionSet.required(for: [.cleaner, .mediaTools])
        let withoutCleaner = OnboardingPermissionSet.required(for: [.mediaTools])

        XCTAssertTrue(withCleaner.contains(.fullDiskAccess))
        XCTAssertFalse(withoutCleaner.contains(.fullDiskAccess),
                       "A lista guardou as permissões do Cleaner depois de ele sair")
        XCTAssertEqual(OnboardingPermissionSet.required(for: [.cleaner, .mediaTools]), withCleaner,
                       "A segunda chamada não pode vir de uma cópia antiga")
        XCTAssertEqual(OnboardingPermissionSet.required(for: [.mediaTools]), withoutCleaner)

        let view = try source("Sources/Hexa/UI/Onboarding/OnboardingView.swift")
        XCTAssertTrue(view.contains("OnboardingPermissionSet.required(for: installedFeatures)"),
                      "O passo precisa calcular a lista no render, a partir do que está instalado")
        XCTAssertFalse(view.contains("@State private var required"),
                       "A lista não pode ser memorizada em estado da view")
    }

    // MARK: - AC-4.2.1 (quem usa)

    /// A lista de "quem usa" do passo são os grupos de módulo instalados que
    /// exigem a permissão, na ordem do catálogo: um grupo desinstalado não
    /// aparece, e um grupo instalado que não pede a permissão também não.
    func testWhoUsesNamesTheInstalledModules() {
        let installed: [AppFeature] = [.cleaner, .uninstaller, .mediaTools]

        XCTAssertEqual(OnboardingPermissionSet.modulesRequiring(.fullDiskAccess, in: installed),
                       [.uninstaller, .cleanerAndMaintenance],
                       "A permissão do Cleaner e do Desinstalador aponta os dois grupos, na ordem do catálogo")
        XCTAssertEqual(OnboardingPermissionSet.modulesRequiring(.automationTerminal, in: installed),
                       [.uninstaller],
                       "Só o Desinstalador pede Automação do Terminal")
        XCTAssertEqual(OnboardingPermissionSet.modulesRequiring(.accessibility, in: installed), [],
                       "Nenhum dos grupos instalados pede Acessibilidade")

        let withoutCleaner: [AppFeature] = [.uninstaller, .mediaTools]
        XCTAssertEqual(OnboardingPermissionSet.modulesRequiring(.fullDiskAccess, in: withoutCleaner),
                       [.uninstaller],
                       "O grupo desinstalado sai da lista de quem usa")
        XCTAssertEqual(OnboardingPermissionSet.modulesRequiring(.automationFinder, in: withoutCleaner),
                       [.uninstaller])
        XCTAssertEqual(OnboardingPermissionSet.modulesRequiring(.notifications, in: withoutCleaner), [],
                       "A notificação era só do Cleaner")
    }

    /// O nome, a explicação e "quem usa" vêm antes do botão de conceder (INV5):
    /// o pedido do macOS chega ao usuário sabendo o que vai acontecer.
    func testRowExplainsBeforeAction() throws {
        let row = try rowSource()
        let name = try XCTUnwrap(row.range(of: "Text(permission.name(hub))"))
        let explainer = try XCTUnwrap(row.range(of: "Text(permission.explainer(hub))"))
        let usedBy = try XCTUnwrap(row.range(of: "Text(usedByLine)"))
        let grant = try XCTUnwrap(row.range(of: "title: hub.requestButton"))

        XCTAssertLessThan(name.lowerBound, explainer.lowerBound,
                          "O nome da permissão vem antes da explicação")
        XCTAssertLessThan(explainer.lowerBound, usedBy.lowerBound,
                          "A explicação vem antes da lista de quem usa")
        XCTAssertLessThan(usedBy.lowerBound, grant.lowerBound,
                          "A linha explica a permissão e quem a usa antes do botão de conceder")

        XCTAssertTrue(row.contains("usedByNames ?? activeFeatures"),
                      "A linha precisa aceitar a lista de quem usa injetada pelo passo")
    }

    // MARK: - AC-4.2.2

    /// O pedido do macOS sai do botão de conceder da linha e de mais lugar
    /// nenhum: abrir, chegar ou reentrar no passo não dispara pedido.
    func testNoProactiveRequest() throws {
        let view = try source("Sources/Hexa/UI/Onboarding/OnboardingView.swift")
        for forbidden in ["requestAccessibility", "requestScreenRecording", "requestFullDiskAccess",
                          "requestAutomationAccess", "AutomationConsentFlow.request", "Permissions.shared.request",
                          "requestNotifications", "requestCalendar", "requestBluetooth"] {
            XCTAssertFalse(view.contains(forbidden),
                           "O passo de permissões não pode disparar pedido por conta própria (\(forbidden))")
        }
        XCTAssertTrue(view.contains("permissions.refresh()"),
                      "Ao aparecer, o passo só lê o estado")

        let model = try source("Sources/Hexa/UI/Onboarding/OnboardingModel.swift")
        XCTAssertFalse(model.contains("request"),
                       "O roteiro não dispara pedido nenhum ao mudar de passo")

        let row = collapsed(try rowSource())
        XCTAssertTrue(row.contains("title:hub.requestButton){request()}"),
                      "O pedido precisa estar dentro do gesto do botão de conceder")
    }

    // MARK: - AC-4.2.3

    /// A recusa deixa a linha pendente e acionável: o botão de conceder aparece
    /// enquanto o macOS ainda aceita pedido, o de Ajustes fica em toda linha e
    /// o roteiro segue para o passo de concluído.
    func testRefusalLeavesTheStepOpen() throws {
        XCTAssertTrue(OnboardingPermissionSet.showsGrantAction(for: .missing, canAskAgain: true),
                      "Depois de uma recusa o macOS ainda permite pedir de novo na maioria das linhas")
        XCTAssertTrue(OnboardingPermissionSet.showsGrantAction(for: .unknown, canAskAgain: true))
        XCTAssertFalse(OnboardingPermissionSet.showsGrantAction(for: .granted, canAskAgain: true),
                       "Permissão concedida não pede de novo")
        XCTAssertFalse(OnboardingPermissionSet.showsGrantAction(for: .missing, canAskAgain: false),
                       "Sem pedido possível, a linha fica só com os Ajustes")

        // O botão de abrir os Ajustes é irmão do bloco condicional, nunca filho:
        // aparece em toda linha (D14). Só a linha aninhada no grupo de Automação
        // o omite, porque o grupo leva o botão comum aos destinos.
        let row = collapsed(try rowSource())
        XCTAssertTrue(row.contains("}}if!nested{HexaAccessButton(icon:\"gearshape\",title:hub.openSystemSettings)"),
                      "O botão de Ajustes precisa ficar fora do bloco do conceder")

        // A recusa não trava o roteiro: o passo seguinte é o de concluído.
        OnboardingProgress.record(.permissions, in: defaults)
        let model = OnboardingModel(defaults: defaults, permissionDemandID: UUID())
        XCTAssertEqual(model.step, .permissions)
        model.advance()
        XCTAssertEqual(model.step, .done, "O botão de continuar leva ao passo de concluído")

        // O texto que avisa que a permissão volta a ser pedida acompanha a
        // linha pendente no passo.
        let view = try source("Sources/Hexa/UI/Onboarding/OnboardingView.swift")
        XCTAssertTrue(view.contains("Text(strings.obPermissionPendingNote)"),
                      "O passo precisa avisar que a permissão pendente volta a ser pedida")
        XCTAssertTrue(view.contains("requiredPermissions.contains(where: { permission in status(for: permission) == .missing })"),
                      "O aviso acompanha a permissão pendente, não a lista sempre")
    }

    /// A regra de D14 por permissão: sempre se pode pedir Acessibilidade,
    /// Gravação de Tela e Acesso Total ao Disco; Notificações, Calendário,
    /// Bluetooth e Automações só enquanto o macOS aceita o pedido; Arquivos e
    /// Pastas, Captura de Áudio e Gerenciamento de Apps nunca, e a linha fica
    /// só com os Ajustes.
    func testCanAskAgainFollowsTheMacOSRule() {
        for permission in [AppPermission.accessibility, .screenRecording, .fullDiskAccess] {
            XCTAssertTrue(PermissionPortalRow.canAskAgain(for: permission, readers: readers()),
                          "\(permission.rawValue) sempre aceita um pedido novo")
            XCTAssertTrue(PermissionPortalRow.canAskAgain(
                for: permission,
                readers: readers(notifications: .denied, calendar: .denied, bluetooth: .denied)),
                          "\(permission.rawValue) não depende do estado das outras permissões")
        }

        XCTAssertTrue(PermissionPortalRow.canAskAgain(
            for: .notifications, readers: readers(notifications: .undetermined)))
        XCTAssertFalse(PermissionPortalRow.canAskAgain(
            for: .notifications, readers: readers(notifications: .denied)))
        XCTAssertFalse(PermissionPortalRow.canAskAgain(
            for: .notifications, readers: readers(notifications: .granted)))

        XCTAssertTrue(PermissionPortalRow.canAskAgain(
            for: .calendar, readers: readers(calendar: .notDetermined)))
        XCTAssertTrue(PermissionPortalRow.canAskAgain(
            for: .calendar, readers: readers(calendar: .writeOnly)))
        XCTAssertFalse(PermissionPortalRow.canAskAgain(
            for: .calendar, readers: readers(calendar: .denied)))

        XCTAssertTrue(PermissionPortalRow.canAskAgain(
            for: .bluetooth, readers: readers(bluetooth: .undetermined)))
        XCTAssertFalse(PermissionPortalRow.canAskAgain(
            for: .bluetooth, readers: readers(bluetooth: .denied)))

        for permission in [AppPermission.automationFinder, .automationTerminal] {
            XCTAssertTrue(PermissionPortalRow.canAskAgain(
                for: permission,
                readers: readers(finder: .undetermined, terminal: .undetermined)),
                          "\(permission.rawValue) aceita um pedido só enquanto não houve resposta")
            XCTAssertFalse(PermissionPortalRow.canAskAgain(
                for: permission,
                readers: readers(finder: .denied, terminal: .denied)))
            XCTAssertFalse(PermissionPortalRow.canAskAgain(
                for: permission,
                readers: readers(finder: .notDeterminable, terminal: .notDeterminable)))
        }

        XCTAssertTrue(PermissionPortalRow.canAskAgain(
            for: .automationPlayback, readers: readers(playback: .consent)))
        XCTAssertFalse(PermissionPortalRow.canAskAgain(
            for: .automationPlayback, readers: readers(playback: .denied)))

        for permission in [AppPermission.filesAndFolders, .audioCapture, .appManagement] {
            for value in [true, false] {
                let readers = readers(audioCapture: value)
                XCTAssertFalse(PermissionPortalRow.canAskAgain(for: permission, readers: readers),
                               "\(permission.rawValue) não tem pedido do macOS: só os Ajustes")
            }
        }
    }

    // MARK: - AC-4.2.4

    /// A leitura de Automação de Finder e Terminal acontece fora da thread
    /// principal e volta nela.
    func testAutomationReadIsOffMain() {
        let delivered = expectation(description: "leitura de Automação entregue na principal")
        var ranOffMain: [Bool] = []

        OnboardingPermissionSet.readAutomation(
            read: { target in
                ranOffMain.append(!Thread.isMainThread)
                return target == .finder ? .undetermined : .denied
            },
            deliver: { statuses in
                XCTAssertTrue(Thread.isMainThread, "A entrega precisa voltar na thread principal")
                XCTAssertEqual(statuses[.finder], .undetermined)
                XCTAssertEqual(statuses[.terminal], .denied)
                delivered.fulfill()
            })

        wait(for: [delivered], timeout: 5)
        XCTAssertEqual(ranOffMain, [true, true],
                       "A leitura de Automação não pode rodar na thread principal")
    }

    /// O padrão do parâmetro é o leitor de produção: o passo lê Finder e
    /// Terminal de verdade quando nada é injetado.
    func testAutomationReadDefaultIsTheProductionReader() {
        let delivered = expectation(description: "leitura de produção")
        OnboardingPermissionSet.readAutomation { statuses in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(Set(statuses.keys), Set(Permissions.AutomationTarget.allCases),
                           "O padrão precisa consultar Finder e Terminal")
            delivered.fulfill()
        }
        wait(for: [delivered], timeout: 10)
    }

    // MARK: - AC-4.2.5

    /// A demanda de sondagem do passo existe só enquanto ele está na tela: entra
    /// quando o passo aparece, sai quando ele desaparece, e o fechamento da
    /// janela a libera mesmo com a view já descartada. O identificador é o do
    /// modelo, e é o mesmo que a janela libera.
    func testPermissionDemandIsReleased() throws {
        var demands = PermissionSurfaceDemands()
        let demandID = UUID()

        OnboardingProgress.record(.permissions, in: defaults)
        let model = OnboardingModel(defaults: defaults, permissionDemandID: demandID)
        XCTAssertEqual(model.step, .permissions)
        XCTAssertEqual(model.permissionDemandID, demandID,
                       "O identificador da demanda vive no modelo")

        // O passo aparece: a demanda entra e a cadência de sondagem existe.
        demands.set(model.permissionDemandID, visible: true)
        XCTAssertEqual(demands.count, 1)
        XCTAssertEqual(pollingInterval(for: demands), 2.5,
                       "Com o passo visível a sondagem tem cadência")

        // Sair do passo (avançar ou voltar) derruba a view e libera a demanda.
        model.advance()
        XCTAssertEqual(model.step, .done)
        demands.set(model.permissionDemandID, visible: false)
        XCTAssertEqual(demands.count, 0, "Sair do passo libera a demanda")
        XCTAssertNil(pollingInterval(for: demands),
                     "Sem demanda visível não existe cadência de sondagem")

        // Reentrar no passo registra de novo; fechar a janela libera a demanda
        // do passo, mesmo com a view descartada.
        model.back()
        XCTAssertEqual(model.step, .permissions)
        demands.set(model.permissionDemandID, visible: true)
        XCTAssertEqual(demands.count, 1)

        let session = OnboardingWindowSession(permissionDemandID: model.permissionDemandID,
                                              releasePermissionDemand: { demands.set($0, visible: false) })
        // O salto para o AppKit é substituído como no balanço da política: o
        // processo de teste não tem NSApplication.
        WindowActivationPolicy.apply = { _ in true }
        WindowActivationPolicy.current = { .accessory }
        session.begin()
        session.end()
        XCTAssertEqual(demands.count, 0,
                       "O fechamento da janela libera a demanda do passo")
        XCTAssertNil(pollingInterval(for: demands),
                     "A demanda liberada não pode deixar sondagem viva")
        XCTAssertEqual(WindowActivationPolicy.retentionCountForTesting, 0,
                       "O fechamento devolve o que a janela reteve")

        // A produção: o passo registra e libera com o identificador do modelo, e
        // a janela entrega ao modelo o mesmo identificador que ela libera.
        let view = try source("Sources/Hexa/UI/Onboarding/OnboardingView.swift")
        XCTAssertTrue(collapsed(view).contains("OnboardingPermissionsStep(demandID:model.permissionDemandID)"),
                      "O passo precisa receber o identificador do modelo")
        XCTAssertTrue(view.contains("permissions.setActivePermissionSurface(demandID, visible: true)"),
                      "O passo visível registra a demanda na central")
        XCTAssertTrue(view.contains("permissions.setActivePermissionSurface(demandID, visible: false)"),
                      "Sair do passo libera a demanda na central")
        let windowSource = try source("Sources/Hexa/UI/Onboarding/OnboardingWindow.swift")
        XCTAssertTrue(collapsed(windowSource).contains(
            "OnboardingWindowSession(permissionDemandID:model.permissionDemandID)"),
            "A janela precisa segurar o identificador que o modelo carrega")
    }

    // MARK: - Helpers

    private static let legacyRule = ["onboarding", "Permissions"].joined()

    private func readers(accessibility: Bool = false,
                         screenRecording: Bool = false,
                         fullDiskAccess: Bool = false,
                         notifications: Permissions.NotificationPermissionState = .unknown,
                         calendar: EKAuthorizationStatus = .denied,
                         bluetooth: Permissions.BluetoothPermissionState = .unknown,
                         finder: Permissions.AutomationStatus? = nil,
                         terminal: Permissions.AutomationStatus? = nil,
                         playback: NotchMusicAutomation.Access? = nil,
                         audioCapture: Bool = false) -> PermissionPortalRow.Readers {
        PermissionPortalRow.Readers(accessibility: accessibility,
                                    screenRecording: screenRecording,
                                    fullDiskAccess: fullDiskAccess,
                                    notifications: notifications,
                                    calendarAccess: calendar,
                                    bluetooth: bluetooth,
                                    finderAutomation: finder,
                                    terminalAutomation: terminal,
                                    playbackAccess: playback,
                                    audioCaptureNeedsPermission: audioCapture)
    }

    /// A cadência que a central calcularia para o conjunto de demandas.
    private func pollingInterval(for demands: PermissionSurfaceDemands) -> TimeInterval? {
        PermissionPollingSupport.interval(visibleSurfaceCount: demands.count,
                                          accessibilityIsNeeded: true,
                                          screenRecordingIsNeeded: true,
                                          accessibilityIsGranted: false,
                                          screenRecordingIsGranted: false)
    }

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests/hexaTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // raiz do repo
    }

    private func source(_ relativePath: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    /// O texto de `PermissionPortalRow`, da declaração até o fim do arquivo.
    private func rowSource() throws -> String {
        let source = try source("Sources/Hexa/UI/Settings/FeatureHubSettings.swift")
        let start = try XCTUnwrap(source.range(of: "struct PermissionPortalRow: View {"))
        return String(source[start.lowerBound...])
    }

    /// O texto sem nenhum espaço, para comparar a forma do código sem depender
    /// da indentação.
    private func collapsed(_ text: String) -> String {
        text.filter { !$0.isWhitespace }
    }

    private func swiftFiles() throws -> [URL] {
        var urls: [URL] = []
        for folder in ["Sources", "Tests"] {
            let root = repoRoot.appendingPathComponent(folder)
            guard let walker = FileManager.default.enumerator(at: root,
                                                              includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in walker where url.pathExtension == "swift" {
                urls.append(url)
            }
        }
        return urls
    }
}
