import Foundation

/// Turns arbitrarily fragmented pipe bytes into complete, prefixed log lines.
/// Buffering bytes rather than decoded strings preserves UTF-8 scalars split
/// across consecutive `FileHandle` callbacks.
final class PrefixedLineDecoder: @unchecked Sendable {
    private let prefix: Data
    private let dropping: @Sendable (String) -> Bool
    private let lock = NSLock()
    private var buffer = Data()
    private var finished = false

    /// `dropping` returns true for complete lines that should not be
    /// forwarded at all (for example the log tool's own banners).
    init(prefix: String = "[log] ", dropping: @escaping @Sendable (String) -> Bool = { _ in false }) {
        self.prefix = Data(prefix.utf8)
        self.dropping = dropping
    }

    func consume(_ data: Data) -> [Data] {
        lock.lock()
        defer { lock.unlock() }

        guard !finished else { return [] }
        buffer.append(data)

        var lines: [Data] = []
        while let newline = buffer.firstIndex(of: 0x0A) {
            var line = Data(buffer[..<newline])
            buffer.removeSubrange(...newline)
            if line.last == 0x0D {
                line.removeLast()
            }
            if dropping(String(decoding: line, as: UTF8.self)) { continue }
            lines.append(prefixed(line))
        }
        return lines
    }

    /// Emits a final unterminated line, if any. Safe to call more than once.
    func finish() -> [Data] {
        lock.lock()
        defer { lock.unlock() }

        guard !finished else { return [] }
        finished = true
        guard !buffer.isEmpty else { return [] }
        defer { buffer.removeAll(keepingCapacity: false) }
        if dropping(String(decoding: buffer, as: UTF8.self)) { return [] }
        return [prefixed(buffer)]
    }

    private func prefixed(_ line: Data) -> Data {
        var result = prefix
        result.append(line)
        result.append(0x0A)
        return result
    }
}

private final class SerializedLogOutput: @unchecked Sendable {
    private let lock = NSLock()

    func write(_ lines: [Data]) {
        guard !lines.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        for line in lines {
            FileHandle.standardError.write(line)
        }
    }
}

/// Streams `xcrun simctl spawn <udid> log stream` output into the current
/// process's stderr with a `[log]` prefix so simulator app logs interleave
/// naturally with grantiva and runner output.
///
/// Line-atomic: the underlying subprocess writes whole lines and we forward
/// them with a prefix, so you never see half a grantiva line mixed with half
/// a log line. Ordering across the two sources is best-effort — they're two
/// processes writing to two pipes, with no global clock — but within a given
/// stream, line order is preserved.
public final class LogStreamer: @unchecked Sendable {
    private var process: Process?
    private var stderrPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrDecoder: PrefixedLineDecoder?
    private var stdoutDecoder: PrefixedLineDecoder?
    private let lock = NSLock()
    private let output = SerializedLogOutput()
    private var stopped = false
    private var cleanupSucceeded = true
    private var terminationCleanup: UInt64?
    private var terminationLogged: EndedOnce?

    public init() {}

    struct OwnedLogChildren {
        let deviceID: String
        let marker: String
        var snapshot: () throws -> String = LogStreamer.processSnapshot

        /// The UUID predicate is minted for this device and this run only.
        /// Arguments mentioning it on another executable never confer ownership.
        func matchingPIDs(in snapshot: String) -> [Int32] {
            snapshot.split(separator: "\n").compactMap { line in
                let fields = line.split(maxSplits: 1, whereSeparator: { $0 == " " || $0 == "\t" })
                guard fields.count == 2, let pid = Int32(fields[0]), pid > 1, pid != getpid() else { return nil }
                let words = fields[1].split(maxSplits: 2, whereSeparator: { $0 == " " || $0 == "\t" })
                guard words.count == 3, URL(fileURLWithPath: String(words[0])).lastPathComponent == "log",
                      words[1] == "stream", words[2].contains(marker) else { return nil }
                return pid
            }
        }

