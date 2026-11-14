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

        let publicFile = repoRoot.appendingPathComponent("scripts/release/sparkle_ed_public.txt")
        if FileManager.default.isReadableFile(atPath: publicFile.path),
           let contents = try? String(contentsOf: publicFile, encoding: .utf8) {
            let trimmed = contents.trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertFalse(trimmed.isEmpty)
            XCTAssertTrue(build.contains("pathlib.Path(sys.argv[1]).read_text().strip()"))
        }
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
