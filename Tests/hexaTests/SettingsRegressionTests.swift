// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import AppKit
import XCTest
@testable import Hexa

final class SettingsRegressionTests: XCTestCase {
    private var savedGeometry: [(key: String, value: Any?)] = []

    override func setUp() {
        super.setUp()
        savedGeometry = [DefaultsKey.settingsWindowWidth, DefaultsKey.settingsWindowHeight].map {
            (key: $0, value: UserDefaults.standard.object(forKey: $0))
        }
    }

    override func tearDown() {
        for entry in savedGeometry {
            if let value = entry.value {
                UserDefaults.standard.set(value, forKey: entry.key)
            } else {
                UserDefaults.standard.removeObject(forKey: entry.key)
            }
        }
        super.tearDown()
    }

    func testWindowStartsAt800WideAndPreservesLargerHeights() {
        let roomy = CGSize(width: 1440, height: 900)
        XCTAssertEqual(SettingsWindowSupport.initialContentSize(savedHeight: 0, availableArea: roomy),
                       CGSize(width: 800, height: 690))
        XCTAssertEqual(SettingsWindowSupport.initialContentSize(savedHeight: 500, availableArea: roomy),
                       CGSize(width: 800, height: 690))
        XCTAssertEqual(SettingsWindowSupport.initialContentSize(savedHeight: 900, availableArea: roomy),
                       CGSize(width: 800, height: 900))
        XCTAssertEqual(SettingsWindowSupport.initialContentSize(savedHeight: 1400,
                                                                availableArea: CGSize(width: 1440, height: 1600)),
                       CGSize(width: 800, height: 1400))
    }

    func testCorruptSavedHeightsCannotReachAppKit() {
        for height in [Double.nan, .infinity, -.infinity, -1] {
            XCTAssertEqual(SettingsWindowSupport.initialContentSize(savedHeight: height,
                                                                    availableArea: CGSize(width: 1440, height: 900)),
                           CGSize(width: 800, height: 690))
        }
    }

    func testInitialContentSizeFitsUsableArea() {
        let low = CGSize(width: 700, height: 640)
        XCTAssertEqual(SettingsWindowSupport.initialContentSize(savedHeight: 0, availableArea: low),
                       CGSize(width: 700, height: 640))
        XCTAssertEqual(SettingsWindowSupport.initialContentSize(savedHeight: 1200, availableArea: low),
                       CGSize(width: 700, height: 640))
        XCTAssertEqual(SettingsWindowSupport.initialContentSize(savedHeight: 0, availableArea: CGSize(width: 900, height: 640)),
                       CGSize(width: 800, height: 640))
        XCTAssertEqual(SettingsWindowSupport.initialContentSize(savedHeight: 1400,
                                                                availableArea: CGSize(width: 1440, height: 900)),
                       CGSize(width: 800, height: 900))
    }

    func testDegenerateAreaKeepsFactoryFloor() {
        let areas = [CGSize.zero,
                     CGSize(width: -10, height: 640),
                     CGSize(width: 1440, height: CGFloat.nan),
                     CGSize(width: CGFloat.infinity, height: 900)]
        for area in areas {
            XCTAssertEqual(SettingsWindowSupport.initialContentSize(savedHeight: 900, availableArea: area),
                           CGSize(width: 800, height: 900))
            XCTAssertEqual(SettingsWindowSupport.initialContentSize(savedHeight: 0, availableArea: area),
                           CGSize(width: 800, height: 690))
        }
    }

