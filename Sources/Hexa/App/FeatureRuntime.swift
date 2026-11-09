// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import FanControlCore
import AppKit

/// Bridges the pure feature catalog to the live singletons. Every binding is
/// a closure, so merely mentioning a feature never instantiates its service:
/// a service only comes to life when its binding runs, and syncAtLaunch skips
/// unavailable features entirely — switched off in the hub means nothing
/// loads and nothing runs after the next launch. Main thread only, like the
/// services it drives.
final class FeatureRuntime: ObservableObject {
    static let shared = FeatureRuntime()

    /// Bumped on every availability change; views observing the runtime
    /// re-read the catalog when it moves.
    @Published private(set) var revision = 0

    /// Every feature that came to life in THIS process: available at launch
    /// or installed later in the session. A feature uninstalled mid-session
    /// stops working immediately, but its (inert) singleton only leaves
    /// memory on the next launch — this set is what the hub's restart banner
    /// keys off, including the install-then-uninstall-again case.
    private var loadedThisSession = Set(AppFeature.allCases.filter(\.isAvailable))

    /// What was installed when the app came up and has not been installed
    /// again since. A feature installed later in the session, a reinstall
    /// included, has not had its chance yet, so it is never offered for
    /// uninstalling as unused until the next launch.
    private var offerableThisSession = Set(AppFeature.allCases.filter(\.isAvailable))

    private init() {}

    /// True while something that loaded this session is now uninstalled, so
    /// a restart would actually unload it. Features already uninstalled when
    /// the app came up never loaded, so they need no restart.
    var needsRestartToUnload: Bool {
        loadedThisSession.contains { !$0.isAvailable }
    }

    /// Relaunches the app in place: a detached helper waits for this process
    /// to be gone and only then reopens it, so the fresh instance starts
    /// without the uninstalled features.
    ///
    /// It waits for the process rather than for a fixed moment because
    /// quitting flushes the clipboard history and every other pending write
    /// first: a reopen that arrives while the app is still here does nothing,
    /// and the restart ends as a plain quit.
    ///
    /// False when the helper could not start; the app then stays open.
    @discardableResult
    func relaunchApp() -> Bool {
        let path = Bundle.main.bundlePath
        // Its own session: the reopen fires after we terminate, so the child
        // has to outlive the session it was started from. It gives up if we
        // are somehow still here after twenty seconds, so a quit that never
        // happens cannot reopen the app long afterwards.
        let script = """
            waited=0
            while kill -0 "$1" 2>/dev/null && [ "$waited" -lt 100 ]; do
                sleep 0.2
                waited=$((waited + 1))
            done
            kill -0 "$1" 2>/dev/null || /usr/bin/open "$2"
            """
        let pid = String(ProcessInfo.processInfo.processIdentifier)
        // Nothing is quit until the helper is running: without it, terminating
        // would close the app instead of restarting it.
        guard (try? DetachedProcess.spawn(
            "/bin/sh", ["-c", script, "hexa-relaunch", pid, path])) != nil
        else { return false }
        NSApp.terminate(nil)
        return true
    }

    func isAvailable(_ feature: AppFeature) -> Bool { feature.isAvailable }

    var availableCount: Int { AppFeature.allCases.filter(\.isAvailable).count }

    /// How many features this Mac can end up with. Counting against the whole
    /// catalog instead would leave the hub's install-all button forever one
    /// short of its own disabled condition on a Mac missing some hardware.
    /// An install that predates the check still counts, so the tally can
    /// never read more installed than installable.
    var installableCount: Int {
        AppFeature.allCases.filter { $0.isHardwareSupported || $0.isAvailable }.count
    }

    /// The one gate every install passes, whichever surface asks: the hub
    /// row, the hub's install-all button, a preset and the first-run picker
    /// all decide here. A feature the Mac cannot run never installs, so a
    /// disabled row cannot be walked around from the button above it.
    ///
    /// Uninstalls are never refused and an existing install is never revoked:
    /// the check reads hardware and can be wrong, and a wrong answer that
    /// strands someone's settings costs far more than one that leaves a
    /// feature reporting itself unsupported.
    private func mayFlip(_ feature: AppFeature, to available: Bool) -> Bool {
        guard feature.isAvailable != available else { return false }
        return !available || feature.isHardwareSupported
    }

    /// The capture's discard question, the same one the editor window asks on
    /// close. Injectable so the cancel path is verifiable without AppKit.
    var confirmCaptureDiscard: () -> Bool = ScreenshotEditorController.confirmDiscardBeforeQuit

