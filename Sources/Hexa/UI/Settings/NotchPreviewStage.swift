// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// The one preview of the island in Settings: a section's open page hanging
/// from a slice of menu bar, the gallery of sections, or the island closed at
/// rest, drawn with the island's own views at a scale that fits the column so
/// every option changes the preview the way it changes the island.
struct NotchPreviewStage: View {
    enum Mode: Equatable {
        case page(NotchModule)
        case resting
        case explore
    }

    let mode: Mode
    /// The section is switched off, or the feature behind it is.
    var hidden = false
    /// The island itself is off.
    var enabled = true
    /// Explains the stage where the eye's caption would not say enough.
    var caption: String? = nil

    @ObservedObject private var notch = NotchService.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var monitoring = false
    @State private var monitorLeaseId: UUID? = nil
    @State private var windowVisible = true
    private var editor: NotchEditorStrings { FeatureStrings.notchEditor(l10n.language) }

    private static let captionHeight: CGFloat = 28
    private static let margin: CGFloat = 16
    private static let maxPreviewHeight: CGFloat = 420

    /// As tall as the island at the scale that fits the column, plus the
    /// caption the stage keeps below it.
    static func height(for mode: Mode, width: CGFloat) -> CGFloat {
        let island = islandSize(for: mode)
        return max(72, island.height * scale(island: island, width: width) + captionHeight)
    }

    /// One scale for the column: the island shrinks to the width it has and
    /// to the height the stage accepts, never past its own size.
    private static func scale(island: CGSize, width: CGFloat) -> CGFloat {
        guard island.width > 0, island.height > 0 else { return 1 }
        let effectiveWidth = width > 0 ? width : 320
        let widthScale = (effectiveWidth - margin * 2) / island.width
        let heightScale = (maxPreviewHeight - captionHeight) / island.height
        return max(0.1, min(1, widthScale, heightScale))
    }

    private static func islandSize(for mode: Mode) -> CGSize {
        switch mode {
        case .page(let module): return NotchService.shared.previewSize(for: module)
        case .resting:
            let geometry = restingGeometry()
            return geometry.restingSize(showsContent: NotchService.shared.idleContent != .none)
        case .explore:
            let size = NotchService.shared.geometry.sectionPickerSize(count: max(1, NotchSupport.modules().count))
            // A display that has not measured itself yet still previews the gallery.
            return size.width > 0 && size.height > 0 ? size : CGSize(width: 560, height: 300)
        }
    }

    /// The display's own geometry while it has a camera; a plain one
    /// otherwise, so a Mac without a notch still previews the closed island.
    private static func restingGeometry() -> NotchGeometry {
        let current = NotchService.shared.geometry
        var geometry = current.cameraWidth > 0 ? current : NotchGeometry(
            screen: CGRect(x: 0, y: 0, width: 1440, height: 900),
            safeAreaTop: 32,
            cameraWidth: 210,
            layout: NotchSize(rawValue: UserDefaults.standard.string(forKey: DefaultsKey.notchSize) ?? "") ?? .spacious,
            menuBarHeight: 24)
        geometry.compactSideRoom = 100
        return geometry
    }

