import Foundation
import XCTest
@testable import GrantivaCLI
import GrantivaCore

@available(macOS 15, *)
final class RunnerLifecycleCommandTests: XCTestCase {
    func testForegroundPortDiscoveryHandlesPortSplitAcrossOutputChunks() async {
        let (stream, continuation) = AsyncStream<Data>.makeStream()
        let probed = LockedValue(false)
        continuation.yield(Data("Starting WDA on localhost:84".utf8))
        continuation.yield(Data("30\n".utf8))
        continuation.finish()

        let port = await RunnerStartCommand.waitForForegroundWDAPort(
            chunks: stream,
            timeout: { _ in try? await Task.sleep(for: .seconds(5)) },
            probe: { probed.set(true); return nil }
        )

        XCTAssertEqual(port, .port(8430))
        XCTAssertFalse(probed.value)
    }

    func testWDAStartupParsingAcceptsTheRunnerAnnouncement() {
        XCTAssertEqual(
            RunnerStartCommand.parseWDAStartup("[wda] WDA build completed successfully\nWDA started successfully on port 8100\n"),
            .port(8100)
        )
    }

    func testWDAStartupParsingIgnoresBuildLogNoise() {
        // The line that once produced "WDA port: 6072": a clang response-file
        // hash on a line naming the WebDriverAgent build directory.
        let log = """
        CompileC /Users/k/.grantiva/runner/cache/wda-builds/sim-ios26.0-iphone/DerivedData/Build/Intermediates.noindex/WebDriverAgent.build/Debug-iphonesimulator/WebDriverAgentRunner.build/Objects-normal/arm64/UITestingUITests.o @/tmp/e6072d4f65d7061329687fe24e3d63a7-common-args.resp
        -target arm64-apple-ios15.0-simulator -isysroot /Applications/Xcode-27.0.0.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator26.0.sdk
        warning: include location '/usr/local/include' is unsafe for cross-compilation [-Wpoison-system-directories]
        """
        XCTAssertNil(RunnerStartCommand.parseWDAStartup(log))
    }

    func testWDAStartupParsingReportsAFailedBuild() {
        let log = "error: include location '/usr/local/include' is unsafe for cross-compilation [-Werror,-Wpoison-system-directories]\n** TEST BUILD FAILED **\n"
        XCTAssertEqual(RunnerStartCommand.parseWDAStartup(log), .buildFailed)
        XCTAssertEqual(RunnerStartCommand.parseWDAStartup("[wda] WDA build failed: xcodebuild failed: exit status 65\n"), .buildFailed)
    }

    func testWDAStartupParsingPrefersAPortOverAnEarlierFailure() {
        let log = "WDA build failed: exit status 65\nWDA stalled on attempt 1\nWDA started successfully on port 8430\n"
        XCTAssertEqual(RunnerStartCommand.parseWDAStartup(log), .port(8430))
    }

    func testWDAStartupErrorNamesTheFailedBuild() {
        let failed = RunnerStartCommand.wdaStartupError(.buildFailed, logPath: "/tmp/r.log")
        XCTAssertTrue("\(failed)".contains("WebDriverAgent failed to build"), "\(failed)")
        XCTAssertTrue("\(failed)".contains("/tmp/r.log"), "\(failed)")
        let timedOut = RunnerStartCommand.wdaStartupError(nil, logPath: nil)
        XCTAssertTrue("\(timedOut)".contains("Timed out waiting for WDA"), "\(timedOut)")
    }

    func testForegroundPortDiscoveryTimesOutWhenRunnerIsSilent() async {
        let pipe = Pipe()
        defer { try? pipe.fileHandleForWriting.close() }
        let stream = RunnerStartCommand.outputStream(from: pipe.fileHandleForReading)

        let port = await RunnerStartCommand.waitForForegroundWDAPort(
            chunks: stream,
            timeout: { _ in },
            probe: { XCTFail("Silent output must not trigger probing"); return nil }
        )

        XCTAssertNil(port)
    }

    func testForegroundPortDiscoveryProbesAfterLaunchCompletes() async {
        let (stream, continuation) = AsyncStream<Data>.makeStream()
        continuation.yield(Data("launchApp completed ✓\n".utf8))
        continuation.finish()

        let port = await RunnerStartCommand.waitForForegroundWDAPort(
            chunks: stream,
            timeout: { _ in try? await Task.sleep(for: .seconds(5)) },
            probe: { 8200 }
        )

        XCTAssertEqual(port, .port(8200))
    }

