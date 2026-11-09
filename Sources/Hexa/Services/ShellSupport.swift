// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import CoreServices
import Darwin

enum Shell {
    /// A command that stops answering must not keep a thread forever. Nothing
    /// here asks a question that is worth more than a few seconds, and a tool
    /// waiting on a damaged disk or a share that went away can wait for good.
    static let defaultTimeout: TimeInterval = 5

    @discardableResult
    static func run(_ path: String,
                    _ args: [String],
                    timeout: TimeInterval = defaultTimeout,
                    maxOutputBytes: Int = 4 * 1024 * 1024)
        -> (status: Int32, output: String) {
        let result = BoundedProcessRunner.run(path, args,
                                              timeout: timeout,
                                              maxOutputBytes: maxOutputBytes)
        return (result.status, String(decoding: result.output, as: UTF8.self))
    }
}

/// Runs a command with administrator privileges (system password prompt).
enum AdminShell {
    // Hexa is a menu-bar agent (LSUIElement), so it is rarely the active
    // app. SecurityAgent attaches its password dialog to the requesting process;
    // when that process is an inactive agent the dialog can open behind the
    // frontmost app and read as "no prompt appeared". Bringing the app forward
    // first — exactly what onboarding and the Dock Preview intro already do for
    // their own windows — makes the dialog surface in focus.
    //
    // `prompting` serializes the request: a second one while a dialog is already
    // up returns false instead of stacking another SecurityAgent dialog (what a
    // frustrated retry used to do, and what was linked to system
    // instability). Every caller already treats false as "permission not granted".
    private static let promptLock = NSLock()
    private static var prompting = false

    private enum RequestOrigin {
        case systemScript
        case signedApp
    }

    /// Result of an administrator request that ran through the system script.
    /// `cancelled` is the dismissed dialog, which is not a failure to report.
    enum Outcome: Equatable {
        case granted, cancelled, failed
    }

    static func runSync(_ command: String, prompt: String) -> Bool {
        runSync(command, prompt: prompt, origin: .systemScript)
    }

    /// Claims the single prompt slot. False while another dialog is up.
    private static func beginPrompt() -> Bool {
        promptLock.lock()
        defer { promptLock.unlock() }
        guard !prompting else { return false }
        prompting = true
        return true
    }

    private static func endPrompt() {
        promptLock.lock()
        prompting = false
        promptLock.unlock()
    }

    private static func runSync(_ command: String, prompt: String, origin: RequestOrigin) -> Bool {
        guard beginPrompt() else { return false }
        defer { endPrompt() }

        bringAppToFront()
        let source = appleScriptSource(command: command, prompt: prompt)
        switch origin {
        case .systemScript:
            // A person typing a password is not a stuck command. Keep the
            // established bound without rushing a prompt that is being read.
            return Shell.run("/usr/bin/osascript", ["-e", source], timeout: 600).status == 0
        case .signedApp:
            // NSAppleScript is main-thread-only. The updater's elevated shell
            // detaches immediately after approval, so this wait covers only the
            // system authorization interaction.
            return DispatchQueue.main.sync {
                AppleScriptRunner.run(source).ok
            }
        }
    }

    /// Same request as `runSync` on the system script path, but reports why it
    /// did not grant. A request that finds a dialog already up is `.failed`:
    /// a busy prompt is not a cancellation by the user.
    static func runSyncOutcome(_ command: String, prompt: String) -> Outcome {
        guard beginPrompt() else { return .failed }
        defer { endPrompt() }

        bringAppToFront()
        let source = appleScriptSource(command: command, prompt: prompt)
        // osascript writes its error text to stderr, and Shell.run merges it into
        // the output, so "(-128)" is visible here next to the exit status.
        let result = Shell.run("/usr/bin/osascript", ["-e", source], timeout: 600)
        return outcome(status: result.status, output: result.output)
    }

