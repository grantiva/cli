import Foundation
import GrantivaCore
import MCP
import XCTest
@testable import GrantivaMCP

@available(macOS 15, *)
final class ContextToolTests: XCTestCase {
    private static let first = SimulatorDevice(name: "iPhone 17 Pro", udid: "B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C", state: "Booted", runtime: "iOS-26-0", isAvailable: true)
    private static let second = SimulatorDevice(name: "qa-c06", udid: "D3E7E498-2E80-469C-A465-4757C8995ACC", state: "Booted", runtime: "iOS-26-0", isAvailable: true)
    private static let shutdown = SimulatorDevice(name: "qa-ios-1", udid: "4DAB1D26-5107-4B17-9093-AC2E19DE0403", state: "Shutdown", runtime: "iOS-26-0", isAvailable: true)

    private func session(_ udid: String) -> RunnerSessionInfo {
        RunnerSessionInfo(pid: 55313, wdaPort: 8400, bundleId: "com.apple.Preferences", udid: udid, startedAt: Date())
    }

    private func emulators(devices: [ADBDevice], names: [String: String], listFails: Bool = false) -> EmulatorToolDependencies {
        EmulatorToolDependencies(
            listAVDs: { Array(names.values) },
            listDevices: {
                if listFails { throw GrantivaError.commandFailed("adb devices", 1) }
                return devices
            },
            avdName: { names[$0] ?? $0 },
            boot: { BootedDevice(udid: "emulator-5554", name: $0) },
            ensure: { name, _, _ in EmulatorProvisionResult(name: name, serial: nil, created: false, state: "Shutdown") },
            delete: { _, _ in }
        )
    }

    private func section(_ name: String, in text: String) -> String {
        guard let start = text.range(of: "[\(name)]") else { return "" }
        let rest = text[start.upperBound...]
        let end = rest.range(of: "\n\n")?.lowerBound ?? rest.endIndex
        return String(rest[..<end])
    }

    // MARK: iOS

    /// C06: with two booted simulators and the session on the second,
    /// [Simulator] names the session's device.
    func testSimulatorSectionNamesTheSessionDeviceNotTheFirstBooted() async throws {
        let result = try await ContextTool.context(
            config: GrantivaConfig(scheme: "Other", simulator: "iPhone 16e"), platform: .ios,
            session: session(Self.second.udid), listSimulators: { [Self.first, Self.second] }, emulators: nil
        )
        let text = try textContent(of: result)
        let simulator = section("Simulator", in: text)
        XCTAssertTrue(simulator.contains("udid: \(Self.second.udid)"), text)
        XCTAssertTrue(simulator.contains("source: runner session"), text)
        XCTAssertFalse(simulator.contains(Self.first.udid), text)
        XCTAssertTrue(section("Runner Session", in: text).contains("udid: \(Self.second.udid)"), text)
    }

    func testWithoutASessionTheConfiguredBootedSimulatorIsShown() async throws {
        let result = try await ContextTool.context(
            config: GrantivaConfig(scheme: "App", simulator: "qa-c06"), platform: .ios,
            session: nil, listSimulators: { [Self.first, Self.second] }, emulators: nil
        )
        let text = try textContent(of: result)
        let simulator = section("Simulator", in: text)
        XCTAssertTrue(simulator.contains("udid: \(Self.second.udid)"), text)
        XCTAssertTrue(simulator.contains("simulator in grantiva.yml"), text)
        XCTAssertTrue(section("Runner Session", in: text).contains("No active session."), text)
    }

    func testWithoutASessionAConfiguredSimulatorThatIsNotBootedIsSaidSo() async throws {
        let result = try await ContextTool.context(
            config: GrantivaConfig(scheme: "App", simulator: "qa-ios-1"), platform: .ios,
            session: nil, listSimulators: { [Self.first, Self.shutdown] }, emulators: nil
        )
        let simulator = section("Simulator", in: try textContent(of: result))
        XCTAssertTrue(simulator.contains("Configured simulator \"qa-ios-1\" is not booted"), simulator)
        XCTAssertFalse(simulator.contains(Self.first.udid), simulator)
    }

    func testWithNeitherSessionNorConfiguredSimulatorTheFirstBootedIsLabelled() async throws {
        let result = try await ContextTool.context(
            config: nil, platform: .ios, session: nil, listSimulators: { [Self.first, Self.second] }, emulators: nil
        )
        let simulator = section("Simulator", in: try textContent(of: result))
        XCTAssertTrue(simulator.contains("udid: \(Self.first.udid)"), simulator)
        XCTAssertTrue(simulator.contains("first booted simulator"), simulator)
    }

    // MARK: Android

    func testAndroidContextNamesTheSessionSerialWithTwoEmulatorsRunning() async throws {
        let config = GrantivaConfig(platform: .android, android: AndroidProject(module: "app", variant: "debug", applicationId: "dev.grantiva.example", emulator: "Pixel_8_API_35"))
        let deps = emulators(
            devices: [ADBDevice(serial: "emulator-5554", state: "device"), ADBDevice(serial: "emulator-5556", state: "device")],
            names: ["emulator-5554": "Pixel_8_API_35", "emulator-5556": "qa-android-1"]
        )
        let result = try await ContextTool.context(config: config, platform: .android, session: session("emulator-5554"), listSimulators: { [] }, emulators: deps)
        let text = try textContent(of: result)
        XCTAssertTrue(text.contains("module: app"), text)
        XCTAssertTrue(text.contains("application_id: dev.grantiva.example"), text)
        let emulator = section("Emulator", in: text)
        XCTAssertTrue(emulator.contains("serial: emulator-5554"), text)
        XCTAssertTrue(emulator.contains("source: runner session"), text)
        XCTAssertFalse(emulator.contains("No emulator running"), text)
        XCTAssertFalse(text.contains("[Xcode]"), text)
    }

