// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// DEC-030: with the preview off, a capture never ends with nothing to show.
final class ScreenshotAfterCaptureTests: XCTestCase {
    private func defaults(previewEnabled: Bool) throws -> UserDefaults {
        let suiteName = "hexaTests.screenshot-after-capture"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(previewEnabled, forKey: DefaultsKey.screenshotPreviewEnabled)
        return defaults
    }

    func testFreshInstallSavesEveryCapture() {
        XCTAssertEqual(Defaults.registeredDefaults[DefaultsKey.screenshotDefaultAction] as? String,
                       ScreenshotDefaultAction.save.rawValue)
    }

    func testPreviewOffStaysQuietAfterASuccessfulAction() throws {
        let defaults = try defaults(previewEnabled: false)
        XCTAssertEqual(ScreenshotSupport.quickPreviewPresentation(
            defaultAction: .save, saved: true, copied: false, defaults: defaults), .hidden)
        XCTAssertEqual(ScreenshotSupport.quickPreviewPresentation(
            defaultAction: .saveAndCopy, saved: true, copied: true, defaults: defaults), .hidden)
        XCTAssertEqual(ScreenshotSupport.quickPreviewPresentation(
            defaultAction: .copy, saved: false, copied: true, defaults: defaults), .hidden)
    }

    func testPreviewOffStillRecoversAFailedAction() throws {
        let defaults = try defaults(previewEnabled: false)
        let recovery = ScreenshotSupport.QuickPreviewPresentation.shown(
            dismissInterval: ScreenshotSupport.recoveryPreviewDismissInterval)
        XCTAssertEqual(ScreenshotSupport.quickPreviewPresentation(
            defaultAction: .save, saved: false, copied: false, defaults: defaults), recovery)
        XCTAssertEqual(ScreenshotSupport.quickPreviewPresentation(
            defaultAction: .copy, saved: false, copied: false, defaults: defaults), recovery)
        XCTAssertEqual(ScreenshotSupport.quickPreviewPresentation(
            defaultAction: .saveAndCopy, saved: true, copied: false, defaults: defaults), recovery)
    }

    func testAskEachTimeAsksWithThePreviewOff() throws {
        let defaults = try defaults(previewEnabled: false)
        XCTAssertNotEqual(ScreenshotSupport.quickPreviewPresentation(
            defaultAction: .none, saved: false, copied: false, defaults: defaults), .hidden)
        XCTAssertEqual(ScreenshotSupport.quickPreviewPresentation(
            defaultAction: .edit, saved: false, copied: false, defaults: defaults), .hidden)
    }
}
