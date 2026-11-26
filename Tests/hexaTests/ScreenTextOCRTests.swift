// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import AppKit
import CoreGraphics
import CoreImage
import Vision
import XCTest

@testable import Hexa

final class ScreenTextOCRTests: XCTestCase {

    // MARK: - Reading order & column layout

    func testJoinedRecognizedTextLegacyNilBoundingBoxesPreservesRowOrder() {
        let lines = [
            QuickToolsSupport.RecognizedLine(text: "world", x: 0.45, y: 0.802),
            QuickToolsSupport.RecognizedLine(text: "Hello", x: 0.10, y: 0.799),
            QuickToolsSupport.RecognizedLine(text: "Second line", x: 0.10, y: 0.65),
            QuickToolsSupport.RecognizedLine(text: "   ", x: 0.10, y: 0.50),
        ]

        XCTAssertEqual(
            QuickToolsSupport.joinedRecognizedText(lines, removingLineBreaks: false),
            "Hello\nworld\nSecond line"
        )
        XCTAssertEqual(
            QuickToolsSupport.joinedRecognizedText(lines, removingLineBreaks: true),
            "Hello world Second line"
        )

        let tightScript = [
            QuickToolsSupport.RecognizedLine(text: "東京", x: 0.10, y: 0.80),
            QuickToolsSupport.RecognizedLine(text: "駅", x: 0.10, y: 0.70),
        ]
        XCTAssertEqual(
            QuickToolsSupport.joinedRecognizedText(tightScript, removingLineBreaks: true),
            "東京駅"
        )
    }

    func testJoinedRecognizedTextSingleRowKeyValueStaysOnSameRow() {
        let singleRow = [
            QuickToolsSupport.RecognizedLine(
                text: "100%",
                x: 0.85,
                y: 0.50,
                boundingBox: CGRect(x: 0.85, y: 0.46, width: 0.10, height: 0.08)
            ),
            QuickToolsSupport.RecognizedLine(
                text: "Label",
                x: 0.05,
                y: 0.50,
                boundingBox: CGRect(x: 0.05, y: 0.46, width: 0.15, height: 0.08)
            ),
        ]

        XCTAssertEqual(
            QuickToolsSupport.joinedRecognizedText(singleRow, removingLineBreaks: true),
            "Label 100%"
        )
        XCTAssertEqual(
            QuickToolsSupport.joinedRecognizedText(singleRow, removingLineBreaks: false),
            "Label\n100%"
        )

        let mixedOneSidedRight = [
            QuickToolsSupport.RecognizedLine(
                text: "Summary",
                x: 0.05,
                y: 0.80,
                boundingBox: CGRect(x: 0.05, y: 0.76, width: 0.20, height: 0.08)
            ),
            QuickToolsSupport.RecognizedLine(
                text: "Status",
                x: 0.05,
                y: 0.60,
                boundingBox: CGRect(x: 0.05, y: 0.56, width: 0.15, height: 0.08)
            ),
            QuickToolsSupport.RecognizedLine(
                text: "OK",
                x: 0.85,
                y: 0.60,
                boundingBox: CGRect(x: 0.85, y: 0.56, width: 0.10, height: 0.08)
            ),
        ]
        XCTAssertEqual(
            QuickToolsSupport.joinedRecognizedText(mixedOneSidedRight, removingLineBreaks: true),
            "Summary Status OK"
        )
    }