    func testForegroundPortDiscoveryStopsOnAFailedBuild() async {
        let (stream, continuation) = AsyncStream<Data>.makeStream()
        continuation.yield(Data("[wda] WDA build failed: xcodebuild failed: exit status 65\n".utf8))
        // Never finished: a failed build must not wait for the timeout.

        let startup = await RunnerStartCommand.waitForForegroundWDAPort(
            chunks: stream,
            timeout: { _ in try? await Task.sleep(for: .seconds(5)) },
            probe: { XCTFail("A failed build must not probe"); return nil }
        )

        XCTAssertEqual(startup, .buildFailed)
        continuation.finish()
    }

    func testForegroundTimeoutLearnsThatWDAIsBeingBuilt() async {
        let (stream, continuation) = AsyncStream<Data>.makeStream()
        let sawBuild = LockedValue<Bool?>(nil)
        continuation.yield(Data("[wda] Building WDA for device B27D7D31\n".utf8))

        let startup = await RunnerStartCommand.waitForForegroundWDAPort(
            chunks: stream,
            timeout: { isBuilding in
                // Give the reader a moment to consume the chunk, as the real
                // 60 s sleep would.
                try? await Task.sleep(for: .milliseconds(200))
                sawBuild.set(isBuilding())
            },
            probe: { nil }
        )

        XCTAssertNil(startup)
        XCTAssertEqual(sawBuild.value, true)
        continuation.finish()
    }

    func testStartTerminatesSpawnedProcessWhenSessionCannotBeRecorded() {
        let session = makeSession()
        let terminated = LockedValue<Int32?>(nil)
        XCTAssertThrowsError(try RunnerStartCommand.record(
            session: session,
            write: { _ in throw CocoaError(.fileWriteNoPermission) },
            terminate: { terminated.set($0) }
        ))
        XCTAssertEqual(terminated.value, session.pid)
    }

    func testStopTerminatesOwnedRunnerThenRemovesMetadata() async throws {
        let events = LockedValue<[String]>([])
        let session = makeSession()
        let dependencies = dependencies(session: session, events: events, snapshot: "\(session.pid) 1 /tmp/grantiva-runner --device X")
        _ = try await RunnerStopCommand.parse([]).perform(dependencies: dependencies)
        XCTAssertEqual(events.value, ["snapshot", "terminate", "files 1234", "remove", "owner", "release"])
    }

    func testStopCleansStaleReusedPIDWithoutSignallingIt() async throws {
        let events = LockedValue<[String]>([])
        let session = makeSession()
        let dependencies = dependencies(session: session, events: events, snapshot: "\(session.pid) 1 /usr/bin/unrelated")
        _ = try await RunnerStopCommand.parse([]).perform(dependencies: dependencies)
        XCTAssertEqual(events.value, ["snapshot", "files 1234", "remove", "owner", "release"])
    }

