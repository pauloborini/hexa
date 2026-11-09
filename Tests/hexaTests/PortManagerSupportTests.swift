// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

final class PortManagerSupportTests: XCTestCase {

    // MARK: - parseLsof Tests

    func testParseLsofKeepsOnlyValidTCPPortRange() {
        // Port 0, 65536 and 99999 are outside the TCP range and must be dropped.
        // Ports 1 and 65535 are the boundaries of the valid range and must be kept.
        let text = """
        p100
        cvalidlow
        PTCP
        n127.0.0.1:1
        p101
        cvalidhigh
        PTCP
        n*:65535
        p102
        czero
        PTCP
        n*:0
        p103
        cover
        PTCP
        n*:65536
        p104
        cfar
        PTCP
        n*:99999
        """

        let rows = PortManagerSupport.parseLsof(text)

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows.map(\.port), [1, 65535])
        XCTAssertEqual(rows.map(\.processName), ["validlow", "validhigh"])
    }

    // MARK: - browserURL Tests

    func testBrowserURLIPv6ScopeWithoutBrackets() {
        let entry = makeEntry(address: "fe80::1%lo0:8080", port: 8080)
        XCTAssertEqual(PortManagerSupport.browserURL(for: entry)?.absoluteString, "http://[fe80::1]:8080")
    }

    func testBrowserURLIPv6ScopeWithBrackets() {
        let entry = makeEntry(address: "[fe80::1%lo0]:8080", port: 8080)
        XCTAssertEqual(PortManagerSupport.browserURL(for: entry)?.absoluteString, "http://[fe80::1]:8080")
    }

    func testBrowserURLIPv6LoopbackKeepsBrackets() {
        let entry = makeEntry(address: "[::1]:8080", port: 8080)
        XCTAssertEqual(PortManagerSupport.browserURL(for: entry)?.absoluteString, "http://[::1]:8080")
    }

    func testBrowserURLWildcardMapsToLocalhost() {
        let entry = makeEntry(address: "*:3000", port: 3000)
        XCTAssertEqual(PortManagerSupport.browserURL(for: entry)?.absoluteString, "http://localhost:3000")
    }

    func testBrowserURLIPv4AnyMapsToLoopback() {
        let entry = makeEntry(address: "0.0.0.0:3000", port: 3000)
        XCTAssertEqual(PortManagerSupport.browserURL(for: entry)?.absoluteString, "http://127.0.0.1:3000")
    }

    func testBrowserURLIPv6AnyMapsToLoopback() {
        let entry = makeEntry(address: "[::]:3000", port: 3000)
        XCTAssertEqual(PortManagerSupport.browserURL(for: entry)?.absoluteString, "http://[::1]:3000")
    }

    // MARK: - processNameMatches Tests

    func testProcessNameMatchesBasenameWithinLimit() {
        XCTAssertTrue(PortManagerSupport.processNameMatches("node", executablePath: "/usr/local/bin/node"))
        // 31 bytes is the whole basename at the limit; lsof printed names of this length unchanged.
        XCTAssertTrue(PortManagerSupport.processNameMatches("abcdefghijklmnopqrstuvwxyzABCDE",
                                                            executablePath: "/x/abcdefghijklmnopqrstuvwxyzABCDE"))
    }

    func testProcessNameMatchesTruncatedBasenameUsesFirstThirtyOneBytes() {
        // lsof cuts a longer basename to its first 31 bytes.
        XCTAssertTrue(PortManagerSupport.processNameMatches("abcdefghijklmnopqrstuvwxyzABCDE",
                                                            executablePath: "/x/abcdefghijklmnopqrstuvwxyzABCDEF"))
    }

    func testProcessNameMatchesRejectsSixteenBytePrefixOfLongerBasename() {
        // lsof printed 25- and 26-byte names whole (observed), so a 16-byte cut is not the rule.
        XCTAssertFalse(PortManagerSupport.processNameMatches("abcdefghijklmnop",
                                                             executablePath: "/x/abcdefghijklmnopqrstuvwxyz"))
    }

    func testProcessNameMatchesRejectsDifferentName() {
        XCTAssertFalse(PortManagerSupport.processNameMatches("python3", executablePath: "/usr/bin/node"))
    }

    func testProcessNameMatchesRejectsEmptyName() {
        XCTAssertFalse(PortManagerSupport.processNameMatches("", executablePath: "/usr/bin/node"))
    }

    func testProcessNameMatchesRejectsNameLongerThanLimit() {
        XCTAssertFalse(PortManagerSupport.processNameMatches("abcdefghijklmnopqrstuvwxyzABCDEFG",
                                                             executablePath: "/x/abcdefghijklmnopqrstuvwxyzABCDEFGH"))
    }

    // MARK: - lsofFailed Tests

    func testLsofFailedTreatsErrorMessageWithoutProcessFieldAsFailure() {
        XCTAssertTrue(PortManagerSupport.lsofFailed(status: 1, output: "lsof: unknown option\nlsof 4.91\n"))
    }

    func testLsofFailedAcceptsEmptyOutputAsNothingListening() {
        XCTAssertFalse(PortManagerSupport.lsofFailed(status: 1, output: ""))
        XCTAssertFalse(PortManagerSupport.lsofFailed(status: 1, output: "\n  \n"))
    }

    func testLsofFailedAcceptsWarningNextToRows() {
        let output = "lsof: WARNING: can't stat() nfs file system /Volumes/x\np100\ncnode\nn*:3000\n"
        XCTAssertFalse(PortManagerSupport.lsofFailed(status: 1, output: output))
        XCTAssertFalse(PortManagerSupport.lsofFailed(status: 1, output: "lsof: WARNING: can't stat()\n"))
    }

    func testLsofFailedIgnoresTextOnSuccess() {
        XCTAssertFalse(PortManagerSupport.lsofFailed(status: 0, output: "anything"))
    }

    // MARK: - identityUnavailable Tests

    func testIdentityUnavailableWhenStartTimeIsMissing() {
        let entry = makeEntry(address: "*:3000", port: 3000)
        XCTAssertTrue(entry.identityUnavailable)
    }

    func testIdentityAvailableWhenStartTimeIsKnown() {
        let entry = PortManagerEntry(
            port: 3000,
            protocolName: "TCP",
            address: "*:3000",
            pid: 4242,
            processName: "node",
            startedAt: 1_700_000_000
        )
        XCTAssertFalse(entry.identityUnavailable)
    }

    // MARK: - Helpers

    private func makeEntry(address: String, port: Int) -> PortManagerEntry {
        PortManagerEntry(
            port: port,
            protocolName: "TCP",
            address: address,
            pid: 4242,
            processName: "node",
            startedAt: nil
        )
    }
}
