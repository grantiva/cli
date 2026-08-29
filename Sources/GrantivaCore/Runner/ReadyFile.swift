import Foundation

/// The terminal state of a run, written to `--ready-file`.
public struct RunReadyState: Codable, Sendable, Equatable {
    public struct Flow: Codable, Sendable, Equatable {
        public let name: String
        public let status: String

        public init(name: String, status: String) {
            self.name = name
            self.status = status
        }
    }

    /// `passed`, `failed`, or `interrupted`.
    public let status: String
    public let flows: [Flow]
    public let finishedAt: Date
    public let reportDir: String?

    public init(status: String, flows: [Flow], finishedAt: Date = Date(), reportDir: String? = nil) {
        self.status = status
        self.flows = flows
        self.finishedAt = finishedAt
        self.reportDir = reportDir
    }

    public var passed: Bool { status == "passed" }
}

/// Writes the readiness signal for a run.
///
/// `--keep-alive` exists to hold one app in a known state while something else
/// drives another, but until now the only completion signal was `report.json`,
/// which the runner rewrites incrementally (hence its `updateSeq`) — so the
/// file existing says nothing about whether the flows finished. The ready file
/// is cleared at startup (see `prepare`) and appears exactly once, when the run
/// reaches a terminal state — including a setup failure that never reached the
/// runner — so a waiter can be `while [ ! -f "$f" ]; do sleep 0.2; done` and
/// then read the verdict out of the file instead of re-implementing report
/// polling.
public enum ReadyFile {
    /// Clears any file left by a previous run and proves the path is writable.
    ///
    /// Must be called before any project/build/simulator work. The documented
    /// waiter is `while [ ! -f "$f" ]`, so a file left behind by an earlier run
    /// makes the waiter return instantly and read that run's verdict — a stale
    /// `passed` for a run that never started. Once this has run, the file
    /// existing always means *this* run reached a terminal state.
    ///
    /// The writability probe is deliberate: deleting at startup means a bad
    /// path must fail loudly now rather than after a ten-minute suite, with the
    /// verdict then undeliverable. It uses a temp sibling rather than the target
    /// itself so a waiter never sees a zero-byte `ready` file.
    public static func prepare(at path: String) throws {
        let url = URL(fileURLWithPath: path)
        let fileManager = FileManager.default

        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: path, isDirectory: &isDirectory) {
            guard !isDirectory.boolValue else {
                throw GrantivaError.invalidArgument("--ready-file \(path) is a directory, not a file.")
            }
            do {
                try fileManager.removeItem(at: url)
            } catch {
                throw GrantivaError.invalidArgument(
                    "--ready-file \(path) exists and could not be removed: \(error.localizedDescription)"
                )
            }
        }

        let directory = url.deletingLastPathComponent()
        if !directory.path.isEmpty, !fileManager.fileExists(atPath: directory.path) {
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                throw GrantivaError.invalidArgument(
                    "--ready-file directory \(directory.path) could not be created: \(error.localizedDescription)"
                )
            }
        }

        let probe = directory.appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).probe")
        guard fileManager.createFile(atPath: probe.path, contents: Data()) else {
            throw GrantivaError.invalidArgument("--ready-file \(path) is not writable.")
        }
        try? fileManager.removeItem(at: probe)
    }

    /// Writes `state` to `path` atomically (temp file in the same directory,
    /// then rename) so a reader never observes a partial file.
    public static func write(_ state: RunReadyState, to path: String) throws {
        let url = URL(fileURLWithPath: path)
        let directory = url.deletingLastPathComponent()
        if !directory.path.isEmpty {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)

        let temporary = directory.appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp")
        try data.write(to: temporary)
        // rename(2) is atomic within a filesystem: the reader sees either the
        // old state or the complete new one, never a half-written file.
        _ = try? FileManager.default.removeItem(at: url)
        try FileManager.default.moveItem(at: temporary, to: url)
    }

    public static func read(_ path: String) throws -> RunReadyState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(RunReadyState.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
    }
}

/// The subset of the runner's `report.json` grantiva needs to decide whether
/// every flow has finished.
public struct RunnerReportIndex: Decodable, Sendable {
    public struct Flow: Decodable, Sendable {
        public let name: String?
        public let status: String?
    }

    public let status: String?
    public let flows: [Flow]?

    static let terminalStatuses: Set<String> = ["passed", "failed", "skipped", "error", "cancelled"]

    /// True when every flow has reached a terminal status. `expectedFlows`
    /// guards against reading the report before all flows have been registered.
    public func isComplete(expectedFlows: Int) -> Bool {
        guard let flows, flows.count >= expectedFlows, !flows.isEmpty else {
            // A run status can go terminal even when no flow entry was written
            // (for example when the suite failed before the first flow started).
            return status.map { Self.terminalStatuses.contains($0) } ?? false
        }
        return flows.allSatisfy { flow in
            guard let status = flow.status else { return false }
            return Self.terminalStatuses.contains(status)
        }
    }

    public var readyState: RunReadyState {
        let entries = (flows ?? []).map {
            RunReadyState.Flow(name: $0.name ?? "flow", status: $0.status ?? "unknown")
        }
        let failed = entries.contains { $0.status != "passed" && $0.status != "skipped" }
        let overall = status.flatMap { Self.terminalStatuses.contains($0) ? $0 : nil }
            ?? (failed ? "failed" : "passed")
        return RunReadyState(status: overall == "passed" ? "passed" : overall, flows: entries)
    }

    public static func load(reportDir: String) -> RunnerReportIndex? {
        let path = "\(reportDir)/report.json"
        guard let data = FileManager.default.contents(atPath: path), !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(RunnerReportIndex.self, from: data)
    }
}

/// A `--ready-file` target that is written at most once.
public final class ReadyFileSignal: @unchecked Sendable {
    public let path: String?
    private let lock = NSLock()
    private var written = false

    public init(path: String?) {
        self.path = path
    }

    /// Writes the terminal state unless it was already written. Returns whether
    /// this call produced the file.
    @discardableResult
    public func write(_ state: RunReadyState) -> Bool {
        guard let path else { return false }
        lock.lock()
        if written {
            lock.unlock()
            return false
        }
        written = true
        lock.unlock()
        do {
            try ReadyFile.write(state, to: path)
            return true
        } catch {
            FileHandle.standardError.write(Data("[grantiva] could not write ready file \(path): \(error)\n".utf8))
            return false
        }
    }

    public var hasWritten: Bool {
        lock.lock()
        defer { lock.unlock() }
        return written
    }
}
