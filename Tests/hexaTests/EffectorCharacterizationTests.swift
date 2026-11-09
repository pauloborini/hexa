// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import AppKit
import IOKit.pwr_mgt
import XCTest

@testable import Hexa

/// Caracteriza cinco efetores com portas falsas (CN6, D9): retroiluminação do
/// teclado, envio DDC, captura + OCR, assertions do Keep Awake e persistência
/// do mixer. Nenhum teste toca CoreBrightness, I2C, ScreenCaptureKit ou IOPM.
final class EffectorCharacterizationTests: XCTestCase {

    // MARK: - Keyboard backlight (AC-02.1.1)

    func testKeyboardLightClampedWriteReachesPort() {
        let port = FakeKeyboardLight()
        BrightnessService.keyboardLightPortOverride = port
        defer { BrightnessService.keyboardLightPortOverride = nil }
        let service = BrightnessService.shared
        service.refreshKeyboardLight()
        XCTAssertNotNil(service.keyboardLightEnabled, "a readable port enables the slider")

        let high = expectation(description: "1.5 is clamped to 1 and written")
        port.onWrite = { value in if value == 1 { high.fulfill() } }
        service.setKeyboardLightLevel(1.5)
        wait(for: [high], timeout: 2)
        port.onWrite = nil
        XCTAssertEqual(port.writes.last, 1)

        let low = expectation(description: "-1 is clamped to 0 and written")
        port.onWrite = { value in if value == 0 { low.fulfill() } }
        service.setKeyboardLightLevel(-1)
        wait(for: [low], timeout: 2)
        port.onWrite = nil
        XCTAssertEqual(port.writes.last, 0)
        XCTAssertTrue(port.writes.allSatisfy { (0...1).contains($0) })

        let before = port.writes.count
        service.setKeyboardLightLevel(.nan)
        let quiet = expectation(description: "NaN never reaches the port")
        quiet.isInverted = true
        wait(for: [quiet], timeout: 0.3)
        XCTAssertEqual(port.writes.count, before)
    }

    // MARK: - DDC send (AC-02.1.2)

    func testDDCWriteSendsLuminancePacket() {
        let display: CGDirectDisplayID = 4_242_001
        let sent = expectation(description: "one DDC packet is sent")
        var packets: [(CGDirectDisplayID, [UInt8])] = []
        BrightnessService.ddcSendOverride = { id, packet in
            packets.append((id, packet))
            sent.fulfill()
            return true
        }
        let service = BrightnessService.shared
        service.installDDCRouteForTesting(display, service: NSObject(), maximum: 100)
        defer {
            service.installDDCRouteForTesting(display, service: nil, maximum: 100)
            BrightnessService.ddcSendOverride = nil
        }

        service.setBrightness(0.5, for: display)
        wait(for: [sent], timeout: 5)

        let expected = BrightnessSupport.writePacket(
            code: BrightnessSupport.luminanceCode,
            value: BrightnessSupport.deviceValue(for: 0.5, maximum: 100))
        XCTAssertEqual(packets.count, 1)
        XCTAssertEqual(packets.first?.0, display)
        XCTAssertEqual(packets.first?.1, expected)
    }

    // MARK: - Capture and OCR (AC-02.1.3)

    func testCaptureEngineUsesInjectedCapturer() async throws {
        let image = try XCTUnwrap(Self.textImage("HEXA 4242"))
        var requested: [CGDirectDisplayID] = []
        ScreenshotCaptureEngine.displayCapturerOverride = { id in
            requested.append(id)
            return image
        }
        defer { ScreenshotCaptureEngine.displayCapturerOverride = nil }

        let captured = await ScreenshotCaptureEngine.captureDisplay(
            7, includePointer: false, hideHexaWindows: true, protectedWindowIDs: [])

        XCTAssertEqual(requested, [7], "the injected capturer serves the display")
        let result = try XCTUnwrap(captured)
        let outcome = ScreenTextService.outcome(for: result, detectQRCodes: false,
                                                removeLineBreaks: true)
        guard case .text(let text) = outcome else {
            return XCTFail("expected recognized text, got \(outcome)")
        }
        let compact = text.uppercased().filter { !$0.isWhitespace }
        XCTAssertTrue(compact.contains("HEXA4242"), "recognized: \(text)")
    }

