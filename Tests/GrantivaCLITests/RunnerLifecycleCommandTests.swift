import Foundation
import ArgumentParser
import XCTest
@testable import GrantivaCLI
import GrantivaCore

@available(macOS 15, *)
final class RunnerLifecycleCommandTests: XCTestCase {
    func testIOSPortDoesNotPublishReadyAfterFailedLaunchReport() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data(#"{"status":"failed","flows":[{"name":"launch","status":"failed"}]}"#.utf8)
            .write(to: directory.appendingPathComponent("report.json"))
        let result = await RunnerStartCommand.waitForIOSLaunchFlow(port: 8834, reportDir: directory.path, timeout: 0, sleep: {})
        XCTAssertNil(result.attachment, "A discovered WDA port cannot make a failed launch ready")
        XCTAssertTrue(result.launchFailed)
    }

    func testIOSPortWithoutCompletedLaunchReportStaysBounded() async {
        let result = await RunnerStartCommand.waitForIOSLaunchFlow(port: 8834, reportDir: nil, timeout: 0, sleep: {})
        XCTAssertNil(result.attachment)
        XCTAssertFalse(result.launchFailed)
    }

    func testIOSLaunchWaitUsesOnlyItsOwnCompletedReport() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let report = directory.appendingPathComponent("report.json")
        try Data(#"{"status":"running","flows":[{"name":"launch","status":"running"}]}"#.utf8).write(to: report)
        let polls = LockedValue(0)
        let result = await RunnerStartCommand.waitForIOSLaunchFlow(
            port: 8834, reportDir: directory.path, timeout: 1,
            sleep: {
                polls.set(polls.value + 1)
                try? Data(#"{"status":"passed","flows":[{"name":"launch","status":"passed"}]}"#.utf8).write(to: report, options: .atomic)
            }
        )
        XCTAssertEqual(polls.value, 1, "Running must remain starting until the report completes")
        XCTAssertEqual(result.attachment?.port, 8834)
        XCTAssertNil(result.exitStatus)
        XCTAssertFalse(result.launchFailed)
    }

    func testIOSLaunchWaitStopsOnRunnerDeathOrInterrupt() async {
        for status: Int32 in [137, 130] {
            let result = await RunnerStartCommand.waitForIOSLaunchFlow(
                port: 8834, reportDir: nil, timeout: 60, runnerExit: { status },
                sleep: { XCTFail("Dead runner must not consume the timeout") }
            )
            XCTAssertNil(result.attachment)
            XCTAssertEqual(result.exitStatus, status)
        }
    }

    func testIOSLaunchReportArgumentsAreFlatBeforeTheFlow() {
        let arguments = RunnerStartCommand.runnerArguments(
            platform: IOSPlatform(), deviceID: "owned-uuid", flowPath: "/tmp/start/session-flow.yaml",
            reportDir: "/tmp/start/report"
        )
        XCTAssertEqual(Array(arguments.suffix(5)), ["--keep-alive", "--output", "/tmp/start/report", "--flatten", "/tmp/start/session-flow.yaml"])
    }

    func testLaunchReportIsFlatAndOptionsPrecedeThePositionalFlow() {
        let arguments = RunnerStartCommand.runnerArguments(
            platform: FakeDevicePlatform(platform: .android), deviceID: "emulator-5554",
            flowPath: "/tmp/session-flow.yaml", reportDir: "/tmp/session-report"
        )
        XCTAssertEqual(Array(arguments.suffix(5)), ["--keep-alive", "--output", "/tmp/session-report", "--flatten", "/tmp/session-flow.yaml"])
    }

    func testFailedLaunchDoesNotPublishReadyAndReleasesItsForward() async {
        let detached = LockedValue(false)
        let result = await RunnerStartCommand.waitForUIAutomator2(
            attach: { DriverAttachment(client: .failing, port: 61211, sessionID: "new", detach: { detached.set(true) }) },
            timeout: 1, launchStatus: { "failed" }, sleep: {}
        )
        XCTAssertNil(result.attachment)
        XCTAssertTrue(result.launchFailed)
        XCTAssertTrue(detached.value)
    }

    func testUnfinishedLaunchStaysBoundedAndReleasesRejectedForwards() async {
        let detached = LockedValue(0)
        let result = await RunnerStartCommand.waitForUIAutomator2(
            attach: { DriverAttachment(client: .failing, port: 61211, sessionID: "new", detach: { detached.set(detached.value + 1) }) },
            timeout: 0, launchStatus: { nil }, sleep: {}
        )
        XCTAssertNil(result.attachment)
        XCTAssertFalse(result.launchFailed)
        XCTAssertEqual(detached.value, 1)
    }

    func testDriverAttachmentDoesNotPublishReadyBeforeLaunchSettles() async {
        let polls = LockedValue(0)
        let result = await RunnerStartCommand.waitForUIAutomator2(
            attach: { DriverAttachment(client: .failing, port: 61211, sessionID: "new", detach: {}) },
            timeout: 1,
            launchStatus: { polls.value >= 3 ? "passed" : nil },
            sleep: { polls.set(polls.value + 1) }
        )
        XCTAssertEqual(result.attachment?.sessionID, "new")
        XCTAssertGreaterThanOrEqual(polls.value, 3, "driver attachment alone is not app readiness")
    }

    func testConcurrentCleanupCallWaitsUntilSessionRemovalFinishes() {
        let started = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let firstReturned = DispatchSemaphore(value: 0)
        let secondEntered = DispatchSemaphore(value: 0)
        let secondReturned = DispatchSemaphore(value: 0)
        let removed = LockedValue(false)
        let cleanup = Once {
            started.signal()
            _ = release.wait(timeout: .now() + 2)
            removed.set(true)
        }
        DispatchQueue.global().async { cleanup.run(); firstReturned.signal() }
        XCTAssertEqual(started.wait(timeout: .now() + 1), .success)
        DispatchQueue.global().async {
            secondEntered.signal()
            cleanup.run()
            secondReturned.signal()
        }
        XCTAssertEqual(secondEntered.wait(timeout: .now() + 1), .success)
        XCTAssertEqual(secondReturned.wait(timeout: .now() + 0.05), .timedOut,
                       "the signal caller must not exit while foreground session removal is still running")
        release.signal()
        XCTAssertEqual(firstReturned.wait(timeout: .now() + 1), .success)
        XCTAssertTrue(removed.value)
        cleanup.run()
    }

    func testStartupInterruptIsNotTranslatedToWDATimeoutInAnyOutputMode() async throws {
        for flags in [[], ["--quiet"], ["--json"]] {
            let command = try RunnerStartCommand.parse(flags)
            command.options.applyRunnerNarration()
            defer { SignalRelay.shared.resetTerminationForTesting(); RunnerNarration.isSilenced = false }
            let cleaned = LockedValue(false)
            let token = SignalRelay.shared.onTermination { cleaned.set(true) }
            defer { SignalRelay.shared.removeCleanup(token) }
            let result = await RunnerStartCommand.waitForForegroundWDAPort(
                chunks: AsyncStream { continuation in
                    SignalRelay.shared.simulateTerminationForTesting()
                    continuation.finish()
                }, timeout: { _ in try? await Task.sleep(for: .seconds(1)) }, probe: { nil }
            )
            let error = RunnerStartCommand.foregroundStartupError(result)
            XCTAssertEqual(error as? ExitCode, ExitCode(130), "\(flags): \(error)")
            XCTAssertTrue(cleaned.value)
        }
        XCTAssertTrue(RunnerStartCommand.foregroundStartupError(nil).localizedDescription.contains("Timed out"))
    }

    func testAlreadyStartingDocumentsPreserveNullPortOnBothPlatforms() throws {
        for platform: Platform in [.ios, .android] {
            let json = try decode(RunnerLifecycleDocument(
                status: "already_running", pid: 123, port: nil, appID: "com.example",
                deviceID: platform == .ios ? "IOS" : "emulator-5554", platform: platform
            ))
            XCTAssertTrue(json["port"] is NSNull, "\(json)")
            XCTAssertEqual(json["pid"] as? Int, 123)
        }
    }

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
        let stream = Self.outputStream(from: pipe.fileHandleForReading)

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
        XCTAssertEqual(events.value, ["snapshot", "remove", "terminate", "files 1234", "owner", "release"])
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
        XCTAssertEqual(events.value, ["snapshot", "remove", "terminate", "files 1234", "orphans 8430", "owner", "release"])
    }

