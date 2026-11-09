// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Darwin
import Foundation
import UniformTypeIdentifiers

enum NotchFileToolsSupport {
    static func optimizationTool(for urls: [URL]) -> MediaTool? {
        if accepts(urls, for: .imageCompressor) { return .imageCompressor }
        if accepts(urls, for: .videoCompressor) { return .videoCompressor }
        return nil
    }

    static func accepts(_ urls: [URL], for tool: MediaTool) -> Bool {
        guard !urls.isEmpty, urls.allSatisfy(\.isFileURL),
              tool == .imageCompressor || urls.count == 1 else { return false }
        let types: [UTType] = tool == .videoCompressor || tool == .gifMaker
            ? [.movie, .video] : [.image]
        return urls.allSatisfy { url in
            let type = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType
            return MediaSupport.inputMatchesTool(contentType: type, inputTypes: types)
        }
    }
}
