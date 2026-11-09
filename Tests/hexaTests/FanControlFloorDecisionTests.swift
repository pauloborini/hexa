// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

import FanControlCore

/// Pina a derivação da cobertura de CPU esperada e a amostra de decisão do
/// piso de segurança.
///
/// O chip não mapeado expõe os sensores de CPU, mas o app não tem o mapa por
/// família. A decisão do piso não pode herdar a cobertura do modo anterior nem
/// descartar a leitura de CPU descoberta: ela lê a amostra de decisão e
/// reavalia o piso com ela.
final class FanControlFloorDecisionTests: XCTestCase {
    // MARK: - unmapped coverage cases

    /// Chip não mapeado com chaves de CPU descobertas: a cobertura é esperada,
    /// mesmo sem mapa de núcleos por família.
    func testUnmappedPlatformExpectsCoverageWhenCPUKeysAreDiscovered() {
        XCTAssertTrue(TemperatureSensorSelector.cpuCoverageExpected(
            discoveredCPUKeys: ["Tp01", "Tp05"], platform: .unmappedAppleSilicon))
    }

    /// Sem nenhuma chave de CPU descoberta, não há cobertura a esperar.
    func testUnmappedPlatformDoesNotExpectCoverageWithoutDiscoveredKeys() {
        XCTAssertFalse(TemperatureSensorSelector.cpuCoverageExpected(
            discoveredCPUKeys: [], platform: .unmappedAppleSilicon))
    }

    /// Chip com mapa de núcleos: só uma chave da família mapeada conta.
    func testMappedPlatformExpectsCoverageOnlyForMappedCoreKey() {
        XCTAssertTrue(TemperatureSensorSelector.cpuCoverageExpected(
            discoveredCPUKeys: ["Tp00"], platform: .appleM5Family))
        XCTAssertFalse(TemperatureSensorSelector.cpuCoverageExpected(
            discoveredCPUKeys: ["Tp09"], platform: .appleM5Family))
    }

    /// Plataforma genérica: a cobertura vem da existência de chave de CPU.
    func testGenericPlatformExpectsCoverageOnlyWithDiscoveredKeys() {
        XCTAssertTrue(TemperatureSensorSelector.cpuCoverageExpected(
            discoveredCPUKeys: ["Tp01"], platform: .generic))
        XCTAssertFalse(TemperatureSensorSelector.cpuCoverageExpected(
            discoveredCPUKeys: [], platform: .generic))
    }

    // MARK: - floor decision sample cases

    /// A amostra de decisão em chip não mapeado mantém a leitura de CPU
    /// descoberta: sem ela, a amostra cairia para só GPU e o piso perderia a
    /// leitura quente do processador.
    func testUnmappedDecisionSampleKeepsDiscoveredCPUReadings() {
        let sample = FanControlPolicy.safetyFloorDecisionTemperatures(
            cpuReadings: [(key: "Tp0X", value: 62)],
            gpuReadings: [30],
            platform: .unmappedAppleSilicon
        )

        XCTAssertEqual(cpuReading(sample, .hottestCPU), 62)
        XCTAssertEqual(cpuReading(sample, .averageCPU), 62)
        // O SoC da decisão soma CPU e GPU.
        XCTAssertEqual(cpuReading(sample, .hottestSoC), 62)
    }

    /// Amostra quente com cobertura esperada: o piso sobe o alvo manual para
    /// 1200 RPM. É esta afirmação que separa "decisão lida da amostra" de
    /// "herança do estado anterior".
    func testUnmappedHotCPUActivatesFloorAndRaisesManualTarget() throws {
        let sample = FanControlPolicy.safetyFloorDecisionTemperatures(
            cpuReadings: [(key: "Tp0X", value: 62)],
            gpuReadings: [30],
            platform: .unmappedAppleSilicon
        )
        let coverage = TemperatureSensorSelector.cpuCoverageExpected(
            discoveredCPUKeys: ["Tp0X"], platform: .unmappedAppleSilicon)

        XCTAssertTrue(FanControlPolicy.safetyFloorActive(for: sample,
                                                          cpuCoverageExpected: coverage))
        let target = try XCTUnwrap(FanControlPolicy.manualTargetRPM(
            minimum: 0, maximum: 6000, level: 0, safetyFloorActive: true))
        XCTAssertEqual(target, 1200)
    }

    /// Chave de CPU descoberta que não lê: a leitura é descartada, a cobertura
    /// permanece esperada e o piso continua ativo por falta de leitura de CPU.
    func testUnmappedUnreadableCPUKeepsFloorActive() throws {
        let sample = FanControlPolicy.safetyFloorDecisionTemperatures(
            cpuReadings: [],
            gpuReadings: [30],
            platform: .unmappedAppleSilicon
        )
        let coverage = TemperatureSensorSelector.cpuCoverageExpected(
            discoveredCPUKeys: ["Tp0X"], platform: .unmappedAppleSilicon)

        XCTAssertNil(cpuReading(sample, .hottestCPU))
        XCTAssertTrue(FanControlPolicy.safetyFloorActive(for: sample,
                                                          cpuCoverageExpected: coverage))
        let target = try XCTUnwrap(FanControlPolicy.manualTargetRPM(
            minimum: 0, maximum: 6000, level: 0, safetyFloorActive: true))
        XCTAssertEqual(target, 1200)
    }

    /// Em plataforma mapeada e genérica, a amostra de decisão equivale à
    /// agregação vigente.
    func testMappedDecisionSampleMatchesCurrentAggregation() {
        let cpu: [(key: String, value: Double)] = [(key: "Tp00", value: 55),
                                                    (key: "Tp04", value: 48)]
        let gpu = [40.0]

        XCTAssertEqual(
            FanControlPolicy.safetyFloorDecisionTemperatures(
                cpuReadings: cpu, gpuReadings: gpu, platform: .appleM5Family),
            FanControlPolicy.aggregatedTemperatures(
                cpuReadings: cpu, gpuReadings: gpu, platform: .appleM5Family)
        )
        XCTAssertEqual(
            FanControlPolicy.safetyFloorDecisionTemperatures(
                cpuReadings: cpu, gpuReadings: gpu, platform: .generic),
            FanControlPolicy.aggregatedTemperatures(
                cpuReadings: cpu, gpuReadings: gpu, platform: .generic)
        )
    }

    // MARK: - display aggregation pin

    /// A agregação de exibição não muda: em chip não mapeado ela segue sem
    /// leitura de CPU, com o SoC vindo só da GPU.
    func testUnmappedDisplayAggregationKeepsCPUOut() {
        let readings = FanControlPolicy.aggregatedTemperatures(
            cpuReadings: [(key: "Tp0X", value: 62)],
            gpuReadings: [30],
            platform: .unmappedAppleSilicon
        )

        XCTAssertNil(cpuReading(readings, .averageCPU))
        XCTAssertNil(cpuReading(readings, .hottestCPU))
        XCTAssertEqual(cpuReading(readings, .hottestSoC), 30)
    }

    // MARK: - Helpers

    private func cpuReading(_ readings: [FanControlTemperatureReading],
                            _ source: FanControlTemperatureSource) -> Double? {
        readings.first { $0.source == source }?.celsius
    }
}