    func testStopOnAStartingAndroidSessionHasNoOwnedForwardToRemove() async throws {
        let events = LockedValue<[String]>([])
        let session = RunnerSessionInfo.starting(
            pid: 1234, bundleId: "com.example", udid: "emulator-5554",
            startedAt: Date(), platform: .android
        )
        let dependencies = dependencies(
            session: session, events: events,
            snapshot: "\(session.pid) 1 /tmp/grantiva-runner --device emulator-5554"
        )

        _ = try await RunnerStopCommand.parse([]).perform(dependencies: dependencies)

        XCTAssertEqual(events.value, ["snapshot", "remove", "terminate", "files 1234", "orphans -", "owner", "release"])
    }

    func testStopOnIOSNeverRequestsAndroidOrphanCleanup() async throws {
        let events = LockedValue<[String]>([])
        let session = makeSession()
        let dependencies = dependencies(
            session: session, events: events,
            snapshot: "\(session.pid) 1 /tmp/grantiva-runner --device \(session.udid)"
        )

        _ = try await RunnerStopCommand.parse([]).perform(dependencies: dependencies)

        XCTAssertFalse(events.value.contains(where: { $0.hasPrefix("orphans") }), "\(events.value)")
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
        XCTAssertEqual(attachment.attachment?.port, 61211)
        XCTAssertEqual(attempts.value, 3)
    }

    func testWaitForUIAutomator2GivesUpAtTheTimeout() async {
        let attachment = await RunnerStartCommand.waitForUIAutomator2(
            attach: { throw GrantivaError.invalidArgument("never") },
            timeout: 0,
            sleep: {}
        )
        XCTAssertNil(attachment.attachment)
        XCTAssertNil(attachment.exitStatus)
    }

    // MARK: - K88: `runner stop` on a session whose runner already exited

