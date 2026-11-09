// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Foundation

enum SudoersSupport {
    /// True when a `pmset -g` report lists lid sleep as disabled.
    static func sleepDisabled(inPmsetOutput output: String) -> Bool {
        output.range(of: #"SleepDisabled\s+1"#, options: .regularExpression) != nil
    }

    /// The closed-lid NOPASSWD rule, granted by uid (`#uid` user spec). A
    /// username would have to be sanitized against sudoers *and* shell
    /// metacharacters — short names on SSO-enrolled Macs can be full email
    /// addresses — while a uid interpolates as bare digits, which
    /// neither interpreter can read as anything else.
    ///
    /// The rule also grants its own removal: the rule lives as long as the
    /// mode does, and the end of the mode takes it away without asking for a
    /// password again.
    static func clamshellRule(uid: uid_t) -> String {
        "#\(uid) ALL=(root) NOPASSWD: /usr/bin/pmset disablesleep 1, /usr/bin/pmset disablesleep 0, \(selfRemoveCommand)"
    }

    /// The command the rule grants itself, so the rule (and the rule file
    /// left behind by earlier names) can go without a password.
    static var selfRemoveCommand: String {
        selfRemoveArguments().joined(separator: " ")
    }

    /// The exact arguments of that removal: the rule file and every rule
    /// file written under an earlier name.
    static func selfRemoveArguments() -> [String] {
        ["/bin/rm", "-f"] + [Sudoers.rulePath] + Sudoers.legacyRulePaths
    }

    /// When the rule is installed, when it goes and how. Pure: it answers
    /// what the cycle of the mode does with the rule, and the executor does
    /// it. The rule lives as long as the mode is on, and it leaves through
    /// the grant it carries.
    enum ClamshellRuleLifecycle {
        enum Event: Equatable {
            case modeActivated
            case modeEnded(reason: EndReason)
            case launchRecovered
        }

        enum EndReason: Equatable {
            case toggleOff
            case appQuit
        }

        struct State: Equatable {
            /// Whether a rule file (current or legacy name) is on disk.
            var ruleFilesPresent: Bool
            /// Whether the rule on disk carries its own removal.
            var ruleIsSelfRemoving: Bool
            /// Whether this app left `pmset disablesleep` on.
            var sleepDisabled: Bool
        }

        enum Action: Equatable {
            /// Install the rule, asking for the administrator password.
            case installRule
            /// Put sleep back through the rule's own grant.
            case restoreSleepPasswordless
            /// Take the rule away through the rule's own grant.
            case removeRulePasswordless
            /// Put sleep back asking for the administrator password.
            case restoreSleepWithAuthorization
        }

        static func action(for event: Event, state: State) -> [Action] {
            switch event {
            case .modeActivated:
                // A rule that predates the self-removing grant is replaced by
                // this same activation: the old one cannot take itself off.
                return state.ruleFilesPresent && state.ruleIsSelfRemoving ? [] : [.installRule]
            case .modeEnded:
                // The mode is over: the rule leaves with it, with or without
                // a sleep override to restore.
                guard state.ruleFilesPresent else { return [] }
                return state.sleepDisabled
                    ? [.restoreSleepPasswordless, .removeRulePasswordless]
                    : [.removeRulePasswordless]
            case .launchRecovered:
                if state.ruleFilesPresent {
                    // The rule the crash left behind grants its own removal.
                    return state.sleepDisabled
                        ? [.restoreSleepPasswordless, .removeRulePasswordless]
                        : [.removeRulePasswordless]
                }
                // No rule to grant the off: the override needs the password.
                return state.sleepDisabled ? [.restoreSleepWithAuthorization] : []
            }
        }
    }
}
