import Foundation

public struct ADBDevice: Sendable, Equatable {
    public let serial: String
    public let state: String

    public init(serial: String, state: String) {
        self.serial = serial
        self.state = state
    }

    public var isEmulator: Bool { serial.hasPrefix("emulator-") }
    public var isUsable: Bool { state == "device" }
}

/// Every adb command Grantiva runs, as exact command lines. Output parsing
/// is static so it can be tested without a device.
public struct ADB: Sendable {
    public let path: String
    private let execute: @Sendable (String) async throws -> String

    public static let uiAutomator2Packages = ["io.appium.uiautomator2.server", "io.appium.uiautomator2.server.test"]

    public init(path: String, execute: @escaping @Sendable (String) async throws -> String = { try await GrantivaCore.shell($0) }) {
        self.path = path
        self.execute = execute
    }

    /// `'<adb>' [-s '<serial>'] <args...>`: every argument that is user data
    /// is quoted; fixed adb words are not, so the lines read like a terminal.
    func line(_ serial: String?, _ tail: String) -> String {
        var parts = [shellQuoted(path)]
        if let serial { parts += ["-s", shellQuoted(serial)] }
        parts.append(tail)
        return parts.joined(separator: " ")
    }

    public func devices() async throws -> [ADBDevice] {
        Self.parseDevices(try await execute(line(nil, "devices -l")))
    }

    public static func parseDevices(_ output: String) -> [ADBDevice] {
        output.components(separatedBy: "\n").compactMap { raw in
            let fields = raw.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard fields.count >= 2, fields[0] != "List", !fields[0].hasPrefix("*") else { return nil }
            return ADBDevice(serial: fields[0], state: fields[1])
        }
    }

    /// `adb emu avd name` prints the name and then `OK`.
    public func avdName(serial: String) async throws -> String {
        let output = try await execute(line(serial, "emu avd name"))
        guard let first = output.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespacesAndNewlines),
              !first.isEmpty, first != "OK" else {
            throw GrantivaError.commandFailed("Could not read the AVD name of \(serial)", 1)
        }
        return first
    }

    public func getprop(serial: String, _ key: String) async throws -> String {
        try await execute(line(serial, "shell getprop \(shellQuoted(key))")).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Runs one shell command on the device, passed as a single quoted argument.
    @discardableResult
    public func shell(serial: String, _ command: String) async throws -> String {
        try await execute(line(serial, "shell \(shellQuoted(command))"))
    }

    public func install(serial: String, apk: String, applicationId: String?) async throws {
        let command = line(serial, "install -r -t -d \(shellQuoted(apk))")
        do {
            _ = try await execute(command)
        } catch let error as GrantivaError {
            guard case .commandFailed(let message, _) = error,
                  message.contains("INSTALL_FAILED_UPDATE_INCOMPATIBLE"),
                  let applicationId else { throw error }
            try await uninstall(serial: serial, applicationId: applicationId)
            _ = try await execute(command)
        }
    }

    public func launch(serial: String, applicationId: String) async throws {
        _ = try await execute(line(serial, "shell monkey -p \(shellQuoted(applicationId)) -c android.intent.category.LAUNCHER --pct-syskeys 0 1"))
    }

    public func forceStop(serial: String, applicationId: String) async throws {
        _ = try await execute(line(serial, "shell am force-stop \(shellQuoted(applicationId))"))
    }

    public func uninstall(serial: String, applicationId: String) async throws {
        _ = try await execute(line(serial, "shell pm uninstall \(shellQuoted(applicationId))"))
    }

    public func screenshot(serial: String, to path: String) async throws {
        _ = try await execute(line(serial, "exec-out screencap -p > \(shellQuoted(path))"))
    }

    public func displaySize(serial: String) async throws -> (width: Int, height: Int) {
        let output = try await shell(serial: serial, "wm size")
        guard let size = Self.parseDisplaySize(output) else {
            throw GrantivaError.invalidArgument("Could not read the display size of \(serial): \(output)")
        }
        return size
    }

    /// `Override size` wins over `Physical size`.
    public static func parseDisplaySize(_ output: String) -> (width: Int, height: Int)? {
        func value(after label: String) -> (Int, Int)? {
            guard let lineText = output.components(separatedBy: "\n").first(where: { $0.hasPrefix(label) }) else { return nil }
            let dims = lineText.dropFirst(label.count).trimmingCharacters(in: .whitespaces).split(separator: "x")
            guard dims.count == 2, let w = Int(dims[0]), let h = Int(dims[1]) else { return nil }
            return (w, h)
        }
        return value(after: "Override size:") ?? value(after: "Physical size:")
    }

    public func density(serial: String) async throws -> Int {
        let output = try await shell(serial: serial, "wm density")
        guard let density = Self.parseDensity(output) else {
            throw GrantivaError.invalidArgument("Could not read the display density of \(serial): \(output)")
        }
        return density
    }

    public static func parseDensity(_ output: String) -> Int? {
        func value(after label: String) -> Int? {
            guard let lineText = output.components(separatedBy: "\n").first(where: { $0.hasPrefix(label) }) else { return nil }
            return Int(lineText.dropFirst(label.count).trimmingCharacters(in: .whitespaces))
        }
        return value(after: "Override density:") ?? value(after: "Physical density:")
    }

    public func packageUID(serial: String, applicationId: String) async throws -> Int? {
        Self.parsePackageUID(try await shell(serial: serial, "pm list packages -U \(shellQuoted(applicationId))"), applicationId: applicationId)
    }

    /// `pm list packages -U <id>` is a substring match; keep only the exact package.
    public static func parsePackageUID(_ output: String, applicationId: String) -> Int? {
        for raw in output.components(separatedBy: "\n") {
            let fields = raw.trimmingCharacters(in: .whitespaces).split(separator: " ")
            guard fields.count == 2, fields[0] == "package:\(applicationId)", fields[1].hasPrefix("uid:") else { continue }
            return Int(fields[1].dropFirst(4))
        }
        return nil
    }

    public func removeAllForwards(serial: String) async throws {
        _ = try await execute(line(serial, "forward --remove-all"))
    }

    public func emuKill(serial: String) async throws {
        _ = try await execute(line(serial, "emu kill"))
    }
}
