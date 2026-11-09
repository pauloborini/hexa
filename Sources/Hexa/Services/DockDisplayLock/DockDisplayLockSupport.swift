// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import CoreGraphics
import Foundation

/// The display the Dock is held to, as stored. A display is remembered by the
/// UUID macOS derives from the monitor itself, so the choice follows it from
/// port to port; the main and built-in choices follow the role instead.
enum DockDisplayLockTarget: Equatable, Hashable {
    case main
    case builtIn
    case display(uuid: String)

    static let mainStorage = "main"
    static let builtInStorage = "builtIn"

    init(storage: String?) {
        switch storage {
        case Self.builtInStorage?: self = .builtIn
        case let uuid? where !uuid.isEmpty && uuid != Self.mainStorage: self = .display(uuid: uuid)
        default: self = .main
        }
    }

    var storageValue: String {
        switch self {
        case .main: return Self.mainStorage
        case .builtIn: return Self.builtInStorage
        case let .display(uuid): return uuid
        }
    }
}

/// One connected display, read once per change of the arrangement. Frames are
/// in global display coordinates, the ones event locations use: the origin at
/// the main display's top left corner, y growing downward.
struct DockDisplayLockDisplay: Equatable, Identifiable {
    let id: CGDirectDisplayID
    let uuid: String
    let name: String
    let frame: CGRect
    let isMain: Bool
    let isBuiltIn: Bool
}

/// Which edge of the screen the Dock occupies. `com.apple.dock` stores
/// "left" and "right"; the key is absent when the Dock sits at the bottom.
enum DockDisplayLockOrientation: String, Equatable {
    case bottom
    case left
    case right

    init(storage: String?) {
        switch storage {
        case "left": self = .left
        case "right": self = .right
        default: self = .bottom
        }
    }
}

/// A screen corner with a Hot Corner action, as the Dock's `wvous-*` keys read.
enum DockDisplayLockCorner: String, CaseIterable {
    case topLeft = "tl", topRight = "tr", bottomLeft = "bl", bottomRight = "br"

    var preferenceKey: String { "wvous-\(rawValue)-corner" }

    /// 0 and 1 are the two ways the preference says "no action".
    static func actions(in dockDomain: [String: Any]) -> Set<DockDisplayLockCorner> {
        Set(allCases.filter { ((dockDomain[$0.preferenceKey] as? NSNumber)?.intValue ?? 0) > 1 })
    }
}

/// The decisions behind keeping the Dock on one display, kept apart from the
/// event tap so every arrangement can be walked without real displays.
///
/// With "Displays have separate Spaces" on, macOS moves the Dock to another
/// display when the pointer pushes against that display's Dock edge. There is
/// no setting and no API for it, so the pointer is nudged back into the screen
/// just before it reaches the edge of a display the Dock should not move to.
/// The Dock never receives the push, so it never relocates. The nudge leaves
/// the pointer a few points inside the screen instead of freezing it, which
/// keeps the edge usable for drags and Hot Corners; those last points are the
/// price, and Option gives them back.
enum DockDisplayLockSupport {
    /// How far the pointer is moved back from a Dock edge, in points.
    static let edgeDepth: CGFloat = 7
    /// The corner square kept for Hot Corners, in points. Same depth as the
    /// edge strip, so the pointer reaches the square before being nudged.
    static let cornerSize: CGFloat = edgeDepth
    /// Displays closer than this along an edge count as touching.
    static let adjacencyTolerance: CGFloat = 2

    // MARK: - Where the Dock belongs

    /// The display the Dock should stay on now. A chosen display that is not
    /// connected falls back to the main one for as long as it is away; the
    /// choice itself is kept, so it applies again when the display returns.
    static func anchor(for target: DockDisplayLockTarget,
                       in displays: [DockDisplayLockDisplay]) -> DockDisplayLockDisplay? {
        let main = displays.first(where: \.isMain) ?? displays.first
        switch target {
        case .main: return main
        case .builtIn: return displays.first(where: \.isBuiltIn) ?? main
        case let .display(uuid): return displays.first { $0.uuid == uuid } ?? main
        }
    }

    // MARK: - What the tap nudges

    /// One band that takes the pointer back into the screen. The vector is the
    /// direction that leaves the edge; its length is `edgeDepth`.
    struct Zone: Equatable {
        var rect: CGRect
        var nudge: CGVector
    }

    struct Zones: Equatable {
        var strips: [Zone] = []
        /// Corner squares whose Hot Corner has an action.
        var corners: [Zone] = []

        static let none = Zones()
        var isEmpty: Bool { strips.isEmpty }
    }