    func testJoinedRecognizedTextTwoColumnsReadsColumnOneBeforeColumnTwo() {
        // Prose columns: independent line flow with offset baselines and a
        // different line count on each side.
        let twoColumns = [
            QuickToolsSupport.RecognizedLine(
                text: "Right 1",
                x: 0.55,
                y: 0.76,
                boundingBox: CGRect(x: 0.55, y: 0.73, width: 0.40, height: 0.06)
            ),
            QuickToolsSupport.RecognizedLine(
                text: "Left 2",
                x: 0.05,
                y: 0.65,
                boundingBox: CGRect(x: 0.05, y: 0.62, width: 0.37, height: 0.06)
            ),
            QuickToolsSupport.RecognizedLine(
                text: "Left 1",
                x: 0.05,
                y: 0.80,
                boundingBox: CGRect(x: 0.05, y: 0.77, width: 0.37, height: 0.06)
            ),
            QuickToolsSupport.RecognizedLine(
                text: "Left 3",
                x: 0.05,
                y: 0.50,
                boundingBox: CGRect(x: 0.05, y: 0.47, width: 0.37, height: 0.06)
            ),
            QuickToolsSupport.RecognizedLine(
                text: "Right 2",
                x: 0.55,
                y: 0.61,
                boundingBox: CGRect(x: 0.55, y: 0.58, width: 0.40, height: 0.06)
            ),
        ]

        XCTAssertEqual(
            QuickToolsSupport.joinedRecognizedText(twoColumns, removingLineBreaks: false),
            "Left 1\nLeft 2\nLeft 3\n\nRight 1\nRight 2"
        )
        XCTAssertEqual(
            QuickToolsSupport.joinedRecognizedText(twoColumns, removingLineBreaks: true),
            "Left 1 Left 2 Left 3 Right 1 Right 2"
        )

        let withHeader = [
            QuickToolsSupport.RecognizedLine(
                text: "HEADER",
                x: 0.05,
                y: 0.92,
                boundingBox: CGRect(x: 0.05, y: 0.89, width: 0.88, height: 0.06)
            )
        ] + twoColumns

        XCTAssertEqual(
            QuickToolsSupport.joinedRecognizedText(withHeader, removingLineBreaks: false),
            "HEADER\n\nLeft 1\nLeft 2\nLeft 3\n\nRight 1\nRight 2"
        )
    }

    func testJoinedRecognizedTextAlignedTableReadsRowByRow() {
        func cell(_ text: String, x: Double, y: Double, width: Double) -> QuickToolsSupport.RecognizedLine {
            QuickToolsSupport.RecognizedLine(
                text: text,
                x: x,
                y: y,
                boundingBox: CGRect(x: x, y: y - 0.03, width: width, height: 0.06)
            )
        }
        let table = [
            cell("8 GB", x: 0.60, y: 0.65, width: 0.12),
            cell("CPU", x: 0.05, y: 0.80, width: 0.10),
            cell("200 GB", x: 0.60, y: 0.50, width: 0.16),
            cell("Memory", x: 0.05, y: 0.65, width: 0.18),
            cell("45%", x: 0.60, y: 0.80, width: 0.10),
            cell("Disk", x: 0.05, y: 0.50, width: 0.11),
        ]

        XCTAssertEqual(
            QuickToolsSupport.joinedRecognizedText(table, removingLineBreaks: true),
            "CPU 45% Memory 8 GB Disk 200 GB"
        )
        XCTAssertEqual(
            QuickToolsSupport.joinedRecognizedText(table, removingLineBreaks: false),
            "CPU\n45%\nMemory\n8 GB\nDisk\n200 GB"
        )

        let withHeader = [
            QuickToolsSupport.RecognizedLine(
                text: "System status",
                x: 0.05,
                y: 0.92,
                boundingBox: CGRect(x: 0.05, y: 0.89, width: 0.88, height: 0.06)
            )
        ] + table
        XCTAssertEqual(
            QuickToolsSupport.joinedRecognizedText(withHeader, removingLineBreaks: true),
            "System status CPU 45% Memory 8 GB Disk 200 GB"
        )
    }

