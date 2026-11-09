// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Foundation

public enum FanControlHardwareError: Error {
    case noFans
    case unsupported
    case alreadyControlled
    case operationFailed
}

/// The only SMC write policy used by Fan Control. It discovers the keys the
/// hardware actually exposes, accepts only sane reported bounds, and writes
/// only a validated cooling level or automatic mode. There is no arbitrary key
/// or RPM entry point.
public final class FanControlHardware {
    private struct TelemetryFan {
        let index: Int
        let actual: SMCClient.Key
    }

    private struct Fan {
        let index: Int
        let actual: SMCClient.Key
        let minimum: SMCClient.Key
        let maximum: SMCClient.Key
        let target: SMCClient.Key
        let mode: SMCClient.Key
    }

    private struct TemperatureKeys {
        let cpu: [SMCClient.Key]
        let gpu: [SMCClient.Key]
    }

    private let client: SMCClient
    private var controlledFans: [Fan]?
    private var telemetryFans: [TelemetryFan]?
    private var cachedForceTestKey: SMCClient.Key?
    private var didDiscoverForceTestKey = false
    private var activeTargets: [Double] = []
    private var temperatureKeys: TemperatureKeys?
    private var writeDeadline: TimeInterval?
    private var writeSafetyCheck: (() -> Bool)?
    private let temperaturePlatform = TemperatureSensorSelector.currentPlatform()

    public init?() {
        guard let client = SMCClient() else { return nil }
        self.client = client
    }

    public func readOnlySnapshot() throws -> FanControlSnapshot {
        let fans = try discoverControlledFans()
        let snapshot = FanControlSnapshot(fans: try readings(for: fans), isCooling: false,
                                          endsAt: nil, stopReason: nil,
                                          coolingLevel: nil,
                                          configuration: nil,
                                          temperatures: readTemperatures())
        if let forceTest = forceTestKey(), try byteValue(forceTest) != 0 {
            throw FanControlHardwareError.alreadyControlled
        }
        return snapshot
    }

    public func telemetrySnapshot() throws -> FanControlSnapshot {
        let fans = try discoverTelemetryFans()
        guard let speeds = FanControlPolicy.telemetryReadings(
            expectedCount: fans.count,
            readings: fans.map { client.readValue($0.actual) }
        ) else {
            throw FanControlHardwareError.operationFailed
        }
        let readings = zip(fans, speeds).map { fan, actual in
            FanControlFanReading(index: fan.index,
                                    actualRPM: actual,
                                    minimumRPM: 0,
                                    maximumRPM: 0,
                                    targetRPM: 0,
                                    isManuallyControlled: false)
        }
        return FanControlSnapshot(fans: readings, isCooling: false,
                                  endsAt: nil, stopReason: nil,
                                  coolingLevel: nil,
                                  configuration: nil,
                                  temperatures: nil)
    }

