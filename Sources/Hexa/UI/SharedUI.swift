// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Divisor decorativo hairline de 1 px (spec §7.1).
/// Usa o token semantico HexaTheme.borderHairline. Passivo e escondido do VoiceOver.
struct HairlineDivider: View {
    var inset: CGFloat = 0
    var vertical: Bool = false

    var body: some View {
        Rectangle()
            .fill(HexaTheme.borderHairline)
            .frame(width: vertical ? HexaTheme.hairline : nil,
                   height: vertical ? nil : HexaTheme.hairline)
            .padding(.horizontal, vertical ? 0 : inset)
            .padding(.vertical, vertical ? inset : 0)
            .accessibilityHidden(true)
    }
}

/// A single keyboard key drawn like a physical keycap. Used across Settings and
/// onboarding to show shortcuts such as ⌘X / ⌘V.
struct KeyCap: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.hexaManrope(size: 11, weight: .medium))
            .frame(minWidth: 16, minHeight: 18)
            .padding(.horizontal, 3)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(HexaTheme.fgPrimary.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(HexaTheme.fgPrimary.opacity(0.14), lineWidth: HexaTheme.hairline)
            )
    }
}

/// A row of keycaps for a shortcut, e.g. ["⌘", "X"].
struct ShortcutCaps: View {
    let keys: [String]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                KeyCap(label: key)
            }
        }
    }
}

struct FullDiskAccessNote: View {
    var compact = false
    /// Why this surface needs the permission. The scan is the usual reason;
    /// a failed removal has its own, so it says so in its own words.
    var reason: String?

    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared

    var body: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            HStack(alignment: .top, spacing: compact ? HexaTheme.Spacing.s : HexaTheme.Spacing.s) {
                HexaIcons.image("info.circle")
                    .foregroundStyle(HexaTheme.fgSecondary)
                Text(reason ?? l10n.s.uninstallerFDANote)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(l10n.s.uninstallerFDAHint)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: HexaTheme.Spacing.s) {
                HexaAccessButton(icon: "lock.open", title: l10n.s.uninstallerFDAGrant) {
                    permissions.requestFullDiskAccess()
                }
                // Shown alongside because access only takes effect on relaunch.
                Button(l10n.s.uninstallerFDARelaunch) { appDelegate()?.relaunchApp() }
                    .buttonStyle(HexaActionButtonStyle())
            }
        }
        // Take the width the host offers, so the card lines up with the cards
        // around it instead of shrinking to its longest line.
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compact ? HexaTheme.Spacing.s : HexaTheme.Spacing.m)
        .hexaCardSurface(
            increaseContrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        )
    }
}

/// What a removal left behind, and why. Sandboxed app data lives in
/// ~/Library/Containers, which macOS keeps behind Full Disk Access; the
/// administrator prompt Finder shows covers file ownership, not that
/// permission, so those items are refused however the removal is attempted.
/// Naming them at the moment they survive is the only point where the
/// permission has visibly cost the person something.
struct UninstallFailureNote: View {
    let items: [AppUninstaller.Leftover]
    var compact = false

    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared

    private static let namesShown = 4

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? HexaTheme.Spacing.xs : HexaTheme.Spacing.s) {
            Text(l10n.s.uninstallerSomeFailed)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.statusWarning)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(items.prefix(Self.namesShown)) { item in
                Text(item.name)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if items.count > Self.namesShown {
                Text(String(format: l10n.s.uninstallerFailedMoreFormat,
                            items.count - Self.namesShown))
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgTertiary)
            }
            if !permissions.fullDiskAccess,
               UninstallerSupport.failureNeedsFullDiskAccess(paths: items.map(\.url.path)) {
                FullDiskAccessNote(compact: compact, reason: l10n.s.uninstallerFailedNeedsFDA)
            }
        }
    }
}