    /// Flipping availability runs each feature's binding immediately, in the
    /// order given: off tears every resource down on the spot, while a first
    /// install turns on the feature's main control. Saved choices survive a
    /// reinstall. One row, the "all" buttons and the Dynamic Island leaving
    /// with its extensions all pass through here, with one revision bump.
    /// Install all leaves enable keys alone: it would otherwise switch on
    /// intrusive features nobody picked, such as focus follows mouse.
    ///
    /// `keepListOnDiscardCancel` belongs to the first-run module line, which
    /// presents a whole group as one switch: cancelling the capture's discard
    /// question keeps that whole list installed instead of uninstalling the
    /// rest of the group. The hub's own capture switch and the batch buttons
    /// keep the default and the behavior they had.
    func setAvailable(_ features: [AppFeature], _ available: Bool,
                      enablingFirstInstalls: Bool = true,
                      keepListOnDiscardCancel: Bool = false) {
        var features = features
        // Uninstalling the capture closes its editors, so unsaved edits get
        // the same discard question as the window's close button. Cancel
        // keeps the capture installed; the bump redraws its switch as on.
        if !available, features.contains(.screenshot), AppFeature.screenshot.isAvailable,
           !confirmCaptureDiscard() {
            features = Self.survivingList(features,
                                          keepListOnDiscardCancel: keepListOnDiscardCancel)
            revision += 1
        }
        var changed = false
        let firstIslandInstall = available && features.contains(.notch)
            && mayFlip(.notch, to: true)
            && !UserDefaults.standard.bool(forKey: DefaultsKey.notchInitialExtensionsInstalled)
        let requested = firstIslandInstall
            ? features + AppFeature.dynamicIslandExtensions.filter { !features.contains($0) }
            : features
        let savedValues = savedPreferences()
        for feature in requested where mayFlip(feature, to: available) {
            if available && enablingFirstInstalls {
                feature.enableOnFirstInstall(in: .standard, savedValues: savedValues)
            }
            UserDefaults.standard.set(available, forKey: feature.availabilityKey)
            if available {
                loadedThisSession.insert(feature)
                offerableThisSession.remove(feature)
            }
            Self.bindings[feature]?()
            changed = true
        }
        if firstIslandInstall && AppFeature.notch.isAvailable {
            UserDefaults.standard.set(true, forKey: DefaultsKey.notchInitialExtensionsInstalled)
        }
        if changed { finishAvailabilityChange() }
    }

    /// The list that survives a cancelled discard question. The hub asks only
    /// about the capture, so the rest of the batch still leaves; the first-run
    /// module line asks about a whole group, and cancelling leaves all of it
    /// installed (D13).
    static func survivingList(_ features: [AppFeature],
                              keepListOnDiscardCancel: Bool) -> [AppFeature] {
        keepListOnDiscardCancel ? [] : features.filter { $0 != .screenshot }
    }

    /// Installed switches that were never once turned on, for the Features
    /// page to offer as one batch, minus the ones the person chose to keep.
    func neverSwitchedOnFeatures() -> [AppFeature] {
        let saved = savedPreferences()
        let kept = Self.keptFeatures()
        return AppFeature.neverSwitchedOn(isAvailable: \.isAvailable,
                                          boolFor: UserDefaults.standard.bool(forKey:),
                                          isSaved: { saved[$0] != nil })
            .filter { offerableThisSession.contains($0) && !kept.contains($0) }
    }

    /// Stops offering these features as unused. A later one that turns out
    /// never used is still offered, on its own merits.
    func keep(_ features: [AppFeature]) {
        let kept = Self.keptFeatures().union(features)
        UserDefaults.standard.set(kept.map(\.rawValue).sorted().joined(separator: ","),
                                  forKey: DefaultsKey.featureHubKeptFeatures)
    }

    private static func keptFeatures() -> Set<AppFeature> {
        Set((UserDefaults.standard.string(forKey: DefaultsKey.featureHubKeptFeatures) ?? "")
            .split(separator: ",")
            .compactMap { AppFeature(rawValue: String($0)) })
    }

    private func savedPreferences() -> [String: Any] {
        guard let domain = Bundle.main.bundleIdentifier else { return [:] }
        return UserDefaults.standard.persistentDomain(forName: domain) ?? [:]
    }

    /// Launch path: replaces the old unconditional sync block. Only available
    /// features get their binding run, so nothing else even instantiates.
    func syncAtLaunch() {
        NotchAccessoryService.shared.onMonitoringStateChanged = { SystemMonitor.shared.setNotchAccessoryMonitoring($0) }
        for feature in AppFeature.allCases where feature.isAvailable {
            Self.bindings[feature]?()
        }
    }

    /// Re-syncs a set of features (used by the permission sinks); skips
    /// unavailable ones so their singletons never come to life.
    func sync(_ features: [AppFeature]) {
        for feature in features where feature.isAvailable {
            Self.bindings[feature]?()
        }
    }

    /// One bump for Settings; the island re-reads its preferences when its
    /// feature set changes.
    private func finishAvailabilityChange() {
        revision += 1
        if AppFeature.notch.isAvailable { NotchService.shared.syncWithPreferences() }
    }

