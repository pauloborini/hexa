// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import AppKit
import ApplicationServices
import SwiftUI

/// Hides other apps' menu bar items in two sections. The sections exist only
/// as the user's ⌘-drag arrangement between this module's status items; the
/// hiding itself is either a fat separator (up to macOS 26) or the private
/// visibility restriction macOS 27 uses for assessment mode.
///
/// The restriction takes an allow-list of bundles and hides every bundle the
/// list omits, so it is applied only from a read that saw something and only
/// while the hidden section is closed. An app whose items could not be read
/// stays allowed: an icon left visible can be fixed with another click, an
/// icon hidden by mistake cannot.
@MainActor
final class MenuBarHidingService: ObservableObject {
    static let shared = MenuBarHidingService()

    enum State: Equatable {
        case expanded
        case collapsed
        case unavailable(String)
    }

    @Published private(set) var isRunning = false
    @Published private(set) var state: State = .expanded
    @Published private(set) var itemsInSections: [MenuBarSection: [String]] = [:]

    /// System item identifiers to keep visible. Unknown identifiers are
    /// ignored, so the range covers items a given Mac does not have.
    static let systemItemsToKeep = Array(0..<64)
    /// The private activation answers through a completion handler. If macOS
    /// never calls it, the restriction is released rather than left in doubt.
    static let activationTimeout: TimeInterval = 3

    private var toggleItem: NSStatusItem?
    private var separatorItem: NSStatusItem?
    private var assertion: MenuBarVisibilityAssertion?
    private var rehideTimer: Timer?
    private var interactionMonitors: [Any] = []
    private var activationTimer: DispatchWorkItem?
    private var activationGeneration: UInt = 0
    private var inventoryInFlight = false
    private var pendingHide = false
    private var observers: [(center: NotificationCenter, token: NSObjectProtocol)] = []
    /// The layout the current restriction was built from. Reused when opening
    /// the hidden section: items that are hidden report stale frames, so a
    /// fresh read while collapsed would classify them by where they used to
    /// be.
    private var restrictedLayout: MenuBarHidingLayout?
    private var unreadBundles: Set<String> = []
    /// The bundles in the allow-list last applied, without this app's own.
    private var appliedBundles: [String] = []

    private var ownBundleIdentifier: String? { Bundle.main.bundleIdentifier }

    private var text: MenuBarHidingStrings { FeatureStrings.menuBarHiding(L10n.shared.language) }

    private var isWanted: Bool {
        AppFeature.menuBarHiding.isAvailable
            && UserDefaults.standard.bool(forKey: DefaultsKey.menuBarHidingEnabled)
    }

    private var engineKind: MenuBarHidingEngineKind {
        MenuBarHidingEngineKind.forOperatingSystem()
    }

    private init() {}

    // MARK: - Lifecycle

    func syncWithPreferences() {
        guard isWanted else {
            stop()
            return
        }
        if isRunning {
            applySeparatorLengthForCurrentState()
            refreshLayout()
            return
        }
        installItemsIfNeeded()
        startObserving()
        isRunning = true
        state = .expanded
        applySeparatorLengthForCurrentState()
        hide()
    }

    func suspend() {
        stop()
    }

    private func stop() {
        rehideTimer?.invalidate()
        rehideTimer = nil
        removeInteractionMonitor()
        activationTimer?.cancel()
        activationTimer = nil
        activationGeneration &+= 1
        pendingHide = false
        inventoryInFlight = false
        releaseAssertion()
        restrictedLayout = nil
        unreadBundles = []
        appliedBundles = []
        isRunning = false
        state = .expanded
        itemsInSections = [:]
        for observer in observers { observer.center.removeObserver(observer.token) }
        observers = []
        if let toggleItem { NSStatusBar.system.removeStatusItem(toggleItem) }
        if let separatorItem { NSStatusBar.system.removeStatusItem(separatorItem) }
        toggleItem = nil
        separatorItem = nil
    }

