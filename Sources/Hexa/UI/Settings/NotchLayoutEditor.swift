// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import SwiftUI

struct NotchLayoutEditor: View {
    @Binding var configuration: NotchQuickAccessConfiguration
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var notch = NotchService.shared
    @State private var editingID: UUID?
    @State private var editingName = ""
    @State private var draggingID: UUID?
    @State private var hoveredID: UUID?
    @State private var targetID: UUID?
    @State private var addingAction = false
    private var text: NotchStrings { FeatureStrings.notch(l10n.language) }
    private var editor: NotchEditorStrings { FeatureStrings.notchEditor(l10n.language) }
    private var experience: NotchExperienceStrings { FeatureStrings.notchExperience(l10n.language) }

    var body: some View {
        VStack(spacing: HexaTheme.Spacing.m) {
            Text(editor.layoutHint).font(.hexa(.body)).foregroundStyle(HexaTheme.fgSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            LazyVGrid(columns: columns, spacing: NotchQuickAccessLayout.buttonSpacing) {
                ForEach(configuration.buttons) { button in
                    bubble(button)
                }
                if configuration.buttons.count < NotchQuickAccessConfiguration.maximumButtons {
                    addButton
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The bar's own columns at the island's width, so a shortcut wraps here
    /// where it wraps in the island. The add tile counts as the next slot.
    private var columns: [GridItem] {
        let width = max(180, notch.geometry.contentWidth)
        let count = NotchQuickAccessLayout(count: configuration.buttons.count + 1, width: width).columns
        return Array(repeating: GridItem(.flexible(), spacing: NotchQuickAccessLayout.buttonSpacing), count: count)
    }

    private var addButton: some View {
        Button { editingID = nil; addingAction = true } label: {
            NotchQuickButtonLabel(symbol: "plus", title: editor.addButton)
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: HexaTheme.Radius.control, lifts: false))
        .popover(isPresented: $addingAction, arrowEdge: .top) {
            NotchActionChooser(title: editor.addButton, excluded: Set(configuration.actions.map(\.canonical))) { action in
                guard configuration.buttons.count < NotchQuickAccessConfiguration.maximumButtons,
                      !configuration.actions.map(\.canonical).contains(action.canonical) else { return }
                configuration.buttons.append(NotchQuickButton(action: action.canonical))
                addingAction = false
            }
        }
    }

    private func bubble(_ button: NotchQuickButton) -> some View {
        let title = button.label.isEmpty ? button.action?.title(l10n) ?? editor.editButton : button.label
        let available = button.action?.isAvailable() == true
        return NotchQuickButtonLabel(symbol: button.action?.symbol ?? "questionmark", title: title,
                                     selected: editingID == button.id, showsGrip: true)
            .overlay {
                RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                    .fill(hoveredID == button.id ? HexaTheme.selectionBg : .clear)
                    .allowsHitTesting(false)
            }
            .overlay {
                if targetID == button.id, draggingID != button.id {
                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                        .strokeBorder(HexaTheme.accentSolid, lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            // A shortcut whose feature or page is off says so on the tile
            // instead of leaving a place that looks ready in the bar.
            .overlay(alignment: .trailing) {
                if !available {
                    HexaIcons.image("eye.slash", size: 10)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgTertiary)
                        .padding(.trailing, HexaTheme.Spacing.s)
                        .allowsHitTesting(false)
                        .help(text.disabled)
                        .accessibilityLabel(text.disabled)
                }
            }
            .opacity(draggingID == button.id ? 0.45 : available ? 1 : 0.5)
            .overlay {
                NotchShortcutTileDrag(id: button.id, label: editor.editButton + ", " + title, help: title,
                                      onTap: { editingName = button.label; editingID = button.id },
                                      onHover: { hovering in hoveredID = hovering ? button.id : (hoveredID == button.id ? nil : hoveredID) },
                                      onBegin: { draggingID = button.id },
                                      onTarget: { entered in targetID = entered ? button.id : (targetID == button.id ? nil : targetID) },
                                      onEnd: { draggingID = nil; targetID = nil },
                                      move: { dragged, target in moveShortcut(dragged, onto: target) })
            }
            .popover(isPresented: Binding(get: { editingID == button.id }, set: { if !$0 { editingID = nil } }),
                     arrowEdge: .top) {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.m) {
                Text(editor.editButton).font(.hexa(.heading))
                TextField(editor.buttonName, text: $editingName, prompt: Text(button.action?.title(l10n) ?? ""))
                    .onChange(of: editingName) { _, value in
                        if let index = configuration.buttons.firstIndex(where: { $0.id == button.id }) { configuration.buttons[index].label = value }
                    }
                HStack {
                    Button(experience.moveUp) { reorder(button.id, by: -1) }
                    Button(experience.moveDown) { reorder(button.id, by: 1) }
                }.controlSize(.small)
                NotchActionChooser(title: "", selected: button.action,
                                   excluded: Set(configuration.buttons.filter { $0.id != button.id }.compactMap { $0.action?.canonical })) { action in
                    if let index = configuration.buttons.firstIndex(where: { $0.id == button.id }) { configuration.buttons[index].actionID = action.canonical.id }
                }
                Button(editor.removeButton, role: .destructive) {
                    editingID = nil
                    configuration.buttons.removeAll { $0.id == button.id }
                }
            }.padding(HexaTheme.Spacing.l).frame(width: 340)
        }
    }

    /// Moves a shortcut into the slot of another. A forward move lands after the
    /// target, so the last slot stays reachable.
    private func moveShortcut(_ dragged: UUID, onto target: UUID) {
        guard dragged != target,
              let from = configuration.buttons.firstIndex(where: { $0.id == dragged }),
              let to = configuration.buttons.firstIndex(where: { $0.id == target }) else { return }
        let anchor: UUID? = to > from ? configuration.buttons.dropFirst(to + 1).first?.id : target
        configuration.move(dragged, before: anchor)
    }

    private func reorder(_ id: UUID, by offset: Int) {
        guard let index = configuration.buttons.firstIndex(where: { $0.id == id }),
              configuration.buttons.indices.contains(index + offset) else { return }
        configuration.buttons.swapAt(index, index + offset)
    }
}

/// Click, hover and drag for one shortcut tile, handled in AppKit. The mixer
/// reorders its apps the same way, because SwiftUI drag never started on these
/// tiles. The tile is also a keyboard target and an accessibility button.
private struct NotchShortcutTileDrag: NSViewRepresentable {
    static let pasteboardType = NSPasteboard.PasteboardType("com.hexa.notch-shortcut")
    let id: UUID
    let label: String
    let help: String
    let onTap: () -> Void
    let onHover: (Bool) -> Void
    let onBegin: () -> Void
    let onTarget: (Bool) -> Void
    let onEnd: () -> Void
    let move: (UUID, UUID) -> Void

    func makeNSView(context: Context) -> DragView { DragView() }

    func updateNSView(_ view: DragView, context: Context) {
        view.source = self
        view.setAccessibilityLabel(label)
        view.toolTip = help
    }

    final class DragView: NSView, NSDraggingSource {
        var source: NotchShortcutTileDrag?
        private var start: NSPoint?

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            registerForDraggedTypes([NotchShortcutTileDrag.pasteboardType])
            setAccessibilityRole(.button)
        }

        required init?(coder: NSCoder) { nil }

        override var acceptsFirstResponder: Bool { true }
        override var mouseDownCanMoveWindow: Bool { false }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(NSTrackingArea(rect: bounds,
                                           options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                           owner: self, userInfo: nil))
        }

        override func mouseEntered(with event: NSEvent) { source?.onHover(true) }
        override func mouseExited(with event: NSEvent) { source?.onHover(false) }

        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
            start = event.locationInWindow
        }

        override func mouseUp(with event: NSEvent) {
            if start != nil { source?.onTap() }
            start = nil
        }

        override func mouseDragged(with event: NSEvent) {
            guard let start, let source,
                  hypot(event.locationInWindow.x - start.x, event.locationInWindow.y - start.y) >= 4 else { return }
            self.start = nil
            let item = NSPasteboardItem()
            item.setString(source.id.uuidString, forType: NotchShortcutTileDrag.pasteboardType)
            let draggingItem = NSDraggingItem(pasteboardWriter: item)
            draggingItem.setDraggingFrame(bounds, contents: snapshot())
            source.onBegin()
            beginDraggingSession(with: [draggingItem], event: event, source: self)
        }

        override func keyDown(with event: NSEvent) {
            // Return and Space press the tile, as a focused button would.
            guard event.keyCode == 36 || event.keyCode == 49 else { return super.keyDown(with: event) }
            source?.onTap()
        }

        override func accessibilityPerformPress() -> Bool {
            source?.onTap()
            return true
        }

        override func becomeFirstResponder() -> Bool {
            needsDisplay = true
            return super.becomeFirstResponder()
        }

        override func resignFirstResponder() -> Bool {
            needsDisplay = true
            return super.resignFirstResponder()
        }

        /// Keyboard focus ring, the same stroke the notch buttons draw.
        override func draw(_ dirtyRect: NSRect) {
            guard window?.firstResponder === self else { return }
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1),
                                    xRadius: HexaTheme.Radius.control, yRadius: HexaTheme.Radius.control)
            path.lineWidth = 2
            HexaTheme.focusRingNSColor.setStroke()
            path.stroke()
        }

        private func snapshot() -> NSImage? {
            guard let root = window?.contentView else { return nil }
            let rect = convert(bounds, to: root)
            guard let rep = root.bitmapImageRepForCachingDisplay(in: rect) else { return nil }
            root.cacheDisplay(in: rect, to: rep)
            let image = NSImage(size: rect.size)
            image.addRepresentation(rep)
            return image
        }

        private func draggedID(_ sender: NSDraggingInfo) -> UUID? {
            (sender.draggingSource as? DragView)?.source?.id
        }

        override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
            guard let source, let dragged = draggedID(sender) else { return [] }
            source.onTarget(true)
            source.move(dragged, source.id)
            return .move
        }

