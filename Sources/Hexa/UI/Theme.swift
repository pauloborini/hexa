// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Shared look & feel: brand colors, card styling and the brand mark.
enum Theme {
    /// Near-black background behind the brand mark. Uses semantic surface tokens
    /// so the badge carries subtle depth without raw colour literals.
    static let spaceGradient = LinearGradient(
        colors: [HexaTheme.surfaceRaised,
                 HexaTheme.surfaceInset,
                 HexaTheme.surfaceBase],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// Canais neutros de dados. Nomes anteriores preservam os consumidores;
/// estado é comunicado por rótulo/forma, sem paleta colorida de UI.
enum PanelMetricColor {
    static func green(for scheme: ColorScheme) -> Color { HexaTheme.accentSolid }
    static func cyan(for scheme: ColorScheme) -> Color { HexaTheme.fgSecondary }
    static func mint(for scheme: ColorScheme) -> Color { HexaTheme.accentText }
    static func yellow(for scheme: ColorScheme) -> Color { HexaTheme.fgPrimary }
    static func red(for scheme: ColorScheme) -> Color { HexaTheme.accentText }
    static func orange(for scheme: ColorScheme) -> Color { HexaTheme.fgSecondary }
    static func pink(for scheme: ColorScheme) -> Color { HexaTheme.accentSolid }
}

private struct NotchPresentationKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var notchPresentation: Bool {
        get { self[NotchPresentationKey.self] }
        set { self[NotchPresentationKey.self] = newValue }
    }
}

enum PanelSurface {
    /// Whether the menu popover hosts the panel across its whole balloon, so the
    /// panel's own surface can reach the arrow. Only macOS 26 lays the
    /// content out that way. On macOS 15, `hasFullSizeContent` publishes the
    /// full-size safe area but leaves the view at its content size in the frame's
    /// lower-left corner: the popover grows by that safe area, the panel sits off
    /// center, and a band of system material shows along the top and right edges.
    static var popoverHostsFullSizeContent: Bool {
        if #available(macOS 26.0, *) { return true }
        return false
    }

    static func baseFill(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color.white.opacity(0.68) : Color.black.opacity(0.42)
    }

    static func cardFill(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color.white.opacity(0.38) : Color.white.opacity(0.075)
    }

    static func controlFill(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color.black.opacity(0.055) : Color.white.opacity(0.085)
    }

    /// Raised contrast is asked for by someone who cannot see a hairline at a
    /// tenth of an opacity, so the outlines that separate one card from the
    /// next are the ones that answer. A panel is rebuilt every time it opens,
    /// which is when a change to this setting shows.
    static func border(for scheme: ColorScheme) -> Color {
        let raised = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        return scheme == .light
            ? Color.black.opacity(raised ? 0.24 : 0.09)
            : Color.white.opacity(raised ? 0.28 : 0.11)
    }

    /// A control that sits ON a glass surface rather than in it: the system's
    /// own round toggles read as physical because they are lighter than what
    /// is behind them and carry their own shadow.
    static func raisedFill(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color.white.opacity(0.88) : Color.white.opacity(0.14)
    }

    static func raisedBorder(for scheme: ColorScheme) -> Color {
        let raised = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        return scheme == .light
            ? Color.black.opacity(raised ? 0.22 : 0.07)
            : Color.white.opacity(raised ? 0.32 : 0.16)
    }

    static func raisedShadow(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color.black.opacity(0.14) : Color.black.opacity(0.38)
    }

    /// The lit edge of a glass surface: bright where the light comes from,
    /// gone by the bottom. Without it a translucent panel reads as paper.
    static func rimHighlight(for scheme: ColorScheme) -> LinearGradient {
        LinearGradient(colors: [Color.white.opacity(scheme == .light ? 0.95 : 0.30),
                                Color.white.opacity(scheme == .light ? 0.12 : 0.04)],
                       startPoint: .top,
                       endPoint: .bottom)
    }

    /// The flat contrast plate laid over the HUD material (`HUDBackdrop` with
    /// `contrast: .high`): tinted black in the dark theme and white in the
    /// light one; the strength comes from the backdrop's `plateOpacity`, not
    /// from the tint. Registered as a component token (spec §2.3); values
    /// unchanged by that registration.
    static func plateTint(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black : Color.white
    }
}

func sectionTitle(_ text: String) -> some View {
    // SectionLabel (spec §7): micro + accentText. A caixa alta vem do papel
    // (textCase), sem alterar a string localizada (DEC-016).
    Text(text)
        .hexaSectionLabel()
        .accessibilityAddTraits(.isHeader)
}

/// Primitive canônico de rótulo de seção (spec §7): micro + accentText.
struct SectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    init(title: String) {
        self.text = title
    }

