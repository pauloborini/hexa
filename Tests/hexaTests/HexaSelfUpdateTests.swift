// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import Combine
import Foundation
import ObjectiveC
import Sparkle
import XCTest

@testable import Hexa

final class HexaSelfUpdateTests: XCTestCase {
    func test_init_does_not_check() {
        let spy = ClientSpy()
        _ = HexaSelfUpdateController(
            isDeveloperBuild: false,
            clientFactory: HexaSelfUpdateClientFactory(make: spy.make)
        )
        XCTAssertEqual(spy.makeCount, 0)
        XCTAssertEqual(spy.checkCount, 0)
    }

    func test_production_client_disables_automatic_and_profile() {
        let recorder = RecordingUpdater()
        let client = SparkleSelfUpdateClient(
            makeStandardDriver: { RecordingUserDriver() },
            makeUpdater: { _ in recorder }
        )
        client.check()
        XCTAssertEqual(recorder.flagsAtStart?.autoCheck, false)
        XCTAssertEqual(recorder.flagsAtStart?.autoDownload, false)
        XCTAssertEqual(recorder.flagsAtStart?.profile, false)
        XCTAssertNil(recorder.assignedFeedURL)
        XCTAssertTrue(recorder.assignedChannels.isEmpty)
        let source = try! String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Sources/Hexa/Services/SelfUpdate/SparkleSelfUpdateClient.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(source.contains("allowedChannels"))
        XCTAssertFalse(source.contains("setFeedURL"))
        XCTAssertFalse(source.contains("beta"))
    }

    func test_background_status_applies_on_main() {
        let client = SpyClient()
        let controller = HexaSelfUpdateController(
            isDeveloperBuild: false,
            clientFactory: HexaSelfUpdateClientFactory(make: { client })
        )
        let applied = expectation(description: "failed status on main")
        client.onCheck = {
            DispatchQueue.global(qos: .userInitiated).async {
                client.onStatus?(.failed)
            }
        }
        let observer = controller.$status.sink { status in
            if status == .failed {
                XCTAssertTrue(Thread.isMainThread)
                applied.fulfill()
            }
        }
        controller.requestCheck()
        wait(for: [applied], timeout: 1)
        _ = observer
    }

    func test_developer_build_skips_sparkle() {
        let spy = ClientSpy()
        let controller = HexaSelfUpdateController(
            isDeveloperBuild: true,
            clientFactory: HexaSelfUpdateClientFactory(make: spy.make)
        )
        controller.requestCheck()
        XCTAssertEqual(controller.status, .developerBuild)
        XCTAssertEqual(spy.makeCount, 0)
        XCTAssertEqual(spy.checkCount, 0)
    }

    func test_production_factory_returns_sparkle_client() {
        let client = HexaSelfUpdateClientFactory.production.make()
        XCTAssertTrue(client is SparkleSelfUpdateClient)
    }

    func test_user_driver_forwards_found_to_standard() throws {
        let standard = RecordingUserDriver()
        var statuses: [HexaSelfUpdateStatus] = []
        let driver = HexaSparkleUserDriver(standard: standard) { statuses.append($0) }
        let item = try makeAppcastItem()
        let state = try makeUserUpdateState()

        driver.showUpdateNotFoundWithError(NSError(domain: "test", code: 1), acknowledgement: {})
        XCTAssertEqual(statuses.last, .upToDate)
        XCTAssertEqual(standard.updateNotFoundCount, 0)
        XCTAssertEqual(standard.userCheckCount, 0)

        driver.showUpdaterError(NSError(domain: "test", code: 2), acknowledgement: {})
        XCTAssertEqual(statuses.last, .failed)
        XCTAssertEqual(standard.updaterErrorCount, 0)

        driver.showUpdateFound(with: item, state: state, reply: { _ in })
        XCTAssertEqual(statuses.last, .available)
        XCTAssertEqual(standard.updateFoundCount, 1)

        driver.showDownloadInitiated(cancellation: {})
        XCTAssertEqual(standard.downloadInitiatedCount, 1)
        XCTAssertEqual(standard.userCheckCount, 0)
    }

