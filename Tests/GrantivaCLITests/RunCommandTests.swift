import ArgumentParser
import XCTest
@testable import GrantivaCLI
import GrantivaCore

final class RunCommandTests: XCTestCase {
    func testFailureScreenshotCommandQuotesHostilePathAndUDID() {
        XCTAssertEqual(
            RunCommand.failureScreenshotCommand(
                udid: "device'; touch /tmp/owned; '",
                path: "/tmp/report'; touch /tmp/owned; '/failure.png"
            ),
            "xcrun simctl io 'device'\\''; touch /tmp/owned; '\\''' screenshot '/tmp/report'\\''; touch /tmp/owned; '\\''/failure.png'"
        )
    }

    func testTimeoutMustBeAtLeastThirtySeconds() throws {
        XCTAssertThrowsError(try RunCommand.parse(["--timeout", "29"])) { error in
            XCTAssertTrue(String(describing: error).contains("at least 30 seconds"))
        }
        XCTAssertEqual(try RunCommand.parse(["--timeout", "30"]).timeout, 30)
    }

    func testParsesReadyFileAndRepeatedEnvironmentPairs() throws {
        let command = try RunCommand.parse([
            "--flow", "flows/advertise.yaml",
            "--keep-alive",
            "--ready-file", "/tmp/advertise.ready",
            "--env", "GRANTIVA_PORT=51234",
            "--env", "MODE=peripheral",
        ])
        XCTAssertEqual(command.readyFile, "/tmp/advertise.ready")
        XCTAssertEqual(command.env, ["GRANTIVA_PORT=51234", "MODE=peripheral"])
        XCTAssertTrue(command.keepAlive)
        XCTAssertEqual(try FlowEnvironment.parse(command.env)["GRANTIVA_PORT"], "51234")
    }

    func testMalformedEnvironmentPairIsRejectedWithAClearError() throws {
        let command = try RunCommand.parse(["--env", "PORT"])
        XCTAssertThrowsError(try FlowEnvironment.parse(command.env)) { error in
            let message = String(describing: error)
            XCTAssertTrue(message.contains("PORT"), message)
            XCTAssertTrue(message.contains("expected KEY=VALUE"), message)
        }
    }

    func testDefaultsLeaveReadyFileAndEnvironmentUnset() throws {
        let command = try RunCommand.parse([])
        XCTAssertNil(command.readyFile)
        XCTAssertTrue(command.env.isEmpty)
        XCTAssertNil(command.reportDir)
    }

    // MARK: - --ready-file contract

    /// Runs `command` from an empty directory, where project resolution fails
    /// immediately — the cheapest stand-in for every setup failure (missing
    /// project, bad scheme, build failure, no simulator) that never reaches the
    /// runner.
    private func runInADirectoryWithNoProject(_ command: RunCommand) async -> Error? {
        let fileManager = FileManager.default
        let previous = fileManager.currentDirectoryPath
        let scratch = fileManager.temporaryDirectory
            .appendingPathComponent("grantiva-run-tests-\(UUID().uuidString)")
        try? fileManager.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer {
            fileManager.changeCurrentDirectoryPath(previous)
            try? fileManager.removeItem(at: scratch)
        }
        fileManager.changeCurrentDirectoryPath(scratch.path)
        do {
            try await command.run()
            return nil
        } catch {
            return error
        }
    }

    // A setup failure used to write nothing at all, so the documented waiter —
    // `while [ ! -f "$f" ]; do sleep 0.2; done`, which has no timeout — wedged
    // the job until CI's global limit.
    func testASetupFailureStillWritesANonPassedVerdict() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-ready-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let readyFile = directory.appendingPathComponent("ready.json").path

        let command = try RunCommand.parse(["--ready-file", readyFile])
        let error = await runInADirectoryWithNoProject(command)

        XCTAssertNotNil(error, "resolving a project in an empty directory must fail")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: readyFile),
            "a waiter must be released even when the run failed before the runner started"
        )
        let state = try ReadyFile.read(readyFile)
        XCTAssertFalse(state.passed)
        XCTAssertEqual(state.status, "failed")
    }

    // A file left by a previous run made the waiter return instantly and read
    // that run's verdict — CI proceeding on a stale `passed` against a run that
    // never started.
    func testAStaleReadyFileIsReplacedRatherThanLeftToBeMisread() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-ready-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let readyFile = directory.appendingPathComponent("ready.json").path
        try ReadyFile.write(RunReadyState(status: "passed", flows: []), to: readyFile)

        let command = try RunCommand.parse(["--ready-file", readyFile])
        _ = await runInADirectoryWithNoProject(command)

        XCTAssertNotEqual(
            try ReadyFile.read(readyFile).status, "passed",
            "the previous run's verdict must not survive into this one"
        )
    }

    // Startup deletes the file, so a path that cannot be written has to be
    // rejected there — not after a long suite, with the verdict undeliverable.
    func testAnUnwritableReadyFilePathFailsBeforeAnyWork() async throws {
        let command = try RunCommand.parse([
            "--ready-file", "/System/definitely-not-writable/ready.json",
        ])
        let error = await runInADirectoryWithNoProject(command)
        let message = String(describing: error)
        XCTAssertTrue(message.contains("ready-file"), message)
    }
}
