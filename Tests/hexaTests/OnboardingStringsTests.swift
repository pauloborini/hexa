// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Fixa o conjunto curado de textos de primeira execução (CN8, INV1, LEG1).
///
/// O golden `onboarding-reference-en` (en-US, 2026-10-28) guarda o texto de
/// referência das 27 chaves; a tabela de auditoria registra, para cada texto
/// herdado que continua, o fato do código que ele afirma.
final class OnboardingStringsTests: XCTestCase {
    // MARK: - O conjunto curado

    /// As 20 chaves do roteiro de 4 passos no catálogo `Strings`.
    static let stringsKeys: [String] = [
        "obContinue",
        "obBack",
        "obStepWelcomeTitle",
        "obStepWelcomeBody",
        "obWelcomeBullet1Title",
        "obWelcomeBullet1Body",
        "obWelcomeBullet2Title",
        "obWelcomeBullet2Body",
        "obWelcomeBullet3Title",
        "obWelcomeBullet3Body",
        "obStepModulesTitle",
        "obStepModulesBody",
        "obStepPermissionsTitle",
        "obStepPermissionsBody",
        "obStepDoneTitle",
        "obStepDoneBody",
        "obDoneHint",
        "obFinish",
        "obPermissionPendingNote",
        "obRedoOnboarding"
    ]

    /// As 7 chaves do passo de módulos e do passo de permissões no hub.
    static let hubKeys: [String] = [
        "onboardingSelectedPermissionsTitle",
        "onboardingNoSelectedPermissions",
        "onboardingModuleCleanerTitle",
        "onboardingModuleMonitorDescription",
        "onboardingModuleCleanerDescription",
        "onboardingModuleIslandDescription",
        "onboardingModuleCaptureDescription"
    ]

    /// As 27 chaves de primeira execução, na ordem do roteiro.
    static var firstRunKeys: [String] { stringsKeys + hubKeys }

    /// As 13 chaves herdadas que continuam e entram na tabela de auditoria.
    static let inheritedKeys: Set<String> = [
        "obContinue",
        "obBack",
        "obStepWelcomeTitle",
        "obStepWelcomeBody",
        "obWelcomeBullet1Title",
        "obWelcomeBullet1Body",
        "obWelcomeBullet2Title",
        "obWelcomeBullet2Body",
        "obWelcomeBullet3Title",
        "obWelcomeBullet3Body",
        "obStepDoneTitle",
        "obStepDoneBody",
        "obDoneHint"
    ]

    /// Chaves com prefixo `ob` que existem no catálogo e ficam fora do conjunto
    /// de primeira execução: as duas da tela Sobre e as sete do aviso de
    /// atualização, herdadas de um fluxo que este pack não toca (nenhuma das
    /// sete tem consumidor hoje; a remoção delas não é autorizada pelo LEG1).
    static let outsideTheSet: Set<String> = [
        "obWhatsNewTitle",
        "obWhatsNewFallback",
        "obStepMenuBarTitle",
        "obStepMenuBarBody",
        "obStepMenuBarNote",
        "obStepPanelTitle",
        "obStepPanelBody",
        "obStepPanelNavigationTitle",
        "obStepPanelNavigationBody"
    ]

    /// LEG1 (GUIDE 2.7): as 24 chaves mortas do passo que não existe mais.
    static let removedKeys: [String] = [
        "obSkipStep",
        "obStart",
        "obLanguageLabel",
        "obStepAccessibilityTitle",
        "obStepAccessibilityBody",
        "obAccessibilityWhy",
        "obStepRecordingTitle",
        "obStepRecordingBody",
        "obRecordingWhy",
        "obStepMonitorTitle",
        "obStepMonitorBody",
        "obMonitorNoPermission",
        "obStepOptionalTitle",
        "obStepOptionalBody",
        "obStepStatusTitle",
        "obStepStatusBody",
        "obStatusRecheck",
        "obPurposeTitle",
        "obPurposeBody",
        "obPurposeSkip",
        "obLanguageUpdateTitle",
        "obLanguageUpdateBody",
        "onboardingOtherPermissionsTitle",
        "onboardingOtherPermissionsCaption"
    ]

