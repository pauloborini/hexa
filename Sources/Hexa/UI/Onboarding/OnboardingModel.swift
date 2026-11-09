// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import Combine
import Foundation

/// O roteiro de 4 passos: dono do passo atual e da escrita do marcador.
///
/// Avançar grava o novo passo; voltar não grava nada, porque o marcador guarda
/// o ponto de retomada e voltar não é progresso. A reexecução pela tela Sobre
/// não regrava o ponto de retomada: ela só grava a conclusão, quando chega ao
/// passo de concluído.
final class OnboardingModel: ObservableObject {
    @Published private(set) var step: OnboardingStep
    @Published private(set) var isRedoing: Bool
    /// O identificador da demanda de sondagem do passo de permissões. Vive no
    /// modelo, e não na view, para que o fechamento da janela libere a demanda
    /// mesmo com a view já descartada: o passo registra e libera esta mesma
    /// identidade, e o `OnboardingWindowSession` a libera no fechamento.
    let permissionDemandID: UUID
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard,
         isRedoing: Bool = false,
         permissionDemandID: UUID = UUID()) {
        self.defaults = defaults
        self.isRedoing = isRedoing
        self.permissionDemandID = permissionDemandID
        self.step = isRedoing ? .welcome : OnboardingProgress.resumeStep(in: defaults)
    }

    func advance() {
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        step = next
        guard !isRedoing || next == .done else { return }
        OnboardingProgress.record(next, in: defaults)
    }

    func back() {
        guard let previous = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        step = previous
    }
}
