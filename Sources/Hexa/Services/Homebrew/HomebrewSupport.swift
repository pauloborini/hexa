// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Darwin
import Foundation

enum HomebrewPackageKind: String, CaseIterable, Identifiable {
    case cask
    case formula

    var id: String { rawValue }
}

struct HomebrewPackage: Identifiable, Hashable {
    let kind: HomebrewPackageKind
    let name: String
    var displayName: String
    var update: HomebrewPackageUpdate?
    /// nil when brew does not report it (older brew, casks, search results).
    var installedOnRequest: Bool?
    /// Installed formulae this package needs, as brew names them: the runtime
    /// closure for a formula, the declared formulae for a cask.
    var requires: [String] = []

    var id: String { "\(kind.rawValue):\(name)" }
    var hasUpdateAvailable: Bool { update != nil }
}

struct HomebrewPackageUpdate: Hashable {
    let kind: HomebrewPackageKind
    let name: String
    let installedVersions: [String]
    let currentVersion: String
    let isPinned: Bool

    var id: String { "\(kind.rawValue):\(name)" }

    var installedText: String {
        installedVersions.joined(separator: ", ")
    }

    var versionSummary: String {
        let installed = installedText
        return installed.isEmpty ? currentVersion : "\(installed) -> \(currentVersion)"
    }
}

/// An installed cask as the catalog describes it, including which app
/// bundles it drops into the Applications folder. The app update check needs
/// that link to read the version the app itself reports.
struct HomebrewCaskRecord: Hashable {
    let token: String
    let displayName: String
    let installedVersion: String?
    let appFileNames: [String]
    let appPaths: [String]

    init(token: String,
         displayName: String,
         installedVersion: String?,
         appFileNames: [String],
         appPaths: [String] = []) {
        self.token = token
        self.displayName = displayName
        self.installedVersion = installedVersion
        self.appFileNames = appFileNames
        self.appPaths = appPaths
    }
}

enum HomebrewOwnershipSupport {
    /// Resolves a package only when its catalog points at this exact app.
    /// A symlink and the bundle it points at are the same app. A same-named
    /// copy elsewhere must never make an unrelated package eligible for a
    /// destructive command.
    static func packageManagingApplication(atPath rawPath: String,
                                           installed: [HomebrewCaskRecord]) -> HomebrewPackage? {
        let selectedURL = URL(fileURLWithPath: rawPath)
        let selectedPaths: Set<String> = [
            selectedURL.standardizedFileURL.path,
            selectedURL.resolvingSymlinksInPath().standardizedFileURL.path,
        ]
        let exact = installed.filter { record in
            record.appPaths.contains { catalog in
                let catalogURL = URL(fileURLWithPath: catalog)
                let catalogPaths = [
                    catalogURL.standardizedFileURL.path,
                    catalogURL.resolvingSymlinksInPath().standardizedFileURL.path,
                ]
                return catalogPaths.contains { selectedPaths.contains($0) }
            }
        }
        if exact.count == 1 {
            return package(from: exact[0])
        }
        return nil
    }

    private static func package(from record: HomebrewCaskRecord) -> HomebrewPackage {
        HomebrewPackage(kind: .cask,
                        name: record.token,
                        displayName: record.displayName)
    }
}

enum HomebrewDependencyGraph {
    static func display(_ visible: [HomebrewPackage],
                        installed: [HomebrewPackage],
                        groupDependencies: Bool) -> (rows: [HomebrewPackage],
                                                     dependencies: [String: [HomebrewPackage]],
                                                     orphans: [HomebrewPackage]) {
        if groupDependencies { return fold(visible, installed: installed) }
        return (visible, [:], [])
    }

