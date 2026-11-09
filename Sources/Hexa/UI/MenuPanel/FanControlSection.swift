// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import FanControlCore
import SwiftUI

struct FanControlSection: View {
    @Environment(\.featureWorkspacePresentation) private var featureWorkspacePresentation
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = FanControlService.shared
    @AppStorage(DefaultsKey.fanControlMode) private var modeRaw = FanControlMode.system.rawValue
    @AppStorage(DefaultsKey.fanControlCoolingLevel) private var coolingLevel =
        FanControlPolicy.defaultCoolingLevel
    @AppStorage(DefaultsKey.fanControlCurves) private var curvesStorage =
        FanControlConfiguration.defaultCurvesStorage
    @AppStorage(DefaultsKey.fanControlResume) private var resume = false
    @AppStorage(DefaultsKey.temperatureUnit) private var temperatureUnit =
        TemperatureUnit.celsius.rawValue
    @State private var leaseID = UUID()
    var collapsible = true
    var fallbackFanSpeeds: [Double] = []

    private var strings: FanControlFeatureStrings {
        FeatureStrings.fanControl(l10n.language)
    }

    var body: some View {
        Group {
            if featureWorkspacePresentation {
                HexaCard {
                    cardContent
                }
                .onAppear { service.panelDidAppear(id: leaseID) }
                .onDisappear { service.panelDidDisappear(id: leaseID) }
                .onChange(of: resume) { _, _ in service.resumePreferenceDidChange() }
            } else {
                PanelSection(.fanControl, title: strings.title, collapsible: collapsible) {
                    cardContent
                        .panelCard()
                        .onAppear { service.panelDidAppear(id: leaseID) }
                        .onDisappear { service.panelDidDisappear(id: leaseID) }
                        .onChange(of: resume) { _, _ in service.resumePreferenceDidChange() }
                }
            }
        }
    }

    private var cardContent: some View {
        FanControlCardContent(strings: strings,
                              snapshot: service.snapshot,
                              fallbackFanSpeeds: fallbackFanSpeeds,
                              accessState: service.accessState,
                              error: service.error,
                              isWorking: service.isWorking,
                              isAwaitingReading: service.isAwaitingFirstReading,
                              mode: modeBinding,
                              coolingLevel: $coolingLevel,
                              curves: curvesBinding,
                              resume: $resume,
                              temperatureUnit: displayTemperatureUnit,
                              authorize: service.authorize,
                              applyConfiguration: service.applyConfiguration,
                              stopCooling: service.returnToSystem)
    }

    private var modeBinding: Binding<FanControlMode> {
        Binding(
            get: { FanControlMode(rawValue: modeRaw) ?? .system },
            set: { modeRaw = $0.rawValue }
        )
    }

    private var curvesBinding: Binding<[FanControlCurve]> {
        Binding(
            get: {
                FanControlConfiguration.decodeCurves(curvesStorage)
                    ?? []
            },
            set: { curves in
                if let encoded = FanControlConfiguration.encodeCurves(curves) {
                    curvesStorage = encoded
                }
            }
        )
    }

    private var displayTemperatureUnit: TemperatureUnit {
        TemperatureUnit(rawValue: temperatureUnit) ?? .celsius
    }
}

struct FanControlCardContent: View {
    @Environment(\.featureWorkspacePresentation) private var featureWorkspacePresentation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let strings: FanControlFeatureStrings
    let snapshot: FanControlSnapshot
    let fallbackFanSpeeds: [Double]
    let accessState: FanControlService.AccessState
    let error: FanControlErrorCode?
    let isWorking: Bool
    let isAwaitingReading: Bool
    @Binding var mode: FanControlMode
    @Binding var coolingLevel: Int
    @Binding var curves: [FanControlCurve]
    @Binding var resume: Bool
    let temperatureUnit: TemperatureUnit
    let authorize: () -> Void
    let applyConfiguration: (FanControlConfiguration) -> Void
    let stopCooling: () -> Void

