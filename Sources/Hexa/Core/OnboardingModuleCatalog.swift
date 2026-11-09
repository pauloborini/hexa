// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import Foundation

/// As linhas do passo de módulos, na ordem decidida (D9): os módulos do
/// escopo, com o Fan Control em linha própria, o Kill Process e o Port Manager
/// separados e a luz do teclado viajando com o Brilho.
///
/// O grupo é a unidade que o usuário vê, e cada caso carrega a lista final
/// COMPLETA dos recursos que ele cobre. A união das 15 listas é exatamente
/// `AppFeature.allCases`: um recurso novo no catálogo do app obriga a uma
/// decisão explícita sobre a linha que o recebe, em vez de não aparecer em
/// lugar nenhum.
enum OnboardingModule: String, CaseIterable {
    case appUpdates
    case monitor
    case fanControl
    case uninstaller
    case cleanerAndMaintenance
    case mediaTools
    case dynamicIsland
    case mixer
    case keepAwake
    case brightness
    case killProcess
    case portManager
    case dockDisplayLock
    case menuBarHiding
    case screenCapture

    /// A lista final completa do grupo, nunca um subconjunto: é ela que a linha
    /// instala e desinstala de uma vez.
    var features: [AppFeature] {
        switch self {
        case .appUpdates:
            return [.appUpdates]
        case .monitor:
            return [.monitorCPU, .monitorGPU, .monitorMemory, .monitorNetwork, .monitorDisk,
                    .monitorPower, .connectedDevices]
        case .fanControl:
            return [.fanControl]
        case .uninstaller:
            return [.uninstaller]
        case .cleanerAndMaintenance:
            return [.cleaner, .maintenanceTasks]
        case .mediaTools:
            return [.mediaTools]
        case .dynamicIsland:
            return [.notch] + AppFeature.dynamicIslandExtensions
        case .mixer:
            return [.mixer]
        case .keepAwake:
            return [.keepAwake]
        // A luz do teclado viaja com o Brilho: ela é um módulo da ilha, e a
        // ilha aparece na própria linha.
        case .brightness:
            return [.brightness]
        case .killProcess:
            return [.killProcess]
        case .portManager:
            return [.portManager]
        case .dockDisplayLock:
            return [.dockDisplayLock]
        case .menuBarHiding:
            return [.menuBarHiding]
        case .screenCapture:
            return [.screenshot, .screenOCR]
        }
    }

    /// O título da linha. Os grupos de um recurso só reaproveitam o nome vivo
    /// da feature; os grupos compostos usam o nome da seção ou a chave de grupo
    /// do passo, nunca uma montagem por concatenação.
    func title(_ language: AppLanguage) -> String {
        let s = Strings.localized(language)
        let hub = FeatureStrings.hub(language)
        switch self {
        case .cleanerAndMaintenance:
            return hub.onboardingModuleCleanerTitle
        case .monitor:
            return hub.groupMonitor
        case .dynamicIsland, .screenCapture, .appUpdates, .fanControl, .uninstaller, .mediaTools,
             .mixer, .keepAwake, .brightness, .killProcess, .portManager, .dockDisplayLock, .menuBarHiding:
            return features[0].hubTitle(s, hub: hub)
        }
    }

    /// A descrição da linha, na mesma regra do título.
    func description(_ language: AppLanguage) -> String {
        let hub = FeatureStrings.hub(language)
        switch self {
        case .monitor:
            return hub.onboardingModuleMonitorDescription
        case .cleanerAndMaintenance:
            return hub.onboardingModuleCleanerDescription
        case .dynamicIsland:
            return hub.onboardingModuleIslandDescription
        case .screenCapture:
            return hub.onboardingModuleCaptureDescription
        case .appUpdates, .fanControl, .uninstaller, .mediaTools, .mixer, .keepAwake, .brightness,
             .killProcess, .portManager, .dockDisplayLock, .menuBarHiding:
            return features[0].hubDescription(hub)
        }
    }

    /// Resolvidos no idioma do app, a cada render: nenhuma cópia do catálogo de
    /// textos fica guardada na tela.
    var title: String { title(L10n.shared.language) }

    var description: String { description(L10n.shared.language) }
}

/// O que o passo de módulos faz com os grupos: lê o estado real de cada recurso
/// e escreve pelo mesmo portão da central de Ajustes.
enum OnboardingModuleCatalog {
    /// A escrita da linha: a lista final completa do grupo e o sentido pedido.
    typealias Write = ([AppFeature], Bool) -> Void

    /// Produção: o portão único de instalar e desinstalar, com a confirmação de
    /// descarte da captura respeitada, como decidido em D13 (D12 para a ilha).
    static let hubGate: Write = { features, available in
        FeatureRuntime.shared.setAvailable(features, available, keepListOnDiscardCancel: true)
    }

    /// Quantos recursos do grupo estão instalados, lido recurso a recurso da
    /// mesma chave que a central de Ajustes lê. Nada é memorizado: cada chamada
    /// reflete o estado do app naquele instante.
    static func installedCount(in group: OnboardingModule,
                               isAvailable: (AppFeature) -> Bool = { $0.isAvailable }) -> Int {
        group.features.filter(isAvailable).count
    }

    /// A linha está ligada quando todos os recursos do grupo estão instalados, e
    /// parcial quando alguns estão.
    static func isInstalled(_ group: OnboardingModule,
                            isAvailable: (AppFeature) -> Bool = { $0.isAvailable }) -> Bool {
        group.features.allSatisfy(isAvailable)
    }

    /// Estado parcial: parte do grupo instalada, parte não. É o que a linha
    /// mostra com a contagem e a barra de proporção.
    static func isPartiallyInstalled(_ group: OnboardingModule,
                                     isAvailable: (AppFeature) -> Bool = { $0.isAvailable }) -> Bool {
        let installed = installedCount(in: group, isAvailable: isAvailable)
        return installed > 0 && installed < group.features.count
    }

    /// Liga ou desliga a linha: sempre a lista final completa do grupo, nunca um
    /// subconjunto, porque a semântica do portão é absoluta por recurso.
    static func setInstalled(_ group: OnboardingModule, _ on: Bool, write: Write = hubGate) {
        write(group.features, on)
    }
}
