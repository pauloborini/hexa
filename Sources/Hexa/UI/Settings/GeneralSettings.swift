// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI
import ServiceManagement

/// App-wide startup and appearance settings.
struct GeneralSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var appearance = AppAppearanceController.shared
    // Seeded from the stored choice so the switch does not flash off while
    // the status read is still on its way.
    @State private var loginRegistration: LaunchAtLoginSupport.Registration =
        UserDefaults.standard.bool(forKey: DefaultsKey.launchAtLoginWanted) ? .enabled : .off
    @State private var loginError: String?
    @State private var loginRefreshID = UUID()

    private var text: GeneralSettingsStrings { FeatureStrings.generalSettings(l10n.language) }
    private var appearanceStrings: AppearanceStrings { FeatureStrings.appearance(l10n.language) }

    var body: some View {
        HexaScreenScaffold(title: l10n.s.tabGeneral, subtitle: text.pageDescription) {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.l) {
                basicsCard
                appearanceCard
            }
            .padding(.horizontal, HexaTheme.Spacing.xxl)
        }
        .onAppear { refreshLaunchAtLogin() }
        .onReceive(NotificationCenter.default.publisher(
            for: LaunchAtLoginSupport.settingsRefreshRequested)) { _ in
            refreshLaunchAtLogin()
        }
    }

    private var basicsCard: some View {
        HexaSection(text.startupLabel) {
            SettingsRow(symbol: "laptopcomputer", title: l10n.s.launchAtLogin,
                        caption: text.launchAtLoginCaption) {
                // Waiting on approval it is still registered, so it reads on and
                // switching it off unregisters it, which also clears the note.
                Toggle(l10n.s.launchAtLogin, isOn: Binding(
                    get: { loginRegistration != .off },
                    set: { setLaunchAtLogin($0) }
                ))
                    .labelsHidden()
                    .toggleStyle(HexaSwitchStyle())
            }
            if loginRegistration == .needsApproval {
                Text(l10n.s.launchAtLoginNeedsApproval)
                    .hexaCaption()
                HexaAccessButton(icon: "gearshape", title: l10n.s.permissionOpenSettings) {
                    SMAppService.openSystemSettingsLoginItems()
                }
            } else if let loginError {
                Text(loginError)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.statusDanger)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HairlineDivider()
            SettingsRow(symbol: "globe", title: l10n.s.languageLabel) {
                Picker(l10n.s.languageLabel, selection: $l10n.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
        }
    }

    private var appearanceCard: some View {
        HexaSection(appearanceStrings.label) {
            HStack(spacing: HexaTheme.Spacing.s) {
                ForEach(AppAppearance.allCases) { option in
                    AppearanceChoice(option: option,
                                     title: option.title(appearanceStrings),
                                     selected: appearance.appearance == option) {
                        appearance.appearance = option
                    }
                }
            }
            Text(text.appearanceCaption)
                .hexaCaption()
        }
    }

    private func refreshLaunchAtLogin() {
        let requestID = UUID()
        loginRefreshID = requestID
        DispatchQueue.global(qos: .userInitiated).async {
            let registration = LaunchAtLogin.registration
            DispatchQueue.main.async {
                guard loginRefreshID == requestID else { return }
                loginRegistration = registration
                loginError = nil
            }
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        loginRefreshID = UUID()
        do {
            try LaunchAtLogin.setEnabled(enabled)
            loginError = nil
        } catch {
            loginError = error.localizedDescription
        }
        loginRegistration = LaunchAtLogin.registration
        // Approval guidance follows current system status, including on a
        // fresh page, instead of retaining an error from a previous attempt.
        if loginRegistration == .needsApproval { loginError = nil }
    }

}

/// Three little desktops with a window on each: the same picture System
/// Settings uses, so the choice needs no reading.
private struct AppearanceChoice: View {
    let option: AppAppearance
    let title: String
    let selected: Bool
    let action: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            VStack(spacing: HexaTheme.Spacing.s) {
                thumbnail
                    .frame(height: 66)
                    .clipShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                            .strokeBorder(selected ? HexaTheme.accentSolid : HexaTheme.borderHairline,
                                          lineWidth: selected ? 2 : 1)
                    }
                Text(title)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(HexaTheme.Spacing.s)
            .background(selected ? HexaTheme.selectionBg : Color.clear,
                        in: RoundedRectangle(cornerRadius: HexaTheme.Radius.panel, style: .continuous))
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: HexaTheme.Radius.panel, style: .continuous)
                        .strokeBorder(HexaTheme.focusRing, lineWidth: 2)
                        .padding(1)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.panel, style: .continuous))
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var thumbnail: some View {
        switch option {
        case .light:
            DesktopThumbnail(dark: false)
        case .dark:
            DesktopThumbnail(dark: true)
        case .system:
            ZStack {
                DesktopThumbnail(dark: false)
                DesktopThumbnail(dark: true)
                    .mask(DiagonalHalf())
            }
        }
    }
}

/// A desktop gradient with a sidebar window on it, painted in the
/// appearance it stands for; the colors are the subject, so they stay fixed.
private struct DesktopThumbnail: View {
    let dark: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: dark
                               ? [Color(red: 0.20, green: 0.22, blue: 0.34), Color(red: 0.07, green: 0.07, blue: 0.13)]
                               : [Color(red: 0.80, green: 0.88, blue: 1.00), Color(red: 0.58, green: 0.72, blue: 0.95)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 0) {
                HStack(spacing: 3) {
                    Circle().fill(Color(red: 1.00, green: 0.37, blue: 0.34))
                    Circle().fill(Color(red: 1.00, green: 0.74, blue: 0.18))
                    Circle().fill(Color(red: 0.16, green: 0.78, blue: 0.25))
                    Spacer(minLength: 0)
                }
                .frame(height: 5)
                .padding(.horizontal, 6)
                .frame(height: 12)
                .background(Color(white: dark ? 0.22 : 0.93))
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                        bar(width: 18)
                        bar(width: 22)
                        bar(width: 14)
                    }
                    .padding(6)
                    .frame(width: 34, alignment: .topLeading)
                    .background(Color(white: dark ? 0.16 : 0.90))
                    VStack(alignment: .leading, spacing: 5) {
                        bar(width: 46)
                        bar(width: 34)
                        bar(width: 40)
                    }
                    .padding(HexaTheme.Spacing.s)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .background(Color(white: dark ? 0.19 : 0.99))
            .clipShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
            .padding(.top, HexaTheme.Spacing.m)
            .padding(.leading, 14)
        }
    }

    private func bar(width: CGFloat) -> some View {
        Capsule()
            .fill(Color(white: dark ? 0.40 : 0.76))
            .frame(width: width, height: 3)
    }
}

/// The lower-right half of a rectangle, cut corner to corner.
private struct DiagonalHalf: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// The idle menu bar glyph, tinted white for dark surfaces.
struct MenuBarGlyph: View {
    var body: some View {
        Group {
            // The menu bar icon is fixed (DEC-018); a saved symbol never reaches it.
            if let image = HexaStatusGlyph.mark() {
                Image(nsImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                HexaIcons.image("circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .foregroundStyle(HexaTheme.fgPrimary)
    }
}
