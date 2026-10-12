import ArgumentParser
import XCTest
@testable import GrantivaCLI
import GrantivaCore

final class SimulatorCommandTests: XCTestCase {
    // `simulator --help` listed `delete` and `sessions` with empty descriptions.
    func testEverySimulatorSubcommandHasAnAbstract() {
        for command in SimulatorCommand.configuration.subcommands {
            XCTAssertFalse(
                command.configuration.abstract.isEmpty,
                "simulator \(command.configuration.commandName ?? String(describing: command)) has no abstract"
            )
        }
        XCTAssertEqual(SimulatorCommand.Delete.configuration.abstract, "Explicitly delete a named simulator.")
        XCTAssertEqual(SimulatorCommand.Sessions.configuration.abstract, "List Grantiva-managed simulator capacity slots.")
    }

    // Commands whose platform options include Android must not describe
    // themselves as simulator-only.
    func testAndroidCapableCommandAbstractsMentionEmulator() {
        let abstracts: [(String, String)] = [
            ("grantiva", GrantivaCommand.configuration.abstract),
            ("run", RunCommand.configuration.abstract),
            ("build", BuildCommand.configuration.abstract),
            ("build build", BuildOnlyCommand.configuration.abstract),
            ("build install", InstallCommand.configuration.abstract),
            ("record", RecordCommand.configuration.abstract),
            ("hierarchy", HierarchyCommand.configuration.abstract),
        ]
        for (name, abstract) in abstracts where abstract.localizedCaseInsensitiveContains("simulator") {
            XCTAssertTrue(
                abstract.localizedCaseInsensitiveContains("emulator"),
                "\(name) abstract mentions simulator but not emulator: \(abstract)"
            )
        }
        XCTAssertTrue(GrantivaCommand.configuration.abstract.contains("Android"))
    }

    func testEnsureParsesExactProvisioningTarget() throws {
        let command = try SimulatorCommand.Ensure.parse([
            "--name", "APP-302 iPhone 393x852",
            "--device-type", "iPhone 15 Pro",
            "--runtime", "latest", "--boot", "--json",
        ])
        XCTAssertEqual(command.name, "APP-302 iPhone 393x852")
        XCTAssertEqual(command.deviceType, "iPhone 15 Pro")
        XCTAssertEqual(command.runtime, "latest")
        XCTAssertTrue(command.boot)
        XCTAssertTrue(command.options.json)
    }

    // `ensure` exists to be captured: `udid=$(grantiva simulator ensure --name X)`.
    // It shipped in 1.7.0 printing "Created iPhone 17 (UDID) — Booted" on stdout,
    // so that substitution produced a sentence where callers expected an
    // identifier, and the failure only surfaced later as an unusable --device
    // argument. stdout must therefore be the UDID and nothing else.
    func testEnsurePrintsBareUDIDOnStdout() throws {
        let result = SimulatorProvisionResult(
            name: "iPhone 17", udid: "921A0945-7157-4533-BA1F-21E8132D3E40",
            deviceType: "iPhone 17", runtime: "iOS 27.0", created: true, state: "Booted",
            pointWidth: nil, pointHeight: nil, pixelWidth: nil, pixelHeight: nil, displayScale: nil
        )
        let rendered = SimulatorCommand.Ensure.render(result)

        XCTAssertEqual(rendered.stdout, "921A0945-7157-4533-BA1F-21E8132D3E40")
        XCTAssertFalse(rendered.stdout.contains(" "), "stdout must be a bare UDID, not prose")

        // The human-readable line is not lost — it moves to stderr, which a
        // terminal shows and a command substitution ignores.
        XCTAssertTrue(rendered.stderr.contains("Created"))
        XCTAssertTrue(rendered.stderr.contains("iPhone 17"))
        XCTAssertTrue(rendered.stderr.contains("Booted"))
    }

