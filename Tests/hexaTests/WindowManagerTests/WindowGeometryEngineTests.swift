// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import CoreGraphics
import XCTest

@testable import Hexa

final class WindowGeometryEngineTests: XCTestCase {
    private let singleScreen = WindowDisplayDescriptor(
        id: 1,
        frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
        visibleFrame: CGRect(x: 0, y: 60, width: 1440, height: 815),
        safeAreaTopInset: 32,
        scaleFactor: 2.0
    )

    private let ultrawideScreen = WindowDisplayDescriptor(
        id: 2,
        frame: CGRect(x: 1440, y: 0, width: 3440, height: 1440),
        visibleFrame: CGRect(x: 1440, y: 0, width: 3440, height: 1415),
        safeAreaTopInset: 0,
        scaleFactor: 1.0
    )

    // MARK: - Single Display Placements

    func testHalvesAndQuartersOnSingleDisplay() {
        let vf = CGRect(x: 0, y: 60, width: 1440, height: 800)
        let current = CGRect(x: 200, y: 200, width: 600, height: 400)

        XCTAssertEqual(WindowGeometryEngine.rect(for: .leftHalf, current: current, visibleFrame: vf),
                       CGRect(x: 0, y: 60, width: 720, height: 800))
        XCTAssertEqual(WindowGeometryEngine.rect(for: .rightHalf, current: current, visibleFrame: vf),
                       CGRect(x: 720, y: 60, width: 720, height: 800))
        let oddScreen = CGRect(x: -1441, y: 60, width: 1441, height: 801)
        for scale in [CGFloat(1), 2] {
            let left = WindowGeometryEngine.rect(for: .leftHalf, current: current,
                                                 visibleFrame: oddScreen, scaleFactor: scale)
            let right = WindowGeometryEngine.rect(for: .rightHalf, current: current,
                                                  visibleFrame: oddScreen, scaleFactor: scale)
            XCTAssertEqual(left.maxX, right.minX)
            XCTAssertEqual(left.union(right), oddScreen)
        }
        XCTAssertEqual(WindowGeometryEngine.rect(for: .topHalf, current: current, visibleFrame: vf),
                       CGRect(x: 0, y: 460, width: 1440, height: 400))
        XCTAssertEqual(WindowGeometryEngine.rect(for: .bottomHalf, current: current, visibleFrame: vf),
                       CGRect(x: 0, y: 60, width: 1440, height: 400))
        XCTAssertEqual(WindowGeometryEngine.rect(for: .topLeft, current: current, visibleFrame: vf),
                       CGRect(x: 0, y: 460, width: 720, height: 400))
        XCTAssertEqual(WindowGeometryEngine.rect(for: .topRight, current: current, visibleFrame: vf),
                       CGRect(x: 720, y: 460, width: 720, height: 400))
        XCTAssertEqual(WindowGeometryEngine.rect(for: .bottomLeft, current: current, visibleFrame: vf),
                       CGRect(x: 0, y: 60, width: 720, height: 400))
        XCTAssertEqual(WindowGeometryEngine.rect(for: .bottomRight, current: current, visibleFrame: vf),
                       CGRect(x: 720, y: 60, width: 720, height: 400))
    }

    func testThirdsAndTwoThirds() {
        let vf = CGRect(x: 0, y: 0, width: 1500, height: 900)
        let current = CGRect(x: 100, y: 100, width: 400, height: 400)

        XCTAssertEqual(WindowGeometryEngine.rect(for: .leftThird, current: current, visibleFrame: vf),
                       CGRect(x: 0, y: 0, width: 500, height: 900))
        XCTAssertEqual(WindowGeometryEngine.rect(for: .centerThird, current: current, visibleFrame: vf),
                       CGRect(x: 500, y: 0, width: 500, height: 900))
        XCTAssertEqual(WindowGeometryEngine.rect(for: .rightThird, current: current, visibleFrame: vf),
                       CGRect(x: 1000, y: 0, width: 500, height: 900))
        XCTAssertEqual(WindowGeometryEngine.rect(for: .leftTwoThirds, current: current, visibleFrame: vf),
                       CGRect(x: 0, y: 0, width: 1000, height: 900))
        XCTAssertEqual(WindowGeometryEngine.rect(for: .rightTwoThirds, current: current, visibleFrame: vf),
                       CGRect(x: 500, y: 0, width: 1000, height: 900))
        XCTAssertEqual(WindowGeometryEngine.rect(for: .centerTwoThirds, current: current, visibleFrame: vf),
                       CGRect(x: 250, y: 0, width: 1000, height: 900))
    }

