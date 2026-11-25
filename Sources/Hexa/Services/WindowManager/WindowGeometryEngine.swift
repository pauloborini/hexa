// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import Carbon.HIToolbox
import CoreGraphics
import Foundation

// MARK: - Actions & Configuration

enum WindowManagerAction: String, CaseIterable, Identifiable, Hashable {
    case leftHalf, rightHalf, topHalf, bottomHalf, centerHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case leftThird, centerThird, rightThird, leftTwoThirds, rightTwoThirds, centerTwoThirds
    case leftQuarter, leftMiddleQuarter, rightMiddleQuarter, rightQuarter
    case maximize, marginMaximize, center, restore
    case previousDisplay, nextDisplay

    var id: String { rawValue }

    enum Category: CaseIterable {
        case halves, quarters, thirds, quarterColumns, fullAndUtility, displays
    }

    var category: Category {
        switch self {
        case .leftHalf, .rightHalf, .topHalf, .bottomHalf, .centerHalf:
            return .halves
        case .topLeft, .topRight, .bottomLeft, .bottomRight:
            return .quarters
        case .leftThird, .centerThird, .rightThird, .leftTwoThirds, .rightTwoThirds, .centerTwoThirds:
            return .thirds
        case .leftQuarter, .leftMiddleQuarter, .rightMiddleQuarter, .rightQuarter:
            return .quarterColumns
        case .maximize, .marginMaximize, .center, .restore:
            return .fullAndUtility
        case .previousDisplay, .nextDisplay:
            return .displays
        }
    }

    var hotKeyID: UInt32 {
        switch self {
        case .leftHalf: return 101
        case .rightHalf: return 102
        case .topHalf: return 103
        case .bottomHalf: return 104
        case .centerHalf: return 105
        case .topLeft: return 106
        case .topRight: return 107
        case .bottomLeft: return 108
        case .bottomRight: return 109
        case .leftThird: return 110
        case .centerThird: return 111
        case .rightThird: return 112
        case .leftTwoThirds: return 113
        case .rightTwoThirds: return 114
        case .centerTwoThirds: return 115
        case .maximize: return 116
        case .marginMaximize: return 117
        case .center: return 118
        case .restore: return 119
        case .previousDisplay: return 120
        case .nextDisplay: return 121
        case .leftQuarter: return 122
        case .leftMiddleQuarter: return 123
        case .rightMiddleQuarter: return 124
        case .rightQuarter: return 125
        }
    }

    init?(hotKeyID: UInt32) {
        guard let match = Self.allCases.first(where: { $0.hotKeyID == hotKeyID }) else { return nil }
        self = match
    }

    var shortcutKey: String {
        switch self {
        case .leftHalf: return DefaultsKey.windowLayoutShortcutLeft
        case .rightHalf: return DefaultsKey.windowLayoutShortcutRight
        case .topHalf: return DefaultsKey.windowLayoutShortcutTop
        case .bottomHalf: return DefaultsKey.windowLayoutShortcutBottom
        case .centerHalf: return DefaultsKey.windowLayoutShortcutCenterHalf
        case .topLeft: return DefaultsKey.windowLayoutShortcutTopLeft
        case .topRight: return DefaultsKey.windowLayoutShortcutTopRight
        case .bottomLeft: return DefaultsKey.windowLayoutShortcutBottomLeft
        case .bottomRight: return DefaultsKey.windowLayoutShortcutBottomRight
        case .leftThird: return DefaultsKey.windowLayoutShortcutLeftThird
        case .centerThird: return DefaultsKey.windowLayoutShortcutCenterThird
        case .rightThird: return DefaultsKey.windowLayoutShortcutRightThird
        case .leftTwoThirds: return DefaultsKey.windowLayoutShortcutLeftTwoThirds
        case .rightTwoThirds: return DefaultsKey.windowLayoutShortcutRightTwoThirds
        case .centerTwoThirds: return DefaultsKey.windowLayoutShortcutCenterTwoThirds
        case .leftQuarter: return DefaultsKey.windowLayoutShortcutLeftQuarter
        case .leftMiddleQuarter: return DefaultsKey.windowLayoutShortcutLeftMiddleQuarter
        case .rightMiddleQuarter: return DefaultsKey.windowLayoutShortcutRightMiddleQuarter
        case .rightQuarter: return DefaultsKey.windowLayoutShortcutRightQuarter
        case .maximize: return DefaultsKey.windowLayoutShortcutMaximize
        case .marginMaximize: return DefaultsKey.windowLayoutShortcutMarginMaximize
        case .center: return DefaultsKey.windowLayoutShortcutCenter
        case .restore: return DefaultsKey.windowLayoutShortcutRestore
        case .previousDisplay: return DefaultsKey.windowLayoutShortcutPreviousDisplay
        case .nextDisplay: return DefaultsKey.windowLayoutShortcutNextDisplay
        }
    }

    static let clearedShortcutStorageValue = "none"

    func defaultShortcut(for profile: WindowShortcutProfile = .standard) -> GlobalShortcut? {
        profile.defaultShortcut(for: self)
    }

    static func resolvedShortcut(storedValue: String?,
                                 defaultShortcut: GlobalShortcut?) -> GlobalShortcut? {
        guard let storedValue else { return defaultShortcut }
        if storedValue == clearedShortcutStorageValue || storedValue.isEmpty { return nil }
        return GlobalShortcut(storageValue: storedValue) ?? defaultShortcut
    }

    func savedShortcut(in defaults: UserDefaults = .standard) -> GlobalShortcut? {
        let profile = WindowShortcutProfile(rawValue: defaults.string(forKey: DefaultsKey.windowManagerShortcutProfile) ?? "") ?? .standard
        return Self.resolvedShortcut(storedValue: defaults.string(forKey: shortcutKey),
                                     defaultShortcut: defaultShortcut(for: profile))
    }

