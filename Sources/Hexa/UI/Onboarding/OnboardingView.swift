// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// A tela de boas-vindas do hexa: desenha o roteiro imersivo em janela widescreen
/// com palco de marca e conteúdo por passo (DEC-011, DEC-017, DEC-037).
/// Todo o estado vive no `OnboardingModel` e todo o texto vem de `L10n.shared`.
struct OnboardingView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject var model: OnboardingModel
    let onFinish: () -> Void

    var body: some View {
        HStack(spacing: OnboardingMetrics.zero) {
            OnboardingStageView(currentStep: model.step)
                .frame(width: OnboardingMetrics.stageWidth)
                .frame(maxHeight: .infinity)
                .overlay(alignment: .trailing) {
                    HairlineDivider(vertical: true)
                }

            HexaScreenScaffold(title: title, subtitle: subtitle, scrolls: false) {
                VStack(alignment: .leading, spacing: OnboardingMetrics.zero) {
                    OverlayScrollView {
                        stepContent
                            .transition(.opacity)
                            .id(model.step)
                            .padding(.horizontal, HexaTheme.Spacing.xxl)
                            .padding(.bottom, HexaTheme.Spacing.pageGap)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    buttons
                        .padding(.horizontal, HexaTheme.Spacing.xxl)
                        .padding(.bottom, HexaTheme.Spacing.l)
                }
            }
        }
        .background(HexaTheme.surfaceBase)
        .ignoresSafeArea(.container, edges: .top)
        .font(.hexa(.body))
        .animation(OnboardingMetrics.stepSpring, value: model.step)
    }

    // MARK: - Texto

    /// Resolvido a cada render, a partir do objeto observado: nenhuma cópia do
    /// catálogo fica guardada na tela.
    private var strings: Strings { l10n.s }

    private var title: String {
        switch model.step {
        case .welcome: strings.obStepWelcomeTitle
        case .modules: strings.obStepModulesTitle
        case .permissions: strings.obStepPermissionsTitle
        case .done: strings.obStepDoneTitle
        }
    }

    private var subtitle: String {
        switch model.step {
        case .welcome: strings.obStepWelcomeBody
        case .modules: strings.obStepModulesBody
        case .permissions: strings.obStepPermissionsBody
        case .done: strings.obStepDoneBody
        }
    }

    // MARK: - Conteúdo do passo

    @ViewBuilder
    private var stepContent: some View {
        switch model.step {
        case .welcome:
            welcomeContent
        case .modules:
            modulesContent
        case .permissions:
            OnboardingPermissionsStep(demandID: model.permissionDemandID)
        case .done:
            doneContent
        }
    }

    private var welcomeContent: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.l) {
            HStack(spacing: HexaTheme.Spacing.m) {
                BrandBadge(size: 56)
                HexaTheme.wordmark(size: 22)
            }
            HexaCard {
                bullet(icon: "cup.and.saucer",
                       title: strings.obWelcomeBullet1Title,
                       detail: strings.obWelcomeBullet1Body)
                HairlineDivider()
                bullet(icon: "gauge",
                       title: strings.obWelcomeBullet2Title,
                       detail: strings.obWelcomeBullet2Body)
                HairlineDivider()
                bullet(icon: "sparkles",
                       title: strings.obWelcomeBullet3Title,
                       detail: strings.obWelcomeBullet3Body)
            }
        }
    }

    /// Uma linha por grupo de módulo, na ordem do catálogo. A rolagem é da
    /// tela, não do cartão.
    private var modulesContent: some View {
        HexaCard {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                ForEach(OnboardingModule.allCases, id: \.self) { group in
                    OnboardingModuleRow(group: group)
                    if group != OnboardingModule.allCases.last {
                        HairlineDivider()
                    }
                }
            }
        }
    }

    private var doneContent: some View {
        HexaCard {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.m) {
                HStack(alignment: .top, spacing: HexaTheme.Spacing.m) {
                    HexaIcons.image("menubar.rectangle", size: HexaIconMetrics.standard)
                        .foregroundStyle(HexaTheme.fgPrimary)
                        .frame(width: OnboardingMetrics.heroIconBoxSize,
                               height: OnboardingMetrics.heroIconBoxSize)
                        .background(
                            RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                                .fill(HexaTheme.surfaceInset)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                                .strokeBorder(HexaTheme.borderHairline, lineWidth: HexaTheme.hairline)
                        )

                    VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                        Text(strings.obStepDoneTitle)
                            .font(.hexa(.heading))
                            .foregroundStyle(HexaTheme.fgPrimary)
                        Text(strings.obStepDoneBody)
                            .font(.hexa(.body))
                            .foregroundStyle(HexaTheme.fgSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HairlineDivider()

                HStack(alignment: .center, spacing: HexaTheme.Spacing.s) {
                    HexaIcons.image("info.circle", size: HexaIconMetrics.label)
                        .foregroundStyle(HexaTheme.fgSecondary)
                    Text(strings.obDoneHint)
                        .font(.hexa(.body))
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func bullet(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: HexaTheme.Spacing.m) {
            HexaIcons.image(icon, size: HexaIconMetrics.standard)
                .foregroundStyle(HexaTheme.fgPrimary)
                .frame(width: OnboardingMetrics.heroIconBoxSize,
                       height: OnboardingMetrics.heroIconBoxSize)
                .background(
                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                        .fill(HexaTheme.surfaceInset)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                        .strokeBorder(HexaTheme.borderHairline, lineWidth: HexaTheme.hairline)
                )

            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                Text(title)
                    .font(.hexa(.heading))
                    .foregroundStyle(HexaTheme.fgPrimary)
                Text(detail)
                    .font(.hexa(.body))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Ações e Controles

    private var buttons: some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            if model.step != .welcome {
                Button(action: { model.back() }) {
                    HStack(spacing: HexaTheme.Spacing.xs) {
                        HexaIcons.image("chevron.left", size: HexaIconMetrics.small)
                        Text(strings.obBack)
                    }
                }
                .buttonStyle(HexaActionButtonStyle())
                .keyboardShortcut(.cancelAction)
            }

            Spacer()

            stepIndicators

            Spacer()

            Button(action: {
                if model.step == .done {
                    onFinish()
                } else {
                    model.advance()
                }
            }) {
                HStack(spacing: HexaTheme.Spacing.xs) {
                    Text(model.step == .done ? strings.obFinish : strings.obContinue)
                    HexaIcons.image(model.step == .done ? "checkmark" : "chevron.right",
                                    size: HexaIconMetrics.small)
                }
            }
            .buttonStyle(HexaActionButtonStyle(variant: .primary))
            .keyboardShortcut(.defaultAction)
        }
    }

    private var stepIndicators: some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            ForEach(OnboardingStep.allCases, id: \.self) { step in
                Circle()
                    .fill(step == model.step ? HexaTheme.accentSolid : HexaTheme.borderHairline)
                    .frame(width: OnboardingMetrics.stepIndicatorSize,
                           height: OnboardingMetrics.stepIndicatorSize)
            }
        }
    }
}

/// O passo de permissões: uma linha do Portal por permissão exigida pelos
/// módulos marcados, com o pedido do macOS saindo só do botão do usuário.
private struct OnboardingPermissionsStep: View {
    let demandID: UUID
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var permissions = Permissions.shared
    @State private var automation: [Permissions.AutomationTarget: Permissions.AutomationStatus] = [:]
    /// Leitura de Automação em andamento: enquanto ela não volta, as linhas de Finder e Terminal
    /// leem como não verificáveis. O indicador avisa que a leitura está em curso.
    @State private var automationPending = false

    var body: some View {
        HexaCard {
            SectionLabel(hub.onboardingSelectedPermissionsTitle)
            if automationPending {
                HStack(spacing: HexaTheme.Spacing.s) {
                    ProgressView()
                        .controlSize(.small)
                    Text(strings.loadingMessage)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgSecondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(strings.loadingMessage)
            }
            if requiredPermissions.isEmpty {
                Text(hub.onboardingNoSelectedPermissions)
                    .font(.hexa(.body))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                    ForEach(requiredPermissions, id: \.self) { permission in
                        PermissionPortalRow(permission: permission,
                                            hub: hub,
                                            status: status(for: permission),
                                            finderAutomation: automation[.finder],
                                            terminalAutomation: automation[.terminal],
                                            refreshAutomation: readAutomation,
                                            usedByNames: usedByNames(for: permission))
                        if permission != requiredPermissions.last {
                            HairlineDivider()
                        }
                    }
                }

                if requiredPermissions.contains(where: { permission in status(for: permission) == .missing }) {
                    Text(strings.obPermissionPendingNote)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onAppear {
            permissions.refresh()
            permissions.setActivePermissionSurface(demandID, visible: true)
            readAutomationIfNeeded()
        }
        .onDisappear {
            permissions.setActivePermissionSurface(demandID, visible: false)
        }
    }

    private var strings: Strings { l10n.s }

    private var hub: FeatureHubStrings { FeatureStrings.hub(l10n.language) }

    private var installedFeatures: [AppFeature] {
        AppFeature.allCases.filter { feature in features.isAvailable(feature) }
    }

    private var requiredPermissions: [AppPermission] {
        OnboardingPermissionSet.required(for: installedFeatures)
    }

    private func status(for permission: AppPermission) -> PermissionPortalRow.Status {
        PermissionPortalRow.status(for: permission,
                                   readers: .live(finderAutomation: automation[.finder],
                                                  terminalAutomation: automation[.terminal]))
    }

    private func usedByNames(for permission: AppPermission) -> [String] {
        OnboardingPermissionSet.modulesRequiring(permission, in: installedFeatures)
            .map { module in module.title(l10n.language) }
    }

    private func readAutomationIfNeeded() {
        guard requiredPermissions.contains(.automationFinder)
            || requiredPermissions.contains(.automationTerminal) else { return }
        readAutomation()
    }

    private func readAutomation() {
        automationPending = true
        OnboardingPermissionSet.readAutomation { statuses in
            automation = statuses
            automationPending = false
        }
    }
}

/// A linha de um grupo de módulo: ícone dedicado, título, descrição, estado e switch.
private struct OnboardingModuleRow: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    let group: OnboardingModule

    private var total: Int { group.features.count }

    private var installed: Int {
        OnboardingModuleCatalog.installedCount(in: group, isAvailable: features.isAvailable)
    }

    private var isOn: Bool {
        OnboardingModuleCatalog.isInstalled(group, isAvailable: features.isAvailable)
    }

    private var isPartial: Bool {
        OnboardingModuleCatalog.isPartiallyInstalled(group, isAvailable: features.isAvailable)
    }

    var body: some View {
        HStack(alignment: .center, spacing: HexaTheme.Spacing.m) {
            HexaIcons.image(iconName, size: HexaIconMetrics.standard)
                .foregroundStyle(isOn ? HexaTheme.fgPrimary : HexaTheme.fgTertiary)
                .frame(width: OnboardingMetrics.moduleIconBoxSize,
                       height: OnboardingMetrics.moduleIconBoxSize)
                .background(
                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                        .fill(isOn ? HexaTheme.selectionBg : HexaTheme.surfaceInset)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control)
                        .strokeBorder(HexaTheme.borderHairline, lineWidth: HexaTheme.hairline)
                )

            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                Text(group.title(l10n.language))
                    .font(.hexa(.body))
                    .foregroundStyle(isOn ? HexaTheme.fgPrimary : HexaTheme.fgSecondary)
                Text(group.description(l10n.language))
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if isPartial {
                    HStack(spacing: HexaTheme.Spacing.s) {
                        Text("\(installed)/\(total)")
                            .font(.hexa(.data))
                            .foregroundStyle(HexaTheme.fgSecondary)
                        InstalledShareBar(installed: installed, total: total)
                            .controlSize(.small)
                    }
                }
            }
            Spacer(minLength: HexaTheme.Spacing.s)
            Toggle(group.title(l10n.language), isOn: installBinding)
                .labelsHidden()
                .toggleStyle(HexaSwitchStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var iconName: String {
        switch group {
        case .appUpdates: return "arrow.down.app"
        case .monitor: return "gauge"
        case .fanControl: return "fanblades.fill"
        case .uninstaller: return "trash"
        case .cleanerAndMaintenance: return "sparkles"
        case .mediaTools: return "photo.on.rectangle.angled"
        case .dynamicIsland: return "macbook"
        case .mixer: return "speaker.wave.2"
        case .keepAwake: return "cup.and.saucer"
        case .brightness: return "sun.max"
        case .killProcess: return "xmark.octagon"
        case .portManager: return "point.3.connected.trianglepath.dotted"
        case .dockDisplayLock: return "panel-bottom"
        case .menuBarHiding: return "menubar.dock.rectangle"
        case .screenCapture: return "camera.viewfinder"
        }
    }

    private var installBinding: Binding<Bool> {
        Binding(get: { isOn },
                set: { on in OnboardingModuleCatalog.setInstalled(group, on) })
    }
}
