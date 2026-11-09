// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import FanControlCore
import Darwin
import Foundation
import IOKit
import IOKit.pwr_mgt
import os
import Security

private let log = Logger(subsystem: FanControlIdentifiers.helperID, category: "FanControl")

// IOMessage.h: kIOMessageCanSystemSleep = iokit_common_msg(0x270) e kIOMessageSystemWillSleep = iokit_common_msg(0x280).
// iokit_common_msg(m) = sys_iokit | sub_iokit_common | m, com sys_iokit = err_system(0x38) = 0xE0000000 e sub_iokit_common = err_sub(0) = 0.
// Macro com argumento não é importada pelo Swift, então os valores são definidos aqui.
private let ioMessageCanSystemSleep: UInt32 = 0xE000_0270
private let ioMessageSystemWillSleep: UInt32 = 0xE000_0280

// Callback C: não captura contexto; o controlador chega pelo refcon.
private func fanControlPowerCallback(_ refcon: UnsafeMutableRawPointer?, _ service: io_service_t,
                                     _ messageType: UInt32, _ messageArgument: UnsafeMutableRawPointer?) {
    guard let refcon else { return }
    Unmanaged<FanControlController>.fromOpaque(refcon).takeUnretainedValue()
        .handleSystemPowerMessage(messageType, argument: messageArgument)
}

private final class FanControlOwnership {
    private let lockPath = "/var/run/hexa-fan-control.lock"
    private let markerPath = FanControlIdentifiers.recoveryMarkerPath
    private var lockFile: Int32 = -1

    var isHeld: Bool { lockFile >= 0 }

    func acquire() -> Bool {
        if isHeld { return true }
        let descriptor = Darwin.open(lockPath, O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW,
                                     mode_t(0o600))
        guard descriptor >= 0, secureRegularFile(descriptor) else {
            if descriptor >= 0 { Darwin.close(descriptor) }
            return false
        }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            Darwin.close(descriptor)
            return false
        }
        lockFile = descriptor
        return true
    }

    func release() {
        guard isHeld else { return }
        _ = flock(lockFile, LOCK_UN)
        Darwin.close(lockFile)
        lockFile = -1
    }

    func markerExists() -> Bool {
        var info = stat()
        guard lstat(markerPath, &info) == 0 else { return false }
        return info.st_uid == 0 && (info.st_mode & S_IFMT) == S_IFREG
            && (info.st_mode & mode_t(0o077)) == 0 && info.st_nlink == 1
    }

    func createMarker() -> Bool {
        guard isHeld, !markerExists() else { return false }
        let descriptor = Darwin.open(markerPath,
                                     O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
                                     mode_t(0o600))
        guard descriptor >= 0, secureRegularFile(descriptor) else {
            if descriptor >= 0 { Darwin.close(descriptor) }
            return false
        }
        let marker = Array("v1\n".utf8)
        let written = marker.withUnsafeBytes {
            Darwin.write(descriptor, $0.baseAddress, $0.count)
        }
        let synced = fsync(descriptor) == 0
        Darwin.close(descriptor)
        if written != marker.count || !synced {
            _ = unlink(markerPath)
            return false
        }
        return true
    }

    func removeMarker() -> Bool {
        !markerExists() || unlink(markerPath) == 0
    }

    private func secureRegularFile(_ descriptor: Int32) -> Bool {
        var info = stat()
        guard fstat(descriptor, &info) == 0 else { return false }
        return info.st_uid == 0 && (info.st_mode & S_IFMT) == S_IFREG
            && (info.st_mode & mode_t(0o077)) == 0 && info.st_nlink == 1
    }

    deinit { release() }
}