    /// Normalized preview rectangle inside a 0...1 unit display box for the UI grid visualizer.
    var previewUnitRect: CGRect? {
        switch self {
        case .leftHalf: return CGRect(x: 0, y: 0, width: 0.5, height: 1)
        case .rightHalf: return CGRect(x: 0.5, y: 0, width: 0.5, height: 1)
        case .topHalf: return CGRect(x: 0, y: 0, width: 1, height: 0.5)
        case .bottomHalf: return CGRect(x: 0, y: 0.5, width: 1, height: 0.5)
        case .centerHalf: return CGRect(x: 0.25, y: 0, width: 0.5, height: 1)
        case .topLeft: return CGRect(x: 0, y: 0, width: 0.5, height: 0.5)
        case .topRight: return CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5)
        case .bottomLeft: return CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5)
        case .bottomRight: return CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)
        case .leftThird: return CGRect(x: 0, y: 0, width: 1.0 / 3.0, height: 1)
        case .centerThird: return CGRect(x: 1.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1)
        case .rightThird: return CGRect(x: 2.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1)
        case .leftTwoThirds: return CGRect(x: 0, y: 0, width: 2.0 / 3.0, height: 1)
        case .rightTwoThirds: return CGRect(x: 1.0 / 3.0, y: 0, width: 2.0 / 3.0, height: 1)
        case .centerTwoThirds: return CGRect(x: 1.0 / 6.0, y: 0, width: 2.0 / 3.0, height: 1)
        case .leftQuarter: return CGRect(x: 0, y: 0, width: 0.25, height: 1)
        case .leftMiddleQuarter: return CGRect(x: 0.25, y: 0, width: 0.25, height: 1)
        case .rightMiddleQuarter: return CGRect(x: 0.5, y: 0, width: 0.25, height: 1)
        case .rightQuarter: return CGRect(x: 0.75, y: 0, width: 0.25, height: 1)
        case .maximize: return CGRect(x: 0, y: 0, width: 1, height: 1)
        case .marginMaximize: return CGRect(x: 0.08, y: 0.08, width: 0.84, height: 0.84)
        case .center: return CGRect(x: 0.18, y: 0.16, width: 0.64, height: 0.68)
        case .restore, .previousDisplay, .nextDisplay: return nil
        }
    }
}

/// Built-in keyboard shortcut presets.
enum WindowShortcutProfile: String, CaseIterable, Identifiable {
    /// Classic Control+Option layout bindings (arrows, U/I/J/K, D/F/G, E/T, Return, C, R).
    case standard
    /// Compact Control+Command layout bindings for setups where Control+Option is reserved.
    case compact

    var id: String { rawValue }

    func defaultShortcut(for action: WindowManagerAction) -> GlobalShortcut? {
        switch self {
        case .standard:
            switch action {
            case .leftHalf: return .windowLayoutLeftDefault
            case .rightHalf: return .windowLayoutRightDefault
            case .topHalf: return .windowLayoutTopDefault
            case .bottomHalf: return .windowLayoutBottomDefault
            case .topLeft: return .windowLayoutTopLeftDefault
            case .topRight: return .windowLayoutTopRightDefault
            case .bottomLeft: return .windowLayoutBottomLeftDefault
            case .bottomRight: return .windowLayoutBottomRightDefault
            case .maximize: return .windowLayoutMaximizeDefault
            case .center: return .windowLayoutCenterDefault
            case .restore: return .windowLayoutRestoreDefault
            case .leftThird: return .windowLayoutLeftThirdDefault
            case .centerThird: return .windowLayoutCenterThirdDefault
            case .rightThird: return .windowLayoutRightThirdDefault
            case .leftTwoThirds: return .windowLayoutLeftTwoThirdsDefault
            case .rightTwoThirds: return .windowLayoutRightTwoThirdsDefault
            case .nextDisplay: return .windowLayoutNextDisplayDefault
            case .previousDisplay: return .windowLayoutPreviousDisplayDefault
            case .centerHalf, .centerTwoThirds, .marginMaximize,
                 .leftQuarter, .leftMiddleQuarter, .rightMiddleQuarter, .rightQuarter:
                return nil
            }
        case .compact:
            let mods: GlobalShortcutModifiers = [.control, .command]
            switch action {
            case .leftHalf: return GlobalShortcut(keyCode: Int64(kVK_LeftArrow), modifiers: mods)
            case .rightHalf: return GlobalShortcut(keyCode: Int64(kVK_RightArrow), modifiers: mods)
            case .topHalf: return GlobalShortcut(keyCode: Int64(kVK_UpArrow), modifiers: mods)
            case .bottomHalf: return GlobalShortcut(keyCode: Int64(kVK_DownArrow), modifiers: mods)
            case .topLeft: return GlobalShortcut(keyCode: Int64(kVK_ANSI_U), modifiers: mods)
            case .topRight: return GlobalShortcut(keyCode: Int64(kVK_ANSI_I), modifiers: mods)
            case .bottomLeft: return GlobalShortcut(keyCode: Int64(kVK_ANSI_J), modifiers: mods)
            case .bottomRight: return GlobalShortcut(keyCode: Int64(kVK_ANSI_K), modifiers: mods)
            case .maximize: return GlobalShortcut(keyCode: Int64(kVK_Return), modifiers: mods)
            case .center: return GlobalShortcut(keyCode: Int64(kVK_ANSI_C), modifiers: mods)
            case .restore: return GlobalShortcut(keyCode: Int64(kVK_ANSI_R), modifiers: mods)
            case .leftThird: return GlobalShortcut(keyCode: Int64(kVK_ANSI_D), modifiers: mods)
            case .centerThird: return GlobalShortcut(keyCode: Int64(kVK_ANSI_F), modifiers: mods)
            case .rightThird: return GlobalShortcut(keyCode: Int64(kVK_ANSI_G), modifiers: mods)
            case .leftTwoThirds: return GlobalShortcut(keyCode: Int64(kVK_ANSI_E), modifiers: mods)
            case .rightTwoThirds: return GlobalShortcut(keyCode: Int64(kVK_ANSI_T), modifiers: mods)
            case .nextDisplay:
                return GlobalShortcut(keyCode: Int64(kVK_RightArrow), modifiers: [.control, .option, .command])
            case .previousDisplay:
                return GlobalShortcut(keyCode: Int64(kVK_LeftArrow), modifiers: [.control, .option, .command])
            case .centerHalf, .centerTwoThirds, .marginMaximize,
                 .leftQuarter, .leftMiddleQuarter, .rightMiddleQuarter, .rightQuarter:
                return nil
            }
        }
    }
}