    public func startCooling(level: Int, safetyFloorActive: Bool = false,
                             shouldContinue: @escaping () -> Bool) throws -> [FanControlFanReading] {
        beginWrites(shouldContinue: shouldContinue)
        defer { endWrites() }
        guard writesAreSafe else { throw FanControlHardwareError.operationFailed }
        let fans = try discoverControlledFans()
        guard try fans.allSatisfy({ try FanControlPolicy.isAutomaticMode(modeValue($0.mode)) }) else {
            throw FanControlHardwareError.alreadyControlled
        }
        if let forceTest = forceTestKey(), try byteValue(forceTest) != 0 {
            throw FanControlHardwareError.alreadyControlled
        }

        let targets = try fans.map { fan -> Double in
            guard let bounds = currentBounds(for: fan), let target = FanControlPolicy.manualTargetRPM(
                    minimum: bounds.minimum,
                    maximum: bounds.maximum,
                    level: level,
                    safetyFloorActive: safetyFloorActive
                  ) else {
                throw FanControlHardwareError.operationFailed
            }
            return target
        }

        // Keep the target write adjacent to manual mode. The thermal controller
        // can reclaim automatic mode between a separate verification and target.
        var directSucceeded = true
        for (fan, target) in zip(fans, targets) {
            if !writeManualPair(for: fan, target: target) { directSucceeded = false }
        }

        if directSucceeded {
            guard waitSafely(0.25) else { throw FanControlHardwareError.operationFailed }
            directSucceeded = fans.allSatisfy { (try? modeValue($0.mode)) == 1 }
        }

        if !directSucceeded {
            let forceTest = forceTestKey()
            let forced = forceTest.map { setByte(1, for: $0, attempts: 20) } ?? false
            guard FanControlPolicy.forceTestSatisfied(keyExists: forceTest != nil,
                                                      writeSucceeded: forced) else {
                throw FanControlHardwareError.operationFailed
            }
            // A stopped Apple Silicon fan can reject manual mode until the
            // automatic controller has accepted a protective maximum target.
            // Apply the requested level only after manual mode sticks.
            for fan in fans {
                guard let bounds = currentBounds(for: fan),
                      setTargetValue(bounds.maximum, for: fan, attempts: 10) else {
                    throw FanControlHardwareError.operationFailed
                }
            }
            guard waitSafely(3) else { throw FanControlHardwareError.operationFailed }
            for fan in fans {
                let deadline = min(writeDeadline ?? 0, ProcessInfo.processInfo.systemUptime + 10)
                guard setMode(1, for: fan, untilUptime: deadline) else {
                    throw FanControlHardwareError.operationFailed
                }
            }
        }

        if !directSucceeded {
            for (fan, target) in zip(fans, targets) {
                guard setTargetRPM(target, for: fan, attempts: 10) else {
                    throw FanControlHardwareError.operationFailed
                }
            }
        }
        guard verifyCooling(fans, targets: targets, attempts: 10) else {
            throw FanControlHardwareError.operationFailed
        }
        activeTargets = targets
        return try readings(for: fans)
    }

    public func updateCooling(level: Int, safetyFloorActive: Bool = false,
                              shouldContinue: @escaping () -> Bool) throws -> [FanControlFanReading] {
        beginWrites(shouldContinue: shouldContinue)
        defer { endWrites() }
        guard writesAreSafe else { throw FanControlHardwareError.operationFailed }
        let fans = try discoverControlledFans()
        guard FanControlPolicy.validCoolingLevel(level) else {
            throw FanControlHardwareError.operationFailed
        }
        let targets = try fans.map { fan -> Double in
            guard let bounds = currentBounds(for: fan), let target = FanControlPolicy.manualTargetRPM(
                minimum: bounds.minimum,
                maximum: bounds.maximum,
                level: level,
                safetyFloorActive: safetyFloorActive
            ) else { throw FanControlHardwareError.operationFailed }
            return target
        }
        for (fan, target) in zip(fans, targets) {
            guard setTargetRPM(target, for: fan, attempts: 10) else {
                throw FanControlHardwareError.operationFailed
            }
        }
        guard verifyCooling(fans, targets: targets, attempts: 10) else {
            throw FanControlHardwareError.operationFailed
        }
        activeTargets = targets
        return try readings(for: fans)
    }

    public func validateAutomaticControl() throws {
        let fans = try discoverControlledFans()
        guard try fans.allSatisfy({ try FanControlPolicy.isAutomaticMode(modeValue($0.mode)) }) else {
            throw FanControlHardwareError.alreadyControlled
        }
        if let forceTest = forceTestKey() {
            guard try byteValue(forceTest) == 0 else {
                throw FanControlHardwareError.alreadyControlled
            }
        }
    }

