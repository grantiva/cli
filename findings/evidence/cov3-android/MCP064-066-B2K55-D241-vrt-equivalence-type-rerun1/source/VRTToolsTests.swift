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

    /// K60: argument arrays, never a shell string; screen names pass verbatim.
    func testCommandsAreArgumentArraysThatCarryThePlatform() {
        let exe = "/opt/grantiva 2/bin/grantiva"
        XCTAssertEqual(VRTTools.captureCommand(platform: .ios, executable: exe), [exe, "diff", "capture", "--no-build", "--json", "--platform", "ios"])
        XCTAssertEqual(VRTTools.compareCommand(platform: .android, executable: exe), [exe, "diff", "compare", "--json", "--platform", "android"])
        XCTAssertEqual(
            VRTTools.approveCommand(platform: .android, screens: ["Home; touch x", "It's", "$(touch y)"], executable: exe),
            [exe, "diff", "approve", "--json", "--platform", "android", "Home; touch x", "It's", "$(touch y)"]
        )
        XCTAssertEqual(VRTTools.approveCommand(platform: .ios, screens: [], executable: exe), [exe, "diff", "approve", "--json", "--platform", "ios"])
    }

    /// C05: the tools run the binary that is serving MCP, never `grantiva` from PATH.
    func testCommandsStartWithTheRunningExecutablesAbsolutePath() throws {
        let running = try XCTUnwrap(Bundle.main.executablePath)
        XCTAssertTrue(running.hasPrefix("/"))
        XCTAssertEqual(VRTTools.executable, running)
        XCTAssertEqual(VRTTools.captureCommand(platform: .ios).first, running)
        XCTAssertEqual(VRTTools.compareCommand(platform: .ios).first, running)
        XCTAssertEqual(VRTTools.approveCommand(platform: .android, screens: ["Home"]).first, running)
    }

    private func script(_ body: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vrt-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("grantiva")
        try "#!/bin/sh\n\(body)\n".write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        return file
    }

    /// K60 behaviour: shell metacharacters in screen names reach the CLI as
    /// one argument each and run nothing.
    func testScreenNamesAreNeverInterpretedByAShell() async throws {
        let own = try script(#"for a in "$@"; do echo "[$a]"; done"#)
        let marker = own.deletingLastPathComponent().appendingPathComponent("pwned")
        let result = try await VRTTools.approve(
            platform: .ios,
            arguments: ["screens": .array([.string("Home; touch \(marker.path)"), .string("$(touch \(marker.path)2)")])],
            executable: own.path
        )
        let text = try textContent(of: result)
        XCTAssertTrue(text.contains("[Home; touch \(marker.path)]"), text)
        XCTAssertTrue(text.contains("[$(touch \(marker.path)2)]"), text)
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path + "2"))
    }

    /// K59: capture, compare and approve fail in one shape: `Error: ` once.
    func testFailuresShareOnePrefix() async throws {
        let own = try script(#"echo "Error: x" >&2; exit 1"#)
        let results = [
            try await VRTTools.capture(platform: .ios, arguments: [:], executable: own.path),
            try await VRTTools.compare(platform: .ios, arguments: [:], executable: own.path),
            try await VRTTools.approve(platform: .ios, arguments: [:], executable: own.path),
        ]
        for result in results {
            XCTAssertEqual(result.isError, true)
            XCTAssertEqual(try textContent(of: result), "Error: x")
        }
        let plain = try script(#"echo "No captures found in .grantiva/captures. Run: grantiva diff capture" >&2; exit 1"#)
        let approve = try await VRTTools.approve(platform: .ios, arguments: [:], executable: plain.path)
        XCTAssertEqual(try textContent(of: approve), "Error: No captures found in .grantiva/captures. Run: grantiva diff capture")
        XCTAssertEqual(VRTTools.failure("grantiva.yml not found at /x/grantiva.yml. Create one with grantiva init.").content.count, 1)
        XCTAssertEqual(try textContent(of: VRTTools.failure("Error: Error: y")), "Error: y")
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
