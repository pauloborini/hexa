// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Feedback keeps the central camera area clear on physical and simulated notches.
struct NotchNoticeView: View {
    let notice: NotchNotice
    let geometry: NotchGeometry
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var wings: NotchNoticeWings { notice.wings(in: geometry) }
    private var tint: Color {
        switch notice.event {
        // The timer's notice keeps the orange its strip and page wear.
        case .timer: return HexaTheme.statusWarning
        default: return HexaTheme.fgPrimary
        }
    }
    /// The words of a timer's notice share its orange too.
    private var textTint: Color { notice.event == .timer ? HexaTheme.statusWarning : HexaTheme.fgPrimary }

    var body: some View {
        Group {
            if geometry.isNotched {
                physicalNotchContent
            } else {
                simulatedNotchContent
            }
        }
        .foregroundStyle(HexaTheme.fgPrimary)
        .frame(height: geometry.stripHeight)
        // A new reading that needs another width, as a level passing 99%,
        // moves its mark and meter with the island's steady ease, not ahead of it.
        // Keyed on the notice's own widths, so a display change does not ease it.
        .animation(reduceMotion ? nil : .spring(duration: NotchMotion.steadyWidth.duration, bounce: 0),
                   value: notice.preferredWings)
        .transaction { $0.disablesAnimations = false }
        // Another kind of notice is drawn anew at its place, as the island
        // springs to it, rather than easing out of the last one's layout.
        .id(notice.event)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(notice.accessibilityText)
    }

    private var physicalNotchContent: some View {
        HStack(spacing: 0) {
            leading
                .padding(.leading, notice.inset(wing: wings.leading))
                .padding(.trailing, notice.cameraGap)
                .frame(width: wings.leading, height: geometry.stripHeight)
                .clipped()
            Color.clear.frame(width: geometry.noticeCameraGap)
            trailing
                .padding(.trailing, notice.inset(wing: wings.trailing))
                .padding(.leading, notice.cameraGap)
                .frame(width: wings.trailing, height: geometry.stripHeight)
                .clipped()
        }
        // Each side is as wide as what it shows, so the island reaches
        // further toward the wider one and the camera's gap stays over it.
        .offset(x: (wings.trailing - wings.leading) / 2)
    }

    private var simulatedNotchContent: some View {
        HStack(spacing: 8) {
            if let content = notice.notification {
                HStack(spacing: NotchNotificationBannerLayout.spacing) {
                    NotchNotificationAppIcon(app: content.app, size: min(16, geometry.stripHeight - 4))
                    Text(content.compactTitle)
                        .font(.hexaManrope(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .layoutPriority(1)
                    Spacer(minLength: 4)
                    Text(content.compactDetail)
                        .font(.hexaManrope(size: 13, weight: .regular))
                        .foregroundStyle(HexaTheme.fgPrimary.opacity(0.85))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            } else if let level = notice.level {
                HexaIcons.image(notice.symbol, size: 14)
                    .font(.hexaManrope(size: 14, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 16)
                NotchMeter(value: level, height: 5, tint: tint)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: level)
                    .frame(maxWidth: .infinity)
                Text(notice.detail)
                    .font(.hexaManrope(size: 13, weight: .medium))
                    .foregroundStyle(textTint)
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            } else {
                Group {
                    if notice.event == .track {
                        NotchTrackArtwork(size: min(16, geometry.stripHeight - 6))
                    } else {
                        HexaIcons.image(notice.symbol, size: 14)
                            .font(.hexaManrope(size: 14, weight: .medium))
                            .foregroundStyle(tint)
                    }
                }
                .frame(width: 16)
                Text(notice.title)
                    .font(.hexaManrope(size: 13, weight: .semibold))
                    .foregroundStyle(textTint)
                    .lineLimit(1)
                    .layoutPriority(1)
                if !notice.detail.isEmpty {
                    Spacer(minLength: 4)
                    Text(notice.detail)
                        .font(.hexaManrope(size: 13, weight: .regular))
                        .foregroundStyle(textTint.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(notice.event == .accessory ? .middle : .tail)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var leading: some View {
        if let content = notice.notification {
            HStack(spacing: NotchNotificationBannerLayout.spacing) {
                NotchNotificationAppIcon(app: content.app, size: min(16, geometry.stripHeight - 4))
                Text(content.compactTitle)
                    .font(.hexaManrope(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            HStack(spacing: 8) {
                Group {
                    if notice.event == .track {
                        NotchTrackArtwork(size: min(16, geometry.stripHeight - 6))
                    } else {
                        HexaIcons.image(notice.symbol, size: 14)
                            .font(.hexaManrope(size: 14, weight: .medium))
                            .foregroundStyle(tint)
                    }
                }
                .frame(width: 16)
                Text(notice.level == nil ? notice.title : notice.detail)
                    .font(.hexaManrope(size: 13, weight: notice.level == nil ? .semibold : .medium))
                    .foregroundStyle(textTint)
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .truncationMode(notice.event == .track ? .tail : .middle)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, alignment: notice.readsFromEnds ? .leading : .trailing)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: notice.detail)
            .transaction { $0.disablesAnimations = false }
        }
    }

    @ViewBuilder private var trailing: some View {
        if let content = notice.notification {
            // At the far end, as far from it as the sender is from the other
            // one, with the air that fits it beside the camera.
            Text(content.compactDetail)
                .font(.hexaManrope(size: 13, weight: .regular))
                .foregroundStyle(HexaTheme.fgPrimary.opacity(0.85))
                .lineLimit(NotchNotificationBannerLayout.messageLines(stripHeight: geometry.stripHeight))
                .frame(maxWidth: .infinity, alignment: .trailing)
        } else if let level = notice.level {
            NotchMeter(value: level, height: 5, tint: tint)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: level)
                .transaction { $0.disablesAnimations = false }
        } else {
            Text(notice.detail)
                .font(.hexaManrope(size: 13, weight: .regular))
                .foregroundStyle(textTint.opacity(0.8))
                .lineLimit(1)
                .truncationMode(notice.event == .accessory ? .middle : .tail)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

/// The new song's cover, read as it arrives: it often lands after the title.
private struct NotchTrackArtwork: View {
    @ObservedObject private var music = NotchMusicService.shared
    let size: CGFloat

    var body: some View { NotchArtwork(image: music.artwork, size: size) }
}

/// Level feedback occupies the header while the current page stays usable.
struct NotchExpandedLevelView: View {
    let notice: NotchNotice

    var body: some View {
        HStack(spacing: 8) {
            HexaIcons.image(notice.symbol)
                .frame(width: 18)
            NotchMeter(value: notice.level ?? 0, height: 5, tint: HexaTheme.fgPrimary)
                .frame(maxWidth: 96)
            Text(notice.detail)
                .monospacedDigit()
                .fixedSize()
        }
        .font(.hexa(.label))
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(notice.accessibilityText)
    }
}
