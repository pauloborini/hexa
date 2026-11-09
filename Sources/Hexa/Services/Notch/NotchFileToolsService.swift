// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import Combine
import Darwin

struct NotchMediaSession: Identifiable {
    let id = UUID()
    let inputs: [URL]
    let tool: MediaTool
}

final class NotchFileToolsService: ObservableObject {
    static let shared = NotchFileToolsService()
    let media = MediaService(replacesExistingOutputs: false)
    @Published private(set) var mediaSession: NotchMediaSession?
    @Published private(set) var mediaPresented = false
    @Published private(set) var mediaContentHeight: CGFloat?
    private(set) var mediaSelection = MediaWorkspaceSelection()

    private init() {}

    var offersMediaDrop: Bool {
        NotchSupport.showsFiles() && AppFeature.mediaTools.isAvailable
    }

    var canAcceptMediaDrop: Bool {
        if case .running = media.state { return false }
        return offersMediaDrop
    }

    func mediaDropContent(for pasteboard: NSPasteboard) -> (tool: MediaTool, inputs: [URL])? {
        guard offersMediaDrop,
              !pasteboard.canReadObject(forClasses: [NSFilePromiseReceiver.self], options: nil) else { return nil }
        let inputs = (pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL])?
            .filter { $0.isFileURL } ?? []
        // Mixed payloads (files and non-files) are not a media drop.
        guard inputs.count >= (pasteboard.pasteboardItems?.count ?? 0) else { return nil }
        guard let tool = NotchFileToolsSupport.optimizationTool(for: inputs) else { return nil }
        return (tool, inputs)
    }

    func openMediaDrop(_ pasteboard: NSPasteboard) -> Bool {
        guard canAcceptMediaDrop, let content = mediaDropContent(for: pasteboard) else { return false }
        return openMedia(content.tool, inputs: content.inputs)
    }

    func updateMediaHeight(id: UUID, height: CGFloat) {
        guard mediaSession?.id == id, height.isFinite, height > 0 else { return }
        let measured = ceil(height)
        if mediaContentHeight != measured { mediaContentHeight = measured }
    }

    func showMedia() {
        guard offersMediaDrop, mediaSession != nil else { return }
        mediaPresented = true
    }

    func hideMedia() {
        mediaPresented = false
    }

    func syncWithPreferences() {
        guard NotchSupport.showsFiles(), AppFeature.mediaTools.isAvailable else {
            stop()
            return
        }
    }

    /// A real stop, including application termination.
    func stop() {
        media.cancel(immediately: true)
        mediaSelection.durationLoading.cancel()
        mediaSelection = MediaWorkspaceSelection()
        mediaSession = nil
        mediaPresented = false
        mediaContentHeight = nil
    }

    @discardableResult
    func openMedia(_ tool: MediaTool, inputs: [URL]) -> Bool {
        guard NotchSupport.showsFiles(), AppFeature.mediaTools.isAvailable,
              NotchFileToolsSupport.accepts(inputs, for: tool) else { return false }
        closeMedia()
        mediaSession = NotchMediaSession(inputs: inputs, tool: tool)
        mediaPresented = true
        return true
    }

    func closeMedia() {
        media.reset()
        mediaSelection.durationLoading.cancel()
        mediaSelection = MediaWorkspaceSelection()
        mediaSession = nil
        mediaPresented = false
        mediaContentHeight = nil
    }
}
