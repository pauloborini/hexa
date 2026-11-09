// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import CoreGraphics
import XCTest
@testable import Hexa

/// Geometry only: no event tap, no real display and no Accessibility grant.
final class DockDisplayLockTests: XCTestCase {
    private func display(_ id: CGDirectDisplayID, _ frame: CGRect,
                         main: Bool = false, builtIn: Bool = false) -> DockDisplayLockDisplay {
        DockDisplayLockDisplay(id: id, uuid: "UUID-\(id)", name: "Display \(id)", frame: frame,
                               isMain: main, isBuiltIn: builtIn)
    }

    // A 2560×1440 main display with a 1920×1080 one to its right, 78 points
    // lower, as a real desk has them.
    private let main = DockDisplayLockDisplay(id: 3, uuid: "UUID-3", name: "Main",
                                             frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
                                             isMain: true, isBuiltIn: false)
    private let side = DockDisplayLockDisplay(id: 1, uuid: "UUID-1", name: "Side",
                                              frame: CGRect(x: 2560, y: 78, width: 1920, height: 1080),
                                              isMain: false, isBuiltIn: false)
    // A laptop under the middle of the main display.
    private let below = DockDisplayLockDisplay(id: 5, uuid: "UUID-5", name: "Built-in",
                                               frame: CGRect(x: 640, y: 1440, width: 1512, height: 982),
                                               isMain: false, isBuiltIn: true)

    private func nudged(_ point: CGPoint, _ zones: DockDisplayLockSupport.Zones) -> CGPoint? {
        var inCorner = false
        return DockDisplayLockSupport.nudged(point, zones: zones, inCorner: &inCorner)
    }

    // MARK: - Target

    func testStoredChoiceRoundTrips() {
        XCTAssertEqual(DockDisplayLockTarget(storage: nil), .main)
        XCTAssertEqual(DockDisplayLockTarget(storage: ""), .main)
        XCTAssertEqual(DockDisplayLockTarget(storage: "main"), .main)
        XCTAssertEqual(DockDisplayLockTarget(storage: "builtIn"), .builtIn)
        XCTAssertEqual(DockDisplayLockTarget(storage: "1A39FCE5"), .display(uuid: "1A39FCE5"))
        for target in [DockDisplayLockTarget.main, .builtIn, .display(uuid: "1A39FCE5")] {
            XCTAssertEqual(DockDisplayLockTarget(storage: target.storageValue), target)
        }
    }

    func testAnchorFallsBackToMainWhenTheChoiceIsAway() {
        XCTAssertEqual(DockDisplayLockSupport.anchor(for: .main, in: [side, main])?.id, main.id)
        XCTAssertEqual(DockDisplayLockSupport.anchor(for: .display(uuid: side.uuid), in: [main, side])?.id, side.id)
        XCTAssertEqual(DockDisplayLockSupport.anchor(for: .builtIn, in: [main, below])?.id, below.id)
        XCTAssertEqual(DockDisplayLockSupport.anchor(for: .display(uuid: "UUID-9"), in: [main, side])?.id, main.id)
        XCTAssertEqual(DockDisplayLockSupport.anchor(for: .builtIn, in: [main, side])?.id, main.id)
    }

    // MARK: - Zones

    func testBottomEdgeOfAnotherDisplayIsNudged() {
        let zones = DockDisplayLockSupport.zones(displays: [main, side], anchorID: main.id,
                                                 orientation: .bottom, hotCorners: [])
        XCTAssertNotNil(nudged(CGPoint(x: 3000, y: 1157), zones))
        XCTAssertNotNil(nudged(CGPoint(x: 4479.5, y: 1157.9), zones))
        XCTAssertNotNil(nudged(CGPoint(x: 3000, y: 1158), zones))
        XCTAssertNil(nudged(CGPoint(x: 3000, y: 1150), zones))
        XCTAssertNil(nudged(CGPoint(x: 1280, y: 1439), zones), "the Dock's own display passes")
        XCTAssertNil(nudged(CGPoint(x: 3000, y: 500), zones))
    }

