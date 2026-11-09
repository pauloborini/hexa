// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import CryptoKit
import Foundation
import XCTest

/// Pins the copy of the uninstall screen: the description stays as it is and
/// one new line recommends the built-in removal as the complete one, in the
/// 15 languages, without touching what the removal itself does (DEC-031).
final class AdvancedUninstallCopyTests: XCTestCase {
    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // hexaTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // repository root

    private static let languageFolder = "Sources/Hexa/Core/Localizations"
    private static let coreLocalization = "Sources/Hexa/Core/Localization.swift"
    private static let uninstallScreen = "Sources/Hexa/UI/Settings/AdvancedSettings.swift"
    private static let uninstaller = "Sources/Hexa/Support/Uninstaller.swift"

    /// The uninstall strings that were already on the screen before the
    /// recommendation line existed. D3 keeps them identical.
    private static let preExistingKeys = [
        "advancedUninstallSection",
        "advancedUninstallDescription",
        "advancedUninstallButton",
        "advancedUninstallConfirmTitle",
        "advancedUninstallConfirmBody",
        "advancedUninstallFailedTitle",
        "advancedUninstallFailedBody",
        "advancedUninstallTrashFailedBody",
    ]

    /// Golden digest of the copy that was already on the screen, one per
    /// file. Provenance: the source as it stood before the pack added the
    /// recommendation line (commit 8f48ee4, 2026-10-28). D3 keeps the
    /// description, the confirmation and the failure alert identical, so
    /// changing any of them has to be a deliberate act, not a side effect.
    private static let copyDigests: [String: String] = [
        "Sources/Hexa/Core/Localization.swift":
            "00a5c834af18b7e0e23e7c7880aa05eef952a657cb5d5d397035bac448b6d612",
        "Sources/Hexa/Core/Localizations/Strings+ChineseSimplified.swift":
            "f3143ab7dc48aa78816c3bfb966219c4b1e57f22ac781e3118fb40f25c4b48de",
        "Sources/Hexa/Core/Localizations/Strings+ChineseTraditionalHK.swift":
            "ab282762638e90612447e8bb6f1fed9dd304c38ccbeb0bfe6a4688d68677808a",
        "Sources/Hexa/Core/Localizations/Strings+ChineseTraditionalTW.swift":
            "9b9be2c1e816e2f48f2d354682e2284a1f04bbe123c5339535d51b6f95232cce",
        "Sources/Hexa/Core/Localizations/Strings+French.swift":
            "30fb07d81db20c52be6173c77049d474df14bd44e9f5926a548ca266167024f5",
        "Sources/Hexa/Core/Localizations/Strings+German.swift":
            "e4c635c4e1cb125f5f82d5c826fb27cd670a1eb42bc6c0fde16f598b844a0c5f",
        "Sources/Hexa/Core/Localizations/Strings+Italian.swift":
            "06ddfd94dad3097e07195bec11a5ce0203877e5933d1d3ead23adbb7b6eb4223",
        "Sources/Hexa/Core/Localizations/Strings+Japanese.swift":
            "10aca6f8017b267f39ad3f426defd5f600d206ae0bcff688dda7d03eb9e11883",
        "Sources/Hexa/Core/Localizations/Strings+Korean.swift":
            "e9df4d1947bc715baa68dc064858ff44e9e6510b8b9370aff6221282fc09cd07",
        "Sources/Hexa/Core/Localizations/Strings+Russian.swift":
            "7d832cb8d458e4b0704dab9ab191441a0172c56fe43f16401ed976ea999f163d",
        "Sources/Hexa/Core/Localizations/Strings+Slovak.swift":
            "310947bf390056222bfd003ff8f8c2126ce86356b5de0a3b805af25b25c6830c",
        "Sources/Hexa/Core/Localizations/Strings+Spanish.swift":
            "3efc8222c637c336873776a3e171cb86b2c82aee90445eb259c2a27397a6a312",
        "Sources/Hexa/Core/Localizations/Strings+Turkish.swift":
            "167aeb90042069fe95291ca25477cf6e4074f8610c46cd2d03a0164d4d7f3418",
        "Sources/Hexa/Core/Localizations/Strings+Ukrainian.swift":
            "ebcfc6e07c1b4bddc97499039293661555a54c1086f7e69a247802a4271e6fc1",
    ]

    // MARK: - The key in the 15 languages

