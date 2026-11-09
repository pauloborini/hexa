// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import Carbon.HIToolbox
import SwiftUI

struct ShortcutRecorderButton: NSViewRepresentable {    let shortcut: GlobalShortcut
    let isEnabled: Bool
    /// Shown inside the field while it is listening. Short on purpose: the
    /// sentence explaining what to do lives in the caption under the row, so
    /// the field never has to grow to fit it.
    let waitingTitle: String
    var requiresModifier = true
    /// When set, the button shows this instead of the shortcut, meaning "no
    /// shortcut assigned"; clicking still records a new one.
    var emptyTitle: String? = nil
    /// Set by rows whose shortcut may be removed. Delete on its own then takes
    /// the shortcut off instead of trying to record.
    var clearAction: (() -> Void)? = nil
    /// Fired when the combination never reached us, so the row can say why.
    var notCapturedAction: (() -> Void)? = nil
    /// Lets the row show its caption exactly while the field is listening.
    var recordingChanged: ((Bool) -> Void)? = nil
    /// For local shortcuts whose typed character also depends on Caps Lock.
    /// When supplied, this handles capture instead of the ordinary callback.
    var captureWithFlagsAction: ((GlobalShortcut, CGEventFlags) -> Void)? = nil
    /// Only hold-trigger fields opt into recording a chord without a key.
    var captureModifiersAction: ((GlobalShortcutModifiers) -> Void)? = nil
    let invalidAction: () -> Void
    let captureAction: (GlobalShortcut) -> Void

    func makeNSView(context: Context) -> RecorderButton {
        let button = RecorderButton()
        // Sem bezel do sistema: o casco é desenhado pelo RecorderButton com o
        // mesmo desenho do botão de ação neutra (spec §7, padrão de botões).
        button.isBordered = false
        button.focusRingType = .none
        button.setButtonType(.momentaryPushIn)
        // One font in every state. The field used to swap a monospaced cap for
        // a proportional sentence, which changed its width mid-interaction.
        // Papel `label` (Manrope 500, 12), o mesmo do botão neutro.
        button.font = HexaTheme.manropeFont(size: 12, weight: .medium)
        // A translation longer than the field trims instead of spilling over
        // the label beside it.
        button.cell?.lineBreakMode = .byTruncatingTail
        button.target = button
        button.action = #selector(RecorderButton.beginRecording)
        apply(to: button)
        return button
    }

    func updateNSView(_ nsView: RecorderButton, context: Context) {
        apply(to: nsView)
    }

    /// The SwiftUI frame decides the width, never the title. An AppKit view's
    /// intrinsic size otherwise wins over the frame, so the field grew with
    /// its own text and slid over the column beside it. The
    /// height follows the control size as the neutral action button does
    /// (36 regular, 28 mini/small), so the two sit at the same height.
    func sizeThatFits(_ proposal: ProposedViewSize,
                      nsView: RecorderButton,
                      context: Context) -> CGSize? {
        let intrinsic = nsView.intrinsicContentSize
        let compact = [ControlSize.mini, .small].contains(context.environment.controlSize)
        let height = compact ? HexaTheme.Density.rowCompact : HexaTheme.Density.rowStandard
        return CGSize(width: proposal.width ?? intrinsic.width, height: height)
    }

    static func dismantleNSView(_ nsView: RecorderButton, coordinator: ()) {
        // The view can go away mid-recording (a sheet closing, a page swap).
        // Nothing else would give the app's own shortcuts back. The row is
        // going away with it, so drop the callback first rather than touch its
        // state while SwiftUI is taking it apart.
        nsView.recordingChanged = nil
        nsView.stopRecording()
    }

    private func apply(to button: RecorderButton) {
        button.requiresModifier = requiresModifier
        button.shortcut = shortcut
        button.waitingTitle = waitingTitle
        button.emptyTitle = emptyTitle
        button.clearAction = clearAction
        button.notCapturedAction = notCapturedAction
        button.recordingChanged = recordingChanged
        button.captureWithFlagsAction = captureWithFlagsAction
        button.captureModifiersAction = captureModifiersAction
        button.invalidAction = invalidAction
        button.captureAction = captureAction
        button.isEnabled = isEnabled
        button.refreshTitle()
    }
}

