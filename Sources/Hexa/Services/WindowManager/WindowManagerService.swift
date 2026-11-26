// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Combine
import CoreGraphics
import Foundation

enum WindowManagerOutcome: Equatable {
    case applied(WindowManagerAction)
    case restored
    case missingAccessibility
    case noWindow
    case noRestoreHistory
    case failed
}

/// Central orchestrator for Hexa's Window Manager module (`DEC-002`, event-driven).
/// Coordinates Carbon global hotkeys, magnetic drag-to-edge snapping, Hexa's
/// snap preview overlay, per-window restore history, and ignored apps.
final class WindowManagerService: ObservableObject {
    static let shared = WindowManagerService()

    @Published private(set) var lastOutcome: WindowManagerOutcome?
    @Published private(set) var failedShortcutActions: Set<WindowManagerAction> = []
    @Published private(set) var ignoredApps: [String] = []
    @Published private(set) var isSnapActive: Bool = false
    @Published private(set) var shortcutRevision: Int = 0

    private static let hotKeySignature: OSType = 0x4858_574D // 'HXWM'

    private var hotKeyRefs: [WindowManagerAction: EventHotKeyRef] = [:]
    private var shortcutRequest: (shortcuts: [WindowManagerAction: GlobalShortcut], conflicts: Set<WindowManagerAction>)?
    private var eventHandler: EventHandlerRef?
    private var hotKeyGeneration = 0

    private var frameHistory = WindowFrameHistory()
    private var lastPlacements: [WindowIdentityKey: (action: WindowManagerAction, frame: WindowFrame, shortcut: GlobalShortcut?)] = [:]
    private var recentPIDs: [pid_t] = []

    private let snapDetector = WindowSnapDetector()
    private let overlayController = WindowOverlayController()
    private let snapMutationQueue = DispatchQueue(label: "io.github.pauloborini.hexa.window-manager.snap",
                                                  qos: .userInteractive)
    private var appActivationObserver: NSObjectProtocol?

    private init() {
        reloadIgnoredApps()
        snapDetector.onPreviewChanged = { [weak self] target in
            guard let self else { return }
            if let target {
                let strings = FeatureStrings.windowManager(L10n.shared.language)
                self.overlayController.show(frame: target.previewFrame,
                                            zoneLabel: strings.actionTitle(target.action))
            } else {
                self.overlayController.hide(immediately: false)
            }
        }
        snapDetector.onSnapCommitted = { [weak self] completed in
            self?.handleCommittedSnap(completed)
        }
        snapDetector.onTapStopped = { [weak self] in self?.suspend() }
        SessionActivity.shared.onChange { [weak self] _ in
            self?.syncWithPreferences()
        }
    }

    // MARK: - Lifecycle

    func syncWithPreferences() {
        reloadIgnoredApps()
        let defaults = UserDefaults.standard
        let available = AppFeature.windowManager.isAvailable
        let trusted = SessionActivitySupport.tapShouldRun(
            featureWanted: available,
            accessibilityGranted: AXIsProcessTrusted(),
            sessionIsActive: SessionActivity.shared.isActive
        )
        guard available && trusted else {
            suspend()
            return
        }

        let shortcutsWanted = defaults.bool(forKey: DefaultsKey.windowLayoutShortcutsEnabled)
        let snapWanted = defaults.bool(forKey: DefaultsKey.windowEdgeSnapEnabled)

        let frontBundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let frontIsIgnored = frontBundle.map { ignoredApps.contains($0) } ?? false

        if shortcutsWanted && !frontIsIgnored && !ShortcutCapture.isCapturing {
            registerHotkeys()
        } else {
            unregisterHotkeys()
        }

        let zones = WindowSnapZone.enabledZones(from: defaults.string(forKey: DefaultsKey.windowEdgeSnapDisabledZones))
        syncActivationObserver(needed: shortcutsWanted || (snapWanted && !zones.isEmpty))
        if snapWanted && !zones.isEmpty {
            let modifier = WindowSnapModifier(rawValue: defaults.string(forKey: DefaultsKey.windowManagerSnapModifier) ?? "") ?? .none
            let reserveSM = defaults.object(forKey: DefaultsKey.windowManagerReserveStageManagerSpace) as? Bool ?? true
            snapDetector.configure(
                enabledZones: zones,
                gaps: WindowGapsConfig.fromDefaults(defaults),
                requiredModifier: modifier,
                reserveStageManagerSpace: reserveSM,
                ignoredBundleIDs: Set(ignoredApps)
            )
            isSnapActive = snapDetector.start()
        } else {
            snapDetector.stop()
            overlayController.hide(immediately: true)
            isSnapActive = false
        }
    }

