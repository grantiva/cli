import Foundation
import GrantivaCore
import MCP
import XCTest
@testable import GrantivaMCP

@available(macOS 15, *)
final class BuildToolsTests: XCTestCase {
    private let androidConfig = GrantivaConfig(platform: .android, android: AndroidProject(module: "app", variant: "debug", applicationId: nil, emulator: "Pixel_8_API_35"))

    func testBuildOnIOSWithoutASchemeIsAToolError() async throws {
        let device = MCPFakeDevicePlatform(platform: .ios)
        let result = try await BuildTools.build(device: device, platform: .ios, config: nil, arguments: [:])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(try textContent(of: result).contains("no scheme specified"))
        XCTAssertTrue(device.calls.isEmpty)
    }

    func testResolvedProjectTakesArgumentsOverConfig() throws {
        let android = try BuildTools.resolvedProject(platform: .android, config: androidConfig, arguments: ["module": .string("mobile"), "variant": .string("freeDebug"), "emulator": .string("Other")])
        XCTAssertEqual(android.android?.module, "mobile")
        XCTAssertEqual(android.android?.variant, "freeDebug")
        XCTAssertEqual(android.simulator, "Other")
        let ios = try BuildTools.resolvedProject(platform: .ios, config: GrantivaConfig(scheme: "Demo", simulator: "iPhone 17"), arguments: ["simulator": .string("iPhone 16")])
        XCTAssertEqual(ios.scheme, "Demo")
        XCTAssertEqual(ios.simulator, "iPhone 16")
        XCTAssertThrowsError(try BuildTools.resolvedProject(platform: .ios, config: nil, arguments: [:]))
    }

    func testBuildOnAndroidBootsThenBuildsThroughThePlatform() async throws {
        let device = MCPFakeDevicePlatform(platform: .android)
        let result = try await BuildTools.build(device: device, platform: .android, config: androidConfig, arguments: [:])
        XCTAssertNil(result.isError)
        XCTAssertEqual(device.calls, ["bootDevice(Pixel_8_API_35)", "build(scheme=-,module=app,variant=debug)"])
        let text = try textContent(of: result)
        XCTAssertTrue(text.contains("Build succeeded"), text)
        XCTAssertTrue(text.contains("Product: /fake/app.apk"), text)
    }

    func testRunOnAndroidInstallsAndLaunchesWithTheBuiltApplicationID() async throws {
        let device = MCPFakeDevicePlatform(platform: .android)
        let result = try await BuildTools.run(device: device, platform: .android, config: androidConfig, arguments: [:])
        XCTAssertNil(result.isError)
        XCTAssertEqual(device.calls, [
            "bootDevice(Pixel_8_API_35)", "build(scheme=-,module=app,variant=debug)",
            "install(com.fake.built,/fake/app.apk)", "launch(com.fake.built)",
        ])
        XCTAssertTrue(try textContent(of: result).contains("Application ID: com.fake.built"))
    }

    func testRunOnIOSWithoutABundleIDIsAToolError() async throws {
        let device = MCPFakeDevicePlatform(platform: .ios)
        let result = try await BuildTools.run(device: device, platform: .ios, config: GrantivaConfig(scheme: "Demo"), arguments: [:])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(try textContent(of: result).contains("bundle_id"))
        XCTAssertTrue(device.calls.isEmpty)
    }

    func testTestOnAndroidReturnsAnErrorResult() async throws {
        let result = try await BuildTools.test(runner: XcodeBuildRunner(), platform: .android, config: androidConfig, simManager: .live, arguments: [:])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(try textContent(of: result).contains("iOS-only"))
    }
}
