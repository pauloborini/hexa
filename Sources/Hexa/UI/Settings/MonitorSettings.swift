// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import SwiftUI

/// The "Monitor" settings page: telemetry readings, update intervals, temperature
/// units, memory display metrics, and graph scaling.
struct MonitorSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared

    @AppStorage(DefaultsKey.monitorInterval) private var interval = 2
    @AppStorage(DefaultsKey.monitorGraphScale) private var graphScale = true
    @AppStorage(DefaultsKey.temperatureUnit) private var temperatureUnit = TemperatureUnit.celsius.rawValue
    @AppStorage(DefaultsKey.monitorMemoryMetric) private var memoryMetric = "used"
    let embedded: Bool

    init(embedded: Bool = false) {
        self.embedded = embedded
    }

    var body: some View {
        Group {
            if embedded {
                content
            } else {
                HexaScreenScaffold(
                    title: l10n.s.tabMonitor,
                    subtitle: FeatureStrings.settingsPages(l10n.language).monitorDescription,
                    scrolls: false
                ) {
                    content
                }
            }
        }
        .toggleStyle(.switch)
        .onAppear {
            interval = Defaults.sanitizedMonitorInterval(interval)
            if TemperatureUnit(rawValue: temperatureUnit) == nil {
                temperatureUnit = TemperatureUnit.celsius.rawValue
            }
            memoryMetric = Defaults.sanitizedMonitorMemoryMetric(memoryMetric)
        }
    }

    private var content: some View {
        OverlayScrollView {
            VStack(alignment: .leading,
                   spacing: embedded ? HexaTheme.Spacing.l : HexaTheme.Spacing.xl) {
                readingsCard
                graphsCard
            }
            .padding(.horizontal, HexaTheme.Spacing.xxl)
            .padding(.bottom, HexaTheme.Spacing.pageGap)
        }
    }

    private var readingsCard: some View {
        HexaSection(FeatureStrings.monitorLayout(l10n.language).shared) {
            SettingsChoiceRow(
                symbol: "timer",
                title: l10n.s.monitorIntervalLabel,
                selection: Binding(
                    get: { Defaults.sanitizedMonitorInterval(interval) },
                    set: { interval = $0 }
                ),
                options: [(1, l10n.s.monitorInterval1), (2, l10n.s.monitorInterval2), (5, l10n.s.monitorInterval5)]
            )
            SettingsRow(symbol: "thermometer.medium", title: l10n.s.temperatures) {
                Picker(l10n.s.temperatures, selection: $temperatureUnit) {
                    Text("°C").tag(TemperatureUnit.celsius.rawValue)
                    Text("°F").tag(TemperatureUnit.fahrenheit.rawValue)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            if AppFeature.monitorMemory.isAvailable {
                SettingsRow(symbol: "memorychip", title: l10n.s.monitorMemoryMetricLabel) {
                    Picker(l10n.s.monitorMemoryMetricLabel, selection: $memoryMetric) {
                        Text(l10n.s.memoryMetricUsed).tag("used")
                        Text(l10n.s.memoryMetricApp).tag("app")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
            }
        }
    }

    private var graphsCard: some View {
        HexaSection(GraphScaleStrings.localized(l10n.language).sectionTitle) {
            SettingsRow(symbol: "arrow.up.to.line", title: GraphScaleStrings.localized(l10n.language).title) {
                Toggle(GraphScaleStrings.localized(l10n.language).title, isOn: $graphScale).labelsHidden()
            }
        }
    }
}