private final class FanControlController {
    private let log = Logger(subsystem: FanControlIdentifiers.helperID, category: "FanControl")
    private let queue = DispatchQueue(label: "com.hexa.fan-control.helper")
    private let ownership = FanControlOwnership()
    private var hardware: FanControlHardware?
    private var owner: UUID?
    private var isCooling = false
    private var isRecovering = false
    private var endsAt: Date?
    private var endsAtUptime: TimeInterval?
    private var lastHeartbeatUptime = ProcessInfo.processInfo.systemUptime
    private var verificationFailures = 0
    private var temperatureFailures = 0
    /// Divergências de giro consecutivas; vive isolado da verificação de registro.
    private var spinFailures = 0
    /// Estado do piso de segurança do modo manual, conforme o último alvo escrito.
    private var manualSafetyFloorActive = false
    private var lastStopReason: FanControlStopReason?
    private var coolingLevel: Int?
    private var activeConfiguration: FanControlConfiguration?
    private var connectionCount = 0
    private var idleGeneration = 0
    private var timer: DispatchSourceTimer?
    // Registro de energia (IOKit): existe só com watchdog ou recuperação ativa. Handles lidos e escritos apenas na fila do controlador.
    private var powerRootPort: io_connect_t = 0
    private var powerNotifier: io_object_t = 0
    private var powerPort: IONotificationPortRef?

    init() {
        queue.async { [weak self] in self?.recoverAbandonedControlIfNeeded() }
    }

    func connectionOpened() {
        queue.async {
            self.connectionCount += 1
            self.idleGeneration += 1
        }
    }

    func connectionClosed(_ id: UUID) {
        queue.async {
            self.connectionCount = max(0, self.connectionCount - 1)
            if self.owner == id, self.isCooling {
                _ = self.performRestore(reason: .appDisconnected)
            }
            self.scheduleExitIfIdle()
        }
    }

    func status(reply: @escaping (Data) -> Void) {
        queue.async { reply(FanControlIPC.encode(self.statusResponse())) }
    }

    func startLegacySession(_ id: UUID, reply: @escaping (Data) -> Void) {
        queue.async {
            let response = self.applyConfiguration(
                session: id,
                configuration: .manual(level: FanControlPolicy.maximumCoolingLevel),
                duration: FanControlPolicy.coolingDuration
            )
            reply(FanControlIPC.encode(response))
        }
    }

    func apply(session id: UUID, encodedConfiguration: Data,
               reply: @escaping (Data) -> Void) {
        queue.async {
            guard let configuration = FanControlIPC.decodeConfiguration(encodedConfiguration) else {
                reply(FanControlIPC.encode(.failure(.controlFailed,
                                                    snapshot: self.currentSnapshot())))
                return
            }
            let response = self.applyConfiguration(session: id,
                                                   configuration: configuration,
                                                   duration: nil)
            reply(FanControlIPC.encode(response))
        }
    }

    func heartbeat(session id: UUID, includeTelemetry: Bool = true, reply: @escaping (Data) -> Void) {
        queue.async {
            guard self.isCooling else {
                let snapshot = self.currentSnapshot(includeTelemetry: includeTelemetry)
                reply(FanControlIPC.encode(self.isRecovering
                    ? .failure(.controlFailed, snapshot: snapshot) : .success(snapshot)))
                return
            }
            guard self.owner == id else {
                reply(FanControlIPC.encode(.failure(.alreadyControlled,
                                                    snapshot: self.currentSnapshot())))
                return
            }
            self.lastHeartbeatUptime = ProcessInfo.processInfo.systemUptime
            reply(FanControlIPC.encode(.success(self.currentSnapshot(includeTelemetry: includeTelemetry))))
        }
    }

    func restore(reply: @escaping (Data) -> Void) {
        queue.async {
            let succeeded = self.performRestore(reason: nil)
            let response = succeeded
                ? FanControlResponse.success(self.currentSnapshot())
                : FanControlResponse.failure(.controlFailed, snapshot: self.currentSnapshot())
            reply(FanControlIPC.encode(response))
            self.scheduleExitIfIdle()
        }
    }

    func shutdown(completion: @escaping (Bool) -> Void) {
        queue.async {
            guard self.isCooling || self.isRecovering || self.ownership.isHeld else {
                completion(true)
                return
            }
            let restored = self.performRestore(reason: .appDisconnected)
            completion(restored)
        }
    }

    // MARK: - Control

