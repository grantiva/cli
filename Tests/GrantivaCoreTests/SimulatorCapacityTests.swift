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

    private func device(_ number: Int, state: String) -> SimulatorDevice {
        SimulatorDevice(
            name: "Simulator \(number)", udid: "SIM-\(number)", state: state,
            runtime: "iOS-27-0", isAvailable: true
        )
    }
}
