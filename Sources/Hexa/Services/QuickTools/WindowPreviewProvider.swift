// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import CoreGraphics
import Darwin
import Foundation

/// The window-server window capture the capture tools reuse: best
/// resolution + ignore the global clip shape, so parked, minimized and
/// other-Space windows come back as their real, untransformed content.
enum WindowPreviewProvider {
    private typealias CGSConnectionID = UInt32
    private typealias CGSCaptureFunction =
        @convention(c) (CGSConnectionID, UnsafeMutablePointer<UInt32>, UInt32, UInt32) -> Unmanaged<CFArray>?
    /// `CGSHWCaptureWindowList` — resolved at runtime so a future macOS that
    /// drops the symbol degrades to the ScreenCaptureKit path instead of
    /// failing to launch.
    private static let windowServerCapture: CGSCaptureFunction? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGSHWCaptureWindowList")
        else { return nil }
        return unsafeBitCast(symbol, to: CGSCaptureFunction.self)
    }()
    private static let windowServerConnection: CGSConnectionID = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGSMainConnectionID")
        else { return 0 }
        typealias ConnectionFunction = @convention(c) () -> CGSConnectionID
        return unsafeBitCast(symbol, to: ConnectionFunction.self)()
    }()
    private static let windowServerCaptureOptions: UInt32 = (1 << 8) | (1 << 11)
    /// Shared by every caller. Cancelling a caller must not let another
    /// capture overlap its unfinished system call.
    private static let windowServerCaptures = WindowServerCaptureQueue()

    static func captureViaWindowServer(_ windowID: CGWindowID,
                                       waitingForOtherCaptures: Bool = true) async -> CGImage? {
        guard windowServerConnection != 0, let capture = windowServerCapture else { return nil }
        return await windowServerCaptures.capture(waitingForOtherCaptures: waitingForOtherCaptures) {
            var id = UInt32(windowID)
            guard let array = capture(windowServerConnection, &id, 1, windowServerCaptureOptions)?
                .takeRetainedValue(),
                CFArrayGetCount(array) > 0,
                let value = CFArrayGetValueAtIndex(array, 0)
            else { return nil }
            let candidate = unsafeBitCast(value, to: CFTypeRef.self)
            guard CFGetTypeID(candidate) == CGImage.typeID else { return nil }
            let image = unsafeBitCast(candidate, to: CGImage.self)
            guard image.width > 1, image.height > 1 else { return nil }
            return image
        }
    }
}
