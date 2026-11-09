// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Foundation

/// When the automatic cleanup runs. Pure calendar math, kept away from the
/// timer so the tests can pin every boundary.
enum CleanerSchedule {
    enum Frequency: String, CaseIterable, Identifiable {
        case off, daily, weekly

        var id: String { rawValue }

        static func sanitized(_ raw: String) -> Frequency {
            Frequency(rawValue: raw) ?? .off
        }
    }

    /// The next moment the cleanup should fire strictly after `date`.
    /// Weekly runs use `weekday` (1 = Sunday … 7 = Saturday, calendar
    /// convention); daily runs ignore it. Off never fires.
    static func nextFireDate(after date: Date,
                             frequency: Frequency,
                             hour: Int,
                             minute: Int,
                             weekday: Int,
                             calendar: Calendar = .current) -> Date? {
        var components = DateComponents()
        components.hour = min(max(hour, 0), 23)
        components.minute = min(max(minute, 0), 59)
        switch frequency {
        case .off:
            return nil
        case .daily:
            break
        case .weekly:
            components.weekday = min(max(weekday, 1), 7)
        }
        return calendar.nextDate(after: date, matching: components,
                                 matchingPolicy: .nextTime)
    }

    /// Twelve hour clock conversions for the schedule pickers, pinned by
    /// tests because midnight and noon trip everyone up.
    static func hour24(hour12: Int, isPM: Bool) -> Int {
        let clamped = min(max(hour12, 1), 12)
        return (clamped % 12) + (isPM ? 12 : 0)
    }

    static func hour12Components(fromHour24 hour: Int) -> (hour12: Int, isPM: Bool) {
        let clamped = min(max(hour, 0), 23)
        let hour12 = clamped % 12 == 0 ? 12 : clamped % 12
        return (hour12, clamped >= 12)
    }

    /// Whether a scheduled run was missed while the Mac was off or asleep:
    /// the fire that followed the last run is already in the past.
    static func missedRun(now: Date,
                          lastRun: Date?,
                          frequency: Frequency,
                          hour: Int,
                          minute: Int,
                          weekday: Int,
                          calendar: Calendar = .current) -> Bool {
        guard frequency != .off else { return false }
        // Never ran before: the schedule starts counting from now, without
        // a surprise catch up clean on the very first enable.
        guard let lastRun else { return false }
        guard let due = nextFireDate(after: lastRun, frequency: frequency,
                                     hour: hour, minute: minute,
                                     weekday: weekday, calendar: calendar) else { return false }
        return due <= now
    }

    /// Delay of the run that catches up a due day left pending because no
    /// surface was visible at its slot.
    static let catchUpDelay: TimeInterval = 120

    /// How long an automatic pass may hold the Cleaner gate, scan and clean
    /// together, before it is ended. Long enough for a large disk, short enough
    /// that a scan which never returns cannot block manual work for good.
    static let automaticPassTimeout: TimeInterval = 20 * 60

    /// What the scheduler arms next. `catchUp` is the short run for a pending
    /// day, `slot` is the next regular fire, `nothing` arms no timer.
    enum Arming: Equatable {
        case catchUp(Date)
        case slot(Date)
        case nothing
    }

    /// The scheduler's arming decision, pure so the tests can pin it. A pass
    /// already stamped today arms the day after. A missed slot arms the
    /// catch-up only while a surface is visible; otherwise it arms the next
    /// regular slot.
    static func arming(now: Date,
                       lastRun: Date?,
                       frequency: Frequency,
                       hour: Int,
                       minute: Int,
                       weekday: Int,
                       hasVisibleSurface: Bool,
                       calendar: Calendar = .current) -> Arming {
        guard frequency != .off else { return .nothing }
        if let lastRun, calendar.isDate(lastRun, inSameDayAs: now) {
            guard let next = nextFireDate(afterDayContaining: now, frequency: frequency,
                                          hour: hour, minute: minute,
                                          weekday: weekday, calendar: calendar) else { return .nothing }
            return .slot(next)
        }
        if hasVisibleSurface,
           missedRun(now: now, lastRun: lastRun, frequency: frequency,
                     hour: hour, minute: minute, weekday: weekday, calendar: calendar) {
            return .catchUp(now.addingTimeInterval(catchUpDelay))
        }
        guard let next = nextFireDate(after: now, frequency: frequency,
                                      hour: hour, minute: minute,
                                      weekday: weekday, calendar: calendar) else { return .nothing }
        return .slot(next)
    }

    /// The first fire on the day after the one containing `date`.
    static func nextFireDate(afterDayContaining date: Date,
                             frequency: Frequency,
                             hour: Int,
                             minute: Int,
                             weekday: Int,
                             calendar: Calendar = .current) -> Date? {
        guard let nextDay = calendar.date(byAdding: .day, value: 1,
                                          to: calendar.startOfDay(for: date)) else { return nil }
        return nextFireDate(after: nextDay.addingTimeInterval(-1), frequency: frequency,
                            hour: hour, minute: minute,
                            weekday: weekday, calendar: calendar)
    }
}
