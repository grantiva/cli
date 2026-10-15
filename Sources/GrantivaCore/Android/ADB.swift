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

    /// Starts the app's launcher activity with `monkey`. Both of monkey's
    /// streams are read (its abort line is on stdout, its argument trace on
    /// stderr) and a failure is reported in one line, never as the trace.
    public func launch(serial: String, applicationId: String) async throws {
        let output: String
        do {
            output = try await execute(line(serial, "shell monkey -p \(shellQuoted(applicationId)) -c android.intent.category.LAUNCHER --pct-syskeys 0 1 2>&1"))
        } catch GrantivaError.commandFailed(let message, _) {
            throw Self.launchFailure(output: message, applicationId: applicationId, serial: serial)
        }
        if output.contains(Self.monkeyNoActivities) {
            throw Self.launchFailure(output: output, applicationId: applicationId, serial: serial)
        }
    }

    static let monkeyNoActivities = "No activities found to run"

    /// monkey says "No activities found" for a package that is not installed
    /// (or has no launcher activity); anything else is reported by monkey's
    /// own last status line, without its argument trace.
    static func launchFailure(output: String, applicationId: String, serial: String) -> GrantivaError {
        if output.contains(monkeyNoActivities) {
            return .unavailable(
                GrantivaError.notInstalledRoot(appID: applicationId, device: serial)
                    + " (or has no launcher activity). Install it first, e.g. grantiva build install --device \(serial)."
            )
        }
        let meaningful = output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in
                !line.isEmpty && !line.hasPrefix("args:") && !line.hasPrefix("arg:") && !line.hasPrefix("arg=")
                    && !line.hasPrefix("data=") && !line.hasPrefix("bash arg:")
            }
        let status = meaningful.last { $0.hasPrefix("**") } ?? meaningful.last
        let reason = status.map { $0.drop { $0 == "*" }.trimmingCharacters(in: .whitespaces) } ?? "monkey failed"
        return .commandFailed("Could not launch \(applicationId) on \(serial): \(reason)", 1)
    }

    /// True when `pm list packages` lists exactly this package (the listing
    /// is a substring match).
    public func isInstalled(serial: String, applicationId: String) async throws -> Bool {
        let output = try await shell(serial: serial, "pm list packages \(shellQuoted(applicationId))")
        return output.components(separatedBy: .newlines).contains { $0.trimmingCharacters(in: .whitespaces) == "package:\(applicationId)" }
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

    /// Puts the display back in touch mode when key input (`pressKey`, a
    /// D-pad event) has taken it out, which leaves the focused view
    /// highlighted in every screenshot after it (N-12). A touch DOWN then
    /// CANCEL at the bottom-left corner pixel: that pixel is the navigation
    /// bar (or, with none, the very edge of the app), a cancelled touch fires
    /// no click, and the status bar is avoided because a touch there opens
    /// the notification shade. Nothing is sent when the display is already
    /// in touch mode or its state cannot be read. Returns whether it touched.
    @discardableResult
    public func restoreTouchMode(serial: String) async throws -> Bool {
        let output = try await shell(serial: serial, "dumpsys window | grep -E 'mInTouchMode=|cur=[0-9]+x[0-9]+'; true")
        guard let state = Self.parseTouchModeState(output), !state.inTouchMode else { return false }
        let y = state.height - 1
        try await shell(serial: serial, "input motionevent DOWN 0 \(y) && input motionevent CANCEL 0 \(y)")
        return true
    }

    /// The touch-mode flag and the current logical (rotated) display height
    /// from `dumpsys window`; nil when either is missing.
    static func parseTouchModeState(_ output: String) -> (inTouchMode: Bool, height: Int)? {
        let lines = output.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let flag = lines.first(where: { $0.hasPrefix("mInTouchMode=") }) else { return nil }
        guard let sizeLine = lines.first(where: { $0.contains("cur=") }),
              let range = sizeLine.range(of: "cur=") else { return nil }
        let size = sizeLine[range.upperBound...].prefix { !$0.isWhitespace }.split(separator: "x")
        guard size.count == 2, let height = Int(size[1]), height > 0 else { return nil }
        return (flag == "mInTouchMode=true", height)
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

    /// `adb forward tcp:0 tcp:<devicePort>` prints the local port it chose.
    public func forward(serial: String, devicePort: Int) async throws -> Int {
        let output = try await execute(line(serial, "forward tcp:0 tcp:\(devicePort)"))
        guard let port = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)), port > 0 else {
            throw GrantivaError.commandFailed("Could not forward a local port to \(serial):\(devicePort): \(output)", 1)
        }
        return port
    }

    public func removeForward(serial: String, localPort: Int) async throws {
        _ = try await execute(line(serial, "forward --remove tcp:\(localPort)"))
    }

    /// Local tcp ports forwarded for `serial`, from `adb forward --list`.
    public func forwards(serial: String) async throws -> [Int] {
        Self.parseForwards(try await execute(line(serial, "forward --list")), serial: serial)
    }

    /// Lines look like `<serial> tcp:<local> tcp:<remote>`; only this serial's
    /// `tcp:` locals count. `--remove-all` is host-wide, so it is never used.
    public static func parseForwards(_ output: String, serial: String) -> [Int] {
        output.components(separatedBy: "\n").compactMap { raw in
            let fields = raw.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard fields.count >= 2, fields[0] == serial, fields[1].hasPrefix("tcp:") else { return nil }
            return Int(fields[1].dropFirst(4))
        }
    }

    public func removeForwards(serial: String) async throws {
        for port in try await forwards(serial: serial) {
            try await removeForward(serial: serial, localPort: port)
        }
    }

    /// Blocks for `seconds`; screenrecord exits when its time limit elapses.
    public func screenrecord(serial: String, remotePath: String, seconds: Int) async throws {
        _ = try await execute(line(serial, "shell screenrecord --time-limit \(seconds) \(shellQuoted(remotePath))"))
    }

    public func pull(serial: String, remotePath: String, to localPath: String) async throws {
        _ = try await execute(line(serial, "pull \(shellQuoted(remotePath)) \(shellQuoted(localPath))"))
    }

    public func removeFile(serial: String, remotePath: String) async throws {
        _ = try await execute(line(serial, "shell rm -f \(shellQuoted(remotePath))"))
    }

    /// Where `sync` finds perl for its alarm.
    public static let perlPath = "/usr/bin/perl"

    /// Flushes the guest's page cache to its data partition. A wedged guest
    /// can hang `adb shell sync`, so adb runs under a `timeoutSeconds` alarm
    /// (perl's `alarm` survives the `exec`): the adb child is killed when it
    /// fires rather than left running. Without an executable perl the flush
    /// still runs, plainly (the caller's bounded wait is then the only
    /// bound), and a warning says so once per process.
    public func sync(
        serial: String, timeoutSeconds: Int = 5,
        perl: String = ADB.perlPath,
        isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) },
        warn: (String) -> Void = ADB.warnOnce
    ) async throws {
        let command = line(serial, "shell \(shellQuoted("sync"))")
        guard isExecutable(perl) else {
            warn("\(perl) is not executable, so `adb shell sync` runs without its \(timeoutSeconds) s alarm; a hung flush is abandoned (not killed) when the teardown's wait ends.")
            _ = try await execute(command)
            return
        }
        _ = try await execute("\(shellQuoted(perl)) -e 'alarm shift; exec @ARGV' \(timeoutSeconds) " + command)
    }

    private static let warnedLock = NSLock()
    nonisolated(unsafe) private static var warned = false

    /// Logs `message` as a warning the first time only.
    public static func warnOnce(_ message: String) {
        let first = warnedLock.withLock {
            defer { warned = true }
            return !warned
        }
        if first { GrantivaLog.logger.warning("\(message)") }
    }

    public func emuKill(serial: String) async throws {
        _ = try await execute(line(serial, "emu kill"))
    }
}