    func testSnapshotFailurePreservesSessionAndLease() async {
        let events = LockedValue<[String]>([])
        let session = makeSession()
        var dependencies = dependencies(session: session, events: events, snapshot: "")
        dependencies.processSnapshot = {
            events.append("snapshot")
            throw GrantivaError.commandFailed("ps failed", 1)
        }
        do {
            _ = try await RunnerStopCommand.parse([]).perform(dependencies: dependencies)
            XCTFail("expected failure")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("ps failed"))
        }
        XCTAssertEqual(events.value, ["snapshot"])
    }

    func testDeadSessionIsCleanedWithoutSnapshotOrSignal() async throws {
        let events = LockedValue<[String]>([])
        let session = makeSession()
        var dependencies = dependencies(session: session, events: events, snapshot: "")
        dependencies.isAlive = { _ in false }
        _ = try await RunnerStopCommand.parse([]).perform(dependencies: dependencies)
        XCTAssertEqual(events.value, ["files 1234", "remove", "owner", "release"])
    }

    func testStopOnAnAndroidSessionCleansOrphansAfterTerminating() async throws {
        let events = LockedValue<[String]>([])
        let session = makeSession(udid: "emulator-5554")
        let dependencies = dependencies(session: session, events: events, snapshot: "\(session.pid) 1 /tmp/grantiva-runner --device emulator-5554")
        _ = try await RunnerStopCommand.parse([]).perform(dependencies: dependencies)
        XCTAssertEqual(events.value, ["snapshot", "terminate", "files 1234", "orphans", "remove", "owner", "release"])
    }

    func testRunnerArgumentsHoldTheSessionWithKeepAliveOnBothPlatforms() {
        let ios = RunnerStartCommand.runnerArguments(platform: IOSPlatform(), deviceID: "921A0945-7157-4533-BA1F-21E8132D3E40", flowPath: "/tmp/f.yaml")
        XCTAssertEqual(ios, [
            "--platform", "ios", "--device", "921A0945-7157-4533-BA1F-21E8132D3E40", "--no-ansi", "--no-app-install",
            "test", "--wait-for-idle-timeout", "0", "--keep-alive", "/tmp/f.yaml",
        ])
        let android = RunnerStartCommand.runnerArguments(platform: FakeDevicePlatform(platform: .android), deviceID: "emulator-5554", flowPath: "/tmp/f.yaml")
        XCTAssertEqual(android, ["--platform", "android", "--device", "emulator-5554", "test", "--keep-alive", "/tmp/f.yaml"])
    }

    func testAppIDAndTargetResolutionPerPlatform() throws {
        XCTAssertEqual(try RunnerStartCommand.appID(platform: .ios, bundleId: "a.b", applicationId: nil, config: nil), "a.b")
        XCTAssertEqual(try RunnerStartCommand.appID(platform: .ios, bundleId: nil, applicationId: nil, config: GrantivaConfig(bundleId: "c.d")), "c.d")
        XCTAssertThrowsError(try RunnerStartCommand.appID(platform: .ios, bundleId: nil, applicationId: nil, config: nil)) {
            XCTAssertTrue("\($0)".contains("--bundle-id"), "\($0)")
        }
        XCTAssertEqual(try RunnerStartCommand.appID(platform: .android, bundleId: nil, applicationId: "e.f", config: nil), "e.f")
        XCTAssertEqual(try RunnerStartCommand.appID(platform: .android, bundleId: nil, applicationId: nil,
                                                    config: GrantivaConfig(platform: .android, android: AndroidProject(applicationId: "g.h"))), "g.h")
        XCTAssertThrowsError(try RunnerStartCommand.appID(platform: .android, bundleId: nil, applicationId: nil, config: nil)) {
            XCTAssertTrue("\($0)".contains("--application-id"), "\($0)")
        }
        XCTAssertEqual(RunnerStartCommand.target(platform: .ios, simulator: nil, emulator: nil, device: nil, config: nil), DefaultSimulator.name)
        XCTAssertEqual(RunnerStartCommand.target(platform: .android, simulator: nil, emulator: "P", device: "emulator-5556", config: nil), "emulator-5556")
        XCTAssertEqual(RunnerStartCommand.target(platform: .android, simulator: nil, emulator: nil, device: nil, config: nil), "")
    }

    func testWaitForUIAutomator2RetriesUntilAttachSucceeds() async {
        let attempts = LockedValue(0)
        let attachment = await RunnerStartCommand.waitForUIAutomator2(
            attach: {
                attempts.set(attempts.value + 1)
                if attempts.value < 3 { throw GrantivaError.invalidArgument("not yet") }
                return DriverAttachment(client: .failing, port: 61211, detach: {})
            },
            timeout: 5,
            sleep: {}
        )
        XCTAssertEqual(attachment?.port, 61211)
        XCTAssertEqual(attempts.value, 3)
    }

    func testWaitForUIAutomator2GivesUpAtTheTimeout() async {
        let attachment = await RunnerStartCommand.waitForUIAutomator2(
            attach: { throw GrantivaError.invalidArgument("never") },
            timeout: 0,
            sleep: {}
        )
        XCTAssertNil(attachment)
    }

    // MARK: - K88: `runner stop` on a session whose runner already exited

    func testStopOfADeadRunnerSaysItHadExited() async throws {
        let events = LockedValue<[String]>([])
        var dependencies = dependencies(session: makeSession(), events: events, snapshot: "")
        dependencies.isAlive = { _ in false }
        let result = try await RunnerStopCommand.parse([]).perform(dependencies: dependencies)
        XCTAssertEqual(result, .exited(pid: 1234))
        XCTAssertEqual(RunnerStopCommand.render(result), "No running runner (pid 1234 had exited); cleaned up its session.")
    }

    // MARK: - K87: SIGKILL escalation still removes the runner's session file

    func testStopOfARunnerThatIgnoresSIGINTRemovesItsSessionFileAndSaysItKilled() async throws {
        let events = LockedValue<[String]>([])
        let session = makeSession()
        var dependencies = dependencies(session: session, events: events, snapshot: "\(session.pid) 1 /tmp/grantiva-runner --device X")
        dependencies.terminateGroup = { _ in events.append("terminate"); return .killed }
        let result = try await RunnerStopCommand.parse([]).perform(dependencies: dependencies)
        XCTAssertEqual(result, .stopped(pid: 1234, udid: session.udid, killed: true))
        XCTAssertTrue(events.value.contains("files 1234"), "\(events.value)")
        XCTAssertEqual(RunnerStopCommand.render(result), "Runner stopped (pid 1234; it ignored SIGINT and SIGTERM and was killed)")
    }

    // MARK: - K14: `runner stop` finds a `run --keep-alive` session

    func testStopReleasesAKeepAliveSessionFromThisDirectory() async throws {
        let events = LockedValue<[String]>([])
        let keepAlive = KeepAliveSession(
            sessionId: "s", port: 8100, pid: 4267, udid: makeSession().udid, path: "/tmp/grantiva-sessions/4267-1.grantiva",
            projectDirectory: "/private/tmp/project", platform: .ios, ownerPid: 4163, detached: false
        )
        var dependencies = dependencies(session: makeSession(), events: events, snapshot: "")
        dependencies.loadSession = { throw CocoaError(.fileNoSuchFile) }
        dependencies.keepAliveSessions = { [keepAlive] }
        dependencies.stopKeepAlive = { session in
            events.append("stop \(session.pid)")
            return .released(grantivaPid: 4163, runnerPid: 4267, udid: session.udid ?? "")
        }
        let result = try await RunnerStopCommand.parse([]).perform(dependencies: dependencies)
        XCTAssertEqual(events.value, ["stop 4267"])
        XCTAssertEqual(result, .keepAlive(.released(grantivaPid: 4163, runnerPid: 4267, udid: keepAlive.udid!)))
        XCTAssertEqual(
            RunnerStopCommand.render(result),
            "Stopped keep-alive session (pid 4163, \(keepAlive.udid!))"
        )
        let json = try decode(RunnerStopCommand.document(result))
        XCTAssertEqual(json["status"] as? String, "stopped")
        XCTAssertEqual(json["pid"] as? Int, 4163)
        XCTAssertEqual(json["runnerPid"] as? Int, 4267)
    }

    func testStopLeavesAKeepAliveSessionFromAnotherDirectoryAlone() async throws {
        let events = LockedValue<[String]>([])
        let keepAlive = KeepAliveSession(
            sessionId: "s", port: 8100, pid: 4267, udid: makeSession().udid, path: "/x",
            projectDirectory: "/private/tmp/elsewhere", platform: .ios, ownerPid: 4163, detached: false
        )
        var dependencies = dependencies(session: makeSession(), events: events, snapshot: "")
        dependencies.loadSession = { throw CocoaError(.fileNoSuchFile) }
        dependencies.keepAliveSessions = { [keepAlive] }
        let result = try await RunnerStopCommand.parse([]).perform(dependencies: dependencies)
        XCTAssertEqual(result, .notRunning)
        XCTAssertEqual(events.value, [])
        XCTAssertEqual(try decode(RunnerStopCommand.document(result))["status"] as? String, "not_running")
    }

    func testStopWithNoSessionAtAllKeepsTheNote() async throws {
        let events = LockedValue<[String]>([])
        var dependencies = dependencies(session: makeSession(), events: events, snapshot: "")
        dependencies.loadSession = { throw CocoaError(.fileNoSuchFile) }
        let result = try await RunnerStopCommand.parse([]).perform(dependencies: dependencies)
        XCTAssertEqual(result, .notRunning)
        XCTAssertEqual(RunnerStopCommand.render(result), "No active session found.")
    }

    func testStopHelpSaysItReleasesKeepAliveSessions() {
        let help = RunnerStopCommand.helpMessage(columns: 1000)
        XCTAssertTrue(help.contains("grantiva run --keep-alive"), help)
        XCTAssertTrue(help.contains("SIGINT"), help)
    }

    // MARK: - K16: numbers for pid and port, platform-neutral keys

    func testStartDocumentsUseNumbersAndThePlatformsKeys() throws {
        let ios = try decode(RunnerStartCommand.document(
            status: "started", pid: 64253, port: 8235, appID: "com.example", deviceID: "921A0945-7157-4533-BA1F-21E8132D3E40",
            platform: .ios, log: "/tmp/r.log"
        ))
        XCTAssertEqual(ios["pid"] as? Int, 64253)
        XCTAssertFalse(ios["pid"] is String)
        XCTAssertEqual(ios["port"] as? Int, 8235)
        XCTAssertFalse(ios["port"] is String)
        XCTAssertEqual(ios["bundleId"] as? String, "com.example")
        XCTAssertEqual(ios["udid"] as? String, "921A0945-7157-4533-BA1F-21E8132D3E40")
        XCTAssertEqual(ios["platform"] as? String, "ios")
        XCTAssertNil(ios["applicationId"])
        XCTAssertNil(ios["serial"])

        let android = try decode(RunnerStartCommand.document(
            status: "already_running", pid: 7067, port: 57776, appID: "com.example", deviceID: "emulator-5554",
            platform: .android, log: nil
        ))
        XCTAssertEqual(android["pid"] as? Int, 7067)
        XCTAssertEqual(android["port"] as? Int, 57776)
        XCTAssertEqual(android["applicationId"] as? String, "com.example")
        XCTAssertEqual(android["serial"] as? String, "emulator-5554")
        XCTAssertEqual(android["platform"] as? String, "android")
        XCTAssertNil(android["bundleId"])
        XCTAssertNil(android["log"])
    }

    func testStopDocumentUsesTheSameKeys() throws {
        let result = RunnerStopCommand.Result.stopped(pid: 6630, udid: "emulator-5554", killed: false)
        let json = try decode(RunnerStopCommand.document(result))
        XCTAssertEqual(json["status"] as? String, "stopped")
        XCTAssertEqual(json["pid"] as? Int, 6630)
        XCTAssertFalse(json["pid"] is String)
        XCTAssertEqual(json["serial"] as? String, "emulator-5554")
        XCTAssertEqual(json["platform"] as? String, "android")
    }

    // MARK: - K88: foreground `runner start` stays attached

    func testForegroundHoldWaitsForTheRunnerThenCleansUp() async throws {
        let (exits, exit) = AsyncStream<Int32>.makeStream()
        let cleaned = LockedValue(0)
        let held = Task {
            await RunnerStartCommand.holdForeground(
                waitForExit: { for await status in exits { return status }; return 0 },
                onInterrupt: { _ in 1 }, removeInterruptHandler: { _ in },
                cleanup: { cleaned.set(cleaned.value + 1) }
            )
        }
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(cleaned.value, 0, "returned before the runner exited")
        exit.yield(0)
        let status = await held.value
        XCTAssertEqual(status, 0)
        XCTAssertEqual(cleaned.value, 1)
    }

    func testForegroundHoldCleansUpOnceOnInterrupt() async throws {
        let (exits, exit) = AsyncStream<Int32>.makeStream()
        let cleaned = LockedValue(0)
        let handler = LockedValue<(@Sendable () -> Void)?>(nil)
        let removed = LockedValue<[UInt64]>([])
        let held = Task {
            await RunnerStartCommand.holdForeground(
                waitForExit: { for await status in exits { return status }; return 0 },
                onInterrupt: { body in handler.set(body); return 7 },
                removeInterruptHandler: { removed.append($0) },
                cleanup: { cleaned.set(cleaned.value + 1) }
            )
        }
        try await Task.sleep(for: .milliseconds(200))
        let interrupt = try XCTUnwrap(handler.value)
        interrupt()
        XCTAssertEqual(cleaned.value, 1)
        exit.yield(Int32(SIGINT))
        _ = await held.value
        XCTAssertEqual(cleaned.value, 1, "cleanup must run once")
        XCTAssertEqual(removed.value, [7])
    }

    func testForegroundStartHelpSaysItStaysAttached() {
        let help = RunnerStartCommand.helpMessage(columns: 1000)
        XCTAssertTrue(help.contains("Ctrl-C"), help)
        XCTAssertTrue(help.contains("130"), help)
    }

    // MARK: - K61: help names both drivers

    func testRunnerStartAbstractNamesBothDriversAndMatchesTheREADME() throws {
        let abstract = "Start the runner with WDA (UIAutomator2 on Android) and keep it alive for interactive use."
        XCTAssertEqual(RunnerStartCommand.configuration.abstract, abstract)
        let readme = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("README.md")
        let text = try String(contentsOf: readme, encoding: .utf8)
        XCTAssertTrue(text.contains("grantiva runner start       \(abstract.dropLast())\n"), "README's runner start line drifted from the abstract")
        XCTAssertTrue(RunnerCommand.helpMessage(columns: 1000).contains("UIAutomator2 on Android"))
    }

    func testDumpHierarchyPortHelpNamesBothDrivers() {
        let help = DumpHierarchyCommand.helpMessage(columns: 1000)
        XCTAssertTrue(help.contains("Driver port: WDA on iOS, the forwarded UIAutomator2 port on Android"), help)
    }

    func testHierarchyTimeoutHelpNamesBothDrivers() {
        let help = HierarchyCommand.helpMessage(columns: 1000)
        XCTAssertTrue(help.contains("GrantivaAgent's (iOS) or UIAutomator2's (Android) page-source response"), help)
    }

    func testAppFileHelpNamesTheAPK() {
        for help in [RunCommand.helpMessage(columns: 1000), InstallCommand.helpMessage(columns: 1000)] {
            XCTAssertTrue(help.contains("Path to a pre-built app: .app bundle or .ipa archive (iOS), .apk (Android). Skips the build step."), help)
        }
        XCTAssertTrue(RunCommand.helpMessage(columns: 1000).contains("UIAutomator2 on Android"))
    }

    private func decode<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = Data(try JSONOutput.string(value).utf8)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func makeSession(udid: String = "921A0945-7157-4533-BA1F-21E8132D3E40") -> RunnerSessionInfo {
        RunnerSessionInfo(pid: 1234, wdaPort: 8430, bundleId: "com.example", udid: udid, startedAt: Date())
    }

    private func dependencies(session: RunnerSessionInfo, events: LockedValue<[String]>, snapshot: String) -> RunnerStopDependencies {
        RunnerStopDependencies(
            loadSession: { session }, isAlive: { _ in true },
            processSnapshot: { events.append("snapshot"); return snapshot },
            terminateGroup: { _ in events.append("terminate"); return .interrupted },
            removeSession: { events.append("remove") },
            releaseLease: { _ in events.append("release") },
            cleanupOrphans: { _ in events.append("orphans") },
            removeKeepAliveOwner: { _ in events.append("owner") },
            removeRunnerSessionFiles: { events.append("files \($0)") },
            keepAliveSessions: { [] },
            stopKeepAlive: { _ in XCTFail("no keep-alive session to stop"); throw GrantivaError.aborted },
            currentDirectory: { "/private/tmp/project" }
        )
    }
}

