import XCTest
import GrantivaCore
@testable import GrantivaCLI

final class BuildCommandTests: XCTestCase {
    func testSkippedAbsentIOSAppDoesNotRequireADataContainer() async throws {
        let fake = FakeDevicePlatform(platform: .ios)
        fake.installed = false
        var command = try InstallCommand.parse([
            "--platform", "ios", "--bundle-id", "com.fake.binary", "--simulator", "Fake",
            "--no-build", "--no-launch", "--json",
        ])
        command.devicePlatform = InjectedDevicePlatform(fake)
        command.containerLookup.call = { _, _, _ in
            XCTFail("absent skipped app must not require a data container")
            throw CocoaError(.fileNoSuchFile)
        }
        let json = try await captureInstallJSON(command)
        XCTAssertEqual(json["status"] as? String, "skipped")
        XCTAssertTrue(json["appPath"] is NSNull)
        XCTAssertTrue(json["dataContainerPath"] is NSNull)
        XCTAssertFalse(fake.calls.contains { $0.hasPrefix("install(") || $0.hasPrefix("launch(") })
    }

    func testSkippedInstalledAndAppFileInstallRetainContainerMetadata() async throws {
        for appFile in [false, true] {
            let fake = FakeDevicePlatform(platform: .ios)
            fake.installed = true
            var args = ["--platform", "ios", "--bundle-id", "com.fake.binary", "--simulator", "Fake", "--no-build", "--no-launch", "--json"]
            if appFile { args += ["--app-file", "/fake/Demo.app"] }
            var command = try InstallCommand.parse(args)
            command.devicePlatform = InjectedDevicePlatform(fake)
            command.containerLookup.call = { _, id, _ in
                XCTAssertEqual(id, "com.fake.binary")
                return "/fake/data"
            }
            let json = try await captureInstallJSON(command)
            XCTAssertEqual(json["status"] as? String, appFile ? "installed" : "skipped")
            XCTAssertEqual(json["dataContainerPath"] as? String, "/fake/data")
            if appFile { XCTAssertEqual(json["appPath"] as? String, "/fake/Demo.app") }
            else { XCTAssertTrue(json["appPath"] is NSNull) }
            XCTAssertEqual(fake.calls.contains("install(com.fake.binary,/fake/Demo.app)"), appFile)
            XCTAssertFalse(fake.calls.contains { $0.hasPrefix("launch(") })
        }
    }

    private func captureInstallJSON(_ command: InstallCommand) async throws -> [String: Any] {
        let pipe = Pipe()
        let saved = dup(STDOUT_FILENO)
        defer { dup2(saved, STDOUT_FILENO); close(saved) }
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        try await command.run()
        dup2(saved, STDOUT_FILENO)
        try pipe.fileHandleForWriting.close()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testBuildAcceptsDerivedDataPath() throws {
        let command = try BuildOnlyCommand.parse([
            "--derived-data-path", "/tmp/Grantiva DerivedData",
        ])

        XCTAssertEqual(command.derivedDataPath, "/tmp/Grantiva DerivedData")
    }

    func testBuildRejectsInstallOnlyBinaryFlags() {
        XCTAssertThrowsError(try BuildOnlyCommand.parse(["--app-file", "/tmp/Test.app"]))
        XCTAssertThrowsError(try BuildOnlyCommand.parse(["--no-build"]))
    }

    /// L29: `build build` never boots or picks a device to run on, so its
    /// help offers none of the boot flags; `build install` still does.
    func testBuildBuildHelpOffersNoBootFlags() throws {
        let help = BuildOnlyCommand.helpMessage()
        for flag in ["--headless", "--emulator", "--allow-device-settings"] {
            XCTAssertFalse(help.contains(flag), "\(flag) in:\n\(help)")
        }
        XCTAssertTrue(help.contains("--device"), help)
        XCTAssertTrue(help.contains("ABI picks the split APK"), help)
        XCTAssertTrue(InstallCommand.helpMessage().contains("--headless"))
        XCTAssertTrue(InstallCommand.helpMessage().contains("--emulator"))
        // Still accepted, hidden, for scripts that pass them.
        let command = try BuildOnlyCommand.parse(["--headless", "--emulator", "Pixel", "--allow-device-settings"])
        XCTAssertTrue(command.target.headless)
        XCTAssertEqual(command.target.emulator, "Pixel")
    }
}