    func testMaximizeMarginMaximizeAndCenter() {
        let vf = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let small = CGRect(x: 50, y: 50, width: 400, height: 300)

        XCTAssertEqual(WindowGeometryEngine.rect(for: .maximize, current: small, visibleFrame: vf), vf)
        let gaps = WindowGapsConfig(windowGap: 0, screenGap: 0, marginPercent: 10)
        XCTAssertEqual(WindowGeometryEngine.rect(for: .marginMaximize, current: small, visibleFrame: vf, gaps: gaps),
                       CGRect(x: 100, y: 80, width: 800, height: 640))
        XCTAssertEqual(WindowGeometryEngine.rect(for: .center, current: small, visibleFrame: vf),
                       CGRect(x: 300, y: 250, width: 400, height: 300))
    }

    // MARK: - Gaps & Screen Margins

    func testWindowGapAndScreenGapSplitEvenlyBetweenAdjacentWindows() {
        let vf = CGRect(x: 0, y: 0, width: 1200, height: 800)
        let gaps = WindowGapsConfig(windowGap: 16, screenGap: 12)
        let left = WindowGeometryEngine.rect(for: .leftHalf, current: .zero, visibleFrame: vf, gaps: gaps)
        let right = WindowGeometryEngine.rect(for: .rightHalf, current: .zero, visibleFrame: vf, gaps: gaps)

        XCTAssertEqual(left.minX, 12)
        XCTAssertEqual(right.maxX, 1188)
        XCTAssertEqual(right.minX - left.maxX, 16, "Shared seam between left and right halves equals windowGap")
        XCTAssertEqual(left.minY, 12)
        XCTAssertEqual(left.maxY, 788)
    }

    // MARK: - Notch Safe Area & Stage Manager

    func testNotchSafeVisibleFrameClipsOverlapWithNotch() {
        let laptopWithNotch = WindowDisplayDescriptor(
            id: 10,
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: CGRect(x: 0, y: 50, width: 1512, height: 932), // overlaps top 38pt notch
            safeAreaTopInset: 38,
            scaleFactor: 2.0
        )
        let safe = WindowGeometryEngine.safeLayoutFrame(for: laptopWithNotch)
        XCTAssertEqual(safe.maxY, 944)
        XCTAssertEqual(safe.minY, 50)
    }

    func testStageManagerReservesStripSpaceOnLeftAndRight() {
        let vf = CGRect(x: 0, y: 60, width: 1440, height: 800)
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let leftConfig = StageManagerConfig(reserveSpace: true, stageManagerEnabled: true,
                                            autoHide: false, dockPosition: "bottom", rightToLeft: false)
        // Strip detected on left edge (width 90, x=8 -> boundary 98+8=106)
        let strip = CGRect(x: 8, y: 120, width: 90, height: 600)
        let adjustedLeft = WindowGeometryEngine.stageManagerAdjustedFrame(
            visibleFrame: vf, screenFrame: screen, config: leftConfig, stripFrames: [strip]
        )
        XCTAssertEqual(adjustedLeft.minX, 106)
        XCTAssertEqual(adjustedLeft.maxX, 1440)

        // Fallback 75pt when strip is temporarily hidden
        let fallbackLeft = WindowGeometryEngine.stageManagerAdjustedFrame(
            visibleFrame: vf, screenFrame: screen, config: leftConfig, stripFrames: []
        )
        XCTAssertEqual(fallbackLeft.minX, 75)
        XCTAssertEqual(fallbackLeft.width, 1365)

        // Dock on left pushes Stage Manager strip to the right edge
        let dockLeftConfig = StageManagerConfig(reserveSpace: true, stageManagerEnabled: true,
                                                autoHide: false, dockPosition: "left", rightToLeft: false)
        let fallbackRight = WindowGeometryEngine.stageManagerAdjustedFrame(
            visibleFrame: vf, screenFrame: screen, config: dockLeftConfig, stripFrames: []
        )
        XCTAssertEqual(fallbackRight.minX, 0)
        XCTAssertEqual(fallbackRight.maxX, 1365)
    }