    /// Best effort across every discovered fan. Returning false keeps the
    /// helper's recovery marker in place so its watchdog continues retrying.
    public func restoreAutomatic() -> Bool {
        // Retomar automático não depende de sensores de RPM funcionando.
        let reportedCount = try? fanCount()
        let modes = (0..<(reportedCount ?? FanControlPolicy.maximumFanCount)).compactMap { index -> (Int, SMCClient.Key)? in
            guard let mode = ["F\(index)md", "F\(index)Md"]
                .compactMap({ client.key(named: $0) }).first(where: { $0.dataSize == 1 }) else { return nil }
            return (index, mode)
        }
        guard !modes.isEmpty else { return false }
        // Não limpar o alvo: até uma escrita de modo aceita pode ser retomada
        // pelo controlador antes da escrita seguinte. Zero nunca é alvo de recuperação.
        if let forceTest = forceTestKey() {
            _ = setByte(0, for: forceTest, attempts: 20)
        }
        for (index, mode) in modes {
            if !setByte(0, for: mode, attempts: 20),
               let fan = controlledFans?.first(where: { $0.index == index }),
               let bounds = currentBounds(for: fan) {
                _ = setTargetValue(bounds.maximum, for: fan, attempts: 10)
            }
        }
        let automatic = (reportedCount != nil && modes.count == reportedCount)
            && modes.allSatisfy { _, mode in
                (try? modeValue(mode)).map(FanControlPolicy.isAutomaticMode) == true
            }
        let forceTestOff = forceTestKey().map { (try? byteValue($0)) == 0 } ?? true
        if automatic && forceTestOff { activeTargets.removeAll() }
        return automatic && forceTestOff
    }

    public func snapshot(isCooling: Bool, endsAt: Date?,
                  stopReason: FanControlStopReason?,
                  coolingLevel: Int? = nil,
                  configuration: FanControlConfiguration? = nil) throws -> FanControlSnapshot {
        let fans = try discoverControlledFans()
        return FanControlSnapshot(fans: try readings(for: fans),
                                  isCooling: isCooling,
                                  endsAt: endsAt,
                                  stopReason: stopReason,
                                  coolingLevel: coolingLevel,
                                  configuration: configuration,
                                  temperatures: readTemperatures())
    }

    public func coolingIsIntact() -> Bool {
        guard let fans = try? discoverControlledFans() else { return false }
        guard (try? readings(for: fans)) != nil else { return false }
        return verifyCooling(fans, targets: activeTargets)
    }

    /// Alvos gravados na sessão corrente; base da leitura de confirmação de giro.
    public var controlledTargets: [Double] { activeTargets }

    /// Confirmação de giro agregada: `true` quando todas as ventoinhas controladas
    /// estão dentro da banda do alvo, `false` quando alguma diverge e `nil`
    /// quando não há leitura para julgar (sem dado, sem acusação).
    public func coolingSpinConfirmed(targets: [Double]) -> Bool? {
        guard let fans = try? discoverControlledFans() else { return nil }
        guard fans.count == targets.count else { return nil }
        var confirmed = true
        for (fan, target) in zip(fans, targets) {
            guard let actual = client.readValue(fan.actual),
                  FanControlPolicy.validReading(actual) else { return nil }
            if !FanControlPolicy.fanSpinConfirmed(actualRPM: actual, targetRPM: target) {
                confirmed = false
            }
        }
        return confirmed
    }

    public func readTemperatures() -> [FanControlTemperatureReading] {
        let keys = discoverTemperatureKeys()
        let cpuKeys = keys.cpu.filter {
            TemperatureSensorSelector.hasCPUCoreSet(platform: temperaturePlatform)
                ? TemperatureSensorSelector.isCPUCoreKey($0.name, platform: temperaturePlatform)
                : temperaturePlatform == .generic
        }
        let cpu = temperatureReadings(cpuKeys)
        let gpu = temperatureReadings(keys.gpu)
        // Todos os sensores descobertos da fonte devem responder, inclusive
        // na primeira leitura. Não recalcular a curva com uma fonte parcial.
        let cpuIntact = !cpu.isEmpty && cpu.count == cpuKeys.count
        let gpuIntact = gpu.count == keys.gpu.count
        var readings = FanControlPolicy.aggregatedTemperatures(
            cpuReadings: cpuIntact ? cpu : [],
            gpuReadings: gpuIntact ? gpu.map(\.value) : [],
            platform: temperaturePlatform
        )
        // Uma fonte SoC não pode mudar silenciosamente de CPU+GPU para só GPU.
        if !cpuIntact || !gpuIntact {
            readings.removeAll { $0.source == .averageSoC || $0.source == .hottestSoC }
        }
        return readings
    }

