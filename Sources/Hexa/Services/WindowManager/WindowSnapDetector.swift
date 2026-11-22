// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

/// Event-driven drag-to-edge magnetic snap detector (`DEC-002`).
/// Zero timers and zero polling when idle: a passive CGEventTap listens only for
/// left mouse press/drag/release while the feature is enabled and Accessibility
/// is granted, releasing all drag state immediately on mouse-up.
final class WindowSnapDetector {
    struct CompletedSnap {
        let pid: pid_t
        let windowID: CGWindowID
        let initialQuartzFrame: CGRect
        let target: WindowSnapTarget
    }

    var onPreviewChanged: ((WindowSnapTarget?) -> Void)?
    var onSnapCommitted: ((CompletedSnap) -> Void)?
    var onTapStopped: (() -> Void)?

    private struct DragSession {
        let pid: pid_t
        let windowID: CGWindowID
        let initialFrame: CGRect
        let pressOrigin: CGPoint
        let nativeOptionTilingEnabled: Bool
        var isConfirmedWindowMove: Bool = false
        var lastPointer: CGPoint
        var lastTimestamp: TimeInterval
        var lastSpeed: CGFloat = 0
        var currentTarget: WindowSnapTarget?
    }

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapGeneration = 0
    private var activeDrag: DragSession?
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    private var enabledZones: Set<WindowSnapZone> = Set(WindowSnapZone.allCases)
    private var gaps = WindowGapsConfig()
    private var requiredModifier: WindowSnapModifier = .none
    private var reserveStageManagerSpace: Bool = true
    private var ignoredBundleIDs: Set<String> = []

    var isRunning: Bool { tap != nil }

    func configure(enabledZones: Set<WindowSnapZone>,
                   gaps: WindowGapsConfig,
                   requiredModifier: WindowSnapModifier,
                   reserveStageManagerSpace: Bool,
                   ignoredBundleIDs: Set<String>) {
        if self.enabledZones != enabledZones || self.gaps != gaps
            || self.requiredModifier != requiredModifier || self.reserveStageManagerSpace != reserveStageManagerSpace
            || self.ignoredBundleIDs != ignoredBundleIDs {
            cancelActiveDrag()
        }
        self.enabledZones = enabledZones
        self.gaps = gaps
        self.requiredModifier = requiredModifier
        self.reserveStageManagerSpace = reserveStageManagerSpace
        self.ignoredBundleIDs = ignoredBundleIDs
    }

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        guard AXIsProcessTrusted() else { return false }

        let mask = CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
            | CGEventMask(1 << CGEventType.leftMouseDragged.rawValue)
            | CGEventMask(1 << CGEventType.leftMouseUp.rawValue)

