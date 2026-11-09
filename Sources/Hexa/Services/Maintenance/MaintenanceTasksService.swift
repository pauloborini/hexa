// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import Combine
import Foundation

enum MaintenanceTaskID: String, CaseIterable, Identifiable {
    case flushDNS
    case freePurgeable
    case purgeInactiveMemory
    case rebuildLaunchServices
    case rebuildSpotlight
    case cleanupHomebrew

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .flushDNS: return "network"
        case .freePurgeable: return "internaldrive"
        case .purgeInactiveMemory: return "memorychip"
        case .rebuildLaunchServices: return "app.badge"
        case .rebuildSpotlight: return "magnifyingglass"
        case .cleanupHomebrew: return "cup.and.saucer"
        }
    }

    /// Tarefas que apagam dados ou pesam por horas: nascem desmarcadas e
    /// passam por confirmação que diz o efeito.
    var isDestructive: Bool {
        switch self {
        case .freePurgeable, .rebuildSpotlight, .cleanupHomebrew: return true
        case .flushDNS, .purgeInactiveMemory, .rebuildLaunchServices: return false
        }
    }
}

enum MaintenanceTaskStatus: Equatable {
    case idle
    case running
    case success
    case failure
    case cancelled
    /// Rodou sem erro, mas não havia o que remover.
    case nothingFreed
}

struct MaintenanceTaskItem: Identifiable {
    let id: MaintenanceTaskID
    var isSelected: Bool = true
    var status: MaintenanceTaskStatus = .idle
    var detail: String?
}

/// Serviço de tarefas de manutenção do sistema.
/// Execução estritamente sob demanda (DEC-002), disparada pelo usuário.
final class MaintenanceTasksService: ObservableObject {
    static let shared = MaintenanceTasksService()

    @Published private(set) var items: [MaintenanceTaskItem] = []
    @Published private(set) var isRunning = false
    /// Snapshots locais do Time Machine em `/`, o único espaço que a tarefa
    /// remove; nil enquanto não medido ou quando a leitura falha.
    @Published private(set) var localSnapshotCount: Int?
    /// Leitura dos snapshots em andamento; a linha mostra espera só enquanto não há contagem.
    @Published private(set) var isReadingLocalSnapshots = false
    @Published private(set) var lastAnalysis: Date?
    /// Lote em andamento e pedido de parada; a parada vale entre tarefas.
    @Published private(set) var isRunningBatch = false
    @Published private(set) var stopRequested = false
    private let stopLock = NSLock()
    private var stopFlag = false

    private let workQueue = DispatchQueue(label: "com.hexa.maintenanceTasks", qos: .userInitiated)

    private init() {
        resetItems()
    }

    /// Reinicia o status das tarefas e reavalia estimativas sob demanda.
    func reanalyze() {
        guard !isRunning else { return }
        resetItems()
        refreshLocalSnapshots()
        lastAnalysis = Date()
    }

    func resetItems() {
        let hasBrew = HomebrewManager.shared.brewPath != nil
        var tasks: [MaintenanceTaskID] = [
            .flushDNS,
            .freePurgeable,
            .purgeInactiveMemory,
            .rebuildLaunchServices,
            .rebuildSpotlight,
        ]
        if hasBrew {
            tasks.append(.cleanupHomebrew)
        }
        // A reanalysis keeps the snapshot count on screen until the new reading lands.
        let previousDetail = items.first(where: { $0.id == .freePurgeable })?.detail
        items = tasks.map { id in
            MaintenanceTaskItem(id: id, isSelected: !id.isDestructive,
                                detail: id == .freePurgeable ? previousDetail : nil)
        }
    }

    /// Conta sob demanda os snapshots locais que "Liberar espaço purgável"
    /// remove. O restante do purgável o macOS libera sozinho e fica fora.
    func refreshLocalSnapshots() {
        // Also reached from the background run of a purge: publish on the main queue.
        DispatchQueue.main.async { [weak self] in self?.isReadingLocalSnapshots = true }
        workQueue.async { [weak self] in
            let count = Self.currentLocalSnapshotCount()
            DispatchQueue.main.async {
                self?.isReadingLocalSnapshots = false
                self?.localSnapshotCount = count
                if let index = self?.items.firstIndex(where: { $0.id == .freePurgeable }) {
                    let strings = FeatureStrings.maintenanceTasks(L10n.shared.language)
                    self?.items[index].detail = count.map {
                        $0 == 0 ? strings.noLocalSnapshots : String(format: strings.localSnapshotsFormat, $0)
                    }
                }
            }
        }
    }

    private static func currentLocalSnapshotCount() -> Int? {
        let result = Shell.run("/usr/bin/tmutil", ["listlocalsnapshots", "/"], timeout: 10)
        guard result.status == 0 else { return nil }
        return localSnapshotCount(inListing: result.output)
    }

