// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import AppKit
import ApplicationServices
import Combine
import CoreGraphics
import Foundation

/// Keeps the Dock on one chosen display. Pointer moves and drags that reach
/// the Dock edge of any other display are nudged back into that screen before
/// the window server passes them to the Dock, so the Dock never receives the
/// request to move; every other event passes untouched. The Dock can be called
/// back to its display on demand, and optionally after sleep or a display
/// change. Requires Accessibility.
final class DockDisplayLockService: ObservableObject {
    static let shared = DockDisplayLockService()

    @Published private(set) var isRunning = false
    /// The connected displays, for the settings picker.
    @Published private(set) var displays: [DockDisplayLockDisplay] = []
    /// The display the Dock is held to right now: the chosen one, or the main
    /// display while the chosen one is away.
    @Published private(set) var anchorID: CGDirectDisplayID?
    /// Where the Dock sits, as last read through Accessibility.
    @Published private(set) var dockDisplayID: CGDirectDisplayID?
    @Published private(set) var isMovingDock = false
    /// macOS only moves the Dock between displays when each display has its
    /// own Spaces; with one set of Spaces across displays the Dock is already
    /// pinned to the main one by the system.
    @Published private(set) var separateSpacesOn = NSScreen.screensHaveSeparateSpaces

    private let zoneLock = NSLock()
    private let lifecycleLock = NSLock()
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapRunLoop: CFRunLoop?
    private var tapThread: Thread?
    private var shouldStopTapThread = false
    private var pendingStartAfterStop = false
    private var lifecycleGeneration: UInt = 0
    // Read by the tap on every move, so kept behind `zoneLock`.
    private var zones = DockDisplayLockSupport.Zones.none
    private var inCorner = false
    private var holdsPointerForMove = false

    // Main thread only.
    private var orientation = DockDisplayLockOrientation.bottom
    private var hotCorners: Set<DockDisplayLockCorner> = []
    private var observers: [(center: NotificationCenter, token: NSObjectProtocol)] = []
    private var pendingReturn: DispatchWorkItem?
    private let moveQueue = DispatchQueue(label: "io.github.pauloborini.hexa.dock-display-lock.move",
                                          qos: .userInitiated)

    /// Marks the moves this service posts to call the Dock over, so its own
    /// tap lets them through while it holds the real pointer still.
    private static let syntheticEventMarker: Int64 = 0x4845_5841 // "HEXA"
    private static let dockBundleID = "com.apple.dock"

    private init() {
        SessionActivity.shared.onChange { [weak self] _ in self?.syncWithPreferences() }
    }

    // MARK: - Lifecycle

    private var isWanted: Bool {
        AppFeature.dockDisplayLock.isAvailable
            && UserDefaults.standard.bool(forKey: DefaultsKey.dockDisplayLockEnabled)
    }

    func syncWithPreferences() {
        if SessionActivitySupport.tapShouldRun(featureWanted: isWanted,
                                               accessibilityGranted: AXIsProcessTrusted(),
                                               sessionIsActive: SessionActivity.shared.isActive) {
            startObserving()
            refresh()
            start()
        } else {
            stop()
            stopObserving()
        }
    }

    private var target: DockDisplayLockTarget {
        DockDisplayLockTarget(storage: UserDefaults.standard.string(forKey: DefaultsKey.dockDisplayLockTarget))
    }

    private var returnsAutomatically: Bool {
        UserDefaults.standard.bool(forKey: DefaultsKey.dockDisplayLockReturns)
    }

