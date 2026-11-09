// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Foundation

public struct FanControlFanReading: Codable, Equatable, Identifiable, Sendable {
    public let index: Int
    public let actualRPM: Double
    public let minimumRPM: Double
    public let maximumRPM: Double
    public let targetRPM: Double
    public let isManuallyControlled: Bool

    public var id: Int { index }
}

public enum FanControlMode: String, Codable, Sendable {
    case system
    case manual
    case curve
}

public enum FanControlTemperatureSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case averageSoC
    case hottestSoC
    case averageCPU
    case hottestCPU
    case hottestGPU

    public var id: String { rawValue }
}

public struct FanControlTemperatureReading: Codable, Equatable, Sendable {
    public let source: FanControlTemperatureSource
    public let celsius: Double

    public init(source: FanControlTemperatureSource, celsius: Double) {
        self.source = source
        self.celsius = celsius
    }
}

public struct FanControlCurvePoint: Codable, Equatable, Sendable {
    public var temperature: Int
    public var coolingLevel: Int

    public init(temperature: Int, coolingLevel: Int) {
        self.temperature = temperature
        self.coolingLevel = coolingLevel
    }
}

public struct FanControlCurve: Codable, Equatable, Sendable {
    public var sensor: FanControlTemperatureSource
    public var points: [FanControlCurvePoint]

    public init(sensor: FanControlTemperatureSource, points: [FanControlCurvePoint]) {
        self.sensor = sensor
        self.points = points
    }
}

public struct FanControlConfiguration: Codable, Equatable, Sendable {
    public var mode: FanControlMode
    public var manualLevel: Int
    public var curves: [FanControlCurve]

    public init(mode: FanControlMode, manualLevel: Int, curves: [FanControlCurve]) {
        self.mode = mode
        self.manualLevel = manualLevel
        self.curves = curves
    }

    public static let defaultCurve = FanControlCurve(
        sensor: .hottestSoC,
        points: [
            FanControlCurvePoint(temperature: 50, coolingLevel: 0),
            FanControlCurvePoint(temperature: 70, coolingLevel: 100),
        ]
    )

    public static func manual(level: Int) -> FanControlConfiguration {
        FanControlConfiguration(mode: .manual, manualLevel: level,
                                curves: [])
    }

    public static func curve(_ curves: [FanControlCurve]) -> FanControlConfiguration {
        FanControlConfiguration(mode: .curve,
                                manualLevel: FanControlPolicy.defaultCoolingLevel,
                                curves: curves)
    }

    public static func encodeCurves(_ curves: [FanControlCurve]) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(curves) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func decodeCurves(_ value: String) -> [FanControlCurve]? {
        guard let data = value.data(using: .utf8),
              let curves = try? JSONDecoder().decode([FanControlCurve].self, from: data),
              FanControlPolicy.validCurves(curves) else { return nil }
        return curves
    }

    public static var defaultCurvesStorage: String {
        encodeCurves([defaultCurve]) ?? "[]"
    }
}

public struct FanControlSnapshot: Codable, Equatable, Sendable {
    public var fans: [FanControlFanReading]
    public var isCooling: Bool
    public var isRecovering: Bool = false
    public var endsAt: Date?
    public var stopReason: FanControlStopReason?
    public var coolingLevel: Int?
    public var configuration: FanControlConfiguration?
    public var temperatures: [FanControlTemperatureReading]?
    /// Confirmação de giro da sessão: `true` quando as ventoinhas controladas estão
    /// dentro da banda do alvo, `false` quando a divergência persistiu acima do
    /// limite, `nil` quando não há sessão ativa ou não há leitura para julgar.
    public var coolingSpinConfirmed: Bool?

    public init(fans: [FanControlFanReading], isCooling: Bool, endsAt: Date?,
                stopReason: FanControlStopReason?, coolingLevel: Int?,
                configuration: FanControlConfiguration?,
                temperatures: [FanControlTemperatureReading]?,
                coolingSpinConfirmed: Bool? = nil) {
        self.fans = fans
        self.isCooling = isCooling
        self.endsAt = endsAt
        self.stopReason = stopReason
        self.coolingLevel = coolingLevel
        self.configuration = configuration
        self.temperatures = temperatures
        self.coolingSpinConfirmed = coolingSpinConfirmed
    }

