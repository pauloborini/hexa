// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit

struct WindowActivationRetention {
    private(set) var count = 0

    mutating func retain() -> Bool {
        count += 1
        return count == 1
    }

    mutating func release() -> Bool {
        guard count > 0 else { return false }
        count -= 1
        return count == 0
    }
}

/// The app is normally accessory only, with no Dock icon and no place in
/// Command Tab. While a user-facing window needs to remain reachable it becomes
/// a regular app, then returns to its normal policy after the last one closes.
enum WindowActivationPolicy {
    private static var retention = WindowActivationRetention()
    private static var promoted = false

    /// O salto para o AppKit, isolado num par de closures para que o balanço do
    /// contador seja verificável sem uma NSApplication em execução. Em produção
    /// as duas falam com o AppKit; ninguém mais no app as reescreve.
    static var apply: (NSApplication.ActivationPolicy) -> Bool = { NSApp.setActivationPolicy($0) }
    static var current: () -> NSApplication.ActivationPolicy = { NSApp.activationPolicy() }

    static func retain() {
        _ = retention.retain()
        guard !promoted, current() != .regular else { return }
        promoted = apply(.regular)
    }

    static func release() {
        guard retention.release(), promoted else { return }
        if apply(.accessory) {
            promoted = false
        }
    }

    /// Hook de teste: devolve o contador, o estado promovido e o salto para o
    /// estado de lançamento.
    static func resetForTesting() {
        retention = WindowActivationRetention()
        promoted = false
        apply = { NSApp.setActivationPolicy($0) }
        current = { NSApp.activationPolicy() }
    }

    /// Hook de teste: quantos donos mantêm a política promovida agora.
    static var retentionCountForTesting: Int { retention.count }
}
