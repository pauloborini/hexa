// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Pins the environment brew runs with: a whitelist of the app's variables,
/// a fixed PATH, and the proxy and HOMEBREW_* passthrough.
final class HomebrewEnvironmentTests: XCTestCase {
    private static let canonicalPath =
        "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin"

    private static let appBase: [String: String] = [
        "HOME": "/Users/tester",
        "USER": "tester",
        "LANG": "en_US.UTF-8",
        "PATH": "/tmp/app/bin:/usr/bin",
        "GITHUB_TOKEN": "ghp_example",
        "AWS_SECRET_ACCESS_KEY": "aws_example",
        "SSH_AUTH_SOCK": "/tmp/agent.sock",
        "https_proxy": "http://proxy.local:3128",
        "HOMEBREW_NO_ANALYTICS": "1",
        "HOMEBREW_GITHUB_API_TOKEN": "api_example",
    ]

    func testCredentialsAndSSHAgentAreNotInherited() {
        let result = HomebrewEnvironment.brewEnvironment(base: Self.appBase, shellExports: [:])

        XCTAssertNil(result["GITHUB_TOKEN"])
        XCTAssertNil(result["AWS_SECRET_ACCESS_KEY"])
        XCTAssertNil(result["SSH_AUTH_SOCK"])
    }

    func testProxyAndHomebrewSettingsArePassedThrough() {
        let result = HomebrewEnvironment.brewEnvironment(base: Self.appBase, shellExports: [:])

        XCTAssertEqual(result["https_proxy"], "http://proxy.local:3128")
        XCTAssertEqual(result["HOMEBREW_NO_ANALYTICS"], "1")
    }

    func testHomebrewGitHubAPITokenIsPassedThrough() {
        let result = HomebrewEnvironment.brewEnvironment(base: Self.appBase, shellExports: [:])

        XCTAssertEqual(result["HOMEBREW_GITHUB_API_TOKEN"], "api_example")
    }

    func testNonPassthroughShellExportIsNotCopied() {
        let result = HomebrewEnvironment.brewEnvironment(
            base: Self.appBase,
            shellExports: ["GIT_SSH_COMMAND": "ssh -i /tmp/key"])

        XCTAssertNil(result["GIT_SSH_COMMAND"])
    }

    func testEveryWhitelistedNamePresentInBaseIsCopied() {
        var base: [String: String] = [:]
        for name in HomebrewEnvironment.inheritedNames {
            base[name] = "value-\(name)"
        }

        let result = HomebrewEnvironment.brewEnvironment(base: base, shellExports: [:])

        for name in HomebrewEnvironment.inheritedNames {
            XCTAssertEqual(result[name], "value-\(name)", name)
        }
    }

    func testWhitelistedNameMissingFromBaseStaysMissing() {
        let result = HomebrewEnvironment.brewEnvironment(base: Self.appBase, shellExports: [:])

        XCTAssertNil(result["LOGNAME"])
        XCTAssertNil(result["TMPDIR"])
        XCTAssertNil(result["LC_ALL"])
        XCTAssertNil(result["TERM"])
    }

    func testPathIsCanonicalWhateverTheBasePathIs() {
        let fromApp = HomebrewEnvironment.brewEnvironment(base: Self.appBase, shellExports: [:])
        let withoutPath = HomebrewEnvironment.brewEnvironment(base: [:], shellExports: [:])

        XCTAssertEqual(fromApp["PATH"], Self.canonicalPath)
        XCTAssertEqual(withoutPath["PATH"], Self.canonicalPath)
        XCTAssertEqual(HomebrewEnvironment.canonicalPath, Self.canonicalPath)
    }

    func testShellExportOverridesBaseForPassthroughName() {
        let result = HomebrewEnvironment.brewEnvironment(
            base: Self.appBase,
            shellExports: ["https_proxy": "http://shell.local:8080"])

        XCTAssertEqual(result["https_proxy"], "http://shell.local:8080")
    }
}