    func testEnsureReportsReuseOnStderrAndStillPrintsUDID() throws {
        let result = SimulatorProvisionResult(
            name: "iPhone 17", udid: "AAAA1111-2222-3333-4444-555566667777",
            deviceType: "iPhone 17", runtime: "iOS 27.0", created: false, state: "Shutdown",
            pointWidth: nil, pointHeight: nil, pixelWidth: nil, pixelHeight: nil, displayScale: nil
        )
        let rendered = SimulatorCommand.Ensure.render(result)
        XCTAssertEqual(rendered.stdout, "AAAA1111-2222-3333-4444-555566667777")
        XCTAssertTrue(rendered.stderr.hasPrefix("Reused"))
    }

    func testDeleteRequiresAndParsesExactName() throws {
        let command = try SimulatorCommand.Delete.parse(["--name", "APP-302 iPhone 393x852", "--json"])
        XCTAssertEqual(command.name, "APP-302 iPhone 393x852")
        XCTAssertTrue(command.options.json)
    }

    func testSessionsSupportsJSON() throws {
        let command = try SimulatorCommand.Sessions.parse(["--json"])
        XCTAssertTrue(command.options.json)
    }

    func testTeardownAcceptsASessionIdentifier() throws {
        let command = try SimulatorCommand.Teardown.parse(["--session-id", "APP-652", "--json"])
        XCTAssertEqual(command.sessionId, "APP-652")
        XCTAssertNil(command.udid)
        XCTAssertFalse(command.force)
        XCTAssertTrue(command.options.json)
        XCTAssertNoThrow(try command.validate())
    }

    func testTeardownReclaimsBySimulatorUDID() throws {
        // The case `--session-id` cannot serve: a stranded run whose session
        // ledger is empty but whose simulator is still owned.
        let command = try SimulatorCommand.Teardown.parse([
            "--udid", "A1B2C3D4-1111-2222-3333-444455556666", "--force", "--json",
        ])
        XCTAssertEqual(command.udid, "A1B2C3D4-1111-2222-3333-444455556666")
        XCTAssertTrue(command.force)
        XCTAssertNil(command.sessionId)
        XCTAssertNoThrow(try command.validate())
    }

    func testTeardownRejectsBothSelectorsTogether() {
        XCTAssertThrowsError(
            try SimulatorCommand.Teardown.parse(["--session-id", "APP-652", "--udid", "SIM-1"])
        ) { error in
            XCTAssertTrue(String(describing: error).contains("mutually exclusive"), String(describing: error))
        }
    }

    func testTeardownRequiresOneSelector() {
        XCTAssertThrowsError(try SimulatorCommand.Teardown.parse([])) { error in
            XCTAssertTrue(
                String(describing: error).contains("--session-id <id> or --udid <UDID>"),
                String(describing: error)
            )
        }
    }

    // `grantiva simulator teardown --udid "$UDID" --force` with UDID unset
    // reaches the CLI as `--udid ""`. An empty string is non-nil, so it
    // satisfied the "pass one selector" check, matched no process, released no
    // lease, and exited 0 printing "No processes were holding ." — the script
    // concluded it had reclaimed the device.
    func testTeardownRejectsAnEmptyUDIDRatherThanReportingSuccess() {
        XCTAssertThrowsError(try SimulatorCommand.Teardown.parse(["--udid", "", "--force"])) { error in
            let message = String(describing: error)
            XCTAssertTrue(message.contains("--udid is empty"), message)
        }
    }

    func testTeardownRejectsAMalformedUDID() {
        XCTAssertThrowsError(
            try SimulatorCommand.Teardown.parse(["--udid", "not-a-udid-at-all", "--force"])
        ) { error in
            let message = String(describing: error)
            XCTAssertTrue(message.contains("is not a simulator UDID"), message)
        }
    }

    func testTeardownRejectsAnEmptySessionIdentifier() {
        XCTAssertThrowsError(try SimulatorCommand.Teardown.parse(["--session-id", ""])) { error in
            let message = String(describing: error)
            XCTAssertTrue(message.contains("--session-id is empty"), message)
        }
    }

