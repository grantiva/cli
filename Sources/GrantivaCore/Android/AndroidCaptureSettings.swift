import Foundation

/// Puts an Android device into a deterministic state for screenshots and
/// puts it back afterwards. The previous values are written to disk first so
/// a crashed run can be undone by the next one.
public struct AndroidCaptureSettings: Sendable {
    public struct Setting: Sendable, Equatable {
        public let namespace: String
        public let key: String
        public let captureValue: String
        var id: String { "\(namespace)/\(key)" }
    }

    /// In the order they are read, and written back.
    public static let trackedSettings: [Setting] = [
        Setting(namespace: "global", key: "sysui_demo_allowed", captureValue: "1"),
        Setting(namespace: "global", key: "window_animation_scale", captureValue: "0"),
        Setting(namespace: "global", key: "transition_animation_scale", captureValue: "0"),
        Setting(namespace: "global", key: "animator_duration_scale", captureValue: "0"),
        Setting(namespace: "system", key: "accelerometer_rotation", captureValue: "0"),
        Setting(namespace: "system", key: "user_rotation", captureValue: "0"),
    ]

    static let demoCommands = [
        "am broadcast -a com.android.systemui.demo -e command enter",
        "am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0941",
        "am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false",
        "am broadcast -a com.android.systemui.demo -e command notifications -e visible false",
        "am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4",
        "am broadcast -a com.android.systemui.demo -e command network -e mobile show -e datatype none -e level 4",
    ]

    private let adb: ADB
    private let stateDirectory: String
    private let reconnectTimeout: TimeInterval
    private let absentGrace: TimeInterval
    private let pollInterval: Duration

    /// `reconnectTimeout` bounds the wait for a device that left adb during a
    /// restore (a freshly booted emulator's adbd restarts once shortly after
    /// boot); `absentGrace` is the shorter wait for a serial adb did not list
    /// at all when the restore started; `pollInterval` is how often `adb
    /// devices` is read meanwhile.
    public init(
        adb: ADB, stateDirectory: String = ".grantiva",
        reconnectTimeout: TimeInterval = 30, absentGrace: TimeInterval = 5,
        pollInterval: Duration = .milliseconds(500)
    ) {
        self.adb = adb
        self.stateDirectory = stateDirectory
        self.reconnectTimeout = reconnectTimeout
        self.absentGrace = absentGrace
        self.pollInterval = pollInterval
    }

    public static func statePath(serial: String, directory: String = ".grantiva") -> String {
        let safe = serial.replacingOccurrences(of: "[^A-Za-z0-9._-]", with: "_", options: .regularExpression)
        return "\(directory)/android-settings-\(safe).json"
    }

    /// Reads and saves every tracked value, then applies the capture state.
    public func prepare(serial: String) async throws {
        var saved: [String: String?] = [:]
        for setting in Self.trackedSettings {
            let value = try await adb.shell(serial: serial, "settings get \(setting.namespace) \(setting.key)")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            saved[setting.id] = value == "null" ? .some(nil) : .some(value)
        }
        try FileManager.default.createDirectory(atPath: stateDirectory, withIntermediateDirectories: true)
        try JSONEncoder().encode(saved).write(to: URL(fileURLWithPath: Self.statePath(serial: serial, directory: stateDirectory)))

        try await adb.shell(serial: serial, "settings put global sysui_demo_allowed 1")
        for command in Self.demoCommands {
            try await adb.shell(serial: serial, command)
        }
        for setting in Self.trackedSettings where setting.key != "sysui_demo_allowed" {
            try await adb.shell(serial: serial, "settings put \(setting.namespace) \(setting.key) \(setting.captureValue)")
        }
    }

