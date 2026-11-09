// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// A compact label for one monitor item, checked and tinted while it is
/// shown. Labels fill their grid column so a group reads as one table. An item
/// with its own settings carries them in a second half that names what is on
/// and opens them, so they read as that item's and not the page's.
struct MonitorToken: View {
    let symbol: String
    let title: String
    @Binding var included: Bool
    var available = true
    var selected = false
    var options: AnyView? = nil
    var optionsSummary = ""
    /// Taller labels for the panel, whose items are whole blocks.
    var large = false
    /// Clicking the name does this instead of showing or hiding the item;
    /// the checkmark always shows or hides it.
    var select: (() -> Void)? = nil
    @State private var showsOptions = false
    @Environment(\.isEnabled) private var isEnabled

    private var on: Bool { included && available }

    var body: some View {
        // The summary shows only while it fits beside the name on one line;
        // otherwise the name may take two lines and the options keep a chevron.
        ViewThatFits(in: .horizontal) {
            row(showsSummary: true)
            row(showsSummary: false)
        }
        .font(.hexa(.body))
        .imageScale(large ? .large : .medium)
        .frame(maxWidth: .infinity, minHeight: large ? 40 : 28)
        .background(on ? HexaTheme.selectionBg : HexaTheme.surfaceInset,
                    in: RoundedRectangle(cornerRadius: large ? HexaTheme.Radius.panel : HexaTheme.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: large ? HexaTheme.Radius.panel : HexaTheme.Radius.control, style: .continuous)
                .strokeBorder(selected ? HexaTheme.accentSolid : .clear, lineWidth: 1)
        }
        .popover(isPresented: $showsOptions, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                Label(title, hexaIcon: symbol).font(.hexa(.heading))
                options
            }
            .padding(HexaTheme.Spacing.m)
            .frame(width: 250, alignment: .leading)
            .toggleStyle(.switch)
        }
        .opacity(available ? 1 : 0.5)
        .disabled(!available)
        .help(title)
    }

    private func activate() {
        guard available && isEnabled else { return }
        if let select { select() } else { included.toggle() }
    }

    private func row(showsSummary: Bool) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: HexaTheme.Spacing.xs) {
                Button { included.toggle() } label: {
                    HexaIcons.image(included ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(on ? HexaTheme.fgPrimary : HexaTheme.fgSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title)
                .accessibilityAddTraits(included ? .isSelected : [])
                Button(action: activate) {
                    Label(title, hexaIcon: symbol)
                        .lineLimit(showsSummary ? 1 : 2)
                        .minimumScaleFactor(showsSummary ? 1 : 0.8)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(on ? HexaTheme.fgPrimary : HexaTheme.fgSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHidden(select == nil)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
            .padding(.horizontal, HexaTheme.Spacing.s)
            .padding(.vertical, HexaTheme.Spacing.xs)
            .background {
                // The padding follows the name's action. Buttons above this
                // background keep their own clicks, including the checkmark.
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: activate)
            }
            if options != nil {
                HairlineDivider(vertical: true).frame(height: 14)
                Button { showsOptions = true } label: {
                    HStack(spacing: HexaTheme.Spacing.xs) {
                        if showsSummary {
                            Text(optionsSummary).lineLimit(1).fixedSize()
                        }
                        HexaIcons.image("chevron.down", size: 10).font(.hexa(.micro))
                    }
                    .foregroundStyle(on ? HexaTheme.fgPrimary : HexaTheme.fgSecondary)
                    .padding(.horizontal, HexaTheme.Spacing.s)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!on)
                .accessibilityLabel("\(title): \(optionsSummary)")
            }
        }
    }
}

/// One switch in an item's options.
struct MonitorTokenOption: View {
    let symbol: String
    let title: String
    var tint: Color? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            HexaIcons.image(symbol, size: 11)
                .font(.hexa(.label))
                .foregroundStyle(tint ?? HexaTheme.fgSecondary)
                .frame(width: 16)
            Text(title)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .controlSize(.small)
        }
    }
}

/// Wide enough for a label with its options half, so every label in a group
/// takes the same column width.
let monitorTokenColumns = [GridItem(.adaptive(minimum: 196), spacing: HexaTheme.Spacing.s)]

extension View {
    /// The inset box that holds one group of labels.
    func monitorTokenGroup() -> some View {
        padding(HexaTheme.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HexaTheme.surfaceInset, in: RoundedRectangle(cornerRadius: HexaTheme.Radius.panel, style: .continuous))
    }
}
