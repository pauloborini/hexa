// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import Vision

/// Screen OCR: the user picks an area on the app's own capture surface, the
/// text in it is recognized offline with Vision and lands on the clipboard.
/// Needs Screen Recording, requested contextually on first use.
///
/// The picking and the capture both happen here rather than through the
/// system's capture command. A separate command is judged by macOS on its own
/// standing, which on recent versions can be refused even while this app is
/// allowed, and a refused command writes no file and says nothing: the tool
/// looked dead with no crosshair, no message and nothing to fix.
final class ScreenTextService: ObservableObject {
    static let shared = ScreenTextService()

    private var recognitionGeneration = 0

    private init() {}

    func syncWithPreferences() {
        guard AppFeature.screenOCR.isAvailable else {
            cancelSession()
            return
        }
    }

    func suspend() {
        cancelSession()
    }

    private func cancelSession() {
        recognitionGeneration += 1
    }

    func capture() {
        ScreenCaptureService.shared.capture(initial: .text)
    }

    func receiveUnifiedCapture(_ capture: ScreenshotSelectionController.Capture) {
        recognitionGeneration += 1
        recognize(capture.image)
    }

    /// What a captured region turned out to hold.
    enum Outcome: Equatable {
        case qr(BarcodeDetector.Reading)
        case text(String)
        case empty
    }