    private func makeAppcastItem() throws -> SUAppcastItem {
        var failure: NSString?
        let item = SUAppcastItem(
            dictionary: [
                "title": "Hexa",
                "sparkle:version": "9.0.0",
                "sparkle:shortVersionString": "9.0.0",
                "enclosure": [
                    "url": "https://github.com/pauloborini/hexa/releases/download/v9.0.0/hexa-9.0.0-arm64.dmg",
                    "sparkle:edSignature": "AAAA",
                    "length": "1",
                    "type": "application/octet-stream"
                ]
            ],
            relativeTo: URL(string: "https://github.com/pauloborini/hexa/releases/latest/download/appcast.xml"),
            failureReason: &failure
        )
        if let item {
            return item
        }
        struct ItemError: Error {}
        throw ItemError()
    }

    private func makeUserUpdateState() throws -> SPUUserUpdateState {
        let selector = NSSelectorFromString("initWithStage:userInitiated:")
        guard let allocated = class_createInstance(SPUUserUpdateState.self, 0) as AnyObject? else {
            struct AllocError: Error {}
            throw AllocError()
        }
        typealias InitIMP = @convention(c) (AnyObject, Selector, Int, Bool) -> Unmanaged<SPUUserUpdateState>
        guard let method = class_getInstanceMethod(SPUUserUpdateState.self, selector) else {
            struct MethodError: Error {}
            throw MethodError()
        }
        let fn = unsafeBitCast(method_getImplementation(method), to: InitIMP.self)
        return fn(allocated, selector, 0, true).takeUnretainedValue()
    }
}

private final class ClientSpy {
    var makeCount = 0
    var checkCount = 0

    func make() -> HexaSelfUpdateClient {
        makeCount += 1
        let client = SpyClient()
        client.onCheck = { [weak self] in self?.checkCount += 1 }
        return client
    }
}

private final class SpyClient: HexaSelfUpdateClient {
    var onStatus: ((HexaSelfUpdateStatus) -> Void)?
    var onCheck: (() -> Void)?

    func check() {
        onCheck?()
    }
}

private final class RecordingUpdater: HexaSparkleUpdaterControlling {
    var automaticallyChecksForUpdates = true
    var automaticallyDownloadsUpdates = true
    var sendsSystemProfile = true
    var assignedFeedURL: URL?
    var assignedChannels: Set<String> = []
    var flagsAtStart: (autoCheck: Bool, autoDownload: Bool, profile: Bool)?

    func start() throws {
        flagsAtStart = (
            automaticallyChecksForUpdates,
            automaticallyDownloadsUpdates,
            sendsSystemProfile
        )
    }

    func checkForUpdates() {}
}

private final class RecordingUserDriver: NSObject, SPUUserDriver {
    var updateFoundCount = 0
    var downloadInitiatedCount = 0
    var userCheckCount = 0
    var updateNotFoundCount = 0
    var updaterErrorCount = 0

    func show(
        _ request: SPUUpdatePermissionRequest,
        reply: @escaping (SUUpdatePermissionResponse) -> Void
    ) {
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: false, sendSystemProfile: false))
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        userCheckCount += 1
    }

    func showUpdateFound(
        with appcastItem: SUAppcastItem,
        state: SPUUserUpdateState,
        reply: @escaping (SPUUserUpdateChoice) -> Void
    ) {
        updateFoundCount += 1
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}

    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {}

    func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        updateNotFoundCount += 1
        acknowledgement()
    }

    func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        updaterErrorCount += 1
        acknowledgement()
    }

    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        downloadInitiatedCount += 1
    }

    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {}

    func showDownloadDidReceiveData(ofLength length: UInt64) {}

    func showDownloadDidStartExtractingUpdate() {}

    func showExtractionReceivedProgress(_ progress: Double) {}

    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {}

    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {}

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        acknowledgement()
    }

    func dismissUpdateInstallation() {}

    func showUpdateInFocus() {}
}
