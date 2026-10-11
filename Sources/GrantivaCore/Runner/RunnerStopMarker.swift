import Darwin
import Foundation

/// A teardown's request to stop a runner, independent of the directory the
/// teardown runs in (L36).
///
/// `runner stop` signals a stop request by removing `.grantiva/session.json`,
/// which only works from the directory that started the session. A teardown
/// can run anywhere, so before it signals anything it writes
/// `<runner home>/stops/<runnerPid>` naming the runner's pid and its kernel
/// start time. The `runner start` holding that runner reads the marker when
/// the runner exits and ends in order. The start time ties a marker to one
/// process: a marker left for a pid the system has since reused never counts.
public struct RunnerStopMarker: Sendable {
    public let directory: String
    /// The kernel start time of a pid (seconds since 1970), nil when gone.
    let startTime: @Sendable (Int32) -> Int64?

    /// `<runner home>/stops`.
    public static var defaultDirectory: String { RunnerManager.baseDir + "/stops" }

    public init(
        directory: String? = nil,
        startTime: @escaping @Sendable (Int32) -> Int64? = RunnerStopMarker.processStartTime
    ) {
        self.directory = directory ?? Self.defaultDirectory
        self.startTime = startTime
    }

    struct Record: Codable, Equatable {
        let runnerPid: Int32
        let runnerStartTime: Int64
        let reason: String
    }

    public static let processStartTime: @Sendable (Int32) -> Int64? = { pid in
        guard pid > 0 else { return nil }
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        return Int64(info.pbi_start_tvsec)
    }

    func path(_ runnerPid: Int32) -> String { "\(directory)/\(runnerPid)" }

    /// Marks `runnerPid` as stopped by a teardown. Only a live process can be
    /// marked (its start time is what the reader checks). Returns whether a
    /// marker was written.
    @discardableResult
    public func mark(runnerPid: Int32, reason: String = "teardown") -> Bool {
        guard let started = startTime(runnerPid) else { return false }
        let record = Record(runnerPid: runnerPid, runnerStartTime: started, reason: reason)
        do {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(record).write(to: URL(fileURLWithPath: path(runnerPid)), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// Whether a teardown marked the runner `runnerPid` that started at
    /// `runnerStartTime` (read by its owner when it spawned the runner). A
    /// marker for another process with the same pid does not count.
    public func isMarked(runnerPid: Int32, runnerStartTime: Int64?) -> Bool {
        guard let runnerStartTime,
              let data = FileManager.default.contents(atPath: path(runnerPid)),
              let record = try? JSONDecoder().decode(Record.self, from: data) else { return false }
        return record.runnerPid == runnerPid && record.runnerStartTime == runnerStartTime
    }

    public func remove(runnerPid: Int32) {
        try? FileManager.default.removeItem(atPath: path(runnerPid))
    }
}
