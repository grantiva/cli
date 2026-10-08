import Darwin
import Foundation

/// Picks the emulator a run uses and boots an AVD when none is running.
public struct EmulatorManager: Sendable {
    public typealias Spawn = @Sendable (_ executable: String, _ arguments: [String]) throws -> Int32

    private let sdk: AndroidSDK
    private let adb: ADB
    private let execute: @Sendable (String) async throws -> String
    private let spawn: Spawn
    private let provenance: AndroidProvenance
    private let headless: Bool
    private let bootTimeout: TimeInterval
    private let pollInterval: TimeInterval

    public static let bootTimeoutVariable = "GRANTIVA_EMULATOR_BOOT_TIMEOUT_SECONDS"

    public init(
        sdk: AndroidSDK,
        adb: ADB,
        execute: @escaping @Sendable (String) async throws -> String = { try await GrantivaCore.shell($0) },
        spawn: @escaping Spawn = EmulatorManager.detachedSpawn,
        provenance: AndroidProvenance = .live,
        headless: Bool = false,
        bootTimeout: TimeInterval = EmulatorManager.configuredBootTimeout(),
        pollInterval: TimeInterval = 1
    ) {
        self.sdk = sdk
        self.adb = adb
        self.execute = execute
        self.spawn = spawn
        self.provenance = provenance
        self.headless = headless
        self.bootTimeout = bootTimeout
        self.pollInterval = pollInterval
    }

    public static func configuredBootTimeout(environment: [String: String] = ProcessInfo.processInfo.environment) -> TimeInterval {
        environment[bootTimeoutVariable].flatMap(Double.init) ?? 180
    }

    /// The emulator must outlive this process, so it is spawned into its own
    /// process group (ChildProcess does that) and never tracked by SignalRelay.
    /// Its output goes to a log file beside the provenance ledger.
    public static let detachedSpawn: Spawn = { executable, arguments in
        let logDir = AndroidProvenance.live.directory
        try FileManager.default.createDirectory(atPath: logDir, withIntermediateDirectories: true)
        let port = arguments.firstIndex(of: "-port").map { arguments[$0 + 1] } ?? "unknown"
        let log = Darwin.open("\(logDir)/emulator-\(port).log", O_CREAT | O_WRONLY | O_TRUNC | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard log >= 0 else {
            throw GrantivaError.commandFailed("Could not open the emulator log file", 1)
        }
        defer { Darwin.close(log) }
        let devnull = Darwin.open("/dev/null", O_RDONLY)
        defer { if devnull >= 0 { Darwin.close(devnull) } }
        let child = try ChildProcess.spawn(
            executable: executable, arguments: arguments,
            stdin: devnull >= 0 ? devnull : nil, stdout: log, stderr: log
        )
        return child.pid
    }

    public func listAVDs() async throws -> [String] {
        try await execute("\(shellQuoted(sdk.emulator)) -list-avds")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("INFO") && !$0.hasPrefix("WARNING") }
    }

    public static func choosePort(used: [String]) -> Int? {
        stride(from: 5554, through: 5584, by: 2).first { !used.contains("emulator-\($0)") }
    }

    public static func bootArguments(avd: String, port: Int, headless: Bool) -> [String] {
        var args = ["-avd", avd, "-port", String(port), "-no-snapshot-save", "-no-boot-anim"]
        if headless { args.append("-no-window") }
        return args
    }

    /// Spec rules: only running emulators count by default. With a configured
    /// AVD name, the running emulator with that name is used, else it is
    /// booted. Without one: a single running emulator, else a single existing
    /// AVD is booted, else the AVDs are listed.
    public func selectDevice(configured: String?) async throws -> BootedDevice {
        let devices = try await adb.devices()
        let broken = devices.filter { !$0.isUsable }
        let running = devices.filter { $0.isEmulator && $0.isUsable }
        var names: [String: String] = [:]
        for device in running {
            names[device.serial] = (try? await adb.avdName(serial: device.serial)) ?? device.serial
        }
        let brokenNote = broken.isEmpty ? "" : " Skipped: " + broken.map { "\($0.serial) is \($0.state)" }.joined(separator: ", ") + "."

        if let configured, !configured.isEmpty {
            if let match = running.first(where: { names[$0.serial] == configured }) {
                return BootedDevice(udid: match.serial, name: configured)
            }
            let avds = try await listAVDs()
            guard avds.contains(configured) else {
                throw GrantivaError.invalidArgument(
                    "No AVD named \"\(configured)\". Existing AVDs: \(avds.isEmpty ? "(none)" : avds.joined(separator: ", ")). "
                        + "Create it with scripts/android-env.sh or avdmanager.\(brokenNote)"
                )
            }
            return try await boot(avd: configured)
        }

        switch running.count {
        case 1:
            return BootedDevice(udid: running[0].serial, name: names[running[0].serial] ?? running[0].serial)
        case 0:
            let avds = try await listAVDs()
            if avds.count == 1 {
                return try await boot(avd: avds[0])
            }
            throw GrantivaError.invalidArgument(
                avds.isEmpty
                    ? "No emulator is running and no AVD exists. Run scripts/android-env.sh to create one.\(brokenNote)"
                    : "No emulator is running. Pass --emulator <AVD> or set emulator in grantiva-android.yml. AVDs: \(avds.joined(separator: ", ")).\(brokenNote)"
            )
        default:
            let list = running.map { "\($0.serial) (\(names[$0.serial] ?? "?"))" }.joined(separator: ", ")
            throw GrantivaError.invalidArgument(
                "Several emulators are running: \(list). Pass --emulator <AVD> or --device <serial>.\(brokenNote)"
            )
        }
    }

    /// Boots `avd` on the first free even port and waits for it.
    public func boot(avd: String) async throws -> BootedDevice {
        let used = try await adb.devices().map(\.serial)
        guard let port = Self.choosePort(used: used) else {
            throw GrantivaError.invalidArgument("No free emulator port between 5554 and 5584; shut one down first.")
        }
        let serial = "emulator-\(port)"
        let arguments = Self.bootArguments(avd: avd, port: port, headless: headless || isatty(STDOUT_FILENO) == 0)
        GrantivaLog.logger.info("Booting AVD \(avd) as \(serial)")
        let pid = try spawn(sdk.emulator, arguments)
        try provenance.register(StartedEmulatorRecord(serial: serial, avd: avd, pid: pid))
        try await waitForBoot(serial: serial)
        return BootedDevice(udid: serial, name: avd)
    }

    /// Done when `sys.boot_completed` is 1, `pm path android` answers, and the
    /// keyguard has been dismissed.
    public func waitForBoot(serial: String) async throws {
        let deadline = Date().addingTimeInterval(bootTimeout)
        while Date() < deadline {
            if (try? await adb.getprop(serial: serial, "sys.boot_completed")) == "1",
               let path = try? await adb.shell(serial: serial, "pm path android"), path.contains("package:") {
                _ = try? await adb.shell(serial: serial, "wm dismiss-keyguard")
                return
            }
            try await Task.sleep(for: .seconds(pollInterval))
        }
        throw GrantivaError.commandFailed(
            "\(serial) did not finish booting within \(Int(bootTimeout))s. Raise \(Self.bootTimeoutVariable) or check \(provenance.directory)/emulator-<port>.log.",
            1
        )
    }
}