    private func recognize(_ image: CGImage) {
        let generation = recognitionGeneration
        let pasteboardChangeCount = NSPasteboard.general.changeCount
        let detectQRCodes = UserDefaults.standard.bool(forKey: DefaultsKey.screenOCRDetectQRCodes)
        let removeLineBreaks = UserDefaults.standard.bool(forKey: DefaultsKey.screenOCRRemoveLineBreaks)
        let fallbackLanguages = HexaTextRecognition.recognitionLanguages(for: L10n.shared.language.rawValue)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let outcome = autoreleasepool {
                ScreenTextService.outcome(for: image,
                                          detectQRCodes: detectQRCodes,
                                          removeLineBreaks: removeLineBreaks,
                                          fallbackLanguages: fallbackLanguages)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.recognitionGeneration == generation else { return }
                let strings = L10n.shared.s
                switch outcome {
                case .qr(let reading):
                    // Show what the code holds instead of copying it blindly;
                    // the panel offers copy and, for a link, open.
                    QRResultController.shared.show(reading: reading)
                case .text(let text):
                    guard QuickToolsSupport.shouldCopyRecognizedText(
                        recognitionGeneration: generation,
                        currentGeneration: self.recognitionGeneration,
                        initialPasteboardChangeCount: pasteboardChangeCount,
                        currentPasteboardChangeCount: NSPasteboard.general.changeCount
                    ) else {
                        // The discard is the guard doing its job (the person
                        // copied something while recognition ran); saying
                        // nothing made the tool read as dead.
                        QuickToolHUD.show(icon: "text.viewfinder",
                                          message: strings.ocrClipboardChanged)
                        return
                    }
                    Self.copyToPasteboard(text)
                    QuickToolHUD.show(icon: "text.viewfinder", message: strings.ocrCopied)
                case .empty:
                    QuickToolHUD.show(icon: "text.viewfinder", message: strings.ocrNoText)
                }
            }
        }
    }

    /// Decides what a captured region holds. A QR code wins over the text:
    /// it is the thing the user pointed at, and the scan is a fast pass that
    /// falls through to text recognition when no code is found. Pure enough
    /// to exercise directly on a known image.
    static func outcome(for image: CGImage,
                        detectQRCodes: Bool,
                        removeLineBreaks: Bool,
                        fallbackLanguages: [String] = ["en-US"]) -> Outcome {
        autoreleasepool {
            let widthSafeImage = downscaleWidthIfNeeded(image, maxWidth: 4096)
            let tiles = verticalTilesIfNeeded(for: widthSafeImage)

            if detectQRCodes {
                if let reading = detectQRReading(in: tiles,
                                                 fullImage: widthSafeImage,
                                                 totalHeight: widthSafeImage.height) {
                    return .qr(reading)
                }
            }

            var lines = recognizeTextLines(in: tiles,
                                           totalHeight: widthSafeImage.height,
                                           fallbackLanguages: fallbackLanguages)
            if !hasReadableText(lines) {
                let enhancedTiles = tiles.compactMap { tile -> ImageTile? in
                    autoreleasepool {
                        guard let enhanced = QuickToolsSupport.contrastNormalizedImage(tile.image)
                        else { return nil }
                        return tile.replacingImage(enhanced)
                    }
                }
                if !enhancedTiles.isEmpty {
                    lines = recognizeTextLines(in: enhancedTiles,
                                               totalHeight: widthSafeImage.height,
                                               fallbackLanguages: fallbackLanguages)
                }
            }
            if !hasReadableText(lines) {
                let invertedTiles = tiles.compactMap { tile -> ImageTile? in
                    autoreleasepool {
                        guard let inverted = QuickToolsSupport.contrastNormalizedImage(tile.image, invert: true)
                        else { return nil }
                        return tile.replacingImage(inverted)
                    }
                }
                if !invertedTiles.isEmpty {
                    lines = recognizeTextLines(in: invertedTiles,
                                               totalHeight: widthSafeImage.height,
                                               fallbackLanguages: fallbackLanguages)
                }
            }

            let text = QuickToolsSupport.joinedRecognizedText(lines,
                                                             removingLineBreaks: removeLineBreaks)
            return text.isEmpty ? .empty : .text(text)
        }
    }

    private struct ImageTile {
        let image: CGImage
        let topPx: Int
        let heightPx: Int
        let ownedTopPx: Double
        let ownedBottomPx: Double

        func replacingImage(_ image: CGImage) -> ImageTile {
            ImageTile(image: image,
                      topPx: topPx,
                      heightPx: heightPx,
                      ownedTopPx: ownedTopPx,
                      ownedBottomPx: ownedBottomPx)
        }
    }

    private static func detectQRReading(
        in tiles: [ImageTile],
        fullImage: CGImage,
        totalHeight: Int
    ) -> BarcodeDetector.Reading? {
        if tiles.count == 1 {
            return BarcodeDetector.read(tiles[0].image)
        }
        guard tiles.count > 1 else { return nil }

        let fullHeight = Double(max(1, totalHeight))
        let mappedCodes = tiles.flatMap { tile in
            let bottomOffsetPx = Double(totalHeight - (tile.topPx + tile.heightPx))
            let tileHeight = Double(tile.heightPx)
            return BarcodeDetector.decode(tile.image).map { code in
                QuickToolsSupport.DecodedBarcode(
                    payload: code.payload,
                    x: code.x,
                    y: (bottomOffsetPx + code.y * tileHeight) / fullHeight
                )
            }
        }
        if let reading = BarcodeDetector.reading(from: mappedCodes) {
            return reading
        }
        let downsampledFullImage = downscaleIfNeeded(fullImage, maxDimension: 4096)
        return BarcodeDetector.read(downsampledFullImage)
    }

    private static func downscaleWidthIfNeeded(_ image: CGImage, maxWidth: Int = 4096) -> CGImage {
        let width = image.width
        let height = image.height
        guard width > maxWidth, height > 0 else { return image }
        let scale = Double(maxWidth) / Double(width)
        let targetHeight = max(1, Int((Double(height) * scale).rounded()))
        return resizedImage(image, width: maxWidth, height: targetHeight)
    }

    private static func downscaleIfNeeded(_ image: CGImage, maxDimension: Int = 4096) -> CGImage {
        let width = image.width
        let height = image.height
        let largestSide = max(width, height)
        guard largestSide > maxDimension, width > 0, height > 0 else { return image }
        let scale = Double(maxDimension) / Double(largestSide)
        let targetWidth = max(1, Int((Double(width) * scale).rounded()))
        let targetHeight = max(1, Int((Double(height) * scale).rounded()))
        return resizedImage(image, width: targetWidth, height: targetHeight)
    }

    private static func resizedImage(_ image: CGImage, width: Int, height: Int) -> CGImage {
        autoreleasepool {
            guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? image.colorSpace,
                  let context = CGContext(
                      data: nil,
                      width: width,
                      height: height,
                      bitsPerComponent: 8,
                      bytesPerRow: 0,
                      space: colorSpace,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else {
                return image
            }
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return context.makeImage() ?? image
        }
    }

    private static func verticalTilesIfNeeded(for image: CGImage) -> [ImageTile] {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return [] }

        let maxPixels = 12_000_000
        let maxDimension = 4096
        guard height > maxDimension || width * height > maxPixels else {
            return [ImageTile(image: image,
                              topPx: 0,
                              heightPx: height,
                              ownedTopPx: 0,
                              ownedBottomPx: Double(height))]
        }

        let maxTileHeight = min(maxDimension, max(1, maxPixels / width))
        let overlap = min(160, maxTileHeight / 4)
        let stride = max(1, maxTileHeight - overlap)
        let minTailHeight = min(maxTileHeight, 512)

        var ranges: [(top: Int, height: Int)] = []
        var top = 0
        while top < height {
            var tileHeight = min(maxTileHeight, height - top)
            if top > 0, tileHeight < minTailHeight {
                top = max(0, height - minTailHeight)
                tileHeight = height - top
            }
            ranges.append((top: top, height: tileHeight))
            if top + tileHeight >= height { break }
            top += stride
        }

        return ranges.enumerated().compactMap { index, range in
            let rect = CGRect(x: 0, y: range.top, width: width, height: range.height)
            guard let cropped = image.cropping(to: rect) else { return nil }
            let ownedTop: Double = index == 0
                ? 0
                : 0.5 * Double(range.top + (ranges[index - 1].top + ranges[index - 1].height))
            let ownedBottom: Double = index == ranges.count - 1
                ? Double(height)
                : 0.5 * Double(ranges[index + 1].top + (range.top + range.height))
            return ImageTile(image: cropped,
                             topPx: range.top,
                             heightPx: range.height,
                             ownedTopPx: ownedTop,
                             ownedBottomPx: ownedBottom)
        }
    }

    private static func hasReadableText(_ lines: [QuickToolsSupport.RecognizedLine]) -> Bool {
        lines.contains { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private static func recognizeTextLines(
        in tiles: [ImageTile],
        totalHeight: Int,
        fallbackLanguages: [String]
    ) -> [QuickToolsSupport.RecognizedLine] {
        let accurate = recognizedLines(in: tiles,
                                       totalHeight: totalHeight,
                                       level: .accurate,
                                       automaticallyDetectLanguage: true,
                                       preferredLanguages: fallbackLanguages)
        if hasReadableText(accurate) { return accurate }

        // The fast path uses a different recognition model. It is a
        // separate second chance when the accurate model returns no text.
        return recognizedLines(in: tiles,
                               totalHeight: totalHeight,
                               level: .fast,
                               automaticallyDetectLanguage: false,
                               preferredLanguages: fallbackLanguages)
    }

    private static func recognizedLines(
        in tiles: [ImageTile],
        totalHeight: Int,
        level: VNRequestTextRecognitionLevel,
        automaticallyDetectLanguage: Bool,
        preferredLanguages: [String] = []
    ) -> [QuickToolsSupport.RecognizedLine] {
        var collected: [QuickToolsSupport.RecognizedLine] = []
        let fullHeight = Double(max(1, totalHeight))
        for tile in tiles {
            let tileLines: [QuickToolsSupport.RecognizedLine] = autoreleasepool {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = level
                request.usesLanguageCorrection = true
                request.automaticallyDetectsLanguage = automaticallyDetectLanguage
                if !preferredLanguages.isEmpty,
                   let supported = try? request.supportedRecognitionLanguages() {
                    let available = preferredLanguages.filter { supported.contains($0) }
                    if !available.isEmpty { request.recognitionLanguages = available }
                }

                let handler = VNImageRequestHandler(cgImage: tile.image, options: [:])
                guard (try? handler.perform([request])) != nil else { return [] }

                let tileBottomFromTop = tile.topPx + tile.heightPx
                let bottomOffsetFromBottomPx = Double(totalHeight - tileBottomFromTop)
                let tileHeight = Double(tile.heightPx)

                return (request.results ?? []).compactMap { observation -> QuickToolsSupport.RecognizedLine? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    let localBox = observation.boundingBox
                    let fullMinY = (bottomOffsetFromBottomPx + Double(localBox.minY) * tileHeight) / fullHeight
                    let fullBoxHeight = Double(localBox.height) * tileHeight / fullHeight
                    let fullBox = CGRect(
                        x: localBox.minX,
                        y: CGFloat(fullMinY),
                        width: localBox.width,
                        height: CGFloat(fullBoxHeight)
                    )
                    if tiles.count > 1 {
                        let centerFromTopPx = (1.0 - Double(fullBox.midY)) * fullHeight
                        let isLastTile = tile.ownedBottomPx >= fullHeight
                        let matchesStart = tile.topPx == 0 ? true : centerFromTopPx >= tile.ownedTopPx
                        let matchesEnd = isLastTile
                            ? centerFromTopPx <= tile.ownedBottomPx
                            : centerFromTopPx < tile.ownedBottomPx
                        guard matchesStart && matchesEnd else { return nil }
                    }
                    return QuickToolsSupport.RecognizedLine(text: candidate.string,
                                                            x: Double(fullBox.minX),
                                                            y: Double(fullBox.midY),
                                                            boundingBox: fullBox)
                }
            }
            collected.append(contentsOf: tileLines)
        }
        return collected
    }

    private static func copyToPasteboard(_ value: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
    }
}
