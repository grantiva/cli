import Foundation
import XCTest
@testable import GrantivaCore

final class EmulatorManagerTests: XCTestCase {
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory.appendingPathComponent("emu-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    private final class FixedPIDSpawn: @unchecked Sendable {
        let pid: Int32
        init(pid: Int32) { self.pid = pid }
        func spawn(_ executable: String, _ arguments: [String]) throws -> Int32 { pid }
    }

    private final class SpawnRecorder: @unchecked Sendable {
        var calls: [(String, [String])] = []
        func spawn(_ executable: String, _ arguments: [String]) throws -> Int32 {
            calls.append((executable, arguments)); return getpid() // a live pid, so the liveness check passes
        }
    }

    private func manager(
        _ shell: ScriptedShell, spawn: SpawnRecorder = SpawnRecorder(), headless: Bool = true, sdkRoot: String = "/sdk",
        boundPorts: Set<Int> = [], portOwners: [Int32]? = nil
    ) -> EmulatorManager {
        EmulatorManager(
            sdk: AndroidSDK(root: sdkRoot),
            adb: ADB(path: "\(sdkRoot)/platform-tools/adb", execute: shell.execute),
            execute: shell.execute,
            spawn: spawn.spawn,
            provenance: AndroidProvenance(directory: scratch.path),
            headless: headless,
            bootTimeout: 1,
            pollInterval: 0.01,
            environment: [:],
            killTimeout: 1,
            consolePortBound: { boundPorts.contains($0) },
            consolePortOwners: { _ in portOwners }
        )
    }

    /// Live children standing in for emulators Grantiva booted: each exits
    /// when the scripted shell sees `emu kill` for its serial.
    private final class EmulatorProcesses: @unchecked Sendable {
        private var processes: [String: Process] = [:]
        let shell: ScriptedShell
        init(_ shell: ScriptedShell) { self.shell = shell }

        func start(serial: String) throws -> Int32 {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sleep")
            process.arguments = ["30"]
            try process.run()
            processes[serial] = process
            return process.processIdentifier
        }

        /// Kill every child when a command contains this, instead of on `emu kill`.
        var killOn: String?

        func execute(_ command: String) async throws -> String {
            for (serial, process) in processes
            where killOn.map(command.contains) ?? command.hasSuffix("'\(serial)' emu kill") {
                process.terminate()
                process.waitUntilExit()
            }
            return try await shell.execute(command)
        }

        deinit { processes.values.forEach { if $0.isRunning { $0.terminate() } } }
    }

    private func manager(_ emulators: EmulatorProcesses) -> EmulatorManager {
        EmulatorManager(
            sdk: AndroidSDK(root: "/sdk"), adb: ADB(path: "/sdk/platform-tools/adb", execute: emulators.execute),
            execute: emulators.execute, spawn: SpawnRecorder().spawn, provenance: AndroidProvenance(directory: scratch.path),
            headless: true, bootTimeout: 1, pollInterval: 0.01, environment: [:], killTimeout: 2,
            consolePortBound: { _ in false }, consolePortOwners: { _ in nil }
        )
    }


