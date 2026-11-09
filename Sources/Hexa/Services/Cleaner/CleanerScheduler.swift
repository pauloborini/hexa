// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import Combine

/// Runs the safe part of the cleanup on a schedule the user picked: daily or
/// weekly at a chosen time. Only ever cleans what a manual scan would start
/// with already checked (the safe groups), everything still goes to the
/// Trash, and an optional notification reports the outcome. Nothing exists
/// while the schedule is off: no timer, no observers, no cost.
final class CleanerScheduler: ObservableObject {
    static let shared = CleanerScheduler()

    /// Runs the automatic passes on its own cleaner, so an unattended pass
    /// never writes to the instance the Cleaner view observes. The Cleaner-wide
    /// gate keeps it and the view's pass from running at once.
    let engine = JunkCleaner(passHolder: .automatic)

    /// When the next automatic pass fires; the interface shows this line so
    /// arming the schedule gives visible confirmation on the spot. It mirrors
    /// the armed timer and is nil while no timer is armed.
    @Published private(set) var nextFire: Date?
    /// When a manual review first held back the due pass; nil while nothing
    /// is held back. The interface says the run is postponed.
    @Published private(set) var postponedSince: Date?
    /// The end of a day whose held back pass was given up at the day's turn.
    /// Arming counts that day as spent; no run is recorded for it.
    private var gaveUpThrough: Date?

    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var clockObservers: [NSObjectProtocol] = []
    private var runObserver: AnyCancellable?
    /// One-shot deadline of the automatic pass in progress; nil between passes.
    private var passDeadline: Timer?
    private(set) var visibleSurfaceCount = 0

    private init() {}

    func setSurfaceVisible(_ visible: Bool) {
        if visible {
            visibleSurfaceCount += 1
            // The first surface after none: a due day left pending runs now,
            // through the catch-up that scheduleNext() decides.
            if visibleSurfaceCount == 1, AppFeature.cleaner.isAvailable,
               settings.frequency != .off {
                scheduleNext()
            }
        } else {
            visibleSurfaceCount = max(0, visibleSurfaceCount - 1)
        }
    }

    /// True when there is an active/visible surface demand in the app.
    var hasVisibleSurface: Bool {
        if visibleSurfaceCount > 0 { return true }
        guard let app = NSApp else { return false }
        return app.windows.contains { window in
            window.isVisible && !window.isMiniaturized && window.canBecomeKey
        }
    }

    func syncWithPreferences() {
        let frequency = CleanerSchedule.Frequency.sanitized(
            UserDefaults.standard.string(forKey: DefaultsKey.cleanerScheduleFrequency) ?? "off")
        guard AppFeature.cleaner.isAvailable, frequency != .off else {
            stop()
            return
        }
        installWakeObserver()
        scheduleNext()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        wakeObserver = nil
        for observer in clockObservers { NotificationCenter.default.removeObserver(observer) }
        clockObservers = []
        if postponedSince != nil { postponedSince = nil }
        // A pass still running is discarded with the schedule, so it cannot keep the gate.
        discardRunningPass()
        if nextFire != nil { nextFire = nil }
    }