    func testAdvancedUninstallRecommendedInAllFifteenLanguages() throws {
        let core = try source(Self.coreLocalization)
        // The property is declared once, next to the other uninstall strings.
        XCTAssertEqual(core.components(separatedBy: "let advancedUninstallRecommended: String").count - 1,
                       1,
                       "A declaração `let advancedUninstallRecommended: String` deve existir uma única vez")

        // Every language block initializes the key with a value of its own.
        // The core file carries pt-BR and en; the other 13 live in their files.
        var total = 0
        var phrases: [String] = []
        let coreCount = core.components(separatedBy: "advancedUninstallRecommended: \"").count - 1
        XCTAssertEqual(coreCount, 2, "Localization.swift carrega pt-BR e en")
        total += coreCount
        phrases += values(of: "advancedUninstallRecommended", in: core)

        for file in try Self.languageFiles() {
            let text = try String(contentsOf: file, encoding: .utf8)
            let count = text.components(separatedBy: "advancedUninstallRecommended: \"").count - 1
            XCTAssertEqual(count, 1,
                           "O bloco \(file.lastPathComponent) deve inicializar `advancedUninstallRecommended` exatamente uma vez")
            total += count
            phrases += values(of: "advancedUninstallRecommended", in: text)
        }
        XCTAssertEqual(total, 15,
                       "A chave `advancedUninstallRecommended` precisa estar nos 15 idiomas, sem bloco duplicado")
        // Each language carries its own phrase: an empty sentence or one
        // copied from a neighbour is not a translation.
        for phrase in phrases {
            XCTAssertFalse(phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                           "A frase de recomendação não pode estar vazia")
        }
        XCTAssertEqual(Set(phrases).count, 15,
                       "Cada idioma precisa da sua própria frase de recomendação")
    }

