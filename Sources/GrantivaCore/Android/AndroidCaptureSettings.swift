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

    public init(adb: ADB, stateDirectory: String = ".grantiva") {
        self.adb = adb
        self.stateDirectory = stateDirectory
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
    public func restore(serial: String) async {
        let path = Self.statePath(serial: serial, directory: stateDirectory)
        let saved = (try? Data(contentsOf: URL(fileURLWithPath: path)))
            .flatMap { try? JSONDecoder().decode([String: String?].self, from: $0) } ?? [:]
        _ = try? await adb.shell(serial: serial, "am broadcast -a com.android.systemui.demo -e command exit")
        for setting in Self.trackedSettings {
            guard let entry = saved[setting.id] else { continue }
            let command: String
            if let value = entry {
                command = "settings put \(setting.namespace) \(setting.key) \(value)"
            } else {
                command = "settings delete \(setting.namespace) \(setting.key)"
            }
            do {
                try await adb.shell(serial: serial, command)
            } catch {
                GrantivaLog.logger.warning("could not restore \(setting.id) on \(serial): \(error)")
            }
        }
        try? FileManager.default.removeItem(atPath: path)
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