    func testEnsureNeedsOnlyAName() throws {
        let command = try SimulatorCommand.Ensure.parse(["--name", "iPhone 17"])
        XCTAssertEqual(command.name, "iPhone 17")
        XCTAssertNil(command.deviceType)
        XCTAssertNil(command.runtime)
        // Booting is the point of `ensure`; the shell function it replaces
        // created, booted, and waited for bootstatus.
        XCTAssertTrue(command.boot)
    }

    func testEnsureCanSkipBooting() throws {
        let command = try SimulatorCommand.Ensure.parse(["--name", "iPhone 17", "--no-boot"])
        XCTAssertFalse(command.boot)
    }

    func testProvisionReportContainsExactDisplayGeometry() throws {
        let report = SimulatorProvisionResult(
            name: "APP-302 iPhone 393x852", udid: "EXACT-UDID", deviceType: "iPhone 15 Pro",
            runtime: "iOS 18.0", created: true, state: "Booted",
            pointWidth: 393, pointHeight: 852, pixelWidth: 1179, pixelHeight: 2556, displayScale: 3
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(report)) as? [String: Any])
        XCTAssertEqual((object["point_dimensions"] as? [String: Int])?["width"], 393)
        XCTAssertEqual((object["point_dimensions"] as? [String: Int])?["height"], 852)
        XCTAssertEqual((object["pixel_dimensions"] as? [String: Int])?["width"], 1179)
        XCTAssertEqual((object["pixel_dimensions"] as? [String: Int])?["height"], 2556)
        XCTAssertEqual(object["display_scale"] as? Double, 3)
        XCTAssertEqual(object["created"] as? Bool, true)
        XCTAssertEqual(object["udid"] as? String, "EXACT-UDID")
    }
    func testCleanupSupportsJSON() throws {
        let command = try SimulatorCommand.Cleanup.parse(["--json"])
        XCTAssertTrue(command.options.json)
    }

    func testTeardownOutcomeEncodesDeletedFlag() throws {
        let outcome = SimulatorTeardownOutcome(
            session: ManagedSimulatorSession(
                udid: "EXACT-UDID", name: "TienLen Flow APP-652", sessionId: "APP-652",
                ownerPID: 1, acquiredAt: Date(), state: .active
            ),
            deleted: true
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(outcome)) as? [String: Any])
        XCTAssertEqual(object["deleted"] as? Bool, true)
        XCTAssertEqual((object["session"] as? [String: Any])?["sessionId"] as? String, "APP-652")
        XCTAssertEqual(object["deviceHomesRemoved"] as? [String], [])
        XCTAssertEqual(object["deviceHomeFailures"] as? [String], [])
    }

    func testForceTeardownJSONStillFailsWhenARunnerHomeCouldNotBeRemoved() async throws {
        try XCTSkipIf(geteuid() == 0, "a read-only parent does not stop root from removing the home")
        let fm = FileManager.default
        let directory = fm.temporaryDirectory.appendingPathComponent("grantiva-force-json-\(UUID().uuidString)").path
        let udid = "F0F0F0F0-1111-2222-3333-444455556666"
        let devices = "\(directory)/runner/versions/v1/devices"
        try fm.createDirectory(atPath: "\(devices)/\(udid)", withIntermediateDirectories: true)
        try fm.setAttributes([.posixPermissions: 0o555], ofItemAtPath: devices)
        defer {
            try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: devices)
            try? fm.removeItem(atPath: directory)
        }
        let result = try await SimulatorReaper.forceTeardown(
            udid: udid,
            capacity: SimulatorCapacity(directory: directory),
            leaseDirectory: directory,
            runnerBase: "\(directory)/runner",
            sessions: KeepAliveSessionStore(directory: "\(directory)/sessions", isProcessAlive: { _ in false }),
            snapshot: { "" },
            gracePeriod: 0,
            isProcessAlive: { _ in false }
        )

        let output = try SimulatorCommand.Teardown.forceOutput([result], json: true)

        XCTAssertEqual(output.lines.count, 1, "--json prints one document")
        let objects = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(output.lines[0].utf8)) as? [[String: Any]])
        XCTAssertEqual((objects.first?["deviceHomeFailures"] as? [String])?.count, 1)
        let message = try XCTUnwrap(output.error?.errorDescription)
        XCTAssertTrue(message.contains("\(devices)/\(udid)"), message)
    }

    func testTeardownFailsWhenARunnerHomeCouldNotBeRemoved() throws {
        XCTAssertNil(SimulatorCommand.Teardown.deviceHomeError([]))
        let error = try XCTUnwrap(SimulatorCommand.Teardown.deviceHomeError(["/r/versions/v1/devices/U: denied"]))
        let message = error.errorDescription ?? ""
        XCTAssertTrue(message.contains("/r/versions/v1/devices/U: denied"), message)
        XCTAssertTrue(message.contains("Delete it by hand"), message)
    }

    /// L22: Foundation's reason ends with a period; the message has one.
    func testTheRunnerHomeErrorHasNoDoubledPeriod() throws {
        let reason = "/r/versions/v1/devices/U: \u{201C}U\u{201D} couldn\u{2019}t be removed because you don\u{2019}t have permission to access it."
        let one = try XCTUnwrap(SimulatorCommand.Teardown.deviceHomeError([reason]).flatMap(\.errorDescription))
        XCTAssertFalse(one.contains(".."), one)
        XCTAssertTrue(one.hasSuffix("access it. Delete it by hand."), one)
        let two = try XCTUnwrap(SimulatorCommand.Teardown.deviceHomeError([reason, "/r/devices/U: denied."]).flatMap(\.errorDescription))
        XCTAssertFalse(two.contains(".."), two)
        XCTAssertTrue(two.contains("access it; /r/devices/U: denied. Delete it by hand."), two)
    }

    /// K42: usage errors read `Error: <message>` with exit 64, never the
    /// runtime "Invalid argument:" prefix.
    func testTeardownUsageErrorsCarryNoInvalidArgumentPrefix() {
        let cases: [([String], String)] = [
            (["--udid", "", "--force"], "--udid is empty"),
            (["--udid", "not-a-udid-at-all", "--force"], "--udid not-a-udid-at-all is not a simulator UDID"),
            (["--session-id", ""], "--session-id is empty"),
        ]
        for (arguments, prefix) in cases {
            XCTAssertThrowsError(try SimulatorCommand.Teardown.parse(arguments)) { error in
                let message = SimulatorCommand.Teardown.message(for: error)
                XCTAssertTrue(message.hasPrefix(prefix), "\(arguments): \(message)")
                XCTAssertFalse(message.contains("Invalid argument"), message)
                XCTAssertEqual(SimulatorCommand.Teardown.exitCode(for: error), .validationFailure, "\(arguments)")
            }
        }
    }

    func testDeviceIDUsageErrorsOnHierarchyAndDumpHierarchyHaveTheSameShape() {
        XCTAssertThrowsError(try HierarchyCommand.parse(["--udid", ""])) { error in
            let message = HierarchyCommand.message(for: error)
            XCTAssertFalse(message.contains("Invalid argument"), message)
            XCTAssertTrue(message.hasPrefix("--udid is empty"), message)
            XCTAssertEqual(HierarchyCommand.exitCode(for: error), .validationFailure)
        }
        XCTAssertThrowsError(try DumpHierarchyCommand.parse(["--udid", ""])) { error in
            let message = DumpHierarchyCommand.message(for: error)
            XCTAssertFalse(message.contains("Invalid argument"), message)
            XCTAssertEqual(DumpHierarchyCommand.exitCode(for: error), .validationFailure)
        }
        XCTAssertThrowsError(try EmulatorCommand.Teardown.parse(["--serial", ""])) { error in
            let message = EmulatorCommand.Teardown.message(for: error)
            XCTAssertFalse(message.contains("Invalid argument"), message)
            XCTAssertEqual(EmulatorCommand.Teardown.exitCode(for: error), .validationFailure)
        }
    }

    // MARK: - K15: teardown stops the simulator's runner session

    func testTeardownStopsRunnerSessionsOfEveryTargetFirst() async throws {
        let stopped = LockedList()
        let lines = await SimulatorCommand.Teardown.stopRunnerSessions(udids: ["A", "B"]) { udid in
            stopped.append(udid)
            return udid == "A" ? [.released(grantivaPid: 4163, runnerPid: 4267, udid: "A")] : []
        }
        XCTAssertEqual(stopped.values, ["A", "B"])
        XCTAssertEqual(lines.stopped, ["A"])
        XCTAssertEqual(lines.lines, ["Stopped runner session (pid 4267) for A."])
    }

    /// Fix round 1, item 5: an unmanaged UDID without --force is a no-op
    /// teardown, so its runner sessions are left alone.
    func testRunnerSessionsAreStoppedOnlyOnDevicesTheTeardownActsOn() {
        typealias T = SimulatorCommand.Teardown
        let record = ManagedSimulatorSession(udid: "MANAGED", name: "n", sessionId: "S1", ownerPID: 1, acquiredAt: Date(), state: .active)
        XCTAssertEqual(T.runnerStopTargets(udid: "UNMANAGED", sessionId: nil, force: false, managed: [record]), [])
        XCTAssertEqual(T.runnerStopTargets(udid: "UNMANAGED", sessionId: nil, force: true, managed: [record]), ["UNMANAGED"])
        XCTAssertEqual(T.runnerStopTargets(udid: "MANAGED", sessionId: nil, force: false, managed: [record]), ["MANAGED"])
        XCTAssertEqual(T.runnerStopTargets(udid: nil, sessionId: "S1", force: false, managed: [record]), ["MANAGED"])
        XCTAssertEqual(T.runnerStopTargets(udid: nil, sessionId: "other", force: false, managed: [record]), [])
    }

    // MARK: - L04: teardown names a leftover device process it did not start

    func testTeardownReportsALeftoverDeviceProcessByPidAndCommand() throws {
        typealias T = SimulatorCommand.Teardown
        let udid = "AD257930-C4D0-4C0F-9DAA-DAA6C335AF8F"
        let ps = """
         4806  4806 /Library/Developer/PrivateFrameworks/CoreSimulator.framework/Versions/A/Resources/bin/simctl diagnose -l -b --timeout=600 --no-archive --udid=\(udid)
         4900  4900 /usr/bin/xcrun simctl diagnose --udid=OTHER-DEVICE
         4999  4999 /opt/homebrew/bin/grantiva simulator teardown --udid \(udid)
        """
        let leftovers = T.leftoverProcesses(udids: [udid], psOutput: ps)
        XCTAssertEqual(leftovers[udid]?.map(\.pid), [4806])
        XCTAssertEqual(leftovers[udid]?.first?.killed, false)

        let lines = T.leftoverWarnings(leftovers)
        XCTAssertEqual(lines.count, 1)
        XCTAssertTrue(lines[0].contains("pid 4806"), lines[0])
        XCTAssertTrue(lines[0].contains("simctl diagnose -l -b --timeout=600"), lines[0])
        XCTAssertTrue(lines[0].contains("grantiva simulator teardown --udid \(udid) --force"), lines[0])

        let outcome = SimulatorTeardownOutcome(udid: udid, session: nil, deleted: false)
        let marked = T.marking([outcome], stopped: [], leftovers: leftovers)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(marked[0])) as? [String: Any])
        let list = try XCTUnwrap(object["leftoverProcesses"] as? [[String: Any]])
        XCTAssertEqual(list.first?["pid"] as? Int, 4806)
        XCTAssertEqual(list.first?["kind"] as? String, "diagnose")
    }

    /// A non-force `--udid` with no ledger record deletes nothing, so it has
    /// nothing to warn about; a managed device or session is checked.
    func testLeftoverCheckCoversOnlyDevicesTheTeardownDeletes() {
        typealias T = SimulatorCommand.Teardown
        let record = ManagedSimulatorSession(udid: "MANAGED", name: "n", sessionId: "S1", ownerPID: 1, acquiredAt: Date(), state: .active)
        XCTAssertEqual(T.leftoverCheckTargets(udid: "UNMANAGED", sessionId: nil, managed: [record]), [])
        XCTAssertEqual(T.leftoverCheckTargets(udid: "MANAGED", sessionId: nil, managed: [record]), ["MANAGED"])
        XCTAssertEqual(T.leftoverCheckTargets(udid: nil, sessionId: "S1", managed: [record]), ["MANAGED"])
        XCTAssertEqual(T.leftoverCheckTargets(udid: nil, sessionId: "other", managed: [record]), [])
    }

    func testTeardownOutcomeEncodesRunnerSessionStopped() throws {
        var outcome = SimulatorTeardownOutcome(
            session: ManagedSimulatorSession(
                udid: "EXACT-UDID", name: "n", sessionId: "s", ownerPID: 1, acquiredAt: Date(), state: .active
            ),
            deleted: false
        )
        outcome.runnerSessionStopped = true
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(outcome)) as? [String: Any])
        XCTAssertEqual(object["runnerSessionStopped"] as? Bool, true)
    }

    /// L54: a foreground `runner start` torn down while its session flow
    /// still runs has only its owner sidecar (no `.grantiva` file, no
    /// session.json in the teardown's directory). The teardown stops it and
    /// reports runnerSessionStopped.
    func testTeardownWithOnlyAnOwnerFileReportsRunnerSessionStopped() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("grantiva-sessions-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let udid = "921A0945-7157-4533-BA1F-21E8132D3E40"
        let owner = KeepAliveOwner(
            udid: udid, runnerPid: 701, grantivaPid: 700, detached: false, command: KeepAliveOwner.runnerStartCommand
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(owner).write(to: directory.appendingPathComponent("701.owner.json"))
        let alive = TeardownLocked<Set<Int32>>([700, 701])
        let events = TeardownLocked<[String]>([])
        let store = KeepAliveSessionStore(directory: directory.path, isProcessAlive: { alive.value.contains($0) })
        let stopper = RunnerSessionStopper(
            store: store,
            isProcessAlive: { alive.value.contains($0) },
            parentPid: { $0 == 701 ? 700 : nil },
            isRunnerProcess: { $0 == 701 },
            isGrantivaProcess: { $0 == 700 },
            interrupt: { events.append("interrupt \($0)") },
            terminateGroup: { pid in
                events.append("terminate \(pid)")
                alive.mutate { $0.subtract([700, 701]) }
                return .interrupted
            },
            removeSessionFiles: { events.append("files \($0)") },
            releaseLease: { _ in },
            cleanupOrphans: { _ in },
            waitTimeout: 2,
            pollInterval: .milliseconds(10)
        )
        let sessions = DeviceRunnerSessions(
            loadSession: { nil }, removeSession: {},
            stopSessions: { udid, file in await stopper.stopSessions(udid: udid, runnerStartSession: file) }
        )
        let (stopped, lines, _) = await SimulatorCommand.Teardown.stopRunnerSessions(udids: [udid]) { await sessions.stop(udid: $0) }
        XCTAssertEqual(stopped, [udid])
        XCTAssertEqual(lines, ["Stopped runner session (pid 701) for \(udid)."])
        XCTAssertEqual(events.value, ["terminate 701", "files 701"])
        let outcome = SimulatorTeardownOutcome(udid: udid, session: nil, deleted: true)
        XCTAssertEqual(SimulatorCommand.Teardown.marking([outcome], stopped: stopped).first?.runnerSessionStopped, true)
    }
}

private final class TeardownLocked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value
    init(_ value: Value) { storage = value }
    var value: Value { lock.withLock { storage } }
    func mutate(_ body: (inout Value) -> Void) { lock.withLock { body(&storage) } }
    func append<Element>(_ element: Element) where Value == [Element] { mutate { $0.append(element) } }
}
