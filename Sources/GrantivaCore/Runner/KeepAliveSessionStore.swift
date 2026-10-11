import Darwin
import Foundation

/// A live `grantiva run --keep-alive` session, as discovered on disk.
///
/// grantiva-runner is the source of truth for the port and session ID: at
/// keep-alive start it writes `/tmp/grantiva-sessions/<pid>-<timestamp>.grantiva`
/// (`{"version","sessionId","createdAt","pid","port","outputDir"}`). That file
/// carries no simulator UDID, so grantiva writes a sidecar next to it the moment
/// the runner is spawned (see `KeepAliveSessionStore.recordOwner`) mapping the
/// runner's pid to the UDID it was started against.
public struct KeepAliveSession: Equatable, Sendable {
    public let sessionId: String
    public let port: Int
    public let pid: Int32
    /// The simulator the session belongs to, when grantiva recorded it.
    public let udid: String?
    public let path: String
    /// The directory `grantiva run --keep-alive` or `runner start` ran in
    /// (symlinks resolved), when grantiva recorded it.
    public let projectDirectory: String?
    /// The platform the session drives, when grantiva recorded it.
    public let platform: Platform?
    /// The grantiva process that started the runner, when recorded.
    public let ownerPid: Int32?
    /// True for a `runner start --detach` hand-off, false for a session a
    /// grantiva process holds (`run --keep-alive`, foreground `runner start`),
    /// nil when not recorded.
    public let detached: Bool?
    /// The app the session launched, when grantiva recorded it.
    public let appId: String?

    public init(
        sessionId: String, port: Int, pid: Int32, udid: String?, path: String,
        projectDirectory: String? = nil, platform: Platform? = nil,
        ownerPid: Int32? = nil, detached: Bool? = nil, appId: String? = nil
    ) {
        self.sessionId = sessionId
        self.port = port
        self.pid = pid
        self.udid = udid
        self.path = path
        self.projectDirectory = projectDirectory
        self.platform = platform
        self.ownerPid = ownerPid
        self.detached = detached
        self.appId = appId
    }
}

/// grantiva's sidecar: which simulator a keep-alive runner process owns.
public struct KeepAliveOwner: Codable, Equatable, Sendable {
    public let udid: String
    public let runnerPid: Int32
    public let grantivaPid: Int32
    public let createdAt: Date
    /// Where the session was started, so the MCP server only attaches to its
    /// own project's session. Absent in sidecars written by earlier versions.
    public let projectDirectory: String?
    public let platform: Platform?
    /// True when `runner start --detach` handed the runner off: the session
    /// outlives `grantivaPid` by design. False when `grantivaPid` holds the
    /// session (`run --keep-alive`, foreground `runner start`), so the session
    /// ends with it. Absent in sidecars written by earlier versions.
    public let detached: Bool?
    /// The app the session launched (bundle ID or application ID). Absent in
    /// sidecars written by earlier versions.
    public let appId: String?

    public init(
        udid: String, runnerPid: Int32, grantivaPid: Int32 = getpid(), createdAt: Date = Date(),
        projectDirectory: String? = nil, platform: Platform? = nil, detached: Bool? = nil, appId: String? = nil
    ) {
        self.udid = udid
        self.runnerPid = runnerPid
        self.grantivaPid = grantivaPid
        self.createdAt = createdAt
        self.projectDirectory = projectDirectory
        self.platform = platform
        self.detached = detached
        self.appId = appId
    }

    /// The canonical form both sides compare: absolute, standardized, with
    /// symlinks resolved the way realpath(3) resolves them, so `/tmp/x` and
    /// `/private/tmp/x` both become `/private/tmp/x`. (Foundation's
    /// `resolvingSymlinksInPath` strips a leading `/private` instead.) A path
    /// that does not exist keeps its standardized spelling.
    public static func canonicalDirectory(_ path: String) -> String {
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        guard let resolved = realpath(standardized, nil) else { return standardized }
        defer { free(resolved) }
        return String(cString: resolved)
    }
}

/// Discovers keep-alive sessions. Shared by `grantiva hierarchy`,
/// `grantiva runner dump-hierarchy` and the MCP server so they cannot drift.
public struct KeepAliveSessionStore: Sendable {
    /// Hardcoded in grantiva-runner; not configurable from this side.
    public static let defaultDirectory = "/tmp/grantiva-sessions"

    static let runnerExtension = "grantiva"
    static let ownerExtension = "owner.json"

    public let directory: String
    let isProcessAlive: @Sendable (Int32) -> Bool

    public init(
        directory: String = KeepAliveSessionStore.defaultDirectory,
        isProcessAlive: @escaping @Sendable (Int32) -> Bool = KeepAliveSessionStore.processIsAlive
    ) {
        self.directory = directory
        self.isProcessAlive = isProcessAlive
    }

