import Foundation
import GrantivaCore
import MCP
import XCTest

@testable import GrantivaMCP

/// K57: `notifications/resources/updated` for the hierarchy follows only a
/// call that may have changed the UI, and only to a client that subscribed.
@available(macOS 15, *)
final class HierarchyNotificationTests: XCTestCase {
    private final class Notified: @unchecked Sendable {
        private let lock = NSLock()
        private var uris: [String] = []
        func record(_ uri: String) { lock.withLock { uris.append(uri) } }
        var all: [String] { lock.withLock { uris } }
    }

    private func call(
        _ registry: ToolRegistry, _ name: String, _ arguments: [String: Value], _ notified: Notified
    ) async throws -> CallTool.Result {
        try await registry.call(name: name, arguments: arguments, notify: { notified.record($0) })
    }

    func testNothingIsSentWithoutASubscription() async throws {
        let registry = MCPTestSupport.registry(driver: MCPTestSupport.fakeDriver(recorder: WDARecorder()))
        let notified = Notified()
        let result = try await call(registry, "grantiva_tap", ["label": .string("Gesture Lab")], notified)
        XCTAssertNil(result.isError)
        XCTAssertEqual(notified.all, [])
    }

    func testOnlyCallsThatMayHaveChangedTheUINotifyASubscriber() async throws {
        var driver = MCPTestSupport.fakeDriver(recorder: WDARecorder())
        driver.tapByLabel = { label in
            if label == "No Such Label" { throw GrantivaError.elementNotFound(label) }
        }
        let registry = MCPTestSupport.registry(driver: driver)
        await registry.subscriptions.subscribe("grantiva://hierarchy")
        let notified = Notified()

        let rejected = try await call(registry, "grantiva_script", ["steps": .array([.object(["bogus": .int(1)])])], notified)
        XCTAssertEqual(rejected.isError, true)
        let missing = try await call(registry, "grantiva_tap", ["label": .string("No Such Label")], notified)
        XCTAssertEqual(missing.isError, true)
        XCTAssertEqual(notified.all, [], "failed calls changed nothing")

        let tapped = try await call(registry, "grantiva_tap", ["label": .string("Gesture Lab")], notified)
        XCTAssertNil(tapped.isError)
        XCTAssertEqual(notified.all, ["grantiva://hierarchy"])

        await registry.subscriptions.unsubscribe("grantiva://hierarchy")
        _ = try await call(registry, "grantiva_tap", ["label": .string("Gesture Lab")], notified)
        XCTAssertEqual(notified.all.count, 1, "no notification after unsubscribing")
    }

    func testAScriptThatRanAStepBeforeFailingStillNotifies() async throws {
        var driver = MCPTestSupport.fakeDriver(recorder: WDARecorder())
        driver.tapByLabel = { label in
            if label == "Missing" { throw GrantivaError.elementNotFound(label) }
        }
        let registry = MCPTestSupport.registry(driver: driver)
        await registry.subscriptions.subscribe("grantiva://hierarchy")
        let notified = Notified()
        let result = try await call(registry, "grantiva_script", ["steps": .array([
            .object(["tap": .string("Gesture Lab")]), .object(["tap": .string("Missing")]),
        ])], notified)
        XCTAssertEqual(result.isError, true)
        XCTAssertEqual(notified.all, ["grantiva://hierarchy"])
    }
}