    /// Golden `onboarding-reference-en` (en-US, capturado em 2026-10-28 na
    /// curadoria deste plano). Mudar um texto de referência exige um golden novo
    /// e a tabela de auditoria atualizada junto.
    static let referenceEN: [String: String] = [
        "obContinue": "Continue",
        "obBack": "Back",
        "obStepWelcomeTitle": "Welcome to Hexa",
        "obStepWelcomeBody": "Hexa is a modular macOS utility. Everything runs on demand, and the app has no telemetry.",
        "obWelcomeBullet1Title": "Power management",
        "obWelcomeBullet1Body": "Configurable sleep prevention and continuous operation on demand.",
        "obWelcomeBullet2Title": "System monitoring",
        "obWelcomeBullet2Body": "Real-time monitoring of hardware utilization, temperatures, and memory pressure.",
        "obWelcomeBullet3Title": "Maintenance and tools",
        "obWelcomeBullet3Body": "Application uninstaller, system cleaning, and process control tools.",
        "obStepModulesTitle": "Modules",
        "obStepModulesBody": "Choose what this Mac runs. A module turned off here leaves the menu bar and Settings, and can be turned back on later in Settings.",
        "obStepPermissionsTitle": "Permissions",
        "obStepPermissionsBody": "These are the permissions required by the modules you kept on. Hexa asks macOS only when you request one.",
        "obStepDoneTitle": "Setup complete",
        "obStepDoneBody": "Hexa is active and ready for use.",
        "obDoneHint": "Access the Hexa icon in the menu bar at the top of your screen.",
        "obFinish": "Finish",
        "obPermissionPendingNote": "Not granted. Hexa asks again when the module needs it.",
        "obRedoOnboarding": "Run setup again",
        "onboardingSelectedPermissionsTitle": "Permissions required for selected modules",
        "onboardingNoSelectedPermissions": "No additional permissions are required for the current configuration.",
        "onboardingModuleCleanerTitle": "Cleaning and maintenance",
        "onboardingModuleMonitorDescription": "CPU, GPU, memory, disk, network, power and connected device metrics.",
        "onboardingModuleCleanerDescription": "System cache cleaning and the Mac maintenance tasks.",
        "onboardingModuleIslandDescription": "The Dynamic Island in the notch, with its extensions.",
        "onboardingModuleCaptureDescription": "Screen capture and text recognition on screen."
    ]

    /// Termos do produto antigo que o texto herdado usava: o alternador de
    /// janelas com miniaturas, a inversão de rolagem do mouse e o ícone do
    /// buraco negro. Nenhum valor de primeira execução pode citá-los.
    static let retiredTerms: [AppLanguage: [String]] = [
        .enUS: ["window switcher", "invert", "black hole"],
        .ptBR: ["alternador de janelas", "inversão de rolagem", "inverter a rolagem", "buraco negro"],
        .de: ["fensterumschalter", "umgekehrtes mausscrollen", "mausscrollen umzukehren", "schwarzen loch", "schwarze loch"],
        .fr: ["sélecteur de fenêtres", "défilement de souris inversé", "inverser le défilement", "trou noir"],
        .it: ["commutatore di finestre", "scorrimento invertito", "invertire lo scorrimento", "buco nero"],
        .es: ["selector de ventanas", "desplazamiento invertido", "invertir el desplazamiento", "agujero negro"],
        .tr: ["pencere değiştirici", "ters fare kaydırma", "fare kaydırmasını ters", "kara delik"],
        .ru: ["переключатель окон", "инверсия прокрутки", "инверсии прокрутки", "чёрную дыру", "чёрная дыра"],
        .sk: ["prepínač okien", "obrátenie rolovania", "čiernu dieru", "čierna diera"],
        .uk: ["перемикач вікон", "інвертована прокрутка", "інвертування прокрутки", "чорну діру"],
        .ja: ["ウインドウスイッチャー", "スクロール反転", "ブラックホール"],
        .ko: ["윈도우 전환기", "스크롤 반전", "블랙홀"],
        .zhHans: ["窗口切换器", "反转鼠标滚动", "缩略图", "黑洞"],
        .zhTW: ["視窗切換器", "反轉滑鼠捲動", "縮圖", "黑洞"],
        .zhHK: ["視窗切換器", "反轉滑鼠捲動", "縮圖", "黑洞"]
    ]

