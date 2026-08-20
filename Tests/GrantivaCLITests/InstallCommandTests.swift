import Foundation
import XCTest
@testable import GrantivaCLI

final class InstallCommandTests: XCTestCase {
    func testNoLaunchSkipsLaunch() async throws {
        let command = try InstallCommand.parse(["--no-launch"])
        var didLaunch = false

        let status = try await command.completeInstall {
            didLaunch = true
        }

        XCTAssertEqual(status, .installed)
        XCTAssertFalse(didLaunch)
    }

    func testExistingBehaviorLaunchesByDefault() async throws {
        let command = try InstallCommand.parse([])
        var didLaunch = false

        let status = try await command.completeInstall {
            didLaunch = true
        }

        XCTAssertEqual(status, .launched)
        XCTAssertTrue(didLaunch)
    }

    func testNoLaunchFlagParses() throws {
        let command = try InstallCommand.parse(["--no-launch"])
        XCTAssertTrue(command.noLaunch)
    }

    func testDerivedDataPathParsesWithSpaces() throws {
        let path = "/private/tmp/Grantiva Runs/Tien Len DerivedData"
        let command = try InstallCommand.parse(["--derived-data-path", path])

        XCTAssertEqual(command.buildOptions.derivedDataPath, path)
        XCTAssertEqual(
            command.buildOptions.xcodeBuildSettings(merging: ["CODE_SIGNING_ALLOWED=NO"]),
            ["CODE_SIGNING_ALLOWED=NO", "-derivedDataPath", path]
        )
    }

    func testDerivedDataPathOverridesConfiguredPair() throws {
        let command = try InstallCommand.parse([
            "--derived-data-path", "/tmp/run-local-derived-data",
        ])

        XCTAssertEqual(
            command.buildOptions.xcodeBuildSettings(merging: [
                "-derivedDataPath", "/tmp/configured-derived-data",
                "CODE_SIGNING_ALLOWED=NO",
            ]),
            [
                "CODE_SIGNING_ALLOWED=NO",
                "-derivedDataPath", "/tmp/run-local-derived-data",
            ]
        )
    }

    func testDerivedDataPathOverridesConfiguredEqualsForm() throws {
        let command = try InstallCommand.parse([
            "--derived-data-path", "/tmp/run-local-derived-data",
        ])

        XCTAssertEqual(
            command.buildOptions.xcodeBuildSettings(merging: [
                "-derivedDataPath=/tmp/configured-derived-data",
            ]),
            ["-derivedDataPath", "/tmp/run-local-derived-data"]
        )
    }

    func testInstallResultJSONContainsFixturePreparationFields() throws {
        let result = InstallResult(
            status: .installed,
            scheme: "Tien Len",
            bundleId: "browning.tienlen",
            simulator: .init(
                name: "TienLen Flow offline-game",
                udid: "00000000-0000-0000-0000-000000000000"
            ),
            appPath: "/tmp/Derived Data/Tien Len.app",
            dataContainerPath: "/tmp/Simulator Data/Application Support"
        )

        let data = try JSONEncoder().encode(result)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let simulator = try XCTUnwrap(json["simulator"] as? [String: Any])

        XCTAssertEqual(json["status"] as? String, "installed")
        XCTAssertEqual(json["scheme"] as? String, "Tien Len")
        XCTAssertEqual(json["bundleId"] as? String, "browning.tienlen")
        XCTAssertEqual(json["appPath"] as? String, "/tmp/Derived Data/Tien Len.app")
        XCTAssertEqual(
            json["dataContainerPath"] as? String,
            "/tmp/Simulator Data/Application Support"
        )
        XCTAssertEqual(simulator["name"] as? String, "TienLen Flow offline-game")
        XCTAssertEqual(
            simulator["udid"] as? String,
            "00000000-0000-0000-0000-000000000000"
        )
    }
}
