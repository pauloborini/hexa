// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Os 3 domínios funcionais do Hexa (ARCH-02, DEC-011, spec §2).
enum HexaDomain: String, CaseIterable, Identifiable {
    /// Ambiente & Áudio: Keep Awake, Brilho e Mixer.
    case ambient
    /// Telemetria de Hardware: Sistema (CPU/GPU/Memória), Rede, Disco, Energia e Ventoinhas.
    case telemetry
    /// Ferramentas do Sistema: Utilidades e ferramentas integradas.
    case tools

    /// Alias para manter consistência semântica com referências de controle.
    static let controls = HexaDomain.ambient

    var id: String { rawValue }

    /// As seções do painel que pertencem a este domínio.
    var sections: [PanelSectionID] {
        switch self {
        case .ambient:
            return [.keepAwake, .brightness, .mixer]
        case .telemetry:
            return [.system, .network, .disk, .power, .fanControl]
        case .tools:
            return [.utilities]
        }
    }

    /// Símbolo SF Symbols representativo do domínio (conjunto próprio, DEC-011).
    var symbolName: String {
        switch self {
        case .ambient:
            return "switch.2"
        case .telemetry:
            return "waveform.path.ecg"
        case .tools:
            return "hammer"
        }
    }

    /// Título localizado do domínio, reutilizando o catálogo de strings existente (regra de localização).
    func title(_ s: Strings) -> String {
        switch self {
        case .ambient:
            return FeatureStrings.menuBarAppearance(L10n.shared.language).ambientDomain
        case .telemetry:
            return s.tabMonitor
        case .tools:
            return FeatureStrings.hub(L10n.shared.language).groupTools
        }
    }
}

extension PanelSectionID {
    /// O domínio funcional ao qual esta seção pertence.
    var domain: HexaDomain {
        switch self {
        case .keepAwake, .brightness, .mixer:
            return .ambient
        case .system, .network, .disk, .power, .fanControl:
            return .telemetry
        case .utilities:
            return .tools
        }
    }
}

extension MetricDetailKind {
    /// O domínio funcional ao qual o detalhe de métrica pertence (.telemetry).
    var domain: HexaDomain {
        panelSection.domain
    }
}

/// Seletor de domínios autoral e navegação secundária da menu bar (ARCH-02).
/// Organiza as seções dos módulos nos 3 domínios funcionais (Ambiente, Telemetria e Ferramentas)
/// com superfícies semânticas surfaceInset, cantos suaves Radius.control e navegação
/// secundária contextual de seções.
struct HexaDomainNav: View {
    @Binding var selectedDomain: HexaDomain
    @Binding var selectedSection: PanelSectionID
    var visibleSections: [PanelSectionID]
    var isEmbeddedInNotch: Bool = false

    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedDomain: HexaDomain?
    @FocusState private var focusedSection: PanelSectionID?
    @Namespace private var domainAnimation
    @Namespace private var sectionAnimation
    @State private var hoveredDomain: HexaDomain?
    @State private var hoveredSection: PanelSectionID?

    /// Domínios disponíveis que possuem ao menos uma seção visível.
    private var availableDomains: [HexaDomain] {
        let active = HexaDomain.allCases.filter { domain in
            visibleSections.contains { domain.sections.contains($0) }
        }
        return active.isEmpty ? HexaDomain.allCases : active
    }

    /// Seções visíveis dentro do domínio ativo, preservando a ordem configurada pelo usuário.
    private var visibleSectionsInDomain: [PanelSectionID] {
        visibleSections.filter { selectedDomain.sections.contains($0) }
    }

