import XCTest
import Foundation

final class PermissionLocalizationTests: XCTestCase {
    static let expectedLanguages: Set<String> = [
        "de", "en-US", "es", "fr", "it", "ja", "ko", "pt-BR", "ru", "sk", "tr", "uk", "zh-HK", "zh-Hans", "zh-TW"
    ]

    static let canonicalKeys: Set<String> = [
        "NSBluetoothAlwaysUsageDescription",
        "NSAudioCaptureUsageDescription",
        "NSCalendarsFullAccessUsageDescription",
        "NSAppleEventsUsageDescription",
        "NSMicrophoneUsageDescription",
        "NSScreenCaptureUsageDescription",
        "NSDesktopFolderUsageDescription",
        "NSDocumentsFolderUsageDescription",
        "NSDownloadsFolderUsageDescription"
    ]

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests/hexaTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repo root
    }

    private func parseStringsFile(at url: URL) throws -> [String: String] {
        let content = try String(contentsOf: url, encoding: .utf8)
        var dict: [String: String] = [:]
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("\"") && trimmed.contains("=") && trimmed.hasSuffix(";") else {
                continue
            }
            // Parse "Key" = "Value";
            guard let equalIndex = trimmed.firstIndex(of: "=") else { continue }
            let keyPart = trimmed[..<equalIndex].trimmingCharacters(in: .whitespaces)
            let valPart = trimmed[trimmed.index(after: equalIndex)...].trimmingCharacters(in: .whitespaces)

            guard keyPart.hasPrefix("\"") && keyPart.hasSuffix("\""),
                  valPart.hasPrefix("\"") && valPart.hasSuffix(";") else {
                continue
            }
            let key = String(keyPart.dropFirst().dropLast())
            var val = String(valPart.dropFirst())
            if val.hasSuffix(";") { val.removeLast() }
            if val.hasSuffix("\"") { val.removeLast() }
            dict[key] = val
        }
        return dict
    }

    private func parseHeredoc(from url: URL) throws -> [String: String] {
        let content = try String(contentsOf: url, encoding: .utf8)
        // Extract block between cat > "$CONTENTS/Info.plist" <<PLIST and \nPLIST
        guard let startRange = content.range(of: "cat > \"$CONTENTS/Info.plist\" <<PLIST"),
              let endRange = content[startRange.upperBound...].range(of: "\nPLIST") else {
            XCTFail("Não foi possível encontrar o heredoc do Info.plist em build.sh")
            return [:]
        }
        let plistSnippet = String(content[startRange.upperBound..<endRange.lowerBound])
        var dict: [String: String] = [:]
        // Look for <key>(NS\w+UsageDescription)</key><string>(.*?)</string>
        let pattern = "<key>(NS\\w+UsageDescription)</key>\\s*<string>(.*?)</string>"
        let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let matches = regex.matches(in: plistSnippet, options: [], range: NSRange(plistSnippet.startIndex..<plistSnippet.endIndex, in: plistSnippet))

        for match in matches {
            guard match.numberOfRanges == 3,
                  let keyRange = Range(match.range(at: 1), in: plistSnippet),
                  let valRange = Range(match.range(at: 2), in: plistSnippet) else {
                continue
            }
            let key = String(plistSnippet[keyRange])
            let val = String(plistSnippet[valRange])
            dict[key] = val
        }
        return dict
    }

    func testCanonicalKeysInEveryLocalization() throws {
        let infoPlistDir = repoRoot.appendingPathComponent("Resources/InfoPlist")
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(atPath: infoPlistDir.path)

        let lprojDirs = contents.filter { $0.hasSuffix(".lproj") }
        let discoveredLangs = Set(lprojDirs.map { $0.replacingOccurrences(of: ".lproj", with: "") })

        XCTAssertEqual(discoveredLangs, Self.expectedLanguages, "O conjunto de línguas .lproj deve ser exatamente os 15 idiomas conhecidos")

        for lang in Self.expectedLanguages {
            let fileURL = infoPlistDir.appendingPathComponent("\(lang).lproj/InfoPlist.strings")
            XCTAssertTrue(fileManager.fileExists(atPath: fileURL.path), "Arquivo não encontrado: \(fileURL.path)")
            let parsed = try parseStringsFile(at: fileURL)

            for key in Self.canonicalKeys {
                guard let val = parsed[key] else {
                    XCTFail("Chave ausente [\(key)] no idioma \(lang)")
                    continue
                }
                XCTAssertFalse(val.trimmingCharacters(in: .whitespaces).isEmpty, "Chave [\(key)] vazia no idioma \(lang)")
            }
        }
    }

    func testHeredocMatchesLocalizationsAndBase() throws {
        let buildShURL = repoRoot.appendingPathComponent("build.sh")
        let heredocDict = try parseHeredoc(from: buildShURL)
        let heredocKeys = Set(heredocDict.keys)

        XCTAssertEqual(heredocKeys, Self.canonicalKeys, "O heredoc do build.sh deve conter exatamente as 9 chaves canônicas")

        let enUSFileURL = repoRoot.appendingPathComponent("Resources/InfoPlist/en-US.lproj/InfoPlist.strings")
        let enUSDict = try parseStringsFile(at: enUSFileURL)

        for key in Self.canonicalKeys {
            XCTAssertEqual(heredocDict[key], enUSDict[key], "Valor base em inglês no heredoc do build.sh deve ser idêntico ao en-US.lproj para [\(key)]")
        }
    }

    func testNoKeyOutsideCanonicalList() throws {
        let buildShURL = repoRoot.appendingPathComponent("build.sh")
        let heredocDict = try parseHeredoc(from: buildShURL)
        for key in heredocDict.keys {
            XCTAssertTrue(Self.canonicalKeys.contains(key), "Chave não-canônica encontrada no heredoc: \(key)")
        }

        let infoPlistDir = repoRoot.appendingPathComponent("Resources/InfoPlist")
        for lang in Self.expectedLanguages {
            let fileURL = infoPlistDir.appendingPathComponent("\(lang).lproj/InfoPlist.strings")
            let parsed = try parseStringsFile(at: fileURL)
            for key in parsed.keys where key.hasPrefix("NS") && key.hasSuffix("UsageDescription") {
                XCTAssertTrue(Self.canonicalKeys.contains(key), "Chave não-canônica encontrada em \(lang).lproj: \(key)")
            }
        }
    }

    /// Sem a chave de uso, o prompt de Gravação de Tela encerra o processo pelo TCC.
    /// A guarda precisa vir antes da chamada de `CGRequestScreenCaptureAccess()` dentro de `requestScreenRecording()`.
    func testScreenRecordingPromptIsGuardedByUsageDescription() throws {
        let permissionsURL = repoRoot.appendingPathComponent("Sources/Hexa/Core/Permissions.swift")
        let content = try String(contentsOf: permissionsURL, encoding: .utf8)

        guard let functionStart = content.range(of: "func requestScreenRecording() {"),
              let functionEnd = content[functionStart.upperBound...].range(of: "\n    }\n") else {
            XCTFail("Não foi possível localizar requestScreenRecording() em Permissions.swift")
            return
        }
        let body = String(content[functionStart.upperBound..<functionEnd.lowerBound])

        guard let guardRange = body.range(of: "guard Self.hasUsageDescription(\"NSScreenCaptureUsageDescription\")"),
              let promptRange = body.range(of: "CGRequestScreenCaptureAccess()") else {
            XCTFail("requestScreenRecording() deve proteger CGRequestScreenCaptureAccess() com hasUsageDescription(\"NSScreenCaptureUsageDescription\")")
            return
        }
        XCTAssertLessThan(guardRange.lowerBound, promptRange.lowerBound,
                          "A guarda de NSScreenCaptureUsageDescription deve vir antes de CGRequestScreenCaptureAccess()")
    }
}
