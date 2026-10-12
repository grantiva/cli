import Foundation
import GrantivaCore

/// The `--json` document of `runner start` and `runner stop`: pid and port
/// are numbers; the app and device keys follow the platform (`bundleId` +
/// `udid` on iOS, `applicationId` + `serial` on Android). `bundle_id`, and
/// `udid` on Android, are the 2.1 names, kept for one release (deprecated).
/// A stop document has the same keys plus `runnerPid`, `killed` and
/// `reaped` (and `alreadyExited`, `sessions` when they apply).
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
    /// Device helpers `runner stop` ended after the runner (L04).
    var reaped: [ReapedProcess]?
    /// A `stopped` document writes `port` and the app ID as `null` when the
    /// session did not record them, so it always carries start's keys (L13).
    var nullWhenUnrecorded = false

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
        if let port {
            try container.encode(port, forKey: "port")
        } else if nullWhenUnrecorded {
            try container.encodeNil(forKey: "port")
        }
        try container.encodeIfPresent(platform?.rawValue, forKey: "platform")
        try container.encodeIfPresent(log, forKey: "log")
        try container.encodeIfPresent(killed, forKey: "killed")
        try container.encodeIfPresent(alreadyExited, forKey: "alreadyExited")
        try container.encodeIfPresent(sessions, forKey: "sessions")
        try container.encodeIfPresent(reaped, forKey: "reaped")
        let android = platform == .android
        if appID != nil || nullWhenUnrecorded {
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
