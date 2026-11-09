// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import Darwin
import XCTest

@testable import Hexa

final class KillProcessSupportTests: XCTestCase {

    // MARK: - isProtected Tests

    func testProtectedKernelAndLaunchdAndCurrentProcess() {
        // PID 0 (kernel_task) and PID 1 (launchd) must always be protected regardless of name or path.
        XCTAssertTrue(KillProcessSupport.isProtected(pid: 0))
        XCTAssertTrue(KillProcessSupport.isProtected(pid: 1))
        XCTAssertTrue(KillProcessSupport.isProtected(pid: 0, name: "custom", path: "/bin/custom"))
        XCTAssertTrue(KillProcessSupport.isProtected(pid: 1, name: "custom", path: "/bin/custom"))

        // Any negative PID is also guarded by pid <= 1.
        XCTAssertTrue(KillProcessSupport.isProtected(pid: -1))

        // Hexa's own process identifier must always be protected.
        let ownPID = ProcessInfo.processInfo.processIdentifier
        XCTAssertTrue(KillProcessSupport.isProtected(pid: ownPID))
        XCTAssertTrue(KillProcessSupport.isProtected(pid: ownPID, name: "anyName", path: "/any/path"))
    }

    func testProtectedVitalSystemDaemonsByName() {
        let daemons = [
            "securityd",
            "opendirectoryd",
            "coreauthd",
            "diskarbitrationd",
            "syspolicyd",
            "powerd",
            "logd",
            "notifyd",
            "fseventsd",
            "distnoted"
        ]

        let testPID: pid_t = 8888
        for daemon in daemons {
            XCTAssertTrue(
                KillProcessSupport.isProtected(pid: testPID, name: daemon),
                "Expected \(daemon) to be protected by process name"
            )
        }

        // Additional critical names
        let otherCore = [
            "kernel_task",
            "launchd",
            "windowserver",
            "loginwindow",
            "hexa",
            "hexa (developer)",
            "hexadeveloper"
        ]
        for name in otherCore {
            XCTAssertTrue(
                KillProcessSupport.isProtected(pid: testPID, name: name),
                "Expected \(name) to be protected"
            )
        }
    }

    func testProtectedCaseInsensitivityAndWhitespaceTrimming() {
        let testPID: pid_t = 9999

        // Name case insensitivity & trimming
        XCTAssertTrue(KillProcessSupport.isProtected(pid: testPID, name: "SecurityD"))
        XCTAssertTrue(KillProcessSupport.isProtected(pid: testPID, name: "  SECURITYD  "))
        XCTAssertTrue(KillProcessSupport.isProtected(pid: testPID, name: "OpenDirectoryD"))
        XCTAssertTrue(KillProcessSupport.isProtected(pid: testPID, name: "COREAUTHD"))
        XCTAssertTrue(KillProcessSupport.isProtected(pid: testPID, name: "DiskArbitrationD"))
        XCTAssertTrue(KillProcessSupport.isProtected(pid: testPID, name: "SysPolicyD"))
        XCTAssertTrue(KillProcessSupport.isProtected(pid: testPID, name: "PowerD"))
        XCTAssertTrue(KillProcessSupport.isProtected(pid: testPID, name: "LOGD"))
        XCTAssertTrue(KillProcessSupport.isProtected(pid: testPID, name: "NotifyD"))
        XCTAssertTrue(KillProcessSupport.isProtected(pid: testPID, name: "FSEventsD"))
        XCTAssertTrue(KillProcessSupport.isProtected(pid: testPID, name: "DistNoted"))

        // Path case insensitivity & trimming
        XCTAssertTrue(KillProcessSupport.isProtected(pid: testPID, path: "/usr/libexec/SecurityD"))
        XCTAssertTrue(KillProcessSupport.isProtected(pid: testPID, path: "  /usr/libexec/opendirectoryd  "))
        XCTAssertTrue(KillProcessSupport.isProtected(pid: testPID, path: "/USR/SBIN/NOTIFYD"))
        XCTAssertTrue(KillProcessSupport.isProtected(pid: testPID, path: "/usr/libexec/distnoted"))
        XCTAssertTrue(KillProcessSupport.isProtected(pid: testPID, path: "/usr/sbin/powerd"))
    }

