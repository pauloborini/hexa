// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Foundation

/// Every judgment call of the cleaner in one place: what starts checked in
/// the review list and what never even appears. The rule of thumb is that a
/// find is pre checked only when the evidence is strong and rebuilding the
/// data is cheap; anything based on guessing starts unchecked and waits for
/// the user's eye.
enum CleanerPolicy {
    /// Leftovers are an educated guess against the installed apps oracle, so
    /// they start unchecked and the interface explains what they are.
    static let precheckLeftovers = false

    /// An orphaned startup item needs two independent signals (every
    /// executable gone AND no living owner for its label), so these start
    /// checked; they are the ghosts in Login Items and Extensions.
    static let precheckLoginItems = true

    /// Logs are diagnostic text apps rewrite freely.
    static let precheckLogs = true

    /// Build products and simulator caches regenerate on the next build.
    static let precheckDeveloper = true

    /// Browser caches regenerate on future browsing.
    static let precheckBrowserCaches = true

    /// Browser site data (cookies, storage, offline data) holds user sessions,
    /// so it starts unchecked and requires explicit review.
    static let precheckBrowserSiteData = false

    /// Relative to the home folder. Only ever offered when they exist. The
    /// DeviceSupport folders are debug symbol caches Xcode rebuilds on the
    /// next device connection; they quietly grow to tens of gigabytes and
    /// are a classic slice of the storage macOS files under "Other".
    static let developerJunkPaths: [String] = [
        "/Library/Developer/Xcode/DerivedData",
        "/Library/Developer/Xcode/DocumentationCache",
        "/Library/Developer/CoreSimulator/Caches",
        "/Library/Developer/Xcode/iOS DeviceSupport",
        "/Library/Developer/Xcode/watchOS DeviceSupport",
        "/Library/Developer/Xcode/tvOS DeviceSupport",
    ]

    /// Device backups are the user's safety net: enormous, ancient, and the
    /// other classic tenant of "Other" storage, but never a machine's call
    /// to delete. Every find waits unchecked for the user's eye.
    static let precheckDeviceBackups = false

    /// Forgotten screenshots sit in the user's own folders, so they are
    /// only ever offered, never pre checked: the size is the useful part.
    static let precheckScreenshots = false

    /// Package manager download caches, by exact subpath under the home
    /// folder. The roots of these tools hold configuration and global
    /// executables, so only these six are ever offered. Rebuilding a download
    /// costs bandwidth and can break an offline build, so every find starts
    /// unchecked.
    static let packageCacheSubpaths: [String] = [
        ".npm/_cacache",
        ".gradle/caches",
        ".gradle/wrapper/dists",
        ".pub-cache/hosted",
        ".cache/uv",
        ".cache/puppeteer",
    ]

    static let precheckPackageCaches = false

    /// Exact path test against the six subpaths under `home`. A symbolic link
    /// is never accepted, whatever it points to.
    static func isPackageCacheRemovalAllowed(_ url: URL, home: String) -> Bool {
        let path = url.standardizedFileURL.path
        guard packageCacheSubpaths.contains(where: { path == home + "/" + $0 }) else { return false }
        return !UninstallerSupport.isSymbolicLink(url)
    }

    /// Old Claude Code conversations are offered by age, with the same choices
    /// as forgotten screenshots. Zero turns the search off.
    static let defaultCodingConversationAgeDays = 30

    /// A conversation is offered unchecked: moving it changes the tool's
    /// history, which the user must choose on purpose.
    static let precheckCodingConversations = false

    /// A conversation leaves as a pair: its transcript and its folder, both
    /// direct, UUID named children of `<projectsRoot>/<project>/`. Neither may be
    /// a symbolic link, and each must still be the file or folder the scan saw.
    static func isCodingConversationRemovalAllowed(_ transcript: URL, companion: URL?,
                                                   projectsRoot: String,
                                                   transcriptIdentity: UninstallerSupport.FileIdentity?,
                                                   companionIdentity: UninstallerSupport.FileIdentity?) -> Bool {
        guard transcript.pathExtension == "jsonl", let transcriptIdentity else { return false }
        let uuid = transcript.deletingPathExtension().lastPathComponent
        let project = transcript.deletingLastPathComponent()
        let root = URL(fileURLWithPath: projectsRoot, isDirectory: true)
        guard CleanerSupport.isUUIDName(uuid),
              CleanerSupport.isDirectChild(project, of: root),
              !UninstallerSupport.isSymbolicLink(project),
              !UninstallerSupport.isSymbolicLink(transcript),
              UninstallerSupport.fileIdentity(at: transcript) == transcriptIdentity else { return false }
        guard let companion else { return true }
        guard companion.lastPathComponent == uuid,
              CleanerSupport.isDirectChild(companion, of: project),
              !UninstallerSupport.isSymbolicLink(companion),
              let companionIdentity,
              UninstallerSupport.fileIdentity(at: companion) == companionIdentity else { return false }
        return true
    }