/// Translucent HUD material behind floating panels (the switcher, the
/// cut-feedback HUD). Mirrors the switcher's backdrop so every floating surface
/// matches.
///
/// `contrast: .high` lays a flat plate over the material, for the panels that
/// are nothing but rows of text. The frost borrows so much of whatever window
/// sits behind it that such a list over a bright document stops being readable,
/// and the darker the theme the worse it reads: light text against a page of
/// white. The plate keeps the frost visible and gives the text something to sit
/// on. Where the system is already told to reduce transparency it makes the
/// material opaque by itself, so the plate stays out of the way.
///
/// `opacity` fades the material itself, for the one panel that lets the user
/// choose how much of the screen shows through. Reduce transparency wins over
/// it: the whole point of that setting is that panels stop being see-through,
/// so a stored preference must not quietly undo it.
struct HUDBackdrop: View {
    enum Contrast {
        case standard
        case high
    }

    var cornerRadius: CGFloat = 0
    var contrast: Contrast = .standard
    var opacity: Double = 1

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var materialOpacity: Double {
        reduceTransparency ? 1 : min(max(opacity, 0), 1)
    }

    /// Chosen from the worst case rather than by eye: a panel over a full white
    /// window in the dark theme, or over a full black one in the light theme,
    /// with the material assumed to hold nothing back. At these values the
    /// plate alone carries white text to 4.8:1 and black text to 5.3:1, both
    /// past the 4.5:1 the accessibility guidelines ask of body text, and the
    /// real material only ever adds to that.
    static func plateOpacity(dark: Bool) -> Double { dark ? 0.55 : 0.5 }

    private var plateOpacity: Double {
        guard contrast == .high, !reduceTransparency else { return 0 }
        return Self.plateOpacity(dark: colorScheme == .dark)
    }

    var body: some View {
        classicBackdrop
    }

    @ViewBuilder
    private var classicBackdrop: some View {
        HUDBackdropMaterial(cornerRadius: cornerRadius, opacity: materialOpacity)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(PanelSurface.plateTint(for: colorScheme))
                    .opacity(plateOpacity)
            )
    }
}

/// The material itself.
///
/// The corner radius rounds the effect view's own layer, which matters for the
/// behind-window blur: SwiftUI's `.clipShape` rounds the drawn content but does
/// not clip an `NSVisualEffectView`'s behind-window material, so the blur (and
/// the borderless window's shadow, computed from it) keeps the full rectangular
/// bounds. Against a contrasty desktop that rectangle reads as a faint extra
/// outline just outside the rounded card, and whether it shows depends on what
/// is behind the window, which is why it looks intermittent. Clipping the layer
/// to the same radius as the card removes it. Pass the card's corner radius.
private struct HUDBackdropMaterial: NSViewRepresentable {
    var cornerRadius: CGFloat = 0
    var opacity: Double = 1

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        apply(to: view)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        apply(to: nsView)
    }

    private func apply(to view: NSVisualEffectView) {
        view.alphaValue = CGFloat(opacity)
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
    }
}

/// A disclosure header where the whole row toggles the group and the chevron
/// sits on the trailing side, the way a drop-down reads. The label supplies
/// the row's one Spacer, so trailing accessories stay flush to the chevron.
struct DisclosureHeaderRow<Label: View>: View {
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let isExpanded: Binding<Bool>
    private let label: () -> Label

    init(isExpanded: Binding<Bool>, @ViewBuilder label: @escaping () -> Label) {
        self.isExpanded = isExpanded
        self.label = label
    }

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                isExpanded.wrappedValue.toggle()
            }
        } label: {
            HStack(spacing: HexaTheme.Spacing.s) {
                label()
                HexaIcons.image("chevron.right", size: 11)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isExpanded.wrappedValue
            ? l10n.s.disclosureExpanded : l10n.s.disclosureCollapsed)
    }
}

extension View {
    /// Child rows sit inset under their group's header row.
    func disclosureIndent(_ enabled: Bool = true) -> some View {
        padding(.leading, enabled ? 25 : 0)
    }
}