    private func applyConfiguration(session id: UUID,
                                    configuration: FanControlConfiguration,
                                    duration: TimeInterval?) -> FanControlResponse {
        guard FanControlPolicy.validConfiguration(configuration) else {
            return .failure(.controlFailed)
        }
        if configuration.mode == .system {
            return performRestore(reason: nil)
                ? .success(currentSnapshot())
                : .failure(.controlFailed, snapshot: currentSnapshot())
        }
        if isCooling {
            guard owner == id else {
                return .failure(.alreadyControlled, snapshot: currentSnapshot())
            }
            return updateActiveConfiguration(configuration, duration: duration)
        }
        guard ownership.acquire() else { return .failure(.alreadyControlled) }
        if ownership.markerExists() {
            isRecovering = true
            startWatchdog()
            _ = performRestore(reason: .recovery)
            return .failure(.controlFailed, snapshot: currentSnapshot())
        }
        let control = FanControlHardware()
        hardware = control
        guard let control else {
            ownership.release()
            return .failure(.unsupportedHardware)
        }

        do {
            try control.validateAutomaticControl()
        } catch FanControlHardwareError.noFans {
            ownership.release()
            return .failure(.noFans)
        } catch FanControlHardwareError.alreadyControlled {
            ownership.release()
            return .failure(.alreadyControlled)
        } catch {
            ownership.release()
            return .failure(.unsupportedHardware)
        }
        // Fail-closed: sem o aviso de sono armado, nenhuma escrita no SMC acontece.
        guard registerPowerNotifications() else {
            ownership.release()
            return .failure(.controlFailed)
        }
        guard ownership.createMarker() else {
            ownership.release()
            stopWatchdogIfIdle()
            return .failure(.controlFailed)
        }

        do {
            guard let level = requestedLevel(for: configuration, hardware: control) else {
                finishFailedStart(mayHaveChangedHardware: false)
                return .failure(.controlFailed)
            }
            // Uma amostra única na partida; o piso manual depende só dela.
            let safetyFloorActive: Bool
            if configuration.mode == .manual {
                let sample = control.safetyFloorSample()
                safetyFloorActive = FanControlPolicy.safetyFloorActive(
                    for: sample.readings, cpuCoverageExpected: sample.cpuCoverageExpected)
            } else {
                safetyFloorActive = false
            }
            _ = try control.startCooling(level: level, safetyFloorActive: safetyFloorActive) {
                self.controlIsSafe(configuration, hardware: control)
            }
            owner = id
            isCooling = true
            coolingLevel = level
            manualSafetyFloorActive = safetyFloorActive
            activeConfiguration = configuration
            isRecovering = false
            let uptime = ProcessInfo.processInfo.systemUptime
            endsAt = duration.map { Date().addingTimeInterval($0) }
            endsAtUptime = duration.map { uptime + $0 }
            lastHeartbeatUptime = uptime
            verificationFailures = 0
            temperatureFailures = 0
            spinFailures = 0
            lastStopReason = nil
            startWatchdog()
            log.notice("Cooling session started")
            return .success(currentSnapshot())
        } catch FanControlHardwareError.noFans {
            finishFailedStart(mayHaveChangedHardware: false)
            return .failure(.noFans)
        } catch FanControlHardwareError.alreadyControlled {
            finishFailedStart(mayHaveChangedHardware: false)
            return .failure(.alreadyControlled)
        } catch FanControlHardwareError.unsupported {
            finishFailedStart(mayHaveChangedHardware: false)
            return .failure(.unsupportedHardware)
        } catch {
            finishFailedStart(mayHaveChangedHardware: true)
            return .failure(.controlFailed, snapshot: currentSnapshot())
        }
    }

