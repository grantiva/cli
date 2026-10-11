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

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: LegacyJSONKeys.self)
        try container.encode(status, forKey: "status")
        try container.encodeIfPresent(pid, forKey: "pid")
        try container.encodeIfPresent(runnerPid, forKey: "runnerPid")
        try container.encodeIfPresent(port, forKey: "port")
        try container.encodeIfPresent(platform?.rawValue, forKey: "platform")
        try container.encodeIfPresent(log, forKey: "log")
        try container.encodeIfPresent(killed, forKey: "killed")
        try container.encodeIfPresent(alreadyExited, forKey: "alreadyExited")
        try container.encodeIfPresent(sessions, forKey: "sessions")
        let android = platform == .android
        if let appID {
            if android {
                // `applicationId` is Android's name; `bundle_id` stays beside
                // it for one release (LegacyJSONKeys.platformTwins).
                try container.encode(appID, forKey: "applicationId")
                try container.encode(appID, forKey: "bundle_id")
            } else {
                try container.encodeWithAlias(appID, "bundleId")
            }
        }
        if let deviceID {
            try container.encode(deviceID, forKey: "udid")
            if android { try container.encode(deviceID, forKey: "serial") }
        }
    }
}