    func testContentSizeLimitsKeepMinWithinMaxAndArea() {
        let roomy = SettingsWindowSupport.contentSizeLimits(availableArea: CGSize(width: 1440, height: 900))
        XCTAssertEqual(roomy.min, NSSize(width: 800, height: 690))
        XCTAssertEqual(roomy.max, NSSize(width: 800, height: 900))

        let low = SettingsWindowSupport.contentSizeLimits(availableArea: CGSize(width: 700, height: 640))
        XCTAssertEqual(low.min, NSSize(width: 700, height: 640))
        XCTAssertEqual(low.max, NSSize(width: 700, height: 640))

        let tall = SettingsWindowSupport.contentSizeLimits(availableArea: CGSize(width: 900, height: 1400))
        XCTAssertEqual(tall.min, NSSize(width: 800, height: 690))
        XCTAssertEqual(tall.max, NSSize(width: 800, height: 1400))

        let areas = [CGSize(width: 1440, height: 900), CGSize(width: 700, height: 640),
                     CGSize(width: 900, height: 1400), .zero, CGSize(width: -10, height: 640),
                     CGSize(width: CGFloat.nan, height: CGFloat.infinity)]
        for area in areas {
            let limits = SettingsWindowSupport.contentSizeLimits(availableArea: area)
            XCTAssertLessThanOrEqual(limits.min.width, limits.max.width)
            XCTAssertLessThanOrEqual(limits.min.height, limits.max.height)
        }

        let invalid = SettingsWindowSupport.contentSizeLimits(availableArea: .zero)
        XCTAssertEqual(invalid.min, NSSize(width: 800, height: 690))
        XCTAssertEqual(invalid.max, NSSize(width: 800, height: CGFloat.greatestFiniteMagnitude))
    }

    func testFittedFrameClampsToVisibleFrame() {
        let visible = CGRect(x: 0, y: 0, width: 700, height: 640)
        let fitted = SettingsWindowSupport.fittedFrame(frame: CGRect(x: -100, y: 200, width: 800, height: 1200),
                                                      visibleFrame: visible)
        XCTAssertLessThanOrEqual(fitted.width, visible.width)
        XCTAssertLessThanOrEqual(fitted.height, visible.height)
        XCTAssertGreaterThanOrEqual(fitted.minX, visible.minX)
        XCTAssertGreaterThanOrEqual(fitted.minY, visible.minY)
        XCTAssertLessThanOrEqual(fitted.maxX, visible.maxX)
        XCTAssertLessThanOrEqual(fitted.maxY, visible.maxY)
        XCTAssertEqual(fitted, CGRect(x: 0, y: 0, width: 700, height: 640))

        let entry = CGRect(x: 10, y: 20, width: 800, height: 690)
        XCTAssertEqual(SettingsWindowSupport.fittedFrame(frame: entry, visibleFrame: .zero), entry)
        XCTAssertEqual(SettingsWindowSupport.fittedFrame(frame: entry,
                                                        visibleFrame: CGRect(x: 0, y: 0, width: CGFloat.nan, height: 640)),
                       entry)
    }

    func testTruncatedHeightIsAppliedWithoutPersisting() {
        UserDefaults.standard.set(800, forKey: DefaultsKey.settingsWindowWidth)
        UserDefaults.standard.set(1200, forKey: DefaultsKey.settingsWindowHeight)

        let low = CGSize(width: 700, height: 640)
        XCTAssertEqual(SettingsWindowSupport.initialContentSize(savedHeight: 1200, availableArea: low),
                       CGSize(width: 700, height: 640))
        _ = SettingsWindowSupport.fittedFrame(frame: CGRect(x: 0, y: 0, width: 800, height: 1200),
                                             visibleFrame: CGRect(x: 0, y: 0, width: low.width, height: low.height))

        XCTAssertEqual(UserDefaults.standard.double(forKey: DefaultsKey.settingsWindowHeight), 1200)
        XCTAssertEqual(UserDefaults.standard.double(forKey: DefaultsKey.settingsWindowWidth), 800)
        XCTAssertFalse(SettingsWindowSupport.isValidContentSize(width: 800, height: 689))
        XCTAssertFalse(SettingsWindowSupport.isValidContentSize(width: 700, height: 900))
    }

    func testPersistenceRejectsWidthChangesAndInvalidHeights() {
        XCTAssertTrue(SettingsWindowSupport.isValidContentSize(width: 800, height: 690))
        XCTAssertTrue(SettingsWindowSupport.isValidContentSize(width: 800, height: 1400))
        for width in [739, 741, 820, Double.nan, .infinity] {
            XCTAssertFalse(SettingsWindowSupport.isValidContentSize(width: width, height: 900))
        }
        for height in [689, Double.nan, .infinity, -.infinity] {
            XCTAssertFalse(SettingsWindowSupport.isValidContentSize(width: 800, height: height))
        }
    }

