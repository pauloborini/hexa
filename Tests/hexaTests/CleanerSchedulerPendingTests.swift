// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Pins the arming decision for a due automatic pass that was left pending
/// because no surface was visible at its slot. Pure: fixed dates, a fixed
/// calendar, no timer, no `UserDefaults`, no scan.
final class CleanerSchedulerPendingTests: XCTestCase {
    private typealias Arming = CleanerSchedule.Arming

    /// Fixed offset (no DST) so the fixtures read the same on every machine.
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: -3 * 3600) ?? .gmt
        return calendar
    }()

    /// 2026-03-10 is a Tuesday (weekday 3 in the Gregorian convention).
    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: day,
                                           hour: hour, minute: minute)) ?? .distantPast
    }

    private func arming(now: Date,
                        lastRun: Date?,
                        frequency: CleanerSchedule.Frequency = .daily,
                        weekday: Int = 3,
                        hasVisibleSurface: Bool) -> Arming {
        CleanerSchedule.arming(now: now, lastRun: lastRun, frequency: frequency,
                               hour: 9, minute: 0, weekday: weekday,
                               hasVisibleSurface: hasVisibleSurface,
                               calendar: calendar)
    }

    func testScheduleOffArmsNothing() {
        XCTAssertEqual(arming(now: date(10, 8), lastRun: date(8, 9), frequency: .off,
                              hasVisibleSurface: true), .nothing)
    }

    /// Last run two days ago, schedule at 09:00, surface opens at 08:00:
    /// the missed 09:00 of the 9th is pending, so the catch-up is 08:02.
    func testPendingDayWithVisibleSurfaceArmsCatchUpIn120Seconds() {
        let now = date(10, 8)
        XCTAssertEqual(arming(now: now, lastRun: date(8, 9), hasVisibleSurface: true),
                       .catchUp(date(10, 8, 2)))
        XCTAssertEqual(CleanerSchedule.catchUpDelay, 120)
    }

    /// Same pending day, but no surface: no catch-up, the regular next slot.
    func testPendingDayWithoutSurfaceArmsOnlyTheRegularSlot() {
        XCTAssertEqual(arming(now: date(10, 8), lastRun: date(8, 9), hasVisibleSurface: false),
                       .slot(date(10, 9)))
    }

    /// ISSUE-073: the pass ran at the 08:02 catch-up. Opening a surface later
    /// that day must arm tomorrow's 09:00, never another 09:00 today.
    func testNoPendingRunAfterTheDaysPassSameDay() {
        let stamped = date(10, 8, 2)
        XCTAssertEqual(arming(now: stamped.addingTimeInterval(30), lastRun: stamped,
                              hasVisibleSurface: true),
                       .slot(date(11, 9)))
        XCTAssertEqual(arming(now: date(10, 8, 30), lastRun: stamped,
                              hasVisibleSurface: true),
                       .slot(date(11, 9)))
    }

    /// Stamped yesterday at 09:00 with the next slot still ahead today: that
    /// slot is not missed, so there is no catch-up.
    func testSlotNotYetDueArmsTodaysSlotWithoutCatchUp() {
        XCTAssertEqual(arming(now: date(10, 8), lastRun: date(9, 9), hasVisibleSurface: true),
                       .slot(date(10, 9)))
    }

    /// A schedule that never ran starts counting from now: no catch-up.
    func testNeverRunArmsRegularSlotWithoutCatchUp() {
        XCTAssertEqual(arming(now: date(10, 8), lastRun: nil, hasVisibleSurface: true),
                       .slot(date(10, 9)))
    }

    /// Weekly on Tuesdays at 09:00. Last run was the Tuesday 3rd at 09:05, so
    /// the Tuesday 10th 09:00 is missed and the catch-up runs at 10:02.
    func testWeeklyPendingDayArmsCatchUp() {
        XCTAssertEqual(arming(now: date(10, 10), lastRun: date(3, 9, 5), frequency: .weekly,
                              weekday: 3, hasVisibleSurface: true),
                       .catchUp(date(10, 10, 2)))
    }

    /// The day after a stamped pass fires at the next slot, and the helper
    /// returns a date strictly after the stamped day.
    func testNextDayAfterTheStampedDay() {
        XCTAssertEqual(CleanerSchedule.nextFireDate(afterDayContaining: date(10, 8, 2),
                                                    frequency: .daily, hour: 9, minute: 0,
                                                    weekday: 3, calendar: calendar),
                       date(11, 9))
    }
}