    /// Termos que nomeiam o controle térmico das ventoinhas. Elas pertencem ao
    /// Fan Control, que é uma linha própria do passo de módulos, e por isso não
    /// podem aparecer na descrição do grupo Monitor.
    static let fanControlTerms: [String] = [
        "fan", "ventoinha", "ventilador", "ventola", "ventilateur", "lüfter",
        "ventilátor", "вентилятор", "ファン", "팬", "風扇", "风扇"
    ]

    // MARK: - Tabela de auditoria (AC-1.1.3)

    struct AuditRow {
        let key: String
        let fact: String
        let evidence: String
        let verdict: String
    }

    /// Uma linha por chave herdada: a chave, o fato do código que o texto
    /// afirma, o caminho que sustenta o fato e o veredito da curadoria.
    static let auditTable: [AuditRow] = [
        AuditRow(key: "obContinue",
                 fact: "botão de avançar do roteiro; não afirma nada sobre o app",
                 evidence: "Sources/Hexa/Core/Localization.swift",
                 verdict: "mantido"),
        AuditRow(key: "obBack",
                 fact: "botão Voltar, compartilhado com a ilha, que já o consome",
                 evidence: "Sources/Hexa/UI/Notch/NotchView.swift",
                 verdict: "mantido"),
        AuditRow(key: "obStepWelcomeTitle",
                 fact: "nomeia o app na tela de boas-vindas; o nome é o do projeto",
                 evidence: "Sources/Hexa/App/AppDelegate.swift",
                 verdict: "mantido"),
        AuditRow(key: "obStepWelcomeBody",
                 fact: "reescrito: diz o funcionamento sob demanda e a ausência de telemetria, sem fixar uma contagem de módulos, que a tela de módulos não espelha (D6)",
                 evidence: "Sources/Hexa/Core/FeatureCatalog.swift",
                 verdict: "reescrito"),
        AuditRow(key: "obWelcomeBullet1Title",
                 fact: "o Keep Awake existe e segura o sono do sistema sob demanda",
                 evidence: "Sources/Hexa/Services/KeepAwakeManager.swift",
                 verdict: "mantido"),
        AuditRow(key: "obWelcomeBullet1Body",
                 fact: "o Keep Awake é acionado sob demanda e desligado pelo usuário",
                 evidence: "Sources/Hexa/Services/KeepAwakeManager.swift",
                 verdict: "mantido"),
        AuditRow(key: "obWelcomeBullet2Title",
                 fact: "reescrito em en-US e pt-BR: o app lê as métricas localmente e não envia telemetria, então o título não usa a palavra",
                 evidence: "Sources/Hexa/UI/MenuPanel/MetricDetailView.swift",
                 verdict: "reescrito"),
        AuditRow(key: "obWelcomeBullet2Body",
                 fact: "o Monitor mostra CPU, GPU, temperatura de bateria, uso de hardware e pressão de memória",
                 evidence: "Sources/Hexa/UI/MenuPanel/MetricDetailView.swift",
                 verdict: "mantido"),
        AuditRow(key: "obWelcomeBullet3Title",
                 fact: "reescrito: manutenção e utilitários, que o catálogo de features representa",
                 evidence: "Sources/Hexa/Core/FeatureCatalog.swift",
                 verdict: "reescrito"),
        AuditRow(key: "obWelcomeBullet3Body",
                 fact: "desinstalador, limpeza do sistema e controle de processos existem como recursos do catálogo",
                 evidence: "Sources/Hexa/Core/FeatureCatalog.swift",
                 verdict: "reescrito"),
        AuditRow(key: "obStepDoneTitle",
                 fact: "o passo de conclusão existe como último passo do roteiro e o marcador guarda o valor de conclusão",
                 evidence: "Sources/Hexa/Core/Defaults.swift",
                 verdict: "mantido"),
        AuditRow(key: "obStepDoneBody",
                 fact: "o app segue ativo na barra de menus depois do lançamento",
                 evidence: "Sources/Hexa/App/StatusItemController.swift",
                 verdict: "mantido"),
        AuditRow(key: "obDoneHint",
                 fact: "reescrito: o ícone do app está na barra de menus, no alto da tela",
                 evidence: "Sources/Hexa/App/StatusItemController.swift",
                 verdict: "reescrito")
    ]