    /// Amostra usada pelas decisões de piso: lê as chaves de CPU descobertas
    /// (sem o filtro de núcleo do caminho de exibição) e as chaves GPU, e
    /// devolve junto a cobertura de CPU esperada. Uma única passagem de leitura.
    public func safetyFloorSample() -> (readings: [FanControlTemperatureReading],
                                        cpuCoverageExpected: Bool) {
        let keys = discoverTemperatureKeys()
        let cpu = temperatureReadings(keys.cpu)
        let gpu = temperatureReadings(keys.gpu)
        let readings = FanControlPolicy.safetyFloorDecisionTemperatures(
            cpuReadings: cpu,
            gpuReadings: gpu.map(\.value),
            platform: temperaturePlatform
        )
        return (readings, cpuCoverageExpected())
    }

    /// A leitura de CPU é esperada quando o chip tem núcleos mapeados e o Mac
    /// expõe esses sensores, ou, em chip sem mapa de núcleos, quando o Mac
    /// expõe alguma chave de CPU.
    public func cpuCoverageExpected() -> Bool {
        TemperatureSensorSelector.cpuCoverageExpected(
            discoveredCPUKeys: discoverTemperatureKeys().cpu.map(\.name),
            platform: temperaturePlatform
        )
    }

    // MARK: - Discovery

    private func fanCount() throws -> Int {
        guard let key = client.key(named: "FNum"),
              let value = client.readValue(key) else {
            throw FanControlHardwareError.noFans
        }
        guard let count = FanControlPolicy.fanCount(from: value) else {
            throw value == 0 ? FanControlHardwareError.noFans
                             : FanControlHardwareError.unsupported
        }
        return count
    }

    private func discoverControlledFans() throws -> [Fan] {
        if let controlledFans { return controlledFans }
        let count = try fanCount()
        var fans: [Fan] = []
        for index in 0..<count {
            guard let actual = client.key(named: "F\(index)Ac"),
                  let minimum = client.key(named: "F\(index)Mn"),
                  let maximum = client.key(named: "F\(index)Mx"),
                  let target = client.key(named: "F\(index)Tg"),
                  let mode = modeKey(for: index),
                  mode.dataSize == 1,
                  let minimumRPM = client.readValue(minimum),
                  let maximumRPM = client.readValue(maximum),
                  FanControlPolicy.validBounds(minimum: minimumRPM, maximum: maximumRPM),
                  SMCValueCodec.encode(maximumRPM, type: target.dataType,
                                       size: Int(target.dataSize)) != nil else {
                throw FanControlHardwareError.unsupported
            }
            fans.append(Fan(index: index, actual: actual, minimum: minimum,
                            maximum: maximum, target: target, mode: mode))
        }
        controlledFans = fans
        return fans
    }

    private func discoverTelemetryFans() throws -> [TelemetryFan] {
        if let telemetryFans { return telemetryFans }
        let count = try fanCount()
        let fans = try (0..<count).map { index -> TelemetryFan in
            guard let actual = client.key(named: "F\(index)Ac") else {
                throw FanControlHardwareError.unsupported
            }
            return TelemetryFan(index: index, actual: actual)
        }
        telemetryFans = fans
        return fans
    }

    private func modeKey(for index: Int) -> SMCClient.Key? {
        for name in ["F\(index)md", "F\(index)Md"] {
            if let key = client.key(named: name), client.readBytes(key) != nil { return key }
        }
        return nil
    }

    private func forceTestKey() -> SMCClient.Key? {
        if didDiscoverForceTestKey { return cachedForceTestKey }
        didDiscoverForceTestKey = true
        guard let key = client.key(named: "Ftst"), key.dataSize == 1 else { return nil }
        cachedForceTestKey = key
        return key
    }

