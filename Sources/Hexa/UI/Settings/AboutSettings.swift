// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import SwiftUI

// MARK: - About

struct AboutSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.openURL) private var openURL

    var body: some View {
        HexaScreenScaffold(title: l10n.s.tabAbout,
                           subtitle: FeatureStrings.generalSettings(l10n.language).aboutPageDescription) {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.l) {
                // Sem rótulo: o título da página já está no scaffold (DEC-017).
                HexaCard { aboutContent }
                HexaSection(l10n.s.tabSupport) { supportContent }
            }
            .padding(.horizontal, HexaTheme.Spacing.xxl)
        }
        .font(.hexa(.body))
    }

    private var aboutContent: some View {
        VStack(spacing: HexaTheme.Spacing.m) {
            BrandBadge(size: 76)
            VStack(spacing: HexaTheme.Spacing.xs) {
                // Wordmark da marca (spec §1.2): "hexa" com "a" itálico.
                HexaTheme.wordmark(size: 22)
                HStack(spacing: HexaTheme.Spacing.xs) {
                    Text("\(l10n.s.versionPrefix) \(AppInfo.version)")
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgSecondary)
                    if AppInfo.isBeta {
                        HexaStateTag(l10n.s.betaBadgeLabel, kind: .warning)
                    }
                }
                if AppInfo.isDeveloperBuild, let commit = AppInfo.buildCommit {
                    // Dev-only: which source commit this build came from. Never shipped.
                    Text(commit)
                        .font(.hexa(.micro))
                        .foregroundStyle(HexaTheme.fgTertiary)
                        .textSelection(.enabled)
                }
            }
            Text(l10n.s.aboutDescription)
                .font(.hexa(.body))
                .multilineTextAlignment(.center)
                .foregroundStyle(HexaTheme.fgSecondary)
            // Reexecuta o mesmo roteiro de 4 passos da primeira execução, com o
            // estado real de cada módulo e sem tocar no que já foi escolhido.
            Button {
                OnboardingWindow.shared.show(isRedoing: true)
            } label: {
                Label(l10n.s.obRedoOnboarding, hexaIcon: "sparkles")
            }
            .buttonStyle(HexaActionButtonStyle())
            // Toda ação da tela usa o mesmo casco de ação neutra (spec §7).
            Button {
                openURL(AppInfo.downloadURL)
            } label: {
                Label(l10n.s.downloadLatestRelease, hexaIcon: "download")
            }
            .buttonStyle(HexaActionButtonStyle())
            Text(AppInfo.copyright)
                .font(.hexa(.micro))
                .foregroundStyle(HexaTheme.fgTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, HexaTheme.Spacing.xl)
    }

    private var supportContent: some View {
        VStack(spacing: HexaTheme.Spacing.m) {
            VStack(spacing: HexaTheme.Spacing.xs) {
                Text(l10n.s.donateHeading)
                    .font(.hexa(.heading))
                    .foregroundStyle(HexaTheme.fgPrimary)
                    .multilineTextAlignment(.center)
                Text(l10n.s.donateMessage)
                    .font(.hexa(.body))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 460)
            }

            Button {
                openURL(AppInfo.coffeeURL)
            } label: {
                Label(l10n.s.donateButton, hexaIcon: "cup.and.saucer.fill")
            }
            .buttonStyle(HexaActionButtonStyle())

            VStack(spacing: HexaTheme.Spacing.s) {
                Text(l10n.s.supportIntroStarMessage)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    openURL(AppInfo.repositoryURL)
                } label: {
                    Label(l10n.s.supportIntroStarButton, hexaIcon: "star.fill")
                }
                .buttonStyle(HexaActionButtonStyle())
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, HexaTheme.Spacing.l)
    }
}

// MARK: - Release notes

struct ReleaseNotesSettings: View {
    @ObservedObject private var l10n = L10n.shared
    private var notes: ReleaseNotes { ReleaseNotes.current(language: l10n.language) }

