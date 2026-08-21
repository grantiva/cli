import XCTest
@testable import GrantivaCore

final class SimulatorManagerTests: XCTestCase {
    func testIPhone15ProPixelMetricsConvertToExpectedPointGeometry() {
        let geometry = SimulatorManager.geometry(pixelWidth: 1179, pixelHeight: 2556, scale: 3)
        XCTAssertEqual(geometry.points, [393, 852])
        XCTAssertEqual(geometry.pixels, [1179, 2556])
        XCTAssertEqual(geometry.scale, 3)
    }

    func testCaptureTargetEncodesNamedSimulatorAndExactGeometry() throws {
        let target = CaptureSimulatorTarget(
            name: "APP-302 iPhone 393x852",
            udid: "12988233-030E-4824-A490-218913870F59",
            geometry: .init(points: [393, 852], pixels: [1179, 2556], scale: 3)
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(target)) as? [String: Any])
        XCTAssertEqual(object["name"] as? String, "APP-302 iPhone 393x852")
        XCTAssertEqual((object["point_dimensions"] as? [String: Int])?["width"], 393)
        XCTAssertEqual((object["point_dimensions"] as? [String: Int])?["height"], 852)
        XCTAssertEqual((object["pixel_dimensions"] as? [String: Int])?["width"], 1179)
        XCTAssertEqual((object["pixel_dimensions"] as? [String: Int])?["height"], 2556)
    }
}