    private func discoverTemperatureKeys() -> TemperatureKeys {
        if let temperatureKeys { return temperatureKeys }
        let keys = client.keys { name in
            TemperatureSensorSelector.isCPUTemperatureKey(name, platform: temperaturePlatform)
                || name.hasPrefix("Tg")
        }
        let result = TemperatureKeys(
            cpu: keys.filter {
                TemperatureSensorSelector.isCPUTemperatureKey($0.name,
                                                              platform: temperaturePlatform)
            },
            gpu: keys.filter { $0.name.hasPrefix("Tg") }
        )
        temperatureKeys = result
        return result
    }

    private func temperatureReadings(_ keys: [SMCClient.Key]) -> [(key: String, value: Double)] {
        keys.compactMap { key in
            guard let value = client.readValue(key),
                  value >= TemperatureSensorSelector.minimumChipTemperature,
                  FanControlPolicy.validTemperature(value) else { return nil }
            return (key.name, value)
        }
    }

    // MARK: - Reads and writes

    private func readings(for fans: [Fan]) throws -> [FanControlFanReading] {
        try fans.map { fan in
            guard let actual = client.readValue(fan.actual),
                  let minimum = client.readValue(fan.minimum),
                  let maximum = client.readValue(fan.maximum),
                  let target = client.readValue(fan.target),
                  FanControlPolicy.validReading(actual),
                  FanControlPolicy.validReading(target),
                  FanControlPolicy.validBounds(minimum: minimum, maximum: maximum) else {
                throw FanControlHardwareError.operationFailed
            }
            return FanControlFanReading(index: fan.index,
                                        actualRPM: max(0, actual),
                                        minimumRPM: minimum,
                                        maximumRPM: maximum,
                                        targetRPM: max(0, target),
                                        isManuallyControlled: try !FanControlPolicy.isAutomaticMode(
                                            modeValue(fan.mode)
                                        ))
        }
    }

    private func verifyCooling(_ fans: [Fan], targets: [Double], attempts: Int = 1) -> Bool {
        guard fans.count == targets.count else { return false }
        for attempt in 0..<attempts {
            guard writesAreSafe else { return false }
            let matches = zip(fans, targets).allSatisfy { fan, expected in
                guard (try? modeValue(fan.mode)) == 1,
                      let bounds = currentBounds(for: fan),
                      expected >= bounds.minimum, expected <= bounds.maximum,
                      let target = client.readValue(fan.target),
                      target >= bounds.minimum, target <= bounds.maximum else { return false }
                return FanControlPolicy.targetRPMMatches(target: target, expected: expected)
            }
            if matches { return true }
            if attempt + 1 < attempts, !waitSafely(0.05) { return false }
        }
        return false
    }

    private func modeValue(_ key: SMCClient.Key) throws -> UInt8 {
        try byteValue(key)
    }

    private func byteValue(_ key: SMCClient.Key) throws -> UInt8 {
        guard let bytes = client.readBytes(key), bytes.count == 1 else {
            throw FanControlHardwareError.operationFailed
        }
        return bytes[0]
    }

    private func setMode(_ value: UInt8, for fan: Fan, attempts: Int) -> Bool {
        guard setByte(value, for: fan.mode, attempts: attempts) else { return false }
        return (try? modeValue(fan.mode)) == value
    }

    private func setTargetRPM(_ target: Double, for fan: Fan, attempts: Int) -> Bool {
        for attempt in 0..<attempts {
            guard writesAreSafe else { return false }
            _ = writeManualPair(for: fan, target: target)
            if let currentTarget = client.readValue(fan.target),
               FanControlPolicy.targetRPMMatches(target: currentTarget, expected: target),
               (try? modeValue(fan.mode)) == 1 {
                return true
            }
            if attempt + 1 < attempts, !waitSafely(0.05) { return false }
        }
        return false
    }

