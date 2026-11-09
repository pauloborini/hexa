// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Pins the persistence contract of the notch shortcuts bar's configuration
/// (`NotchQuickAccessConfiguration`): a Codable roundtrip that survives the
/// app restart and the migration from the retired floating layer's keys
/// (DEC-008: the sides died with the floating layer; the user's layout must
/// not). Pure unit: fixtures use fixed UUIDs, and UserDefaults runs in a
/// throwaway suite domain removed in teardown, never in the user's own
/// preferences.
final class NotchQuickAccessConfigurationTests: XCTestCase {
    /// One fixed domain for the class. removePersistentDomain empties it but
    /// keeps its .plist in ~/Library/Preferences (see NotchRoutingBehaviorTests).
    private let suiteName = "hexaTests.notch-quick-access"
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

    private func button(_ index: Int, action: NotchQuickAction) -> NotchQuickButton {
        NotchQuickButton(id: UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", index))!,
                         action: action)
    }

    // MARK: Codable roundtrip

    func testRoundtripPreservesButtonsOrderSidesAndLabels() throws {
        var configuration = NotchQuickAccessConfiguration(buttons: [
            button(1, action: .explore),
            button(2, action: .module(.timer)),
            NotchQuickButton(id: UUID(uuidString: "00000000-0000-4000-8000-000000000003")!,
                             action: .pin,
                             side: .left,
                             label: "Ajustes"),
        ])
        configuration.move(UUID(uuidString: "00000000-0000-4000-8000-000000000002")!)
        let data = configuration.encoded
        XCTAssertFalse(data.isEmpty)
        let restored = try JSONDecoder().decode(NotchQuickAccessConfiguration.self, from: data)
        XCTAssertEqual(restored, configuration)
        // move() with no target sends the button to the end.
        XCTAssertEqual(restored.buttons[1].label, "Ajustes")
        XCTAssertEqual(restored.actions, [.explore, .pin, .module(.timer)])
    }

    func testEncodedIsSortedAndStableAcrossCalls() {
        let configuration = NotchQuickAccessConfiguration(buttons: [
            button(1, action: .explore),
            button(2, action: .module(.music)),
        ])
        XCTAssertEqual(configuration.encoded, configuration.encoded,
                       "the persisted bytes must be stable (sorted keys)")
    }

    // MARK: Sanitization

    func testSanitizeCapsAtMaximumButtons() {
        let buttons = (NotchQuickAction.optionalActions + [.explore, .module(.mixer), .control(.mixer)])
            .enumerated().map { button($0.offset + 1, action: $0.element) }
        let sanitized = NotchQuickAccessConfiguration(buttons: buttons).sanitized()
        XCTAssertEqual(sanitized.buttons.count, NotchQuickAccessConfiguration.maximumButtons)
        XCTAssertEqual(Set(sanitized.actions.map(\.canonical)).count, sanitized.buttons.count)
    }

    func testSanitizeDropsBrokenButtonsAndCleansLabels() {
        let configuration = NotchQuickAccessConfiguration(buttons: [
            button(1, action: .explore),
            // Unknown action id: the bar has nothing to run.
            NotchQuickButton(id: UUID(uuidString: "00000000-0000-4000-8000-000000000002")!,
                             action: .explore).pruned(),
            // Duplicate id: only the first survives.
            button(1, action: .module(.timer)),
            button(3, action: .pin),
        ])
        let sanitized = configuration.sanitized()
        XCTAssertEqual(sanitized.buttons.map(\.id), [button(1, action: .explore).id,
                                                     button(3, action: .pin).id])
        XCTAssertTrue(sanitized.buttons.first?.label.isEmpty == true)
    }

    func testSanitizeFlattensAndTrimsLabels() throws {
        let raw = NotchQuickButton(id: UUID(), action: .explore,
                                   label: "\n\n  Timer   longo\n\n" + String(repeating: "x", count: 45))
        let sanitized = NotchQuickAccessConfiguration(buttons: [raw]).sanitized()
        let label = try XCTUnwrap(sanitized.buttons.first?.label)
        XCTAssertFalse(label.contains("\n"))
        XCTAssertTrue(label.count <= 40)
    }

