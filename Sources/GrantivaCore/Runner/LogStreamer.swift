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
    private var terminationCleanup: UInt64?

    public init() {}

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

        do {
            try p.run()
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
        // Ctrl-C reaches SignalRelay, which runs its cleanups and calls exit,
        // so a caller's `defer { stop() }` never runs and the log process
        // (`adb logcat`, `log stream`) would be reparented to launchd.
        terminationCleanup = SignalRelay.shared.onTermination { [self] in stop() }
    }

    /// Stops the log stream subprocess. Safe to call multiple times.
    public func stop() {
        lock.lock()
        defer { lock.unlock() }

        guard !stopped else { return }
        stopped = true
        if let terminationCleanup {
            SignalRelay.shared.removeCleanup(terminationCleanup)
            self.terminationCleanup = nil
        }

        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        output.write(stdoutDecoder?.finish() ?? [])
        output.write(stderrDecoder?.finish() ?? [])

        if let p = process, p.isRunning {
            p.terminate()
        }
        process = nil
        stdoutPipe = nil
        stderrPipe = nil
        stdoutDecoder = nil
        stderrDecoder = nil
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