    // MARK: - minSize Resilience

    func testMinSizeResilienceKeepsWindowAnchoredInsideVisibleFrame() {
        let vf = CGRect(x: 0, y: 0, width: 1200, height: 800)
        let targetRightThird = WindowGeometryEngine.rect(for: .rightThird, current: .zero, visibleFrame: vf)
        // Window refuses to go narrower than 600pt (target is 400pt)
        let constrained = WindowGeometryEngine.resolveConstrainedRect(
            for: .rightThird,
            targetRect: targetRightThird,
            minSize: CGSize(width: 600, height: 500),
            maxSize: nil,
            visibleFrame: vf
        )
        XCTAssertEqual(constrained.width, 600)
        XCTAssertEqual(constrained.maxX, 1200, "Right-anchored window stays flush with right edge instead of overflowing")
        XCTAssertGreaterThanOrEqual(constrained.minX, vf.minX)
    }

    // MARK: - Multi-Monitor Transfer & Ordering

    func testMultiDisplayTransferPreservesMaximizedAndClampsPartialWindows() {
        let laptopVF = singleScreen.visibleFrame
        let ultraVF = ultrawideScreen.visibleFrame

        // Maximized window on MacBook becomes maximized on Ultrawide
        let transferredMax = WindowGeometryEngine.transferRect(current: laptopVF, from: laptopVF, to: ultraVF)
        XCTAssertEqual(transferredMax, ultraVF)

        // Right-half window on Ultrawide shrinks to fit MacBook and stays anchored right
        let wideWindow = CGRect(x: ultraVF.midX, y: 0, width: 1720, height: 1415)
        let transferredToLaptop = WindowGeometryEngine.transferRect(current: wideWindow, from: ultraVF, to: laptopVF)
        XCTAssertEqual(transferredToLaptop.width, laptopVF.width)
        XCTAssertEqual(transferredToLaptop.height, laptopVF.height)
        XCTAssertEqual(transferredToLaptop.minX, laptopVF.minX)

        // Adjacent display index wraps cleanly
        let frames = [singleScreen.frame, ultrawideScreen.frame]
        XCTAssertEqual(WindowGeometryEngine.adjacentDisplayIndex(currentIndex: 0, frames: frames, movingForward: true), 1)
        XCTAssertEqual(WindowGeometryEngine.adjacentDisplayIndex(currentIndex: 1, frames: frames, movingForward: true), 0)
        XCTAssertEqual(WindowGeometryEngine.neighbourDisplayIndex(currentIndex: 0, frames: frames, direction: .right), 1)
        XCTAssertEqual(WindowGeometryEngine.neighbourDisplayIndex(currentIndex: 1, frames: frames, direction: .left), 0)
    }

    // MARK: - Snap Zone Detection

    func testSnapTargetCornersEdgesAndMultiMonitorSeam() {
        let displays = [singleScreen, ultrawideScreen]

        // Top-left corner of primary screen
        let tl = WindowGeometryEngine.snapTarget(at: CGPoint(x: 5, y: 895), displays: displays)
        XCTAssertEqual(tl?.zone, .topLeft)
        XCTAssertEqual(tl?.action, .topLeft)

        // Fast drag across the seam between display 1 (maxX=1440) and display 2 (minX=1440) does NOT snap
        let fastSeam = WindowGeometryEngine.snapTarget(at: CGPoint(x: 1435, y: 450), displays: displays, pointerSpeed: 600)
        XCTAssertNil(fastSeam)

        // Slow/paused drag at the seam DOES snap to right half of display 1
        let slowSeam = WindowGeometryEngine.snapTarget(at: CGPoint(x: 1435, y: 450), displays: displays, pointerSpeed: 50)
        XCTAssertEqual(slowSeam?.zone, .right)
        XCTAssertEqual(slowSeam?.displayID, 1)

        // Disabled zone is ignored
        let enabledWithoutTop = Set(WindowSnapZone.allCases).subtracting([.top])
        let disabledTop = WindowGeometryEngine.snapTarget(at: CGPoint(x: 720, y: 895),
                                                          displays: displays,
                                                          enabledZones: enabledWithoutTop)
        XCTAssertNil(disabledTop)
    }

