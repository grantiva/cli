import Foundation
import XCTest
@testable import GrantivaCore

final class SimulatorCapacityTests: XCTestCase {
    private var directory: String!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-capacity-tests-\(UUID().uuidString)").path
    }

    override func tearDownWithError() throws {
        if let directory { try? FileManager.default.removeItem(atPath: directory) }
    }

    func testStaleSnapshotPreservesTwinActivation() async throws {
        let capacity = SimulatorCapacity(directory: directory, waitTimeout: 0)
        let shutdown = device(1, state: "Shutdown")
        _ = try await capacity.reserve(device: shutdown, devices: { [shutdown] })
        let original = try XCTUnwrap(capacity.records(udid: shutdown.udid).first)
        let acquired = try await capacity.reserve(device: shutdown, devices: {
            let snapshot = [shutdown]
            try capacity.activate(udid: shutdown.udid, bootedByGrantiva: true)
            return snapshot
        })
        XCTAssertEqual(acquired.bootedByGrantiva, true)
        XCTAssertEqual(acquired.acquiredAt, original.acquiredAt)
        XCTAssertEqual(acquired.state, .active)
    }

    func testSessionListingPreservesActivationAfterShutdownOrMissingSnapshot() async throws {
        for missing in [false, true] {
            let capacity = SimulatorCapacity(directory: directory, waitTimeout: 0)
            let shutdown = device(1, state: "Shutdown")
            _ = try await capacity.reserve(device: shutdown, devices: { [shutdown] })
            let snapshot = try await capacity.snapshot(devices: {
                let captured = missing ? [] : [shutdown]
                try capacity.activate(udid: shutdown.udid, bootedByGrantiva: true)
                return captured
            })
            let records = try capacity.sessions(snapshot: snapshot)
            XCTAssertEqual(records.first?.bootedByGrantiva, true)
            XCTAssertEqual(records.first?.state, .active)
            // A fresh observation must still prune genuinely stale records.
            let fresh = try await capacity.snapshot(devices: { missing ? [] : [shutdown] })
            XCTAssertEqual(try capacity.sessions(snapshot: fresh), [])
        }
    }

    func testSessionListingPreservesReservationAddedDuringEnumeration() async throws {
        let capacity = SimulatorCapacity(directory: directory, waitTimeout: 0)
        let shutdown = device(1, state: "Shutdown")
        let snapshot = try await capacity.snapshot(devices: {
            _ = try await capacity.reserve(device: shutdown, devices: { [shutdown] })
            return []
        })
        XCTAssertEqual(try capacity.sessions(snapshot: snapshot).map(\.udid), [shutdown.udid])
    }

    func testFifthManagedSimulatorIsRejectedAtCapacity() async throws {
        let capacity = SimulatorCapacity(directory: directory, maximum: 4, waitTimeout: 0, pollInterval: 0.01)
        let devices = (1...5).map { device($0, state: "Booted") }

        for device in devices.prefix(4) {
            _ = try await capacity.reserve(device: device, devices: { devices })
            try capacity.activate(udid: device.udid)
        }

        do {
            _ = try await capacity.reserve(device: devices[4], devices: { devices })
            XCTFail("Expected the fifth simulator to be rejected")
        } catch {
            XCTAssertTrue(String(describing: error).contains("limit 4"))
        }
    }

    func testReleasedSlotCanBeReused() async throws {
        let capacity = SimulatorCapacity(directory: directory, maximum: 1, waitTimeout: 0, pollInterval: 0.01)
        let first = device(1, state: "Booted")
        let second = device(2, state: "Booted")
        let initialDevices = [first, second]

        _ = try await capacity.reserve(device: first, devices: { initialDevices })
        try capacity.activate(udid: first.udid)
        try capacity.remove(udid: first.udid)
        let releasedDevices = [device(1, state: "Shutdown"), second]

        _ = try await capacity.reserve(device: second, devices: { releasedDevices })
        try capacity.activate(udid: second.udid)
        let snapshot = try await capacity.snapshot(devices: { releasedDevices })
        XCTAssertEqual(try capacity.sessions(snapshot: snapshot).map(\.udid), [second.udid])
    }

    func testShutdownManagedSimulatorIsPruned() async throws {
        let capacity = SimulatorCapacity(directory: directory, maximum: 4, waitTimeout: 0)
        let booted = device(1, state: "Booted")
        _ = try await capacity.reserve(device: booted, devices: { [booted] })
        try capacity.activate(udid: booted.udid)

        let shutdown = device(1, state: "Shutdown")
        let snapshot = try await capacity.snapshot(devices: { [shutdown] })
        XCTAssertEqual(try capacity.sessions(snapshot: snapshot), [])
    }

    func testBootedPendingReservationWithDeadOwnerIsPruned() {
        let simulator = device(1, state: "Booted")
        var records = [ManagedSimulatorSession(
            udid: simulator.udid,
            name: simulator.name,
            sessionId: "abandoned",
            ownerPID: 4242,
            acquiredAt: Date(),
            state: .pending
        )]

        SimulatorCapacity.prune(&records, devices: [simulator], isProcessAlive: { _ in false })

        XCTAssertTrue(records.isEmpty)
    }

    // A run without GRANTIVA_SESSION_ID owns its record as `simulator:<udid>`.
    // Nothing will ever tear that session down by name, so once the run's
    // process is gone the record must not hold a slot forever.
    func testActiveSessionlessRecordWithDeadOwnerIsPruned() {
        let simulator = device(1, state: "Booted")
        var records = [record(simulator, sessionId: "simulator:\(simulator.udid)", pid: 4242)]

        SimulatorCapacity.prune(&records, devices: [simulator], isProcessAlive: { _ in false })

        XCTAssertTrue(records.isEmpty)
    }

    func testEphemeralSessionlessRecordWithDeadOwnerIsPruned() {
        let simulator = device(1, state: "Booted")
        var records = [record(simulator, sessionId: "simulator:\(simulator.udid)", pid: 4242, ephemeral: true)]

        SimulatorCapacity.prune(&records, devices: [simulator], isProcessAlive: { _ in false })

        XCTAssertTrue(records.isEmpty)
    }

    // `simulator ensure` exits right after booting. Its slot must last until
    // the device is shut down, or the cap and `teardown --udid` stop applying.
    func testDurableSessionlessRecordOutlivesItsOwnerWhileBooted() {
        let simulator = device(1, state: "Booted")
        var records = [record(simulator, sessionId: "simulator:\(simulator.udid)", pid: 4242, ephemeral: false)]

        SimulatorCapacity.prune(&records, devices: [simulator], isProcessAlive: { _ in false })
        XCTAssertEqual(records.count, 1)

        SimulatorCapacity.prune(&records, devices: [device(1, state: "Shutdown")], isProcessAlive: { _ in false })
        XCTAssertTrue(records.isEmpty)
    }

    func testRecordsWithoutTheNewFieldsStillDecode() throws {
        let legacy = #"[{"udid":"SIM-1","name":"Simulator 1","sessionId":"x","ownerPID":1,"acquiredAt":0,"state":"active"}]"#
        let records = try JSONDecoder().decode([ManagedSimulatorSession].self, from: Data(legacy.utf8))
        XCTAssertNil(records[0].bootedByGrantiva)
        XCTAssertNil(records[0].ephemeral)
    }

    func testActiveSessionlessRecordWithLiveOwnerIsKept() {
        let simulator = device(1, state: "Booted")
        var records = [record(simulator, sessionId: "simulator:\(simulator.udid)", pid: 4242)]

        SimulatorCapacity.prune(&records, devices: [simulator], isProcessAlive: { _ in true })

        XCTAssertEqual(records.count, 1)
    }

    // A named ticket session outlives the CLI process that booted its device.
    func testActiveNamedSessionRecordOutlivesItsOwnerProcess() {
        let simulator = device(1, state: "Booted")
        var records = [record(simulator, sessionId: "APP-652", pid: 4242)]

        SimulatorCapacity.prune(&records, devices: [simulator], isProcessAlive: { _ in false })

        XCTAssertEqual(records.count, 1)
    }

    func testSameSimulatorReusesItsSlot() async throws {
        let capacity = SimulatorCapacity(directory: directory, maximum: 1, waitTimeout: 0)
        let simulator = device(1, state: "Booted")
        let first = try await capacity.reserve(device: simulator, devices: { [simulator] })
        try capacity.activate(udid: simulator.udid)
        let second = try await capacity.reserve(device: simulator, devices: { [simulator] })

        XCTAssertEqual(first.udid, second.udid)
        let snapshot = try await capacity.snapshot(devices: { [simulator] })
        XCTAssertEqual(try capacity.sessions(snapshot: snapshot).count, 1)
    }

    func testWaiterAcquiresSlotAfterRelease() async throws {
        let capacity = SimulatorCapacity(directory: directory, maximum: 1, waitTimeout: 1, pollInterval: 0.01)
        let first = device(1, state: "Booted")
        let second = device(2, state: "Booted")
        let devices = [first, second]
        _ = try await capacity.reserve(device: first, devices: { devices })
        try capacity.activate(udid: first.udid)

        let waiter = Task {
            try await capacity.reserve(device: second, devices: { devices })
        }
        try await Task.sleep(for: .milliseconds(50))
        try capacity.remove(udid: first.udid)

        let acquired = try await waiter.value
        XCTAssertEqual(acquired.udid, second.udid)
    }

    // MARK: - K67: waiting on a twin is not a capacity wait

    func testAPendingRecordOfAnotherLiveProcessUnderTheLimitIsADeviceWait() async throws {
        // Long enough that the first poll reports its wait even on a loaded
        // host: a first pass slower than the timeout times out unreported.
        let capacity = SimulatorCapacity(directory: directory, maximum: 6, waitTimeout: 1, pollInterval: 0.01)
        let simulator = device(1, state: "Shutdown")
        let owner = capacity.sessionId ?? "simulator:\(simulator.udid)"
        let twin = ManagedSimulatorSession(
            udid: simulator.udid, name: simulator.name, sessionId: owner,
            ownerPID: 1, acquiredAt: Date(), state: .pending
        )
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode([twin]).write(to: URL(fileURLWithPath: "\(directory!)/sessions.json"))

        let waits = WaitLog()
        do {
            _ = try await capacity.reserve(device: simulator, devices: { [simulator] }) { wait, _ in waits.add(wait) }
            XCTFail("the twin never finished, so the wait times out")
        } catch {}

        let seen = waits.all
        XCTAssertFalse(seen.isEmpty)
        for wait in seen {
            guard case .deviceBusy(let holder) = wait else { return XCTFail("reported as \(wait)") }
            XCTAssertEqual(holder.ownerPID, 1)
        }
    }

    // MARK: - K70: the refusal says how to use or free the device

    func testForeignSessionRefusalNamesBothWaysOut() async throws {
        let capacity = SimulatorCapacity(directory: directory, maximum: 4, waitTimeout: 0)
        let simulator = device(1, state: "Booted")
        let foreign = record(simulator, sessionId: "cov-ios", pid: 1)
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode([foreign]).write(to: URL(fileURLWithPath: "\(directory!)/sessions.json"))

        do {
            _ = try await capacity.reserve(device: simulator, devices: { [simulator] })
            XCTFail("expected the foreign session to refuse the run")
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            XCTAssertTrue(message.contains("belongs to Grantiva session cov-ios"), message)
            XCTAssertTrue(message.contains("GRANTIVA_SESSION_ID=cov-ios"), message)
            XCTAssertTrue(message.contains("`grantiva simulator teardown --session-id cov-ios`"), message)
            XCTAssertFalse(message.contains("Teardown that session"), message)
        }
    }

    private func record(_ device: SimulatorDevice, sessionId: String, pid: Int32, ephemeral: Bool? = nil) -> ManagedSimulatorSession {
        ManagedSimulatorSession(
            udid: device.udid, name: device.name, sessionId: sessionId,
            ownerPID: pid, acquiredAt: Date(), state: .active, ephemeral: ephemeral
        )
    }

    private func device(_ number: Int, state: String) -> SimulatorDevice {
        SimulatorDevice(
            name: "Simulator \(number)", udid: "SIM-\(number)", state: state,
            runtime: "iOS-27-0", isAvailable: true
        )
    }
}

private final class WaitLog: @unchecked Sendable {
    private let lock = NSLock()
    private var waits: [SimulatorCapacity.Wait] = []
    var all: [SimulatorCapacity.Wait] { lock.withLock { waits } }
    func add(_ wait: SimulatorCapacity.Wait) { lock.withLock { waits.append(wait) } }
}
