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
            let processedImage = downsampledImageIfNeeded(image)
            if detectQRCodes, let reading = BarcodeDetector.read(processedImage) {
                return .qr(reading)
            }

            var lines = recognizedLines(in: processedImage,
                                        level: .accurate,
                                        automaticallyDetectLanguage: true,
                                        preferredLanguages: fallbackLanguages)
            if lines.isEmpty {
                // The fast path uses a different recognition model. It is a
                // separate second chance when the accurate model returns no text.
                lines = recognizedLines(in: processedImage,
                                        level: .fast,
                                        automaticallyDetectLanguage: false,
                                        preferredLanguages: fallbackLanguages)
            }
            let text = QuickToolsSupport.joinedRecognizedText(lines,
                                                             removingLineBreaks: removeLineBreaks)
            return text.isEmpty ? .empty : .text(text)
        }
    }

    private static func downsampledImageIfNeeded(_ image: CGImage, maxDimension: Int = 4096) -> CGImage {
        let width = image.width
        let height = image.height
        guard width > maxDimension || height > maxDimension else { return image }
        let scale = min(Double(maxDimension) / Double(width), Double(maxDimension) / Double(height))
        let targetWidth = max(1, Int((Double(width) * scale).rounded()))
        let targetHeight = max(1, Int((Double(height) * scale).rounded()))
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? image.colorSpace,
              let context = CGContext(
                  data: nil,
                  width: targetWidth,
                  height: targetHeight,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return image
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        return context.makeImage() ?? image
    }

    private static func recognizedLines(
        in image: CGImage,
        level: VNRequestTextRecognitionLevel,
        automaticallyDetectLanguage: Bool,
        preferredLanguages: [String] = []
    ) -> [QuickToolsSupport.RecognizedLine] {
        autoreleasepool {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = level
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = automaticallyDetectLanguage
            if !preferredLanguages.isEmpty,
               let supported = try? request.supportedRecognitionLanguages() {
                let available = preferredLanguages.filter { supported.contains($0) }
                if !available.isEmpty { request.recognitionLanguages = available }
            }

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            guard (try? handler.perform([request])) != nil else { return [] }

            return (request.results ?? []).compactMap { observation -> QuickToolsSupport.RecognizedLine? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                return QuickToolsSupport.RecognizedLine(text: candidate.string,
                                                        x: observation.boundingBox.minX,
                                                        y: observation.boundingBox.midY)
            }
        }
    }

    private static func copyToPasteboard(_ value: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
    }
}
