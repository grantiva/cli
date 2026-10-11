import XCTest
@testable import GrantivaCLI

final class BuildCommandTests: XCTestCase {
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
