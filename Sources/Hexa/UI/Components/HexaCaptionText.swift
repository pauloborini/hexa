// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Legenda de apoio multi-linha solta dentro de `HexaSection` (fora de
/// `SettingsRow`, que tem slot próprio). Anatomia canônica: fonte `label`,
/// cor `fgSecondary` e quebra vertical livre (`fixedSize` horizontal falso,
/// vertical verdadeiro). Inset de alinhamento com o texto da row
/// (`settingsRowTextInset`) e condição de exibição ficam no call site.
extension Text {
    /// Aplica a anatomia canônica de legenda de seção.
    func hexaCaption() -> some View {
        self
            .font(.hexa(.label))
            .foregroundStyle(HexaTheme.fgSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
