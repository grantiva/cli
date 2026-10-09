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
        try await RunnerStopCommand.parse([]).run(dependencies: dependencies)
        XCTAssertEqual(events.value, ["snapshot", "terminate", "remove", "owner", "release"])
    }

    func testStopCleansStaleReusedPIDWithoutSignallingIt() async throws {
        let events = LockedValue<[String]>([])
        let session = makeSession()
        let dependencies = dependencies(session: session, events: events, snapshot: "\(session.pid) 1 /usr/bin/unrelated")
        try await RunnerStopCommand.parse([]).run(dependencies: dependencies)
        XCTAssertEqual(events.value, ["snapshot", "remove", "owner", "release"])
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
            try await RunnerStopCommand.parse([]).run(dependencies: dependencies)
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
        try await RunnerStopCommand.parse([]).run(dependencies: dependencies)
        XCTAssertEqual(events.value, ["remove", "owner", "release"])
    }

    func testStopOnAnAndroidSessionCleansOrphansAfterTerminating() async throws {
        let events = LockedValue<[String]>([])
        let session = makeSession(udid: "emulator-5554")
        let dependencies = dependencies(session: session, events: events, snapshot: "\(session.pid) 1 /tmp/grantiva-runner --device emulator-5554")
        try await RunnerStopCommand.parse([]).run(dependencies: dependencies)
        XCTAssertEqual(events.value, ["snapshot", "terminate", "orphans", "remove", "owner", "release"])
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
        XCTAssertEqual(RunnerStartCommand.target(platform: .ios, simulator: nil, emulator: nil, device: nil, config: nil), "iPhone 16")
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

    private func makeSession(udid: String = "921A0945-7157-4533-BA1F-21E8132D3E40") -> RunnerSessionInfo {
        RunnerSessionInfo(pid: 1234, wdaPort: 8430, bundleId: "com.example", udid: udid, startedAt: Date())
    }

    private func dependencies(session: RunnerSessionInfo, events: LockedValue<[String]>, snapshot: String) -> RunnerStopDependencies {
        RunnerStopDependencies(
            loadSession: { session }, isAlive: { _ in true },
            processSnapshot: { events.append("snapshot"); return snapshot },
            terminateGroup: { _ in events.append("terminate") },
            removeSession: { events.append("remove") },
            releaseLease: { _ in events.append("release") },
            cleanupOrphans: { _ in events.append("orphans") },
            removeKeepAliveOwner: { _ in events.append("owner") }
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
