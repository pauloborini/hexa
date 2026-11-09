// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import Foundation

/// Pure detection and target enumeration for browser caches and site data.
/// Strictly bounded to registered definitions; never guesses or scans unknown directories.
enum BrowserJunk {

    struct Target: Equatable, Hashable {
        let url: URL
        let identity: UninstallerSupport.FileIdentity?

        init(url: URL, identity: UninstallerSupport.FileIdentity? = nil) {
            self.url = url
            self.identity = identity ?? UninstallerSupport.fileIdentity(at: url)
        }
    }

    struct BrowserFound: Equatable {
        let id: String
        let displayName: String
        let bundleIDs: [String]
        let profileURLs: [URL]

        init(id: String, displayName: String, bundleIDs: [String], profileURLs: [URL]) {
            self.id = id
            self.displayName = displayName
            self.bundleIDs = bundleIDs
            self.profileURLs = profileURLs
        }
    }

    struct BrowserScanResult: Equatable {
        let id: String
        let displayName: String
        let bundleIDs: [String]
        let rootURL: URL
        let cacheTargets: [Target]
        let siteDataTargets: [Target]
        let cacheSize: Int64
        let siteDataSize: Int64
        let accessPending: Bool

        init(id: String,
             displayName: String,
             bundleIDs: [String],
             rootURL: URL,
             cacheTargets: [Target],
             siteDataTargets: [Target],
             cacheSize: Int64,
             siteDataSize: Int64,
             accessPending: Bool) {
            self.id = id
            self.displayName = displayName
            self.bundleIDs = bundleIDs
            self.rootURL = rootURL
            self.cacheTargets = cacheTargets
            self.siteDataTargets = siteDataTargets
            self.cacheSize = cacheSize
            self.siteDataSize = siteDataSize
            self.accessPending = accessPending
        }
    }

    struct Definition: Equatable {
        let id: String
        let displayName: String
        let bundleIDs: [String]
        let profileRootSubpaths: [String]
        let cacheRootSubpaths: [String]
        let profileSubdirectoryPatterns: [String]
        let cacheSubpaths: [String]
        let siteDataSubpaths: [String]
        /// Site data that lives outside the profile roots, relative to the home
        /// folder (the Safari container is the case today).
        let extraSiteDataSubpaths: [String]

        init(id: String,
             displayName: String,
             bundleIDs: [String],
             profileRootSubpaths: [String],
             cacheRootSubpaths: [String] = [],
             profileSubdirectoryPatterns: [String] = [],
             cacheSubpaths: [String],
             siteDataSubpaths: [String],
             extraSiteDataSubpaths: [String] = []) {
            self.id = id
            self.displayName = displayName
            self.bundleIDs = bundleIDs
            self.profileRootSubpaths = profileRootSubpaths
            self.cacheRootSubpaths = cacheRootSubpaths
            self.profileSubdirectoryPatterns = profileSubdirectoryPatterns
            self.cacheSubpaths = cacheSubpaths
            self.siteDataSubpaths = siteDataSubpaths
            self.extraSiteDataSubpaths = extraSiteDataSubpaths
        }
    }

    static let chromiumCacheSubpaths = ["Cache", "Code Cache", "GPUCache"]
    static let chromiumSiteDataSubpaths = ["Cookies", "Local Storage", "IndexedDB", "Service Worker"]

