// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// One brightness slider per adjustable display, with the options that govern
/// the keys and the shortcuts. Values refresh whenever the section appears, so
/// changes made with the keyboard, in System Settings or on the monitor itself
/// are picked up. The page presents the options as a visible section; the menu
/// bar panel keeps them behind a disclosure to stay compact.
struct BrightnessSection: View {
    @Environment(\.featureWorkspacePresentation) private var featureWorkspacePresentation
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = BrightnessService.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(DefaultsKey.brightnessControlEnabled) private var brightnessControlEnabled = false
    @AppStorage(DefaultsKey.brightnessOSDEnabled) private var brightnessOSDEnabled = false
    @AppStorage(DefaultsKey.brightnessKeysEnabled) private var brightnessKeysEnabled = false
    @AppStorage(DefaultsKey.brightnessKeyStep) private var brightnessKeyStep = BrightnessSupport.KeyStep.standard.rawValue
    @State private var optionsExpanded = false
    var collapsible = true

    private var strings: BrightnessFeatureStrings { FeatureStrings.brightness(l10n.language) }
    /// The panel keeps 20 pt controls; the page has room for the 28 pt ones.
    private var compactControls: Bool { !featureWorkspacePresentation }
    private var screenControlEnabled: Bool { !featureWorkspacePresentation || brightnessControlEnabled }

