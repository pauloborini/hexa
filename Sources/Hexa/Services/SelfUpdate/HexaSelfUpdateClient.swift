// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

protocol HexaSelfUpdateClient: AnyObject {
    var onStatus: ((HexaSelfUpdateStatus) -> Void)? { get set }
    func check()
}

struct HexaSelfUpdateClientFactory {
    var make: () -> HexaSelfUpdateClient

    static let production = HexaSelfUpdateClientFactory(make: { SparkleSelfUpdateClient() })
}