    func testStopOfADeadRunnerSaysItHadExited() async throws {
        let events = LockedValue<[String]>([])
        var dependencies = dependencies(session: makeSession(), events: events, snapshot: "")
        dependencies.isAlive = { _ in false }
        let result = try await RunnerStopCommand.parse([]).perform(dependencies: dependencies)
        XCTAssertEqual(result, .exited(pid: 1234, udid: makeSession().udid, details: .init(port: 8430, appID: "com.example")))
        XCTAssertEqual(RunnerStopCommand.render(result), "No running runner (pid 1234 had exited); cleaned up its session.")
        // Ruling (c): still `stopped`, flagged, with the platform's keys.
        let json = try decode(RunnerStopCommand.document(result))
        XCTAssertEqual(json["status"] as? String, "stopped")
        XCTAssertEqual(json["alreadyExited"] as? Bool, true)
        XCTAssertEqual(json["runnerPid"] as? Int, 1234)
        XCTAssertEqual(json["pid"] as? Int, 1234)
        XCTAssertEqual(json["platform"] as? String, "ios")
        XCTAssertEqual(json["udid"] as? String, makeSession().udid)

        let android = try decode(RunnerStopCommand.document(.exited(pid: 9, udid: "emulator-5554")))
        XCTAssertEqual(android["serial"] as? String, "emulator-5554")
        XCTAssertEqual(android["platform"] as? String, "android")
    }

    // MARK: - K87: SIGKILL escalation still removes the runner's session file

    func testStopOfARunnerThatIgnoresSIGINTRemovesItsSessionFileAndSaysItKilled() async throws {
        let events = LockedValue<[String]>([])
        let session = makeSession()
        var dependencies = dependencies(session: session, events: events, snapshot: "\(session.pid) 1 /tmp/grantiva-runner --device X")
        dependencies.terminateGroup = { _ in events.append("terminate"); return .killed }
        let result = try await RunnerStopCommand.parse([]).perform(dependencies: dependencies)
        XCTAssertEqual(result, .stopped(pid: 1234, udid: session.udid, killed: true, details: .init(port: 8430, appID: "com.example")))
        XCTAssertTrue(events.value.contains("files 1234"), "\(events.value)")
        XCTAssertEqual(RunnerStopCommand.render(result), "Runner stopped (pid 1234; it ignored SIGINT and SIGTERM and was killed)")
    }

    // MARK: - L04: `runner stop` ends the helpers its runner started