    static let definitions: [Definition] = [
        Definition(
            id: "com.google.Chrome",
            displayName: "Google Chrome",
            bundleIDs: ["com.google.Chrome", "com.google.Chrome.canary"],
            profileRootSubpaths: ["Library/Application Support/Google/Chrome"],
            cacheRootSubpaths: ["Library/Caches/Google/Chrome", "Library/Caches/com.google.Chrome"],
            profileSubdirectoryPatterns: ["Default", "Profile *"],
            cacheSubpaths: chromiumCacheSubpaths,
            siteDataSubpaths: chromiumSiteDataSubpaths
        ),
        Definition(
            id: "com.microsoft.edgemac",
            displayName: "Microsoft Edge",
            bundleIDs: ["com.microsoft.edgemac", "com.microsoft.edgemac.Beta", "com.microsoft.edgemac.Dev", "com.microsoft.edgemac.Canary"],
            profileRootSubpaths: ["Library/Application Support/Microsoft Edge"],
            cacheRootSubpaths: ["Library/Caches/Microsoft Edge", "Library/Caches/com.microsoft.edgemac"],
            profileSubdirectoryPatterns: ["Default", "Profile *"],
            cacheSubpaths: chromiumCacheSubpaths,
            siteDataSubpaths: chromiumSiteDataSubpaths
        ),
        Definition(
            id: "com.brave.Browser",
            displayName: "Brave Browser",
            bundleIDs: ["com.brave.Browser", "com.brave.Browser.beta", "com.brave.Browser.nightly"],
            profileRootSubpaths: ["Library/Application Support/BraveSoftware/Brave-Browser"],
            cacheRootSubpaths: ["Library/Caches/BraveSoftware/Brave-Browser", "Library/Caches/com.brave.Browser"],
            profileSubdirectoryPatterns: ["Default", "Profile *"],
            cacheSubpaths: chromiumCacheSubpaths,
            siteDataSubpaths: chromiumSiteDataSubpaths
        ),
        Definition(
            id: "company.thebrowser.Browser",
            displayName: "Arc",
            bundleIDs: ["company.thebrowser.Browser"],
            profileRootSubpaths: ["Library/Application Support/Arc/User Data", "Library/Application Support/Arc"],
            cacheRootSubpaths: ["Library/Caches/company.thebrowser.Browser", "Library/Caches/Arc"],
            profileSubdirectoryPatterns: ["Default", "Profile *"],
            cacheSubpaths: chromiumCacheSubpaths,
            siteDataSubpaths: chromiumSiteDataSubpaths
        ),
        Definition(
            id: "com.operasoftware.Opera",
            displayName: "Opera",
            bundleIDs: ["com.operasoftware.Opera", "com.operasoftware.OperaNext", "com.operasoftware.OperaDeveloper"],
            profileRootSubpaths: ["Library/Application Support/com.operasoftware.Opera"],
            cacheRootSubpaths: ["Library/Caches/com.operasoftware.Opera"],
            profileSubdirectoryPatterns: ["Default", "Profile *"],
            cacheSubpaths: chromiumCacheSubpaths,
            siteDataSubpaths: chromiumSiteDataSubpaths
        ),
        Definition(
            id: "com.vivaldi.Vivaldi",
            displayName: "Vivaldi",
            bundleIDs: ["com.vivaldi.Vivaldi"],
            profileRootSubpaths: ["Library/Application Support/Vivaldi"],
            cacheRootSubpaths: ["Library/Caches/Vivaldi", "Library/Caches/com.vivaldi.Vivaldi"],
            profileSubdirectoryPatterns: ["Default", "Profile *"],
            cacheSubpaths: chromiumCacheSubpaths,
            siteDataSubpaths: chromiumSiteDataSubpaths
        ),
        Definition(
            id: "org.mozilla.firefox",
            displayName: "Firefox",
            bundleIDs: ["org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition", "org.mozilla.nightly"],
            profileRootSubpaths: ["Library/Application Support/Firefox/Profiles", "Library/Application Support/Firefox"],
            cacheRootSubpaths: ["Library/Caches/Firefox/Profiles", "Library/Caches/Firefox", "Library/Caches/org.mozilla.firefox"],
            profileSubdirectoryPatterns: ["*"],
            cacheSubpaths: ["cache2", "startupCache", "Cache"],
            siteDataSubpaths: ["cookies.sqlite", "storage/default"]
        ),
        Definition(
            id: "com.apple.Safari",
            displayName: "Safari",
            bundleIDs: ["com.apple.Safari"],
            profileRootSubpaths: ["Library/Safari"],
            cacheRootSubpaths: ["Library/Caches/com.apple.Safari",
                                "Library/Containers/com.apple.Safari/Data/Library/Caches/com.apple.Safari"],
            profileSubdirectoryPatterns: [],
            cacheSubpaths: ["WebKitCache", "Cache.db", "fsCachedData"],
            siteDataSubpaths: ["LocalStorage", "Databases", "IndexedDB", "ServiceWorkers"],
            extraSiteDataSubpaths: ["Library/Containers/com.apple.Safari/Data/Library/WebKit/WebsiteData",
                                    "Library/Containers/com.apple.Safari/Data/Library/Cookies/Cookies.binarycookies"]
        )
    ]

    /// Cache roots the scan actually reached, so an orphan root (a browser
    /// without a profile) keeps its generic cache row instead of vanishing.
    static func claimedCacheRoots(for results: [BrowserScanResult],
                                  home: String = NSHomeDirectory()) -> Set<String> {
        let homeURL = URL(fileURLWithPath: home)
        var roots: Set<String> = []
        for result in results {
            guard let def = definitions.first(where: { $0.id == result.id }) else { continue }
            let targetPaths = result.cacheTargets.map { $0.url.standardizedFileURL.path }
            for subpath in def.cacheRootSubpaths {
                let rootPath = homeURL.appendingPathComponent(subpath).standardizedFileURL.path
                if targetPaths.contains(where: { $0 == rootPath || $0.hasPrefix(rootPath + "/") }) {
                    roots.insert(rootPath)
                }
            }
        }
        return roots
    }

