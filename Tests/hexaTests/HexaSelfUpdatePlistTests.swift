// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import Foundation
import XCTest

final class HexaSelfUpdatePlistTests: XCTestCase {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func test_package_and_build_embed_sparkle_without_zip_pkg() throws {
        let package = try String(contentsOf: repoRoot.appendingPathComponent("Package.swift"), encoding: .utf8)
        XCTAssertTrue(package.contains(".package(url: \"https://github.com/sparkle-project/Sparkle\", from: \"2.10.1\")"))
        XCTAssertTrue(package.contains(".product(name: \"Sparkle\", package: \"Sparkle\")"))

        let build = try String(contentsOf: repoRoot.appendingPathComponent("build.sh"), encoding: .utf8)
        XCTAssertTrue(build.contains("Contents/Frameworks/Sparkle.framework") || build.contains("\"$CONTENTS/Frameworks/Sparkle.framework\""))
        XCTAssertTrue(build.contains("codesign --force --options runtime --sign \"$SIGN_IDENTITY\" \"$CONTENTS/Frameworks/Sparkle.framework\""))

        let selfUpdate = try contentsOfDirectory(named: "Sources/Hexa/Services/SelfUpdate")
        let joined = selfUpdate.joined(separator: "\n")
        XCTAssertFalse(joined.contains(".zip"))
        XCTAssertFalse(joined.contains(".pkg"))
        XCTAssertFalse(joined.contains("AppUpdateFeedSupport"))
    }

    func test_production_bundle_id_unchanged() throws {
        let build = try String(contentsOf: repoRoot.appendingPathComponent("build.sh"), encoding: .utf8)
        XCTAssertTrue(build.contains("BUNDLE_ID=\"io.github.pauloborini.hexa\""))
        let probeRange = try XCTUnwrap(build.range(of: "if [ \"$PROBE\" = true ]; then"))
        let beforeProbe = String(build[..<probeRange.lowerBound])
        XCTAssertTrue(beforeProbe.contains("BUNDLE_ID=\"io.github.pauloborini.hexa\""))
        XCTAssertFalse(beforeProbe.contains("BUNDLE_ID=\"io.github.pauloborini.hexa.dev\""))
        let heredoc = try infoPlistHeredoc(in: build)
        XCTAssertTrue(heredoc.contains("<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>"))
    }