    public static let empty = FanControlSnapshot(fans: [], isCooling: false,
                                                 endsAt: nil, stopReason: nil,
                                                 coolingLevel: nil,
                                                 configuration: nil,
                                                 temperatures: nil)
}

public enum FanControlStopReason: String, Codable, Equatable, Sendable {
    case timeLimit
    case appDisconnected
    case heartbeatLost
    case hardwareChanged
    case thermalPressure
    case temperatureUnavailable
    case recovery
}

public enum FanControlErrorCode: String, Codable, Equatable, Error, Sendable {
    case noFans
    case unsupportedHardware
    case alreadyControlled
    case authorizationRequired
    case helperUnavailable
    case controlFailed
}

public struct FanControlResponse: Codable, Equatable, Sendable {
    public let succeeded: Bool
    public let snapshot: FanControlSnapshot
    public let error: FanControlErrorCode?

    public static func success(_ snapshot: FanControlSnapshot) -> FanControlResponse {
        FanControlResponse(succeeded: true, snapshot: snapshot, error: nil)
    }

    public static func failure(_ error: FanControlErrorCode,
                        snapshot: FanControlSnapshot = .empty) -> FanControlResponse {
        FanControlResponse(succeeded: false, snapshot: snapshot, error: error)
    }
}

public enum FanControlPolicy {
    /// Retained only for the legacy XPC entry point used by older app builds.
    public static let coolingDuration: TimeInterval = 15 * 60
    public static let heartbeatLimit: TimeInterval = 7
    public static let verificationFailureLimit = 3
    public static let temperatureFailureLimit = 3
    public static let maximumFanCount = 8
    public static let maximumSaneRPM = 20_000.0
    public static let minimumCoolingLevel = 0
    public static let maximumCoolingLevel = 100
    public static let coolingLevelStep = 5
    public static let defaultCoolingLevel = maximumCoolingLevel
    public static let minimumCurveTemperature = 20
    public static let maximumCurveTemperature = 110
    public static let minimumCurvePointCount = 2
    public static let maximumCurvePointCount = 8
    public static let maximumCurveCount = FanControlTemperatureSource.allCases.count
    public static let curveHysteresis = 2.0
    /// Piso de RPM aplicado no modo manual enquanto o piso de segurança estiver ativo.
    public static let manualSafetyFloorRPM: Double = 1200
    /// Temperatura (°C) acima da qual o piso de segurança do modo manual fica ativo.
    public static let manualSafetyFloorTemperature: Double = 50

    public static func isAutomaticMode(_ mode: UInt8) -> Bool {
        mode == 0 || mode == 3
    }

    public static func fanCount(from value: Double) -> Int? {
        guard value.isFinite else { return nil }
        let rounded = value.rounded()
        guard abs(value - rounded) < 0.001,
              rounded >= 1, rounded <= Double(maximumFanCount) else { return nil }
        let count = Int(rounded)
        return (1...maximumFanCount).contains(count) ? count : nil
    }

    public static func validBounds(minimum: Double, maximum: Double) -> Bool {
        minimum.isFinite && maximum.isFinite
            && minimum >= 0 && maximum > minimum && maximum <= maximumSaneRPM
    }

    public static func validReading(_ value: Double) -> Bool {
        value.isFinite && value >= 0 && value <= maximumSaneRPM
    }

    public static func validCoolingLevel(_ level: Int) -> Bool {
        (minimumCoolingLevel...maximumCoolingLevel).contains(level)
            && level.isMultiple(of: coolingLevelStep)
    }

    public static func targetRPMMatches(target: Double, expected: Double) -> Bool {
        target.isFinite && expected.isFinite
            && abs(target - expected) <= max(2, expected * 0.001)
    }

