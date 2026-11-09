// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import SwiftUI

/// The "Until…" chip beside the duration chips. It opens hour and minute
/// wheels (scroll, click a neighbour, or arrow keys) plus a field to type an
/// exact time, and starts the session from the popover. While that session
/// runs the chip shows its end time, and a click stops it like any chip.
struct KeepAwakeEndTimePicker: View {
    @ObservedObject private var l10n = L10n.shared
    @Binding var selection: Date
    /// The end of a running "until" session, shown on the highlighted chip.
    var activeEnd: Date?
    var onStop: () -> Void
    var onStart: () -> Void
    @State private var isPresented = false

    /// A time with the widest hour, so the reserved width fits any end time.
    private static let widestTime = Calendar.current.date(bySettingHour: 22, minute: 22, second: 0, of: Date()) ?? Date()

    var body: some View {
        Button {
            if activeEnd != nil { onStop() } else { isPresented.toggle() }
        } label: {
            HStack(spacing: HexaTheme.Spacing.xs) {
                HexaIcons.image("clock")
                // Both labels hold their width, so starting or stopping never
                // resizes the chip and moves the row between one and two lines.
                ZStack {
                    Text(l10n.s.keepAwakeUntilLabel + "…")
                        .opacity(activeEnd == nil ? 1 : 0)
                    Text(activeEnd ?? Self.widestTime, style: .time)
                        .opacity(activeEnd == nil ? 0 : 1)
                }
            }
        }
        .buttonStyle(KeepAwakeChipStyle(isSelected: activeEnd != nil))
        .accessibilityAddTraits(activeEnd != nil ? .isSelected : [])
        .fixedSize()
        .accessibilityLabel(l10n.s.keepAwakeUntilLabel)
        .accessibilityValue(activeEnd.map { $0.formatted(date: .omitted, time: .shortened) } ?? "")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            editor
        }
    }

    private var editor: some View {
        VStack(spacing: HexaTheme.Spacing.s) {
            HStack {
                Text(l10n.s.keepAwakeUntilLabel)
                    .font(.hexa(.label))
                Spacer()
                DatePicker(l10n.s.keepAwakeUntilLabel, selection: $selection,
                           displayedComponents: .hourAndMinute)
                    .datePickerStyle(.field)
                    .controlSize(.small)
                    .labelsHidden()
                    .fixedSize()
            }

            HStack(spacing: HexaTheme.Spacing.xs) {
                TimeDigitWheel(title: labels.hour, range: 24, value: part(.hour))
                Text(":")
                    .font(.hexa(.display(24)))
                    .foregroundStyle(HexaTheme.fgTertiary)
                TimeDigitWheel(title: labels.minute, range: 60, value: part(.minute))
            }

            HairlineDivider()
            HStack {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Text(endSummary(now: context.date))
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgSecondary)
                }
                Spacer()
                Button(l10n.s.keepAwakeUntilStart) {
                    isPresented = false
                    onStart()
                }
                .buttonStyle(HexaActionButtonStyle())
                .controlSize(.small)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(HexaTheme.Spacing.s)
        .frame(width: 224)
    }

    private func part(_ component: Calendar.Component) -> Binding<Int> {
        Binding(
            get: { Calendar.current.component(component, from: selection) },
            set: { value in
                // Edit on a neutral date: the session resolves the next
                // occurrence at activation, including a DST transition.
                var parts = Calendar.current.dateComponents([.hour, .minute], from: selection)
                parts.setValue(value, for: component)
                parts.year = 2001
                parts.month = 1
                parts.day = 15
                if let date = Calendar.current.date(from: parts) { selection = date }
            }
        )
    }

    private func endSummary(now: Date) -> String {
        let end = KeepAwakeAutomationSupport.resolvedUntilDate(picked: selection, now: now)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: l10n.language.rawValue)
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        let left = DateComponentsFormatter()
        left.calendar = { var c = Calendar.current; c.locale = formatter.locale; return c }()
        left.unitsStyle = .abbreviated
        left.allowedUnits = [.hour, .minute]
        let remaining = left.string(from: max(60, end.timeIntervalSince(now))) ?? ""
        return "\(formatter.string(from: end)) · \(remaining)"
    }

    private var labels: (hour: String, minute: String) {
        switch l10n.language {
        case .enUS: return ("Hour (0–23)", "Minute")
        case .ptBR: return ("Hora (0–23)", "Minuto")
        case .tr: return ("Saat (0–23)", "Dakika")
        case .ru: return ("Час (0–23)", "Минута")
        case .es: return ("Hora (0–23)", "Minuto")
        case .sk: return ("Hodina (0–23)", "Minúta")
        case .de: return ("Stunde (0–23)", "Minute")
        case .fr: return ("Heure (0–23)", "Minute")
        case .it: return ("Ora (0–23)", "Minuto")
        case .ja: return ("時 (0–23)", "分")
        case .ko: return ("시 (0–23)", "분")
        case .uk: return ("Година (0–23)", "Хвилина")
        case .zhHans: return ("小时 (0–23)", "分钟")
        case .zhTW, .zhHK: return ("小時 (0–23)", "分鐘")
        }
    }
}

/// One scrollable two-digit column: the current value with its neighbours
/// above and below. Scrolling, clicking a neighbour, or the arrow keys step
/// it, wrapping at the ends.
private struct TimeDigitWheel: View {
    let title: String
    let range: Int
    @Binding var value: Int
    @FocusState private var isFocused: Bool
    @State private var hovering = false
    @State private var monitor: Any?
    @State private var accumulated: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            neighbour(-1)
            Text(String(format: "%02d", value))
                .font(.hexa(.display(26)))
                .monospacedDigit()
                .foregroundStyle(HexaTheme.fgPrimary)
                .frame(width: 52, height: 36)
                .background(RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                    .fill(HexaTheme.selectionBg))
                .overlay {
                    if isFocused {
                        RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                            .strokeBorder(HexaTheme.focusRing, lineWidth: 2)
                    }
                }
            neighbour(1)
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .focusable()
        .focused($isFocused)
        .onKeyPress(.upArrow) { step(-1); return .handled }
        .onKeyPress(.downArrow) { step(1); return .handled }
        .onAppear(perform: installMonitor)
        .onDisappear {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityValue(String(format: "%02d", value))
        .accessibilityAdjustableAction { direction in
            step(direction == .increment ? 1 : -1)
        }
    }

    private func neighbour(_ offset: Int) -> some View {
        Text(String(format: "%02d", wrapped(value + offset)))
            .font(.hexa(.label))
            .monospacedDigit()
            .foregroundStyle(HexaTheme.fgSecondary)
            .frame(width: 52, height: 20)
            .contentShape(Rectangle())
            .onTapGesture { step(offset) }
    }

    private func step(_ delta: Int) {
        value = wrapped(value + delta)
    }

    private func wrapped(_ n: Int) -> Int {
        (n % range + range) % range
    }

    private func installMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            guard hovering else { return event }
            // Momentum is ignored so a flick stops where the finger lifts.
            guard event.momentumPhase.isEmpty else { return nil }
            // Trackpads report fine deltas; a mouse wheel reports whole notches.
            let threshold: CGFloat = event.hasPreciseScrollingDeltas ? 8 : 1
            accumulated += event.scrollingDeltaY
            while abs(accumulated) >= threshold {
                // Content follows the finger, as in a scroll view: moving it up
                // brings the next (larger) value into the middle.
                step(accumulated < 0 ? 1 : -1)
                accumulated += accumulated < 0 ? threshold : -threshold
            }
            return nil
        }
    }
}