    func testProtectedPathSuffixes() {
        let testPID: pid_t = 7777

        XCTAssertTrue(KillProcessSupport.isProtected(pid: testPID, path: "/System/Library/CoreServices/loginwindow.app/Contents/MacOS/loginwindow"))
        XCTAssertTrue(KillProcessSupport.isProtected(pid: testPID, path: "/System/Library/Frameworks/CoreGraphics.framework/Resources/WindowServer"))
        XCTAssertTrue(KillProcessSupport.isProtected(pid: testPID, path: "/sbin/launchd"))
        XCTAssertTrue(KillProcessSupport.isProtected(pid: testPID, path: "/usr/libexec/coreauthd"))
        XCTAssertTrue(KillProcessSupport.isProtected(pid: testPID, path: "/usr/libexec/diskarbitrationd"))
        XCTAssertTrue(KillProcessSupport.isProtected(pid: testPID, path: "/usr/libexec/syspolicyd"))
        XCTAssertTrue(KillProcessSupport.isProtected(pid: testPID, path: "/System/Library/Frameworks/CoreServices.framework/Frameworks/FSEvents.framework/Support/fseventsd"))
    }

    func testNormalUserAppsAreNotProtected() {
        // Fixture PID above the macOS PID range: no live process, so proc_pidpath cannot read a path.
        let testPID: pid_t = 4_000_000

        XCTAssertFalse(KillProcessSupport.isProtected(pid: testPID, name: "TextEdit", path: "/System/Applications/TextEdit.app/Contents/MacOS/TextEdit"))
        XCTAssertFalse(KillProcessSupport.isProtected(pid: testPID, name: "Safari", path: "/Applications/Safari.app/Contents/MacOS/Safari"))
        XCTAssertFalse(KillProcessSupport.isProtected(pid: testPID, name: "Slack", path: "/Applications/Slack.app/Contents/MacOS/Slack"))
        XCTAssertFalse(KillProcessSupport.isProtected(pid: testPID, name: "Xcode", path: "/Applications/Xcode.app/Contents/MacOS/Xcode"))
        XCTAssertFalse(KillProcessSupport.isProtected(pid: testPID, name: "bash", path: "/bin/bash"))
        XCTAssertFalse(KillProcessSupport.isProtected(pid: testPID, name: "python3", path: "/usr/local/bin/python3"))
        XCTAssertFalse(KillProcessSupport.isProtected(pid: testPID, name: "securityd_helper", path: "/usr/local/bin/securityd_helper"))
        XCTAssertFalse(KillProcessSupport.isProtected(pid: testPID, name: "not_syspolicyd", path: "/usr/bin/not_syspolicyd"))
    }

    // MARK: - Resolved binary path Tests

    func testResolvedPathProtectsRunningDaemonWhenNameIsInnocent() throws {
        // Reads the real binary path of a running system daemon (no signal is sent).
        guard let daemon = Self.runningProtectedDaemonForResolvedPathTest() else {
            throw XCTSkip("Nenhum daemon protegido com caminho legível está em execução; a checagem de caminho resolvido não pode rodar.")
        }
        print("Resolved-path test uses PID \(daemon.pid) at \(daemon.path)")
        XCTAssertTrue(
            KillProcessSupport.isProtected(pid: daemon.pid, name: "node"),
            "O PID \(daemon.pid) executa \(daemon.path) e deve continuar protegido mesmo com nome informado inocente"
        )
    }

    func testResolvedPathControlOwnChildProcessIsNotProtected() throws {
        // The child is created and collected by this test only; no other process is signaled.
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/bin/sleep")
        child.arguments = ["30"]
        try child.run()
        defer {
            if child.isRunning { child.terminate() }
            child.waitUntilExit()
        }
        XCTAssertFalse(KillProcessSupport.isProtected(pid: child.processIdentifier, name: "sleep", path: "/bin/sleep"))
    }

    func testArchDaemonNamesProtectLiveChildByName() throws {
        // The child is created and collected by this test only; no other process is signaled.
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/bin/sleep")
        child.arguments = ["30"]
        try child.run()
        defer {
            if child.isRunning { child.terminate() }
            child.waitUntilExit()
        }
        let daemons = [
            "configd", "mdnsresponder", "coreaudiod", "bluetoothd", "tccd",
            "trustd", "runningboardd", "containermanagerd", "systemstatusd", "diagnosticd"
        ]
        for daemon in daemons {
            XCTAssertTrue(
                KillProcessSupport.isProtected(pid: child.processIdentifier, name: daemon),
                "Esperado que \(daemon) seja protegido pelo nome do processo"
            )
        }
    }

