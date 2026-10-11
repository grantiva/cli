import ArgumentParser
import Foundation
import XCTest
@testable import GrantivaCLI
@testable import GrantivaCore

/// L08 at the CLI: the default simulator (nothing named one) goes through the
/// ownership check in `run`, `run --flow`, and `runner start`; a named one
/// does not. The refusal comes before anything is prepared.
final class DefaultSimulatorCommandTests: XCTestCase {
    private var dir: URL!
    private var previousDirectory: String!
    private let refusal = GrantivaError.invalidArgument("refused: not created by Grantiva")

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("l08-cli-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        previousDirectory = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(dir.path)
    }

    override func tearDownWithError() throws {
        FileManager.default.changeCurrentDirectoryPath(previousDirectory)
        try? FileManager.default.removeItem(at: dir)
    }

    func testTargetDeviceTakesTheDefaultPathOnlyForTheDefault() async throws {
        let fake = FakeDevicePlatform(platform: .ios)
        _ = try await RunCommand.targetDevice(platform: .ios, device: fake, target: "iPhone 18 Pro", serialFlag: nil, targetIsDefault: true, log: { _ in })
        _ = try await RunCommand.targetDevice(platform: .ios, device: fake, target: "qa-ios", serialFlag: nil, targetIsDefault: false, log: { _ in })
        XCTAssertEqual(fake.calls, ["bootDefaultDevice(iPhone 18 Pro)", "bootDevice(qa-ios)"])
    }

    func testRunFlowWithoutASimulatorIsRefusedBeforeAnythingElse() async throws {
        let flow = dir.appendingPathComponent("f.yaml")
        try "appId: com.example.app\n---\n- launchApp\n".write(to: flow, atomically: true, encoding: .utf8)
        var command = try RunCommand.parse(["--platform", "ios", "--flow", flow.path, "--no-build", "--bundle-id", "com.example.app"])
        let fake = FakeDevicePlatform(platform: .ios)
        fake.defaultRefusal = refusal
        command.devicePlatform = InjectedDevicePlatform(fake)
        command.runnerManager = RunnerManager(
            ensureAvailable: { XCTFail("the runner must not be prepared before the refusal") },
            runnerPath: { "/usr/bin/false" }, runnerDir: { NSTemporaryDirectory() },
            leaseDirectory: dir.appendingPathComponent("locks").path
        )
        do {
            try await command.run()
            XCTFail("expected the refusal")
        } catch {
            XCTAssertEqual((error as? GrantivaError)?.errorDescription, refusal.errorDescription)
        }
        // `--flow` carries the default flag through its copy of the project.
        XCTAssertEqual(fake.calls, ["checkDefaultDevice(\(DefaultSimulator.name))"])
    }

    func testRunFlowWithANamedSimulatorSkipsTheCheck() async throws {
        let flow = dir.appendingPathComponent("f.yaml")
        try "appId: com.example.app\n---\n- launchApp\n".write(to: flow, atomically: true, encoding: .utf8)
        var command = try RunCommand.parse(["--platform", "ios", "--flow", flow.path, "--no-build", "--bundle-id", "com.example.app", "--simulator", "qa-ios"])
        let fake = FakeDevicePlatform(platform: .ios)
        fake.defaultRefusal = refusal
        fake.bootFailure = GrantivaError.unavailable("stop here")
        command.devicePlatform = InjectedDevicePlatform(fake)
        command.runnerManager = RunnerManager(
            ensureAvailable: {}, runnerPath: { "/usr/bin/false" }, runnerDir: { NSTemporaryDirectory() },
            leaseDirectory: dir.appendingPathComponent("locks").path
        )
        do { try await command.run() } catch {}
        XCTAssertFalse(fake.calls.contains { $0.hasPrefix("checkDefaultDevice") || $0.hasPrefix("bootDefaultDevice") }, "\(fake.calls)")
    }

    func testRunnerStartWithoutASimulatorTakesTheDefaultPath() async throws {
        var command = try RunnerStartCommand.parse(["--platform", "ios", "--bundle-id", "com.example.app"])
        let fake = FakeDevicePlatform(platform: .ios)
        fake.defaultRefusal = refusal
        command.devicePlatform = InjectedDevicePlatform(fake)
        do {
            try await command.run()
            XCTFail("expected the refusal")
        } catch {
            XCTAssertEqual((error as? GrantivaError)?.errorDescription, refusal.errorDescription)
        }
        XCTAssertEqual(fake.calls, ["bootDefaultDevice(\(DefaultSimulator.name))"])

        var named = try RunnerStartCommand.parse(["--platform", "ios", "--bundle-id", "com.example.app", "--simulator", "qa-ios"])
        let other = FakeDevicePlatform(platform: .ios)
        other.bootFailure = GrantivaError.unavailable("stop here")
        named.devicePlatform = InjectedDevicePlatform(other)
        do { try await named.run() } catch {}
        XCTAssertEqual(other.calls, ["bootDevice(qa-ios)"])
    }
}

/// L08's `--no-build` twin: the capture's fallback (the sole booted
/// simulator) through the real iOS platform over a scripted simctl.
final class NoBuildDefaultDeviceTests: XCTestCase {
    private func platform(booted udid: String, name: String, created: [String]) throws -> IOSPlatform {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("l08-nobuild-\(UUID().uuidString)").path
        addTeardownBlock { try? FileManager.default.removeItem(atPath: directory) }
        let provenance = SimulatorProvenance(directory: directory)
        for id in created { try provenance.register(udid: id, name: name) }
        let list = #"{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-0":[{"name":"\#(name)","udid":"\#(udid)","state":"Booted","isAvailable":true}]}}"#
        let manager = SimulatorManager(
            execute: { command in
                guard command == "xcrun simctl list devices --json" else { throw GrantivaError.commandFailed("unexpected: \(command)", 1) }
                return list
            },
            capacity: SimulatorCapacity(directory: directory, maximum: 4, waitTimeout: 0, pollInterval: 0.01),
            provenance: provenance, runnerHome: "\(directory)/runner"
        )
        return IOSPlatform(simulators: manager)
    }

    func testTheSoleBootedSimulatorIsRefusedUnlessGrantivaCreatedIt() async throws {
        let theirs = try platform(booted: "USER-3", name: "Mine", created: [])
        do {
            _ = try await DiffCommand.noBuildDevice(platform: .ios, explicit: nil, config: nil, sessionUDID: { nil }, device: theirs)
            XCTFail("expected the refusal")
        } catch {
            let text = (error as? GrantivaError)?.errorDescription ?? ""
            XCTAssertTrue(text.hasPrefix("Invalid argument: Simulator \"Mine\" (USER-3) was not created by Grantiva. It is the only booted simulator, "), text)
            XCTAssertTrue(text.contains("Pass --simulator \"Mine\" to use it anyway"), text)
        }
        let ours = try platform(booted: "OURS-3", name: "qa", created: ["OURS-3"])
        let device = try await DiffCommand.noBuildDevice(platform: .ios, explicit: nil, config: nil, sessionUDID: { nil }, device: ours)
        XCTAssertEqual(device.udid, "OURS-3")
    }
}
