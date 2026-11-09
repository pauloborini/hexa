// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Foundation

struct PortManagerEntry: Identifiable, Equatable {
    let port: Int
    let protocolName: String
    let address: String
    let pid: Int32
    let processName: String
    let startedAt: UInt64?
    var id: String { "\(protocolName)-\(port)-\(pid)-\(address)" }
    /// Executable path read with the start time. Present only together with `startedAt`.
    var path: String? = nil
    /// No start time was read, so the row cannot be terminated from the page.
    var identityUnavailable: Bool { startedAt == nil }
}

enum PortManagerSupport {
    static func browserURL(for entry: PortManagerEntry) -> URL? {
        guard entry.protocolName == "TCP", (1...65535).contains(entry.port),
              let separator = entry.address.lastIndex(of: ":") else { return nil }
        var host = String(entry.address[..<separator])
        // lsof may wrap an IPv6 host in brackets, and may add a zone such as
        // `%lo0`. The zone is a local interface scope and not part of the URL.
        if host.hasPrefix("["), host.hasSuffix("]") {
            host = String(host.dropFirst().dropLast())
        }
        if let zone = host.firstIndex(of: "%") {
            host = String(host[..<zone])
        }
        guard !host.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "http"
        // Wildcard binds are not destinations. Preserve the address family
        // when it is known, and a specific bind when localhost cannot reach it.
        switch host {
        case "*": components.host = "localhost"
        case "0.0.0.0": components.host = "127.0.0.1"
        case "::": components.host = "[::1]"
        default:
            if host.contains(":") {
                components.host = "[\(host)]"
            } else {
                components.host = host
            }
        }
        components.port = entry.port
        return components.url
    }

    /// Whether an lsof endpoint such as `*:3000` or `127.0.0.1:3000` is bound
    /// to every interface rather than one specific address. A wildcard bind
    /// accepts connections from other machines on the network unless a
    /// firewall stops them, so it is worth pointing out.
    static func listensOnAllInterfaces(_ endpoint: String) -> Bool {
        guard let separator = endpoint.lastIndex(of: ":") else { return false }
        var host = endpoint[..<separator]
        if host.hasPrefix("["), host.hasSuffix("]") {
            host = host.dropFirst().dropLast()
        }
        return host == "*" || host == "0.0.0.0" || host == "::"
    }

    /// Whether the lsof `c` name is the executable's name as lsof reports it:
    /// the basename, cut to its first 31 bytes when longer (observed with
    /// `+c0`). A mismatch leaves the row without an identity.
    static func processNameMatches(_ name: String, executablePath: String) -> Bool {
        let basename = (executablePath as NSString).lastPathComponent
        return !name.isEmpty && name.utf8.elementsEqual(basename.utf8.prefix(31))
    }

    /// lsof exits 1 both when nothing listens (no output) and when it fails
    /// (an error message and no process field). Only the second is a failure.
    /// A warning printed next to real rows still yields those rows, and a
    /// warning alone is not an error.
    static func lsofFailed(status: Int32, output: String) -> Bool {
        guard status != 0 else { return false }
        let lines = output.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("lsof: WARNING") }
        return !lines.isEmpty && !lines.contains { $0.hasPrefix("p") }
    }

    static func parseLsof(_ text: String) -> [PortManagerEntry] {
        var name = "", pid: Int32 = 0, address = "", port = 0, proto = "TCP"
        var rows: [PortManagerEntry] = []
        var seen = Set<String>()
        for line in text.split(separator: "\n").map(String.init) {
            guard let type = line.first else { continue }
            let value = String(line.dropFirst())
            switch type {
            case "p":
                pid = Int32(value) ?? 0
                port = 0
                address = ""
                name = ""
                proto = "TCP"
            case "c": name = value
            case "P": proto = value
            case "n":
                address = value
                guard let last = value.split(separator: ":").last, let parsed = Int(last) else {
                    port = 0
                    continue
                }
                port = parsed
                if pid > 0 && (1...65535).contains(port) {
                    let key = "\(proto)|\(port)|\(address)|\(pid)"
                    if seen.insert(key).inserted {
                        rows.append(.init(port: port, protocolName: proto, address: address,
                                          pid: pid, processName: name, startedAt: nil))
                    }
                }
            case "T": continue
            default: continue
            }
        }
        return rows.sorted { $0.port == $1.port ? $0.processName < $1.processName : $0.port < $1.port }
    }
}