    func testArchFixturePIDHasNoLiveProcess() {
        // Guards the fixture used by testNormalUserAppsAreNotProtected.
        let fixturePID: pid_t = 4_000_000
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        XCTAssertLessThanOrEqual(proc_pidpath(fixturePID, &buffer, UInt32(buffer.count)), 0)
    }

    func testArchBundleIdentifierRuleNeverProtectsWithNil() {
        XCTAssertTrue(KillProcessSupport.isProtectedBundle(identifier: "app.hexa", ownIdentifier: "app.hexa"))
        XCTAssertFalse(KillProcessSupport.isProtectedBundle(identifier: nil, ownIdentifier: "app.hexa"))
        XCTAssertFalse(KillProcessSupport.isProtectedBundle(identifier: "app.hexa", ownIdentifier: nil))
        XCTAssertFalse(KillProcessSupport.isProtectedBundle(identifier: nil, ownIdentifier: nil))
        XCTAssertFalse(KillProcessSupport.isProtectedBundle(identifier: "", ownIdentifier: ""))
        XCTAssertFalse(KillProcessSupport.isProtectedBundle(identifier: "com.apple.Safari", ownIdentifier: "app.hexa"))
    }

    func testArchInsideAppBundleRuleMatchesOnlyDirectoryBoundary() {
        let bundle = "/Applications/hexa.app"
        XCTAssertTrue(KillProcessSupport.isInsideAppBundle(
            path: "/Applications/hexa.app/Contents/Helpers/FanControlHelper", bundlePath: bundle))
        XCTAssertTrue(KillProcessSupport.isInsideAppBundle(
            path: "/Applications/hexa.app/Contents/MacOS/Hexa", bundlePath: bundle + "/"))
        XCTAssertFalse(KillProcessSupport.isInsideAppBundle(
            path: "/Applications/hexa.app2/x", bundlePath: bundle))
        XCTAssertFalse(KillProcessSupport.isInsideAppBundle(
            path: "/Applications/Safari.app/Contents/MacOS/Safari", bundlePath: bundle))
        XCTAssertFalse(KillProcessSupport.isInsideAppBundle(path: "", bundlePath: bundle))
        XCTAssertFalse(KillProcessSupport.isInsideAppBundle(path: "/Applications/hexa.app/x", bundlePath: ""))
    }

    func testArchTestBundleDoesNotContainSystemBinary() {
        // Control for the bundle-path rule: the test host bundle must not cover /bin/sleep.
        XCTAssertFalse(KillProcessSupport.isInsideAppBundle(path: "/bin/sleep", bundlePath: Bundle.main.bundleURL.path))
    }

    /// Scans the process table for a daemon from the protected list whose binary
    /// path can be read by proc_pidpath. Read-only: never signals a process.
    private static func runningProtectedDaemonForResolvedPathTest() -> (pid: pid_t, path: String)? {
        let daemonBinaries: Set<String> = [
            "logd", "notifyd", "syspolicyd", "diskarbitrationd", "opendirectoryd",
            "securityd", "distnoted", "powerd", "fseventsd"
        ]
        let capacity = Int(proc_listallpids(nil, 0)) + 64
        var pids = [pid_t](repeating: 0, count: capacity)
        let filled = Int(proc_listallpids(&pids, Int32(capacity * MemoryLayout<pid_t>.stride)))
        guard filled > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        for pid in pids.prefix(min(filled, capacity)) where pid > 1 && pid != getpid() {
            guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { continue }
            let path = String(cString: buffer)
            // Host daemons only; skips copies inside simulator runtimes and similar bundles.
            guard path.hasPrefix("/usr/") || path.hasPrefix("/System/") || path.hasPrefix("/sbin/") else { continue }
            if daemonBinaries.contains((path as NSString).lastPathComponent) {
                return (pid, path)
            }
        }
        return nil
    }

    // MARK: - descendants Tests

