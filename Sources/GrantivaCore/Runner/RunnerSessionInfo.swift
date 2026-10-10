import Foundation

/// Shared session state persisted to `.grantiva/session.json`.
public struct RunnerSessionInfo: Codable, Sendable {
    public let pid: Int32
    public let wdaPort: UInt16
    public let bundleId: String
    public let udid: String
    public let startedAt: Date
    /// The platform the session drives. Absent in files written by earlier
    /// versions; `drivesPlatform` then falls back to the device ID's shape.
    public let platform: Platform?

    public static let path = ".grantiva/session.json"

    public init(pid: Int32, wdaPort: UInt16, bundleId: String, udid: String, startedAt: Date, platform: Platform? = nil) {
        self.pid = pid
        self.wdaPort = wdaPort
        self.bundleId = bundleId
        self.udid = udid
        self.startedAt = startedAt
        self.platform = platform
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