/// Optional modifier required during drag-to-edge snapping.
enum WindowSnapModifier: String, CaseIterable, Identifiable {
    case none
    case option
    case control
    case command
    case shift

    var id: String { rawValue }

    func matches(_ flags: CGEventFlags) -> Bool {
        switch self {
        case .none: return true
        case .option: return flags.contains(.maskAlternate)
        case .control: return flags.contains(.maskControl)
        case .command: return flags.contains(.maskCommand)
        case .shift: return flags.contains(.maskShift)
        }
    }

    /// Coexists cleanly with macOS native Option-drag tiling: when no modifier is
    /// required by Hexa, holding Option yields the drag to the system instead of
    /// drawing two competing snap overlays.
    func shouldTrigger(for flags: CGEventFlags, nativeOptionTilingEnabled: Bool = false) -> Bool {
        if nativeOptionTilingEnabled, flags.contains(.maskAlternate) { return false }
        guard self == .option || !flags.contains(.maskAlternate) else { return false }
        return matches(flags)
    }
}

/// Pure shortcut conflict verdict for the Window Manager module.
enum WindowManagerShortcutConflict: Equatable {
    case windowAction(WindowManagerAction)
    case globalRole(GlobalShortcutRole)
}

// MARK: - Gaps, Display & Stage Manager Descriptors

struct WindowGapsConfig: Equatable {
    static let presets: [Int] = [0, 8, 12, 16, 24, 32]
    static let defaultMarginPercent: Double = 5.0
    static let marginPercentRange: ClosedRange<Double> = 0.0...25.0

    var windowGap: CGFloat
    var screenGap: CGFloat
    var marginPercent: Double

    init(windowGap: CGFloat = 0, screenGap: CGFloat = 0, marginPercent: Double = defaultMarginPercent) {
        self.windowGap = max(0, windowGap)
        self.screenGap = max(0, screenGap)
        self.marginPercent = Self.sanitizedMarginPercent(marginPercent)
    }

    static func sanitizedMarginPercent(_ value: Double) -> Double {
        guard value.isFinite else { return defaultMarginPercent }
        return min(max(value, marginPercentRange.lowerBound), marginPercentRange.upperBound)
    }

    static func fromDefaults(_ defaults: UserDefaults = .standard) -> WindowGapsConfig {
        let wGap = CGFloat(max(0, defaults.integer(forKey: DefaultsKey.windowLayoutWindowGap)))
        let sGap = CGFloat(max(0, defaults.integer(forKey: DefaultsKey.windowLayoutScreenGap)))
        let margin = defaults.object(forKey: DefaultsKey.windowLayoutMarginPercent) as? Double ?? defaultMarginPercent
        return WindowGapsConfig(windowGap: wGap, screenGap: sGap, marginPercent: margin)
    }
}

/// Pure AppKit-free display descriptor in AppKit coordinates (origin at bottom-left of primary display).
struct WindowDisplayDescriptor: Equatable, Identifiable {
    let id: UInt32
    let frame: CGRect
    let visibleFrame: CGRect
    /// Extra top inset for a physical camera housing (notch) if `visibleFrame` did not already clear it.
    let safeAreaTopInset: CGFloat
    let scaleFactor: CGFloat

    init(id: UInt32,
         frame: CGRect,
         visibleFrame: CGRect,
         safeAreaTopInset: CGFloat = 0,
         scaleFactor: CGFloat = 2.0) {
        self.id = id
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.safeAreaTopInset = max(0, safeAreaTopInset)
        self.scaleFactor = max(1, scaleFactor)
    }

    /// Visible frame guaranteed to sit below the notch and menu bar.
    var notchSafeVisibleFrame: CGRect {
        guard safeAreaTopInset > 0 else { return visibleFrame }
        let notchBottomY = frame.maxY - safeAreaTopInset
        guard visibleFrame.maxY > notchBottomY else { return visibleFrame }
        let clippedHeight = max(80, notchBottomY - visibleFrame.minY)
        return CGRect(x: visibleFrame.minX,
                      y: visibleFrame.minY,
                      width: visibleFrame.width,
                      height: clippedHeight)
    }
}

struct StageManagerConfig: Equatable {
    var reserveSpace: Bool
    var stageManagerEnabled: Bool
    var autoHide: Bool
    var dockPosition: String?
    var rightToLeft: Bool

    static let disabled = StageManagerConfig(
        reserveSpace: false,
        stageManagerEnabled: false,
        autoHide: true,
        dockPosition: nil,
        rightToLeft: false
    )
}

// MARK: - Snap Zones

enum WindowSnapZone: String, CaseIterable, Identifiable, Hashable {
    case topLeft, top, topRight
    case left, right
    case bottomLeft, bottom, bottomRight

    var id: String { rawValue }

    var action: WindowManagerAction {
        switch self {
        case .left: return .leftHalf
        case .right: return .rightHalf
        case .top: return .maximize
        case .bottom: return .bottomHalf
        case .topLeft: return .topLeft
        case .topRight: return .topRight
        case .bottomLeft: return .bottomLeft
        case .bottomRight: return .bottomRight
        }
    }