    // MARK: - AC-1.1.1

    /// O catálogo declara exatamente as 27 chaves de primeira execução, mais as
    /// chaves herdadas que ficam fora do conjunto, e nenhuma das 24 removidas.
    func testReferenceKeySetIsClosed() {
        let declaredStrings = Self.declaredKeys(of: Strings.localized(.enUS), prefix: "ob")
        let declaredHub = Self.declaredKeys(of: FeatureStrings.hub(.enUS), prefix: "onboarding")

        XCTAssertEqual(declaredStrings,
                       Set(Self.stringsKeys).union(Self.outsideTheSet),
                       "O catálogo declara chaves de primeira execução fora da lista de 27")
        XCTAssertEqual(declaredHub,
                       Set(Self.hubKeys),
                       "O hub declara chaves de onboarding fora da lista de 7")
        for key in Self.removedKeys {
            XCTAssertFalse(declaredStrings.contains(key), "A chave removida \(key) voltou a ser declarada")
            XCTAssertFalse(declaredHub.contains(key), "A chave removida \(key) voltou a ser declarada")
        }
    }

    // MARK: - AC-1.1.2

    /// Nenhuma das 24 chaves removidas tem valor em nenhum dos 15 idiomas, e
    /// nenhum uso delas sobrevive em `Sources/` ou `Tests/`.
    func testRemovedKeysAreGoneEverywhere() throws {
        var catalogFiles = [
            "Sources/Hexa/Core/Localization.swift",
            Self.hubFile
        ]
        catalogFiles += Self.languageFiles.values.sorted()
        for file in catalogFiles {
            let text = try source(file)
            for key in Self.removedKeys {
                XCTAssertFalse(text.contains(key),
                               "A chave removida \(key) ainda aparece em \(file)")
            }
        }

        // A varredura do repositório ignora este arquivo, que lista as chaves
        // removidas para poder afirmar a ausência delas.
        let thisFile = URL(fileURLWithPath: #filePath).lastPathComponent
        for url in try swiftFiles() where url.lastPathComponent != thisFile {
            let text = try String(contentsOf: url, encoding: .utf8)
            for key in Self.removedKeys {
                XCTAssertFalse(text.contains(key),
                               "Uso da chave removida \(key) sobreviveu em \(url.path)")
            }
        }
    }

    // MARK: - AC-1.1.3

    /// A tabela de auditoria cobre as 13 chaves herdadas, cita uma evidência que
    /// existe no repositório e marca as reescritas.
    func testAuditTableIsPresentAndPinned() {
        XCTAssertEqual(Self.auditTable.count, 13,
                       "A tabela de auditoria precisa de uma linha por chave herdada")
        XCTAssertEqual(Set(Self.auditTable.map(\.key)), Self.inheritedKeys,
                       "A tabela de auditoria cobre chaves diferentes das 13 herdadas")
        for row in Self.auditTable {
            XCTAssertFalse(row.fact.isEmpty, "A linha de \(row.key) está sem o fato do código")
            XCTAssertTrue(["mantido", "reescrito"].contains(row.verdict),
                          "Veredito desconhecido para \(row.key): \(row.verdict)")
            let url = repoRoot.appendingPathComponent(row.evidence)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                          "A evidência \(row.evidence) de \(row.key) não existe no repositório")
        }
        let rewritten = Set(Self.auditTable.filter { $0.verdict == "reescrito" }.map(\.key))
        XCTAssertEqual(rewritten,
                       ["obStepWelcomeBody", "obWelcomeBullet2Title", "obWelcomeBullet3Title",
                        "obWelcomeBullet3Body", "obDoneHint"],
                       "As cinco chaves reescritas precisam estar marcadas na tabela")
    }

    // MARK: - AC-1.1.4