    private func startObserving() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        let workspace = NSWorkspace.shared.notificationCenter
        // The arrangement is read on demand. Reading it on every app
        // activation would walk every running app through Accessibility
        // (near a second) for nothing: the restriction is rebuilt right
        // before it is applied, from a read made at that moment.
        observers = [
            (center, center.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                        object: nil, queue: .main) { [weak self] _ in
                self?.applySeparatorLengthForCurrentState()
            }),
            // An app that starts while the section is closed cannot be placed:
            // its item is not in the arrangement, and an allow-list that omits
            // it hides it. It stays visible, the same way an unreadable app
            // does.
            (workspace, workspace.addObserver(forName: NSWorkspace.didLaunchApplicationNotification,
                                              object: nil, queue: .main) { [weak self] note in
                guard let bundle = (note.userInfo?[NSWorkspace.applicationUserInfoKey]
                                    as? NSRunningApplication)?.bundleIdentifier else { return }
                self?.includeBundle(bundle)
            }),
        ]
    }

    private func includeBundle(_ bundle: String) {
        guard isRunning, assertion != nil, engineKind == .visibilityRestriction,
              !appliedBundles.contains(bundle) else { return }
        // Kept in the unread set too, so every later list built from the
        // stored arrangement keeps it visible as well.
        unreadBundles.insert(bundle)
        let allowed = (appliedBundles + [bundle]).sorted()
        // The published state is left as it is: the section stays closed.
        activate(allowing: allowed) { _ in }
    }

    // MARK: - Status items

    private func installItemsIfNeeded() {
        guard toggleItem == nil else { return }
        let toggle = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        toggle.autosaveName = "HexaMenuBarHidingToggle"
        toggle.button?.imagePosition = .imageOnly
        toggle.button?.target = self
        toggle.button?.action = #selector(toggleClicked)
        toggleItem = toggle

        // On macOS 27 the arrow is the only boundary: the restriction hides
        // every app left of it. A separator there would be an empty item the
        // person has to place for nothing.
        guard engineKind == .separatorLength else { return }
        let separator = NSStatusBar.system.statusItem(withLength: 20)
        separator.autosaveName = "HexaMenuBarHidingSeparator"
        separator.button?.isEnabled = false
        separator.button?.toolTip = text.separatorHint
        separatorItem = separator
    }

    @objc private func toggleClicked() {
        switch state {
        case .collapsed:
            reveal()
        case .expanded, .unavailable:
            hide()
        }
    }

    // MARK: - Hiding

    /// Reads where every other app's items are, then closes the hidden section.
    func hide() {
        guard isRunning else { return }
        rehideTimer?.invalidate()
        rehideTimer = nil
        removeInteractionMonitor()
        guard engineKind != .unavailable else {
            releaseAssertion()
            state = .unavailable(text.unavailable)
            return
        }
        guard engineKind == .separatorLength || AXIsProcessTrusted() else {
            releaseAssertion()
            state = .expanded
            return
        }
        switch engineKind {
        case .separatorLength:
            applySeparatorLengthForCurrentState(collapsed: true)
            state = .collapsed
        case .visibilityRestriction:
            if let restrictedLayout, assertion != nil {
                restrict(to: restrictedLayout, unread: unreadBundles, readAnyItem: true)
            } else {
                releaseAssertion()
                pendingHide = true
                refreshLayout()
            }
        case .unavailable:
            break
        }
    }

    /// Opens the hidden section until the chosen delay or interaction ends.
    func reveal() {
        guard isRunning else { return }
        rehideTimer?.invalidate()
        // A hide still reading the bar, or an activate still in flight, must
        // not close the section again after this click asked to open it.
        pendingHide = false
        removeInteractionMonitor()
        activationTimer?.cancel()
        activationTimer = nil
        activationGeneration &+= 1
        switch engineKind {
        case .separatorLength:
            applySeparatorLengthForCurrentState(collapsed: false)
            state = .expanded
        case .visibilityRestriction:
            // Releasing the restriction reveals the whole ordinary hidden
            // section. A fresh read would not see its items while collapsed.
            releaseAssertion()
            state = .expanded
            applySeparatorLengthForCurrentState(collapsed: false)
        case .unavailable:
            return
        }
        scheduleRehide()
    }

    /// Starts the countdown that closes the section again. Every click in the
    /// menu bar while it is open restarts it, so the section stays open while
    /// the person is still using it.
    private func scheduleRehide() {
        installInteractionMonitor()
        restartRehideTimer()
    }

    private func restartRehideTimer() {
        rehideTimer?.invalidate()
        rehideTimer = nil
        guard let seconds = currentRehideDelay.seconds else { return }
        let timer = Timer(timeInterval: seconds, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.hide() }
        }
        RunLoop.main.add(timer, forMode: .common)
        rehideTimer = timer
    }

    private var currentRehideDelay: MenuBarHidingRehideDelay {
        let rawValue = UserDefaults.standard.string(forKey: DefaultsKey.menuBarHidingRehideDelay)
            ?? MenuBarHidingRehideDelay.defaultValue.rawValue
        return MenuBarHidingRehideDelay(rawValue: rawValue) ?? .fiveSeconds
    }

    /// Reacts to one click or key while the section is open. Escape, and a
    /// click outside the bar with the instant choice, close it now; a click
    /// in the bar restarts the countdown.
    private func handleRevealInteraction(isKey: Bool, keyCode: UInt16, location: CGPoint) {
        // `hide()` removes the monitors; a click already queued must not
        // restart a countdown for a section that is closing.
        guard isRunning, state == .expanded, !interactionMonitors.isEmpty else { return }
        if isKey {
            if keyCode == 53 { hide() }
            return
        }
        if isInMenuBar(location) {
            restartRehideTimer()
        } else if currentRehideDelay.seconds == nil {
            hide()
        }
    }

    private func installInteractionMonitor() {
        guard interactionMonitors.isEmpty else { return }
        let events: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .keyDown]
        let forward: (NSEvent) -> Void = { [weak self] event in
            let isKey = event.type == .keyDown
            let keyCode = isKey ? event.keyCode : 0
            let location = NSEvent.mouseLocation
            DispatchQueue.main.async { [weak self] in
                self?.handleRevealInteraction(isKey: isKey, keyCode: keyCode, location: location)
            }
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: events, handler: forward) {
            interactionMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: events, handler: { event in
            forward(event)
            return event
        }) {
            interactionMonitors.append(local)
        }
    }

    private func removeInteractionMonitor() {
        for monitor in interactionMonitors { NSEvent.removeMonitor(monitor) }
        interactionMonitors = []
    }

    private func isInMenuBar(_ point: CGPoint) -> Bool {
        NSScreen.screens.contains { screen in
            screen.frame.contains(point)
                && point.y >= screen.frame.maxY - NSStatusBar.system.thickness
        }
    }

    /// Applies the restriction that keeps only the visible section on screen.
    /// Called only from a just-read arrangement.
    private func restrict(to layout: MenuBarHidingLayout, unread: Set<String>, readAnyItem: Bool) {
        guard let allowed = MenuBarHidingSupport.restrictionAllowList(
            layout: layout, unreadBundles: unread, readAnyItem: readAnyItem) else {
            // A read that saw nothing is no reason to hide every icon: stay
            // open and say why.
            releaseAssertion()
            state = .unavailable(text.readFailed)
            return
        }
        activate(allowing: allowed) { [weak self] succeeded in
            guard let self else { return }
            // `activate` publishes `.unavailable` on failure; keep it.
            guard succeeded else { return }
            self.restrictedLayout = layout
            self.unreadBundles = unread
            self.state = .collapsed
            self.applySeparatorLengthForCurrentState(collapsed: true)
        }
    }

    /// Activates the new restriction before dropping the old one, so switching
    /// between closed and open never flashes the whole bar visible.
    private func activate(allowing bundles: [String], completion: @escaping (Bool) -> Void) {
        guard engineKind != .visibilityRestriction || MenuBarVisibilityBridge.isDeveloperIDSigned else {
            releaseAssertion()
            state = .unavailable(text.unavailable)
            applySeparatorLengthForCurrentState(collapsed: false)
            completion(false)
            return
        }
        guard MenuBarVisibilityBridge.isAvailable else {
            releaseAssertion()
            state = .unavailable(text.unavailable)
            completion(false)
            return
        }
        let allowed = MenuBarHidingSupport.activationAllowList(
            bundles: bundles, ownBundle: ownBundleIdentifier)
        activationGeneration &+= 1
        let generation = activationGeneration
        activationTimer?.cancel()
        let timeout = DispatchWorkItem { [weak self] in
            guard let self, self.activationGeneration == generation else { return }
            // Drop this generation so a late success cannot install a
            // restriction after fail-open has already given the icons back.
            self.activationGeneration &+= 1
            self.activationTimer = nil
            self.releaseAssertion()
            self.state = .unavailable(self.text.activationFailed)
            completion(false)
        }
        activationTimer = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.activationTimeout, execute: timeout)
        MenuBarVisibilityBridge.activate(allowedSystemItems: Self.systemItemsToKeep,
                                         allowedBundleIdentifiers: allowed) { [weak self] result in
            guard let self, self.activationGeneration == generation else { return }
            self.activationTimer?.cancel()
            self.activationTimer = nil
            switch result {
            case let .success(newAssertion):
                let old = self.assertion
                self.assertion = newAssertion
                self.appliedBundles = bundles
                old?.invalidate()
                completion(true)
            case let .failure(error):
                // Fail open: never leave icons hidden after an error.
                self.releaseAssertion()
                self.state = .unavailable(error.localizedDescription)
                completion(false)
            }
        }
    }

    private func releaseAssertion() {
        assertion?.invalidate()
        assertion = nil
        // Nothing is restricted any more, so every item is back on screen and
        // the arrangement captured before the restriction no longer describes
        // where things are.
        restrictedLayout = nil
        appliedBundles = []
    }

    private func applySeparatorLengthForCurrentState(collapsed: Bool? = nil) {
        let isCollapsed: Bool
        if let collapsed {
            isCollapsed = collapsed
        } else {
            if case .collapsed = state { isCollapsed = true } else { isCollapsed = false }
        }
        setToggleImage(collapsed: isCollapsed)
        // Only the separator engine has one; on macOS 27 the arrow is the
        // boundary.
        guard let separatorItem else { return }
        separatorItem.length = MenuBarHidingSupport.separatorLength(
            expanded: !isCollapsed, enabled: true,
            collapsedLength: MenuBarHidingSupport.collapsedLength(
                screenWidths: NSScreen.screens.map(\.frame.width)))
    }

    /// The arrow points where a click moves the icons: left while they are
    /// hidden (they come out to the left), right while they are shown.
    private func setToggleImage(collapsed: Bool) {
        guard let button = toggleItem?.button else { return }
        let symbol = MenuBarHidingSupport.toggleSymbol(collapsed: collapsed)
        guard button.image?.name() != symbol,
              let image = NSImage(systemSymbolName: symbol, accessibilityDescription: text.title)
        else { return }
        image.setName(symbol)
        if button.image != nil, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            button.wantsLayer = true
            let flip = CATransition()
            flip.type = .push
            flip.subtype = collapsed ? .fromRight : .fromLeft
            flip.duration = 0.2
            flip.timingFunction = CAMediaTimingFunction(name: .easeOut)
            button.layer?.add(flip, forKey: "chevron")
        }
        button.image = image
    }

    // MARK: - Sections

    /// Reads which side of the arrow each app's items occupy.
    func refreshLayout() {
        guard isRunning, !inventoryInFlight else { return }
        guard assertion == nil else { return }
        guard let toggleFrame = statusItemFrame(toggleItem) else {
            if pendingHide {
                pendingHide = false
                state = .unavailable(text.readFailed)
            }
            return
        }
        let isLeftToRight = NSApp.userInterfaceLayoutDirection != .rightToLeft
        let ownBundle = ownBundleIdentifier
        inventoryInFlight = true
        MenuBarHidingInventory.snapshot { [weak self] snapshot in
            guard let self else { return }
            self.inventoryInFlight = false
            guard self.isRunning else { return }
            let live = MenuBarHidingLayoutResolver.resolve(
                inventory: snapshot.items,
                separatorFrame: toggleFrame,
                isLeftToRight: isLeftToRight,
                excludingBundle: ownBundle)
            let unread = snapshot.unreadBundles
            self.itemsInSections = [
                .visible: live.bundles(in: [.visible]),
                .hidden: live.bundles(in: [.hidden]),
            ]
            if self.pendingHide {
                self.pendingHide = false
                self.restrict(to: live, unread: unread, readAnyItem: !snapshot.items.isEmpty)
            }
        }
    }

    private func statusItemFrame(_ item: NSStatusItem?) -> CGRect? {
        guard let item, let button = item.button, let window = button.window else { return nil }
        // Screen coordinates, the same space Accessibility reports frames in.
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

}