final class RecorderButton: NSButton {
    var requiresModifier = true
    var shortcut = GlobalShortcut.keepAwakeDefault
    var waitingTitle = ""
    var emptyTitle: String?
    var clearAction: (() -> Void)?
    var notCapturedAction: (() -> Void)?
    var recordingChanged: ((Bool) -> Void)?
    var captureWithFlagsAction: ((GlobalShortcut, CGEventFlags) -> Void)?
    var captureModifiersAction: ((GlobalShortcutModifiers) -> Void)?
    private var modifierRecording = ModifierShortcutRecording()
    var invalidAction: (() -> Void)?
    var captureAction: ((GlobalShortcut) -> Void)?
    private var isRecording = false
    /// True once a Control, Option or Command combination went down while the
    /// field was listening and no key has arrived since. If the modifiers then
    /// come all the way back up with nothing in between, the key never reached
    /// us: something upstream consumed it.
    private var awaitingKeyForHeldModifiers = false
    private var observers: [NSObjectProtocol] = []
    private var isHovered = false

    override var acceptsFirstResponder: Bool { true }

    override var isEnabled: Bool {
        didSet {
            needsDisplay = true
            // A recorder switched off while listening must stop capturing
            // keys: the field is read-only, so it cannot finish the recording.
            // Deferred because this runs from `updateNSView`, and stopping
            // reports the change back through `recordingChanged`.
            if !isEnabled, isRecording {
                DispatchQueue.main.async { [weak self] in self?.stopRecording() }
            }
        }
    }