    /// Vendor folders directly under `~/Library/Caches` that hold a registered
    /// browser cache root (`Google`, `BraveSoftware`). A generic cache row for
    /// one of these is decomposed into its unclaimed children.
    static func vendorCacheRoots(home: String = NSHomeDirectory()) -> Set<String> {
        let homeURL = URL(fileURLWithPath: home)
        var roots: Set<String> = []
        for def in definitions {
            for subpath in def.cacheRootSubpaths {
                let components = subpath.split(separator: "/").map(String.init)
                guard components.count >= 4,
                      components[0] == "Library",
                      components[1] == "Caches" else { continue }
                let vendorPath = components.prefix(3).joined(separator: "/")
                roots.insert(homeURL.appendingPathComponent(vendorPath).standardizedFileURL.path)
            }
        }
        return roots
    }

    /// Detects installed browsers with profile data under `home`.
    static func detect(home: String = NSHomeDirectory(),
                       fm: FileManager = .default) -> [BrowserFound] {
        let homeURL = URL(fileURLWithPath: home)
        var found: [BrowserFound] = []

        for def in definitions {
            guard let resolved = resolveBrowser(def: def, homeURL: homeURL, fm: fm) else {
                continue
            }
            if resolved.accessPending || !resolved.profiles.isEmpty {
                found.append(BrowserFound(
                    id: def.id,
                    displayName: def.displayName,
                    bundleIDs: def.bundleIDs,
                    profileURLs: resolved.profiles
                ))
            }
        }

        return found
    }

    /// Scans cache and site data targets for all installed browsers.
    static func scanItems(home: String = NSHomeDirectory(),
                          fm: FileManager = .default) -> [BrowserScanResult] {
        let homeURL = URL(fileURLWithPath: home)
        var results: [BrowserScanResult] = []

        for def in definitions {
            guard let resolved = resolveBrowser(def: def, homeURL: homeURL, fm: fm) else {
                continue
            }

            if resolved.accessPending {
                results.append(BrowserScanResult(
                    id: def.id,
                    displayName: def.displayName,
                    bundleIDs: def.bundleIDs,
                    rootURL: resolved.displayRootURL,
                    cacheTargets: [],
                    siteDataTargets: [],
                    cacheSize: 0,
                    siteDataSize: 0,
                    accessPending: true
                ))
                continue
            }

            var cacheTargets: [Target] = []
            var siteDataTargets: [Target] = []

            for profileURL in resolved.profiles {
                // Collect cache targets inside profile folder
                for subpath in def.cacheSubpaths {
                    let targetURL = profileURL.appendingPathComponent(subpath)
                    if isValidTarget(targetURL, profileRootURL: resolved.displayRootURL, fm: fm) {
                        cacheTargets.append(Target(url: targetURL))
                    }
                }

                // Check profile-specific cache roots (e.g. Caches/<vendor>/<browser>/<profile>/<subpath>)
                let profileName = profileURL.lastPathComponent
                for cacheRoot in resolved.cacheRoots {
                    let candidateInCacheRoot = cacheRoot.appendingPathComponent(profileName)
                    for subpath in def.cacheSubpaths {
                        let targetURL = candidateInCacheRoot.appendingPathComponent(subpath)
                        if isValidTarget(targetURL, profileRootURL: resolved.displayRootURL, fm: fm) {
                            cacheTargets.append(Target(url: targetURL))
                        }
                    }
                }

                // Collect site data targets
                for subpath in def.siteDataSubpaths {
                    let targetURL = profileURL.appendingPathComponent(subpath)
                    if isValidTarget(targetURL, profileRootURL: resolved.displayRootURL, fm: fm) {
                        siteDataTargets.append(Target(url: targetURL))
                    }
                }
            }

            // Site data that lives outside the profile roots (Safari container).
            for subpath in def.extraSiteDataSubpaths {
                let targetURL = homeURL.appendingPathComponent(subpath)
                if isValidTarget(targetURL, profileRootURL: resolved.displayRootURL, fm: fm) {
                    siteDataTargets.append(Target(url: targetURL))
                }
            }

            // Safari special case: cache root itself may hold cache files
            if def.id == "com.apple.Safari" {
                for cacheRoot in resolved.cacheRoots {
                    if isValidTarget(cacheRoot, profileRootURL: resolved.displayRootURL, fm: fm) {
                        cacheTargets.append(Target(url: cacheRoot))
                    }
                }
            }

            // Deduplicate targets by path
            let uniqueCache = deduplicateTargets(cacheTargets)
            let uniqueSiteData = deduplicateTargets(siteDataTargets)

            if uniqueCache.isEmpty && uniqueSiteData.isEmpty {
                continue
            }

            let cacheSize = uniqueCache.reduce(0) { $0 + JunkCleaner.directorySize(of: $1.url, fm: fm) }
            let siteDataSize = uniqueSiteData.reduce(0) { $0 + JunkCleaner.directorySize(of: $1.url, fm: fm) }

            results.append(BrowserScanResult(
                id: def.id,
                displayName: def.displayName,
                bundleIDs: def.bundleIDs,
                rootURL: resolved.displayRootURL,
                cacheTargets: uniqueCache,
                siteDataTargets: uniqueSiteData,
                cacheSize: cacheSize,
                siteDataSize: siteDataSize,
                accessPending: false
            ))
        }

        return results
    }