    func testAndroidWithoutASessionShowsTheConfiguredAVDsSerial() async throws {
        let config = GrantivaConfig(platform: .android, android: AndroidProject(emulator: "qa-android-1"))
        let deps = emulators(
            devices: [ADBDevice(serial: "emulator-5554", state: "device"), ADBDevice(serial: "emulator-5556", state: "device")],
            names: ["emulator-5554": "Pixel_8_API_35", "emulator-5556": "qa-android-1"]
        )
        let result = try await ContextTool.context(config: config, platform: .android, session: nil, listSimulators: { [] }, emulators: deps)
        let emulator = section("Emulator", in: try textContent(of: result))
        XCTAssertTrue(emulator.contains("serial: emulator-5556"), emulator)
    }

    func testAndroidWithoutSessionOrConfiguredAVDListsTheRunningSerials() async throws {
        let deps = emulators(
            devices: [ADBDevice(serial: "emulator-5554", state: "device"), ADBDevice(serial: "emulator-5556", state: "device")],
            names: ["emulator-5554": "Pixel_8_API_35", "emulator-5556": "qa-android-1"]
        )
        let result = try await ContextTool.context(config: nil, platform: .android, session: nil, listSimulators: { [] }, emulators: deps)
        let emulator = section("Emulator", in: try textContent(of: result))
        XCTAssertTrue(emulator.contains("emulator-5554 (Pixel_8_API_35)"), emulator)
        XCTAssertTrue(emulator.contains("emulator-5556 (qa-android-1)"), emulator)
        XCTAssertFalse(emulator.contains("No emulator running"), emulator)
    }

    func testAndroidDeviceListingFailureIsNotReportedAsNoEmulator() async throws {
        let deps = emulators(devices: [], names: [:], listFails: true)
        let result = try await ContextTool.context(config: nil, platform: .android, session: nil, listSimulators: { [] }, emulators: deps)
        let emulator = section("Emulator", in: try textContent(of: result))
        XCTAssertTrue(emulator.contains("Could not list devices"), emulator)
        XCTAssertFalse(emulator.contains("No emulator running"), emulator)
    }

    // MARK: - K56: keep-alive sessions show their app ID and port

    private func context(
        platform: Platform, session: RunnerSessionInfo?, config: GrantivaConfig? = nil,
        configSource: String? = nil, driverPort: Int? = nil
    ) async throws -> String {
        let result = try await ContextTool.context(
            config: config, platform: platform, session: session,
            listSimulators: { [] }, emulators: nil, configSource: configSource, driverPort: driverPort
        )
        return try textContent(of: result)
    }

    func testAKeepAliveSessionRendersItsAppIDAndNoEmptyValues() async throws {
        let ios = RunnerSessionInfo(pid: 4267, wdaPort: 8235, bundleId: "com.kylebrowning.Landmarks", udid: Self.first.udid, startedAt: Date())
        let iosSession = section("Runner Session", in: try await context(platform: .ios, session: ios))
        XCTAssertTrue(iosSession.contains("bundle_id: com.kylebrowning.Landmarks"), iosSession)

        let android = RunnerSessionInfo(pid: 79748, wdaPort: 0, bundleId: "com.kylebrowning.landmarks", udid: "emulator-5554", startedAt: Date())
        let forwarded = section("Runner Session", in: try await context(platform: .android, session: android))
        XCTAssertTrue(forwarded.contains("driver_port: (forwarded on attach)"), forwarded)
        XCTAssertTrue(forwarded.contains("application_id: com.kylebrowning.landmarks"), forwarded)
        let attached = section("Runner Session", in: try await context(platform: .android, session: android, driverPort: 61211))
        XCTAssertTrue(attached.contains("driver_port: 61211"), attached)

        for text in [iosSession, forwarded, attached] {
            XCTAssertFalse(text.components(separatedBy: "\n").contains { $0.hasSuffix(": ") || $0.hasSuffix(":") }, text)
        }
    }

    func testASessionFromAnOlderGrantivaSaysTheAppIDIsUnknown() async throws {
        let legacy = RunnerSessionInfo(pid: 4267, wdaPort: 8235, bundleId: "", udid: Self.first.udid, startedAt: Date())
        let text = section("Runner Session", in: try await context(platform: .ios, session: legacy))
        XCTAssertTrue(text.contains("bundle_id: (unknown)"), text)
    }

    // MARK: - K58: the config names its source

    func testTheConfigNamesItsSource() async throws {
        let maestro = section("Config", in: try await context(
            platform: .ios, session: nil, config: GrantivaConfig(bundleId: "com.example.ios"), configSource: ".maestro/ (no grantiva.yml)"
        ))
        XCTAssertTrue(maestro.contains("  source: .maestro/ (no grantiva.yml)"), maestro)
        let file = section("Config", in: try await context(
            platform: .ios, session: nil, config: GrantivaConfig(scheme: "Demo"), configSource: "grantiva.yml"
        ))
        XCTAssertTrue(file.contains("  source: grantiva.yml"), file)
    }

    func testTheRegistryTellsAFileFromTheMaestroFallback() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("k58-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertNil(ToolRegistry.configSource(platform: .ios, config: nil, directory: directory))
        XCTAssertEqual(ToolRegistry.configSource(platform: .ios, config: GrantivaConfig(), directory: directory), ".maestro/ (no grantiva.yml)")
        try Data().write(to: directory.appendingPathComponent("grantiva.yml"))
        XCTAssertEqual(ToolRegistry.configSource(platform: .ios, config: GrantivaConfig(), directory: directory), "grantiva.yml")
    }
}