    var body: some View {
        sectionTitle(text)
    }
}


extension View {
    /// The rounded card background used by every panel section (ARCH-05).
    /// Uses canonical semantic tokens: surfaceRaised, borderHairline (1 px)
    /// and Radius.panel (10 pt).
    func panelCard(interactive: Bool = true, padded: Bool = true) -> some View {
        modifier(HexaSectionCardModifier(padded: padded, interactive: interactive))
    }

    /// A restrained glass base for the menu panel: still translucent, but with a
    /// stable tint so text and controls do not depend too much on the wallpaper.
    /// It reaches the popover's arrow; see PanelGlassSurface.
    func panelGlassSurface() -> some View {
        background(PanelGlassSurface())
    }
}

private struct PanelGlassSurface: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.notchPresentation) private var notchPresentation
    @Environment(\.notchGlassSurface) private var notchGlassSurface
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        // AppKit hands the hosted panel a safe area for the popover's border and
        // arrow, so a surface that stopped at the panel would leave the tip in the
        // plain system material. The panel content keeps that inset and never sits
        // under the arrow; only this background bleeds into it. The popover clips
        // it to its own balloon, so the surface is a plain rectangle: rounding would
        // expose the system material at the corners, while stroking would duplicate
        // the outline AppKit already draws. Where the popover still insets its
        // content, the panel is a card inside the balloon instead; see
        // PanelSurface.popoverHostsFullSizeContent.
        if notchPresentation {
            Rectangle().fill(notchGlassSurface ? Color.clear : .black)
        } else if PanelSurface.popoverHostsFullSizeContent {
            surface.ignoresSafeArea()
        } else {
            insetSurface
        }
    }

    @ViewBuilder
    private var surface: some View {
        standardSurface
    }

    @ViewBuilder
    private var standardSurface: some View {
        Rectangle()
            .fill(.regularMaterial)
            .overlay(Rectangle().fill(PanelSurface.baseFill(for: colorScheme)))
    }

    /// The panel as a card inside a popover that insets its content.
    /// Aligned with HexaTheme tokens (Radius.panel, surfaceBase, borderHairline)
    /// to avoid concentric mismatched outlines and double borders.
    private var insetSurface: some View {
        let shape = RoundedRectangle(cornerRadius: HexaTheme.Radius.panel, style: .continuous)
        return shape
            .fill(.regularMaterial)
            .overlay(shape.fill(HexaTheme.surfaceBase.opacity(colorScheme == .light ? 0.65 : 0.80)))
            .overlay(shape.strokeBorder(HexaTheme.borderHairline, lineWidth: HexaTheme.hairline))
    }
}

func appDelegate() -> AppDelegate? {
    NSApp.delegate as? AppDelegate
}

/// The official mark: Conceito A "Segmento aberto" (spec §1.1), drawn in
/// code so it is vector-crisp at any size and follows the theme tokens.
/// `tint` keeps the previous call sites working; the accent segment and the
/// core use `brandSolid` (latão da marca, DEC-017).
struct BrandMark: View {
    var width: CGFloat
    var tint: Color = HexaTheme.fgPrimary

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let inset = CGSize(width: (size.width - side) / 2, height: (size.height - side) / 2)
            var content = context
            content.translateBy(x: inset.width, y: inset.height)
            let strokeStyle = StrokeStyle(lineWidth: HexaBrandGlyph.strokeWidth(for: side),
                                          lineCap: .round, lineJoin: .round)
            for segment in HexaBrandGlyph.closedSegments(size: side) {
                content.stroke(segment, with: .color(tint), style: strokeStyle)
            }
            content.stroke(HexaBrandGlyph.openSegment(size: side),
                           with: .color(HexaTheme.brandSolid), style: strokeStyle)
            content.fill(Path(HexaBrandGlyph.core(size: side)), with: .color(HexaTheme.brandSolid))
        }
        .frame(width: width, height: width)
        .accessibilityHidden(true)
    }
}

struct DiscordMark: View {
    var width: CGFloat

    private static let mark: NSImage? = {
        guard let url = Bundle.main.url(forResource: "discord-symbol",
                                        withExtension: "svg",
                                        subdirectory: "Images") else { return nil }
        return NSImage(contentsOf: url)
    }()

    var body: some View {
        if let mark = Self.mark {
            Image(nsImage: mark)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: width)
        }
    }
}

/// Squircle badge with the mark on the space gradient — the app's face in the
/// About tab and onboarding.
struct BrandBadge: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(Theme.spaceGradient)
            BrandMark(width: size * 0.8)
        }
        .frame(width: size, height: size)
    }
}
