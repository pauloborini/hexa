// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import ServiceManagement

/// Detaches the app from the system before its bundle goes (DEC-031). It hands
/// the fans back and unregisters their helper daemon, restores normal sleep
/// and removes the closed-lid NOPASSWD rule, gives back the macOS shortcuts it
/// took over, unregisters the login item, moves its caches and data to the
/// Trash and erases its preferences.
///
/// Ajustes > Avançado runs it with the app alive, then moves the bundle to the
/// Trash and quits. `Hexa --uninstall` runs the same cleanup without any of
/// that and leaves the bundle to whoever called it. Either way it must run
/// from the installed bundle, since `SMAppService.mainApp` is scoped to the
/// running app's bundle identifier.
enum Uninstaller {
    /// Set once the in-app removal is past every step that can stop it. The
    /// data and preferences go last, in `applicationWillTerminate`, after every
    /// teardown that still writes them.
    private static var finishesOnTerminate = false

    static func runAndExit() -> Never {
        let shortcuts = restoreShortcuts()
        print(shortcuts
              ? "UNINSTALL: macOS shortcuts given back"
              : "UNINSTALL: some macOS shortcuts are still off")
        // The fan helper is a daemon service of its own, so unregistering the
        // main app as a login item never reaches it. Without this its root
        // registration outlives the bundle that carried its executable.
        let detached = FanControlService.restoreAndUnregisterForRemoval()
        print(detached
              ? "UNINSTALL: fan helper daemon unregistered"
              : "UNINSTALL: fan helper daemon still registered")
        // This runs before `NSApplication.shared` exists, so the password
        // dialog comes from the system on its own.
        let sleepRestored = restoreSleepAndRemoveRule()
        print(sleepRestored
              ? "UNINSTALL: normal sleep restored and closed-lid rule removed"
              : "UNINSTALL: sleep is still disabled or the closed-lid rule is still installed")
        print(unregisterLoginItem()
              ? "UNINSTALL: login item unregistered"
              : "UNINSTALL: login item still registered")
        // A helper or a sleep override left behind is only recoverable through
        // the markers in the preferences, so those stay until both are clean.
        guard detached, sleepRestored else { exit(EXIT_FAILURE) }
        moveDataToTrash()
        erasePreferences()
        print("UNINSTALL: settings erased, caches and data moved to the Trash")
        exit(shortcuts ? EXIT_SUCCESS : EXIT_FAILURE)
    }

    /// Ajustes > Avançado. The steps that can stop the removal run first, off
    /// the main thread (the helper waits up to 20 s for the fans); on a stop the
    /// app stays installed and `onStop` says so. Past them nothing can keep the
    /// app, so it gives the rest back, goes to the Trash and quits.
    static func runFromApp(onStop: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let detached = restoreSleepAndRemoveRule()
                && FanControlService.restoreAndUnregisterForRemoval()
            DispatchQueue.main.async {
                guard detached else {
                    onStop()
                    return
                }
                restoreShortcuts()
                unregisterLoginItem()
                finishesOnTerminate = true
                if (try? FileManager.default.trashItem(at: Bundle.main.bundleURL,
                                                       resultingItemURL: nil)) == nil {
                    let strings = L10n.shared.s
                    let alert = NSAlert()
                    alert.messageText = strings.advancedUninstallFailedTitle
                    alert.informativeText = strings.advancedUninstallTrashFailedBody
                    NSApp.activate(ignoringOtherApps: true)
                    alert.runModal()
                }
                NSApp.terminate(nil)
            }
        }
    }

    /// Last step of `applicationWillTerminate` after an in-app removal.
    static func finishOnTerminateIfNeeded() {
        guard finishesOnTerminate else { return }
        moveDataToTrash()
        erasePreferences()
    }

    /// Lid sleep back on and the closed-lid rule gone, in one administrator
    /// request. Sleep is only touched when this app marked it disabled, so an
    /// override someone set by hand stays theirs. Both are read back: a
    /// dismissed dialog and a refused command look alike from here.
    private static func restoreSleepAndRemoveRule() -> Bool {
        let rulePresent = Sudoers.ruleFilesPresent
        let restoresSleep = DefaultsKey.sleepDisabledValue()
        guard rulePresent || restoresSleep else { return true }
        let strings = L10n.shared.s
        _ = AdminShell.runSync(Sudoers.removalCommand(restoringSleep: restoresSleep),
                           prompt: rulePresent ? strings.adminPromptSudoersRemove
                                               : strings.adminPromptClamshellOff)
        guard !Sudoers.ruleFilesPresent else { return false }
        guard restoresSleep else { return true }
        // An unreadable report is not evidence that the override is gone.
        let report = Shell.run("/usr/bin/pmset", ["-g"])
        return report.status == 0 && !SudoersSupport.sleepDisabled(inPmsetOutput: report.output)
    }

    /// Absorbs an older marker first, then hands every key back.
    @discardableResult
    private static func restoreShortcuts() -> Bool {
        SystemShortcutTakeover.recoverIfNeeded(keeping: [])
        return SystemShortcutTakeover.restoreAll()
    }

    /// Unregistering an item that was never registered throws; the state
    /// read afterwards is the answer.
    @discardableResult
    private static func unregisterLoginItem() -> Bool {
        try? SMAppService.mainApp.unregister()
        return LaunchAtLogin.registration == .off
    }

    /// To the Trash rather than deleted: Application Support holds the
    /// person's own material, and the Trash keeps it recoverable.
    private static func moveDataToTrash() {
        guard let bundleID = Bundle.main.bundleIdentifier,
              let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
        else { return }
        for path in ["Caches/\(bundleID)",
                     "Application Support/\(bundleID)",
                     "HTTPStorages/\(bundleID)",
                     "Saved Application State/\(bundleID).savedState"] {
            let url = library.appendingPathComponent(path, isDirectory: true)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }
    }

    private static func erasePreferences() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        UserDefaults.standard.removePersistentDomain(forName: bundleID)
        UserDefaults.standard.synchronize()
    }
}