    var body: some View {
        Group {
            if featureWorkspacePresentation {
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.l) {
                    HexaSection(strings.pageTitle) {
                        cardContent
                    }
                    if screenControlEnabled {
                        HexaSection(strings.optionsTitle) {
                            optionsContent
                        }
                    }
                }
            } else {
                PanelSection(.brightness, title: strings.pageTitle, collapsible: collapsible) {
                    VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                        cardContent
                        if screenControlEnabled {
                            HairlineDivider()
                            optionsDisclosure
                        }
                    }
                    .panelCard()
                }
            }
        }
        .onAppear {
            brightnessKeyStep = BrightnessSupport.KeyStep.sanitized(brightnessKeyStep).rawValue
            service.refresh()
            service.refreshKeyboardLight()
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            if featureWorkspacePresentation {
                optionToggle(icon: AppFeature.brightness.symbolName,
                             title: strings.enable,
                             isOn: $brightnessControlEnabled)
                    .onChange(of: brightnessControlEnabled) { _, _ in
                        service.syncWithPreferences()
                    }
            }
            if !screenControlEnabled {
                Text(strings.enableCaption)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                if service.displays.isEmpty {
                    if service.isRefreshing {
                        HexaBusyState(variant: .compact, message: strings.readingDisplays)
                    } else {
                        Text(strings.noDisplays)
                            .font(.hexa(.label))
                            .foregroundStyle(HexaTheme.fgSecondary)
                    }
                } else {
                    ForEach(service.displays) { display in
                        row(display)
                    }
                }
                // A failure that names no display belongs to the surface, not
                // to a row; the per-display one is drawn inside that row.
                if let failure = service.displayControlFailure,
                   service.displayControlFailureDisplayID == nil {
                    Text(displayControlFailureText(failure, strings: strings))
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.statusDanger)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if service.keyboardLightEnabled != nil {
                HairlineDivider()
                keyboardLightRow
            }
        }
    }

    private var optionsDisclosure: some View {
        HexaDisclosure(isExpanded: $optionsExpanded) {
            Text(strings.optionsTitle).font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
        } content: {
            optionsContent
        }
    }

    private var optionsContent: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.m) {
            if service.brightnessOSDSupported {
                optionToggle(icon: "sun.max",
                             title: strings.osdToggle,
                             caption: strings.osdCaption,
                             isOn: $brightnessOSDEnabled)
                    .onChange(of: brightnessOSDEnabled) { _, isOn in
                        if isOn { permissions.requestAccessibility() }
                        service.syncWithPreferences()
                    }
                if brightnessOSDEnabled, !permissions.accessibility {
                    HexaAccessButton(icon: "hand.raised",
                                     title: l10n.s.permissionOpenSettings) {
                        permissions.openAccessibilitySettings()
                    }
                    .padding(.leading, HexaTheme.Spacing.xl)
                }
                HairlineDivider()
            }
            optionToggle(icon: "keyboard",
                         title: strings.keysToggle,
                         caption: strings.keysCaption,
                         isOn: $brightnessKeysEnabled)
                .onChange(of: brightnessKeysEnabled) { _, isOn in
                    if isOn { permissions.requestAccessibility() }
                    service.syncWithPreferences()
                }
            if brightnessKeysEnabled, !permissions.accessibility {
                HexaAccessButton(icon: "hand.raised",
                                 title: l10n.s.permissionOpenSettings) {
                    permissions.openAccessibilitySettings()
                }
                .padding(.leading, HexaTheme.Spacing.xl)
            }
            keyStepRow
            HairlineDivider()
            DisplayBrightnessShortcutControls()
        }
    }

    private var keyStepRow: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            HStack(spacing: HexaTheme.Spacing.s) {
                HexaIcons.image("arrow.left.and.right", size: 11)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .frame(width: 15)
                Text(strings.keyStep)
                    .font(.hexa(.label))
                Spacer(minLength: 8)
                Picker(strings.keyStep, selection: $brightnessKeyStep) {
                    ForEach(BrightnessSupport.KeyStep.allCases, id: \.self) { step in
                        Text(keyStepTitle(step)).tag(step.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .fixedSize()
                .onChange(of: brightnessKeyStep) { _, _ in
                    service.syncWithPreferences()
                }
            }
            Text(strings.keyStepCaption)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, HexaTheme.Spacing.xl)
        }
    }

    private func keyStepTitle(_ step: BrightnessSupport.KeyStep) -> String {
        switch step {
        case .standard: return strings.keyStepStandard
        case .half: return strings.keyStepHalf
        case .quarter: return strings.keyStepQuarter
        }
    }

    /// A labelled switch row. The label stays visible next to the control, and
    /// the switch is the canonical `HexaSwitchStyle` used by the rest of the
    /// app. The caption sits under the label, aligned with it.
    private func optionToggle(icon: String,
                              title: String,
                              caption: String? = nil,
                              isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            HStack(spacing: HexaTheme.Spacing.s) {
                HexaIcons.image(icon, size: 11)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .frame(width: 15)
                Text(title)
                    .font(.hexa(.label))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Toggle(title, isOn: isOn)
                    .toggleStyle(HexaSwitchStyle())
                    .labelsHidden()
            }
            if let caption {
                Text(caption)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, HexaTheme.Spacing.xl)
            }
        }
    }

    private func row(_ display: BrightnessDisplay) -> some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            HStack(spacing: HexaTheme.Spacing.xs) {
                HexaIcons.image(display.isBuiltIn ? "laptopcomputer" : "display", size: 11)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .frame(width: 16)
                Text(displayLabel(display))
                    .font(.hexa(.body))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 4)
                if display.isActive, display.method != nil {
                    Text("\(Int((display.brightness * 100).rounded()))%")
                        .font(.hexa(.data))
                        .foregroundStyle(HexaTheme.fgSecondary)
                } else if !display.isActive {
                    Text(strings.displayOff)
                        .font(.hexa(.body))
                        .foregroundStyle(HexaTheme.fgSecondary)
                }
                DisplayPowerButton(display: display, compact: compactControls)
            }
            if display.isActive, display.method != nil {
                Slider(value: brightnessBinding(display), in: 0...1)
                    .controlSize(.small)
                    .disabled(service.isDisplayPending(display.id))
                    .accessibilityLabel(displayLabel(display))
            }
            if display.isActive, !display.isBuiltIn, display.method != nil {
                routeFooter(display)
            }
            SoftwareDimmingButton(display: display, compact: compactControls)
            if service.displayControlFailureDisplayID == display.id,
               let failure = service.displayControlFailure {
                Text(displayControlFailureText(failure, strings: strings))
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.statusDanger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Two identical monitors carry the same product name; the ordinal keeps
    /// each slider tied to one screen on the desk.
    private func displayLabel(_ display: BrightnessDisplay) -> String {
        let sameName = service.displays.filter { $0.name == display.name }
        guard sameName.count > 1,
              let index = sameName.firstIndex(where: { $0.id == display.id }) else {
            return display.name
        }
        return "\(display.name) (\(index + 1))"
    }

    /// The route each external display's brightness actually takes, with a
    /// retry for the states a person cannot otherwise act on: a channel
    /// whose writes go through and whose reads never answer, and one demoted
    /// to picture dimming because it never applied them. Both verdicts
    /// expire on their own; this is the immediate way back.
    private func routeFooter(_ display: BrightnessDisplay) -> some View {
        HStack(spacing: HexaTheme.Spacing.xs) {
            Text(routeText(display))
                .font(.hexa(.micro))
                .foregroundStyle(HexaTheme.fgSecondary)
            Spacer(minLength: 4)
            if display.routeKind == .ddcWriteOnly || display.routeKind == .softwareAuto {
                Button {
                    service.retryDDCClassification(for: display.id)
                } label: {
                    HStack(spacing: HexaTheme.Spacing.xs) {
                        HexaIcons.image("arrow.clockwise", size: 11)
                        Text(strings.retryDDCClassification)
                            .font(.hexa(.micro))
                            .lineLimit(1)
                    }
                    .foregroundStyle(HexaTheme.fgSecondary)
                }
                .buttonStyle(.plain)
                .disabled(service.isDisplayPending(display.id))
                .accessibilityLabel("\(display.name): \(strings.retryDDCClassification)")
            }
        }
    }

    private func routeText(_ display: BrightnessDisplay) -> String {
        switch display.routeKind {
        case .system: return strings.routeSystem
        case .ddcReadable: return strings.routeDDCReadable
        case .ddcWriteOnly:
            return display.writeOnlyVerdictCached
                ? strings.routeDDCWriteOnlyCached
                : strings.routeDDCWriteOnly
        case .software: return strings.routeSoftware
        case .softwareAuto: return strings.routeSoftwareAuto
        case .softwareAmbiguous: return strings.routeSoftwareAmbiguous
        case .none: return ""
        }
    }

    /// Sits with the display sliders because it is the same control. The
    /// Quick toggles switch stays the place to flip it off and back on, and
    /// the slider reaches 0, so the row carries no switch of its own.
    private var keyboardLightRow: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            HStack(spacing: HexaTheme.Spacing.xs) {
                HexaIcons.image("keyboard", size: 11)
                    .font(.hexa(.body))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .frame(width: 16)
                Text(strings.keyboardLight)
                    .font(.hexa(.body))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("\(Int(((service.keyboardLightLevel ?? 0) * 100).rounded()))%")
                    .font(.hexa(.data))
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
            Slider(value: keyboardLightBinding, in: 0...1,
                   onEditingChanged: service.keyboardLightDragChanged)
                .controlSize(.small)
                .accessibilityLabel(strings.keyboardLight)
        }
    }

    private var keyboardLightBinding: Binding<Double> {
        Binding(get: { Double(service.keyboardLightLevel ?? 0) },
                set: { service.setKeyboardLightLevel(Float($0)) })
    }

    private func brightnessBinding(_ display: BrightnessDisplay) -> Binding<Double> {
        Binding(get: { display.brightness },
                set: { service.setBrightness($0, for: display.id,
                                             showOSD: brightnessOSDEnabled) })
    }
}