    // MARK: - Side Cycle & Frame History

    func testEffectiveActionCyclesThirdsAndTopMaximizes() {
        XCTAssertEqual(WindowGeometryEngine.effectiveAction(for: .topHalf, previousAction: .topHalf, sideRepeatCyclesThirds: false), .maximize)
        XCTAssertEqual(WindowGeometryEngine.effectiveAction(for: .leftHalf, previousAction: .leftHalf, sideRepeatCyclesThirds: true), .leftTwoThirds)
        XCTAssertEqual(WindowGeometryEngine.effectiveAction(for: .leftHalf, previousAction: .leftTwoThirds, sideRepeatCyclesThirds: true), .leftThird)
        XCTAssertEqual(WindowGeometryEngine.effectiveAction(for: .leftHalf, previousAction: .leftThird, sideRepeatCyclesThirds: true), .leftHalf)
    }

    func testFrameHistoryRecordsPopsAndRespectsLimit() {
        var history = WindowFrameHistory()
        let key = WindowIdentityKey(processID: 42, processLaunchTime: 1000, windowID: 99)
        let f1 = WindowFrame(rect: CGRect(x: 10, y: 10, width: 500, height: 400))
        let f2 = WindowFrame(rect: CGRect(x: 0, y: 0, width: 720, height: 800))
        history.record(f1, for: key)
        history.record(f2, for: key)

        XCTAssertEqual(history.popPrevious(for: key, current: f2), f1)
        XCTAssertNil(history.popPrevious(for: key, current: f1))
    }

    // MARK: - Regression Coverage (Multi-Monitor, Exact Edges, Conflicts, Native Tiling)

    func testSnapTargetMatchesExactTopAndRightScreenEdges() {
        let displays = [singleScreen]
        // Pointer pinned at exact top edge (Quartz y=0 -> AppKit y=frame.maxY=900)
        let exactTop = WindowGeometryEngine.snapTarget(at: CGPoint(x: 720, y: 900), displays: displays)
        XCTAssertEqual(exactTop?.zone, .top)
        XCTAssertEqual(exactTop?.action, .maximize)

        // Pointer pinned at exact right edge (x=frame.maxX=1440)
        let exactRight = WindowGeometryEngine.snapTarget(at: CGPoint(x: 1440, y: 450), displays: displays)
        XCTAssertEqual(exactRight?.zone, .right)
        XCTAssertEqual(exactRight?.action, .rightHalf)

        // Exact top-right corner
        let exactTopRight = WindowGeometryEngine.snapTarget(at: CGPoint(x: 1440, y: 900), displays: displays)
        XCTAssertEqual(exactTopRight?.zone, .topRight)
    }

    func testMultiMonitorVerticalAndLeftNegativeCoordinatesRoundTrip() {
        let primaryTopY: CGFloat = 900
        let leftExternal = WindowDisplayDescriptor(
            id: 3,
            frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: -1920, y: 0, width: 1920, height: 1055),
            scaleFactor: 1.0
        )
        let aboveExternal = WindowDisplayDescriptor(
            id: 4,
            frame: CGRect(x: -100, y: 900, width: 2560, height: 1440),
            visibleFrame: CGRect(x: -100, y: 900, width: 2560, height: 1415),
            scaleFactor: 2.0
        )
        let belowExternal = WindowDisplayDescriptor(
            id: 5,
            frame: CGRect(x: 0, y: -1080, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: -1080, width: 1920, height: 1055),
            scaleFactor: 1.0
        )

        // Quartz <-> AppKit round-trip across above, below and left displays
        for rect in [leftExternal.visibleFrame, aboveExternal.visibleFrame, belowExternal.visibleFrame] {
            let quartz = WindowGeometryEngine.quartzRect(fromAppKit: rect, primaryScreenTopY: primaryTopY)
            let roundTripped = WindowGeometryEngine.appKitRect(fromQuartz: quartz, primaryScreenTopY: primaryTopY)
            XCTAssertEqual(roundTripped, rect)
        }

