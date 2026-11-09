// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import SwiftUI

/// Reusable controls for screenshot tool order and shortcut assignments.
struct ScreenshotToolOrderControls: View {
    @ObservedObject private var l10n = L10n.shared
    @Binding var orderRaw: String
    @Binding var shortcutsEnabled: Bool
    var showsTitle = true
    @AppStorage(DefaultsKey.screenshotToolShortcuts) private var bindingsRaw = ""
    @State private var recordingTool: ScreenshotSupport.Tool?
    @State private var errorText: String?
    @StateObject private var keyboard = ScreenshotShortcutContext()

    private var strings: ScreenshotFeatureStrings {
        FeatureStrings.screenshot(l10n.language)
    }

    private var movementStrings: ClipboardFeatureStrings {
        FeatureStrings.clipboard(l10n.language)
    }

    private var orderedTools: [ScreenshotSupport.Tool] {
        ScreenshotSupport.Tool.ordered(from: orderRaw)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            if showsTitle {
                Text(strings.toolShortcutsTitle)
                    .font(.hexa(.heading))
            }

            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                Toggle(strings.toolShortcutsToggle, isOn: $shortcutsEnabled)
                Text(strings.toolShortcutsCaption)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: HexaTheme.Spacing.xs) {
                ForEach(orderedTools, id: \.self) { tool in
                    toolRow(tool)
                    if tool != orderedTools.last {
                        HairlineDivider()
                    }
                }
            }