    func testTheNudgeLeavesThePointerInsideTheScreen() {
        let zones = DockDisplayLockSupport.zones(displays: [main, side], anchorID: main.id,
                                                 orientation: .bottom, hotCorners: [])
        let point = CGPoint(x: 3000, y: 1158)
        let moved = nudged(point, zones)
        XCTAssertEqual(moved?.x, point.x)
        XCTAssertEqual(moved?.y, point.y - DockDisplayLockSupport.edgeDepth)
        XCTAssertTrue(side.frame.contains(moved!))
    }

    func testChoosingTheOtherDisplayMovesTheHeldEdge() {
        let zones = DockDisplayLockSupport.zones(displays: [main, side], anchorID: side.id,
                                                 orientation: .bottom, hotCorners: [])
        XCTAssertNotNil(nudged(CGPoint(x: 1280, y: 1439), zones))
        XCTAssertNil(nudged(CGPoint(x: 3000, y: 1157), zones))
    }

    func testWhereADisplaySitsBelowThePointerCrossesInstead() {
        let zones = DockDisplayLockSupport.zones(displays: [main, below], anchorID: below.id,
                                                 orientation: .bottom, hotCorners: [])
        XCTAssertNotNil(nudged(CGPoint(x: 100, y: 1439), zones))
        XCTAssertNotNil(nudged(CGPoint(x: 2400, y: 1439), zones))
        XCTAssertNil(nudged(CGPoint(x: 1000, y: 1439), zones))
        XCTAssertEqual(DockDisplayLockSupport.hardSegments(of: main, orientation: .bottom, others: [below]),
                       [0...640, 2152...2560])
    }

    func testSideDocksUseVerticalBands() {
        let leftZones = DockDisplayLockSupport.zones(displays: [main, side], anchorID: main.id,
                                                     orientation: .left, hotCorners: [])
        XCTAssertTrue(leftZones.isEmpty, "a display touching the main one leaves no edge to hold")

        let leftOnSide = DockDisplayLockSupport.zones(displays: [main, side], anchorID: side.id,
                                                     orientation: .left, hotCorners: [])
        XCTAssertNotNil(nudged(CGPoint(x: 0.5, y: 700), leftOnSide))
        XCTAssertNil(nudged(CGPoint(x: 12, y: 700), leftOnSide))

        let rightZones = DockDisplayLockSupport.zones(displays: [main, side], anchorID: main.id,
                                                     orientation: .right, hotCorners: [])
        XCTAssertNotNil(nudged(CGPoint(x: 4479, y: 600), rightZones))
        XCTAssertNil(nudged(CGPoint(x: 2559, y: 600), rightZones))
    }

    func testOneDisplayOrNoAnchorHoldsNothingBack() {
        XCTAssertTrue(DockDisplayLockSupport.zones(displays: [main], anchorID: main.id,
                                                   orientation: .bottom, hotCorners: []).isEmpty)
        XCTAssertTrue(DockDisplayLockSupport.zones(displays: [main, side], anchorID: nil,
                                                   orientation: .bottom, hotCorners: []).isEmpty)
        XCTAssertTrue(DockDisplayLockSupport.zones(displays: [main, side], anchorID: 42,
                                                   orientation: .bottom, hotCorners: []).isEmpty)
    }

    func testHotCornerFiresOnceThenHoldsTheEdge() {
        let zones = DockDisplayLockSupport.zones(displays: [main, side], anchorID: main.id,
                                                 orientation: .bottom,
                                                 hotCorners: [.bottomRight, .bottomLeft])
        var inCorner = false
        let corner = CGPoint(x: 4479.5, y: 1157.5)
        XCTAssertNil(DockDisplayLockSupport.nudged(corner, zones: zones, inCorner: &inCorner),
                     "the first move into the corner passes so it fires")
        XCTAssertNotNil(DockDisplayLockSupport.nudged(corner, zones: zones, inCorner: &inCorner))
        XCTAssertNotNil(DockDisplayLockSupport.nudged(CGPoint(x: 4000, y: 1157.5), zones: zones, inCorner: &inCorner),
                        "pressing on along the edge is still held")
        XCTAssertNil(DockDisplayLockSupport.nudged(corner, zones: zones, inCorner: &inCorner),
                     "leaving the corner and coming back lets it fire again")
    }

