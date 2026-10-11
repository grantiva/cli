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
    private let pollInterval: Duration

    /// `reconnectTimeout` bounds the wait for a device that left adb during a
    /// restore (a freshly booted emulator's adbd restarts once shortly after
    /// boot); `pollInterval` is how often `adb devices` is read meanwhile.
    public init(
        adb: ADB, stateDirectory: String = ".grantiva",
        reconnectTimeout: TimeInterval = 30, pollInterval: Duration = .milliseconds(500)
    ) {
        self.adb = adb
        self.stateDirectory = stateDirectory
        self.reconnectTimeout = reconnectTimeout
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
    /// A device that leaves adb mid-restore (`device '<serial>' not found`,
    /// `device offline`) is waited on once, for up to `reconnectTimeout`,
    /// and the failed command is retried. One that does not come back gets a
    /// single warning and nothing more is sent to it. Returns the warnings
    /// it logged.
    @discardableResult
    public func restore(serial: String) async -> [String] {
        let path = Self.statePath(serial: serial, directory: stateDirectory)
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
        var waited = false
        for (id, command) in commands {
            do {
                try await adb.shell(serial: serial, command)
                continue
            } catch where Self.deviceLeftAdb(error) && !waited {
                waited = true
                guard await waitForDevice(serial: serial) else {
                    warn("could not restore Android settings on \(serial): the device left adb and did not come back within \(Int(reconnectTimeout)) s")
                    return warnings
                }
                do {
                    try await adb.shell(serial: serial, command)
                    continue
                } catch {
                    if let id { warn("could not restore \(id) on \(serial): \(error)") }
                }
            } catch where Self.deviceLeftAdb(error) {
                warn("could not restore Android settings on \(serial): the device left adb again")
                return warnings
            } catch {
                // Exiting demo mode is best effort, as before.
                if let id { warn("could not restore \(id) on \(serial): \(error)") }
            }
        }
        return warnings
    }

    /// adb's wordings for a device that is not (or no longer) attached.
    static func deviceLeftAdb(_ error: Error) -> Bool {
        let text: String
        if case GrantivaError.commandFailed(let message, _) = error { text = message } else { text = "\(error)" }
        return ["not found", "device offline", "no devices/emulators found"].contains { text.contains($0) }
    }

    /// Polls `adb devices` until `serial` is listed as `device`, for up to
    /// `reconnectTimeout`.
    private func waitForDevice(serial: String) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .milliseconds(Int(reconnectTimeout * 1000)))
        GrantivaLog.logger.info("\(serial) left adb; waiting up to \(Int(reconnectTimeout)) s for it to come back before restoring settings")
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