    /// After `terminateGroup` returns `.interrupted`, the process table still
    /// lists the `simctl diagnose` WebDriverAgent's xcodebuild started for the
    /// device in a group of its own: stop reaps it, waits, and reports it.
    func testStopReapsTheDiagnoseTheRunnersXcodebuildLeftAndReportsIt() async throws {
        let events = LockedValue<[String]>([])
        let session = makeSession()
        let udid = session.udid
        let runner = "1234     1  1234 /tmp/grantiva-runner --platform ios --device \(udid) --no-ansi server"
        let xcodebuild = "1240  1234  1234 /usr/bin/xcodebuild test-without-building -destination id=\(udid)"
        let diagnose = "/Library/Developer/PrivateFrameworks/CoreSimulator.framework/Versions/A/Resources/bin/simctl diagnose -l -b --timeout=600 --output=/elsewhere/simctl_diagnostics --no-archive --udid=\(udid)"
        let table = LockedValue("\(runner)\n\(xcodebuild)")
        let signals = LockedValue<[String]>([])
        let alive = LockedValue<Set<Int32>>([1250])

        var dependencies = dependencies(session: session, events: events, snapshot: "1234 1234 /tmp/grantiva-runner --device \(udid)")
        dependencies.terminateGroup = { _ in
            events.append("terminate")
            table.set("1240     1  1234 /usr/bin/xcodebuild test-without-building -destination id=\(udid)\n1250  1240  1250 \(diagnose)")
            usleep(200_000)
            table.set("1250     1  1250 \(diagnose)")
            return .interrupted
        }
        dependencies.helperReaper = RunnerHelperReaper(
            snapshot: { table.value },
            signal: { pid, signal in signals.append("\(signal) \(pid)"); alive.set(alive.value.subtracting([abs(pid)])) },
            isAlive: { alive.value.contains($0) },
            runnerBases: [], gracePeriod: 0.5, pollInterval: .milliseconds(10)
        )

        let result = try await RunnerStopCommand.parse([]).perform(dependencies: dependencies)
        let reaped = ReapedProcess(pid: 1250, processGroup: 1250, kind: .diagnose, command: diagnose, killed: true)
        XCTAssertEqual(result, .stopped(pid: 1234, udid: udid, killed: false, reaped: [reaped], details: .init(port: 8430, appID: "com.example")))
        XCTAssertEqual(signals.value.first, "\(SIGINT) 1250")
        XCTAssertFalse(alive.value.contains(1250), "stop returned before the helper exited")

        let json = try decode(RunnerStopCommand.document(result))
        let list = try XCTUnwrap(json["reaped"] as? [[String: Any]])
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list.first?["kind"] as? String, "diagnose")
        XCTAssertEqual(list.first?["pid"] as? Int, 1250)
        XCTAssertEqual(list.first?["command"] as? String, diagnose)
        XCTAssertEqual(
            RunnerStopCommand.render(result),
            "Runner stopped (pid 1234)\nAlso stopped diagnose pid 1250, which the runner left running for \(udid)."
        )
    }

    func testStopReportsAnEmptyReapedListWhenTheRunnerLeftNothing() async throws {
        let result = RunnerStopCommand.Result.stopped(pid: 1234, udid: makeSession().udid, killed: false)
        let json = try decode(RunnerStopCommand.document(result))
        XCTAssertEqual((json["reaped"] as? [Any])?.count, 0)
        XCTAssertEqual(RunnerStopCommand.render(result), "Runner stopped (pid 1234)")
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
        XCTAssertEqual(result, .keepAlive([.released(grantivaPid: 4163, runnerPid: 4267, udid: keepAlive.udid!)], details: [4267: .init(port: 8100, appID: nil)]))
        XCTAssertEqual(
            RunnerStopCommand.render(result),
            "Stopped keep-alive session (pid 4163, \(keepAlive.udid!))"
        )
        let json = try decode(RunnerStopCommand.document(result))
        XCTAssertEqual(json["status"] as? String, "stopped")
        XCTAssertEqual(json["pid"] as? Int, 4163)
        XCTAssertEqual(json["runnerPid"] as? Int, 4267)
    }

    func testStopReleasesEveryKeepAliveSessionFromThisDirectory() async throws {
        let events = LockedValue<[String]>([])
        let sessions = [4267, 5267].map { pid in
            KeepAliveSession(
                sessionId: "s\(pid)", port: 8100, pid: Int32(pid), udid: makeSession().udid, path: "/x",
                projectDirectory: "/private/tmp/project", platform: .ios, ownerPid: Int32(pid - 100), detached: false
            )
        }
        var dependencies = dependencies(session: makeSession(), events: events, snapshot: "")
        dependencies.loadSession = { throw CocoaError(.fileNoSuchFile) }
        dependencies.keepAliveSessions = { sessions }
        dependencies.stopKeepAlive = { session in
            events.append("stop \(session.pid)")
            return .released(grantivaPid: session.ownerPid!, runnerPid: session.pid, udid: session.udid ?? "")
        }
        let result = try await RunnerStopCommand.parse([]).perform(dependencies: dependencies)
        XCTAssertEqual(events.value, ["stop 4267", "stop 5267"])
        XCTAssertEqual(RunnerStopCommand.render(result).split(separator: "\n").count, 2)
        let json = try decode(RunnerStopCommand.document(result))
        XCTAssertEqual((json["sessions"] as? [[String: Any]])?.compactMap { $0["runnerPid"] as? Int }, [4267, 5267])
    }

    /// L55: a `run --keep-alive` still in its flows has only its owner
    /// sidecar; `runner stop` releases it through its holder instead of
    /// saying "No active session found.", and --json gives `port: null`.
    func testStopReleasesAKeepAliveRunStillInItsFlows() async throws {
        let sessionsDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("grantiva-sessions-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sessionsDirectory) }
        let project = FileManager.default.temporaryDirectory.appendingPathComponent("grantiva-project-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: project) }
        let udid = makeSession().udid
        let owner = KeepAliveOwner(
            udid: udid, runnerPid: 4267, grantivaPid: 4163,
            projectDirectory: KeepAliveOwner.canonicalDirectory(project.path), platform: .ios, detached: false, appId: "com.example"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(owner).write(to: sessionsDirectory.appendingPathComponent("4267.owner.json"))
        let store = KeepAliveSessionStore(directory: sessionsDirectory.path, isProcessAlive: { [4267, 4163].contains($0) })

        let events = LockedValue<[String]>([])
        var dependencies = dependencies(session: makeSession(), events: events, snapshot: "")
        dependencies.loadSession = { throw CocoaError(.fileNoSuchFile) }
        dependencies.currentDirectory = { project.path }
        dependencies.keepAliveSessions = { RunnerStopDependencies.keepAliveSessions(in: store) }
        dependencies.stopKeepAlive = { session in
            events.append("stop \(session.pid) holder \(session.ownerPid ?? 0)")
            return .released(grantivaPid: session.ownerPid ?? 0, runnerPid: session.pid, udid: session.udid ?? "")
        }
        let result = try await RunnerStopCommand.parse([]).perform(dependencies: dependencies)
        XCTAssertEqual(events.value, ["stop 4267 holder 4163"])
        XCTAssertEqual(RunnerStopCommand.render(result), "Stopped keep-alive session (pid 4163, \(udid))")
        let json = try decode(RunnerStopCommand.document(result))
        XCTAssertEqual(json["status"] as? String, "stopped")
        XCTAssertTrue(json.keys.contains("port"))
        XCTAssertTrue(json["port"] is NSNull, "\(json)")
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
        let ios = try decode(RunnerLifecycleDocument(
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

        let android = try decode(RunnerLifecycleDocument(
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
        XCTAssertEqual(json["runnerPid"] as? Int, 6630)
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

    func testForegroundHoldRetainsAndReleasesItsDriverAttachmentExactlyOnce() async throws {
        for interrupted in [false, true] {
            let releases = LockedValue(0)
            let unrelatedReleases = LockedValue(0)
            let attachment = DriverAttachment(
                client: .failing, port: 61211, sessionID: "owned",
                detach: { releases.set(releases.value + 1) }
            )
            _ = DriverAttachment(
                client: .failing, port: 61212, sessionID: "unrelated",
                detach: { unrelatedReleases.set(unrelatedReleases.value + 1) }
            )
            let owned = ForegroundDriverAttachment()
            XCTAssertEqual(RunnerStartCommand.retainForegroundAttachment(attachment, in: owned), 61211)

            let (exits, exit) = AsyncStream<Int32>.makeStream()
            let handler = LockedValue<(@Sendable () -> Void)?>(nil)
            let held = Task {
                await RunnerStartCommand.holdForeground(
                    waitForExit: { for await status in exits { return status }; return 0 },
                    onInterrupt: { body in handler.set(body); return 7 },
                    removeInterruptHandler: { _ in },
                    cleanup: { owned.release() }
                )
            }

            while handler.value == nil { await Task.yield() }
            XCTAssertEqual(releases.value, 0, "the live session must retain its forward")
            if interrupted { handler.value?() }
            exit.yield(interrupted ? Int32(SIGINT) : 0)
            _ = await held.value
            XCTAssertEqual(releases.value, 1)
            owned.release()
            XCTAssertEqual(releases.value, 1, "foreground cleanup must release the attachment exactly once")
            XCTAssertEqual(unrelatedReleases.value, 0, "foreground cleanup must not release an attachment it does not own")
        }
    }

    func testForegroundCleanupBeforeTransferRejectsAndFinishesLateAttachmentBeforeReturning() throws {
        let owner = ForegroundDriverAttachment()
        let releaseRequested = DispatchSemaphore(value: 0)
        let detachStarted = DispatchSemaphore(value: 0)
        let (detachGate, allowDetach) = AsyncStream<Void>.makeStream()
        let retainReturned = DispatchSemaphore(value: 0)
        let releaseReturned = DispatchSemaphore(value: 0)
        let accepted = LockedValue<Bool?>(nil)
        let attachment = DriverAttachment(
            client: .failing, port: 61211, sessionID: "late",
            detach: {
                detachStarted.signal()
                for await _ in detachGate { break }
            }
        )

        DispatchQueue.global().async {
            owner.release(timeout: 2, onRequested: { releaseRequested.signal() })
            releaseReturned.signal()
        }
        XCTAssertEqual(releaseRequested.wait(timeout: .now() + 1), .success)
        DispatchQueue.global().async {
            accepted.set(owner.retain(attachment, timeout: 2))
            retainReturned.signal()
        }
        XCTAssertEqual(detachStarted.wait(timeout: .now() + 1), .success)
        XCTAssertEqual(retainReturned.wait(timeout: .now() + 0.05), .timedOut)
        XCTAssertEqual(releaseReturned.wait(timeout: .now() + 0.05), .timedOut,
                       "the signal cleanup must wait for the rejected attachment's detach")

        allowDetach.yield(())
        allowDetach.finish()
        XCTAssertEqual(retainReturned.wait(timeout: .now() + 1), .success)
        XCTAssertEqual(releaseReturned.wait(timeout: .now() + 1), .success)
        XCTAssertEqual(accepted.value, false)
    }

    func testForegroundCleanupWaitsForOwnedAttachmentDetach() throws {
        let owner = ForegroundDriverAttachment()
        let detachStarted = DispatchSemaphore(value: 0)
        let (detachGate, allowDetach) = AsyncStream<Void>.makeStream()
        let releaseReturned = DispatchSemaphore(value: 0)
        let attachment = DriverAttachment(
            client: .failing, port: 61211, sessionID: "owned",
            detach: {
                detachStarted.signal()
                for await _ in detachGate { break }
            }
        )
        XCTAssertTrue(owner.retain(attachment))

        DispatchQueue.global().async {
            owner.release(timeout: 2)
            releaseReturned.signal()
        }
        XCTAssertEqual(detachStarted.wait(timeout: .now() + 1), .success)
        XCTAssertEqual(releaseReturned.wait(timeout: .now() + 0.05), .timedOut,
                       "the signal cleanup must not return while owned detach is running")
        allowDetach.yield(())
        allowDetach.finish()
        XCTAssertEqual(releaseReturned.wait(timeout: .now() + 1), .success)
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

    // MARK: - L13: every stop document shares start's keys

    private static let startKeysIOS: Set<String> = ["status", "pid", "port", "platform", "bundleId", "bundle_id", "udid"]
    private static let startKeysAndroid: Set<String> = ["status", "pid", "port", "platform", "applicationId", "bundle_id", "udid", "serial"]
    private static let stopOnlyKeys: Set<String> = ["runnerPid", "killed", "reaped", "alreadyExited", "sessions"]

    private func assertStopShape(_ json: [String: Any], android: Bool, file: StaticString = #filePath, line: UInt = #line) {
        let keys = Set(json.keys)
        let start = android ? Self.startKeysAndroid : Self.startKeysIOS
        XCTAssertTrue(start.isSubset(of: keys), "missing \(start.subtracting(keys))", file: file, line: line)
        XCTAssertTrue(keys.subtracting(start).isSubset(of: Self.stopOnlyKeys), "undocumented \(keys.subtracting(start).subtracting(Self.stopOnlyKeys))", file: file, line: line)
        XCTAssertNotNil(json["killed"] as? Bool, "killed is on every stopped document", file: file, line: line)
        XCTAssertNotNil(json["runnerPid"], file: file, line: line)
        XCTAssertNotNil(json["reaped"], file: file, line: line)
    }

    func testEveryStopShapeCarriesStartsKeysOnBothPlatforms() throws {
        let iosUDID = makeSession().udid
        let details = RunnerStopCommand.SessionDetails(port: 8987, appID: "com.kylebrowning.Landmarks")
        let android = RunnerStopCommand.SessionDetails(port: 62621, appID: "com.kylebrowning.landmarks")
        let stopped = try decode(RunnerStopCommand.document(.stopped(pid: 1, udid: iosUDID, killed: false, details: details)))
        assertStopShape(stopped, android: false)
        XCTAssertEqual(stopped["port"] as? Int, 8987)
        XCTAssertEqual(stopped["bundleId"] as? String, "com.kylebrowning.Landmarks")
        XCTAssertEqual(stopped["killed"] as? Bool, false)

        let exited = try decode(RunnerStopCommand.document(.exited(pid: 2, udid: "emulator-5554", details: android)))
        assertStopShape(exited, android: true)
        XCTAssertEqual(exited["applicationId"] as? String, "com.kylebrowning.landmarks")
        XCTAssertEqual(exited["port"] as? Int, 62621)
        XCTAssertEqual(exited["alreadyExited"] as? Bool, true)

        let multi = try decode(RunnerStopCommand.document(.keepAlive(
            [
                .released(grantivaPid: 4163, runnerPid: 4267, udid: iosUDID),
                .terminated(runnerPid: 4300, udid: "emulator-5556", killed: true),
            ],
            details: [4267: details, 4300: android]
        )))
        assertStopShape(multi, android: false)
        let entries = try XCTUnwrap(multi["sessions"] as? [[String: Any]])
        assertStopShape(entries[0], android: false)
        assertStopShape(entries[1], android: true)
        XCTAssertEqual(entries[0]["killed"] as? Bool, false)
        XCTAssertEqual(entries[1]["killed"] as? Bool, true)
    }

    func testAStopWhoseSessionRecordedNoPortOrAppWritesNull() throws {
        let json = try decode(RunnerStopCommand.document(.stopped(pid: 1, udid: "emulator-5554", killed: false)))
        assertStopShape(json, android: true)
        XCTAssertTrue(json["port"] is NSNull)
        XCTAssertTrue(json["applicationId"] is NSNull)
    }

    func testStopCarriesThePortAndAppTheSessionFileRecorded() async throws {
        let events = LockedValue<[String]>([])
        let session = makeSession()
        let dependencies = dependencies(session: session, events: events, snapshot: "\(session.pid) 1 /tmp/grantiva-runner --device X")
        let result = try await RunnerStopCommand.parse([]).perform(dependencies: dependencies)
        let json = try decode(RunnerStopCommand.document(result))
        XCTAssertEqual(json["port"] as? Int, 8430)
        XCTAssertEqual(json["bundleId"] as? String, "com.example")
    }

    func testStopOfAKeepAliveSessionCarriesItsPortAndApp() async throws {
        let events = LockedValue<[String]>([])
        let keepAlive = KeepAliveSession(
            sessionId: "s", port: 8100, pid: 4267, udid: makeSession().udid, path: "/x",
            projectDirectory: "/private/tmp/project", platform: .ios, ownerPid: 4163, detached: false, appId: "com.example"
        )
        var dependencies = dependencies(session: makeSession(), events: events, snapshot: "")
        dependencies.loadSession = { throw CocoaError(.fileNoSuchFile) }
        dependencies.keepAliveSessions = { [keepAlive] }
        dependencies.stopKeepAlive = { _ in .released(grantivaPid: 4163, runnerPid: 4267, udid: keepAlive.udid!) }
        let json = try decode(RunnerStopCommand.document(try await RunnerStopCommand.parse([]).perform(dependencies: dependencies)))
        XCTAssertEqual(json["port"] as? Int, 8100)
        XCTAssertEqual(json["bundleId"] as? String, "com.example")
        XCTAssertEqual(json["killed"] as? Bool, false)
    }

    // MARK: - L36: `runner stop` of a foreground `runner start` is orderly

    func testStopRemovesTheSessionFileBeforeSignallingTheRunner() async throws {
        let events = LockedValue<[String]>([])
        let session = makeSession()
        let dependencies = dependencies(session: session, events: events, snapshot: "\(session.pid) 1 /tmp/grantiva-runner --device X")
        _ = try await RunnerStopCommand.parse([]).perform(dependencies: dependencies)
        XCTAssertEqual(events.value, ["snapshot", "remove", "terminate", "files 1234", "owner", "release"])
    }

    func testAForegroundRunnerThatExitsOneAfterARunnerStopEndsInOrder() throws {
        XCTAssertTrue(RunnerStartCommand.stopWasRequested(runnerPid: 1234, session: nil))
        XCTAssertTrue(RunnerStartCommand.stopWasRequested(runnerPid: 1234, session: RunnerSessionInfo(
            pid: 999, wdaPort: 1, bundleId: "b", udid: "emulator-5554", startedAt: Date()
        )))
        XCTAssertFalse(RunnerStartCommand.stopWasRequested(runnerPid: 1234, session: makeSession()))
        XCTAssertEqual(
            try RunnerStartCommand.foregroundEnding(status: 1, pid: 1234, stopRequested: true),
            "Runner stopped (pid 1234); the session has ended."
        )
    }

    func testAForegroundRunnerKilledUnpromptedFailsWhateverTheSignal() {
        for status in [SIGKILL, SIGTERM, SIGINT, 128 + SIGINT] {
            XCTAssertThrowsError(try RunnerStartCommand.foregroundEnding(status: status, pid: 1234, stopRequested: false), "status \(status)") {
                XCTAssertEqual($0.localizedDescription, "The runner exited with status \(status); the session has ended.")
            }
        }
        XCTAssertEqual(try? RunnerStartCommand.foregroundEnding(status: SIGKILL, pid: 1234, stopRequested: true),
                       "Runner stopped (pid 1234); the session has ended.")
    }

    /// L36 fix round 2: a foreground `runner start` in directory A torn down
    /// from directory B. B's teardown cannot touch A's session file, but its
    /// stop marker names the runner: the start ends in order.
    func testAForegroundStartTornDownFromAnotherDirectoryEndsInOrder() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("grantiva-stops-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let started: Int64 = 1_791_700_000
        let marker = RunnerStopMarker(directory: directory, startTime: { _ in started }, isProcessAlive: { _ in true })
        XCTAssertTrue(try marker.mark(runnerPid: 1234, ownerPid: 77))
        // A's session file still names the runner: no `runner stop` happened.
        let request = RunnerStartCommand.stopRequest(
            runnerPid: 1234, session: makeSession(), marked: marker.isMarked(runnerPid: 1234, runnerStartTime: started)
        )
        XCTAssertEqual(request, .teardown)
        XCTAssertEqual(
            try RunnerStartCommand.foregroundEnding(status: SIGTERM, pid: 1234, stop: request),
            "Runner stopped by teardown (pid 1234); the session has ended."
        )
    }

    func testAStaleStopMarkerDoesNotMakeARunnerDeathOrderly() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("grantiva-stops-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let marker = RunnerStopMarker(directory: directory, startTime: { _ in 1_791_600_000 }, isProcessAlive: { _ in true })
        XCTAssertTrue(try marker.mark(runnerPid: 1234, ownerPid: 77))
        let request = RunnerStartCommand.stopRequest(
            runnerPid: 1234, session: makeSession(), marked: marker.isMarked(runnerPid: 1234, runnerStartTime: 1_791_700_000)
        )
        XCTAssertNil(request)
        XCTAssertThrowsError(try RunnerStartCommand.foregroundEnding(status: SIGTERM, pid: 1234, stop: request))
    }

    func testAForegroundRunnerThatExitsOneUnpromptedStillFails() {
        XCTAssertThrowsError(try RunnerStartCommand.foregroundEnding(status: 1, pid: 1234, stopRequested: false)) {
            XCTAssertEqual($0.localizedDescription, "The runner exited with status 1; the session has ended.")
        }
        XCTAssertEqual(try? RunnerStartCommand.foregroundEnding(status: 0, pid: 1234, stopRequested: false),
                       "Runner stopped (pid 1234); the session has ended.")
    }

    // MARK: - L37: the interrupt notice names the emulator on Android

    func testTheForegroundSetUpForAnAndroidLaunchSaysEmulator() {
        let saved = SignalRelay.shared.deviceNoun
        defer {
            SignalRelay.shared.untrack(group: 999_997)
            SignalRelay.shared.deviceNoun = saved
        }
        RunnerStartCommand.trackRunner(group: 999_997, platform: .android)
        XCTAssertEqual(SignalRelay.shared.deviceNoun, "emulator")
        RunnerStartCommand.trackRunner(group: 999_997, platform: .ios)
        XCTAssertEqual(SignalRelay.shared.deviceNoun, "simulator")
    }

    // MARK: - L38-a: a starting session is reported as starting

    func testDumpHierarchyOnAStartingSessionSaysItIsStarting() {
        let starting = RunnerSessionInfo.starting(pid: 5, bundleId: "a.b", udid: "emulator-5554", startedAt: Date(), platform: .android)
        XCTAssertThrowsError(try DumpHierarchyCommand.resolveTarget(port: nil, runnerSession: starting, keepAlive: nil)) {
            XCTAssertEqual($0.localizedDescription, "The runner session is starting (UIAutomator2 has no session yet). Retry in a few seconds.")
        }
    }

    // MARK: - L38-b: a new runner never adopts an orphaned UIAutomator2 server

    /// The device still holds the session of a `kill -9`'d keep-alive run's
    /// server ("old") until the new runner restarts it: the wait skips "old"
    /// and returns the new runner's own session, without clearing anything.
    func testTheWaitSkipsTheSessionTheDeviceHeldBeforeTheRunnerStarted() async {
        let polls = LockedValue(0)
        let detached = LockedValue(0)
        let result = await RunnerStartCommand.waitForUIAutomator2(
            attach: {
                polls.set(polls.value + 1)
                let id = polls.value <= 3 ? "old" : "new"
                return DriverAttachment(client: .failing, port: 61000 + polls.value, sessionID: id, detach: { detached.set(detached.value + 1) })
            },
            timeout: 5,
            staleSessionID: "old",
            sleep: {}
        )
        XCTAssertEqual(result.attachment?.sessionID, "new")
        XCTAssertEqual(polls.value, 4)
        XCTAssertEqual(detached.value, 3, "each rejected attachment's forward is removed")
    }

    func testWithoutAStaleSessionTheFirstAttachmentIsTaken() async {
        let result = await RunnerStartCommand.waitForUIAutomator2(
            attach: { DriverAttachment(client: .failing, port: 61211, sessionID: "only", detach: {}) },
            timeout: 5, sleep: {}
        )
        XCTAssertEqual(result.attachment?.sessionID, "only")
    }

    func testTheStaleSessionIsReadWithoutClearingTheDevice() async {
        let ios = FakeDevicePlatform(platform: .ios)
        let none = await RunnerStartCommand.currentDriverSession(ios, deviceID: "6A186B51-AE17-4808-8EB3-11972382F715")
        XCTAssertNil(none)
        XCTAssertEqual(ios.calls, [], "nothing is probed on iOS")
        let android = FakeDevicePlatform(platform: .android)
        _ = await RunnerStartCommand.currentDriverSession(android, deviceID: "emulator-5558")
        XCTAssertFalse(android.calls.contains("cleanupOrphans"), "\(android.calls)")
    }

    // MARK: - L48: the wait scales with a raised driver start limit

    func testTheUIAutomator2WaitIsTwiceTheDriverLimitPlusThirtyWithA90SecondFloor() {
        let key = AndroidPlatform.driverStartTimeoutVariable
        XCTAssertEqual(RunnerStartCommand.uiAutomator2WaitTimeout(environment: [:]), 90)
        XCTAssertEqual(RunnerStartCommand.uiAutomator2WaitTimeout(environment: [key: "30"]), 90)
        XCTAssertEqual(RunnerStartCommand.uiAutomator2WaitTimeout(environment: [key: "45"]), 120)
        XCTAssertEqual(RunnerStartCommand.uiAutomator2WaitTimeout(environment: [key: "120"]), 270)
    }

    // MARK: - L48: the start wait ends when the runner dies

    func testWaitForUIAutomator2EndsAsSoonAsTheRunnerExits() async {
        let started = Date()
        let result = await RunnerStartCommand.waitForUIAutomator2(
            attach: { throw GrantivaError.invalidArgument("never") },
            timeout: 90,
            runnerExit: { Date().timeIntervalSince(started) > 1 ? 1 : nil },
            sleep: { try? await Task.sleep(for: .milliseconds(100)) }
        )
        XCTAssertEqual(result.exitStatus, 1)
        XCTAssertNil(result.attachment)
        XCTAssertLessThan(Date().timeIntervalSince(started), 2)
    }

    func testTheRunnersStartFailureIsReportedWithItsReason() {
        let log = """
          ⏳ Connecting to device emulator-5554...
          ✓ Connected to google sdk_gphone64_arm64 (SDK 35)
          ⏳ Starting UIAutomator2 server...
        Error: failed to create driver: start UIAutomator2: UIAutomator2 server not ready after 30s
        """
        let line = RunnerStartCommand.lastErrorLine(in: log)
        XCTAssertEqual(line, "Error: failed to create driver: start UIAutomator2: UIAutomator2 server not ready after 30s")
        XCTAssertEqual(
            RunnerStartCommand.startupExitError(serial: "emulator-5554", status: 1, lastError: line, logPath: "/tmp/r.log").localizedDescription,
            "The runner could not start UIAutomator2 on emulator-5554: UIAutomator2 server not ready after 30s. "
                + "Raise the limit with GRANTIVA_DRIVER_START_TIMEOUT=<seconds>. Log: /tmp/r.log"
        )
        XCTAssertEqual(
            RunnerStartCommand.startupExitError(serial: "emulator-5554", status: 2, lastError: nil, logPath: nil).localizedDescription,
            "The runner exited (status 2) before UIAutomator2 was up on emulator-5554."
        )
        // Progress lines are not a reason: a runner killed mid-start says how it ended.
        XCTAssertNil(RunnerStartCommand.lastErrorLine(in: "  ⏳ Connecting to device emulator-5558...\n"))
        XCTAssertEqual(
            RunnerStartCommand.startupExitError(serial: "emulator-5558", status: 9, signal: 9, lastError: nil, logPath: "/tmp/r.log").localizedDescription,
            "The runner was killed by SIGKILL before UIAutomator2 was up on emulator-5558. Log: /tmp/r.log"
        )
    }

    /// Convert process output into a cancellable stream. `availableData` blocks
    /// when called directly, which can otherwise prevent the startup timeout
    /// from ever firing for a silent or wedged runner.
    static func outputStream(from handle: FileHandle) -> AsyncStream<Data> {
        AsyncStream { continuation in
            handle.readabilityHandler = { readableHandle in
                let data = readableHandle.availableData
                if data.isEmpty {
                    readableHandle.readabilityHandler = nil
                    continuation.finish()
                } else {
                    continuation.yield(data)
                }
            }
            continuation.onTermination = { _ in
                handle.readabilityHandler = nil
                try? handle.close()
            }
        }
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
            cleanupOrphans: { _, port in events.append("orphans \(port.map(String.init) ?? "-")") },
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

/// Foreground `runner start` output goes through the narration choke point,
/// whole lines at a time.
@available(macOS 15, *)
final class RunnerOutputForwarderTests: XCTestCase {
    func testOutputIsNarratedLineByLineAndParsed() async throws {
        let narrated = LockedValue<[String]>([])
        let forwarder = RunnerOutputForwarder(narrate: { narrated.append($0) })
        let pipe = Pipe()
        forwarder.attachOutput(pipe.fileHandleForReading)
        let bytes = Array("WDA started successfully on port 8430 🙂\nnext".utf8)
        pipe.fileHandleForWriting.write(Data(bytes.prefix(41)))
        try await Task.sleep(for: .milliseconds(100))
        pipe.fileHandleForWriting.write(Data(bytes.dropFirst(41)))
        try pipe.fileHandleForWriting.close()
        var received = Data()
        for await chunk in forwarder.chunks { received.append(chunk) }
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(narrated.value.joined(), "WDA started successfully on port 8430 🙂\nnext\n")
        XCTAssertEqual(String(decoding: received, as: UTF8.self), "WDA started successfully on port 8430 🙂\nnext")
    }

    func testSilencedNarrationPrintsNothing() {
        XCTAssertTrue(RunnerNarration.shouldSilence(json: true, quiet: false, verbose: false))
        XCTAssertTrue(RunnerNarration.shouldSilence(json: false, quiet: true, verbose: false))
    }
}
