// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import Combine
import SwiftUI

struct PermissionGuideConfig: Equatable {
    enum WatcherKind: Equatable {
        case published(PublishedGrant)
        case activeRecheck
    }

    enum PublishedGrant: Equatable {
        case accessibility, screenRecording, fullDiskAccess
    }

    let permissionName: String
    let stepOpen: String
    let stepToggle: String
    let stepReturn: String
    let watcher: WatcherKind
    let requiresRelaunchOnGrant: Bool

    static func config(for kind: PermissionKind, language: AppLanguage) -> PermissionGuideConfig {
        let guide = FeatureStrings.permissionGuide(language)
        let hub = FeatureStrings.hub(language)
        let strings = Strings.localized(language)
        let musicExtras = FeatureStrings.notchMusicExtras(language)

        let name: String
        let watcher: WatcherKind
        let requiresRelaunch: Bool

        switch kind {
        case .accessibility:
            name = strings.permissionAccessibility
            watcher = .published(.accessibility)
            requiresRelaunch = false
        case .screenRecording:
            name = strings.permissionScreenRecording
            watcher = .published(.screenRecording)
            requiresRelaunch = true
        case .fullDiskAccess:
            name = hub.permFullDisk
            watcher = .published(.fullDiskAccess)
            requiresRelaunch = true
        case .automationFinder:
            name = hub.permAutomationFinder
            watcher = .activeRecheck
            requiresRelaunch = false
        case .automationTerminal:
            name = hub.permAutomationTerminal
            watcher = .activeRecheck
            requiresRelaunch = false
        case .automationPlayback(let appName):
            if let appName, !appName.isEmpty {
                name = "\(musicExtras.automationPermission) (\(appName))"
            } else {
                name = musicExtras.automationPermission
            }
            watcher = .activeRecheck
            requiresRelaunch = false
        }

        return PermissionGuideConfig(
            permissionName: name,
            stepOpen: guide.stepOpen,
            stepToggle: guide.stepToggle,
            stepReturn: guide.stepReturn,
            watcher: watcher,
            requiresRelaunchOnGrant: requiresRelaunch
        )
    }
}

/// The automation consent a person asks for from a permission row. The
/// consent call blocks until the prompt is answered, so it runs off the main
/// thread; back on main the row refreshes, and a refusal opens the guide card.
enum AutomationConsentFlow {
    static func request(_ target: Permissions.AutomationTarget,
                        consent: @escaping (String) -> Bool = { AppleScriptRunner.consentToAutomate(bundleID: $0) },
                        showGuide: @escaping (PermissionKind) -> Void = { PermissionGuideOverlay.shared.show(for: $0) },
                        completion: @escaping () -> Void = {}) {
        DispatchQueue.global(qos: .userInitiated).async {
            let granted = consent(target.rawValue)
            DispatchQueue.main.async {
                completion()
                if !granted { showGuide(guideKind(for: target)) }
            }
        }
    }

    static func guideKind(for target: Permissions.AutomationTarget) -> PermissionKind {
        switch target {
        case .finder: return .automationFinder
        case .terminal: return .automationTerminal
        }
    }

    /// The player's consent: only an answer that actually came back refused
    /// opens the card. Nil means the prompt never ran (cancelled, player gone).
    static func playbackGuide(consentGranted: Bool?, appName: String?) -> PermissionKind? {
        consentGranted == false ? .automationPlayback(name: appName) : nil
    }

    /// The consent prompt exists only while the answer is undetermined; once
    /// refused, the switch in System Settings is the only way back.
    static func canAsk(_ status: Permissions.AutomationStatus?) -> Bool { status == .undetermined }
    static func canAsk(_ access: NotchMusicAutomation.Access?) -> Bool { access == .consent }
}

/// The floating permission guide: a small non-activating card that appears
/// when a permission request sends the person to System Settings, walks them
/// through the three steps and notices the grant by itself (the app's
/// permission refresh already observes it). The trip to System Settings and
/// back is where most people give up; this card keeps them company.
///
/// Nothing exists while the card is hidden: the window, the hosting view and
/// the Combine subscription are created on show and released on dismiss.
final class PermissionGuideOverlay {
    static let shared = PermissionGuideOverlay()

    /// Onboarding walks the person through permissions with its own UI, so
    /// the floating card stays out of its way.
    static var suppressed = false

    private var panel: NSPanel?
    private var grantWatcher: AnyCancellable?
    private var activeWatcher: AnyCancellable?
    private var dismissWork: DispatchWorkItem?
    private var staleWork: DispatchWorkItem?
    private let pollingDemandID = UUID()
    /// Long enough for the trip to System Settings and back; short enough
    /// that someone staring at a switch that is already on is not left alone.
    private static let staleAfter: TimeInterval = 12

