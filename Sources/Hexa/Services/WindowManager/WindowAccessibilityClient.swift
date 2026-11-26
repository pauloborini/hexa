// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import AppKit
import ApplicationServices
import CoreGraphics
import Darwin
import Foundation

/// Resolved target window for layout mutations.
struct WindowAccessibilityTarget {
    let window: AXUIElement
    let key: WindowIdentityKey
    let frame: WindowFrame
    let app: NSRunningApplication

    var windowID: CGWindowID { key.windowID }
}

/// Low-level Accessibility client for reading and mutating external macOS windows.
/// Uses bounded messaging timeouts, suspends `AXEnhancedUserInterface` during frame
/// writes for smooth resizing, and respects
/// window `minSize`/`maxSize` constraints.
enum WindowAccessibilityClient {
    private typealias AXUIElementGetWindowFn = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError

    private static let axGetWindow: AXUIElementGetWindowFn? = {
        guard let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2) /* RTLD_DEFAULT */,
                              "_AXUIElementGetWindow") else { return nil }
        return unsafeBitCast(sym, to: AXUIElementGetWindowFn.self)
    }()

    static let defaultMessagingTimeout: Float = 0.35

    // MARK: - Window ID & Element Lookup

    static func windowID(for element: AXUIElement) -> CGWindowID? {
        guard let fn = axGetWindow else { return nil }
        var id: CGWindowID = 0
        guard fn(element, &id) == .success, id != 0 else { return nil }
        return id
    }

    static func focusedTarget(skippingOwnApp: Bool = true,
                              ignoredBundleIDs: Set<String> = [],
                              recentPIDs: [pid_t] = []) -> WindowAccessibilityTarget? {
        guard AXIsProcessTrusted() else { return nil }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let ownBundleID = Bundle.main.bundleIdentifier

        var candidatePIDs: [pid_t] = []
        let front = NSWorkspace.shared.frontmostApplication
        let frontPID = front?.processIdentifier
        let hasExternalFront = front?.activationPolicy == .regular && (!skippingOwnApp || frontPID != ownPID)
        if hasExternalFront, let frontPID {
            candidatePIDs.append(frontPID)
        } else {
            candidatePIDs = recentPIDs
        }

        // Also include front-to-back on-screen regular windows as fallback when Hexa itself is focused.
        let onScreenList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                      kCGNullWindowID) as? [[String: Any]] ?? []
        var onScreenIDs = Set<CGWindowID>()
        for info in onScreenList {
            guard let wid = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value else { continue }
            onScreenIDs.insert(wid)
            if !hasExternalFront, (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
               let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
               !candidatePIDs.contains(pid) {
                candidatePIDs.append(pid)
            }
        }

        for pid in candidatePIDs {
            if skippingOwnApp && pid == ownPID { continue }
            guard let app = NSRunningApplication(processIdentifier: pid),
                  !app.isTerminated,
                  app.activationPolicy == .regular,
                  !app.isHidden else { continue }
            if skippingOwnApp, let bundle = app.bundleIdentifier, bundle == ownBundleID { continue }
            if let bundle = app.bundleIdentifier, ignoredBundleIDs.contains(bundle) { continue }

            let axApp = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(axApp, defaultMessagingTimeout)

            for attr in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] {
                if let win = windowAttribute(axApp, attr as String),
                   let target = makeTarget(from: win, app: app, onScreenIDs: onScreenIDs) {
                    return target
                }
            }
            if hasExternalFront { return nil }
            if let windows = windowsAttribute(axApp) {
                for win in windows {
                    if let target = makeTarget(from: win, app: app, onScreenIDs: onScreenIDs) {
                        return target
                    }
                }
            }
        }
        return nil
    }

    static func resolveTarget(windowID: CGWindowID, pid: pid_t) -> WindowAccessibilityTarget? {
        guard AXIsProcessTrusted(),
              let app = NSRunningApplication(processIdentifier: pid),
              !app.isTerminated,
              app.activationPolicy == .regular else { return nil }
        let axApp = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(axApp, 0.25)
        guard let windows = windowsAttribute(axApp),
              let match = windows.first(where: { Self.windowID(for: $0) == windowID }) else {
            return nil
        }
        return makeTarget(from: match, app: app, onScreenIDs: [windowID])
    }

    private static func makeTarget(from window: AXUIElement,
                                   app: NSRunningApplication,
                                   onScreenIDs: Set<CGWindowID>) -> WindowAccessibilityTarget? {
        AXUIElementSetMessagingTimeout(window, defaultMessagingTimeout)
        let subrole = stringAttribute(window, kAXSubroleAttribute as String)
        guard stringAttribute(window, kAXRoleAttribute as String) == (kAXWindowRole as String),
              !boolAttribute(window, kAXMinimizedAttribute as String),
              !boolAttribute(window, "AXFullScreen"),
              subrole != "AXFloatingWindow",
              subrole != "AXSheet",
              subrole != "AXSystemDialog",
              let wid = windowID(for: window),
              onScreenIDs.contains(wid),
              let frame = frame(of: window),
              frame.size.width > WindowGeometryEngine.minimumLayoutDimension,
              frame.size.height > WindowGeometryEngine.minimumLayoutDimension,
              canSetPosition(on: window) else {
            return nil
        }
        let key = WindowIdentityKey(
            processID: app.processIdentifier,
            processLaunchTime: app.launchDate?.timeIntervalSinceReferenceDate ?? 0,
            windowID: wid
        )
        return WindowAccessibilityTarget(window: window, key: key, frame: frame, app: app)
    }

    // MARK: - Window Attributes & Constraints

    static func frame(of window: AXUIElement) -> WindowFrame? {
        guard let origin = pointAttribute(window, kAXPositionAttribute as String),
              let size = sizeAttribute(window, kAXSizeAttribute as String),
              size.width > 0, size.height > 0 else { return nil }
        return WindowFrame(origin: origin, size: size)
    }

    static func minSize(of window: AXUIElement) -> CGSize? {
        sizeAttribute(window, "AXMinSize")
    }

    static func maxSize(of window: AXUIElement) -> CGSize? {
        sizeAttribute(window, "AXMaxSize")
    }

    static func canSetPosition(on window: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(window, kAXPositionAttribute as CFString, &settable) == .success
            && settable.boolValue
    }

    static func canSetSize(on window: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(window, kAXSizeAttribute as CFString, &settable) == .success
            && settable.boolValue
    }

    static func setPosition(_ point: CGPoint, on window: AXUIElement) -> Bool {
        var p = point
        guard let value = AXValueCreate(.cgPoint, &p) else { return false }
        return AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value) == .success
    }

    static func setSize(_ size: CGSize, on window: AXUIElement) -> Bool {
        var s = size
        guard let value = AXValueCreate(.cgSize, &s) else { return false }
        return AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value) == .success
    }

    // MARK: - Resilient Frame Mutation (with AXEnhancedUserInterface Suspension)

    /// Applies `targetAppKitRect` to `window` with resilience against app-enforced `minSize`
    /// and multi-step AX commit behavior. Returns the final read-back Quartz frame on success.
    @discardableResult
    static func applyRect(_ targetAppKitRect: CGRect,
                          action: WindowManagerAction,
                          visibleFrame: CGRect,
                          primaryScreenTopY: CGFloat,
                          on window: AXUIElement) -> WindowFrame? {
        let suspension = EnhancedUISuspension.suspend(forWindow: window)
        defer { suspension?.resume() }

        guard let initialFrame = frame(of: window) else { return nil }
        let minSz = minSize(of: window)
        let maxSz = maxSize(of: window)
        let constrainedAppKit = WindowGeometryEngine.resolveConstrainedRect(
            for: action,
            targetRect: targetAppKitRect,
            minSize: minSz,
            maxSize: maxSz,
            visibleFrame: visibleFrame
        )
        let desiredQuartz = WindowGeometryEngine.quartzRect(fromAppKit: constrainedAppKit,
                                                            primaryScreenTopY: primaryScreenTopY)
        let desiredFrame = WindowFrame(rect: desiredQuartz)
        let resizable = canSetSize(on: window)
        let shrinking = desiredFrame.size.width < initialFrame.size.width - 1
            || desiredFrame.size.height < initialFrame.size.height - 1

        for attempt in 0..<2 {
            // Shrink before moving when transferring to a smaller display so macOS does not clamp origin.
            if attempt == 0, shrinking, resizable {
                _ = setSize(desiredFrame.size, on: window)
            }
            _ = setPosition(desiredFrame.origin, on: window)
            if resizable {
                _ = setSize(desiredFrame.size, on: window)
            }
            guard let readBack = frame(of: window) else { continue }
            // If the app silently enforced a larger minSize than reported, re-anchor cleanly.
            let anchoredAppKit = WindowGeometryEngine.anchoredRect(
                for: action,
                targetRect: targetAppKitRect,
                actualSize: readBack.size,
                visibleFrame: visibleFrame
            )
            let anchoredQuartz = WindowGeometryEngine.quartzRect(fromAppKit: anchoredAppKit,
                                                                 primaryScreenTopY: primaryScreenTopY)
            if abs(readBack.origin.x - anchoredQuartz.minX) > 1
                || abs(readBack.origin.y - anchoredQuartz.minY) > 1 {
                _ = setPosition(anchoredQuartz.origin, on: window)
            }
            if let finalFrame = frame(of: window) {
                if finalFrame.isClose(to: desiredFrame, tolerance: WindowGeometryEngine.frameTolerance)
                    || finalFrame.isClose(to: WindowFrame(rect: anchoredQuartz),
                                          tolerance: WindowGeometryEngine.frameTolerance) {
                    return finalFrame
                }
            }
        }
        _ = writeExactFrame(initialFrame, on: window, resizable: resizable)
        return nil
    }

    static func applyExactQuartzFrame(_ frame: WindowFrame, on window: AXUIElement) -> Bool {
        let suspension = EnhancedUISuspension.suspend(forWindow: window)
        defer { suspension?.resume() }
        guard let initial = self.frame(of: window) else { return false }
        let resizable = canSetSize(on: window)
        if writeExactFrame(frame, on: window, resizable: resizable) { return true }
        _ = writeExactFrame(initial, on: window, resizable: resizable)
        return false
    }

    private static func writeExactFrame(_ desired: WindowFrame, on window: AXUIElement, resizable: Bool) -> Bool {
        for _ in 0..<2 {
            if let actual = frame(of: window), actual.isClose(to: desired, tolerance: 1) { return true }
            if resizable { _ = setSize(desired.size, on: window) }
            _ = setPosition(desired.origin, on: window)
        }
        return frame(of: window)?.isClose(to: desired, tolerance: 1) == true
    }

    // MARK: - WindowServer Queries (No Screen Recording Required)

    static func activeWindowKeys() -> Set<WindowIdentityKey> {
        guard let list = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements],
                                                    kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        var launchTimes: [pid_t: TimeInterval] = [:]
        var result = Set<WindowIdentityKey>()
        for info in list {
            guard (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  let wid = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value else { continue }
            if launchTimes[pid] == nil {
                guard let app = NSRunningApplication(processIdentifier: pid),
                      app.activationPolicy == .regular else { continue }
                launchTimes[pid] = app.launchDate?.timeIntervalSinceReferenceDate ?? 0
            }
            if let t = launchTimes[pid] {
                result.insert(WindowIdentityKey(processID: pid, processLaunchTime: t, windowID: wid))
            }
        }
        return result
    }

    static func windowServerFrame(ofWindowID windowID: CGWindowID) -> CGRect? {
        guard let list = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowID) as? [[String: Any]],
              let info = list.first,
              let bounds = info[kCGWindowBounds as String] as? [String: Any] else {
            return nil
        }
        return CGRect(dictionaryRepresentation: bounds as CFDictionary)
    }

    static func topWindowCandidate(at quartzPoint: CGPoint,
                                   skippingPID: pid_t) -> (pid: pid_t, windowID: CGWindowID, frame: CGRect)? {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                    kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        for info in list {
            guard (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  let wid = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                  rect.width > WindowGeometryEngine.minimumLayoutDimension,
                  rect.height > WindowGeometryEngine.minimumLayoutDimension,
                  rect.contains(quartzPoint) else { continue }
            guard pid != skippingPID else { return nil }
            guard let app = NSRunningApplication(processIdentifier: pid),
                  !app.isTerminated,
                  app.activationPolicy == .regular else { continue }
            return (pid, wid, rect)
        }
        return nil
    }

    // MARK: - Stage Manager Strip Reading

    static func currentStageManagerStripFrames(primaryScreenTopY: CGFloat) -> [CGRect] {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                       kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        return windows.compactMap { window in
            guard window[kCGWindowOwnerName as String] as? String == "WindowManager",
                  (window[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1 > 0,
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return nil }
            return WindowGeometryEngine.appKitRect(fromQuartz: rect, primaryScreenTopY: primaryScreenTopY)
        }
    }

    static func currentStageManagerConfig(reserveSpace: Bool) -> StageManagerConfig {
        let wmDefaults = UserDefaults(suiteName: "com.apple.WindowManager")
        let dockDefaults = UserDefaults(suiteName: "com.apple.dock")
        return StageManagerConfig(
            reserveSpace: reserveSpace,
            stageManagerEnabled: wmDefaults?.bool(forKey: "GloballyEnabled") == true,
            autoHide: (wmDefaults?.object(forKey: "AutoHide") as? Bool) ?? true,
            dockPosition: dockDefaults?.string(forKey: "orientation"),
            rightToLeft: Locale.current.language.characterDirection == .rightToLeft
        )
    }

    static var nativeOptionTilingEnabled: Bool {
        guard #available(macOS 15, *) else { return false }
        return (UserDefaults(suiteName: "com.apple.WindowManager")?
            .object(forKey: "EnableTilingOptionAccelerator") as? NSNumber)?.boolValue ?? true
    }

    // MARK: - Display Descriptors

    static func displayDescriptors(from screens: [NSScreen] = NSScreen.screens) -> [WindowDisplayDescriptor] {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return screens.enumerated().map { idx, screen in
            let id = (screen.deviceDescription[key] as? NSNumber)?.uint32Value ?? UInt32(idx + 1)
            let safeTop = screen.safeAreaInsets.top
            return WindowDisplayDescriptor(
                id: id,
                frame: screen.frame,
                visibleFrame: screen.visibleFrame,
                safeAreaTopInset: safeTop,
                scaleFactor: screen.backingScaleFactor
            )
        }
    }

    static func primaryScreenTopY(from screens: [NSScreen] = NSScreen.screens) -> CGFloat {
        let primary = screens.first { abs($0.frame.minX) < 0.5 && abs($0.frame.minY) < 0.5 }
        return (primary ?? NSScreen.main ?? screens.first)?.frame.maxY ?? 0
    }

    // MARK: - Private AX Helpers

    private static func stringAttribute(_ element: AXUIElement, _ attr: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attr as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func boolAttribute(_ element: AXUIElement, _ attr: String) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attr as CFString, &value) == .success else { return false }
        return (value as? Bool) ?? false
    }

    private static func windowAttribute(_ element: AXUIElement, _ attr: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attr as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func windowsAttribute(_ element: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success,
              let array = value as? [AXUIElement] else { return nil }
        return array
    }

    private static func pointAttribute(_ element: AXUIElement, _ attr: String) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attr as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axVal = value as! AXValue
        guard AXValueGetType(axVal) == .cgPoint else { return nil }
        var p = CGPoint.zero
        return AXValueGetValue(axVal, .cgPoint, &p) ? p : nil
    }

    private static func sizeAttribute(_ element: AXUIElement, _ attr: String) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attr as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axVal = value as! AXValue
        guard AXValueGetType(axVal) == .cgSize else { return nil }
        var s = CGSize.zero
        return AXValueGetValue(axVal, .cgSize, &s) ? s : nil
    }

    /// Temporarily disables `AXEnhancedUserInterface` on an application during
    /// programmatic window resize so apps do not animate
    /// intermediate frames or reject rapid geometry writes.
    private final class EnhancedUISuspension {
        private let app: AXUIElement
        private var resumed = false

        private init(app: AXUIElement) { self.app = app }

        static func suspend(forWindow window: AXUIElement) -> EnhancedUISuspension? {
            var pid: pid_t = 0
            guard AXUIElementGetPid(window, &pid) == .success, pid != 0 else { return nil }
            let axApp = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(axApp, 0.2)
            var raw: CFTypeRef?
            guard AXUIElementCopyAttributeValue(axApp, "AXEnhancedUserInterface" as CFString, &raw) == .success,
                  (raw as? Bool) == true else { return nil }
            guard AXUIElementSetAttributeValue(axApp, "AXEnhancedUserInterface" as CFString, kCFBooleanFalse) == .success else {
                return nil
            }
            return EnhancedUISuspension(app: axApp)
        }

        func resume() {
            guard !resumed else { return }
            resumed = true
            _ = AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        }
    }
}