    var body: some View {
        HexaScreenScaffold(title: l10n.s.obWhatsNewTitle, subtitle: versionLine) {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.l) {
                if notes.sections.isEmpty {
                    fallbackNote
                } else {
                    ForEach(Array(notes.sections.enumerated()), id: \.offset) { _, section in
                        releaseSection(section)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, HexaTheme.Spacing.xxl)
        }
    }

    private var versionLine: String {
        if let date = notes.date {
            return "v\(notes.version) · \(date)"
        }
        return "v\(notes.version)"
    }

    private var fallbackNote: some View {
        HStack(alignment: .top, spacing: HexaTheme.Spacing.s) {
            HexaIcons.image("checkmark.circle.fill", size: 13)
                .font(.hexa(.body))
                .foregroundStyle(HexaTheme.fgSecondary)
                .frame(width: 18, alignment: .center)
            Text(l10n.s.releaseNotesUnavailable)
                .font(.hexa(.body))
                .foregroundStyle(HexaTheme.fgSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func releaseSection(_ section: ReleaseNoteSection) -> some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            if !section.title.isEmpty {
                SectionLabel(title: section.title)
            }
            ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                releaseItem(item, sectionTitle: section.title)
            }
        }
    }

    @ViewBuilder
    private func releaseItem(_ item: ReleaseNoteItem, sectionTitle: String) -> some View {
        switch item {
        case let .paragraph(text):
            Text(text)
                .font(.hexa(.body))
                .foregroundStyle(HexaTheme.fgPrimary)
                .fixedSize(horizontal: false, vertical: true)
        case let .bullet(text):
            HStack(alignment: .top, spacing: HexaTheme.Spacing.s) {
                HexaIcons.image(iconName(for: sectionTitle), size: 13)
                    .font(.hexa(.body))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .frame(width: 18, alignment: .center)
                Text(text)
                    .font(.hexa(.body))
                    .foregroundStyle(HexaTheme.fgPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case let .image(image):
            if let nsImage = releaseNoteImage(image) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                            .stroke(HexaTheme.borderHairline, lineWidth: HexaTheme.hairline)
                    )
                    .accessibilityLabel(image.alt)
                    .padding(.leading, HexaTheme.Spacing.xxl)
            }
        }
    }

    private func releaseNoteImage(_ image: ReleaseNoteImage) -> NSImage? {
        var path = image.path
        if let resourcesRange = path.range(of: "Resources/") {
            path = String(path[resourcesRange.lowerBound...])
        }
        if path.hasPrefix("Resources/") {
            path.removeFirst("Resources/".count)
        }
        let nsPath = path as NSString
        let ext = nsPath.pathExtension
        let name = (nsPath.deletingPathExtension as NSString).lastPathComponent
        let directory = nsPath.deletingLastPathComponent
        guard !name.isEmpty, !ext.isEmpty else { return nil }
        let subdirectory = directory.isEmpty || directory == "." ? nil : directory
        guard let url = Bundle.main.url(forResource: name,
                                        withExtension: ext,
                                        subdirectory: subdirectory) else { return nil }
        return NSImage(contentsOf: url)
    }

    private func iconName(for title: String) -> String {
        switch title.lowercased() {
        case "added": return "plus.circle.fill"
        case "changed": return "slider.horizontal.3"
        case "fixed": return "checkmark.circle.fill"
        default: return "circle.fill"
        }
    }
}

// MARK: - Support

struct SupportSettings: View {
    var body: some View {
        AboutSettings()
    }
}

// MARK: - Shared permission row

enum PermissionKind: Hashable {
    case accessibility
    case screenRecording
    case fullDiskAccess
    case automationFinder
    case automationTerminal
    case automationPlayback(name: String? = nil)
}

/// Status + actions for one TCC permission; shared by Settings and onboarding.
struct PermissionRow: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @State private var pollingDemandID = UUID()
    @State private var automation: Permissions.AutomationStatus?
    let kind: PermissionKind

    private var granted: Bool {
        switch kind {
        case .accessibility: return permissions.accessibility
        case .screenRecording: return permissions.screenRecording
        case .fullDiskAccess: return permissions.fullDiskAccess
        case .automationFinder, .automationTerminal: return automation == .granted
        case .automationPlayback: return NotchMusicService.shared.automationAvailability?.access == .granted
        }
    }

    /// Finder/Terminal automation is read off the main thread (the Apple
    /// Event check can block), once when the row shows and after a request.
    private func readAutomation() {
        let target: Permissions.AutomationTarget
        switch kind {
        case .automationFinder: target = .finder
        case .automationTerminal: target = .terminal
        case .accessibility, .screenRecording, .fullDiskAccess, .automationPlayback: return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let status = Permissions.automationStatus(for: target)
            DispatchQueue.main.async { automation = status }
        }
    }

    private var name: String {
        switch kind {
        case .accessibility: return l10n.s.permissionAccessibility
        case .screenRecording: return l10n.s.permissionScreenRecording
        case .fullDiskAccess: return FeatureStrings.hub(l10n.language).permFullDisk
        case .automationFinder: return FeatureStrings.hub(l10n.language).permAutomationFinder
        case .automationTerminal: return FeatureStrings.hub(l10n.language).permAutomationTerminal
        case .automationPlayback: return FeatureStrings.notchMusicExtras(l10n.language).automationPermission
        }
    }