    private init() {}

    /// What the main thread already knows, without asking the system.
    /// Finder and Terminal automation is only readable through an Apple Event
    /// round trip that can block, and the card opens for them right after the
    /// consent came back refused, so they read as not granted here.
    private func grantedOnMain(_ kind: PermissionKind) -> Bool {
        switch kind {
        case .accessibility:
            return Permissions.shared.accessibility
        case .screenRecording:
            return Permissions.shared.screenRecording
        case .fullDiskAccess:
            return Permissions.shared.fullDiskAccess
        case .automationFinder, .automationTerminal:
            return false
        case .automationPlayback:
            return NotchMusicService.shared.automationAvailability?.access == .granted
        }
    }

    /// Emits the grant for `kind` without a timer: published state for the
    /// TCC permissions, a fresh check each time the app becomes active again
    /// for automation (off the main thread for Finder/Terminal; the music
    /// service's own published answer for the player).
    private func grantPublisher(for kind: PermissionKind, watcher: PermissionGuideConfig.WatcherKind) -> AnyPublisher<Bool, Never> {
        let activation = NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        switch (watcher, kind) {
        case (.published(.accessibility), _):
            return Permissions.shared.$accessibility.eraseToAnyPublisher()
        case (.published(.screenRecording), _):
            return Permissions.shared.$screenRecording.eraseToAnyPublisher()
        case (.published(.fullDiskAccess), _):
            return Permissions.shared.$fullDiskAccess.eraseToAnyPublisher()
        case (.activeRecheck, .automationPlayback):
            activeWatcher = activation
                .receive(on: DispatchQueue.main)
                .sink { _ in NotchMusicService.shared.refreshAutomation() }
            return NotchMusicService.shared.$automationAvailability
                .map { $0?.access == .granted }
                .eraseToAnyPublisher()
        case (.activeRecheck, _):
            let target: Permissions.AutomationTarget = kind == .automationTerminal ? .terminal : .finder
            return activation
                .receive(on: DispatchQueue.global(qos: .userInitiated))
                .map { _ in Permissions.automationStatus(for: target) == .granted }
                .eraseToAnyPublisher()
        }
    }

    func show(for kind: PermissionKind) {
        guard !Self.suppressed else { return }
        // A permission already granted when the request fires opens no card.
        guard !grantedOnMain(kind) else { return }

        Permissions.shared.setActivePermissionSurface(pollingDemandID, visible: false)
        dismissWork?.cancel()
        dismissWork = nil
        staleWork?.cancel()
        staleWork = nil
        grantWatcher = nil
        activeWatcher = nil
        panel?.orderOut(nil)
        panel = nil

        let language = L10n.shared.language
        let guide = FeatureStrings.permissionGuide(language)
        let config = PermissionGuideConfig.config(for: kind, language: language)
        let model = PermissionGuideModel()
        let view = PermissionGuideCard(guide: guide, config: config,
                                       kind: kind, model: model,
                                       onStartOver: { Permissions.shared.startOver(kind) },
                                       onRelaunch: { appDelegate()?.relaunchApp() }) { [weak self] in
            self?.dismiss()
        }
        let stale = DispatchWorkItem { [weak self] in
            model.stale = true
            self?.resizePanelToContent()
        }
        staleWork = stale
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.staleAfter, execute: stale)

        let host = NSHostingView(rootView: view)
        let size = host.fittingSize
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? .zero
        let frame = NSRect(x: visible.maxX - size.width - 20,
                           y: visible.maxY - size.height - 20,
                           width: size.width, height: size.height)

        // Non-activating, so System Settings keeps focus while the card
        // floats above it; joins every Space so the trip back finds it.
        let panel = PermissionGuidePanel(contentRect: frame,
                                 styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = host
        panel.orderFrontRegardless()
        self.panel = panel
        Permissions.shared.setActivePermissionSurface(pollingDemandID, visible: true)

        grantWatcher = grantPublisher(for: kind, watcher: config.watcher)
            .removeDuplicates()
            .filter { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                model.granted = true
                model.stale = false
                self.resizePanelToContent()
                self.staleWork?.cancel()
                // Granted is the end of the wait either way, so the fast
                // polling this card asked for stops here, whether the card
                // leaves or stays.
                Permissions.shared.setActivePermissionSurface(self.pollingDemandID, visible: false)
                // Screen Recording and Full Disk Access apply to a fresh
                // process only, so the card stays with a Relaunch button.
                if !config.requiresRelaunchOnGrant { self.scheduleDismiss() }
            }
    }

    private func resizePanelToContent() {
        DispatchQueue.main.async { [weak self] in
            guard let panel = self?.panel, let host = panel.contentView else { return }
            let size = host.fittingSize
            let previous = panel.frame
            panel.setFrame(NSRect(x: previous.maxX - size.width,
                                  y: previous.maxY - size.height,
                                  width: size.width, height: size.height), display: true)
        }
    }

