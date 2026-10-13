import Foundation
import XCTest
@testable import GrantivaCore

/// L08 in Core: the default-name path refuses a simulator Grantiva did not
/// create, before reserving a slot or booting; the capacity and created
/// ledgers are scoped by runner home. L21: runtimes and device types read as
/// names.
final class DefaultSimulatorOwnershipCoreTests: XCTestCase {
    private func makeManager(_ simctl: FakeSimctl) -> (SimulatorManager, SimulatorCapacity, SimulatorProvenance) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-l08-core-\(UUID().uuidString)").path
        addTeardownBlock { try? FileManager.default.removeItem(atPath: directory) }
        let capacity = SimulatorCapacity(directory: directory, maximum: 4, waitTimeout: 0, pollInterval: 0.01)
        let provenance = SimulatorProvenance(directory: directory)
        let manager = SimulatorManager(execute: simctl.execute, capacity: capacity, provenance: provenance, runnerHome: "\(directory)/runner")
        return (manager, capacity, provenance)
    }

    func testTheDefaultPathRefusesASimulatorTheUserCreated() async throws {
        for state in ["Shutdown", "Booted"] {
            let simctl = FakeSimctl(devices: [.init(name: "iPhone 18 Pro", udid: "USER-1", state: state, runtime: "iOS-26-0", type: FakeSimctl.iPhone17Pro)])
            let (manager, _, _) = makeManager(simctl)
            do {
                _ = try await manager.bootDefault(name: "iPhone 18 Pro", ephemeral: true)
                XCTFail("expected a refusal")
            } catch {
                XCTAssertEqual(
                    (error as? GrantivaError)?.errorDescription,
                    "Invalid argument: Simulator \"iPhone 18 Pro\" (USER-1) was not created by Grantiva. It has the default simulator's name, "
                        + "and Grantiva does not take a simulator you created as its default. Pass --simulator \"iPhone 18 Pro\" to use it anyway, "
                        + "or set simulator: in grantiva.yml (create one with grantiva simulator ensure --name \"Grantiva iPhone 18 Pro\")."
                )
            }
            XCTAssertFalse(simctl.commands.contains { $0.hasPrefix("xcrun simctl boot") }, "\(simctl.commands)")
            let sessions = try await manager.managedSessions()
            XCTAssertTrue(sessions.isEmpty, state)
        }
    }

    func testTheDefaultPathBootsASimulatorGrantivaCreated() async throws {
        let simctl = FakeSimctl(devices: [.init(name: "iPhone 18 Pro", udid: "OURS-1", state: "Shutdown", runtime: "iOS-26-0", type: FakeSimctl.iPhone17Pro)])
        let (manager, _, provenance) = makeManager(simctl)
        try provenance.register(udid: "OURS-1", name: "iPhone 18 Pro")
        let device = try await manager.bootDefault(name: "iPhone 18 Pro", ephemeral: true)
        XCTAssertEqual(device.udid, "OURS-1")
        XCTAssertTrue(simctl.commands.contains("xcrun simctl boot OURS-1"), "\(simctl.commands)")
    }

    func testResolveMarksOnlyAnUnnamedSimulatorAsTheDefault() async throws {
        let unnamed = try await ResolvedProject.resolve(schemeFlag: "S", bundleIdFlag: "com.x", config: nil, loadCache: { nil }, saveCache: { _ in })
        XCTAssertTrue(unnamed.simulatorIsDefault)
        XCTAssertEqual(unnamed.simulator, DefaultSimulator.name)
        let flagged = try await ResolvedProject.resolve(schemeFlag: "S", simulatorFlag: DefaultSimulator.name, bundleIdFlag: "com.x", config: nil, loadCache: { nil }, saveCache: { _ in })
        XCTAssertFalse(flagged.simulatorIsDefault)
        let configured = try await ResolvedProject.resolve(schemeFlag: "S", bundleIdFlag: "com.x", config: GrantivaConfig(simulator: "x"), loadCache: { nil }, saveCache: { _ in })
        XCTAssertFalse(configured.simulatorIsDefault)
    }

    // MARK: - The ledgers follow GRANTIVA_RUNNER_HOME

    func testTheLedgerDirectoryIsScopedByRunnerHome() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        XCTAssertEqual(SimulatorCapacity.defaultDirectory(environment: [:]), "\(home)/.grantiva/simulator-capacity")
        XCTAssertEqual(
            SimulatorCapacity.defaultDirectory(environment: ["GRANTIVA_RUNNER_HOME": "\(home)/.grantiva/runner"]),
            "\(home)/.grantiva/simulator-capacity", "the default home keeps the existing ledger"
        )
        XCTAssertEqual(SimulatorCapacity.defaultDirectory(environment: ["GRANTIVA_RUNNER_HOME": "/tmp/qa/runner/"]), "/private/tmp/qa/runner/simulator-capacity",
                       "the runner home is spelled the realpath way (L27)")
    }

    func testReadingAnAbsentLedgerCreatesNothing() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("grantiva-absent-\(UUID().uuidString)").path
        let provenance = SimulatorProvenance(directory: directory)
        XCTAssertEqual(try provenance.all(), [])
        XCTAssertFalse(try provenance.contains(udid: "X"))
        let snapshot = try await SimulatorCapacity(directory: directory).snapshot(devices: { [] })
        XCTAssertEqual(try SimulatorCapacity(directory: directory).sessions(snapshot: snapshot), [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory))
    }

    /// Devices sharing a name come back in one order whatever order simctl's
    /// runtime dictionary has (doctor's fix line names the first).
    func testDevicesSharingANameAreOrderedDeterministically() throws {
        let json = #"{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-27-0":[{"name":"iPhone 17 Pro","udid":"B","state":"Shutdown","isAvailable":true}],"com.apple.CoreSimulator.SimRuntime.iOS-26-0":[{"name":"iPhone 17 Pro","udid":"C","state":"Shutdown","isAvailable":true},{"name":"iPhone 17 Pro","udid":"A","state":"Shutdown","isAvailable":true}]}}"#
        let devices = try JSONDecoder().decode(SimctlDeviceList.self, from: Data(json.utf8)).allDevices
        XCTAssertEqual(devices.map(\.udid), ["A", "C", "B"])
    }

    // MARK: - L21

    func testRuntimesReadAsNames() {
        XCTAssertEqual(SimulatorDevice.runtimeDisplayName("iOS-26-0"), "iOS 26.0")
        XCTAssertEqual(SimulatorDevice.runtimeDisplayName("com.apple.CoreSimulator.SimRuntime.iOS-27-1"), "iOS 27.1")
        let table = TableFormatter().formatDevices([SimulatorDevice(name: "a", udid: "U", state: "Booted", runtime: "iOS-26-0", isAvailable: true)])
        XCTAssertTrue(table.contains("iOS 26.0"), table)
        XCTAssertFalse(table.contains("iOS-26-0"), table)
    }

    func testTheIncompatibleConfigurationRefusalUsesNames() async throws {
        let simctl = FakeSimctl(devices: [.init(name: "qa-x", udid: "QAX-1", state: "Shutdown", runtime: "iOS-26-0", type: FakeSimctl.iPhone17)])
        let (manager, _, _) = makeManager(simctl)
        do {
            _ = try await manager.ensure(name: "qa-x", runtime: "27.0", boot: false)
            XCTFail("expected an incompatible-configuration error")
        } catch {
            XCTAssertEqual(
                (error as? GrantivaError)?.errorDescription,
                "Invalid argument: Simulator \"qa-x\" exists with incompatible configuration (device type: iPhone 17, runtime: iOS 26.0); requested iOS 27.0"
            )
        }
    }
}