    /// Not every Mac exposes `Ftst`. Where it is present the unlock write has to
    /// succeed; where it is absent there is nothing to force and nothing to fail.
    public static func forceTestSatisfied(keyExists: Bool, writeSucceeded: Bool) -> Bool {
        !keyExists || writeSucceeded
    }

    public static func coolingTargetRPM(minimum: Double, maximum: Double,
                                 level: Int) -> Double? {
        guard validBounds(minimum: minimum, maximum: maximum),
              validCoolingLevel(level) else { return nil }
        return minimum + (maximum - minimum) * Double(level) / 100
    }

    /// Alvo do modo manual. Com o piso ativo, eleva o alvo até o piso limitado à
    /// faixa do ventilador; nunca reduz nem rejeita. Sem o piso, igual a `coolingTargetRPM`.
    public static func manualTargetRPM(minimum: Double, maximum: Double, level: Int,
                                       safetyFloorActive: Bool) -> Double? {
        guard let computed = coolingTargetRPM(minimum: minimum, maximum: maximum, level: level)
        else { return nil }
        guard safetyFloorActive else { return computed }
        let floorRPM = min(maximum, max(minimum, manualSafetyFloorRPM))
        return max(computed, floorRPM)
    }

    /// Piso ativo quando: a amostra não tem leitura válida (conservador); alguma
    /// leitura passa de 50 °C; ou a cobertura de CPU é esperada (`cpuCoverageExpected`)
    /// e a amostra não tem leitura de CPU (`averageCPU` ou `hottestCPU`).
    public static func safetyFloorActive(for readings: [FanControlTemperatureReading],
                                         cpuCoverageExpected: Bool) -> Bool {
        if readings.isEmpty { return true }
        if readings.contains(where: { $0.celsius > manualSafetyFloorTemperature }) { return true }
        let hasCPUReading = readings.contains { $0.source == .averageCPU || $0.source == .hottestCPU }
        return cpuCoverageExpected && !hasCPUReading
    }

    /// Corte térmico da sessão manual: os estados `serious` e `critical` exigem a
    /// devolução ao firmware; `nominal` e `fair` mantêm a sessão.
    public static func manualThermalCutoffActive(_ state: ProcessInfo.ThermalState) -> Bool {
        state == .serious || state == .critical
    }

    /// Fração do alvo que a rotação real precisa alcançar para confirmar o giro.
    public static let spinConfirmationRatio: Double = 0.6
    /// Divergências de giro consecutivas até a sessão deixar de ser confirmada.
    public static let spinConfirmationFailureLimit = 3

    /// Confirmação de giro de uma ventoinha: a rotação real alcança a banda do
    /// alvo. Alvo zero não exige giro. Leitura inválida (não finita ou negativa)
    /// não confirma.
    public static func fanSpinConfirmed(actualRPM: Double, targetRPM: Double) -> Bool {
        guard actualRPM.isFinite, targetRPM.isFinite,
              actualRPM >= 0, targetRPM >= 0 else { return false }
        guard targetRPM > 0 else { return true }
        return actualRPM >= targetRPM * spinConfirmationRatio
    }

    public static func validConfiguration(_ configuration: FanControlConfiguration) -> Bool {
        switch configuration.mode {
        case .system:
            return true
        case .manual:
            return validCoolingLevel(configuration.manualLevel)
        case .curve:
            return validCurves(configuration.curves)
        }
    }

    public static func validCurves(_ curves: [FanControlCurve]) -> Bool {
        guard (1...maximumCurveCount).contains(curves.count),
              Set(curves.map(\.sensor)).count == curves.count else { return false }
        return curves.allSatisfy(validCurve)
    }

    public static func validCurve(_ curve: FanControlCurve) -> Bool {
        guard (minimumCurvePointCount...maximumCurvePointCount).contains(curve.points.count) else {
            return false
        }
        for (index, point) in curve.points.enumerated() {
            guard (minimumCurveTemperature...maximumCurveTemperature).contains(point.temperature),
                  validCoolingLevel(point.coolingLevel) else { return false }
            if index > 0 {
                let previous = curve.points[index - 1]
                guard point.temperature > previous.temperature,
                      point.coolingLevel >= previous.coolingLevel else { return false }
            }
        }
        return true
    }

