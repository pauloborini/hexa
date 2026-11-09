// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Estado ocupado/carregando centralizado (spec §7): spinner com mensagem
/// opcional, detalhe opcional e ação opcional (ex.: cancelar durante um
/// scan). Duas variantes observadas em consumidores reais: `.workspace`
/// (spinner grande, respiro `Spacing.l`, altura mínima de página) e
/// `.compact` (spinner pequeno, respiro `Spacing.s`, painel). Conteúdo
/// extra entre mensagem e ação (ex.: app alvo do desinstalador) vai no
/// slot `accessory`; a moldura externa (altura fixa, preenchimento) fica
/// no call site.
struct HexaBusyState<Accessory: View>: View {
    /// Variantes observadas: página de workspace e painel compacto.
    enum Variant {
        case workspace
        case compact
    }

    let variant: Variant
    let message: String?
    var detail: String?
    var actionTitle: String?
    var action: (() -> Void)?
    var accessory: Accessory

    init(
        variant: Variant,
        message: String? = nil,
        detail: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.variant = variant
        self.message = message
        self.detail = detail
        self.actionTitle = actionTitle
        self.action = action
        self.accessory = accessory()
    }

    /// Sem slot de acessório (`Accessory == EmptyView`): um init dedicado
    /// evita inferir `Accessory` por expressão default do closure, que o
    /// compilador já rejeita em future language mode.
    init(
        variant: Variant,
        message: String? = nil,
        detail: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) where Accessory == EmptyView {
        self.init(
            variant: variant,
            message: message,
            detail: detail,
            actionTitle: actionTitle,
            action: action,
            accessory: { EmptyView() }
        )
    }

    var body: some View {
        VStack(spacing: variant == .workspace ? HexaTheme.Spacing.l : HexaTheme.Spacing.s) {
            Spacer(minLength: variant == .workspace ? 0 : 24)
            ProgressView()
                .controlSize(variant == .workspace ? .large : .small)
            if let message {
                Text(message)
                    .font(.hexa(.body))
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
            if let detail {
                Text(detail)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgTertiary)
            }
            accessory
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .controlSize(variant == .workspace ? .large : .small)
            }
            Spacer(minLength: variant == .workspace ? 0 : 24)
        }
        .frame(maxWidth: .infinity, minHeight: variant == .workspace ? 320 : 0)
    }
}
