import XCTest
@testable import GrantivaCLI

final class BuildCommandTests: XCTestCase {
    func testBuildAcceptsDerivedDataPath() throws {
        let command = try BuildOnlyCommand.parse([
            "--derived-data-path", "/tmp/Grantiva DerivedData",
        ])

        XCTAssertEqual(command.derivedDataPath, "/tmp/Grantiva DerivedData")
    }

    func testBuildRejectsInstallOnlyBinaryFlags() {
        XCTAssertThrowsError(try BuildOnlyCommand.parse(["--app-file", "/tmp/Test.app"]))
        XCTAssertThrowsError(try BuildOnlyCommand.parse(["--no-build"]))
    }
}
