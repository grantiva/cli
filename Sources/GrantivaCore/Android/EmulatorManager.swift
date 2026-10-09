import Darwin
import Foundation

public struct EmulatorProvisionResult: Codable, Equatable, Sendable {
    public let name: String
    public let serial: String?
    public let created: Bool
    public let state: String

    public init(name: String, serial: String?, created: Bool, state: String) {
        self.name = name
        self.serial = serial
        self.created = created
        self.state = state
    }
}

public struct EmulatorSessionRecord: Codable, Equatable, Sendable {
    public let serial: String
    public let avd: String
    public let pid: Int32
    public let startedAt: Date
    public let processAlive: Bool
    /// adb's state for the serial, or `absent` when adb does not list it.
    public let adbState: String

    public init(serial: String, avd: String, pid: Int32, startedAt: Date, processAlive: Bool, adbState: String) {
        self.serial = serial
        self.avd = avd
        self.pid = pid
        self.startedAt = startedAt
        self.processAlive = processAlive
        self.adbState = adbState
    }
}

public struct EmulatorTeardownOutcome: Codable, Equatable, Sendable {
    public let serial: String
    public let avd: String?
    public let killed: Bool
    public let recorded: Bool

    public init(serial: String, avd: String?, killed: Bool, recorded: Bool) {
        self.serial = serial
        self.avd = avd
        self.killed = killed
        self.recorded = recorded
    }
}

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
    private let environment: [String: String]
    nonisolated(unsafe) private let fileManager: FileManager
    private let killTimeout: TimeInterval

    public static let bootTimeoutVariable = "GRANTIVA_EMULATOR_BOOT_TIMEOUT_SECONDS"

    public init(
        sdk: AndroidSDK,
        adb: ADB,
        execute: @escaping @Sendable (String) async throws -> String = { try await GrantivaCore.shell($0) },
        spawn: @escaping Spawn = EmulatorManager.detachedSpawn,
        provenance: AndroidProvenance = .live,
        headless: Bool = false,
        bootTimeout: TimeInterval = EmulatorManager.configuredBootTimeout(),
        pollInterval: TimeInterval = 1,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        killTimeout: TimeInterval = 30
    ) {
        self.sdk = sdk
        self.adb = adb
        self.execute = execute
        self.spawn = spawn
        self.provenance = provenance
        self.headless = headless
        self.bootTimeout = bootTimeout
        self.pollInterval = pollInterval
        self.environment = environment
        self.fileManager = fileManager
        self.killTimeout = killTimeout
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
            .filter { !$0.isEmpty && !$0.hasPrefix("INFO") && !$0.hasPrefix("WARNING") && !$0.hasPrefix("ERROR") }
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
        // Every emulator's AVD name is read, whatever its state: one that is
        // still booting shows as `offline` and must not be booted a second time.
        var names: [String: String] = [:]
        for device in devices where device.isEmulator {
            names[device.serial] = try? await adb.avdName(serial: device.serial)
        }
        // A booting emulator answers on its console (so its name is known)
        // while adb still reports it offline.
        let booting = devices.filter { $0.isEmulator && $0.state == "offline" && names[$0.serial] != nil }
        let brokenNote = broken.isEmpty ? "" : " Skipped: " + broken.map { "\($0.serial) is \($0.state)" }.joined(separator: ", ") + "."

        if let configured, !configured.isEmpty {
            if let match = running.first(where: { names[$0.serial] == configured }) {
                return BootedDevice(udid: match.serial, name: configured)
            }
            if let starting = booting.first(where: { names[$0.serial] == configured }) {
                return try await waitForBooting(starting.serial, name: configured)
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
            if booting.count == 1 {
                return try await waitForBooting(booting[0].serial, name: names[booting[0].serial] ?? booting[0].serial)
            }
            if booting.count > 1 {
                let list = booting.map { "\($0.serial) (\(names[$0.serial] ?? "?"))" }.joined(separator: ", ")
                throw GrantivaError.invalidArgument(
                    "Several emulators are still booting: \(list). Pass --emulator <AVD> or --device <serial>."
                )
            }
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

    private func waitForBooting(_ serial: String, name: String) async throws -> BootedDevice {
        GrantivaLog.logger.info("Waiting for \(serial) (\(name)) to finish booting")
        try await waitForBoot(serial: serial)
        return BootedDevice(udid: serial, name: name)
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
        try await waitForBoot(serial: serial, pid: pid)
        return BootedDevice(udid: serial, name: avd)
    }

    /// Done when `sys.boot_completed` is 1, `pm path android` answers, and the
    /// keyguard has been dismissed. With `pid` (an emulator Grantiva spawned),
    /// a process that exits early fails at once and its ledger record is removed.
    public func waitForBoot(serial: String, pid: Int32? = nil) async throws {
        let log = "\(provenance.directory)/emulator-\(serial.replacingOccurrences(of: "emulator-", with: "")).log"
        let deadline = Date().addingTimeInterval(bootTimeout)
        while Date() < deadline {
            if let pid, !Self.isAlive(pid) {
                try? provenance.remove(serial: serial)
                throw GrantivaError.commandFailed(
                    "The emulator process for \(serial) (pid \(pid)) exited before it finished booting. See \(log).",
                    1
                )
            }
            if (try? await adb.getprop(serial: serial, "sys.boot_completed")) == "1",
               let path = try? await adb.shell(serial: serial, "pm path android"), path.contains("package:") {
                _ = try? await adb.shell(serial: serial, "wm dismiss-keyguard")
                return
            }
            try await Task.sleep(for: .seconds(pollInterval))
        }
        throw GrantivaError.commandFailed(
            "\(serial) did not finish booting within \(Int(bootTimeout))s. Raise \(Self.bootTimeoutVariable) or check \(log).",
            1
        )
    }

    public static let defaultSystemImage = "system-images;android-35;google_apis;arm64-v8a"

    /// `system-images;android-35;google_apis;arm64-v8a` is installed at
    /// `<sdk>/system-images/android-35/google_apis/arm64-v8a`.
    public static func systemImagePath(root: String, image: String) -> String {
        "\(root)/" + image.replacingOccurrences(of: ";", with: "/")
    }

    private func javaPrefix() async -> String {
        let home = await AndroidSDK.javaHome(environment: environment, execute: execute)
        return home.map { "JAVA_HOME=\(shellQuoted($0)) " } ?? ""
    }

    /// Creates the AVD when missing (installing its system image first when
    /// that is missing too), then boots it unless `boot` is false.
    public func ensure(avd: String, systemImage: String?, boot: Bool) async throws -> EmulatorProvisionResult {
        var created = false
        if !(try await listAVDs()).contains(avd) {
            let image = systemImage ?? Self.defaultSystemImage
            let java = await javaPrefix()
            if !fileManager.fileExists(atPath: Self.systemImagePath(root: sdk.root, image: image)) {
                GrantivaLog.logger.info("Installing \(image) with sdkmanager")
                _ = try await execute("yes 2>/dev/null | \(java)\(shellQuoted(sdk.sdkmanager)) --sdk_root=\(shellQuoted(sdk.root)) \(shellQuoted(image))")
            }
            GrantivaLog.logger.info("Creating AVD \(avd)")
            _ = try await execute("echo no | \(java)\(shellQuoted(sdk.avdmanager)) create avd -n \(shellQuoted(avd)) -k \(shellQuoted(image)) -d pixel_8")
            try provenance.registerCreatedAVD(avd)
            created = true
        }
        guard boot else {
            return EmulatorProvisionResult(name: avd, serial: nil, created: created, state: "Shutdown")
        }
        let device = try await selectDevice(configured: avd)
        return EmulatorProvisionResult(name: avd, serial: device.udid, created: created, state: "Booted")
    }

    /// Deletes an AVD Grantiva created; others need `force`. A running AVD
    /// is never deleted.
    public func deleteAVD(name: String, force: Bool) async throws {
        for device in try await adb.devices() where device.isEmulator {
            // Fail closed: an emulator whose console cannot be read yet may be
            // this very AVD still booting.
            let running: String
            do {
                running = try await adb.avdName(serial: device.serial)
            } catch {
                throw GrantivaError.invalidArgument(
                    "Could not read the AVD name of \(device.serial); refusing to delete \"\(name)\" while an emulator is booting. Try again when it is up."
                )
            }
            if running == name {
                throw GrantivaError.invalidArgument(
                    "AVD \"\(name)\" is running as \(device.serial). Run `grantiva emulator teardown --serial \(device.serial)` first."
                )
            }
        }
        let avds = try await listAVDs()
        guard avds.contains(name) else {
            throw GrantivaError.invalidArgument(
                "No AVD named \"\(name)\". Existing AVDs: \(avds.isEmpty ? "(none)" : avds.joined(separator: ", "))."
            )
        }
        if !force, !(try provenance.createdAVDs()).contains(name) {
            throw GrantivaError.invalidArgument(
                "AVD \"\(name)\" was not created by Grantiva (grantiva emulator ensure). Pass --force to delete it anyway."
            )
        }
        let java = await javaPrefix()
        _ = try await execute("\(java)\(shellQuoted(sdk.avdmanager)) delete avd -n \(shellQuoted(name))")
        try provenance.removeCreatedAVD(name)
    }

    /// Ledger records with their liveness. A record whose process is gone
    /// and whose serial adb no longer lists is pruned on the way out.
    public func sessions() async throws -> [EmulatorSessionRecord] {
        let devices = try await adb.devices()
        var records: [EmulatorSessionRecord] = []
        for record in try provenance.all() {
            let alive = Self.isAlive(record.pid)
            let state = devices.first { $0.serial == record.serial }?.state ?? "absent"
            if !alive, state == "absent" {
                try provenance.remove(serial: record.serial)
                continue
            }
            records.append(EmulatorSessionRecord(
                serial: record.serial, avd: record.avd, pid: record.pid, startedAt: record.startedAt,
                processAlive: alive, adbState: state
            ))
        }
        return records
    }

    /// Stops the UIAutomator2 server, drops this serial's forwards, asks the
    /// emulator to exit, and waits for both the process and the serial to go.
    public func teardown(serial: String, force: Bool) async throws -> EmulatorTeardownOutcome {
        var record = try provenance.all().first { $0.serial == serial }
        // A record whose process is gone proves nothing about the serial: the
        // port may now belong to someone else's emulator. Keep it only when
        // the listed emulator still runs the recorded AVD.
        if let stale = record, !Self.isAlive(stale.pid),
           try await adb.devices().contains(where: { $0.serial == serial }),
           (try? await adb.avdName(serial: serial)) != stale.avd {
            try provenance.remove(serial: serial)
            record = nil
        }
        guard record != nil || force else {
            throw GrantivaError.invalidArgument(
                "\(serial) was not started by Grantiva (see `grantiva emulator sessions`). Pass --force to kill it anyway."
            )
        }
        for package in ADB.uiAutomator2Packages {
            _ = try? await adb.forceStop(serial: serial, applicationId: package)
        }
        _ = try? await adb.removeForwards(serial: serial)

        var listed = try await adb.devices().contains { $0.serial == serial }
        var killed = false
        if listed {
            _ = try? await adb.emuKill(serial: serial)
            killed = true
            let deadline = Date().addingTimeInterval(killTimeout)
            while true {
                listed = try await adb.devices().contains { $0.serial == serial }
                let processGone = record.map { !Self.isAlive($0.pid) } ?? true
                if !listed, processGone { break }
                guard Date() < deadline else {
                    throw GrantivaError.commandFailed(
                        "\(serial) did not exit within \(Int(killTimeout))s after adb emu kill. Check `adb devices` and the emulator log.", 1
                    )
                }
                try await Task.sleep(for: .seconds(pollInterval))
            }
        }
        if record != nil {
            try provenance.remove(serial: serial)
        }
        return EmulatorTeardownOutcome(serial: serial, avd: record?.avd, killed: killed, recorded: record != nil)
    }

    public func teardownAll() async throws -> [EmulatorTeardownOutcome] {
        var outcomes: [EmulatorTeardownOutcome] = []
        for record in try provenance.all() {
            outcomes.append(try await teardown(serial: record.serial, force: false))
        }
        return outcomes
    }

    /// An emulator we spawned is our child: once it exits it stays a zombie
    /// (and `kill(pid, 0)` keeps succeeding) until reaped, so reap it here
    /// with `WNOHANG`. A pid that is not our child (ECHILD, e.g. from a ledger
    /// written by another process) falls back to `kill(pid, 0)`, where EPERM
    /// still means it exists.
    static func isAlive(_ pid: Int32) -> Bool {
        var status: Int32 = 0
        let reaped = waitpid(pid, &status, WNOHANG)
        if reaped == pid { return false }
        if reaped == 0 { return true }
        guard errno == ECHILD else { return true }
        return kill(pid, 0) == 0 || errno == EPERM
    }
}
