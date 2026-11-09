// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import Carbon.HIToolbox
import os.log
import Combine
import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSWindowDelegate, NotchSurfaceCoordinating {
    private var statusController: StatusItemController!
    private let popover = NSPopover()
    private var popoverClosedAt = Date.distantPast
    private var popoverDismissMonitor: Any?
    private var popoverLocalDismissMonitor: Any?
    private var popoverKeyboardMonitor: Any?
    private var popoverIsClosing = false
    private var popoverCloseIsAppRequested = false
    /// The last visible geometry and event destination survive AppKit's teardown.
    private var popoverLastFrame: CGRect?
    private var popoverLastWindowNumber: Int?
    private var popoverForeignReopenAt = Date.distantPast
    private var popoverIsSwitchingAnchor = false
    /// The app to hand activation back to when the panel is dismissed, so
    /// Hexa does not stay in front. Captured when a click opens the panel
    /// and kept current by the observers below while the panel is shown.
    private var panelActivationSource: NSRunningApplication?
    private var panelActivationObservers: [NSObjectProtocol] = []
    private var popoverCloseReason: PanelCloseReason?
    private var popoverCloseCompletions: [() -> Void] = []
    private var isTerminating = false
    private var cancellables = Set<AnyCancellable>()
    private var featureWorkspaceWindow: NSWindow? { FeatureWorkspaceWindow.shared.presentationWindow }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // Scrollers em overlay: só um knob fino durante a rolagem, sem a caixa
        // da trilha clássica. Vale para as ScrollViews do SwiftUI; o
        // OverlayScrollView fixa o próprio estilo. No domínio de registro, a
        // escolha "Sempre" dos Ajustes do Sistema continua vencendo; a remoção
        // apaga o valor que versões anteriores gravaram no domínio do app.
        UserDefaults.standard.removeObject(forKey: "AppleShowScrollBars")
        UserDefaults.standard.register(defaults: ["AppleShowScrollBars": "WhenScrolling"])
        // Fontes OFL do design system (DEC-017) antes de qualquer view renderizar.
        HexaTheme.registerFonts()
        // Before any window exists, so nothing is ever built with the wrong
        // appearance and then repainted.
        AppAppearanceController.shared.apply()
        GlobalShortcut.startObservingKeyboardLayout()
        // UNUserNotificationCenter aborts in a process without a bundle;
        // guard keeps ad-hoc runs of the bare binary alive for probing.
        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().delegate = self
        }
        beginStartupWatch()
        Self.boundAccessibilityWaits()
        // Pay the first AppKit process lookup before an input callback needs
        // it. Each click still resolves the current process independently.
        _ = AssistiveKeyboard.isRunning

        // Redo a launch at login registration the system lost. The stored
        // choice is the last thing the user expressed in the app; startup
        // never turns the item off.
        LaunchAtLogin.repairAtStartup()

        // Switch back on any display a previous run left off. A run that ends
        // without putting one back leaves a screen dark with no app around to
        // offer it back, so the repair happens before anything else can care
        // about which displays are attached.
        BrightnessService.shared.restoreDisplaysLeftOff()

        // An accessory (LSUIElement) app gets no default main menu, so the standard
        // keyboard shortcuts (Cmd+H/M/W/Q and the Edit shortcuts Cmd+C/V/X/A) have
        // no menu items to fire and do nothing in the Settings window. Install one.
        installMainMenu()
        PanelLayout.resetCollapsedSectionsOnce(for: "0.1.0")

        statusController = StatusItemController()
        statusController.onLeftClick = { [weak self] in
            self?.captureStatusClick()
            self?.toggleMainPopover()
        }
        statusController.onRightClick = { [weak self] button in
            // With the main item hidden by choice, the quick toggle would leave the
            // command center without an entry point, so the context menu opens instead.
            if AppFeature.keepAwake.isAvailable
                && UserDefaults.standard.bool(forKey: DefaultsKey.keepAwakeRightClickToggle)
                && self?.statusController.mainItemHiddenByChoice == false {
                KeepAwakeManager.shared.toggle()
            } else {
                self?.showContextMenu(from: button)
            }
        }
        statusController.onMetricClick = { [weak self] metric, button in
            self?.captureStatusClick()
            self?.showMetricPanel(for: metric, anchoredTo: button)
        }

        setUpPopover()
        bindManagers()

        // A marker from an earlier build may name a hotkey id this build no
        // longer owns; give it back before any feature decides what to hold.
        // It has to run before the first claim of the launch — keep-awake makes
        // one on the next line — because a claim resolves what every source
        // wants together, and a marker no source has spoken for yet resolves
        // to nothing and is handed back whole.
        SystemShortcutTakeover.recoverIfNeeded(keeping: [])
        HotkeyManager.shared.onActivate = { KeepAwakeManager.shared.toggle() }
        HotkeyManager.shared.syncWithPreferences()

        KeepAwakeManager.shared.recoverIfNeeded {
            KeepAwakeManager.shared.activateOnLaunchIfNeeded()
        }
        FanControlService.recoverIfNeeded()
        // One binding per feature: only available features are touched, so a
        // feature switched off in the hub never even instantiates here.
        FeatureRuntime.shared.syncAtLaunch()
        NotificationCenter.default.addObserver(self, selector: #selector(appBecameActive),
                                               name: NSApplication.didBecomeActiveNotification, object: nil)

        // If Accessibility is granted while the app is running (e.g. during
        // onboarding), bring the features that need it up without a relaunch.
        // The list comes from the catalog so a new feature cannot be missed.
        let accessibilityFeatures: [AppFeature] = AppFeature.allCases.filter {
            $0.isAvailable && $0.permissions.contains(.accessibility)
        }
        Permissions.shared.$accessibility
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { _ in
                FeatureRuntime.shared.sync(accessibilityFeatures)
            }
            .store(in: &cancellables)

        // Keep the menu titles in step with the in-app language.
        L10n.shared.$language
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.installMainMenu() }
            .store(in: &cancellables)

        let defaults = UserDefaults.standard
        // Whatever opens a window at startup waits for the next turn of the
        // run loop, so the menu bar icon is on screen first. A start that goes
        // wrong after this point then leaves the app reachable instead of
        // invisible. And if the previous start never finished, the extra
        // windows are skipped entirely this time: the app comes up bare rather
        // than walking into the same thing twice.
        let skipStartupWindows = startupOfPreviousRunDidNotFinish
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Keep the last seen version marker current without opening
            // post-update release notes; the update flow already previews
            // them.
            let previousVersion = defaults.string(forKey: DefaultsKey.lastUpdateIntroVersion)
            self.queueBrightnessUpdatePromptIfNeeded(previousVersion: previousVersion)
            defaults.set(AppInfo.version, forKey: DefaultsKey.lastUpdateIntroVersion)
            guard !skipStartupWindows else { return }
            // A tela de boas-vindas é a primeira coisa que o usuário vê na
            // primeira execução; o aviso de atualização vem depois dela. A
            // guarda do arranque que morreu mora na própria decisão, para ser
            // verificável sem AppKit.
            if OnboardingProgress.shouldPresent(skipStartupWindows: skipStartupWindows) {
                OnboardingWindow.shared.show()
            }
            self.recoverStatusItemAfterUpdate(previousVersion: previousVersion)
            self.presentUpdateIntros()
        }
    }

    /// Asking another app about its windows waits for that app to answer, and
    /// the wait allowed by default is a second and a half per question. An app
    /// that is busy saving, or stuck on a slow disk, would hold this one still
    /// for that long each time, and this app asks in places where the whole
    /// session is waiting on it. The limit is set once here, low enough that a
    /// slow answer is dropped rather than felt. The value matches what the
    /// window features already settled on for themselves. It applies to every
    /// question asked from this process, whichever element it is asked of, so
    /// it also covers the places that never set one of their own.
    private static func boundAccessibilityWaits() {
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.35)
    }

    // MARK: - Startup that did not finish

    /// A start is marked as under way before anything else happens and cleared
    /// once the app has been running healthily for a while, or when it is
    /// quit properly. Finding the mark still set means the previous run died
    /// on the way up, and this one leaves the optional windows out of it.
    private var startupOfPreviousRunDidNotFinish = false

    /// How long a run has to last before its start counts as having worked.
    /// Comfortably past the point where the reported failures happened.
    private static let healthyStartupSeconds: TimeInterval = 20

    private func beginStartupWatch() {
        let defaults = UserDefaults.standard
        startupOfPreviousRunDidNotFinish = defaults.bool(forKey: DefaultsKey.startupDidNotFinish)
        defaults.set(true, forKey: DefaultsKey.startupDidNotFinish)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.healthyStartupSeconds) {
            UserDefaults.standard.removeObject(forKey: DefaultsKey.startupDidNotFinish)
        }
    }

    private func endStartupWatch() {
        UserDefaults.standard.removeObject(forKey: DefaultsKey.startupDidNotFinish)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Quitting skips the editor's own close confirmation.
        guard !AppFeature.screenshot.isAvailable
                || ScreenshotEditorController.confirmDiscardBeforeQuit() else { return .terminateCancel }
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        isTerminating = true
        // Hands back every icon before the process goes: the restriction is
        // released explicitly instead of trusting the system to drop it.
        if AppFeature.menuBarHiding.isAvailable { MenuBarHidingService.shared.suspend() }
        if AppFeature.notch.isAvailable { NotchService.shared.stop(restoreCapture: false) }
        // A child process outlives the app, so a running conversion stops here.
        if AppFeature.mediaTools.isAvailable { MediaService.shared.cancel(immediately: true) }
        // Quitting properly means the start worked, whenever it happened.
        endStartupWatch()
        if AppFeature.brightness.isAvailable {
            BrightnessService.shared.restoreDisplaysBeforeTermination()
        }
        ProcessUsageService.shared.stopNetworkMonitoring(force: true)
        PreciseVolumeRollerService.shared.stop()
        AppVolumeMixer.shared.stopAll()
        FanControlService.restoreBeforeTerminationIfNeeded()
        // Every macOS shortcut a feature took over goes back now, whichever
        // feature held it; not all of them suspend here.
        SystemShortcutTakeover.restoreAll()
        KeepAwakeManager.shared.deactivate(reason: .quit)
        // After every teardown above that still writes preferences.
        Uninstaller.finishOnTerminateIfNeeded()
    }

    /// The lifeline when the menu bar icon goes missing. Opening the app again
    /// from Finder, Spotlight or Launchpad while it's already running lands here:
    /// force the icon back and pop the panel so there's immediate proof the app is
    /// alive. Without this, a hidden icon would strand the app running with no way
    /// in. (A cold launch can't happen while running, so this is the recovery path.)
    /// Reopens that Siri and Shortcuts send on their own are ignored.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        let requester = ReopenRequestSupport.currentSender()
        guard ReopenRequestSupport.isPersonOpeningApp(requester) else {
            Self.menuBarLog.log("reopen ignored from \(ReopenRequestSupport.logName(requester), privacy: .public)")
            return false
        }
        if restoreMiniaturizedAppWindows() { return true }
        guard !flag else { return true }
        // A deliberate reopen with no windows showing is the user's recovery action.
        // Rebuild the menu bar item only when it is actually missing: the
        // pre-rebuild item has a settled frame, so iconIsOnScreen() is trustworthy
        // here (the not-ready-frame caveat below only applies to a freshly created
        // item), and a dropped icon reads off-screen/zero, so recovery still gets
        // its rebuild with fresh placement. A healthy icon is left alone: on
        // macOS 27 a rebuilt item's window can keep reporting the slot it was
        // born in (the far right of the status area) while the icon draws at the
        // user's arranged spot, and that mismatch strands the panel against the
        // screen edge and survives relaunches. An item the app took out of the
        // bar itself, for Dynamic Island or for metrics, is not missing either:
        // a rebuild would only hide it again, and Settings opens below.
        if statusController?.mainItemHiddenByChoice != true, !iconIsOnScreen() {
            statusController?.recreateStatusItem()
        }
        // Decide on the next run-loop turn: a freshly rebuilt status item has no
        // laid-out on-screen frame yet this turn, so iconIsOnScreen() would read a
        // not-ready frame and wrongly skip the panel. After layout: pop the panel
        // when the icon is genuinely on screen, else fall back to the Settings
        // window. Either way the user ALWAYS gets back in.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.iconIsOnScreen(), !self.popover.isShown {
                self.popoverClosedAt = .distantPast
                self.togglePopover()
            }
            if !self.popover.isShown {
                self.openFeatureWorkspace(.general)
            }
        }
        return true
    }

    /// Clique no Dock com a janela de telas ou o onboarding minimizados: o
    /// AppKit trata isso como "sem janelas visíveis" e, sem este passo, o
    /// caminho de recuperação abriria o popover em vez de devolver a janela.
    private func restoreMiniaturizedAppWindows() -> Bool {
        var restored = false
        for window in [FeatureWorkspaceWindow.shared.presentationWindow,
                       OnboardingWindow.shared.presentationWindow] {
            guard let window, window.isMiniaturized else { continue }
            window.deminiaturize(nil)
            restored = true
        }
        if restored {
            NSApp.activate(ignoringOtherApps: true)
        }
        return restored
    }

    /// Whether the menu bar icon is actually visible on a screen, rather than
    /// present in the status bar but clipped or dropped by a crowded/notched menu
    /// bar (in which case the button still has a window, just not an on-screen one).
    private static let menuBarLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "hexa",
                                           category: "menubar")

    private func iconIsOnScreen() -> Bool {
        // A hidden item is not on screen, whatever frame its window last had.
        guard statusController?.statusItem.isVisible == true,
              let frame = statusController?.statusItem.button?.window?.frame else { return false }
        // The band test, not mere intersection: an item macOS never places
        // keeps a full-size window at the main display's bottom-left origin,
        // which intersects that screen and read as "appeared".
        return StatusItemPlacementSupport.isPlacedStatusFrame(frame, screenFrames: NSScreen.screens.map(\.frame))
    }

    private func iconIsSettling() -> Bool {
        StatusItemAnchorSupport.isSettlingStatusFrame(
            statusController?.statusItem.button?.window?.frame)
    }

    /// What the recovery saw, in the app's own log. Whether macOS gave the
    /// rebuilt item a place is invisible from the outside, so a report of an
    /// icon that never comes back has nothing to go on without this.
    /// Read with:
    /// log show --last 1h --predicate 'category == "menubar"'
    private func logStatusItemPlacement(_ stage: String) {
        let window = statusController?.statusItem.button?.window
        let frame = window?.frame ?? .zero
        let placement = "\(Int(frame.origin.x)),\(Int(frame.origin.y)) \(Int(frame.width))x\(Int(frame.height))"
        let screens = NSScreen.screens.map { "\(Int($0.frame.width))x\(Int($0.frame.height))" }
            .joined(separator: ",")
        let visible = statusController?.statusItem.isVisible ?? false
        let manager = Self.runningMenuBarManagerName() ?? "none"
        Self.menuBarLog.log("reshow \(stage, privacy: .public) window=\(window != nil) frame=\(placement, privacy: .public) visible=\(visible) screens=\(screens, privacy: .public) organizer=\(manager, privacy: .public)")
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    private func bindManagers() {
        // The island's only route back to the shell: every operation it used
        // to reach through `NSApp.delegate` goes through this coordinator.
        NotchService.shared.surfaceCoordinator = self
        KeepAwakeManager.shared.onSessionEnded = { reason in
            let strings = L10n.shared.s
            switch reason {
            case .timer:
                Notifier.post(title: strings.notifySessionEndedTitle, body: strings.notifySessionEndedBody)
            case .battery:
                Notifier.post(title: strings.notifyBatteryTitle, body: strings.notifyBatteryBody)
            default:
                break
            }
        }
    }

    // MARK: - Main panel

    private func setUpPopover() {
        // Application-defined (not .transient) so the panel stays open while the
        // user works in our own Settings window and sees changes live. Click
        // monitors below dismiss it when it would block that same Settings window.
        popover.behavior = .applicationDefined
        popover.animates = true
        // Use AppKit's standard content frame. A fixed SwiftUI root combined
        // with full-size popover content leaves asymmetric system-material bands.
        popover.hasFullSizeContent = false
        popover.delegate = self
        let host = NSHostingController(rootView: QuickControlPanel())
        host.safeAreaRegions = []
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
        AppAppearanceController.shared.follow(panel: popover)
    }

    private func togglePopover(anchor button: NSStatusBarButton? = nil) {
        if popover.isShown {
            closePopover(reason: .statusItem)
            return
        }
        showPopover(anchor: button)
    }

    private func toggleMainPopover() {
        if !popover.isShown {
            MenuPanelFocus.shared.showNormalPanel()
        }
        togglePopover()
    }

    func isOverStatusItem(_ point: NSPoint) -> Bool {
        statusController?.containsStatusItem(at: point) == true
    }

    // MARK: - NotchSurfaceCoordinating

    /// The island's route to the menu panel focus; `openFeatureWorkspace(_:settingsMode:)`
    /// and `isOverStatusItem(_:)` satisfy the protocol directly.
    func showNormalPanelFocus() {
        MenuPanelFocus.shared.showNormalPanel()
    }

    func closePopoverPreservingNotch() {
        closePopover(preservingNotch: true)
    }

    private func showMetricPanel(for metric: MenuBarMetric, anchoredTo button: NSStatusBarButton) {
        FeatureWorkspaceWindow.shared.show(metric: metric.detailKind)
    }



    private func statusButtonMidX(_ button: NSStatusBarButton) -> CGFloat? {
        guard let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil)).midX
    }

    /// Where the user last physically clicked a status button, captured at
    /// action time. The deferred metric re-shows fire up to ~0.2s after the
    /// click, and re-reading the pointer there would chase a flicked-away
    /// cursor; the captured point is immune to that. Accessibility presses
    /// (no mouse event) capture nothing, so they never "correct" toward a
    /// pointer parked anywhere on screen.
    private var lastStatusClick: (point: NSPoint, at: Date)?
    private var popoverAnchor: PanelAnchor?
    private var lastGoodPanelAnchor: PanelAnchor?
    private var popoverDriftObservers: [NSObjectProtocol] = []
    private var popoverPositioningPanel: NSPanel?

    /// How long a captured click still counts as "where the icon is".
    private static let statusClickFreshness: TimeInterval = 0.5

    /// The spot an open panel holds: the horizontal middle and the top edge it
    /// must keep across content resizes, plus the screen the menu bar icon was
    /// on. The screen travels with the anchor instead of being read back from
    /// the panel's window, because a window already flung to a corner can
    /// report a different display and would then be clamped against that one.
    private struct PanelAnchor {
        /// The opening popover window's horizontal center, used while direct
        /// frame correction is still responsible for placement.
        let midX: CGFloat
        /// The opening arrow's screen-space tip, used once the popover hangs
        /// from a stable positioning view. With a trustworthy status frame this
        /// is the status button's center, while `midX` is the already-placed
        /// window's center; AppKit's horizontal edge clamp can make them differ.
        /// Fallback anchors know only one x coordinate and use it for both.
        let tipX: CGFloat
        let top: CGFloat
        let screen: NSScreen?
        /// False when it came from a fallback, so a guess never becomes the
        /// remembered good anchor for the rest of the session.
        let trusted: Bool
        /// True when the anchor is known to beat the status item's frame from
        /// the moment the panel opens, because a physical click landed clearly
        /// outside that frame. Otherwise the anchor waits: while the frame
        /// still describes a spot in the menu bar the system places the panel
        /// better than any remembered point can, following the icon as the bar
        /// shuffles items around it.
        let overridesSoundFrame: Bool
        /// The button the anchor was taken from, so "does the frame still
        /// describe the bar?" asks the item the panel is actually hanging off
        /// (a metric item, not necessarily the main icon).
        weak var button: NSStatusBarButton?
    }

    private func captureStatusClick() {
        guard let event = NSApp.currentEvent,
              Self.statusClickEventTypes.contains(event.type),
              (0...Self.statusClickFreshness).contains(ProcessInfo.processInfo.systemUptime - event.timestamp)
        else {
            lastStatusClick = nil
            return
        }
        lastStatusClick = (NSEvent.mouseLocation, Date())
    }

    private var freshStatusClick: NSPoint? {
        guard let click = lastStatusClick,
              (0...Self.statusClickFreshness).contains(Date().timeIntervalSince(click.at)) else { return nil }
        return click.point
    }

    /// The on-screen midX the open panel must center on, or nil when the
    /// button's reported frame can be trusted. A fresh physical click landing
    /// clearly outside the frame the button claims to occupy is the macOS 27
    /// stale-frame mismatch (see StatusItemAnchorSupport): the click marks
    /// where the icon is actually drawn, so the panel centers there. The
    /// positioning rect cannot express this (AppKit intersects it with the
    /// button's bounds), so the correction moves the popover's window instead.
    private func correctedPopoverMidX(for button: NSStatusBarButton) -> CGFloat? {
        guard let click = freshStatusClick,
              let reportedMidX = statusButtonMidX(button),
              StatusItemAnchorSupport.anchorDriftX(clickX: click.x,
                                                   reportedMidX: reportedMidX,
                                                   buttonWidth: button.bounds.width) != nil
        else { return nil }
        return click.x
    }

    private static let statusClickEventTypes: Set<NSEvent.EventType> = [
        .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
    ]

    /// The screen the menu bar icon lives on, for the panel's height cap and
    /// for clamping it once it is open.
    private func statusScreen(for button: NSStatusBarButton) -> NSScreen? {
        // Replicated menu bars (including Sidecar) can report the status
        // window on a different display. The captured click identifies the
        // actual bar, including vertically arranged screens with the same x.
        if let click = freshStatusClick,
           let clicked = NSScreen.screens.first(where: { NSMouseInRect(click, $0.frame, false) }) {
            return clicked
        }
        if let frame = button.window?.frame,
           let hosting = NSScreen.screens.first(where: { $0.frame.intersects(frame) }) {
            return hosting
        }
        // A window parked out of the visible area reports no screen of its own,
        // and that is exactly the state this path exists for, so fall back to
        // the display that owns the bar rather than to whichever one happens to
        // hold the key window.
        return button.window?.screen ?? NSScreen.withMenuBar
    }

    /// Whether the item the panel hangs off still reports a frame that sits in
    /// a menu bar. While it does, the system's own placement wins and the
    /// remembered anchor stays out of the way; once it stops (a bar that hides
    /// itself parks the window out of the visible area) the anchor takes over.
    private func frameStillDescribesMenuBar(_ anchor: PanelAnchor) -> Bool {
        guard let frame = anchor.button?.window?.frame,
              let screen = anchor.screen, screen.isStillAttached else { return false }
        return StatusItemAnchorSupport.isTrustworthyStatusFrame(frame, screenFrames: [screen.frame])
    }

    private func statusFrameNeedsAnchorOverride(_ anchor: PanelAnchor) -> Bool {
        anchor.overridesSoundFrame || !frameStillDescribesMenuBar(anchor)
    }

    /// The spot the panel must hold while it is open, decided at the moment it
    /// opens: the user has just clicked the icon, so the menu bar is up and its
    /// frame is at its most trustworthy. Everything after that (a bar that
    /// slides away, a status item stranded at the slot it was born in) is read
    /// from a frame that no longer describes where the icon is.
    private func resolvePanelAnchor(for button: NSStatusBarButton, window: NSWindow) -> PanelAnchor {
        let screen = statusScreen(for: button)
        let statusFrame = button.window?.frame
        let frameIsSound = statusFrame.map {
            StatusItemAnchorSupport.isTrustworthyStatusFrame($0, screenFrames: screen.map { [$0.frame] } ?? [])
        } ?? false
        if frameIsSound, statusFrame != nil {
            // Where the popover has just been placed is the anchor: with a
            // sound frame the system put it exactly right, including its own
            // clamping near a screen edge, so holding that spot changes
            // nothing about how an open panel looks. It is held in reserve,
            // though, and only applied once that frame stops describing the
            // bar. A fresh physical click that clearly disagrees with the
            // frame is the stranded item instead, and then the click marks
            // where the icon really is and outranks the frame right away.
            let corrected = correctedPopoverMidX(for: button)
            return PanelAnchor(midX: corrected ?? window.frame.midX,
                               tipX: corrected ?? statusButtonMidX(button) ?? window.frame.midX,
                               top: window.frame.maxY,
                               screen: screen,
                               trusted: true,
                               overridesSoundFrame: corrected != nil,
                               button: button)
        }
        // A real click outranks both a frame on another display and a spot
        // remembered from an earlier opening. Reset the top as well as x:
        // the first AppKit placement may have used an entirely different bar.
        if let click = freshStatusClick, let screen,
           NSMouseInRect(click, screen.frame, false) {
            return PanelAnchor(midX: click.x, tipX: click.x,
                               top: screen.visibleFrame.maxY, screen: screen,
                               trusted: true, overridesSoundFrame: true, button: button)
        }
        // Without a click or a usable frame, reuse this session's last spot
        // before falling back to the corner of the screen that owns the bar.
        // The remembered spot is only worth reusing while it still describes
        // somewhere that exists. One captured on a display that has since been
        // unplugged would put the panel against an edge of the display that is
        // left, which is the very thing this is here to prevent.
        if let remembered = lastGoodPanelAnchor,
           let rememberedScreen = remembered.screen,
           rememberedScreen.isStillAttached,
           rememberedScreen.displayID == screen?.displayID {
            // Reused for an item whose frame is already pointing nowhere, so it
            // has to act now rather than wait for a frame that will not recover.
            return PanelAnchor(midX: remembered.midX, tipX: remembered.tipX,
                               top: remembered.top,
                               screen: screen, trusted: true,
                               overridesSoundFrame: true, button: button)
        }
        lastGoodPanelAnchor = nil
        let visible = screen?.visibleFrame ?? window.frame
        return PanelAnchor(midX: visible.maxX, tipX: visible.maxX,
                           top: visible.maxY, screen: screen,
                           trusted: false, overridesSoundFrame: true, button: button)
    }

    /// Keeps the popover at the opening anchor when its status item stops being
    /// trustworthy. Ordinary menu-bar movement remains AppKit's responsibility;
    /// an untrustworthy frame instead gets a stable screen-space positioning
    /// view so both the window and its arrow survive later geometry changes.
    private func beginPopoverDriftCorrection(window: NSWindow, anchor: PanelAnchor) {
        endPopoverDriftCorrection()
        armPopoverDriftCorrection(window: window, anchor: anchor)
    }

    /// Re-arms drift correction after AppKit re-shows the popover against our
    /// stable positioning view. Keeping the panel out of the ordinary teardown
    /// prevents `popoverDidClose` from closing the new anchor mid-switch.
    private func beginPopoverDriftCorrection(window: NSWindow,
                                             anchor: PanelAnchor,
                                             preserving positioningPanel: NSPanel) {
        endPopoverDriftCorrection(preserving: positioningPanel)
        popoverPositioningPanel = positioningPanel
        positioningPanel.orderFrontRegardless()
        armPopoverDriftCorrection(window: window, anchor: anchor)
    }

    private func armPopoverDriftCorrection(window: NSWindow, anchor: PanelAnchor) {
        popoverAnchor = anchor
        if anchor.trusted { lastGoodPanelAnchor = anchor }
        PanelInteractionState.shared.anchorScreen = anchor.screen
        if popoverPositioningPanel != nil {
            useStablePopoverPositioningViewIfNeeded(window)
        } else {
            applyPopoverDriftFrame(window)
        }
        popoverLastFrame = window.frame
        popoverLastWindowNumber = window.windowNumber
        for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
            popoverDriftObservers.append(NotificationCenter.default.addObserver(
                forName: name, object: window, queue: .main
            ) { [weak self, weak window] notification in
                guard let self, let window else { return }
                self.popoverLastFrame = window.frame
                // Once the popover hangs from the stable view, that view is the
                // only authority for placement. Recompute its screen-space
                // position on both resize and move; applying the old midX frame
                // as well would fight AppKit's tip-aware edge clamping.
                if self.popoverPositioningPanel != nil {
                    self.useStablePopoverPositioningViewIfNeeded(window)
                    return
                }
                let contentResized = notification.name == NSWindow.didResizeNotification
                if contentResized, self.useStablePopoverPositioningViewIfNeeded(window) { return }
                self.applyPopoverDriftFrame(window)
                guard contentResized else { return }
                // A status-item frame can become untrustworthy after the
                // popover opens. AppKit may run another placement pass after
                // publishing the resize, so check once more on the next turn.
                DispatchQueue.main.async { [weak self, weak window] in
                    guard let self,
                          let window,
                          self.popover.isShown,
                          window === self.popover.contentViewController?.view.window else { return }
                    self.useStablePopoverPositioningViewIfNeeded(window)
                }
            })
        }
    }

    private func applyPopoverDriftFrame(_ window: NSWindow) {
        guard let anchor = popoverAnchor,
              // A healthy bar places the panel better than the anchor can, and
              // keeps it under an icon that shifts as items come and go, so the
              // anchor stays dormant until that frame stops meaning anything.
              statusFrameNeedsAnchorOverride(anchor),
              let visible = anchorVisibleFrame(anchor, window: window) else { return }
        let frame = window.frame
        let target = StatusItemAnchorSupport.pinnedPanelFrame(size: frame.size,
                                                              anchorMidX: anchor.midX,
                                                              anchorTop: anchor.top,
                                                              visibleFrame: visible)
        // The 2pt tolerance breaks the loop with our own setFrame's didMove.
        guard abs(frame.midX - target.midX) > 2 || abs(frame.maxY - target.maxY) > 2 else { return }
        window.setFrame(target, display: true)
    }

    /// An untrustworthy status-item frame leaves AppKit pointing the arrow at a
    /// parked positioning view. Replace it with a transparent screen-space view
    /// at the opening arrow location, and keep that view current as the popover
    /// or display geometry changes.
    @discardableResult
    private func useStablePopoverPositioningViewIfNeeded(_ window: NSWindow) -> Bool {
        guard let anchor = popoverAnchor,
              popoverPositioningPanel != nil
                || statusFrameNeedsAnchorOverride(anchor),
              let visibleFrame = anchorVisibleFrame(anchor, window: window) else { return false }
        let targetFrame = StatusItemAnchorSupport.pinnedPanelFrame(size: window.frame.size,
                                                                  anchorMidX: anchor.midX,
                                                                  anchorTop: anchor.top,
                                                                  visibleFrame: visibleFrame)
        let tipX = min(max(anchor.tipX, visibleFrame.minX), visibleFrame.maxX)
        let anchorRect = CGRect(x: tipX - 0.5, y: targetFrame.maxY, width: 1, height: 1)
        if let panel = popoverPositioningPanel {
            if abs(panel.frame.minX - anchorRect.minX) > 0.5
                || abs(panel.frame.minY - anchorRect.minY) > 0.5 {
                panel.setFrame(anchorRect, display: false)
            }
            return true
        }
        let panel = OverlayPanel(contentRect: anchorRect,
                                 styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered,
                                 defer: false)
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.level = window.level
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary,
                                    .stationary, .ignoresCycle]
        let positioningView = NSView(frame: CGRect(origin: .zero, size: anchorRect.size))
        panel.contentView = positioningView
        popoverPositioningPanel = panel
        panel.orderFrontRegardless()
        let preservedAnchor = anchor
        popoverIsSwitchingAnchor = true
        MenuPanelFocus.shared.setSwitchingMetricAnchor(true)
        popover.animates = false
        popover.show(relativeTo: positioningView.bounds,
                     of: positioningView,
                     preferredEdge: .minY)
        MenuPanelFocus.shared.setPopoverVisible(popover.isShown)
        popover.animates = true
        guard popover.isShown,
              let popoverWindow = popover.contentViewController?.view.window else {
            endPopoverDriftCorrection()
            panel.close()
            removePopoverDismissMonitor()
            popoverIsSwitchingAnchor = false
            MenuPanelFocus.shared.setSwitchingMetricAnchor(false)
            // A close during the show ran while switching, so popoverDidClose
            // kept these for a panel that is not coming back.
            if !popover.isShown {
                releasePanelResources()
                endPanelActivationTracking()
            }
            return false
        }
        configurePopoverWindow(popoverWindow)
        popoverWindow.makeKey()
        beginPopoverDriftCorrection(window: popoverWindow,
                                    anchor: preservedAnchor,
                                    preserving: panel)
        installPopoverDismissMonitor()
        DispatchQueue.main.async { [weak self] in
            self?.popoverIsSwitchingAnchor = false
            MenuPanelFocus.shared.setSwitchingMetricAnchor(false)
        }
        return true
    }

    /// The usable area the panel is clamped to. Prefers the anchor's own screen
    /// and only falls back when that display has since been unplugged.
    private func anchorVisibleFrame(_ anchor: PanelAnchor, window: NSWindow) -> CGRect? {
        if let screen = anchor.screen, screen.isStillAttached {
            return screen.visibleFrame
        }
        return (window.screen ?? NSScreen.withMenuBar)?.visibleFrame
    }

    private func endPopoverDriftCorrection(preserving positioningPanel: NSPanel? = nil) {
        popoverDriftObservers.forEach { NotificationCenter.default.removeObserver($0) }
        popoverDriftObservers.removeAll()
        if popoverPositioningPanel !== positioningPanel {
            popoverPositioningPanel?.close()
        }
        popoverPositioningPanel = nil
        popoverAnchor = nil
        // Nothing is measuring itself against a screen with the panel closed,
        // and holding one keeps a display object alive for no reason.
        PanelInteractionState.shared.anchorScreen = nil
    }

    private func configurePopoverWindow(_ window: NSWindow) {
        // Keep the panel alive next to fullscreen apps and on any Space —
        // without this it blinks shut when another display is fullscreen.
        window.collectionBehavior.insert([.fullScreenAuxiliary, .canJoinAllSpaces])
        if let panel = window as? NSPanel {
            panel.hidesOnDeactivate = false
        }
    }


    private func showPopover(anchor button: NSStatusBarButton? = nil,
                             allowRecentClose: Bool = false,
                             animate: Bool = true,
                             activate: Bool = true,
                             restoring savedAnchor: PanelAnchor? = nil) {
        guard !popover.isShown, !popoverIsClosing else { return }
        // The click that just transient-dismissed the popover also lands here;
        // reopening would make the panel look impossible to close.
        guard allowRecentClose || Date().timeIntervalSince(popoverClosedAt) > 0.15 else { return }
        guard let button = button ?? statusController.button else { return }

        // The panel measures itself against this while the popover lays out, so
        // it has to be known before the content is asked for its size.
        PanelInteractionState.shared.anchorScreen = savedAnchor?.screen ?? statusScreen(for: button)
        if !animate {
            popover.animates = false
        }
        MenuPanelFocus.shared.setPopoverVisible(true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        MenuPanelFocus.shared.setPopoverVisible(popover.isShown)
        if !animate {
            popover.animates = true
        }
        if let window = popover.contentViewController?.view.window {
            configurePopoverWindow(window)
            window.contentView?.layoutSubtreeIfNeeded()
            window.makeKey()
            popoverIsClosing = false
            popoverCloseIsAppRequested = false
            popoverCloseReason = nil
        }
        if activate {
            beginPanelActivationTracking()
            NSApp.activate(ignoringOtherApps: true)
        }
        // Only arm the monitors and the anchor if the popover actually presented
        // — otherwise popoverDidClose never fires and both would leak, holding a
        // display object and a window observer for the rest of the session.
        guard popover.isShown else {
            endPopoverDriftCorrection()
            endPanelActivationTracking()
            return
        }
        if let window = popover.contentViewController?.view.window {
            beginPopoverDriftCorrection(window: window,
                                        anchor: savedAnchor ?? resolvePanelAnchor(for: button, window: window))
        }
        installPopoverDismissMonitor()
    }

    private func installPopoverDismissMonitor() {
        removePopoverDismissMonitor()
        // A global monitor only sees events delivered to OTHER apps, so a click in
        // another app or on the desktop dismisses the panel.
        popoverDismissMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self, self.popover.isShown else { return }
            guard !PanelInteractionState.shared.preventsPopoverDismissal else { return }
            guard self.statusController.containsStatusItem(at: NSEvent.mouseLocation) == false else { return }
            self.closePopover(reason: .outsideClick)
        }

        // Local events cover our own Settings window. Keep Settings + panel open
        // when they sit side by side for live reordering, but close the panel if it
        // overlaps Settings and the user clicks Settings to get it out of the way.
        popoverLocalDismissMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self, self.popover.isShown else { return event }
            if self.shouldDismissPopover(forLocalEvent: event) {
                self.closePopover(reason: .outsideClick)
            }
            return event
        }

        popoverKeyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handlePopoverKeyDown(event)
        }
    }

    private func removePopoverDismissMonitor() {
        if let monitor = popoverDismissMonitor {
            NSEvent.removeMonitor(monitor)
            popoverDismissMonitor = nil
        }
        if let monitor = popoverLocalDismissMonitor {
            NSEvent.removeMonitor(monitor)
            popoverLocalDismissMonitor = nil
        }
        if let monitor = popoverKeyboardMonitor {
            NSEvent.removeMonitor(monitor)
            popoverKeyboardMonitor = nil
        }
    }

    private func shouldDismissPopover(forLocalEvent event: NSEvent) -> Bool {
        guard !PanelInteractionState.shared.preventsPopoverDismissal else { return false }
        guard let featureWorkspaceWindow,
              event.windowNumber == featureWorkspaceWindow.windowNumber && event.windowNumber > 0,
              let popoverFrame = popover.contentViewController?.view.window?.frame else {
            return false
        }
        return featureWorkspaceWindow.frame.intersects(popoverFrame)
    }

    private func handlePopoverKeyDown(_ event: NSEvent) -> NSEvent? {
        if popover.isShown, event.keyCode == UInt16(kVK_Escape) {
            // The monitor sees the whole app; Esc in another window, such as
            // Settings or a popover or dialog opened from the panel, stays there.
            guard let window = popover.contentViewController?.view.window,
                  event.window === window else { return event }
            // While an input method is composing, Esc belongs to it and
            // drops the candidate; the panel closes on the next one.
            if (window.firstResponder as? NSTextView)?.hasMarkedText() == true { return event }
            closePopover(reason: .escape)
            return nil
        }

        guard popover.isShown,
              PanelInteractionState.shared.viewKeepsPopoverOpen,
              isPlainPopoverHoldKey(event),
              let window = popover.contentViewController?.view.window else {
            return event
        }

        // Text controls inside the popover, especially the Homebrew search
        // field, need Space/Return delivered through AppKit's normal field
        // editor path so delegates and target/actions can submit correctly.
        if isTextEditingActive(in: window) {
            return event
        }

        if NSApp.keyWindow === window || event.window === window {
            window.firstResponder?.keyDown(with: event)
            return nil
        }
        return event
    }

    private func isPlainPopoverHoldKey(_ event: NSEvent) -> Bool {
        let blockedModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
        guard event.modifierFlags.intersection(blockedModifiers).isEmpty else { return false }
        return event.keyCode == 49 || event.keyCode == 36 || event.keyCode == 76
    }

    private func isTextEditingActive(in window: NSWindow) -> Bool {
        guard let responder = window.firstResponder else { return false }
        if responder is NSTextView || responder is NSTextField {
            return true
        }
        guard let fieldEditor = window.fieldEditor(false, for: nil) else { return false }
        return responder === fieldEditor
    }

    @objc private func appBecameActive() {
        // Menu bar icon recovery happens on a deliberate reopen, not here: this
        // fires on every activation, so rebuilding here would cause churn/flicker.
        restoreAfterAppUpdateHandoff()
        if featureWorkspaceWindow?.isVisible == true {
            NotificationCenter.default.post(name: LaunchAtLoginSupport.settingsRefreshRequested, object: nil)
        }
    }

    /// Some updates finish in another app. With no Dock icon there is no way
    /// back to the window that sent the person there, so returning brings it
    /// forward again, on the update list, while the list reads the truth again.
    private func restoreAfterAppUpdateHandoff() {
        guard AppFeature.appUpdates.isAvailable else { return }
        let service = AppUpdatesService.shared
        service.applicationBecameActive()
        // Only a window still on screen is brought back. A Settings window the
        // person closed themselves stays closed.
        guard service.consumeUpdateHandoffReturn(),
              featureWorkspaceWindow?.isVisible == true else { return }
        openFeatureWorkspace(.appUpdates)
    }

    /// Callers other than the dismissal paths are panel actions, so `reason`
    /// defaults to one that leaves activation alone.
    func closePopover(animated: Bool = true, after delay: TimeInterval = 0,
                      preservingNotch: Bool = false, reason: PanelCloseReason = .action,
                      completion: (() -> Void)? = nil) {
        if !preservingNotch, NotchSupport.isEnabled() { NotchService.shared.collapse() }
        if delay <= 0 {
            closePopoverNow(animated: animated, reason: reason, completion: completion)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.closePopoverNow(animated: animated, reason: reason, completion: completion)
        }
    }

    private func closePopoverNow(animated: Bool, reason: PanelCloseReason,
                                 completion: (() -> Void)?) {
        guard popover.isShown else {
            completion?()
            return
        }
        if let completion { popoverCloseCompletions.append(completion) }
        popoverCloseIsAppRequested = true
        // Any request in the same close that hands work to something else
        // wins, so a dismissal racing an action never takes activation back.
        if popoverCloseReason?.dismissesWithoutTakeover != false {
            popoverCloseReason = reason
        }
        guard !popoverIsClosing else { return }

        popoverIsClosing = true
        if animated {
            popover.performClose(nil)
        } else {
            popover.animates = false
            popover.close()
            popover.animates = true
        }
    }

    private func runPopoverCloseCompletions() {
        let completions = popoverCloseCompletions
        popoverCloseCompletions.removeAll()
        completions.forEach { $0() }
    }

    // The SwiftUI panel reports which monitor sections are actually visible.
    func popoverWillShow(_ notification: Notification) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .menuPanelWillShow, object: nil)
        }
        SystemMonitor.shared.suppressGPUReadsForTransientUI()
    }

    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        popoverCloseIsAppRequested || !PanelInteractionState.shared.preventsPopoverDismissal
    }

    func popoverWillClose(_ notification: Notification) {
        popoverIsClosing = true
        if !popoverIsSwitchingAnchor {
            popoverClosedAt = Date()
        }
    }

    func popoverDidClose(_ notification: Notification) {
        if !popover.isShown {
            MenuPanelFocus.shared.setPopoverVisible(false)
        }
        // Decided before anything below is torn down, and treated like a
        // metric anchor switch: the panel is about to be shown again in the
        // same turn, so the sampling and caches it is using stay alive.
        let recoveryAnchor = anchorAfterForeignClose()
        if recoveryAnchor != nil {
            popoverIsSwitchingAnchor = true
            MenuPanelFocus.shared.setSwitchingMetricAnchor(true)
        }
        if !popoverIsSwitchingAnchor {
            releasePanelResources()
        }
        removePopoverDismissMonitor()
        endPopoverDriftCorrection()
        PanelInteractionState.shared.viewKeepsPopoverOpen = false
        PanelInteractionState.shared.isPresentingPopoverModal = false
        popoverClosedAt = popoverIsSwitchingAnchor ? .distantPast : Date()
        popoverIsClosing = false
        popoverCloseIsAppRequested = false
        let closeReason = popoverCloseReason
        popoverCloseReason = nil
        runPopoverCloseCompletions()
        if let recoveryAnchor {
            reopenPanelAfterForeignClose(anchor: recoveryAnchor)
        } else if !popoverIsSwitchingAnchor {
            returnActivation(to: endPanelActivationTracking(), after: closeReason)
        }
    }

    /// Remembers the app in front as the panel opens with activation, and
    /// follows it while the panel is shown. The observers live only as long as
    /// the panel: an anchor switch or an in-place reopen keeps them, a real
    /// close ends them.
    private func beginPanelActivationTracking() {
        endPanelActivationTracking()
        let ownPID = NSRunningApplication.current.processIdentifier
        let front = NSWorkspace.shared.frontmostApplication
        // Opened while Hexa was already in front (from Settings, say):
        // there is nothing to hand back when the panel closes.
        panelActivationSource = front?.processIdentifier == ownPID ? nil : front
        let center = NSWorkspace.shared.notificationCenter
        panelActivationObservers = [
            center.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification,
                               object: nil, queue: .main) { [weak self] _ in
                self?.updatePanelActivationSource(.activeSpaceChanged)
            },
            center.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                               object: nil, queue: .main) { [weak self] note in
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey]
                        as? NSRunningApplication else { return }
                self?.updatePanelActivationSource(.appActivated(app))
            },
        ]
    }

    private func updatePanelActivationSource(_ change: PanelActivationChange<NSRunningApplication>) {
        let ownPID = NSRunningApplication.current.processIdentifier
        panelActivationSource = StatusItemAnchorSupport.panelActivationSource(
            after: change, current: panelActivationSource,
            isOwnApp: { $0.processIdentifier == ownPID })
    }

    /// Stops following activation and returns the app remembered last.
    @discardableResult
    private func endPanelActivationTracking() -> NSRunningApplication? {
        let center = NSWorkspace.shared.notificationCenter
        panelActivationObservers.forEach { center.removeObserver($0) }
        panelActivationObservers.removeAll()
        let source = panelActivationSource
        panelActivationSource = nil
        return source
    }

    /// Closing the panel leaves Hexa active, and macOS keeps reporting it
    /// as the frontmost app until something else is focused, which misleads
    /// window managers and anything that follows the active app.
    private func returnActivation(to source: NSRunningApplication?, after closeReason: PanelCloseReason?) {
        guard let source, closeReason?.dismissesWithoutTakeover == true else { return }
        // One turn later, so the close animation has finished and anything the
        // dismissal itself focused has become key.
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.popover.isShown, !source.isTerminated,
                  StatusItemAnchorSupport.shouldReturnActivation(
                      to: source.processIdentifier,
                      ownPID: NSRunningApplication.current.processIdentifier,
                      frontmostPID: NSWorkspace.shared.frontmostApplication?.processIdentifier,
                      ownWindowIsKey: NSApp.keyWindow != nil || NSApp.modalWindow != nil,
                      closeReason: closeReason)
            else { return }
            ActivationHandoff.yield(to: source)
            if !source.activate(from: NSRunningApplication.current, options: []) {
                source.activate(options: [])
            }
        }
    }

    /// What the panel was holding open only for as long as it was on screen.
    private func releasePanelResources() {
        SystemMonitor.shared.setMenuPanelNeeds(.none)
        MenuPanelFocus.shared.clearMetricFocus()
        // Fechou o painel, encerra a demanda e descarta a baseline (DEC-002).
        ProcessUsageService.shared.stopMenuPanelNetworkMonitoring()
        ProcessUsageService.shared.clearCachedRows()
        ResponsibleProcess.clearIconCache()
    }

    /// Preserve the corrected anchor, not just the status item's stale frame.
    /// A recent event targeting this panel is required; a parked pointer is not
    /// evidence that an unrelated system close should be undone.
    private func anchorAfterForeignClose() -> PanelAnchor? {
        guard !isTerminating, !popoverIsSwitchingAnchor,
              let anchor = popoverAnchor, anchor.screen?.isStillAttached == true,
              let button = anchor.button, button.window != nil,
              StatusItemAnchorSupport.shouldReopenPanel(
                  closedByApp: popoverCloseIsAppRequested,
                  lastFrame: popoverLastFrame,
                  panelWindowNumber: popoverLastWindowNumber,
                  event: NSApp.currentEvent,
                  secondsSinceLastReopen: Date().timeIntervalSince(popoverForeignReopenAt))
        else { return nil }
        return anchor
    }

    /// Reuses the anchor within the close callback. If presentation fails or
    /// another close follows immediately, release the resources held for recovery.
    private func reopenPanelAfterForeignClose(anchor: PanelAnchor) {
        popoverForeignReopenAt = Date()
        if let button = anchor.button {
            showPopover(anchor: button, allowRecentClose: true, animate: false, activate: false,
                        restoring: anchor)
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.popoverIsSwitchingAnchor = false
            MenuPanelFocus.shared.setSwitchingMetricAnchor(false)
            if !self.popover.isShown {
                self.releasePanelResources()
                self.endPanelActivationTracking()
            }
        }
    }

    // MARK: - Context menu (right click)

    private func showContextMenu(from button: NSStatusBarButton?) {
        // The panel uses applicationDefined dismissal, so a right-click while it's
        // open won't close it on its own — and the menu would try to open behind it.
        // Close it first so the context menu always appears.
        if popover.isShown {
            closePopover { [weak self] in self?.presentContextMenu(from: button) }
            return
        }

        presentContextMenu(from: button)
    }

    private func presentContextMenu(from button: NSStatusBarButton?) {
        let manager = KeepAwakeManager.shared
        let strings = L10n.shared.s
        let menu = NSMenu()

        if AppFeature.keepAwake.isAvailable {
            let toggleItem = NSMenuItem(title: manager.isActive ? strings.menuDisableAwake : strings.menuEnableAwake,
                                        action: #selector(menuToggleAwake),
                                        keyEquivalent: "")
            toggleItem.target = self
            menu.addItem(toggleItem)
        }

        if AppFeature.keepAwake.isAvailable, !manager.isActive {
            let durationsItem = NSMenuItem(title: strings.menuActivateFor, action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            let options: [(String, Int)] = [(strings.minutes15, 15), (strings.minutes30, 30),
                                            (strings.hour1, 60), (strings.hours2, 120),
                                            (strings.hours4, 240), (strings.hours8, 480),
                                            (strings.indefinitely, 0)]
            for (label, minutes) in options {
                let item = NSMenuItem(title: label, action: #selector(menuActivateDuration(_:)), keyEquivalent: "")
                item.target = self
                item.tag = minutes
                submenu.addItem(item)
            }
            durationsItem.submenu = submenu
            menu.addItem(durationsItem)
        }

        if menu.items.isEmpty == false {
            menu.addItem(.separator())
        }

        let commandCenterItem = NSMenuItem(title: FeatureStrings.menuBarAppearance(L10n.shared.language).tabCommandCenter,
                                           action: #selector(menuOpenCommandCenter), keyEquivalent: "")
        commandCenterItem.target = self
        menu.addItem(commandCenterItem)

        let settingsItem = NSMenuItem(title: strings.menuSettings, action: #selector(menuOpenSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(title: strings.menuAbout, action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        if AppFeature.uninstaller.isAvailable {
            let uninstallItem = NSMenuItem(title: strings.uninstallerMenuItem,
                                           action: #selector(menuOpenUninstaller), keyEquivalent: "")
            uninstallItem.target = self
            menu.addItem(uninstallItem)
        }

        if AppFeature.appUpdates.isAvailable {
            let updatesItem = NSMenuItem(title: strings.menuCheckUpdates, action: #selector(menuCheckUpdates), keyEquivalent: "")
            updatesItem.target = self
            menu.addItem(updatesItem)
        }

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: strings.menuQuit, action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        contextMenuButton = button
        let host = statusController.menuHost(for: button)
        host.menu = menu
        host.button?.performClick(nil)
        DispatchQueue.main.async {
            host.menu = nil
        }
    }

    /// The status item that was clicked to open the context menu. The command
    /// center entry opens the popover from it, so the popover stays reachable
    /// when the main item is hidden. Weak: a removed item must not be retained.
    private weak var contextMenuButton: NSStatusBarButton?

    @objc private func menuOpenCommandCenter() {
        let anchor = contextMenuButton ?? statusController.button
        // Defer so the context menu finishes closing before the popover opens.
        DispatchQueue.main.async { [weak self] in
            self?.showPopover(anchor: anchor)
        }
    }

    @objc private func menuToggleAwake() {
        KeepAwakeManager.shared.toggle()
    }

    @objc private func menuActivateDuration(_ sender: NSMenuItem) {
        KeepAwakeManager.shared.activate(minutes: sender.tag)
    }

    @objc private func menuOpenSettings() {
        openFeatureWorkspace(.general)
    }

    @objc private func menuOpenUninstaller() {
        if AppFeature.uninstaller.isAvailable {
            FeatureWorkspaceWindow.shared.show(.uninstaller)
        } else {
            openFeatureWorkspace(.featureHub)
        }
    }

    @objc private func menuCheckUpdates() {
        if AppFeature.appUpdates.isAvailable {
            openFeatureWorkspace(.appUpdates)
        } else {
            openFeatureWorkspace(.featureHub)
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let credits = NSAttributedString(
            string: L10n.shared.s.aboutDescription,
            attributes: [.font: HexaTheme.manropeFont(size: 11)]
        )
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    // MARK: - Application menu

    /// Builds and installs the standard application menu (App / Edit / Go / Window).
    ///
    /// Because the app runs as an accessory, AppKit never gives it the default main
    /// menu a regular app gets, so `NSApp.mainMenu` stays nil and the standard key
    /// equivalents (which live on menu items) never resolve. That is why nothing
    /// happens for Cmd+H/M/W/Q or Cmd+C/V/X/A inside the Settings window. A minimal
    /// standard menu restores them. The menu bar only appears while one of the
    /// app's own windows is focused; otherwise the app is as invisible as before.
    /// Most items use the responder chain (nil target) so they act on the key
    /// window or the focused text field; About and Settings route to our handlers.
    func installMainMenu() {
        let strings = L10n.shared.s
        let mainMenu = NSMenu()

        // Application menu (the bold, app-named first menu).
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        let about = NSMenuItem(title: strings.menuAbout, action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        appMenu.addItem(about)
        appMenu.addItem(.separator())

        let settings = NSMenuItem(title: strings.menuSettings, action: #selector(menuOpenSettings), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(settings)
        appMenu.addItem(.separator())

        appMenu.addItem(NSMenuItem(title: strings.menuHide,
                                   action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        let hideOthers = NSMenuItem(title: strings.menuHideOthers,
                                    action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(NSMenuItem(title: strings.menuShowAll,
                                   action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: strings.menuQuit,
                                   action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        // Edit menu, so text fields in Settings respond to the editing shortcuts.
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: strings.menuEdit)
        editMenuItem.submenu = editMenu

        editMenu.addItem(NSMenuItem(title: strings.menuUndo, action: Selector(("undo:")), keyEquivalent: "z"))
        let redo = NSMenuItem(title: strings.menuRedo, action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redo)
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: strings.menuCut, action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: strings.menuCopy, action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: strings.menuPaste, action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: strings.menuSelectAll, action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))

        // Window menu (Minimize / Zoom / Close). Settings is .miniaturizable so
        // Cmd+M actually minimizes; AppKit manages enabling once windowsMenu is set.
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: strings.menuWindow)
        windowMenuItem.submenu = windowMenu

        windowMenu.addItem(NSMenuItem(title: strings.menuMinimize,
                                      action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: strings.menuZoom,
                                      action: #selector(NSWindow.performZoom(_:)), keyEquivalent: ""))
        windowMenu.addItem(.separator())
        windowMenu.addItem(NSMenuItem(title: strings.menuClose,
                                      action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }

    // MARK: - Windows

    func openFeatureWorkspace(_ destination: WorkspaceSystemDestination) {
        FeatureWorkspaceWindow.shared.showSettings(destination)
        NotificationCenter.default.post(name: LaunchAtLoginSupport.settingsRefreshRequested, object: nil)
    }

    func openFeatureWorkspace(_ feature: AppFeature, settingsMode: Bool = false) {
        FeatureWorkspaceWindow.shared.show(feature)
        if settingsMode {
            FeatureWorkspaceState.shared.featureSettingsMode = true
        }
        NotificationCenter.default.post(name: LaunchAtLoginSupport.settingsRefreshRequested, object: nil)
    }

    /// Only the first launch of a newer version gets this bounded check. Normal
    /// launches and activations must not disturb an arranged menu bar.
    private func recoverStatusItemAfterUpdate(previousVersion: String?) {
        guard let previousVersion, !AppInfo.isDeveloperBuild,
              let previous = UpdateServiceSupport.SemanticVersion(raw: previousVersion),
              let current = UpdateServiceSupport.SemanticVersion(raw: AppInfo.version), current > previous,
              let item = statusController?.statusItem else { return }
        let screens = NSScreen.screens.map(\.frame)
        guard !screens.isEmpty else { return }
        verifyPostUpdateStatusItem(item, screenFrames: screens,
                                   deadline: Date().addingTimeInterval(30))
    }

    private func verifyPostUpdateStatusItem(_ item: NSStatusItem,
                                            screenFrames: [CGRect],
                                            deadline: Date,
                                            attemptsLeft: Int = 12,
                                            recreated: Bool = false) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.reshowVerifyInterval) { [weak self, weak item] in
            // Reopening or explicitly recovering the app replaces this item,
            // cancelling these callbacks. A sleep, display change or hidden bar
            // is not evidence of failed placement, so those stop the check too.
            guard let self, let item, self.statusController?.statusItem === item,
                  !self.isTerminating, !self.isReshowingStatusItem,
                  !self.popover.isShown, item.menu == nil, item.isVisible,
                  NSEvent.pressedMouseButtons == 0,
                  Date() < deadline,
                  !UserDefaults.standard.bool(forKey: DefaultsKey.menuBarHideIconWithMetrics),
                  NSScreen.screens.map(\.frame) == screenFrames,
                  NSMenu.menuBarVisible(),
                  NSApp.currentSystemPresentationOptions.intersection(
                    [.autoHideMenuBar, .hideMenuBar, .fullScreen]).isEmpty,
                  let session = CGSessionCopyCurrentDictionary() as? [String: Any],
                  SessionActivitySupport.isOnConsole(session),
                  !KeepAwakeAutomationSupport.isScreenLocked(sessionDictionary: session),
                  Self.runningMenuBarManagerName() == nil else { return }
            if self.iconIsOnScreen() {
                self.logStatusItemPlacement("post-update appeared")
                return
            }
            guard attemptsLeft <= 1 else {
                self.verifyPostUpdateStatusItem(item, screenFrames: screenFrames, deadline: deadline,
                                                attemptsLeft: attemptsLeft - 1, recreated: recreated)
                return
            }
            // Preserve the autosave identity and position. The more disruptive
            // reset remains exclusive to the person's explicit recovery action.
            guard !recreated else {
                self.logStatusItemPlacement("post-update still hidden")
                return
            }
            self.logStatusItemPlacement("post-update recreating")
            self.statusController?.recreateStatusItem()
            if let replacement = self.statusController?.statusItem {
                self.verifyPostUpdateStatusItem(replacement, screenFrames: screenFrames,
                                                deadline: deadline, recreated: true)
            }
        }
    }

    /// Rebuilds the menu bar item so the icon reappears when the OS has dropped it
    /// from a crowded or notched menu bar. Backs the "Show menu bar icon" button.
    /// The rebuild can silently lose to a full bar or to a menu bar manager app
    /// stuffing the fresh item into its hidden section, so
    /// after the frame settles this checks the icon really made it on screen
    /// and, if not, says so instead of looking like the button did nothing.
    func reshowStatusItem() {
        // The button is an explicit "I want the icon back": neither hiding
        // option may immediately re-hide what the user just asked to see
        // (and then trip the "still hidden" alert).
        UserDefaults.standard.set(false, forKey: DefaultsKey.menuBarHideIconWithMetrics)
        UserDefaults.standard.set(false, forKey: DefaultsKey.notchHidesMenuBarIcon)
        guard !isReshowingStatusItem else { return }
        isReshowingStatusItem = true
        statusController?.recreateStatusItem()
        verifyIconReappeared(attemptsLeft: Self.reshowVerifyAttempts)
    }

    /// macOS places a rebuilt status item on its own schedule, and a busy bar
    /// can take longer than one look to settle. Judging it once meant a slow
    /// placement read as a failure and the person was told the bar was full
    /// when it was not, so the answer is asked for several times before
    /// anything is said. A newborn item also reports a zero-height frame for
    /// a few seconds; that settling grace is separate from the
    /// "still hidden" countdown so recovery does not burn the arranged spot
    /// while macOS is still placing the window.
    private var isReshowingStatusItem = false
    private static let reshowVerifyAttempts = 6
    private static let reshowSettlingGraceAttempts = 8
    private static let reshowVerifyInterval: TimeInterval = 0.8

    private func verifyIconReappeared(attemptsLeft: Int,
                                      settlingGraceLeft: Int = AppDelegate.reshowSettlingGraceAttempts,
                                      placementWasReset: Bool = false) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.reshowVerifyInterval) { [weak self] in
            guard let self else { return }
            // A later choice to hide the icon cancels the explicit recovery.
            guard !UserDefaults.standard.bool(forKey: DefaultsKey.menuBarHideIconWithMetrics),
                  !MenuBarSpacingSupport.islandHidesStatusIcon(
                    in: .standard, hiddenInFullscreen: self.statusController?.islandHiddenInFullscreen == true) else {
                self.isReshowingStatusItem = false
                return
            }
            if self.iconIsOnScreen() {
                self.isReshowingStatusItem = false
                self.logStatusItemPlacement("appeared")
                return
            }
            if StatusItemPlacementSupport.shouldKeepWaitingForSettlement(
                isOnScreen: false,
                isSettling: self.iconIsSettling(),
                settlingGraceLeft: settlingGraceLeft) {
                self.logStatusItemPlacement("settling")
                self.verifyIconReappeared(attemptsLeft: attemptsLeft,
                                          settlingGraceLeft: settlingGraceLeft - 1,
                                          placementWasReset: placementWasReset)
                return
            }
            guard attemptsLeft <= 1 else {
                self.verifyIconReappeared(attemptsLeft: attemptsLeft - 1,
                                          settlingGraceLeft: settlingGraceLeft,
                                          placementWasReset: placementWasReset)
                return
            }
            // With the app switched off under System Settings > Menu Bar >
            // "Allow in the Menu Bar" (macOS 26), macOS never places the item
            // whatever its identity, so a reset would only burn the arranged
            // spot. Name the switch instead.
            if MenuBarAllowanceSupport.currentAllowance() == .disallowed {
                self.isReshowingStatusItem = false
                self.logStatusItemPlacement("disallowed by system")
                let s = L10n.shared.s
                NSApp.activate(ignoringOtherApps: true)
                let alert = NSAlert()
                alert.messageText = s.menuBarIconStillHiddenTitle
                alert.informativeText = s.menuBarIconDisallowedBody
                alert.runModal()
                return
            }
            // Keeping the arranged spot did not bring the icon back, so the
            // saved position is itself part of what macOS will not show. Start
            // the item over completely and look again before telling anyone
            // there is nothing left to try.
            guard placementWasReset else {
                self.logStatusItemPlacement("resetting placement")
                self.statusController?.resetStatusItemPlacementIdentity()
                self.verifyIconReappeared(attemptsLeft: Self.reshowVerifyAttempts,
                                          settlingGraceLeft: Self.reshowSettlingGraceAttempts,
                                          placementWasReset: true)
                return
            }
            self.isReshowingStatusItem = false
            self.logStatusItemPlacement("still hidden")
            let s = L10n.shared.s
            var body = s.menuBarIconStillHiddenBody
            if let manager = Self.runningMenuBarManagerName() {
                body += "\n\n" + String(format: s.menuBarIconManagerHintFormat, manager, manager)
            }
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = s.menuBarIconStillHiddenTitle
            alert.informativeText = body
            alert.runModal()
        }
    }

    /// Known menu bar organizers, by bundle id; any of them can be holding
    /// the icon in its hidden section, which explains it never reappearing
    /// on this machine. The hint names whichever one is running by its own
    /// localized app name.
    private static let menuBarManagerBundlePrefixes = [
        "com.jordanbaird.Ice",
        "com.surteesstudios.Bartender",
        "com.dwarvesv.minimalbar",
        "com.mortenjust.Dozer",
    ]

    private static func runningMenuBarManagerName() -> String? {
        for app in NSWorkspace.shared.runningApplications {
            guard let bundleID = app.bundleIdentifier else { continue }
            if menuBarManagerBundlePrefixes.contains(where: { bundleID.hasPrefix($0) }) {
                return app.localizedName
            }
        }
        return nil
    }

    /// Quits and reopens the app. Full Disk Access only applies to a fresh
    /// process, so this is how the uninstaller picks up a just-granted grant.
    func relaunchApp() {
        FeatureRuntime.shared.relaunchApp()
    }

    /// Beta updates only introduce their new feature; other update surfaces
    /// retain their own release gates.
    private func presentUpdateIntros() {
        showBrightnessUpdatePromptIfNeeded()
    }

    private func brightnessSetupNeeded() -> Bool {
        let defaults = UserDefaults.standard
        return BrightnessUpdatePromptInfo.needsSetup(
            notchAvailable: AppFeature.notch.isAvailable,
            brightnessAvailable: AppFeature.brightness.isAvailable,
            notchEnabled: defaults.bool(forKey: DefaultsKey.notchEnabled),
            notchBrightness: defaults.bool(forKey: DefaultsKey.notchBrightness),
            brightnessEnabled: defaults.bool(forKey: DefaultsKey.brightnessControlEnabled))
    }

    private func queueBrightnessUpdatePromptIfNeeded(previousVersion: String?) {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: DefaultsKey.brightnessUpdatePromptState) == nil,
              !AppInfo.isDeveloperBuild,
              BrightnessUpdatePromptInfo.isUpgrade(appVersion: AppInfo.version,
                                                   previousVersion: previousVersion) else { return }
        defaults.set(brightnessSetupNeeded() ? BrightnessUpdatePromptInfo.pending : BrightnessUpdatePromptInfo.handled,
                     forKey: DefaultsKey.brightnessUpdatePromptState)
    }

    private func showBrightnessUpdatePromptIfNeeded() {
        let defaults = UserDefaults.standard
        guard !isTerminating,
              defaults.string(forKey: DefaultsKey.brightnessUpdatePromptState)
                == BrightnessUpdatePromptInfo.pending else { return }
        guard brightnessSetupNeeded() else {
            defaults.set(BrightnessUpdatePromptInfo.handled, forKey: DefaultsKey.brightnessUpdatePromptState)
            return
        }
        let language = L10n.shared.language
        let strings = FeatureStrings.brightness(language)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = strings.islandPromptTitle
        alert.informativeText = strings.islandPromptMessage
        alert.addButton(withTitle: L10n.shared.s.menuSettings)
        // The invitation is not repeated, so the other choice says what stays.
        alert.addButton(withTitle: strings.islandPromptKeepOff)
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        defaults.set(BrightnessUpdatePromptInfo.handled, forKey: DefaultsKey.brightnessUpdatePromptState)
        if response == .alertFirstButtonReturn {
            if AppFeature.brightness.isAvailable {
                FeatureWorkspaceWindow.shared.show(.brightness)
            } else {
                openFeatureWorkspace(.featureHub)
            }
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Without this, macOS drops a notice that arrives while the app is
    /// active, which is when a visible surface of the app is up.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
