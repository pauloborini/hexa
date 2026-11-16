// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Combine
import Foundation

enum HexaSelfUpdateStatus: Equatable {
    case idle
    case checking
    case upToDate
    case available
    case failed
    case developerBuild
}

final class HexaSelfUpdateController: ObservableObject {
    static let shared = HexaSelfUpdateController()

    @Published private(set) var status: HexaSelfUpdateStatus = .idle

    private let isDeveloperBuild: Bool
    private let clientFactory: HexaSelfUpdateClientFactory
    private var activeClient: HexaSelfUpdateClient?

    init(
        isDeveloperBuild: Bool = AppInfo.isDeveloperBuild,
        clientFactory: HexaSelfUpdateClientFactory = .production
    ) {
        self.isDeveloperBuild = isDeveloperBuild
        self.clientFactory = clientFactory
    }

    func apply(_ status: HexaSelfUpdateStatus) {
        self.status = status
    }

    func requestCheck() {
        if isDeveloperBuild {
            apply(.developerBuild)
            return
        }
        if status == .checking {
            return
        }
        apply(.checking)
        let client = clientFactory.make()
        client.onStatus = { [weak self] status in
            if Thread.isMainThread {
                self?.apply(status)
            } else {
                DispatchQueue.main.async {
                    self?.apply(status)
                }
            }
        }
        activeClient = client
        client.check()
    }
}