    /// `kill(pid, 0)` succeeds for a live process we may signal; EPERM means
    /// it is alive but owned by someone else. Anything else means it is gone.
    public static func processIsAlive(_ pid: Int32) -> Bool {
        guard pid > 0 else { return false }
        return kill(pid, 0) == 0 || errno == EPERM
    }

    // MARK: - Writing (grantiva run --keep-alive)

    func ownerPath(runnerPid: Int32) -> String {
        "\(directory)/\(runnerPid).\(Self.ownerExtension)"
    }

    /// Records that `runnerPid` holds `udid`, started from `projectDirectory`
    /// (default: the current directory) for `platform` (default: inferred from
    /// the device ID's shape). Called right after the runner is spawned, so the
    /// mapping exists before the runner's own session file and before the
    /// `--ready-file` is written.
    @discardableResult
    public func recordOwner(
        udid: String,
        runnerPid: Int32,
        projectDirectory: String = FileManager.default.currentDirectoryPath,
        platform: Platform? = nil,
        detached: Bool? = nil,
        appID: String? = nil
    ) -> KeepAliveOwner? {
        let owner = KeepAliveOwner(
            udid: udid, runnerPid: runnerPid,
            projectDirectory: KeepAliveOwner.canonicalDirectory(projectDirectory),
            platform: platform ?? (DeviceID.isAndroidSerial(udid) ? .android : .ios),
            detached: detached,
            appId: appID.flatMap { $0.isEmpty ? nil : $0 }
        )
        do {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            let path = ownerPath(runnerPid: runnerPid)
            let temporary = "\(directory)/.\(runnerPid).\(UUID().uuidString).tmp"
            try encoder.encode(owner).write(to: URL(fileURLWithPath: temporary))
            _ = try? FileManager.default.removeItem(atPath: path)
            try FileManager.default.moveItem(atPath: temporary, toPath: path)
            return owner
        } catch {
            FileHandle.standardError.write(
                Data("[grantiva] could not record keep-alive owner for pid \(runnerPid): \(error)\n".utf8)
            )
            return nil
        }
    }

    public func removeOwner(runnerPid: Int32) {
        try? FileManager.default.removeItem(atPath: ownerPath(runnerPid: runnerPid))
    }

    /// Deletes `runnerPid`'s sidecar and its own `<pid>-<timestamp>.grantiva`
    /// file whether or not the pid still looks alive: for callers that have
    /// just stopped that runner (a SIGKILL'd runner never removes its file,
    /// and an unreaped one still answers `kill(pid, 0)`). Returns the paths
    /// removed.
    @discardableResult
    public func removeSessionFiles(runnerPid: Int32) -> [String] {
        let fm = FileManager.default
        guard runnerPid > 0, let contents = try? fm.contentsOfDirectory(atPath: directory) else { return [] }
        var removed: [String] = []
        for name in contents.sorted() {
            let isOwner = name == "\(runnerPid).\(Self.ownerExtension)"
            let isRunner = name.hasSuffix(".\(Self.runnerExtension)") && name.hasPrefix("\(runnerPid)-")
            guard isOwner || isRunner else { continue }
            let path = "\(directory)/\(name)"
            if (try? fm.removeItem(atPath: path)) != nil { removed.append(path) }
        }
        return removed
    }