        /// Reorders once per entry. Repeating the move on every update could undo
        /// it before the grid lays out again.
        override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
            draggedID(sender) == nil ? [] : .move
        }

        override func draggingExited(_ sender: NSDraggingInfo?) { source?.onTarget(false) }

        override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
            source?.onTarget(false)
            return true
        }

        func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
            context == .withinApplication ? .move : []
        }

        func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }

        func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
            source?.onEnd()
        }
    }
}

struct NotchActionChooser: View {
    let title: String
    var selected: NotchQuickAction?
    var excluded: Set<NotchQuickAction> = []
    let choose: (NotchQuickAction) -> Void
    @ObservedObject private var l10n = L10n.shared
    private var editor: NotchEditorStrings { FeatureStrings.notchEditor(l10n.language) }
    @State private var query = ""
    @FocusState private var searching: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.m) {
            if !title.isEmpty { Text(title).font(.hexa(.heading)) }
            TextField(editor.findAction, text: $query).textFieldStyle(.roundedBorder).focused($searching)
            ScrollView {
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.m) {
                    if !NotchQuickAction.optionalActions.contains(where: { matchesQuery($0) }) {
                        Text(FeatureStrings.clipboard(l10n.language).noResults)
                            .foregroundStyle(HexaTheme.fgSecondary).frame(maxWidth: .infinity, minHeight: 120)
                    }
                    group(editor.quickActions, actions: NotchQuickAction.optionalActions)
                }.padding(2)
            }.frame(height: 200)
        }.padding(title.isEmpty ? 0 : HexaTheme.Spacing.l).frame(width: title.isEmpty ? nil : 340)
            .onAppear { searching = !title.isEmpty }
    }

    private func matchesQuery(_ action: NotchQuickAction) -> Bool {
        guard action.isAvailable(), !excluded.contains(action.canonical) else { return false }
        let term = CommandBarSearch.normalized(query)
        return term.isEmpty || CommandBarSearch.normalized(action.title(l10n) + " " + action.id).contains(term)
    }

    @ViewBuilder private func group(_ title: String, actions: [NotchQuickAction]) -> some View {
        let matches = actions.filter(matchesQuery)
        if !matches.isEmpty {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                Text(title).font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: HexaTheme.Spacing.xs) {
                    ForEach(matches) { action in
                        Button { choose(action) } label: {
                            Label(action.title(l10n), hexaIcon: action.symbol)
                                .font(.hexa(.label)).lineLimit(2)
                                .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading).padding(.horizontal, HexaTheme.Spacing.s)
                                .background(selected == action ? HexaTheme.selectionBg : HexaTheme.surfaceInset, in: RoundedRectangle(cornerRadius: HexaTheme.Radius.control))
                        }.buttonStyle(.plain).disabled(!action.isAvailable())
                    }
                }
            }
        }
    }
}