        // Staggered display above (minX=-100) must NOT be treated as a left neighbour of primary
        let verticalFrames = [singleScreen.frame, aboveExternal.frame, belowExternal.frame]
        XCTAssertNil(WindowGeometryEngine.neighbourDisplayIndex(currentIndex: 0, frames: verticalFrames, direction: .left))
        XCTAssertEqual(WindowGeometryEngine.neighbourDisplayIndex(currentIndex: 0, frames: verticalFrames, direction: .up), 1)
        XCTAssertEqual(WindowGeometryEngine.neighbourDisplayIndex(currentIndex: 0, frames: verticalFrames, direction: .down), 2)

        // Horizontal left display IS found as left neighbour
        let horizontalFrames = [singleScreen.frame, leftExternal.frame]
        XCTAssertEqual(WindowGeometryEngine.neighbourDisplayIndex(currentIndex: 0, frames: horizontalFrames, direction: .left), 1)
    }

    func testMinSizeWinsOverInconsistentMaxSize() {
        let vf = CGRect(x: 0, y: 0, width: 1200, height: 800)
        let target = WindowGeometryEngine.rect(for: .bottomRight, current: .zero, visibleFrame: vf)
        let constrained = WindowGeometryEngine.resolveConstrainedRect(
            for: .bottomRight,
            targetRect: target,
            minSize: CGSize(width: 700, height: 500),
            maxSize: CGSize(width: 500, height: 400),
            visibleFrame: vf
        )
        XCTAssertEqual(constrained.width, 700)
        XCTAssertEqual(constrained.height, 500)
        XCTAssertEqual(constrained.maxX, 1200)
        XCTAssertEqual(constrained.minY, 0)
    }

    func testSnapModifierCoexistsWithNativeOptionDrag() {
        // When no modifier is required, holding Option yields to macOS native tiling
        XCTAssertTrue(WindowSnapModifier.none.shouldTrigger(for: []))
        XCTAssertFalse(WindowSnapModifier.none.shouldTrigger(for: .maskAlternate))

        // When Option is explicitly chosen as Hexa's snap modifier, Option triggers Hexa
        XCTAssertTrue(WindowSnapModifier.option.shouldTrigger(for: .maskAlternate))
        XCTAssertFalse(WindowSnapModifier.option.shouldTrigger(for: []))
        XCTAssertFalse(WindowSnapModifier.option.shouldTrigger(for: .maskAlternate, nativeOptionTilingEnabled: true))
        XCTAssertFalse(WindowSnapModifier.control.shouldTrigger(for: [.maskControl, .maskAlternate],
                                                                 nativeOptionTilingEnabled: true))
    }

    func testShortcutConflictDetectsWindowActionAndGlobalRole() {
        let wmMap: [WindowManagerAction: GlobalShortcut] = [
            .leftHalf: .windowLayoutLeftDefault,
            .rightHalf: .windowLayoutRightDefault,
        ]
        let roles: [(GlobalShortcutRole, GlobalShortcut)] = [
            (.keepAwake, .keepAwakeDefault),
            (.menuBarHiding, .menuBarHidingDefault),
        ]

        // Colliding with another WindowManager action
        XCTAssertEqual(
            WindowGeometryEngine.shortcutConflict(for: .windowLayoutLeftDefault,
                                                  excluding: .rightHalf,
                                                  windowManagerShortcuts: wmMap,
                                                  roleShortcuts: roles),
            .windowAction(.leftHalf)
        )
        // Own action is excluded
        XCTAssertNil(
            WindowGeometryEngine.shortcutConflict(for: .windowLayoutLeftDefault,
                                                  excluding: .leftHalf,
                                                  windowManagerShortcuts: wmMap,
                                                  roleShortcuts: roles)
        )
        // Colliding with another Hexa module's GlobalShortcutRole
        XCTAssertEqual(
            WindowGeometryEngine.shortcutConflict(for: .menuBarHidingDefault,
                                                  excluding: .leftHalf,
                                                  windowManagerShortcuts: wmMap,
                                                  roleShortcuts: roles),
            .globalRole(.menuBarHiding)
        )
        // Registered default for previousDisplay matches standard profile
        XCTAssertEqual(
            Defaults.registeredDefaults[DefaultsKey.windowLayoutShortcutPreviousDisplay] as? String,
            GlobalShortcut.windowLayoutPreviousDisplayDefault.storageValue
        )
    }
}
