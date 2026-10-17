import Foundation

/// Shared session state persisted to `.grantiva/session.json`.
///
/// The file names the app, device and port the way `runner start --json`
/// does on the same platform: `bundleId` and `udid` on iOS, `applicationId`
/// and `serial` (with `udid`) on Android, and `port` (L43). 2.1.0 wrote
/// `wdaPort` on both platforms and `bundleId` on Android too; those stay beside
/// the new keys for one release (`LegacyJSONKeys.sessionFileTwins`) and are
/// still read. `state` is `starting` from the moment the runner is spawned
/// until its driver answers, then `ready` (L38-a); a file without it is ready.
/// `startedAt` is an ISO 8601 UTC string; files from earlier builds that wrote
/// Apple-reference seconds still decode.
public struct RunnerSessionInfo: Codable, Sendable {
    public enum State: String, Codable, Sendable {
        case starting, ready
    }

    public let pid: Int32
    /// The driver port (`port` in the file); 0 while a starting session's
    /// runner has not reported it yet.
    public let wdaPort: UInt16
    /// The app the session launched: bundle ID on iOS, application ID on Android.
    public let bundleId: String
    public let udid: String
    public let startedAt: Date
    /// The platform the session drives. Absent in files written by earlier
    /// versions; `drivesPlatform` then falls back to the device ID's shape.
    public let platform: Platform?
    /// nil in files written before the state was recorded: those were
    /// written once the driver answered.
    public let state: State?

    public static let path = ".grantiva/session.json"

    public init(
        pid: Int32, wdaPort: UInt16, bundleId: String, udid: String, startedAt: Date, platform: Platform? = nil,
        state: State? = .ready
    ) {
        self.pid = pid
        self.wdaPort = wdaPort
        self.bundleId = bundleId
        self.udid = udid
        self.startedAt = startedAt
        self.platform = platform
        self.state = state
    }

    /// The file `runner start` writes the moment it spawns the runner, before
    /// the driver answers: no port yet. It is written again with `port` once
    /// the runner reports WDA's port, still `starting` until WDA has its
    /// session (side finding 12).
    public static func starting(
        pid: Int32, bundleId: String, udid: String, startedAt: Date, platform: Platform, port: UInt16 = 0
    ) -> RunnerSessionInfo {
        RunnerSessionInfo(pid: pid, wdaPort: port, bundleId: bundleId, udid: udid, startedAt: startedAt, platform: platform, state: .starting)
    }

    /// False while the runner has been spawned but its driver has not
    /// answered yet.
    public var isReady: Bool { state != .starting }

    /// What session tools, `resources/read` and `dump-hierarchy` answer while
    /// a session is starting. It names the driver's port once the runner has
    /// reported it (`port` > 0), and says the port is not known yet before.
    public static func startingError(platform: Platform, port: UInt16? = nil) -> GrantivaError {
        let driver = platform == .android ? "UIAutomator2" : "WDA"
        if let port, port > 0 {
            return .unavailable("The runner session is starting (\(driver) on port \(port) has no session yet). Retry in a few seconds.")
        }
        return .unavailable("The runner session is starting (\(driver) has no session yet; its port is not known yet). Retry in a few seconds.")
    }

    /// `startingError` for this session, with the port it recorded.
    public var startingError: GrantivaError {
        Self.startingError(platform: resolvedPlatform, port: wdaPort)
    }