/// Shared routing choice, on every surface that shows the display rows: the
/// slider is just as dead on the Energy page as in the panel, so the way out
/// has to be there too.
///
/// On readable DDC displays, the choice extends the slider below the panel's
/// hardware minimum; the page offers it, and the compact panel keeps only the
/// write-only fallback so the quick surface stays short. Either choice stays
/// visible until cleared.
struct SoftwareDimmingButton: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = BrightnessService.shared
    let display: BrightnessDisplay
    var compact = false

    private var strings: BrightnessFeatureStrings { FeatureStrings.brightness(l10n.language) }
    private var extendedChosen: Bool { service.extendedDimmingPreferred.contains(display.id) }
    private var softwareChosen: Bool { service.softwareDimmingPreferred.contains(display.id) }
    private var chosen: Bool { extendedChosen || softwareChosen }
    private var usesExtendedDimming: Bool {
        !softwareChosen && (extendedChosen || (display.method == .ddc && display.readable))
    }

    private var offered: Bool {
        guard display.isActive, !display.isBuiltIn, display.canChooseDimming else { return false }
        if chosen { return true }
        guard display.method == .ddc else { return false }
        // The panel keeps only the write-only way out; extra dimming joins it
        // once it is on.
        return !(compact && display.readable)
    }

    var body: some View {
        if offered {
            Button {
                if usesExtendedDimming {
                    service.setExtendedDimmingPreferred(!extendedChosen, for: display.id)
                } else {
                    service.setSoftwareDimmingPreferred(!softwareChosen, for: display.id)
                }
            } label: {
                HStack(spacing: HexaTheme.Spacing.xs) {
                    HexaIcons.image(chosen ? "checkmark.circle.fill" : "circle.lefthalf.filled")
                        .font(compact ? .hexa(.micro) : .hexa(.label))
                    Text(usesExtendedDimming ? strings.extendedDimming : strings.softwareDimming)
                        .font(compact ? .hexa(.label) : .hexa(.body))
                        .lineLimit(1)
                }
                .foregroundStyle(chosen ? HexaTheme.fgPrimary : HexaTheme.fgSecondary)
            }
            .buttonStyle(.plain)
            .disabled(service.isDisplayPending(display.id))
            .accessibilityLabel("\(display.name): \(usesExtendedDimming ? strings.extendedDimming : strings.softwareDimming)")
            .accessibilityAddTraits(chosen ? [.isSelected] : [])
        }
    }
}

