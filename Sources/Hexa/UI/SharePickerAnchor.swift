// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import SwiftUI

/// Opens the system share sheet for files, from a toolbar button. It holds
/// the picker while the sheet is up, brings the app forward only once a
/// target has actually been chosen (the island and panels never activate on
/// their own, so a share window would otherwise open behind whatever is in
/// front), and lets the picker go afterwards.
final class SharePickerPresenter: NSObject, NSSharingServicePickerDelegate, NSSharingServiceDelegate {
    private var picker: NSSharingServicePicker?
    private var completion: ((Bool) -> Void)?
    private var activeService: NSSharingService?

    /// `completion` reports whether a target was chosen once the sheet
    /// closes. It never runs when there was no window to show the sheet
    /// from, which the result reports as false.
    @discardableResult
    func present(for urls: [URL], from view: NSView, completion: ((Bool) -> Void)? = nil) -> Bool {
        guard let window = view.window else { return false }
        let picker = makePicker(for: urls)
        self.completion = completion
        self.activeService = nil

        NSApp.activate(ignoringOtherApps: true)
        if !window.isKeyWindow {
            window.makeKeyAndOrderFront(nil)
        }

        let targetBounds = view.bounds.isEmpty
            ? (view.superview?.bounds ?? CGRect(x: 0, y: 0, width: 24, height: 24))
            : view.bounds

        DispatchQueue.main.async { [weak self, weak view] in
            guard self != nil, let view, view.window != nil else {
                completion?(false)
                return
            }
            picker.show(relativeTo: targetBounds, of: view, preferredEdge: .minY)
        }
        return true
    }

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker,
                              didChoose service: NSSharingService?) {
        guard sharingServicePicker === picker else { return }
        picker = nil
        guard let service else {
            let completion = self.completion
            self.completion = nil
            completion?(false)
            return
        }
        activeService = service
        service.delegate = self
    }

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker,
                              delegateFor sharingService: NSSharingService) -> (any NSSharingServiceDelegate)? {
        return self
    }

    func sharingService(_ sharingService: NSSharingService,
                        didShareItems items: [Any]) {
        finish(success: true)
    }

    func sharingService(_ sharingService: NSSharingService,
                        didFailToShareItems items: [Any],
                        error: any Error) {
        finish(success: false)
    }

    private func finish(success: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.activeService = nil
            let completion = self.completion
            self.completion = nil
            completion?(success)
        }
    }

    private func makePicker(for urls: [URL]) -> NSSharingServicePicker {
        let picker = NSSharingServicePicker(items: urls)
        picker.delegate = self
        self.picker = picker
        completion = nil
        return picker
    }
}

/// Hosts the invisible view the system share sheet is anchored to. SwiftUI
/// creates and owns that view, so the button reaches whichever one is on
/// screen right now through the box below.
struct SharePickerAnchor: NSViewRepresentable {
    final class Anchor {
        fileprivate weak var view: NSView?
        private let presenter = SharePickerPresenter()

        @discardableResult
        func present(_ urls: [URL], completion: ((Bool) -> Void)? = nil) -> Bool {
            guard let view else { return false }
            return presenter.present(for: urls, from: view, completion: completion)
        }
    }

    let anchor: Anchor

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        anchor.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        anchor.view = nsView
    }
}