    private var resolvedPlatform: Platform {
        platform ?? (DeviceID.isAndroidSerial(udid) ? .android : .ios)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: LegacyJSONKeys.self)
        let android = resolvedPlatform == .android
        try container.encode(pid, forKey: "pid")
        if isReady || wdaPort > 0 {
            try container.encode(wdaPort, forKey: "port")
            try container.encode(wdaPort, forKey: "wdaPort")
        }
        try container.encode(bundleId, forKey: android ? "applicationId" : "bundleId")
        if android { try container.encode(bundleId, forKey: "bundleId") }
        try container.encode(udid, forKey: "udid")
        if android { try container.encode(udid, forKey: "serial") }
        try container.encodeIfPresent(platform?.rawValue, forKey: "platform")
        try container.encode(Self.isoString(startedAt), forKey: "startedAt")
        try container.encode((state ?? .ready).rawValue, forKey: "state")
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: LegacyJSONKeys.self)
        pid = try container.decode(Int32.self, forKey: "pid")
        wdaPort = try container.decodeIfPresent(UInt16.self, forKey: "port")
            ?? container.decodeIfPresent(UInt16.self, forKey: "wdaPort") ?? 0
        bundleId = try container.decodeIfPresent(String.self, forKey: "applicationId")
            ?? container.decodeIfPresent(String.self, forKey: "bundleId") ?? ""
        guard let device = try container.decodeIfPresent(String.self, forKey: "udid")
            ?? container.decodeIfPresent(String.self, forKey: "serial") else {
            throw DecodingError.keyNotFound(LegacyJSONKeys(stringValue: "udid"), .init(codingPath: [], debugDescription: "No udid or serial"))
        }
        udid = device
        startedAt = Self.decodeStartedAt(from: container)
        platform = try container.decodeIfPresent(Platform.self, forKey: "platform")
        state = try container.decodeIfPresent(State.self, forKey: "state")
    }

    /// `startedAt` as an ISO 8601 UTC string (`2026-10-15T18:48:12Z`), the
    /// representation README and docs/mcp.md promise for every date field.
    static func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }

    /// Reads the ISO 8601 string this version writes, and the numeric
    /// Apple-reference seconds that earlier builds wrote.
    private static func decodeStartedAt(from container: KeyedDecodingContainer<LegacyJSONKeys>) -> Date {
        let key = LegacyJSONKeys(stringValue: "startedAt")
        if let text = try? container.decodeIfPresent(String.self, forKey: key) {
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: text) { return date }
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: text) { return date }
        }
        if let seconds = try? container.decodeIfPresent(Double.self, forKey: key) {
            return Date(timeIntervalSinceReferenceDate: seconds)
        }
        return Date(timeIntervalSinceReferenceDate: 0)
    }

    /// The file's bytes: sorted keys, `startedAt` as an ISO 8601 string.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> RunnerSessionInfo {
        try JSONDecoder().decode(RunnerSessionInfo.self, from: data)
    }

    /// Whether this session belongs to `platform`: the recorded platform, or
    /// for older files, whether the device ID is shaped like an adb serial.
    public func drivesPlatform(_ platform: Platform) -> Bool {
        if let recorded = self.platform { return recorded == platform }
        return DeviceID.isAndroidSerial(udid) == (platform == .android)
    }

    public func write() throws {
        let dir = (Self.path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try encoded().write(to: URL(fileURLWithPath: Self.path), options: .atomic)
    }

    public static func load() throws -> RunnerSessionInfo {
        try decode(Data(contentsOf: URL(fileURLWithPath: path)))
    }

    public static func remove() {
        try? FileManager.default.removeItem(atPath: path)
    }

    /// Removes `<directory>/.grantiva/session.json` when it records the
    /// runner `runnerPid` (on `udid`, when given): a teardown run from any
    /// directory takes the stopped session's project file with it (L73).
    /// A file naming another runner, or that cannot be read, is kept.
    /// Returns the path removed.
    @discardableResult
    public static func removeProjectSession(in directory: String, runnerPid: Int32, udid: String? = nil) -> String? {
        let file = (directory as NSString).appendingPathComponent(path)
        guard let data = FileManager.default.contents(atPath: file),
              let session = try? decode(data), session.pid == runnerPid,
              udid.map({ session.udid.caseInsensitiveCompare($0) == .orderedSame }) ?? true,
              (try? FileManager.default.removeItem(atPath: file)) != nil
        else { return nil }
        return file
    }

    /// Check if the session process is still alive.
    public var isAlive: Bool {
        kill(pid, 0) == 0
    }

    /// PIDs are reusable; confirm the current process is still the runner that
    /// this persisted session is allowed to control.
    public func ownsRunnerProcess(in psOutput: String) -> Bool {
        for line in psOutput.split(separator: "\n", omittingEmptySubsequences: true) {
            let fields = line.split(maxSplits: 2, whereSeparator: { $0 == " " || $0 == "\t" })
            guard fields.count == 3, Int32(fields[0]) == pid else { continue }
            guard let executable = fields[2].split(whereSeparator: { $0 == " " || $0 == "\t" }).first else {
                return false
            }
            return URL(fileURLWithPath: String(executable)).lastPathComponent.lowercased() == "grantiva-runner"
        }
        return false
    }
}