    /// How long a screenshot must go untouched to count as forgotten. Zero
    /// turns the search off.
    static let screenshotAgeChoices = [7, 14, 30, 60, 90]
    static let defaultScreenshotAgeDays = 30

    static func sanitizedScreenshotAgeDays(_ raw: Int) -> Int {
        raw <= 0 ? 0 : min(raw, 3650)
    }

    // MARK: - Large and old files

    /// The fixed age choices of D13, in days: 30, 90, 180 and 365.
    static let largeFileAgeChoices = [30, 90, 180, 365]

    /// Neither threshold has an "off" value: the list always has a rule.
    static let defaultLargeFileAgeDays = 180

    /// The fixed size choices of D13, in megabytes: 100 MB, 500 MB, 1 GB and
    /// 5 GB. The list shows gigabytes for the last two.
    static let largeFileSizeChoicesMegabytes = [100, 500, 1024, 5120]

    static let defaultLargeFileSizeMegabytes = 500

    /// The stored age brought to the nearest fixed choice, so a restored
    /// backup or an older build cannot inject an arbitrary number into the
    /// search. A tie goes to the smaller choice.
    static func sanitizedLargeFileAgeDays(_ raw: Int) -> Int {
        nearest(raw, among: largeFileAgeChoices)
    }

    /// The stored size (in megabytes) brought to the nearest fixed choice,
    /// under the same rule as the age.
    static func sanitizedLargeFileSizeMegabytes(_ raw: Int) -> Int {
        nearest(raw, among: largeFileSizeChoicesMegabytes)
    }

    private static func nearest(_ value: Int, among choices: [Int]) -> Int {
        // The ends are answered before any distance is computed: a stored value
        // can be any Int, and subtracting it from the choices would overflow.
        if value <= choices[0] { return choices[0] }
        if value >= choices[choices.count - 1] { return choices[choices.count - 1] }
        return choices.reduce(choices[0]) { best, choice in
            abs(choice - value) < abs(best - value) ? choice : best
        }
    }

    /// Cache folders that never appear in the list at all: this app's own
    /// data and entries known to break things when removed (audio output
    /// loss, blank Settings panels, service sign outs, plugin licensing),
    /// each learned the hard way by the cleaners that came before.
    private static let hiddenCachePrefixes = [
        "io.github.pauloborini.hexa",
        "CloudKit", "com.apple.bird",
        "com.apple.coreaudio", "com.apple.audio.", "coreaudiod",
        "com.apple.systempreferences", "com.apple.controlcenter",
        "com.apple.finder", "com.apple.dock",
        "com.apple.FontRegistry", "com.apple.ATS",
        "com.apple.akd", "com.apple.AuthKit",
        "com.paceap.", "com.native-instruments", "com.fabfilter",
        // This cache also holds installed customizations that cannot be rebuilt.
        "com.spotify.client",
        // Cloud storage sync clients whose caches contain sync state or replica metadata.
        "com.dropbox.", "com.google.Drive", "com.microsoft.OneDrive", "com.box.desktop",
        "com.apple.CloudPhotosConfiguration",
    ]

    /// Third party caches whose content the user paid bandwidth or setup
    /// for (offline media, model and browser downloads): shown, never pre
    /// checked.
    private static let sensitiveCachePrefixes = [
        "ms-playwright",
    ]

    static func isExcludedCacheEntry(_ name: String) -> Bool {
        let lowered = name.lowercased()
        // A localization name is not evidence of disposable data. Keep the
        // leftover exclusion when the same entry is visited as caches or logs.
        if lowered.hasSuffix(".localized") { return true }
        return hiddenCachePrefixes.contains { lowered.hasPrefix($0.lowercased()) }
    }

    /// Plain named cache folders known to be pure downloads or build junk;
    /// anything plain named outside this list stays unchecked because bare
    /// names cannot be attributed (some are the system's own, like the maps
    /// tile cache).
    private static let safePlainNameCaches: Set<String> = [
        "homebrew", "pip", "node-gyp", "yarn", "npm", "google",
        "electron", "cypress", "typescript", "puppeteer",
    ]

    /// Apple's own caches are safe to remove but the system rebuilds them
    /// eagerly (slower first launches, re indexing), so they are listed for
    /// the willing and pre checked for nobody. Third party caches start
    /// checked unless they hold content worth keeping, and plain named
    /// folders only when they are known download or build caches.
    static func precheckCacheEntry(_ name: String) -> Bool {
        guard !isExcludedCacheEntry(name) else { return false }
        let lowered = name.lowercased()
        if sensitiveCachePrefixes.contains(where: { lowered.hasPrefix($0.lowercased()) }) { return false }
        if CleanerSupport.looksLikeBundleID(name) {
            return !lowered.hasPrefix("com.apple.")
        }
        return safePlainNameCaches.contains(lowered)
    }
}