    /// `tmutil listlocalsnapshots /` imprime um cabeçalho e uma linha por snapshot.
    static func localSnapshotCount(inListing output: String) -> Int {
        output.split(whereSeparator: \.isNewline)
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("com.apple.TimeMachine.") }
            .count
    }

    func toggleSelection(for id: MaintenanceTaskID) {
        guard !isRunning, let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isSelected.toggle()
    }

    /// Executa uma tarefa individual sob demanda.
    func runTask(_ id: MaintenanceTaskID) {
        guard !isRunning, let index = items.firstIndex(where: { $0.id == id }) else { return }
        isRunning = true
        items[index].status = .running

        workQueue.async { [weak self] in
            guard let self = self else { return }
            let outcome = self.executeCommand(for: id)
            DispatchQueue.main.async {
                if let idx = self.items.firstIndex(where: { $0.id == id }) {
                    self.items[idx].status = outcome
                }
                self.isRunning = false
            }
        }
    }

    /// Executa todas as tarefas selecionadas sequencialmente sob demanda.
    func runSelected() {
        guard !isRunning else { return }
        let selectedIDs = items.filter(\.isSelected).map(\.id)
        guard !selectedIDs.isEmpty else { return }

        isRunning = true
        isRunningBatch = true
        stopLock.withLock { stopFlag = false }
        for id in selectedIDs {
            if let idx = items.firstIndex(where: { $0.id == id }) {
                items[idx].status = .running
            }
        }

        workQueue.async { [weak self] in
            guard let self = self else { return }
            for (offset, id) in selectedIDs.enumerated() {
                if self.stopLock.withLock({ self.stopFlag }) {
                    // As que não começaram voltam a aguardar.
                    let skipped = selectedIDs[offset...]
                    DispatchQueue.main.async {
                        for idx in self.items.indices where skipped.contains(self.items[idx].id) {
                            self.items[idx].status = .idle
                        }
                    }
                    break
                }
                let outcome = self.executeCommand(for: id)
                DispatchQueue.main.async {
                    if let idx = self.items.firstIndex(where: { $0.id == id }) {
                        self.items[idx].status = outcome
                    }
                }
            }
            DispatchQueue.main.async {
                self.isRunning = false
                self.isRunningBatch = false
                self.stopRequested = false
            }
        }
    }

    /// Pede a parada do lote: a tarefa em curso termina e as seguintes não começam.
    func stopAfterCurrent() {
        guard isRunningBatch, !stopRequested else { return }
        stopLock.withLock { stopFlag = true }
        stopRequested = true
    }

    private func executeCommand(for id: MaintenanceTaskID) -> MaintenanceTaskStatus {
        switch id {
        case .flushDNS:
            // O cache do Directory Services e o do mDNSResponder, que é o que
            // os apps consultam; o segundo só reinicia como administrador.
            let prompt = FeatureStrings.maintenanceTasks(L10n.shared.language).taskFlushDNSAdminPrompt
            switch AdminShell.runSyncOutcome(
                "/usr/bin/dscacheutil -flushcache && /usr/bin/killall -HUP mDNSResponder",
                prompt: prompt) {
            case .granted: return .success
            case .cancelled: return .cancelled
            case .failed: return .failure
            }

        case .freePurgeable:
            // Sucesso só quando algum snapshot local saiu de fato.
            defer { refreshLocalSnapshots() }
            guard let before = Self.currentLocalSnapshotCount() else { return .failure }
            guard before > 0 else { return .nothingFreed }
            let result = Shell.run(
                "/usr/bin/tmutil",
                ["thinlocalsnapshots", "/", "10000000000", "4"],
                timeout: 30
            )
            guard result.status == 0 else { return .failure }
            guard let after = Self.currentLocalSnapshotCount() else { return .failure }
            return after < before ? .success : .nothingFreed

        case .purgeInactiveMemory:
            let prompt = FeatureStrings.maintenanceTasks(L10n.shared.language).taskPurgeMemoryAdminPrompt
            switch AdminShell.runSyncOutcome("/usr/sbin/purge", prompt: prompt) {
            case .granted: return .success
            case .cancelled: return .cancelled
            case .failed: return .failure
            }

        case .rebuildLaunchServices:
            let lsregisterPath = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
            // `-seed` alone acts only on a database that was never seeded.
            // `-f` registers every app in the domains again and `-gc` drops the
            // records of apps that are gone, which is what clears the duplicates.
            // No `-delete`: the database stays in place and no restart is needed.
            let result = Shell.run(
                lsregisterPath,
                ["-gc", "-f", "-r", "-all", "local,system,user"],
                timeout: 5 * 60
            )
            return result.status == 0 ? .success : .failure

        case .rebuildSpotlight:
            let prompt = FeatureStrings.maintenanceTasks(L10n.shared.language).taskSpotlightAdminPrompt
            switch AdminShell.runSyncOutcome("/usr/bin/mdutil -E /", prompt: prompt) {
            case .granted: return .success
            case .cancelled: return .cancelled
            case .failed: return .failure
            }

        case .cleanupHomebrew:
            guard let brewPath = HomebrewCommandBuilder.trustedBrewPath() else {
                return .failure
            }
            // Same lane and environment as every other brew command (DEC-004):
            // never alongside an upgrade, and on the cache the person configured.
            // A large cache takes minutes, so the limit only stops a hung run.
            let result = HomebrewManager.lane.sync {
                BoundedProcessRunner.run(brewPath, ["cleanup", "-s", "--prune=all"],
                                         timeout: 10 * 60,
                                         maxOutputBytes: 4 * 1024 * 1024,
                                         environment: HomebrewEnvironment.forBrew)
            }
            return result.status == 0 ? .success : .failure
        }
    }
}
