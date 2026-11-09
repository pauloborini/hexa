// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Pins "Onde está o espaço": the measured space map (ranking, volume, refusals
/// and the estimated system data) and the fixed block of known locations.
/// Everything is measured only on the user's explicit request, never by a scan;
/// sizes use the allocated-size helper; the map never offers a removal; and
/// nothing is counted twice. Every test runs on a scratch home under the
/// temporary directory, with a scratch applications folder of its own: the real
/// home and the real /Applications are never measured here.
final class SpaceInventoryTests: XCTestCase {
    /// A guard for the test itself, never a product deadline: the measurement
    /// has no deadline of its own, so a loaded machine may take far longer than
    /// a minute to finish. See `testLoadedCompletion`.
    private static let testDeadline: TimeInterval = 600

    /// Said when a wait runs past the guard, so a failure names the guard
    /// instead of reading like a product timeout.
    private static let deadlineMessage =
        "the measurement must finish within the test guard of \(Int(testDeadline)) s, "
        + "which only exists in the test: the product has no deadline"

    /// One scratch home built once and shared by the tests that only read it:
    /// building the same tree in every test costs more than measuring it.
    private static let sharedHome: String = {
        let root = makeHome("shared")
        try? write(1024, to: ".codex/session.bin", in: root)
        try? write(1024, to: ".ollama/models/blob.bin", in: root)
        return root
    }()

    /// An empty applications folder: the map's third root. Tests point the walk
    /// here so no test measures the machine it runs on.
    private static let emptyApplications: String = makeHome("apps")

    override class func tearDown() {
        for path in [sharedHome, emptyApplications] {
            try? FileManager.default.removeItem(atPath: path)
        }
        super.tearDown()
    }

    /// A unique scratch folder under the system temporary directory.
    private static func makeHome(_ label: String) -> String {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hexa-space-\(label)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.standardizedFileURL.path
    }

    /// A unique scratch home under the system temporary directory, removed
    /// when the test ends.
    private func makeFixtureHome() throws -> String {
        let root = Self.makeHome("fixture")
        addTeardownBlock { try? FileManager.default.removeItem(atPath: root) }
        return root
    }

    /// Writes a file of exactly `bytes` zero bytes under `home`.
    private func write(_ bytes: Int, to relativePath: String, in home: String) throws {
        try Self.write(bytes, to: relativePath, in: home)
    }