        /// Re-snapshot before each signal, including after wrapper exit. This
        /// finds the child even when simctl reparented it to the device launchd.
        func stop(gracePeriod: TimeInterval = 2) -> Bool {
            let deadline = Date().addingTimeInterval(gracePeriod)
            let killDeadline = deadline.addingTimeInterval(1)
            var signalled: [Int32: Int64] = [:]
            repeat {
                guard let current = try? snapshot() else { return false }
                let pids = matchingPIDs(in: current)
                if pids.isEmpty { return true }
                for pid in pids {
                    guard let started = RunnerStopMarker.processStartTime(pid) else { continue }
                    if Date() >= deadline {
                        // A reused PID must still have the unique marker and
                        // executable in this snapshot before it is signalled.
                        if signalled[pid] == started { kill(pid, SIGKILL) }
                    } else if signalled[pid] != started {
                        signalled[pid] = started
                        kill(pid, SIGTERM)
                    }
                }
                usleep(10_000)
            } while Date() < killDeadline
            return (try? snapshot()).map { matchingPIDs(in: $0).isEmpty } ?? false
        }
    }
    var ownedLogChildren: OwnedLogChildren?

    /// The running log process's pid, for tests.
    var processIdentifier: Int32? {
        lock.lock()
        defer { lock.unlock() }
        return process.map(\.processIdentifier)
    }

    /// Starts streaming simulator logs. Non-blocking. Call `stop()` to tear
    /// down. `predicate` is passed verbatim to `simctl log stream --predicate`;
    /// pass `nil` for no predicate (warning: very chatty).
    public func start(udid: String, predicate: String?, level: String?) throws {
        var args = ["simctl", "spawn", udid, "log", "stream", "--style", "compact"]
        if let predicate, !predicate.isEmpty { args += ["--predicate", predicate] }
        if let level, !level.isEmpty { args += ["--level", level] }
        try start(executable: "/usr/bin/xcrun", arguments: args)
    }

    /// Starts streaming the output of an arbitrary log process (for example a
    /// platform's `LogStreamCommand`). Non-blocking. Call `stop()` to tear down.
    public func start(executable: String, arguments: [String]) throws {
        lock.lock()
        defer { lock.unlock() }

        guard process == nil else { return }
        // Started after the relay snapshotted its cleanups, a stream would
        // never be stopped and would outlive the exit.
        guard !SignalRelay.shared.isTerminating else { return }

        var arguments = arguments
        if URL(fileURLWithPath: executable).lastPathComponent == "xcrun",
           arguments.count >= 5, arguments[0] == "simctl", arguments[1] == "spawn",
           arguments[3] == "log", arguments[4] == "stream" {
            let marker = "grantiva-log-\(UUID().uuidString)"
            ownedLogChildren = OwnedLogChildren(deviceID: arguments[2], marker: marker)
            let identity = "\"\(marker)\" == \"\(marker)\""
            if let index = arguments.firstIndex(of: "--predicate"), arguments.indices.contains(index + 1) {
                arguments[index + 1] = "(\(arguments[index + 1])) AND (\(identity))"
            } else {
                arguments += ["--predicate", identity]
            }
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: executable)
        p.arguments = arguments

        let outPipe = Pipe()
        let errPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = errPipe

        let outDecoder = PrefixedLineDecoder(dropping: Self.isStreamBanner)
        let errDecoder = PrefixedLineDecoder(dropping: Self.isStreamBanner)

        // Pipe reads may split anywhere, including in the middle of a line or
        // UTF-8 scalar, so each pipe keeps independent raw-byte decoder state.
        let forward: @Sendable (FileHandle, PrefixedLineDecoder) -> Void = { [output] handle, decoder in
            handle.readabilityHandler = { fh in
                let data = fh.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    output.write(decoder.finish())
                } else {
                    output.write(decoder.consume(data))
                }
            }
        }

        forward(outPipe.fileHandleForReading, outDecoder)
        forward(errPipe.fileHandleForReading, errDecoder)

        // `--verbose` names the stream when it ends, however it ends; the
        // flag keeps stop() and the handler from logging it twice.
        let ended = EndedOnce()
        let waitsForRemoteChild = ownedLogChildren != nil
        p.terminationHandler = { process in
            if !waitsForRemoteChild { ended.once { SubprocessLog.ended(process) } }
        }
        terminationLogged = ended

        do {
            try SubprocessLog.run(p)
        } catch {
            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil
            throw error
        }