    func testHotCornerIsReachedThroughTheEdgeStrip() {
        let zones = DockDisplayLockSupport.zones(displays: [main, side], anchorID: main.id,
                                                 orientation: .bottom, hotCorners: [.bottomRight])
        var inCorner = false
        // Six points inside the side display's bottom edge: in the strip, and
        // in the corner now that the square is as deep as the strip.
        let approach = CGPoint(x: 4479.5, y: 1152)
        XCTAssertNil(DockDisplayLockSupport.nudged(approach, zones: zones, inCorner: &inCorner),
                     "the approach itself is the first entry, so the corner fires")
        XCTAssertNotNil(DockDisplayLockSupport.nudged(approach, zones: zones, inCorner: &inCorner))
        XCTAssertNotNil(nudged(CGPoint(x: 4000, y: 1152), zones),
                        "the rest of the strip still holds on the first touch")
    }

    func testCornerActionsReadTheDockDomain() {
        let domain: [String: Any] = ["wvous-br-corner": NSNumber(value: 1),
                                    "wvous-bl-corner": NSNumber(value: 2),
                                    "wvous-tl-corner": NSNumber(value: 0)]
        XCTAssertEqual(DockDisplayLockCorner.actions(in: domain), [.bottomLeft])
    }

    func testIntervalSubtraction() {
        XCTAssertEqual(DockDisplayLockSupport.subtract([2...4], from: 0...10), [0...2, 4...10])
        XCTAssertTrue(DockDisplayLockSupport.subtract([-5...20], from: 0...10).isEmpty)
        XCTAssertEqual(DockDisplayLockSupport.subtract([20...30], from: 0...10), [0...10])
    }

    // MARK: - Where the Dock is

    func testDockDisplayComesFromTheIconListFrame() {
        let displays = [main, side]
        XCTAssertEqual(DockDisplayLockSupport.display(
            holdingDockFrame: CGRect(x: 679, y: 1370, width: 1202, height: 60),
            orientation: .bottom, displays: displays), main.id)
        XCTAssertEqual(DockDisplayLockSupport.display(
            holdingDockFrame: CGRect(x: 3000, y: 1098, width: 600, height: 60),
            orientation: .bottom, displays: displays), side.id)
        XCTAssertEqual(DockDisplayLockSupport.display(
            holdingDockFrame: CGRect(x: 679, y: 1442, width: 1202, height: 60),
            orientation: .bottom, displays: displays), main.id,
                       "a list frame reported off its display on the short axis still finds it")
        XCTAssertNil(DockDisplayLockSupport.display(holdingDockFrame: .zero, orientation: .bottom,
                                                    displays: displays))
    }

    // MARK: - Calling the Dock over

    func testSummonPathPressesTheChosenEdgeFromInside() {
        let path = DockDisplayLockSupport.summonPath(to: side, orientation: .bottom)
        XCTAssertEqual(path.last?.point, CGPoint(x: side.frame.midX, y: side.frame.maxY - 1))
        XCTAssertTrue(path.allSatisfy { side.frame.contains($0.point) && $0.delta.dy > 0 && $0.delta.dx == 0 })

        let leftPath = DockDisplayLockSupport.summonPath(to: main, orientation: .left)
        XCTAssertEqual(leftPath.last?.point, CGPoint(x: 0, y: main.frame.midY))
        XCTAssertTrue(leftPath.allSatisfy { $0.delta.dx < 0 && $0.delta.dy == 0 })
    }

    func testSummonPathPressesAHardSegmentNotTheCoveredMiddle() {
        let path = DockDisplayLockSupport.summonPath(to: main, orientation: .bottom, others: [below])
        XCTAssertFalse(path.isEmpty)
        let x = path.last!.point.x
        XCTAssertEqual(path.last?.point.y, main.frame.maxY - 1)
        XCTAssertFalse((below.frame.minX..<below.frame.maxX).contains(x),
                       "the press would call the Dock onto the display below")
        XCTAssertTrue((0...640).contains(x) || (2152...2560).contains(x))

        let rightPath = DockDisplayLockSupport.summonPath(to: main, orientation: .right, others: [side])
        XCTAssertFalse(rightPath.isEmpty)
        XCTAssertEqual(rightPath.last?.point.x, main.frame.maxX - 1)
        XCTAssertTrue(rightPath.allSatisfy { $0.delta.dx > 0 && $0.delta.dy == 0 })
        XCTAssertFalse((side.frame.minY..<side.frame.maxY).contains(rightPath.last!.point.y),
                       "the press would call the Dock onto the display on the right")
    }
}