    /// Classifies a finished system script request. Only the exact code
    /// "(-128)" means the user dismissed the dialog, so "(-1280)" and other
    /// errors stay failures.
    static func outcome(status: Int32, output: String) -> Outcome {
        if status == 0 { return .granted }
        if output.contains("(-128)") { return .cancelled }
        return .failed
    }

    static func run(_ command: String, prompt: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            completion(runSync(command, prompt: prompt))
        }
    }

    /// Runs the administrator request inside this signed process so system
    /// policy can identify the app that initiated it. Reserved for the updater;
    /// other administrative tools retain their bounded subprocess behavior.
    static func runInProcess(_ command: String, prompt: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            completion(runSync(command, prompt: prompt, origin: .signedApp))
        }
    }

    /// Brings the app forward so the administrator dialog opens in focus. Safe
    /// from any thread: hops to the main thread when it is not already on it.
    /// `Hexa --uninstall` asks before `NSApplication` exists; the system
    /// dialog then opens on its own, with nothing of ours to bring forward.
    private static func bringAppToFront() {
        guard NSApp != nil else { return }
        if Thread.isMainThread {
            NSApp.activate(ignoringOtherApps: true)
        } else {
            DispatchQueue.main.sync {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        Thread.sleep(forTimeInterval: 0.12)
    }

    static func appleScriptSource(command: String, prompt: String) -> String {
        "do shell script \(appleScriptString(command)) with administrator privileges with prompt \(appleScriptString(prompt))"
    }

    private static func appleScriptString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }
}

/// NOPASSWD rule restricted to `pmset disablesleep 0/1`, so closed-lid mode can
/// toggle without asking for the administrator password every time.
/// The password is asked once, when installing the rule. The rule also grants
/// its own removal, so the end of the mode does not ask again.
enum Sudoers {
    static let rulePath = "/etc/sudoers.d/hexa-clamshell"
    // Rule files written under earlier names; removed whenever the rule is
    // (re)installed or removed, so the closed-lid permission migrates without an
    // extra password prompt.
    static let legacyRulePaths = [
        "/etc/sudoers.d/hexa-utils-clamshell",
    ]

    /// Serializes native writes and read/reapply probes. Authorization runs
    /// separately with probes suspended, so a probe cannot resurrect a stale
    /// "1" after a restore cleared it and leave lid sleep off without a marker.
    private static let sleepStateQueue = DispatchQueue(label: "com.hexa.utils.pmset-state")
    // Authorization runs outside this queue so quitting never waits for a
    // password prompt. Probes must not reapply a stale state during that off.
    private static var sleepStateProbeSuspensions = 0

    /// Proves the passwordless path by running it: re-applying the current
    /// SleepDisabled state through `sudo -n` changes nothing on the system and
    /// exercises the exact call the feature makes. Listing checks (`sudo -l`)
    /// reported the rule as ready on Macs where the real call still asked for
    /// a password, which put every toggle behind a prompt.
    static func isConfigured() -> Bool {
        sleepStateQueue.sync {
            guard sleepStateProbeSuspensions == 0 else { return false }
            let report = Shell.run("/usr/bin/pmset", ["-g"])
            guard report.status == 0 else { return false }
            return pmsetDisableSleepOnQueue(SudoersSupport.sleepDisabled(inPmsetOutput: report.output))
        }
    }

    /// Whether any rule file (current or legacy name) is visible on disk.
    /// Uninstall offers the removal prompt from this instead of `isConfigured`,
    /// so a rule that stopped working still gets cleaned up.
    static var ruleFilesPresent: Bool {
        ([rulePath] + legacyRulePaths).contains { FileManager.default.fileExists(atPath: $0) }
    }