    /// A pid that no longer exists: a child that ran and was reaped.
    private func deadPID() throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/true")
        try process.run()
        process.waitUntilExit()
        return process.processIdentifier
    }

    func testChoosePortSkipsSerialsInUse() {
        XCTAssertEqual(EmulatorManager.choosePort(used: []), 5554)
        XCTAssertEqual(EmulatorManager.choosePort(used: ["emulator-5554", "emulator-5556"]), 5558)
        let all = stride(from: 5554, through: 5584, by: 2).map { "emulator-\($0)" }
        XCTAssertNil(EmulatorManager.choosePort(used: all))
    }

    /// C02: adb can briefly miss a running emulator; its console port is
    /// still bound, so that port is not free.
    func testChoosePortSkipsPortsWhoseConsoleIsBound() {
        XCTAssertEqual(EmulatorManager.choosePort(used: [], isBound: { $0 == 5554 }), 5556)
        XCTAssertEqual(EmulatorManager.choosePort(used: [], isBound: { $0 == 5557 }), 5554)
        XCTAssertEqual(EmulatorManager.choosePort(used: [], isBound: { $0 == 5555 }), 5556, "the adb port counts too")
    }

    func testIsLocalPortBoundSeesAListeningSocket() {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        defer { close(fd) }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                XCTAssertEqual(Darwin.bind(fd, $0, length), 0)
                XCTAssertEqual(Darwin.listen(fd, 1), 0)
                XCTAssertEqual(getsockname(fd, $0, &length), 0)
            }
        }
        let port = Int(UInt16(bigEndian: address.sin_port))
        XCTAssertTrue(EmulatorManager.isLocalPortBound(port))
        close(fd)
    }

    /// C02: adb missed the user's emulator, Grantiva spawned a second copy on
    /// the same port, and that copy died just as the user's emulator answered
    /// `boot_completed=1` on the serial. The boot must fail and leave no record.
    func testBootFailsAndLeavesNoRecordWhenTheSpawnedEmulatorDiesWhileTheSerialAnswers() async throws {
        let shell = ScriptedShell([
            .success("List of devices attached"),          // boot: adb devices (port choice) misses emulator-5554
            .success("1"), .success("package:x"), .success(""), // the user's emulator answers the boot probes
        ])
        let emulators = EmulatorProcesses(shell)
        let pid = try emulators.start(serial: "emulator-5554")
        emulators.killOn = "sys.boot_completed"            // the duplicate dies during the first probe
        let manager = EmulatorManager(
            sdk: AndroidSDK(root: "/sdk"), adb: ADB(path: "/sdk/platform-tools/adb", execute: emulators.execute),
            execute: emulators.execute, spawn: FixedPIDSpawn(pid: pid).spawn, provenance: AndroidProvenance(directory: scratch.path),
            headless: true, bootTimeout: 1, pollInterval: 0.01, environment: [:], killTimeout: 1,
            consolePortBound: { _ in false }, consolePortOwners: { _ in nil }
        )
        do {
            _ = try await manager.boot(avd: "Pixel_8_API_35")
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("exited"), "\(error)")
        }
        XCTAssertEqual(try AndroidProvenance(directory: scratch.path).all(), [])
    }

    /// C02: the boot probes pass, the spawned pid is alive, but another
    /// process owns the console port: not ours.
    func testBootFailsAndLeavesNoRecordWhenAnotherProcessOwnsTheConsolePort() async throws {
        let shell = ScriptedShell([
            .success("List of devices attached"),
            .success("1"), .success("package:x"),
        ])
        do {
            _ = try await manager(shell, portOwners: [49817]).boot(avd: "Pixel_8_API_35")
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("49817"), "\(error)")
            XCTAssertTrue("\(error)".contains("not the one Grantiva started"), "\(error)")
        }
        XCTAssertEqual(try AndroidProvenance(directory: scratch.path).all(), [])
    }

    func testBootSucceedsWhenTheSpawnedPIDOwnsTheConsolePort() async throws {
        let shell = ScriptedShell([
            .success("List of devices attached"),
            .success("1"), .success("package:x"), .success(""),
        ])
        let device = try await manager(shell, portOwners: [getpid()]).boot(avd: "Pixel_8_API_35")
        XCTAssertEqual(device.udid, "emulator-5554")
        XCTAssertEqual(try AndroidProvenance(directory: scratch.path).all().map(\.pid), [getpid()])
    }

    func testBootSkipsAPortWhoseConsoleIsBound() async throws {
        let spawn = SpawnRecorder()
        let shell = ScriptedShell([
            .success("List of devices attached"),
            .success("1"), .success("package:x"), .success(""),
        ])
        let device = try await manager(shell, spawn: spawn, boundPorts: [5554, 5555]).boot(avd: "Pixel_8_API_35")
        XCTAssertEqual(device.udid, "emulator-5556")
        XCTAssertEqual(spawn.calls.first?.1.prefix(4), ["-avd", "Pixel_8_API_35", "-port", "5556"])
    }

    func testBootArgumentsMatchTheSpec() {
        XCTAssertEqual(
            EmulatorManager.bootArguments(avd: "Pixel_8_API_35", port: 5556, headless: false),
            ["-avd", "Pixel_8_API_35", "-port", "5556", "-no-snapshot-save", "-no-boot-anim"]
        )
        XCTAssertEqual(EmulatorManager.bootArguments(avd: "P", port: 5554, headless: true).last, "-no-window")
    }

    func testListAVDsSkipsInfoLines() async throws {
        let shell = ScriptedShell([.success("INFO    | Storing crashdata in: /tmp/x\nPixel_8_API_35\nPixel_7_API_34")])
        let avds = try await manager(shell).listAVDs()
        XCTAssertEqual(avds, ["Pixel_8_API_35", "Pixel_7_API_34"])
        XCTAssertEqual(shell.commands, ["'/sdk/emulator/emulator' -list-avds"])
    }

    func testSelectDeviceUsesTheRunningEmulatorWithTheConfiguredAVD() async throws {
        let shell = ScriptedShell([
            .success("List of devices attached\nemulator-5554 device\nemulator-5556 device"),
            .success("Pixel_7_API_34\nOK"),
            .success("Pixel_8_API_35\nOK"),
        ])
        let device = try await manager(shell).selectDevice(configured: "Pixel_8_API_35")
        XCTAssertEqual(device, BootedDevice(udid: "emulator-5556", name: "Pixel_8_API_35"))
    }

    func testSelectDeviceWithoutConfigUsesTheOnlyRunningEmulator() async throws {
        let shell = ScriptedShell([
            .success("List of devices attached\nemulator-5554 device\nR58M1234ABC device"),
            .success("Pixel_8_API_35\nOK"),
        ])
        let device = try await manager(shell).selectDevice(configured: nil)
        XCTAssertEqual(device.udid, "emulator-5554", "physical devices are never picked by default")
    }

    func testSelectDeviceWithTwoRunningAndNoConfigAsksForAChoice() async throws {
        let shell = ScriptedShell([
            .success("List of devices attached\nemulator-5554 device\nemulator-5556 device"),
            .success("A\nOK"), .success("B\nOK"),
        ])
        do {
            _ = try await manager(shell).selectDevice(configured: nil)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("emulator-5554 (A)"), "\(error)")
            XCTAssertTrue("\(error)".contains("--emulator"), "\(error)")
        }
    }

    func testSelectDeviceBootsTheConfiguredAVDWhenNotRunning() async throws {
        let spawn = SpawnRecorder()
        let shell = ScriptedShell([
            .success("List of devices attached"),                 // adb devices
            .success("Pixel_8_API_35"),                           // emulator -list-avds
            .success("List of devices attached"),                 // devices again, for the port choice
            .success("1"),                                        // sys.boot_completed
            .success("package:/system/framework/framework-res.apk"), // pm path android
            .success(""),                                         // wm dismiss-keyguard
        ])
        let device = try await manager(shell, spawn: spawn).selectDevice(configured: "Pixel_8_API_35")
        XCTAssertEqual(device, BootedDevice(udid: "emulator-5554", name: "Pixel_8_API_35"))
        XCTAssertEqual(spawn.calls.count, 1)
        XCTAssertEqual(spawn.calls[0].0, "/sdk/emulator/emulator")
        XCTAssertEqual(spawn.calls[0].1, ["-avd", "Pixel_8_API_35", "-port", "5554", "-no-snapshot-save", "-no-boot-anim", "-no-window"])
        XCTAssertEqual(try AndroidProvenance(directory: scratch.path).all().map(\.serial), ["emulator-5554"])
    }

    func testSelectDeviceWithUnknownAVDListsTheOnesThatExist() async throws {
        let shell = ScriptedShell([.success("List of devices attached"), .success("Pixel_7_API_34")])
        do {
            _ = try await manager(shell).selectDevice(configured: "Nope")
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("Pixel_7_API_34"), "\(error)")
        }
    }

    func testSelectDeviceWithNoConfigNoRunningAndOneAVDBootsIt() async throws {
        let spawn = SpawnRecorder()
        let shell = ScriptedShell([
            .success("List of devices attached"), .success("Only_One"),
            .success("List of devices attached"), .success("1"), .success("package:x"), .success(""),
        ])
        let device = try await manager(shell, spawn: spawn).selectDevice(configured: nil)
        XCTAssertEqual(device.name, "Only_One")
        XCTAssertEqual(spawn.calls.count, 1)
    }

    func testOfflineAndUnauthorizedDevicesAreReportedNotUsed() async throws {
        let shell = ScriptedShell([
            .success("List of devices attached\nemulator-5554 offline\nemulator-5556 unauthorized"),
            .success(""), // emu avd name emulator-5554: console does not answer
            .success(""), // emu avd name emulator-5556
            .success(""), // emulator -list-avds
        ])
        do {
            _ = try await manager(shell).selectDevice(configured: nil)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("emulator-5554 is offline"), "\(error)")
            XCTAssertTrue("\(error)".contains("emulator-5556 is unauthorized"), "\(error)")
        }
    }

    func testWaitForBootTimesOutWithAClearMessage() async throws {
        let shell = ScriptedShell()
        shell.fallback = "0"
        do {
            try await manager(shell).waitForBoot(serial: "emulator-5554")
            XCTFail("expected timeout")
        } catch {
            XCTAssertTrue("\(error)".contains("did not finish booting"), "\(error)")
            XCTAssertTrue("\(error)".contains("GRANTIVA_EMULATOR_BOOT_TIMEOUT_SECONDS"), "\(error)")
        }
    }

    func testListAVDsSkipsErrorLines() async throws {
        let shell = ScriptedShell([.success("ERROR   | Unable to connect to adb daemon\nPixel_8_API_35")])
        let avds = try await manager(shell).listAVDs()
        XCTAssertEqual(avds, ["Pixel_8_API_35"])
    }

    func testConfiguredAVDThatIsStillBootingIsWaitedOnNotBootedAgain() async throws {
        let spawn = SpawnRecorder()
        let shell = ScriptedShell([
            .success("List of devices attached\nemulator-5554 offline"), // adb devices
            .success("Pixel_8_API_35\nOK"),                              // emu avd name
            .success("1"),                                               // sys.boot_completed
            .success("package:/system/framework/framework-res.apk"),     // pm path android
            .success(""),                                                // wm dismiss-keyguard
        ])
        let device = try await manager(shell, spawn: spawn).selectDevice(configured: "Pixel_8_API_35")
        XCTAssertEqual(device, BootedDevice(udid: "emulator-5554", name: "Pixel_8_API_35"))
        XCTAssertTrue(spawn.calls.isEmpty, "a booting copy of the AVD must not be started twice")
        XCTAssertFalse(shell.commands.contains { $0.contains("-list-avds") })
    }

    func testWithoutConfigASingleBootingEmulatorIsWaitedOn() async throws {
        let spawn = SpawnRecorder()
        let shell = ScriptedShell([
            .success("List of devices attached\nemulator-5554 offline"),
            .success("Only_One\nOK"),
            .success("1"), .success("package:x"), .success(""),
        ])
        let device = try await manager(shell, spawn: spawn).selectDevice(configured: nil)
        XCTAssertEqual(device, BootedDevice(udid: "emulator-5554", name: "Only_One"))
        XCTAssertTrue(spawn.calls.isEmpty)
    }

    func testWaitForBootFailsFastWhenTheEmulatorProcessExited() async throws {
        let provenance = AndroidProvenance(directory: scratch.path)
        try provenance.register(StartedEmulatorRecord(serial: "emulator-5556", avd: "Pixel_8_API_35", pid: Int32.max))
        let shell = ScriptedShell()
        shell.fallback = "0"
        let started = Date()
        do {
            try await manager(shell).waitForBoot(serial: "emulator-5556", pid: Int32.max)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("emulator-5556"), "\(error)")
            XCTAssertTrue("\(error)".contains("exited"), "\(error)")
            XCTAssertTrue("\(error)".contains("\(scratch.path)/emulator-5556.log"), "\(error)")
        }
        XCTAssertLessThan(Date().timeIntervalSince(started), 0.5, "must not wait for the boot timeout")
        XCTAssertFalse(try provenance.contains(serial: "emulator-5556"))
    }

    /// The real case: an emulator Grantiva spawned exits at once ("AVD already
    /// in use"). Nothing has reaped it, so it is a zombie and `kill(pid, 0)`
    /// alone still says it is alive.
    func testWaitForBootFailsFastWhenASpawnedChildExitedUnreaped() async throws {
        let devnull = open("/dev/null", O_RDWR)
        XCTAssertGreaterThanOrEqual(devnull, 0)
        defer { close(devnull) }
        let child = try ChildProcess.spawn(executable: "/usr/bin/false", arguments: [], stdin: devnull, stdout: devnull, stderr: devnull)
        // Block until it has exited, but leave it unreaped (WNOWAIT): a zombie.
        var info = siginfo_t()
        XCTAssertEqual(waitid(P_PID, id_t(child.pid), &info, WEXITED | WNOWAIT), 0)
        XCTAssertEqual(kill(child.pid, 0), 0, "precondition: a zombie still answers kill(pid, 0)")

        let provenance = AndroidProvenance(directory: scratch.path)
        try provenance.register(StartedEmulatorRecord(serial: "emulator-5558", avd: "Pixel_8_API_35", pid: child.pid))
        let shell = ScriptedShell()
        shell.fallback = "0"
        let started = Date()
        do {
            try await manager(shell).waitForBoot(serial: "emulator-5558", pid: child.pid)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("emulator-5558"), "\(error)")
            XCTAssertTrue("\(error)".contains("exited"), "\(error)")
            XCTAssertTrue("\(error)".contains("\(scratch.path)/emulator-5558.log"), "\(error)")
        }
        XCTAssertLessThan(Date().timeIntervalSince(started), 0.5, "must not wait for the boot timeout")
        XCTAssertFalse(try provenance.contains(serial: "emulator-5558"))
    }

    func testEnsureCreatesAMissingAVDAndBootsIt() async throws {
        let shell = ScriptedShell([
            .success(""),                                  // emulator -list-avds: none
            .success("/jdk"),                              // java_home
            .success(""),                                  // sdkmanager
            .success(""),                                  // avdmanager create
            .success("List of devices attached"),          // selectDevice: adb devices
            .success("Pixel_8_API_35"),                    // selectDevice: list-avds
            .success("List of devices attached"),          // boot: adb devices (port choice)
            .success("1"),                                 // boot_completed
            .success("package:/system/framework/framework-res.apk"),
            .success(""),                                  // dismiss-keyguard
        ])
        let result = try await manager(shell).ensure(avd: "Pixel_8_API_35", systemImage: nil, boot: true)
        XCTAssertEqual(result, EmulatorProvisionResult(name: "Pixel_8_API_35", serial: "emulator-5554", created: true, state: "Booted"))
        XCTAssertEqual(shell.commands, [
            "'/sdk/emulator/emulator' -list-avds",
            "/usr/libexec/java_home",
            "yes 2>/dev/null | JAVA_HOME='/jdk' '/sdk/cmdline-tools/latest/bin/sdkmanager' --sdk_root='/sdk' 'system-images;android-35;google_apis;arm64-v8a'",
            "echo no | JAVA_HOME='/jdk' '/sdk/cmdline-tools/latest/bin/avdmanager' create avd -n 'Pixel_8_API_35' -k 'system-images;android-35;google_apis;arm64-v8a' -d pixel_8",
            "'/sdk/platform-tools/adb' devices -l",
            "'/sdk/emulator/emulator' -list-avds",
            "'/sdk/platform-tools/adb' devices -l",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell getprop 'sys.boot_completed'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell 'pm path android'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell 'wm dismiss-keyguard'",
        ])
        XCTAssertEqual(try AndroidProvenance(directory: scratch.path).createdAVDs(), ["Pixel_8_API_35"])
    }

    func testEnsureReusesAnExistingAVDWithoutBootingWhenAsked() async throws {
        let shell = ScriptedShell([.success("Pixel_8_API_35")])
        let result = try await manager(shell).ensure(avd: "Pixel_8_API_35", systemImage: nil, boot: false)
        XCTAssertEqual(result, EmulatorProvisionResult(name: "Pixel_8_API_35", serial: nil, created: false, state: "Shutdown"))
        XCTAssertEqual(shell.commands, ["'/sdk/emulator/emulator' -list-avds"])
        XCTAssertEqual(try AndroidProvenance(directory: scratch.path).createdAVDs(), [])
    }

    func testEnsureSkipsSdkmanagerWhenTheImageIsInstalled() async throws {
        let root = scratch.appendingPathComponent("sdk").path
        try FileManager.default.createDirectory(atPath: "\(root)/system-images/android-34/google_apis/arm64-v8a", withIntermediateDirectories: true)
        let shell = ScriptedShell([.success(""), .success("/jdk"), .success("")])
        let result = try await manager(shell, sdkRoot: root).ensure(avd: "Pixel_7_API_34", systemImage: "system-images;android-34;google_apis;arm64-v8a", boot: false)
        XCTAssertTrue(result.created)
        XCTAssertEqual(shell.commands, [
            "'\(root)/emulator/emulator' -list-avds",
            "/usr/libexec/java_home",
            "echo no | JAVA_HOME='/jdk' '\(root)/cmdline-tools/latest/bin/avdmanager' create avd -n 'Pixel_7_API_34' -k 'system-images;android-34;google_apis;arm64-v8a' -d pixel_8",
        ])
    }

    func testSystemImagePathReplacesSemicolons() {
        XCTAssertEqual(
            EmulatorManager.systemImagePath(root: "/sdk", image: "system-images;android-35;google_apis;arm64-v8a"),
            "/sdk/system-images/android-35/google_apis/arm64-v8a"
        )
    }

    func testDeleteRefusesARunningAVD() async {
        let shell = ScriptedShell([.success("List of devices attached\nemulator-5554 device"), .success("Pixel_8_API_35\nOK")])
        do {
            try await manager(shell).deleteAVD(name: "Pixel_8_API_35", force: false)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("running as emulator-5554"), "\(error)")
            XCTAssertTrue("\(error)".contains("grantiva emulator teardown --serial emulator-5554"), "\(error)")
        }
    }

    func testDeleteRefusesAForeignAVDWithoutForce() async {
        let shell = ScriptedShell([.success("List of devices attached"), .success("Pixel_8_API_35")])
        do {
            try await manager(shell).deleteAVD(name: "Pixel_8_API_35", force: false)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("was not created by Grantiva"), "\(error)")
            XCTAssertTrue("\(error)".contains("--force"), "\(error)")
        }
        XCTAssertEqual(shell.commands.count, 2)
    }

    func testDeleteWithForceRemovesAForeignAVD() async throws {
        let shell = ScriptedShell([.success("List of devices attached"), .success("Pixel_8_API_35"), .success("/jdk"), .success("")])
        try await manager(shell).deleteAVD(name: "Pixel_8_API_35", force: true)
        XCTAssertEqual(shell.commands.last, "JAVA_HOME='/jdk' '/sdk/cmdline-tools/latest/bin/avdmanager' delete avd -n 'Pixel_8_API_35'")
    }

    func testDeleteRemovesACreatedAVDAndItsLedgerEntry() async throws {
        try AndroidProvenance(directory: scratch.path).registerCreatedAVD("Pixel_8_API_35")
        let shell = ScriptedShell([.success("List of devices attached"), .success("Pixel_8_API_35"), .success("/jdk"), .success("")])
        try await manager(shell).deleteAVD(name: "Pixel_8_API_35", force: false)
        XCTAssertEqual(try AndroidProvenance(directory: scratch.path).createdAVDs(), [])
    }

    func testDeleteOfAnUnknownAVDListsTheOnesThatExist() async {
        let shell = ScriptedShell([.success("List of devices attached"), .success("Pixel_7_API_34")])
        do {
            try await manager(shell).deleteAVD(name: "Nope", force: true)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("No AVD named \"Nope\""), "\(error)")
            XCTAssertTrue("\(error)".contains("Pixel_7_API_34"), "\(error)")
        }
    }

    func testSessionsReportLivenessAndPruneDeadAbsentRecords() async throws {
        let ledger = AndroidProvenance(directory: scratch.path)
        try ledger.register(StartedEmulatorRecord(serial: "emulator-5554", avd: "Live", pid: getpid()))
        try ledger.register(StartedEmulatorRecord(serial: "emulator-5556", avd: "Gone", pid: try deadPID()))
        let shell = ScriptedShell([.success("List of devices attached\nemulator-5554 device")])
        let sessions = try await manager(shell).sessions()
        XCTAssertEqual(sessions.map(\.serial), ["emulator-5554"])
        XCTAssertEqual(sessions.first?.processAlive, true)
        XCTAssertEqual(sessions.first?.adbState, "device")
        XCTAssertEqual(try ledger.all().map(\.serial), ["emulator-5554"], "the dead, absent record is pruned")
    }

    /// C02 / AND-F03: the emulator Grantiva booted died and the user started
    /// the same AVD by hand on the same serial. The dead record is pruned.
    func testSessionsPruneADeadPIDRecordWhoseSerialRunsTheSameAVD() async throws {
        let ledger = AndroidProvenance(directory: scratch.path)
        try ledger.register(StartedEmulatorRecord(serial: "emulator-5554", avd: "Pixel_8_API_35", pid: try deadPID()))
        let shell = ScriptedShell([.success("List of devices attached\nemulator-5554 device")])
        shell.fallback = "Pixel_8_API_35\nOK"
        let sessions = try await manager(shell).sessions()
        XCTAssertEqual(sessions, [])
        XCTAssertEqual(try ledger.all(), [])
    }

    /// Review Focus 4.
    func testTeardownRefusesAForeignSerialWithoutForce() async {
        let shell = ScriptedShell()
        do {
            _ = try await manager(shell).teardown(serial: "emulator-5556", force: false)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("was not started by Grantiva"), "\(error)")
            XCTAssertTrue("\(error)".contains("--force"), "\(error)")
        }
        XCTAssertTrue(shell.commands.isEmpty)
    }

    /// Review Focus 4.
    func testTeardownWithForceKillsAForeignSerial() async throws {
        let shell = ScriptedShell([
            .success(""), .success(""),                              // force-stop x2
            .success(""),                                            // forward --list
            .success("List of devices attached\nemulator-5556 device"),
            .success(""),                                            // emu kill
            .success("List of devices attached"),                    // gone
        ])
        let outcome = try await manager(shell).teardown(serial: "emulator-5556", force: true)
        XCTAssertEqual(outcome, EmulatorTeardownOutcome(serial: "emulator-5556", avd: nil, killed: true, recorded: false))
        XCTAssertEqual(shell.commands, [
            "'/sdk/platform-tools/adb' -s 'emulator-5556' shell am force-stop 'io.appium.uiautomator2.server'",
            "'/sdk/platform-tools/adb' -s 'emulator-5556' shell am force-stop 'io.appium.uiautomator2.server.test'",
            "'/sdk/platform-tools/adb' -s 'emulator-5556' forward --list",
            "'/sdk/platform-tools/adb' devices -l",
            "'/sdk/platform-tools/adb' -s 'emulator-5556' emu kill",
            "'/sdk/platform-tools/adb' devices -l",
        ])
    }

    func testTeardownKillsARecordedEmulatorAndRemovesTheRecord() async throws {
        let ledger = AndroidProvenance(directory: scratch.path)
        let shell = ScriptedShell([
            .success(""), .success(""), .success(""),                     // force-stop x2, forward --list
            .success("List of devices attached\nemulator-5554 device"),
            .success(""),                                                 // emu kill
            .success("List of devices attached"),
        ])
        let emulators = EmulatorProcesses(shell)
        try ledger.register(StartedEmulatorRecord(serial: "emulator-5554", avd: "Pixel_8_API_35", pid: try emulators.start(serial: "emulator-5554")))
        let outcome = try await manager(emulators).teardown(serial: "emulator-5554", force: false)
        XCTAssertEqual(outcome, EmulatorTeardownOutcome(serial: "emulator-5554", avd: "Pixel_8_API_35", killed: true, recorded: true))
        XCTAssertEqual(try ledger.all(), [])
    }

    func testTeardownOfARecordedEmulatorThatIsAlreadyGoneJustDropsTheRecord() async throws {
        let ledger = AndroidProvenance(directory: scratch.path)
        try ledger.register(StartedEmulatorRecord(serial: "emulator-5554", avd: "Pixel_8_API_35", pid: try deadPID()))
        let shell = ScriptedShell([
            .success("List of devices attached"),                         // ownership: not listed, no name read
            .success(""), .success(""), .success(""),                     // force-stop x2, forward --list
            .success("List of devices attached"),
        ])
        let outcome = try await manager(shell).teardown(serial: "emulator-5554", force: false)
        XCTAssertEqual(outcome.killed, false)
        XCTAssertEqual(try ledger.all(), [])
        XCTAssertFalse(shell.commands.contains { $0.hasSuffix("emu kill") })
        XCTAssertFalse(shell.commands.contains { $0.hasSuffix("emu avd name") })
    }

    /// A dead pid's serial reused by someone else's emulator is not ours.
    func testTeardownRefusesAReusedSerialWhoseAVDDiffersAndDropsTheRecord() async throws {
        let ledger = AndroidProvenance(directory: scratch.path)
        try ledger.register(StartedEmulatorRecord(serial: "emulator-5554", avd: "Old", pid: try deadPID()))
        let shell = ScriptedShell([
            .success("List of devices attached\nemulator-5554 device"),
        ])
        shell.fallback = "Other\nOK"
        do {
            _ = try await manager(shell).teardown(serial: "emulator-5554", force: false)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("was not started by Grantiva"), "\(error)")
        }
        XCTAssertEqual(try ledger.all(), [], "the stale record is dropped")
        XCTAssertFalse(shell.commands.contains { $0.hasSuffix("emu kill") })
        XCTAssertFalse(shell.commands.contains { $0.contains("force-stop") })
    }

    /// C02 / AND-F03: dead pid, same AVD name, live serial. An AVD name does
    /// not say who started the emulator, so it is not killed without --force.
    func testTeardownRefusesADeadPIDRecordEvenWhenTheSerialRunsTheSameAVD() async throws {
        let ledger = AndroidProvenance(directory: scratch.path)
        try ledger.register(StartedEmulatorRecord(serial: "emulator-5556", avd: "qa-android-1", pid: try deadPID()))
        let shell = ScriptedShell([.success("List of devices attached\nemulator-5556 device")])
        shell.fallback = "qa-android-1\nOK"
        do {
            _ = try await manager(shell).teardown(serial: "emulator-5556", force: false)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("was not started by Grantiva"), "\(error)")
            XCTAssertTrue("\(error)".contains("--force"), "\(error)")
        }
        XCTAssertEqual(try ledger.all(), [])
        XCTAssertFalse(shell.commands.contains { $0.hasSuffix("emu kill") })
        XCTAssertFalse(shell.commands.contains { $0.contains("force-stop") })
    }

    func testTeardownTimesOutWhenTheEmulatorKeepsRunning() async throws {
        let ledger = AndroidProvenance(directory: scratch.path)
        try ledger.register(StartedEmulatorRecord(serial: "emulator-5554", avd: "P", pid: getpid()))
        let shell = ScriptedShell([.success(""), .success(""), .success(""), .success("List of devices attached\nemulator-5554 device"), .success("")])
        shell.fallback = "List of devices attached\nemulator-5554 device"
        do {
            _ = try await manager(shell).teardown(serial: "emulator-5554", force: false)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("did not exit within 1s"), "\(error)")
        }
        XCTAssertEqual(try ledger.all().count, 1, "a record whose emulator is still up stays")
    }

    func testTeardownAllCoversEveryRecordedEmulator() async throws {
        let ledger = AndroidProvenance(directory: scratch.path)
        let both = "List of devices attached\nemulator-5554 device\nemulator-5556 device"
        let second = "List of devices attached\nemulator-5556 device"
        let shell = ScriptedShell([
            // emulator-5554
            .success(""), .success(""), .success(""),                    // force-stop x2, forward --list
            .success(both), .success(""), .success(second),              // listed, emu kill, gone
            // emulator-5556
            .success(""), .success(""), .success(""),
            .success(second), .success(""), .success("List of devices attached"),
        ])
        let emulators = EmulatorProcesses(shell)
        try ledger.register(StartedEmulatorRecord(serial: "emulator-5554", avd: "A", pid: try emulators.start(serial: "emulator-5554")))
        try ledger.register(StartedEmulatorRecord(serial: "emulator-5556", avd: "B", pid: try emulators.start(serial: "emulator-5556")))
        let outcomes = try await manager(emulators).teardownAll()
        XCTAssertEqual(outcomes.map(\.serial), ["emulator-5554", "emulator-5556"])
        XCTAssertEqual(outcomes.map(\.killed), [true, true])
        XCTAssertEqual(shell.commands.filter { $0.hasSuffix("emu kill") }, [
            "'/sdk/platform-tools/adb' -s 'emulator-5554' emu kill",
            "'/sdk/platform-tools/adb' -s 'emulator-5556' emu kill",
        ])
        XCTAssertEqual(try ledger.all(), [])
    }

    /// C02: the user's emulator-5554 carries a dead-pid record with its own
    /// AVD name (the shared-host state). `teardown --all` leaves it running.
    func testTeardownAllSkipsADeadPIDRecordWhoseSerialRunsTheSameAVD() async throws {
        let ledger = AndroidProvenance(directory: scratch.path)
        try ledger.register(StartedEmulatorRecord(serial: "emulator-5554", avd: "Pixel_8_API_35", pid: try deadPID()))
        let afterKill = "List of devices attached\nemulator-5554 device"
        let both = "List of devices attached\nemulator-5554 device\nemulator-5556 device"
        let shell = ScriptedShell([
            // emulator-5554: dead pid, serial listed; refused and dropped
            .success(both),
            // emulator-5556: ours, torn down
            .success(""), .success(""), .success(""),                    // force-stop x2, forward --list
            .success(both), .success(""), .success(afterKill),           // listed, emu kill, gone
        ])
        let emulators = EmulatorProcesses(shell)
        try ledger.register(StartedEmulatorRecord(serial: "emulator-5556", avd: "B", pid: try emulators.start(serial: "emulator-5556")))
        let outcomes = try await manager(emulators).teardownAll()
        XCTAssertEqual(outcomes, [EmulatorTeardownOutcome(serial: "emulator-5556", avd: "B", killed: true, recorded: true)])
        XCTAssertEqual(try ledger.all(), [])
        XCTAssertEqual(shell.commands.filter { $0.hasSuffix("emu kill") }, ["'/sdk/platform-tools/adb' -s 'emulator-5556' emu kill"])
        XCTAssertFalse(shell.commands.contains { $0.contains("'emulator-5554'") }, "nothing is sent to the user's emulator")
    }

    func testDeleteRefusesWhenARunningEmulatorsNameCannotBeRead() async {
        let shell = ScriptedShell([
            .success("List of devices attached\nemulator-5554 offline"),
            .failure(GrantivaError.commandFailed("offline", 1)),
        ])
        do {
            try await manager(shell).deleteAVD(name: "Pixel_8_API_35", force: true)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("refusing to delete"), "\(error)")
        }
        XCTAssertFalse(shell.commands.contains { $0.contains("delete avd") })
    }
}
