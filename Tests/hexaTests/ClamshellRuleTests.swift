// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Pins the cycle of the closed-lid rule: the rule carries its own removal,
/// so the end of the mode, the quit and the recovery after a crash take it
/// away without asking for the administrator password again.
final class ClamshellRuleTests: XCTestCase {
    private typealias Lifecycle = SudoersSupport.ClamshellRuleLifecycle

    /// The names the prompted removal left behind. Spelled in pieces so this
    /// file does not make the repository-wide sweep non-empty: the acceptance
    /// asks for a sweep that finds nothing in `Sources/` or `Tests/`.
    private static let deadSymbols = [
        "Sudoers." + "remove",
        "removeClamshellRule" + "IfRequested",
        "clamshellRule" + "RemovalRequested",
    ]

    // MARK: - The rule itself

    func testClamshellRuleIsSelfRemoving() {
        let rule = SudoersSupport.clamshellRule(uid: 501)
        XCTAssertEqual(rule, "#501 ALL=(root) NOPASSWD: /usr/bin/pmset disablesleep 1, "
            + "/usr/bin/pmset disablesleep 0, "
            + "/bin/rm -f /etc/sudoers.d/hexa-clamshell /etc/sudoers.d/hexa-utils-clamshell")
    }

    func testSelfRemoveArgumentsAndNoAdminShellPath() throws {
        XCTAssertEqual(SudoersSupport.selfRemoveArguments(),
                       ["/bin/rm", "-f",
                        "/etc/sudoers.d/hexa-clamshell",
                        "/etc/sudoers.d/hexa-utils-clamshell"])

        let shell = try source("Sources/Hexa/Services/ShellSupport.swift")
        let removal = try XCTUnwrap(body(of: shell, startingAt: "static func selfRemove(completion:"))
        // The removal runs on the same serialized queue as the other native
        // writes, and never opens a prompt.
        XCTAssertTrue(removal.contains("sleepStateQueue"))
        XCTAssertFalse(removal.contains("AdminShell"))
        let call = try XCTUnwrap(body(of: shell, startingAt: "private static func selfRemoveOnQueue()"))
        XCTAssertTrue(call.contains(#"Shell.run("/usr/bin/sudo", ["-n"]"#))
        XCTAssertFalse(call.contains("AdminShell"))
    }

    func testTheSelfRemovingMarkerStartsUnset() {
        let suiteName = "hexa.tests.clamshell.rule"
        let defaults = UserDefaults(suiteName: suiteName)
        defaults?.removePersistentDomain(forName: suiteName)
        XCTAssertFalse(DefaultsKey.clamshellRuleSelfRemovingValue(in: defaults ?? .standard))
    }

    // MARK: - The lifecycle

    func testModeActivatedInstallsWhenRuleMissingOrNotMigrated() {
        let noRule = Lifecycle.State(ruleFilesPresent: false, ruleIsSelfRemoving: false, sleepDisabled: false)
        XCTAssertEqual(Lifecycle.action(for: .modeActivated, state: noRule), [.installRule])
        // A rule that predates the self-removing grant is migrated by this
        // same activation: the old one cannot take itself off.
        let oldRule = Lifecycle.State(ruleFilesPresent: true, ruleIsSelfRemoving: false, sleepDisabled: false)
        XCTAssertEqual(Lifecycle.action(for: .modeActivated, state: oldRule), [.installRule])
        // A rule that already carries its own removal asks for nothing.
        let currentRule = Lifecycle.State(ruleFilesPresent: true, ruleIsSelfRemoving: true, sleepDisabled: false)
        XCTAssertEqual(Lifecycle.action(for: .modeActivated, state: currentRule), [])
    }

    func testModeEndedRemovesRulePasswordlessIncludingQuitWithoutOverride() {
        let withOverride = Lifecycle.State(ruleFilesPresent: true, ruleIsSelfRemoving: true, sleepDisabled: true)
        let withoutOverride = Lifecycle.State(ruleFilesPresent: true, ruleIsSelfRemoving: true, sleepDisabled: false)
        XCTAssertEqual(Lifecycle.action(for: .modeEnded(reason: .toggleOff), state: withOverride),
                       [.restoreSleepPasswordless, .removeRulePasswordless])
        XCTAssertEqual(Lifecycle.action(for: .modeEnded(reason: .toggleOff), state: withoutOverride),
                       [.removeRulePasswordless])
        // The quit takes the rule with it, with or without an override to
        // restore.
        XCTAssertEqual(Lifecycle.action(for: .modeEnded(reason: .appQuit), state: withOverride),
                       [.restoreSleepPasswordless, .removeRulePasswordless])
        XCTAssertEqual(Lifecycle.action(for: .modeEnded(reason: .appQuit), state: withoutOverride),
                       [.removeRulePasswordless])
        // Without a rule there is nothing to remove.
        let noRule = Lifecycle.State(ruleFilesPresent: false, ruleIsSelfRemoving: false, sleepDisabled: true)
        XCTAssertEqual(Lifecycle.action(for: .modeEnded(reason: .toggleOff), state: noRule), [])
        XCTAssertEqual(Lifecycle.action(for: .modeEnded(reason: .appQuit), state: noRule), [])
        // The end of the mode never asks for authorization and never installs.
        for state in [withOverride, withoutOverride, noRule] {
            for reason in [Lifecycle.EndReason.toggleOff, .appQuit] {
                let actions = Lifecycle.action(for: .modeEnded(reason: reason), state: state)
                XCTAssertFalse(actions.contains(.restoreSleepWithAuthorization))
                XCTAssertFalse(actions.contains(.installRule))
            }
        }
    }

    func testLaunchRecoveredCleansResidualRuleWithoutAuthorization() {
        // The rule the crash left behind carries its own removal.
        XCTAssertEqual(Lifecycle.action(for: .launchRecovered,
                                        state: Lifecycle.State(ruleFilesPresent: true,
                                                               ruleIsSelfRemoving: true,
                                                               sleepDisabled: true)),
                       [.restoreSleepPasswordless, .removeRulePasswordless])
        XCTAssertEqual(Lifecycle.action(for: .launchRecovered,
                                        state: Lifecycle.State(ruleFilesPresent: true,
                                                               ruleIsSelfRemoving: true,
                                                               sleepDisabled: false)),
                       [.removeRulePasswordless])
        // Without a rule to grant it, the override needs the password.
        XCTAssertEqual(Lifecycle.action(for: .launchRecovered,
                                        state: Lifecycle.State(ruleFilesPresent: false,
                                                               ruleIsSelfRemoving: false,
                                                               sleepDisabled: true)),
                       [.restoreSleepWithAuthorization])
    }

    // MARK: - The wiring

    func testFimDoModoSemPromptWiring() throws {
        let manager = try source("Sources/Hexa/Services/KeepAwakeManager.swift")
        let preference = try XCTUnwrap(body(of: manager, startingAt: "@Published var clamshellPreferred: Bool {"))
        // Turning the option off reaches the end of the mode.
        XCTAssertTrue(preference.contains("endClamshellMode()"))
        // The end of the mode is the consequence of the restore that finished.
        let restore = try XCTUnwrap(body(of: manager, startingAt: "private func finishClamshellRestore(ok: Bool"))
        XCTAssertTrue(restore.contains("endClamshellMode()"))
        let end = try XCTUnwrap(body(of: manager, startingAt: "private func endClamshellMode() {"))
        XCTAssertTrue(end.contains("Sudoers.selfRemove"))
        XCTAssertFalse(end.contains("AdminShell"))
        // The prompted removal is gone from the whole repository.
        for file in try Self.swiftSources() {
            let text = try String(contentsOf: file, encoding: .utf8)
            for dead in Self.deadSymbols {
                XCTAssertFalse(text.contains(dead),
                               "\(dead) still exists in \(file.lastPathComponent)")
            }
        }
    }

    func testQuitRemovesRuleUnconditionally() throws {
        let manager = try source("Sources/Hexa/Services/KeepAwakeManager.swift")
        let deactivate = try XCTUnwrap(body(of: manager, startingAt: "func deactivate(reason: EndReason) {"))
        XCTAssertTrue(deactivate.contains("Sudoers.selfRemove"))
        // The removal is not inside the branch that only restores an existing
        // override: the quit takes the rule with or without one.
        XCTAssertNil(deactivate.range(of: #"if clamshellNeedsRestore \{[^}]*Sudoers\.selfRemove"#,
                                      options: .regularExpression))
        // No administrator prompt on the way out.
        XCTAssertFalse(manager.contains("AdminShell"))
    }

    func testRecoveryCleansTheResidualRuleWithoutAskingAnything() throws {
        let manager = try source("Sources/Hexa/Services/KeepAwakeManager.swift")
        let recovery = try XCTUnwrap(body(of: manager, startingAt: "func recoverIfNeeded(completion:"))
        XCTAssertTrue(recovery.contains("Sudoers.selfRemove"))
        // The authorized restore stays for the case with no rule to grant it.
        XCTAssertTrue(recovery.contains("restoreSleepWithAuthorization"))
    }

    func testActivationConsultsTheRuleAndMarksItOnlyAfterItIsInstalled() throws {
        let manager = try source("Sources/Hexa/Services/KeepAwakeManager.swift")
        let prepare = try XCTUnwrap(body(of: manager, startingAt: "private func prepareClamshellPreference() {"))
        XCTAssertTrue(prepare.contains(".modeActivated"))
        let setup = try XCTUnwrap(body(of: manager, startingAt: "private func finishClamshellSetup(ok: Bool"))
        let failure = try XCTUnwrap(setup.range(of: "guard ok else"))
        let marker = try XCTUnwrap(setup.range(of: "DefaultsKey.clamshellRuleSelfRemoving"))
        // A setup that failed writes nothing: the next activation tries again.
        XCTAssertGreaterThan(marker.lowerBound, failure.lowerBound)
    }

    /// The probe answers for the passwordless call, never for the rule: a rule
    /// written before the self-removing grant still answers `sudo -n pmset`,
    /// so an activation gated only by the probe leaves the old rule in place
    /// forever (ISSUE-788 survives for everyone who already uses the mode).
    func testActivationMigratesEvenWhenThePasswordlessCallStillAnswers() throws {
        let manager = try source("Sources/Hexa/Services/KeepAwakeManager.swift")
        let apply = try XCTUnwrap(body(of: manager, startingAt: "private func applyClamshellPreference() {"))
        let policy = try XCTUnwrap(apply.range(of: "ClamshellRuleLifecycle"),
                                   "A ativação precisa consultar a política da regra")
        let shortcut = try XCTUnwrap(apply.range(of: "if passwordlessClamshell"),
                                     "O atalho sem senha continua existindo")
        XCTAssertLessThan(policy.lowerBound, shortcut.lowerBound,
                          "A política decide antes do atalho: a regra antiga responde ao probe")
        XCTAssertTrue(apply.contains(".installRule"),
                      "A ativação precisa tratar a ação de instalar/migrar a regra")
    }

    func testTheSessionTogglesStayOnThePasswordlessPath() throws {
        let manager = try source("Sources/Hexa/Services/KeepAwakeManager.swift")
        let enable = try XCTUnwrap(body(of: manager, startingAt: "private func enableClamshell() {"))
        XCTAssertTrue(enable.contains("Sudoers.pmsetDisableSleep(true)"))
        // The override is registered before the system-wide write.
        let flag = try XCTUnwrap(enable.range(of: "DefaultsKey.sleepDisabledFlag"))
        let write = try XCTUnwrap(enable.range(of: "Sudoers.pmsetDisableSleep(true)"))
        XCTAssertLessThan(flag.lowerBound, write.lowerBound)
        let disable = try XCTUnwrap(body(of: manager, startingAt: "private func disableClamshell(synchronous: Bool) {"))
        XCTAssertTrue(disable.contains("Sudoers.pmsetDisableSleep(false)"))
        // A session toggle never asks for the password.
        XCTAssertFalse(enable.contains("AdminShell"))
        XCTAssertFalse(disable.contains("AdminShell"))
    }

    // MARK: - Helpers

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // hexaTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // repository root

    private func source(_ path: String) throws -> String {
        try String(contentsOf: Self.repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    private static func swiftSources() throws -> [URL] {
        let manager = FileManager.default
        var files: [URL] = []
        for root in ["Sources", "Tests"] {
            let directory = repoRoot.appendingPathComponent(root)
            guard let enumerator = manager.enumerator(atPath: directory.path) else { continue }
            for case let path as String in enumerator where path.hasSuffix(".swift") {
                files.append(directory.appendingPathComponent(path))
            }
        }
        return files
    }

    /// The body of the declaration that starts at `marker`, braces counted.
    private func body(of source: String, startingAt marker: String) -> String? {
        guard let start = source.range(of: marker) else { return nil }
        var depth = 0
        var body = ""
        var opened = false
        for character in source[start.lowerBound...] {
            if character == "{" {
                depth += 1
                opened = true
            } else if character == "}" {
                depth -= 1
                if opened, depth == 0 {
                    body.append(character)
                    return body
                }
            }
            body.append(character)
        }
        return nil
    }
}