    static func install(completion: @escaping (Bool) -> Void) {
        // Granted by uid, not username: a short name is free-form text on
        // SSO-enrolled Macs (name@company.com) and the old validation
        // rejected it before the password prompt could even appear.
        let rule = SudoersSupport.clamshellRule(uid: getuid())
        // Clear any earlier-named rule first, then write and validate the new one
        // (a failed check rolls back). Same password prompt either way.
        let legacy = legacyRulePaths.joined(separator: " ")
        let command = "mkdir -p /etc/sudoers.d && chmod 0755 /etc/sudoers.d && rm -f \(legacy) && echo '\(rule)' > \(rulePath) && chmod 0440 \(rulePath) && /usr/sbin/visudo -c -f \(rulePath) || { rm -f \(rulePath); exit 1; }"
        AdminShell.run(command, prompt: L10n.shared.s.adminPromptSudoersInstall) { ok in
            completion(ok && isConfigured())
        }
    }

    /// Takes the rule away through the grant the rule itself carries: the
    /// exact `rm` the rule authorizes, run with `sudo -n`. No prompt: the end
    /// of the mode and the quit never wait for a password again. A rule that
    /// was never installed (or one written before the grant existed) fails
    /// silently, leaving nothing behind.
    @discardableResult
    static func selfRemove() -> Bool {
        sleepStateQueue.sync { selfRemoveOnQueue() }
    }

    /// The same removal, queued: the caller does not wait for the native call.
    static func selfRemove(completion: @escaping (Bool) -> Void) {
        sleepStateQueue.async {
            completion(selfRemoveOnQueue())
        }
    }

    private static func selfRemoveOnQueue() -> Bool {
        Shell.run("/usr/bin/sudo", ["-n"] + SudoersSupport.selfRemoveArguments()).status == 0
    }

    /// The app's removal in one administrator request: lid sleep back on when
    /// the app turned it off, then every rule file gone. A failed restore keeps
    /// the rule, so a later attempt can still clear the override.
    static func removalCommand(restoringSleep: Bool) -> String {
        let remove = "rm -f \(([rulePath] + legacyRulePaths).joined(separator: " "))"
        return restoringSleep ? "/usr/bin/pmset disablesleep 0 && \(remove)" : remove
    }

    /// Toggles sleep through the password-free path. Fails silently
    /// (returns false) when the rule is not installed.
    @discardableResult
    static func pmsetDisableSleep(_ on: Bool) -> Bool {
        sleepStateQueue.sync { pmsetDisableSleepOnQueue(on) }
    }

    /// Queues asynchronous writes directly in request order. Completions
    /// must not wait for the main thread or for administrator authorization.
    static func pmsetDisableSleep(_ on: Bool, completion: @escaping (Bool) -> Void) {
        sleepStateQueue.async {
            completion(pmsetDisableSleepOnQueue(on))
        }
    }

    /// Completes earlier probes before authorization can restore sleep and
    /// suspends later probes until it finishes. The queue remains free for a
    /// silent restore during quit; the main-thread guard cancels stale prompts.
    static func restoreSleepWithAuthorization(prompt: String,
                                              shouldProceed: @escaping () -> Bool,
                                              completion: @escaping (Bool) -> Void) {
        sleepStateQueue.async {
            sleepStateProbeSuspensions += 1
            let finish: (Bool) -> Void = { ok in
                sleepStateQueue.async {
                    sleepStateProbeSuspensions -= 1
                    completion(ok)
                }
            }
            // A failed enable may never have set the override. Once probes
            // are suspended, a confirmed off needs no further authorization.
            let report = Shell.run("/usr/bin/pmset", ["-g"])
            if report.status == 0, !SudoersSupport.sleepDisabled(inPmsetOutput: report.output) {
                finish(true)
                return
            }
            DispatchQueue.main.async {
                guard shouldProceed() else {
                    finish(false)
                    return
                }
                AdminShell.run("/usr/bin/pmset disablesleep 0", prompt: prompt, completion: finish)
            }
        }
    }

