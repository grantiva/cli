import Foundation
import XCTest
@testable import GrantivaCore

final class WDADeviceHomeTests: XCTestCase {
    private var home: String!
    private let fm = FileManager.default
    private let config = "sim-ios26.0-iphone"

    override func setUpWithError() throws {
        home = fm.temporaryDirectory.appendingPathComponent("grantiva-wda-home-\(UUID().uuidString)").path
        try fm.createDirectory(atPath: "\(home!)/drivers/ios", withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(atPath: home)
    }

    private func products(in root: String) -> String {
        "\(root)/cache/wda-builds/\(config)/DerivedData/Build/Products"
    }

    private func writeBuild(in root: String, port: String = "8100") throws {
        let dir = products(in: root)
        try fm.createDirectory(atPath: "\(dir)/Debug-iphonesimulator", withIntermediateDirectories: true)
        try "USE_PORT=\(port)".write(toFile: "\(dir)/WDA.xctestrun", atomically: true, encoding: .utf8)
        try "bin".write(toFile: "\(dir)/Debug-iphonesimulator/WebDriverAgentRunner-Runner", atomically: true, encoding: .utf8)
    }

    func testTwoSimulatorsGetDistinctRunnerHomesAndDerivedData() throws {
        let env1 = IOSPlatform().runnerEnvironment(runnerHome: home, deviceID: "AAAA-1111")
        let env2 = IOSPlatform().runnerEnvironment(runnerHome: home, deviceID: "BBBB-2222")
        let home1 = try XCTUnwrap(env1["MAESTRO_RUNNER_HOME"])
        let home2 = try XCTUnwrap(env2["MAESTRO_RUNNER_HOME"])
        XCTAssertEqual(home1, "\(home!)/devices/AAAA-1111")
        XCTAssertEqual(home2, "\(home!)/devices/BBBB-2222")
        XCTAssertNotEqual(products(in: home1), products(in: home2))
    }

    func testDeviceHomeClonesTheCachedBuildAndLinksDrivers() throws {
        try writeBuild(in: home)
        let deviceHome = try XCTUnwrap(WDADeviceHome.prepare(runnerHome: home, deviceID: "AAAA-1111"))
        XCTAssertEqual(try fm.destinationOfSymbolicLink(atPath: "\(deviceHome)/drivers"), "\(home!)/drivers")
        XCTAssertEqual(try String(contentsOfFile: "\(products(in: deviceHome))/WDA.xctestrun", encoding: .utf8), "USE_PORT=8100")
        XCTAssertTrue(fm.fileExists(atPath: "\(products(in: deviceHome))/Debug-iphonesimulator/WebDriverAgentRunner-Runner"))
    }

    func testEditingOneDevicesXctestrunLeavesTheOtherAndTheSharedBuildAlone() throws {
        try writeBuild(in: home)
        let home1 = try XCTUnwrap(WDADeviceHome.prepare(runnerHome: home, deviceID: "AAAA-1111"))
        let home2 = try XCTUnwrap(WDADeviceHome.prepare(runnerHome: home, deviceID: "BBBB-2222"))
        // The runner injects each session's port into its xctestrun in place.
        try "USE_PORT=8285".write(toFile: "\(products(in: home1))/WDA.xctestrun", atomically: true, encoding: .utf8)
        XCTAssertEqual(try String(contentsOfFile: "\(products(in: home2))/WDA.xctestrun", encoding: .utf8), "USE_PORT=8100")
        XCTAssertEqual(try String(contentsOfFile: "\(products(in: home))/WDA.xctestrun", encoding: .utf8), "USE_PORT=8100")
    }

    func testPrepareRefreshesAStaleDeviceCopy() throws {
        try writeBuild(in: home, port: "1")
        let deviceHome = try XCTUnwrap(WDADeviceHome.prepare(runnerHome: home, deviceID: "AAAA-1111"))
        try writeBuild(in: home, port: "2")
        _ = WDADeviceHome.prepare(runnerHome: home, deviceID: "AAAA-1111")
        XCTAssertEqual(try String(contentsOfFile: "\(products(in: deviceHome))/WDA.xctestrun", encoding: .utf8), "USE_PORT=2")
    }

    func testABuildMadeInADeviceHomeIsPromotedToTheSharedCache() throws {
        let home1 = try XCTUnwrap(WDADeviceHome.prepare(runnerHome: home, deviceID: "AAAA-1111"))
        try writeBuild(in: home1)  // the runner built WDA inside the device home
        let home2 = try XCTUnwrap(WDADeviceHome.prepare(runnerHome: home, deviceID: "BBBB-2222"))
        XCTAssertTrue(fm.fileExists(atPath: "\(products(in: home))/WDA.xctestrun"))
        XCTAssertTrue(fm.fileExists(atPath: "\(products(in: home2))/WDA.xctestrun"))
    }

    func testRejectsIdentifiersThatEscapeTheDevicesDirectory() {
        XCTAssertNil(WDADeviceHome.prepare(runnerHome: home, deviceID: "../x"))
        XCTAssertNil(WDADeviceHome.prepare(runnerHome: home, deviceID: ""))
    }
}
