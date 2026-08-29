import ArgumentParser
import XCTest
@testable import GrantivaCLI
import GrantivaCore

final class SimulatorCommandTests: XCTestCase {
    func testEnsureParsesExactProvisioningTarget() throws {
        let command = try SimulatorCommand.Ensure.parse([
            "--name", "APP-302 iPhone 393x852",
            "--device-type", "iPhone 15 Pro",
            "--runtime", "latest", "--boot", "--json",
        ])
        XCTAssertEqual(command.name, "APP-302 iPhone 393x852")
        XCTAssertEqual(command.deviceType, "iPhone 15 Pro")
        XCTAssertEqual(command.runtime, "latest")
        XCTAssertTrue(command.boot)
        XCTAssertTrue(command.options.json)
    }

    func testDeleteRequiresAndParsesExactName() throws {
        let command = try SimulatorCommand.Delete.parse(["--name", "APP-302 iPhone 393x852", "--json"])
        XCTAssertEqual(command.name, "APP-302 iPhone 393x852")
        XCTAssertTrue(command.options.json)
    }

    func testSessionsSupportsJSON() throws {
        let command = try SimulatorCommand.Sessions.parse(["--json"])
        XCTAssertTrue(command.options.json)
    }

    func testTeardownAcceptsASessionIdentifier() throws {
        let command = try SimulatorCommand.Teardown.parse(["--session-id", "APP-652", "--json"])
        XCTAssertEqual(command.sessionId, "APP-652")
        XCTAssertNil(command.udid)
        XCTAssertFalse(command.force)
        XCTAssertTrue(command.options.json)
        XCTAssertNoThrow(try command.validate())
    }

    func testTeardownReclaimsBySimulatorUDID() throws {
        // The case `--session-id` cannot serve: a stranded run whose session
        // ledger is empty but whose simulator is still owned.
        let command = try SimulatorCommand.Teardown.parse([
            "--udid", "A1B2C3D4-1111-2222-3333-444455556666", "--force", "--json",
        ])
        XCTAssertEqual(command.udid, "A1B2C3D4-1111-2222-3333-444455556666")
        XCTAssertTrue(command.force)
        XCTAssertNil(command.sessionId)
        XCTAssertNoThrow(try command.validate())
    }

    func testTeardownRejectsBothSelectorsTogether() {
        XCTAssertThrowsError(
            try SimulatorCommand.Teardown.parse(["--session-id", "APP-652", "--udid", "SIM-1"])
        ) { error in
            XCTAssertTrue(String(describing: error).contains("mutually exclusive"), String(describing: error))
        }
    }

    func testTeardownRequiresOneSelector() {
        XCTAssertThrowsError(try SimulatorCommand.Teardown.parse([])) { error in
            XCTAssertTrue(
                String(describing: error).contains("--session-id <id> or --udid <UDID>"),
                String(describing: error)
            )
        }
    }

    func testEnsureNeedsOnlyAName() throws {
        let command = try SimulatorCommand.Ensure.parse(["--name", "iPhone 17"])
        XCTAssertEqual(command.name, "iPhone 17")
        XCTAssertNil(command.deviceType)
        XCTAssertNil(command.runtime)
        // Booting is the point of `ensure`; the shell function it replaces
        // created, booted, and waited for bootstatus.
        XCTAssertTrue(command.boot)
    }

    func testEnsureCanSkipBooting() throws {
        let command = try SimulatorCommand.Ensure.parse(["--name", "iPhone 17", "--no-boot"])
        XCTAssertFalse(command.boot)
    }

    func testProvisionReportContainsExactDisplayGeometry() throws {
        let report = SimulatorProvisionResult(
            name: "APP-302 iPhone 393x852", udid: "EXACT-UDID", deviceType: "iPhone 15 Pro",
            runtime: "iOS 18.0", created: true, state: "Booted",
            pointWidth: 393, pointHeight: 852, pixelWidth: 1179, pixelHeight: 2556, displayScale: 3
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(report)) as? [String: Any])
        XCTAssertEqual((object["point_dimensions"] as? [String: Int])?["width"], 393)
        XCTAssertEqual((object["point_dimensions"] as? [String: Int])?["height"], 852)
        XCTAssertEqual((object["pixel_dimensions"] as? [String: Int])?["width"], 1179)
        XCTAssertEqual((object["pixel_dimensions"] as? [String: Int])?["height"], 2556)
        XCTAssertEqual(object["display_scale"] as? Double, 3)
        XCTAssertEqual(object["created"] as? Bool, true)
        XCTAssertEqual(object["udid"] as? String, "EXACT-UDID")
    }
    func testCleanupSupportsJSON() throws {
        let command = try SimulatorCommand.Cleanup.parse(["--json"])
        XCTAssertTrue(command.options.json)
    }

    func testTeardownOutcomeEncodesDeletedFlag() throws {
        let outcome = SimulatorTeardownOutcome(
            session: ManagedSimulatorSession(
                udid: "EXACT-UDID", name: "TienLen Flow APP-652", sessionId: "APP-652",
                ownerPID: 1, acquiredAt: Date(), state: .active
            ),
            deleted: true
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(outcome)) as? [String: Any])
        XCTAssertEqual(object["deleted"] as? Bool, true)
        XCTAssertEqual((object["session"] as? [String: Any])?["sessionId"] as? String, "APP-652")
    }

}