    public static func nextCurvePoint(for points: [FanControlCurvePoint]) -> FanControlCurvePoint? {
        guard points.count < maximumCurvePointCount,
              let first = points.first,
              let last = points.last else { return nil }
        var best: (index: Int, gap: Int)?
        for index in 1..<points.count {
            let gap = points[index].temperature - points[index - 1].temperature
            if gap > 1, gap > (best?.gap ?? 0) { best = (index, gap) }
        }
        if let best {
            let lower = points[best.index - 1]
            let upper = points[best.index]
            let temperature = lower.temperature + best.gap / 2
            let rawLevel = Double(lower.coolingLevel + upper.coolingLevel) / 2
            let level = Int((rawLevel / Double(coolingLevelStep)).rounded())
                * coolingLevelStep
            return FanControlCurvePoint(temperature: temperature, coolingLevel: level)
        }
        if last.temperature < maximumCurveTemperature {
            return FanControlCurvePoint(
                temperature: min(maximumCurveTemperature, last.temperature + 10),
                coolingLevel: last.coolingLevel
            )
        }
        if first.temperature > minimumCurveTemperature {
            return FanControlCurvePoint(
                temperature: max(minimumCurveTemperature, first.temperature - 10),
                coolingLevel: first.coolingLevel
            )
        }
        return nil
    }

    public static func addingCurvePoint(to points: [FanControlCurvePoint]) -> [FanControlCurvePoint]? {
        guard let point = nextCurvePoint(for: points) else { return nil }
        var updated = points
        updated.append(point)
        updated.sort { $0.temperature < $1.temperature }
        guard validCurve(FanControlCurve(sensor: .hottestSoC, points: updated)) else { return nil }
        return updated
    }

    public static func curveCoolingLevel(curves: [FanControlCurve],
                                  temperatures: [FanControlTemperatureReading],
                                  previousLevel: Int? = nil) -> Int? {
        guard let requested = evaluatedCurveCoolingLevel(curves: curves,
                                                         temperatures: temperatures) else { return nil }
        guard let previousLevel, requested < previousLevel else { return requested }
        let warmerReadings = temperatures.map {
            FanControlTemperatureReading(source: $0.source,
                                         celsius: $0.celsius + curveHysteresis)
        }
        guard let held = evaluatedCurveCoolingLevel(curves: curves,
                                                    temperatures: warmerReadings) else { return nil }
        return min(previousLevel, max(requested, held))
    }

    private static func evaluatedCurveCoolingLevel(curves: [FanControlCurve],
                                                   temperatures: [FanControlTemperatureReading]) -> Int? {
        guard validCurves(curves) else { return nil }
        let values = Dictionary(temperatures.map { ($0.source, $0.celsius) },
                                uniquingKeysWith: { _, newest in newest })
        var levels: [Int] = []
        for curve in curves {
            guard let temperature = values[curve.sensor], validTemperature(temperature) else {
                return nil
            }
            levels.append(interpolatedCoolingLevel(points: curve.points,
                                                   temperature: temperature))
        }
        return levels.max()
    }

    public static func interpolatedCoolingLevel(points: [FanControlCurvePoint],
                                         temperature: Double) -> Int {
        guard let first = points.first, let last = points.last else {
            return minimumCoolingLevel
        }
        if temperature <= Double(first.temperature) { return first.coolingLevel }
        if temperature >= Double(last.temperature) { return last.coolingLevel }
        for index in 1..<points.count {
            let upper = points[index]
            guard temperature <= Double(upper.temperature) else { continue }
            let lower = points[index - 1]
            let progress = (temperature - Double(lower.temperature))
                / Double(upper.temperature - lower.temperature)
            let raw = Double(lower.coolingLevel)
                + Double(upper.coolingLevel - lower.coolingLevel) * progress
            let stepped = Int(ceil(raw / Double(coolingLevelStep) - 1e-9))
                * coolingLevelStep
            return min(maximumCoolingLevel, max(minimumCoolingLevel, stepped))
        }
        return last.coolingLevel
    }