    func testDescendantsMultiTierHierarchy() {
        // Tree:
        //        100
        //       /   \
        //     200   201
        //    /   \     \
        //  300   301   302
        //         |
        //        400
        let parents: [(pid: pid_t, ppid: pid_t)] = [
            (pid: 200, ppid: 100),
            (pid: 201, ppid: 100),
            (pid: 300, ppid: 200),
            (pid: 301, ppid: 200),
            (pid: 302, ppid: 201),
            (pid: 400, ppid: 301),
            (pid: 999, ppid: 888) // Disjoint process
        ]

        let result = KillProcessSupport.descendants(of: 100, parents: parents)
        // BFS order visits level 1 (200, 201), level 2 (300, 301, 302), level 3 (400)
        XCTAssertEqual(result, [200, 201, 300, 301, 302, 400])
    }

    func testDescendantsEmptyAndNoChildren() {
        XCTAssertEqual(KillProcessSupport.descendants(of: 100, parents: []), [])

        let parents: [(pid: pid_t, ppid: pid_t)] = [
            (pid: 200, ppid: 50),
            (pid: 300, ppid: 50)
        ]
        XCTAssertEqual(KillProcessSupport.descendants(of: 100, parents: parents), [])
    }

    func testDescendantsCycleAndSelfParentingSafety() {
        // Self-parenting node: PID 100 has PPID 100
        let selfParent: [(pid: pid_t, ppid: pid_t)] = [
            (pid: 100, ppid: 100)
        ]
        XCTAssertEqual(KillProcessSupport.descendants(of: 100, parents: selfParent), [])

        // Self-parenting child: 100 -> 200, 200 -> 200
        let selfParentChild: [(pid: pid_t, ppid: pid_t)] = [
            (pid: 200, ppid: 100),
            (pid: 200, ppid: 200)
        ]
        XCTAssertEqual(KillProcessSupport.descendants(of: 100, parents: selfParentChild), [200])

        // Direct cycle: 100 -> 200 -> 100
        let directCycle: [(pid: pid_t, ppid: pid_t)] = [
            (pid: 200, ppid: 100),
            (pid: 100, ppid: 200)
        ]
        XCTAssertEqual(KillProcessSupport.descendants(of: 100, parents: directCycle), [200])

        // Multi-tier cycle: 100 -> 200 -> 300 -> 400 -> 200
        let multiCycle: [(pid: pid_t, ppid: pid_t)] = [
            (pid: 200, ppid: 100),
            (pid: 300, ppid: 200),
            (pid: 400, ppid: 300),
            (pid: 200, ppid: 400)
        ]
        XCTAssertEqual(KillProcessSupport.descendants(of: 100, parents: multiCycle), [200, 300, 400])
    }

    func testDescendantsMaxNodeGuard() {
        // Deep chain exceeding the 4096 guard limit:
        // root = 10000, 10001 -> 10000, 10002 -> 10001, ..., 15000 -> 14999
        let chainCount = 5000
        var chainParents: [(pid: pid_t, ppid: pid_t)] = []
        chainParents.reserveCapacity(chainCount)
        for i in 1...chainCount {
            chainParents.append((pid: pid_t(10000 + i), ppid: pid_t(10000 + i - 1)))
        }

        let descendants = KillProcessSupport.descendants(of: 10000, parents: chainParents)
        // Must be capped at 4096 nodes
        XCTAssertEqual(descendants.count, 4096)
        XCTAssertEqual(descendants.first, 10001)
        XCTAssertEqual(descendants.last, 10000 + 4096)
    }

    // MARK: - numberComesBefore Tests

    func testNumberComesBeforeAscendingAndDescending() {
        // Ascending
        XCTAssertTrue(KillProcessSupport.numberComesBefore(10.0, 20.0, lhsPID: 1, rhsPID: 2, ascending: true))
        XCTAssertFalse(KillProcessSupport.numberComesBefore(20.0, 10.0, lhsPID: 1, rhsPID: 2, ascending: true))

        // Descending
        XCTAssertTrue(KillProcessSupport.numberComesBefore(20.0, 10.0, lhsPID: 1, rhsPID: 2, ascending: false))
        XCTAssertFalse(KillProcessSupport.numberComesBefore(10.0, 20.0, lhsPID: 1, rhsPID: 2, ascending: false))
    }

