import XCTest
@testable import Hexa

final class PortalAutomationStatusTests: XCTestCase {
    func testPlaybackStatusMapping() {
        // AC-2.1.1: .granted -> .granted, .consent/.denied -> .missing
        XCTAssertEqual(PermissionPortalRow.playbackStatus(for: .granted), .granted)
        XCTAssertEqual(PermissionPortalRow.playbackStatus(for: .consent), .missing)
        XCTAssertEqual(PermissionPortalRow.playbackStatus(for: .denied), .missing)
    }

    func testUnreadableIsHonestNotMissing() {
        // AC-2.1.2: nil and .unavailable -> .unknown (honest label, not .missing)
        XCTAssertEqual(PermissionPortalRow.playbackStatus(for: nil), .unknown)
        XCTAssertEqual(PermissionPortalRow.playbackStatus(for: .unavailable), .unknown)
    }

    func testPlaybackSinkDelegatesToMapping() throws {
        // AC-2.1.1 / LEG1: a linha Player do portal resolve pelo estado publicado do serviço de música,
        // nunca por um literal (.unknown constante reencarnaria LEG1). O estado da view não é injetável,
        // então o sink é lido no fonte: o caso playback de status(for:) delega ao mapeamento puro.
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: repoRoot.appendingPathComponent("Sources/Hexa/UI/Settings/FeatureHubSettings.swift"),
                                encoding: .utf8)
        let statusBody = try XCTUnwrap(source.components(separatedBy: "private func status(for permission: AppPermission)")
            .dropFirst().first?.components(separatedBy: "\n    private func ").first)
        let playbackCase = try XCTUnwrap(statusBody.components(separatedBy: "case .automationPlayback:").dropFirst().first?
            .components(separatedBy: "case .").first)
        XCTAssertTrue(playbackCase.contains("PermissionPortalRow.playbackStatus(for: music.automationAvailability?.access)"),
                      "O caso playback precisa delegar ao mapeamento com a availability do serviço")
        XCTAssertFalse(playbackCase.contains("return .unknown") || playbackCase.contains("return .missing")
                       || playbackCase.contains("return .granted"), "Literal no caso playback reencarna LEG1")
    }

    func testPollingDoorStaysShut() {
        // AC-2.2.1 & AC-2.2.2: PermissionPollingSupport.interval returns nil when visibleSurfaceCount == 0,
        // even if permissions are needed and not granted
        let interval = PermissionPollingSupport.interval(
            visibleSurfaceCount: 0,
            accessibilityIsNeeded: true,
            screenRecordingIsNeeded: true,
            accessibilityIsGranted: false,
            screenRecordingIsGranted: false
        )
        XCTAssertNil(interval, "A porta de cadência deve permanecer fechada (nil) sem nenhuma superfície visível")
    }
}
