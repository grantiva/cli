import ArgumentParser
import XCTest
@testable import GrantivaCLI
import GrantivaCore

final class RunCommandTests: XCTestCase {
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
}