    func testNumberComesBeforeTieBreakByPID() {
        // When numbers are equal, lhsPID < rhsPID is used regardless of ascending flag
        XCTAssertTrue(KillProcessSupport.numberComesBefore(15.0, 15.0, lhsPID: 10, rhsPID: 20, ascending: true))
        XCTAssertFalse(KillProcessSupport.numberComesBefore(15.0, 15.0, lhsPID: 20, rhsPID: 10, ascending: true))

        XCTAssertTrue(KillProcessSupport.numberComesBefore(15.0, 15.0, lhsPID: 10, rhsPID: 20, ascending: false))
        XCTAssertFalse(KillProcessSupport.numberComesBefore(15.0, 15.0, lhsPID: 20, rhsPID: 10, ascending: false))
    }

    // MARK: - nameComesBefore Tests

    func testNameComesBeforeAscendingAndDescending() {
        // Ascending
        XCTAssertTrue(KillProcessSupport.nameComesBefore("Alpha", "Beta", lhsPID: 1, rhsPID: 2, ascending: true))
        XCTAssertFalse(KillProcessSupport.nameComesBefore("Beta", "Alpha", lhsPID: 1, rhsPID: 2, ascending: true))

        // Descending
        XCTAssertTrue(KillProcessSupport.nameComesBefore("Beta", "Alpha", lhsPID: 1, rhsPID: 2, ascending: false))
        XCTAssertFalse(KillProcessSupport.nameComesBefore("Alpha", "Beta", lhsPID: 1, rhsPID: 2, ascending: false))
    }

    func testNameComesBeforeCaseInsensitivity() {
        // Case-insensitive comparisons
        XCTAssertTrue(KillProcessSupport.nameComesBefore("apple", "Banana", lhsPID: 1, rhsPID: 2, ascending: true))
        XCTAssertFalse(KillProcessSupport.nameComesBefore("Banana", "apple", lhsPID: 1, rhsPID: 2, ascending: true))
        XCTAssertTrue(KillProcessSupport.nameComesBefore("Banana", "apple", lhsPID: 1, rhsPID: 2, ascending: false))
    }

    func testNameComesBeforeTieBreakByPID() {
        // Exact same name
        XCTAssertTrue(KillProcessSupport.nameComesBefore("Hexa", "Hexa", lhsPID: 10, rhsPID: 20, ascending: true))
        XCTAssertFalse(KillProcessSupport.nameComesBefore("Hexa", "Hexa", lhsPID: 20, rhsPID: 10, ascending: true))
        XCTAssertTrue(KillProcessSupport.nameComesBefore("Hexa", "Hexa", lhsPID: 10, rhsPID: 20, ascending: false))
        XCTAssertFalse(KillProcessSupport.nameComesBefore("Hexa", "Hexa", lhsPID: 20, rhsPID: 10, ascending: false))

        // Same name with different casing (orderedSame in case-insensitive comparison)
        XCTAssertTrue(KillProcessSupport.nameComesBefore("hexa", "HEXA", lhsPID: 10, rhsPID: 20, ascending: true))
        XCTAssertFalse(KillProcessSupport.nameComesBefore("HEXA", "hexa", lhsPID: 20, rhsPID: 10, ascending: true))
        XCTAssertTrue(KillProcessSupport.nameComesBefore("hexa", "HEXA", lhsPID: 10, rhsPID: 20, ascending: false))
        XCTAssertFalse(KillProcessSupport.nameComesBefore("HEXA", "hexa", lhsPID: 20, rhsPID: 10, ascending: false))
    }

    // MARK: - normalizedStartDescription Tests

    func testNormalizedStartDescriptionWhitespaceCleaning() {
        XCTAssertEqual(KillProcessSupport.normalizedStartDescription("10:30"), "10:30")
        XCTAssertEqual(KillProcessSupport.normalizedStartDescription("  10:30  "), "10:30")
        XCTAssertEqual(KillProcessSupport.normalizedStartDescription("Oct   12    10:30:00"), "Oct 12 10:30:00")
        XCTAssertEqual(KillProcessSupport.normalizedStartDescription("\tMon \n 15:45:00 "), "Mon 15:45:00")
        XCTAssertEqual(KillProcessSupport.normalizedStartDescription("12:00:00"), "12:00:00")
    }

