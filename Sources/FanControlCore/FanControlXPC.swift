// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Foundation
import Security

public enum FanControlIdentifiers {
    // A identidade vem da assinatura do próprio processo, nunca de defaults
    // ou da entrada IPC. Binário ad-hoc não tem Team ID e permanece rejeitado.
    public static let teamID: String = {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return "" }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess,
              let staticCode else { return "" }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation),
                                            &info) == errSecSuccess,
              let values = info as? [String: Any] else { return "" }
        return values[kSecCodeInfoTeamIdentifier as String] as? String ?? ""
    }()

    #if HEXA_DEVELOPMENT
    public static let appBundleID = "io.github.pauloborini.hexa.dev"
    #else
    public static let appBundleID = "io.github.pauloborini.hexa"
    #endif

    public static let helperID = "\(appBundleID).fan-control"
    public static let recoveryMarkerPath = "/var/run/hexa-fan-control.active"
    public static let plistName = "\(helperID).plist"

    public static let appCodeRequirement =
        "anchor apple generic and certificate leaf[subject.OU] = \"\(teamID)\" and identifier \"\(appBundleID)\""
    public static let helperCodeRequirement =
        "anchor apple generic and certificate leaf[subject.OU] = \"\(teamID)\" and identifier \"\(helperID)\""
}

@objc public protocol FanControlXPCProtocol {
    func status(withReply reply: @escaping (Data) -> Void)
    func startMaximumCooling(withReply reply: @escaping (Data) -> Void)
    func applyConfiguration(_ configuration: Data, withReply reply: @escaping (Data) -> Void)
    func heartbeat(_ includeTelemetry: Bool, withReply reply: @escaping (Data) -> Void)
    func heartbeat(withReply reply: @escaping (Data) -> Void)
    func restoreAutomatic(withReply reply: @escaping (Data) -> Void)
}

public enum FanControlIPC {
    public static let version = 1
    public static let maximumPayloadBytes = 65_536

    private struct Message<Payload: Codable>: Codable {
        let version: Int
        let payload: Payload
    }

    public static func encode(_ response: FanControlResponse) -> Data {
        (try? JSONEncoder().encode(Message(version: version, payload: response)))
            ?? Data(#"{"version":1,"payload":{"succeeded":false,"snapshot":{"fans":[],"isCooling":false,"isRecovering":true},"error":"controlFailed"}}"#.utf8)
    }

    public static func decode(_ data: Data) -> FanControlResponse? {
        guard data.count <= maximumPayloadBytes,
              let message = try? JSONDecoder().decode(Message<FanControlResponse>.self, from: data),
              message.version == version,
              message.payload.snapshot.fans.count <= FanControlPolicy.maximumFanCount,
              message.payload.snapshot.fans.allSatisfy({
                  (0..<FanControlPolicy.maximumFanCount).contains($0.index)
                      && FanControlPolicy.validReading($0.actualRPM)
                      && FanControlPolicy.validReading($0.targetRPM)
              }),
              (message.payload.snapshot.temperatures ?? []).count
                  <= FanControlTemperatureSource.allCases.count,
              (message.payload.snapshot.temperatures ?? []).allSatisfy({
                  FanControlPolicy.validTemperature($0.celsius)
              }) else { return nil }
        return message.payload
    }

    public static func encode(_ configuration: FanControlConfiguration) -> Data? {
        guard FanControlPolicy.validConfiguration(configuration) else { return nil }
        return try? JSONEncoder().encode(Message(version: version, payload: configuration))
    }

    public static func decodeConfiguration(_ data: Data) -> FanControlConfiguration? {
        guard data.count <= maximumPayloadBytes,
              let message = try? JSONDecoder().decode(Message<FanControlConfiguration>.self, from: data),
              message.version == version,
              FanControlPolicy.validConfiguration(message.payload) else { return nil }
        return message.payload
    }
}