    /// As cinco chaves novas do hub descrevem os grupos compostos do passo de
    /// módulos, e a descrição do grupo Monitor não invade o Fan Control.
    func testModuleDescriptionsStayInsideTheirGroups() throws {
        XCTAssertEqual(Self.hubKeys.count - 2, 5,
                       "O plano acrescenta cinco chaves de grupo ao hub")
        for language in AppLanguage.allCases {
            let values = try firstRunValues(for: language)
            let monitor = try XCTUnwrap(values["onboardingModuleMonitorDescription"],
                                        "Descrição do grupo Monitor ausente em \(language.rawValue)")
            let lowered = monitor.lowercased()
            for term in Self.fanControlTerms {
                XCTAssertFalse(lowered.contains(term),
                               "A descrição do grupo Monitor cita o controle das ventoinhas (\(term)) em \(language.rawValue)")
            }
            let cleaner = try XCTUnwrap(values["onboardingModuleCleanerTitle"],
                                        "Título do grupo Limpeza e Manutenção ausente em \(language.rawValue)")
            XCTAssertFalse(cleaner.isEmpty,
                           "Título do grupo Limpeza e Manutenção vazio em \(language.rawValue)")
        }
    }

    // MARK: - AC-1.2.1 e AC-1.3.1

    /// O texto de referência (en-US) das 27 chaves bate com o golden.
    func testReferenceTextIsPinned() throws {
        let reference = try firstRunValues(for: .enUS)
        XCTAssertEqual(Set(reference.keys), Set(Self.firstRunKeys),
                       "O texto de referência não cobre as 27 chaves")
        for key in Self.firstRunKeys {
            XCTAssertEqual(reference[key], Self.referenceEN[key],
                           "O texto de referência de \(key) divergiu do golden onboarding-reference-en")
        }
    }

    // MARK: - AC-1.2.1, AC-1.3.2

    /// Os 15 idiomas expõem as mesmas 27 chaves, com valor não vazio e sem o
    /// texto de referência em inglês no lugar da tradução.
    func testEveryLanguageHasTheSameKeys() throws {
        XCTAssertEqual(AppLanguage.allCases.count, 15)
        let reference = try firstRunValues(for: .enUS)
        for language in AppLanguage.allCases {
            let values = try firstRunValues(for: language)
            XCTAssertEqual(Set(values.keys), Set(Self.firstRunKeys),
                           "O conjunto de chaves de \(language.rawValue) difere do en-US")
            for key in Self.firstRunKeys {
                let value = try XCTUnwrap(values[key],
                                          "Chave \(key) ausente em \(language.rawValue)")
                XCTAssertFalse(value.trimmingCharacters(in: .whitespaces).isEmpty,
                               "Chave \(key) vazia em \(language.rawValue)")
                guard language != .enUS, let english = reference[key], english.count > 40 else { continue }
                XCTAssertNotEqual(value, english,
                                  "O valor de \(key) em \(language.rawValue) ainda é o texto de referência em inglês")
            }
        }
    }

    // MARK: - AC-1.2.2

    /// Nenhum valor de primeira execução, em nenhum idioma, cita o produto antigo.
    func testNoRetiredClaimSurvives() throws {
        for language in AppLanguage.allCases {
            let values = try firstRunValues(for: language)
            let terms = try XCTUnwrap(Self.retiredTerms[language],
                                      "Sem termos aposentados declarados para \(language.rawValue)")
            XCTAssertFalse(terms.isEmpty, "Sem termos aposentados declarados para \(language.rawValue)")
            for key in Self.firstRunKeys {
                let value = try XCTUnwrap(values[key],
                                          "Chave \(key) ausente em \(language.rawValue)").lowercased()
                for term in terms {
                    XCTAssertFalse(value.contains(term),
                                   "O texto \(key) de \(language.rawValue) ainda cita o produto antigo: \(term)")
                }
            }
        }
    }

    // MARK: - INV4 (prova da tela de boas-vindas)