    // MARK: Reordering

    func testMoveReordersBeforeTarget() {
        let a = button(1, action: .explore).id
        let b = button(2, action: .module(.music)).id
        let c = button(3, action: .pin).id
        var configuration = NotchQuickAccessConfiguration(buttons: [
            button(1, action: .explore), button(2, action: .module(.music)), button(3, action: .pin),
        ])
        configuration.move(c, before: a)
        XCTAssertEqual(configuration.buttons.map(\.id), [c, a, b])
        configuration.move(c, before: nil)
        XCTAssertEqual(configuration.buttons.map(\.id), [a, b, c])
        // Unknown ids are no-ops, never crashes or reshuffles.
        configuration.move(UUID(), before: nil)
        XCTAssertEqual(configuration.buttons.map(\.id), [a, b, c])
    }

    // MARK: Legacy migration (retired floating layer keys)

    func testFreshInstallFallsBackToInitialLayout() {
        let stored = NotchQuickAccessConfiguration.stored(in: defaults)
        XCTAssertEqual(stored, .initial)
        XCTAssertEqual(stored.buttons.map(\.action), [.explore, .module(.timer), .module(.mixer), .module(.music), .control(.keepAwake), .module(.calendar)])
    }

    func testLegacySideKeysMigrateIntoTheBar() {
        // The retired floating layer stored side picks under three string
        // keys. Their presence alone (even empty) marks an explicit legacy
        // choice; the side itself is dead, the actions survive in bar order.
        defaults.set("bottom", forKey: DefaultsKey.notchQuickAccessSide)
        defaults.set("mixer", forKey: DefaultsKey.notchQuickAccessSecond)
        defaults.set("pin", forKey: DefaultsKey.notchQuickAccessThird)
        let migrated = NotchQuickAccessConfiguration.stored(in: defaults)
        XCTAssertEqual(migrated.actions, [.explore, .module(.mixer), .pin, .control(.keepAwake), .module(.timer), .module(.calendar)])
        // Migrated buttons carry stable UUIDs in positional order.
        XCTAssertEqual(migrated.buttons.first?.id,
                       UUID(uuidString: "00000000-0000-4000-8000-000000000001")!)
    }

    func testLegacySecondKeyEmptyDoesNotInjectSettings() {
        defaults.set("bottom", forKey: DefaultsKey.notchQuickAccessSide)
        let migrated = NotchQuickAccessConfiguration.stored(in: defaults)
        XCTAssertEqual(migrated.actions, [.explore, .module(.mixer), .control(.keepAwake), .module(.timer), .module(.calendar)])
        XCTAssertFalse(migrated.buttons.contains { $0.actionID == "settings" })
    }