    /// Splits installed packages into rows the person asked for and, under
    /// each, the installed dependencies it reaches. Only packages in `visible`
    /// become rows, so a filter never hides a dependency whose parent it hid.
    /// A dependency nothing visible reaches stays a row of its own. One with a
    /// pending update stays under its parents, and those parents move up with
    /// the packages that have updates. A dependency no installed package needs
    /// any more is an orphan, listed apart with its update if it has one.
    static func fold(_ visible: [HomebrewPackage],
                     installed: [HomebrewPackage]) -> (rows: [HomebrewPackage],
                                                       dependencies: [String: [HomebrewPackage]],
                                                       orphans: [HomebrewPackage]) {
        guard installed.contains(where: { $0.installedOnRequest != nil }) else { return (visible, [:], []) }
        var byName: [String: HomebrewPackage] = [:]
        for package in installed where package.kind == .formula {
            byName[package.name] = package
            // Dependency lists name core formulae by their short token.
            let short = (package.name as NSString).lastPathComponent
            if byName[short] == nil { byName[short] = package }
        }

        let visibleIDs = Set(visible.map(\.id))
        var dependencies: [String: [HomebrewPackage]] = [:]
        var reached: Set<String> = []
        var needed: Set<String> = []
        for root in installed where root.installedOnRequest != false {
            var seen: Set<String> = [root.id]
            var found: [HomebrewPackage] = []
            var queue = root.requires
            while let next = queue.popLast() {
                guard let package = byName[next], seen.insert(package.id).inserted else { continue }
                found.append(package)
                queue += package.requires
            }
            needed.formUnion(found.map(\.id))
            guard visibleIDs.contains(root.id), !found.isEmpty else { continue }
            dependencies[root.id] = found.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            reached.formUnion(found.map(\.id))
        }
        let listed = visible.filter {
            $0.installedOnRequest != false || (needed.contains($0.id) && !reached.contains($0.id))
        }
        let hasUpdates: (HomebrewPackage) -> Bool = { package in
            package.hasUpdateAvailable || dependencies[package.id]?.contains(where: \.hasUpdateAvailable) == true
        }
        let rows = listed.filter(hasUpdates) + listed.filter { !hasUpdates($0) }
        let orphans = visible.filter {
            $0.installedOnRequest == false && !needed.contains($0.id)
        }
        return (rows, dependencies, orphans)
    }
}

enum HomebrewPackageOrdering {
    static func updatesFirst(_ packages: [HomebrewPackage]) -> [HomebrewPackage] {
        packages.filter(\.hasUpdateAvailable) + packages.filter { !$0.hasUpdateAvailable }
    }
}

struct HomebrewCommand: Equatable {
    let executable: String
    let arguments: [String]
}

struct HomebrewOperation {
    enum Action {
        case uninstall
        case upgradeAll

        var runningSystemImage: String {
            switch self {
            case .uninstall:
                return "trash.circle.fill"
            case .upgradeAll:
                return "arrow.up.circle.fill"
            }
        }
    }

    let action: Action
    let package: HomebrewPackage?
}

enum HomebrewOperationPhase: Equatable {
    case preparing
    case downloading
    case uninstalling
    case upgrading
    case finalizing
    case refreshing
}

enum HomebrewOperationResult: Equatable {
    case running
    case succeeded
    case failed
    case cancelled
    case needsTerminal
}

struct HomebrewOperationStatus: Equatable {
    var action: HomebrewOperation.Action
    var package: HomebrewPackage?
    var phase: HomebrewOperationPhase
    var result: HomebrewOperationResult
    var progressFraction: Double?
    var startedAt: Date
    var finishedAt: Date?
    var lastActivity: String?

    var isActive: Bool {
        result == .running
    }

    var targetID: String {
        package?.id ?? "homebrew:\(action)"
    }
}

struct HomebrewPendingAction {
    let action: HomebrewOperation.Action
    let package: HomebrewPackage?

    init(action: HomebrewOperation.Action, package: HomebrewPackage? = nil) {
        self.action = action
        self.package = package
    }
}

enum HomebrewCommandBuilder {
    static let candidatePaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
    static var currentShellPath: String {
        if let shell = getpwuid(getuid())?.pointee.pw_shell {
            return String(cString: shell)
        }
        return ProcessInfo.processInfo.environment["SHELL"] ?? ""
    }

    /// First candidate whose binary passes `isTrustedBrewBinary`. A rejected
    /// binary counts as missing, so the caller behaves as if brew were not
    /// installed.
    static func trustedBrewPath(candidates: [String] = candidatePaths) -> String? {
        candidates.first { isTrustedBrewBinary(atPath: $0) }
    }

    /// Accepts a brew binary only when the file that runs is a regular
    /// executable owned by root or the current user, and neither it nor any
    /// directory above it (as written or as resolved) is world-writable. A
    /// world-writable file or directory lets another local account swap in
    /// code that runs with the app's environment.
    private static func isTrustedBrewBinary(atPath path: String) -> Bool {
        guard isTrustedDirectoryChain(from: (path as NSString).deletingLastPathComponent) else {
            return false
        }
        guard let resolved = realpath(path, nil) else { return false }
        defer { free(resolved) }
        let resolvedPath = String(cString: resolved)
        var info = stat()
        guard stat(resolvedPath, &info) == 0,
              info.st_mode & S_IFMT == S_IFREG,
              access(resolvedPath, X_OK) == 0,
              info.st_mode & S_IWOTH == 0,
              info.st_uid == 0 || info.st_uid == getuid() else { return false }
        return isTrustedDirectoryChain(from: (resolvedPath as NSString).deletingLastPathComponent)
    }

