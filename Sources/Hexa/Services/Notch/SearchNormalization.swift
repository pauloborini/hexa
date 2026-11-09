// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Foundation

/// Search normalization shared by the island's section search and the
/// settings' layout editor.
enum CommandBarSearch {
    /// Case, accent and width differences never matter. Folded without a
    /// locale on purpose: Turkish lowercases a capital I to a dotless one, so
    /// a locale-aware fold would stop "insta" from finding a title that begins
    /// with that letter on a Mac set to Turkish.
    static func normalized(_ value: String) -> String {
        let folded = strippingInvisibles(value)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                     locale: nil)
            .lowercased()
        // Splitting on any whitespace — not just the ASCII space — treats the
        // full-width space (U+3000) that some input methods produce the same
        // as the half-width one, so "bd　123" folds like "bd 123".
        return folded.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Drops the characters that take up no space and that nobody can type:
    /// direction marks, zero-width joiners, soft hyphens. At least one widely
    /// installed app carries a left-to-right mark in front of its name, and a
    /// single invisible character was enough to stop the app from being an
    /// exact match for its own name and sink it below everything else.
    private static func strippingInvisibles(_ value: String) -> String {
        guard value.unicodeScalars.contains(where: isInvisible) else { return value }
        return String(String.UnicodeScalarView(value.unicodeScalars.filter { !isInvisible($0) }))
    }

    /// Every format character sits above this point, so plain text never pays
    /// for the lookup.
    private static func isInvisible(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value >= 0x00AD && scalar.properties.generalCategory == .format
    }
}
