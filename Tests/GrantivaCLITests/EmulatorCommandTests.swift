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

    // MARK: - K28 teardown bookkeeping

    /// A refused teardown still forgets created AVDs that are gone from disk.
    func testRefusedTeardownStillPrunesCreatedAVDsGoneFromDisk() async throws {
        let (ledger, manager, dir) = try ledgerAndManager()
        defer { try? FileManager.default.removeItem(at: dir) }
        do {
            _ = try await EmulatorCommand.Teardown.teardown(manager, serial: "emulator-5598", force: false)
            XCTFail("expected the not-started-by-Grantiva refusal")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("was not started by Grantiva"), "\(error)")
        }
        XCTAssertEqual(try ledger.createdAVDs(), ["Kept"])
    }

    func testTeardownOutcomeWording() {
        typealias T = EmulatorCommand.Teardown
        XCTAssertEqual(T.render(EmulatorTeardownOutcome(serial: "emulator-5554", avd: "A", killed: true, recorded: true)), "Killed emulator-5554 (A).")
        XCTAssertEqual(T.render(EmulatorTeardownOutcome(serial: "emulator-5554", avd: "A", killed: false, recorded: true)), "emulator-5554 (A) was already gone; dropped its record.")
        XCTAssertEqual(T.render(EmulatorTeardownOutcome(serial: "emulator-5598", avd: nil, killed: false, recorded: false)), "emulator-5598 is not attached and has no record; nothing to do.")
    }

    func testForcedTeardownOfAnUnknownSerialReportsNoRecord() async throws {
        let (_, manager, dir) = try ledgerAndManager()
        defer { try? FileManager.default.removeItem(at: dir) }
        let outcomes = try await EmulatorCommand.Teardown.teardown(manager, serial: "emulator-5598", force: true)
        XCTAssertEqual(outcomes, [EmulatorTeardownOutcome(serial: "emulator-5598", avd: nil, killed: false, recorded: false)])
    }

    // MARK: - K30 delete --json

    func testDeleteJSONIsPrettyPrintedLikeItsSiblings() throws {
        let rendered = try EmulatorCommand.Delete.renderJSON(name: "fix-k30")
        XCTAssertEqual(rendered, "{\n  \"deleted\" : true,\n  \"name\" : \"fix-k30\"\n}")
        XCTAssertEqual(rendered, try JSONOutput.string(EmulatorDeleteResult(name: "fix-k30", deleted: true)))
    }

    /// No command prints a compact hand-made JSON document: a
    /// JSONSerialization call (for `[String: Any]` trees) is pretty-printed
    /// and key-sorted like JSONOutput.
    func testNoCommandPrintsCompactJSONSerializationOutput() throws {
        let commands = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/GrantivaCLI")
        let files = try FileManager.default.contentsOfDirectory(atPath: commands.path).filter { $0.hasSuffix(".swift") }
        XCTAssertFalse(files.isEmpty)
        for file in files {
            let source = try String(contentsOf: commands.appendingPathComponent(file), encoding: .utf8)
            // Whitespace-free, so a call split over several lines still
            // matches; each call is checked up to the next one.
            let flat = source.filter { !$0.isWhitespace }
            let calls = flat.components(separatedBy: "JSONSerialization.data(withJSONObject:").dropFirst()
            for call in calls {
                let options = call.range(of: "options:").map { String(call[$0.upperBound...].prefix(80)) } ?? ""
                XCTAssertTrue(options.contains(".prettyPrinted") && options.contains(".sortedKeys"), "\(file): options \(options)")
            }
        }
    }

    // MARK: - K27 headless rule in help and docs

    func testHeadlessHelpAndDocsStateTheRule() throws {
        let variable = EmulatorManager.headlessVariable
        XCTAssertTrue(EmulatorCommand.Ensure.helpMessage().contains(variable), EmulatorCommand.Ensure.helpMessage())
        XCTAssertTrue(InstallCommand.helpMessage().contains(variable), InstallCommand.helpMessage())
        let doc = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("docs/android.md"),
            encoding: .utf8
        )
        XCTAssertTrue(doc.contains(variable), "docs/android.md names \(variable)")
        let flat = doc.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        XCTAssertTrue(flat.contains("even when stdout is not a terminal"), "docs/android.md states the rule")
        XCTAssertTrue(flat.contains("`CI` set to any value other than empty, `0` or `false`"), "docs/android.md names CI")
        XCTAssertTrue(EmulatorCommand.Ensure.helpMessage(columns: 1000).contains("CI=true"))
        XCTAssertTrue(InstallCommand.helpMessage(columns: 1000).contains("CI=true"))
    }
}
