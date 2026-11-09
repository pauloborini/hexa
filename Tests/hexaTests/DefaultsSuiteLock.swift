// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import Darwin
import Foundation

/// Serializa o uso de um domínio fixo também entre processos de testes.
final class DefaultsSuiteLock {
    private let descriptor: Int32

    init(_ name: String) {
        let path = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Preferences/.hexa-defaults-\(name).lock")
        descriptor = open(path, O_CREAT | O_RDWR | O_NOFOLLOW | O_CLOEXEC, S_IRUSR | S_IWUSR)
        precondition(descriptor >= 0, "Não foi possível abrir o lock de defaults")
        var result: Int32
        repeat { result = flock(descriptor, LOCK_EX) } while result == -1 && errno == EINTR
        precondition(result == 0, "Não foi possível adquirir o lock de defaults")
    }

    deinit {
        flock(descriptor, LOCK_UN)
        close(descriptor)
    }
}