    static func enabledZones(from disabledStorage: String?) -> Set<WindowSnapZone> {
        guard let disabledStorage, !disabledStorage.isEmpty else {
            return Set(allCases)
        }
        let disabled = Set(disabledStorage.split(separator: ",").compactMap {
            WindowSnapZone(rawValue: $0.trimmingCharacters(in: .whitespaces))
        })
        return Set(allCases).subtracting(disabled)
    }

    static func disabledStorageValue(from enabled: Set<WindowSnapZone>) -> String {
        Set(allCases).subtracting(enabled).map(\.rawValue).sorted().joined(separator: ",")
    }
}

struct WindowSnapTarget: Equatable {
    let zone: WindowSnapZone
    let action: WindowManagerAction
    let displayID: UInt32
    let visibleFrame: CGRect
    let previewFrame: CGRect
}

// MARK: - Frame & History Models

struct WindowFrame: Equatable {
    var origin: CGPoint
    var size: CGSize

    var rect: CGRect { CGRect(origin: origin, size: size) }

    init(origin: CGPoint, size: CGSize) {
        self.origin = origin
        self.size = size
    }

    init(rect: CGRect) {
        self.origin = rect.origin
        self.size = rect.size
    }

    func isClose(to other: WindowFrame, tolerance: CGFloat) -> Bool {
        abs(origin.x - other.origin.x) <= tolerance
            && abs(origin.y - other.origin.y) <= tolerance
            && abs(size.width - other.size.width) <= tolerance
            && abs(size.height - other.size.height) <= tolerance
    }
}

struct WindowIdentityKey: Hashable {
    let processID: pid_t
    let processLaunchTime: TimeInterval
    let windowID: CGWindowID
}

struct WindowFrameHistory {
    static let perWindowLimit = 20
    private var framesByWindow: [WindowIdentityKey: [WindowFrame]] = [:]

    mutating func record(_ frame: WindowFrame, for key: WindowIdentityKey) {
        var stack = framesByWindow[key] ?? []
        stack.append(frame)
        if stack.count > Self.perWindowLimit {
            stack.removeFirst(stack.count - Self.perWindowLimit)
        }
        framesByWindow[key] = stack
    }

    mutating func popPrevious(for key: WindowIdentityKey, current: WindowFrame) -> WindowFrame? {
        guard var stack = framesByWindow[key] else { return nil }
        defer {
            if stack.isEmpty {
                framesByWindow.removeValue(forKey: key)
            } else {
                framesByWindow[key] = stack
            }
        }
        while let previous = stack.popLast() {
            if !previous.isClose(to: current, tolerance: 1) {
                return previous
            }
        }
        return nil
    }

    mutating func prune(keeping activeKeys: Set<WindowIdentityKey>) {
        framesByWindow = framesByWindow.filter { activeKeys.contains($0.key) }
    }
}

// MARK: - Pure Geometry Engine

enum WindowGeometryEngine {
    enum DisplayDirection {
        case left, right, up, down
    }

    static let frameTolerance: CGFloat = 8
    static let minimumLayoutDimension: CGFloat = 80
    static let edgeSnapDepth: CGFloat = 18
    static let cornerSnapSize: CGFloat = 96
    static let seamSnapMaxSpeed: CGFloat = 240

    // MARK: Safe Frame (Notch + Menu Bar + Dock + Stage Manager)

    /// Computes the usable layout area for a display, deducting Menu Bar, Dock,
    /// physical Notch safe area, and the Stage Manager recent-apps strip when visible.
    static func safeLayoutFrame(for display: WindowDisplayDescriptor,
                                stageManager: StageManagerConfig = .disabled,
                                stageManagerStripFrames: @autoclosure () -> [CGRect] = []) -> CGRect {
        let base = display.notchSafeVisibleFrame
        return stageManagerAdjustedFrame(
            visibleFrame: base,
            screenFrame: display.frame,
            config: stageManager,
            stripFrames: stageManagerStripFrames()
        )
    }

    static func stageManagerAdjustedFrame(visibleFrame: CGRect,
                                          screenFrame: CGRect,
                                          config: StageManagerConfig,
                                          stripFrames: @autoclosure () -> [CGRect]) -> CGRect {
        guard config.reserveSpace,
              config.stageManagerEnabled,
              !config.autoHide,
              visibleFrame.width > minimumLayoutDimension,
              visibleFrame.height > 0 else {
            return visibleFrame
        }
        let onRight = config.dockPosition == "left"
            || (config.dockPosition != "right" && config.rightToLeft)
        let candidates = stripFrames().filter { frame in
            guard !frame.isNull, !frame.isInfinite,
                  frame.width >= 16, frame.height >= 32,
                  frame.width <= screenFrame.width / 4,
                  frame.minY >= screenFrame.minY, frame.maxY <= screenFrame.maxY else {
                return false
            }
            let distance = onRight ? screenFrame.maxX - frame.maxX : frame.minX - screenFrame.minX
            return distance >= -1 && distance <= 24
        }
        let boundary: CGFloat
        if onRight {
            boundary = candidates.map(\.minX).min().map { $0 - 8 } ?? (screenFrame.maxX - 75)
        } else {
            boundary = candidates.map(\.maxX).max().map { $0 + 8 } ?? (screenFrame.minX + 75)
        }
        let inset = min(max(0, onRight ? visibleFrame.maxX - boundary : boundary - visibleFrame.minX),
                        visibleFrame.width - minimumLayoutDimension)
        return CGRect(x: visibleFrame.minX + (onRight ? 0 : inset),
                      y: visibleFrame.minY,
                      width: visibleFrame.width - inset,
                      height: visibleFrame.height).integral
    }

    // MARK: Core Placement Geometry

