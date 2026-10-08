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

    private final class SpawnRecorder: @unchecked Sendable {
        var calls: [(String, [String])] = []
        func spawn(_ executable: String, _ arguments: [String]) throws -> Int32 {
            calls.append((executable, arguments)); return 4242
        }
    }

    private func manager(_ shell: ScriptedShell, spawn: SpawnRecorder = SpawnRecorder(), headless: Bool = true) -> EmulatorManager {
        EmulatorManager(
            sdk: AndroidSDK(root: "/sdk"),
            adb: ADB(path: "/sdk/platform-tools/adb", execute: shell.execute),
            execute: shell.execute,
            spawn: spawn.spawn,
            provenance: AndroidProvenance(directory: scratch.path),
            headless: headless,
            bootTimeout: 1,
            pollInterval: 0.01
        )
    }

    func testChoosePortSkipsSerialsInUse() {
        XCTAssertEqual(EmulatorManager.choosePort(used: []), 5554)
        XCTAssertEqual(EmulatorManager.choosePort(used: ["emulator-5554", "emulator-5556"]), 5558)
        let all = stride(from: 5554, through: 5584, by: 2).map { "emulator-\($0)" }
        XCTAssertNil(EmulatorManager.choosePort(used: all))
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
            .success(""),
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
}