    // MARK: - Validation & Helpers

    /// Exact anchoring: a target must be `<root>/<subpath>` or
    /// `<root>/<one profile component>/<subpath>` for a registered profile or
    /// cache root. A path that merely ends with a known subpath name (for
    /// example another app's `Cookies`) is never accepted.
    static func isSubpathAllowed(_ targetURL: URL,
                                 for definition: Definition,
                                 under homeURL: URL) -> Bool {
        let targetPath = targetURL.standardizedFileURL.path
        let homePath = homeURL.standardizedFileURL.path
        guard targetPath.hasPrefix(homePath + "/") else { return false }

        let rootSubpaths = definition.profileRootSubpaths + definition.cacheRootSubpaths
        let subpaths = definition.cacheSubpaths + definition.siteDataSubpaths
        for rootSubpath in rootSubpaths {
            let rootPath = homeURL.appendingPathComponent(rootSubpath).standardizedFileURL.path
            guard targetPath.hasPrefix(rootPath + "/") else { continue }
            let remainder = String(targetPath.dropFirst(rootPath.count + 1))
            for subpath in subpaths where remainder == subpath || remainder.hasSuffix("/" + subpath) {
                let profileComponent = remainder == subpath
                    ? ""
                    : String(remainder.dropLast(subpath.count + 1))
                if profileComponent.isEmpty || !profileComponent.contains("/") {
                    return true
                }
            }
        }

        // Safari's cache root is itself the target.
        if definition.id == "com.apple.Safari" {
            for rootSubpath in definition.cacheRootSubpaths {
                let rootPath = homeURL.appendingPathComponent(rootSubpath).standardizedFileURL.path
                if targetPath == rootPath { return true }
            }
        }

        // Site data that lives outside the profile roots (Safari container).
        for subpath in definition.extraSiteDataSubpaths {
            if targetPath == homeURL.appendingPathComponent(subpath).standardizedFileURL.path {
                return true
            }
        }

        return false
    }

    private struct ResolvedBrowser {
        let displayRootURL: URL
        let profiles: [URL]
        let cacheRoots: [URL]
        let accessPending: Bool
    }

    private static func resolveBrowser(def: Definition,
                                       homeURL: URL,
                                       fm: FileManager) -> ResolvedBrowser? {
        var existingRoots: [URL] = []
        for subpath in def.profileRootSubpaths {
            let root = homeURL.appendingPathComponent(subpath)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue {
                existingRoots.append(root)
                break
            }
        }

        var existingCacheRoots: [URL] = []
        for subpath in def.cacheRootSubpaths {
            let root = homeURL.appendingPathComponent(subpath)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue {
                existingCacheRoots.append(root)
            }
        }

        if existingRoots.isEmpty && existingCacheRoots.isEmpty {
            return nil
        }

        let primaryRoot = existingRoots.first ?? existingCacheRoots.first!

        // Check readability of primary root
        if !fm.isReadableFile(atPath: primaryRoot.path) {
            return ResolvedBrowser(
                displayRootURL: primaryRoot,
                profiles: [],
                cacheRoots: existingCacheRoots,
                accessPending: true
            )
        }

        // A cache root that exists but cannot be read is the pending state,
        // not an empty browser.
        for root in existingCacheRoots where !fm.isReadableFile(atPath: root.path) {
            return ResolvedBrowser(
                displayRootURL: primaryRoot,
                profiles: [],
                cacheRoots: existingCacheRoots,
                accessPending: true
            )
        }

        var profileURLs: [URL] = []

        for root in existingRoots {
            if !fm.isReadableFile(atPath: root.path) {
                return ResolvedBrowser(
                    displayRootURL: root,
                    profiles: [],
                    cacheRoots: existingCacheRoots,
                    accessPending: true
                )
            }

            guard let entries = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey]) else {
                return ResolvedBrowser(
                    displayRootURL: root,
                    profiles: [],
                    cacheRoots: existingCacheRoots,
                    accessPending: true
                )
            }

