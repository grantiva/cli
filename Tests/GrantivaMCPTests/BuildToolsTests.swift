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
}