    private func updateActiveConfiguration(_ configuration: FanControlConfiguration,
                                           duration: TimeInterval?) -> FanControlResponse {
        if hardware == nil { hardware = FanControlHardware() }
        guard let hardware,
              let level = requestedLevel(for: configuration, hardware: hardware) else {
            _ = performRestore(reason: .temperatureUnavailable)
            return .failure(.controlFailed, snapshot: currentSnapshot())
        }
        do {
            // Curva não usa piso; na entrada em manual o piso é avaliado com amostra
            // fresca (sem janela silenciosa); manual -> manual mantém a herança
            // vigente, reavaliada pelo tick.
            let safetyFloorActive: Bool
            if configuration.mode == .manual {
                if activeConfiguration?.mode == .manual {
                    safetyFloorActive = manualSafetyFloorActive
                } else {
                    let sample = hardware.safetyFloorSample()
                    safetyFloorActive = FanControlPolicy.safetyFloorActive(
                        for: sample.readings, cpuCoverageExpected: sample.cpuCoverageExpected)
                }
            } else {
                safetyFloorActive = false
            }
            _ = try hardware.updateCooling(level: level, safetyFloorActive: safetyFloorActive) {
                self.controlIsSafe(configuration, hardware: hardware)
            }
            activeConfiguration = configuration
            coolingLevel = level
            manualSafetyFloorActive = safetyFloorActive
            let uptime = ProcessInfo.processInfo.systemUptime
            endsAt = duration.map { Date().addingTimeInterval($0) }
            endsAtUptime = duration.map { uptime + $0 }
            lastHeartbeatUptime = uptime
            verificationFailures = 0
            temperatureFailures = 0
            lastStopReason = nil
            return .success(currentSnapshot())
        } catch {
            _ = performRestore(reason: .hardwareChanged)
            return .failure(.controlFailed, snapshot: currentSnapshot())
        }
    }

    private func requestedLevel(for configuration: FanControlConfiguration,
                                hardware: FanControlHardware,
                                previousLevel: Int? = nil) -> Int? {
        switch configuration.mode {
        case .system:
            return nil
        case .manual:
            return configuration.manualLevel
        case .curve:
            return FanControlPolicy.curveCoolingLevel(
                curves: configuration.curves,
                temperatures: hardware.readTemperatures(),
                previousLevel: previousLevel
            )
        }
    }

    private func finishFailedStart(mayHaveChangedHardware: Bool) {
        if (mayHaveChangedHardware && hardware?.restoreAutomatic() != true)
            || !ownership.removeMarker() {
            isRecovering = true
            startWatchdog()
            return
        }
        ownership.release()
        hardware = nil
        isRecovering = false
        stopWatchdogIfIdle()
    }

    @discardableResult
    private func performRestore(reason: FanControlStopReason?) -> Bool {
        if !ownership.isHeld {
            guard ownership.acquire() else { return false }
        }
        guard ownership.markerExists() || isCooling || isRecovering else {
            ownership.release()
            return true
        }
        if hardware == nil { hardware = FanControlHardware() }
        guard hardware?.restoreAutomatic() == true,
              ownership.removeMarker() else {
            isRecovering = true
            isCooling = false
            owner = nil
            coolingLevel = nil
            activeConfiguration = nil
            endsAt = nil
            endsAtUptime = nil
            verificationFailures = 0
            temperatureFailures = 0
            spinFailures = 0
            manualSafetyFloorActive = false
            startWatchdog()
            log.error("Automatic fan recovery will retry")
            return false
        }

        isCooling = false
        isRecovering = false
        owner = nil
        coolingLevel = nil
        activeConfiguration = nil
        endsAt = nil
        endsAtUptime = nil
        verificationFailures = 0
        temperatureFailures = 0
        spinFailures = 0
        manualSafetyFloorActive = false
        lastStopReason = reason
        ownership.release()
        stopWatchdogIfIdle()
        log.notice("Automatic fan control restored")
        scheduleExitIfIdle()
        return true
    }

    private func recoverAbandonedControlIfNeeded() {
        guard ownership.acquire() else {
            scheduleExitIfIdle()
            return
        }
        guard ownership.markerExists() else {
            ownership.release()
            scheduleExitIfIdle()
            return
        }
        isRecovering = true
        hardware = FanControlHardware()
        if performRestore(reason: .recovery) {
            scheduleExitIfIdle()
        } else {
            startWatchdog()
        }
    }

    // MARK: - Watchdog

