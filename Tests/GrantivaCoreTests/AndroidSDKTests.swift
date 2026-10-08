import Foundation
import XCTest
@testable import GrantivaCore

final class AndroidSDKTests: XCTestCase {
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory.appendingPathComponent("android-sdk-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    private func makeSDK(_ name: String) throws -> String {
        let root = scratch.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("platform-tools"), withIntermediateDirectories: true)
        try Data().write(to: root.appendingPathComponent("platform-tools/adb"))
        return root.path
    }

    func testLocatePrefersAndroidHomeThenSdkRootThenLibrary() throws {
        let home = try makeSDK("home")
        let sdkRoot = try makeSDK("sdkroot")
        let library = scratch.appendingPathComponent("user").path
        _ = try makeSDK("user/Library/Android/sdk")

        XCTAssertEqual(AndroidSDK.locate(environment: ["ANDROID_HOME": home, "ANDROID_SDK_ROOT": sdkRoot], home: library)?.root, home)
        XCTAssertEqual(AndroidSDK.locate(environment: ["ANDROID_SDK_ROOT": sdkRoot], home: library)?.root, sdkRoot)
        XCTAssertEqual(AndroidSDK.locate(environment: [:], home: library)?.root, "\(library)/Library/Android/sdk")
    }

    func testLocateSkipsARootWithoutAdb() throws {
        let empty = scratch.appendingPathComponent("empty").path
        try FileManager.default.createDirectory(atPath: empty, withIntermediateDirectories: true)
        let good = try makeSDK("good")
        XCTAssertEqual(AndroidSDK.locate(environment: ["ANDROID_HOME": empty, "ANDROID_SDK_ROOT": good], home: scratch.path)?.root, good)
        XCTAssertNil(AndroidSDK.locate(environment: ["ANDROID_HOME": empty], home: scratch.path))
    }

    func testRequireThrowsTheSetupMessage() {
        XCTAssertThrowsError(try AndroidSDK.require(environment: [:], home: scratch.path)) { error in
            XCTAssertTrue("\(error)".contains("ANDROID_HOME"), "\(error)")
            XCTAssertTrue("\(error)".contains("scripts/android-env.sh"), "\(error)")
        }
    }

    func testToolPathsHangOffTheRoot() {
        let sdk = AndroidSDK(root: "/sdk")
        XCTAssertEqual(sdk.adb, "/sdk/platform-tools/adb")
        XCTAssertEqual(sdk.emulator, "/sdk/emulator/emulator")
        XCTAssertEqual(sdk.avdmanager, "/sdk/cmdline-tools/latest/bin/avdmanager")
        XCTAssertEqual(sdk.sdkmanager, "/sdk/cmdline-tools/latest/bin/sdkmanager")
        XCTAssertEqual(sdk.apkanalyzer, "/sdk/cmdline-tools/latest/bin/apkanalyzer")
    }

    func testJavaHomeUsesTheVariableWhenItExistsElseJavaHomeTool() async throws {
        let jdk = scratch.appendingPathComponent("jdk").path
        try FileManager.default.createDirectory(atPath: jdk, withIntermediateDirectories: true)
        let fromEnv = await AndroidSDK.javaHome(environment: ["JAVA_HOME": jdk], execute: { _ in XCTFail("must not shell out"); return "" })
        XCTAssertEqual(fromEnv, jdk)

        let fromTool = await AndroidSDK.javaHome(environment: ["JAVA_HOME": "/nonexistent"], execute: { command in
            XCTAssertEqual(command, "/usr/libexec/java_home")
            return "/Library/Java/JavaVirtualMachines/jdk-21/Contents/Home\n"
        })
        XCTAssertEqual(fromTool, "/Library/Java/JavaVirtualMachines/jdk-21/Contents/Home")

        let none = await AndroidSDK.javaHome(environment: [:], execute: { _ in throw GrantivaError.commandFailed("no java", 1) })
        XCTAssertNil(none)
    }
}
