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

    struct ProcessIdentity: Equatable {
        let seconds: UInt64
        let microseconds: UInt64
    }

    static func processIdentity(_ pid: Int32) -> ProcessIdentity? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard pid > 0, proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        return ProcessIdentity(seconds: info.pbi_start_tvsec, microseconds: info.pbi_start_tvusec)
    }

    static func processIdentities() -> [Int32: ProcessIdentity] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [:] }
        var pids = [Int32](repeating: 0, count: Int(count) + 64)
        let read = pids.withUnsafeMutableBytes { proc_listallpids($0.baseAddress, Int32($0.count)) }
        guard read > 0 else { return [:] }
        return Dictionary(pids.prefix(min(Int(read), pids.count)).compactMap { pid in
            processIdentity(pid).map { (pid, $0) }
        }, uniquingKeysWith: { first, _ in first })
    }

    struct OwnedLogChildren {
        let deviceID: String
        let marker: String
        var snapshot: (Date) throws -> String = { try LogStreamer.processSnapshot(deadline: $0) }
        var identities: () -> [Int32: ProcessIdentity] = LogStreamer.processIdentities
        var identity: (Int32) -> ProcessIdentity? = LogStreamer.processIdentity
        var signal: (Int32, Int32) -> Void = { _ = kill($0, $1) }

        /// The UUID predicate is minted for this device and this run only.
        /// Arguments mentioning it on another executable never confer ownership.
        func matchingPIDs(in snapshot: String) -> [Int32] {
            snapshot.split(separator: "\n").compactMap { line in
                let fields = line.split(maxSplits: 1, whereSeparator: { $0 == " " || $0 == "\t" })
                guard fields.count == 2, let pid = Int32(fields[0]), pid > 1, pid != getpid() else { return nil }
                let words = fields[1].split(maxSplits: 2, whereSeparator: { $0 == " " || $0 == "\t" })
                guard words.count == 3, URL(fileURLWithPath: String(words[0])).lastPathComponent == "log",
                      words[1] == "stream",
                      words[2].components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_")).inverted)
                        .contains(marker) else { return nil }
                return pid
            }
        }

        struct Discovery {
            let identities: [Int32: ProcessIdentity]
            let sawMatchingCommand: Bool
        }

        /// Bracket command discovery with kernel identities. Reading only a
        /// start time after ps would incorrectly adopt a PID reused while ps ran.
        func discover(until deadline: Date) throws -> Discovery {
            guard Date() < deadline else { throw InventoryError.timedOut }
            let before = identities()
            let commands = try snapshot(deadline)
            guard Date() < deadline else { throw InventoryError.timedOut }
            let pids = matchingPIDs(in: commands)
            let stable = pids.compactMap { pid -> (Int32, ProcessIdentity)? in
                guard let original = before[pid], identity(pid) == original else { return nil }
                return (pid, original)
            }
            return Discovery(identities: Dictionary(stable, uniquingKeysWith: { first, _ in first }), sawMatchingCommand: !pids.isEmpty)
        }

        /// Revalidate the captured identity and exact marker before every
        /// signal. A replacement never inherits an earlier PID's ownership.
        func stop(gracePeriod: TimeInterval = 2) -> Bool {
            let terminateDeadline = Date().addingTimeInterval(gracePeriod)
            let deadline = terminateDeadline.addingTimeInterval(1)
            var discovered: [Int32: ProcessIdentity] = [:]
            var signalled: [Int32: ProcessIdentity] = [:]
            while Date() < deadline {
                guard let current = try? discover(until: deadline) else { return false }
                if !current.sawMatchingCommand { return true }
                for (pid, original) in current.identities {
                    if discovered[pid] == nil { discovered[pid] = original }
                    guard discovered[pid] == original,
                          let confirmed = try? discover(until: deadline),
                          confirmed.identities[pid] == original,
                          Date() < deadline, identity(pid) == original else { continue }
                    if Date() >= terminateDeadline, signalled[pid] == original {
                        signal(pid, SIGKILL)
                    } else if signalled[pid] == nil {
                        signalled[pid] = original
                        signal(pid, SIGTERM)
                    }
                }
                let remaining = deadline.timeIntervalSinceNow
                if remaining > 0 { usleep(useconds_t(min(0.01, remaining) * 1_000_000)) }
            }
            // No unbudgeted final inventory: without an in-budget empty
            // confirmation, cleanup is explicitly incomplete.
            return false
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

    enum InventoryError: Error {
        case timedOut
        case readFailed
        case commandFailed
    }

    /// The inventory gets only the cleanup budget that remains. Its pipe is
    /// nonblocking, and part of that budget is reserved for killing/reaping
    /// this exact child if it stalls. Foundation owns child reaping throughout.
    static func processSnapshot(
        deadline: Date, executable: String = "/bin/ps", arguments: [String] = ["-ww", "-axo", "pid=,command="],
        didSpawn: (Int32) -> Void = { _ in }
    ) throws -> String {
        let remaining = deadline.timeIntervalSinceNow
        guard remaining > 0 else { throw InventoryError.timedOut }
        let executionDeadline = deadline.addingTimeInterval(-min(0.1, remaining / 2))
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        let descriptor = pipe.fileHandleForReading.fileDescriptor
        let flags = fcntl(descriptor, F_GETFL)
        guard flags >= 0, fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) == 0 else { throw InventoryError.readFailed }
        try process.run()
        didSpawn(process.processIdentifier)
        try? pipe.fileHandleForWriting.close()
        defer {
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
                while process.isRunning, Date() < deadline { usleep(1_000) }
            }
            try? pipe.fileHandleForReading.close()
        }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 16_384)
        while Date() < executionDeadline {
            let count = buffer.withUnsafeMutableBytes { Darwin.read(descriptor, $0.baseAddress, $0.count) }
            if count > 0 {
                data.append(contentsOf: buffer.prefix(count))
                continue
            }
            if count < 0, errno != EAGAIN, errno != EINTR { throw InventoryError.readFailed }
            if count == 0, !process.isRunning {
                guard process.terminationStatus == 0 else { throw InventoryError.commandFailed }
                return String(decoding: data, as: UTF8.self)
            }
            usleep(1_000)
        }
        throw InventoryError.timedOut
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
