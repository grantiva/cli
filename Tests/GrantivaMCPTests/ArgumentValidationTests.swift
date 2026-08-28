import Foundation
import GrantivaCore
import MCP
import XCTest

@testable import GrantivaMCP

/// Argument validation for the tools whose happy path is inseparable from `xcodebuild`
/// or `xcrun simctl`. Only the guard clauses that run *before* any side effect are
/// exercised here. The success paths cannot be reached without booting a simulator or
/// invoking xcodebuild, so they are intentionally out of scope for unit tests.
final class ArgumentValidationTests: XCTestCase {

    private let simManager = SimulatorManager.live
    private let buildRunner = XcodeBuildRunner()

    // MARK: - Build tools

    func testBuildWithoutASchemeOrConfigIsRejectedBeforeBooting() async throws {
        let result = try await BuildTools.build(
            runner: buildRunner, config: nil, simManager: simManager, arguments: [:]
        )
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(try textContent(of: result).contains("no scheme specified"))
    }

    func testTestWithoutASchemeOrConfigIsRejectedBeforeBooting() async throws {
        let result = try await BuildTools.test(
            runner: buildRunner, config: nil, simManager: simManager, arguments: [:]
        )
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(try textContent(of: result).contains("no scheme specified"))
    }

    func testRunWithoutASchemeOrConfigIsRejectedBeforeBooting() async throws {
        let result = try await BuildTools.run(
            runner: buildRunner, config: nil, simManager: simManager, arguments: [:]
        )
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(try textContent(of: result).contains("no scheme specified"))
    }

    func testRunWithASchemeButNoBundleIdIsRejectedBeforeBooting() async throws {
        let result = try await BuildTools.run(
            runner: buildRunner,
            config: GrantivaConfig(scheme: "App"),
            simManager: simManager,
            arguments: [:]
        )
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(try textContent(of: result).contains("no bundle_id in grantiva.yml"))
    }

    func testASchemeOfTheWrongTypeFallsBackToConfigAndIsThenRejected() async throws {
        // A non-string "scheme" must not be coerced into a scheme name.
        let result = try await BuildTools.build(
            runner: buildRunner, config: nil, simManager: simManager, arguments: ["scheme": .int(1)]
        )
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(try textContent(of: result).contains("no scheme specified"))
    }

    // MARK: - Simulator tools

    func testSimEnsureRequiresNameDeviceTypeAndRuntime() async throws {
        let incompleteArgumentSets: [[String: Value]] = [
            [:],
            ["name": .string("A")],
            ["name": .string("A"), "device_type": .string("iPhone 16")],
            ["device_type": .string("iPhone 16"), "runtime": .string("latest")],
            ["name": .string("A"), "device_type": .string("iPhone 16"), "runtime": .int(18)],
        ]
        for arguments in incompleteArgumentSets {
            let result = try await SimTools.ensure(simManager: simManager, arguments: arguments)
            XCTAssertEqual(result.isError, true, "Expected ensure to reject \(arguments.keys.sorted())")
            let message = try textContent(of: result)
            XCTAssertTrue(message.contains("'name', 'device_type', and 'runtime' are required"), message)
        }
    }

    func testSimDeleteRequiresAName() async throws {
        for arguments in [[:], ["name": Value.int(3)]] as [[String: Value]] {
            let result = try await SimTools.delete(simManager: simManager, arguments: arguments)
            XCTAssertEqual(result.isError, true, "Expected delete to reject \(arguments)")
            let message = try textContent(of: result)
            XCTAssertTrue(message.contains("'name' is required"), message)
        }
    }
}