    func test_no_private_key_and_production_requires_public_file() throws {
        let build = try String(contentsOf: repoRoot.appendingPathComponent("build.sh"), encoding: .utf8)
        let selfUpdate = try contentsOfDirectory(named: "Sources/Hexa/Services/SelfUpdate").joined(separator: "\n")
        let publicFile = (try? String(
            contentsOf: repoRoot.appendingPathComponent("scripts/release/sparkle_ed_public.txt"),
            encoding: .utf8
        )) ?? ""
        let haystack = build + selfUpdate + publicFile
        XCTAssertFalse(haystack.contains("SUPrivateEDKey"))
        XCTAssertFalse(haystack.contains("generate_keys -x"))
        let hexSeed = try NSRegularExpression(pattern: #"[0-9a-fA-F]{64,}"#)
        let matches = hexSeed.matches(in: haystack, range: NSRange(haystack.startIndex..., in: haystack))
        XCTAssertTrue(matches.isEmpty, "seed hex longa de chave privada encontrada")

        XCTAssertTrue(build.contains("test -s \"$PUBLIC_ED_KEY_FILE\""))
        XCTAssertFalse(build.contains("# test -s \"$PUBLIC_ED_KEY_FILE\""))
        XCTAssertTrue(build.contains("scripts/release/sparkle_ed_public.txt"))
        let nonProbe = try nonProbeSparkleBlock(in: build)
        XCTAssertTrue(nonProbe.contains("sparkle_ed_public.txt"))
        XCTAssertTrue(nonProbe.contains("\n  test -s \"$PUBLIC_ED_KEY_FILE\"\n"))
    }

    func test_production_plist_has_stable_feed_and_public_key() throws {
        let build = try String(contentsOf: repoRoot.appendingPathComponent("build.sh"), encoding: .utf8)
        let keys = try sparkleKeysFragment(in: build)
        XCTAssertTrue(keys.contains("<key>SUFeedURL</key><string>https://github.com/pauloborini/hexa/releases/latest/download/appcast.xml</string>"))
        XCTAssertTrue(keys.contains("<key>SUPublicEDKey</key><string>${SPARKLE_PUBLIC_ED_KEY}</string>"))
        XCTAssertTrue(keys.contains("<key>SUEnableAutomaticChecks</key><false/>"))
    }

    func test_sparkle_plist_branch_executes_and_fails_closed() throws {
        let build = try String(contentsOf: repoRoot.appendingPathComponent("build.sh"), encoding: .utf8)
        let block = try sparkleInfoEntriesBlock(in: build)
        // Chave pública publicada pelo próprio Sparkle em
        // Tests/Resources/SUUpdateValidatorTest/EDOnly.bundle/Contents/Info.plist.
        let publicKey = "rhHib+w769W2/6/t+oM1ZxgjBB93BfBKMLO0Qo1etQs="

        let production = try runSparkleBlock(block, probe: false, publicKey: "  \(publicKey)\n\n")
        XCTAssertEqual(production.status, 0)
        XCTAssertTrue(production.output.contains("<key>SUFeedURL</key><string>https://github.com/pauloborini/hexa/releases/latest/download/appcast.xml</string>"))
        XCTAssertTrue(production.output.contains("<key>SUPublicEDKey</key><string>\(publicKey)</string>"))
        XCTAssertTrue(production.output.contains("<key>SUEnableAutomaticChecks</key><false/>"))
        XCTAssertTrue(production.output.contains("<key>SUAutomaticallyUpdate</key><false/>"))

        let probe = try runSparkleBlock(block, probe: true, publicKey: nil)
        XCTAssertEqual(probe.status, 0)
        XCTAssertEqual(probe.output, "")

        let missing = try runSparkleBlock(block, probe: false, publicKey: nil)
        XCTAssertNotEqual(missing.status, 0)
        XCTAssertEqual(missing.output, "")

        let empty = try runSparkleBlock(block, probe: false, publicKey: "")
        XCTAssertNotEqual(empty.status, 0)
        XCTAssertEqual(empty.output, "")
    }

    func test_probe_plist_omits_sparkle_keys() throws {
        let build = try String(contentsOf: repoRoot.appendingPathComponent("build.sh"), encoding: .utf8)
        XCTAssertTrue(build.contains("SPARKLE_INFO_ENTRIES=\"\""))
        XCTAssertTrue(build.contains("if [ \"$PROBE\" != true ]; then"))
        XCTAssertTrue(build.contains("$SPARKLE_INFO_ENTRIES"))
        let keys = try sparkleKeysFragment(in: build)
        XCTAssertTrue(keys.contains("SUFeedURL"))
        let beforeNonProbe = String(build[..<(try XCTUnwrap(build.range(of: "if [ \"$PROBE\" != true ]; then")).lowerBound)])
        XCTAssertFalse(beforeNonProbe.contains("SUFeedURL"))
        XCTAssertFalse(beforeNonProbe.contains("SUPublicEDKey"))
    }

    private func infoPlistHeredoc(in build: String) throws -> String {
        guard let start = build.range(of: "cat > \"$CONTENTS/Info.plist\" <<PLIST"),
              let end = build[start.upperBound...].range(of: "\nPLIST") else {
            XCTFail("heredoc do Info.plist ausente")
            throw TestParseError.missing
        }
        return String(build[start.upperBound..<end.lowerBound])
    }

    private func sparkleKeysFragment(in build: String) throws -> String {
        let block = try nonProbeSparkleBlock(in: build)
        guard let start = block.range(of: "SPARKLE_INFO_ENTRIES=\""),
              let end = block[start.upperBound...].range(of: "\"") else {
            XCTFail("fragmento Sparkle do plist ausente")
            throw TestParseError.missing
        }
        return String(block[start.upperBound..<end.lowerBound])
    }

    private func nonProbeSparkleBlock(in build: String) throws -> String {
        guard let start = build.range(of: "if [ \"$PROBE\" != true ]; then"),
              let end = build[start.upperBound...].range(of: "\nfi") else {
            XCTFail("bloco Sparkle não-probe ausente")
            throw TestParseError.missing
        }
        return String(build[start.lowerBound..<end.upperBound])
    }

    private func sparkleInfoEntriesBlock(in build: String) throws -> String {
        guard let start = build.range(of: "SPARKLE_INFO_ENTRIES=\"\""),
              let end = build[start.upperBound...].range(of: "\nfi") else {
            XCTFail("bloco SPARKLE_INFO_ENTRIES ausente")
            throw TestParseError.missing
        }
        return String(build[start.lowerBound..<end.upperBound])
    }

    private func runSparkleBlock(
        _ block: String,
        probe: Bool,
        publicKey: String?
    ) throws -> (status: Int32, output: String) {
        let sandbox = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        let keyDirectory = sandbox.appendingPathComponent("scripts/release")
        try FileManager.default.createDirectory(at: keyDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sandbox) }
        if let publicKey {
            try publicKey.write(
                to: keyDirectory.appendingPathComponent("sparkle_ed_public.txt"),
                atomically: true,
                encoding: .utf8
            )
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [
            "-c",
            "set -euo pipefail\nPROBE=\(probe ? "true" : "false")\n\(block)\nprintf '%s' \"$SPARKLE_INFO_ENTRIES\"\n"
        ]
        process.currentDirectoryURL = sandbox
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }

    private func contentsOfDirectory(named relative: String) throws -> [String] {
        try contentsOfDirectory(at: repoRoot.appendingPathComponent(relative))
    }

    private func contentsOfDirectory(at url: URL) throws -> [String] {
        let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil)!
        var files: [String] = []
        while let item = enumerator.nextObject() as? URL {
            guard item.pathExtension == "swift" || item.pathExtension == "sh" || item.pathExtension == "txt" else { continue }
            files.append((try? String(contentsOf: item, encoding: .utf8)) ?? "")
        }
        return files
    }
}

private enum TestParseError: Error {
    case missing
}
