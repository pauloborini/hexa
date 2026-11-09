// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import AppKit
import CoreGraphics
import Foundation

/// Which of the menu bar's sections an item belongs to, read from where the
/// user ⌘-dragged it relative to the module's separators.
///
///     LTR:  [ hidden ] | > [ visible ]
///                       ^
enum MenuBarSection: Int, Comparable, CaseIterable {
    case visible
    case hidden

    static func < (lhs: MenuBarSection, rhs: MenuBarSection) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum MenuBarHidingRehideDelay: String, CaseIterable {
    case instant
    case fiveSeconds = "5"
    case tenSeconds = "10"

    static let defaultValue = Self.fiveSeconds

    var seconds: TimeInterval? {
        switch self {
        case .instant: nil
        case .fiveSeconds: 5
        case .tenSeconds: 10
        }
    }
}

/// One status item another app owns. Accessibility exposes no title or
/// identifier for these, so the owning bundle and the frame are all there is.
struct MenuBarHidingInventoryItem: Equatable {
    let bundleIdentifier: String?
    let frame: CGRect
}

struct MenuBarHidingLayout: Equatable {
    /// One section per owning bundle, because hiding is per bundle.
    var sections: [String: MenuBarSection]

    func bundles(in wanted: Set<MenuBarSection>) -> [String] {
        sections.filter { wanted.contains($0.value) }.map(\.key).sorted()
    }
}

enum MenuBarHidingLayoutResolver {
    /// Bundles whose items are macOS's own controls (clock, Wi-Fi, Control
    /// Center...). They cannot be hidden by bundle, so they are left out of
    /// the layout and kept visible separately.
    static let systemItemOwners: Set<String> = [
        "com.apple.MenuBarAgent", "com.apple.controlcenter", "com.apple.systemuiserver",
    ]

    static func resolve(inventory: [MenuBarHidingInventoryItem],
                        separatorFrame: CGRect,
                        isLeftToRight: Bool,
                        excludingBundle ownBundle: String?) -> MenuBarHidingLayout {
        var sections: [String: MenuBarSection] = [:]
        for item in inventory {
            guard let bundle = item.bundleIdentifier,
                  bundle != ownBundle,
                  !systemItemOwners.contains(bundle) else { continue }
            let section = self.section(of: item.frame,
                                       separatorFrame: separatorFrame,
                                       isLeftToRight: isLeftToRight)
            // One app can own several items, but hiding applies to the whole
            // bundle. The most visible item wins so an icon the user kept
            // visible is never hidden because a sibling sits in the hidden
            // section.
            sections[bundle] = min(sections[bundle] ?? section, section)
        }
        return MenuBarHidingLayout(sections: sections)
    }

    static func section(of frame: CGRect,
                        separatorFrame: CGRect,
                        isLeftToRight: Bool) -> MenuBarSection {
        // Distance toward the arrow side: positive means on the visible side.
        func towardArrow(_ x: CGFloat, from boundary: CGRect) -> CGFloat {
            isLeftToRight ? x - boundary.midX : boundary.midX - x
        }
        if towardArrow(frame.midX, from: separatorFrame) > 0 {
            return .visible
        }
        return .hidden
    }
}

/// How this macOS hides other apps' menu bar items.
///
/// Up to macOS 26 the bar draws a window per item, and inflating a separator
/// status item pushes everything left of it off screen. macOS 27 rebuilt the
/// bar as one window drawn by MenuBarAgent: an oversized item is dropped, so
/// the only path left is the visibility restriction behind assessment mode,
/// which takes an allow-list of bundles.
enum MenuBarHidingEngineKind: Equatable {
    case separatorLength
    case visibilityRestriction
    case unavailable

    static func forOperatingSystem(majorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion)
        -> MenuBarHidingEngineKind {
        majorVersion >= 27 ? .visibilityRestriction : .separatorLength
    }
}

/// The menu bar's own geometry, kept apart from the status items so it can be
/// measured without a bar.
enum MenuBarHidingSupport {
    static func toggleSymbol(collapsed: Bool) -> String {
        collapsed ? "chevron.left" : "chevron.right"
    }

    static func isDeveloperIDCertificateSubject(_ subject: String?) -> Bool {
        subject?.hasPrefix("Developer ID Application:") == true
    }

    /// macOS's own items stay visible. The system item numbers cover only a
    /// handful of them (battery, clock, Wi-Fi...): the other ones, Now
    /// Playing among them, belong to Control Center and are kept by bundle.
    static func activationAllowList(bundles: [String], ownBundle: String?) -> [String] {
        var allowed = Set(bundles).union(MenuBarHidingLayoutResolver.systemItemOwners)
        if let ownBundle { allowed.insert(ownBundle) }
        return allowed.sorted()
    }

    /// A length that covers the widest attached display. The menu bar is
    /// replicated on every display, so sizing from `NSScreen.main` leaks
    /// hidden icons on wider screens. macOS caps `NSStatusItem.length` at
    /// 10,000 points.
    static func collapsedLength(screenWidths: [CGFloat]) -> CGFloat {
        let width = screenWidths.max() ?? 1728
        return max(500, min(width * 2, 10_000))
    }

    /// The expanded width of a separator, and zero for one the user asked to
    /// keep out of the way. Zero rather than `isVisible = false`: a hidden
    /// status item makes macOS forget where the user placed it.
    static func separatorLength(expanded: Bool, enabled: Bool, collapsedLength: CGFloat) -> CGFloat {
        guard enabled else { return 0 }
        return expanded ? 20 : collapsedLength
    }

    /// The bundles an allow-list keeps on screen while the hidden section is
    /// closed, or `nil` when hiding must not happen at all.
    ///
    /// The restriction hides every bundle the list omits, so the list is only
    /// safe when it was built from a read that saw something: an empty read
    /// (Accessibility denied, framework answering nothing) would otherwise
    /// hide every icon in the bar. An app whose items could not be read is
    /// kept visible: leaving an icon visible that should be hidden is
    /// recoverable, hiding one the user meant to keep is not.
    static func restrictionAllowList(layout: MenuBarHidingLayout,
                                     unreadBundles: Set<String>,
                                     readAnyItem: Bool) -> [String]? {
        guard readAnyItem || !layout.sections.isEmpty else { return nil }
        var allowed = Set(layout.bundles(in: [.visible]))
        allowed.formUnion(unreadBundles)
        return allowed.sorted()
    }

}
