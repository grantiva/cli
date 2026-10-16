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

    // K37: with no argument and no config `simulator:`, the shared default.
    func testResolvedProjectWithoutASimulatorUsesTheSharedDefault() throws {
        let ios = try BuildTools.resolvedProject(platform: .ios, config: GrantivaConfig(scheme: "Demo"), arguments: [:])
        XCTAssertEqual(ios.simulator, DefaultSimulator.name)
    }

    /// A10: a failed Android build names the module and variant, not a scheme.
    func testFailedAndroidBuildShowsModuleAndVariantAndNoScheme() async throws {
        let device = MCPFakeDevicePlatform(platform: .android)
        device.buildResult = BuildResult(success: false, duration: 0, warnings: [], errors: ["Task 'assembleNoSuchVariant' not found"], productPath: nil)
        let result = try await BuildTools.build(device: device, platform: .android, config: androidConfig, arguments: ["variant": .string("noSuchVariant")])
        XCTAssertEqual(result.isError, true)
        let text = try textContent(of: result)
        XCTAssertTrue(text.contains("Build FAILED"), text)
        XCTAssertTrue(text.contains("Module: app\nVariant: noSuchVariant"), text)
        XCTAssertFalse(text.contains("Scheme:"), text)
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

    func testRunOnAndroidWarnsWhenTheConfiguredApplicationIDDisagreesWithTheBuild() async throws {
        let device = MCPFakeDevicePlatform(platform: .android)
        let config = GrantivaConfig(platform: .android, android: AndroidProject(applicationId: "com.fake.configured", emulator: "Pixel_8_API_35"))
        let result = try await BuildTools.run(device: device, platform: .android, config: config, arguments: [:])
        XCTAssertNil(result.isError)
        XCTAssertTrue(device.calls.contains("install(com.fake.built,/fake/app.apk)"), "\(device.calls)")
        let text = try textContent(of: result)
        XCTAssertTrue(text.contains("Application ID: com.fake.built"), text)
        XCTAssertTrue(text.contains("Warning: application_id com.fake.configured"), text)
    }

    func testRunOnIOSWithoutABundleIDIsAToolError() async throws {
        let device = MCPFakeDevicePlatform(platform: .ios)
        device.buildResult = BuildResult(success: true, duration: 0, warnings: [], errors: [], productPath: "/nonexistent/Demo.app")
        let result = try await BuildTools.run(device: device, platform: .ios, config: GrantivaConfig(scheme: "Demo"), arguments: [:])
        XCTAssertEqual(result.isError, true)
        XCTAssertEqual(try textContent(of: result), "Error: No bundle ID: grantiva.yml has no bundle_id and the built app has no CFBundleIdentifier.")
        XCTAssertFalse(device.calls.contains { $0.hasPrefix("launch") })
    }

    func testTestOnAndroidReturnsAnErrorResult() async throws {
        let result = try await BuildTools.test(runner: XcodeBuildRunner(), platform: .android, config: androidConfig, simManager: .live, arguments: [:])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(try textContent(of: result).contains("iOS-only"))
    }

    // MARK: - grantiva_test failure reason (I17)

    func testTestSummaryOnFailureIncludesXcodebuildErrorLines() {
        let result = TestResult(
            success: false, scheme: "X", duration: 0.6, testsPassed: 0, testsFailed: 0,
            output: "Command line invocation:\n    xcodebuild -scheme X test\n\nxcodebuild: error: Scheme X is not currently configured for the test action.\n"
        )
        let text = BuildTools.testSummary(result)
        XCTAssertTrue(text.hasPrefix("Tests FAILED\nScheme: X"), text)
        XCTAssertTrue(text.contains("Errors:\nxcodebuild: error: Scheme X is not currently configured for the test action."), text)
        XCTAssertTrue(text.contains("Output (last 3 lines):"), text)
    }

    func testTestSummaryOnFailureNamesFailingTests() {
        let output = """
            Test Case '-[DemoTests testLogin]' started.
            /src/DemoTests.swift:12: error: -[DemoTests testLogin] : XCTAssertEqual failed: ("1") is not equal to ("2")
            Test Case '-[DemoTests testLogin]' failed (0.010 seconds).
            ✘ Test checkout() failed after 0.002 seconds with 1 issue.
            Executed 2 tests, with 1 failure (0 unexpected) in 0.02 seconds
            """
        let text = BuildTools.testSummary(TestResult(success: false, scheme: "Demo", duration: 1, testsPassed: 1, testsFailed: 1, output: output))
        XCTAssertTrue(text.contains("Test Case '-[DemoTests testLogin]' failed"), text)
        XCTAssertTrue(text.contains("✘ Test checkout() failed"), text)
        XCTAssertTrue(text.contains("XCTAssertEqual failed"), text)
        XCTAssertFalse(text.contains("Errors:\nTest Case '-[DemoTests testLogin]' started."), text)
    }

    func testTestSummaryBoundsTheOutputTail() {
        let output = (1...500).map { "line \($0) " + String(repeating: "x", count: 200) }.joined(separator: "\n")
        let text = BuildTools.testSummary(TestResult(success: false, scheme: "Demo", duration: 1, testsPassed: 0, testsFailed: 0, output: output))
        XCTAssertLessThan(text.utf8.count, 4096 + 300, "tail must be bounded")
        XCTAssertTrue(text.contains("line 500 "), "the tail keeps the last lines")
        XCTAssertFalse(text.contains("line 400 "), text.prefix(200).description)
    }

    func testTestSummaryOnSuccessStaysShort() {
        let result = TestResult(success: true, scheme: "Demo", duration: 2, testsPassed: 4, testsFailed: 0, output: String(repeating: "noise\n", count: 1000))
        XCTAssertEqual(BuildTools.testSummary(result), "Tests passed\nScheme: Demo\nDuration: 2.0s\nPassed: 4\nFailed: 0")
    }

    func testFailedRunnerResultSurfacesTheReasonInTheSummary() async throws {
        // runner.test merges the failure into TestResult.output; the handler must surface it.
        let runner = XcodeBuildRunner { _ in
            throw GrantivaError.commandFailed("xcodebuild: error: Scheme X is not currently configured for the test action.", 66)
        }
        let result = try await runner.test(scheme: "X", destination: "sim")
        XCTAssertFalse(result.success)
        XCTAssertTrue(BuildTools.testSummary(result).contains("Scheme X is not currently configured for the test action"))
    }

    func testTestSummaryCapsEachErrorLineAndTheErrorsBlock() {
        let long = "error: " + String(repeating: "t", count: 3000)
        let output = (1...20).map { "\($0) \(long)" }.joined(separator: "\n")
        let text = BuildTools.testSummary(TestResult(success: false, scheme: "Demo", duration: 1, testsPassed: 0, testsFailed: 0, output: output), tailLines: 0)
        let errors = text.components(separatedBy: "Errors:\n")[1]
        XCTAssertLessThanOrEqual(errors.utf8.count, 4096 + 3, "the block is capped")
        let first = errors.components(separatedBy: "\n")[0]
        XCTAssertLessThanOrEqual(first.utf8.count, 500 + 3, "each line is capped")
        XCTAssertTrue(first.hasPrefix("1 error: ttt"), first)
    }

    func testTruncationNeverSplitsAMultiByteCharacter() {
        let text = String(repeating: "é✘", count: 1000)
        for bytes in [1, 2, 3, 4, 100, 101, 102] {
            XCTAssertFalse(BuildTools.utf8Suffix(text, maxBytes: bytes).contains("\u{FFFD}"))
            XCTAssertFalse(BuildTools.utf8Prefix(text, maxBytes: bytes).contains("\u{FFFD}"))
            XCTAssertLessThanOrEqual(BuildTools.utf8Suffix(text, maxBytes: bytes).utf8.count, bytes)
        }
        XCTAssertEqual(BuildTools.utf8Suffix("aaaa\nbb", maxBytes: 5), "bb", "starts after a newline in range")
        let failing = TestResult(success: false, scheme: "D", duration: 1, testsPassed: 0, testsFailed: 0, output: (1...200).map { "ligne é✘ \($0)" }.joined(separator: "\n"))
        XCTAssertFalse(BuildTools.testSummary(failing, maxTailBytes: 101).contains("\u{FFFD}"))
    }

    // MARK: - K54: grantiva_build on Android compiles only

    func testBuildOnAndroidCompilesWithoutBootingTheConfiguredEmulator() async throws {
        let device = MCPFakeDevicePlatform(platform: .android)
        let result = try await BuildTools.build(device: device, platform: .android, config: androidConfig, arguments: [:])
        XCTAssertNil(result.isError)
        XCTAssertEqual(device.calls, ["build(scheme=-,module=app,variant=debug)"], "nothing is booted")
        let text = try textContent(of: result)
        XCTAssertTrue(text.contains("Module: app\nVariant: debug"), text)
    }

    func testBuildOnIOSStillBootsItsSimulator() async throws {
        let device = MCPFakeDevicePlatform(platform: .ios)
        _ = try await BuildTools.build(device: device, platform: .ios, config: GrantivaConfig(scheme: "Demo", simulator: "fix2-10-ios"), arguments: [:])
        XCTAssertEqual(device.calls.first, "bootDevice(fix2-10-ios)")
    }

    // MARK: - K94: grantiva_run says what it built

    func testRunNamesTheProductItInstalled() async throws {
        let ios = MCPFakeDevicePlatform(platform: .ios)
        ios.buildResult = BuildResult(success: true, duration: 0, warnings: [], errors: [], productPath: "/fake/Demo.app")
        let iosText = try textContent(of: try await BuildTools.run(
            device: ios, platform: .ios, config: GrantivaConfig(scheme: "Demo", bundleId: "com.example.demo"), arguments: [:]
        ))
        XCTAssertTrue(iosText.hasSuffix("\nProduct: /fake/Demo.app"), iosText)

        let android = MCPFakeDevicePlatform(platform: .android)
        let androidText = try textContent(of: try await BuildTools.run(device: android, platform: .android, config: androidConfig, arguments: [:]))
        XCTAssertTrue(androidText.contains("\nProduct: /fake/app.apk"), androidText)
    }

    // MARK: - K95: grantiva_run without a config reads the built app's bundle ID

    private func appWithInfoPlist(bundleID: String?) throws -> String {
        let app = FileManager.default.temporaryDirectory.appendingPathComponent("k95-\(UUID().uuidString)/Demo.app")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: app.deletingLastPathComponent()) }
        var plist: [String: Any] = ["CFBundleName": "Demo"]
        if let bundleID { plist["CFBundleIdentifier"] = bundleID }
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: app.appendingPathComponent("Info.plist"))
        return app.path
    }

    func testRunWithoutAConfigLaunchesTheBundleIDOfTheBuiltApp() async throws {
        let device = MCPFakeDevicePlatform(platform: .ios)
        let product = try appWithInfoPlist(bundleID: "com.example.App")
        device.buildResult = BuildResult(success: true, duration: 0, warnings: [], errors: [], productPath: product)
        let result = try await BuildTools.run(
            device: device, platform: .ios, config: nil, arguments: ["scheme": .string("Demo (UI Testing)")],
            missingConfig: "grantiva.yml not found at /x/grantiva.yml. Create one with grantiva init.",
            projectDirectory: URL(fileURLWithPath: "/x")
        )
        XCTAssertNil(result.isError)
        XCTAssertEqual(Array(device.calls.suffix(2)), ["install(com.example.App,\(AppBinaryResolver.canonicalPath(product)))", "launch(com.example.App)"])
        let text = try textContent(of: result)
        XCTAssertTrue(text.hasPrefix("App built and launched.\nScheme: Demo (UI Testing)\nBundle ID: com.example.App\nSimulator: Fake"), text)
    }

    func testRunPrefersTheConfiguredBundleID() async throws {
        let device = MCPFakeDevicePlatform(platform: .ios)
        device.buildResult = BuildResult(success: true, duration: 0, warnings: [], errors: [], productPath: try appWithInfoPlist(bundleID: "com.example.Built"))
        _ = try await BuildTools.run(device: device, platform: .ios, config: GrantivaConfig(scheme: "Demo", bundleId: "com.example.Configured"), arguments: [:])
        XCTAssertEqual(device.calls.last, "launch(com.example.Configured)")
    }

    func testRunWithNoBundleIDAnywhereSaysWhereItLooked() async throws {
        let device = MCPFakeDevicePlatform(platform: .ios)
        device.buildResult = BuildResult(success: true, duration: 0, warnings: [], errors: [], productPath: try appWithInfoPlist(bundleID: nil))
        let result = try await BuildTools.run(
            device: device, platform: .ios, config: nil, arguments: ["scheme": .string("Demo")],
            missingConfig: "unused", projectDirectory: URL(fileURLWithPath: "/proj")
        )
        XCTAssertEqual(result.isError, true)
        XCTAssertEqual(try textContent(of: result), "Error: No bundle ID: no grantiva.yml in /proj and the built app has no CFBundleIdentifier.")
        XCTAssertFalse(device.calls.contains { $0.hasPrefix("launch") })
    }
}
