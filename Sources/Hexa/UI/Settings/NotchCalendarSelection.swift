// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import EventKit
import SwiftUI

/// Per-calendar checkboxes, grouped by account like Calendar.app. Unchecked
/// calendars stay out of the Calendar section and the event countdown.
struct NotchCalendarSelection: View {
    @ObservedObject private var l10n = L10n.shared
    @State private var choices: [NotchCalendarChoice] = []
    /// Set once the first read has answered, so an empty answer (no access,
    /// no calendars) is told apart from a read still on its way.
    @State private var loaded = false
    @State private var excluded = NotchCalendarSupport.excludedCalendars()

    var body: some View {
        let groups = NotchCalendarSupport.grouped(choices)
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            if !loaded {
                HexaBusyState(variant: .compact, message: l10n.s.loadingMessage)
            } else if !groups.isEmpty {
                HairlineDivider()
                Text(FeatureStrings.notchCalendar(l10n.language).calendars).font(.hexa(.body))
                ForEach(groups, id: \.first?.sourceID) { group in
                    if let source = group.first?.source, !source.isEmpty {
                        Text(source).font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary).padding(.top, HexaTheme.Spacing.xs)
                    }
                    ForEach(group) { choice in
                        Toggle(isOn: shown(choice.id)) {
                            HStack(spacing: HexaTheme.Spacing.xs) {
                                Circle().fill(choice.color.color).frame(width: 8, height: 8)
                                Text(choice.title).lineLimit(1)
                            }
                        }
                        .toggleStyle(.checkbox)
                        .accessibilityLabel(choice.title)
                    }
                }
            }
        }
        .task { await reload() }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
            Task { await reload() }
        }
    }

    private func reload() async {
        choices = await NotchCalendarService.shared.calendarChoices()
        loaded = true
    }

    private func shown(_ identifier: String) -> Binding<Bool> {
        Binding(get: { !excluded.contains(identifier) }, set: { shown in
            NotchCalendarSupport.setCalendar(identifier, shown: shown)
            excluded = NotchCalendarSupport.excludedCalendars()
            NotchCalendarService.shared.syncWithPreferences()
        })
    }
}