    static func zones(displays: [DockDisplayLockDisplay],
                      anchorID: CGDirectDisplayID?,
                      orientation: DockDisplayLockOrientation,
                      hotCorners: Set<DockDisplayLockCorner>) -> Zones {
        // One display has nowhere to move the Dock to.
        guard displays.count > 1, let anchorID, displays.contains(where: { $0.id == anchorID }) else {
            return .none
        }
        var zones = Zones()
        for display in displays where display.id != anchorID {
            let others = displays.filter { $0.id != display.id }
            for segment in hardSegments(of: display, orientation: orientation, others: others) {
                zones.strips.append(strip(along: segment, of: display.frame, orientation: orientation))
            }
            zones.corners += cornerSquares(of: display, orientation: orientation, others: others,
                                           hotCorners: hotCorners)
        }
        return zones
    }

    /// Where a pointer at `point` should be moved to, or nil when it passes
    /// untouched. The first move into a Hot Corner square passes so the corner
    /// fires; the moves after it, which would press on the edge, are pushed
    /// back until the pointer leaves the square.
    static func nudged(_ point: CGPoint, zones: Zones, inCorner: inout Bool) -> CGPoint? {
        if let corner = zones.corners.first(where: { $0.rect.contains(point) }) {
            defer { inCorner = true }
            return inCorner ? CGPoint(x: point.x + corner.nudge.dx, y: point.y + corner.nudge.dy) : nil
        }
        inCorner = false
        guard let zone = zones.strips.first(where: { $0.rect.contains(point) }) else { return nil }
        return CGPoint(x: point.x + zone.nudge.dx, y: point.y + zone.nudge.dy)
    }

    /// The parts of a display's Dock edge with no display beyond them, as
    /// ranges along the edge. Where another display touches that edge the
    /// pointer crosses over instead of pressing, so there is nothing to hold.
    static func hardSegments(of display: DockDisplayLockDisplay,
                             orientation: DockDisplayLockOrientation,
                             others: [DockDisplayLockDisplay]) -> [ClosedRange<CGFloat>] {
        let frame = display.frame
        let edge: ClosedRange<CGFloat>
        let neighbours: [ClosedRange<CGFloat>]
        switch orientation {
        case .bottom:
            edge = frame.minX...frame.maxX
            neighbours = others.filter { abs($0.frame.minY - frame.maxY) <= adjacencyTolerance }
                .map { $0.frame.minX...$0.frame.maxX }
        case .left:
            edge = frame.minY...frame.maxY
            neighbours = others.filter { abs($0.frame.maxX - frame.minX) <= adjacencyTolerance }
                .map { $0.frame.minY...$0.frame.maxY }
        case .right:
            edge = frame.minY...frame.maxY
            neighbours = others.filter { abs($0.frame.minX - frame.maxX) <= adjacencyTolerance }
                .map { $0.frame.minY...$0.frame.maxY }
        }
        return subtract(neighbours, from: edge)
    }

    static func subtract(_ ranges: [ClosedRange<CGFloat>],
                         from whole: ClosedRange<CGFloat>) -> [ClosedRange<CGFloat>] {
        var remaining = [whole]
        for cut in ranges {
            remaining = remaining.flatMap { piece -> [ClosedRange<CGFloat>] in
                guard cut.lowerBound < piece.upperBound, cut.upperBound > piece.lowerBound else { return [piece] }
                var kept: [ClosedRange<CGFloat>] = []
                if cut.lowerBound > piece.lowerBound { kept.append(piece.lowerBound...cut.lowerBound) }
                if cut.upperBound < piece.upperBound { kept.append(cut.upperBound...piece.upperBound) }
                return kept
            }
        }
        return remaining.filter { $0.upperBound > $0.lowerBound }
    }

    /// The band along one hard segment. It reaches one point past the edge,
    /// where no display lies, so a pointer reported exactly on the edge line
    /// still falls inside.
    static func strip(along segment: ClosedRange<CGFloat>,
                      of frame: CGRect,
                      orientation: DockDisplayLockOrientation) -> Zone {
        let length = segment.upperBound - segment.lowerBound
        switch orientation {
        case .bottom:
            return Zone(rect: CGRect(x: segment.lowerBound, y: frame.maxY - edgeDepth,
                                     width: length, height: edgeDepth + 1),
                        nudge: CGVector(dx: 0, dy: -edgeDepth))
        case .left:
            return Zone(rect: CGRect(x: frame.minX - 1, y: segment.lowerBound,
                                     width: edgeDepth + 1, height: length),
                        nudge: CGVector(dx: edgeDepth, dy: 0))
        case .right:
            return Zone(rect: CGRect(x: frame.maxX - edgeDepth, y: segment.lowerBound,
                                     width: edgeDepth + 1, height: length),
                        nudge: CGVector(dx: -edgeDepth, dy: 0))
        }
    }

