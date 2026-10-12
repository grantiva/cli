import Darwin
import Foundation

/// A teardown's request to stop a foreground `runner start`'s runner,
/// independent of the directory and the runner home the teardown runs with
/// (L36).
///
/// `runner stop` signals a stop request by removing `.grantiva/session.json`,
/// which only works from the directory that started the session. A teardown
/// can run anywhere, with any `GRANTIVA_RUNNER_HOME`, so before it signals
/// anything it writes `<pid>.stop.json` beside the runner's owner file in the
/// shared session directory (`/tmp/grantiva-sessions`), naming the runner's
/// pid, its kernel start time and the grantiva process holding it. That
/// `runner start` reads the marker when its runner exits and ends in order.
///
/// Markers never outlive their use: the holder removes its own; every write
/// and read sweeps markers whose runner is gone and whose holder is gone too,
/// or whose pid now names another process; and the session-file sweeps
/// remove a marker with its owner file once its holder is gone.
public struct RunnerStopMarker: Sendable {
    public let directory: String
    /// The kernel start time of a pid (seconds since 1970), nil when gone.
    let startTime: @Sendable (Int32) -> Int64?
    let isProcessAlive: @Sendable (Int32) -> Bool

    public static let fileSuffix = ".stop.json"

    public init(
        directory: String = KeepAliveSessionStore.defaultDirectory,
        startTime: @escaping @Sendable (Int32) -> Int64? = RunnerStopMarker.processStartTime,
        isProcessAlive: @escaping @Sendable (Int32) -> Bool = KeepAliveSessionStore.processIsAlive
    ) {
        self.directory = directory
        self.startTime = startTime
        self.isProcessAlive = isProcessAlive
    }

    struct Record: Codable, Equatable {
        let runnerPid: Int32
        let runnerStartTime: Int64
        /// The grantiva process holding the runner, which reads and removes
        /// the marker.
        let ownerPid: Int32?
        let reason: String
    }

    public static let processStartTime: @Sendable (Int32) -> Int64? = { pid in
        guard pid > 0 else { return nil }
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        return Int64(info.pbi_start_tvsec)
    }

    public func path(_ runnerPid: Int32) -> String { "\(directory)/\(runnerPid)\(Self.fileSuffix)" }

    /// Marks `runnerPid`, held by `ownerPid`, as stopped by a teardown. Only a
    /// live process can be marked (its start time is what the reader checks):
    /// returns false, writing nothing, for a pid that is gone. Throws when
    /// the marker cannot be written.
    @discardableResult
    public func mark(runnerPid: Int32, ownerPid: Int32?, reason: String = "teardown") throws -> Bool {
        sweep()
        guard let started = startTime(runnerPid) else { return false }
        let record = Record(runnerPid: runnerPid, runnerStartTime: started, ownerPid: ownerPid, reason: reason)
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(record).write(to: URL(fileURLWithPath: path(runnerPid)), options: .atomic)
        return true
    }

    /// Whether a teardown marked the runner `runnerPid` that started at
    /// `runnerStartTime` (read by its holder when it spawned the runner). A
    /// marker for another process with the same pid does not count.
    public func isMarked(runnerPid: Int32, runnerStartTime: Int64?) -> Bool {
        defer { sweep() }
        guard let runnerStartTime, let record = Self.load(path(runnerPid)) else { return false }
        return record.runnerPid == runnerPid && record.runnerStartTime == runnerStartTime
    }

    public func remove(runnerPid: Int32) {
        try? FileManager.default.removeItem(atPath: path(runnerPid))
    }

    /// Removes `runnerPid`'s marker unless its holder is still alive (the
    /// holder reads it after the runner dies, then removes it itself).
    /// For the session-file sweeps.
    @discardableResult
    public func removeUnlessHeld(runnerPid: Int32) -> Bool {
        guard FileManager.default.fileExists(atPath: path(runnerPid)) else { return false }
        if let owner = Self.load(path(runnerPid))?.ownerPid, isProcessAlive(owner) { return false }
        remove(runnerPid: runnerPid)
        return true
    }

    /// Removes every marker that can no longer be read by its holder: its
    /// pid now names another process, or its runner and its holder are both
    /// gone. Returns the paths removed.
    @discardableResult
    public func sweep() -> [String] {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: directory) else { return [] }
        var removed: [String] = []
        for name in contents where name.hasSuffix(Self.fileSuffix) {
            let file = "\(directory)/\(name)"
            let stale: Bool
            if let record = Self.load(file) {
                if let current = startTime(record.runnerPid) {
                    stale = current != record.runnerStartTime
                } else {
                    stale = record.ownerPid.map { !isProcessAlive($0) } ?? true
                }
            } else {
                stale = true
            }
            if stale, (try? FileManager.default.removeItem(atPath: file)) != nil { removed.append(file) }
        }
        return removed
    }

    static func load(_ path: String) -> Record? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return try? JSONDecoder().decode(Record.self, from: data)
    }
}