    func testJoinedRecognizedTextTallNormalizedRowSpacingPreservesOrder() {
        let tallLines = [
            QuickToolsSupport.RecognizedLine(
                text: "Line C",
                x: 0.05,
                y: 0.8950,
                boundingBox: CGRect(x: 0.05, y: 0.8940, width: 0.30, height: 0.002)
            ),
            QuickToolsSupport.RecognizedLine(
                text: "Line A",
                x: 0.25,
                y: 0.9000,
                boundingBox: CGRect(x: 0.25, y: 0.8990, width: 0.30, height: 0.002)
            ),
            QuickToolsSupport.RecognizedLine(
                text: "Line B",
                x: 0.15,
                y: 0.8975,
                boundingBox: CGRect(x: 0.15, y: 0.8965, width: 0.30, height: 0.002)
            ),
        ]

        XCTAssertEqual(
            QuickToolsSupport.joinedRecognizedText(tallLines, removingLineBreaks: false),
            "Line A\nLine B\nLine C"
        )
    }

    func testJoinedBarcodePayloadsDeduplicatesInReadingOrder() {
        let codes = [
            QuickToolsSupport.DecodedBarcode(payload: "https://example.com/2", x: 0.70, y: 0.80),
            QuickToolsSupport.DecodedBarcode(payload: "https://example.com/1", x: 0.15, y: 0.80),
            QuickToolsSupport.DecodedBarcode(payload: "https://example.com/1", x: 0.16, y: 0.80),
            QuickToolsSupport.DecodedBarcode(payload: "https://example.com/3", x: 0.15, y: 0.40),
        ]

        XCTAssertEqual(
            QuickToolsSupport.joinedBarcodePayloads(codes),
            "https://example.com/1\nhttps://example.com/2\nhttps://example.com/3"
        )
    }

    // MARK: - Vision OCR end-to-end fixtures

    func testOutcomeMulticolumnImageReadsColumnOneBeforeColumnTwo() throws {
        let image = try XCTUnwrap(Self.multicolumnTextImage())

        for removeBreaks in [false, true] {
            let outcome = ScreenTextService.outcome(
                for: image,
                detectQRCodes: false,
                removeLineBreaks: removeBreaks
            )
            guard case .text(let text) = outcome else {
                return XCTFail("Expected recognized text, got \(outcome)")
            }

            let normalized = text.uppercased()
            let markers = [
                "ALPHA ONE",
                "ALPHA TWO",
                "ALPHA THREE",
                "ALPHA FOUR",
                "ALPHA FIVE",
                "OMEGA ONE",
                "OMEGA TWO",
                "OMEGA THREE",
            ]
            var previousEnd = normalized.startIndex
            for marker in markers {
                let range = try XCTUnwrap(
                    normalized.range(of: marker),
                    "Missing marker '\(marker)' in recognized text: \(text)"
                )
                XCTAssertTrue(
                    range.lowerBound >= previousEnd,
                    "Expected '\(marker)' after prior markers in: \(text)"
                )
                previousEnd = range.upperBound
            }
        }
    }

    func testOutcomeAlignedTableImageReadsRowByRow() throws {
        let image = try XCTUnwrap(Self.alignedTableImage())
        let outcome = ScreenTextService.outcome(
            for: image,
            detectQRCodes: false,
            removeLineBreaks: true
        )
        guard case .text(let text) = outcome else {
            return XCTFail("Expected recognized text, got \(outcome)")
        }

        let normalized = text.uppercased()
        let markers = ["PROCESSOR", "45 PERCENT", "MEMORY", "EIGHT GIGS", "STORAGE", "TWO HUNDRED"]
        var previousEnd = normalized.startIndex
        for marker in markers {
            let range = try XCTUnwrap(
                normalized.range(of: marker),
                "Missing marker '\(marker)' in recognized text: \(text)"
            )
            XCTAssertTrue(range.lowerBound >= previousEnd, "Expected row order in: \(text)")
            previousEnd = range.upperBound
        }
    }

    func testOutcomeSingleRowKeyValuePairKeepsLeftToRightOrder() throws {
        let image = try XCTUnwrap(Self.keyValueRowImage(left: "BATTERY", right: "95%"))
        let outcome = ScreenTextService.outcome(
            for: image,
            detectQRCodes: false,
            removeLineBreaks: true
        )
        guard case .text(let text) = outcome else {
            return XCTFail("Expected recognized text, got \(outcome)")
        }
        let upper = text.uppercased()
        let leftRange = try XCTUnwrap(upper.range(of: "BATTERY"), "Recognized: \(text)")
        let rightRange = try XCTUnwrap(upper.range(of: "95%"), "Recognized: \(text)")
        XCTAssertTrue(leftRange.upperBound <= rightRange.lowerBound, "Recognized: \(text)")
    }

