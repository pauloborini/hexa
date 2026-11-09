// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

/// Módulos da sidebar que agrupam funcionalidades relacionadas num único item.
/// Modelo puro: não conhece SwiftUI nem disponibilidade real; a checagem de
/// disponibilidade entra como closure para manter o comportamento testável.
enum SidebarModule: CaseIterable {
    case maintenance, processesAndPorts, screenCapture, energyAndDisplay

    /// Membros na ordem do segmento.
    var members: [AppFeature] {
        switch self {
        case .maintenance: return [.cleaner, .maintenanceTasks, .uninstaller, .appUpdates]
        case .processesAndPorts: return [.killProcess, .portManager]
        case .screenCapture: return [.screenshot, .screenOCR]
        case .energyAndDisplay: return [.keepAwake, .brightness]
        }
    }

    /// Grupo da sidebar ao qual o módulo pertence.
    var group: FeatureGroup {
        switch self {
        case .maintenance, .processesAndPorts, .screenCapture: return .tools
        case .energyAndDisplay: return .energyDisplay
        }
    }

    /// Módulo que contém a funcionalidade, ou nil se ela não pertence a nenhum módulo.
    static func module(containing feature: AppFeature) -> SidebarModule? {
        allCases.first { $0.members.contains(feature) }
    }

    /// Membros disponíveis, mantendo a ordem.
    func availableMembers(isAvailable: (AppFeature) -> Bool) -> [AppFeature] {
        members.filter(isAvailable)
    }

    /// Membro aberto ao clicar na linha: o lembrado se ainda for membro disponível;
    /// senão o primeiro disponível; senão nil.
    func defaultMember(remembered: AppFeature?, isAvailable: (AppFeature) -> Bool) -> AppFeature? {
        if let remembered, members.contains(remembered), isAvailable(remembered) {
            return remembered
        }
        return availableMembers(isAvailable: isAvailable).first
    }
}
