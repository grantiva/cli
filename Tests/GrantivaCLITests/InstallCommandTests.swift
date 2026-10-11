import Foundation
import XCTest
@testable import GrantivaCLI
import GrantivaCore

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

    /// A10: Android names the application ID and the adb serial.
    func testAndroidInstallResultJSONUsesAndroidKeys() throws {
        let result = AndroidInstallResult(
            status: .installed,
            applicationId: "com.kylebrowning.landmarks",
            device: .init(name: "Pixel_8_API_35", serial: "emulator-5554"),
            appPath: "/tmp/app-free-debug.apk"
        )
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(JSONOutput.string(result).utf8)) as? [String: Any]
        )
        XCTAssertEqual(Set(json.keys), ["status", "applicationId", "device", "appPath"])
        XCTAssertEqual(json["applicationId"] as? String, "com.kylebrowning.landmarks")
        let device = try XCTUnwrap(json["device"] as? [String: Any])
        XCTAssertEqual(device["name"] as? String, "Pixel_8_API_35")
        XCTAssertEqual(device["serial"] as? String, "emulator-5554")
        XCTAssertNil(json["bundleId"])
        XCTAssertNil(json["simulator"])
    }

    /// L39: every document carries `appPath`, null when nothing was installed.
    func testASkippedInstallReportsANullAppPath() throws {
        let android = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(JSONOutput.string(AndroidInstallResult(
            status: .skipped, applicationId: "com.kylebrowning.landmarks",
            device: .init(name: "fix3-6-android", serial: "emulator-5554"), appPath: nil
        )).utf8)) as? [String: Any])
        XCTAssertEqual(Set(android.keys), ["status", "applicationId", "device", "appPath"])
        XCTAssertTrue(android["appPath"] is NSNull)

        let ios = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(JSONOutput.string(InstallResult(
            status: .skipped, scheme: nil, bundleId: "com.kylebrowning.Landmarks",
            simulator: .init(name: "fix3-6-ios", udid: "U"), appPath: nil, dataContainerPath: nil
        )).utf8)) as? [String: Any])
        XCTAssertEqual(Set(ios.keys), ["status", "scheme", "bundleId", "simulator", "appPath", "dataContainerPath"])
        XCTAssertTrue(ios["appPath"] is NSNull)
    }

    func testHumanCompletionIncludesDataContainerPath() {
        let message = InstallCommand.completionMessage(
            status: .launched,
            bundleId: "com.example.app",
            deviceName: "iPhone 17",
            dataContainerPath: "/tmp/simulator/data"
        )

        XCTAssertEqual(
            message,
            "[grantiva] Done — com.example.app running on iPhone 17\nData container: /tmp/simulator/data"
        )
    }

    /// K73: a --bundle-id that is not the built app's ID is named, with both
    /// IDs, before install; the container lookup never runs under it.
    func testABundleIDThatIsNotTheBuiltAppsFailsNamingBothBeforeInstall() async throws {
        let fm = FileManager.default
        let previous = fm.currentDirectoryPath
        let root = fm.temporaryDirectory.appendingPathComponent("k73-\(UUID().uuidString)", isDirectory: true)
        let app = root.appendingPathComponent("Demo.app", isDirectory: true)
        try fm.createDirectory(at: app, withIntermediateDirectories: true)
        defer {
            fm.changeCurrentDirectoryPath(previous)
            try? fm.removeItem(at: root)
        }
        let plist = try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": "com.example.A"], format: .xml, options: 0)
        try plist.write(to: app.appendingPathComponent("Info.plist"))
        try "scheme: Demo\nsimulator: fake\n".write(to: root.appendingPathComponent("grantiva.yml"), atomically: true, encoding: .utf8)
        fm.changeCurrentDirectoryPath(root.path)

        let fake = FakeDevicePlatform(platform: .ios)
        fake.buildResult = BuildResult(success: true, scheme: "Demo", duration: 0, warnings: [], errors: [], productPath: app.path)
        var command = try InstallCommand.parse(["--no-launch", "--platform", "ios", "--bundle-id", "com.example.B"])
        command.devicePlatform = InjectedDevicePlatform(fake)
        do {
            try await command.run()
            XCTFail("expected the mismatch error")
        } catch {
            let message = (error as? GrantivaError)?.errorDescription ?? "\(error)"
            XCTAssertTrue(message.contains("--bundle-id com.example.B does not match the built app (com.example.A, "), message)
            XCTAssertTrue(message.contains("Demo.app/Info.plist"), message)
            XCTAssertFalse(message.contains("NSPOSIXErrorDomain"), message)
        }
        XCTAssertFalse(fake.calls.contains { $0.hasPrefix("install(") }, "\(fake.calls)")
    }

    func testAMatchingOrAbsentBundleIDIsNotAMismatch() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("k73b-\(UUID().uuidString)/Demo.app", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
        let plist = try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": "com.example.A"], format: .xml, options: 0)
        try plist.write(to: root.appendingPathComponent("Info.plist"))
        XCTAssertNil(InstallCommand.bundleIDMismatch(flag: "com.example.A", configured: "com.other", productPath: root.path))
        XCTAssertNil(InstallCommand.bundleIDMismatch(flag: nil, configured: nil, productPath: root.path))
        let configured = InstallCommand.bundleIDMismatch(flag: nil, configured: "com.other", productPath: root.path)?.errorDescription ?? ""
        XCTAssertTrue(configured.contains("bundle_id com.other in grantiva.yml does not match the built app (com.example.A"), configured)
    }
}
