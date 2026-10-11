import Foundation
import GrantivaCore

/// The `--json` document of `runner start` and `runner stop`: pid and port
/// are numbers; the app and device keys follow the platform (`bundleId` +
/// `udid` on iOS, `applicationId` + `serial` on Android). `bundle_id`, and
/// `udid` on Android, are the 2.1 names, kept for one release (deprecated).
struct RunnerLifecycleDocument: Encodable, Equatable {
    let status: String
    var pid: Int32?
    var runnerPid: Int32?
    var port: UInt16?
    var appID: String?
    var deviceID: String?
    var platform: Platform?
    var log: String?
    var killed: Bool?
    /// `runner stop` on a session whose runner had already exited.
    var alreadyExited: Bool?
    /// Every session `runner stop` released, when it released more than one.
    var sessions: [RunnerLifecycleDocument]?

    init(
        status: String, pid: Int32? = nil, port: UInt16? = nil, appID: String? = nil,
        deviceID: String? = nil, platform: Platform? = nil, log: String? = nil
    ) {
        self.status = status
        self.pid = pid
        self.port = port
        self.appID = appID
        self.deviceID = deviceID
        self.platform = platform
        self.log = log
    }

    // TODO: replace with LegacyJSONKeys after Task 4
    private struct Key: CodingKey {
        let stringValue: String
        init(_ value: String) { stringValue = value }
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(status, forKey: Key("status"))
        try container.encodeIfPresent(pid, forKey: Key("pid"))
        try container.encodeIfPresent(runnerPid, forKey: Key("runnerPid"))
        try container.encodeIfPresent(port, forKey: Key("port"))
        try container.encodeIfPresent(platform?.rawValue, forKey: Key("platform"))
        try container.encodeIfPresent(log, forKey: Key("log"))
        try container.encodeIfPresent(killed, forKey: Key("killed"))
        try container.encodeIfPresent(alreadyExited, forKey: Key("alreadyExited"))
        try container.encodeIfPresent(sessions, forKey: Key("sessions"))
        let android = platform == .android
        if let appID {
            try container.encode(appID, forKey: Key(android ? "applicationId" : "bundleId"))
            try container.encode(appID, forKey: Key("bundle_id"))
        }
        if let deviceID {
            try container.encode(deviceID, forKey: Key("udid"))
            if android { try container.encode(deviceID, forKey: Key("serial")) }
        }
    }
}
