import Darwin
import Foundation
import XCTest
@testable import GrantivaCore

/// Covers the spawn behaviour that lets a cancelled run reap everything it
/// started. The full simulator path (grantiva-runner → WebDriverAgent's
/// xcodebuild → simctl diagnose) cannot run in a unit test, but the property
/// that makes reaping work — one process group per runner, signalled as a unit —
/// is exercised here with a stand-in process tree.
final class ChildProcessTests: XCTestCase {
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-child-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    private func devNullOutput() throws -> Int32 {
        let descriptor = Darwin.open("/dev/null", O_WRONLY)
        XCTAssertGreaterThanOrEqual(descriptor, 0)
        return descriptor
    }

    func testChildIsLeaderOfItsOwnProcessGroup() throws {
        let output = try devNullOutput()
        defer { Darwin.close(output) }

        let child = try ChildProcess.spawn(
            executable: "/bin/sh",
            arguments: ["-c", "sleep 30"],
            stdout: output,
            stderr: output
        )
        defer { child.terminateGroup(gracePeriod: 1) }

        // Own group, not grantiva's: `kill(-pgid, …)` can therefore target the
        // runner tree without also signalling grantiva itself.
        XCTAssertEqual(getpgid(child.pid), child.pid)
        XCTAssertNotEqual(child.processGroup, getpgrp())
    }

    func testTerminateGroupReapsGrandchildren() throws {
        let output = try devNullOutput()
        defer { Darwin.close(output) }

        // Stands in for grantiva-runner starting WebDriverAgent's xcodebuild:
        // a grandchild that outlives the direct child unless the whole group is
        // signalled.
        let pidFile = scratch.appendingPathComponent("grandchild.pid").path
        let child = try ChildProcess.spawn(
            executable: "/bin/sh",
            arguments: ["-c", "sleep 60 & echo $! > \(pidFile); sleep 60"],
            stdout: output,
            stderr: output
        )

        var grandchild: pid_t = 0
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if let text = try? String(contentsOfFile: pidFile, encoding: .utf8),
               let parsed = pid_t(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                grandchild = parsed
                break
            }
            usleep(50_000)
        }
        XCTAssertGreaterThan(grandchild, 0, "grandchild never started")
        XCTAssertEqual(kill(grandchild, 0), 0, "grandchild should be alive before teardown")

        child.terminateGroup(gracePeriod: 2)
        child.wait()

        let gone = Date().addingTimeInterval(5)
        while Date() < gone, kill(grandchild, 0) == 0 {
            usleep(50_000)
        }
        XCTAssertNotEqual(kill(grandchild, 0), 0, "grandchild survived the group teardown")
    }

    func testExitStatusIsReported() throws {
        let output = try devNullOutput()
        defer { Darwin.close(output) }

        let child = try ChildProcess.spawn(
            executable: "/bin/sh",
            arguments: ["-c", "exit 7"],
            stdout: output,
            stderr: output
        )
        XCTAssertEqual(child.wait(), 7)
    }

    func testTerminationStatusDecoding() {
        XCTAssertEqual(ChildProcess.terminationStatus(raw: 7 << 8), 7) // exit(7)
        XCTAssertEqual(ChildProcess.terminationStatus(raw: SIGTERM), SIGTERM) // killed
    }

    func testWorkingDirectoryIsApplied() throws {
        let outPath = scratch.appendingPathComponent("cwd.txt").path
        FileManager.default.createFile(atPath: outPath, contents: nil)
        let outFD = Darwin.open(outPath, O_WRONLY)
        defer { Darwin.close(outFD) }

        let child = try ChildProcess.spawn(
            executable: "/bin/sh",
            arguments: ["-c", "pwd"],
            workingDirectory: "/tmp",
            stdout: outFD,
            stderr: outFD
        )
        XCTAssertEqual(child.wait(), 0)
        let text = try String(contentsOfFile: outPath, encoding: .utf8)
        XCTAssertTrue(text.contains("/tmp"), text)
    }

    func testRunnerSessionRejectsALiveUnrelatedProcess() throws {
        let output = try devNullOutput()
        defer { Darwin.close(output) }
        let child = try ChildProcess.spawn(
            executable: "/bin/sleep",
            arguments: ["30"],
            stdout: output,
            stderr: output
        )
        defer {
            child.terminateGroup(gracePeriod: 1)
            child.wait()
        }

        let unrelated = RunnerSessionInfo(
            pid: child.pid, wdaPort: 8100, bundleId: "example", udid: "device", startedAt: Date(),
            executablePath: "/bin/sh"
        )
        XCTAssertTrue(unrelated.isAlive)
        XCTAssertFalse(unrelated.ownsRunningProcess)

        let owner = RunnerSessionInfo(
            pid: child.pid, wdaPort: 8100, bundleId: "example", udid: "device", startedAt: Date(),
            executablePath: "/bin/sleep"
        )
        XCTAssertTrue(owner.ownsRunningProcess)
    }
}