    func testEverySidebarTitleBuildsInEveryLanguageWithoutCrashing() {
        for language in AppLanguage.allCases {
            let s = Strings.localized(language)
            let hub = FeatureStrings.hub(language)
            let menuBar = FeatureStrings.menuBarAppearance(language)
            let notch = FeatureStrings.notch(language)
            // Linhas reais da sidebar única (FeatureWorkspaceView): título de
            // cada feature por idioma, Monitor colapsado em uma linha e as
            // páginas de sistema. Ícones por feature já são cobertos em
            // testFeatureAndPermissionIconsLoad.
            for feature in AppFeature.allCases {
                XCTAssertFalse(feature.hubTitle(s, hub: hub).isEmpty,
                               "\(language): \(feature.rawValue)")
            }
            let titles = [s.tabMonitor, s.tabGeneral, s.menuBarSection, hub.pageTitle, s.shortcutsPageTitle,
                          s.tabAdvanced, s.tabAbout, hub.groupSound, hub.groupEnergyDisplay,
                          hub.groupTools, hub.groupMonitor, hub.processesAndPorts,
                          hub.moduleScreenCapture, hub.modulePowerDisplay, hub.moduleMaintenance,
                          notch.title, menuBar.tabMenuBar, menuBar.tabCommandCenter,
                          menuBar.commandCenterCaption, menuBar.barReadingsSection,
                          menuBar.monitoringCardsSection, menuBar.quickActionsSection,
                          menuBar.ambientDomain]
            for title in titles where title.isEmpty {
                XCTFail("\(language): título de sidebar vazio")
            }
            XCTAssertNotEqual(menuBar.tabMenuBar, menuBar.tabCommandCenter, "\(language)")
            XCTAssertNotEqual(menuBar.quickActionsSection, notch.controls, "\(language)")
            XCTAssertNotEqual(menuBar.ambientDomain, notch.controls, "\(language)")
        }
    }

    func testFeatureAndPermissionIconsLoad() {
        for feature in AppFeature.allCases {
            XCTAssertNotNil(HexaIcons.nsImage(named: feature.symbolName), feature.rawValue)
            XCTAssertTrue(feature.settingsDestination.hasValidSectionAnchor, feature.rawValue)
        }
        for permission in AppPermission.allCases {
            XCTAssertNotNil(HexaIcons.nsImage(named: permission.symbolName), permission.rawValue)
        }
    }

    func testScreenshotToolIconsLoad() {
        for tool in ScreenshotSupport.Tool.allCases {
            XCTAssertNotNil(HexaIcons.nsImage(named: tool.screenshotSymbolName), tool.rawValue)
        }
        for tool in ScreenCaptureTool.allCases {
            XCTAssertNotNil(HexaIcons.nsImage(named: tool.systemImageName), tool.rawValue)
        }
        XCTAssertNotNil(HexaIcons.nsImage(named: "cursorarrow.click.2"))
        XCTAssertNotNil(HexaIcons.nsImage(named: "cursorarrow.click"))
        XCTAssertNotNil(HexaIcons.nsImage(named: "mouse-pointer-click"))
    }

    /// Every literal `HexaIcons.image("NAME")` in the views must be a key of the
    /// glyph catalog; a missing key trips `assertionFailure` in debug builds.
    func testEveryIconLiteralInTheViewsExistsInTheCatalog() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests/hexaTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repository root
        let literal = try NSRegularExpression(pattern: #"HexaIcons\.image\(\s*"([^"]+)""#)

        var names = Set<String>()
        for folder in ["Sources/Hexa/UI", "Sources/Hexa/App", "Sources/Hexa/Services"] {
            let directory = root.appendingPathComponent(folder, isDirectory: true)
            let walker = try XCTUnwrap(FileManager.default.enumerator(at: directory,
                                                                      includingPropertiesForKeys: nil),
                                       folder)
            for case let url as URL in walker where url.pathExtension == "swift" {
                let text = try String(contentsOf: url, encoding: .utf8)
                for match in literal.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                    if let range = Range(match.range(at: 1), in: text) {
                        names.insert(String(text[range]))
                    }
                }
            }
        }
        XCTAssertGreaterThanOrEqual(names.count, 50,
                                    "Only \(names.count) icon literals found; the scan is not reading the views")

