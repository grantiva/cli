import Foundation
import GrantivaCore
import MCP
import XCTest
@testable import GrantivaMCP

@available(macOS 15, *)
final class EmulatorToolsTests: XCTestCase {
    private final class Log: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [String] = []
        func add(_ s: String) { lock.withLock { items.append(s) } }
        var value: [String] { lock.withLock { items } }
    }

    private func deps(_ log: Log) -> EmulatorToolDependencies {
        EmulatorToolDependencies(
            listAVDs: { log.add("listAVDs"); return ["Pixel_8_API_35", "Pixel_7_API_34"] },
            listDevices: { log.add("listDevices"); return [ADBDevice(serial: "emulator-5554", state: "device"), ADBDevice(serial: "R58M1", state: "device")] },
            avdName: { serial in log.add("avdName(\(serial))"); return "Pixel_8_API_35" },
            boot: { name in log.add("boot(\(name))"); return BootedDevice(udid: "emulator-5554", name: name.isEmpty ? "Pixel_8_API_35" : name) },
            ensure: { name, image, boot in log.add("ensure(\(name),\(image ?? "-"),\(boot))"); return EmulatorProvisionResult(name: name, serial: boot ? "emulator-5556" : nil, created: true, state: boot ? "Booted" : "Shutdown") },
            delete: { name, force in log.add("delete(\(name),\(force))") }
        )
    }

    func testListPairsAVDsWithRunningSerials() async throws {
        let log = Log()
        let result = try await EmulatorTools.list(deps: deps(log), arguments: [:])
        let text = try textContent(of: result)
        XCTAssertEqual(text, "Name | Serial | State\nPixel_8_API_35 | emulator-5554 | Booted\nPixel_7_API_34 | - | Shutdown")
        XCTAssertEqual(log.value, ["listAVDs", "listDevices", "avdName(emulator-5554)"])
    }

    func testBootFallsBackToTheConfiguredEmulator() async throws {
        let log = Log()
        let config = GrantivaConfig(platform: .android, android: AndroidProject(emulator: "Pixel_8_API_35"))
        let result = try await EmulatorTools.boot(deps: deps(log), config: config, arguments: [:])
        XCTAssertTrue(try textContent(of: result).contains("Emulator booted: Pixel_8_API_35 (emulator-5554)"))
        XCTAssertEqual(log.value, ["boot(Pixel_8_API_35)"])
    }

    func testEnsureRequiresANameAndReturnsJSON() async throws {
        let log = Log()
        let missing = try await EmulatorTools.ensure(deps: deps(log), arguments: [:])
        XCTAssertEqual(missing.isError, true)
        XCTAssertTrue(try textContent(of: missing).contains("'name' is required"))
        let result = try await EmulatorTools.ensure(deps: deps(log), arguments: ["name": .string("New"), "system_image": .string("img"), "boot": .bool(true)])
        XCTAssertNil(result.isError)
        XCTAssertTrue(try textContent(of: result).contains(#""serial" : "emulator-5556""#))
        XCTAssertEqual(log.value, ["ensure(New,img,true)"])
    }

    func testDeleteRequiresANameAndPassesForce() async throws {
        let log = Log()
        let missing = try await EmulatorTools.delete(deps: deps(log), arguments: [:])
        XCTAssertEqual(missing.isError, true)
        let result = try await EmulatorTools.delete(deps: deps(log), arguments: ["name": .string("Old"), "force": .bool(true)])
        XCTAssertEqual(try textContent(of: result), #"{"deleted":true,"name":"Old"}"#)
        XCTAssertEqual(log.value, ["delete(Old,true)"])
    }

    func testWithoutAnSDKEveryEmulatorToolReturnsAnErrorResult() async throws {
        let result = try await EmulatorTools.list(deps: nil, arguments: [:])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(try textContent(of: result).contains("Android SDK not found"))
    }

    func testEmulatorToolsDispatchThroughTheRegistry() async throws {
        let log = Log()
        let registry = ToolRegistry(
            driver: MCPTestSupport.fakeDriver(recorder: WDARecorder()), platform: .android, device: MCPFakeDevicePlatform(platform: .android),
            config: nil, session: MCPTestSupport.sessionWithoutUDID(), simulatorManager: .live, buildRunner: XcodeBuildRunner(), emulators: deps(log)
        )
        _ = try await registry.call(name: "grantiva_emulator_list", arguments: [:], server: MCPTestSupport.disconnectedServer())
        XCTAssertEqual(log.value.first, "listAVDs")
    }
}
