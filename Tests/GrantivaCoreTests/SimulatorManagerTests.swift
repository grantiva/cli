import XCTest
@testable import GrantivaCore

final class SimulatorManagerTests: XCTestCase {
    // MARK: - I02: never guess among several booted simulators

    private func device(_ name: String, _ udid: String, _ state: String = "Booted") -> SimulatorDevice {
        SimulatorDevice(name: name, udid: udid, state: state, runtime: "iOS-26-0", isAvailable: true)
    }

    func testSoleBootedReturnsTheOnlyBootedSimulator() throws {
        let devices = [device("Off", "OFF", "Shutdown"), device("qa-ios-1", "QA-1")]
        XCTAssertEqual(try SimulatorManager.soleBooted(in: devices).udid, "QA-1")
    }

    func testSoleBootedRefusesToPickAmongSeveralAndNamesThem() {
        let devices = [device("iPhone 17 Pro", "B27D7D31"), device("qa-ios-1", "QA-1")]
        XCTAssertThrowsError(try SimulatorManager.soleBooted(in: devices)) { error in
            let message = error.localizedDescription
            XCTAssertTrue(message.contains("iPhone 17 Pro (B27D7D31)"), message)
            XCTAssertTrue(message.contains("qa-ios-1 (QA-1)"), message)
            XCTAssertTrue(message.contains("--simulator"), message)
            XCTAssertTrue(message.contains("simulator:"), message)
        }
    }

    func testSoleBootedWithNoneBootedIsSimulatorNotRunning() {
        XCTAssertThrowsError(try SimulatorManager.soleBooted(in: [device("Off", "OFF", "Shutdown")])) { error in
            guard case GrantivaError.simulatorNotRunning = error else { return XCTFail("\(error)") }
        }
    }

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

    // MARK: - Device type inference

    private let catalog: [(name: String, identifier: String)] = [
        ("iPhone 16", "com.apple.CoreSimulator.SimDeviceType.iPhone-16"),
        ("iPhone 17", "com.apple.CoreSimulator.SimDeviceType.iPhone-17"),
        ("iPhone 17 Pro", "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"),
        ("iPad Pro 11-inch (M4)", "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-11-inch-M4"),
    ]

    func testInfersTheDeviceTypeFromASimulatorName() {
        // `grantiva simulator ensure --name "iPhone 17"` must work on its own.
        let inferred = SimulatorManager.inferDeviceType(fromName: "iPhone 17", in: catalog)
        XCTAssertEqual(inferred?.identifier, "com.apple.CoreSimulator.SimDeviceType.iPhone-17")
    }

    func testTheLongestMatchingDeviceTypeWins() {
        let inferred = SimulatorManager.inferDeviceType(fromName: "BLE iPhone 17 Pro", in: catalog)
        XCTAssertEqual(inferred?.name, "iPhone 17 Pro")
    }

    func testInferenceIsCaseInsensitive() {
        XCTAssertEqual(
            SimulatorManager.inferDeviceType(fromName: "app-925 iphone 16", in: catalog)?.name,
            "iPhone 16"
        )
    }

    func testInferenceFailsWhenTheNameNamesNoDevice() {
        XCTAssertNil(SimulatorManager.inferDeviceType(fromName: "APP-652 device", in: catalog))
    }
}
