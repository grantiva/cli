import ArgumentParser
import XCTest
@testable import GrantivaCLI
import GrantivaCore

final class EmulatorCommandTests: XCTestCase {
    func testEnsureParsesItsFlags() throws {
        let command = try EmulatorCommand.Ensure.parse(["--name", "Pixel_8_API_35", "--system-image", "system-images;android-35;google_apis;arm64-v8a", "--no-boot", "--headless", "--json"])
        XCTAssertEqual(command.name, "Pixel_8_API_35")
        XCTAssertEqual(command.systemImage, "system-images;android-35;google_apis;arm64-v8a")
        XCTAssertFalse(command.boot)
        XCTAssertTrue(command.headless)
        XCTAssertTrue(command.options.json)
        XCTAssertTrue(try EmulatorCommand.Ensure.parse([]).boot, "boot is the default")
    }

    /// Mirrors `simulator ensure`: stdout is the identifier, context goes to stderr.
    func testEnsurePrintsTheSerialOrNameOnStdout() {
        let booted = EmulatorCommand.Ensure.render(EmulatorProvisionResult(name: "Pixel_8_API_35", serial: "emulator-5554", created: true, state: "Booted"))
        XCTAssertEqual(booted.stdout, "emulator-5554")
        XCTAssertEqual(booted.stderr, "Created Pixel_8_API_35 (emulator-5554) — Booted")
        let idle = EmulatorCommand.Ensure.render(EmulatorProvisionResult(name: "Pixel_8_API_35", serial: nil, created: false, state: "Shutdown"))
        XCTAssertEqual(idle.stdout, "Pixel_8_API_35")
        XCTAssertEqual(idle.stderr, "Reused Pixel_8_API_35 — Shutdown")
    }

    func testEnsureNameFallsBackToConfigThenFails() throws {
        XCTAssertEqual(try EmulatorCommand.Ensure.resolveName(flag: "A", config: nil), "A")
        XCTAssertEqual(try EmulatorCommand.Ensure.resolveName(flag: nil, config: GrantivaConfig(platform: .android, android: AndroidProject(emulator: "B"))), "B")
        XCTAssertThrowsError(try EmulatorCommand.Ensure.resolveName(flag: nil, config: nil)) { error in
            XCTAssertTrue("\(error)".contains("--name"), "\(error)")
        }
    }

    func testTeardownNeedsExactlyOneTarget() {
        XCTAssertThrowsError(try EmulatorCommand.Teardown.parse([]))
        XCTAssertThrowsError(try EmulatorCommand.Teardown.parse(["--serial", "emulator-5554", "--all"]))
        XCTAssertThrowsError(try EmulatorCommand.Teardown.parse(["--serial", ""]))
        XCTAssertThrowsError(try EmulatorCommand.Teardown.parse(["--serial", "921A0945-7157-4533-BA1F-21E8132D3E40"]), "a simulator UDID is not an emulator")
        XCTAssertNoThrow(try EmulatorCommand.Teardown.parse(["--serial", "emulator-5554", "--force"]))
        XCTAssertNoThrow(try EmulatorCommand.Teardown.parse(["--all"]))
    }

    func testDeleteParsesForce() throws {
        let command = try EmulatorCommand.Delete.parse(["--name", "Pixel_8_API_35", "--force"])
        XCTAssertEqual(command.name, "Pixel_8_API_35")
        XCTAssertTrue(command.force)
    }

    func testSessionsRenderOneLinePerEmulator() {
        let record = EmulatorSessionRecord(serial: "emulator-5554", avd: "Pixel_8_API_35", pid: 42, startedAt: Date(), processAlive: true, adbState: "device")
        XCTAssertEqual(EmulatorCommand.Sessions.render([record]), ["Grantiva-started emulators (1):", "  emulator-5554 (Pixel_8_API_35) — pid 42 running, adb: device"])
        XCTAssertEqual(EmulatorCommand.Sessions.render([]), ["No emulators started by Grantiva are running."])
    }

    func testEmulatorIsARootSubcommand() {
        XCTAssertTrue(GrantivaCommand.configuration.subcommands.contains { ObjectIdentifier($0) == ObjectIdentifier(EmulatorCommand.self) })
    }
}