    /// Casco do botão de ação neutra (spec §7): raio de controle, fundo
    /// `surface.inset`, hover e pressionado em `selection.bg`, desabilitado a
    /// 50%, e anel `focus.ring` de 2 pt com 1 pt de respiro. O texto segue por
    /// `super.draw` com a cor `fg.primary` definida em `refreshTitle`.
    override func draw(_ dirtyRect: NSRect) {
        let radius = HexaTheme.Radius.control
        let context = NSGraphicsContext.current?.cgContext
        context?.saveGState()
        defer { context?.restoreGState() }

        let pressed = isEnabled && isHighlighted
        let hovered = isEnabled && isHovered && !pressed
        let enabledAlpha: CGFloat = isEnabled ? 1 : 0.5
        // O hover só clareia o fundo (selection.bg a 70%), como o `.opacity`
        // do HexaActionButtonStyle; o texto fica no alfa normal.
        context?.setAlpha(hovered ? 0.7 : enabledAlpha)
        if pressed || hovered {
            HexaTheme.selectionBgNSColor.setFill()
        } else {
            HexaTheme.surfaceInsetNSColor.setFill()
        }
        NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()

        context?.setAlpha(enabledAlpha)
        super.draw(dirtyRect)

        if isEnabled, window?.firstResponder === self {
            context?.setAlpha(1)
            let ring = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2),
                                    xRadius: radius - 1, yRadius: radius - 1)
            ring.lineWidth = 2
            HexaTheme.focusRingNSColor.setStroke()
            ring.stroke()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }

    override func highlight(_ flag: Bool) {
        super.highlight(flag)
        needsDisplay = true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        guard isRecording else { return }
        // Last resort. Leaving the app's shortcuts suspended, or the
        // recording tap eating the keyboard, would be worse than the bug
        // this fixes, so give both back even from here.
        if Thread.isMainThread {
            ShortcutRecordingTap.end()
            ShortcutCapture.end()
        } else {
            DispatchQueue.main.async {
                ShortcutRecordingTap.end()
                ShortcutCapture.end()
            }
        }
    }

    @objc func beginRecording() {
        guard isEnabled, !isRecording else { return }
        // Take the keyboard first: a field that believes it is listening while
        // some other view holds the keys would suspend the app's shortcuts and
        // never see the press that gives them back.
        if window?.firstResponder !== self {
            guard window?.makeFirstResponder(self) == true else { return }
        }
        isRecording = true
        awaitingKeyForHeldModifiers = false
        modifierRecording = ModifierShortcutRecording()
        ShortcutCapture.begin()
        // The tap keeps the typed combination to the field: without it, a
        // combination the system or another app answers to performs that
        // action while being recorded. When the tap cannot exist (no
        // Accessibility), the view events below still record as before.
        ShortcutRecordingTap.begin { [weak self] keyCode, modifiers, flags in
            guard let self, self.isRecording else { return }
            self.handleRecordingKey(keyCode: keyCode, modifiers: modifiers, flags: flags)
        }
        observeExits()
        refreshTitle()
        recordingChanged?(true)
    }

    /// Every route out of recording lands here, and it is safe to call when
    /// nothing is being recorded.
    func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        awaitingKeyForHeldModifiers = false
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
        ShortcutRecordingTap.end()
        ShortcutCapture.end()
        refreshTitle()
        recordingChanged?(false)
    }

    /// Combinations built with Control, Option or Command are offered to the
    /// view hierarchy before the app's own menu, so this is where nearly every
    /// recordable press arrives. Without it the menu answered first and the
    /// app closed its window on Command W or quit on Command Q instead of
    /// recording them.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording, window?.firstResponder === self else {
            return super.performKeyEquivalent(with: event)
        }
        handleRecordingKey(event)
        return true
    }

    /// Keys with no Control, Option or Command never reach the key equivalent
    /// path, so Escape, Delete and plain keys land here.
    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        handleRecordingKey(event)
    }

    override func flagsChanged(with event: NSEvent) {
        guard isRecording else {
            super.flagsChanged(with: event)
            return
        }
        let modifiers = GlobalShortcutModifiers(eventFlags: event.modifierFlags)
        if let captureModifiersAction {
            let unsupported = event.modifierFlags.contains(.function)
            let captured = modifierRecording.flagsChanged(modifiers, hasUnsupportedModifier: unsupported)
            if unsupported {
                invalidAction?()
                return
            }
            if let captured {
                guard captured.hasPrimaryModifier else {
                    invalidAction?()
                    return
                }
                stopRecording()
                captureModifiersAction(captured)
            }
            return
        }
        if modifiers.hasPrimaryModifier {
            awaitingKeyForHeldModifiers = true
        } else if modifiers.isEmpty, awaitingKeyForHeldModifiers {
            awaitingKeyForHeldModifiers = false
            notCapturedAction?()
        }
    }

    override func becomeFirstResponder() -> Bool {
        needsDisplay = true
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        stopRecording()
        needsDisplay = true
        return super.resignFirstResponder()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { stopRecording() }
    }

    private func handleRecordingKey(_ event: NSEvent) {
        handleRecordingKey(keyCode: Int64(event.keyCode),
                           modifiers: GlobalShortcutModifiers(eventFlags: event.modifierFlags),
                           flags: CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue)))
    }

    /// The one recording path, fed by the swallowing tap or, without it, by
    /// the view events above.
    private func handleRecordingKey(keyCode: Int64, modifiers: GlobalShortcutModifiers,
                                    flags: CGEventFlags) {
        // A key arrived, so the modifiers being held did produce something.
        awaitingKeyForHeldModifiers = false
        modifierRecording.keyPressed()

        if keyCode == Int64(kVK_Escape), !modifiers.hasPrimaryModifier {
            stopRecording()
            return
        }
        if GlobalShortcut.clearsShortcut(keyCode: keyCode, modifiers: modifiers) {
            guard let clearAction else { return }
            stopRecording()
            clearAction()
            return
        }
        let captured = GlobalShortcut(keyCode: keyCode, modifiers: modifiers)
        // Fn on a letter cannot be represented by the saved shortcut. Do not
        // silently record N when the user pressed Fn-N. Function/navigation
        // keys carry this flag intrinsically and remain recordable.
        if !requiresModifier, flags.contains(.maskSecondaryFn),
           !captured.syntheticEventFlags.contains(.maskSecondaryFn) {
            invalidAction?()
            return
        }
        guard requiresModifier ? captured.isValid : captured.hasPrintableKey else {
            NSSound.beep()
            invalidAction?()
            return
        }
        shortcut = captured
        stopRecording()
        if let captureWithFlagsAction {
            captureWithFlagsAction(captured, flags)
        } else {
            captureAction?(captured)
        }
    }

    /// Watchers that exist only while the field is listening. Each one is a
    /// way out of recording that no key press would announce.
    private func observeExits() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSApplication.didResignActiveNotification,
                                            object: nil, queue: .main) { [weak self] _ in
            self?.stopRecording()
        })
        if let window {
            observers.append(center.addObserver(forName: NSWindow.willCloseNotification,
                                                object: window, queue: .main) { [weak self] _ in
                self?.stopRecording()
            })
        }
    }

    func refreshTitle() {
        let text = isRecording ? waitingTitle : (emptyTitle ?? shortcut.displayString)
        // Cor e fonte do texto vêm dos tokens, não do tema do controle nativo.
        attributedTitle = NSAttributedString(string: text, attributes: [
            .font: font ?? HexaTheme.manropeFont(size: 12, weight: .medium),
            .foregroundColor: HexaTheme.fgPrimaryNSColor,
        ])
    }
}

