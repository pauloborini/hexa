// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Darwin
import Foundation

/// A brew operation started as the leader of its own session and process
/// group. A signal to the group reaches everything brew spawned, which a
/// signal to the root process alone does not.
final class HomebrewProcessGroup {
    /// Equal to the leader's pid, because the spawn makes the child a session leader.
    let processGroupID: pid_t

    private static let exitQueue = DispatchQueue(label: "com.hexa.homebrew.process-exit")

    private let reader: FileHandle
    private let drained: DispatchSemaphore
    private let state: State

    /// Spawns `command` as the leader of a new session and process group with
    /// `environment`. Each valid UTF-8 chunk of output reaches `onOutput` on the
    /// reader's queue. When `abortsWhenPartialLine` returns true for the text after
    /// the last line break, the group is terminated, once.
    static func start(_ command: HomebrewCommand,
                      environment: [String: String],
                      abortsWhenPartialLine: @escaping (String) -> Bool = { _ in false },
                      onOutput: @escaping (String) -> Void) throws -> HomebrewProcessGroup {
        let pipe = Pipe()
        let reader = pipe.fileHandleForReading
        let pid: pid_t
        do {
            // Only the child keeps the write end, so the group's exit reaches the reader as EOF.
            defer { try? pipe.fileHandleForWriting.close() }
            pid = try BoundedProcessRunner.spawnInNewSession(command.executable,
                                                             command.arguments,
                                                             environment: environment,
                                                             output: pipe.fileHandleForWriting.fileDescriptor)
        } catch {
            try? reader.close()
            throw error
        }

        let state = State()
        let drained = DispatchSemaphore(value: 0)
        let group = HomebrewProcessGroup(processGroupID: pid, reader: reader,
                                         drained: drained, state: state)
        // Weak, so the reader never keeps the group alive. The caller holds it until the output ends.
        reader.readabilityHandler = { [weak group] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                drained.signal()
                return
            }
            let partialLine = state.append(data)
            if let chunk = String(data: data, encoding: .utf8) {
                onOutput(chunk)
            }
            if abortsWhenPartialLine(partialLine) {
                group?.terminateGroup()
            }
        }
        // Watched on a serial queue so a starved global pool cannot hold back the reap.
        let source = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit,
                                                      queue: exitQueue)
        source.setEventHandler {
            var raw: Int32 = 0
            while waitpid(pid, &raw, 0) == -1 && errno == EINTR {}
            state.recordExit(raw)
            source.cancel()
        }
        source.resume()
        return group
    }

    private init(processGroupID: pid_t, reader: FileHandle,
                 drained: DispatchSemaphore, state: State) {
        self.processGroupID = processGroupID
        self.reader = reader
        self.drained = drained
        self.state = state
    }

    /// True once the leader has been reaped. Members that outlive it keep the group alive.
    func waitForExit(timeout: TimeInterval) -> Bool {
        state.waitForExit(timeout: timeout)
    }

    /// Seconds since the last output chunk.
    var silence: TimeInterval {
        state.silence
    }

    /// -1 while the leader runs, else the exit code or the signal that ended it,
    /// as `BoundedProcessRunner` reports it.
    var status: Int32 {
        state.status
    }

    var output: String {
        state.output
    }

    /// SIGTERM to the whole group, then SIGKILL to it after `grace` if any member
    /// still exists. Only the first call acts, and a group that is already gone is left alone.
    func terminateGroup(grace: TimeInterval = 2) {
        guard state.claimTermination() else { return }
        let pgid = processGroupID
        guard kill(-pgid, 0) == 0 else { return }
        kill(-pgid, SIGTERM)
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + grace) {
            guard kill(-pgid, 0) == 0 else { return }
            kill(-pgid, SIGKILL)
        }
    }

    /// Waits up to `timeout` for EOF so output written just before the exit is
    /// collected, then closes the reader. Call once the leader has exited.
    func drainOutput(timeout: TimeInterval = 1) {
        _ = drained.wait(timeout: .now() + timeout)
        reader.readabilityHandler = nil
        try? reader.close()
    }

    /// Shared with the reader and exit handlers, which never reference the group.
    private final class State {
        private let lock = NSLock()
        private let exited = DispatchGroup()
        private var collected = Data()
        /// Bytes after the last line break of `collected`.
        private var partialLine = Data()
        private var lastOutput = Date()
        private var rawStatus: Int32?
        private var terminationRequested = false

        init() {
            exited.enter()
        }

        /// Records `chunk` and returns the partial line it leaves, decoded as UTF-8.
        func append(_ chunk: Data) -> String {
            lock.lock()
            defer { lock.unlock() }
            collected.append(chunk)
            lastOutput = Date()
            if let lineBreak = chunk.lastIndex(of: UInt8(ascii: "\n")) {
                partialLine = Data(chunk[(lineBreak + 1)...])
            } else {
                partialLine.append(chunk)
            }
            return String(data: partialLine, encoding: .utf8) ?? ""
        }

        func recordExit(_ raw: Int32) {
            lock.lock()
            rawStatus = raw
            lock.unlock()
            exited.leave()
        }

        func waitForExit(timeout: TimeInterval) -> Bool {
            exited.wait(timeout: .now() + timeout) == .success
        }

        var silence: TimeInterval {
            lock.lock()
            defer { lock.unlock() }
            return Date().timeIntervalSince(lastOutput)
        }

        var status: Int32 {
            lock.lock()
            defer { lock.unlock() }
            guard let raw = rawStatus else { return -1 }
            // What `Process.terminationStatus` reports: the exit code, or the signal that ended the child.
            let signal = raw & 0x7f
            return signal == 0 ? (raw >> 8) & 0xff : signal
        }

        var output: String {
            lock.lock()
            defer { lock.unlock() }
            return String(data: collected, encoding: .utf8) ?? ""
        }

        func claimTermination() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            guard !terminationRequested else { return false }
            terminationRequested = true
            return true
        }
    }
}