    private func startWatchdog() {
        // Best effort: uma falha já foi logada e a próxima chamada tenta de novo, sem bloquear a recuperação.
        _ = registerPowerNotifications()
        guard timer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1, repeating: 1, leeway: .milliseconds(100))
        timer.setEventHandler { [weak self] in self?.watchdogTick() }
        self.timer = timer
        timer.resume()
    }

    private func watchdogTick() {
        if isRecovering {
            if performRestore(reason: .recovery) { scheduleExitIfIdle() }
            return
        }
        guard isCooling else {
            stopWatchdogIfIdle()
            return
        }
        // Prazo da sessão antes de qualquer leitura de temperatura ou escrita no SMC.
        if FanControlPolicy.sessionExpired(nowUptime: ProcessInfo.processInfo.systemUptime,
                                           endsAtUptime: endsAtUptime) {
            _ = performRestore(reason: .timeLimit)
            return
        }
        if let reason = FanControlPolicy.restoreReason(
            now: Date(), endsAt: nil,
            heartbeatAge: max(0, ProcessInfo.processInfo.systemUptime - lastHeartbeatUptime),
            verificationFailures: verificationFailures, temperatureFailures: temperatureFailures) {
            _ = performRestore(reason: reason)
            return
        }
        // Corte térmico: só a sessão manual devolve ao firmware; a curva não corta.
        // A leitura do estado térmico acontece aqui, dentro do tick, sem observer.
        if activeConfiguration?.mode == .manual,
           FanControlPolicy.manualThermalCutoffActive(ProcessInfo.processInfo.thermalState) {
            _ = performRestore(reason: .thermalPressure)
            return
        }
        var controlIntact = false
        if activeConfiguration?.mode == .curve,
           let configuration = activeConfiguration,
           let hardware {
            if let requested = requestedLevel(for: configuration, hardware: hardware,
                                              previousLevel: coolingLevel) {
                temperatureFailures = 0
                if requested == coolingLevel {
                    controlIntact = hardware.coolingIsIntact()
                } else {
                    do {
                        _ = try hardware.updateCooling(level: requested) {
                            self.controlIsSafe(configuration, hardware: hardware)
                        }
                        coolingLevel = requested
                        controlIntact = true
                    } catch {
                        _ = performRestore(reason: .hardwareChanged)
                        return
                    }
                }
            } else {
                temperatureFailures += 1
                controlIntact = hardware.coolingIsIntact()
            }
        } else {
            // Sessão manual: uma amostra por tick, sem leitura quando não há sessão.
            // A mesma amostra alimenta a contagem de falhas e o piso de segurança.
            if activeConfiguration?.mode == .manual, let hardware,
               let configuration = activeConfiguration {
                let sample = hardware.safetyFloorSample()
                temperatureFailures = FanControlPolicy.nextTemperatureFailures(
                    previous: temperatureFailures, hasUsableReading: !sample.readings.isEmpty)
                let safetyFloorActive = FanControlPolicy.safetyFloorActive(
                    for: sample.readings, cpuCoverageExpected: sample.cpuCoverageExpected)
                if safetyFloorActive != manualSafetyFloorActive {
                    do {
                        _ = try hardware.updateCooling(
                            level: configuration.manualLevel,
                            safetyFloorActive: safetyFloorActive
                        ) {
                            self.controlIsSafe(configuration, hardware: hardware)
                        }
                        manualSafetyFloorActive = safetyFloorActive
                    } catch {
                        _ = performRestore(reason: .hardwareChanged)
                        return
                    }
                }
            }
            controlIntact = hardware?.coolingIsIntact() == true
        }
        if controlIntact {
            verificationFailures = 0
        } else {
            verificationFailures += 1
        }
        // Confirmação de giro: contador isolado. Sem dado (nil) não acusa nem zera;
        // divergência não devolve a sessão nem regrava o alvo.
        if let hardware {
            switch hardware.coolingSpinConfirmed(targets: hardware.controlledTargets) {
            case .none:
                break
            case .some(true):
                spinFailures = 0
            case .some(false):
                spinFailures += 1
            }
        }
        let nowUptime = ProcessInfo.processInfo.systemUptime
        let deadlineNow: Date
        if let endsAt, let endsAtUptime, nowUptime >= endsAtUptime {
            deadlineNow = endsAt
        } else {
            deadlineNow = Date()
        }
        let reason = FanControlPolicy.restoreReason(
            now: deadlineNow,
            endsAt: endsAt,
            heartbeatAge: max(0, nowUptime - lastHeartbeatUptime),
            verificationFailures: verificationFailures,
            temperatureFailures: temperatureFailures
        )
        if let reason { _ = performRestore(reason: reason) }
    }

    private func stopWatchdogIfIdle() {
        guard !isCooling, !isRecovering else { return }
        timer?.cancel()
        timer = nil
        // Teardown adiado para a própria fila serial: o bloco roda depois de qualquer callback de WillSleep
        // em curso, que já terá retornado e feito o ack (IOAllowPowerChange). A ociosidade é revalidada ali.
        queue.async { self.unregisterPowerNotificationsIfIdle() }
    }

    // MARK: - Energia

    // Roda apenas na fila do controlador. Retorna true quando o aviso de sono está armado.
    private func registerPowerNotifications() -> Bool {
        guard powerRootPort == 0 else { return true }
        var port: IONotificationPortRef?
        var notifier: io_object_t = 0
        let rootPort = IORegisterForSystemPower(Unmanaged.passUnretained(self).toOpaque(),
                                                &port, fanControlPowerCallback, &notifier)
        guard rootPort != 0, let port else {
            // Porta criada mas sem registro efetivo: destruir para não vazar o recurso.
            if let port { IONotificationPortDestroy(port) }
            log.error("System power notifications unavailable")
            return false
        }
        // Eventos de energia são entregues na fila serial do controlador, sem run loop.
        IONotificationPortSetDispatchQueue(port, queue)
        powerRootPort = rootPort
        powerNotifier = notifier
        powerPort = port
        return true
    }

    private func unregisterPowerNotifications() {
        guard powerRootPort != 0, let port = powerPort else { return }
        _ = IODeregisterForSystemPower(&powerNotifier)
        _ = IOServiceClose(powerRootPort)
        IONotificationPortDestroy(port)
        powerRootPort = 0
        powerNotifier = 0
        powerPort = nil
    }

    // Executa só na fila do controlador, agendada por stopWatchdogIfIdle.
    private func unregisterPowerNotificationsIfIdle() {
        // Revalida no momento da execução: uma sessão ou recuperação pode ter começado após o agendamento.
        guard timer == nil, !isCooling, !isRecovering else { return }
        unregisterPowerNotifications()
    }

    // Chamado pela fila do controlador (IONotificationPortSetDispatchQueue), nunca pela main.
    fileprivate func handleSystemPowerMessage(_ messageType: UInt32, argument: UnsafeMutableRawPointer?) {
        // messageArgument carrega o notificationID (intptr_t) que IOAllowPowerChange exige de volta.
        let notificationID = Int(bitPattern: argument)
        switch messageType {
        case ioMessageSystemWillSleep:
            // Restore automático nesta mesma execução; o ack vem em seguida, sem sair da fila.
            _ = performRestore(reason: .recovery)
            // Ack em todo caminho: sucesso, falha do restore ou ausência de sessão.
            _ = IOAllowPowerChange(powerRootPort, notificationID)
        case ioMessageCanSystemSleep:
            // Nunca veta o sono; apenas confirma.
            _ = IOAllowPowerChange(powerRootPort, notificationID)
        default:
            break
        }
    }

    // MARK: - Status and lifecycle

    private func statusResponse() -> FanControlResponse {
        if isRecovering { return .failure(.controlFailed, snapshot: currentSnapshot()) }
        if isCooling { return .success(currentSnapshot()) }

        guard ownership.acquire() else { return .failure(.alreadyControlled) }
        if ownership.markerExists() {
            isRecovering = true
            startWatchdog()
            _ = performRestore(reason: .recovery)
            return isRecovering ? .failure(.controlFailed, snapshot: currentSnapshot())
                                : .success(currentSnapshot())
        }
        ownership.release()

        if hardware == nil { hardware = FanControlHardware() }
        guard let hardware else { return .failure(.unsupportedHardware) }
        do {
            let snapshot = try hardware.snapshot(isCooling: false, endsAt: nil,
                                                 stopReason: lastStopReason,
                                                 coolingLevel: nil,
                                                 configuration: nil)
            if snapshot.fans.contains(where: \.isManuallyControlled) {
                return .failure(.alreadyControlled, snapshot: snapshot)
            }
            return .success(snapshot)
        } catch FanControlHardwareError.noFans {
            return .failure(.noFans)
        } catch FanControlHardwareError.unsupported {
            return .failure(.unsupportedHardware)
        } catch {
            return .failure(.controlFailed)
        }
    }

    private func controlIsSafe(_ configuration: FanControlConfiguration,
                               hardware: FanControlHardware) -> Bool {
        return configuration.mode != .curve || requestedLevel(for: configuration, hardware: hardware) != nil
    }

    private func currentSnapshot(includeTelemetry: Bool = true) -> FanControlSnapshot {
        let telemetry = includeTelemetry
            ? (try? hardware?.snapshot(isCooling: isCooling, endsAt: endsAt,
                                       stopReason: lastStopReason, coolingLevel: coolingLevel,
                                       configuration: activeConfiguration))
            : nil
        var snapshot = telemetry ?? FanControlSnapshot(
            fans: [], isCooling: isCooling, endsAt: endsAt, stopReason: lastStopReason,
            coolingLevel: coolingLevel, configuration: activeConfiguration, temperatures: nil)
        snapshot.isRecovering = isRecovering
        snapshot.coolingSpinConfirmed = isCooling
            ? (spinFailures >= FanControlPolicy.spinConfirmationFailureLimit ? false : true)
            : nil
        return snapshot
    }

    private func scheduleExitIfIdle() {
        guard connectionCount == 0, !isCooling, !isRecovering else { return }
        idleGeneration += 1
        let generation = idleGeneration
        queue.asyncAfter(deadline: .now() + 10) {
            guard generation == self.idleGeneration,
                  self.connectionCount == 0, !self.isCooling, !self.isRecovering else { return }
            exit(EXIT_SUCCESS)
        }
    }
}