struct ShortcutPreferenceRow: View {
    @ObservedObject private var l10n = L10n.shared

    private let role: GlobalShortcutRole
    private let isEnabled: Bool
    private let label: String?
    private let symbolName: String?
    private let contextLabel: String?
    private let statusText: String?
    private let statusIsActive: Bool
    private let reservesClearButtonSpace: Bool
    private let onChange: () -> Void
    @AppStorage private var rawValue: String
    @State private var errorText: String?
    @State private var isRecording = false
    @State private var pendingTakeOver: GlobalShortcut?

    init(role: GlobalShortcutRole,
         isEnabled: Bool = true,
         label: String? = nil,
         symbolName: String? = nil,
         contextLabel: String? = nil,
         statusText: String? = nil,
         statusIsActive: Bool = false,
         reservesClearButtonSpace: Bool = false,
         onChange: @escaping () -> Void) {
        self.role = role
        self.isEnabled = isEnabled
        self.label = label
        self.symbolName = symbolName
        self.contextLabel = contextLabel
        self.statusText = statusText
        self.statusIsActive = statusIsActive
        self.reservesClearButtonSpace = reservesClearButtonSpace
        self.onChange = onChange
        _rawValue = AppStorage(wrappedValue: role.defaultShortcut.storageValue, role.storageKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            HStack(alignment: .top, spacing: HexaTheme.Spacing.s) {
                ShortcutRowLabel(title: label ?? l10n.s.shelfHotkeyLabel,
                                 symbolName: symbolName,
                                 contextLabel: contextLabel,
                                 statusText: statusText,
                                 statusIsActive: statusIsActive)
                Spacer()
                VStack(alignment: .trailing, spacing: HexaTheme.Spacing.xs) {
                    HStack(spacing: HexaTheme.Spacing.s) {
                        ShortcutRecorderButton(shortcut: pendingTakeOver ?? shortcut,
                                               isEnabled: isEnabled,
                                               waitingTitle: l10n.s.shortcutPressKeys,
                                               notCapturedAction: { errorText = l10n.s.shortcutNotCaptured },
                                               recordingChanged: { recording in
                                                   isRecording = recording
                                                   if recording {
                                                       errorText = nil
                                                       pendingTakeOver = nil
                                                   }
                                               },
                                               invalidAction: {
                                                   errorText = l10n.s.shortcutInvalid
                                               },
                                               captureAction: save)
                            .frame(width: 108)
                            .disabled(!isEnabled)
                        if reservesClearButtonSpace {
                            // Rows beside it have a clear button here; keep the
                            // recorders in one column.
                            HexaIcons.image("xmark.circle.fill")
                                .hidden()
                                .accessibilityHidden(true)
                        }
                        Button(l10n.s.shortcutReset) {
                            rawValue = role.defaultShortcut.storageValue
                            errorText = nil
                            pendingTakeOver = nil
                            SystemShortcutTakeover.setTakeOver(role.storageKey, false)
                            onChange()
                        }
                        .buttonStyle(HexaActionButtonStyle())
                        .disabled(!isEnabled || shortcut == role.defaultShortcut)
                    }
                }
            }

            if let errorText {
                HexaStatusNote(message: errorText)
            } else if isRecording {
                Text(ShortcutRecordingCaption.text(l10n.s, canClear: false))
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
            if let pendingTakeOver {
                SystemShortcutTakeOverOffer(shortcut: pendingTakeOver,
                                            onAccept: {
                                                rawValue = pendingTakeOver.storageValue
                                                SystemShortcutTakeover.setTakeOver(role.storageKey, true)
                                                self.pendingTakeOver = nil
                                                onChange()
                                            },
                                            onDismiss: {
                                                self.pendingTakeOver = nil
                                                errorText = String(format: l10n.s.shortcutConflictFormat, "macOS")
                                            })
            }
        }
        .onChange(of: l10n.language) { _, _ in errorText = nil }
    }

    private var shortcut: GlobalShortcut {
        GlobalShortcut(storageValue: rawValue) ?? role.defaultShortcut
    }

    private func save(_ shortcut: GlobalShortcut) {
        // Another live role already answering to this exact combination is
        // the one conflict this row can name itself; the system's own take
        // overs go through the offer below.
        var conflictRole: GlobalShortcutRole?
        for other in GlobalShortcutRole.allCases
        where other != role && other.feature.isAvailable
            && other.savedShortcut == shortcut {
            conflictRole = other
            break
        }
        if let conflict = conflictRole {
            errorText = String(format: l10n.s.shortcutConflictFormat, conflict.title(l10n.s))
            return
        }
        // Nothing claims this row's key, so accepting an offer would write an
        // opt-in no feature ever resolves: refuse the combination the way the
        // row did before the take-over existed. The live table alone is the
        // right question here, and its blindness to a key already switched off
        // is what still lets the switcher's rows record the ids its own
        // take-over toggle is holding.
        if !role.supportsTakeOver, shortcut.conflictsWithSystemShortcut(for: role) {
            errorText = String(format: l10n.s.shortcutConflictFormat, "macOS")
            return
        }
        // The offer is the last word on a combination: every other check has
        // already passed, so accepting it writes exactly what a save writes.
        switch SystemShortcutTakeoverSupport.recorderDecision(
            shortcut: shortcut,
            conflictsWithMacOS: role.supportsTakeOver
                && SystemShortcutTakeover.conflictsWithMacOS(shortcut, for: role),
            takenOver: SystemShortcutTakeover.isTakenOver(role.storageKey),
            current: GlobalShortcut(storageValue: rawValue)) {
        case .offer:
            pendingTakeOver = shortcut
            errorText = nil
            return
        case .save(let clearTakeOver):
            rawValue = shortcut.storageValue
            errorText = nil
            if clearTakeOver { SystemShortcutTakeover.setTakeOver(role.storageKey, false) }
        }
        onChange()
    }
}

struct ShortcutRowLabel: View {
    let title: String
    let symbolName: String?
    let contextLabel: String?
    let statusText: String?
    let statusIsActive: Bool