    func testOutcomeTallScrollingCapturePreservesWidthAndTileOrder() throws {
        let image = try XCTUnwrap(Self.tallScrollingImage())
        let outcome = ScreenTextService.outcome(
            for: image,
            detectQRCodes: false,
            removeLineBreaks: false
        )
        guard case .text(let text) = outcome else {
            return XCTFail("Expected recognized text on tall image, got \(outcome)")
        }

        let upper = text.uppercased()
        let topRange = try XCTUnwrap(upper.range(of: "TOP SECTION"), "Recognized: \(text)")
        let seamRange = try XCTUnwrap(upper.range(of: "SEAM SECTION"), "Recognized: \(text)")
        let bottomRange = try XCTUnwrap(upper.range(of: "BOTTOM SECTION"), "Recognized: \(text)")
        XCTAssertTrue(topRange.upperBound < seamRange.lowerBound, "Recognized: \(text)")
        XCTAssertTrue(seamRange.upperBound < bottomRange.lowerBound, "Recognized: \(text)")
    }

    func testOutcomeComplexLowContrastBackgroundRecognizesText() throws {
        let image = try XCTUnwrap(Self.lowContrastTexturedImage(text: "HEXA CONTRAST"))
        let outcome = ScreenTextService.outcome(
            for: image,
            detectQRCodes: false,
            removeLineBreaks: true
        )
        guard case .text(let text) = outcome else {
            return XCTFail("Expected recognized text on low-contrast image, got \(outcome)")
        }
        let upper = text.uppercased()
        XCTAssertTrue(upper.contains("HEXA"), "Recognized: \(text)")
        XCTAssertTrue(upper.contains("CONTRAST"), "Recognized: \(text)")
    }

    func testWashedOutTextIsReadOnlyThroughTheContrastFallbackPass() throws {
        let image = try XCTUnwrap(Self.washedOutTexturedImage(text: "HEXA CONTRAST"))
        XCTAssertEqual(Self.primaryPassText(image), "", "The primary pass alone must find nothing")

        let enhanced = try XCTUnwrap(QuickToolsSupport.contrastNormalizedImage(image))
        let fallback = Self.primaryPassText(enhanced).uppercased()
        XCTAssertTrue(fallback.contains("HEXA") && fallback.contains("CONTRAST"), "Fallback read: \(fallback)")

        let outcome = ScreenTextService.outcome(for: image, detectQRCodes: false, removeLineBreaks: true)
        guard case .text(let text) = outcome else {
            return XCTFail("Expected recognized text through the fallback, got \(outcome)")
        }
        XCTAssertTrue(text.uppercased().contains("CONTRAST"), "Recognized: \(text)")
    }

    // MARK: - QR / 2D Barcode resilience

    func testInvertedQRCodeDecodedByBarcodeDetectorAndScreenTextService() throws {
        let payload = "https://hexa.example/qr-ok"
        let qrImage = try XCTUnwrap(
            Self.qrImage(
                payload: payload,
                moduleColor: CIColor(red: 0.92, green: 0.94, blue: 0.97),
                backgroundColor: CIColor(red: 0.10, green: 0.12, blue: 0.16),
                quietZoneCGColor: CGColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 1.0)
            )
        )

        let expectedURL = try XCTUnwrap(URL(string: payload))
        let expectedReading = BarcodeDetector.Reading(payload: payload, url: expectedURL)

