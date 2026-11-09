// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import NotchPlaybackCore
import XCTest

@testable import Hexa

/// Pins the pure routing and behaviour contract of the Dynamic Island
/// (`NotchSupport`): which events the island may route (each event's own
/// preference, the feature behind it and the module list), when a notice may
/// replace the one being read, when the open island closes, and the volume
/// key steps. Pure unit: every case builds its scenario in a throwaway
/// UserDefaults suite removed in teardown, never in the user's own
/// preferences, and nothing schedules background work or needs the app.
final class NotchRoutingBehaviorTests: XCTestCase {
    /// One fixed domain for the class. removePersistentDomain empties it but
    /// keeps its .plist in ~/Library/Preferences, so a name per scenario would
    /// pile up files on every run.
    private let suiteName = "hexaTests.notch-routing"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    /// A clean domain per scenario, so one event's keys never leak into the
    /// next one's assertion.
    private func freshDefaults() -> UserDefaults {
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    /// The island on, plus every dependency the event leans on besides its
    /// own preference key.
    private func turnOnDependencies(of event: NotchEvent, in defaults: UserDefaults) {
        defaults.set(true, forKey: AppFeature.notch.availabilityKey)
        defaults.set(true, forKey: DefaultsKey.notchEnabled)
        switch event {
        case .volume: defaults.set(true, forKey: AppFeature.mixer.availabilityKey)
        case .brightness:
            defaults.set(true, forKey: AppFeature.brightness.availabilityKey)
            defaults.set(true, forKey: DefaultsKey.brightnessControlEnabled)
        case .keyboardLight: defaults.set(true, forKey: AppFeature.brightness.availabilityKey)
        case .battery: defaults.set(true, forKey: AppFeature.monitorPower.availabilityKey)
        case .capture: defaults.set(true, forKey: AppFeature.screenshot.availabilityKey)
        case .systemNotification: defaults.set(true, forKey: AppFeature.notchNotifications.availabilityKey)
        case .timer: defaults.set(true, forKey: AppFeature.notchTimer.availabilityKey)
        case .watch: defaults.set(true, forKey: AppFeature.notchWatch.availabilityKey)
        case .accessory:
            defaults.set(true, forKey: AppFeature.notchAccessories.availabilityKey)
            defaults.set(true, forKey: AppFeature.monitorPower.availabilityKey)
        case .download: defaults.set(true, forKey: AppFeature.notchDownloads.availabilityKey)
        case .track: break // The music module is always available.
        }
    }

    // MARK: Routes

    func testRoutesEnabledForEveryEvent() {
        for event in NotchEvent.allCases {
            let defaults = freshDefaults()
            turnOnDependencies(of: event, in: defaults)
            defaults.set(true, forKey: event.preferenceKey)
            XCTAssertTrue(NotchSupport.routes(event, in: defaults),
                          "\(event) must route when the island, its preference and its feature are on")
        }
    }

    func testRoutesBlockedWhenTheEventPreferenceIsOff() {
        for event in NotchEvent.allCases {
            let defaults = freshDefaults()
            turnOnDependencies(of: event, in: defaults)
            XCTAssertFalse(NotchSupport.routes(event, in: defaults),
                           "\(event) must not route when its own preference is off")
        }
    }

    func testRoutesBlockedWhenTheFeatureBehindTheEventIsOff() {
        for event in NotchEvent.allCases {
            let defaults = freshDefaults()
            turnOnDependencies(of: event, in: defaults)
            defaults.set(true, forKey: event.preferenceKey)
            switch event {
            case .volume: defaults.set(false, forKey: AppFeature.mixer.availabilityKey)
            case .brightness, .keyboardLight:
                defaults.set(false, forKey: AppFeature.brightness.availabilityKey)
            case .battery: defaults.set(false, forKey: AppFeature.monitorPower.availabilityKey)
            case .capture:
                // The captures module survives via OCR; the route itself
                // still belongs to the screenshot feature.
                defaults.set(false, forKey: AppFeature.screenshot.availabilityKey)
                defaults.set(true, forKey: AppFeature.screenOCR.availabilityKey)
            case .systemNotification:
                defaults.set(false, forKey: AppFeature.notchNotifications.availabilityKey)
            case .timer: defaults.set(false, forKey: AppFeature.notchTimer.availabilityKey)
            case .watch: defaults.set(false, forKey: AppFeature.notchWatch.availabilityKey)
            case .accessory: defaults.set(false, forKey: AppFeature.notchAccessories.availabilityKey)
            case .download: defaults.set(false, forKey: AppFeature.notchDownloads.availabilityKey)
            case .track:
                // No feature to switch off: hiding the module is the block.
                defaults.set("music", forKey: DefaultsKey.notchHiddenModules)
            }
            XCTAssertFalse(NotchSupport.routes(event, in: defaults),
                           "\(event) must not route while the feature behind it is off")
        }
    }

    func testRoutesBlockedWhileTheIslandItselfIsOff() {
        // The island's own switch gates every event: its feature being
        // uninstalled or its enable key turned off.
        for key in [AppFeature.notch.availabilityKey, DefaultsKey.notchEnabled] {
            for event in NotchEvent.allCases {
                let defaults = freshDefaults()
                turnOnDependencies(of: event, in: defaults)
                defaults.set(true, forKey: event.preferenceKey)
                defaults.set(false, forKey: key)
                XCTAssertFalse(NotchSupport.routes(event, in: defaults),
                               "\(event) must not route while \(key) is off")
            }
        }
    }

    func testBrightnessRouteRequiresTheControlEnabledSetting() {
        let defaults = freshDefaults()
        turnOnDependencies(of: .brightness, in: defaults)
        defaults.set(true, forKey: NotchEvent.brightness.preferenceKey)
        // The brightness feature can be on while its control is off; the
        // island only routes once the control itself is enabled.
        defaults.set(false, forKey: DefaultsKey.brightnessControlEnabled)
        XCTAssertFalse(NotchSupport.routes(.brightness, in: defaults))
        defaults.set(true, forKey: DefaultsKey.brightnessControlEnabled)
        XCTAssertTrue(NotchSupport.routes(.brightness, in: defaults))
    }

    // MARK: Module list

    func testControlsCannotBeHiddenFromModules() {
        let defaults = freshDefaults()
        defaults.set(true, forKey: AppFeature.notch.availabilityKey)
        defaults.set(true, forKey: DefaultsKey.notchEnabled)
        defaults.set(true, forKey: AppFeature.notchCalendar.availabilityKey)
        defaults.set(true, forKey: DefaultsKey.notchCalendarEnabled)
        XCTAssertTrue(NotchSupport.modules(in: defaults).contains(.calendar),
                      "the calendar starts visible, so hiding it is what the test measures")
        defaults.set("controls,calendar", forKey: DefaultsKey.notchHiddenModules)
        let modules = NotchSupport.modules(in: defaults)
        // Controles is the island's default interface (DEC-006), so a stored
        // hidden entry for it is ignored (DEC-039).
        XCTAssertTrue(modules.contains(.controls))
        XCTAssertFalse(modules.contains(.calendar))
    }

    // MARK: Notice replacement

    func testShouldReplaceAcceptsAnythingWhenNothingIsShowing() {
        XCTAssertTrue(NotchSupport.shouldReplace(nil, with: .volume))
        XCTAssertTrue(NotchSupport.shouldReplace(nil, with: .track, held: true))
    }

    func testShouldReplaceFollowsPriorityWhileUnheld() {
        // Equal priority takes its turn; a lower one waits.
        XCTAssertTrue(NotchSupport.shouldReplace(.volume, with: .brightness))
        XCTAssertFalse(NotchSupport.shouldReplace(.volume, with: .track))
        XCTAssertTrue(NotchSupport.shouldReplace(.track, with: .volume))
    }

    func testHeldNoticeOnlyYieldsToItsOwnKindOrHigherPriority() {
        XCTAssertTrue(NotchSupport.shouldReplace(.volume, with: .volume, held: true))
        // Same priority, another kind: the notice being read keeps its place.
        XCTAssertFalse(NotchSupport.shouldReplace(.volume, with: .brightness, held: true))
        XCTAssertTrue(NotchSupport.shouldReplace(.battery, with: .volume, held: true))
        XCTAssertFalse(NotchSupport.shouldReplace(.volume, with: .battery, held: true))
    }

    // MARK: Closing the open island

    func testClosesOnPointerExit() {
        // A peek always yields the pointer's place back.
        XCTAssertTrue(NotchSupport.closesOnPointerExit(expanded: false, peeking: true, openedByHover: false))
        XCTAssertTrue(NotchSupport.closesOnPointerExit(expanded: false, peeking: true, openedByHover: true))
        XCTAssertTrue(NotchSupport.closesOnPointerExit(expanded: true, peeking: true, openedByHover: false))
        XCTAssertTrue(NotchSupport.closesOnPointerExit(expanded: true, peeking: true, openedByHover: true))
        // A direct opening is dismissed explicitly, never by the pointer leaving.
        XCTAssertFalse(NotchSupport.closesOnPointerExit(expanded: true, peeking: false, openedByHover: false))
        // One opened by hover closes as the pointer leaves it.
        XCTAssertTrue(NotchSupport.closesOnPointerExit(expanded: true, peeking: false, openedByHover: true))
        // A closed island has nothing to close.
        XCTAssertFalse(NotchSupport.closesOnPointerExit(expanded: false, peeking: false, openedByHover: false))
        XCTAssertFalse(NotchSupport.closesOnPointerExit(expanded: false, peeking: false, openedByHover: true))
    }

    func testClosesOnActivation() {
        // A directly opened island closes like a click away.
        XCTAssertTrue(NotchSupport.closesOnActivation(openedByHover: false, clicked: false, pointerInside: false))
        XCTAssertTrue(NotchSupport.closesOnActivation(openedByHover: false, clicked: false, pointerInside: true))
        XCTAssertTrue(NotchSupport.closesOnActivation(openedByHover: false, clicked: true, pointerInside: false))
        XCTAssertTrue(NotchSupport.closesOnActivation(openedByHover: false, clicked: true, pointerInside: true))
        // One opened by hover stays only while the pointer rests on it unclicked.
        XCTAssertFalse(NotchSupport.closesOnActivation(openedByHover: true, clicked: false, pointerInside: true))
        XCTAssertTrue(NotchSupport.closesOnActivation(openedByHover: true, clicked: false, pointerInside: false))
        XCTAssertTrue(NotchSupport.closesOnActivation(openedByHover: true, clicked: true, pointerInside: false))
        XCTAssertTrue(NotchSupport.closesOnActivation(openedByHover: true, clicked: true, pointerInside: true))
    }

    // MARK: Volume steps

    func testVolumeLevelStepsBySixteenthsAndQuarterStepsOfThose() {
        XCTAssertEqual(NotchSupport.volumeLevel(current: 0.5, direction: 1, fine: false),
                       0.5 + NotchSupport.fullVolumeKeyStep, accuracy: 1e-9)
        XCTAssertEqual(NotchSupport.volumeLevel(current: 0.5, direction: 1, fine: true),
                       0.5 + NotchSupport.finestVolumeKeyStep, accuracy: 1e-9)
        XCTAssertEqual(NotchSupport.volumeLevel(current: 0.5, direction: -1, fine: false),
                       0.5 - NotchSupport.fullVolumeKeyStep, accuracy: 1e-9)
    }

    func testVolumeLevelClampsAtBothEnds() {
        XCTAssertEqual(NotchSupport.volumeLevel(current: 0.99, direction: 1, fine: false), 1, accuracy: 1e-9)
        XCTAssertEqual(NotchSupport.volumeLevel(current: 0.01, direction: -1, fine: false), 0, accuracy: 1e-9)
    }

    func testVolumeLevelIgnoresZeroDirectionAndNonFiniteCurrent() {
        XCTAssertEqual(NotchSupport.volumeLevel(current: 0.5, direction: 0, fine: false), 0.5, accuracy: 1e-9)
        XCTAssertEqual(NotchSupport.volumeLevel(current: .nan, direction: 1, fine: false), 0, accuracy: 1e-9)
        XCTAssertEqual(NotchSupport.volumeLevel(current: .infinity, direction: 1, fine: true), 0, accuracy: 1e-9)
    }

    // MARK: Timer activity visibility

    func testTimerShowsActivityWhenCompletedEvenIfCountdownIsHidden() {
        let defaults = freshDefaults()
        turnOnDependencies(of: .timer, in: defaults)
        defaults.set(true, forKey: DefaultsKey.notchTimerEnabled)
        defaults.set(true, forKey: DefaultsKey.notchHideTimerCountdown)

        var session = NotchTimerSession()
        XCTAssertFalse(NotchTimerSupport.showsActivity(session, in: defaults))

        session.start(mode: .timer, minutes: 1, now: 100)
        XCTAssertFalse(NotchTimerSupport.showsActivity(session, in: defaults))

        session.pause(at: 110)
        XCTAssertFalse(NotchTimerSupport.showsActivity(session, in: defaults))

        session.resume(at: 110)
        XCTAssertTrue(session.finishIfDue(at: 200))
        XCTAssertTrue(session.completed)
        XCTAssertTrue(NotchTimerSupport.showsActivity(session, in: defaults))

        session.cancel()
        XCTAssertFalse(NotchTimerSupport.showsActivity(session, in: defaults))
    }

    // MARK: Playback source preference

    func testPreferredPlaybackSourceKeepsFollowedOtherPlayerWhenPausedOverPausedMusic() {
        let musicPaused = NotchPlaybackSource(
            pid: 100,
            bundleIdentifier: "com.spotify.client",
            isMusicApp: true,
            isPlaying: false,
            hasTrack: true
        )
        let videoPaused = NotchPlaybackSource(
            pid: 200,
            bundleIdentifier: "com.apple.Safari",
            isMusicApp: false,
            isPlaying: false,
            hasTrack: true
        )
        let chosen = NotchPlaybackSource.preferred(
            in: [musicPaused, videoPaused],
            previousPID: 200,
            systemPID: 100,
            includeOtherPlayers: true
        )
        XCTAssertEqual(chosen, videoPaused)

        let musicPlaying = NotchPlaybackSource(
            pid: 100,
            bundleIdentifier: "com.spotify.client",
            isMusicApp: true,
            isPlaying: true,
            hasTrack: true
        )
        let whenMusicResumes = NotchPlaybackSource.preferred(
            in: [musicPlaying, videoPaused],
            previousPID: 200,
            systemPID: 200,
            includeOtherPlayers: true
        )
        XCTAssertEqual(whenMusicResumes, musicPlaying)

        let withoutOtherPlayers = NotchPlaybackSource.preferred(
            in: [musicPaused, videoPaused],
            previousPID: 200,
            systemPID: 200,
            includeOtherPlayers: false
        )
        XCTAssertEqual(withoutOtherPlayers, musicPaused)
    }

    // MARK: Watch percentage parsing

    func testWatchNumberAndHeadlineParsePercentagesWithThousandsAndMinusSign() {
        XCTAssertEqual(NotchWatchSupport.number(in: "Zoom 1,250%", decimalSeparator: "."), 1250)
        XCTAssertEqual(NotchWatchSupport.headline(from: "Zoom 1,250%", groupsWithSpace: false), "1,250%")

        XCTAssertEqual(NotchWatchSupport.number(in: "Zoom 1250%"), 1250)
        XCTAssertEqual(NotchWatchSupport.headline(from: "Zoom 1250%", groupsWithSpace: false), "1250%")

        XCTAssertEqual(NotchWatchSupport.number(in: "−1 250%", decimalSeparator: ",", groupsWithSpace: true), -1250)
        XCTAssertEqual(NotchWatchSupport.headline(from: "−1 250%", groupsWithSpace: true), "−1250%")

        XCTAssertEqual(NotchWatchSupport.number(in: "−15%"), -15)
        XCTAssertEqual(NotchWatchSupport.headline(from: "−15%", groupsWithSpace: false), "−15%")

        XCTAssertEqual(NotchWatchSupport.number(in: "3 of 10, then 80% done"), 80)
        XCTAssertEqual(NotchWatchSupport.headline(from: "3 of 10, then 80% done", groupsWithSpace: false), "80%")

        XCTAssertEqual(NotchWatchSupport.number(in: "Step 2\n100%", groupsWithSpace: true), 100)
        XCTAssertEqual(NotchWatchSupport.headline(from: "Step 2\n100%", groupsWithSpace: true), "100%")
    }
}
