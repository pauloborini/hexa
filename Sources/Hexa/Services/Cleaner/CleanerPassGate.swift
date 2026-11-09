// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import Combine

/// One pass at a time for the whole Cleaner. The workspace and the automatic
/// scheduler each run their own JunkCleaner, so the lock lives here: the pass
/// that starts first holds it until it ends, and the other one is refused
/// rather than running over the same paths. Main thread only.
final class CleanerPassGate: ObservableObject {
    static let shared = CleanerPassGate()

    /// The kind of pass. Each kind has exactly one JunkCleaner.
    enum Holder: Equatable {
        case manual
        case automatic
    }

    /// Who holds the gate, or nil while no pass runs. The views observe it.
    @Published private(set) var holder: Holder?

    /// The app uses `shared`; tests build their own gates to stay apart.
    init() {}

    /// Takes the gate for `requester`. Succeeds when the gate is free or the
    /// requester already holds it; fails while the other kind holds it.
    func acquire(_ requester: Holder) -> Bool {
        guard let current = holder else {
            holder = requester
            return true
        }
        return current == requester
    }

    /// Frees the gate only when `requester` holds it, so a reset of one kind
    /// of pass cannot end the other.
    func release(_ requester: Holder) {
        if holder == requester { holder = nil }
    }
}
