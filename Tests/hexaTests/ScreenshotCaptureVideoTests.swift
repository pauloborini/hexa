// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import CoreGraphics
import XCTest
@testable import Hexa

final class ScreenshotCaptureVideoTests: XCTestCase {
    private struct DisplayFixture: Equatable {
        let id: Int
        let frame: CGRect
    }

    private let primary = DisplayFixture(id: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
    private let secondary = DisplayFixture(id: 2, frame: CGRect(x: 1920, y: 0, width: 2560, height: 1440))

    func testDisplayCoveringWindowReturnsSingleCoveringDisplay() {
        let displays = [primary, secondary]

        let onPrimary = ScreenshotCapturePolicy.displayCoveringWindow(
            CGRect(x: 200, y: 120, width: 1280, height: 720),
            in: displays,
            frame: \.frame)
        XCTAssertEqual(onPrimary, primary)

        let onSecondary = ScreenshotCapturePolicy.displayCoveringWindow(
            CGRect(x: 2100, y: 100, width: 1280, height: 720),
            in: displays,
            frame: \.frame)
        XCTAssertEqual(onSecondary, secondary)

        let fullPrimary = ScreenshotCapturePolicy.displayCoveringWindow(
            primary.frame,
            in: displays,
            frame: \.frame)
        XCTAssertEqual(fullPrimary, primary)
    }

    func testDisplayCoveringWindowReturnsNilWhenStraddlingTwoDisplays() {
        let straddling = CGRect(x: 1600, y: 100, width: 640, height: 480)
        XCTAssertNil(ScreenshotCapturePolicy.displayCoveringWindow(
            straddling,
            in: [primary, secondary],
            frame: \.frame))
    }

    func testDisplayCoveringWindowReturnsNilWhenPartiallyOffDisplay() {
        let displays = [primary]

        XCTAssertNil(ScreenshotCapturePolicy.displayCoveringWindow(
            CGRect(x: -40, y: 100, width: 800, height: 600),
            in: displays,
            frame: \.frame))
        XCTAssertNil(ScreenshotCapturePolicy.displayCoveringWindow(
            CGRect(x: 1400, y: 100, width: 800, height: 600),
            in: displays,
            frame: \.frame))
        XCTAssertNil(ScreenshotCapturePolicy.displayCoveringWindow(
            CGRect(x: 100, y: 700, width: 800, height: 600),
            in: displays,
            frame: \.frame))
    }

    func testDisplayCoveringWindowIgnoresSharedEdgeWithZeroIntersection() {
        let displays = [primary, secondary]

        let flushLeftOfSeam = CGRect(x: 920, y: 100, width: 1000, height: 600)
        XCTAssertEqual(ScreenshotCapturePolicy.displayCoveringWindow(
            flushLeftOfSeam,
            in: displays,
            frame: \.frame), primary)

        let flushRightOfSeam = CGRect(x: 1920, y: 100, width: 1000, height: 600)
        XCTAssertEqual(ScreenshotCapturePolicy.displayCoveringWindow(
            flushRightOfSeam,
            in: displays,
            frame: \.frame), secondary)
    }

    func testDisplayCoveringWindowReturnsNilForEmptyBounds() {
        let displays = [primary, secondary]

        XCTAssertNil(ScreenshotCapturePolicy.displayCoveringWindow(
            .zero,
            in: displays,
            frame: \.frame))
        XCTAssertNil(ScreenshotCapturePolicy.displayCoveringWindow(
            CGRect(x: 100, y: 100, width: 0, height: 200),
            in: displays,
            frame: \.frame))
        XCTAssertNil(ScreenshotCapturePolicy.displayCoveringWindow(
            CGRect(x: 100, y: 100, width: 200, height: 0),
            in: displays,
            frame: \.frame))
        XCTAssertNil(ScreenshotCapturePolicy.displayCoveringWindow(
            .null,
            in: displays,
            frame: \.frame))
        XCTAssertNil(ScreenshotCapturePolicy.displayCoveringWindow(
            CGRect(x: 100, y: 100, width: 400, height: 300),
            in: [DisplayFixture](),
            frame: \.frame))
    }

    func testLayerCoversFrameExactMatch() {
        let frame = CGRect(x: 100, y: 80, width: 1280, height: 720)
        XCTAssertTrue(ScreenshotCapturePolicy.layerCoversFrame(
            imageWidth: 2560,
            imageHeight: 1440,
            frame: frame,
            scale: 2))
        XCTAssertTrue(ScreenshotCapturePolicy.layerCoversFrame(
            imageWidth: 1280,
            imageHeight: 720,
            frame: frame,
            scale: 1))
    }

    func testLayerCoversFrameOnePixelTolerance() {
        let frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        XCTAssertTrue(ScreenshotCapturePolicy.layerCoversFrame(
            imageWidth: 1599,
            imageHeight: 1200,
            frame: frame,
            scale: 2))
        XCTAssertTrue(ScreenshotCapturePolicy.layerCoversFrame(
            imageWidth: 1601,
            imageHeight: 1201,
            frame: frame,
            scale: 2))
        XCTAssertFalse(ScreenshotCapturePolicy.layerCoversFrame(
            imageWidth: 1598,
            imageHeight: 1200,
            frame: frame,
            scale: 2))
        XCTAssertFalse(ScreenshotCapturePolicy.layerCoversFrame(
            imageWidth: 1600,
            imageHeight: 1202,
            frame: frame,
            scale: 2))
    }

    func testLayerCoversFrameReturnsFalseWhenClippedOffscreen() {
        let offscreenFrame = CGRect(x: -200, y: 100, width: 1200, height: 800)
        XCTAssertFalse(ScreenshotCapturePolicy.layerCoversFrame(
            imageWidth: 2000,
            imageHeight: 1600,
            frame: offscreenFrame,
            scale: 2))
        XCTAssertFalse(ScreenshotCapturePolicy.layerCoversFrame(
            imageWidth: 0,
            imageHeight: 0,
            frame: offscreenFrame,
            scale: 2))
        XCTAssertFalse(ScreenshotCapturePolicy.layerCoversFrame(
            imageWidth: 2400,
            imageHeight: 1600,
            frame: offscreenFrame,
            scale: 0))
    }
}