private final class FanControlSession: NSObject, FanControlXPCProtocol {
    let id = UUID()
    private let controller: FanControlController

    init(controller: FanControlController) {
        self.controller = controller
    }

    func status(withReply reply: @escaping (Data) -> Void) {
        controller.status(reply: reply)
    }

    func startMaximumCooling(withReply reply: @escaping (Data) -> Void) {
        controller.startLegacySession(id, reply: reply)
    }

    func applyConfiguration(_ configuration: Data, withReply reply: @escaping (Data) -> Void) {
        controller.apply(session: id, encodedConfiguration: configuration, reply: reply)
    }

    func heartbeat(_ includeTelemetry: Bool, withReply reply: @escaping (Data) -> Void) {
        controller.heartbeat(session: id, includeTelemetry: includeTelemetry, reply: reply)
    }

    func heartbeat(withReply reply: @escaping (Data) -> Void) {
        controller.heartbeat(session: id, reply: reply)
    }

    func restoreAutomatic(withReply reply: @escaping (Data) -> Void) {
        controller.restore(reply: reply)
    }
}

private extension NSXPCConnection {
    var auditToken: audit_token_t {
        let selector = NSSelectorFromString("auditToken")
        guard responds(to: selector) else {
            var token = audit_token_t()
            if let val = value(forKey: "auditToken") as? NSValue {
                val.getValue(&token, size: MemoryLayout<audit_token_t>.size)
            }
            return token
        }
        typealias AuditTokenFunc = @convention(c) (AnyObject, Selector) -> audit_token_t
        let imp = class_getMethodImplementation(type(of: self), selector)
        let getAuditToken = unsafeBitCast(imp, to: AuditTokenFunc.self)
        return getAuditToken(self, selector)
    }
}