    private func writeManualPair(for fan: Fan, target: Double) -> Bool {
        guard writesAreSafe, validTarget(target, for: fan) else { return false }
        do {
            // Preparar alvo válido antes de habilitar manual evita herdar alvo zero.
            try client.writeValue(target, to: fan.target)
            guard writesAreSafe else { return false }
            try client.writeBytes([1], to: fan.mode)
            guard writesAreSafe, validTarget(target, for: fan) else { return false }
            try client.writeValue(target, to: fan.target)
            return true
        } catch {
            return false
        }
    }

    private func setMode(_ value: UInt8, for fan: Fan, untilUptime deadline: TimeInterval) -> Bool {
        repeat {
            guard writesAreSafe else { return false }
            if setMode(value, for: fan, attempts: 1) { return true }
            let remaining = deadline - ProcessInfo.processInfo.systemUptime
            if remaining <= 0 { return false }
            if !waitSafely(min(0.1, remaining)) { return false }
        } while ProcessInfo.processInfo.systemUptime < deadline
        return false
    }

    private func setByte(_ value: UInt8, for key: SMCClient.Key, attempts: Int) -> Bool {
        for attempt in 0..<attempts {
            guard writesAreSafe else { return false }
            do {
                try client.writeBytes([value], to: key)
                if (try? byteValue(key)) == value { return true }
            } catch {}
            if attempt + 1 < attempts, !waitSafely(0.05) { return false }
        }
        return false
    }

    private func setTargetValue(_ value: Double, for fan: Fan, attempts: Int) -> Bool {
        for attempt in 0..<attempts {
            guard writesAreSafe, validTarget(value, for: fan) else { return false }
            do {
                try client.writeValue(value, to: fan.target)
                return true
            } catch {}
            if attempt + 1 < attempts, !waitSafely(0.05) { return false }
        }
        return false
    }

    private func currentBounds(for fan: Fan) -> (minimum: Double, maximum: Double)? {
        guard let minimum = client.readValue(fan.minimum),
              let maximum = client.readValue(fan.maximum),
              FanControlPolicy.validBounds(minimum: minimum, maximum: maximum) else { return nil }
        return (minimum, maximum)
    }

    private func validTarget(_ value: Double, for fan: Fan) -> Bool {
        guard let bounds = currentBounds(for: fan),
              let bytes = SMCValueCodec.encode(value, type: fan.target.dataType,
                                               size: Int(fan.target.dataSize)),
              let encodedValue = SMCValueCodec.decode(bytes, type: fan.target.dataType) else { return false }
        return value >= bounds.minimum && value <= bounds.maximum
            && encodedValue >= bounds.minimum && encodedValue <= bounds.maximum
    }

    private func beginWrites(shouldContinue: @escaping () -> Bool) {
        writeDeadline = ProcessInfo.processInfo.systemUptime + 15
        writeSafetyCheck = shouldContinue
    }

    private func endWrites() {
        writeDeadline = nil
        writeSafetyCheck = nil
    }

    private var writesAreSafe: Bool {
        guard let writeDeadline else { return true } // Recuperação não se cancela por pressão térmica.
        return ProcessInfo.processInfo.systemUptime < writeDeadline
            && writeSafetyCheck?() == true
    }

    private func waitSafely(_ duration: TimeInterval) -> Bool {
        let end = ProcessInfo.processInfo.systemUptime + duration
        repeat {
            guard writesAreSafe else { return false }
            let remaining = end - ProcessInfo.processInfo.systemUptime
            if remaining <= 0 { return true }
            Thread.sleep(forTimeInterval: min(0.05, remaining))
        } while true
    }

    /// Whether this Mac exposes a fan the app can actually drive. It asks the
    /// same discovery the control path uses, so "controllable" means the very
    /// keys a cooling write needs, not merely a reported fan count. Hardware
    /// does not change under a running process, so the answer is computed once.
    public static let hasControllableFan: Bool = {
        guard let hardware = FanControlHardware() else { return false }
        return (try? hardware.discoverControlledFans())?.isEmpty == false
    }()
}
