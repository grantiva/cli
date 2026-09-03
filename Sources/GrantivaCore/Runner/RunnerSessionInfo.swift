import Foundation

/// Shared session state persisted to `.grantiva/session.json`.
public struct RunnerSessionInfo: Codable, Sendable {
    public let pid: Int32
    public let wdaPort: UInt16
    public let bundleId: String
    public let udid: String
    public let startedAt: Date
    public let executablePath: String?

    public static let path = ".grantiva/session.json"

    public init(
        pid: Int32, wdaPort: UInt16, bundleId: String, udid: String, startedAt: Date,
        executablePath: String? = nil
    ) {
        self.pid = pid
        self.wdaPort = wdaPort
        self.bundleId = bundleId
        self.udid = udid
        self.startedAt = startedAt
        self.executablePath = executablePath
    }

    public func write() throws {
        let dir = (Self.path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(self)
        try data.write(to: URL(fileURLWithPath: Self.path))
    }

    public static func load() throws -> RunnerSessionInfo {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try JSONDecoder().decode(RunnerSessionInfo.self, from: data)
    }

    public static func remove() {
        try? FileManager.default.removeItem(atPath: path)
    }

    /// Check if the session process is still alive.
    public var isAlive: Bool {
        kill(pid, 0) == 0
    }

    /// A persisted PID can be reused after an unclean exit. Only signal it
    /// when it still names the runner executable recorded for this session.
    public var ownsRunningProcess: Bool {
        guard isAlive, let executablePath else { return false }
        // PROC_PIDPATHINFO_MAXSIZE is 4 * MAXPATHLEN, but the C macro is not
        // imported by every Swift SDK.
        var buffer = [CChar](repeating: 0, count: 4_096)
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return false }
        let path = String(decoding: buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
        let actual = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL
        let expected = URL(fileURLWithPath: executablePath).resolvingSymlinksInPath().standardizedFileURL
        return actual == expected
    }
}
