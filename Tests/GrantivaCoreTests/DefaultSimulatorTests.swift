import Foundation
import XCTest
@testable import GrantivaCore

/// K37: the default simulator name is chosen in one place.
final class DefaultSimulatorTests: XCTestCase {
    private let catalog = """
    {"devicetypes": [
      {"name":"iPhone 18 Pro","identifier":"t.18p","minRuntimeVersionString":"27.0.0","productFamily":"iPhone"},
      {"name":"iPhone 17 Pro","identifier":"t.17p","minRuntimeVersionString":"26.0.0","productFamily":"iPhone"},
      {"name":"iPhone 16","identifier":"t.16","minRuntimeVersionString":"18.0.0","productFamily":"iPhone"}
    ], "runtimes": [
      {"name":"iOS 26.0","identifier":"com.apple.CoreSimulator.SimRuntime.iOS-26-0","version":"26.0","isAvailable":true,"platform":"iOS"}
    ]}
    """

    func testTheDefaultIsTheNewestInstalledIPhone() {
        XCTAssertEqual(DefaultSimulator.name(catalogJSON: Data(catalog.utf8)), "iPhone 17 Pro")
    }

    func testWithoutACatalogTheDefaultIsTheFallback() {
        XCTAssertEqual(DefaultSimulator.name(catalogJSON: nil), DefaultSimulator.fallback)
        XCTAssertEqual(DefaultSimulator.name(catalogJSON: Data("not json".utf8)), DefaultSimulator.fallback)
    }

    func testTheProcessWideNameIsResolvedOrTheFallback() {
        XCTAssertEqual(DefaultSimulator.name, DefaultSimulator.resolved ?? DefaultSimulator.fallback)
        XCTAssertFalse(DefaultSimulator.name.isEmpty)
    }

    func testAMissingDefaultSimulatorSaysHowToCreateOrOverrideIt() async {
        let manager = SimulatorManager(execute: { _ in #"{"devices": {}}"# })
        do {
            _ = try await manager.exactDevice(nameOrUDID: DefaultSimulator.name)
            XCTFail("expected not found")
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            XCTAssertTrue(message.contains("Simulator not found: \"\(DefaultSimulator.name)\""), message)
            XCTAssertTrue(message.contains("grantiva simulator ensure --name \"\(DefaultSimulator.name)\""), message)
            XCTAssertTrue(message.contains("--simulator"), message)
        }
    }
}
