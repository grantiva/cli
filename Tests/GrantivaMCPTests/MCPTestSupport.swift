import Foundation
import GrantivaCore
import MCP
import XCTest

@testable import GrantivaMCP

/// Thread-safe recorder for calls made against the fake `WDAClient`.
final class WDARecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    func record(_ entry: String) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(entry)
    }

    var calls: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

enum MCPTestSupport {
    /// An empty-but-valid hierarchy payload.
    static let emptyHierarchyJSON = #"{"type":"XCUIElementTypeApplication","children":[]}"#

    /// Builds a `WDAClient` whose every call is recorded and whose responses are fixtures.
    /// Nothing here touches the network, a simulator, or the filesystem.
    static func fakeWDA(
        recorder: WDARecorder,
        hierarchyJSON: String = emptyHierarchyJSON,
        screenshotBytes: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
    ) -> WDAClient {
        WDAClient(
            status: { WDAStatus(sessionId: "test-session", ready: true) },
            hierarchy: {
                recorder.record("hierarchy")
                let object = try JSONSerialization.jsonObject(with: Data(hierarchyJSON.utf8))
                return object as? [String: Any] ?? [:]
            },
            hierarchyXML: {
                recorder.record("hierarchyXML")
                return "<AppiumAUT/>"
            },
            tapByLabel: { label in recorder.record("tapByLabel(\(label))") },
            tapByCoordinate: { x, y in recorder.record("tapByCoordinate(\(x),\(y))") },
            typeText: { text in recorder.record("typeText(\(text))") },
            swipe: { direction in recorder.record("swipe(\(direction))") },
            screenshot: {
                recorder.record("screenshot")
                return Data(screenshotBytes)
            }
        )
    }

    /// A session with no UDID, which forces the screenshot tool down the WDA path
    /// instead of shelling out to `xcrun simctl`.
    static func sessionWithoutUDID() -> RunnerSessionInfo {
        RunnerSessionInfo(pid: 0, wdaPort: 8100, bundleId: "", udid: "", startedAt: Date())
    }

    static func registry(
        wda: WDAClient,
        config: GrantivaConfig? = nil,
        session: RunnerSessionInfo? = nil
    ) -> ToolRegistry {
        ToolRegistry(
            wda: wda,
            config: config,
            session: session ?? sessionWithoutUDID(),
            simulatorManager: SimulatorManager.live,
            buildRunner: XcodeBuildRunner()
        )
    }

    /// A `Server` that was never connected to a transport. Notification sends against it
    /// fail fast (and the registry swallows that), so it is safe to use in tests.
    static func disconnectedServer() -> Server {
        Server(name: "grantiva-test", version: "0.0.0")
    }
}

// MARK: - Assertions

extension XCTestCase {
    /// Extracts the concatenated text of a tool result, failing if there is none.
    func textContent(
        of result: CallTool.Result,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> String {
        let texts: [String] = result.content.compactMap {
            if case .text(let text, _, _) = $0 { return text }
            return nil
        }
        if texts.isEmpty {
            XCTFail("Expected text content, got \(result.content)", file: file, line: line)
            throw XCTSkip("no text content")
        }
        return texts.joined(separator: "\n")
    }

    func imageContent(
        of result: CallTool.Result,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> (data: String, mimeType: String) {
        for item in result.content {
            if case .image(let data, let mimeType, _, _) = item { return (data, mimeType) }
        }
        XCTFail("Expected image content, got \(result.content)", file: file, line: line)
        throw XCTSkip("no image content")
    }
}