    var body: some View {
        GeometryReader { proxy in stage(in: proxy.size) }
            .background(HexaTheme.surfaceRaised)
            .background(NotchPreviewVisibilityReader { windowVisible = $0 })
            .clipShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.panel, style: .continuous))
            .overlay(alignment: .bottomLeading) { captionLabel }
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(editor.preview)
            .accessibilityValue(accessibilityValue)
            .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: mode)
            .onAppear { monitor(wanted: windowVisible) }
            .onChange(of: mode) { _, _ in monitor(wanted: windowVisible) }
            .onChange(of: windowVisible) { _, visible in monitor(wanted: visible) }
            .onDisappear { monitor(wanted: false) }
    }

    private func stage(in stageSize: CGSize) -> some View {
        switch mode {
        case .page(let module): return AnyView(pageStage(module: module, in: stageSize))
        case .resting: return AnyView(restingStage(in: stageSize))
        case .explore: return AnyView(exploreStage(in: stageSize))
        }
    }

    /// The section's own page at the island's size, with the header it has
    /// there and the shortcuts bar below it, scaled into the column.
    private func pageStage(module: NotchModule, in stageSize: CGSize) -> some View {
        let geometry = notch.previewGeometry(for: module)
        let size = notch.previewSize(for: module)
        let scale = Self.scale(island: size, width: stageSize.width)
        let scaledWidth = max(size.width * scale, 1)
        let scaledHeight = max(size.height * scale, 1)
        return ZStack(alignment: .top) {
            menuBarStrip(height: geometry.menuBarHeight * scale)
            pageIsland(module: module, size: size, geometry: geometry)
                .scaleEffect(scale, anchor: .top)
                .frame(width: scaledWidth, height: scaledHeight, alignment: .top)
        }
        .frame(width: stageSize.width, height: stageSize.height, alignment: .top)
    }

    /// The island closed, with the wings it shows at rest.
    private func restingStage(in stageSize: CGSize) -> some View {
        let geometry = Self.restingGeometry()
        let size = geometry.restingSize(showsContent: notch.idleContent != .none)
        let scale = Self.scale(island: size, width: stageSize.width)
        let scaledWidth = max(size.width * scale, 1)
        let scaledHeight = max(size.height * scale, 1)
        return ZStack(alignment: .top) {
            menuBarStrip(height: geometry.menuBarHeight * scale)
            restingIsland(size: size, geometry: geometry)
                .scaleEffect(scale, anchor: .top)
                .frame(width: scaledWidth, height: scaledHeight, alignment: .top)
        }
        .frame(width: stageSize.width, height: stageSize.height, alignment: .top)
    }

    /// The gallery as the island draws it, still: the header with the camera
    /// between its halves, the sections in their columns and the shortcuts bar below.
    private func exploreStage(in stageSize: CGSize) -> some View {
        let geometry = notch.geometry
        let size = Self.islandSize(for: .explore)
        // The content tab keeps a page's frame height, so the grid below does
        // not move mid-drag; the gallery shrinks to that frame instead of
        // overflowing it.
        var scale = Self.scale(island: size, width: stageSize.width)
        if stageSize.height > Self.captionHeight {
            scale = min(scale, (stageSize.height - Self.captionHeight) / max(size.height, 1))
        }
        let scaledWidth = max(size.width * scale, 1)
        let scaledHeight = max(size.height * scale, 1)
        return ZStack(alignment: .top) {
            menuBarStrip(height: geometry.menuBarHeight * scale)
            exploreIsland(size: size, geometry: geometry)
                .scaleEffect(scale, anchor: .top)
                .frame(width: scaledWidth, height: scaledHeight, alignment: .top)
        }
        .frame(width: stageSize.width, height: stageSize.height, alignment: .top)
    }

    private func exploreIsland(size: CGSize, geometry: NotchGeometry) -> some View {
        let content = geometry.contentSize(for: size)
        let width = max(content.width, 180)
        let columns = geometry.sectionColumns > 0 ? geometry.sectionColumns : 3
        return islandShell {
            VStack(spacing: NotchLayout.spacing) {
                header(title: FeatureStrings.notch(l10n.language).sectionsTitle, gridIcon: false,
                       geometry: geometry, width: width)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: HexaTheme.Spacing.s), count: columns),
                          alignment: .leading, spacing: HexaTheme.Spacing.s) {
                    ForEach(NotchSupport.modules()) { module in
                        VStack(spacing: HexaTheme.Spacing.xs) {
                            NotchSectionTile(module: module, shown: true, side: 34)
                            Text(module.title(l10n.language))
                                .font(.hexa(.label))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                    }
                }
                .frame(width: width, height: max(content.height, 64), alignment: .top)
                .clipped()
                if geometry.quickAccessBottomInset > 0 {
                    NotchShortcutsBarView(service: notch, configuration: NotchQuickAccessConfiguration.current(), width: width)
                }
            }
            .padding(.horizontal, NotchLayout.horizontalInset)
            .padding(.top, geometry.headerTopInset)
            .padding(.bottom, NotchLayout.bottomInset)
            .frame(width: max(size.width, 240), height: max(size.height, 100), alignment: .top)
            .background {
                NotchShape.island(height: max(size.height, 100), geometry: geometry).fill(.black)
            }
        }
    }

    private func menuBarStrip(height: CGFloat) -> some View {
        Rectangle()
            .fill(HexaTheme.surfaceInset)
            .frame(height: max(height, 2))
    }

    private func pageIsland(module: NotchModule, size: CGSize, geometry: NotchGeometry) -> some View {
        let contentRaw = geometry.contentSize(for: size)
        let content = CGSize(width: max(contentRaw.width, 180), height: max(contentRaw.height, 60))
        return islandShell {
            VStack(spacing: NotchLayout.spacing) {
                header(title: module.title(l10n.language),
                       gridIcon: !NotchQuickAccessConfiguration.current().actions.contains(.explore),
                       geometry: geometry, width: content.width)
                NotchPagePreview(module: module, size: content)
                    .frame(width: content.width, height: content.height, alignment: .top)
                    .clipped()
                if geometry.quickAccessBottomInset > 0 {
                    NotchShortcutsBarView(service: notch, configuration: NotchQuickAccessConfiguration.current(), width: content.width)
                }
            }
            .padding(.horizontal, NotchLayout.horizontalInset)
            .padding(.top, geometry.headerTopInset)
            .padding(.bottom, NotchLayout.bottomInset)
            .frame(width: max(size.width, 240), height: max(size.height, 100), alignment: .top)
            .background {
                NotchShape.island(height: max(size.height, 100), geometry: geometry).fill(.black)
            }
        }
    }

    private func restingIsland(size: CGSize, geometry: NotchGeometry) -> some View {
        islandShell {
            NotchRestingStrip(service: notch, displayGeometry: geometry)
                .frame(width: max(size.width, 24), height: max(size.height, 24), alignment: .top)
                .background {
                    NotchShape.island(height: max(size.height, 24), geometry: geometry).fill(.black)
                }
        }
    }

    /// The island draws in the dark, in a surface that never starts work; a
    /// section or the island switched off keeps it in place, dimmed.
    private func islandShell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .foregroundStyle(HexaTheme.fgPrimary)
            .tint(HexaTheme.fgPrimary)
            .environment(\.colorScheme, .dark)
            .environment(\.notchPresentation, true)
            .environment(\.notchGlassSurface, false)
            .environment(\.notchSettingsPreview, true)
            .opacity(hidden || !enabled ? 0.45 : 1)
            .saturation(enabled ? 1 : 0)
    }

    /// The island's title row: the page's name, the camera between the
    /// halves, and the actions that wait for the pointer.
    private func header(title: String, gridIcon: Bool, geometry: NotchGeometry, width: CGFloat) -> some View {
        let half = geometry.headerCameraGap > 0 ? (width - geometry.headerCameraGap) / 2 : nil
        return HStack(spacing: 0) {
            HStack(spacing: 6) {
                if gridIcon {
                    HexaIcons.image("square.grid.2x2", size: 13)
                        .font(.hexa(.body))
                        .foregroundStyle(HexaTheme.fgTertiary)
                        .frame(width: 28, height: 28)
                }
                Text(title)
                    .font(Font(NotchLayout.headerTitleFont as CTFont))
                    .lineLimit(1)
            }
            .frame(width: half, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            if geometry.headerCameraGap > 0 {
                Color.clear.frame(width: geometry.headerCameraGap)
            }
            // In a row of its own the title takes the width the actions leave.
            HexaIcons.image("ellipsis", size: 11)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgDisabled)
                .frame(width: 28, height: 28)
                .frame(width: half, alignment: .trailing)
                .frame(maxWidth: half == nil ? nil : .infinity, alignment: .trailing)
        }
        .frame(height: geometry.headerRowHeight)
    }

    private var captionText: String {
        caption ?? (hidden ? editor.hiddenInIsland : editor.preview)
    }

    private var captionLabel: some View {
        Label(captionText, hexaIcon: hidden ? "eye.slash" : "eye")
            .font(.hexa(.label))
            .foregroundStyle(HexaTheme.fgSecondary)
            .padding(.horizontal, HexaTheme.Spacing.m)
            .padding(.bottom, HexaTheme.Spacing.s)
    }

    private var accessibilityValue: String {
        switch mode {
        case .page(let module):
            return module.title(l10n.language) + (hidden ? ", " + editor.hiddenInIsland : "")
        case .resting:
            return captionText
        case .explore:
            return FeatureStrings.notch(l10n.language).sectionsTitle
        }
    }

    private var showsSystemPage: Bool {
        mode == .page(.system)
    }

    /// The system page reads live metrics, which sample only while a surface
    /// shows them; the preview counts as one, like the menu panel, and only
    /// while the window is on screen.
    private func monitor(wanted: Bool) {
        let lease = wanted && showsSystemPage && windowVisible
        guard lease != monitoring else { return }
        monitoring = lease
        if lease {
            let id = UUID()
            monitorLeaseId = id
            _ = SystemMonitor.shared.registerDemand(id: id)
        } else if let id = monitorLeaseId {
            SystemMonitor.shared.unregisterDemand(id: id)
            monitorLeaseId = nil
        }
    }
}