    /// Reads the arrangement, the Dock's side and Hot Corners again and hands
    /// the tap the zones they make. `readingDock` also asks Accessibility
    /// where the Dock is, which only the settings card shows.
    func refresh(readingDock: Bool = true) {
        let displays = Self.readDisplays()
        let domain = UserDefaults.standard.persistentDomain(forName: Self.dockBundleID) ?? [:]
        orientation = DockDisplayLockOrientation(storage: domain["orientation"] as? String)
        hotCorners = DockDisplayLockCorner.actions(in: domain)
        let anchor = DockDisplayLockSupport.anchor(for: target, in: displays)
        // With one set of Spaces across all displays, macOS never moves the
        // Dock between them, so there is nothing to hold back. The setting
        // only changes with a new login.
        let separateSpaces = NSScreen.screensHaveSeparateSpaces
        let next = separateSpaces
            ? DockDisplayLockSupport.zones(displays: displays, anchorID: anchor?.id,
                                           orientation: orientation, hotCorners: hotCorners)
            : .none
        zoneLock.withLock {
            if zones != next { inCorner = false }
            zones = next
        }
        if self.displays != displays { self.displays = displays }
        if anchorID != anchor?.id { anchorID = anchor?.id }
        if separateSpacesOn != separateSpaces { separateSpacesOn = separateSpaces }
        if readingDock { readDockDisplay() }
    }

