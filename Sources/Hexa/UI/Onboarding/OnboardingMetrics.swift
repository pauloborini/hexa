// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Tokens de layout e métricas para a experiência de boas-vindas widescreen (DEC-017, DEC-037).
enum OnboardingMetrics {
    static let zero: CGFloat = 0
    static let windowWidth: CGFloat = 880
    static let windowHeight: CGFloat = 600
    static let stageWidth: CGFloat = 299
    static let contentWidth: CGFloat = FeatureWorkspaceMetrics.scaffoldWidth
    static let stageLogoSize: CGFloat = 48
    static let stageWordmarkSize: CGFloat = 20
    static let heroIconBoxSize: CGFloat = 36
    static let stepCircleSize: CGFloat = 24
    static let stepIndicatorSize: CGFloat = 6
    static let moduleIconBoxSize: CGFloat = 28
    static let cardMinHeight: CGFloat = 64
    static let stepSpring = Animation.spring(response: 0.4, dampingFraction: 0.85)
    static let smoothEase = Animation.easeInOut(duration: 0.25)
}