            if let errorText {
                HexaStatusNote(message: errorText)
            } else if recordingTool != nil {
                Text(ShortcutRecordingCaption.text(l10n.s, canClear: true))
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button(l10n.s.shortcutReset) {
                    orderRaw = ScreenshotSupport.Tool.defaultOrderStorage
                    bindingsRaw = ""
                    errorText = nil
                }
                .disabled(orderRaw == ScreenshotSupport.Tool.defaultOrderStorage && bindingsRaw.isEmpty)
            }
        }
        .onChange(of: l10n.language) { _, _ in errorText = nil }
        .onAppear { keyboard.start() }
        .onDisappear { keyboard.stop() }
    }

    private func toolRow(_ tool: ScreenshotSupport.Tool) -> some View {
        let index = orderedTools.firstIndex(of: tool) ?? 0

        return HStack(spacing: HexaTheme.Spacing.s) {
            HexaIcons.image(tool.screenshotSymbolName)
                .foregroundStyle(HexaTheme.fgSecondary)
                .frame(width: 20)
            Text(tool.screenshotTitle(strings))
                .lineLimit(1)
            Spacer(minLength: 4)

            Group {
                if ScreenshotSupport.Tool.bindings(from: bindingsRaw)[tool] != nil {
                    Button {
                        var bindings = ScreenshotSupport.Tool.bindings(from: bindingsRaw)
                        bindings[tool] = nil
                        bindingsRaw = ScreenshotSupport.Tool.bindingsStorage(bindings)
                        errorText = nil
                    } label: {
                        HexaIcons.image("arrow.counterclockwise", size: 11)
                            .font(.hexa(.label))
                            .foregroundStyle(HexaTheme.fgSecondary)
                            .frame(width: 28, height: 28)
                            .background(HexaTheme.surfaceInset,
                                        in: RoundedRectangle(cornerRadius: HexaTheme.Radius.control))
                    }
                    .buttonStyle(.plain)
                    .help(l10n.s.shortcutReset)
                    .accessibilityLabel(tool.screenshotTitle(strings) + ": " + l10n.s.shortcutReset)
                } else {
                    Color.clear.frame(width: 28, height: 28)
                }
            }

            shortcutRecorder(for: tool)

            Button {
                move(tool, by: -1)
            } label: {
                HexaIcons.image("chevron.up")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .disabled(index == 0)
            .accessibilityLabel(movementStrings.moveUp)

            Button {
                move(tool, by: 1)
            } label: {
                HexaIcons.image("chevron.down")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .disabled(index == orderedTools.count - 1)
            .accessibilityLabel(movementStrings.moveDown)
        }
        .frame(minHeight: 26)
        .contentShape(Rectangle())
    }

    private func shortcutRecorder(for tool: ScreenshotSupport.Tool) -> some View {
        let binding = ScreenshotSupport.Tool.activeBindings(
            from: bindingsRaw, capsLockOn: keyboard.capsLockOn)[tool]
        // The position digit is a title, not a shortcut: the field shows it
        // as its empty state so nothing else (Delete, reset) treats it as a
        // recorded key.
        let label = ScreenshotSupport.Tool.shortcutLabel(
            for: tool, orderRaw: orderRaw, bindingsRaw: bindingsRaw, enabled: true,
            capsLockOn: keyboard.capsLockOn)
        return ShortcutRecorderButton(
            shortcut: binding ?? .keepAwakeDefault,
            isEnabled: shortcutsEnabled,
            waitingTitle: l10n.s.shortcutPressKeys,
            requiresModifier: false,
            emptyTitle: binding == nil ? (label ?? l10n.s.shortcutNone) : nil,
            clearAction: { assign(nil, to: tool) },
            notCapturedAction: { errorText = l10n.s.shortcutNotCaptured },
            recordingChanged: { recording in
                recordingTool = recording ? tool : nil
                if recording { errorText = nil }
            },
            captureWithFlagsAction: { shortcut, flags in
                assign(shortcut, to: tool, capsLockOn: flags.contains(.maskAlphaShift))
            },
            invalidAction: { errorText = l10n.s.shortcutNotCaptured },
            captureAction: { assign($0, to: tool, capsLockOn: keyboard.capsLockOn) })
            .frame(width: 86, height: 28)
            // Linha compacta da lista: controles e campo de 28 pt (alvo mínimo).
            .controlSize(.small)
            .accessibilityLabel(tool.screenshotTitle(strings))
    }

    private func move(_ tool: ScreenshotSupport.Tool, by offset: Int) {
        var order = orderedTools
        guard let index = order.firstIndex(of: tool) else { return }
        let destination = index + offset
        guard order.indices.contains(destination) else { return }
        withAnimation(.easeInOut(duration: 0.14)) {
            order.swapAt(index, destination)
            persist(order)
        }
    }

    /// A digit moves the tool and skips every conflict check. Anything else
    /// has to be free before it is saved; a rejection leaves the previous
    /// binding in place and says who owns the key.
    private func assign(_ shortcut: GlobalShortcut?, to tool: ScreenshotSupport.Tool,
                        capsLockOn: Bool = false) {
        let digit = shortcut.flatMap { ScreenshotSupport.Tool.shortcutDigit($0, capsLockOn: capsLockOn) }
        if let shortcut, digit == nil, let rejection = ScreenshotSupport.Tool.bindingRejection(
            for: shortcut, excluding: tool, bindingsRaw: bindingsRaw,
            roleConflict: { GlobalShortcutRole.conflict(for: $0, excluding: nil) },
            systemConflict: { $0.conflictsWithSystemShortcut }) {
            let reason: String
            switch rejection {
            case .reserved:
                reason = strings.toolShortcutReserved
            case .tool(let other):
                reason = String(format: l10n.s.shortcutConflictFormat, other.screenshotTitle(strings))
            case .role(let role):
                reason = String(format: l10n.s.shortcutConflictFormat, role.title(l10n.s))
            case .system:
                reason = String(format: l10n.s.shortcutConflictFormat, "macOS")
            }
            errorText = tool.screenshotTitle(strings) + " · " + shortcut.displayString + "\n" + reason
            return
        }
        let assignment = ScreenshotSupport.Tool.assigningBinding(
            shortcut, digit: digit, to: tool, orderRaw: orderRaw, bindingsRaw: bindingsRaw)
        orderRaw = assignment.orderRaw
        bindingsRaw = assignment.bindingsRaw
        errorText = nil
    }

    private func persist(_ order: [ScreenshotSupport.Tool]) {
        orderRaw = order.map(\.rawValue).joined(separator: ",")
    }
}

/// Only visible editor/shortcut controls observe keyboard context. Saved
/// preferences stay unchanged; badges reflect which bindings can work now.
final class ScreenshotShortcutContext: ObservableObject {
    @Published private(set) var capsLockOn = false
    private var flagsMonitor: Any?
    private var observers: [NSObjectProtocol] = []

    func start() {
        guard flagsMonitor == nil else { return }
        updateCapsLock(NSEvent.modifierFlags)
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.updateCapsLock(event.modifierFlags)
            return event
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: GlobalShortcut.keyboardLayoutDidChange, object: nil, queue: .main
        ) { [weak self] _ in self?.objectWillChange.send() })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.updateCapsLock(NSEvent.modifierFlags) })
    }

    private func updateCapsLock(_ flags: NSEvent.ModifierFlags) {
        let locked = flags.contains(.capsLock)
        if capsLockOn != locked { capsLockOn = locked }
    }

    func stop() {
        if let flagsMonitor { NSEvent.removeMonitor(flagsMonitor) }
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        flagsMonitor = nil
        observers.removeAll()
    }

    deinit { stop() }
}