            var foundSubProfiles: [URL] = []
            for entry in entries {
                let name = entry.lastPathComponent
                if name.hasPrefix(".") { continue }
                if UninstallerSupport.isSymbolicLink(entry) { continue }

                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: entry.path, isDirectory: &isDir), isDir.boolValue else {
                    continue
                }

                if matchesProfilePattern(name: name, patterns: def.profileSubdirectoryPatterns) {
                    foundSubProfiles.append(entry)
                }
            }

            if !foundSubProfiles.isEmpty {
                profileURLs.append(contentsOf: foundSubProfiles)
            } else if def.profileSubdirectoryPatterns.isEmpty || hasAnyTargetDirectly(in: root, def: def, fm: fm) {
                profileURLs.append(root)
            }
        }

        // Deduplicate profiles
        var uniqueProfiles: [URL] = []
        var seenPaths: Set<String> = []
        for p in profileURLs {
            if seenPaths.insert(p.standardizedFileURL.path).inserted {
                uniqueProfiles.append(p)
            }
        }

        // Filter out profiles with zero matching targets if patterns were present
        var activeProfiles: [URL] = []
        for profile in uniqueProfiles {
            if profileHasAnyTarget(profile: profile, cacheRoots: existingCacheRoots, def: def, fm: fm) {
                activeProfiles.append(profile)
            }
        }

        let hasExtras = def.extraSiteDataSubpaths.contains {
            fm.fileExists(atPath: homeURL.appendingPathComponent($0).path)
        }
        if activeProfiles.isEmpty && !hasExtras && def.id != "com.apple.Safari" {
            return nil
        }
        if def.id == "com.apple.Safari" && activeProfiles.isEmpty && existingCacheRoots.isEmpty && !hasExtras {
            return nil
        }

        return ResolvedBrowser(
            displayRootURL: primaryRoot,
            profiles: activeProfiles.isEmpty ? (existingRoots.first.map { [$0] } ?? []) : activeProfiles,
            cacheRoots: existingCacheRoots,
            accessPending: false
        )
    }

    private static func matchesProfilePattern(name: String, patterns: [String]) -> Bool {
        for pattern in patterns {
            if pattern == "*" { return true }
            if pattern == name { return true }
            if pattern.hasSuffix("*") {
                let prefix = String(pattern.dropLast())
                if name.hasPrefix(prefix) { return true }
            }
        }
        return false
    }

    private static func hasAnyTargetDirectly(in url: URL, def: Definition, fm: FileManager) -> Bool {
        for sub in def.cacheSubpaths + def.siteDataSubpaths {
            let target = url.appendingPathComponent(sub)
            if fm.fileExists(atPath: target.path) {
                return true
            }
        }
        return false
    }

    private static func profileHasAnyTarget(profile: URL,
                                            cacheRoots: [URL],
                                            def: Definition,
                                            fm: FileManager) -> Bool {
        for sub in def.siteDataSubpaths + def.cacheSubpaths {
            let target = profile.appendingPathComponent(sub)
            if fm.fileExists(atPath: target.path) {
                return true
            }
        }
        let profileName = profile.lastPathComponent
        for cacheRoot in cacheRoots {
            let targetInCache = cacheRoot.appendingPathComponent(profileName)
            if fm.fileExists(atPath: targetInCache.path) {
                return true
            }
        }
        return false
    }

    private static func isValidTarget(_ url: URL, profileRootURL: URL, fm: FileManager) -> Bool {
        guard fm.fileExists(atPath: url.path) else { return false }
        if UninstallerSupport.isSymbolicLink(url) { return false }
        if url.standardizedFileURL.path == profileRootURL.standardizedFileURL.path { return false }
        return true
    }

    private static func deduplicateTargets(_ targets: [Target]) -> [Target] {
        var seen: Set<String> = []
        var result: [Target] = []
        for t in targets {
            let path = t.url.standardizedFileURL.path
            if seen.insert(path).inserted {
                result.append(t)
            }
        }
        return result
    }
}