    var body: some View {
        if isAwaitingReading, fallbackFanSpeeds.isEmpty {
            HexaBusyState(variant: .compact, message: strings.readingFans)
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading,
               spacing: featureWorkspacePresentation ? HexaTheme.Spacing.l : HexaTheme.Spacing.s) {
            statusHeader

            if !fallbackFanSpeeds.isEmpty,
               snapshot.fans.isEmpty || error == .helperUnavailable {
                fallbackFanRows
            } else if !snapshot.fans.isEmpty {
                fanRows
            }

            if let message = stateMessage {
                Text(message)
                    .font(.hexa(.body))
                    .foregroundStyle(messageIsError ? HexaTheme.statusDanger
                                                    : snapshot.stopReason != nil || coolingUnverified
                                                        ? HexaTheme.statusWarning : HexaTheme.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if canConfigure {
                modePicker
                switch mode {
                case .system:
                    EmptyView()
                case .manual:
                    manualControl
                case .curve:
                    FanControlCurveEditor(strings: strings,
                                          curves: $curves,
                                          temperatures: snapshot.temperatures ?? [],
                                          temperatureUnit: temperatureUnit,
                                          disabled: isWorking)
                    if !FanControlPolicy.validCurves(curves) {
                        Text(strings.invalidCurve)
                            .font(.hexa(.body))
                            .foregroundStyle(HexaTheme.statusDanger)
                        Button(strings.resetCurve) { curves = [FanControlConfiguration.defaultCurve] }
                            .buttonStyle(HexaActionButtonStyle())
                            .disabled(isWorking)
                    } else if !curveCanRun {
                        Text(strings.curveUnavailable)
                            .font(.hexa(.body))
                            .foregroundStyle(HexaTheme.fgSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if hasPendingChanges {
                Text(strings.pendingChanges)
                    .font(.hexa(.body))
                    .foregroundStyle(HexaTheme.statusWarning)
            }
            action

            if canConfigure, mode != .system {
                Toggle(strings.resumeAfterRestart, isOn: $resume)
                    .font(.hexa(.body))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }

            if controlsCanAppear {
                Text(strings.safetyCaption)
                    .font(.hexa(.body))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(HexaTheme.accentSolid)
    }

    private var modePicker: some View {
        Picker(strings.mode, selection: $mode) {
            Text(strings.systemControl).tag(FanControlMode.system)
            Text(strings.manualControl).tag(FanControlMode.manual)
            Text(strings.customCurve).tag(FanControlMode.curve)
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
        .disabled(isWorking)
    }

    private var manualControl: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            HexaKeyValueRow(label: strings.coolingIntensity,
                            value: "\(selectedCoolingLevel)%")
            Slider(value: coolingLevelBinding,
                   in: Double(FanControlPolicy.minimumCoolingLevel)...Double(FanControlPolicy.maximumCoolingLevel),
                   step: Double(FanControlPolicy.coolingLevelStep))
                .controlSize(.small)
                .accessibilityLabel(strings.coolingIntensity)
                .accessibilityValue("\(selectedCoolingLevel)%")
                .disabled(isWorking)
        }
    }

    private var statusHeader: some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            HexaIcons.image(snapshot.isCooling ? "fanblades.fill" : "fanblades", size: 15)
                .font(.hexa(.heading))
                .foregroundStyle(snapshot.isCooling ? AnyShapeStyle(HexaTheme.statusOk)
                                                     : AnyShapeStyle(HexaTheme.fgSecondary))
                .opacity(snapshot.isCooling ? 1 : 0.8)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                Text(strings.title)
                    .font(.hexa(.body))
                Text(statusText)
                    .font(snapshot.isRecovering ? .hexa(.body) : .hexa(.data))
                    .foregroundStyle(snapshot.isRecovering ? HexaTheme.statusDanger : snapshot.isCooling ? HexaTheme.statusOk : HexaTheme.fgSecondary)
            }
            Spacer()
            if isWorking { ProgressView().tint(HexaTheme.fgSecondary).controlSize(.small) }
        }
    }

    private var fanRows: some View {
        VStack(spacing: HexaTheme.Spacing.xs) {
            ForEach(snapshot.fans) { fan in
                HStack(spacing: HexaTheme.Spacing.xs) {
                    Text(String(format: strings.fanNameFormat, fan.index + 1))
                        .font(.hexa(.body))
                        .foregroundStyle(HexaTheme.fgSecondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: HexaTheme.Spacing.xs) {
                        Text(String(format: strings.currentRPMFormat,
                                    Int(fan.actualRPM.rounded())))
                            .font(.hexa(.data))
                        if fan.isManuallyControlled {
                            Text(String(format: strings.targetRPMFormat,
                                        Int(fan.targetRPM.rounded())))
                                .font(.hexa(.data))
                                .foregroundStyle(HexaTheme.fgSecondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 1) // geometria de plataforma (spec §4): evita clipagem da hairline das linhas
    }

    private var fallbackFanRows: some View {
        VStack(spacing: HexaTheme.Spacing.xs) {
            ForEach(fallbackFanSpeeds.indices, id: \.self) { index in
                HexaKeyValueRow(label: String(format: strings.fanNameFormat, index + 1),
                                value: String(format: strings.currentRPMFormat,
                                              Int(fallbackFanSpeeds[index].rounded())))
            }
        }
        .padding(.vertical, 1) // geometria de plataforma (spec §4): evita clipagem da hairline das linhas
    }

    @ViewBuilder
    private var action: some View {
        if snapshot.isRecovering, accessState != .enabled {
            // Only the helper can put the fans back; it needs approval first.
            HexaAccessButton(icon: "gearshape",
                             title: strings.openSettings,
                             action: authorize)
        } else if snapshot.isRecovering {
            Button(strings.returnToSystem, action: stopCooling)
                .buttonStyle(HexaActionButtonStyle())
                .disabled(isWorking)
        } else if error == .noFans || error == .unsupportedHardware || error == .alreadyControlled {
            EmptyView()
        } else if accessState == .notRegistered, !snapshot.fans.isEmpty {
            Button(strings.allowControl, action: authorize)
                .buttonStyle(HexaActionButtonStyle())
                .controlSize(.small)
                .frame(maxWidth: .infinity)
        } else if accessState == .requiresApproval {
            HexaAccessButton(icon: "gearshape",
                             title: strings.openSettings,
                             action: authorize)
        } else if accessState == .enabled, controlsCanAppear {
            switch mode {
            case .system:
                if snapshot.isCooling {
                    Button(strings.returnToSystem, action: stopCooling)
                        .buttonStyle(HexaActionButtonStyle())
                        .controlSize(.small)
                        .disabled(isWorking)
                        .frame(maxWidth: .infinity)
                }
            case .manual:
                Button(strings.applyManual) {
                    coolingLevel = selectedCoolingLevel
                    applyConfiguration(.manual(level: selectedCoolingLevel))
                }
                .buttonStyle(HexaActionButtonStyle())
                .controlSize(.small)
                .disabled(isWorking)
                .frame(maxWidth: .infinity)
            case .curve:
                Button(strings.applyCurve) {
                    applyConfiguration(.curve(curves))
                }
                .buttonStyle(HexaActionButtonStyle())
                .controlSize(.small)
                .disabled(isWorking || !curveCanRun)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var statusText: String {
        if snapshot.isRecovering { return strings.recovering }
        guard snapshot.isCooling else { return strings.systemControl }
        let level = snapshot.coolingLevel ?? FanControlPolicy.defaultCoolingLevel
        switch snapshot.configuration?.mode ?? .manual {
        case .system:
            return strings.systemControl
        case .manual:
            return "\(strings.manualControl) · \(level)%"
        case .curve:
            let activeCurves = snapshot.configuration?.curves ?? []
            let temperature = activeCurves.count == 1
                ? snapshot.temperatures?.first { $0.source == activeCurves[0].sensor }?.celsius
                : nil
            if let temperature {
                return "\(strings.customCurve) · \(MetricFormat.temperature(temperature, unit: temperatureUnit)) · \(level)%"
            }
            return "\(strings.customCurve) · \(level)%"
        }
    }

    private var stateMessage: String? {
        if snapshot.isRecovering { return accessState == .enabled ? nil : strings.approvalCaption }
        if error == .noFans { return strings.noFans }
        if accessState == .unavailable { return strings.unsupported }
        switch error {
        case .alreadyControlled: return strings.alreadyControlled
        case .unsupportedHardware: return strings.unsupported
        case .helperUnavailable: return strings.helperUnavailable
        case .controlFailed: return strings.failed
        case .authorizationRequired: return strings.approvalCaption
        case .noFans, .none: break
        }
        if accessState == .notRegistered, !snapshot.fans.isEmpty { return strings.approvalCaption }
        if accessState == .requiresApproval { return strings.approvalCaption }
        switch snapshot.stopReason {
        case .temperatureUnavailable: return strings.temperatureUnavailable
        case .thermalPressure: return strings.thermalPressureStopped
        case .timeLimit, .appDisconnected, .heartbeatLost, .hardwareChanged, .recovery:
            return strings.safetyStopped
        case .none:
            break
        }
        if coolingUnverified { return strings.coolingUnverified }
        return nil
    }

    /// Alvo aplicado com ventoinha sem giro confirmado: o estado de verificação
    /// distingue o alvo gravado do resfriamento realmente executado.
    private var coolingUnverified: Bool {
        snapshot.isCooling && snapshot.coolingSpinConfirmed == false
    }

    private var messageIsError: Bool {
        if snapshot.isRecovering { return true }
        switch error {
        case .alreadyControlled, .unsupportedHardware, .helperUnavailable, .controlFailed:
            return true
        default:
            return false
        }
    }

    private var controlsCanAppear: Bool {
        !snapshot.fans.isEmpty
            && (error == nil || error == .controlFailed || snapshot.isCooling)
    }

    private var canConfigure: Bool {
        controlsCanAppear && accessState == .enabled && !snapshot.isRecovering
    }

    private var selectedCoolingLevel: Int {
        let clamped = min(max(coolingLevel, FanControlPolicy.minimumCoolingLevel),
                          FanControlPolicy.maximumCoolingLevel)
        let remainder = clamped % FanControlPolicy.coolingLevelStep
        return remainder == 0 ? clamped : clamped + FanControlPolicy.coolingLevelStep - remainder
    }

    private var coolingLevelBinding: Binding<Double> {
        Binding(
            get: { Double(selectedCoolingLevel) },
            set: { coolingLevel = Int($0.rounded()) }
        )
    }

    private var hasPendingChanges: Bool {
        guard canConfigure, !isWorking else { return false }
        let selected: FanControlConfiguration?
        switch mode {
        case .system: return snapshot.isCooling
        case .manual: selected = .manual(level: selectedCoolingLevel)
        case .curve: selected = .curve(curves)
        }
        return selected != snapshot.configuration
    }

    private var curveCanRun: Bool {
        guard FanControlPolicy.validCurves(curves) else { return false }
        let available = Set((snapshot.temperatures ?? []).map(\.source))
        return curves.allSatisfy { available.contains($0.sensor) }
    }
}
