// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit

/// Formats and copies the color of a pixel from the shared capture surface.
/// The capture loupe's readout bar shows exactly what a copy will put on the
/// pasteboard, in the configured format.
final class ColorSamplerService: ObservableObject {
    static let shared = ColorSamplerService()

    private init() {}

    /// The string the configured copy format would produce for this color,
    /// so a preview (the capture loupe's readout bar) can show exactly what
    /// a copy will put on the pasteboard.
    func formattedValue(_ color: NSColor) -> String? {
        guard let srgb = color.usingColorSpace(.sRGB) else { return nil }
        let format = ColorCopyFormat.sanitized(
            UserDefaults.standard.string(forKey: DefaultsKey.colorPickerFormat) ?? "hex"
        )
        return ColorValue.string(red: srgb.redComponent,
                                 green: srgb.greenComponent,
                                 blue: srgb.blueComponent,
                                 format: format,
                                 bareHex: UserDefaults.standard.bool(forKey: DefaultsKey.colorPickerBareHex))
    }

    /// Copies without the HUD. The capture surface calls this while its
    /// shielding-level panels are still up, where the HUD would be invisible,
    /// and shows its own confirmation instead.
    @discardableResult
    func copyQuietly(_ color: NSColor) -> String? {
        guard let value = formattedValue(color) else { return nil }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        return value
    }
}
