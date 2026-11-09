// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

private enum NotchCaptureControl: Hashable {
    case collapse, close, tool(ScreenCaptureTool)
}

/// The same selection model drives keyboard shortcuts and the screen overlay.
/// Only the controls change their destination; capture remains in its owner.
struct NotchCaptureControlsView: View {
    @ObservedObject var options: ScreenCaptureSelectionOptions
    let service: NotchService
    let layout: NotchCaptureControlsLayout
    @ObservedObject private var l10n = L10n.shared
    @FocusState private var focusedControl: NotchCaptureControl?

    var body: some View {
        VStack(spacing: 12) {
            header
                .padding(.horizontal, NotchLayout.horizontalInset)
                .frame(height: layout.headerHeight)
            HStack(spacing: 6) {
                ForEach(options.showsCaptureMenu ? options.availableTools : [options.selectedTool], id: \.self) { tool in
                    NotchActionTile(symbol: tool.systemImageName,
                                    title: tool.settingsTitle(l10n.s, language: l10n.language),
                                    active: options.selectedTool == tool) { options.select(tool) }
                        .focused($focusedControl, equals: .tool(tool))
                }
            }
            .padding(.horizontal, 18)
        }
        .padding(.top, layout.headerTop)
        .foregroundStyle(HexaTheme.fgPrimary)
        .onChange(of: focusedControl) {
            options.hasFocusedControl = focusedControl != nil
            service.scheduleCaptureControlsCollapse()
        }
        .onDisappear { options.hasFocusedControl = false }
    }

    /// Beside the camera the title and the buttons keep to their own side,
    /// as the open island's header does; otherwise one row holds both.
    @ViewBuilder private var header: some View {
        if layout.cameraGap > 0 {
            HStack(spacing: 0) {
                title
                    .padding(.trailing, NotchCaptureControlsLayout.cameraClearance)
                    .frame(width: layout.sideWidth, alignment: .leading)
                Color.clear.frame(width: layout.cameraGap)
                actions
                    .padding(.leading, NotchCaptureControlsLayout.cameraClearance)
                    .frame(width: layout.sideWidth, alignment: .trailing)
            }
        } else {
            HStack {
                title
                Spacer()
                actions.fixedSize()
            }
        }
    }

    private var text: NotchStrings { FeatureStrings.notch(l10n.language) }

    /// The layout measures this title with the same font.
    private var title: some View {
        Text(FeatureStrings.screenshot(l10n.language).screenCaptureTitle)
            .font(.hexa(.heading))
            .lineLimit(1)
    }

    private var actions: some View {
        HStack(spacing: NotchCaptureControlsLayout.buttonSpacing) {
            if options.offersRepeatLastRegion {
                // A narrow side of the camera keeps only the key.
                ViewThatFits(in: .horizontal) {
                    Label(text.regionShortcutKey, hexaIcon: "rectangle.dashed")
                        .padding(.horizontal, 8)
                    Text(text.regionShortcutKey).frame(width: 28)
                }
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
                .frame(height: 26)
                .background(HexaTheme.surfaceInset, in: RoundedRectangle(cornerRadius: HexaTheme.Radius.control))
            }
            NotchIconButton(symbol: "chevron.up", title: text.collapse,
                            action: service.collapseCaptureControls)
                .focused($focusedControl, equals: .collapse)
            NotchIconButton(symbol: "xmark", title: l10n.s.menuClose, action: service.cancelCaptureControls)
                .focused($focusedControl, equals: .close)
        }
    }
}