    public static func validTemperature(_ value: Double) -> Bool {
        value.isFinite && value >= 1 && value < 125
    }

    public static func aggregatedTemperatures(
        cpuReadings: [(key: String, value: Double)],
        gpuReadings: [Double],
        platform: CPUTemperaturePlatform
    ) -> [FanControlTemperatureReading] {
        let validCPU = cpuReadings.filter {
            $0.value >= TemperatureSensorSelector.minimumChipTemperature
                && validTemperature($0.value)
        }
        let preferredCPU = validCPU.filter {
            TemperatureSensorSelector.isCPUCoreKey($0.key, platform: platform)
        }
        let cpu: [Double]
        if TemperatureSensorSelector.hasCPUCoreSet(platform: platform) {
            cpu = preferredCPU.map(\.value)
        } else if platform == .generic {
            cpu = validCPU.map(\.value)
        } else {
            cpu = []
        }
        let gpu = gpuReadings.filter {
            $0 >= TemperatureSensorSelector.minimumChipTemperature && validTemperature($0)
        }
        return aggregatedSources(cpu: cpu, gpu: gpu)
    }

    /// Amostra de decisão do piso de segurança. Em chip mapeado e em `.generic`
    /// equivale à agregação vigente; em `.unmappedAppleSilicon` usa todas as
    /// leituras válidas de CPU como CPU e recalcula o SoC com CPU+GPU, sem
    /// alterar a agregação de exibição.
    public static func safetyFloorDecisionTemperatures(
        cpuReadings: [(key: String, value: Double)],
        gpuReadings: [Double],
        platform: CPUTemperaturePlatform
    ) -> [FanControlTemperatureReading] {
        guard platform == .unmappedAppleSilicon else {
            return aggregatedTemperatures(cpuReadings: cpuReadings,
                                          gpuReadings: gpuReadings,
                                          platform: platform)
        }
        let cpu = cpuReadings.filter {
            $0.value >= TemperatureSensorSelector.minimumChipTemperature
                && validTemperature($0.value)
        }
        let gpu = gpuReadings.filter {
            $0 >= TemperatureSensorSelector.minimumChipTemperature && validTemperature($0)
        }
        return aggregatedSources(cpu: cpu.map(\.value), gpu: gpu)
    }

    private static func aggregatedSources(cpu: [Double],
                                          gpu: [Double]) -> [FanControlTemperatureReading] {
        let soc = cpu + gpu
        var readings: [FanControlTemperatureReading] = []
        if !soc.isEmpty {
            readings.append(.init(source: .averageSoC,
                                  celsius: soc.reduce(0, +) / Double(soc.count)))
            if let hottest = soc.max() {
                readings.append(.init(source: .hottestSoC, celsius: hottest))
            }
        }
        if !cpu.isEmpty {
            readings.append(.init(source: .averageCPU,
                                  celsius: cpu.reduce(0, +) / Double(cpu.count)))
            if let hottest = cpu.max() {
                readings.append(.init(source: .hottestCPU, celsius: hottest))
            }
        }
        if let hottest = gpu.max() {
            readings.append(.init(source: .hottestGPU, celsius: hottest))
        }
        return readings
    }

    public static func telemetryReadings(expectedCount: Int,
                                  readings: [Double?]) -> [Double]? {
        guard (1...maximumFanCount).contains(expectedCount),
              readings.count == expectedCount else { return nil }
        let values = readings.compactMap { $0 }
        guard values.count == expectedCount,
              values.allSatisfy(validReading) else { return nil }
        return values
    }

    public static func menuBarValue(for speeds: [Double]) -> String? {
        guard !speeds.isEmpty, speeds.allSatisfy(validReading) else { return nil }
        return speeds.map { String(Int($0.rounded())) }.joined(separator: "/")
    }

    public static func menuBarWidthUnits(fanCount: Int) -> Int {
        guard (1...maximumFanCount).contains(fanCount) else { return 0 }
        return 7 + fanCount * 5 + (fanCount - 1)
    }