    var body: some View {
        HStack(alignment: .top, spacing: HexaTheme.Spacing.s) {
            if let symbolName {
                HexaIcons.image(symbolName)
                    .foregroundStyle(HexaTheme.fgPrimary)
                    .frame(width: 18)
            }
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                Text(title)
                if contextLabel != nil || statusText != nil {
                    HStack(spacing: HexaTheme.Spacing.xs) {
                        if let contextLabel {
                            Text(contextLabel)
                        }
                        if contextLabel != nil, statusText != nil {
                            Text("•")
                        }
                        if let statusText {
                            HexaStateTag(statusText, kind: statusIsActive ? .ok : .neutral)
                        }
                    }
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                }
            }
        }
    }
}

// MARK: - Recording support

/// Keeps a recorded combination inside the field: a local monitor swallows
/// the keys the recording view answers to, so neither the app's menu (the
/// view's `performKeyEquivalent` already outranks it) nor another app
/// surface acts on them while the tap is up.
enum ShortcutRecordingTap {
    private static var monitor: Any?
    private static var handler: ((Int64, GlobalShortcutModifiers, CGEventFlags) -> Void)?

    static func begin(_ keyHandler: @escaping (Int64, GlobalShortcutModifiers, CGEventFlags) -> Void) {
        end()
        handler = keyHandler
        monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .flagsChanged, .keyUp]) { event in
            guard let handler else { return event }
            switch event.type {
            case .keyDown:
                handler(Int64(event.keyCode),
                        GlobalShortcutModifiers(eventFlags: event.modifierFlags),
                        CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue)))
                return nil
            case .flagsChanged:
                // The view's own `flagsChanged` handles modifier-only paths;
                // the monitor only keeps the event from leaking further.
                return event
            default:
                return event
            }
        }
    }

    static func end() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        handler = nil
    }
}
