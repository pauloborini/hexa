// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Switch transversal: forma, posição, foco e estado independentes da cor.
struct HexaSwitchStyle: ToggleStyle {
    var activeTint = HexaTheme.fgPrimary
    @FocusState private var hasFocus: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            Capsule()
                .fill(configuration.isOn ? activeTint : HexaTheme.surfaceInset)
                .overlay { Capsule().strokeBorder(HexaTheme.focusRing, lineWidth: HexaTheme.hairline) }
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle().fill(configuration.isOn ? HexaTheme.surfaceBase : HexaTheme.fgSecondary)
                        .frame(width: HexaSwitchMetrics.knob, height: HexaSwitchMetrics.knob)
                        .padding(HexaSwitchMetrics.inset)
                }
                .frame(width: HexaSwitchMetrics.width, height: HexaSwitchMetrics.height)
                .opacity(isEnabled ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .focused($hasFocus)
        .overlay { if hasFocus { Capsule().strokeBorder(HexaTheme.focusRing, lineWidth: 2).padding(-1) } }
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }.toggleStyle(.switch)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: configuration.isOn)
    }
}
