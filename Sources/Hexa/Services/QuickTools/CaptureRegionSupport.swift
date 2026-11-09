// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import CoreGraphics
import Foundation

/// Geometry shared by the capture tools: the picked area a capture resolves
/// once when the person confirms it and never recomputes.
enum CaptureRegionSupport {
    /// The area a capture covers, resolved once when the person confirms it
    /// and never recomputed: a window that moves keeps recording the region it
    /// was picked in.
    struct Region: Equatable {
        let displayID: CGDirectDisplayID
        /// Set only when a window was clicked, so the stream can follow that
        /// window's own buffer instead of a slice of the display.
        let windowID: CGWindowID?
        /// Top-left origin, in the display's pixels, already even on both axes.
        let pixelRect: CGRect
        /// The same area in Cocoa global points, for anchoring panels to it.
        let anchorRect: CGRect
        /// Pixels per point of the source display.
        let scale: CGFloat

        var pixelSize: CGSize { pixelRect.size }
    }

    /// Encoders reject or silently adjust odd dimensions, so the picked
    /// area is snapped before anything else sees it and the badge the person
    /// reads is the snapped number.
    static let minimumSide: CGFloat = 32

    static func evenSize(_ size: CGSize) -> CGSize {
        CGSize(width: evenSide(size.width), height: evenSide(size.height))
    }

    private static func evenSide(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return minimumSide }
        let rounded = max(minimumSide, value.rounded(.down))
        return rounded.truncatingRemainder(dividingBy: 2) == 0 ? rounded : rounded - 1
    }

    /// The picked rectangle in whole, even pixels, kept inside the display it
    /// came from. Shrinks rather than shifts when it would overflow, so the
    /// area never silently covers something the person did not choose.
    static func snappedPixelRect(_ rect: CGRect, in bounds: CGRect) -> CGRect {
        guard rect.width.isFinite, rect.height.isFinite,
              rect.origin.x.isFinite, rect.origin.y.isFinite
        else { return CGRect(origin: bounds.origin, size: evenSize(bounds.size)) }

        let clamped = rect.intersection(bounds).isNull ? bounds : rect.intersection(bounds)
        var origin = CGPoint(x: clamped.origin.x.rounded(.down),
                             y: clamped.origin.y.rounded(.down))
        var size = evenSize(clamped.size)
        if origin.x + size.width > bounds.maxX {
            origin.x = max(bounds.minX, (bounds.maxX - size.width).rounded(.down))
        }
        if origin.y + size.height > bounds.maxY {
            origin.y = max(bounds.minY, (bounds.maxY - size.height).rounded(.down))
        }
        size = evenSize(CGSize(width: min(size.width, bounds.maxX - origin.x),
                               height: min(size.height, bounds.maxY - origin.y)))
        return CGRect(origin: origin, size: size)
    }
}

/// The capture tools' shared name for the region geometry, kept at the call
/// sites' original spelling.
typealias RecorderSupport = CaptureRegionSupport