private final class LockedValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value
    init(_ value: Value) { storage = value }
    func set(_ value: Value) { lock.withLock { storage = value } }
    func append<Element>(_ value: Element) where Value == [Element] { lock.withLock { storage.append(value) } }
    var value: Value { lock.withLock { storage } }
}

/// K45: `runner install` narrates what happened.
@available(macOS 15, *)
final class RunnerInstallNarrationTests: XCTestCase {
    func testOnlyAnInstallThatExtractsSaysExtracting() async throws {
        let installed = LockedValue(false)
        let manager = RunnerManager(
            ensureAvailable: {},
            runnerPath: { "/rh/versions/v/grantiva-runner" },
            runnerDir: { "/rh/versions/v" },
            install: { willExtract in
                if installed.value { return false }
                willExtract()
                installed.set(true)
                return true
            }
        )
        let first = LockedValue<[String]>([])
        let firstResult = try await RunnerInstallCommand.install(manager: manager, note: { first.append($0) })
        XCTAssertEqual(first.value, ["Extracting runner..."])
        XCTAssertTrue(firstResult.extracted)
        XCTAssertEqual(RunnerInstallCommand.lines(firstResult).first, "Runner installed at /rh/versions/v/grantiva-runner")

        let second = LockedValue<[String]>([])
        let secondResult = try await RunnerInstallCommand.install(manager: manager, note: { second.append($0) })
        XCTAssertFalse(second.value.contains { $0.contains("Extracting") }, "\(second.value)")
        XCTAssertFalse(secondResult.extracted)
        XCTAssertEqual(RunnerInstallCommand.lines(secondResult).first, "Runner already installed at /rh/versions/v/grantiva-runner")

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(JSONOutput.string(secondResult).utf8)) as? [String: Any])
        XCTAssertEqual(json["extracted"] as? Bool, false)
        XCTAssertEqual(json["status"] as? String, "installed")
    }
}
