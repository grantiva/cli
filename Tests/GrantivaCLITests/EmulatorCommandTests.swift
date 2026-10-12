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
            execute: execute, provenance: ledger, bootTimeout: 1, pollInterval: 0.01, environment: [:], killTimeout: 1,
            flushTimeout: 0.2, leaseDirectory: dir.appendingPathComponent("locks").path
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

    // MARK: - K15: teardown stops the device's runner session

    func testTeardownStopsTheRunnerSessionOfTheTornDownSerial() async throws {
        let (_, manager, dir) = try ledgerAndManager()
        defer { try? FileManager.default.removeItem(at: dir) }
        let stopped = LockedList()
        let outcomes = try await EmulatorCommand.Teardown.teardown(
            manager, serial: "emulator-5598", force: true,
            stopRunners: { serial in
                stopped.append(serial)
                return [.terminated(runnerPid: 27331, udid: serial, killed: false)]
            }
        )
        XCTAssertEqual(stopped.values, ["emulator-5598"])
        XCTAssertEqual(outcomes.first?.runnerSessionStopped, true)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(JSONOutput.string(outcomes).utf8)) as? [[String: Any]])
        XCTAssertEqual(json.first?["runnerSessionStopped"] as? Bool, true)
        XCTAssertEqual(
            DeviceRunnerSessions.render(.terminated(runnerPid: 27331, udid: "emulator-5598", killed: false)),
            "Stopped runner session (pid 27331) for emulator-5598."
        )
    }

    func testARefusedTeardownStopsNothing() async throws {
        let (_, manager, dir) = try ledgerAndManager()
        defer { try? FileManager.default.removeItem(at: dir) }
        let stopped = LockedList()
        _ = try? await EmulatorCommand.Teardown.teardown(
            manager, serial: "emulator-5598", force: false,
            stopRunners: { stopped.append($0); return [] }
        )
        XCTAssertEqual(stopped.values, [])
    }

    /// The session.json `runner start` wrote is handed to the stopper and
    /// removed only when it names the torn-down serial.
    func testSessionFileNamingTheSerialIsStoppedAndRemoved() async {
        let removed = LockedList()
        let handed = LockedList()
        let file = RunnerSessionInfo(pid: 27331, wdaPort: 53095, bundleId: "b", udid: "emulator-5556", startedAt: Date(), platform: .android)
        let sessions = DeviceRunnerSessions(
            loadSession: { file },
            removeSession: { removed.append("session.json") },
            stopSessions: { udid, runnerStart, _ in
                handed.append("\(udid) \(runnerStart?.pid ?? 0)")
                return runnerStart?.udid == udid ? [.terminated(runnerPid: 27331, udid: udid, killed: false)] : []
            }
        )
        let outcomes = await sessions.stop(udid: "emulator-5556")
        XCTAssertEqual(outcomes.count, 1)
        XCTAssertEqual(removed.values, ["session.json"])

        let other = await sessions.stop(udid: "emulator-5554")
        XCTAssertTrue(other.isEmpty)
        XCTAssertEqual(removed.values, ["session.json"], "a session naming another serial is left alone")
        XCTAssertEqual(handed.values, ["emulator-5556 27331", "emulator-5554 27331"])
    }

    /// L36: teardown removes the session file before it signals the runner,
    /// as `runner stop` does, so a foreground `runner start` ends in order.
    func testTeardownRemovesTheSessionFileBeforeStoppingTheRunner() async {
        let events = LockedList()
        let file = RunnerSessionInfo(pid: 27331, wdaPort: 53095, bundleId: "b", udid: "emulator-5556", startedAt: Date(), platform: .android)
        let sessions = DeviceRunnerSessions(
            loadSession: { file },
            removeSession: { events.append("remove") },
            stopSessions: { udid, _, _ in events.append("stop"); return [.terminated(runnerPid: 27331, udid: udid, killed: false)] }
        )
        _ = await sessions.stop(udid: "emulator-5556")
        XCTAssertEqual(events.values, ["remove", "stop"])
    }

    /// The stop markers are written before anything is signalled.
    func testTeardownMarksTheDevicesRunnersBeforeStoppingThem() async {
        let events = LockedList()
        var sessions = DeviceRunnerSessions(
            loadSession: { nil }, removeSession: { events.append("remove") },
            stopSessions: { _, _, _ in events.append("stop"); return [] }
        )
        sessions.markStops = { udid in events.append("mark \(udid)"); return [77] }
        _ = await sessions.stop(udid: "emulator-5556")
        XCTAssertEqual(events.values, ["mark emulator-5556", "stop"])
    }

    /// The emulator is killed before its runners are stopped, so they are
    /// marked first; a refused teardown takes its markers back.
    func testEmulatorTeardownMarksBeforeTheKillAndUnmarksOnRefusal() async throws {
        let (_, manager, dir) = try ledgerAndManager()
        defer { try? FileManager.default.removeItem(at: dir) }
        let events = LockedList()
        _ = try await EmulatorCommand.Teardown.teardown(
            manager, serial: "emulator-5598", force: true,
            markStops: { events.append("mark \($0)"); return [77] },
            unmarkStops: { events.append("unmark \($0)") }
        )
        XCTAssertEqual(events.values, ["mark emulator-5598"])

        let refused = LockedList()
        _ = try? await EmulatorCommand.Teardown.teardown(
            manager, serial: "emulator-5598", force: false,
            markStops: { refused.append("mark \($0)"); return [78] },
            unmarkStops: { refused.append("unmark \($0)") }
        )
        XCTAssertEqual(refused.values, ["mark emulator-5598", "unmark [78]"])
    }

    /// L54: a foreground `runner start` marked before the kill may be gone
    /// (its runner died with the emulator, or it read the marker and ended)
    /// before `stopRunners` looks; the teardown still stopped it.
    func testAMarkedRunnerGoneBeforeTheStopCountsAsStopped() async throws {
        let (_, manager, dir) = try ledgerAndManager()
        defer { try? FileManager.default.removeItem(at: dir) }
        let outcomes = try await EmulatorCommand.Teardown.teardown(
            manager, serial: "emulator-5598", force: true,
            stopRunners: { _ in [] },
            markStops: { _ in [77] },
            waitForExit: { _ in true }
        )
        XCTAssertEqual(outcomes.first?.runnerSessionStopped, true)
        // A marked runner still alive after the bounded wait is not claimed.
        let alive = try await EmulatorCommand.Teardown.teardown(
            manager, serial: "emulator-5598", force: true,
            stopRunners: { _ in [] },
            markStops: { _ in [77] },
            waitForExit: { _ in false }
        )
        XCTAssertEqual(alive.first?.runnerSessionStopped, false)
        let unmarked = try await EmulatorCommand.Teardown.teardown(
            manager, serial: "emulator-5598", force: true, stopRunners: { _ in [] }, markStops: { _ in [] },
            waitForExit: { _ in true }
        )
        XCTAssertEqual(unmarked.first?.runnerSessionStopped, false)
    }

    /// L54: the same on a simulator, where the stop runs before the device
    /// goes: a marked runner the stop did not reach is reported once it has
    /// exited, and not while it still runs.
    func testAMarkedRunnerThatEndsOnItsOwnIsReportedOnceItHasExited() async {
        var sessions = DeviceRunnerSessions(loadSession: { nil }, removeSession: {}, stopSessions: { _, _, _ in [] })
        sessions.markStops = { _ in [77] }
        sessions.waitForExit = { _, _ in true }
        let stopped = await sessions.stop(udid: "emulator-5556")
        XCTAssertEqual(stopped, [.terminated(runnerPid: 77, udid: "emulator-5556", killed: false)])
        sessions.waitForExit = { _, _ in false }
        let running = await sessions.stop(udid: "emulator-5556")
        XCTAssertEqual(running, [])
    }

    // MARK: - L36 fix round 3: stop markers beside the owner files

    private func sleeper() throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["30"]
        try process.run()
        return process
    }

    private func stopMarkers(in directory: String) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []).filter { $0.hasSuffix(".stop.json") }
    }

    /// A foreground `runner start` under runner home A, torn down by a
    /// grantiva using runner home B: the marker is found through the shared
    /// session directory, not either home, and the start ends in order.
    func testAForegroundStartUnderOneHomeTornDownFromAnotherEndsInOrder() async throws {
        let sessions = FileManager.default.temporaryDirectory.appendingPathComponent("grantiva-sessions-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: sessions) }
        let runner = try sleeper()
        defer { runner.terminate() }
        let store = KeepAliveSessionStore(directory: sessions)
        // Home A's start records its runner (this test process holds it).
        store.recordOwner(
            udid: "emulator-5556", runnerPid: runner.processIdentifier, platform: .android, detached: false,
            command: KeepAliveOwner.runnerStartCommand
        )
        let startTime = RunnerStopMarker.processStartTime(runner.processIdentifier)
        // Home B's teardown: its runner home appears nowhere in the marking.
        let teardown = DeviceRunnerSessions(
            loadSession: { nil }, removeSession: {},
            stopSessions: { _, _, _ in [] },
            markStops: { DeviceRunnerSessions.markLive(udid: $0, store: store) },
            sweepStops: { store.stopMarkers.sweep() }
        )
        _ = await teardown.stop(udid: "emulator-5556")
        XCTAssertEqual(store.stopMarkers.directory, sessions)
        let request = RunnerStartCommand.stopRequest(
            runnerPid: runner.processIdentifier, session: nil,
            marked: store.stopMarkers.isMarked(runnerPid: runner.processIdentifier, runnerStartTime: startTime)
        )
        XCTAssertEqual(request, .teardown)
        XCTAssertEqual(
            try RunnerStartCommand.foregroundEnding(status: SIGTERM, pid: runner.processIdentifier, stop: request),
            "Runner stopped by teardown (pid \(runner.processIdentifier)); the session has ended."
        )
    }

    /// Detached starts and `run --keep-alive` runs read no marker, so a
    /// teardown of their devices leaves none behind.
    func testNoMarkerRemainsAfterTearingDownADetachedAndAKeepAliveRunner() async throws {
        let sessions = FileManager.default.temporaryDirectory.appendingPathComponent("grantiva-sessions-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: sessions) }
        let detached = try sleeper()
        let keepAlive = try sleeper()
        defer { detached.terminate(); keepAlive.terminate() }
        let store = KeepAliveSessionStore(directory: sessions)
        store.recordOwner(udid: "emulator-5556", runnerPid: detached.processIdentifier, platform: .android, detached: true,
                          command: KeepAliveOwner.runnerStartCommand)
        store.recordOwner(udid: "emulator-5558", runnerPid: keepAlive.processIdentifier, platform: .android, detached: false)
        for serial in ["emulator-5556", "emulator-5558"] {
            let teardown = DeviceRunnerSessions(
                loadSession: { nil }, removeSession: {}, stopSessions: { _, _, _ in [] },
                markStops: { DeviceRunnerSessions.markLive(udid: $0, store: store) },
                sweepStops: { store.stopMarkers.sweep() }
            )
            _ = await teardown.stop(udid: serial)
        }
        XCTAssertEqual(stopMarkers(in: sessions), [])
    }

    /// A marker that cannot be written is one warning naming the pid; the
    /// runner is still stopped.
    func testAMarkerThatCannotBeWrittenWarnsAndTheRunnerIsStillStopped() async throws {
        let sessions = FileManager.default.temporaryDirectory.appendingPathComponent("grantiva-sessions-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: sessions) }
        let runner = try sleeper()
        defer { runner.terminate() }
        let store = KeepAliveSessionStore(directory: sessions)
        store.recordOwner(udid: "emulator-5556", runnerPid: runner.processIdentifier, platform: .android, detached: false,
                          command: KeepAliveOwner.runnerStartCommand)
        let blocker = "\(sessions)/blocker"
        FileManager.default.createFile(atPath: blocker, contents: Data())
        let warnings = LockedList()
        let events = LockedList()
        let teardown = DeviceRunnerSessions(
            loadSession: { nil }, removeSession: {},
            stopSessions: { udid, _, _ in events.append("stop \(udid)"); return [] },
            markStops: { udid in
                DeviceRunnerSessions.markLive(
                    udid: udid, store: store, marker: RunnerStopMarker(directory: "\(blocker)/sub"), warn: warnings.append
                )
            }
        )
        _ = await teardown.stop(udid: "emulator-5556")
        XCTAssertEqual(warnings.values.count, 1)
        XCTAssertTrue(warnings.values.first?.contains("runner pid \(runner.processIdentifier)") == true, "\(warnings.values)")
        XCTAssertEqual(events.values, ["stop emulator-5556"])
    }

    // MARK: - L12/L35: what a teardown cleaned up is listed

    func testTeardownListsTheDeadRunnersSessionFilesAndTheTempDirectories() async throws {
        let (_, manager, dir) = try ledgerAndManager()
        defer { try? FileManager.default.removeItem(at: dir) }
        let swept = LockedList()
        let outcomes = try await EmulatorCommand.Teardown.teardown(
            manager, serial: "emulator-5598", force: true,
            stopRunners: { _ in [] },
            removeDeadSessions: { serial in
                swept.append(serial)
                return ["/tmp/grantiva-sessions/12109-1791747326192132000.grantiva"]
            }
        )
        XCTAssertEqual(swept.values, ["emulator-5598"])
        XCTAssertEqual(outcomes.first?.sessionFilesRemoved, ["/tmp/grantiva-sessions/12109-1791747326192132000.grantiva"])
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(JSONOutput.string(outcomes).utf8)) as? [[String: Any]])
        XCTAssertEqual(json.first?["sessionFilesRemoved"] as? [String], ["/tmp/grantiva-sessions/12109-1791747326192132000.grantiva"])
        XCTAssertEqual(json.first?["temporaryDirectoriesRemoved"] as? [String], [])
    }

    func testTeardownTextDoesNotAttributeStaleSessionFilesToTheSerial() {
        var outcome = EmulatorTeardownOutcome(serial: "emulator-5556", avd: "A", killed: true, recorded: true)
        outcome.sessionFilesRemoved = ["/tmp/grantiva-sessions/12109-1.grantiva"]
        XCTAssertEqual(EmulatorCommand.Teardown.cleanupLines(outcome), [
            "Removed 1 stale keep-alive session file(s) of runners that are no longer running.",
        ])
    }

    func testTeardownTextNamesTheRemovedTempDirectories() {
        var outcome = EmulatorTeardownOutcome(serial: "emulator-5556", avd: "A", killed: true, recorded: true)
        outcome.temporaryDirectoriesRemoved = ["/var/folders/x/T/grantiva-96934240", "/var/folders/x/T/grantiva-report-E0C9"]
        XCTAssertEqual(EmulatorCommand.Teardown.cleanupLines(outcome), [
            "Removed the killed run's temp directory /var/folders/x/T/grantiva-96934240.",
            "Removed the killed run's temp directory /var/folders/x/T/grantiva-report-E0C9.",
        ])
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

final class LockedList: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []
    func append(_ value: String) { lock.withLock { storage.append(value) } }
    var values: [String] { lock.withLock { storage } }
}
