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

    /// A ledger with "Kept" (on disk) and "Gone" (deleted behind Grantiva's
    /// back), and an emulator manager whose listing shows only "Kept".
    private func ledgerAndManager() throws -> (AndroidProvenance, EmulatorManager, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("emu-cmd-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let ledger = AndroidProvenance(directory: dir.path)
        try ledger.registerCreatedAVD("Kept")
        try ledger.registerCreatedAVD("Gone")
        let execute: @Sendable (String) async throws -> String = { command in
            if command.hasSuffix("-list-avds") { return "Kept" }
            if command.hasSuffix("devices -l") { return "List of devices attached" }
            return ""
        }
        let manager = EmulatorManager(
            sdk: AndroidSDK(root: "/sdk"), adb: ADB(path: "/sdk/platform-tools/adb", execute: execute),
            execute: execute, provenance: ledger, bootTimeout: 1, pollInterval: 0.01, environment: [:], killTimeout: 1
        )
        return (ledger, manager, dir)
    }

    func testSessionsPrunesCreatedAVDsGoneFromDisk() async throws {
        let (ledger, manager, dir) = try ledgerAndManager()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sessions = try await EmulatorCommand.Sessions.sessions(manager)
        XCTAssertEqual(sessions, [])
        XCTAssertEqual(try ledger.createdAVDs(), ["Kept"])
    }

    func testTeardownPrunesCreatedAVDsGoneFromDisk() async throws {
        let (ledger, manager, dir) = try ledgerAndManager()
        defer { try? FileManager.default.removeItem(at: dir) }
        let outcomes = try await EmulatorCommand.Teardown.teardown(manager, serial: nil, force: false)
        XCTAssertEqual(outcomes, [])
        XCTAssertEqual(try ledger.createdAVDs(), ["Kept"])
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
