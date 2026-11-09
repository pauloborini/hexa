// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import SwiftUI

// MARK: - Botão de ícone

/// Botão de ícone (spec §7): o único ícone que anda dentro de caixa própria.
/// `.regular`: 28 pt com ícone 14; `.small`: 20 pt com ícone 12. Mesmos
/// estados do botão de ação: hover `selection.bg` a 70%, foco com anel,
/// desabilitado em inset a 50%.
///
/// `iconTint`: cor opcional aplicada somente ao ícone, para botões de ícone
/// com estado de consumo (ex.: tokens `status.ok`/`status.warning`/
/// `status.danger` via `HexaTheme`). O container permanece nos tokens
/// padrão (fill, raio, tamanhos, anel de foco); o chamador passa o token.
struct HexaIconButtonStyle: ButtonStyle {
    enum Variant { case regular, small }
    var variant: Variant = .regular
    var iconTint: Color? = nil

    init(variant: Variant = .regular, iconTint: Color? = nil) {
        self.variant = variant
        self.iconTint = iconTint
    }

    init(size: Variant, iconTint: Color? = nil) {
        self.variant = size
        self.iconTint = iconTint
    }

    func makeBody(configuration: Configuration) -> some View {
        HexaIconButtonBody(configuration: configuration, variant: variant, iconTint: iconTint)
    }

    private struct HexaIconButtonBody: View {
        let configuration: Configuration
        let variant: Variant
        var iconTint: Color? = nil
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.isFocused) private var isFocused
        @State private var isHovered = false

        private var side: CGFloat {
            variant == .regular ? HexaTheme.Density.rowCompact : HexaTheme.Spacing.xl
        }
        private var iconSize: CGFloat {
            variant == .regular ? HexaIconMetrics.label : HexaIconMetrics.small
        }

        var body: some View {
            configuration.label
                .foregroundStyle(iconTint ?? (isEnabled ? HexaTheme.fgPrimary : HexaTheme.fgDisabled))
                .frame(width: side, height: side)
                .background {
                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                        .fill(isEnabled
                            ? (configuration.isPressed
                                ? HexaTheme.selectionBg
                                : (isHovered ? HexaTheme.selectionBg.opacity(0.7) : HexaTheme.surfaceInset))
                            : HexaTheme.surfaceInset.opacity(0.5))
                }
                .overlay {
                    if isFocused && isEnabled {
                        RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                            .strokeBorder(HexaTheme.focusRing, lineWidth: 2)
                            .padding(1)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
                .onHover { isHovered = $0 }
        }
    }
}

/// Componente pronto do botão de ícone (spec §7): ícone + rótulo de
/// acessibilidade obrigatório, nos dois tamanhos do contrato.
///
/// `iconTint`: cor opcional do ícone para estados de consumo
/// (`status.*` via `HexaTheme`); o container segue os tokens padrão.
struct HexaIconButton: View {
    let icon: String
    /// Rótulo acessível: um botão de ícone nunca fica sem nome.
    let label: String
    var variant: HexaIconButtonStyle.Variant = .regular
    var iconTint: Color? = nil
    let action: () -> Void

    init(icon: String, label: String, variant: HexaIconButtonStyle.Variant = .regular, iconTint: Color? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.variant = variant
        self.iconTint = iconTint
        self.action = action
    }

    init(icon: String, label: String, size: HexaIconButtonStyle.Variant, iconTint: Color? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.variant = size
        self.iconTint = iconTint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HexaIcons.image(icon, size: variant == .regular ? HexaIconMetrics.label : HexaIconMetrics.small)
        }
        .buttonStyle(HexaIconButtonStyle(variant: variant, iconTint: iconTint))
        .accessibilityLabel(label)
    }
}

// MARK: - Botão de acesso

/// Ação de acesso (spec §7): pedir permissão do sistema ou abrir Ajustes do
/// sistema — qualquer ação que SAI do hexa para uma superfície do sistema.
/// Ícone do assunto, título e glifo de saída, sobre o estilo canônico de ação.
struct HexaAccessButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: HexaTheme.Spacing.s) {
                HexaIcons.image(icon, size: HexaIconMetrics.label)
                    .foregroundStyle(HexaTheme.fgSecondary)
                Text(title)
                    .font(.hexa(.label))
                    .lineLimit(1)
                Spacer(minLength: 0)
                HexaIcons.image("arrow.up.right", size: HexaIconMetrics.small)
                    .foregroundStyle(HexaTheme.fgTertiary)
            }
        }
        .buttonStyle(HexaActionButtonStyle())
    }
}

// MARK: - Item de lista

/// Item de lista (spec §7): a linha inteira é clicável — ícone opcional,
/// título, legenda opcional e slot à direita. Ícone aqui é conteúdo da
/// linha: sem caixa. Hover SÓ clareia o texto; seleção = `selection.bg`.
/// A linha da sidebar é o `HexaSidebarRow` (com dot); este primitivo serve
/// às listas de conteúdo (apps, processos, dispositivos).
struct HexaListItem<Accessory: View>: View {
    var icon: String? = nil
    var nsImage: NSImage? = nil
    let title: String
    var caption: String? = nil
    var selected: Bool = false
    @ViewBuilder let accessory: () -> Accessory
    let action: (() -> Void)?
    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    init(icon: String? = nil,
         nsImage: NSImage? = nil,
         title: String,
         caption: String? = nil,
         selected: Bool = false,
         @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() },
         action: (() -> Void)? = nil) {
        self.icon = icon
        self.nsImage = nsImage
        self.title = title
        self.caption = caption
        self.selected = selected
        self.accessory = accessory
        self.action = action
    }

    var body: some View {
        if let action {
            Button(action: action) {
                rowContent
            }
            .buttonStyle(.plain)
            .focused($isFocused)
            .onHover { isHovered = $0 }
            .accessibilityAddTraits(selected ? .isSelected : [])
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(spacing: HexaTheme.Spacing.m) {
            if let nsImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .frame(width: 18, height: 18)
            } else if let icon {
                HexaIcons.image(icon, size: HexaIconMetrics.label)
                    .foregroundStyle(isHovered ? HexaTheme.fgPrimary : HexaTheme.fgSecondary)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.hexa(.body))
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let caption {
                    Text(caption)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: HexaTheme.Spacing.xs)
            accessory()
        }
        .foregroundStyle(HexaTheme.fgPrimary)
        .padding(.horizontal, HexaTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: HexaTheme.Density.rowStandard)
        .background {
            if selected {
                RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                    .fill(HexaTheme.selectionBg)
            }
        }
        .overlay {
            if isFocused && action != nil {
                RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                    .strokeBorder(HexaTheme.focusRing, lineWidth: 2)
                    .padding(1)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
    }
}