    static func rect(for action: WindowManagerAction,
                     current: CGRect,
                     visibleFrame: CGRect,
                     gaps: WindowGapsConfig = WindowGapsConfig(),
                     scaleFactor: CGFloat = 1) -> CGRect {
        let layoutFrame: CGRect
        switch action {
        case .marginMaximize, .center, .restore, .previousDisplay, .nextDisplay:
            layoutFrame = visibleFrame
        default:
            layoutFrame = screenGapFrame(visibleFrame, screenGap: gaps.screenGap)
        }
        let raw = ungappedRect(for: action, current: current, visibleFrame: layoutFrame, marginPercent: gaps.marginPercent)
        let spaced = applyWindowGap(raw, for: action, in: layoutFrame, windowGap: gaps.windowGap)
        let left = (spaced.minX * scaleFactor).rounded(.toNearestOrEven) / scaleFactor
        let right = (spaced.maxX * scaleFactor).rounded(.toNearestOrEven) / scaleFactor
        let bottom = (spaced.minY * scaleFactor).rounded(.toNearestOrEven) / scaleFactor
        let top = (spaced.maxY * scaleFactor).rounded(.toNearestOrEven) / scaleFactor
        return CGRect(x: left, y: bottom, width: right - left, height: top - bottom)
    }

    static func screenGapFrame(_ visibleFrame: CGRect, screenGap: CGFloat) -> CGRect {
        guard screenGap > 0 else { return visibleFrame }
        let dx = min(screenGap, max(0, (visibleFrame.width - minimumLayoutDimension) / 2))
        let dy = min(screenGap, max(0, (visibleFrame.height - minimumLayoutDimension) / 2))
        return visibleFrame.insetBy(dx: dx, dy: dy)
    }

    private static func applyWindowGap(_ rect: CGRect,
                                       for action: WindowManagerAction,
                                       in frame: CGRect,
                                       windowGap: CGFloat) -> CGRect {
        guard windowGap > 0 else { return rect }
        switch action {
        case .maximize, .marginMaximize, .center, .restore, .previousDisplay, .nextDisplay:
            return rect
        default:
            break
        }
        let half = windowGap / 2
        var result = rect
        if result.minX - frame.minX > 1 {
            result.origin.x += half
            result.size.width -= half
        }
        if frame.maxX - result.maxX > 1 {
            result.size.width -= half
        }
        if result.minY - frame.minY > 1 {
            result.origin.y += half
            result.size.height -= half
        }
        if frame.maxY - result.maxY > 1 {
            result.size.height -= half
        }
        result.size.width = max(1, result.size.width)
        result.size.height = max(1, result.size.height)
        return result
    }

