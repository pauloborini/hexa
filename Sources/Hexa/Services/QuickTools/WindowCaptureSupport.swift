// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import CoreGraphics
import Foundation

/// Pure classification helpers for window captures, shared by the capture
/// engine and the notch's watch strip.
enum WindowCaptureSupport {
    /// Grid resolution used to classify window captures.
    static let captureAlphaGridSize = 8

    /// Downsamples a capture into a small alpha grid for classification.
    static func alphaGrid(of image: CGImage, gridSize: Int = captureAlphaGridSize) -> [Double]? {
        guard gridSize > 0 else { return nil }
        let bytesPerPixel = 4
        var data = [UInt8](repeating: 0, count: gridSize * gridSize * bytesPerPixel)
        let drawn = data.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress,
                                          width: gridSize,
                                          height: gridSize,
                                          bitsPerComponent: 8,
                                          bytesPerRow: gridSize * bytesPerPixel,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.interpolationQuality = .low
            context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(gridSize), height: CGFloat(gridSize)))
            return true
        }
        guard drawn else { return nil }
        return (0..<(gridSize * gridSize)).map { Double(data[$0 * bytesPerPixel + 3]) / 255.0 }
    }

    /// Whether a window capture looks like Stage Manager's strip rendering
    /// instead of real window content. Parked windows are captured as a sheared
    /// snapshot whose bounding box leaves fully transparent wedges in at least
    /// two corner/edge probes of the downsampled grid; a real window capture is
    /// opaque edge to edge (rounded corners only shave sub-cell slivers at this
    /// resolution, alpha stays well above the threshold).
    static func captureLooksTransformed(alphaGrid: [Double],
                                        gridSize: Int = captureAlphaGridSize) -> Bool {
        guard gridSize >= 4, alphaGrid.count == gridSize * gridSize else { return false }
        let last = gridSize - 1
        let mid = gridSize / 2
        let probes = [
            (0, 0), (0, last), (last, 0), (last, last),
            (0, mid), (last, mid), (mid, 0), (mid, last),
        ]
        let transparent = probes.filter { alphaGrid[$0.0 * gridSize + $0.1] < 0.05 }.count
        return transparent >= 2
    }

    /// How far the two axes of a capture may disagree before it counts as a
    /// slice of a window instead of the whole window.
    static let captureCoverageTolerance = 0.08

    /// Whether a capture holds the whole window or only the part of it that
    /// was inside a display. The window server clips a window capture to the
    /// visible region, so a window hanging over a screen edge comes back as a
    /// thin band of real content while still reporting its full size. Comparing
    /// the two axes catches that without caring about the display scale, so a
    /// plain screen and a Retina screen both score the same. A window with
    /// nothing to measure passes, because there is no evidence either way.
    static func captureCoversWindow(imageWidth: Int,
                                    imageHeight: Int,
                                    windowSize: CGSize,
                                    tolerance: Double = captureCoverageTolerance) -> Bool {
        guard windowSize.width.isFinite, windowSize.height.isFinite,
              windowSize.width > 1, windowSize.height > 1
        else { return true }
        let horizontal = Double(imageWidth) / Double(windowSize.width)
        let vertical = Double(imageHeight) / Double(windowSize.height)
        guard horizontal > 0, vertical > 0 else { return true }
        return max(horizontal, vertical) / min(horizontal, vertical) <= 1 + tolerance
    }
}

/// The capture tools' shared name for the window-capture classification,
/// kept at the call sites' original spelling.
typealias SwitcherSupport = WindowCaptureSupport