    func suspend() {
        unregisterHotkeys()
        snapDetector.stop()
        overlayController.tearDown()
        isSnapActive = false
        if !AppFeature.windowManager.isAvailable {
            frameHistory = WindowFrameHistory()
            lastPlacements.removeAll()
            recentPIDs.removeAll()
            lastOutcome = nil
        }
        if let observer = appActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            appActivationObserver = nil
        }
    }

    // MARK: - Shortcut Profiles & Customization

    func resetHorizontalCycle() {
        for key in lastPlacements.keys { lastPlacements[key]?.shortcut = nil }
    }

    func applyShortcutProfile(_ profile: WindowShortcutProfile) {
        let defaults = UserDefaults.standard
        defaults.set(profile.rawValue, forKey: DefaultsKey.windowManagerShortcutProfile)
        for action in WindowManagerAction.allCases {
            SystemShortcutTakeover.setTakeOver(action.shortcutKey, false)
            if let shortcut = profile.defaultShortcut(for: action) {
                defaults.set(shortcut.storageValue, forKey: action.shortcutKey)
            } else {
                defaults.set(WindowManagerAction.clearedShortcutStorageValue, forKey: action.shortcutKey)
            }
        }
        shortcutRequest = nil
        shortcutRevision += 1
        syncWithPreferences()
    }

    func setShortcut(_ shortcut: GlobalShortcut?, for action: WindowManagerAction) {
        let defaults = UserDefaults.standard
        if let shortcut {
            defaults.set(shortcut.storageValue, forKey: action.shortcutKey)
        } else {
            SystemShortcutTakeover.setTakeOver(action.shortcutKey, false)
            defaults.set(WindowManagerAction.clearedShortcutStorageValue, forKey: action.shortcutKey)
        }
        shortcutRequest = nil
        shortcutRevision += 1
        syncWithPreferences()
    }

    func savedShortcutsMap(in defaults: UserDefaults = .standard) -> [WindowManagerAction: GlobalShortcut] {
        var map: [WindowManagerAction: GlobalShortcut] = [:]
        for action in WindowManagerAction.allCases {
            if let shortcut = action.savedShortcut(in: defaults) {
                map[action] = shortcut
            }
        }
        return map
    }

    func conflictTitle(for shortcut: GlobalShortcut,
                       excluding action: WindowManagerAction?,
                       language: AppLanguage = L10n.shared.language,
                       defaults: UserDefaults = .standard) -> String? {
        let roles = GlobalShortcutRole.availableRoles().map { ($0, $0.savedShortcut) }
        let conflict = WindowGeometryEngine.shortcutConflict(
            for: shortcut,
            excluding: action,
            windowManagerShortcuts: savedShortcutsMap(in: defaults),
            roleShortcuts: roles
        )
        switch conflict {
        case .windowAction(let other):
            return FeatureStrings.windowManager(language).actionTitle(other)
        case .globalRole(let role):
            return role.title(Strings.localized(language))
        case nil:
            return Self.screenshotToolShortcuts(in: defaults).first { $0.value == shortcut }?
                .key.screenshotTitle(FeatureStrings.screenshot(language))
        }
    }

    static func activeActionTitle(for shortcut: GlobalShortcut, language: AppLanguage) -> String? {
        guard AppFeature.windowManager.isAvailable,
              UserDefaults.standard.bool(forKey: DefaultsKey.windowLayoutShortcutsEnabled),
              let action = WindowManagerAction.allCases.first(where: { $0.savedShortcut() == shortcut }) else { return nil }
        return FeatureStrings.windowManager(language).actionTitle(action)
    }

    private static func screenshotToolShortcuts(in defaults: UserDefaults) -> [ScreenshotSupport.Tool: GlobalShortcut] {
        guard AppFeature.screenshot.isAvailable(in: defaults) else { return [:] }
        return ScreenshotSupport.Tool.bindings(from: defaults.string(forKey: DefaultsKey.screenshotToolShortcuts))
    }

    // MARK: - Ignored Apps

    func reloadIgnoredApps() {
        let defaults = UserDefaults.standard
        let raw = defaults.stringArray(forKey: DefaultsKey.windowLayoutIgnoredApps) ?? []
        let sanitized = Defaults.sanitizedBundleIdentifierList(raw)
        if sanitized != raw {
            defaults.set(sanitized, forKey: DefaultsKey.windowLayoutIgnoredApps)
        }
        if ignoredApps != sanitized {
            ignoredApps = sanitized
        }
    }

    func addIgnoredApp(_ bundleID: String) {
        let updated = Defaults.sanitizedBundleIdentifierList(ignoredApps + [bundleID])
        guard updated != ignoredApps else { return }
        UserDefaults.standard.set(updated, forKey: DefaultsKey.windowLayoutIgnoredApps)
        ignoredApps = updated
        syncWithPreferences()
    }

    func removeIgnoredApp(_ bundleID: String) {
        guard ignoredApps.contains(bundleID) else { return }
        let updated = ignoredApps.filter { $0 != bundleID }
        UserDefaults.standard.set(updated, forKey: DefaultsKey.windowLayoutIgnoredApps)
        ignoredApps = updated
        syncWithPreferences()
    }

    // MARK: - Action Execution

    @discardableResult
    func apply(_ action: WindowManagerAction, shortcut: GlobalShortcut? = nil) -> WindowManagerOutcome {
        guard AppFeature.windowManager.isAvailable, SessionActivity.shared.isActive else { return .failed }
        guard AXIsProcessTrusted() else {
            suspend()
            return publish(.missingAccessibility)
        }
        guard let target = WindowAccessibilityClient.focusedTarget(
            skippingOwnApp: true,
            ignoredBundleIDs: Set(ignoredApps),
            recentPIDs: recentPIDs
        ) else {
            return publish(.noWindow)
        }

        pruneHistory(keeping: target.key)

        if action == .restore {
            guard let previous = frameHistory.popPrevious(for: target.key, current: target.frame) else {
                return publish(.noRestoreHistory)
            }
            if WindowAccessibilityClient.applyExactQuartzFrame(previous, on: target.window) {
                lastPlacements.removeValue(forKey: target.key)
                return publish(.restored)
            }
            frameHistory.record(previous, for: target.key)
            return publish(.failed)
        }

        let screens = NSScreen.screens
        let descriptors = WindowAccessibilityClient.displayDescriptors(from: screens)
        let topY = WindowAccessibilityClient.primaryScreenTopY(from: screens)
        let currentAppKit = WindowGeometryEngine.appKitRect(fromQuartz: target.frame.rect,
                                                            primaryScreenTopY: topY)
        guard let currentIndex = bestDisplayIndex(for: currentAppKit, in: descriptors) else {
            return publish(.failed)
        }

        let defaults = UserDefaults.standard
        let gaps = WindowGapsConfig.fromDefaults(defaults)
        let reserveSM = defaults.object(forKey: DefaultsKey.windowManagerReserveStageManagerSpace) as? Bool ?? true
        let smConfig = WindowAccessibilityClient.currentStageManagerConfig(reserveSpace: reserveSM)
        let stripFrames = (smConfig.reserveSpace && smConfig.stageManagerEnabled && !smConfig.autoHide)
            ? WindowAccessibilityClient.currentStageManagerStripFrames(primaryScreenTopY: topY)
            : []

        if action == .nextDisplay || action == .previousDisplay {
            guard let destIndex = WindowGeometryEngine.adjacentDisplayIndex(
                currentIndex: currentIndex,
                frames: descriptors.map(\.frame),
                movingForward: action == .nextDisplay
            ) else {
                return publish(.failed)
            }
            let srcVisible = WindowGeometryEngine.safeLayoutFrame(for: descriptors[currentIndex],
                                                                  stageManager: smConfig,
                                                                  stageManagerStripFrames: stripFrames)
            let dstVisible = WindowGeometryEngine.safeLayoutFrame(for: descriptors[destIndex],
                                                                  stageManager: smConfig,
                                                                  stageManagerStripFrames: stripFrames)
            let destRect = WindowGeometryEngine.transferRect(current: currentAppKit,
                                                             from: srcVisible,
                                                             to: dstVisible)
            let placedFrame = WindowAccessibilityClient.applyRect(destRect,
                                                                  action: action,
                                                                  visibleFrame: dstVisible,
                                                                  primaryScreenTopY: topY,
                                                                  on: target.window)
            return recordPlacementOutcome(placedFrame,
                                          action: action,
                                          for: target.key,
                                          previousFrame: target.frame)
        }

        let sideCycle = defaults.bool(forKey: DefaultsKey.windowLayoutSideRepeatCyclesThirds)
        let previousPlacement = lastPlacements[target.key].flatMap { placement in
            target.frame.isClose(to: placement.frame, tolerance: WindowGeometryEngine.frameTolerance) ? placement : nil
        }
        let previousAction = shortcut == nil ? nil : previousPlacement?.action
        let cycledAction: WindowManagerAction?
        if let shortcut, defaults.bool(forKey: DefaultsKey.windowLayoutCycleSameWidth) {
            cycledAction = WindowGeometryEngine.horizontalCycle(
                for: action,
                previousAction: previousPlacement?.shortcut == shortcut ? previousAction : nil
            )
        } else {
            cycledAction = nil
        }

        // Repeated edge half crosses to neighbouring display when thirds-cycle is off.
        if cycledAction == nil,
           let crossing = WindowGeometryEngine.displayCrossing(for: action,
                                                               previousAction: previousAction,
                                                               sideRepeatCyclesThirds: sideCycle),
           let neighbourIdx = WindowGeometryEngine.neighbourDisplayIndex(
               currentIndex: currentIndex,
               frames: descriptors.map(\.frame),
               direction: crossing.direction
           ) {
            let dstVisible = WindowGeometryEngine.safeLayoutFrame(for: descriptors[neighbourIdx],
                                                                  stageManager: smConfig,
                                                                  stageManagerStripFrames: stripFrames)
            return executePlacement(crossing.action,
                                    on: target,
                                    currentAppKit: currentAppKit,
                                    visibleFrame: dstVisible,
                                    gaps: gaps,
                                    scaleFactor: descriptors[neighbourIdx].scaleFactor,
                                    primaryScreenTopY: topY)
        }

        let effective = cycledAction ?? WindowGeometryEngine.effectiveAction(for: action,
            previousAction: previousAction, sideRepeatCyclesThirds: sideCycle)
        let visibleFrame = WindowGeometryEngine.safeLayoutFrame(for: descriptors[currentIndex],
                                                                stageManager: smConfig,
                                                                stageManagerStripFrames: stripFrames)
        return executePlacement(effective,
                                on: target,
                                currentAppKit: currentAppKit,
                                visibleFrame: visibleFrame,
                                gaps: gaps,
                                scaleFactor: descriptors[currentIndex].scaleFactor,
                                primaryScreenTopY: topY,
                                shortcut: cycledAction == nil ? nil : shortcut)
    }

    private func executePlacement(_ action: WindowManagerAction,
                                  on target: WindowAccessibilityTarget,
                                  currentAppKit: CGRect,
                                  visibleFrame: CGRect,
                                  gaps: WindowGapsConfig,
                                  scaleFactor: CGFloat,
                                  primaryScreenTopY: CGFloat,
                                  shortcut: GlobalShortcut? = nil) -> WindowManagerOutcome {
        let destRect = WindowGeometryEngine.rect(for: action,
                                                 current: currentAppKit,
                                                 visibleFrame: visibleFrame,
                                                 gaps: gaps,
                                                 scaleFactor: scaleFactor)
        return executePlacement(action, on: target, destRect: destRect, visibleFrame: visibleFrame,
                                primaryScreenTopY: primaryScreenTopY, previousFrame: target.frame, shortcut: shortcut)
    }

    private func executePlacement(_ action: WindowManagerAction,
                                  on target: WindowAccessibilityTarget,
                                  destRect: CGRect,
                                  visibleFrame: CGRect,
                                  primaryScreenTopY: CGFloat,
                                  previousFrame: WindowFrame,
                                  shortcut: GlobalShortcut? = nil) -> WindowManagerOutcome {
        let placedFrame = WindowAccessibilityClient.applyRect(destRect,
                                                              action: action,
                                                              visibleFrame: visibleFrame,
                                                              primaryScreenTopY: primaryScreenTopY,
                                                              on: target.window)
        return recordPlacementOutcome(placedFrame,
                                      action: action,
                                      for: target.key,
                                      previousFrame: previousFrame,
                                      shortcut: shortcut)
    }

    private func recordPlacementOutcome(_ placedFrame: WindowFrame?,
                                        action: WindowManagerAction,
                                        for key: WindowIdentityKey,
                                        previousFrame: WindowFrame,
                                        shortcut: GlobalShortcut? = nil) -> WindowManagerOutcome {
        guard let placedFrame else {
            return publish(.failed)
        }
        if !previousFrame.isClose(to: placedFrame, tolerance: 1) {
            frameHistory.record(previousFrame, for: key)
        }
        lastPlacements[key] = (action, placedFrame, shortcut)
        return publish(.applied(action))
    }

    private func handleCommittedSnap(_ completed: WindowSnapDetector.CompletedSnap) {
        guard AppFeature.windowManager.isAvailable,
              UserDefaults.standard.bool(forKey: DefaultsKey.windowEdgeSnapEnabled),
              SessionActivity.shared.isActive else { return }
        guard AXIsProcessTrusted() else {
            suspend()
            return
        }

        let screens = NSScreen.screens
        let topY = WindowAccessibilityClient.primaryScreenTopY(from: screens)
        let ignoredSet = Set(ignoredApps)
        let initialFrame = WindowFrame(rect: completed.initialQuartzFrame)

        snapMutationQueue.async { [weak self] in
            guard self != nil else { return }
            guard let target = WindowAccessibilityClient.resolveTarget(windowID: completed.windowID,
                                                                       pid: completed.pid),
                  target.app.bundleIdentifier.map({ !ignoredSet.contains($0) }) ?? true else { return }
            let placedFrame = WindowAccessibilityClient.applyRect(
                completed.target.previewFrame,
                action: completed.target.action,
                visibleFrame: completed.target.visibleFrame,
                primaryScreenTopY: topY,
                on: target.window
            )
            let targetKey = target.key
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      AppFeature.windowManager.isAvailable,
                      SessionActivity.shared.isActive else { return }
                self.pruneHistory(keeping: targetKey)
                _ = self.recordPlacementOutcome(placedFrame,
                                                action: completed.target.action,
                                                for: targetKey,
                                                previousFrame: initialFrame)
            }
        }
    }

    // MARK: - Carbon Global Hotkeys

    private func registerHotkeys() {
        let desired = savedShortcutsMap()
        let reserved = Set(GlobalShortcutRole.availableRoles().map(\.savedShortcut))
            .union(Self.screenshotToolShortcuts(in: .standard).values)
        let eligible = desired.filter { !reserved.contains($0.value) }
        let conflicts = Set(desired.keys).subtracting(eligible.keys)
        if shortcutRequest?.shortcuts == desired, shortcutRequest?.conflicts == conflicts { return }
        unregisterHotkeys()
        var failures = conflicts
        guard !eligible.isEmpty else {
            shortcutRequest = (desired, conflicts)
            failedShortcutActions = Set(desired.keys)
            shortcutRevision += 1
            return
        }
        guard installHotKeyHandlerIfNeeded() else {
            failedShortcutActions = Set(desired.keys)
            shortcutRevision += 1
            return
        }

        var registered = Set<GlobalShortcut>()
        var registrationFailed = false
        for action in WindowManagerAction.allCases {
            guard let shortcut = eligible[action] else { continue }
            guard !registered.contains(shortcut) else {
                failures.insert(action)
                continue
            }
            if SystemShortcutTakeover.isTakenOver(action.shortcutKey) {
                SystemShortcutTakeover.claim(action.shortcutKey, shortcut: shortcut)
            } else if SystemShortcutTakeover.conflictsWithMacOS(shortcut) {
                failures.insert(action)
                continue
            }
            let id = EventHotKeyID(signature: Self.hotKeySignature, id: action.hotKeyID)
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(shortcut.carbonKeyCode,
                                             shortcut.carbonModifiers,
                                             id,
                                             GetEventDispatcherTarget(),
                                             0,
                                             &ref)
            if status == noErr, let ref {
                hotKeyRefs[action] = ref
                registered.insert(shortcut)
                SystemShortcutTakeover.claim(action.shortcutKey, shortcut: shortcut)
            } else {
                SystemShortcutTakeover.release(action.shortcutKey)
                failures.insert(action)
                registrationFailed = true
            }
        }
        if !registrationFailed { shortcutRequest = (desired, conflicts) }
        failedShortcutActions = failures
        shortcutRevision += 1
    }

    private func unregisterHotkeys() {
        hotKeyGeneration += 1
        let hadShortcutState = !hotKeyRefs.isEmpty || shortcutRequest != nil || !failedShortcutActions.isEmpty
        for (action, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
            SystemShortcutTakeover.release(action.shortcutKey)
        }
        hotKeyRefs.removeAll()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        shortcutRequest = nil
        failedShortcutActions.removeAll()
        if hadShortcutState {
            shortcutRevision += 1
        }
    }

    private func installHotKeyHandlerIfNeeded() -> Bool {
        if eventHandler != nil { return true }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetEventDispatcherTarget(), { _, event, userData -> OSStatus in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            if let event {
                GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                  EventParamType(typeEventHotKeyID), nil,
                                  MemoryLayout<EventHotKeyID>.size, nil, &id)
            }
            guard id.signature == WindowManagerService.hotKeySignature,
                  let action = WindowManagerAction(hotKeyID: id.id) else {
                return OSStatus(eventNotHandledErr)
            }
            let service = Unmanaged<WindowManagerService>.fromOpaque(userData).takeUnretainedValue()
            let generation = service.hotKeyGeneration
            DispatchQueue.main.async {
                guard generation == service.hotKeyGeneration,
                      service.hotKeyRefs[action] != nil,
                      !ShortcutCapture.isCapturing,
                      let shortcut = action.savedShortcut() else { return }
                service.apply(action, shortcut: shortcut)
            }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
        return status == noErr && eventHandler != nil
    }

    // MARK: - Helpers

    private func syncActivationObserver(needed: Bool) {
        if needed {
            guard appActivationObserver == nil else { return }
            appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self else { return }
                if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                   app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
                   app.activationPolicy == .regular {
                    self.recentPIDs.removeAll { $0 == app.processIdentifier }
                    self.recentPIDs.insert(app.processIdentifier, at: 0)
                    if self.recentPIDs.count > 12 { self.recentPIDs.removeLast() }
                }
                if !self.ignoredApps.isEmpty || !AXIsProcessTrusted() {
                    self.syncWithPreferences()
                }
            }
        } else if let observer = appActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            appActivationObserver = nil
        }
    }

    private func bestDisplayIndex(for appKitRect: CGRect, in displays: [WindowDisplayDescriptor]) -> Int? {
        displays.indices.max { lhs, rhs in
            let a = displays[lhs].frame.intersection(appKitRect)
            let b = displays[rhs].frame.intersection(appKitRect)
            let areaA = (a.isNull || a.isEmpty) ? 0 : a.width * a.height
            let areaB = (b.isNull || b.isEmpty) ? 0 : b.width * b.height
            return areaA < areaB
        }
    }

    private func pruneHistory(keeping current: WindowIdentityKey) {
        var active = WindowAccessibilityClient.activeWindowKeys()
        active.insert(current)
        frameHistory.prune(keeping: active)
        lastPlacements = lastPlacements.filter { active.contains($0.key) }
    }

    private func publish(_ outcome: WindowManagerOutcome) -> WindowManagerOutcome {
        lastOutcome = outcome
        return outcome
    }
}
