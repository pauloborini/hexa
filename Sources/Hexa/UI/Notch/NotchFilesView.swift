// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct NotchFilesView: View {
    @ObservedObject var service: NotchService
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var archives = NotchFileToolsService.shared
    @ObservedObject private var media = NotchFileToolsService.shared.media
    @Environment(\.notchSettingsPreview) private var preview
    private var text: NotchFilesStrings { FeatureStrings.notchFiles(l10n.language) }

    var body: some View {
        VStack(spacing: NotchLayout.rowSpacing) {
            if service.choosingFileDropDestination, AppFeature.mediaTools.isAvailable {
                dropDestination(text.optimizeMedia, symbol: "wand.and.stars", available: archives.canAcceptMediaDrop)
            } else if let session = archives.mediaSession, archives.mediaPresented, AppFeature.mediaTools.isAvailable {
                MediaWorkspaceView(compact: true, onClose: archives.closeMedia,
                                   media: media, initialInputs: session.inputs,
                                   initialTool: session.tool, preservesServiceState: true,
                                   workspace: archives.mediaSelection,
                                   onContentHeightChange: { mediaHeightChanged($0, id: session.id) },
                                   onToolChange: { service.refreshPresentation(transitionContent: .replace) })
                    .id(session.id)
            } else {
                NotchEmptyView(symbol: "tray.and.arrow.down", message: text.mediaDropHint)
                    .frame(maxHeight: .infinity)
                    .overlay { RoundedRectangle(cornerRadius: HexaTheme.Radius.panel, style: .continuous)
                        .strokeBorder(HexaTheme.fgPrimary.opacity(0.18), style: StrokeStyle(lineWidth: 0.75, dash: [4, 5])) }
            }
            if !service.choosingFileDropDestination, !archives.mediaPresented, AppFeature.mediaTools.isAvailable {
                if archives.mediaSession != nil {
                    Button(action: archives.showMedia) {
                        Label(text.resumeMedia, hexaIcon: "wand.and.stars")
                    }.controlSize(.small)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: archives.mediaSession?.id) {
            if !preview { service.refreshPresentation() }
        }
        .onChange(of: archives.mediaPresented) { if !preview { service.refreshPresentation() } }
        .onDisappear {
            // Only the island's own page holds the island open.
            if !preview { service.keepFileInteractionOpen(false) }
        }
        .onChange(of: features.revision) {
            if !AppFeature.mediaTools.isAvailable {
                archives.syncWithPreferences()
            }
        }
    }

    private func mediaHeightChanged(_ height: CGFloat, id: UUID) {
        let previous = archives.mediaContentHeight
        archives.updateMediaHeight(id: id, height: height)
        // Start the native resize in the same layout callback. Waiting for a
        // second SwiftUI update leaves the new controls inside the old frame,
        // and an unrelated preference refresh can settle it without animation.
        if archives.mediaContentHeight != previous { service.refreshPresentation() }
    }

    private func dropDestination(_ title: String, symbol: String, available: Bool) -> some View {
        VStack(spacing: 12) {
            HexaIcons.image(symbol, size: 28).font(.hexa(.display(28)))
            Text(title).font(.hexa(.body)).multilineTextAlignment(.center)
            if !available { Text(l10n.s.mediaRunning).font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary) }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HexaTheme.selectionBg, in: RoundedRectangle(cornerRadius: HexaTheme.Radius.panel))
        .overlay {
            RoundedRectangle(cornerRadius: HexaTheme.Radius.panel)
                .strokeBorder(HexaTheme.fgPrimary.opacity(0.7), lineWidth: 1.5)
        }
        .accessibilityElement(children: .combine)
        .opacity(available ? 1 : 0.5)
    }
}