    func testMigrationFromVersion2StripsSettings() throws {
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: NotchQuickAccessConfiguration.initial.encoded) as? [String: Any])
        old["version"] = 2
        var buttons = (old["buttons"] as? [[String: Any]]) ?? []
        buttons.insert(["id": UUID().uuidString, "actionID": "settings", "side": "bottom", "label": ""], at: 2)
        old["buttons"] = buttons
        defaults.set(try JSONSerialization.data(withJSONObject: old), forKey: DefaultsKey.notchQuickAccessLayout)
        let migrated = NotchQuickAccessConfiguration.stored(in: defaults)
        XCTAssertFalse(migrated.buttons.contains { $0.actionID == "settings" })
        XCTAssertEqual(migrated.buttons.count, 6)
    }

    func testVersion3WithSettingsMigratesToVersion4AndKeepsOtherButtons() throws {
        let configuration = NotchQuickAccessConfiguration(buttons: [
            button(1, action: .explore),
            button(2, action: .module(.timer)),
        ])
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: configuration.encoded) as? [String: Any])
        old["version"] = 3
        var buttons = (old["buttons"] as? [[String: Any]]) ?? []
        buttons.append(["id": UUID().uuidString, "actionID": "settings", "side": "bottom", "label": ""])
        old["buttons"] = buttons
        defaults.set(try JSONSerialization.data(withJSONObject: old), forKey: DefaultsKey.notchQuickAccessLayout)
        let migrated = NotchQuickAccessConfiguration.stored(in: defaults)
        XCTAssertFalse(migrated.buttons.contains { $0.actionID == "settings" },
                       "the retired Settings action is dropped by the v4 migration")
        XCTAssertEqual(migrated.actions, [.explore, .module(.timer)])
        XCTAssertEqual(migrated.buttons.count, 2, "the other buttons survive the migration")
        // The migration persists version 4, so it runs once.
        let data = try XCTUnwrap(defaults.data(forKey: DefaultsKey.notchQuickAccessLayout))
        let persisted = try JSONDecoder().decode(NotchQuickAccessConfiguration.self, from: data)
        XCTAssertEqual(persisted.actions, [.explore, .module(.timer)])
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["version"] as? Int, 4)
    }

    func testLegacyUnknownActionIsSkipped() {
        defaults.set("left", forKey: DefaultsKey.notchQuickAccessSide)
        defaults.set("no-such-module", forKey: DefaultsKey.notchQuickAccessSecond)
        defaults.set("timer", forKey: DefaultsKey.notchQuickAccessThird)
        let migrated = NotchQuickAccessConfiguration.stored(in: defaults)
        XCTAssertEqual(migrated.actions, [.explore, .module(.timer), .module(.mixer), .control(.keepAwake), .module(.calendar)])
    }

    func testSavedLayoutBeatsLegacyKeys() throws {
        let configuration = NotchQuickAccessConfiguration(buttons: [button(7, action: .module(.timer))])
        defaults.set(configuration.encoded, forKey: DefaultsKey.notchQuickAccessLayout)
        defaults.set("bottom", forKey: DefaultsKey.notchQuickAccessSide)
        let stored = NotchQuickAccessConfiguration.stored(in: defaults)
        XCTAssertEqual(stored.buttons.map(\.id), [button(7, action: .module(.timer)).id])
        // A versão anterior incorpora Controles uma vez, preservando ID/nome
        // e desduplicando o alias control.mixer com o destino module.mixer.
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: configuration.encoded) as? [String: Any])
        old["version"] = 1
        defaults.set(try JSONSerialization.data(withJSONObject: old), forKey: DefaultsKey.notchQuickAccessLayout)
        defaults.set("screenshot,speedTest,panel,calendar", forKey: DefaultsKey.notchHiddenControls)
        let migrated = NotchQuickAccessConfiguration.stored(in: defaults)
        XCTAssertEqual(migrated.buttons.first?.id, configuration.buttons.first?.id)
        XCTAssertEqual(migrated.actions, [.module(.timer), .module(.mixer), .control(.keepAwake)])
        defaults.set(migrated.encoded, forKey: DefaultsKey.notchQuickAccessLayout)
        defaults.set("", forKey: DefaultsKey.notchHiddenControls)
        XCTAssertEqual(NotchQuickAccessConfiguration.stored(in: defaults), migrated)

    }

    func testOversizedOrCorruptStoredDataFallsBackToLegacyChoice() {
        defaults.set(Data(count: 40_000), forKey: DefaultsKey.notchQuickAccessLayout)
        defaults.set("bottom", forKey: DefaultsKey.notchQuickAccessSide)
        XCTAssertEqual(NotchQuickAccessConfiguration.stored(in: defaults).buttons.count, 5,
                       "an oversized blob is rejected and the legacy choice wins")
        defaults.set(Data("garbage".utf8), forKey: DefaultsKey.notchQuickAccessLayout)
        XCTAssertEqual(NotchQuickAccessConfiguration.stored(in: defaults).buttons.count, 5)
    }
}

private extension NotchQuickButton {
    /// A row whose action id nothing can resolve.
    func pruned() -> NotchQuickButton {
        var copy = self
        copy.actionID = "no-such-action"
        return copy
    }
}
