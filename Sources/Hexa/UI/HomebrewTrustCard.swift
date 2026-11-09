// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import SwiftUI

/// Asks once for a Homebrew tap's trust before an operation can reach it.
/// Homebrew refuses untapped repositories until the user approves them, so
/// the operation reports the tap here instead of failing blind.
struct HomebrewTrustCard: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var homebrew = HomebrewManager.shared
    let tap: String
    var compact = false

    var body: some View {
        HexaSection(l10n.s.homebrewTrustTitle) {
            VStack(alignment: .leading, spacing: compact ? HexaTheme.Spacing.xs : HexaTheme.Spacing.s) {
                Text(String(format: l10n.s.homebrewTrustCaption, tap))
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    homebrew.trustTapAndContinue()
                } label: {
                    HStack(spacing: HexaTheme.Spacing.xs) {
                        if homebrew.isTrustingTap {
                            ProgressView()
                                .controlSize(.mini)
                        }
                        Text(l10n.s.homebrewTrustButton)
                    }
                }
                .buttonStyle(HexaActionButtonStyle())
                .controlSize(compact ? .small : .regular)
                .disabled(homebrew.isTrustingTap)
            }
        }
    }
}