    private func startObserving() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()
        observers = [
            (center, center.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                        object: nil, queue: .main) { [weak self] _ in
                self?.refresh()
                self?.scheduleReturn(after: 1)
            }),
            // macOS can put the Dock back on the main display after a sleep.
            (workspace, workspace.addObserver(forName: NSWorkspace.didWakeNotification,
                                              object: nil, queue: .main) { [weak self] _ in
                self?.refresh()
                self?.scheduleReturn(after: 3)
            }),
            // Only once someone is at the Mac: moving the pointer under the
            // lock screen would read as that someone.
            (distributed, distributed.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"),
                                                  object: nil, queue: .main) { [weak self] _ in
                self?.scheduleReturn(after: 1)
            }),
            // The Dock's side and Hot Corners change in System Settings with
            // no notification of their own. Re-reading when this app comes
            // forward covers the trip back from there, without a timer.
            (center, center.addObserver(forName: NSApplication.didBecomeActiveNotification,
                                        object: nil, queue: .main) { [weak self] _ in
                self?.refresh(readingDock: false)
            }),
        ]
    }

    private func stopObserving() {
        for observer in observers {
            observer.center.removeObserver(observer.token)
        }
        observers = []
        pendingReturn?.cancel()
        pendingReturn = nil
    }

    private func start() {
        let startState = lifecycleLock.withLock { () -> (thread: Thread?, publishRunning: Bool, generation: UInt) in
            if tapThread != nil {
                if shouldStopTapThread {
                    pendingStartAfterStop = true
                    return (nil, false, lifecycleGeneration)
                }
                return (nil, true, lifecycleGeneration)
            }
            shouldStopTapThread = false
            pendingStartAfterStop = false
            lifecycleGeneration &+= 1
            let generation = lifecycleGeneration
            let thread = Thread { [weak self] in
                self?.runEventTap(generation: generation)
            }
            thread.name = "Hexa Dock Display Lock"
            thread.qualityOfService = .userInteractive
            tapThread = thread
            return (thread, false, generation)
        }

        if let thread = startState.thread {
            thread.start()
        } else if startState.publishRunning {
            publishRunning(true, generation: startState.generation)
        }
    }

    private func stop() {
        zoneLock.withLock {
            zones = .none
            inCorner = false
            holdsPointerForMove = false
        }

        let snapshot = lifecycleLock.withLock {
            () -> (runLoop: CFRunLoop?, tap: CFMachPort?, threadExists: Bool, generation: UInt) in
            shouldStopTapThread = true
            pendingStartAfterStop = false
            lifecycleGeneration &+= 1
            return (tapRunLoop, tap, tapThread != nil, lifecycleGeneration)
        }

        if let tap = snapshot.tap {
            // The tap's own thread invalidates the port, after its run loop
            // leaves. Invalidating here would pull the port from under it.
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoop = snapshot.runLoop {
            CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) {
                CFRunLoopStop(runLoop)
            }
            CFRunLoopWakeUp(runLoop)
        } else if !snapshot.threadExists {
            lifecycleLock.withLock {
                shouldStopTapThread = false
                tapThread = nil
            }
        }
        publishRunning(false, generation: snapshot.generation)
    }

    private func runEventTap(generation: UInt) {
        autoreleasepool {
            let runLoop = CFRunLoopGetCurrent()
            lifecycleLock.withLock {
                tapRunLoop = runLoop
            }

            let shouldStopBeforeCreatingTap = lifecycleLock.withLock {
                shouldStopTapThread
            }
            guard !shouldStopBeforeCreatingTap else {
                let shouldRestart = clearEventTapThread()
                if shouldRestart {
                    start()
                } else {
                    publishRunning(false, generation: generation)
                }
                return
            }

            // Drags press on an edge just as moves do: a file carried to the
            // bottom of another display would otherwise take the Dock with it.
            // Clicks join the mask only so a hold during a Dock move can
            // swallow them; they are never nudged.
            let mask = [CGEventType.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
                        .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
                        .otherMouseDown, .otherMouseUp]
                .reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
            guard let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: { _, type, event, userInfo in
                    guard let userInfo else { return Unmanaged.passUnretained(event) }
                    let service = Unmanaged<DockDisplayLockService>.fromOpaque(userInfo).takeUnretainedValue()
                    return service.handle(type: type, event: event)
                },
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            ) else {
                _ = clearEventTapThread()
                publishRunning(false, generation: generation)
                return
            }

            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            lifecycleLock.withLock {
                self.tap = tap
                runLoopSource = source
            }
            CFRunLoopAddSource(runLoop, source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)

            let shouldStop = lifecycleLock.withLock {
                shouldStopTapThread
            }
            if shouldStop {
                CGEvent.tapEnable(tap: tap, enable: false)
            } else {
                publishRunning(true, generation: generation)
                CFRunLoopRun()
            }

            CGEvent.tapEnable(tap: tap, enable: false)
            CFRunLoopRemoveSource(runLoop, source, .commonModes)
            CFMachPortInvalidate(tap)
            let shouldRestart = clearEventTapThread()
            if shouldRestart {
                start()
            } else {
                publishRunning(false, generation: generation)
            }
        }
    }

    private func clearEventTapThread() -> Bool {
        lifecycleLock.withLock {
            let shouldRestart = pendingStartAfterStop
            tap = nil
            runLoopSource = nil
            tapRunLoop = nil
            tapThread = nil
            shouldStopTapThread = false
            pendingStartAfterStop = false
            return shouldRestart
        }
    }

    private func publishRunning(_ running: Bool, generation: UInt) {
        let update = { [weak self] in
            guard let self else { return }
            let isCurrent = self.lifecycleLock.withLock {
                generation == self.lifecycleGeneration
            }
            guard isCurrent else { return }
            self.isRunning = running
        }

        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // A stop under way switches the tap off itself; there is nothing
            // to recover then. Without Accessibility the tap must go, not
            // come back. The lock is held through the enable so a stop on the
            // main thread cannot switch the tap off and lose the race to a
            // re-enable here.
            let canRecover = SessionActivity.shared.isActive && AXIsProcessTrusted()
            let isBack = canRecover && lifecycleLock.withLock { () -> Bool in
                guard !shouldStopTapThread, let tap else { return false }
                CGEvent.tapEnable(tap: tap, enable: true)
                return true
            }
            if !isBack {
                DispatchQueue.main.async { [weak self] in self?.syncWithPreferences() }
            }
            return Unmanaged.passUnretained(event)
        }

        let isOwnMove = event.getIntegerValueField(.eventSourceUserData) == Self.syntheticEventMarker
        let isHeld = zoneLock.withLock { holdsPointerForMove }
        // While the Dock is being called over, the real pointer waits so it
        // cannot pull the path off the edge. Option does not lift this hold:
        // it only gives the edge back during ordinary nudges.
        if isHeld {
            return isOwnMove ? Unmanaged.passUnretained(event) : nil
        }
        // Option is the way to reach the edge on purpose: the last points of
        // another display's Dock edge are held back, and this gives them back
        // while the key is down.
        if event.flags.contains(.maskAlternate) {
            return Unmanaged.passUnretained(event)
        }
        switch type {
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            break
        default:
            return Unmanaged.passUnretained(event)
        }
        let location = event.location
        guard let point = zoneLock.withLock({
            DockDisplayLockSupport.nudged(location, zones: zones, inCorner: &inCorner)
        }) else {
            return Unmanaged.passUnretained(event)
        }
        event.location = point
        return Unmanaged.passUnretained(event)
    }

    // MARK: - Displays and the Dock

    private static func readDisplays() -> [DockDisplayLockDisplay] {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(UInt32(ids.count), &ids, &count) == .success else { return [] }
        let screenNumber = NSDeviceDescriptionKey("NSScreenNumber")
        let names = Dictionary(NSScreen.screens.compactMap { screen -> (CGDirectDisplayID, String)? in
            guard let id = (screen.deviceDescription[screenNumber] as? NSNumber)?.uint32Value else { return nil }
            return (id, screen.localizedName)
        }, uniquingKeysWith: { first, _ in first })
        return ids.prefix(Int(count)).compactMap { id in
            // A display mirroring another shows the same desktop and has no
            // Dock edge of its own.
            guard CGDisplayMirrorsDisplay(id) == kCGNullDirectDisplay,
                  let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue()
            else { return nil }
            return DockDisplayLockDisplay(id: id,
                                          uuid: CFUUIDCreateString(nil, uuid) as String,
                                          name: names[id] ?? "",
                                          frame: CGDisplayBounds(id),
                                          isMain: CGDisplayIsMain(id) != 0,
                                          isBuiltIn: CGDisplayIsBuiltin(id) != 0)
        }
    }

    /// Finds the Dock's icon list through Accessibility and the display it
    /// sits on. The walk costs up to a few hundred milliseconds when the Dock
    /// is slow to answer, so it runs off the main thread; the serial queue
    /// keeps one walk at a time.
    func readDockDisplay() {
        let orientation = self.orientation
        let displays = self.displays
        moveQueue.async { [weak self] in
            let found = Self.dockListFrame().flatMap {
                DockDisplayLockSupport.display(holdingDockFrame: $0, orientation: orientation, displays: displays)
            }
            DispatchQueue.main.async {
                guard let self else { return }
                if self.dockDisplayID != found { self.dockDisplayID = found }
            }
        }
    }

    private static func dockListFrame() -> CGRect? {
        guard AXIsProcessTrusted(),
              let pid = NSRunningApplication.runningApplications(withBundleIdentifier: dockBundleID)
                .first?.processIdentifier
        else { return nil }
        let dock = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(dock, 0.35)
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dock, kAXChildrenAttribute as CFString, &children) == .success,
              let elements = children as? [AXUIElement]
        else { return nil }
        for element in elements {
            var role: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success,
                  role as? String == "AXList"
            else { continue }
            var positionValue: CFTypeRef?
            var sizeValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
                  AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
                  let positionValue, let sizeValue,
                  CFGetTypeID(positionValue) == AXValueGetTypeID(), CFGetTypeID(sizeValue) == AXValueGetTypeID()
            else { continue }
            var position = CGPoint.zero
            var size = CGSize.zero
            guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
                  AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
            else { continue }
            return CGRect(origin: position, size: size)
        }
        return nil
    }

    // MARK: - Calling the Dock over

    /// After sleep, an unlock or a change of displays, the Dock goes back to
    /// its display when the user asked for that. Several triggers in a row
    /// end in one move.
    private func scheduleReturn(after delay: TimeInterval) {
        guard returnsAutomatically else { return }
        pendingReturn?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingReturn = nil
            guard self.returnsAutomatically else { return }
            self.refresh()
            self.moveDockToAnchor()
        }
        pendingReturn = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// Calls the Dock to the display it is held to, by pressing the pointer
    /// against that display's Dock edge the way a person would, and puts the
    /// pointer back. Nothing happens when the Dock is already there, and
    /// nothing happens with one set of Spaces across displays: macOS keeps the
    /// Dock on the main display and no edge press moves it.
    func moveDockToAnchor() {
        guard isWanted, !isMovingDock, SessionActivity.shared.isActive, AXIsProcessTrusted(),
              !Self.screenIsLocked, NSScreen.screensHaveSeparateSpaces, displays.count > 1,
              let anchor = displays.first(where: { $0.id == anchorID })
        else { return }
        isMovingDock = true
        let orientation = self.orientation
        let displays = self.displays
        let generation = lifecycleLock.withLock { lifecycleGeneration }
        moveQueue.async { [weak self] in
            guard let self else { return }
            func stillWanted() -> Bool {
                self.lifecycleLock.withLock { self.lifecycleGeneration == generation } && self.isWanted
            }
            func abortMove(restore original: CGPoint?) {
                self.zoneLock.withLock { self.holdsPointerForMove = false }
                if let original { CGWarpMouseCursorPosition(original) }
                DispatchQueue.main.async { self.isMovingDock = false }
            }
            guard stillWanted() else {
                DispatchQueue.main.async { self.isMovingDock = false }
                return
            }
            // Where the Dock is now, read here so the main thread never waits
            // on the Dock. An unreadable Dock is left alone: pressing an edge
            // blind can move it away from where the user wanted it.
            let found = Self.dockListFrame().flatMap {
                DockDisplayLockSupport.display(holdingDockFrame: $0, orientation: orientation, displays: displays)
            }
            DispatchQueue.main.async { self.dockDisplayID = found }
            guard stillWanted() else {
                DispatchQueue.main.async { self.isMovingDock = false }
                return
            }
            guard let found, found != anchor.id else {
                DispatchQueue.main.async { self.isMovingDock = false }
                return
            }
            let others = displays.filter { $0.id != anchor.id }
            let path = DockDisplayLockSupport.summonPath(to: anchor, orientation: orientation, others: others)
            guard !path.isEmpty else {
                DispatchQueue.main.async { self.isMovingDock = false }
                return
            }
            let source = CGEventSource(stateID: .hidSystemState)
            let original = CGEvent(source: nil)?.location
            self.zoneLock.withLock { self.holdsPointerForMove = true }
            for (index, step) in path.enumerated() {
                guard stillWanted() else {
                    abortMove(restore: original)
                    return
                }
                CGWarpMouseCursorPosition(step.point)
                self.postMove(to: step.point, delta: step.delta, source: source)
                Thread.sleep(forTimeInterval: index < path.count - 10 ? 0.015 : 0.025)
            }
            if let original {
                guard stillWanted() else {
                    abortMove(restore: original)
                    return
                }
                CGWarpMouseCursorPosition(original)
                // A warp alone moves no event past the Dock, which then keeps
                // its icons magnified under a pointer that left. Posted while
                // the pointer is still held so this one is not nudged too.
                self.postMove(to: original, delta: .zero, source: source)
            }
            self.zoneLock.withLock { self.holdsPointerForMove = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.isMovingDock = false
                if stillWanted() { self.readDockDisplay() }
            }
        }
    }

    /// The lock screen is up, or a Mac woke to it: no pointer moves there.
    private static var screenIsLocked: Bool {
        let session = CGSessionCopyCurrentDictionary() as? [String: Any]
        return (session?["CGSSessionScreenIsLocked"] as? NSNumber)?.boolValue ?? false
    }

    private func postMove(to point: CGPoint, delta: CGVector, source: CGEventSource?) {
        guard let event = CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
                                  mouseCursorPosition: point, mouseButton: .left) else { return }
        event.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventMarker)
        event.setIntegerValueField(.mouseEventDeltaX, value: Int64(delta.dx))
        event.setIntegerValueField(.mouseEventDeltaY, value: Int64(delta.dy))
        event.post(tap: .cghidEventTap)
    }
}
