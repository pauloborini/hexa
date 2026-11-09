// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Screenshot-specific sections inside the shared screen-capture page.
struct ScreenshotCaptureSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var service = ScreenshotService.shared
    @ObservedObject private var screenCaptureService = ScreenCaptureService.shared
    @ObservedObject private var recentCapturesService = RecentCaptureService.shared
    @State private var editorToolsExpanded = false
    @AppStorage(DefaultsKey.screenshotShortcutEnabled)
    private var screenshotShortcutEnabled = false
    @AppStorage(DefaultsKey.screenshotShowCaptureMenuOnShortcut)
    private var showCaptureMenuOnShortcut = true
    @AppStorage(DefaultsKey.recentCapturesShortcutEnabled)
    private var recentCapturesShortcutEnabled = false
    @AppStorage(DefaultsKey.screenshotFullScreenShortcutEnabled)
    private var fullScreenShortcutEnabled = false
    @AppStorage(DefaultsKey.screenshotLastCaptureShortcutEnabled)
    private var lastCaptureShortcutEnabled = false
    @AppStorage(DefaultsKey.screenshotClipboardShortcutEnabled)
    private var clipboardShortcutEnabled = false
    @AppStorage(DefaultsKey.screenshotFreeze) private var freeze = true
    @AppStorage(DefaultsKey.screenshotHideHexaWindows) private var hideHexaWindows = true
    @AppStorage(DefaultsKey.screenshotAutoSaveToFolder) private var autoSaveToFolder = false
    @AppStorage(DefaultsKey.screenshotSaveFolder) private var saveFolder = ""
    @AppStorage(DefaultsKey.screenshotSaveSubfolder) private var saveSubfolder = ""
    @AppStorage(DefaultsKey.screenshotFileNamePattern) private var fileNamePattern = ""
    @AppStorage(DefaultsKey.screenshotFileNumberNext) private var nextNumber = 1
    @AppStorage(DefaultsKey.screenshotIncludePointer) private var includePointer = false
    @AppStorage(DefaultsKey.screenshotShowLastRegion) private var showLastRegion = true
    @AppStorage(DefaultsKey.screenshotLoupeStartsOn) private var loupeStartsOn = false
    @AppStorage(DefaultsKey.screenshotLoupeRememberZoom) private var rememberLoupeZoom = false
    @AppStorage(DefaultsKey.screenshotLoupeDefaultZoom) private var loupeDefaultZoom = 1.0
    @AppStorage(DefaultsKey.screenshotLoupeSteppedZoomByDefault)
    private var steppedLoupeZoomByDefault = false
    @AppStorage(DefaultsKey.screenshotDownscale) private var downscale = false
    @AppStorage(DefaultsKey.screenshotDelay) private var delay = 0
    @AppStorage(DefaultsKey.screenshotDefaultAction) private var defaultActionRaw = ScreenshotDefaultAction.save.rawValue
    @AppStorage(DefaultsKey.screenshotToolOrder) private var toolOrderRaw =
        ScreenshotSupport.Tool.defaultOrderStorage
    @AppStorage(DefaultsKey.screenshotToolShortcutsEnabled) private var toolShortcutsEnabled = true
    @AppStorage(DefaultsKey.screenshotCopyToClipboard) private var copyToClipboard = false
    @AppStorage(DefaultsKey.screenshotPreviewPosition) private var previewPositionRaw = ""
    @AppStorage(DefaultsKey.screenshotPreviewDestination) private var previewDestinationRaw =
        ScreenshotSupport.QuickPreviewDestination.notch.rawValue
    @AppStorage(DefaultsKey.screenshotPreviewTakesFocus) private var previewTakesFocus = false
    @AppStorage(DefaultsKey.screenshotPreviewEnabled) private var previewEnabled = false
    @AppStorage(DefaultsKey.screenshotPreviewDuration) private var previewDuration =
        ScreenshotSupport.defaultConfirmationPreviewDuration
    @AppStorage(DefaultsKey.notchEnabled) private var notchEnabled = true
    let embedded: Bool

    init(embedded: Bool = false) {
        self.embedded = embedded
    }

    private var strings: ScreenshotFeatureStrings {
        FeatureStrings.screenshot(l10n.language)
    }

    var body: some View {
        Group {
            if embedded {
                content
            } else {
                HexaScreenScaffold(title: strings.pageTitle, scrolls: false) {
                    content
                }
            }
        }
    }

    private var content: some View {
        OverlayScrollView {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.l) {
                afterCaptureBlock
                previewBlock
                destinationBlock
                selectionBlock
                loupeBlock
                shortcutsBlock
                editorToolsBlock
            }
            .padding(.horizontal, HexaTheme.Spacing.xxl)
            .padding(.bottom, HexaTheme.Spacing.pageGap)
        }
    }

    // MARK: - Depois de capturar

    private var afterCaptureBlock: some View {
        HexaSection(strings.afterCaptureSection) {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                ScreenshotDefaultActionPicker(strings: strings, selection: $defaultActionRaw)
                Text(strings.defaultActionCaption)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                Toggle(strings.autoCopyToggle, isOn: autoCopyBinding)
                    .toggleStyle(TrailingSwitchToggleStyle())
                    .disabled(defaultAction.copiesToClipboard)
                Text(strings.autoCopyCaption)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
            Toggle(autoSaveToggleTitle, isOn: autoSaveBinding)
                .toggleStyle(TrailingSwitchToggleStyle())
                .disabled(defaultAction.savesFile)
            if folderIsUnavailable {
                HexaStatusNote(message: strings.folderUnavailableNote)
            }
        }
        .settingsSectionAnchor(.screenshot, cornerRadius: HexaTheme.Radius.panel)
    }

    // MARK: - Prévia

    private var previewBlock: some View {
        HexaSection(strings.previewSection) {
            Toggle(strings.confirmationPreviewToggle, isOn: $previewEnabled)
                .toggleStyle(TrailingSwitchToggleStyle())
                .disabled(defaultAction == .edit)

            if defaultAction == .edit {
                Text(strings.previewEditActionNote)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
            } else {
                if previewEnabled || defaultAction == .none {
                    VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                        Text(strings.previewDestinationLabel)
                            .font(.hexa(.body))
                        Picker(strings.previewDestinationLabel, selection: $previewDestinationRaw) {
                            ForEach(ScreenshotSupport.QuickPreviewDestination.allCases) { destination in
                                Text(destination.title(strings)).tag(destination.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    if previewDestinationRaw == ScreenshotSupport.QuickPreviewDestination.notch.rawValue && !notchEnabled {
                        HexaStatusNote(message: strings.previewNotchDisabledNote)
                    }

                    if previewDestinationRaw == ScreenshotSupport.QuickPreviewDestination.screen.rawValue {
                        previewPositionRow
                        previewFocusRow
                    }
                }

                if previewEnabled {
                    Picker(strings.confirmationPreviewDurationLabel, selection: $previewDuration) {
                        ForEach(ScreenshotSupport.confirmationPreviewDurations, id: \.self) { seconds in
                            if seconds == 0 {
                                Text(strings.confirmationPreviewUntilDismissed).tag(0)
                            } else {
                                Text(String(format: strings.delaySecondsFormat, seconds)).tag(seconds)
                            }
                        }
                    }
                }
            }

            Text(strings.confirmationPreviewCaption)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
        }
    }

    // MARK: - Salvar e copiar

    private var destinationBlock: some View {
        HexaSection(strings.destinationFormatSection) {
            folderRow
            subfolderRow
            fileNameRow
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                Toggle(strings.downscaleToggle, isOn: $downscale)
                    .toggleStyle(TrailingSwitchToggleStyle())
                Text(strings.downscaleCaption)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
        }
    }

    // MARK: - Seleção

    private var selectionBlock: some View {
        HexaSection(strings.captureAndLoupeSection) {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                Toggle(strings.freezeToggle, isOn: $freeze)
                    .toggleStyle(TrailingSwitchToggleStyle())
                Text(strings.freezeCaption)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
            Toggle(strings.hideHexaWindowsToggle, isOn: $hideHexaWindows)
                .toggleStyle(TrailingSwitchToggleStyle())
            Picker(strings.delayLabel, selection: $delay) {
                ForEach(ScreenshotSupport.allowedDelays, id: \.self) { seconds in
                    if seconds == 0 {
                        Text(strings.delayOff).tag(0)
                    } else {
                        Text(String(format: strings.delaySecondsFormat, seconds)).tag(seconds)
                    }
                }
            }
            .pickerStyle(.segmented)
            Toggle(strings.pointerToggle, isOn: $includePointer)
                .toggleStyle(TrailingSwitchToggleStyle())
            Toggle(strings.lastRegionToggle, isOn: $showLastRegion)
                .toggleStyle(TrailingSwitchToggleStyle())
        }
    }

    // MARK: - Lupa

    private var loupeBlock: some View {
        HexaSection(strings.loupeSection) {
            Toggle(strings.loupeStartsOnToggle, isOn: $loupeStartsOn)
                .toggleStyle(TrailingSwitchToggleStyle())
            Toggle(strings.loupeRememberZoomToggle, isOn: $rememberLoupeZoom)
                .toggleStyle(TrailingSwitchToggleStyle())
            if !rememberLoupeZoom {
                Picker(strings.loupeDefaultZoomLabel, selection: $loupeDefaultZoom) {
                    ForEach(ScreenshotSupport.captureLoupeDefaultZooms, id: \.self) { zoom in
                        Text(zoom.formatted(
                            .number.precision(.fractionLength(0...1))) + "×")
                            .tag(zoom)
                    }
                }
            }
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                Picker(strings.loupeWheelZoomLabel,
                       selection: $steppedLoupeZoomByDefault) {
                    Text(strings.loupeZoomFast).tag(false)
                    Text(strings.loupeZoomStepped).tag(true)
                }
                .pickerStyle(.segmented)
                Text(strings.loupeZoomOptionCaption)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
        }
    }

    // MARK: - Atalhos

    private var shortcutsBlock: some View {
        HexaSection(l10n.s.shortcutsPageTitle) {
            Toggle(strings.screenshotShortcutLabel, isOn: $screenshotShortcutEnabled)
                .toggleStyle(TrailingSwitchToggleStyle())
                .onChange(of: screenshotShortcutEnabled) { _, _ in
                    screenCaptureService.syncWithPreferences()
                }
            ShortcutPreferenceRow(role: .screenshot, isEnabled: screenshotShortcutEnabled) {
                screenCaptureService.syncWithPreferences()
            }
            Toggle(strings.showCaptureMenuOnShortcut, isOn: $showCaptureMenuOnShortcut)
                .toggleStyle(TrailingSwitchToggleStyle())
                .disabled(!screenshotShortcutEnabled)
            if screenshotShortcutEnabled, screenCaptureService.toolShortcutRegistrationFailures.contains(.screenshot) {
                HexaStatusNote(message: l10n.s.shortcutUnavailable)
            }
            Toggle(strings.recentCapturesShortcutLabel, isOn: $recentCapturesShortcutEnabled)
                .toggleStyle(TrailingSwitchToggleStyle())
                .onChange(of: recentCapturesShortcutEnabled) { _, _ in
                    recentCapturesService.syncWithPreferences()
                }
            ShortcutPreferenceRow(role: .recentCaptures, isEnabled: recentCapturesShortcutEnabled) {
                recentCapturesService.syncWithPreferences()
            }
            if recentCapturesShortcutEnabled, recentCapturesService.shortcutRegistrationFailed {
                HexaStatusNote(message: l10n.s.shortcutUnavailable)
            }
            Toggle(strings.fullScreenShortcutLabel, isOn: $fullScreenShortcutEnabled)
                .toggleStyle(TrailingSwitchToggleStyle())
                .onChange(of: fullScreenShortcutEnabled) { _, _ in
                    ScreenshotService.shared.syncWithPreferences()
                }
            ShortcutPreferenceRow(role: .screenshotFullScreen,
                                  isEnabled: fullScreenShortcutEnabled) {
                ScreenshotService.shared.syncWithPreferences()
            }
            if fullScreenShortcutEnabled, service.fullScreenShortcutRegistrationFailed {
                HexaStatusNote(message: l10n.s.shortcutUnavailable)
            }
            Toggle(strings.lastCaptureShortcutLabel, isOn: $lastCaptureShortcutEnabled)
                .toggleStyle(TrailingSwitchToggleStyle())
                .onChange(of: lastCaptureShortcutEnabled) { _, _ in
                    ScreenshotService.shared.syncWithPreferences()
                }
            ShortcutPreferenceRow(role: .screenshotLastCapture,
                                  isEnabled: lastCaptureShortcutEnabled) {
                ScreenshotService.shared.syncWithPreferences()
            }
            if lastCaptureShortcutEnabled,
               service.lastCaptureShortcutRegistrationFailed {
                HexaStatusNote(message: l10n.s.shortcutUnavailable)
            }
            Toggle(strings.clipboardShortcutLabel, isOn: $clipboardShortcutEnabled)
                .toggleStyle(TrailingSwitchToggleStyle())
                .onChange(of: clipboardShortcutEnabled) { _, _ in
                    ScreenshotService.shared.syncWithPreferences()
                }
            ShortcutPreferenceRow(role: .screenshotClipboard,
                                  isEnabled: clipboardShortcutEnabled) {
                ScreenshotService.shared.syncWithPreferences()
            }
            if clipboardShortcutEnabled, service.clipboardShortcutRegistrationFailed {
                HexaStatusNote(message: l10n.s.shortcutUnavailable)
            }
            if !permissions.screenRecording {
                PermissionRow(kind: .screenRecording)
            }
        }
    }

    // MARK: - Atalhos das ferramentas

    private var editorToolsBlock: some View {
        HexaSection(strings.toolShortcutsTitle) {
            HexaDisclosure(isExpanded: $editorToolsExpanded) {
                Text(strings.editorToolsDisclosure)
                    .font(.hexa(.body))
            } content: {
                ScreenshotToolOrderControls(orderRaw: $toolOrderRaw,
                                            shortcutsEnabled: $toolShortcutsEnabled,
                                            showsTitle: false)
            }
        }
    }

    private var autoSaveToggleTitle: String {
        ScreenshotFeatureStrings.autoSaveToggleTitle(l10n.language)
    }

    /// The after-capture action can copy too, so the toggle reads on while
    /// either one copies. Turning it off only clears the extra copy: the
    /// action itself is the user's choice, never rewritten from here.
    private var autoCopyBinding: Binding<Bool> {
        Binding {
            copyToClipboard || defaultAction.copiesToClipboard
        } set: { isOn in
            copyToClipboard = isOn
        }
    }

    /// Same shape for saving: the action may already save, and the switch
    /// only carries the extra destination.
    private var autoSaveBinding: Binding<Bool> {
        Binding {
            autoSaveToFolder || defaultAction.savesFile
        } set: { isOn in
            autoSaveToFolder = isOn
        }
    }

    private var defaultAction: ScreenshotDefaultAction {
        ScreenshotDefaultAction(rawValue: defaultActionRaw) ?? .none
    }

    /// A stored folder that no longer resolves falls back to the Desktop at
    /// save time; the note tells the user before the capture lands elsewhere.
    private var folderIsUnavailable: Bool {
        guard !saveFolder.isEmpty else { return false }
        let expanded = (saveFolder as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory)
        return !(exists && isDirectory.boolValue)
    }

    private var previewFocusRow: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            Toggle(strings.previewFocusToggle, isOn: $previewTakesFocus)
                .toggleStyle(TrailingSwitchToggleStyle())
            Text(strings.previewFocusCaption)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
        }
    }

    private var previewPositionRow: some View {
        Picker(strings.previewPositionLabel, selection: $previewPositionRaw) {
            Text(strings.previewPositionAutomatic)
                .tag(ScreenshotSupport.QuickPreviewPosition.automatic.rawValue)
            Text(strings.previewPositionTopLeft)
                .tag(ScreenshotSupport.QuickPreviewPosition.topLeft.rawValue)
            Text(strings.previewPositionTopRight)
                .tag(ScreenshotSupport.QuickPreviewPosition.topRight.rawValue)
            Text(strings.previewPositionBottomLeft)
                .tag(ScreenshotSupport.QuickPreviewPosition.bottomLeft.rawValue)
            Text(strings.previewPositionBottomRight)
                .tag(ScreenshotSupport.QuickPreviewPosition.bottomRight.rawValue)
        }
    }

    private var folderRow: some View {
        HStack {
            Text(strings.folderLabel)
            Spacer()
            Text(currentFolderName)
                .foregroundStyle(HexaTheme.fgSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
            if !saveFolder.isEmpty {
                Button {
                    saveFolder = ""
                } label: {
                    HexaIcons.image("xmark.circle.fill")
                        .foregroundStyle(HexaTheme.fgTertiary)
                }
                .buttonStyle(.borderless)
                .screenshotSafeHelp(strings.folderUseDefault)
                .accessibilityLabel(strings.folderUseDefault)
            }
            Button(strings.folderChoose) {
                chooseFolder()
            }
        }
    }

    private var subfolderRow: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            HStack {
                Text(strings.subfolderLabel)
                    .lineLimit(1)
                Spacer(minLength: 12)
                if !saveSubfolder.isEmpty {
                    Text(ScreenshotSupport.expandSaveSubfolder(saveSubfolder, date: Date()))
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                TextField("", text: $saveSubfolder)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                    .accessibilityLabel(strings.subfolderLabel)
            }
            .fixedSize(horizontal: false, vertical: true)
            Text(strings.subfolderCaption)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
        }
    }

    private var fileNameRow: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            HStack {
                Text(strings.fileNamePatternLabel)
                    .lineLimit(1)
                Spacer(minLength: 12)
                Text(fileNamePreview)
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                TextField("", text: $fileNamePattern)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                    .accessibilityLabel(strings.fileNamePatternLabel)
            }
            .fixedSize(horizontal: false, vertical: true)
            Text(strings.fileNamePatternCaption)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
            if ScreenshotSupport.fileNamePatternUsesNumber(fileNamePattern) {
                HStack {
                    Text(strings.fileNumberStartLabel)
                        .lineLimit(1)
                    TextField("", value: $nextNumber, formatter: Self.numberFieldFormatter)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
                        .accessibilityLabel(strings.fileNumberStartLabel)
                    Stepper("", value: $nextNumber, in: 0...999_999)
                        .labelsHidden()
                        .accessibilityLabel(strings.fileNumberStartLabel)
                    Spacer()
                    Button(strings.fileNumberResetButton) {
                        nextNumber = 1
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private static let numberFieldFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 0
        formatter.maximum = 999_999
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    /// Mirrors the runtime name: same base name, then the same "name 2.png"
    /// collision suffix the save applies against the destination folder.
    private var fileNamePreview: String {
        let folder = ScreenshotService.saveDestinationFolder()
        let trimmed = fileNamePattern.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmed.isEmpty
            ? ScreenshotSupport.fileName(prefix: strings.fileNamePrefix, date: Date())
            : ScreenshotSupport.expandFileNamePattern(trimmed, date: Date(), number: nextNumber) + ".png"
        return ScreenshotSupport.uniqueFileName(baseName) { candidate in
            FileManager.default.fileExists(atPath: folder.appendingPathComponent(candidate).path)
        }
    }

    private var currentFolderName: String {
        let manager = FileManager.default
        if !saveFolder.isEmpty {
            let expanded = (saveFolder as NSString).expandingTildeInPath
            var isDirectory: ObjCBool = false
            if manager.fileExists(atPath: expanded, isDirectory: &isDirectory), isDirectory.boolValue {
                return manager.displayName(atPath: expanded)
            }
        }
        let desktop = manager.urls(for: .desktopDirectory, in: .userDomainMask).first
        return desktop.map { manager.displayName(atPath: $0.path) } ?? "Desktop"
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            saveFolder = url.path
        }
    }
}


struct ScreenshotDefaultActionPicker: View {
    let strings: ScreenshotFeatureStrings
    @Binding var selection: String

    var body: some View {
        Picker(strings.defaultActionLabel, selection: $selection) {
            Text(strings.defaultActionNone).tag(ScreenshotDefaultAction.none.rawValue)
            Text(strings.saveButton).tag(ScreenshotDefaultAction.save.rawValue)
            Text(strings.defaultActionSaveAndCopy).tag(ScreenshotDefaultAction.saveAndCopy.rawValue)
            Text(strings.copyButton).tag(ScreenshotDefaultAction.copy.rawValue)
            Text(strings.editButton).tag(ScreenshotDefaultAction.edit.rawValue)
        }
    }
}
