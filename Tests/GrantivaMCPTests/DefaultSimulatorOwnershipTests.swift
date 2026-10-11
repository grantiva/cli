import Foundation
import MCP
import XCTest
@testable import GrantivaCore
@testable import GrantivaMCP

/// L08: a sessionless `grantiva_build {scheme}` with no simulator argument and
/// no config `simulator:` uses the default name. A simulator of that name the
/// user created (not in the created-simulator ledger) is never booted or
/// slotted; one Grantiva created is. Every build and run result names the
/// simulator it used.
@available(macOS 15, *)
final class DefaultSimulatorOwnershipTests: XCTestCase {
    /// A scripted `simctl` (and `xcodebuild`) that records every command.
    final class Host: @unchecked Sendable {
        struct Device { var name: String; var udid: String; var state: String }
        private let lock = NSLock()
        private var devices: [Device]
        private var recorded: [String] = []
        init(_ devices: [Device]) { self.devices = devices }
        var commands: [String] { lock.withLock { recorded } }

        func execute(_ command: String) async throws -> String {
            try lock.withLock {
                recorded.append(command)
                if command == "xcrun simctl list devices --json" {
                    let list = devices.map {
                        ["name": $0.name, "udid": $0.udid, "state": $0.state, "isAvailable": true] as [String: Any]
                    }
                    let data = try JSONSerialization.data(withJSONObject: ["devices": ["com.apple.CoreSimulator.SimRuntime.iOS-26-0": list]])
                    return String(decoding: data, as: UTF8.self)
                }
                if command.hasPrefix("xcrun simctl boot ") {
                    let udid = String(command.dropFirst("xcrun simctl boot ".count))
                    if let index = devices.firstIndex(where: { $0.udid == udid }) { devices[index].state = "Booted" }
                    return ""
                }
                if command.hasPrefix("xcrun simctl bootstatus ") || command.hasPrefix("'xcodebuild'") { return "" }
                throw GrantivaError.commandFailed("unexpected command: \(command)", 1)
            }
        }
    }