/// Lists other apps' status items through public Accessibility API: every
/// running app's `AXExtrasMenuBar` children, with the owning bundle from the
/// process.
enum MenuBarHidingInventory {
    struct Snapshot {
        var items: [MenuBarHidingInventoryItem]
        /// Apps whose items could not be read. They stay visible: an
        /// allow-list built without them hides icons the user never moved.
        var unreadBundles: Set<String>
    }

    /// The default timeout is several seconds per app, and one busy or hung
    /// app then stalls the whole read.
    private static let messagingTimeout: Float = 0.1

    static func snapshot(completion: @escaping (Snapshot) -> Void) {
        guard AXIsProcessTrusted() else {
            completion(Snapshot(items: [], unreadBundles: []))
            return
        }
        // Only app bundles own status items. Skipping the rest (dozens of
        // WebKit and XPC helpers, each of which would sit out the timeout)
        // keeps the walk near a second.
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.processIdentifier != ownPID && $0.bundleURL?.pathExtension == "app" }
            .map { (pid: $0.processIdentifier, bundleIdentifier: $0.bundleIdentifier) }
        DispatchQueue.global(qos: .userInitiated).async {
            let snapshot = statusItems(of: apps)
            DispatchQueue.main.async { completion(snapshot) }
        }
    }

    private static func statusItems(of apps: [(pid: pid_t, bundleIdentifier: String?)]) -> Snapshot {
        var items: [MenuBarHidingInventoryItem] = []
        var unreadBundles: Set<String> = []
        for app in apps {
            let element = AXUIElementCreateApplication(app.pid)
            AXUIElementSetMessagingTimeout(element, messagingTimeout)
            var barValue: CFTypeRef?
            let barResult = AXUIElementCopyAttributeValue(element, "AXExtrasMenuBar" as CFString, &barValue)
            // An app without status items answers "unsupported", which is not
            // a failed read.
            if barResult == .attributeUnsupported || barResult == .noValue { continue }
            guard barResult == .success, let barValue,
                  CFGetTypeID(barValue) == AXUIElementGetTypeID() else {
                unreadBundles.formUnion([app.bundleIdentifier].compactMap { $0 })
                continue
            }
            let bar = barValue as! AXUIElement
            AXUIElementSetMessagingTimeout(bar, messagingTimeout)
            var childrenValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(bar, kAXChildrenAttribute as CFString, &childrenValue) == .success,
                  let children = childrenValue as? [AXUIElement] else {
                unreadBundles.formUnion([app.bundleIdentifier].compactMap { $0 })
                continue
            }
            for child in children {
                AXUIElementSetMessagingTimeout(child, messagingTimeout)
                guard let frame = frame(of: child) else {
                    unreadBundles.formUnion([app.bundleIdentifier].compactMap { $0 })
                    continue
                }
                items.append(MenuBarHidingInventoryItem(bundleIdentifier: app.bundleIdentifier, frame: frame))
            }
        }
        return Snapshot(items: items, unreadBundles: unreadBundles)
    }

    /// Accessibility frames use a top-left origin, AppKit's bottom-left. Only
    /// the horizontal position matters for sections, and x is the same in both.
    private static func frame(of element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue, let sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: position, size: size)
    }
}
