import Foundation
import XCTest
@testable import GrantivaCore

/// K33: the debug lines `--verbose` prints for long-running subprocesses.
final class SubprocessLogTests: XCTestCase {
    func testArgumentsAreQuotedOnlyWhenTheyNeedIt() {
        XCTAssertEqual(
            SubprocessLog.commandLine(executable: "/usr/bin/xcrun", arguments: ["simctl", "io", "ABC", "recordVideo", "--codec=h264", "/tmp/a b.mp4"], environment: [:]),
            "/usr/bin/xcrun simctl io ABC recordVideo --codec=h264 '/tmp/a b.mp4'"
        )
    }

    func testSecretsAreNeverLogged() {
        let line = SubprocessLog.commandLine(
            executable: "/bin/runner", arguments: ["--api-key", "gk_live_secret", "--token=abc123", "x=gk_live_secret"],
            environment: ["GRANTIVA_API_KEY": "gk_live_secret"]
        )
        XCTAssertFalse(line.contains("gk_live_secret"), line)
        XCTAssertFalse(line.contains("abc123"), line)
        XCTAssertEqual(line, "/bin/runner --api-key '<redacted>' '--token=<redacted>' 'x=<redacted>'")
    }

    func testEndedLines() {
        let lines = SubprocessLog.capturing {
            SubprocessLog.ended(executable: "/bin/x", arguments: ["a"], status: 0, signal: nil)
            SubprocessLog.ended(executable: "/bin/x", arguments: ["a"], status: 1, signal: nil)
            SubprocessLog.ended(executable: "/bin/x", arguments: ["a"], status: 0, signal: SIGINT)
            SubprocessLog.ended(executable: "/bin/x", arguments: ["a"], status: 0, signal: SIGKILL)
        }
        XCTAssertEqual(lines, ["exit 0: /bin/x a", "exit 1: /bin/x a", "stopped by SIGINT: /bin/x a", "stopped by SIGKILL: /bin/x a"])
    }

    /// The simctl recorder is a Foundation `Process`; its start and end go
    /// through the same helpers.
    func testAFoundationProcessIsLoggedWhenItStartsAndEnds() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "exit 4"]
        let lines = try SubprocessLog.capturing {
            try SubprocessLog.run(process)
            process.waitUntilExit()
            SubprocessLog.ended(process)
        }
        XCTAssertEqual(lines, ["$ /bin/sh -c 'exit 4'", "exit 4: /bin/sh -c 'exit 4'"])
    }

    func testIOSRecorderCommandIsLogged() throws {
        let log = FileHandle.nullDevice
        let recorder = IOSPlatform.makeRecorder(deviceID: "ABC", path: "/tmp/r.mp4", log: log)
        XCTAssertEqual(
            SubprocessLog.commandLine(of: recorder),
            "/usr/bin/xcrun simctl io ABC recordVideo --codec=h264 /tmp/r.mp4"
        )
    }
}