/// A section's page as the island draws it. The camera and the scratchpad
/// show a still instead: a preview must never turn the camera on or give a
/// text editor the keyboard.
struct NotchPagePreview: View {
    let module: NotchModule
    let size: CGSize
    @ObservedObject private var notch = NotchService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        switch module {
        case .timer: NotchTimerView(size: size)
        case .notifications: NotchNotificationsView(size: size)
        case .downloads: NotchDownloadsView(size: size)
        case .calendar: NotchCalendarView(size: size)
        case .controls: NotchControlsView(service: notch, size: size)
        case .mixer: NotchMixerView(size: size)
        case .music: NotchMusicView(size: size, extrasHeight: notch.geometry.musicExtrasHeight)
        case .captures: RecentCapturesView(onClose: nil, notchSize: size)
        case .files: NotchFilesView(service: notch)
        case .system: NotchSystemView(size: size) { _ in }
        case .tools: placeholderStill
        // The live area belongs to the island; the preview explains it instead.
        case .watch: NotchWatchView(size: size)
        }
    }

    /// The source of this preview's page did not come along; the still shows
    /// the section's own name until its view returns.
    private var placeholderStill: some View {
        VStack(spacing: 10) {
            HexaIcons.image("rectangle.dashed", size: 34)
                .font(.hexa(.display(34)))
                .foregroundStyle(HexaTheme.fgDisabled)
            Text(module.title(l10n.language))
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(NotchControlSurface(cornerRadius: HexaTheme.Radius.notch, interactive: false))
    }

}

