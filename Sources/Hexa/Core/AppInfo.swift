// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Foundation

/// Static identity of the app, shared by UI, notifications and tooling.
enum AppInfo {
    static let name = "Hexa"
    static let copyright = "© 2026 Paulo Borini"
    static let repositoryURL = URL(string: "https://github.com/pauloborini/hexa")!
    static let downloadURL = URL(string: "https://github.com/pauloborini/hexa/releases/latest")!
    static let coffeeURL = URL(string: "https://buymeacoffee.com/pauloborini")!

    /// Versão pública, incluindo o canal beta; o commit é um carimbo separado.
    static var version: String {
        if let value = Bundle.main.object(forInfoDictionaryKey: "HexaReleaseVersion") as? String { return value }
        if let value = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String { return value }
        guard let url = Bundle.module.url(forResource: "ReleaseVersion", withExtension: "txt"),
              let value = try? String(contentsOf: url, encoding: .utf8) else { return "dev" }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True for the local "Hexa (Developer)" build (bundle id ends in `.dev`).
    /// It is never published and never auto-updates; all work is tested here first.
    static var isDeveloperBuild: Bool {
        (Bundle.main.bundleIdentifier ?? "").hasSuffix(".dev")
    }

    /// True when the current version is a pre-release (e.g. 0.2.0-beta.1 or 0.2.0-rc.1).
    static var isBeta: Bool {
        if isDeveloperBuild && UserDefaults.standard.bool(forKey: DefaultsKey.simulateBetaUI) {
            return true
        }
        let v = version.lowercased()
        return v.contains("-beta") || v.contains("-rc") || v.contains("-alpha")
    }

    /// Commit usado no bundle local io.github.pauloborini.hexa gerado por build.sh.
    /// O SHA recebe "-dirty" quando há alterações não commitadas.
    /// Retorna nil quando o bundle não contém o carimbo HexaBuildCommit.
    static var buildCommit: String? {
        Bundle.main.object(forInfoDictionaryKey: "HexaBuildCommit") as? String
    }
}
