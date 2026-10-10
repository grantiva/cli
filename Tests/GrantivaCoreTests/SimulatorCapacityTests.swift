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
        XCTAssertEqual(try capacity.sessions(devices: releasedDevices).map(\.udid), [second.udid])
    }

    func testShutdownManagedSimulatorIsPruned() async throws {
        let capacity = SimulatorCapacity(directory: directory, maximum: 4, waitTimeout: 0)
        let booted = device(1, state: "Booted")
        _ = try await capacity.reserve(device: booted, devices: { [booted] })
        try capacity.activate(udid: booted.udid)

        let shutdown = device(1, state: "Shutdown")
        XCTAssertEqual(try capacity.sessions(devices: [shutdown]), [])
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
        XCTAssertEqual(try capacity.sessions(devices: [simulator]).count, 1)
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