    /// The two ends of the Dock edge that are real screen corners, where the
    /// pointer stops in both directions, and that have a Hot Corner action.
    static func cornerSquares(of display: DockDisplayLockDisplay,
                              orientation: DockDisplayLockOrientation,
                              others: [DockDisplayLockDisplay],
                              hotCorners: Set<DockDisplayLockCorner>) -> [Zone] {
        let frame = display.frame
        let ends: [DockDisplayLockCorner]
        switch orientation {
        case .bottom: ends = [.bottomLeft, .bottomRight]
        case .left: ends = [.topLeft, .bottomLeft]
        case .right: ends = [.topRight, .bottomRight]
        }
        let nudge: CGVector
        switch orientation {
        case .bottom: nudge = CGVector(dx: 0, dy: -edgeDepth)
        case .left: nudge = CGVector(dx: edgeDepth, dy: 0)
        case .right: nudge = CGVector(dx: -edgeDepth, dy: 0)
        }
        return ends.compactMap { corner in
            guard hotCorners.contains(corner) else { return nil }
            let left = corner == .topLeft || corner == .bottomLeft
            let top = corner == .topLeft || corner == .topRight
            let x = left ? frame.minX : frame.maxX - cornerSize
            let y = top ? frame.minY : frame.maxY - cornerSize
            // Just past the corner on each side: another display there means
            // the pointer slides on instead of stopping in the corner.
            let beyondSide = CGPoint(x: left ? frame.minX - 0.5 : frame.maxX + 0.5, y: y + cornerSize / 2)
            let beyondEnd = CGPoint(x: x + cornerSize / 2, y: top ? frame.minY - 0.5 : frame.maxY + 0.5)
            guard !others.contains(where: { $0.frame.contains(beyondSide) || $0.frame.contains(beyondEnd) })
            else { return nil }
            return Zone(rect: CGRect(x: left ? x - 1 : x, y: top ? y - 1 : y,
                                     width: cornerSize + 1, height: cornerSize + 1),
                        nudge: nudge)
        }
    }

    // MARK: - Where the Dock is

    /// The display the Dock sits on, from the frame of its icon list. The
    /// list's short-axis position can be reported off by tens of points
    /// (seen on macOS 27), so the display is picked along the long axis and
    /// then by the nearest Dock edge.
    static func display(holdingDockFrame dockFrame: CGRect,
                        orientation: DockDisplayLockOrientation,
                        displays: [DockDisplayLockDisplay]) -> CGDirectDisplayID? {
        guard !dockFrame.isEmpty else { return nil }
        switch orientation {
        case .bottom:
            return displays.filter { $0.frame.minX <= dockFrame.midX && dockFrame.midX < $0.frame.maxX }
                .min { abs($0.frame.maxY - dockFrame.maxY) < abs($1.frame.maxY - dockFrame.maxY) }?.id
        case .left:
            return displays.filter { $0.frame.minY <= dockFrame.midY && dockFrame.midY < $0.frame.maxY }
                .min { abs($0.frame.minX - dockFrame.minX) < abs($1.frame.minX - dockFrame.minX) }?.id
        case .right:
            return displays.filter { $0.frame.minY <= dockFrame.midY && dockFrame.midY < $0.frame.maxY }
                .min { abs($0.frame.maxX - dockFrame.maxX) < abs($1.frame.maxX - dockFrame.maxX) }?.id
        }
    }

    // MARK: - Calling the Dock over

    /// The pointer path that calls the Dock to `display`: a short approach
    /// toward the middle of its Dock edge, then a few presses against it,
    /// each carrying the push into the edge macOS reads as a request.
    struct Step: Equatable {
        let point: CGPoint
        let delta: CGVector
    }

    static func summonPath(to display: DockDisplayLockDisplay,
                           orientation: DockDisplayLockOrientation,
                           others: [DockDisplayLockDisplay] = []) -> [Step] {
        let frame = display.frame
        // Press a hard segment: the middle of the full edge may sit against
        // another display, and that press would call the Dock over there.
        let segments = hardSegments(of: display, orientation: orientation, others: others)
        guard let segment = segments.max(by: {
            ($0.upperBound - $0.lowerBound) < ($1.upperBound - $1.lowerBound)
        }) else { return [] }
        let mid = (segment.lowerBound + segment.upperBound) / 2
        let edge: CGPoint
        let inward: CGVector
        switch orientation {
        case .bottom:
            edge = CGPoint(x: mid, y: frame.maxY - 1)
            inward = CGVector(dx: 0, dy: 1)
        case .left:
            edge = CGPoint(x: frame.minX, y: mid)
            inward = CGVector(dx: -1, dy: 0)
        case .right:
            edge = CGPoint(x: frame.maxX - 1, y: mid)
            inward = CGVector(dx: 1, dy: 0)
        }
        let approachLength: CGFloat = 40
        let approachSteps = 8
        let approach = (0..<approachSteps).map { index -> Step in
            let remaining = approachLength * CGFloat(approachSteps - 1 - index) / CGFloat(approachSteps - 1)
            let point = CGPoint(x: edge.x - inward.dx * remaining, y: edge.y - inward.dy * remaining)
            let step = approachLength / CGFloat(approachSteps - 1)
            return Step(point: point, delta: CGVector(dx: inward.dx * step, dy: inward.dy * step))
        }
        let presses = Array(repeating: Step(point: edge, delta: CGVector(dx: inward.dx * 4, dy: inward.dy * 4)),
                            count: 10)
        return approach + presses
    }
}
