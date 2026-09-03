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
            timeout: { try? await Task.sleep(for: .seconds(5)) },
            probe: { probed.set(true); return nil }
        )

        XCTAssertEqual(port, 8430)
        XCTAssertFalse(probed.value)
    }

    func testForegroundPortDiscoveryTimesOutWhenRunnerIsSilent() async {
        let pipe = Pipe()
        defer { try? pipe.fileHandleForWriting.close() }
        let stream = RunnerStartCommand.outputStream(from: pipe.fileHandleForReading)

        let port = await RunnerStartCommand.waitForForegroundWDAPort(
            chunks: stream,
            timeout: {},
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
            timeout: { try? await Task.sleep(for: .seconds(5)) },
            probe: { 8200 }
        )

        XCTAssertEqual(port, 8200)
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
        XCTAssertEqual(events.value, ["snapshot", "terminate", "remove", "release"])
    }

    func testStopCleansStaleReusedPIDWithoutSignallingIt() async throws {
        let events = LockedValue<[String]>([])
        let session = makeSession()
        let dependencies = dependencies(session: session, events: events, snapshot: "\(session.pid) 1 /usr/bin/unrelated")
        try await RunnerStopCommand.parse([]).run(dependencies: dependencies)
        XCTAssertEqual(events.value, ["snapshot", "remove", "release"])
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
        XCTAssertEqual(events.value, ["remove", "release"])
    }

    private func makeSession() -> RunnerSessionInfo {
        RunnerSessionInfo(pid: 1234, wdaPort: 8430, bundleId: "com.example", udid: "UDID", startedAt: Date())
    }

    private func dependencies(session: RunnerSessionInfo, events: LockedValue<[String]>, snapshot: String) -> RunnerStopDependencies {
        RunnerStopDependencies(
            loadSession: { session }, isAlive: { _ in true },
            processSnapshot: { events.append("snapshot"); return snapshot },
            terminateGroup: { _ in events.append("terminate") },
            removeSession: { events.append("remove") },
            releaseLease: { _ in events.append("release") }
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
