// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import ApplicationServices
import Combine
import CoreBluetooth
import CoreGraphics
import EventKit
import os.log
import UserNotifications

/// As superfícies visíveis que pedem sondagem de permissão. A contagem é o que
/// decide se existe cadência de sondagem; o conjunto é dono do balanço entre a
/// superfície que aparece e a que sai, e por isso vive aqui, verificável sem
/// instanciar a central.
struct PermissionSurfaceDemands {
    private(set) var ids: Set<UUID> = []

    mutating func set(_ id: UUID, visible: Bool) {
        if visible {
            ids.insert(id)
        } else {
            ids.remove(id)
        }
    }

    var count: Int { ids.count }
}

/// Central place to check, request and watch the TCC permissions the app uses.
/// Accessibility powers the scroll inverter and the switcher's event tap;
/// Screen Recording powers window titles and thumbnails in the switcher.
final class Permissions: ObservableObject {
    static let shared = Permissions()

    /// Uma distribuição incompleta degrada sem chamar APIs que podem abortar via TCC.
    static func hasUsageDescription(_ key: String) -> Bool {
        guard let purpose = Bundle.main.infoDictionary?[key] as? String else { return false }
        return !purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @Published private(set) var accessibility = false
    @Published private(set) var screenRecording = false
    /// Optional — only used to make the uninstaller's scan more thorough by
    /// reaching protected locations. There is no API prompt for it; the user
    /// grants it in System Settings.
    @Published private(set) var fullDiskAccess = false
    /// Refreshed inside refresh() only (launch and activation); notifications
    /// have no cheap poll and the portal calls refresh() when it appears.
    @Published private(set) var notifications: NotificationPermissionState = .unknown
    @Published private(set) var calendarAccess = EKEventStore.authorizationStatus(for: .event)
    @Published private(set) var requestingCalendar = false
    @Published private(set) var calendarRequestFailed = false
    private var calendarPermissionResolution: TimeInterval?

    var keepsCalendarPrompt: Bool {
        NotchSupport.keepsPermissionSurface(requesting: requestingCalendar,
                                            resolvedAt: calendarPermissionResolution,
                                            now: ProcessInfo.processInfo.systemUptime)
    }
    /// Bluetooth reads the battery of connected accessories (Monitor > Power
    /// and the island's accessory alerts). Readers wait for a grant; only
    /// `requestBluetooth()` shows the system prompt.
    @Published private(set) var bluetooth: BluetoothPermissionState = .unknown
    private var bluetoothRequest: BluetoothPermissionRequest?

    enum NotificationPermissionState {
        case granted, denied, undetermined, unknown
    }

    enum BluetoothPermissionState {
        case granted, denied, undetermined, unknown
    }

    private var activePermissionTimer: Timer?
    private var activationObserver: NSObjectProtocol?
    private var defaultsObserver: NSObjectProtocol?
    private var permissionSurfaceDemands = PermissionSurfaceDemands()
    private var currentPollInterval: TimeInterval?

    private init() {
        refresh()
        // Watch Accessibility and Screen Recording only while a running
        // feature or visible permission surface can use the result. One-shot
        // tools refresh when invoked, so their mere availability must not keep
        // a timer alive in the background.
        // Full Disk Access is deliberately NOT polled here: probing it touches
        // protected paths, so polling it would just be repeated denied accesses
        // for no gain. It is read at launch, on activation and when the portal
        // shows, and only while a feature that uses it is installed.
        scheduleActivePermissionPolling()
        // Re-check everything the instant the user returns from System Settings
        // (e.g. after relaunching for Full Disk Access), so the state reflects
        // immediately instead of waiting for the next poll.
        activationObserver = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification,
                                                                    object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
            self?.scheduleActivePermissionPolling()
        }
        defaultsObserver = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification,
                                                                  object: nil, queue: .main) { [weak self] _ in
            self?.scheduleActivePermissionPolling()
        }
    }

    deinit {
        activePermissionTimer?.invalidate()
        if let activationObserver { NotificationCenter.default.removeObserver(activationObserver) }
        if let defaultsObserver { NotificationCenter.default.removeObserver(defaultsObserver) }
    }

    private var desiredPollInterval: TimeInterval? {
        let accessibilityIsNeeded = AppFeature.activeFeatures(using: .accessibility)
            .contains { $0.monitorsPermissionChanges }
        let screenRecordingIsNeeded = AppFeature.activeFeatures(using: .screenRecording)
            .contains { $0.monitorsPermissionChanges }
        return PermissionPollingSupport.interval(
            visibleSurfaceCount: permissionSurfaceDemands.count,
            accessibilityIsNeeded: accessibilityIsNeeded,
            screenRecordingIsNeeded: screenRecordingIsNeeded,
            accessibilityIsGranted: accessibility,
            screenRecordingIsGranted: screenRecording)
    }

    private func scheduleActivePermissionPolling() {
        let interval = desiredPollInterval
        guard interval != currentPollInterval else { return }
        currentPollInterval = interval
        activePermissionTimer?.invalidate()
        activePermissionTimer = nil
        guard let interval else { return }
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.refreshActivePermissions()
        }
        timer.tolerance = interval * 0.4
        RunLoop.main.add(timer, forMode: .common)
        activePermissionTimer = timer
    }

    /// Visible permission UI owns a stable demand identifier so repeated
    /// SwiftUI appearances cannot accidentally leave an unbalanced timer.
    func setActivePermissionSurface(_ id: UUID, visible: Bool) {
        permissionSurfaceDemands.set(id, visible: visible)
        if visible {
            refreshActivePermissions()
        }
        scheduleActivePermissionPolling()
    }

    /// Full refresh including Full Disk Access. Runs at launch and on activation.
    func refresh() {
        refreshActivePermissions()
        refreshNotificationPermission()
        calendarAccess = EKEventStore.authorizationStatus(for: .event)
        refreshBluetoothPermission()
        // Only the Cleaner and the Uninstaller read protected folders. With
        // neither installed nothing shows the answer, and asking would still
        // knock on private folders at every activation.
        guard AppFeature.cleaner.isAvailable || AppFeature.uninstaller.isAvailable else { return }
        // Checking Full Disk Access means asking the system about protected
        // folders, and every refused answer costs time. Doing that where the
        // app is starting up holds back the menu bar icon, so it moves off
        // and reports back.
        DispatchQueue.global(qos: .utility).async {
            let granted = Self.probeFullDiskAccess()
            DispatchQueue.main.async {
                if self.fullDiskAccess != granted { self.fullDiskAccess = granted }
            }
        }
    }

    private func refreshBluetoothPermission() {
        let state: BluetoothPermissionState
        switch CBManager.authorization {
        case .allowedAlways: state = .granted
        case .denied, .restricted: state = .denied
        case .notDetermined: state = .undetermined
        @unknown default: state = .unknown
        }
        DispatchQueue.main.async {
            if self.bluetooth != state { self.bluetooth = state }
        }
    }

    private func refreshNotificationPermission() {
        // Asking the system for the notification centre ends the process
        // outright when it cannot resolve this app, which is what happens
        // when the bundle is replaced or moved out from under a running copy.
        // An update does exactly that, so reporting nothing beats dying.
        guard Bundle.main.bundleIdentifier != nil,
              FileManager.default.fileExists(atPath: Bundle.main.bundlePath) else {
            if notifications != .unknown { notifications = .unknown }
            return
        }
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let state: NotificationPermissionState
            switch settings.authorizationStatus {
            case .authorized, .provisional: state = .granted
            case .denied: state = .denied
            case .notDetermined: state = .undetermined
            @unknown default: state = .unknown
            }
            DispatchQueue.main.async {
                if self?.notifications != state { self?.notifications = state }
            }
        }
    }

    /// Shows the system notification prompt. The answer lands in `notifications`
    /// from the request's own completion, so the surface that asked reads the
    /// truth without waiting for the next activation.
    func requestNotifications() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] _, error in
            // A denied prompt is the user's call; a request that ERRORS means
            // notifications silently cannot work at all, so it leaves a trace.
            if let error {
                Self.notificationLog.error("notification authorization failed: \(error.localizedDescription, privacy: .public)")
            }
            self?.refreshNotificationPermission()
        }
    }

    private static let notificationLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "hexa",
                                                category: "notifications")

    /// Accessibility and Screen Recording only — free, side-effect-free checks
    /// suitable for frequent polling. On the main thread the answer is
    /// published before returning, so a one-shot tool that refreshes right
    /// before its guard decides on what the system says now, not on a value
    /// left over from before a grant made while the app sat in the background.
    func refreshActivePermissions() {
        let ax = AXIsProcessTrusted()
        let sr = CGPreflightScreenCaptureAccess()
        guard !Thread.isMainThread else {
            if accessibility != ax { accessibility = ax }
            if screenRecording != sr { screenRecording = sr }
            scheduleActivePermissionPolling()
            return
        }
        DispatchQueue.main.async {
            if self.accessibility != ax { self.accessibility = ax }
            if self.screenRecording != sr { self.screenRecording = sr }
            // A flip can change which cadence applies (e.g. the last grant
            // landed while the app was in the background).
            self.scheduleActivePermissionPolling()
        }
    }

    /// Protected directories safe to use both as access probes and as
    /// registration attempts. Request-only paths stay separate because every
    /// entry here must remain a reliable signal that access was granted.
    private static let fdaGatedDirectories = [
        "Library/Safari",
        "Library/Mail",
        "Library/Messages",
        "Library/Cookies",
        "Library/Suggestions",
        "Library/Application Support/MobileSync",
    ]

    /// Detects Full Disk Access without a prompt. Reading the TCC database is the
    /// classic signal, but that file is absent on some macOS versions (so a
    /// missing file would read as "no access" forever, even once granted). The
    /// dependable fallback is to list a protected directory that exists: that
    /// listing is denied without Full Disk Access and succeeds with it.
    private static func probeFullDiskAccess() -> Bool {
        let home = NSHomeDirectory()
        let fm = FileManager.default

        // Preferred when present: the TCC database is readable only with access.
        let tccDB = (home as NSString)
            .appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db")
        if let handle = FileHandle(forReadingAtPath: tccDB) {
            let ok = (try? handle.read(upToCount: 1)) != nil
            try? handle.close()
            if ok { return true }
        }

        // Works on every version: each of these is gated by Full Disk Access, so
        // a successful listing (even of an empty directory) means it is granted.
        // Seeing that a folder exists needs no access, so only the first one
        // present is listed: one answer is the whole signal, and the others
        // stay untouched.
        let signal = fdaGatedDirectories
            .map { (home as NSString).appendingPathComponent($0) }
            .first { fm.fileExists(atPath: $0) }
        guard let signal else { return false }
        return (try? fm.contentsOfDirectory(atPath: signal)) != nil
    }

    /// Shows the system Accessibility prompt (once per TCC reset) and floats
    /// the little guide card for the System Settings round trip.
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        refreshActivePermissions()
        if !accessibility {
            PermissionGuideOverlay.shared.show(for: .accessibility)
        }
    }

    /// Shows the system Screen Recording prompt (once per TCC reset) and
    /// floats the guide card, like the Accessibility path. Without the usage
    /// description the system would end the process, so the prompt is skipped
    /// and the card is not floated for a prompt that cannot be shown.
    func requestScreenRecording() {
        guard Self.hasUsageDescription("NSScreenCaptureUsageDescription") else {
            refreshActivePermissions()
            return
        }
        CGRequestScreenCaptureAccess()
        refreshActivePermissions()
        if !screenRecording {
            PermissionGuideOverlay.shared.show(for: .screenRecording)
        }
    }

    /// Drops this app's entry from the list and asks again. The entry macOS
    /// keeps is bound to the app's code signature, so a copy signed
    /// differently (a local build, an update signed another way) finds the
    /// switch on and the permission gone; nothing short of removing the entry
    /// makes the system ask afresh. `tccutil` does that for the calling
    /// user's own entries with no privilege, and is the command Apple
    /// documents for the purpose.
    func startOver(_ kind: PermissionKind) {
        guard kind == .accessibility || kind == .screenRecording,
              let bundleID = Bundle.main.bundleIdentifier else { return }
        let service = kind == .accessibility ? "Accessibility" : "ScreenCapture"
        // Off the main thread through the bounded runner, like
        // `SelfUninstall.resetTCC`: a stuck tccutil must not hang the UI. The
        // hop back also lets the button's click finish before the card that
        // holds the button is rebuilt by the new request.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            _ = Shell.run("/usr/bin/tccutil", ["reset", service, bundleID])
            DispatchQueue.main.async {
                guard let self else { return }
                self.refreshActivePermissions()
                if kind == .accessibility { self.requestAccessibility() } else { self.requestScreenRecording() }
            }
        }
    }

    func openAccessibilitySettings() {
        open(pane: "Privacy_Accessibility")
    }

    func openScreenRecordingSettings() {
        open(pane: "Privacy_ScreenCapture")
    }

    func openFullDiskAccessSettings() {
        open(pane: "Privacy_AllFiles")
    }

    func openFilesAndFoldersSettings() {
        open(pane: "Privacy_FilesAndFolders")
    }

    /// Full Disk Access has no prompt API, and an app only shows up (toggled
    /// off) in its System Settings list once it has attempted to read a
    /// protected location. Touch likely protected paths to register the app,
    /// then open the pane after a short delay so tccd has recorded the denial
    /// before System Settings reads the list. If it still does not appear, the
    /// user can add the app with the list's "+" button.
    func requestFullDiskAccess() {
        if !fullDiskAccess {
            PermissionGuideOverlay.shared.show(for: .fullDiskAccess)
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let home = NSHomeDirectory()
            let fm = FileManager.default
            // The TCC database is the classic trigger when present. Some macOS
            // versions omit it, so the protected directories below are the
            // fallback registration attempts.
            let tccDB = (home as NSString)
                .appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db")
            _ = try? Data(contentsOf: URL(fileURLWithPath: tccDB), options: .mappedIfSafe)
            if let handle = FileHandle(forReadingAtPath: tccDB) {
                _ = try? handle.read(upToCount: 1)
                try? handle.close()
            }
            // Protected locations, harmless when absent. The TCC directory is
            // useful for registration but is not part of the access probe.
            let dirs = (["Library/Application Support/com.apple.TCC"] + Self.fdaGatedDirectories)
                .map { (home as NSString).appendingPathComponent($0) }
            for path in dirs { _ = try? fm.contentsOfDirectory(atPath: path) }

            // Let tccd persist the denial before the pane loads its list.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                self.openFullDiskAccessSettings()
            }
        }
    }

    /// Reading calendar events requires full access even though the app never writes them.
    func requestCalendar() {
        guard !requestingCalendar else { return }
        guard Self.hasUsageDescription("NSCalendarsFullAccessUsageDescription") else {
            calendarRequestFailed = true
            return
        }
        requestingCalendar = true
        calendarRequestFailed = false
        let store = EKEventStore()
        store.requestFullAccessToEvents { [weak self, store] _, error in
            _ = store
            DispatchQueue.main.async {
                self?.calendarPermissionResolution = ProcessInfo.processInfo.systemUptime
                self?.requestingCalendar = false
                let status = EKEventStore.authorizationStatus(for: .event)
                self?.calendarRequestFailed = NotchCalendarSupport.requestFailed(status: status, hasError: error != nil)
                self?.calendarAccess = status
            }
        }
    }

    func openCalendarSettings() {
        open(pane: "Privacy_Calendars")
    }

    /// Shows the Bluetooth prompt, for a control the user just used. The
    /// accessory readers pick the grant up on their next reading.
    func requestBluetooth() {
        guard Self.hasUsageDescription("NSBluetoothAlwaysUsageDescription"),
              CBManager.authorization == .notDetermined, bluetoothRequest == nil else { return }
        bluetoothRequest = BluetoothPermissionRequest { [weak self] in
            self?.bluetoothRequest = nil
            self?.refreshBluetoothPermission()
        }
    }

    func openBluetoothSettings() {
        open(pane: "Privacy_Bluetooth")
    }

    func openNotificationSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!
        NSWorkspace.shared.open(url)
    }

    func openAutomationSettings() {
        open(pane: "Privacy_Automation")
    }

    func openAudioCaptureSettings() {
        open(pane: "Privacy_AudioCapture")
    }

    func openAppManagementSettings() {
        let pane = URL(string:
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AppBundles")!
        if NSWorkspace.shared.open(pane) { return }

        // A general Privacy & Security page is still useful if a future macOS
        // version stops accepting the pane identifier.
        let fallback = URL(string: "x-apple.systempreferences:com.apple.preference.security")!
        NSWorkspace.shared.open(fallback)
    }

    private func open(pane: String) {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Automation (Apple Events)

    enum AutomationTarget: String, CaseIterable {
        case finder = "com.apple.finder"
        case terminal = "com.apple.Terminal"
    }

    enum AutomationStatus {
        case granted, denied, undetermined, notDeterminable
    }

    /// Never prompts (askUserIfNeeded false). A target that is not running
    /// cannot be checked and reads as notDeterminable. Call off the main
    /// thread; the check can block briefly.
    static func automationStatus(for target: AutomationTarget) -> AutomationStatus {
        var descriptor = AEAddressDesc()
        let bundleID = target.rawValue
        let created = bundleID.withCString { pointer in
            AECreateDesc(typeApplicationBundleID, pointer, bundleID.utf8.count, &descriptor)
        }
        guard created == noErr else { return .notDeterminable }
        defer { AEDisposeDesc(&descriptor) }
        switch AEDeterminePermissionToAutomateTarget(&descriptor, typeWildCard, typeWildCard, false) {
        case noErr: return .granted
        case OSStatus(errAEEventNotPermitted): return .denied
        case OSStatus(errAEEventWouldRequireUserConsent): return .undetermined
        default: return .notDeterminable
        }
    }
}

/// Creating a central manager is what asks macOS for Bluetooth. This one
/// exists only for that question and goes away once it is answered.
private final class BluetoothPermissionRequest: NSObject, CBCentralManagerDelegate {
    private var central: CBCentralManager?
    private let answered: () -> Void

    init(answered: @escaping () -> Void) {
        self.answered = answered
        super.init()
        central = CBCentralManager(delegate: self, queue: .main,
                                   options: [CBCentralManagerOptionShowPowerAlertKey: false])
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard CBManager.authorization != .notDetermined else { return }
        self.central = nil
        answered()
    }
}
