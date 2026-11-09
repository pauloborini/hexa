// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Rail vertical de domínios do painel horizontal (Fase 2 do redesign).
/// Coluna à esquerda: domínios no topo e, abaixo, as seções do domínio
/// ativo em ORDEM ALFABÉTICA pelo nome exibido. Seleção neutra
/// (`selection.bg` + `fg.primary`, spec §5), sem fill de accent.
/// Composição local em vez de `HexaSegmentControl`: as linhas da rail têm
/// largura variável, ícone + rótulo empilhados verticalmente e agrupamento
/// em dois níveis (domínio/seção) — anatomia que diverge do segmento
/// uniforme do primitive (registro na spec §7).
/// Só é usado pelo layout de rail de `MenuPanelView` (`navigablePanel` e `metricPanel`), inalcançável no grafo de chamadas atual.
struct HexaDomainRail: View {
    @Binding var selectedDomain: HexaDomain
    @Binding var selectedSection: PanelSectionID
    var visibleSections: [PanelSectionID]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var l10n = L10n.shared
    @FocusState private var focusedDomain: HexaDomain?
    @FocusState private var focusedSection: PanelSectionID?
    @State private var hoveredDomain: HexaDomain?
    @State private var hoveredSection: PanelSectionID?

    /// Domínios disponíveis que possuem ao menos uma seção visível.
    private var availableDomains: [HexaDomain] {
        let active = HexaDomain.allCases.filter { domain in
            visibleSections.contains { domain.sections.contains($0) }
        }
        return active.isEmpty ? HexaDomain.allCases : active
    }

    /// Seções visíveis do domínio ativo em ordem alfabética pelo nome
    /// exibido (sequência própria do hexa; DEC-011).
    private var sortedSectionsInDomain: [PanelSectionID] {
        visibleSections
            .filter { selectedDomain.sections.contains($0) }
            .sorted { $0.title(l10n.s).localizedStandardCompare($1.title(l10n.s)) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            ForEach(availableDomains) { domain in
                domainRow(domain)
            }

            if sortedSectionsInDomain.count > 1 {
                HairlineDivider()
                    .padding(.vertical, HexaTheme.Spacing.xs)

                ForEach(sortedSectionsInDomain) { section in
                    sectionRow(section)
                }
            }

            Spacer(minLength: 0)
        }
            .padding(HexaTheme.Spacing.s)
        }
        .scrollIndicators(.hidden)
        .frame(width: HexaPanelMetrics.railWidth, alignment: .leading)
        .background(HexaTheme.surfaceRaised)
    }

    private func domainRow(_ domain: HexaDomain) -> some View {
        railButton(
            icon: domain.symbolName,
            title: domain.title(l10n.s),
            isActive: selectedDomain == domain,
            isFocused: focusedDomain == domain,
            isHovered: hoveredDomain == domain
        ) {
            selectDomain(domain)
        }
        .focused($focusedDomain, equals: domain)
        .onHover { isHovering in
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                hoveredDomain = isHovering ? domain : nil
            }
        }
        .accessibilityAddTraits(selectedDomain == domain ? .isSelected : [])
    }

    private func sectionRow(_ section: PanelSectionID) -> some View {
        railButton(
            icon: section.symbolName,
            title: section.title(l10n.s),
            isActive: selectedSection == section,
            isFocused: focusedSection == section,
            isHovered: hoveredSection == section,
            indent: true
        ) {
            withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.8)) {
                selectedSection = section
                focusedSection = section
            }
        }
        .focused($focusedSection, equals: section)
        .onHover { isHovering in
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                hoveredSection = isHovering ? section : nil
            }
        }
        .accessibilityAddTraits(selectedSection == section ? .isSelected : [])
    }

    /// Linha da rail: ícone + rótulo. Inativo `fg.secondary`, hover SÓ
    /// clareia o texto (`fg.primary`, sem fill), ativo `fg.primary` sobre
    /// `selection.bg`, foco com anel `focus.ring`.
    private func railButton(
        icon: String,
        title: String,
        isActive: Bool,
        isFocused: Bool,
        isHovered: Bool,
        indent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: HexaTheme.Spacing.s) {
                HexaIcons.image(icon, size: 13)
                    .font(.hexa(.body))
                    .foregroundStyle(isActive || isHovered ? HexaTheme.fgPrimary : HexaTheme.fgSecondary)
                Text(title)
                    .font(.hexa(.label))
                    .lineLimit(1)
                    .foregroundStyle(isActive || isHovered ? HexaTheme.fgPrimary : HexaTheme.fgSecondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, HexaTheme.Spacing.s)
            .padding(.leading, indent ? HexaTheme.Spacing.m : 0)
            .frame(height: HexaTheme.Density.rowCompact)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                        .fill(HexaTheme.selectionBg)
                }
            }
            .overlay {
                // Anel de foco com offset de 1 px (padrão spec §5, como no
                // HexaSegmentControl): o traço não cola no fill.
                if isFocused {
                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                        .strokeBorder(HexaTheme.focusRing, lineWidth: 2)
                        .padding(1)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
    }

    private func selectDomain(_ domain: HexaDomain) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.8)) {
            selectedDomain = domain
            focusedDomain = domain
            let domainVisible = sortedSectionsInDomain
            if !domainVisible.contains(selectedSection) {
                selectedSection = domainVisible.first ?? selectedSection
            }
        }
    }
}
