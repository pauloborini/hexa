// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Foundation
import Sparkle

protocol HexaSparkleUpdaterControlling: AnyObject {
    var automaticallyChecksForUpdates: Bool { get set }
    var automaticallyDownloadsUpdates: Bool { get set }
    var sendsSystemProfile: Bool { get set }
    func start() throws
    func checkForUpdates()
}

final class SPUUpdaterControl: HexaSparkleUpdaterControlling {
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
    }

    var automaticallyChecksForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        set { updater.automaticallyChecksForUpdates = newValue }
    }

    var automaticallyDownloadsUpdates: Bool {
        get { updater.automaticallyDownloadsUpdates }
        set { updater.automaticallyDownloadsUpdates = newValue }
    }

    var sendsSystemProfile: Bool {
        get { updater.sendsSystemProfile }
        set { updater.sendsSystemProfile = newValue }
    }

    func start() throws {
        try updater.start()
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }
}

final class SparkleSelfUpdateClient: HexaSelfUpdateClient {
    var onStatus: ((HexaSelfUpdateStatus) -> Void)?

    private let makeStandardDriver: () -> SPUUserDriver
    private let makeUpdater: (SPUUserDriver) -> HexaSparkleUpdaterControlling
    private var driver: HexaSparkleUserDriver?
    private var updater: HexaSparkleUpdaterControlling?

    init(
        makeStandardDriver: @escaping () -> SPUUserDriver = {
            SPUStandardUserDriver(hostBundle: .main, delegate: nil)
        },
        makeUpdater: @escaping (SPUUserDriver) -> HexaSparkleUpdaterControlling = { driver in
            SPUUpdaterControl(
                updater: SPUUpdater(
                    hostBundle: .main,
                    applicationBundle: .main,
                    userDriver: driver,
                    delegate: nil
                )
            )
        }
    ) {
        self.makeStandardDriver = makeStandardDriver
        self.makeUpdater = makeUpdater
    }

    func check() {
        let hexaDriver = HexaSparkleUserDriver(standard: makeStandardDriver(), onStatus: { [weak self] status in
            self?.onStatus?(status)
        })
        driver = hexaDriver
        let updater = makeUpdater(hexaDriver)
        updater.automaticallyChecksForUpdates = false
        updater.automaticallyDownloadsUpdates = false
        updater.sendsSystemProfile = false
        self.updater = updater
        do {
            try updater.start()
            updater.checkForUpdates()
        } catch {
            onStatus?(.failed)
        }
    }
}
