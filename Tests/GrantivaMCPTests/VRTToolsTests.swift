import Foundation
import MCP
import XCTest
import GrantivaCore
@testable import GrantivaMCP

final class VRTToolsTests: XCTestCase {
    func testCaptureDoesNotAdvertiseUnsupportedScreenFiltering() throws {
        let capture = try XCTUnwrap(VRTTools.definitions.first { $0.name == "grantiva_vrt_capture" })
        guard case .object(let schema) = capture.inputSchema,
              case .object(let properties) = schema["properties"] else {
            return XCTFail("Expected an object schema with properties")
        }
        XCTAssertTrue(properties.isEmpty)
    }

    func testStructuredDiffVerdictIsNotAToolError() {
        let result = VRTTools.compareFailureResult(
            message: #"{"passed":false,"screens":[{"screen_name":"home","status":"failed"}]}"#
        )
        XCTAssertNil(result.isError)
    }

    func testOperationalCompareFailureIsAToolError() {
        for message in ["No captures found", "Not authenticated", "grantiva diff compare --json"] {
            XCTAssertEqual(VRTTools.compareFailureResult(message: message).isError, true)
        }
    }

    func testCommandsCarryThePlatform() {
        let exe = "/opt/grantiva 2/bin/grantiva"
        XCTAssertEqual(VRTTools.captureCommand(platform: .ios, executable: exe), "'/opt/grantiva 2/bin/grantiva' diff capture --no-build --json --platform ios")
        XCTAssertEqual(VRTTools.compareCommand(platform: .android, executable: exe), "'/opt/grantiva 2/bin/grantiva' diff compare --json --platform android")
        XCTAssertEqual(VRTTools.approveCommand(platform: .android, screens: ["Home", "It's"], executable: exe), "'/opt/grantiva 2/bin/grantiva' diff approve --json --platform android 'Home' 'It'\\''s'")
        XCTAssertEqual(VRTTools.approveCommand(platform: .ios, screens: [], executable: exe), "'/opt/grantiva 2/bin/grantiva' diff approve --json --platform ios")
    }

    /// C05: the tools run the binary that is serving MCP, never `grantiva` from PATH.
    func testCommandsStartWithTheRunningExecutablesAbsolutePath() throws {
        let running = try XCTUnwrap(Bundle.main.executablePath)
        XCTAssertTrue(running.hasPrefix("/"))
        XCTAssertEqual(VRTTools.executable, running)
        let prefix = shellQuoted(running) + " diff "
        XCTAssertTrue(VRTTools.captureCommand(platform: .ios).hasPrefix(prefix))
        XCTAssertTrue(VRTTools.compareCommand(platform: .ios).hasPrefix(prefix))
        XCTAssertTrue(VRTTools.approveCommand(platform: .android, screens: ["Home"]).hasPrefix(prefix))
        for command in [VRTTools.captureCommand(platform: .ios), VRTTools.compareCommand(platform: .android)] {
            XCTAssertFalse(command.hasPrefix("grantiva "), command)
        }
    }

    /// C05 repro: an older `grantiva` first on PATH is never invoked.
    func testHandlersIgnoreAGrantivaOnPath() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vrt-c05-\(UUID().uuidString)")
        let stubDir = dir.appendingPathComponent("path")
        try FileManager.default.createDirectory(at: stubDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let stub = stubDir.appendingPathComponent("grantiva")
        try "#!/bin/sh\necho \"stub $*\" >&2; exit 2\n".write(to: stub, atomically: true, encoding: .utf8)
        let own = dir.appendingPathComponent("own grantiva")
        try "#!/bin/sh\necho \"own $*\"\n".write(to: own, atomically: true, encoding: .utf8)
        for file in [stub, own] {
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        }

        // PATH is overridden only for the subprocesses, never for this test process.
        let path = ["PATH": "\(stubDir.path):\(ProcessInfo.processInfo.environment["PATH"] ?? "")"]
        let stubFirst = try await shell("command -v grantiva", environment: path)
        XCTAssertEqual(stubFirst, stub.path)

        let results = [
            try await VRTTools.capture(platform: .ios, arguments: [:], executable: own.path, environment: path),
            try await VRTTools.compare(platform: .android, arguments: [:], executable: own.path, environment: path),
            try await VRTTools.approve(platform: .ios, arguments: ["screens": .array([.string("Home")])], executable: own.path, environment: path),
        ]
        let texts = results.map { result -> String in
            guard case .text(let text, _, _) = result.content.first else { return "" }
            return text
        }
        XCTAssertEqual(texts, [
            "own diff capture --no-build --json --platform ios",
            "own diff compare --json --platform android",
            "own diff approve --json --platform ios Home",
        ])
        XCTAssertTrue(results.allSatisfy { $0.isError == nil })
    }
}