    var body: some View {
        VStack(spacing: HexaTheme.Spacing.xs) {
            domainSegmentBar

            if visibleSectionsInDomain.count > 1 {
                secondarySectionBar
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var domainSegmentBar: some View {
        HStack(spacing: HexaTheme.Spacing.xs) {
            ForEach(availableDomains) { domain in
                let isActive = selectedDomain == domain
                let isFocused = focusedDomain == domain
                let isHovered = hoveredDomain == domain

                Button {
                    selectDomain(domain)
                } label: {
                    HStack(spacing: HexaTheme.Spacing.xs) {
                        HexaIcons.image(domain.symbolName, size: 11)
                            .font(.hexa(.label))
                        Text(domain.title(l10n.s))
                            .font(.hexa(.label))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 26)
                    .background {
                        if isActive {
                            RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                                .fill(HexaTheme.selectionBg)
                                .overlay(
                                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                                        .strokeBorder(HexaTheme.borderHairline, lineWidth: HexaTheme.hairline)
                                )
                                .matchedGeometryEffect(id: "activeDomainIndicator", in: domainAnimation)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                            .strokeBorder(
                                isFocused ? HexaTheme.focusRing : Color.clear,
                                lineWidth: isFocused ? 2 : HexaTheme.hairline
                            )
                    )
                    .contentShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
                }
                .buttonStyle(.plain)
                .focused($focusedDomain, equals: domain)
                .foregroundStyle((isActive || isHovered) ? HexaTheme.fgPrimary : HexaTheme.fgSecondary)
                .onHover { isHovering in
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                        hoveredDomain = isHovering ? domain : nil
                    }
                }
                .help(domain.title(l10n.s))
                .accessibilityLabel(domain.title(l10n.s))
                .accessibilityAddTraits(isActive ? .isSelected : [])
            }
        }
        .padding(HexaTheme.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                .fill(HexaTheme.surfaceInset)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                .strokeBorder(HexaTheme.borderHairline, lineWidth: HexaTheme.hairline)
        )
    }

    private var secondarySectionBar: some View {
        HStack(spacing: HexaTheme.Spacing.xs) {
            ForEach(visibleSectionsInDomain) { section in
                let isSectionActive = selectedSection == section
                let isFocused = focusedSection == section
                let isHovered = hoveredSection == section

                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.8)) {
                        selectedSection = section
                        focusedSection = section
                    }
                } label: {
                    HStack(spacing: HexaTheme.Spacing.xs) {
                        HexaIcons.image(section.symbolName, size: 11)
                        if visibleSectionsInDomain.count <= 3 {
                            Text(section.title(l10n.s))
                                .font(.hexa(.label))
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 24)
                    .background {
                        if isSectionActive {
                            RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                                .fill(HexaTheme.selectionBg)
                                .overlay(
                                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                                        .strokeBorder(HexaTheme.borderHairline, lineWidth: HexaTheme.hairline)
                                )
                                .matchedGeometryEffect(id: "activeSectionIndicator", in: sectionAnimation)
                        } else {
                            RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                                .fill((isEmbeddedInNotch ? HexaTheme.surfaceInset : HexaTheme.surfaceRaised))
                                .overlay(
                                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                                        .strokeBorder(HexaTheme.borderHairline, lineWidth: HexaTheme.hairline)
                                )
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                            .strokeBorder(
                                isFocused ? HexaTheme.focusRing : Color.clear,
                                lineWidth: isFocused ? 2 : HexaTheme.hairline
                            )
                    )
                    .contentShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
                }
                .buttonStyle(.plain)
                .focused($focusedSection, equals: section)
                .foregroundStyle(isSectionActive ? HexaTheme.accentText : (isHovered ? HexaTheme.fgPrimary : HexaTheme.fgSecondary))
                .onHover { isHovering in
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                        hoveredSection = isHovering ? section : nil
                    }
                }
                .help(section.title(l10n.s))
                .accessibilityLabel(section.title(l10n.s))
                .accessibilityAddTraits(isSectionActive ? .isSelected : [])
            }
        }
    }

    private func selectDomain(_ domain: HexaDomain) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.8)) {
            selectedDomain = domain
            focusedDomain = domain
            let domainVisible = visibleSections.filter { domain.sections.contains($0) }
            if !domainVisible.contains(selectedSection) {
                if let first = domainVisible.first {
                    selectedSection = first
                }
            }
        }
    }
}
