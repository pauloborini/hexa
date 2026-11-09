// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Foundation

/// Decision logic for keeping the launch at login registration alive.
///
/// The system's own record is not durable enough on its own. A registration
/// made from a temporary location (a mounted disk image, or the randomized
/// read-only mount the system uses for unmoved downloads) points at a path
/// that no longer exists on the next launch, and system updates have been
/// seen dropping third-party items outright. So the app remembers the user's
/// choice in preferences and redoes a registration lost to a move at startup.
/// The same "off" also follows a removal in System Settings, which is the
/// user's own choice; that one is adopted rather than undone.
enum LaunchAtLoginSupport {
    /// Settings keeps its view alive when the window closes, so onAppear
    /// alone cannot refresh a choice made in System Settings.
    static let settingsRefreshRequested = Notification.Name("Hexa.launchAtLoginSettingsRefreshRequested")

    /// What the system holds for this app. `needsApproval` is a registration
    /// that exists but is not allowed to run. Background permission can block
    /// it even when it appears under Open at Login. Only the user can approve
    /// it in System Settings; registering again does not grant that permission.
    enum Registration: Equatable {
        case enabled
        case needsApproval
        case off
    }

    enum StartupAction: Equatable {
        /// Leave everything as it is.
        case none
        /// The system has launch at login on but the stored choice says off:
        /// the user turned it on outside the app, so adopt that choice.
        case adoptEnabled
        /// The user wants launch at login and the system lost the
        /// registration: register again from the current location.
        case register
        /// The item was removed while the app stayed where it was registered
        /// from: the user took it out in System Settings, so adopt that.
        case adoptOff
    }

    /// What startup reconciliation should do. Startup never disables
    /// anything: turning the item off is always an explicit user action.
    /// Registration is only redone from a stable location, because a record
    /// made from an unstable one would just die with the mount again, never
    /// over an item awaiting approval (the record is already there and
    /// registering again cannot approve it), and only when the app moved
    /// since it registered. A record missing for an app still where it
    /// registered from was removed in System Settings, which is the user
    /// turning it off. With no path on record (a registration older than
    /// this check) the app cannot tell, and registers as it always did.
    static func startupAction(wanted: Bool, registration: Registration,
                              locationIsUnstable: Bool,
                              registeredPath: String?, appPath: String) -> StartupAction {
        switch registration {
        case .enabled:
            return wanted ? .none : .adoptEnabled
        case .needsApproval:
            return .none
        case .off:
            guard wanted, !locationIsUnstable else { return .none }
            return registeredPath == appPath ? .adoptOff : .register
        }
    }

    /// True when the app runs from the randomized read-only mount Gatekeeper
    /// uses for translocated apps, or from any other read-only volume (the
    /// mounted DMG). External writable volumes are fine, so this asks the
    /// file system instead of guessing from the path.
    static func runsFromImmutableLocation(appPath: String,
                                          volumeIsReadOnly: (String) -> Bool) -> Bool {
        appPath.contains("/AppTranslocation/") || volumeIsReadOnly(appPath)
    }
}