        guard let createdTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let detector = Unmanaged<WindowSnapDetector>.fromOpaque(userInfo).takeUnretainedValue()
                detector.handleTapEvent(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, createdTap, 0)
        tap = createdTap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: createdTap, enable: true)
        return true
    }

    func stop() {
        tapGeneration += 1
        cancelActiveDrag()
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        runLoopSource = nil
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        tap = nil
    }

    // MARK: - Event Handling

    private func handleTapEvent(type: CGEventType, event: CGEvent) {
        let generation = tapGeneration
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            tapGeneration += 1
            let disabledGeneration = tapGeneration
            DispatchQueue.main.async { [weak self] in
                guard let self, self.tapGeneration == disabledGeneration else { return }
                self.cancelActiveDrag()
                if let tap = self.tap, SessionActivity.shared.isActive, AXIsProcessTrusted() {
                    CGEvent.tapEnable(tap: tap, enable: true)
                } else {
                    self.stop()
                    self.onTapStopped?()
                }
            }
            return
        }

        let location = event.location
        let flags = event.flags
        let now = ProcessInfo.processInfo.systemUptime

        DispatchQueue.main.async { [weak self] in
            guard let self, self.tapGeneration == generation else { return }
            switch type {
            case .leftMouseDown:
                self.handleMouseDown(at: location, now: now)
            case .leftMouseDragged:
                self.handleMouseDragged(to: location, flags: flags, now: now)
            case .leftMouseUp:
                self.handleMouseUp(at: location, flags: flags, now: now)
            default:
                break
            }
        }
    }

    private func handleMouseDown(at quartzPoint: CGPoint, now: TimeInterval) {
        cancelActiveDrag()
        guard isRunning, !enabledZones.isEmpty else { return }
        guard AXIsProcessTrusted() else {
            stop()
            onTapStopped?()
            return
        }
        guard let candidate = WindowAccessibilityClient.topWindowCandidate(at: quartzPoint,
                                                                           skippingPID: ownPID) else {
            return
        }
        if let app = NSRunningApplication(processIdentifier: candidate.pid),
           let bundle = app.bundleIdentifier,
           ignoredBundleIDs.contains(bundle) {
            return
        }
        // Ignore clicks on window resize edges (within 8pt of border).
        let f = candidate.frame
        let onResizeBorder = abs(quartzPoint.x - f.minX) <= 8
            || abs(quartzPoint.x - f.maxX) <= 8
            || abs(quartzPoint.y - f.maxY) <= 8
            || (abs(quartzPoint.y - f.minY) <= 4)
        guard !onResizeBorder else { return }

        activeDrag = DragSession(
            pid: candidate.pid,
            windowID: candidate.windowID,
            initialFrame: candidate.frame,
            pressOrigin: quartzPoint,
            nativeOptionTilingEnabled: WindowAccessibilityClient.nativeOptionTilingEnabled,
            lastPointer: quartzPoint,
            lastTimestamp: now,
            currentTarget: nil
        )
    }

    private func handleMouseDragged(to quartzPoint: CGPoint, flags: CGEventFlags, now: TimeInterval) {
        guard isRunning, var drag = activeDrag else { return }
        let dt = max(0.004, now - drag.lastTimestamp)
        let speed = hypot(quartzPoint.x - drag.lastPointer.x, quartzPoint.y - drag.lastPointer.y) / CGFloat(dt)
        drag.lastPointer = quartzPoint
        drag.lastTimestamp = now
        drag.lastSpeed = speed

        // Confirm that the window itself is moving with the drag (filters out text selection / canvas drags).
        if !drag.isConfirmedWindowMove {
            let dragDist = hypot(quartzPoint.x - drag.pressOrigin.x, quartzPoint.y - drag.pressOrigin.y)
            if dragDist < 10 {
                activeDrag = drag
                return
            }
            guard let liveFrame = WindowAccessibilityClient.windowServerFrame(ofWindowID: drag.windowID) else {
                cancelActiveDrag()
                return
            }
            let sizeChanged = abs(liveFrame.width - drag.initialFrame.width) > 4
                || abs(liveFrame.height - drag.initialFrame.height) > 4
            if sizeChanged {
                cancelActiveDrag()
                return
            }
            let movedDist = hypot(liveFrame.origin.x - drag.initialFrame.origin.x,
                                  liveFrame.origin.y - drag.initialFrame.origin.y)
            if movedDist < 4 {
                if dragDist > 36 {
                    // Pointer moved far without moving the window: this is an in-app drag.
                    cancelActiveDrag()
                } else {
                    activeDrag = drag
                }
                return
            }
            drag.isConfirmedWindowMove = true
        }

        let target: WindowSnapTarget?
        if requiredModifier.shouldTrigger(for: flags, nativeOptionTilingEnabled: drag.nativeOptionTilingEnabled) {
            target = resolveSnapTarget(atQuartzPoint: quartzPoint, speed: speed)
        } else {
            target = nil
        }

        if target != drag.currentTarget {
            drag.currentTarget = target
            onPreviewChanged?(target)
        }
        activeDrag = drag
    }

    private func handleMouseUp(at quartzPoint: CGPoint, flags: CGEventFlags, now: TimeInterval) {
        guard let drag = activeDrag else { return }
        activeDrag = nil
        onPreviewChanged?(nil)

        let elapsed = now - drag.lastTimestamp
        let distance = hypot(quartzPoint.x - drag.lastPointer.x, quartzPoint.y - drag.lastPointer.y)
        let releaseSpeed = distance / CGFloat(max(0.004, elapsed))
        let speed = elapsed < 0.15 ? max(releaseSpeed, drag.lastSpeed) : releaseSpeed
        guard isRunning,
              drag.isConfirmedWindowMove,
              requiredModifier.shouldTrigger(for: flags, nativeOptionTilingEnabled: drag.nativeOptionTilingEnabled),
              let target = resolveSnapTarget(atQuartzPoint: quartzPoint, speed: speed) else {
            return
        }
        onSnapCommitted?(CompletedSnap(
            pid: drag.pid,
            windowID: drag.windowID,
            initialQuartzFrame: drag.initialFrame,
            target: target
        ))
    }

    private func cancelActiveDrag() {
        if activeDrag?.currentTarget != nil {
            onPreviewChanged?(nil)
        }
        activeDrag = nil
    }

    private func resolveSnapTarget(atQuartzPoint quartzPoint: CGPoint, speed: CGFloat) -> WindowSnapTarget? {
        let screens = NSScreen.screens
        let topY = WindowAccessibilityClient.primaryScreenTopY(from: screens)
        let appKitPoint = CGPoint(x: quartzPoint.x, y: topY - quartzPoint.y)
        let displays = WindowAccessibilityClient.displayDescriptors(from: screens)
        let smConfig = WindowAccessibilityClient.currentStageManagerConfig(reserveSpace: reserveStageManagerSpace)
        return WindowGeometryEngine.snapTarget(
            at: appKitPoint,
            displays: displays,
            pointerSpeed: speed,
            enabledZones: enabledZones,
            gaps: gaps,
            stageManager: smConfig,
            stageManagerStripFrames: WindowAccessibilityClient.currentStageManagerStripFrames(primaryScreenTopY: topY)
        )
    }
}
