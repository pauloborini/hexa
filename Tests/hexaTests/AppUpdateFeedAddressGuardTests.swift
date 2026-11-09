// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Address classification and host resolution use a fake resolver, so the
/// suite never depends on DNS. The load tests run the production session
/// settings with a URLProtocol stub as the only protocol class, so no request
/// can reach the network.
final class AppUpdateFeedAddressGuardTests: XCTestCase {
    private static let feedURL = URL(string: "https://feed.example.com/appcast.xml")!

    override func setUp() {
        super.setUp()
        RecordingURLProtocol.requestedHosts = []
    }

    private static func stubbedConfiguration() -> URLSessionConfiguration {
        let configuration = AppUpdateFeedLoader.productionConfiguration()
        configuration.protocolClasses = [RecordingURLProtocol.self]
        return configuration
    }

    func testClassificationRejectsNonPublicAddresses() {
        let addresses = [
            "127.0.0.1", "10.1.2.3", "172.16.0.1", "172.31.255.255", "192.168.1.1",
            "169.254.169.254", "0.0.0.0", "100.64.0.1", "::1", "fc00::1", "fd12::1",
            "fe80::1", "::ffff:127.0.0.1",
            // ISSUE-236: multicast, reserved, benchmarking, documentation and
            // the IPv6 forms that embed a private IPv4 address.
            "224.0.0.1", "239.255.255.250", "240.0.0.1", "255.255.255.255", "198.18.0.1",
            "198.19.255.255", "192.0.0.1", "192.0.2.1", "198.51.100.1", "203.0.113.1",
            "ff02::1", "64:ff9b::a00:1", "2002:a00:1::1", "::a00:1", "2001:db8::1"
        ]
        for address in addresses {
            XCTAssertFalse(AppUpdateFeedAddressGuard.isPublicAddress(address), address)
        }
    }

    func testClassificationAcceptsPublicAddresses() {
        let addresses = ["8.8.8.8", "172.32.0.1", "100.128.0.1", "2606:4700:4700::1111",
                         "198.20.0.1", "223.255.255.1", "64:ff9b::808:808", "2002:808:808::1"]
        for address in addresses {
            XCTAssertTrue(AppUpdateFeedAddressGuard.isPublicAddress(address), address)
        }
    }

    func testFakeResolverDecidesHostAccess() {
        XCTAssertFalse(AppUpdateFeedAddressGuard.allowsHost("feed.example.com",
                                                            resolve: { _ in ["127.0.0.1"] }))
        XCTAssertFalse(AppUpdateFeedAddressGuard.allowsHost("feed.example.com",
                                                            resolve: { _ in ["8.8.8.8", "10.0.0.1"] }))
        XCTAssertTrue(AppUpdateFeedAddressGuard.allowsHost("feed.example.com",
                                                           resolve: { _ in ["8.8.8.8"] }))
        XCTAssertFalse(AppUpdateFeedAddressGuard.allowsHost("feed.example.com", resolve: { _ in nil }))
        XCTAssertFalse(AppUpdateFeedAddressGuard.allowsHost("feed.example.com", resolve: { _ in [] }))
    }

    func testLoadRejectsPrivateResolutionWithoutRequest() {
        let done = expectation(description: "feed rejected")
        var result: AppUpdateFeedSupport.LoadResult?
        AppUpdateFeedLoader.load(Self.feedURL, resolve: { _ in ["10.0.0.1"] },
                                 configuration: Self.stubbedConfiguration()) { loadResult in
            result = loadResult
            done.fulfill()
        }
        waitForExpectations(timeout: 5)
        switch result {
        case .failed?: break
        default: XCTFail("expected .failed, got \(String(describing: result))")
        }
        XCTAssertEqual(RecordingURLProtocol.requestedHosts, [])
    }

    func testLoadStartsRequestOnlyAfterPublicResolution() {
        let done = expectation(description: "feed answered")
        var result: AppUpdateFeedSupport.LoadResult?
        AppUpdateFeedLoader.load(Self.feedURL, resolve: { _ in ["8.8.8.8"] },
                                 configuration: Self.stubbedConfiguration()) { loadResult in
            result = loadResult
            done.fulfill()
        }
        waitForExpectations(timeout: 5)
        switch result {
        case .absent?: break
        default: XCTFail("expected .absent, got \(String(describing: result))")
        }
        XCTAssertEqual(RecordingURLProtocol.requestedHosts, ["feed.example.com"])
    }

    func testRedirectToNonPublicAddressIsRejected() {
        let redirectURL = URL(string: "https://feed.example.com/redirect.xml")!
        let resolve: AppUpdateFeedAddressGuard.Resolver = { host in
            switch host {
            case "feed.example.com": return ["8.8.8.8"]
            case "internal.example.com": return ["10.0.0.1"]
            default: return nil
            }
        }
        let done = expectation(description: "redirect rejected")
        var result: AppUpdateFeedSupport.LoadResult?
        AppUpdateFeedLoader.load(redirectURL, resolve: resolve,
                                 configuration: Self.stubbedConfiguration()) { loadResult in
            result = loadResult
            done.fulfill()
        }
        waitForExpectations(timeout: 5)
        switch result {
        case .failed?: break
        default: XCTFail("expected .failed, got \(String(describing: result))")
        }
        XCTAssertEqual(RecordingURLProtocol.requestedHosts, ["feed.example.com"])
    }
}

private final class RecordingURLProtocol: URLProtocol {
    /// Hosts of every request the stub accepted, in arrival order.
    static var requestedHosts: [String] = []

    private static let feedHost = "feed.example.com"
    private static let internalHost = "internal.example.com"
    private static let redirectPath = "/redirect.xml"

    override class func canInit(with request: URLRequest) -> Bool {
        guard let host = request.url?.host, host == feedHost || host == internalHost else { return false }
        requestedHosts.append(host)
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url!
        if url.host == Self.feedHost, url.path == Self.redirectPath {
            // Sent as an ordinary 3xx response so URLSession asks the delegate
            // whether to follow the Location header.
            let response = HTTPURLResponse(url: url, statusCode: 302, httpVersion: nil,
                                           headerFields: ["Location": "https://\(Self.internalHost)/latest.yml"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