    // MARK: - Keep Awake assertions (AC-02.1.4)

    func testKeepAwakeActivateCreatesSystemAssertion() {
        let port = FakeAssertions()
        let defaults = UserDefaults.standard
        let availableKey = DefaultsKey.featureAvailable(AppFeature.keepAwake.rawValue)
        let keys = [availableKey, DefaultsKey.defaultDuration, DefaultsKey.keepAwakeSwitchUsesUntil]
        let saved = keys.map { defaults.object(forKey: $0) }
        defaults.set(true, forKey: availableKey)
        KeepAwakeManager.assertionPortOverride = port
        let manager = KeepAwakeManager.shared
        defer {
            manager.deactivate(reason: .manual)
            KeepAwakeManager.assertionPortOverride = nil
            for (key, value) in zip(keys, saved) {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
        }

        manager.activate(minutes: 1)
        XCTAssertTrue(manager.isActive)
        XCTAssertTrue(port.created.contains("PreventUserIdleSystemSleep"),
                      "requested: \(port.created)")

        manager.deactivate(reason: .manual)
        XCTAssertFalse(manager.isActive)
        XCTAssertFalse(port.released.isEmpty, "the session releases what it created")
    }

    // MARK: - Mixer persist (AC-02.1.5)

    func testMixerPersistWritesNonUnityVolume() {
        let suiteLock = DefaultsSuiteLock("effector")
        defer { withExtendedLifetime(suiteLock) {} }
        let suiteName = "hexa.tests.effector"
        let suite = UserDefaults(suiteName: suiteName)!
        suite.removePersistentDomain(forName: suiteName)
        let mixer = AppVolumeMixer.shared
        mixer.volumeDefaults = suite
        defer {
            mixer.volumeDefaults = .standard
            suite.removePersistentDomain(forName: suiteName)
        }
        let key = "com.hexa.tests.effector"
        func stored(_ id: String) -> Double? {
            (suite.dictionary(forKey: DefaultsKey.appVolumes) as? [String: Double])?[id]
        }

        mixer.persistVolume(0.5, for: Self.mixerApp(persistenceID: key))
        XCTAssertEqual(stored(key), 0.5)

        mixer.persistVolume(1.0, for: Self.mixerApp(persistenceID: key))
        XCTAssertNil(stored(key), "unity removes the saved id")

        let bypassed = "com.hexa.tests.bypassed"
        mixer.setVolume(0.5, for: Self.mixerApp(persistenceID: bypassed, bypassed: true))
        XCTAssertNil(stored(bypassed), "a bypassed app writes nothing")
    }

    // MARK: - Helpers

    private static func mixerApp(persistenceID: String, bypassed: Bool = false) -> MixerApp {
        MixerApp(id: "test.\(persistenceID)",
                 persistenceID: persistenceID,
                 ownerPid: 1,
                 name: "Test",
                 audioObjects: [],
                 isPlaying: false,
                 isBypassed: bypassed,
                 outputDeviceUnavailable: false,
                 volume: 1)
    }

    private static func textImage(_ string: String) -> CGImage? {
        let width = 800
        let height = 200
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        (string as NSString).draw(
            at: NSPoint(x: 40, y: 70),
            withAttributes: [.font: NSFont.systemFont(ofSize: 72, weight: .semibold),
                             .foregroundColor: NSColor.black])
        NSGraphicsContext.current = previous
        return context.makeImage()
    }
}

private final class FakeKeyboardLight: KeyboardLightPort {
    var level: Float = 0.5
    private(set) var writes: [Float] = []
    var onWrite: ((Float) -> Void)?

    func brightness() -> Float { level }

    func setBrightness(_ value: Float) -> Bool {
        writes.append(value)
        level = value
        onWrite?(value)
        return true
    }
}

private final class FakeAssertions: KeepAwakeAssertionPort {
    private(set) var created: [String] = []
    private(set) var released: [IOPMAssertionID] = []
    private var nextID: IOPMAssertionID = 100

    func create(type: String, name: String) -> IOPMAssertionID? {
        created.append(type)
        nextID += 1
        return nextID
    }

    func release(_ id: IOPMAssertionID) {
        released.append(id)
    }
}