/// Reports whether the hosting window is on screen (occlusion state), so the
/// island preview can pause its live content when the page is not seen.
fileprivate struct NotchPreviewVisibilityReader: NSViewRepresentable {
    var onChange: (Bool) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = VisibilityObservingView()
        view.onVisibilityChange = onChange
        view.setupObservers()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? VisibilityObservingView {
            view.onVisibilityChange = onChange
            view.updateVisibility()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {}
}

fileprivate final class VisibilityObservingView: NSView {
    var onVisibilityChange: ((Bool) -> Void)?
    private var observers: [NSObjectProtocol] = []

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateVisibility()
    }

    func updateVisibility() {
        guard let window else { return }
        let isVisible = window.isVisible && window.occlusionState.contains(.visible)
        onVisibilityChange?(isVisible)
    }

    func setupObservers() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        let center = NotificationCenter.default
        let handler: (Notification) -> Void = { [weak self] _ in
            self?.updateVisibility()
        }
        observers.append(center.addObserver(forName: NSNotification.Name("NSWindowDidBecomeVisible"), object: nil, queue: .main, using: handler))
        observers.append(center.addObserver(forName: NSNotification.Name("NSWindowDidBecomeHidden"), object: nil, queue: .main, using: handler))
        observers.append(center.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: nil, queue: .main, using: handler))
    }

    deinit {
        for obs in observers { NotificationCenter.default.removeObserver(obs) }
    }
}
