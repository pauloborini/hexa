// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import SwiftUI

struct NotchWatchSettingsControls: View {
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchWatchEnabled) private var enabled = true
    @AppStorage(DefaultsKey.notchWatchSound) private var sound = true
    private var text: NotchWatchStrings { FeatureStrings.notchWatch(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text.description).font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
            if enabled {
                Toggle(text.sound, isOn: $sound)
                PermissionRow(kind: .screenRecording)
            }
        }
        .onChange(of: enabled) { NotchService.shared.schedulePreferenceSync() }
    }
}

/// The page: what to watch and the rule, the live area and its reading.
struct NotchWatchView: View {
    let size: CGSize
    @ObservedObject private var watch = NotchWatchService.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchWatchEnabled) private var enabled = true
    @Environment(\.notchSettingsPreview) private var preview
    private var text: NotchWatchStrings { FeatureStrings.notchWatch(l10n.language) }

    var body: some View {
        Group {
            if !enabled || watch.target == nil || preview {
                NotchWatchSetupView()
            } else {
                VStack(alignment: .leading, spacing: NotchLayout.rowSpacing) {
                    header
                    NotchWatchAreaCard()
                        .frame(maxHeight: .infinity)
                    NotchWatchRuleRow()
                    footer
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { if !preview { watch.pageVisible = true } }
        .onDisappear { if !preview { watch.pageVisible = false } }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if let icon = watch.target?.appIcon {
                Image(nsImage: icon).resizable().frame(width: 16, height: 16).accessibilityHidden(true)
            } else {
                HexaIcons.image(NotchModule.watch.symbol).foregroundStyle(NotchWatchStrip.tint)
            }
            Text(headerTitle).lineLimit(1).truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            NotchIconButton(symbol: "viewfinder", title: text.chooseAgain) {
                NotchService.shared.perform { NotchWatchService.shared.chooseArea() }
            }
            NotchIconButton(symbol: "xmark", title: text.stop) { watch.stop() }
        }
        .font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
        .frame(height: 24)
    }

    private var headerTitle: String {
        guard let target = watch.target else { return text.title }
        guard let title = target.windowTitle, title != target.appName else { return target.appName }
        return "\(target.appName) · \(title)"
    }

    @ViewBuilder private var footer: some View {
        if case .finished = watch.state {
            HStack(spacing: 8) {
                if watch.canWatchAgain {
                    NotchPillButton(title: text.watchAgain, prominent: true) { watch.watchAgain() }
                }
                NotchPillButton(title: text.chooseAgain, prominent: !watch.canWatchAgain) {
                    NotchService.shared.perform { NotchWatchService.shared.chooseArea() }
                }
                Spacer(minLength: 0)
            }
        } else if let started = watch.startedAt {
            Text(text.since(started.formatted(Date.FormatStyle(date: .omitted, time: .shortened)
                .locale(l10n.language.formattingLocale()))))
                .font(.hexa(.micro)).foregroundStyle(HexaTheme.fgSecondary).lineLimit(1)
        }
    }
}

/// The live area with its reading below it, and what happened once the
/// watch ended.
private struct NotchWatchAreaCard: View {
    @ObservedObject private var watch = NotchWatchService.shared
    @ObservedObject private var l10n = L10n.shared
    private var text: NotchWatchStrings { FeatureStrings.notchWatch(l10n.language) }

    private var lines: [String] { NotchWatchSupport.lines(in: watch.text) }

    /// What the island shows, picked automatically or chosen line by line
    /// when the automatic pick lands on the wrong words.
    private var headlineMenu: some View {
        Menu {
            Section(text.inIsland) {
                choice(text.automatic, selected: watch.headlineLine == nil) { watch.setHeadlineLine(nil) }
                ForEach(Array(lines.prefix(12).enumerated()), id: \.offset) { index, line in
                    choice(line, selected: watch.headlineLine == index) { watch.setHeadlineLine(index) }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(watch.headline.isEmpty ? text.noText : watch.headline)
                    .monospacedDigit().lineLimit(1)
                HexaIcons.image("chevron.down", size: 10).font(.hexa(.micro))
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .font(.hexa(.heading))
        .fixedSize()
        .help(text.inIsland)
        .accessibilityLabel(text.inIsland)
        .accessibilityValue(watch.headline)
    }

    private func choice(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if selected { Label(title, hexaIcon: "checkmark") } else { Text(title) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if let image = watch.preview {
                    Image(decorative: image, scale: 2)
                        .resizable().interpolation(.high).aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .opacity(watch.state == .hidden ? 0.35 : 1)
                } else if watch.state != .hidden {
                    ProgressView().controlSize(.small)
                }
                if watch.state == .hidden {
                    Label(watch.permissionMissing ? text.permissionHint : text.hidden,
                          hexaIcon: watch.permissionMissing ? "lock" : "eye.slash")
                        .font(.hexa(.label)).multilineTextAlignment(.center)
                        .padding(8)
                        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if case .finished(let outcome) = watch.state {
                    HexaIcons.image(outcome == .closed ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(outcome == .closed ? HexaTheme.fgSecondary : HexaTheme.fgPrimary)
                    Text(text.outcome(outcome)).font(.hexa(.body)).lineLimit(1)
                } else if lines.isEmpty {
                    Text(text.noText).font(.hexa(.heading)).foregroundStyle(HexaTheme.fgSecondary)
                } else {
                    headlineMenu
                }
                Spacer(minLength: 0)
            }
            let full = watch.text.replacingOccurrences(of: "\n", with: " ")
            if !full.isEmpty, full != watch.headline {
                Text(full).font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary).lineLimit(2)
                    .textSelection(.enabled)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(HexaTheme.fgPrimary.opacity(0.07), in: RoundedRectangle(cornerRadius: HexaTheme.Radius.notch, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// When to speak up. A word or a number applies once Return is pressed or
/// the field is left, so typing never ends the watch halfway. After a watch
/// ends the rule can still change, for the next Watch Again.
private struct NotchWatchRuleRow: View {
    @ObservedObject private var watch = NotchWatchService.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var draftText = ""
    @State private var draftNumber = ""
    @FocusState private var focused: Bool
    private var text: NotchWatchStrings { FeatureStrings.notchWatch(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(text.tellMe).font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
                Menu {
                    ForEach(NotchWatchCondition.allCases) { condition in
                        Button { watch.setCondition(condition) } label: {
                            Label(text.condition(condition), hexaIcon: condition.symbol)
                        }
                    }
                } label: {
                    Label(text.condition(watch.condition), hexaIcon: watch.condition.symbol)
                }
                .menuStyle(.borderlessButton)
                .controlSize(.small)
                .font(.hexa(.body))
                .fixedSize()
                if watch.condition == .contains || watch.condition == .reaches {
                    field
                }
                Spacer(minLength: 0)
            }
            if watch.condition == .settles {
                Text(text.settlesHint).font(.hexa(.micro)).foregroundStyle(HexaTheme.fgSecondary).lineLimit(2)
            }
        }
        .onAppear {
            draftText = watch.matchText
            draftNumber = watch.matchNumber.map {
                NotchWatchSupport.formatted($0, locale: l10n.language.formattingLocale())
            } ?? ""
        }
    }

    private var field: some View {
        let number = watch.condition == .reaches
        return TextField(number ? text.numberPlaceholder : text.textPlaceholder,
                         text: number ? $draftNumber : $draftText)
            .textFieldStyle(.plain)
            .font(.hexaManrope(size: 12))
            .focused($focused)
            .onSubmit(apply)
            .onChange(of: focused) { _, isFocused in if !isFocused { apply() } }
            .padding(.horizontal, 8)
            .frame(height: 24)
            .frame(maxWidth: 180)
            .background(HexaTheme.fgPrimary.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(HexaTheme.fgPrimary.opacity(focused ? 0.34 : 0), lineWidth: 1)
            }
            .accessibilityLabel(text.condition(watch.condition))
    }

    private func apply() {
        if watch.condition == .reaches { watch.setMatchNumber(draftNumber) } else { watch.setMatchText(draftText) }
    }
}

/// Before anything is watched: what the page does, and the one step that
/// starts it, in the same voice as the island's other empty pages.
private struct NotchWatchSetupView: View {
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchWatchEnabled) private var enabled = true
    /// The settings preview draws the empty page; it must not poll a grant.
    @Environment(\.notchSettingsPreview) private var preview
    /// The page follows a grant made in System Settings while it is shown;
    /// nothing checks for one while it is away.
    @State private var pollingDemandID = UUID()
    private var text: NotchWatchStrings { FeatureStrings.notchWatch(l10n.language) }

    var body: some View {
        ViewThatFits(in: .vertical) {
            VStack(spacing: 12) {
                glyph
                copy.multilineTextAlignment(.center)
                actions
            }
            HStack(spacing: 16) {
                glyph
                VStack(alignment: .leading, spacing: 10) {
                    copy.multilineTextAlignment(.leading)
                    actions
                }
            }
        }
        .frame(maxWidth: 360)
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { if !preview { permissions.setActivePermissionSurface(pollingDemandID, visible: true) } }
        .onDisappear { if !preview { permissions.setActivePermissionSurface(pollingDemandID, visible: false) } }
    }

    private var glyph: some View {
        NotchGlyphBadge(symbol: "eye")
            .accessibilityHidden(true)
    }

    private var copy: some View {
        Text(!enabled ? text.description : permissions.screenRecording ? text.setupHint : text.permissionHint)
            .font(.hexaManrope(size: 12))
            .foregroundStyle(HexaTheme.fgSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var actions: some View {
        if !enabled {
            if AppFeature.notchWatch.isAvailable {
                Toggle(text.title, isOn: $enabled)
                    .toggleStyle(.switch)
                    .onChange(of: enabled) { NotchService.shared.schedulePreferenceSync() }
            }
        } else if !permissions.screenRecording {
            NotchPillButton(title: text.allowAccess, prominent: true) {
                Permissions.shared.requestScreenRecording()
            }
        } else {
            NotchPillButton(title: text.choose, prominent: true) {
                NotchService.shared.perform { NotchWatchService.shared.chooseArea() }
            }
        }
    }
}

/// The area itself, small, where a reading would be when it holds no text.
struct NotchWatchThumbnail: View {
    let image: CGImage
    let height: CGFloat

    var body: some View {
        // Whole, so a bar shows how far it has filled.
        Image(decorative: image, scale: 2)
            .resizable().interpolation(.medium).aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .frame(width: NotchWatchSupport.thumbnailWidth, height: height)
            .accessibilityHidden(true)
    }
}

/// The watching eye, breathing while the area is read, and still, crossed
/// out, while its window is hidden. The motion runs in the compositor and
/// stops whenever the island is not on screen.
struct NotchWatchEye: View {
    let size: CGFloat
    var hidden = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NotchWatchEyeBridge(size: size, hidden: hidden, animates: !hidden && !reduceMotion)
            .frame(width: size + 2, height: size + 2)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

private struct NotchWatchEyeBridge: NSViewRepresentable {
    let size: CGFloat
    let hidden: Bool
    let animates: Bool

    func makeNSView(context: Context) -> NotchBreathingGlyphView { NotchBreathingGlyphView() }
    func updateNSView(_ view: NotchBreathingGlyphView, context: Context) {
        let image = HexaIcons.nsImage(named: hidden ? "eye.slash" : "eye", accessibilityDescription: nil)?
            .hexaSized(size)
        view.configureGlyph(image: image, size: size, tint: NotchWatchStrip.eyeTint, animates: animates)
    }
    static func dismantleNSView(_ view: NotchBreathingGlyphView, coordinator: ()) { view.stop() }
}

/// The eye at the left end and what the area reads at the right, each
/// anchored to its own edge so the silhouette's curve decides the margin.
struct NotchWatchStrip: View {
    static let tint = HexaTheme.fgPrimary
    /// Softer than the reading, so the mark does not outshine it.
    static let eyeTint = HexaTheme.fgSecondaryNSColor.withAlphaComponent(0.75)

    @ObservedObject var service: NotchService
    /// Where the island draws it: its own strip as of the last update, or
    /// another display's when the island shows on every display.
    var displayGeometry: NotchGeometry? = nil
    @ObservedObject private var watch = NotchWatchService.shared
    @ObservedObject private var l10n = L10n.shared

    private var geometry: NotchGeometry { displayGeometry ?? service.compactActivityGeometry }
    /// The eye breathes at the size a single mark takes on the strip.
    private var iconSize: CGFloat {
        min(14, max(8, geometry.compactActivityContentHeight - NotchLayout.compactEdgeGap * 2 - 4))
    }
    private var textSize: CGFloat { NotchTimerSupport.stripTextSize(height: geometry.compactActivityContentHeight) }
    private var iconInset: CGFloat { geometry.compactActivityEdgeInset(boxHeight: iconSize, radius: iconSize / 2) }
    private var textInset: CGFloat { geometry.compactActivityEdgeInset(boxHeight: textSize * 0.72, radius: 0) }

    var body: some View {
        Button { service.openActivity(.watch) } label: {
            HStack(spacing: 0) {
                NotchWatchEye(size: iconSize, hidden: watch.state == .hidden)
                    .padding(.leading, iconInset)
                    .frame(width: geometry.compactActivityWingWidth, alignment: .leading)
                    .opacity(geometry.compactActivityWingWidth >= 28 ? 1 : 0)
                Color.clear.frame(width: geometry.compactActivityCameraGap)
                reading
                    .padding(.trailing, textInset)
                    .frame(width: geometry.compactActivityWingWidth, alignment: .trailing)
                    .clipped()
            }
            .frame(height: geometry.compactActivityContentHeight)
            .padding(.horizontal, geometry.compactActivityHorizontalPadding)
            .padding(.top, geometry.compactActivityTopPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(FeatureStrings.notchWatch(l10n.language).title)
        .accessibilityValue(watch.headline)
        .accessibilityHint(FeatureStrings.notch(l10n.language).open)
    }

    @ViewBuilder private var reading: some View {
        if geometry.compactActivityWingWidth < 36 {
            EmptyView()
        } else if watch.showsThumbnail, let preview = watch.preview {
            NotchWatchThumbnail(image: preview, height: max(8, geometry.compactActivityContentHeight - 6))
        } else if watch.headline.isEmpty {
            // A hidden window's slashed eye says enough until it is read.
            if watch.state != .hidden { ProgressView().controlSize(.mini) }
        } else {
            // A reading can change on every pass; rolling each change would
            // keep the closed island animating.
            Text(watch.headline)
                .font(.hexaManrope(size: textSize, weight: .medium))
                .foregroundStyle(Self.tint)
                .lineLimit(1).minimumScaleFactor(0.7).truncationMode(.tail)
        }
    }
}