    /// A marca do passo de boas-vindas é a do hexa: a view usa `BrandBadge` e o
    /// wordmark do tema, lê os textos curados do passo e de conclusão, e não
    /// nomeia terceiros.
    func testWelcomeUsesHexaBrand() throws {
        let view = try source("Sources/Hexa/UI/Onboarding/OnboardingView.swift")
        for brand in ["BrandBadge(", "HexaTheme.wordmark("] {
            XCTAssertTrue(view.contains(brand), "A tela não usa a marca do hexa (\(brand))")
        }
        for key in ["obStepWelcomeTitle", "obStepWelcomeBody",
                    "obWelcomeBullet1Title", "obWelcomeBullet1Body",
                    "obWelcomeBullet2Title", "obWelcomeBullet2Body",
                    "obWelcomeBullet3Title", "obWelcomeBullet3Body",
                    "obStepDoneTitle", "obStepDoneBody", "obDoneHint"] {
            XCTAssertTrue(view.contains(key), "A tela não desenha \(key)")
        }
        let lowered = view.lowercased()
        for thirdParty in ["discord", "macpaw", "raycast", "bartender", "istat",
                           "aldente", "dropover", "stats"] {
            XCTAssertFalse(lowered.contains(thirdParty),
                           "A tela nomeia um terceiro (\(thirdParty))")
        }
    }

    // MARK: - Leitura do repositório

    static let hubFile = "Sources/Hexa/Core/FeatureHubStrings.swift"