        process = p
        stdoutPipe = outPipe
        stderrPipe = errPipe
        stdoutDecoder = outDecoder
        stderrDecoder = errDecoder
        stopped = false
        cleanupSucceeded = true
        // Ctrl-C reaches SignalRelay, which runs its cleanups and calls exit,
        // so a caller's `defer { stop() }` never runs and the log process
        // (`adb logcat`, `log stream`) would be reparented to launchd.
        terminationCleanup = SignalRelay.shared.onTermination { [self] in stop() }
    }

    /// Stops the log stream subprocess. Safe to call multiple times.
    @discardableResult
    public func stop() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard !stopped else { return cleanupSucceeded }
        stopped = true
        if let terminationCleanup {
            SignalRelay.shared.removeCleanup(terminationCleanup)
            self.terminationCleanup = nil
        }

        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        output.write(stdoutDecoder?.finish() ?? [])
        output.write(stderrDecoder?.finish() ?? [])

        var complete = true
        if let p = process {
            if p.isRunning { p.terminate() }
            let deadline = Date().addingTimeInterval(2)
            while p.isRunning, Date() < deadline { usleep(10_000) }
            if p.isRunning {
                kill(p.processIdentifier, SIGKILL)
                let killDeadline = Date().addingTimeInterval(1)
                while p.isRunning, Date() < killDeadline { usleep(10_000) }
            }
            complete = !p.isRunning
            if !complete {
                FileHandle.standardError.write(Data("Warning: log wrapper pid \(p.processIdentifier) did not stop before the cleanup deadline.\n".utf8))
            }
        }
        if let children = ownedLogChildren, !children.stop() {
            complete = false
            FileHandle.standardError.write(Data("Warning: could not confirm log-stream cleanup for \(children.deviceID) (\(children.marker)).\n".utf8))
        }
        if let p = process, !p.isRunning {
            terminationLogged?.once { SubprocessLog.ended(p) }
        }
        terminationLogged = nil
        process = nil
        stdoutPipe = nil
        stderrPipe = nil
        stdoutDecoder = nil
        stderrDecoder = nil
        ownedLogChildren = nil
        cleanupSucceeded = complete
        return complete
    }

    private static func processSnapshot() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-ww", "-axo", "pid=,command="]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw CocoaError(.fileReadUnknown) }
        return String(decoding: data, as: UTF8.self)
    }
}

/// Set once by whichever of `stop()` and the termination handler sees the
/// log process's exit first.
final class EndedOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    /// Runs `body` the first time only. The lock is held while it runs, so a
    /// second caller returns only after the first caller's line is out.
    func once(_ body: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !claimed else { return }
        claimed = true
        body()
    }
}

extension LogStreamer {
    /// Lines `log stream` prints about itself rather than about the app: the
    /// simulator's `getpwuid_r` warning, the "Filtering the log data using …"
    /// echo of the predicate, and the compact style's column header. They are
    /// dropped instead of being forwarded as `[log]` lines.
    static let isStreamBanner: @Sendable (String) -> Bool = { line in
        line.hasPrefix("getpwuid_r did not find a match")
            || line.hasPrefix("Filtering the log data using")
            || (line.hasPrefix("Timestamp") && line.contains("Process[PID:TID]"))
    }
}

/// Derives a sensible default `simctl log stream --predicate` value for an
/// app. Matches os_log subsystems that BEGIN with the bundle ID (the
/// convention), so apps using `Logger(subsystem: "com.example.app", …)` get
/// caught without extra config, and the process image by bundle ID. When the
/// app's executable name (`CFBundleExecutable`) is known it also matches that
/// process, which catches everything else the app logs: on a simulator the
/// image path is `…/<App>.app/<App>` and never contains the bundle ID.
public func defaultLogPredicate(forBundleID bundleID: String, executable: String? = nil) -> String {
    var predicate = "subsystem BEGINSWITH \(predicateString(bundleID)) OR processImagePath CONTAINS \(predicateString(bundleID))"
    if let executable, !executable.isEmpty {
        predicate += " OR process == \(predicateString(executable))"
    }
    return predicate
}

private func predicateString(_ value: String) -> String {
    "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
}