    private func installWakeObserver() {
        guard wakeObserver == nil else { return }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main) { [weak self] _ in
            // A fire date that passed during sleep never triggers its timer;
            // recomputing catches the miss within a couple of minutes.
            self?.scheduleNext()
        }
        // The chosen time means the user's wall clock: when the time zone
        // or the system clock changes, the armed fire date is stale and the
        // schedule recomputes against the new local time.
        clockObservers = [NSNotification.Name.NSSystemTimeZoneDidChange,
                          NSNotification.Name.NSSystemClockDidChange].map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil,
                                                   queue: .main) { [weak self] _ in
                self?.scheduleNext()
            }
        }
    }

    private var settings: (frequency: CleanerSchedule.Frequency, hour: Int, minute: Int, weekday: Int) {
        let defaults = UserDefaults.standard
        return (CleanerSchedule.Frequency.sanitized(
                    defaults.string(forKey: DefaultsKey.cleanerScheduleFrequency) ?? "off"),
                defaults.integer(forKey: DefaultsKey.cleanerScheduleHour),
                defaults.integer(forKey: DefaultsKey.cleanerScheduleMinute),
                defaults.integer(forKey: DefaultsKey.cleanerScheduleWeekday))
    }

    private func scheduleNext() {
        let current = settings
        let defaults = UserDefaults.standard
        let lastRunStamp = defaults.double(forKey: DefaultsKey.cleanerLastAutoRun)
        let stamped = lastRunStamp > 0 ? Date(timeIntervalSince1970: lastRunStamp) : nil
        let lastRun = [stamped, gaveUpThrough].compactMap { $0 }.max()

        // A due day missed while no surface was visible is pending: the
        // catch-up is armed only here, and only when a surface is visible.
        switch CleanerSchedule.arming(now: Date(), lastRun: lastRun,
                                      frequency: current.frequency,
                                      hour: current.hour, minute: current.minute,
                                      weekday: current.weekday,
                                      hasVisibleSurface: hasVisibleSurface) {
        case let .catchUp(fireDate), let .slot(fireDate):
            schedule(at: fireDate)
        case .nothing:
            return
        }
    }

    private func schedule(at fireDate: Date) {
        timer?.invalidate()
        let timer = Timer(fire: fireDate, interval: 0, repeats: false) { [weak self] _ in
            self?.runAutomaticCleanup()
        }
        // Tight tolerance: one shot a day costs nothing, and a schedule that
        // fires a minute late reads as broken to anyone testing it.
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        if nextFire != fireDate { nextFire = fireDate }
    }

    /// One automatic pass: scan, clean exactly what the scan pre checked
    /// (the safe groups), record the outcome, leave the tool idle again.
    private func runAutomaticCleanup() {
        guard hasVisibleSurface else {
            // DEC-002: "nem scans de updates ou Cleaner em fundo"
            // Autonomous scans/cleanups must not run in background without visible surfaces.
            // The due day stays pending: no timer, no stamp, no scan. The next
            // surface opening runs it through the catch-up in scheduleNext().
            // nextFire is cleared instead of showing the next slot, because no
            // timer is armed to move it once that slot passes.
            timer = nil
            if nextFire != nil { nextFire = nil }
            return
        }

        let current = settings
        let defaults = UserDefaults.standard
        let lastRunStamp = defaults.double(forKey: DefaultsKey.cleanerLastAutoRun)
        if lastRunStamp > 0,
           Calendar.current.isDate(Date(timeIntervalSince1970: lastRunStamp), inSameDayAs: Date()) {
            if let next = CleanerSchedule.nextFireDate(afterDayContaining: Date(),
                                                       frequency: current.frequency,
                                                       hour: current.hour, minute: current.minute,
                                                       weekday: current.weekday) {
                schedule(at: next)
            } else {
                stop()
            }
            return
        }

        // A finished manual session holds nothing: its gate is released.
        let manualPhase = JunkCleaner.shared.phase
        let manualIsDone: Bool
        if case .done = manualPhase { manualIsDone = true } else { manualIsDone = false }
        guard manualPhase == .idle || manualIsDone, runObserver == nil else {
            // The user is in the middle of a manual session: their review
            // wins. Try again in ten minutes, until the day turns; then that
            // day is given up and the next slot is armed.
            let since = postponedSince ?? Date()
            if Calendar.current.isDate(since, inSameDayAs: Date()) {
                if postponedSince == nil { postponedSince = since }
                schedule(at: Date().addingTimeInterval(600))
            } else {
                postponedSince = nil
                gaveUpThrough = Calendar.current.startOfDay(for: Date()).addingTimeInterval(-1)
                scheduleNext()
            }
            return
        }
        if postponedSince != nil { postponedSince = nil }
        // The Cleaner-wide gate: a pass of the other kind that still holds it
        // makes this one wait the same ten minutes.
        guard CleanerPassGate.shared.acquire(.automatic) else {
            schedule(at: Date().addingTimeInterval(600))
            return
        }

        // dropFirst: a published property replays its CURRENT value (.idle)
        // to every new subscriber, and that echo must not be read as "the
        // user interrupted the pass" before the pass even started.
        runObserver = engine.$phase
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] phase in
                // A delivery queued before the pass ended must not act on a pass that is gone.
                guard let self, self.runObserver != nil else { return }
                switch phase {
                case .results:
                    // The scan pre checks exactly the safe groups; an
                    // automatic run takes that selection as is.
                    if self.engine.selectedCount > 0 {
                        self.engine.cleanSelected(escalate: false)
                    } else {
                        self.finishRun(movedToTrash: 0, failed: 0)
                    }
                case let .done(movedToTrash, _, failed):
                    // An automatic pass only runs recommended rows, and the Trash
                    // row is never recommended, so nothing here is freed for good.
                    self.finishRun(movedToTrash: movedToTrash, failed: failed)
                case .idle:
                    // Safety net. The engine returns to idle only through
                    // reset(), and endAutomaticRun() detaches this observer
                    // before it calls reset(). The day's stamp is already written,
                    // so scheduleNext() arms the next slot and does not retry the pass.
                    self.endAutomaticRun()
                    self.scheduleNext()
                default:
                    break
                }
            }
        // An interrupted scan still consumes today's automatic attempt, including after restart.
        defaults.set(Date().timeIntervalSince1970, forKey: DefaultsKey.cleanerLastAutoRun)
        // The fired timer is spent. While the pass runs only its one-shot
        // deadline is armed, so the published time must not keep the instant
        // that just fired.
        timer = nil
        if nextFire != nil { nextFire = nil }
        armPassDeadline()
        engine.scan(attended: false)
    }

    /// Arms the one-shot deadline of the pass that just started. It fires
    /// once, and every other way out of the pass disarms it first.
    private func armPassDeadline() {
        passDeadline?.invalidate()
        let deadline = Timer(fire: Date().addingTimeInterval(CleanerSchedule.automaticPassTimeout),
                             interval: 0, repeats: false) { [weak self] _ in
            self?.abortAutomaticRun()
        }
        RunLoop.main.add(deadline, forMode: .common)
        passDeadline = deadline
    }

    /// Detaches the pass from its engine and disarms its deadline. The engine
    /// then resets, which cancels the work still in flight and frees the gate.
    private func endAutomaticRun() {
        runObserver = nil
        passDeadline?.invalidate()
        passDeadline = nil
        engine.reset()
    }

    /// Ends the automatic pass before it finishes: the deadline expired, or
    /// the user chose Abort all. The user is told it was interrupted, and
    /// today's attempt stays spent. A pass whose clean has already ended keeps
    /// its own finish, which records the real figures.
    func abortAutomaticRun() {
        guard runObserver != nil else { return }
        if case .done = engine.phase { return }
        discardRunningPass()
        notifyInterrupted()
        scheduleNext()
    }

    /// Ends the running pass with no result. Its stats record nothing, so the
    /// last-run line never shows the figures of an earlier run.
    private func discardRunningPass() {
        guard runObserver != nil else { return }
        endAutomaticRun()
        let defaults = UserDefaults.standard
        defaults.set(0, forKey: DefaultsKey.cleanerLastAutoMovedToTrash)
        defaults.set(0, forKey: DefaultsKey.cleanerLastAutoFailed)
    }

    private func finishRun(movedToTrash: Int64, failed: Int) {
        let skipped = engine.skippedBrowsers
        endAutomaticRun()
        let defaults = UserDefaults.standard
        defaults.set(movedToTrash, forKey: DefaultsKey.cleanerLastAutoMovedToTrash)
        defaults.set(failed, forKey: DefaultsKey.cleanerLastAutoFailed)
        notifyIfWanted(movedToTrash: movedToTrash, failed: failed, skippedBrowsers: skipped)
        scheduleNext()
    }

    /// Pure composition of notification sentences reporting the automatic cleanup outcome.
    static func formatNotificationBody(
        movedToTrash: Int64,
        failed: Int,
        skippedBrowsers: [String],
        strings: Strings
    ) -> [String] {
        var sentences: [String] = []
        if movedToTrash > 0 {
            sentences.append(String(format: strings.cleanerAutoNotificationFormat,
                                    ByteCountFormatter.string(fromByteCount: movedToTrash, countStyle: .file)))
        }
        if !skippedBrowsers.isEmpty {
            sentences.append(strings.cleanerNotificationSkippedBrowsersFormat)
        }
        if failed > 0 {
            sentences.append(strings.uninstallerSomeFailed)
        }
        if sentences.isEmpty {
            sentences.append(strings.cleanerNothingFound)
        }
        return sentences
    }

    /// Reports the outcome when the user asked to be told, through the
    /// app's regular notifier (which drops the note quietly if macOS
    /// notifications are not allowed). Even a run that found nothing posts,
    /// so a fresh schedule gives proof of life on its first pass.
    private func notifyIfWanted(movedToTrash: Int64, failed: Int, skippedBrowsers: [String] = []) {
        guard UserDefaults.standard.bool(forKey: DefaultsKey.cleanerScheduleNotify) else { return }
        let strings = L10n.shared.s
        let sentences = Self.formatNotificationBody(
            movedToTrash: movedToTrash,
            failed: failed,
            skippedBrowsers: skippedBrowsers,
            strings: strings
        )
        Notifier.post(title: strings.cleanerScheduleTitle, body: sentences.joined(separator: " "))
    }

    /// Says that the pass ended before it finished, under the same toggle as
    /// the outcome note.
    private func notifyInterrupted() {
        guard UserDefaults.standard.bool(forKey: DefaultsKey.cleanerScheduleNotify) else { return }
        let strings = L10n.shared.s
        Notifier.post(title: strings.cleanerScheduleTitle, body: strings.cleanerAutoInterrupted)
    }
}