    private static func write(_ bytes: Int, to relativePath: String, in home: String) throws {
        let url = URL(fileURLWithPath: home + "/" + relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data(count: bytes).write(to: url)
    }

    /// Writes `folders` first-level folders, each holding `files` small files one
    /// level down, so a walk has enough folders to be caught mid flight.
    private func writeSlowTree(folders: Int, files: Int, in home: String) throws {
        for folder in 0..<folders {
            for file in 0..<files {
                try write(1024, to: String(format: "tree%02d/data/file%02d.bin", folder, file), in: home)
            }
        }
    }

    /// Runs the real scan entry point over `home` and waits for its results.
    /// The scan hops back to the main queue, so the run loop is pumped.
    private func runScan(attended: Bool, home: String) throws -> JunkCleaner {
        let cleaner = JunkCleaner.shared
        cleaner.reset()
        addTeardownBlock { cleaner.reset() }
        try scanAndWait(cleaner, attended: attended, home: home)
        return cleaner
    }

    /// Starts a scan without resetting first, and waits for its results.
    private func scanAndWait(_ cleaner: JunkCleaner, attended: Bool, home: String) throws {
        cleaner.scan(attended: attended, home: home)
        let deadline = Date().addingTimeInterval(Self.testDeadline)
        while cleaner.phase != .results, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        XCTAssertEqual(cleaner.phase, .results, Self.deadlineMessage)
    }

    /// Requests the on-demand measurement over `home`, the way the button does,
    /// and waits for its rows.
    private func measure(_ cleaner: JunkCleaner, home: String,
                         applications: String = SpaceInventoryTests.emptyApplications)
        throws -> [SpaceInventoryRow] {
        cleaner.measureSpaceInventory(home: home, applications: applications)
        XCTAssertTrue(cleaner.spaceInventoryIsComputing, "the request starts the measurement")
        let deadline = Date().addingTimeInterval(Self.testDeadline)
        while cleaner.spaceInventoryIsComputing, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        XCTAssertFalse(cleaner.spaceInventoryIsComputing, Self.deadlineMessage)
        return try XCTUnwrap(cleaner.spaceInventory)
    }

    /// Requests the measurement and waits for it, returning the published map.
    private func measureMap(_ cleaner: JunkCleaner, home: String,
                            applications: String = SpaceInventoryTests.emptyApplications)
        throws -> SpaceMap {
        _ = try measure(cleaner, home: home, applications: applications)
        return try XCTUnwrap(cleaner.spaceMap)
    }

    /// Kilobytes of `path` as `du -sk` reports them: the reference the sizes
    /// are checked against. Only this suite runs `du`, once; the app never does.
    private func duKilobytes(_ path: String) throws -> Double {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sk", path]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let first = output.split(whereSeparator: { $0 == "\t" || $0 == " " }).first ?? ""
        return try XCTUnwrap(Double(first))
    }

    /// The path macOS reports for a folder of the scratch tree: the walk
    /// enumerates the same folder under `/private/var`, so both sides of a
    /// comparison are written in that one form.
    private func canonicalPath(_ path: String) -> String {
        var value = path
        if value.hasPrefix("/var/") { value = "/private" + value }
        while value.count > 1 && value.hasSuffix("/") { value.removeLast() }
        return value
    }

    /// Compares two paths after both are written the way the walk reports them.
    private func samePath(_ a: String, _ b: String) -> Bool {
        canonicalPath(a) == canonicalPath(b)
    }

    /// The source of a file of this repository, for the rules that only the
    /// view's own code can prove.
    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests/hexaTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repository root
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// Starts a busy loop, so a measurement can be checked under load.
    private func spawnBusyLoop() throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "while :; do :; done"]
        try process.run()
        return process
    }

    // MARK: DoD 2: a scan never builds the inventory

    func testUnattendedScanProducesNoInventoryRows() throws {
        let cleaner = try runScan(attended: false, home: Self.sharedHome)

        XCTAssertNil(cleaner.spaceInventory)
        XCTAssertNil(cleaner.spaceMap)
    }

    func testAttendedScanBuildsNoRowsAndTheRequestedMeasureListsOnlyExistingLocations() throws {
        let cleaner = try runScan(attended: true, home: Self.sharedHome)
        XCTAssertNil(cleaner.spaceInventory, "the attended scan computes no inventory")
        XCTAssertNil(cleaner.spaceMap, "the attended scan computes no map")

        // Positive control: the on-demand measure lists the locations that exist.
        let rows = try measure(cleaner, home: Self.sharedHome)
        XCTAssertEqual(rows.map(\.location), [.ollama, .codex])
    }

    // MARK: DoD 1: the row type has no selection and never enters the cleanable items

    func testRowHasNoSelectionFlagAndNoCleanableItemOverlapsIt() throws {
        let cleaner = try runScan(attended: true, home: Self.sharedHome)
        let rows = try measure(cleaner, home: Self.sharedHome)
        XCTAssertFalse(rows.isEmpty)

        XCTAssertFalse(Mirror(reflecting: rows[0]).children.contains { $0.label == "include" })
        XCTAssertFalse(cleaner.items.contains { item in
            rows.contains { SpaceInventory.overlaps(item.url.standardizedFileURL.path, $0.url.path) }
        })
    }

    // MARK: Lifecycle: the measured rows stay until a new scan or a reset

    func testNewScanAndResetClearTheMeasuredRows() throws {
        let cleaner = try runScan(attended: true, home: Self.sharedHome)
        XCTAssertFalse(try measure(cleaner, home: Self.sharedHome).isEmpty)

        try scanAndWait(cleaner, attended: true, home: Self.sharedHome)
        XCTAssertNil(cleaner.spaceInventory, "a new scan clears the measured rows")
        XCTAssertNil(cleaner.spaceMap, "a new scan clears the measured map")

        _ = try measure(cleaner, home: Self.sharedHome)
        cleaner.reset()
        XCTAssertNil(cleaner.spaceInventory, "a reset clears the measured rows")
        XCTAssertNil(cleaner.spaceMap, "a reset clears the measured map")
        XCTAssertFalse(cleaner.spaceInventoryIsComputing)
    }

    // MARK: DoD 3: sizes equal the allocated-size helper and match du -sk

    func testSizeIsTheAllocatedHelperValueAndMatchesDuWithinFivePercent() throws {
        let home = try makeFixtureHome()
        try write(100_000, to: ".codex/a.bin", in: home)
        try write(250_000, to: ".codex/nested/b.bin", in: home)
        let url = URL(fileURLWithPath: home + "/.codex", isDirectory: true)

        let rows = SpaceInventory.rows(home: home, excluding: [])
        let row = try XCTUnwrap(rows.first { $0.location == .codex })

        XCTAssertEqual(row.size, JunkCleaner.directorySize(of: url, fm: .default))
        let reference = try duKilobytes(url.path)
        let rowKilobytes = Double(row.size) / 1024
        XCTAssertLessThanOrEqual(abs(rowKilobytes - reference), reference * 0.05,
                                 "hexa \(rowKilobytes) KB, du \(reference) KB")
    }

    // MARK: Simulator row: the total of the Devices folder

    func testSimulatorRowIsTheTotalOfTheDevicesFolder() throws {
        let home = try makeFixtureHome()
        try write(4096, to: "Library/Developer/CoreSimulator/Devices/UDID-1/data.bin", in: home)
        try write(8192, to: "Library/Developer/CoreSimulator/Devices/UDID-2/data.bin", in: home)
        let devices = URL(fileURLWithPath: home + "/Library/Developer/CoreSimulator/Devices",
                          isDirectory: true)

        let cleaner = try runScan(attended: true, home: home)
        let rows = try measure(cleaner, home: home)
        let row = try XCTUnwrap(rows.first { $0.location == .simulators })

        XCTAssertEqual(row.size, JunkCleaner.directorySize(of: devices, fm: .default))
        XCTAssertEqual(SpaceInventory.Location.simulators.group, .simulators)
    }

    // MARK: Overlap: a cleanable item of the same scan removes the row it covers

    func testInventoryRowIsDroppedWhenACleanableItemCoversIt() throws {
        let home = try makeFixtureHome()
        try write(1024, to: ".codex/session.bin", in: home)
        try write(1024, to: ".ollama/models/blob.bin", in: home)
        try write(1024, to: "Library/Application Support/Claude/vm_bundles/vm.bin", in: home)

        // An ancestor of the VM folder, and the exact codex folder.
        let claudeAncestor = JunkCleaner.Item(
            url: URL(fileURLWithPath: home + "/Library/Application Support/Claude"),
            category: .leftovers, size: 0, detail: "", recommended: false)
        let codexExact = JunkCleaner.Item(
            url: URL(fileURLWithPath: home + "/.codex"),
            category: .leftovers, size: 0, detail: "", recommended: false)

        let locations = SpaceInventory.rows(home: home, excluding: [claudeAncestor, codexExact])
            .map(\.location)

        XCTAssertEqual(locations, [.ollama])
    }

    func testSymbolicLinkLocationIsNotInventoried() throws {
        let home = try makeFixtureHome()
        try write(1024, to: "elsewhere/session.bin", in: home)
        try FileManager.default.createSymbolicLink(atPath: home + "/.codex",
                                                   withDestinationPath: home + "/elsewhere")

        XCTAssertTrue(SpaceInventory.rows(home: home, excluding: []).isEmpty)
    }

    func testOverlapMeansSamePathOrOneInsideTheOther() {
        XCTAssertTrue(SpaceInventory.overlaps("/a/b", "/a/b"))
        XCTAssertTrue(SpaceInventory.overlaps("/a", "/a/b"))
        XCTAssertTrue(SpaceInventory.overlaps("/a/b/c", "/a/b"))
        XCTAssertFalse(SpaceInventory.overlaps("/a/bc", "/a/b"))
        XCTAssertFalse(SpaceInventory.overlaps("/a/b", "/a/c"))
    }

    // MARK: Cancellation: a cancelled measurement measures nothing further

    func testCancelledMeasurementReturnsNoRowsAndALiveOneReturnsTheRow() throws {
        let home = try makeFixtureHome()
        try write(1024, to: ".codex/session.bin", in: home)
        let url = URL(fileURLWithPath: home + "/.codex", isDirectory: true)

        let cancelled = CleanerSupport.ScanCancellation()
        cancelled.cancel()
        XCTAssertTrue(SpaceInventory.rows(home: home, excluding: [], cancellation: cancelled).isEmpty)
        XCTAssertEqual(JunkCleaner.directorySize(of: url, fm: .default, cancellation: cancelled), 0)

        let live = CleanerSupport.ScanCancellation()
        let rows = SpaceInventory.rows(home: home, excluding: [], cancellation: live)
        XCTAssertEqual(rows.map(\.location), [.codex])
        XCTAssertGreaterThan(JunkCleaner.directorySize(of: url, fm: .default, cancellation: live), 0)
    }

    func testResetCancelsTheRunningMeasurementAndClearsItsState() throws {
        let home = try makeFixtureHome()
        try write(1024, to: "docs/session.bin", in: home)
        let cleaner = JunkCleaner.shared
        cleaner.reset()
        addTeardownBlock { cleaner.reset() }

        // Complete one measurement first, so the reset has measured rows to clear.
        cleaner.measureSpaceInventory(home: home, applications: Self.emptyApplications)
        let completeDeadline = Date().addingTimeInterval(Self.testDeadline)
        while cleaner.spaceInventoryIsComputing, Date() < completeDeadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        XCTAssertFalse(cleaner.spaceInventoryIsComputing, Self.deadlineMessage)
        XCTAssertNotNil(cleaner.spaceInventory, "the completed measurement publishes its rows")
        XCTAssertNotNil(cleaner.spaceMap, "the completed measurement publishes its map")

        // The second measurement is still running when the reset arrives.
        cleaner.measureSpaceInventory(home: home, applications: Self.emptyApplications)
        let cancellation = try XCTUnwrap(cleaner.spaceInventoryCancellation)
        cleaner.reset()

        XCTAssertTrue(cancellation.isCancelled, "a reset cancels the measurement it started")
        XCTAssertFalse(cleaner.spaceInventoryIsComputing)
        XCTAssertNil(cleaner.spaceInventory)
        XCTAssertNil(cleaner.spaceMap)
    }

    // MARK: AC-1.1.1: the ranking of the measured roots

    func testMapSnapshot() throws {
        let home = try makeFixtureHome()
        let applications = try makeFixtureHome()

        // Twelve home folders, each one smaller than the one before it.
        for step in 1...12 {
            try write(step * 20_000, to: String(format: "home%02d/data.bin", step), in: home)
        }
        // Two Library children: the first is larger than every home child, so a
        // ranking that omitted a big Library child would show another folder first.
        try write(400_000, to: "Library/Application Support/data.bin", in: home)
        try write(10_000, to: "Library/Preferences/data.bin", in: home)
        // A first-level file is not a folder and never becomes an entry.
        try write(10_000, to: "stray.bin", in: home)
        // Applications children come from the applications root.
        try write(120_000, to: "AppA.app/Contents/a.bin", in: applications)
        try write(30_000, to: "AppB.app/Contents/b.bin", in: applications)
        // A link that points outside every measured root: it is never followed.
        let outside = try makeFixtureHome()
        try write(9_000_000, to: "huge.bin", in: outside)
        let outsideResolved = canonicalPath(outside)
        try FileManager.default.createSymbolicLink(atPath: home + "/linked",
                                                   withDestinationPath: outside)

        let cleaner = JunkCleaner.shared
        cleaner.reset()
        addTeardownBlock { cleaner.reset() }
        let map = try measureMap(cleaner, home: home, applications: applications)

        // Descending by size, and at most ten entries.
        let sizes = map.entries.map(\.size)
        XCTAssertEqual(sizes, sizes.sorted(by: >), "the ranking is descending by size")
        XCTAssertGreaterThan(map.entries.count, SpaceMap.rankingLimit)
        XCTAssertEqual(map.ranking.count, SpaceMap.rankingLimit)
        XCTAssertEqual(map.ranking, Array(map.entries.prefix(SpaceMap.rankingLimit)))

        // The biggest Library child ranks first, and neither Library nor the home
        // folder itself is an entry, so no byte is summed twice.
        XCTAssertNotNil(map.entries.first { samePath($0.url.path, home + "/Library/Application Support") })
        XCTAssertEqual(map.entries.first?.size, map.entries.map(\.size).max())
        XCTAssertFalse(map.entries.contains { samePath($0.url.path, home + "/Library") })
        XCTAssertFalse(map.entries.contains { samePath($0.url.path, home) })

        // Folders only, and no followed link: the 9 MB behind the link is absent.
        XCTAssertFalse(map.entries.contains { $0.url.lastPathComponent == "stray.bin" })
        XCTAssertFalse(map.entries.contains { $0.url.lastPathComponent == "linked" })
        XCTAssertFalse(map.entries.contains { $0.url.path.hasPrefix(outsideResolved) })
        XCTAssertTrue(map.entries.allSatisfy { $0.size < 500_000 },
                      "no entry carries the bytes behind the symbolic link")

        // Every measured folder lives on the volume of the home it came from: an
        // outside volume is never walked.
        let homeDevice = try XCTUnwrap(SpaceInventory.device(of: URL(fileURLWithPath: home)))
        let applicationsDevice = try XCTUnwrap(SpaceInventory.device(of: URL(fileURLWithPath: applications)))
        XCTAssertEqual(homeDevice, applicationsDevice)
        for entry in map.entries {
            XCTAssertEqual(SpaceInventory.device(of: entry.url), homeDevice,
                           "\(entry.url.path) is not on the measured volume")
        }

        XCTAssertFalse(map.cancelled)
        XCTAssertTrue(map.denials.isEmpty, "a readable tree has no refusal")
    }

    // MARK: AC-1.1.1: a nested mount point is never walked

    /// Two paths on different volumes report different devices. `/dev` (devfs)
    /// is mounted on every Mac. The Data volume is the second choice, but only
    /// where it reports a device of its own: on some systems it shares the
    /// device of `/`, and then nothing here can tell two volumes apart.
    func testDeviceTellsAnotherVolumeApart() throws {
        let root = try XCTUnwrap(SpaceInventory.device(of: URL(fileURLWithPath: "/")))
        let other: (path: String, device: dev_t)
        if let devfs = SpaceInventory.device(of: URL(fileURLWithPath: "/dev")) {
            other = ("/dev", devfs)
        } else if let data = SpaceInventory.device(of: URL(fileURLWithPath: "/System/Volumes/Data")),
                  data != root {
            other = ("/System/Volumes/Data", data)
        } else {
            throw XCTSkip("no second volume to compare with /: /dev is unreadable and "
                          + "/System/Volumes/Data does not report a device of its own")
        }
        XCTAssertNotEqual(other.device, root, "\(other.path) is on a volume of its own, not on /")
    }

    /// A mount point inside a measured root is another volume: the walk skips
    /// it and its contents, and it is not a refusal. A mount cannot be created
    /// inside a unit test, so the rule is pinned on the walk's own source: the
    /// root's device is read from the root, and in one block the device of each
    /// directory is compared with it and the descendants are skipped.
    func testMeasuredSizeSkipsAnotherVolumeWithoutRecordingIt() throws {
        let body = try measuredSizeSource()

        XCTAssertNotNil(body.range(of: #"device\s*\(\s*of\s*:\s*url\s*\)"#, options: .regularExpression),
                        "the root's device is read from the root")
        let readItem = try XCTUnwrap(body.range(of: #"let\s+itemDevice\s*=\s*device\s*\(\s*of\s*:\s*item\s*\)"#,
                                                options: .regularExpression),
                                     "each directory's device is read once, for the comparison")
        let pattern = #"itemDevice\s*!=\s*rootDevice\s*\{\s*enumerator\.skipDescendants\(\)\s*continue\s*\}"#
        XCTAssertNotNil(body.range(of: pattern, options: .regularExpression,
                                   range: readItem.upperBound..<body.endIndex),
                        "measuredSize must compare each directory's device with the root's and, when they differ, skip its descendants and continue, without recording a denial")
    }

    /// A directory whose device cannot be read is a refusal, not a mount point:
    /// the walk records it as unavailable and skips its contents, so the map is
    /// marked partial and never shows zero for a folder it could not read.
    /// Pinned on the source, since a directory that stat cannot read is not
    /// reproducible inside a unit test.
    func testMeasuredSizeRecordsDirectoryWithoutDeviceAsDenial() throws {
        let body = try measuredSizeSource()
        let pattern = #"device\(of: item\)\s*else\s*\{\s*denials\.append\(SpaceMapDenial\(url: item, reason: \.unavailable\)\)\s*enumerator\.skipDescendants\(\)\s*continue\s*\}"#
        XCTAssertNotNil(body.range(of: pattern, options: .regularExpression),
                        "measuredSize must record a .unavailable denial for a directory whose device is nil, skip its descendants and continue")
    }

    /// A top-level folder whose device cannot be read is the same refusal as a
    /// directory inside the walk: the map records it as unavailable and does not
    /// measure it. A real mount point stays silent. Pinned on the source, since
    /// a folder that stat cannot read is not reproducible inside a unit test.
    func testMapRecordsTopLevelFolderWithoutDeviceAsDenial() throws {
        let spaceSource = try source("Sources/Hexa/Services/Cleaner/SpaceInventory.swift")
        let start = try XCTUnwrap(spaceSource.range(of: "func measure(_ folder: URL"))
        let end = try XCTUnwrap(spaceSource.range(of: "// `~/Library` is left out",
                                                  range: start.upperBound..<spaceSource.endIndex))
        let body = String(spaceSource[start.lowerBound..<end.lowerBound])
            .replacingOccurrences(of: ";", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        let pattern = #"device\(of: folder\)\s*else\s*\{\s*denials\.append\(SpaceMapDenial\(url: folder, reason: \.unavailable\)\)\s*return\s*\}"#
        XCTAssertNotNil(body.range(of: pattern, options: .regularExpression),
                        "the map must record a .unavailable denial for a top-level folder whose device is nil, and return without measuring it")
    }

    /// The source of `SpaceInventory.measuredSize`, with statement semicolons
    /// read as separators and every whitespace run collapsed to one space, so
    /// the patterns do not depend on how the code is laid out on its lines.
    private func measuredSizeSource() throws -> String {
        let spaceSource = try source("Sources/Hexa/Services/Cleaner/SpaceInventory.swift")
        let start = try XCTUnwrap(spaceSource.range(of: "static func measuredSize"))
        let end = try XCTUnwrap(spaceSource.range(of: "static func reason(for",
                                                  range: start.upperBound..<spaceSource.endIndex))
        return String(spaceSource[start.lowerBound..<end.lowerBound])
            .replacingOccurrences(of: ";", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    // MARK: AC-1.1.2: progress, cancel and restart

    func testProgressCancelAndRestart() throws {
        let slowHome = try makeFixtureHome()
        try writeSlowTree(folders: 30, files: 30, in: slowHome)
        let smallHome = try makeFixtureHome()
        try write(10_000, to: "only/a.bin", in: smallHome)

        let cleaner = JunkCleaner.shared
        cleaner.reset()
        addTeardownBlock { cleaner.reset() }

        // At least one finished folder is published before the walk ends.
        cleaner.measureSpaceInventory(home: slowHome, applications: Self.emptyApplications)
        var sawFolderWhileComputing = false
        let deadline = Date().addingTimeInterval(Self.testDeadline)
        while cleaner.spaceInventoryIsComputing, Date() < deadline {
            if let map = cleaner.spaceMap, !map.entries.isEmpty {
                sawFolderWhileComputing = true
            }
            RunLoop.main.run(until: Date().addingTimeInterval(0.002))
        }
        XCTAssertFalse(cleaner.spaceInventoryIsComputing, Self.deadlineMessage)
        XCTAssertTrue(sawFolderWhileComputing,
                      "a finished folder must publish while the walk still runs")

        // A second run is cancelled mid flight: the last photograph stays and is
        // marked partial.
        cleaner.reset()
        cleaner.measureSpaceInventory(home: slowHome, applications: Self.emptyApplications)
        var sawSnapshotMidFlight = false
        while cleaner.spaceInventoryIsComputing, Date() < deadline {
            if cleaner.spaceMap != nil {
                sawSnapshotMidFlight = true
                break
            }
            RunLoop.main.run(until: Date().addingTimeInterval(0.002))
        }
        XCTAssertTrue(sawSnapshotMidFlight, "a cancel needs a photograph of the run to keep")

        // Nothing pumps the run loop between this read and the cancel, so the
        // photograph is exactly what the screen shows when Cancel is pressed.
        let photograph = try XCTUnwrap(cleaner.spaceMap)
        let staleToken = cleaner.spaceInventoryToken
        cleaner.cancelSpaceInventory()

        XCTAssertFalse(cleaner.spaceInventoryIsComputing, "a cancel ends the run at once")
        XCTAssertEqual(cleaner.spaceMap, photograph.markedCancelled(),
                       "a cancel keeps what was measured and marks it partial")

        // A callback of the run that was stopped never lands on the map.
        let stale = SpaceMap(
            entries: [SpaceMapEntry(url: URL(fileURLWithPath: "/stale"), size: 4096, partial: false)],
            denials: [], volume: photograph.volume, systemData: nil, cancelled: false)
        cleaner.publishSpaceMap(stale, token: staleToken)
        XCTAssertEqual(cleaner.spaceMap, photograph.markedCancelled(),
                       "a stale callback must not overwrite the map")

        // A new run publishes its own complete map.
        let restart = try measureMap(cleaner, home: smallHome)
        XCTAssertEqual(restart.entries.count, 1)
        XCTAssertTrue(samePath(try XCTUnwrap(restart.entries.first).url.path, smallHome + "/only"))
        XCTAssertFalse(restart.cancelled, "a completed run is not partial")
    }

    /// AC-1.1.2: cancelling a remesure that has not published yet must keep the
    /// previous complete map. Marking that completed photograph as cancelled
    /// would tell the user a finished ranking is partial.
    func testRemeasureCancelDoesNotMarkPreviousCompleteMap() throws {
        let home = try makeFixtureHome()
        try write(20_000, to: "docs/a.bin", in: home)

        let cleaner = JunkCleaner.shared
        cleaner.reset()
        addTeardownBlock { cleaner.reset() }
        let complete = try measureMap(cleaner, home: home)
        XCTAssertFalse(complete.cancelled)
        XCTAssertFalse(complete.entries.isEmpty)

        let slowHome = try makeFixtureHome()
        try writeSlowTree(folders: 30, files: 30, in: slowHome)
        cleaner.measureSpaceInventory(home: slowHome, applications: Self.emptyApplications)
        XCTAssertTrue(cleaner.spaceInventoryIsComputing)
        // Nothing pumps the run loop: the completed photograph is still what
        // the screen shows, and the new run has not published a folder of its own.
        XCTAssertEqual(cleaner.spaceMap?.cancelled, false)
        cleaner.cancelSpaceInventory()

        XCTAssertFalse(cleaner.spaceInventoryIsComputing)
        XCTAssertEqual(cleaner.spaceMap?.cancelled, false,
                       "a remesure cancelled before its first folder must keep the previous complete map")
        XCTAssertEqual(cleaner.spaceMap?.entries.map(\.url.path), complete.entries.map(\.url.path))
    }

    // MARK: AC-1.1.3: refusals, volume and the estimated system data

    func testDeniedDescendant() throws {
        let home = try makeFixtureHome()
        try write(60_000, to: "open/readable.bin", in: home)
        try write(60_000, to: "open/locked/hidden.bin", in: home)
        try write(90_000, to: "Library/Caches/cache.bin", in: home)
        let locked = home + "/open/locked"
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked)
        addTeardownBlock {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked)
        }

        let cleaner = JunkCleaner.shared
        cleaner.reset()
        addTeardownBlock { cleaner.reset() }
        let map = try measureMap(cleaner, home: home)

        // The refused path is listed with its path and with a reason of the
        // app's own, not the system's localized message.
        let denial = try XCTUnwrap(map.denials.first { samePath($0.url.path, locked) })
        XCTAssertEqual(denial.reason, .accessDenied)
        XCTAssertEqual(SpaceInventory.reason(for: NSError(domain: NSPOSIXErrorDomain,
                                                          code: Int(EACCES))), .accessDenied)
        XCTAssertEqual(SpaceInventory.reason(for: NSError(domain: NSPOSIXErrorDomain,
                                                          code: Int(ENOENT))), .unavailable)

        // The ancestor keeps the bytes it could measure and is marked partial; a
        // refusal is never a complete zero.
        let open = try XCTUnwrap(map.entries.first { samePath($0.url.path, home + "/open") })
        XCTAssertTrue(open.partial, "a denied descendant makes the ancestor partial")
        XCTAssertGreaterThan(open.size, 0, "the measured bytes stay")

        // The volume is shown, used is the difference of the same volume's
        // figures, and the estimate is the sum of the measured Library children,
        // never the volume residual.
        XCTAssertTrue(map.volume.isAvailable)
        let total = try XCTUnwrap(map.volume.total)
        let free = try XCTUnwrap(map.volume.free)
        XCTAssertEqual(map.volume.used, total - free)
        let libraryRoot = canonicalPath(home + "/Library")
        let libraryChildren = map.entries.filter { canonicalPath($0.url.path).hasPrefix(libraryRoot + "/") }
        XCTAssertFalse(libraryChildren.isEmpty,
                       "root \(libraryRoot) entries \(map.entries.map(\.url.path))")
        XCTAssertEqual(map.systemData?.size, libraryChildren.reduce(Int64(0)) { $0 + $1.size })
        XCTAssertEqual(map.systemData?.partial, true)
        XCTAssertLessThanOrEqual(map.systemData?.size ?? 0, map.volume.used ?? 0)

        // The warning is strictly below 10 percent free.
        XCTAssertFalse(SpaceVolume(total: 1000, free: 100).lowSpace, "exactly 10 percent is not low")
        XCTAssertTrue(SpaceVolume(total: 1000, free: 99).lowSpace)
        XCTAssertFalse(SpaceVolume(total: 0, free: 0).lowSpace)

        // A refused volume read is unavailable, never zero.
        let unavailable = SpaceVolume(total: nil, free: nil)
        XCTAssertFalse(unavailable.isAvailable)
        XCTAssertNil(unavailable.used)
        XCTAssertNil(unavailable.total)
        XCTAssertFalse(unavailable.lowSpace)
    }

    // MARK: AC-1.1.4: the map never removes, and leaving stops the reading

    func testNoBackgroundOrMapRemoval() throws {
        let home = try makeFixtureHome()
        try write(20_000, to: "pictures/a.bin", in: home)

        let cleaner = JunkCleaner.shared
        cleaner.reset()
        addTeardownBlock { cleaner.reset() }
        let map = try measureMap(cleaner, home: home)
        XCTAssertFalse(map.ranking.isEmpty)

        // No selection flag, and no map entry is a cleanable item.
        XCTAssertFalse(Mirror(reflecting: map.ranking[0]).children.contains { $0.label == "include" })
        XCTAssertFalse(cleaner.items.contains { item in
            map.entries.contains { SpaceInventory.overlaps(item.url.standardizedFileURL.path, $0.url.path) }
        })

        // The section offers no removal, and the exit cancels the reading.
        let view = try source("Sources/Hexa/UI/Cleaner/CleanerView.swift")
        let sectionStart = try XCTUnwrap(view.range(of: "private var spaceInventorySection"))
        let sectionEnd = view.range(of: "private var resultsFooter",
                                    range: sectionStart.lowerBound..<view.endIndex)
        let section = String(view[sectionStart.lowerBound..<(sectionEnd?.lowerBound ?? view.endIndex)])
        for forbidden in ["cleanSelected", "trashItem", "removeItem", "mayRemove"] {
            XCTAssertFalse(section.contains(forbidden), "the map must not offer \(forbidden)")
        }
        let exit = try XCTUnwrap(view.range(of: ".onDisappear {"))
        XCTAssertTrue(view[exit.upperBound...].prefix(400).contains("cancelSpaceInventory()"),
                      "leaving the surface must stop the reading")

        // What the exit does: a finished map is not marked partial by an exit
        // that found nothing running, and no run survives the exit.
        XCTAssertEqual(cleaner.spaceMap?.cancelled, false)
        cleaner.cancelSpaceInventory()
        XCTAssertEqual(cleaner.spaceMap?.cancelled, false,
                       "an idle exit must not turn a complete result into a partial one")
        XCTAssertFalse(cleaner.spaceInventoryIsComputing)
    }

    // MARK: AC-1.1.5: completion under load, with only the test guard

    func testLoadedCompletion() throws {
        let home = try makeFixtureHome()
        try write(200_000, to: "docs/a.bin", in: home)
        try write(100_000, to: "Library/Caches/b.bin", in: home)

        // Load: a few busy loops run while the walk measures.
        let load = try (0..<3).map { _ in try spawnBusyLoop() }
        defer { load.forEach { $0.terminate() } }

        let cleaner = JunkCleaner.shared
        cleaner.reset()
        addTeardownBlock { cleaner.reset() }
        let map = try measureMap(cleaner, home: home)

        XCTAssertFalse(map.cancelled, "a loaded machine must not stop the walk")
        XCTAssertEqual(map.entries.count, 2)
        XCTAssertFalse(cleaner.spaceInventoryIsComputing)

        // No product deadline: the measurement carries no timer and no deadline.
        let cleanerSource = try source("Sources/Hexa/Services/Cleaner/JunkCleaner.swift")
        let start = try XCTUnwrap(cleanerSource.range(of: "func measureSpaceInventory"))
        let body = String(cleanerSource[start.lowerBound...].prefix(2500))
        for forbidden in ["Timer", "asyncAfter", "deadline", "timeout"] {
            XCTAssertFalse(body.contains(forbidden), "the measurement must not carry \(forbidden)")
        }
    }

    // MARK: AC-1.1.6: idle before the first request

    func testMapIdle() throws {
        let cleaner = JunkCleaner.shared
        cleaner.reset()
        addTeardownBlock { cleaner.reset() }

        // Nothing is measured before the first request.
        XCTAssertNil(cleaner.spaceMap)
        XCTAssertNil(cleaner.spaceInventory)
        XCTAssertFalse(cleaner.spaceInventoryIsComputing)

        // A fresh instance starts idle too: opening the surface starts nothing.
        let fresh = JunkCleaner()
        XCTAssertNil(fresh.spaceMap)
        XCTAssertNil(fresh.spaceInventory)
        XCTAssertFalse(fresh.spaceInventoryIsComputing)

        // The measure control stays available while nothing runs.
        let view = try source("Sources/Hexa/UI/Cleaner/CleanerView.swift")
        XCTAssertTrue(view.contains(".disabled(cleaner.spaceInventoryIsComputing)"),
                      "the measure control depends on the run, not on the phase")
    }

    // MARK: AC-1.1.7: an empty result is a result

    func testEmptyMap() throws {
        let home = try makeFixtureHome()

        let cleaner = JunkCleaner.shared
        cleaner.reset()
        addTeardownBlock { cleaner.reset() }
        let map = try measureMap(cleaner, home: home)

        XCTAssertTrue(map.isEmpty)
        XCTAssertTrue(map.entries.isEmpty)
        XCTAssertTrue(map.ranking.isEmpty)
        XCTAssertTrue(map.denials.isEmpty)
        XCTAssertNil(map.systemData)
        XCTAssertFalse(map.cancelled)
        XCTAssertFalse(cleaner.spaceInventoryIsComputing,
                       "an empty result is a result, not a run still pending")
    }

    // MARK: The measured total is the sum of the map, counted once

    func testMeasuredTotalIsTheSumOfTheEntriesAndNeverAddsSystemDataAgain() throws {
        let home = try makeFixtureHome()
        try write(400_000, to: "Library/Application Support/data.bin", in: home)
        try write(10_000, to: "Library/Preferences/data.bin", in: home)
        try write(20_000, to: "docs/a.bin", in: home)

        let cleaner = JunkCleaner.shared
        cleaner.reset()
        addTeardownBlock { cleaner.reset() }
        let map = try measureMap(cleaner, home: home)

        // The total is exactly the sum of the measured folders.
        XCTAssertEqual(map.measuredTotal, map.entries.reduce(Int64(0)) { $0 + $1.size })
        // The Library parent is never an entry: its children carry its bytes, so
        // the total counts them once and the estimate is not added on top.
        XCTAssertFalse(map.entries.contains { samePath($0.url.path, home + "/Library") })
        let systemData = try XCTUnwrap(map.systemData)
        XCTAssertLessThanOrEqual(systemData.size, map.measuredTotal)

        // Built by hand: an estimate equal to its children's sum is not added again.
        let children = [SpaceMapEntry(url: URL(fileURLWithPath: "/a"), size: 100, partial: false),
                        SpaceMapEntry(url: URL(fileURLWithPath: "/b"), size: 200, partial: false)]
        let built = SpaceMap(entries: children, denials: [],
                             volume: SpaceVolume(total: nil, free: nil),
                             systemData: SpaceSystemData(size: 300, partial: true), cancelled: false)
        XCTAssertEqual(built.measuredTotal, 300, "the estimate is the same children, never added again")
        let nothing = SpaceMap(entries: [], denials: [], volume: SpaceVolume(total: nil, free: nil),
                               systemData: nil, cancelled: true)
        XCTAssertEqual(nothing.measuredTotal, 0)
    }

    // MARK: The measured total and the empty text, in the view

    /// The slice of a view file from `start` up to `end`, or to the end of the
    /// file when `end` is nil. Both markers must exist, in that order.
    private func viewSlice(_ view: String, from start: String, to end: String?) throws -> String {
        let startRange = try XCTUnwrap(view.range(of: start), "missing marker \(start)")
        let endIndex: String.Index
        if let end {
            endIndex = try XCTUnwrap(view.range(of: end, range: startRange.upperBound..<view.endIndex),
                                     "missing marker \(end)").lowerBound
        } else {
            endIndex = view.endIndex
        }
        return String(view[startRange.lowerBound..<endIndex])
    }

    func testMeasuredTotalIsRenderedBesideTheVolume() throws {
        let view = try source("Sources/Hexa/UI/Cleaner/CleanerView.swift")
        let measured = try viewSlice(view, from: "private var spaceInventoryMeasured",
                                     to: "/// The ten largest measured folders")
        XCTAssertTrue(measured.contains("map.measuredTotal"), "the view shows the measured total")
        XCTAssertTrue(measured.contains("l10n.s.spaceInventoryMeasuredTotal"),
                      "the total carries its own label")
        XCTAssertFalse(measured.contains("systemData"), "the estimate is never added to the total again")

        let section = try viewSlice(view, from: "private var spaceInventorySection",
                                    to: "/// Total, free and used of the home volume.")
        XCTAssertTrue(section.contains("spaceInventoryMeasured\n"), "the section renders the measured total")
    }

    func testEmptyTextIsSaidOnlyWhenNothingWasCancelled() throws {
        let view = try source("Sources/Hexa/UI/Cleaner/CleanerView.swift")
        let notes = try viewSlice(view, from: "private func spaceInventoryNotes",
                                  to: "private var spaceInventoryFixedBlock")
        let guardStart = try XCTUnwrap(notes.range(of: "if map.isEmpty"), "the empty text is guarded")
        let condition = notes[guardStart.lowerBound...].prefix { $0 != "{" }
        XCTAssertTrue(condition.contains("!map.cancelled"),
                      "a cancelled map with nothing measured must not claim that no folder was eligible")
        XCTAssertTrue(notes.contains("if map.cancelled {"), "the cancelled mark is still shown")
    }

    // MARK: The map is reachable from the idle screen and opening it measures nothing

    func testIdleScreenOffersTheMapAndOpeningItMeasuresNothing() throws {
        let view = try source("Sources/Hexa/UI/Cleaner/CleanerView.swift")

        let workspace = try viewSlice(view, from: "private var workspaceIdleState",
                                      to: "private var compactIdleState")
        let compact = try viewSlice(view, from: "private var compactIdleState",
                                    to: "private var automaticRunLine")
        XCTAssertTrue(workspace.contains("spaceMapEntry"), "the workspace idle screen offers the map")
        XCTAssertTrue(compact.contains("spaceMapEntry"), "the compact idle screen offers the map")

        let entry = try viewSlice(view, from: "private var spaceMapEntry", to: "private var spaceMapScreen")
        XCTAssertTrue(entry.contains("openSpaceMap()"), "the entry opens the map")
        XCTAssertFalse(entry.contains("measureSpaceInventory"), "the entry only opens the map")

        let open = try viewSlice(view, from: "private func openSpaceMap", to: "private func closeSpaceMap")
        XCTAssertTrue(open.contains("spaceMapOpen = true"))
        XCTAssertFalse(open.contains("measureSpaceInventory"), "opening the map starts no measurement")

        let screen = try viewSlice(view, from: "private var spaceMapScreen", to: "private var spaceMapHeader")
        XCTAssertTrue(screen.contains("spaceInventorySection"), "the map screen shows the same section")
        XCTAssertFalse(screen.contains("measureSpaceInventory"), "the map screen starts no measurement")

        // The body, the route and the appearance start nothing on their own.
        let body = try viewSlice(view, from: "var body: some View", to: "private var content: some View")
        XCTAssertFalse(body.contains("measureSpaceInventory"), "appearing on screen starts no measurement")
        let route = try viewSlice(view, from: "private var content: some View",
                                  to: "private func settingsScrolling")
        XCTAssertTrue(route.contains("spaceMapOpen"), "the content switch carries the map route")
        XCTAssertTrue(route.contains("spaceMapScreen"), "the content switch shows the map")

        // Back drops the route and stops the reading, without resetting the Cleaner.
        let close = try viewSlice(view, from: "private func closeSpaceMap", to: "// MARK: Large and old files")
        XCTAssertTrue(close.contains("spaceMapOpen = false"))
        XCTAssertTrue(close.contains("cancelSpaceInventory()"), "Back stops a reading still running")
        XCTAssertFalse(close.contains("reset()"), "Back never resets the Cleaner")
        XCTAssertFalse(close.contains("phase"), "Back leaves the Cleaner's phase as it was")
    }

    func testResultsStillShowTheMapInline() throws {
        let view = try source("Sources/Hexa/UI/Cleaner/CleanerView.swift")
        let results = try viewSlice(view, from: "private var resultsState", to: "private var resultsHeader")
        XCTAssertTrue(results.contains("spaceInventorySection"), "the results keep the map inline")
    }

    // MARK: The map's text exists in every language of the base

    func testMapTextExistsInAllFifteenLanguages() {
        XCTAssertEqual(AppLanguage.allCases.count, 15)
        // The typographic dash the project forbids in generated text, spelled
        // out so this file carries no literal of it.
        let emDash = "\u{2014}"

        for language in AppLanguage.allCases {
            let strings = Strings.localized(language)
            let values: [(String, String)] = [
                ("spaceInventoryVolumeTotal", strings.spaceInventoryVolumeTotal),
                ("spaceInventoryVolumeFree", strings.spaceInventoryVolumeFree),
                ("spaceInventoryVolumeUsed", strings.spaceInventoryVolumeUsed),
                ("spaceInventoryVolumeUnavailable", strings.spaceInventoryVolumeUnavailable),
                ("spaceInventoryLowSpace", strings.spaceInventoryLowSpace),
                ("spaceInventoryRankingTitle", strings.spaceInventoryRankingTitle),
                ("spaceInventorySummaryTitle", strings.spaceInventorySummaryTitle),
                ("spaceInventorySummaryPartial", strings.spaceInventorySummaryPartial),
                ("spaceInventoryDeniedFormat", strings.spaceInventoryDeniedFormat),
                ("spaceInventoryDeniedAccess", strings.spaceInventoryDeniedAccess),
                ("spaceInventoryDeniedUnavailable", strings.spaceInventoryDeniedUnavailable),
                ("spaceInventoryPartialMark", strings.spaceInventoryPartialMark),
                ("spaceInventoryEmpty", strings.spaceInventoryEmpty),
                ("spaceInventoryCancelled", strings.spaceInventoryCancelled),
                ("spaceInventoryMeasuredTotal", strings.spaceInventoryMeasuredTotal),
            ]
            for (key, value) in values {
                XCTAssertFalse(value.isEmpty, "\(key) is empty in \(language.rawValue)")
                XCTAssertFalse(value.contains(emDash),
                               "\(key) carries an em dash in \(language.rawValue)")
            }
            XCTAssertEqual(strings.spaceInventoryDeniedFormat.components(separatedBy: "%@").count, 3,
                           "the denial line takes a path and a reason in \(language.rawValue)")
            XCTAssertNotEqual(strings.spaceInventoryDeniedAccess, strings.spaceInventoryDeniedUnavailable,
                              "the two reasons are different messages in \(language.rawValue)")
            XCTAssertNotEqual(strings.spaceInventorySummaryTitle, strings.spaceInventoryRankingTitle,
                              "the summary and the ranking are different titles in \(language.rawValue)")
        }
    }
}