    /// Exits demo mode and writes the saved values back. Never throws: a
    /// failed restore is logged and the state file is still removed so the
    /// next run does not loop on it.
    ///
    /// No state file means `prepare` never changed the device, so nothing is
    /// sent. A device that leaves adb mid-restore (`device '<serial>' not
    /// found`, `device offline`) is waited on once, for up to
    /// `reconnectTimeout`, and the failed command is retried. A device adb
    /// does not list at all when the restore starts gets only
    /// `absentGrace` to appear, so a dead emulator fails fast. A device that
    /// does not come back, or leaves again, gets a single warning and nothing
    /// more is sent to it. Returns the warnings it logged.
    @discardableResult
    public func restore(serial: String) async -> [String] {
        let path = Self.statePath(serial: serial, directory: stateDirectory)
        guard FileManager.default.fileExists(atPath: path) else { return [] }
        defer { try? FileManager.default.removeItem(atPath: path) }
        let saved = (try? Data(contentsOf: URL(fileURLWithPath: path)))
            .flatMap { try? JSONDecoder().decode([String: String?].self, from: $0) } ?? [:]

        var commands: [(id: String?, command: String)] = [(nil, "am broadcast -a com.android.systemui.demo -e command exit")]
        for setting in Self.trackedSettings {
            guard let entry = saved[setting.id] else { continue }
            if let value = entry {
                commands.append((setting.id, "settings put \(setting.namespace) \(setting.key) \(value)"))
            } else {
                commands.append((setting.id, "settings delete \(setting.namespace) \(setting.key)"))
            }
        }

        var warnings: [String] = []
        func warn(_ message: String) {
            GrantivaLog.logger.warning("\(message)")
            warnings.append(message)
        }
        func gone(_ detail: String) -> [String] {
            warn("could not restore Android settings on \(serial): the device \(detail)")
            return warnings
        }

        // A serial adb does not list at all is most likely a dead emulator:
        // give it a short grace rather than the full reconnect wait.
        var waitLimit = reconnectTimeout
        if let devices = try? await adb.devices(), !devices.contains(where: { $0.serial == serial }) {
            waitLimit = min(absentGrace, reconnectTimeout)
        }

        var waited = false
        for (id, command) in commands {
            do {
                try await adb.shell(serial: serial, command)
                continue
            } catch where Self.deviceLeftAdb(error) && !waited {
                waited = true
                guard await waitForDevice(serial: serial, timeout: waitLimit) else {
                    return gone("left adb and did not come back within \(Self.seconds(waitLimit)) s")
                }
                do {
                    try await adb.shell(serial: serial, command)
                } catch where Self.deviceLeftAdb(error) {
                    return gone("left adb again")
                } catch {
                    if let id { warn("could not restore \(id) on \(serial): \(error)") }
                }
            } catch where Self.deviceLeftAdb(error) {
                return gone("left adb again")
            } catch {
                // Exiting demo mode is best effort, as before.
                if let id { warn("could not restore \(id) on \(serial): \(error)") }
            }
        }
        return warnings
    }

    private static func seconds(_ interval: TimeInterval) -> String {
        interval >= 1 ? String(Int(interval)) : String(format: "%.2f", interval)
    }

    /// adb's own wordings for a device that is not (or no longer) attached.
    /// Only adb's phrasing counts: a command that ran on the device and
    /// printed "not found" (`settings: not found`) is an ordinary failure.
    /// `error: closed` is adb's transport dropping mid-command and `device
    /// still connecting` a device coming back; both clear once it is back.
    static func deviceLeftAdb(_ error: Error) -> Bool {
        let text: String
        if case GrantivaError.commandFailed(let message, _) = error { text = message } else { text = "\(error)" }
        if text.range(of: #"device '[^']*' not found"#, options: .regularExpression) != nil { return true }
        return ["device offline", "no devices/emulators found", "error: closed", "device still connecting"]
            .contains { text.contains($0) }
    }

    /// Polls `adb devices` until `serial` is listed as `device`, for up to
    /// `timeout`.
    private func waitForDevice(serial: String, timeout: TimeInterval) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .milliseconds(Int(timeout * 1000)))
        GrantivaLog.logger.info("\(serial) left adb; waiting up to \(Self.seconds(timeout)) s for it to come back before restoring settings")
        while true {
            if let devices = try? await adb.devices(), devices.contains(where: { $0.serial == serial && $0.isUsable }) {
                return true
            }
            if clock.now >= deadline { return false }
            try? await Task.sleep(for: pollInterval)
        }
    }

    /// A state file at the start of a run means the previous run crashed
    /// between `prepare` and `restore`. Returns true when a restore ran.
    public func restoreIfCrashed(serial: String) async -> Bool {
        guard FileManager.default.fileExists(atPath: Self.statePath(serial: serial, directory: stateDirectory)) else { return false }
        GrantivaLog.logger.warning("restoring Android settings left by an interrupted run on \(serial)")
        await restore(serial: serial)
        return true
    }
}