        let catalogURL = root.appendingPathComponent("Sources/Hexa/Resources/Icons/glyphs.json")
        let catalog = try JSONDecoder().decode([String: Int].self, from: Data(contentsOf: catalogURL))
        let missing = names.subtracting(catalog.keys).sorted()
        XCTAssertTrue(missing.isEmpty,
                      "Icon literals absent from glyphs.json: \(missing.joined(separator: ", "))")
    }

    // ISSUE-536: a login item removed in System Settings stays removed; one
    // lost to a move is registered again.
    func testLaunchAtLoginRegistersAgainOnlyAfterAMove() {
        func action(registeredPath: String?) -> LaunchAtLoginSupport.StartupAction {
            LaunchAtLoginSupport.startupAction(wanted: true, registration: .off, locationIsUnstable: false,
                                               registeredPath: registeredPath,
                                               appPath: "/Applications/Hexa.app")
        }
        XCTAssertEqual(action(registeredPath: "/Applications/Hexa.app"), .adoptOff)
        XCTAssertEqual(action(registeredPath: "/Volumes/Hexa/Hexa.app"), .register)
        XCTAssertEqual(action(registeredPath: nil), .register)
        XCTAssertEqual(LaunchAtLoginSupport.startupAction(wanted: true, registration: .off, locationIsUnstable: true,
                                                          registeredPath: nil, appPath: "/Volumes/Hexa/Hexa.app"),
                       .none)
        XCTAssertEqual(LaunchAtLoginSupport.startupAction(wanted: false, registration: .enabled,
                                                          locationIsUnstable: false,
                                                          registeredPath: nil, appPath: "/Applications/Hexa.app"),
                       .adoptEnabled)
    }

    func testStaleConsumersCannotDiscardNewNavigationRequests() {
        let router = SettingsRouter()
        let target = FeatureSettingsDestination(.features)
        router.request(target, targetFeature: .mixer)
        let oldID = router.requestID
        router.request(target, targetFeature: .brightness)
        let newID = router.requestID
        XCTAssertNotEqual(oldID, newID)
        router.consumeDestinationRequest(id: oldID)
        router.consumeFeatureTarget(id: oldID)
        XCTAssertEqual(router.pendingDestinationRequest?.id, newID)
        XCTAssertEqual(router.pendingFeatureTarget?.feature, .brightness)
        router.consumeDestinationRequest(id: newID)
        router.consumeFeatureTarget(id: newID)
        XCTAssertNil(router.pendingDestinationRequest)
        XCTAssertNil(router.pendingFeatureTarget)
    }

    func testBackForwardAndNewVisitDiscardForwardHistory() {
        let router = SettingsRouter()
        router.page = .features
        router.page = .about
        router.goBack()
        XCTAssertEqual(router.page, .features)
        router.goForward()
        XCTAssertEqual(router.page, .about)
        router.goBack()
        router.page = .advanced
        XCTAssertFalse(router.canGoForward())
        router.goBack()
        XCTAssertEqual(router.page, .features)
    }

    func testHistorySkipsUnavailablePages() {
        let router = SettingsRouter()
        router.page = .notch
        router.page = .about
        router.goBack(isPageVisible: { $0 != .notch })
        XCTAssertEqual(router.page, .general)
        router.goForward(isPageVisible: { $0 != .notch })
        XCTAssertEqual(router.page, .about)
    }

    func testVolumePercentHandlesNonFiniteAndOutOfRangeValues() {
        XCTAssertEqual(MixerRoutingSupport.volumePercent(.nan, maximum: 1), 0)
        XCTAssertEqual(MixerRoutingSupport.volumePercent(.infinity, maximum: 1), 0)
        XCTAssertEqual(MixerRoutingSupport.volumePercent(-.infinity, maximum: 2), 0)
        XCTAssertEqual(MixerRoutingSupport.volumePercent(-0.25, maximum: 1), 0)
        XCTAssertEqual(MixerRoutingSupport.volumePercent(1.5, maximum: 1), 100)
        XCTAssertEqual(MixerRoutingSupport.volumePercent(1.5, maximum: 2), 150)
        XCTAssertEqual(MixerRoutingSupport.volumePercent(2.5, maximum: 2), 200)
    }

    func testSystemOutputMutesAtZeroAndUnmutesAboveZero() {
        XCTAssertTrue(MixerRoutingSupport.shouldMuteSystemOutput(forVolume: 0))
        XCTAssertTrue(MixerRoutingSupport.shouldMuteSystemOutput(forVolume: -0.1))
        XCTAssertFalse(MixerRoutingSupport.shouldMuteSystemOutput(forVolume: 0.01))
        XCTAssertFalse(MixerRoutingSupport.shouldMuteSystemOutput(forVolume: 1.0))
        XCTAssertFalse(MixerRoutingSupport.shouldMuteSystemOutput(forVolume: .nan))
    }

    func testOutputStepTargetAccumulatesAcrossCoarseQuantizedReadbacks() {
        var target: MixerRoutingSupport.OutputStepTarget?
        let device: UInt32 = 42

        // 1st step at t = 100.0 from quantized hardware 0.50 (+1/16 = +0.0625)
        let base1 = MixerRoutingSupport.OutputStepTarget.baseVolume(
            target: target,
            device: device,
            hardwareVolume: 0.50,
            muted: false,
            now: 100.0
        )
        XCTAssertEqual(base1 ?? -1, 0.50, accuracy: 0.0001)
        let requested1 = NotchSupport.volumeLevel(current: base1 ?? 0, direction: 1, fine: false)
        XCTAssertEqual(requested1, 0.5625, accuracy: 0.0001)
        target = MixerRoutingSupport.OutputStepTarget.recordStep(
            previous: target,
            device: device,
            hardwareVolume: 0.50,
            requestedVolume: requested1,
            now: 100.0
        )

        // 30ms later, hardware still reports quantized 0.50; reconciledVolume preserves 0.5625
        let reconciled1 = MixerRoutingSupport.OutputStepTarget.reconciledVolume(
            target: &target,
            device: device,
            hardwareVolume: 0.50,
            muted: false,
            now: 100.03
        )
        XCTAssertEqual(reconciled1 ?? -1, 0.5625, accuracy: 0.0001)

        // 2nd step at t = 100.2 while hardware still reports 0.50: starts from 0.5625 -> 0.625
        let base2 = MixerRoutingSupport.OutputStepTarget.baseVolume(
            target: target,
            device: device,
            hardwareVolume: 0.50,
            muted: false,
            now: 100.2
        )
        XCTAssertEqual(base2 ?? -1, 0.5625, accuracy: 0.0001)
        let requested2 = NotchSupport.volumeLevel(current: base2 ?? 0, direction: 1, fine: false)
        XCTAssertEqual(requested2, 0.625, accuracy: 0.0001)
        target = MixerRoutingSupport.OutputStepTarget.recordStep(
            previous: target,
            device: device,
            hardwareVolume: 0.50,
            requestedVolume: requested2,
            now: 100.2
        )

        // External hardware change outside [0.50, 0.625] invalidates target
        let reconciledExternal = MixerRoutingSupport.OutputStepTarget.reconciledVolume(
            target: &target,
            device: device,
            hardwareVolume: 0.25,
            muted: false,
            now: 100.4
        )
        XCTAssertEqual(reconciledExternal ?? -1, 0.25, accuracy: 0.0001)
        XCTAssertNil(target)
    }

    func testOutputStepTargetHoldsAcrossDirectionReversal() {
        var target: MixerRoutingSupport.OutputStepTarget?
        let device: UInt32 = 42

        // 1st step up from hardware 0.50 -> 0.5625
        target = MixerRoutingSupport.OutputStepTarget.recordStep(
            previous: target,
            device: device,
            hardwareVolume: 0.50,
            requestedVolume: 0.5625,
            now: 100.0
        )

        // Readback arrives matching 0.5625
        let reconciled1 = MixerRoutingSupport.OutputStepTarget.reconciledVolume(
            target: &target,
            device: device,
            hardwareVolume: 0.5625,
            muted: false,
            now: 100.03
        )
        XCTAssertEqual(reconciled1 ?? -1, 0.5625, accuracy: 0.0001)

        // Step down back to 0.50
        target = MixerRoutingSupport.OutputStepTarget.recordStep(
            previous: target,
            device: device,
            hardwareVolume: 0.5625,
            requestedVolume: 0.50,
            now: 100.05
        )

        // Hardware still reports 0.5625 before the step-down write completes;
        // holding window must retain 0.50 rather than snapping back to 0.5625.
        let reconciledReversed = MixerRoutingSupport.OutputStepTarget.reconciledVolume(
            target: &target,
            device: device,
            hardwareVolume: 0.5625,
            muted: false,
            now: 100.08
        )
        XCTAssertEqual(reconciledReversed ?? -1, 0.50, accuracy: 0.0001)
        XCTAssertNotNil(target)
    }
}