    /// Os 13 idiomas que não vivem no corpo de `Localization.swift`.
    static let languageFiles: [AppLanguage: String] = [
        .de: "Sources/Hexa/Core/Localizations/Strings+German.swift",
        .es: "Sources/Hexa/Core/Localizations/Strings+Spanish.swift",
        .fr: "Sources/Hexa/Core/Localizations/Strings+French.swift",
        .it: "Sources/Hexa/Core/Localizations/Strings+Italian.swift",
        .ja: "Sources/Hexa/Core/Localizations/Strings+Japanese.swift",
        .ko: "Sources/Hexa/Core/Localizations/Strings+Korean.swift",
        .ru: "Sources/Hexa/Core/Localizations/Strings+Russian.swift",
        .sk: "Sources/Hexa/Core/Localizations/Strings+Slovak.swift",
        .tr: "Sources/Hexa/Core/Localizations/Strings+Turkish.swift",
        .uk: "Sources/Hexa/Core/Localizations/Strings+Ukrainian.swift",
        .zhHans: "Sources/Hexa/Core/Localizations/Strings+ChineseSimplified.swift",
        .zhHK: "Sources/Hexa/Core/Localizations/Strings+ChineseTraditionalHK.swift",
        .zhTW: "Sources/Hexa/Core/Localizations/Strings+ChineseTraditionalTW.swift"
    ]

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests/hexaTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // raiz do repo
    }

    private func source(_ relativePath: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(relativePath), encoding: .utf8)
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

    /// Os nomes das propriedades armazenadas que começam com o prefixo dado. É o
    /// conjunto realmente declarado no catálogo, não uma lista copiada à mão.
    private static func declaredKeys<T>(of value: T, prefix: String) -> Set<String> {
        Set(Mirror(reflecting: value).children.compactMap { child in
            guard let label = child.label, label.hasPrefix(prefix) else { return nil }
            return label
        })
    }

    private static func staticName(of language: AppLanguage) -> String {
        switch language {
        case .enUS: return "enUS"
        case .ptBR: return "ptBR"
        case .tr: return "tr"
        case .ru: return "ru"
        case .es: return "es"
        case .sk: return "sk"
        case .de: return "de"
        case .fr: return "fr"
        case .it: return "it"
        case .ja: return "ja"
        case .ko: return "ko"
        case .zhHans: return "zhHans"
        case .zhHK: return "zhHK"
        case .zhTW: return "zhTW"
        case .uk: return "uk"
        }
    }

    /// As 20 chaves de `Strings` com os valores do catálogo compilado.
    private static func stringsValues(_ s: Strings) -> [String: String] {
        [
            "obContinue": s.obContinue,
            "obBack": s.obBack,
            "obStepWelcomeTitle": s.obStepWelcomeTitle,
            "obStepWelcomeBody": s.obStepWelcomeBody,
            "obWelcomeBullet1Title": s.obWelcomeBullet1Title,
            "obWelcomeBullet1Body": s.obWelcomeBullet1Body,
            "obWelcomeBullet2Title": s.obWelcomeBullet2Title,
            "obWelcomeBullet2Body": s.obWelcomeBullet2Body,
            "obWelcomeBullet3Title": s.obWelcomeBullet3Title,
            "obWelcomeBullet3Body": s.obWelcomeBullet3Body,
            "obStepModulesTitle": s.obStepModulesTitle,
            "obStepModulesBody": s.obStepModulesBody,
            "obStepPermissionsTitle": s.obStepPermissionsTitle,
            "obStepPermissionsBody": s.obStepPermissionsBody,
            "obStepDoneTitle": s.obStepDoneTitle,
            "obStepDoneBody": s.obStepDoneBody,
            "obDoneHint": s.obDoneHint,
            "obFinish": s.obFinish,
            "obPermissionPendingNote": s.obPermissionPendingNote,
            "obRedoOnboarding": s.obRedoOnboarding
        ]
    }

    /// As 7 chaves do hub com os valores do catálogo compilado.
    private static func hubValues(_ h: FeatureHubStrings) -> [String: String] {
        [
            "onboardingSelectedPermissionsTitle": h.onboardingSelectedPermissionsTitle,
            "onboardingNoSelectedPermissions": h.onboardingNoSelectedPermissions,
            "onboardingModuleCleanerTitle": h.onboardingModuleCleanerTitle,
            "onboardingModuleMonitorDescription": h.onboardingModuleMonitorDescription,
            "onboardingModuleCleanerDescription": h.onboardingModuleCleanerDescription,
            "onboardingModuleIslandDescription": h.onboardingModuleIslandDescription,
            "onboardingModuleCaptureDescription": h.onboardingModuleCaptureDescription
        ]
    }

    /// Os 27 valores de um idioma: catálogo compilado para en-US e pt-BR, texto
    /// dos arquivos para os 13 idiomas restantes.
    private func firstRunValues(for language: AppLanguage) throws -> [String: String] {
        switch language {
        case .enUS:
            var values = Self.stringsValues(Strings.localized(.enUS))
            values.merge(Self.hubValues(FeatureStrings.hub(.enUS))) { _, new in new }
            return values
        case .ptBR:
            var values = Self.stringsValues(Strings.localized(.ptBR))
            values.merge(Self.hubValues(FeatureStrings.hub(.ptBR))) { _, new in new }
            return values
        default:
            let file = try XCTUnwrap(Self.languageFiles[language],
                                     "Sem arquivo de catálogo declarado para \(language.rawValue)")
            let stringsText = try source(file)
            let block = try body(of: stringsText, struct: "Strings", language: language)
            var values = block.filter { Self.stringsKeys.contains($0.key) }
            let hubBlock = try body(of: try source(Self.hubFile), struct: "FeatureHubStrings", language: language)
            for key in Self.hubKeys {
                values[key] = hubBlock[key]
            }
            return values
        }
    }

    /// O corpo `static let <idioma> = <Struct>(` do texto de um catálogo.
    private func body(of text: String, struct name: String, language: AppLanguage) throws -> [String: String] {
        let marker = "static let \(Self.staticName(of: language)) = \(name)("
        let start = try XCTUnwrap(text.range(of: marker),
                                  "Bloco de \(name) de \(language.rawValue) não encontrado")
        let rest = text[start.upperBound...]
        let end = try XCTUnwrap(rest.range(of: "\n    )"),
                                "Fim do bloco de \(language.rawValue) não encontrado")
        var map: [String: String] = [:]
        for line in rest[..<end.lowerBound].components(separatedBy: .newlines) {
            guard let entry = Self.entry(in: line) else { continue }
            map[entry.key] = entry.value
        }
        return map
    }

    /// Uma linha de valor no formato `<chave>: "<valor>",`.
    private static func entry(in line: String) -> (key: String, value: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let colon = trimmed.firstIndex(of: ":") else { return nil }
        let key = String(trimmed[trimmed.startIndex..<colon])
        guard let first = key.first, first.isLetter,
              key.allSatisfy({ $0.isLetter || $0.isNumber }) else { return nil }
        var rest = trimmed[trimmed.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        guard rest.hasPrefix("\""), rest.hasSuffix(",") else { return nil }
        rest.removeFirst()
        rest.removeLast()
        guard rest.hasSuffix("\"") else { return nil }
        rest.removeLast()
        return (key, rest)
    }
}
