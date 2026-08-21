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

    func testTeardownRequiresSessionIdentifier() throws {
        let command = try SimulatorCommand.Teardown.parse(["--session-id", "APP-652", "--json"])
        XCTAssertEqual(command.sessionId, "APP-652")
        XCTAssertTrue(command.options.json)
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
}
