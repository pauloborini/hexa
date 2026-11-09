// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import Foundation

/// Os quatro passos do roteiro de primeira execução, na ordem decidida (D1).
/// O valor gravado é o `rawValue`, e `.done` vale também como "primeira
/// execução concluída".
enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case modules = 1
    case permissions = 2
    case done = 3
}

/// A única autoridade sobre `DefaultsKey.onboardingStep`: sabe dizer se a tela
/// deve aparecer, em que passo retomar e o que gravar.
///
/// A ausência da chave significa "nunca começou" e é distinguível de qualquer
/// passo gravado, inclusive do primeiro. Por isso a chave NÃO entra em
/// `Defaults.registeredDefaults`: registrada, ela devolveria `0` em vez de
/// ausente e a decisão de primeira execução perderia o sentido.
enum OnboardingProgress {
    /// O passo gravado, ou `nil` quando a chave está ausente, guarda outro tipo
    /// ou um valor fora da faixa (um build futuro, por exemplo).
    static func step(in defaults: UserDefaults = .standard) -> OnboardingStep? {
        guard let recorded = recordedNumber(in: defaults) else { return nil }
        return OnboardingStep(rawValue: recorded)
    }

    /// A decisão de lançamento. `skipStartupWindows` é a guarda que já evita
    /// abrir duas vezes a mesma coisa depois de um arranque que morreu, e mora
    /// aqui para ser verificável sem AppKit.
    static func shouldPresent(in defaults: UserDefaults = .standard,
                              skipStartupWindows: Bool = false) -> Bool {
        guard !skipStartupWindows else { return false }
        return step(in: defaults) != .done
    }

    /// Onde o roteiro retoma: o primeiro passo quando nunca começou.
    static func resumeStep(in defaults: UserDefaults = .standard) -> OnboardingStep {
        step(in: defaults) ?? .welcome
    }

    /// Grava o ponto de retomada. Escrita absoluta: o marcador inteiro passa a
    /// ser o passo registrado, e nenhuma outra chave é tocada.
    static func record(_ step: OnboardingStep, in defaults: UserDefaults = .standard) {
        defaults.set(step.rawValue, forKey: DefaultsKey.onboardingStep)
    }

    /// Lê apenas um inteiro de verdade: um `Bool`, um texto ou um número
    /// fracionário gravado na chave devolve `nil`, e a tela abre no primeiro
    /// passo em vez de interpretar lixo como progresso.
    private static func recordedNumber(in defaults: UserDefaults) -> Int? {
        guard let value = defaults.object(forKey: DefaultsKey.onboardingStep) as? NSNumber,
              CFGetTypeID(value) != CFBooleanGetTypeID(),
              !CFNumberIsFloatType(unsafeBitCast(value, to: CFNumber.self))
        else { return nil }
        return value.intValue
    }
}
