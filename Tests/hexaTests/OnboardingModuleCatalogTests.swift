// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Fixa o passo de módulos: as 13 linhas que cobrem o catálogo do app, o estado
/// real de cada uma lido da mesma chave que os Ajustes leem e a escrita da lista
/// final completa do grupo pelo mesmo portão (CN2, VC3, INV3).
final class OnboardingModuleCatalogTests: XCTestCase {
    private var suiteLock: DefaultsSuiteLock?
    private var suiteName = ""
    private var defaults: UserDefaults!
    private var previousLanguage: AppLanguage!
    private var standardSnapshot: [String: Any] = [:]

    /// As chaves de `UserDefaults.standard` que os caminhos de produção tocam.
    /// O portão real escreve nos defaults de verdade, então o teste guarda o
    /// valor anterior de cada uma e devolve no fim.
    private var standardKeys: [String] {
        [AppFeature.portManager.availabilityKey,
         AppFeature.screenshot.availabilityKey,
         AppFeature.screenOCR.availabilityKey,
         AppFeature.notchCalendar.availabilityKey,
         DefaultsKey.notchCalendarEnabled]
    }

    override func setUp() {
        super.setUp()
        suiteLock = DefaultsSuiteLock("onboarding-modules")
        suiteName = "hexaTests.onboarding-modules"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        previousLanguage = L10n.shared.language
        for key in standardKeys {
            if let value = UserDefaults.standard.object(forKey: key) {
                standardSnapshot[key] = value
            }
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        for key in standardKeys {
            if let value = standardSnapshot[key] {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        L10n.shared.language = previousLanguage
        suiteLock = nil
        super.tearDown()
    }

    // MARK: - AC-3.1.1

    /// A união dos 13 grupos é exatamente o catálogo do app: nenhum recurso
    /// repetido, nenhum faltando.
    func testGroupCoverage() {
        XCTAssertEqual(OnboardingModule.allCases.count, 15, "O passo tem 15 linhas")

        let union = OnboardingModule.allCases.flatMap(\.features)
        XCTAssertEqual(Set(union), Set(AppFeature.allCases),
                       "A união dos grupos difere do catálogo do app")
        XCTAssertEqual(union.count, Set(union).count,
                       "Um recurso foi listado em mais de um grupo")
        XCTAssertEqual(union.count, AppFeature.allCases.count,
                       "A soma das listas difere do catálogo do app")
    }

    /// INV3: o texto das linhas nomeia só o que está no catálogo vivo do app. O
    /// título de cada linha é o nome vivo de um recurso dela ou uma chave de
    /// grupo auditada, nunca um nome solto.
    func testScreenTextCitesOnlyCatalogFeatures() {
        for language in AppLanguage.allCases {
            let s = Strings.localized(language)
            let hub = FeatureStrings.hub(language)
            let groupDescriptions = [hub.onboardingModuleMonitorDescription,
                                     hub.onboardingModuleCleanerDescription,
                                     hub.onboardingModuleIslandDescription,
                                     hub.onboardingModuleCaptureDescription]
            for group in OnboardingModule.allCases {
                let liveTitles = Set(group.features.map { $0.hubTitle(s, hub: hub) })
                XCTAssertTrue(liveTitles.union([hub.groupMonitor, hub.onboardingModuleCleanerTitle])
                                .contains(group.title(language)),
                              "O título de \(group) em \(language.rawValue) não nomeia nada do grupo")
                let liveDescriptions = Set(group.features.map { $0.hubDescription(hub) })
                XCTAssertTrue(liveDescriptions.union(groupDescriptions).contains(group.description(language)),
                              "A descrição de \(group) em \(language.rawValue) não descreve o grupo")
            }
        }
    }

    // MARK: - AC-3.1.2

    /// Título e descrição não vazios nos 15 idiomas, e os grupos compostos usam
    /// a chave de grupo do Plan 01 em vez de um título montado por concatenação.
    func testTitlesResolve() {
        XCTAssertEqual(AppLanguage.allCases.count, 15)
        for language in AppLanguage.allCases {
            let s = Strings.localized(language)
            let hub = FeatureStrings.hub(language)
            for group in OnboardingModule.allCases {
                let title = group.title(language).trimmingCharacters(in: .whitespacesAndNewlines)
                let description = group.description(language).trimmingCharacters(in: .whitespacesAndNewlines)
                XCTAssertFalse(title.isEmpty, "Título de \(group) vazio em \(language.rawValue)")
                XCTAssertFalse(description.isEmpty, "Descrição de \(group) vazia em \(language.rawValue)")
            }

            XCTAssertEqual(OnboardingModule.cleanerAndMaintenance.title(language),
                           hub.onboardingModuleCleanerTitle,
                           "Limpeza e manutenção usa a chave de grupo em \(language.rawValue)")
            XCTAssertNotEqual(OnboardingModule.cleanerAndMaintenance.title(language),
                              AppFeature.cleaner.hubTitle(s, hub: hub) + ", "
                                  + AppFeature.maintenanceTasks.hubTitle(s, hub: hub),
                              "O título do grupo não pode ser a concatenação de dois títulos")
            XCTAssertEqual(OnboardingModule.cleanerAndMaintenance.description(language),
                           hub.onboardingModuleCleanerDescription)
            XCTAssertEqual(OnboardingModule.monitor.description(language),
                           hub.onboardingModuleMonitorDescription)
            XCTAssertEqual(OnboardingModule.dynamicIsland.description(language),
                           hub.onboardingModuleIslandDescription)
            XCTAssertEqual(OnboardingModule.screenCapture.description(language),
                           hub.onboardingModuleCaptureDescription)
        }

        // O texto de referência (en-US) das chaves de grupo é o golden fixado no
        // Plan 01; aqui ele é o mesmo que a linha desenha.
        L10n.shared.language = .enUS
        XCTAssertEqual(OnboardingModule.cleanerAndMaintenance.title,
                       "Cleaning and maintenance")
        XCTAssertEqual(OnboardingModule.monitor.title, "System monitor")
    }

    // MARK: - AC-3.1.3

    /// Os únicos grupos com recursos fora do padrão de fábrica são Fan Control,
    /// Kill Process, Port Manager e Dock em uma tela.
    func testGroupIsComplete() {
        let optInGroups = OnboardingModule.allCases.filter { group in
            group.features.contains { !$0.installedByDefault }
        }
        XCTAssertEqual(Set(optInGroups), [.fanControl, .killProcess, .portManager, .dockDisplayLock, .menuBarHiding],
                       "Só Fan Control, Kill Process, Port Manager, Dock em uma tela e Ícones da menu bar nascem desmarcados")
        for group in [OnboardingModule.fanControl, .killProcess, .portManager, .dockDisplayLock, .menuBarHiding] {
            XCTAssertTrue(group.features.allSatisfy { !$0.installedByDefault },
                          "O grupo \(group) é opt-in por inteiro")
        }
    }

    // MARK: - AC-3.2.1

    /// A linha lê o estado real de cada recurso do grupo, sem cópia própria: o
    /// valor acompanha a chave que a central de Ajustes lê, inclusive quando ela
    /// muda pelas costas da linha.
    func testStateIsSharedWithTheHub() {
        let suite = defaults!
        let isAvailable = { (feature: AppFeature) in feature.isAvailable(in: suite) }
        let monitor = OnboardingModule.monitor

        XCTAssertEqual(OnboardingModuleCatalog.installedCount(in: monitor, isAvailable: isAvailable), 0)
        XCTAssertFalse(OnboardingModuleCatalog.isInstalled(monitor, isAvailable: isAvailable))

        // Um recurso instalado: o grupo está parcial e o switch não mente.
        suite.set(true, forKey: AppFeature.monitorCPU.availabilityKey)
        XCTAssertTrue(AppFeature.monitorCPU.isAvailable(in: suite),
                      "A linha e os Ajustes leem a mesma chave")
        XCTAssertEqual(OnboardingModuleCatalog.installedCount(in: monitor, isAvailable: isAvailable), 1)
        XCTAssertFalse(OnboardingModuleCatalog.isInstalled(monitor, isAvailable: isAvailable),
                       "Grupo parcial não pode aparecer ligado")
        XCTAssertTrue(OnboardingModuleCatalog.isPartiallyInstalled(monitor, isAvailable: isAvailable),
                      "Um recurso de sete instalado é estado parcial")

        // A chave muda sem aviso à linha: a próxima leitura acompanha.
        suite.set(false, forKey: AppFeature.monitorCPU.availabilityKey)
        XCTAssertEqual(OnboardingModuleCatalog.installedCount(in: monitor, isAvailable: isAvailable), 0,
                       "A linha guardou cópia própria do estado")

        for feature in monitor.features {
            suite.set(true, forKey: feature.availabilityKey)
        }
        XCTAssertTrue(OnboardingModuleCatalog.isInstalled(monitor, isAvailable: isAvailable))
        XCTAssertEqual(OnboardingModuleCatalog.installedCount(in: monitor, isAvailable: isAvailable),
                       monitor.features.count)

        suite.set(false, forKey: AppFeature.monitorGPU.availabilityKey)
        XCTAssertEqual(OnboardingModuleCatalog.installedCount(in: monitor, isAvailable: isAvailable),
                       monitor.features.count - 1,
                       "A contagem precisa refletir a chave desligada")
        XCTAssertFalse(OnboardingModuleCatalog.isInstalled(monitor, isAvailable: isAvailable))
        XCTAssertTrue(OnboardingModuleCatalog.isPartiallyInstalled(monitor, isAvailable: isAvailable))
    }

    // MARK: - AC-3.2.2

    /// Desligar e ligar a linha passa sempre a lista final completa do grupo, e
    /// depois dela todas as chaves do grupo estão no valor pedido.
    func testWholeGroupIsFlipped() throws {
        let suite = defaults!
        var received: [(features: [AppFeature], available: Bool)] = []
        let write: OnboardingModuleCatalog.Write = { features, available in
            received.append((features, available))
            for feature in features {
                suite.set(available, forKey: feature.availabilityKey)
            }
        }

        XCTAssertEqual(OnboardingModule.dynamicIsland.features.count, 11,
                       "A ilha leva as dez extensões junto")

        for available in [false, true] {
            for group in OnboardingModule.allCases {
                OnboardingModuleCatalog.setInstalled(group, available, write: write)
                let last = try XCTUnwrap(received.last)
                XCTAssertEqual(last.available, available)
                XCTAssertEqual(Set(last.features), Set(group.features),
                               "A linha de \(group) não passou o grupo inteiro")
                XCTAssertEqual(last.features.count, group.features.count,
                               "A linha de \(group) repetiu um recurso")
                for feature in group.features {
                    XCTAssertEqual(feature.isAvailable(in: suite), available,
                                   "A chave de \(feature) não ficou \(available) pelo grupo \(group)")
                }
            }
        }
    }

    /// O caminho de produção da linha é o portão da central de Ajustes, com a
    /// lista intacta no cancelamento do descarte da captura (D13).
    func testProductionWriteIsTheHubGate() throws {
        UserDefaults.standard.set(false, forKey: AppFeature.portManager.availabilityKey)
        OnboardingModuleCatalog.setInstalled(.portManager, true)
        XCTAssertTrue(AppFeature.portManager.isAvailable,
                      "A linha liga pelo portão que os Ajustes usam")
        OnboardingModuleCatalog.setInstalled(.portManager, false)
        XCTAssertFalse(AppFeature.portManager.isAvailable,
                       "A linha desliga pelo portão que os Ajustes usam")

        let catalog = try source("Sources/Hexa/Core/OnboardingModuleCatalog.swift")
        XCTAssertTrue(catalog.contains("keepListOnDiscardCancel: true"),
                      "A linha do passo de módulos precisa pedir a lista intacta no cancelamento")
    }

    // MARK: - AC-3.2.3

    /// Cancelar a confirmação de descarte da captura não desinstala nada da
    /// linha: a captura e o OCR continuam instalados. Sem o parâmetro, o
    /// cancelamento segue como nos Ajustes, tirando só a captura da lista.
    func testCaptureDiscardIsRespected() throws {
        let runtime = FeatureRuntime.shared
        let original = runtime.confirmCaptureDiscard
        defer { runtime.confirmCaptureDiscard = original }
        // O usuário cancelou a pergunta de descarte de uma captura por terminar.
        runtime.confirmCaptureDiscard = { false }

        UserDefaults.standard.set(true, forKey: AppFeature.screenshot.availabilityKey)
        UserDefaults.standard.set(true, forKey: AppFeature.screenOCR.availabilityKey)
        let revisionBefore = runtime.revision

        OnboardingModuleCatalog.setInstalled(.screenCapture, false)

        XCTAssertTrue(AppFeature.screenshot.isAvailable,
                      "Cancelar a confirmação não pode desinstalar a captura")
        XCTAssertTrue(AppFeature.screenOCR.isAvailable,
                      "Cancelar a confirmação não pode desinstalar o OCR")
        XCTAssertEqual(runtime.revision, revisionBefore + 1,
                       "O switch precisa voltar ao estado ligado")

        // Hoje, no interruptor dos Ajustes: só a captura sai da lista.
        XCTAssertEqual(FeatureRuntime.survivingList([.screenshot, .screenOCR],
                                                   keepListOnDiscardCancel: false),
                       [.screenOCR])
        XCTAssertEqual(FeatureRuntime.survivingList([.screenshot, .screenOCR],
                                                   keepListOnDiscardCancel: true),
                       [])

        // O padrão do parâmetro é a pergunta real do editor: sem esta linha, o
        // teste provaria só a closure injetada.
        let runtimeSource = try source("Sources/Hexa/App/FeatureRuntime.swift")
        XCTAssertTrue(runtimeSource.contains(
            "var confirmCaptureDiscard: () -> Bool = ScreenshotEditorController.confirmDiscardBeforeQuit"),
                      "O padrão do portão precisa ser a pergunta de descarte do editor")
    }

    // MARK: - AC-3.2.4

    /// Com todos os grupos desligados as 13 linhas continuam na tela, todas
    /// desligadas, e o passo continua mostrando o texto que aponta os Ajustes.
    func testRowsSurviveAllOff() throws {
        let suite = defaults!
        for group in OnboardingModule.allCases {
            for feature in group.features {
                suite.set(false, forKey: feature.availabilityKey)
            }
        }
        let isAvailable = { (feature: AppFeature) in feature.isAvailable(in: suite) }

        XCTAssertEqual(OnboardingModule.allCases.count, 15, "A lista de linhas é fixa")
        for group in OnboardingModule.allCases {
            XCTAssertEqual(OnboardingModuleCatalog.installedCount(in: group, isAvailable: isAvailable), 0)
            XCTAssertFalse(OnboardingModuleCatalog.isInstalled(group, isAvailable: isAvailable))
        }

        let view = try source("Sources/Hexa/UI/Onboarding/OnboardingView.swift")
        XCTAssertTrue(view.contains("ForEach(OnboardingModule.allCases"),
                      "O passo desenha as 15 linhas fixas")
        XCTAssertFalse(view.contains("OnboardingModule.allCases.filter"),
                       "Nenhuma linha pode ser filtrada pelo estado")
        XCTAssertTrue(view.contains("obStepModulesBody"),
                      "O passo mostra o texto que diz que os módulos voltam nos Ajustes")
    }

    // MARK: - AC-3.2.5

    /// Desligar a linha da Dynamic Island leva a ilha e as dez extensões na mesma
    /// passada, sem segunda pergunta.
    func testIslandOffTakesExtensionsAlong() throws {
        let suite = defaults!
        var received: [AppFeature] = []
        let write: OnboardingModuleCatalog.Write = { features, available in
            received = features
            for feature in features {
                suite.set(available, forKey: feature.availabilityKey)
            }
        }

        OnboardingModuleCatalog.setInstalled(.dynamicIsland, false, write: write)

        XCTAssertEqual(Set(received), Set([.notch] + AppFeature.dynamicIslandExtensions))
        XCTAssertEqual(received.count, 11, "A ilha e as dez extensões saem juntas")
        let listed = try XCTUnwrap(received.first { $0 == .notch }, "A ilha precisa estar na lista")
        XCTAssertTrue(listed == .notch)
        for feature in AppFeature.dynamicIslandExtensions {
            XCTAssertTrue(received.contains(feature), "A extensão \(feature) ficou de fora")
            XCTAssertFalse(feature.isAvailable(in: suite),
                           "A extensão \(feature) continuou instalada")
        }
    }

    /// O desligamento não apaga a configuração da extensão: religar devolve cada
    /// uma com o que tinha antes (D12). O caminho é o de produção.
    func testIslandSettingsSurviveOffOn() {
        UserDefaults.standard.set(true, forKey: AppFeature.notchCalendar.availabilityKey)
        UserDefaults.standard.set(true, forKey: DefaultsKey.notchCalendarEnabled)

        FeatureRuntime.shared.setAvailable([.notchCalendar], false)
        XCTAssertFalse(AppFeature.notchCalendar.isAvailable)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: DefaultsKey.notchCalendarEnabled),
                      "Desligar não pode apagar a configuração da extensão")

        FeatureRuntime.shared.setAvailable([.notchCalendar], true)
        XCTAssertTrue(AppFeature.notchCalendar.isAvailable)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: DefaultsKey.notchCalendarEnabled),
                      "Religar a linha devolve a extensão com a configuração que tinha")
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