/// Shared power affordance used by the page and the menu bar panel. It stays
/// icon-only in the row, with a localized tooltip and accessibility label.
struct DisplayPowerButton: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = BrightnessService.shared
    let display: BrightnessDisplay
    var compact = false

    private var strings: BrightnessFeatureStrings { FeatureStrings.brightness(l10n.language) }
    private var pending: Bool { service.isDisplayPending(display.id) }
    private var enabled: Bool { service.canToggleDisplay(display) }

    private var label: String {
        if !service.displaySwitchingAvailable { return strings.switchUnavailable }
        if display.isActive, !enabled { return strings.lastDisplayCaption }
        return display.isActive ? strings.turnOffDisplay : strings.turnOnDisplay
    }

    var body: some View {
        Group {
            if pending {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: compact ? 16 : 20, height: 18)
                    .accessibilityLabel(label)
            } else {
                HexaIconButton(icon: display.isActive ? "power" : "power.circle.fill",
                               label: label,
                               variant: compact ? .small : .regular,
                               iconTint: display.isActive ? HexaTheme.fgSecondary : HexaTheme.statusOk) {
                    service.toggleDisplay(display)
                }
                .disabled(!enabled)
                .help(label)
            }
        }
    }
}

func displayControlFailureText(_ failure: BrightnessService.DisplayControlFailure,
                               strings: BrightnessFeatureStrings) -> String {
    switch failure {
    case .unavailable: return strings.switchUnavailable
    case .lastActive: return strings.lastDisplayCaption
    case .failed: return strings.switchFailed
    case .closedLid: return strings.openLidToEnable
    }
}

extension BrightnessFeatureStrings {
    /// Section title for the brightness options disclosure.
    var optionsTitle: String {
        switch L10n.shared.language {
        case .enUS: return "Brightness Options"
        case .ptBR: return "Opções de brilho"
        case .tr: return "Parlaklık Seçenekleri"
        case .ru: return "Параметры яркости"
        case .es: return "Opciones de brillo"
        case .sk: return "Možnosti jasu"
        case .de: return "Helligkeitsoptionen"
        case .fr: return "Options de luminosité"
        case .it: return "Opzioni luminosità"
        case .ja: return "輝度設定"
        case .ko: return "밝기 옵션"
        case .zhHans: return "亮度选项"
        case .zhTW: return "亮度選項"
        case .zhHK: return "亮度選項"
        case .uk: return "Параметри яскравості"
        }
    }

    /// The page's reading state while the first display probe is answering.
    var readingDisplays: String {
        switch L10n.shared.language {
        case .enUS: return "Reading displays…"
        case .ptBR: return "Lendo telas…"
        case .tr: return "Ekranlar okunuyor…"
        case .ru: return "Чтение дисплеев…"
        case .es: return "Leyendo pantallas…"
        case .sk: return "Načítavajú sa displeje…"
        case .de: return "Displays werden gelesen…"
        case .fr: return "Lecture des écrans…"
        case .it: return "Lettura degli schermi…"
        case .ja: return "ディスプレイを読み込み中…"
        case .ko: return "디스플레이 읽는 중…"
        case .zhHans: return "正在读取显示器…"
        case .zhTW: return "正在讀取顯示器…"
        case .zhHK: return "正在讀取顯示器…"
        case .uk: return "Читання дисплеїв…"
        }
    }
}