    func testNormalizedStartDescriptionRejectsInvalidFormats() {
        // Empty or whitespace-only
        XCTAssertNil(KillProcessSupport.normalizedStartDescription(""))
        XCTAssertNil(KillProcessSupport.normalizedStartDescription("   "))
        XCTAssertNil(KillProcessSupport.normalizedStartDescription("\t\n  "))

        // Disallowed punctuation / special characters
        XCTAssertNil(KillProcessSupport.normalizedStartDescription("10-12-2026"))
        XCTAssertNil(KillProcessSupport.normalizedStartDescription("10/12/2026"))
        XCTAssertNil(KillProcessSupport.normalizedStartDescription("10:30!"))
        XCTAssertNil(KillProcessSupport.normalizedStartDescription("10:30; rm -rf /"))
        XCTAssertNil(KillProcessSupport.normalizedStartDescription("12:30.45"))
        XCTAssertNil(KillProcessSupport.normalizedStartDescription("user@host"))

        // Non-ASCII
        XCTAssertNil(KillProcessSupport.normalizedStartDescription("10:30\u{0000}"))
        XCTAssertNil(KillProcessSupport.normalizedStartDescription("café 10:30"))
    }

    // MARK: - protectionReason Tests

    /// PIDs above the kernel's maximum (99998) so a fixture can never name a
    /// running process. Nothing here signals anything.
    private func makeEntry(pid: pid_t,
                           startedAt: UInt64?,
                           isProtected: Bool,
                           protectionReason: KillProcessEntry.ProtectionReason? = nil,
                           groupedCount: Int = 1,
                           groupMembers: [KillProcessEntry] = []) -> KillProcessEntry {
        KillProcessEntry(
            pid: pid,
            ppid: 1,
            name: "fixture",
            path: "/fixture",
            cpuPercent: 0,
            memoryBytes: 0,
            isRegularApp: false,
            bundleURL: nil,
            groupedCount: groupedCount,
            isProtected: isProtected,
            startedAt: startedAt,
            groupMembers: groupMembers,
            protectionReason: protectionReason
        )
    }

    func testSystemProtectedRowIsReportedAsSystemProcess() {
        XCTAssertEqual(
            KillProcessSupport.protectionReason(isSystemProtected: true, hasIdentity: true),
            .systemProcess
        )
    }

    func testIdentifiedRowWithoutSystemProtectionHasNoReason() {
        XCTAssertNil(KillProcessSupport.protectionReason(isSystemProtected: false, hasIdentity: true))
    }

    func testRowWithoutIdentityIsReportedAsIdentityUnavailable() {
        XCTAssertEqual(
            KillProcessSupport.protectionReason(isSystemProtected: false, hasIdentity: false),
            .identityUnavailable
        )
    }

    func testSystemProtectionWinsOverMissingIdentity() {
        XCTAssertEqual(
            KillProcessSupport.protectionReason(isSystemProtected: true, hasIdentity: false),
            .systemProcess
        )
    }

    // MARK: - groupKillTargets Tests

    func testGroupedRowExpandsToOwnerAndHelper() {
        let owner = makeEntry(pid: 900_001, startedAt: 1_700_000_000_000_000, isProtected: false)
        let helper = makeEntry(pid: 900_002, startedAt: 1_700_000_000_000_001, isProtected: false)
        let grouped = makeEntry(pid: 900_001,
                                startedAt: 1_700_000_000_000_000,
                                isProtected: false,
                                groupedCount: 2,
                                groupMembers: [owner, helper])

        XCTAssertEqual(KillProcessSupport.groupKillTargets(for: grouped), [owner, helper])
    }

    func testGroupedRowDropsProtectedHelper() {
        let owner = makeEntry(pid: 900_003, startedAt: 1_700_000_000_000_000, isProtected: false)
        let helper = makeEntry(pid: 900_004,
                               startedAt: nil,
                               isProtected: true,
                               protectionReason: .identityUnavailable)
        let grouped = makeEntry(pid: 900_003,
                                startedAt: 1_700_000_000_000_000,
                                isProtected: false,
                                groupedCount: 2,
                                groupMembers: [owner, helper])

        XCTAssertEqual(KillProcessSupport.groupKillTargets(for: grouped), [owner])
    }

    func testUngroupedRowExpandsToItself() {
        let row = makeEntry(pid: 900_005, startedAt: 1_700_000_000_000_000, isProtected: false)
        XCTAssertEqual(KillProcessSupport.groupKillTargets(for: row), [row])
    }

    func testProtectedUngroupedRowExpandsToNothing() {
        let row = makeEntry(pid: 900_006,
                            startedAt: nil,
                            isProtected: true,
                            protectionReason: .identityUnavailable)
        XCTAssertTrue(KillProcessSupport.groupKillTargets(for: row).isEmpty)
    }
}