    private static func pmsetDisableSleepOnQueue(_ on: Bool) -> Bool {
        Shell.run("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "disablesleep", on ? "1" : "0"]).status == 0
    }
}

/// Sends Apple Events to another app IN-PROCESS (via NSAppleScript) instead of
/// spawning `osascript`. The Automation consent is then attributed to THIS app —
/// so it stays granted across updates, is re-requested if it was lost, and the
/// first-run consent prompt is never killed by a watchdog. It is the same
/// per-target Automation permission the features already required; nothing new is
/// requested. Call these OFF the main thread, so a slow target never blocks the
/// UI or the event taps (the calls block their thread until the target replies).
enum AppleScriptRunner {
    /// True when this app may script `bundleID`. Undetermined → shows the system
    /// prompt (attributed to this app); granted → returns at once; denied →
    /// false without nagging.
    @discardableResult
    static func consentToAutomate(bundleID: String) -> Bool {
        var target = AEAddressDesc()
        let created = bundleID.withCString { ptr in
            AECreateDesc(typeApplicationBundleID, ptr, bundleID.utf8.count, &target)
        }
        guard created == noErr else { return false }
        defer { AEDisposeDesc(&target) }
        return AEDeterminePermissionToAutomateTarget(&target, typeWildCard, typeWildCard, true) == noErr
    }

    /// Runs the AppleScript in this process. Returns whether it succeeded and the
    /// result string (or the error message on failure). Sending the event in
    /// process itself triggers the Automation prompt when consent is undetermined.
    @discardableResult
    static func run(_ source: String, timeout: TimeInterval? = nil) -> (ok: Bool, output: String) {
        let result = runDetailed(source, timeout: timeout)
        return (result.ok, result.ok ? result.output : result.message)
    }

    /// Same as `run`, keeping the AppleScript error number so callers can tell
    /// a declined Automation consent (-1743/-1744) apart from a real failure.
    /// A nil `timeout` keeps AppleScript's own limit for each Apple Event; a
    /// set one bounds every Apple Event the script sends (`with timeout`), and
    /// an event that gets no reply in time returns `timeoutMessage`. The script
    /// itself gives up, so the call returns only once nothing is left running.
    @discardableResult
    static func runDetailed(_ source: String, timeout: TimeInterval? = nil) -> (ok: Bool, errorNumber: Int?, message: String, output: String) {
        let result = execute(timeout.map { timedSource(source, timeout: $0) } ?? source)
        if timeout != nil, result.errorNumber == timeoutErrorNumber {
            return (false, result.errorNumber, timeoutMessage, "")
        }
        return result
    }

    /// The message returned when a timed AppleScript call does not finish in time.
    static let timeoutMessage = "timeout"

    /// `errAETimeout`: an Apple Event got no reply within its `with timeout` limit.
    static let timeoutErrorNumber = -1712

    /// Wraps `source` so each Apple Event it sends waits at most `timeout`,
    /// rounded up to whole seconds and never below one.
    static func timedSource(_ source: String, timeout: TimeInterval) -> String {
        "with timeout of \(max(1, Int(timeout.rounded(.up)))) seconds\n\(source)\nend timeout"
    }

    /// Two `NSAppleScript` executions at once in the process can abort it
    /// ("Run loop nesting count is negative"), so every compile and run goes
    /// through this lock. Recursive, so a nested run on the same thread does
    /// not deadlock.
    private static let executionLock = NSRecursiveLock()

    private static func execute(_ source: String) -> (ok: Bool, errorNumber: Int?, message: String, output: String) {
        executionLock.lock()
        defer { executionLock.unlock() }
        guard let script = NSAppleScript(source: source) else { return (false, nil, "", "") }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            return (false,
                    error[NSAppleScript.errorNumber] as? Int,
                    (error[NSAppleScript.errorMessage] as? String) ?? "",
                    "")
        }
        return (true, nil, "", result.stringValue ?? "")
    }

    /// Escapes a value for embedding inside an AppleScript double-quoted string.
    static func literal(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }
}
