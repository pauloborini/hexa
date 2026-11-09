// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import Darwin
import Foundation

/// Keeps update feed hosts on public addresses. A host passes only when it
/// resolves to at least one address and every resolved address is public.
enum AppUpdateFeedAddressGuard {
    typealias Resolver = (String) -> [String]?

    static func allowsHost(_ host: String,
                           resolve: Resolver = AppUpdateFeedAddressGuard.systemAddresses) -> Bool {
        guard let addresses = resolve(host), !addresses.isEmpty else { return false }
        return addresses.allSatisfy { isPublicAddress($0) }
    }

    /// Classifies a numeric IPv4 or IPv6 address. Anything unparsable is not public.
    static func isPublicAddress(_ address: String) -> Bool {
        var ipv4 = in_addr()
        if inet_pton(AF_INET, address, &ipv4) == 1 {
            return isPublicIPv4(withUnsafeBytes(of: ipv4) { Array($0) })
        }
        var ipv6 = in6_addr()
        guard inet_pton(AF_INET6, address, &ipv6) == 1 else { return false }
        let bytes = withUnsafeBytes(of: ipv6) { Array($0) }
        // ::ffff:0:0/96 and the NAT64 prefix 64:ff9b::/96 are classified by
        // the embedded IPv4 address, so a synthesized private address stays out.
        if bytes[0..<10].allSatisfy({ $0 == 0 }), bytes[10] == 0xff, bytes[11] == 0xff {
            return isPublicIPv4(Array(bytes[12..<16]))
        }
        if bytes[0..<4] == [0x00, 0x64, 0xff, 0x9b], bytes[4..<12].allSatisfy({ $0 == 0 }) {
            return isPublicIPv4(Array(bytes[12..<16]))
        }
        // 6to4 (2002::/16) carries its IPv4 relay address right after the prefix.
        if bytes[0] == 0x20, bytes[1] == 0x02 {
            return isPublicIPv4(Array(bytes[2..<6]))
        }
        // ::/96 covers the unspecified, loopback and deprecated IPv4-compatible forms.
        let ipv4Compatible = bytes[0..<12].allSatisfy { $0 == 0 }
        let uniqueLocal = (bytes[0] & 0xfe) == 0xfc
        let linkLocal = bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80
        let multicast = bytes[0] == 0xff
        let documentation = bytes[0..<4] == [0x20, 0x01, 0x0d, 0xb8]
        return !(ipv4Compatible || uniqueLocal || linkLocal || multicast || documentation)
    }

    /// URLSession resolves the host again on its own, so the answer checked by
    /// `allowsHost` may not be the peer it connects to (DNS rebinding). Every
    /// transaction that reached the network must name a public peer. A proxy
    /// hop resolves the host itself, so only its own address is not judged here.
    static func connectedPeersArePublic(_ metrics: URLSessionTaskMetrics) -> Bool {
        metrics.transactionMetrics.allSatisfy { transaction in
            guard transaction.resourceFetchType == .networkLoad,
                  !transaction.isProxyConnection else { return true }
            return transaction.remoteAddress.map(isPublicAddress) ?? false
        }
    }

    /// Resolves the host with the system resolver. Returns nil on any failure
    /// or when an address of an unexpected family is returned.
    static func systemAddresses(_ host: String) -> [String]? {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        var list: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &list) == 0, let first = list else { return nil }
        defer { freeaddrinfo(first) }
        var addresses: [String] = []
        var node: UnsafeMutablePointer<addrinfo>? = first
        while let current = node {
            guard let address = current.pointee.ai_addr, let text = numericAddress(address) else { return nil }
            addresses.append(text)
            node = current.pointee.ai_next
        }
        return addresses
    }

    private static func numericAddress(_ address: UnsafePointer<sockaddr>) -> String? {
        var text = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        let converted: Bool
        switch Int32(address.pointee.sa_family) {
        case AF_INET:
            var ip = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
            converted = inet_ntop(AF_INET, &ip, &text, socklen_t(text.count)) != nil
        case AF_INET6:
            var ip = address.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee.sin6_addr }
            converted = inet_ntop(AF_INET6, &ip, &text, socklen_t(text.count)) != nil
        default:
            return nil
        }
        return converted ? String(cString: text) : nil
    }

    private static func isPublicIPv4(_ bytes: [UInt8]) -> Bool {
        let (first, second) = (bytes[0], bytes[1])
        if first == 0 || first == 10 || first == 127 { return false }
        if first == 100 && (64...127).contains(second) { return false }
        if first == 169 && second == 254 { return false }
        if first == 172 && (16...31).contains(second) { return false }
        if first == 192 && second == 168 { return false }
        // IETF assignments and the three documentation blocks.
        if first == 192 && second == 0 && (bytes[2] == 0 || bytes[2] == 2) { return false }
        if first == 198 && second == 51 && bytes[2] == 100 { return false }
        if first == 203 && second == 0 && bytes[2] == 113 { return false }
        // Benchmarking.
        if first == 198 && (18...19).contains(second) { return false }
        // Multicast (224.0.0.0/4) and reserved (240.0.0.0/4, broadcast included).
        if first >= 224 { return false }
        return true
    }
}