    /// Deletes the session files of keep-alive runners that held `udid` and are
    /// no longer running: their `<pid>.owner.json` sidecar and the runner's own
    /// `<pid>-<timestamp>.grantiva` file. `runnerPids` adds runners known to
    /// have held the device (for example ones just killed) whose sidecar is
    /// missing. Live runners are left alone. Returns the removed paths.
    @discardableResult
    public func removeSessions(udid: String, runnerPids: [Int32] = []) -> [String] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: directory) else { return [] }
        let owners = contents
            .filter { $0.hasSuffix(".\(Self.ownerExtension)") }
            .compactMap { Self.loadOwner(path: "\(directory)/\($0)") }
            .filter { $0.udid.caseInsensitiveCompare(udid) == .orderedSame }
            .map(\.runnerPid)
        let pids = Set(owners + runnerPids).filter { !isProcessAlive($0) }
        var removed: [String] = []
        for name in contents.sorted() {
            let isOwner = pids.contains { name == "\($0).\(Self.ownerExtension)" }
            let isRunner = name.hasSuffix(".\(Self.runnerExtension)") && pids.contains { name.hasPrefix("\($0)-") }
            guard isOwner || isRunner else { continue }
            let path = "\(directory)/\(name)"
            if (try? fm.removeItem(atPath: path)) != nil { removed.append(path) }
        }
        return removed
    }

    // MARK: - Reading

    /// Every session whose runner process is still alive, newest first.
    ///
    /// A session a grantiva process holds (`run --keep-alive`, foreground
    /// `runner start`; owner `detached == false`) whose grantiva process is
    /// gone is an orphan: its runner normally follows within seconds (see
    /// `ChildProcess.bindLifetimeToParent`), and until then it is excluded
    /// unless `includingOrphans` (for `runner stop` and teardown, which clean
    /// orphans up).
    public func liveSessions(includingOrphans: Bool = false) -> [KeepAliveSession] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: directory) else { return [] }

        let owners = Dictionary(
            contents
                .filter { $0.hasSuffix(".\(Self.ownerExtension)") }
                .compactMap { Self.loadOwner(path: "\(directory)/\($0)") }
                .map { ($0.runnerPid, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let sessions: [(KeepAliveSession, Double)] = contents
            .filter { $0.hasSuffix(".\(Self.runnerExtension)") }
            .compactMap { name -> (KeepAliveSession, Double)? in
                let path = "\(directory)/\(name)"
                guard let raw = Self.loadRunnerSession(path: path), isProcessAlive(raw.pid) else { return nil }
                let owner = owners[raw.pid]
                if !includingOrphans, let owner, owner.detached == false, !isProcessAlive(owner.grantivaPid) {
                    return nil
                }
                let session = KeepAliveSession(
                    sessionId: raw.sessionId, port: raw.port, pid: raw.pid,
                    udid: owner?.udid, path: path,
                    // Re-canonicalised: sidecars written by 2.1.0 hold the
                    // `/tmp` spelling of a `/private/tmp` directory.
                    projectDirectory: owner?.projectDirectory.map(KeepAliveOwner.canonicalDirectory),
                    platform: owner?.platform,
                    ownerPid: owner?.grantivaPid, detached: owner?.detached, appId: owner?.appId
                )
                return (session, Self.sortKey(fileName: name, path: path))
            }

        return sessions
            .sorted {
                if $0.1 != $1.1 { return $0.1 > $1.1 }
                return $0.0.path < $1.0.path
            }
            .map(\.0)
    }

    /// The session held by `runnerPid`, if its file has appeared yet.
    public func session(forRunnerPid runnerPid: Int32) -> KeepAliveSession? {
        liveSessions().first { $0.pid == runnerPid }
    }

    /// The newest live session, or the live session for `udid` when given.
    public func locate(udid: String? = nil) throws -> KeepAliveSession {
        let live = liveSessions()
        guard !live.isEmpty else {
            throw GrantivaError.noRunnerSession()
        }
        guard let udid else { return live[0] }

        if let match = live.first(where: { $0.udid == udid }) {
            return match
        }
        let available = live.map { $0.udid ?? "pid \($0.pid) (unknown udid)" }.joined(separator: ", ")
        throw GrantivaError.invalidArgument(
            "No keep-alive session for udid \(udid). Live sessions: \(available)"
        )
    }

    // MARK: - Parsing

    struct RunnerSessionFile {
        let sessionId: String
        let port: Int
        let pid: Int32
    }

    /// Decoded leniently: the runner is a separate binary and only the three
    /// fields we route on are required. A `port` of 0 is what the runner
    /// publishes on Android, where it does not proxy UIAutomator2 and the CLI
    /// finds the device from the owner sidecar instead; negative ports are
    /// rejected.
    static func loadRunnerSession(path: String) -> RunnerSessionFile? {
        guard let data = FileManager.default.contents(atPath: path),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sessionId = object["sessionId"] as? String, !sessionId.isEmpty,
              let port = Self.integer(object["port"]), port >= 0,
              let pid = Self.integer(object["pid"]), pid > 0, pid <= Int(Int32.max)
        else { return nil }
        return RunnerSessionFile(sessionId: sessionId, port: port, pid: Int32(pid))
    }

    static func loadOwner(path: String) -> KeepAliveOwner? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(KeepAliveOwner.self, from: data)
    }

    private static func integer(_ value: Any?) -> Int? {
        switch value {
        case let number as NSNumber: return number.intValue
        case let string as String: return Int(string)
        default: return nil
        }
    }

    /// The runner names its file `<pid>-<unix nanoseconds>.grantiva`; order on
    /// that timestamp and fall back to the file's modification date.
    static func sortKey(fileName: String, path: String) -> Double {
        let stem = (fileName as NSString).deletingPathExtension
        if let dash = stem.firstIndex(of: "-"), let nanos = Double(stem[stem.index(after: dash)...]) {
            return nanos / 1_000_000_000
        }
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        return (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
    }
}
