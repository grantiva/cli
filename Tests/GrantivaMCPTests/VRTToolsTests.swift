import Foundation
import MCP
import XCTest
@testable import GrantivaMCP

final class VRTToolsTests: XCTestCase {
    func testCaptureDoesNotAdvertiseUnsupportedScreenFiltering() throws {
        let capture = try XCTUnwrap(VRTTools.definitions.first { $0.name == "grantiva_vrt_capture" })
        guard case .object(let schema) = capture.inputSchema,
              case .object(let properties) = schema["properties"] else {
            return XCTFail("Expected an object schema with properties")
        }
        XCTAssertTrue(properties.isEmpty)
    }

    func testStructuredDiffVerdictIsNotAToolError() {
        let result = VRTTools.compareFailureResult(
            message: #"{"passed":false,"screens":[{"screen_name":"home","status":"failed"}]}"#
        )
        XCTAssertNil(result.isError)
    }

    func testOperationalCompareFailureIsAToolError() {
        for message in ["No captures found", "Not authenticated", "grantiva diff compare --json"] {
            XCTAssertEqual(VRTTools.compareFailureResult(message: message).isError, true)
        }
    }

    func testCommandsCarryThePlatform() {
        XCTAssertEqual(VRTTools.captureCommand(platform: .ios), "grantiva diff capture --no-build --json --platform ios")
        XCTAssertEqual(VRTTools.compareCommand(platform: .android), "grantiva diff compare --json --platform android")
        XCTAssertEqual(VRTTools.approveCommand(platform: .android, screens: ["Home", "It's"]), "grantiva diff approve --json --platform android 'Home' 'It'\\''s'")
        XCTAssertEqual(VRTTools.approveCommand(platform: .ios, screens: []), "grantiva diff approve --json --platform ios")
    }
}
