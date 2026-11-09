// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import Foundation

/// A lista de permissões do passo de permissões da primeira execução.
///
/// A lista é a união real de `AppFeature.permissions` sobre os recursos
/// instalados, recalculada cada vez que o passo aparece: o passo de módulos
/// pode ter desinstalado um recurso entre duas visitas, e nada é memorizado
/// (D4). Ela substitui a regra antiga do catálogo, que filtrava só
/// Acessibilidade e Gravação de Tela e devolvia lista vazia para o Cleaner e o
/// Desinstalador, contra D4.
enum OnboardingPermissionSet {
    /// As permissões que os recursos instalados exigem, sem repetição e na
    /// ordem de `AppPermission.allCases`, a mesma do catálogo do Portal: o
    /// passo e o Portal leem as permissões no mesmo lugar.
    static func required(for installed: [AppFeature]) -> [AppPermission] {
        let needed = Set(installed.flatMap { $0.permissions })
        return AppPermission.allCases.filter(needed.contains)
    }

    /// Os grupos do passo de módulos que contêm ao menos um recurso instalado
    /// que exige a permissão. É a lista de "quem usa" do passo: no onboarding a
    /// pergunta é qual módulo marcado pede a permissão, não quem a usa agora.
    static func modulesRequiring(_ permission: AppPermission,
                                 in installed: [AppFeature],
                                 groups: [OnboardingModule] = OnboardingModule.allCases) -> [OnboardingModule] {
        groups.filter { group in
            group.features.contains { feature in
                installed.contains(feature) && feature.permissions.contains(permission)
            }
        }
    }

    /// A decisão do botão de conceder da linha: aparece enquanto a permissão não
    /// está concedida e o macOS ainda aceita um pedido (D14). A linha do Portal
    /// chama esta função, então a decisão tem um lugar só.
    static func showsGrantAction(for status: PermissionPortalRow.Status, canAskAgain: Bool) -> Bool {
        canAskAgain && status != .granted
    }

    /// A leitura do estado de Automação de Finder e Terminal, fora da thread
    /// principal e de volta na principal, como o Portal faz: a ida e volta de
    /// Apple Events pode bloquear. Os leitores entram por parâmetro para que a
    /// prova do salto não dependa dos singletons do app.
    static func readAutomation(
        read: @escaping (Permissions.AutomationTarget) -> Permissions.AutomationStatus = Permissions.automationStatus(for:),
        deliver: @escaping ([Permissions.AutomationTarget: Permissions.AutomationStatus]) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let statuses = Dictionary(uniqueKeysWithValues: Permissions.AutomationTarget.allCases.map { target in
                (target, read(target))
            })
            DispatchQueue.main.async {
                deliver(statuses)
            }
        }
    }
}
