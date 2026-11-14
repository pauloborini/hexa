// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

final class HexaSelfUpdateAboutTests: XCTestCase {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func test_new_about_update_strings_exist_in_all_languages() {
        XCTAssertEqual(AppLanguage.allCases.count, 15)
        for language in AppLanguage.allCases {
            let strings = Strings.localized(language)
            let fields = [
                strings.checkForUpdates,
                strings.updateChecking,
                strings.updateUpToDate,
                strings.updateAvailable,
                strings.updateFailed,
                strings.updateDevBuild
            ]
            for field in fields {
                XCTAssertFalse(
                    field.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    "Missing About self-update string for \(language.rawValue)"
                )
            }
        }
    }

    func test_about_button_uses_catalog_label() throws {
        let about = try aboutSettingsSource()
        XCTAssertTrue(about.contains("l10n.s.checkForUpdates"))
        XCTAssertFalse(about.contains("Label(\"Verificar atualizações\""))
        XCTAssertFalse(about.contains("Label(\"Check for updates\""))
    }

    func test_about_hosts_check_button_not_app_updates() throws {
        let about = try aboutSettingsSource()
        let updates = try source("Sources/Hexa/UI/Settings/AppUpdatesSettings.swift")
        XCTAssertTrue(about.contains("l10n.s.checkForUpdates"))
        XCTAssertTrue(about.contains(".buttonStyle(HexaActionButtonStyle())"))
        XCTAssertTrue(about.contains("hexaIcon: \"arrow.clockwise\""))
        XCTAssertFalse(updates.contains("checkForUpdates"))
        XCTAssertFalse(updates.contains("HexaSelfUpdateController"))
    }

    func test_tap_requests_check_and_shows_checking() throws {
        let about = try aboutSettingsSource()
        XCTAssertTrue(about.contains("Button {\n                selfUpdate.requestCheck()\n            } label: {"))
        XCTAssertFalse(about.contains("// selfUpdate.requestCheck()"))
        XCTAssertTrue(about.contains(".disabled(selfUpdate.status == .checking)"))
        XCTAssertTrue(about.contains("ProgressView()"))
        XCTAssertTrue(about.contains("AboutSelfUpdateCopy.text(for: selfUpdate.status"))

        let spy = CheckSpy()
        let controller = HexaSelfUpdateController(
            isDeveloperBuild: false,
            clientFactory: HexaSelfUpdateClientFactory(make: spy.make)
        )
        XCTAssertEqual(controller.status, .idle)
        XCTAssertNil(AboutSelfUpdateCopy.text(for: controller.status, strings: Strings.localized(.ptBR)))
        controller.requestCheck()
        XCTAssertEqual(spy.checkCount, 1)
        XCTAssertEqual(controller.status, .checking)
        let strings = Strings.localized(.ptBR)
        XCTAssertEqual(AboutSelfUpdateCopy.text(for: controller.status, strings: strings), strings.updateChecking)
    }

    func test_failure_keeps_manual_download() throws {
        let about = try aboutSettingsSource()
        let strings = Strings.localized(.enUS)
        XCTAssertEqual(AboutSelfUpdateCopy.text(for: .failed, strings: strings), strings.updateFailed)
        XCTAssertTrue(about.contains("l10n.s.downloadLatestRelease"))
        XCTAssertTrue(about.contains("openURL(AppInfo.downloadURL)"))
        XCTAssertFalse(about.contains("if selfUpdate.status != .failed"))
        XCTAssertFalse(about.contains("case .failed:"))
    }

    func test_status_copy_matches_hexa_states() {
        let strings = Strings.localized(.enUS)
        XCTAssertNil(AboutSelfUpdateCopy.text(for: .idle, strings: strings))
        XCTAssertEqual(AboutSelfUpdateCopy.text(for: .checking, strings: strings), strings.updateChecking)
        XCTAssertEqual(AboutSelfUpdateCopy.text(for: .upToDate, strings: strings), strings.updateUpToDate)
        XCTAssertEqual(AboutSelfUpdateCopy.text(for: .available, strings: strings), strings.updateAvailable)
        XCTAssertEqual(AboutSelfUpdateCopy.text(for: .failed, strings: strings), strings.updateFailed)
        XCTAssertEqual(AboutSelfUpdateCopy.text(for: .developerBuild, strings: strings), strings.updateDevBuild)
    }

    func test_about_has_no_hexa_install_alert() throws {
        let about = try aboutSettingsSource()
        XCTAssertFalse(about.contains(".alert("))
        XCTAssertFalse(about.contains("Alert("))
        XCTAssertFalse(about.contains("updateInstallButton"))
        let driver = try source("Sources/Hexa/Services/SelfUpdate/HexaSparkleUserDriver.swift")
        XCTAssertTrue(driver.contains("standard.showUpdateFound"))
    }

    func test_app_updates_still_excludes_hexa() throws {
        let service = try source("Sources/Hexa/Services/AppUpdates/AppUpdatesService.swift")
        XCTAssertTrue(service.contains("bundleID == Bundle.main.bundleIdentifier"))
        XCTAssertTrue(service.contains("bundleID == \"io.github.pauloborini.hexa\""))
        XCTAssertTrue(service.contains("bundleID.hasPrefix(\"io.github.pauloborini.hexa.\")"))
        let updates = try source("Sources/Hexa/UI/Settings/AppUpdatesSettings.swift")
        XCTAssertFalse(updates.contains("HexaSelfUpdateController"))
        XCTAssertFalse(updates.contains("SelfUpdate"))
    }

    private func aboutSettingsSource() throws -> String {
        let full = try source("Sources/Hexa/UI/Settings/AboutSettings.swift")
        let start = try XCTUnwrap(full.range(of: "struct AboutSettings: View {"))
        let end = try XCTUnwrap(full.range(of: "struct ReleaseNotesSettings: View {"))
        return String(full[start.lowerBound..<end.lowerBound])
    }

    private func source(_ relative: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(relative), encoding: .utf8)
    }
}

private final class CheckSpy {
    var checkCount = 0

    func make() -> HexaSelfUpdateClient {
        let client = CheckClient()
        client.onCheck = { [weak self] in self?.checkCount += 1 }
        return client
    }
}

private final class CheckClient: HexaSelfUpdateClient {
    var onStatus: ((HexaSelfUpdateStatus) -> Void)?
    var onCheck: (() -> Void)?

    func check() {
        onCheck?()
    }
}