    /// Sessão expirada pelo relógio de uptime. Sem prazo, nunca expira; no
    /// instante exato do prazo já conta como expirada, igual a `restoreReason`.
    public static func sessionExpired(nowUptime: TimeInterval,
                                      endsAtUptime: TimeInterval?) -> Bool {
        guard let endsAtUptime else { return false }
        return nowUptime >= endsAtUptime
    }

    public static func restoreReason(now: Date,
                              endsAt: Date?,
                              heartbeatAge: TimeInterval,
                              verificationFailures: Int,
                              temperatureFailures: Int = 0) -> FanControlStopReason? {
        if let endsAt, now >= endsAt { return .timeLimit }
        if heartbeatAge > heartbeatLimit { return .heartbeatLost }
        if verificationFailures >= verificationFailureLimit { return .hardwareChanged }
        if temperatureFailures >= temperatureFailureLimit { return .temperatureUnavailable }
        return nil
    }

    /// Conta amostras de temperatura consecutivas sem leitura útil.
    /// Uma leitura útil zera a contagem; cada tick sem leitura soma 1.
    public static func nextTemperatureFailures(previous: Int, hasUsableReading: Bool) -> Int {
        hasUsableReading ? 0 : previous + 1
    }
}

public enum SMCValueCodec {
    public static func decode(_ bytes: [UInt8], type: String) -> Double? {
        switch type {
        case "flt " where bytes.count == 4:
            let bits = UInt32(bytes[0])
                | UInt32(bytes[1]) << 8
                | UInt32(bytes[2]) << 16
                | UInt32(bytes[3]) << 24
            let value = Double(Float32(bitPattern: bits))
            return value.isFinite ? value : nil
        case "fpe2" where bytes.count == 2:
            let raw = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
            return Double(raw) / 4.0
        case "sp78" where bytes.count == 2:
            let raw = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
            return Double(Int16(bitPattern: raw)) / 256.0
        case "ui8 " where bytes.count == 1:
            return Double(bytes[0])
        case "ui16" where bytes.count == 2:
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        case "ui32" where bytes.count == 4:
            return Double(UInt32(bytes[0]) << 24
                          | UInt32(bytes[1]) << 16
                          | UInt32(bytes[2]) << 8
                          | UInt32(bytes[3]))
        case "ioft" where bytes.count == 8:
            var raw: UInt64 = 0
            for (offset, byte) in bytes.enumerated() {
                raw |= UInt64(byte) << UInt64(offset * 8)
            }
            return Double(raw) / 65_536.0
        default:
            return nil
        }
    }

    public static func encode(_ value: Double, type: String, size: Int) -> [UInt8]? {
        guard value.isFinite, value >= 0 else { return nil }
        switch type {
        case "flt " where size == 4:
            let float = Float32(value)
            guard float.isFinite else { return nil }
            let bits = float.bitPattern
            return [UInt8(bits & 0xff), UInt8((bits >> 8) & 0xff),
                    UInt8((bits >> 16) & 0xff), UInt8((bits >> 24) & 0xff)]
        case "fpe2" where size == 2:
            let scaled = (value * 4).rounded()
            guard scaled <= Double(UInt16.max) else { return nil }
            let raw = UInt16(scaled)
            return [UInt8((raw >> 8) & 0xff), UInt8(raw & 0xff)]
        case "ui8 " where size == 1:
            guard value.rounded() == value, value <= Double(UInt8.max) else { return nil }
            return [UInt8(value)]
        case "ui16" where size == 2:
            guard value.rounded() == value, value <= Double(UInt16.max) else { return nil }
            let raw = UInt16(value)
            return [UInt8((raw >> 8) & 0xff), UInt8(raw & 0xff)]
        case "ui32" where size == 4:
            guard value.rounded() == value, value <= Double(UInt32.max) else { return nil }
            let raw = UInt32(value)
            return [UInt8((raw >> 24) & 0xff), UInt8((raw >> 16) & 0xff),
                    UInt8((raw >> 8) & 0xff), UInt8(raw & 0xff)]
        default:
            return nil
        }
    }
}
