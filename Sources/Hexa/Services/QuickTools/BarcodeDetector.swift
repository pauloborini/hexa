// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import CoreGraphics
import Vision

/// Offline 2D code detection shared by the screen text tool and the
/// screenshot preview. Restricted to matrix symbologies (QR and its
/// relatives): 1D barcodes false fire on any striped area of a normal
/// screen, and the useful case here is scanning a QR shown on screen.
enum BarcodeDetector {
    /// Matrix codes only. Kept as a fast, lightweight pass that runs before
    /// the heavier text recognition.
    static let symbologies: [VNBarcodeSymbology] = [.qr, .microQR, .aztec, .dataMatrix, .pdf417]

    static func decode(_ image: CGImage) -> [QuickToolsSupport.DecodedBarcode] {
        autoreleasepool {
            let primary = detectBarcodes(in: image)
            if !primary.isEmpty { return QuickToolsSupport.orderedUniqueBarcodes(primary) }

            if let inverted = QuickToolsSupport.invertedImage(image) {
                let codes = detectBarcodes(in: inverted)
                if !codes.isEmpty { return QuickToolsSupport.orderedUniqueBarcodes(codes) }
            }

            if let enhanced = QuickToolsSupport.contrastNormalizedImage(image) {
                let codes = detectBarcodes(in: enhanced)
                if !codes.isEmpty { return QuickToolsSupport.orderedUniqueBarcodes(codes) }
            }

            if let enhancedInverted = QuickToolsSupport.contrastNormalizedImage(image, invert: true) {
                let codes = detectBarcodes(in: enhancedInverted)
                if !codes.isEmpty { return QuickToolsSupport.orderedUniqueBarcodes(codes) }
            }

            return []
        }
    }

    private static func detectBarcodes(in image: CGImage) -> [QuickToolsSupport.DecodedBarcode] {
        autoreleasepool {
            let request = VNDetectBarcodesRequest()
            request.symbologies = symbologies
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            guard (try? handler.perform([request])) != nil else { return [] }
            return (request.results ?? []).compactMap { observation in
                guard let payload = observation.payloadStringValue, !payload.isEmpty else { return nil }
                let box = observation.boundingBox
                return QuickToolsSupport.DecodedBarcode(payload: payload,
                                                        x: Double(box.minX),
                                                        y: Double(box.midY))
            }
        }
    }

    /// A finished read of an image: the joined payload, and an openable link
    /// only when a single code carries a plain web address. Nil when nothing
    /// was found. Shared by the screenshot preview and the annotation editor.
    struct Reading: Equatable {
        let payload: String
        let url: URL?
    }

    static func reading(from codes: [QuickToolsSupport.DecodedBarcode]) -> Reading? {
        let uniqueCodes = QuickToolsSupport.orderedUniqueBarcodes(codes)
        let payload = QuickToolsSupport.joinedBarcodePayloads(uniqueCodes)
        guard !payload.isEmpty else { return nil }
        let url = uniqueCodes.count == 1 ? QuickToolsSupport.openableURL(from: payload) : nil
        return Reading(payload: payload, url: url)
    }

    static func read(_ image: CGImage) -> Reading? {
        reading(from: decode(image))
    }
}