        XCTAssertEqual(BarcodeDetector.read(qrImage), expectedReading)
        XCTAssertEqual(
            ScreenTextService.outcome(for: qrImage, detectQRCodes: true, removeLineBreaks: false),
            .qr(expectedReading)
        )
    }

    func testLowContrastQRCodeDecodedByBarcodeDetector() throws {
        let payload = "https://hexa.example/low-contrast"
        let qrImage = try XCTUnwrap(
            Self.qrImage(
                payload: payload,
                moduleColor: CIColor(red: 0.36, green: 0.36, blue: 0.36),
                backgroundColor: CIColor(red: 0.52, green: 0.52, blue: 0.52),
                quietZoneCGColor: CGColor(red: 0.52, green: 0.52, blue: 0.52, alpha: 1.0)
            )
        )

        let expectedURL = try XCTUnwrap(URL(string: payload))
        XCTAssertEqual(
            BarcodeDetector.read(qrImage),
            BarcodeDetector.Reading(payload: payload, url: expectedURL)
        )
    }

    func testBarcodeReadingPreservesURLWhenSameCodeAppearsTwice() throws {
        let payload = "https://hexa.example/deduped"
        let expectedURL = try XCTUnwrap(URL(string: payload))
        let duplicateTiles = [
            QuickToolsSupport.DecodedBarcode(payload: payload, x: 0.5, y: 0.23),
            QuickToolsSupport.DecodedBarcode(payload: payload, x: 0.5, y: 0.231),
        ]

        XCTAssertEqual(
            BarcodeDetector.reading(from: duplicateTiles),
            BarcodeDetector.Reading(payload: payload, url: expectedURL)
        )
    }

    func testOutcomeTallImageDecodesMultipleQRCodesAcrossTilesInReadingOrder() throws {
        let topPayload = "https://hexa.example/top-tile"
        let bottomPayload = "https://hexa.example/bottom-tile"
        let image = try XCTUnwrap(
            Self.tallImageWithQRCodes([
                (payload: bottomPayload, rect: CGRect(x: 340, y: 300, width: 320, height: 320)),
                (payload: topPayload, rect: CGRect(x: 340, y: 4600, width: 320, height: 320)),
            ])
        )

        let expectedReading = BarcodeDetector.Reading(
            payload: "\(topPayload)\n\(bottomPayload)",
            url: nil
        )
        XCTAssertEqual(
            ScreenTextService.outcome(for: image, detectQRCodes: true, removeLineBreaks: false),
            .qr(expectedReading)
        )
    }

    func testOutcomeTallImageDecodesQRCodeSpanningTileSeam() throws {
        let payload = "https://hexa.example/seam-qr"
        let seamRect = CGRect(x: 340, y: 1024, width: 320, height: 320)
        let image = try XCTUnwrap(
            Self.tallImageWithQRCodes([
                (payload: payload, rect: seamRect),
            ])
        )

        let topTile = try XCTUnwrap(image.cropping(to: CGRect(x: 0, y: 0, width: 1000, height: 4096)))
        let bottomTile = try XCTUnwrap(image.cropping(to: CGRect(x: 0, y: 3936, width: 1000, height: 1264)))
        XCTAssertNil(BarcodeDetector.read(topTile))
        XCTAssertNil(BarcodeDetector.read(bottomTile))

        let expectedURL = try XCTUnwrap(URL(string: payload))
        XCTAssertEqual(
            ScreenTextService.outcome(for: image, detectQRCodes: true, removeLineBreaks: false),
            .qr(BarcodeDetector.Reading(payload: payload, url: expectedURL))
        )
    }

    // MARK: - Primary pass mirrors

    /// The same Vision requests the service runs before any fallback: the
    /// accurate model, then the fast one, on the untouched image.
    private static func primaryPassText(_ image: CGImage) -> String {
        for level in [VNRequestTextRecognitionLevel.accurate, .fast] {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = level
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = level == .accurate
            request.recognitionLanguages = ["en-US"]
            guard (try? VNImageRequestHandler(cgImage: image, options: [:]).perform([request])) != nil
            else { continue }
            let text = (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { return text }
        }
        return ""
    }

    // MARK: - Image fixture generators

    private static func makeBitmapContext(width: Int, height: Int) -> CGContext? {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        return CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    private static func drawString(
        _ string: String,
        at point: NSPoint,
        font: NSFont,
        color: NSColor,
        in context: CGContext
    ) {
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        defer { NSGraphicsContext.current = previous }

        (string as NSString).draw(
            at: point,
            withAttributes: [
                .font: font,
                .foregroundColor: color,
            ]
        )
    }

    /// Two prose columns: the left one runs five lines, the right one three,
    /// with baselines offset by half a line so the rows never align as a grid.
    private static func multicolumnTextImage() -> CGImage? {
        let width = 1000
        let height = 480
        guard let context = makeBitmapContext(width: width, height: height) else { return nil }
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let font = NSFont.monospacedSystemFont(ofSize: 28, weight: .semibold)
        let leftLines = ["ALPHA ONE", "ALPHA TWO", "ALPHA THREE", "ALPHA FOUR", "ALPHA FIVE"]
        let rightLines = ["OMEGA ONE", "OMEGA TWO", "OMEGA THREE"]
        for (index, line) in leftLines.enumerated() {
            let y = 400 - CGFloat(index) * 76
            drawString(line, at: NSPoint(x: 50, y: y), font: font, color: .black, in: context)
        }
        for (index, line) in rightLines.enumerated() {
            let y = 362 - CGFloat(index) * 76
            drawString(line, at: NSPoint(x: 560, y: y), font: font, color: .black, in: context)
        }
        return context.makeImage()
    }

    /// A table: every row holds one cell per column on the same baseline.
    private static func alignedTableImage() -> CGImage? {
        let width = 1000
        let height = 400
        guard let context = makeBitmapContext(width: width, height: height) else { return nil }
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let font = NSFont.monospacedSystemFont(ofSize: 30, weight: .semibold)
        let rows = [("PROCESSOR", "45 PERCENT"), ("MEMORY", "EIGHT GIGS"), ("STORAGE", "TWO HUNDRED")]
        for (index, row) in rows.enumerated() {
            let y = 300 - CGFloat(index) * 100
            drawString(row.0, at: NSPoint(x: 50, y: y), font: font, color: .black, in: context)
            drawString(row.1, at: NSPoint(x: 600, y: y), font: font, color: .black, in: context)
        }
        return context.makeImage()
    }

    private static func keyValueRowImage(left: String, right: String) -> CGImage? {
        let width = 800
        let height = 160
        guard let context = makeBitmapContext(width: width, height: height) else { return nil }
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let font = NSFont.systemFont(ofSize: 40, weight: .semibold)
        drawString(left, at: NSPoint(x: 40, y: 55), font: font, color: .black, in: context)
        drawString(right, at: NSPoint(x: 620, y: 55), font: font, color: .black, in: context)
        return context.makeImage()
    }

    private static func tallScrollingImage() -> CGImage? {
        let width = 1000
        let height = 5200
        guard let context = makeBitmapContext(width: width, height: height) else { return nil }
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let font = NSFont.systemFont(ofSize: 44, weight: .bold)
        drawString("TOP SECTION", at: NSPoint(x: 80, y: 4920), font: font, color: .black, in: context)
        drawString("SEAM SECTION", at: NSPoint(x: 80, y: 1090), font: font, color: .black, in: context)
        drawString("BOTTOM SECTION", at: NSPoint(x: 80, y: 140), font: font, color: .black, in: context)
        return context.makeImage()
    }

    private static func lowContrastTexturedImage(text: String) -> CGImage? {
        let width = 900
        let height = 260
        guard let context = makeBitmapContext(width: width, height: height) else { return nil }

        // Deterministic gradient + fine texture around 0.18...0.24 luminance.
        for x in stride(from: 0, to: width, by: 6) {
            let progress = CGFloat(x) / CGFloat(width)
            let stripe: CGFloat = (x / 6).isMultiple(of: 2) ? 0.015 : -0.015
            let base = 0.19 + progress * 0.04 + stripe
            context.setFillColor(CGColor(red: base, green: base + 0.01, blue: base + 0.02, alpha: 1.0))
            context.fill(CGRect(x: x, y: 0, width: 6, height: height))
        }
        for y in stride(from: 0, to: height, by: 12) {
            context.setFillColor(CGColor(gray: 0.25, alpha: 0.18))
            context.fill(CGRect(x: 0, y: y, width: width, height: 2))
        }

        let font = NSFont.systemFont(ofSize: 54, weight: .bold)
        let subtleLightText = NSColor(calibratedRed: 0.34, green: 0.35, blue: 0.37, alpha: 1.0)
        drawString(text, at: NSPoint(x: 60, y: 95), font: font, color: subtleLightText, in: context)
        return context.makeImage()
    }

    /// Faint text on a striped near-white background: too little contrast for
    /// the primary pass, readable once the contrast fallback stretches it.
    private static func washedOutTexturedImage(text: String) -> CGImage? {
        let width = 900
        let height = 260
        guard let context = makeBitmapContext(width: width, height: height) else { return nil }
        for x in stride(from: 0, to: width, by: 6) {
            let base: CGFloat = (x / 6).isMultiple(of: 2) ? 0.972 : 0.968
            context.setFillColor(CGColor(gray: base, alpha: 1.0))
            context.fill(CGRect(x: x, y: 0, width: 6, height: height))
        }

        let font = NSFont.systemFont(ofSize: 54, weight: .bold)
        let faintText = NSColor(calibratedWhite: 0.962, alpha: 1.0)
        drawString(text, at: NSPoint(x: 60, y: 95), font: font, color: faintText, in: context)
        return context.makeImage()
    }

    private static func qrImage(
        payload: String,
        moduleColor: CIColor,
        backgroundColor: CIColor,
        quietZoneCGColor: CGColor
    ) -> CGImage? {
        guard let data = payload.data(using: .utf8),
              let generator = CIFilter(name: "CIQRCodeGenerator"),
              let colorFilter = CIFilter(name: "CIFalseColor")
        else { return nil }

        generator.setValue(data, forKey: "inputMessage")
        generator.setValue("M", forKey: "inputCorrectionLevel")
        guard let rawQR = generator.outputImage else { return nil }

        colorFilter.setValue(rawQR, forKey: kCIInputImageKey)
        colorFilter.setValue(moduleColor, forKey: "inputColor0")
        colorFilter.setValue(backgroundColor, forKey: "inputColor1")
        guard let coloredQR = colorFilter.outputImage else { return nil }

        let ciContext = CIContext(options: [.cacheIntermediates: false])
        guard let baseCG = ciContext.createCGImage(coloredQR, from: rawQR.extent) else { return nil }

        let canvasSize = 320
        let inset = 40
        guard let context = makeBitmapContext(width: canvasSize, height: canvasSize) else { return nil }
        context.setFillColor(quietZoneCGColor)
        context.fill(CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize))
        context.interpolationQuality = .none
        context.draw(
            baseCG,
            in: CGRect(x: inset, y: inset, width: canvasSize - inset * 2, height: canvasSize - inset * 2)
        )
        return context.makeImage()
    }

    private static func tallImageWithQRCodes(
        _ codes: [(payload: String, rect: CGRect)],
        width: Int = 1000,
        height: Int = 5200
    ) -> CGImage? {
        guard let context = makeBitmapContext(width: width, height: height) else { return nil }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .none

        let black = CIColor(red: 0, green: 0, blue: 0)
        let white = CIColor(red: 1, green: 1, blue: 1)
        let quietZone = CGColor(gray: 1, alpha: 1)
        for entry in codes {
            guard let qr = qrImage(
                payload: entry.payload,
                moduleColor: black,
                backgroundColor: white,
                quietZoneCGColor: quietZone
            ) else { return nil }
            context.draw(qr, in: entry.rect)
        }
        return context.makeImage()
    }
}
