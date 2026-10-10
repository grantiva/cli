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
        let deviceHome = try XCTUnwrap(WDADeviceHome.prepare(runnerHome: home, deviceID: "AAAA-1111", existingDeviceIDs: { nil }))
        XCTAssertEqual(try fm.destinationOfSymbolicLink(atPath: "\(deviceHome)/drivers"), "\(home!)/drivers")
        XCTAssertEqual(try String(contentsOfFile: "\(products(in: deviceHome))/WDA.xctestrun", encoding: .utf8), "USE_PORT=8100")
        XCTAssertTrue(fm.fileExists(atPath: "\(products(in: deviceHome))/Debug-iphonesimulator/WebDriverAgentRunner-Runner"))
    }

    func testEditingOneDevicesXctestrunLeavesTheOtherAndTheSharedBuildAlone() throws {
        try writeBuild(in: home)
        let home1 = try XCTUnwrap(WDADeviceHome.prepare(runnerHome: home, deviceID: "AAAA-1111", existingDeviceIDs: { nil }))
        let home2 = try XCTUnwrap(WDADeviceHome.prepare(runnerHome: home, deviceID: "BBBB-2222", existingDeviceIDs: { nil }))
        // The runner injects each session's port into its xctestrun in place.
        try "USE_PORT=8285".write(toFile: "\(products(in: home1))/WDA.xctestrun", atomically: true, encoding: .utf8)
        XCTAssertEqual(try String(contentsOfFile: "\(products(in: home2))/WDA.xctestrun", encoding: .utf8), "USE_PORT=8100")
        XCTAssertEqual(try String(contentsOfFile: "\(products(in: home))/WDA.xctestrun", encoding: .utf8), "USE_PORT=8100")
    }

    func testPrepareRefreshesAStaleDeviceCopy() throws {
        try writeBuild(in: home, port: "1")
        let deviceHome = try XCTUnwrap(WDADeviceHome.prepare(runnerHome: home, deviceID: "AAAA-1111", existingDeviceIDs: { nil }))
        try writeBuild(in: home, port: "2")
        _ = WDADeviceHome.prepare(runnerHome: home, deviceID: "AAAA-1111", existingDeviceIDs: { nil })
        XCTAssertEqual(try String(contentsOfFile: "\(products(in: deviceHome))/WDA.xctestrun", encoding: .utf8), "USE_PORT=2")
    }

    func testABuildMadeInADeviceHomeIsPromotedWhenTheRunEnds() throws {
        let home1 = try XCTUnwrap(WDADeviceHome.prepare(runnerHome: home, deviceID: "AAAA-1111", existingDeviceIDs: { nil }))
        try writeBuild(in: home1)  // the runner built WDA inside the device home
        IOSPlatform().runnerFinished(runnerHome: home, deviceID: "AAAA-1111")
        XCTAssertTrue(fm.fileExists(atPath: "\(products(in: home))/WDA.xctestrun"))
        let home2 = try XCTUnwrap(WDADeviceHome.prepare(runnerHome: home, deviceID: "BBBB-2222", existingDeviceIDs: { nil }))
        XCTAssertTrue(fm.fileExists(atPath: "\(products(in: home2))/WDA.xctestrun"))
        let build = "\(home!)/cache/wda-builds/\(config)/DerivedData/Build"
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: build).filter { $0.hasPrefix(".Products-") }, [], "staging leftovers")
    }

    func testABuildDeletedFromTheSharedCacheIsNotResurrected() throws {
        try writeBuild(in: home)
        let home1 = try XCTUnwrap(WDADeviceHome.prepare(runnerHome: home, deviceID: "AAAA-1111", existingDeviceIDs: { nil }))
        _ = try XCTUnwrap(WDADeviceHome.prepare(runnerHome: home, deviceID: "BBBB-2222", existingDeviceIDs: { nil }))
        // The user clears the shared cache to force a WDA rebuild.
        try fm.removeItem(atPath: "\(home!)/cache/wda-builds/\(config)")
        _ = try XCTUnwrap(WDADeviceHome.prepare(runnerHome: home, deviceID: "AAAA-1111", existingDeviceIDs: { nil }))
        XCTAssertFalse(fm.fileExists(atPath: "\(home1)/cache/wda-builds/\(config)"), "stale device copy kept")
        // Neither the next run's promotion nor another device's leftovers bring it back.
        IOSPlatform().runnerFinished(runnerHome: home, deviceID: "AAAA-1111")
        _ = WDADeviceHome.prepare(runnerHome: home, deviceID: "BBBB-2222", existingDeviceIDs: { nil })
        IOSPlatform().runnerFinished(runnerHome: home, deviceID: "BBBB-2222")
        XCTAssertFalse(fm.fileExists(atPath: "\(products(in: home))/WDA.xctestrun"))
    }

    func testHomesOfSimulatorsThatNoLongerExistArePruned() throws {
        _ = try XCTUnwrap(WDADeviceHome.prepare(runnerHome: home, deviceID: "AAAA-1111", existingDeviceIDs: { nil }))
        _ = try XCTUnwrap(WDADeviceHome.prepare(runnerHome: home, deviceID: "BBBB-2222", existingDeviceIDs: { nil }))
        _ = try XCTUnwrap(WDADeviceHome.prepare(runnerHome: home, deviceID: "CCCC-3333", existingDeviceIDs: { nil }))
        // simctl lists only BBBB; AAAA was deleted, CCCC is the device being prepared.
        _ = try XCTUnwrap(WDADeviceHome.prepare(runnerHome: home, deviceID: "CCCC-3333", existingDeviceIDs: { ["BBBB-2222"] }))
        XCTAssertFalse(fm.fileExists(atPath: WDADeviceHome.path(runnerHome: home, deviceID: "AAAA-1111")))
        XCTAssertTrue(fm.fileExists(atPath: WDADeviceHome.path(runnerHome: home, deviceID: "BBBB-2222")))
        XCTAssertTrue(fm.fileExists(atPath: WDADeviceHome.path(runnerHome: home, deviceID: "CCCC-3333")))
    }

    func testNothingIsPrunedWhenSimulatorsCannotBeListed() throws {
        _ = try XCTUnwrap(WDADeviceHome.prepare(runnerHome: home, deviceID: "AAAA-1111", existingDeviceIDs: { nil }))
        _ = try XCTUnwrap(WDADeviceHome.prepare(runnerHome: home, deviceID: "BBBB-2222", existingDeviceIDs: { nil }))
        XCTAssertTrue(fm.fileExists(atPath: WDADeviceHome.path(runnerHome: home, deviceID: "AAAA-1111")))
    }

    func testRemoveDeletesTheDeviceHome() throws {
        let deviceHome = try XCTUnwrap(WDADeviceHome.prepare(runnerHome: home, deviceID: "AAAA-1111", existingDeviceIDs: { nil }))
        WDADeviceHome.remove(runnerHome: home, deviceID: "AAAA-1111")
        XCTAssertFalse(fm.fileExists(atPath: deviceHome))
        XCTAssertTrue(fm.fileExists(atPath: "\(home!)/drivers"), "shared drivers untouched")
    }

    func testTheBuildsLockIsExclusive() throws {
        let builds = "\(home!)/cache/wda-builds"
        try fm.createDirectory(atPath: builds, withIntermediateDirectories: true)
        let held = expectation(description: "first holder inside")
        let release = DispatchSemaphore(value: 0)
        let order = OrderLog()
        DispatchQueue.global().async {
            WDADeviceHome.withBuildsLock(builds) {
                order.append("first-in")
                held.fulfill()
                release.wait()
                order.append("first-out")
            }
        }
        wait(for: [held], timeout: 5)
        let second = expectation(description: "second holder")
        DispatchQueue.global().async {
            WDADeviceHome.withBuildsLock(builds) { order.append("second-in") }
            second.fulfill()
        }
        Thread.sleep(forTimeInterval: 0.2)
        release.signal()
        wait(for: [second], timeout: 5)
        XCTAssertEqual(order.entries, ["first-in", "first-out", "second-in"])
    }

    func testRejectsIdentifiersThatEscapeTheDevicesDirectory() {
        XCTAssertNil(WDADeviceHome.prepare(runnerHome: home, deviceID: "../x"))
        XCTAssertNil(WDADeviceHome.prepare(runnerHome: home, deviceID: ""))
    }
}

private final class OrderLog: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []
    func append(_ value: String) { lock.lock(); values.append(value); lock.unlock() }
    var entries: [String] { lock.lock(); defer { lock.unlock() }; return values }
}