    private static func ungappedRect(for action: WindowManagerAction,
                                     current: CGRect,
                                     visibleFrame: CGRect,
                                     marginPercent: Double) -> CGRect {
        let halfW = visibleFrame.width / 2
        let halfH = visibleFrame.height / 2
        let thirdW = visibleFrame.width / 3
        let twoThirdsW = thirdW * 2
        let quarterW = visibleFrame.width / 4

        switch action {
        case .leftHalf:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: halfW, height: visibleFrame.height)
        case .rightHalf:
            return CGRect(x: visibleFrame.midX, y: visibleFrame.minY, width: halfW, height: visibleFrame.height)
        case .topHalf:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.midY, width: visibleFrame.width, height: halfH)
        case .bottomHalf:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: visibleFrame.width, height: halfH)
        case .centerHalf:
            return CGRect(x: visibleFrame.midX - halfW / 2, y: visibleFrame.minY, width: halfW, height: visibleFrame.height)
        case .topLeft:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.midY, width: halfW, height: halfH)
        case .topRight:
            return CGRect(x: visibleFrame.midX, y: visibleFrame.midY, width: halfW, height: halfH)
        case .bottomLeft:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: halfW, height: halfH)
        case .bottomRight:
            return CGRect(x: visibleFrame.midX, y: visibleFrame.minY, width: halfW, height: halfH)
        case .leftThird:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: thirdW, height: visibleFrame.height)
        case .centerThird:
            return CGRect(x: visibleFrame.minX + thirdW, y: visibleFrame.minY, width: thirdW, height: visibleFrame.height)
        case .rightThird:
            return CGRect(x: visibleFrame.maxX - thirdW, y: visibleFrame.minY, width: thirdW, height: visibleFrame.height)
        case .leftTwoThirds:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: twoThirdsW, height: visibleFrame.height)
        case .rightTwoThirds:
            return CGRect(x: visibleFrame.maxX - twoThirdsW, y: visibleFrame.minY, width: twoThirdsW, height: visibleFrame.height)
        case .centerTwoThirds:
            return CGRect(x: visibleFrame.midX - twoThirdsW / 2, y: visibleFrame.minY, width: twoThirdsW, height: visibleFrame.height)
        case .leftQuarter:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: quarterW, height: visibleFrame.height)
        case .leftMiddleQuarter:
            return CGRect(x: visibleFrame.minX + quarterW, y: visibleFrame.minY, width: quarterW, height: visibleFrame.height)
        case .rightMiddleQuarter:
            return CGRect(x: visibleFrame.midX, y: visibleFrame.minY, width: quarterW, height: visibleFrame.height)
        case .rightQuarter:
            return CGRect(x: visibleFrame.maxX - quarterW, y: visibleFrame.minY, width: quarterW, height: visibleFrame.height)
        case .maximize:
            return visibleFrame
        case .marginMaximize:
            let fraction = CGFloat(WindowGapsConfig.sanitizedMarginPercent(marginPercent) / 100.0)
            return visibleFrame.insetBy(dx: visibleFrame.width * fraction, dy: visibleFrame.height * fraction)
        case .center:
            let width = min(current.width, visibleFrame.width)
            let height = min(current.height, visibleFrame.height)
            return CGRect(x: visibleFrame.midX - width / 2,
                          y: visibleFrame.midY - height / 2,
                          width: width,
                          height: height)
        case .restore, .previousDisplay, .nextDisplay:
            return current
        }
    }

    // MARK: minSize / maxSize Resilience & Anchoring

    /// Resolves a target frame when a window enforces a `minSize` or `maxSize`.
    /// Rather than overflowing off-screen or failing silently, the size is clamped
    /// to the window's constraints and anchored to the requested edge or corner
    /// within `visibleFrame`.
    static func resolveConstrainedRect(for action: WindowManagerAction,
                                       targetRect: CGRect,
                                       minSize: CGSize?,
                                       maxSize: CGSize?,
                                       visibleFrame: CGRect) -> CGRect {
        var resolvedSize = targetRect.size
        if let maxSize {
            if maxSize.width > 0 { resolvedSize.width = min(resolvedSize.width, maxSize.width) }
            if maxSize.height > 0 { resolvedSize.height = min(resolvedSize.height, maxSize.height) }
        }
        if let minSize {
            if minSize.width > 0 { resolvedSize.width = max(resolvedSize.width, minSize.width) }
            if minSize.height > 0 { resolvedSize.height = max(resolvedSize.height, minSize.height) }
        }
        return anchoredRect(for: action,
                            targetRect: targetRect,
                            actualSize: resolvedSize,
                            visibleFrame: visibleFrame)
    }

    static func anchoredRect(for action: WindowManagerAction,
                             targetRect: CGRect,
                             actualSize: CGSize,
                             visibleFrame: CGRect) -> CGRect {
        let size = CGSize(width: max(1, actualSize.width), height: max(1, actualSize.height))
        var origin = targetRect.origin

        switch action {
        case .leftHalf, .leftThird, .leftTwoThirds, .leftQuarter:
            origin.x = targetRect.minX
            origin.y = targetRect.maxY - size.height
        case .rightHalf, .rightThird, .rightTwoThirds, .rightQuarter:
            origin.x = targetRect.maxX - size.width
            origin.y = targetRect.maxY - size.height
        case .topHalf:
            origin.x = targetRect.minX
            origin.y = targetRect.maxY - size.height
        case .bottomHalf:
            origin.x = targetRect.minX
            origin.y = targetRect.minY
        case .centerHalf, .centerThird, .centerTwoThirds, .leftMiddleQuarter, .rightMiddleQuarter:
            origin.x = targetRect.midX - size.width / 2
            origin.y = targetRect.maxY - size.height
        case .topLeft:
            origin.x = targetRect.minX
            origin.y = targetRect.maxY - size.height
        case .topRight:
            origin.x = targetRect.maxX - size.width
            origin.y = targetRect.maxY - size.height
        case .bottomLeft:
            origin.x = targetRect.minX
            origin.y = targetRect.minY
        case .bottomRight:
            origin.x = targetRect.maxX - size.width
            origin.y = targetRect.minY
        case .maximize, .marginMaximize, .center:
            origin.x = targetRect.midX - size.width / 2
            origin.y = targetRect.midY - size.height / 2
        case .previousDisplay, .nextDisplay:
            if visibleFrame.maxX - targetRect.maxX < targetRect.minX - visibleFrame.minX {
                origin.x = targetRect.maxX - size.width
            }
            if visibleFrame.maxY - targetRect.maxY <= targetRect.minY - visibleFrame.minY {
                origin.y = targetRect.maxY - size.height
            }
        case .restore:
            return targetRect
        }

        if size.width <= visibleFrame.width {
            origin.x = min(max(origin.x, visibleFrame.minX), visibleFrame.maxX - size.width)
        } else {
            origin.x = visibleFrame.minX
        }
        if size.height <= visibleFrame.height {
            origin.y = min(max(origin.y, visibleFrame.minY), visibleFrame.maxY - size.height)
        } else {
            origin.y = visibleFrame.minY
        }
        return CGRect(origin: origin, size: size)
    }

    // MARK: Repeated Actions & Multi-Display Transfer

    static func horizontalCycle(for action: WindowManagerAction,
                                previousAction: WindowManagerAction?) -> WindowManagerAction? {
        let positions: [WindowManagerAction]
        switch action {
        case .leftHalf, .centerHalf, .rightHalf:
            positions = [.rightHalf, .centerHalf, .leftHalf]
        case .leftThird, .centerThird, .rightThird:
            positions = [.rightThird, .centerThird, .leftThird]
        case .leftTwoThirds, .centerTwoThirds, .rightTwoThirds:
            positions = [.rightTwoThirds, .centerTwoThirds, .leftTwoThirds]
        case .leftQuarter, .leftMiddleQuarter, .rightMiddleQuarter, .rightQuarter:
            positions = [.rightQuarter, .rightMiddleQuarter, .leftMiddleQuarter, .leftQuarter]
        default:
            return nil
        }
        guard let previousAction, let index = positions.firstIndex(of: previousAction) else { return action }
        return positions[(index + 1) % positions.count]
    }

    static func effectiveAction(for action: WindowManagerAction,
                                previousAction: WindowManagerAction?,
                                sideRepeatCyclesThirds: Bool) -> WindowManagerAction {
        if action == .topHalf, previousAction == .topHalf {
            return .maximize
        }
        if sideRepeatCyclesThirds {
            let cycle: [WindowManagerAction]
            switch action {
            case .leftHalf: cycle = [.leftHalf, .leftTwoThirds, .leftThird]
            case .rightHalf: cycle = [.rightHalf, .rightTwoThirds, .rightThird]
            default: cycle = []
            }
            if let previousAction, let idx = cycle.firstIndex(of: previousAction) {
                return cycle[(idx + 1) % cycle.count]
            }
        }
        return action
    }

    static func displayCrossing(for action: WindowManagerAction,
                                previousAction: WindowManagerAction?,
                                sideRepeatCyclesThirds: Bool) -> (action: WindowManagerAction, direction: DisplayDirection)? {
        guard action == previousAction else { return nil }
        if sideRepeatCyclesThirds, action == .leftHalf || action == .rightHalf { return nil }
        switch action {
        case .leftHalf: return (.rightHalf, .left)
        case .rightHalf: return (.leftHalf, .right)
        case .topHalf: return (.bottomHalf, .up)
        case .bottomHalf: return (.topHalf, .down)
        default: return nil
        }
    }

    /// Transfers a window frame across displays with potentially different resolutions and DPIs.
    /// Full-frame windows stay maximized on the destination; partial windows preserve their size
    /// (shrinking only when needed to fit) and leading/trailing edge insets.
    static func transferRect(current: CGRect,
                             from sourceVisibleFrame: CGRect,
                             to destinationVisibleFrame: CGRect) -> CGRect {
        guard sourceVisibleFrame.width > 0, sourceVisibleFrame.height > 0,
              destinationVisibleFrame.width > 0, destinationVisibleFrame.height > 0 else {
            return current.integral
        }
        if current.width >= sourceVisibleFrame.width - frameTolerance,
           current.height >= sourceVisibleFrame.height - frameTolerance {
            return destinationVisibleFrame.integral
        }
        let width = min(destinationVisibleFrame.width, max(1, current.width))
        let height = min(destinationVisibleFrame.height, max(1, current.height))
        let x = unscaledOrigin(sourceMin: sourceVisibleFrame.minX,
                               sourceMax: sourceVisibleFrame.maxX,
                               currentMin: current.minX,
                               currentMax: current.maxX,
                               destMin: destinationVisibleFrame.minX,
                               destMax: destinationVisibleFrame.maxX,
                               size: width,
                               preferMax: false)
        let y = unscaledOrigin(sourceMin: sourceVisibleFrame.minY,
                               sourceMax: sourceVisibleFrame.maxY,
                               currentMin: current.minY,
                               currentMax: current.maxY,
                               destMin: destinationVisibleFrame.minY,
                               destMax: destinationVisibleFrame.maxY,
                               size: height,
                               preferMax: true)
        let clampedX = min(max(x, destinationVisibleFrame.minX), destinationVisibleFrame.maxX - width)
        let clampedY = min(max(y, destinationVisibleFrame.minY), destinationVisibleFrame.maxY - height)
        return CGRect(x: clampedX, y: clampedY, width: width, height: height).integral
    }

    private static func unscaledOrigin(sourceMin: CGFloat, sourceMax: CGFloat,
                                       currentMin: CGFloat, currentMax: CGFloat,
                                       destMin: CGFloat, destMax: CGFloat,
                                       size: CGFloat, preferMax: Bool) -> CGFloat {
        let minInset = currentMin - sourceMin
        let maxInset = sourceMax - currentMax
        let slack = (sourceMax - sourceMin) - (currentMax - currentMin)
        if slack <= frameTolerance {
            return preferMax ? (destMax - maxInset - size) : (destMin + minInset)
        }
        if preferMax {
            if minInset <= frameTolerance, minInset < maxInset {
                return destMin + minInset
            }
            return destMax - maxInset - size
        }
        if maxInset <= frameTolerance, maxInset < minInset {
            return destMax - maxInset - size
        }
        return destMin + minInset
    }

    static func adjacentDisplayIndex(currentIndex: Int,
                                     frames: [CGRect],
                                     movingForward: Bool) -> Int? {
        guard frames.count > 1, frames.indices.contains(currentIndex) else { return nil }
        let ordered = frames.indices.sorted { lhs, rhs in
            let a = frames[lhs], b = frames[rhs]
            if a.minX != b.minX { return a.minX < b.minX }
            if a.minY != b.minY { return a.minY < b.minY }
            if a.width != b.width { return a.width < b.width }
            return lhs < rhs
        }
        guard let pos = ordered.firstIndex(of: currentIndex) else { return nil }
        return ordered[(pos + (movingForward ? 1 : ordered.count - 1)) % ordered.count]
    }

    static func neighbourDisplayIndex(currentIndex: Int,
                                      frames: [CGRect],
                                      direction: DisplayDirection) -> Int? {
        guard frames.indices.contains(currentIndex) else { return nil }
        let current = frames[currentIndex]
        return frames.indices
            .filter { idx in
                guard idx != currentIndex else { return false }
                let candidate = frames[idx]
                switch direction {
                case .left:
                    return candidate.maxX <= current.minX + 1
                        && candidate.maxY > current.minY && candidate.minY < current.maxY
                case .right:
                    return candidate.minX >= current.maxX - 1
                        && candidate.maxY > current.minY && candidate.minY < current.maxY
                case .up:
                    return candidate.minY >= current.maxY - 1
                        && candidate.maxX > current.minX && candidate.minX < current.maxX
                case .down:
                    return candidate.maxY <= current.minY + 1
                        && candidate.maxX > current.minX && candidate.minX < current.maxX
                }
            }
            .min { lhs, rhs in
                let a = frames[lhs], b = frames[rhs]
                let posA: CGFloat, posB: CGFloat, distA: CGFloat, distB: CGFloat
                switch direction {
                case .left:
                    posA = a.maxX; posB = b.maxX
                    distA = abs(a.midY - current.midY); distB = abs(b.midY - current.midY)
                case .right:
                    posA = a.minX; posB = b.minX
                    distA = abs(a.midY - current.midY); distB = abs(b.midY - current.midY)
                case .up:
                    posA = a.minY; posB = b.minY
                    distA = abs(a.midX - current.midX); distB = abs(b.midX - current.midX)
                case .down:
                    posA = a.maxY; posB = b.maxY
                    distA = abs(a.midX - current.midX); distB = abs(b.midX - current.midX)
                }
                if posA != posB {
                    return (direction == .right || direction == .up) ? posA < posB : posA > posB
                }
                if distA != distB { return distA < distB }
                return lhs < rhs
            }
    }

    // MARK: Edge Snap Zone Detection

    /// Resolves the magnetic snap target for a pointer in AppKit coordinates.
    /// On multi-display seams, fast pointer movement passes smoothly to the neighbouring
    /// display without accidentally snapping; pausing or moving slowly snaps on the edge.
    static func snapTarget(at point: CGPoint,
                           displays: [WindowDisplayDescriptor],
                           pointerSpeed: CGFloat = 0,
                           enabledZones: Set<WindowSnapZone> = Set(WindowSnapZone.allCases),
                           gaps: WindowGapsConfig = WindowGapsConfig(),
                           stageManager: StageManagerConfig = .disabled,
                           stageManagerStripFrames: @autoclosure () -> [CGRect] = []) -> WindowSnapTarget? {
        guard !enabledZones.isEmpty,
              let index = displayIndex(containing: point, in: displays) else {
            return nil
        }
        let display = displays[index]
        let frame = display.frame
        let others = displays.enumerated().filter { $0.offset != index }.map(\.element.frame)

        let nearLeft = point.x <= frame.minX + edgeSnapDepth
        let nearRight = point.x >= frame.maxX - edgeSnapDepth
        let nearTop = point.y >= frame.maxY - edgeSnapDepth
        let nearBottom = point.y <= frame.minY + edgeSnapDepth

        guard nearLeft || nearRight || nearTop || nearBottom else { return nil }

        // Check if the triggered edge is an internal seam shared with another display.
        if pointerSpeed > seamSnapMaxSpeed {
            let crossesLeftSeam = nearLeft && others.contains { abs($0.maxX - frame.minX) <= 2 && $0.minY <= point.y && point.y <= $0.maxY }
            let crossesRightSeam = nearRight && others.contains { abs($0.minX - frame.maxX) <= 2 && $0.minY <= point.y && point.y <= $0.maxY }
            let crossesTopSeam = nearTop && others.contains { abs($0.minY - frame.maxY) <= 2 && $0.minX <= point.x && point.x <= $0.maxX }
            let crossesBottomSeam = nearBottom && others.contains { abs($0.maxY - frame.minY) <= 2 && $0.minX <= point.x && point.x <= $0.maxX }
            if crossesLeftSeam || crossesRightSeam || crossesTopSeam || crossesBottomSeam {
                return nil
            }
        }

        let inLeftCorner = point.x <= frame.minX + cornerSnapSize
        let inRightCorner = point.x >= frame.maxX - cornerSnapSize
        let inTopCorner = point.y >= frame.maxY - cornerSnapSize
        let inBottomCorner = point.y <= frame.minY + cornerSnapSize

        let zone: WindowSnapZone
        if (nearTop && inLeftCorner) || (nearLeft && inTopCorner) {
            zone = .topLeft
        } else if (nearTop && inRightCorner) || (nearRight && inTopCorner) {
            zone = .topRight
        } else if (nearBottom && inLeftCorner) || (nearLeft && inBottomCorner) {
            zone = .bottomLeft
        } else if (nearBottom && inRightCorner) || (nearRight && inBottomCorner) {
            zone = .bottomRight
        } else if nearLeft {
            zone = .left
        } else if nearRight {
            zone = .right
        } else if nearTop {
            zone = .top
        } else {
            zone = .bottom
        }

        guard enabledZones.contains(zone) else { return nil }
        let safeVisible = safeLayoutFrame(for: display,
                                          stageManager: stageManager,
                                          stageManagerStripFrames: stageManagerStripFrames())
        let preview = rect(for: zone.action, current: safeVisible, visibleFrame: safeVisible,
                           gaps: gaps, scaleFactor: display.scaleFactor)
        return WindowSnapTarget(zone: zone,
                                action: zone.action,
                                displayID: display.id,
                                visibleFrame: safeVisible,
                                previewFrame: preview)
    }

    // MARK: Coordinate Conversion (Quartz Top-Left <-> AppKit Bottom-Left)

    static func appKitRect(fromQuartz quartzRect: CGRect, primaryScreenTopY: CGFloat) -> CGRect {
        CGRect(x: quartzRect.minX,
               y: primaryScreenTopY - quartzRect.maxY,
               width: quartzRect.width,
               height: quartzRect.height)
    }

    static func quartzRect(fromAppKit appKitRect: CGRect, primaryScreenTopY: CGFloat) -> CGRect {
        CGRect(x: appKitRect.minX,
               y: primaryScreenTopY - appKitRect.maxY,
               width: appKitRect.width,
               height: appKitRect.height)
    }

    /// Checks internal Window Manager actions and active `GlobalShortcutRole` bindings for collisions.
    static func shortcutConflict(for shortcut: GlobalShortcut,
                                 excluding action: WindowManagerAction?,
                                 windowManagerShortcuts: [WindowManagerAction: GlobalShortcut],
                                 roleShortcuts: [(GlobalShortcutRole, GlobalShortcut)]) -> WindowManagerShortcutConflict? {
        for candidate in WindowManagerAction.allCases where candidate != action {
            if windowManagerShortcuts[candidate] == shortcut {
                return .windowAction(candidate)
            }
        }
        for (role, bound) in roleShortcuts where bound == shortcut {
            return .globalRole(role)
        }
        return nil
    }

    private static func displayIndex(containing point: CGPoint,
                                     in displays: [WindowDisplayDescriptor]) -> Int? {
        if let exact = displays.firstIndex(where: { $0.frame.contains(point) }) {
            return exact
        }
        // `CGRect.contains` excludes exact maxX/maxY edges (e.g. pointer pinned at top of screen).
        return displays.firstIndex { descriptor in
            let f = descriptor.frame
            return point.x >= f.minX - 1 && point.x <= f.maxX + 1
                && point.y >= f.minY - 1 && point.y <= f.maxY + 1
        }
    }
}