private final class FanControlListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let controller: FanControlController
    // Compilado uma única vez; nil em falha, e nesse caso todas as conexões são recusadas.
    private let callerRequirement: SecRequirement?

    init(controller: FanControlController) {
        self.controller = controller
        var requirement: SecRequirement?
        let reqStatus = SecRequirementCreateWithString(
            FanControlIdentifiers.appCodeRequirement as CFString,
            [],
            &requirement
        )
        if reqStatus != errSecSuccess {
            log.error("Failed to compile app code requirement: \(reqStatus)")
        }
        self.callerRequirement = reqStatus == errSecSuccess ? requirement : nil
    }

    private func isValidCaller(connection: NSXPCConnection) -> Bool {
        let token = connection.auditToken
        let tokenData = withUnsafeBytes(of: token) { Data($0) }
        let attributes = [kSecGuestAttributeAudit: tokenData] as CFDictionary
        var code: SecCode?
        let copyStatus = SecCodeCopyGuestWithAttributes(nil, attributes, [], &code)
        guard copyStatus == errSecSuccess, let code else {
            log.error("Failed to obtain SecCode for connecting process: \(copyStatus)")
            return false
        }

        if !FanControlIdentifiers.teamID.isEmpty {
            guard let requirement = callerRequirement else {
                log.error("App code requirement unavailable; rejecting connection")
                return false
            }
            // [] == kSecCSDefaultFlags (0): flag explícita, sem mudança de comportamento.
            let validityStatus = SecCodeCheckValidity(
                code,
                [],
                requirement
            )
            guard validityStatus == errSecSuccess else {
                log.error("Connecting process failed requirement validation: \(validityStatus)")
                return false
            }
        } else {
            log.error("helper misconfigured: missing Team ID; rejecting connection")
            return false
        }

        return true
    }

    func listener(_ listener: NSXPCListener,
                  shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard isValidCaller(connection: connection) else {
            log.error("Rejected incoming connection: caller validation failed")
            return false
        }
        let session = FanControlSession(controller: controller)
        connection.exportedInterface = NSXPCInterface(with: FanControlXPCProtocol.self)
        connection.exportedObject = session
        connection.invalidationHandler = { [weak controller] in
            controller?.connectionClosed(session.id)
        }
        controller.connectionOpened()
        connection.activate()
        return true
    }
}

