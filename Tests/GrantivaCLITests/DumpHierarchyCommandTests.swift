import Foundation
import GrantivaCore
import XCTest
@testable import GrantivaCLI

@available(macOS 15, *)
final class DumpHierarchyCommandTests: XCTestCase {
    private let simulator = "921A0945-7157-4533-BA1F-21E8132D3E40"

    func testAnExplicitPortWins() throws {
        let target = try DumpHierarchyCommand.resolveTarget(port: 8100, runnerSession: nil, keepAlive: nil)
        XCTAssertEqual(target.udid, "")
        XCTAssertEqual(target.port, 8100)
    }

    func testARunnerStartSessionCarriesItsDeviceAndPort() throws {
        let session = RunnerSessionInfo(pid: 1, wdaPort: 61211, bundleId: "x", udid: "emulator-5554", startedAt: Date())
        let target = try DumpHierarchyCommand.resolveTarget(port: nil, runnerSession: session, keepAlive: nil)
        XCTAssertEqual(target.udid, "emulator-5554")
        XCTAssertEqual(target.port, 61211)
    }

    func testAKeepAliveSessionWithPortZeroHasNoPort() throws {
        let keepAlive = KeepAliveSession(sessionId: "s", port: 0, pid: 1, udid: "emulator-5554", path: "/tmp/x")
        let target = try DumpHierarchyCommand.resolveTarget(port: nil, runnerSession: nil, keepAlive: keepAlive)
        XCTAssertEqual(target.udid, "emulator-5554")
        XCTAssertNil(target.port)
    }

    func testAnIOSKeepAliveSessionKeepsItsPort() throws {
        let keepAlive = KeepAliveSession(sessionId: "s", port: 8430, pid: 1, udid: simulator, path: "/tmp/x")
        let target = try DumpHierarchyCommand.resolveTarget(port: nil, runnerSession: nil, keepAlive: keepAlive)
        XCTAssertEqual(target.udid, simulator)
        XCTAssertEqual(target.port, 8430)
    }

    func testNothingFoundNamesBothWaysToStartASession() {
        XCTAssertThrowsError(try DumpHierarchyCommand.resolveTarget(port: nil, runnerSession: nil, keepAlive: nil)) { error in
            XCTAssertTrue("\(error)".contains("grantiva runner start"), "\(error)")
            XCTAssertTrue("\(error)".contains("--keep-alive"), "\(error)")
        }
    }

    func testAnAndroidTargetDumpsThroughThePlatform() async throws {
        var command = try DumpHierarchyCommand.parse(["--format", "tree"])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        try await command.dump(target: .init(udid: "emulator-5554", port: 61211))
        XCTAssertEqual(fake.calls, ["attachDriver(emulator-5554,61211)", "detach"])
    }

    func testUDIDAcceptsASerial() throws {
        XCTAssertNoThrow(try DumpHierarchyCommand.parse(["--udid", "emulator-5554"]))
        XCTAssertThrowsError(try DumpHierarchyCommand.parse(["--udid", "../x"]))
    }

    func testJSONFlagSelectsJSONOutput() throws {
        XCTAssertEqual(try DumpHierarchyCommand.parse(["--json"]).outputFormat, "json")
        XCTAssertEqual(try DumpHierarchyCommand.parse([]).outputFormat, "tree")
        XCTAssertEqual(try DumpHierarchyCommand.parse(["--format", "XML"]).outputFormat, "xml")
        XCTAssertEqual(try DumpHierarchyCommand.parse(["--json", "--format", "json"]).outputFormat, "json")
        for other in ["xml", "tree"] {
            XCTAssertThrowsError(try DumpHierarchyCommand.parse(["--json", "--format", other])) { error in
                XCTAssertEqual(DumpHierarchyCommand.exitCode(for: error), .validationFailure)
            }
        }
    }
}