    /// The literal values assigned to `key` in `text`.
    private func values(of key: String, in text: String) -> [String] {
        var found: [String] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(key + ": \"") else { continue }
            let afterPrefix = trimmed.dropFirst(key.count + 3)
            guard let end = afterPrefix.firstIndex(of: "\"") else { continue }
            found.append(String(afterPrefix[afterPrefix.startIndex..<end]))
        }
        return found
    }

    // MARK: - The screen

    func testAdvancedSettingsRendersRecommendationInSection() throws {
        let screen = try source(Self.uninstallScreen)
        let section = try XCTUnwrap(body(of: screen, startingAt: "HexaSection(l10n.s.advancedUninstallSection) {"))

        let description = try XCTUnwrap(section.range(
            of: #"Text\(l10n\.s\.advancedUninstallDescription\)\s*\.hexaCaption\(\)"#,
            options: .regularExpression))
        let recommendation = try XCTUnwrap(section.range(
            of: #"Text\(l10n\.s\.advancedUninstallRecommended\)\s*\.hexaCaption\(\)"#,
            options: .regularExpression))

        // The line comes right after the description, with the same primitive.
        XCTAssertLessThan(description.upperBound, recommendation.lowerBound)
        let between = section[description.upperBound..<recommendation.lowerBound]
        XCTAssertTrue(between.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      "A linha de recomendação vem imediatamente após a descrição")

        // It lives inside the uninstall section and nowhere else.
        let sectionRange = try XCTUnwrap(bodyRange(of: screen, startingAt: "HexaSection(l10n.s.advancedUninstallSection) {"))
        let occurrence = try XCTUnwrap(screen.range(of: "l10n.s.advancedUninstallRecommended"))
        XCTAssertTrue(sectionRange.contains(occurrence),
                      "A linha de recomendação pertence à seção de desinstalação")

        // The promise the screen already made is still there.
        for reference in ["l10n.s.advancedUninstallDescription",
                          "l10n.s.advancedUninstallButton",
                          "l10n.s.advancedUninstallConfirmTitle",
                          "l10n.s.advancedUninstallConfirmBody",
                          "l10n.s.advancedUninstallFailedTitle",
                          "l10n.s.advancedUninstallFailedBody"] {
            XCTAssertTrue(screen.contains(reference), "A referência \(reference) sumiu da tela")
        }
    }

    func testUninstallButtonStaysDisabledWhileRunning() throws {
        let screen = try source(Self.uninstallScreen)
        XCTAssertTrue(screen.contains(".disabled(uninstalling)"),
                      "O botão de desinstalar segue desabilitado durante a execução")
        let section = try XCTUnwrap(body(of: screen, startingAt: "HexaSection(l10n.s.advancedUninstallSection) {"))
        // The line is static: it is not gated by the running state.
        XCTAssertTrue(section.contains("l10n.s.advancedUninstallRecommended"))
        // The running state carries a visual indicator of its own, and never
        // the line: the removal waits for the helper off the main thread.
        let running = try XCTUnwrap(body(of: section, startingAt: "if uninstalling {"),
                                    "A desinstalação em andamento precisa de um indicador visual na seção")
        XCTAssertTrue(running.contains("ProgressView"),
                      "A desinstalação em andamento precisa de um indicador visual de progresso")
        XCTAssertFalse(running.contains("advancedUninstallRecommended"),
                       "A linha não pode desaparecer do corpo durante a execução")
    }

    /// The copy that was already on the screen before the recommendation line
    /// existed. D3 keeps it identical, so its values are pinned.
    func testTheExistingUninstallCopyKeepsItsValues() throws {
        for (path, expected) in Self.copyDigests {
            let text = try source(path)
            let values = text.split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { line in Self.preExistingKeys.contains { line.hasPrefix($0 + ": \"") } }
            XCTAssertEqual(values.count, path == Self.coreLocalization ? 16 : 8,
                           "`\(path)` precisa manter as strings de desinstalação que já existiam")
            let body = Data(values.joined(separator: "\n").utf8)
            let digest = SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
            XCTAssertEqual(digest, expected,
                           "A copy de desinstalação que já existia mudou em `\(path)`; D3 manda mantê-la idêntica")
        }
    }

    func testStoppedAlertRemainsIntact() throws {
        let screen = try source(Self.uninstallScreen)
        // The alert of the stopped removal keeps its title and its body.
        let alert = try XCTUnwrap(screen.range(
            of: #"\.alert\(l10n\.s\.advancedUninstallFailedTitle, isPresented: \$uninstallStopped\) \{[\s\S]*?\} message: \{[\s\S]*?Text\(l10n\.s\.advancedUninstallFailedBody\)"#,
            options: .regularExpression))
        XCTAssertNotNil(alert)
        // The line of the screen is still there when the alert is closed.
        let section = try XCTUnwrap(body(of: screen, startingAt: "HexaSection(l10n.s.advancedUninstallSection) {"))
        XCTAssertTrue(section.contains("l10n.s.advancedUninstallRecommended"))
    }

    // MARK: - What the removal delivers

    func testUninstallerKeepsDec031Set() throws {
        let uninstaller = try source(Self.uninstaller)

        // Sleep and the rule go back in one privileged request, read back after.
        let restore = try XCTUnwrap(body(of: uninstaller, startingAt: "private static func restoreSleepAndRemoveRule()"))
        XCTAssertTrue(restore.contains("Sudoers.removalCommand"))
        XCTAssertTrue(restore.contains("AdminShell.runSync"))
        XCTAssertEqual(restore.components(separatedBy: "Sudoers.ruleFilesPresent").count - 1,
                       2,
                       "A regra é conferida antes e reconferida depois da remoção")

        // The whole set, in the order it has today.
        let fromApp = try XCTUnwrap(body(of: uninstaller, startingAt: "static func runFromApp(onStop:"))
        assertOrder(["restoreSleepAndRemoveRule",
                     "FanControlService.restoreAndUnregisterForRemoval",
                     "restoreShortcuts",
                     "unregisterLoginItem"], in: fromApp)

        let andExit = try XCTUnwrap(body(of: uninstaller, startingAt: "static func runAndExit()"))
        assertOrder(["restoreShortcuts",
                     "FanControlService.restoreAndUnregisterForRemoval",
                     "restoreSleepAndRemoveRule",
                     "unregisterLoginItem",
                     "moveDataToTrash",
                     "erasePreferences"], in: andExit)

        let onTerminate = try XCTUnwrap(body(of: uninstaller, startingAt: "static func finishOnTerminateIfNeeded()"))
        XCTAssertTrue(onTerminate.contains("moveDataToTrash"))
        XCTAssertTrue(onTerminate.contains("erasePreferences"))
    }

    // MARK: - Helpers

    private func source(_ path: String) throws -> String {
        try String(contentsOf: Self.repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    private static func languageFiles() throws -> [URL] {
        let directory = repoRoot.appendingPathComponent(languageFolder)
        let files = try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("Strings+") && $0.pathExtension == "swift" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        XCTAssertEqual(files.count, 13, "Devem existir 13 arquivos de idioma em \(languageFolder)")
        return files
    }

    private func assertOrder(_ symbols: [String], in source: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        var cursor = source.startIndex
        for symbol in symbols {
            let range = source.range(of: symbol, range: cursor..<source.endIndex)
            XCTAssertNotNil(range, "`\(symbol)` não aparece depois do passo anterior", file: file, line: line)
            cursor = range?.lowerBound ?? cursor
        }
    }

    /// The body of the declaration that starts at `marker`, braces counted.
    private func body(of source: String, startingAt marker: String) -> String? {
        guard let range = bodyRange(of: source, startingAt: marker) else { return nil }
        return String(source[range])
    }

    /// The range of the body of the declaration that starts at `marker`.
    private func bodyRange(of source: String, startingAt marker: String) -> Range<String.Index>? {
        guard let start = source.range(of: marker) else { return nil }
        var depth = 0
        var opened = false
        var index = start.lowerBound
        while index < source.endIndex {
            let character = source[index]
            if character == "{" {
                depth += 1
                opened = true
            } else if character == "}" {
                depth -= 1
                if opened, depth == 0 {
                    return start.lowerBound..<source.index(after: index)
                }
            }
            index = source.index(after: index)
        }
        return nil
    }
}