    /// Every directory from `directory` up to "/" must be a directory owned by
    /// root or the current user and not world-writable.
    private static func isTrustedDirectoryChain(from directory: String) -> Bool {
        var current = directory
        while true {
            var info = stat()
            guard current.hasPrefix("/"),
                  stat(current, &info) == 0,
                  info.st_mode & S_IFMT == S_IFDIR,
                  info.st_mode & S_IWOTH == 0,
                  info.st_uid == 0 || info.st_uid == getuid() else { return false }
            if current == "/" { return true }
            current = (current as NSString).deletingLastPathComponent
        }
    }

    static func installed(brewPath: String) -> HomebrewCommand {
        HomebrewCommand(executable: brewPath, arguments: ["info", "--json=v2", "--installed"])
    }

    /// Casks the plain listing hides because they carry their own updater.
    /// Those are exactly the apps the update check is for, so it asks for
    /// them explicitly and then checks each app bundle before believing the
    /// answer (see `AppUpdatesSupport.packageUpdates`).
    static func outdatedCasksIncludingSelfUpdating(brewPath: String) -> HomebrewCommand {
        HomebrewCommand(executable: brewPath,
                        arguments: ["outdated", "--cask", "--greedy", "--json=v2"])
    }

    static func outdatedFormulas(brewPath: String) -> HomebrewCommand {
        HomebrewCommand(executable: brewPath,
                        arguments: ["outdated", "--formula", "--json=v2"])
    }

    static func upgradeCasks(brewPath: String, tokens: [String]) -> HomebrewCommand? {
        let valid = tokens.filter(isValidToken)
        guard !valid.isEmpty else { return nil }
        return HomebrewCommand(executable: brewPath,
                               arguments: ["upgrade", "--cask", "--greedy"] + valid)
    }

    /// Upgrades exactly the CLI formulae asked for. Kept apart from the cask
    /// upgrade because a formula token sent with `--cask` either fails or
    /// updates the wrong thing.
    static func upgradeFormulas(brewPath: String, tokens: [String]) -> HomebrewCommand? {
        let valid = tokens.filter(isValidToken)
        guard !valid.isEmpty else { return nil }
        return HomebrewCommand(executable: brewPath,
                               arguments: ["upgrade", "--formula"] + valid)
    }

    static func uninstall(brewPath: String, package: HomebrewPackage) -> HomebrewCommand {
        var args = ["uninstall"]
        if package.kind == .cask { args.append("--cask") }
        args.append(package.name)
        return HomebrewCommand(executable: brewPath, arguments: args)
    }

    static func isValidToken(_ token: String) -> Bool {
        guard !token.isEmpty,
              !token.hasPrefix("-"),
              !token.contains(".."),
              !token.contains("//") else { return false }
        return token.range(of: #"^[A-Za-z0-9][A-Za-z0-9._+@/-]*$"#,
                           options: .regularExpression) != nil
    }

    static func shellCommand(_ command: HomebrewCommand) -> String {
        ([command.executable] + command.arguments).map(shellQuote).joined(separator: " ")
    }

    /// Homebrew 6 refuses to load packages from taps the user never
    /// confirmed ("Refusing to load formula x from untrusted tap owner/repo")
    /// and only offers an interactive prompt in a terminal. The tap name is
    /// extracted here so the app can offer the trust step as one click.
    static func untrustedTapName(fromOutput output: String) -> String? {
        guard let range = output.range(of: #"from untrusted tap ([A-Za-z0-9._-]+/[A-Za-z0-9._-]+)"#,
                                       options: .regularExpression) else { return nil }
        let name = String(output[range])
            .replacingOccurrences(of: "from untrusted tap ", with: "")
            // The refusal ends the sentence right after the name.
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return isValidToken(name) ? name : nil
    }

    static func trustTap(brewPath: String, tap: String) -> HomebrewCommand {
        HomebrewCommand(executable: brewPath, arguments: ["trust", "--tap", tap])
    }

    static func needsTerminalFallback(output: String) -> Bool {
        let lower = output.lowercased()
        return lower.contains("sudo:")
            || lower.contains("a terminal is required")
            || lower.contains("password is required")
            || lower.contains("password:")
            || lower.contains("administrator privileges")
    }