    /// What each feature must re-evaluate when its availability (or a
    /// permission it depends on) changes. Most on-demand tools have no binding;
    /// Media only binds so uninstalling it can cancel work already in flight.
    private static let bindings: [AppFeature: () -> Void] = [
        .mixer: {
            PreciseVolumeRollerService.shared.syncWithPreferences()
            AppVolumeMixer.shared.syncWithPreferences()
        },
        .keepAwake: {
            KeepAwakeManager.shared.syncWithFeatures()
            HotkeyManager.shared.syncWithPreferences()
        },
        .brightness: { BrightnessService.shared.syncWithPreferences() },
        .mediaTools: {
            NotchFileToolsService.shared.syncWithPreferences()
            guard !AppFeature.mediaTools.isAvailable else { return }
            MediaService.shared.cancel()
        },
        .screenshot: {
            ScreenCaptureService.shared.syncWithPreferences()
            ScreenshotService.shared.syncWithPreferences()
            RecentCaptureService.shared.syncWithPreferences()
        },
        .screenOCR: {
            ScreenCaptureService.shared.syncWithPreferences()
            ScreenTextService.shared.syncWithPreferences()
        },
        .notch: { NotchService.shared.syncWithPreferences() },
        .notchGestures: {
            if AppFeature.notch.isAvailable { NotchService.shared.syncWithPreferences() }
        },
        .notchTimer: {
            if AppFeature.notch.isAvailable { NotchService.shared.syncWithPreferences() }
            else { NotchTimerService.shared.stop() }
        },
        .notchAccessories: {
            if AppFeature.notch.isAvailable { NotchService.shared.syncWithPreferences() }
            else { NotchAccessoryService.shared.stop() }
        },
        .notchLyrics: {
            if !NotchLyricsSupport.isEnabled() { NotchLyricsService.shared.stop() }
        },
        .notchQueue: { NotchMusicService.shared.syncQueuePreference() },
        .notchLiveEqualizer: { NotchAudioLevelService.shared.syncWithPreferences() },
        .notchNotifications: {
            if AppFeature.notch.isAvailable { NotchService.shared.syncWithPreferences() }
            else { NotchNotificationService.shared.stop() }
        },
        .notchDownloads: {
            if AppFeature.notch.isAvailable { NotchService.shared.syncWithPreferences() }
            else { NotchDownloadService.shared.stop() }
        },
        .notchCalendar: {
            if AppFeature.notch.isAvailable { NotchService.shared.syncWithPreferences() }
            else { NotchCalendarService.shared.stop() }
        },
        .notchWatch: {
            if AppFeature.notch.isAvailable { NotchService.shared.syncWithPreferences() }
            else { NotchWatchService.shared.stop() }
        },
        .cleaner: { CleanerScheduler.shared.syncWithPreferences() },
        .dockDisplayLock: { DockDisplayLockService.shared.syncWithPreferences() },
        .menuBarHiding: {
            MainActor.assumeIsolated { MenuBarHidingService.shared.syncWithPreferences() }
        },
        .appUpdates: { AppUpdatesService.shared.syncWithPreferences() },
        .monitorCPU: { FeatureRuntime.syncMonitor() },
        .monitorGPU: { FeatureRuntime.syncMonitor() },
        .monitorMemory: { FeatureRuntime.syncMonitor() },
        .monitorNetwork: { FeatureRuntime.syncMonitor() },
        .monitorDisk: { FeatureRuntime.syncMonitor() },
        .monitorPower: { FeatureRuntime.syncMonitor() },
        .fanControl: {
            SystemMonitor.shared.planDidChange()
            let defaults = UserDefaults.standard
            let needsRecovery = defaults.bool(forKey: DefaultsKey.fanControlRecoveryNeeded)
            let hasRegisteredHelper = !(defaults.string(forKey: DefaultsKey.fanControlHelperVersion) ?? "").isEmpty
            if needsRecovery || (!AppFeature.fanControl.isAvailable && hasRegisteredHelper) {
                FanControlService.shared.syncWithPreferences()
            }
        },
    ]

    private static func syncMonitor() {
        SystemMonitor.shared.planDidChange()
    }
}

/// Hardware a feature needs and this Mac may not have. One switch answers
/// both questions, so a feature can never be unsupported without a reason to
/// show for it, and a feature added here can never grey a row silently.
/// It lives beside the runtime rather than in the catalog because the answer
/// comes from a service, and the catalog stays a pure description.
extension AppFeature {
    /// Why this Mac cannot run the feature, ready to show. `nil` when it can,
    /// or when the feature depends on no hardware at all.
    var hardwareUnsupportedReason: String? {
        switch self {
        case .fanControl:
            return FanControlHardware.hasControllableFan
                ? nil : FeatureStrings.fanControl(L10n.shared.language).noFans
        default:
            return nil
        }
    }

    var isHardwareSupported: Bool { hardwareUnsupportedReason == nil }

    /// Why a feature list must refuse to install this feature, ready to show
    /// as a tooltip. `nil` once it is installed: the check reads hardware and
    /// can be wrong, so it is never allowed to strand an existing install
    /// behind a greyed row. Both the hub and the first-run picker read this,
    /// so neither can drift from the gate in `FeatureRuntime`.
    var installBlockedReason: String? {
        isAvailable ? nil : hardwareUnsupportedReason
    }
}
