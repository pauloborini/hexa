// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// The General page's tools, one anchor at a time: the menu bar item (icon
/// and panel sections) and the mixer. Every control writes an existing
/// preference; the page introduces no new key.
struct GeneralToolSettings: View {
    let anchor: SettingsSectionAnchor
    let embedded: Bool

    @ObservedObject private var l10n = L10n.shared

    init(anchor: SettingsSectionAnchor, embedded: Bool = false) {
        self.anchor = anchor
        self.embedded = embedded
    }

    var body: some View {
        if embedded {
            anchorContent
        } else {
            HexaScreenScaffold(title: pageTitle) {
                anchorContent
                    .padding(.horizontal, HexaTheme.Spacing.xxl)
            }
        }
    }

    @ViewBuilder
    private var anchorContent: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xl) {
            switch anchor {
            // No call site uses `.panelConfiguration` today (the only caller passes
            // `.mixer`); the menu bar item is configured by `MenuBarSettings`.
            case .panelConfiguration: MenuBarItemConfigCard()
            case .mixer: MixerCard()
            default: EmptyView()
            }
        }
    }

    private var pageTitle: String {
        switch anchor {
        case .panelConfiguration: return l10n.s.menuBarSection
        case .mixer: return l10n.s.mixerSection
        default: return l10n.s.tabGeneral
        }
    }
}

/// The menu bar item: which icon it wears and which panel sections show.
/// Readings printed beside the icon are opt-in per metric and stay on the
/// Monitor page, where the metrics live.
/// Unreachable today: no call site builds this card, since `.panelConfiguration` is never passed.
private struct MenuBarItemConfigCard: View {
    @ObservedObject private var l10n = L10n.shared
    @State private var sectionsRevision = UUID()

    private var text: GeneralSettingsStrings { FeatureStrings.generalSettings(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xl) {
            HexaSection(text.menuBarIconTitle) {
                HStack(spacing: HexaTheme.Spacing.m) {
                    BrandMark(width: HexaTheme.Spacing.xxl, tint: HexaTheme.fgPrimary)
                    HexaTheme.wordmark(size: HexaTheme.Spacing.xl)
                }
            }

            HexaSection(l10n.s.utilitiesSection) {
                Text(text.panelIntro)
                    .hexaCaption()
                ForEach(PanelSectionID.allCases) { section in
                    sectionRow(section)
                }
                Text(text.panelReorderHint)
                    .hexaCaption()
                Button(l10n.s.shortcutReset) {
                    PanelLayout.setOrder(PanelSectionID.allCases)
                    sectionsRevision = UUID()
                }
                .buttonStyle(HexaActionButtonStyle())
            }
        }
    }

    @ViewBuilder
    private func sectionRow(_ section: PanelSectionID) -> some View {
        let caption = caption(for: section)
        SettingsRow(symbol: section.symbolName, title: section.title(l10n.s), caption: caption) {
            Toggle(section.title(l10n.s), isOn: Binding(
                get: { PanelLayout.isShown(section) },
                set: { shown in
                    UserDefaults.standard.set(shown, forKey: section.visibilityKey)
                    sectionsRevision = UUID()
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .disabled(!section.isAvailable)
        }
    }

    /// The sections themselves stay put in the panel; the feature captions
    /// say what each one is, and visibility follows the installed features.
    private func caption(for section: PanelSectionID) -> String? {
        let text = FeatureStrings.generalSettings(l10n.language)
        switch section {
        case .keepAwake: return text.sectionKeepAwake
        case .brightness: return text.sectionDisplays
        case .mixer: return text.sectionMixer
        case .system: return text.sectionSystem
        case .network: return text.sectionNetwork
        case .disk: return text.sectionDisks
        case .power: return text.sectionPower
        case .fanControl: return text.sectionFanControl
        case .utilities: return text.sectionUtilities
        }
    }


}

/// The mixer's app-wide preferences. Per-app sliders live in the panel and
/// the notch; this card holds the behavior the whole mixer shares.
private struct MixerCard: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.mixerLowerVolumeOnHeadphonesDisconnect) private var lowerOnDisconnect = false
    @AppStorage(DefaultsKey.mixerHeadphonesDisconnectVolumePercent) private var disconnectVolumePercent = Defaults.defaultMixerHeadphonesDisconnectVolumePercent

    var body: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xl) {
            // Sem rótulo: o título da página já está no scaffold (DEC-017).
            HexaCard {
                Toggle(l10n.s.mixerLowerOnHeadphonesDisconnect, isOn: $lowerOnDisconnect)
                    .toggleStyle(TrailingSwitchToggleStyle())
                Text(l10n.s.mixerLowerOnHeadphonesDisconnectCaption)
                    .hexaCaption()
                    .padding(.leading, settingsRowTextInset)
                if lowerOnDisconnect {
                    SettingsRow(symbol: "speaker.minus", title: l10n.s.mixerHeadphonesDisconnectVolume) {
                        EmptyView()
                    }
                    .transition(.opacity)
                    HStack {
                        Slider(value: Binding(
                            get: { Double(disconnectVolumePercent) },
                            set: { disconnectVolumePercent = Int($0.rounded()) }
                        ), in: 0...100)
                        .padding(.leading, settingsRowTextInset)
                        Text("\(disconnectVolumePercent)%")
                            .font(.hexa(.data))
                            .foregroundStyle(HexaTheme.fgSecondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }
        }
        .animation(.easeOut(duration: 0.15), value: lowerOnDisconnect)
    }
}
