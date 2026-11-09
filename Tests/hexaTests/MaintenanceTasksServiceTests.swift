// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

final class MaintenanceTasksServiceTests: XCTestCase {

    func testInitialItemsCountAndSelection() {
        let service = MaintenanceTasksService.shared
        service.resetItems()
        XCTAssertFalse(service.items.isEmpty)
        XCTAssertTrue(service.items.contains { $0.id == .flushDNS })
        XCTAssertTrue(service.items.contains { $0.id == .freePurgeable })
        XCTAssertTrue(service.items.contains { $0.id == .purgeInactiveMemory })
        XCTAssertTrue(service.items.contains { $0.id == .rebuildLaunchServices })
        XCTAssertTrue(service.items.contains { $0.id == .rebuildSpotlight })

        // ISSUE-205: desbaste, Spotlight e Homebrew nascem desmarcados; o resto, marcado
        for item in service.items {
            XCTAssertEqual(item.isSelected, !item.id.isDestructive, "Task \(item.id) initial selection")
            XCTAssertEqual(item.status, .idle)
        }
    }

    func testToggleSelection() {
        let service = MaintenanceTasksService.shared
        service.resetItems()

        guard let firstID = service.items.first?.id else {
            XCTFail("Items should not be empty")
            return
        }

        service.toggleSelection(for: firstID)
        let toggled = service.items.first { $0.id == firstID }?.isSelected
        XCTAssertEqual(toggled, false)

        service.toggleSelection(for: firstID)
        let toggledBack = service.items.first { $0.id == firstID }?.isSelected
        XCTAssertEqual(toggledBack, true)
    }

    func testTaskIDsHaveNonEmptySymbols() {
        for id in MaintenanceTaskID.allCases {
            XCTAssertFalse(id.symbolName.isEmpty)
        }
    }

    func testRefreshLocalSnapshotsDoesNotCrash() {
        MaintenanceTasksService.shared.refreshLocalSnapshots()
    }

    // ISSUE-196: a tarefa mede só os snapshots locais que remove.
    func testLocalSnapshotCountReadsOnlySnapshotLines() {
        XCTAssertEqual(MaintenanceTasksService.localSnapshotCount(inListing: "Snapshots for disk /:\n"), 0)
        let listing = """
            Snapshots for disk /:
            com.apple.TimeMachine.2026-10-21-101500.local
            com.apple.TimeMachine.2026-10-22-091200.local
            """
        XCTAssertEqual(MaintenanceTasksService.localSnapshotCount(inListing: listing), 2)
    }

    func testAllLanguagesHaveNonEmptyStrings() {
        for lang in AppLanguage.allCases {
            let s = FeatureStrings.maintenanceTasks(lang)
            XCTAssertFalse(s.pageTitle.isEmpty)
            XCTAssertFalse(s.pageSubtitle.isEmpty)
            XCTAssertFalse(s.executeButton.isEmpty)
            XCTAssertFalse(s.runSelectedButton.isEmpty)
            XCTAssertFalse(s.selectedCountFormat.isEmpty)
            XCTAssertFalse(s.statusSuccess.isEmpty)
            XCTAssertFalse(s.statusFailed.isEmpty)
            XCTAssertFalse(s.statusCancelled.isEmpty)
            XCTAssertFalse(s.statusDNSFlushed.isEmpty)
            XCTAssertFalse(s.statusPurgeableFreed.isEmpty)
            XCTAssertFalse(s.statusNothingFreed.isEmpty)
            XCTAssertFalse(s.noLocalSnapshots.isEmpty)
            XCTAssertFalse(s.taskFlushDNSAdminPrompt.isEmpty)
            XCTAssertFalse(s.statusMemoryFreed.isEmpty)
            XCTAssertFalse(s.statusLaunchServicesRebuilt.isEmpty)
            XCTAssertFalse(s.statusSpotlightReindexed.isEmpty)
            XCTAssertFalse(s.statusHomebrewCleaned.isEmpty)
            XCTAssertFalse(s.taskPurgeMemoryAdminPrompt.isEmpty)
            XCTAssertFalse(s.taskSpotlightAdminPrompt.isEmpty)
            XCTAssertFalse(s.reanalyzeButton.isEmpty)
            XCTAssertFalse(s.lastAnalysisFormat.isEmpty)
            XCTAssertFalse(s.neverAnalyzed.isEmpty)
            XCTAssertFalse(s.confirmRunTitle.isEmpty)
            XCTAssertFalse(s.stopButton.isEmpty)
            XCTAssertFalse(s.effectFreePurgeable.isEmpty)
            XCTAssertFalse(s.effectSpotlight.isEmpty)
            XCTAssertFalse(s.effectHomebrew.isEmpty)
        }
    }

    func testReanalyzeResetsItemsAndUpdatesLastAnalysis() {
        let service = MaintenanceTasksService.shared
        service.resetItems()

        // Modify first item to simulate execution
        if let firstID = service.items.first?.id {
            service.toggleSelection(for: firstID)
        }

        service.reanalyze()
        XCTAssertNotNil(service.lastAnalysis)
        for item in service.items {
            XCTAssertEqual(item.isSelected, !item.id.isDestructive, "Selection returns to the default after reanalyze")
            XCTAssertEqual(item.status, .idle, "All items should be idle after reanalyze")
        }
    }
}
