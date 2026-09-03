import XCTest
@testable import GrantivaCLI

final class DiffCommandTests: XCTestCase {
    func testCaptureArtifactsReturnsCanonicalArtifactsInDeterministicOrder() throws {
        let artifacts = try DiffCommand.captureArtifacts(from: [
            "Settings%2FGeneral.png",
            "Home.png",
        ])

        XCTAssertEqual(artifacts, [
            .init(fileName: "Home.png", screenName: "Home"),
            .init(fileName: "Settings%2FGeneral.png", screenName: "Settings/General"),
        ])
    }

    func testCaptureArtifactsRejectsUndecodableScreenName() {
        XCTAssertThrowsError(try DiffCommand.captureArtifacts(from: ["%FF.png"])) { error in
            XCTAssertTrue(error.localizedDescription.contains("Invalid capture filename \"%FF.png\""))
        }
    }

    func testCaptureArtifactsRejectsNonCanonicalAlias() {
        XCTAssertThrowsError(try DiffCommand.captureArtifacts(from: ["%48ome.png"])) { error in
            XCTAssertTrue(error.localizedDescription.contains("Invalid capture filename \"%48ome.png\""))
        }
    }
}
