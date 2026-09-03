import Foundation
import XCTest
@testable import GrantivaCore

final class DoctorTests: XCTestCase {
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-doctor-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    // MARK: - a broken toolchain must not read as passing

    // `xcode-select -p` echoes $DEVELOPER_DIR back without checking it, so
    // `DEVELOPER_DIR=/nonexistent grantiva doctor` reported "✓ Xcode
    // /nonexistent" — the broken-CI-image case doctor exists to catch.
    func testXcodeCheckFailsWhenTheDeveloperDirectoryDoesNotExist() async throws {
        let previous = ProcessInfo.processInfo.environment["DEVELOPER_DIR"]
        setenv("DEVELOPER_DIR", scratch.appendingPathComponent("nonexistent").path, 1)
        defer {
            if let previous { setenv("DEVELOPER_DIR", previous, 1) } else { unsetenv("DEVELOPER_DIR") }
        }

        let check = await DoctorRunner().checkXcode()
        XCTAssertEqual(check.status, .error)
        XCTAssertNotNil(check.fix)
    }

    func testRunnerCheckReportsInstalledVersion() async throws {
        let runner = scratch.appendingPathComponent("grantiva-runner")
        let version = scratch.appendingPathComponent("version")
        try Data().write(to: runner)
        try "1.2.3".write(to: version, atomically: true, encoding: .utf8)

        let check = await DoctorRunner().checkRunner(
            runnerPath: runner.path,
            versionFilePath: version.path,
            expectedVersion: "1.2.3"
        )

        XCTAssertEqual(check.status, .ok)
        XCTAssertEqual(check.message, "grantiva-runner 1.2.3")
    }

    func testRunnerCheckWarnsWhenInstalledVersionIsStale() async throws {
        let runner = scratch.appendingPathComponent("grantiva-runner")
        let version = scratch.appendingPathComponent("version")
        try Data().write(to: runner)
        try "1.0.0".write(to: version, atomically: true, encoding: .utf8)

        let check = await DoctorRunner().checkRunner(
            runnerPath: runner.path,
            versionFilePath: version.path,
            expectedVersion: "2.0.0"
        )

        XCTAssertEqual(check.status, .warning)
        XCTAssertTrue(check.message.contains("1.0.0"), check.message)
        XCTAssertTrue(check.message.contains("2.0.0"), check.message)
        XCTAssertNotNil(check.fix)
    }

    func testRunnerCheckWarnsWhenVersionMarkerIsMissing() async throws {
        let runner = scratch.appendingPathComponent("grantiva-runner")
        try Data().write(to: runner)

        let check = await DoctorRunner().checkRunner(
            runnerPath: runner.path,
            versionFilePath: scratch.appendingPathComponent("missing-version").path,
            expectedVersion: "2.0.0"
        )

        XCTAssertEqual(check.status, .warning)
        XCTAssertTrue(check.message.contains("unknown"), check.message)
    }

    func testEmptyEnvironmentAPIKeyIsNotAuthenticated() {
        let check = DoctorRunner().checkGrantivaAuth(
            environment: ["GRANTIVA_API_KEY": "  \n"],
            storedCredentials: nil
        )

        XCTAssertEqual(check.status, .warning)
        XCTAssertTrue(check.message.contains("Not authenticated"), check.message)
    }

    // MARK: - exit status

    // `grantiva doctor || exit 1` as a CI preflight could never fire: doctor had
    // no exit-code path at all.
    func testAFailedRequiredCheckIsAFailure() {
        XCTAssertTrue(DoctorRunner.hasFailures(Self.sampleChecks))
    }

    // Optional checks are advisory and must not change the exit code — a
    // developer machine with no simulator booted and no grantiva.yml is fine.
    func testOptionalChecksAloneAreNotAFailure() {
        XCTAssertFalse(DoctorRunner.hasFailures([
            DoctorCheck(name: "Booted Simulator", status: .warning, message: "No simulator booted", fix: nil),
            DoctorCheck(name: "grantiva.yml", status: .warning, message: "Not found", fix: nil, section: .project),
            DoctorCheck(name: "Grantiva Auth", status: .warning, message: "Not authenticated", fix: nil, section: .cloud),
            DoctorCheck(name: "Xcode", status: .ok, message: "/Applications/Xcode.app", fix: nil),
        ]))
    }

    // MARK: - colour is for terminals

    // `grantiva doctor > log.txt` was writing raw SGR sequences into the file.
    func testFormatterEmitsNoEscapesWhenColourIsOff() {
        let output = DoctorFormatter(color: false).format(Self.sampleChecks)
        XCTAssertFalse(output.contains("\u{001B}"), "redirected output must carry no ANSI escapes")
        // The information the colour carried is still there in plain text.
        XCTAssertTrue(output.contains("✓"))
        XCTAssertTrue(output.contains("✗"))
        XCTAssertTrue(output.contains("Xcode not found"))
    }

    func testFormatterStillColoursWhenColourIsOn() {
        XCTAssertTrue(DoctorFormatter(color: true).format(Self.sampleChecks).contains("\u{001B}"))
    }

    func testNoColorEnvironmentVariableDisablesColour() {
        let previous = ProcessInfo.processInfo.environment["NO_COLOR"]
        setenv("NO_COLOR", "1", 1)
        defer {
            if let previous { setenv("NO_COLOR", previous, 1) } else { unsetenv("NO_COLOR") }
        }
        XCTAssertFalse(DoctorFormatter.terminalSupportsColor())
    }

    // MARK: - failures are visible in the footer

    func testFooterCountsFailuresAlongsidePassedAndOptional() {
        let output = DoctorFormatter(color: false).format(Self.sampleChecks)
        XCTAssertTrue(output.contains("1 passed"), output)
        XCTAssertTrue(output.contains("1 optional"), output)
        XCTAssertTrue(output.contains("1 failed"), output)
    }

    private static let sampleChecks: [DoctorCheck] = [
        DoctorCheck(name: "Runner", status: .ok, message: "grantiva-runner 1.0.0", fix: nil),
        DoctorCheck(
            name: "Xcode", status: .error, message: "Xcode not found",
            fix: "Install Xcode from the App Store"
        ),
        DoctorCheck(name: "Booted Simulator", status: .warning, message: "No simulator booted", fix: nil),
    ]
}
