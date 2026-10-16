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
    /// `runner-start` for a `grantiva runner start` session, nil for
    /// `run --keep-alive` (see `KeepAliveOwner.command`).
    public let command: String?
    /// False while the runner is up but has not published its own session
    /// file (L52, L54, L55): a `run --keep-alive` still in its flows, or a
    /// `runner start` whose session flow has not armed the hold. Such a
    /// session has no session ID or port yet (`port` is 0), and `path` is
    /// its owner sidecar.
    public let isPublished: Bool
    /// The runner's kernel start time when grantiva recorded it, so a stop
    /// never signals another process that reused the pid.
    public let runnerStartTime: Int64?

    public init(
        sessionId: String, port: Int, pid: Int32, udid: String?, path: String,
        projectDirectory: String? = nil, platform: Platform? = nil,
        ownerPid: Int32? = nil, detached: Bool? = nil, appId: String? = nil,
        command: String? = nil, isPublished: Bool = true, runnerStartTime: Int64? = nil
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
        self.command = command
        self.isPublished = isPublished
        self.runnerStartTime = runnerStartTime
    }

    /// A session whose runner has not published its file yet, from its
    /// owner sidecar at `path`.
    init(starting owner: KeepAliveOwner, path: String) {
        self.init(
            sessionId: "", port: 0, pid: owner.runnerPid, udid: owner.udid, path: path,
            projectDirectory: owner.projectDirectory.map(KeepAliveOwner.canonicalDirectory),
            platform: owner.platform, ownerPid: owner.grantivaPid, detached: owner.detached, appId: owner.appId,
            command: owner.command, isPublished: false, runnerStartTime: owner.runnerStartTime
        )
    }

    /// A foreground `runner start`: its holder reads a teardown's stop marker
    /// when its runner exits (L36).
    public var isForegroundRunnerStart: Bool {
        command == KeepAliveOwner.runnerStartCommand && detached == false
    }

    /// The platform the session drives, inferred from the device ID's shape
    /// when not recorded.
    public var resolvedPlatform: Platform {
        platform ?? (udid.map(DeviceID.isAndroidSerial) == true ? .android : .ios)
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
    /// `runner-start` for a `grantiva runner start` session, nil for
    /// `run --keep-alive` and sidecars written by earlier versions.
    public let command: String?
    /// The runner's kernel start time (seconds since 1970), so a stop can
    /// tell the runner from a process that reused its pid. Absent in
    /// sidecars written by earlier versions.
    public let runnerStartTime: Int64?

    public static let runnerStartCommand = "runner-start"

    public init(
        udid: String, runnerPid: Int32, grantivaPid: Int32 = getpid(), createdAt: Date = Date(),
        projectDirectory: String? = nil, platform: Platform? = nil, detached: Bool? = nil, appId: String? = nil,
        command: String? = nil, runnerStartTime: Int64? = nil
    ) {
        self.udid = udid
        self.runnerPid = runnerPid
        self.grantivaPid = grantivaPid
        self.createdAt = createdAt
        self.projectDirectory = projectDirectory
        self.platform = platform
        self.detached = detached
        self.appId = appId
        self.command = command
        self.runnerStartTime = runnerStartTime
    }

    /// A foreground `runner start`: the grantiva process holding it reads a
    /// teardown's stop marker when its runner exits (L36).
    public var isForegroundRunnerStart: Bool {
        command == Self.runnerStartCommand && detached == false
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
    ///
    /// A zombie (exited, not yet reaped by its parent) also answers
    /// `kill(pid, 0)` but is gone: a keep-alive holder started by a harness
    /// that waits on it only after `runner stop` returns made the stop wait
    /// its full 30 s and fail although the holder had exited 0 (N-01).
    public static func processIsAlive(_ pid: Int32) -> Bool {
        guard pid > 0 else { return false }
        guard kill(pid, 0) == 0 || errno == EPERM else { return false }
        return !ProcessLookup.isZombie(pid)
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
        appID: String? = nil,
        command: String? = nil
    ) -> KeepAliveOwner? {
        let owner = KeepAliveOwner(
            udid: udid, runnerPid: runnerPid,
            projectDirectory: KeepAliveOwner.canonicalDirectory(projectDirectory),
            platform: platform ?? (DeviceID.isAndroidSerial(udid) ? .android : .ios),
            detached: detached,
            appId: appID.flatMap { $0.isEmpty ? nil : $0 },
            command: command,
            runnerStartTime: RunnerStopMarker.processStartTime(runnerPid)
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
        stopMarkers.removeUnlessHeld(runnerPid: runnerPid)
    }

    /// Teardown stop markers live beside the owner files and go with them.
    public var stopMarkers: RunnerStopMarker {
        RunnerStopMarker(directory: directory, isProcessAlive: isProcessAlive)
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
        if stopMarkers.removeUnlessHeld(runnerPid: runnerPid) { removed.append(stopMarkers.path(runnerPid)) }
        return removed
    }

    /// Deletes the session files of keep-alive runners that held `udid` and are
    /// no longer running: their `<pid>.owner.json` sidecar and the runner's own
    /// `<pid>-<timestamp>.grantiva` file. `runnerPids` adds runners known to
    /// have held the device (for example ones just killed) whose sidecar is
    /// missing. A runner file whose pid is dead and that has no sidecar at all
    /// goes too (L12): the runner's file carries no device, so with its
    /// sidecar gone it belongs to no live session. Live runners, and dead
    /// ones whose sidecar names another device, are left alone. Returns the
    /// removed paths.
    @discardableResult
    public func removeSessions(udid: String, runnerPids: [Int32] = []) -> [String] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: directory) else { return [] }
        let allOwners = contents
            .filter { $0.hasSuffix(".\(Self.ownerExtension)") }
            .compactMap { Self.loadOwner(path: "\(directory)/\($0)") }
        let owners = allOwners
            .filter { $0.udid.caseInsensitiveCompare(udid) == .orderedSame }
            .map(\.runnerPid)
        let recorded = Set(allOwners.map(\.runnerPid))
        let unclaimed = contents.compactMap(Self.runnerPid(fileName:)).filter { !recorded.contains($0) }
        let pids = Set(owners + runnerPids + unclaimed).filter { !isProcessAlive($0) }
        var removed: [String] = []
        for name in contents.sorted() {
            let isOwner = pids.contains { name == "\($0).\(Self.ownerExtension)" }
            let isRunner = Self.runnerPid(fileName: name).map(pids.contains) == true
            guard isOwner || isRunner else { continue }
            let path = "\(directory)/\(name)"
            if (try? fm.removeItem(atPath: path)) != nil { removed.append(path) }
        }
        let markers = stopMarkers
        for pid in pids.sorted() where markers.removeUnlessHeld(runnerPid: pid) {
            removed.append(markers.path(pid))
        }
        markers.sweep()
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
                    ownerPid: owner?.grantivaPid, detached: owner?.detached, appId: owner?.appId,
                    command: owner?.command, runnerStartTime: owner?.runnerStartTime
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

    /// Sessions whose runner is up but has not published its session file
    /// yet (L38-a): an owner sidecar with a live runner and no
    /// `<pid>-*.grantiva`. A sidecar held by a grantiva process that is gone
    /// is an orphan, not a start in progress, and is left out unless
    /// `includingOrphans` (for `runner stop` and teardown, which clean
    /// orphans up).
    public func startingSessions(includingOrphans: Bool = false) -> [KeepAliveOwner] {
        startingOwners(includingOrphans: includingOrphans).map(\.owner)
    }

    private func startingOwners(includingOrphans: Bool) -> [(owner: KeepAliveOwner, path: String)] {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: directory) else { return [] }
        let published = Set(contents.compactMap(Self.runnerPid(fileName:)))
        return contents.sorted()
            .filter { $0.hasSuffix(".\(Self.ownerExtension)") }
            .compactMap { name in Self.loadOwner(path: "\(directory)/\(name)").map { ($0, "\(directory)/\(name)") } }
            .filter { owner, _ in
                !published.contains(owner.runnerPid) && isProcessAlive(owner.runnerPid)
                    && (includingOrphans || !(owner.detached == false && !isProcessAlive(owner.grantivaPid)))
            }
    }

    /// Every keep-alive session a grantiva command can reach: the published
    /// ones (`liveSessions`, newest first), then the ones still starting
    /// (`isPublished == false`). The one lookup `runner stop`, both device
    /// teardowns, `hierarchy`, `runner dump-hierarchy` and the MCP server
    /// share (L52, L54, L55), so a run still in its flows is found by all of
    /// them: a session is a live owner sidecar whose runner is alive, with or
    /// without the runner's published file, which adds the port and the
    /// session ID.
    public func sessions(includingOrphans: Bool = false) -> [KeepAliveSession] {
        liveSessions(includingOrphans: includingOrphans)
            + startingOwners(includingOrphans: includingOrphans).map { KeepAliveSession(starting: $0.owner, path: $0.path) }
    }

    /// Existing session metadata paths for `udid`, before a teardown stops
    /// their runners. The stop removes these files itself; force teardown uses
    /// this snapshot to report that preliminary cleanup rather than losing it
    /// when its later reaper sees an already-clean session directory.
    public func sessionFilePaths(udid: String) -> [String] {
        let fm = FileManager.default
        let paths = sessions(includingOrphans: true)
            .filter { $0.udid?.caseInsensitiveCompare(udid) == .orderedSame }
            .flatMap { session in
                [session.path, ownerPath(runnerPid: session.pid)]
            }
            .filter { fm.fileExists(atPath: $0) }
        return Array(Set(paths)).sorted()
    }

    /// The live foreground `runner start` sessions recorded for `udid`, whose
    /// holder is alive: the runners a teardown of that device marks before
    /// stopping them (L36). Detached starts and `run --keep-alive` runs read
    /// no marker, so they get none.
    public func foregroundRunnerStarts(udid: String) -> [KeepAliveOwner] {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: directory) else { return [] }
        return contents.sorted()
            .filter { $0.hasSuffix(".\(Self.ownerExtension)") }
            .compactMap { Self.loadOwner(path: "\(directory)/\($0)") }
            .filter {
                $0.udid.caseInsensitiveCompare(udid) == .orderedSame && $0.isForegroundRunnerStart
                    && isProcessAlive($0.runnerPid) && isProcessAlive($0.grantivaPid)
            }
    }

    /// The pid in a runner's `<pid>-<timestamp>.grantiva` file name.
    static func runnerPid(fileName: String) -> Int32? {
        guard fileName.hasSuffix(".\(runnerExtension)"), let dash = fileName.firstIndex(of: "-") else { return nil }
        return Int32(fileName[..<dash])
    }

    /// The session held by `runnerPid`, if its file has appeared yet.
    public func session(forRunnerPid runnerPid: Int32) -> KeepAliveSession? {
        liveSessions().first { $0.pid == runnerPid }
    }

    /// The newest live session, or the live session for `udid` when given.
    /// A matching session that has not published yet is "starting, retry"
    /// (L52), as the MCP server says.
    public func locate(udid: String? = nil) throws -> KeepAliveSession {
        let session = try locateIncludingStarting(udid: udid)
        guard session.isPublished else { throw RunnerSessionInfo.startingError(platform: session.resolvedPlatform) }
        return session
    }

    /// As `locate`, but a session still starting is returned rather than
    /// thrown, for callers that report it themselves.
    public func locateIncludingStarting(udid: String? = nil) throws -> KeepAliveSession {
        let all = sessions()
        guard !all.isEmpty else {
            throw GrantivaError.noRunnerSession()
        }
        guard let udid else { return all[0] }

        if let match = all.first(where: { $0.udid == udid }) {
            return match
        }
        let available = all.map { $0.udid ?? "pid \($0.pid) (unknown udid)" }.joined(separator: ", ")
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