    /// The success beat stays on screen for a moment, then the card leaves.
    private func scheduleDismiss() {
        dismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.dismiss() }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: work)
    }

    func dismiss() {
        dismissWork?.cancel()
        dismissWork = nil
        staleWork?.cancel()
        staleWork = nil
        grantWatcher = nil
        activeWatcher = nil
        panel?.orderOut(nil)
        panel = nil
        Permissions.shared.setActivePermissionSurface(pollingDemandID, visible: false)
    }
}

private final class PermissionGuidePanel: OverlayPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// The card's mutable state: `granted` flips once when the grant arrives;
/// `stale` once the wait has gone on long enough that the usual cause is an
/// entry left by an earlier copy of the app.
private final class PermissionGuideModel: ObservableObject {
    @Published var granted = false
    @Published var stale = false
}

private struct PermissionGuideCard: View {
    let guide: PermissionGuideStrings
    let config: PermissionGuideConfig
    let kind: PermissionKind
    @ObservedObject var model: PermissionGuideModel
    let onStartOver: () -> Void
    let onRelaunch: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.m) {
            // Cabeçalho: título + fechamento. Sem ícone de accent.
            HStack(alignment: .firstTextBaseline, spacing: HexaTheme.Spacing.s) {
                Text(guide.title)
                    .hexaFont(.heading)
                    .foregroundStyle(HexaTheme.fgPrimary)
                    .lineLimit(1)
                Spacer(minLength: HexaTheme.Spacing.s)
                closeButton
            }

            // Estado: etiqueta com dot (warning pendente, ok concedido) e,
            // enquanto espera, dot pulsante como indicador de forma.
            stateTag

            // Instrução: uma linha de body (a ação que importa) e as duas
            // margens em label secundário, sem bullets nem numeração.
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                Text(config.stepOpen)
                    .hexaFont(.label)
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(config.stepToggle)
                    .hexaFont(.body)
                    .foregroundStyle(HexaTheme.fgPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(config.stepReturn)
                    .hexaFont(.label)
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // A permissão em pauta, como dado em nicho.
            Text(config.permissionName)
                .hexaFont(.data)
                .foregroundStyle(HexaTheme.fgSecondary)
                .padding(.horizontal, HexaTheme.Spacing.s)
                .padding(.vertical, HexaTheme.Spacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                        .fill(HexaTheme.surfaceInset)
                )

            if model.stale, !model.granted, (kind == .accessibility || kind == .screenRecording) {
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                    Text(guide.staleHint)
                        .hexaFont(.label)
                        .foregroundStyle(HexaTheme.fgTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                    neutralButton(guide.startOver, action: onStartOver)
                }
            }

            if model.granted, config.requiresRelaunchOnGrant {
                neutralButton(guide.relaunch, action: onRelaunch)
            }
        }
        .padding(HexaTheme.Spacing.l)
        .frame(width: 320, alignment: .leading)
        .hexaCardSurface(increaseContrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.granted)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.stale)
    }

    /// Etiqueta de estado: `HexaStateTag` quando o resultado é definitivo
    /// (ok concedido) e etiqueta equivalente com dot pulsante enquanto o
    /// progresso segue (fg.secondary + indicador de forma, spec §5).
    @ViewBuilder
    private var stateTag: some View {
        if model.granted {
            HexaStateTag(guide.granted, kind: .ok)
        } else {
            HStack(spacing: HexaTheme.Spacing.s) {
                Circle()
                    .fill(HexaTheme.fgSecondary)
                    .frame(width: 6, height: 6)
                    .modifier(PulseModifier(reduceMotion: reduceMotion))
                Text(guide.waiting)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, HexaTheme.Spacing.s)
            .frame(minHeight: HexaTheme.Density.rowCompact)
            .background(
                RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                    .fill(HexaTheme.surfaceInset)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(guide.waiting))
        }
    }

    private var closeButton: some View {
        HexaIconButton(
            icon: "xmark",
            label: guide.closeHelp,
            variant: .small,
            action: onClose
        )
        .help(guide.closeHelp)
    }

    private func neutralButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(HexaActionButtonStyle())
            .controlSize(.small)
            .focused($focusAction)
    }

    @FocusState private var focusClose: Bool
    @FocusState private var focusAction: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
}

/// Dot de progresso pulsando de forma discreta; sem animação sob reduce motion.
private struct PulseModifier: ViewModifier {
    let reduceMotion: Bool
    @State private var on = false

    func body(content: Content) -> some View {
        content
            .opacity(on ? 0.35 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    on = true
                }
            }
    }
}