    /// True when the unfinished last line already asks for a password, so the
    /// operation can be stopped before brew waits on a prompt nobody can answer.
    static func isPendingTerminalPrompt(partialLine: String) -> Bool {
        guard !partialLine.isEmpty else { return false }
        return needsTerminalFallback(output: partialLine)
    }

    static func shellQuote(_ value: String) -> String {
        if value.range(of: #"^[A-Za-z0-9._+@%/=:,-]+$"#, options: .regularExpression) != nil {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

enum HomebrewProgressParser {
    private static let percentageRegex = try? NSRegularExpression(pattern: #"([0-9]{1,3}(?:\.[0-9]+)?)%"#)
    private static let ansiRegex = try? NSRegularExpression(pattern: #"\u001B\[[0-9;?]*[ -/]*[@-~]"#)

    static func progressFraction(in output: String) -> Double? {
        var latest: Double?
        guard let regex = percentageRegex else { return nil }
        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        regex.enumerateMatches(in: output, range: range) { match, _, _ in
            guard let match,
                  let valueRange = Range(match.range(at: 1), in: output),
                  let value = Double(output[valueRange]) else { return }
            latest = min(max(value / 100, 0), 1)
        }
        return latest
    }

    static func phase(in output: String,
                      action: HomebrewOperation.Action) -> HomebrewOperationPhase? {
        let lower = stripANSI(output).lowercased()
        if lower.contains("downloading")
            || lower.contains("fetching")
            || lower.contains("downloaded") {
            return .downloading
        }
        if lower.contains("uninstalling")
            || lower.contains("zap")
            || lower.contains("purging") {
            return .uninstalling
        }
        if lower.contains("upgrading")
            || lower.contains("upgraded") {
            return .upgrading
        }
        if lower.contains("installing")
            || lower.contains("pouring")
            || lower.contains("moving app")
            || lower.contains("linking") {
            switch action {
            case .uninstall:
                return .uninstalling
            case .upgradeAll:
                return .upgrading
            }
        }
        if lower.contains("cleanup")
            || lower.contains("cleaning")
            || lower.contains("caveats")
            || lower.contains("summary")
            || lower.contains("installed!")
            || lower.contains("uninstalled") {
            return .finalizing
        }
        return nil
    }

    static func activity(in output: String) -> String? {
        lines(in: output).reversed().first { line in
            let stripped = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !stripped.isEmpty,
                  !stripped.hasPrefix("$ "),
                  !isMostlyProgressSymbols(stripped) else { return false }
            return true
        }
    }

    static func visibleError(from output: String) -> String {
        let candidates = lines(in: output).filter { line in
            let stripped = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return !stripped.isEmpty
                && !stripped.hasPrefix("$ ")
                && !isMostlyProgressSymbols(stripped)
        }
        return candidates.suffix(3).joined(separator: "\n")
    }

    private static func lines(in output: String) -> [String] {
        stripANSI(output)
            .replacingOccurrences(of: "\r", with: "\n")
            .split(whereSeparator: \.isNewline)
            .map(cleanLine)
    }

    private static func cleanLine(_ line: Substring) -> String {
        var value = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasPrefix("==>") {
            value.removeFirst(3)
            value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        while value.hasPrefix("->") {
            value.removeFirst(2)
            value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value
    }

    private static func stripANSI(_ value: String) -> String {
        guard let regex = ansiRegex else {
            return value
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.stringByReplacingMatches(in: value, range: range, withTemplate: "")
    }

    private static func isMostlyProgressSymbols(_ value: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "#=-> .:%0123456789")
        let scalars = value.unicodeScalars.filter { !$0.properties.isWhitespace }
        guard !scalars.isEmpty else { return true }
        let progressCount = scalars.filter { allowed.contains($0) }.count
        return Double(progressCount) / Double(scalars.count) > 0.85
    }
}

enum HomebrewParser {
    /// Installed casks with the app bundles they install, so a package token
    /// can be traced back to the app on disk.
    static func parseInstalledCaskRecords(_ output: String) -> [HomebrewCaskRecord] {
        for json in [output] + balancedJSONObjects(in: output) {
            let data = Data(json.utf8)
            guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let casks = root["casks"] as? [[String: Any]] else { continue }
            return casks.compactMap(parseCaskRecord)
        }
        return []
    }

    private static func parseCaskRecord(_ item: [String: Any]) -> HomebrewCaskRecord? {
        guard let token = item["token"] as? String,
              HomebrewCommandBuilder.isValidToken(token) else { return nil }
        let displayName = (item["name"] as? [String])?.first(where: { !$0.isEmpty }) ?? token
        let installed = item["installed"] as? String
        var appFileNames: [String] = []
        var appPaths: [String] = []
        for artifact in (item["artifacts"] as? [Any] ?? []) {
            guard let entry = artifact as? [String: Any],
                  let apps = entry["app"] as? [Any] else { continue }
            // A package can rename the bundle it installs. Prefer that target
            // name, then keep the source name as a fallback for older output.
            var targets: [String] = []
            var sources: [String] = []
            if let target = entry["target"] as? String { targets.append(target) }
            for app in apps {
                if let source = app as? String {
                    sources.append(source)
                } else if let mapping = app as? [String: Any],
                          let target = mapping["target"] as? String {
                    targets.append(target)
                }
            }
            for candidate in targets.isEmpty ? sources : targets {
                let fileName = URL(fileURLWithPath: candidate).lastPathComponent
                if fileName.hasSuffix(".app"), !appFileNames.contains(fileName) {
                    appFileNames.append(fileName)
                }
            }
            for candidate in targets + sources where candidate.hasPrefix("/") {
                let path = URL(fileURLWithPath: candidate).standardizedFileURL.path
                if path.hasSuffix(".app"), !appPaths.contains(path) {
                    appPaths.append(path)
                }
            }
        }
        return HomebrewCaskRecord(token: token,
                                  displayName: displayName,
                                  installedVersion: installed?.isEmpty == false ? installed : nil,
                                  appFileNames: appFileNames,
                                  appPaths: appPaths)
    }

    static func parseOutdatedJSON(_ data: Data) throws -> [String: HomebrewPackageUpdate] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        let formulae = (root["formulae"] as? [[String: Any]] ?? [])
            .compactMap { parseOutdatedItem($0, kind: .formula) }
        let casks = (root["casks"] as? [[String: Any]] ?? [])
            .compactMap { parseOutdatedItem($0, kind: .cask) }
        return Dictionary(uniqueKeysWithValues: (formulae + casks).map { ($0.id, $0) })
    }

    static func parseOutdatedCommandOutput(_ output: String) throws -> [String: HomebrewPackageUpdate] {
        let data = Data(output.utf8)
        do {
            return try parseOutdatedJSON(data)
        } catch {
            for json in balancedJSONObjects(in: output) {
                let jsonData = Data(json.utf8)
                guard isOutdatedJSONObject(jsonData) else { continue }
                if let updates = try? parseOutdatedJSON(jsonData) {
                    return updates
                }
            }
            throw error
        }
    }

    private static func parseOutdatedItem(_ item: [String: Any],
                                          kind: HomebrewPackageKind) -> HomebrewPackageUpdate? {
        guard let name = (item["name"] as? String) ?? (item["token"] as? String),
              HomebrewCommandBuilder.isValidToken(name),
              let currentVersion = item["current_version"] as? String,
              !currentVersion.isEmpty else { return nil }
        let installedVersions = (item["installed_versions"] as? [String]) ?? []
        return HomebrewPackageUpdate(kind: kind,
                                     name: name,
                                     installedVersions: installedVersions,
                                     currentVersion: currentVersion,
                                     isPinned: item["pinned"] as? Bool ?? false)
    }

    private static func isOutdatedJSONObject(_ data: Data) -> Bool {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        let formulae = root["formulae"] as? [[String: Any]]
        let casks = root["casks"] as? [[String: Any]]
        guard formulae != nil || casks != nil else { return false }
        let items = (formulae ?? []) + (casks ?? [])
        return items.isEmpty || items.contains { item in
            item["current_version"] != nil || item["installed_versions"] != nil
        }
    }

    private static func balancedJSONObjects(in output: String) -> [String] {
        var objects: [String] = []
        var start: String.Index?
        var depth = 0
        var inString = false
        var escaping = false

        var index = output.startIndex
        while index < output.endIndex {
            let character = output[index]

            if start == nil {
                if character == "{" {
                    start = index
                    depth = 1
                    inString = false
                    escaping = false
                }
                index = output.index(after: index)
                continue
            }

            if inString {
                if escaping {
                    escaping = false
                } else if character == "\\" {
                    escaping = true
                } else if character == "\"" {
                    inString = false
                }
            } else if character == "\"" {
                inString = true
            } else if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0, let objectStart = start {
                    let end = output.index(after: index)
                    objects.append(String(output[objectStart..<end]))
                    start = nil
                    depth = 0
                }
                if depth < 0 {
                    start = nil
                    depth = 0
                }
            }

            index = output.index(after: index)
        }

        return objects
    }
}