    private func makePlatform(_ host: Host, created: [String]) throws -> (IOSPlatform, SimulatorManager, SimulatorCapacity) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-l08-\(UUID().uuidString)").path
        addTeardownBlock { try? FileManager.default.removeItem(atPath: directory) }
        let capacity = SimulatorCapacity(directory: directory, maximum: 4, waitTimeout: 0, pollInterval: 0.01)
        let provenance = SimulatorProvenance(directory: directory)
        for udid in created { try provenance.register(udid: udid, name: DefaultSimulator.name) }
        let manager = SimulatorManager(
            execute: host.execute, capacity: capacity, provenance: provenance, runnerHome: "\(directory)/runner"
        )
        let platform = IOSPlatform(simulators: manager, xcodebuild: XcodeBuildRunner(execute: host.execute))
        return (platform, manager, capacity)
    }

    private var userOwned: Host {
        Host([.init(name: DefaultSimulator.name, udid: "USER-0001", state: "Shutdown")])
    }

    func testBuildWithTheDefaultNameRefusesASimulatorTheUserCreated() async throws {
        let host = userOwned
        let (platform, manager, _) = try makePlatform(host, created: [])
        let registry = ToolRegistry(
            connection: RunnerConnection(resolveSession: { throw GrantivaError.unavailable("none") }, attach: { _ in throw GrantivaError.unavailable("none") }),
            platform: .ios, device: platform, config: nil, simulatorManager: manager,
            buildRunner: XcodeBuildRunner(execute: host.execute), emulators: nil,
            projectDirectory: FileManager.default.temporaryDirectory
        )
        let result = try await registry.call(name: "grantiva_build", arguments: ["scheme": .string("Demo")], notify: { _ in })
        XCTAssertEqual(result.isError, true)
        let name = DefaultSimulator.name
        XCTAssertEqual(
            try textContent(of: result),
            "Error: Invalid argument: Simulator \"\(name)\" (USER-0001) was not created by Grantiva. It has the default simulator's name, "
                + "and Grantiva does not take a simulator you created as its default. Pass simulator: \"\(name)\" to use it anyway, "
                + "or set simulator: in grantiva.yml (create one with grantiva simulator ensure --name \"Grantiva \(name)\")."
        )
        XCTAssertFalse(host.commands.contains { $0.hasPrefix("xcrun simctl boot") }, "\(host.commands)")
        XCTAssertFalse(host.commands.contains { $0.contains("xcodebuild") }, "\(host.commands)")
        let sessions = try await manager.managedSessions()
        XCTAssertTrue(sessions.isEmpty)
    }

    private func refusal(_ override: String) -> String {
        let name = DefaultSimulator.name
        return "Invalid argument: Simulator \"\(name)\" (USER-0001) was not created by Grantiva. It has the default simulator's name, "
            + "and Grantiva does not take a simulator you created as its default. Pass \(override) \"\(name)\" to use it anyway, "
            + "or set simulator: in grantiva.yml (create one with grantiva simulator ensure --name \"Grantiva \(name)\")."
    }

    private func message(_ body: () async throws -> Any) async -> String? {
        do {
            _ = try await body()
            return nil
        } catch {
            return (error as? LocalizedError)?.errorDescription
        }
    }

    func testRunAndTestAndSimBootWithTheDefaultNameRefuseItToo() async throws {
        let host = userOwned
        let (platform, manager, _) = try makePlatform(host, created: [])
        let run = await message { try await BuildTools.run(device: platform, platform: .ios, config: GrantivaConfig(scheme: "Demo"), arguments: [:]) }
        XCTAssertEqual(run, refusal("simulator:"))
        let test = await message {
            try await BuildTools.test(
                runner: XcodeBuildRunner(execute: host.execute), platform: .ios, config: GrantivaConfig(scheme: "Demo"),
                simManager: manager, arguments: [:]
            )
        }
        XCTAssertEqual(test, refusal("simulator:"))
        let boot = await message { try await SimTools.boot(simManager: manager, arguments: [:]) }
        XCTAssertEqual(boot, refusal("name:"))
        XCTAssertFalse(host.commands.contains { $0.hasPrefix("xcrun simctl boot") }, "\(host.commands)")
    }

    /// The `--no-build` capture's default (the sole booted simulator) follows
    /// the same rule; `grantiva_vrt_capture` without a session runs that capture.
    func testTheSoleBootedDefaultIsRefusedUnlessGrantivaCreatedIt() async throws {
        let user = Host([.init(name: "Mine", udid: "USER-0002", state: "Booted")])
        let (refusing, _, _) = try makePlatform(user, created: [])
        let text = await message { try await refusing.defaultDevice() }
        XCTAssertEqual(
            text,
            "Invalid argument: Simulator \"Mine\" (USER-0002) was not created by Grantiva. It is the only booted simulator, "
                + "and Grantiva does not take a simulator you created as its default. Pass --simulator \"Mine\" to use it anyway, "
                + "or set simulator: in grantiva.yml (create one with grantiva simulator ensure --name \"Grantiva Mine\")."
        )
        let ours = Host([.init(name: "qa", udid: "OURS-2", state: "Booted")])
        let (using, _, _) = try makePlatform(ours, created: ["OURS-2"])
        let device = try await using.defaultDevice()
        XCTAssertEqual(device.udid, "OURS-2")
    }

    func testANamedSimulatorIsUsedAsBeforeEvenWithTheDefaultName() async throws {
        let host = userOwned
        let (platform, _, _) = try makePlatform(host, created: [])
        let result = try await BuildTools.build(
            device: platform, platform: .ios, config: nil,
            arguments: ["scheme": .string("Demo"), "simulator": .string(DefaultSimulator.name)]
        )
        XCTAssertNil(result.isError)
        XCTAssertTrue(host.commands.contains("xcrun simctl boot USER-0001"), "\(host.commands)")
    }

    func testBuildWithTheDefaultNameBootsASimulatorGrantivaCreatedAndNamesIt() async throws {
        let host = Host([.init(name: DefaultSimulator.name, udid: "GRANTIVA-1", state: "Shutdown")])
        let (platform, _, _) = try makePlatform(host, created: ["GRANTIVA-1"])
        let result = try await BuildTools.build(device: platform, platform: .ios, config: nil, arguments: ["scheme": .string("Demo")])
        XCTAssertNil(result.isError)
        XCTAssertTrue(host.commands.contains("xcrun simctl boot GRANTIVA-1"), "\(host.commands)")
        let text = try textContent(of: result)
        XCTAssertTrue(text.contains("Scheme: Demo\nSimulator: \(DefaultSimulator.name) (GRANTIVA-1)\n"), text)
    }

    func testRunNamesTheSimulatorWithItsUDID() async throws {
        let device = MCPFakeDevicePlatform(platform: .ios)
        device.bootedID = "UDID-9"
        device.bootedName = "qa-ios"
        let result = try await BuildTools.run(
            device: device, platform: .ios, config: GrantivaConfig(scheme: "Demo", simulator: "qa-ios", bundleId: "com.example"), arguments: [:]
        )
        let text = try textContent(of: result)
        XCTAssertTrue(text.contains("Simulator: qa-ios (UDID-9)"), text)
    }

    func testResolvedProjectMarksTheDefault() throws {
        XCTAssertTrue(try BuildTools.resolvedProject(platform: .ios, config: GrantivaConfig(scheme: "D"), arguments: [:]).simulatorIsDefault)
        XCTAssertFalse(try BuildTools.resolvedProject(platform: .ios, config: GrantivaConfig(scheme: "D", simulator: "x"), arguments: [:]).simulatorIsDefault)
        XCTAssertFalse(try BuildTools.resolvedProject(platform: .ios, config: nil, arguments: ["scheme": .string("D"), "simulator": .string("x")]).simulatorIsDefault)
    }
}