    private var accessIcon: String {
        switch kind {
        case .accessibility: return "accessibility"
        case .screenRecording: return "video"
        case .fullDiskAccess: return "internaldrive"
        case .automationFinder: return "finder"
        case .automationTerminal: return "terminal"
        case .automationPlayback: return "play.circle"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            HStack(spacing: HexaTheme.Spacing.s) {
                HexaIcons.image(granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(granted ? HexaTheme.statusOk : HexaTheme.statusWarning)
                Text(name)
                    .font(.hexa(.body))
                Spacer()
                HexaStateTag(granted ? l10n.s.permissionGranted : l10n.s.permissionMissing,
                             kind: granted ? .ok : .warning)
            }
            if !granted {
                HStack(spacing: HexaTheme.Spacing.s) {
                    HexaAccessButton(icon: accessIcon, title: l10n.s.permissionRequest) {
                        switch kind {
                        case .accessibility:
                            permissions.requestAccessibility()
                        case .screenRecording:
                            permissions.requestScreenRecording()
                        case .fullDiskAccess:
                            permissions.requestFullDiskAccess()
                        case .automationFinder:
                            AutomationConsentFlow.request(.finder, completion: readAutomation)
                        case .automationTerminal:
                            AutomationConsentFlow.request(.terminal, completion: readAutomation)
                        case .automationPlayback:
                            NotchMusicService.shared.requestAutomationAccess()
                        }
                    }
                    HexaAccessButton(icon: "gearshape", title: l10n.s.permissionOpenSettings) {
                        switch kind {
                        case .accessibility:
                            permissions.openAccessibilitySettings()
                        case .screenRecording:
                            permissions.openScreenRecordingSettings()
                        case .fullDiskAccess:
                            permissions.openFullDiskAccessSettings()
                        case .automationFinder, .automationTerminal, .automationPlayback:
                            permissions.openAutomationSettings()
                        }
                    }
                }
                .controlSize(.small)
                Button {
                    FeatureWorkspaceWindow.shared.openPermissionsHub()
                } label: {
                    let hub = FeatureStrings.hub(l10n.language)
                    Text(hub.viewAllPermissions)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgTertiary)
                        .underline()
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            permissions.setActivePermissionSurface(pollingDemandID, visible: true)
            readAutomation()
        }
        .onDisappear {
            permissions.setActivePermissionSurface(pollingDemandID, visible: false)
        }
    }
}

// MARK: - Secure input row

/// Secure Event Input blocks every synthetic keystroke. Typing a snippet
/// trigger then does nothing at all, while the snippet library and the
/// Command Bar's typing actions beep; none of the four paths says what is
/// wrong or who is holding it. This row is the only place the app explains
/// that, and it names the holder when the session can attribute it.
///
/// Both call sites instantiate it only once secure input is on, and the
/// snippets page waits for one of its own toggles as well, so the `.off`
/// branch below is there to keep the switch exhaustive and for nothing else.
/// What drives the feature is the polling demand on each page; see
/// `SecureInputObservation`.
struct SecureInputRow: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var monitor = SecureInputMonitor.shared

    var body: some View {
        switch monitor.holder {
        case .off:
            EmptyView()
        case .app(let name, _):
            row(caption: String(format: l10n.s.secureInputHeldFormat, name)) {
                Button(String(format: l10n.s.secureInputRevealFormat, name)) {
                    monitor.revealHolder()
                }
                .buttonStyle(HexaActionButtonStyle())
                .controlSize(.small)
            }
        case .unattributed:
            row(caption: l10n.s.secureInputUnattributed) { EmptyView() }
        case .unknown:
            row(caption: l10n.s.secureInputUnidentified) { EmptyView() }
        }
    }

    private func row<Action: View>(caption: String,
                                   @ViewBuilder action: () -> Action) -> some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            HStack(spacing: HexaTheme.Spacing.s) {
                HexaIcons.image("exclamationmark.circle.fill")
                    .foregroundStyle(HexaTheme.statusWarning)
                Text(l10n.s.secureInputTitle)
                    .font(.hexa(.body))
                Spacer()
            }
            Text(caption)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
                .fixedSize(horizontal: false, vertical: true)
            action()
        }
    }
}

/// Keeps secure input polled for as long as the page is on screen and
/// `isActive` holds, e.g. the snippets page only while one of its own
/// toggles is on, since with both off nothing this row could report can
/// show. The demand cannot live on `SecureInputRow`: nothing would
/// register it until the state it reports had already been reached.
private struct SecureInputObservation: ViewModifier {
    let isActive: Bool
    @State private var demandID = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear { SecureInputMonitor.shared.setObservingSurface(demandID, visible: isActive) }
            .onDisappear { SecureInputMonitor.shared.setObservingSurface(demandID, visible: false) }
            .onChange(of: isActive) { _, active in
                SecureInputMonitor.shared.setObservingSurface(demandID, visible: active)
            }
    }
}

extension View {
    func observesSecureInput(isActive: Bool = true) -> some View {
        modifier(SecureInputObservation(isActive: isActive))
    }
}
