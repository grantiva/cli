import Foundation
import XCTest
@testable import GrantivaCore

final class XcodeBuildRunnerTests: XCTestCase {
    func testBuildQuotesArgumentsAndResolvesTheAppProduct() async throws {
        let executor = ScriptedExecutor([
            .success("warning: heads up"),
            .success("""
                BUILT_PRODUCTS_DIR = /tmp/Test Products
                FULL_PRODUCT_NAME = Tests.xctest

                BUILT_PRODUCTS_DIR = /tmp/App Products
                FULL_PRODUCT_NAME = Demo.app
                """),
        ])
        let result = try await XcodeBuildRunner(execute: executor.execute).build(
            scheme: "Demo's App", workspace: "Demo Workspace.xcworkspace", project: "Ignored.xcodeproj",
            destination: "platform=iOS Simulator,id=ABC", buildSettings: ["FEATURE=it's on"]
        )
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.warnings, ["warning: heads up"])
        XCTAssertEqual(result.productPath, "/tmp/App Products/Demo.app")
        let commands = executor.commands
        XCTAssertEqual(commands.count, 2)
        XCTAssertTrue(commands[0].contains("'-workspace' 'Demo Workspace.xcworkspace'"))
        XCTAssertFalse(commands[0].contains("Ignored.xcodeproj"))
        XCTAssertTrue(commands[0].contains("'Demo'\\''s App'"))
        XCTAssertTrue(commands[0].hasSuffix("'build' 'FEATURE=it'\\''s on'"))
    }

    func testFailedBuildReturnsDiagnosticsWithoutResolvingProduct() async throws {
        let executor = ScriptedExecutor([.failure(GrantivaError.commandFailed("warning: w\nerror: broken", 65))])
        let result = try await XcodeBuildRunner(execute: executor.execute).build(scheme: "Demo", project: "Demo.xcodeproj", destination: "sim")
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.warnings, ["warning: w"])
        XCTAssertEqual(result.errors, ["error: broken"])
        XCTAssertEqual(executor.commands.count, 1)
        XCTAssertTrue(executor.commands[0].contains("'-project' 'Demo.xcodeproj'"))
    }

    func testUnexpectedBuildErrorPropagates() async {
        let executor = ScriptedExecutor([.failure(GrantivaError.invalidArgument("bad"))])
        do {
            _ = try await XcodeBuildRunner(execute: executor.execute).build(scheme: "Demo", destination: "sim")
            XCTFail("expected error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("bad"))
        }
    }

    func testTestCountsUseFinalExecutedSummaryNotSuiteLines() async throws {
        let output = """
        Test Suite 'Nested' passed
        Test Suite 'All tests' failed
        Executed 12 tests, with 2 failures in 1.0 seconds
        """
        let executor = ScriptedExecutor([.success(output)])
        let result = try await XcodeBuildRunner(execute: executor.execute).test(scheme: "Demo", destination: "sim")
        XCTAssertEqual(result.testsPassed, 10)
        XCTAssertEqual(result.testsFailed, 2)
    }

    func testSimctlOperationsQuoteValuesAndTrimContainer() async throws {
        let executor = ScriptedExecutor([.success(""), .success(""), .success(" /tmp/container \n"), .success(""), .success("")])
        let runner = XcodeBuildRunner(execute: executor.execute)
        try await runner.install(bundleId: "com.example", productPath: "/tmp/My App.app", udid: "A B")
        try await runner.launch(bundleId: "com.example", udid: "A B")
        let containerPath = try await runner.dataContainerPath(bundleId: "com.example", udid: "A B")
        XCTAssertEqual(containerPath, "/tmp/container")
        try await runner.terminate(bundleId: "com.example", udid: "A B")
        try await runner.uninstall(bundleId: "com.example", udid: "A B")
        XCTAssertEqual(executor.commands, [
            "xcrun simctl install 'A B' '/tmp/My App.app'",
            "xcrun simctl launch 'A B' 'com.example'",
            "xcrun simctl get_app_container 'A B' 'com.example' data",
            "xcrun simctl terminate 'A B' 'com.example'",
            "xcrun simctl uninstall 'A B' 'com.example'",
        ])
    }
}

private final class ScriptedExecutor: @unchecked Sendable {
    private let lock = NSLock()
    private var results: [Result<String, Error>]
    private var recorded: [String] = []
    init(_ results: [Result<String, Error>]) { self.results = results }
    func execute(_ command: String) async throws -> String {
        try lock.withLock {
            recorded.append(command)
            return try results.removeFirst().get()
        }
    }
    var commands: [String] { lock.withLock { recorded } }
}
