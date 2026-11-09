// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import Darwin
import XCTest

@testable import Hexa

final class PortManagerServiceTests: XCTestCase {

    /// Read-only: opens a loopback listener owned by the test process and reads
    /// the process table through snapshot(). Never signals a process.
    func testSnapshotReportsOwnListenerWithCompleteIdentity() throws {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        XCTAssertGreaterThanOrEqual(fd, 0)
        defer { close(fd) }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        XCTAssertEqual(bindResult, 0)
        XCTAssertEqual(listen(fd, 1), 0)

        var assigned = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &assigned) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(fd, $0, &length)
            }
        }
        XCTAssertEqual(nameResult, 0)
        let port = Int(UInt16(bigEndian: assigned.sin_port))
        XCTAssertGreaterThan(port, 0)

        let entries = try XCTUnwrap(PortManagerService.snapshot())
        let own = try XCTUnwrap(entries.first { $0.pid == getpid() && $0.port == port },
                                "The test listener is missing from the snapshot")
        XCTAssertNotNil(own.startedAt)
        XCTAssertNotNil(own.path)
    }
}
