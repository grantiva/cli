import Foundation
import XCTest
@testable import GrantivaCore

final class SimulatorUDIDTests: XCTestCase {
    func testAcceptsTheFormSimctlPrints() {
        XCTAssertTrue(SimulatorUDID.isWellFormed("921A0945-7157-4533-BA1F-21E8132D3E40"))
    }

    // The process-inspection path lowercases before comparing, so a lowercased
    // UDID works end to end; rejecting it would break scripts piping through tr.
    func testAcceptsALowercasedUDID() {
        XCTAssertTrue(SimulatorUDID.isWellFormed("921a0945-7157-4533-ba1f-21e8132d3e40"))
    }

    func testRejectsTheUnsetShellVariableAndOtherNonUDIDs() {
        XCTAssertFalse(SimulatorUDID.isWellFormed(""))
        XCTAssertFalse(SimulatorUDID.isWellFormed("not-a-udid-at-all"))
        XCTAssertFalse(SimulatorUDID.isWellFormed("SIM-1"))
        // Right shape, non-hex.
        XCTAssertFalse(SimulatorUDID.isWellFormed("ZZZZZZZZ-7157-4533-BA1F-21E8132D3E40"))
        // Right characters, wrong grouping.
        XCTAssertFalse(SimulatorUDID.isWellFormed("921A09457157-4533-BA1F-21E8132D3E40"))
        XCTAssertFalse(SimulatorUDID.isWellFormed("921A0945-7157-4533-BA1F-21E8132D3E40-9"))
    }

    func testValidateNamesTheUnsetVariableCase() {
        XCTAssertThrowsError(try SimulatorUDID.validate("")) { error in
            XCTAssertTrue(String(describing: error).contains("unset"), String(describing: error))
        }
        XCTAssertThrowsError(try SimulatorUDID.validateSessionID("   ")) { error in
            XCTAssertTrue(String(describing: error).contains("unset"), String(describing: error))
        }
    }

    func testValidateTrimsSurroundingWhitespace() throws {
        XCTAssertEqual(
            try SimulatorUDID.validate("  921A0945-7157-4533-BA1F-21E8132D3E40\n"),
            "921A0945-7157-4533-BA1F-21E8132D3E40"
        )
        XCTAssertEqual(try SimulatorUDID.validateSessionID(" APP-652 "), "APP-652")
    }

    // Shape only, deliberately: reclaiming a simulator that was already deleted
    // — killing what it stranded, breaking its lease — is what `--force` is for,
    // so a well-formed UDID naming no live device must still be accepted.
    func testAWellFormedUDIDForADeletedDeviceIsStillAccepted() throws {
        XCTAssertEqual(
            try SimulatorUDID.validate("DEADBEEF-0000-4000-8000-000000000001"),
            "DEADBEEF-0000-4000-8000-000000000001"
        )
    }
}