private func runSelfTest() -> Bool {
    guard !FanControlIdentifiers.teamID.isEmpty,
          FanControlIdentifiers.helperID.hasSuffix(".fan-control"),
          FanControlPolicy.coolingDuration == 900,
          FanControlPolicy.validCoolingLevel(FanControlPolicy.defaultCoolingLevel),
          FanControlPolicy.validConfiguration(.curve([FanControlConfiguration.defaultCurve])),
          let encoded = SMCValueCodec.encode(4_800, type: "flt ", size: 4),
          SMCValueCodec.decode(encoded, type: "flt ") == 4_800 else { return false }
    print("fan-control-helper: ok")
    return true
}

if ProcessInfo.processInfo.arguments.contains("--selftest") {
    exit(runSelfTest() ? EXIT_SUCCESS : EXIT_FAILURE)
}

guard geteuid() == 0 else {
    log.error("The helper must run as root")
    exit(EXIT_FAILURE)
}

guard !FanControlIdentifiers.teamID.isEmpty else {
    log.error("A signed identity is required for fan control")
    exit(EXIT_FAILURE)
}

private let controller = FanControlController()
private let delegate = FanControlListenerDelegate(controller: controller)
private let listener = NSXPCListener(machServiceName: FanControlIdentifiers.helperID)
listener.setConnectionCodeSigningRequirement(FanControlIdentifiers.appCodeRequirement)
listener.delegate = delegate
listener.activate()

signal(SIGTERM, SIG_IGN)
signal(SIGINT, SIG_IGN)
let termination = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
termination.setEventHandler {
    controller.shutdown { restored in
        if restored { exit(EXIT_SUCCESS) }
    }
}
termination.resume()
let interruption = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
interruption.setEventHandler {
    controller.shutdown { restored in
        if restored { exit(EXIT_SUCCESS) }
    }
}
interruption.resume()

RunLoop.main.run()
