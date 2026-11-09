// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// Palco visual da lateral esquerda do Onboarding: apresenta a marca do hexa,
/// o wordmark e a linha do tempo do roteiro em 4 passos (DEC-011, DEC-017, DEC-037).
struct OnboardingStageView: View {
    @ObservedObject private var l10n = L10n.shared
    let currentStep: OnboardingStep

    var body: some View {
        VStack(spacing: HexaTheme.Spacing.l) {
            heroSection
                .padding(.top, HexaTheme.Spacing.xxl)

            Spacer()

            stepTimeline
                .padding(.horizontal, HexaTheme.Spacing.xl)

            Spacer()

            identityBadge
                .padding(.bottom, HexaTheme.Spacing.xl)
                .padding(.horizontal, HexaTheme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HexaTheme.surfaceInset)
        .font(.hexa(.body))
        .foregroundStyle(HexaTheme.fgPrimary)
    }

    private var strings: Strings { l10n.s }

    // MARK: - Hero & Identidade da Marca

    private var heroSection: some View {
        VStack(spacing: HexaTheme.Spacing.m) {
            BrandBadge(size: OnboardingMetrics.stageLogoSize)

            VStack(spacing: HexaTheme.Spacing.xs) {
                HexaTheme.wordmark(size: OnboardingMetrics.stageWordmarkSize)
                Text("\(strings.versionPrefix) \(AppInfo.version)")
                    .font(.hexa(.micro))
                    .foregroundStyle(HexaTheme.fgTertiary)
            }
        }
    }

    // MARK: - Linha do Tempo

    private var stepTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(OnboardingStep.allCases, id: \.self) { step in
                stepRow(step)
                if step != OnboardingStep.allCases.last {
                    stepConnector(for: step)
                }
            }
        }
    }

    private func stepRow(_ step: OnboardingStep) -> some View {
        let isCurrent = step == currentStep
        let isPast = step.rawValue < currentStep.rawValue

        return HStack(spacing: HexaTheme.Spacing.m) {
            ZStack {
                Circle()
                    .fill(isPast ? HexaTheme.accentSolid : (isCurrent ? HexaTheme.selectionBg : HexaTheme.surfaceRaised))
                    .frame(width: OnboardingMetrics.stepCircleSize, height: OnboardingMetrics.stepCircleSize)
                    .overlay {
                        Circle()
                            .strokeBorder(isCurrent ? HexaTheme.accentSolid : HexaTheme.borderHairline,
                                          lineWidth: isCurrent ? 1.5 : HexaTheme.hairline)
                    }

                if isPast {
                    HexaIcons.image("checkmark", size: HexaIconMetrics.small)
                        .foregroundStyle(HexaTheme.fgInverse)
                } else if isCurrent {
                    Circle()
                        .fill(HexaTheme.accentSolid)
                        .frame(width: OnboardingMetrics.stepIndicatorSize, height: OnboardingMetrics.stepIndicatorSize)
                } else {
                    Text("\(step.rawValue + 1)")
                        .font(.hexa(.micro))
                        .foregroundStyle(HexaTheme.fgTertiary)
                }
            }

            Text(stepTitle(for: step))
                .font(isCurrent ? .hexa(.heading) : .hexa(.label))
                .foregroundStyle(isCurrent ? HexaTheme.fgPrimary : (isPast ? HexaTheme.fgSecondary : HexaTheme.fgTertiary))
                .lineLimit(1)

            Spacer()
        }
        .frame(height: HexaTheme.Density.rowStandard)
    }

    private func stepConnector(for step: OnboardingStep) -> some View {
        let isPast = step.rawValue < currentStep.rawValue
        return Rectangle()
            .fill(isPast ? HexaTheme.accentSolid : HexaTheme.borderHairline)
            .frame(width: HexaTheme.hairline, height: HexaTheme.Spacing.m)
            .padding(.leading, (OnboardingMetrics.stepCircleSize - HexaTheme.hairline) / 2)
    }

    private func stepTitle(for step: OnboardingStep) -> String {
        switch step {
        case .welcome: return strings.obStepWelcomeTitle
        case .modules: return strings.obStepModulesTitle
        case .permissions: return strings.obStepPermissionsTitle
        case .done: return strings.obStepDoneTitle
        }
    }

    // MARK: - Rodapé de Identidade e Integridade

    private var identityBadge: some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            HexaIcons.image("shield-check", size: HexaIconMetrics.label)
                .foregroundStyle(HexaTheme.fgSecondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(AppInfo.name)
                    .font(.hexa(.micro))
                    .foregroundStyle(HexaTheme.fgPrimary)
                Text(AppInfo.copyright)
                    .font(.hexa(.micro))
                    .foregroundStyle(HexaTheme.fgTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, HexaTheme.Spacing.m)
        .padding(.vertical, HexaTheme.Spacing.s)
        .background(
            RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                .fill(HexaTheme.surfaceRaised)
        )
        .overlay {
            RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                .strokeBorder(HexaTheme.borderHairline, lineWidth: HexaTheme.hairline)
        }
    }
}
