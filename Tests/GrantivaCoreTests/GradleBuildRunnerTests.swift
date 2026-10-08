import Foundation
import XCTest
@testable import GrantivaCore

final class GradleBuildRunnerTests: XCTestCase {
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory.appendingPathComponent("gradle-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    func testTaskNameCapitalizesEachVariantComponent() {
        XCTAssertEqual(GradleBuildRunner.taskName(module: "app", variant: "debug"), ":app:assembleDebug")
        XCTAssertEqual(GradleBuildRunner.taskName(module: "mobile", variant: "freeDebug"), ":mobile:assembleFreeDebug")
    }

    func testNestedAndColonPrefixedModules() {
        XCTAssertEqual(GradleBuildRunner.taskName(module: ":app", variant: "debug"), ":app:assembleDebug")
        XCTAssertEqual(GradleBuildRunner.taskName(module: "feature:app", variant: "debug"), ":feature:app:assembleDebug")
        XCTAssertEqual(GradleBuildRunner.buildDirectory(projectRoot: "/p", module: "feature:app", extraArgs: []), "/p/feature/app/build")
        XCTAssertEqual(GradleBuildRunner.buildDirectory(projectRoot: "/p", module: ":app", extraArgs: []), "/p/app/build")
    }

    func testCommandUsesTheWrapperWhenPresentElseGradleOnPath() throws {
        let noWrapper = GradleBuildRunner.command(projectRoot: scratch.path, module: "app", variant: "debug", extraArgs: ["-PsomeFlag=1"], javaHome: "/jdk")
        XCTAssertEqual(noWrapper, "cd \(shellQuoted(scratch.path)) && JAVA_HOME='/jdk' gradle ':app:assembleDebug' --console=plain '-PsomeFlag=1'")

        try "".write(to: scratch.appendingPathComponent("gradlew"), atomically: true, encoding: .utf8)
        let withWrapper = GradleBuildRunner.command(projectRoot: scratch.path, module: "app", variant: "debug", extraArgs: [], javaHome: nil)
        XCTAssertEqual(withWrapper, "cd \(shellQuoted(scratch.path)) && ./gradlew ':app:assembleDebug' --console=plain")
    }

    func testBuildDirectoryHonorsPBuildDir() {
        XCTAssertEqual(GradleBuildRunner.buildDirectory(projectRoot: "/p", module: "app", extraArgs: []), "/p/app/build")
        XCTAssertEqual(GradleBuildRunner.buildDirectory(projectRoot: "/p", module: "app", extraArgs: ["-PbuildDir=/tmp/out"]), "/tmp/out")
        XCTAssertEqual(GradleBuildRunner.buildDirectory(projectRoot: "/p", module: "app", extraArgs: ["-PbuildDir=out"]), "/p/out")
    }

    func testSuccessfulBuildReturnsApkAndApplicationId() async throws {
        let metadataDir = scratch.appendingPathComponent("app/build/outputs/apk/debug")
        try FileManager.default.createDirectory(at: metadataDir, withIntermediateDirectories: true)
        try """
        {"version":3,"artifactType":{"type":"APK","kind":"Directory"},"applicationId":"com.example.app","variantName":"debug",
         "elements":[{"type":"SINGLE","filters":[],"attributes":[],"versionCode":1,"versionName":"1.0","outputFile":"app-debug.apk"}],"elementType":"File"}
        """.write(to: metadataDir.appendingPathComponent("output-metadata.json"), atomically: true, encoding: .utf8)

        let shell = ScriptedShell([.success("> Task :app:assembleDebug\nw: some warning\nBUILD SUCCESSFUL in 3s")])
        let result = try await GradleBuildRunner(execute: shell.execute).build(
            projectRoot: scratch.path, module: "app", variant: "debug", extraArgs: [], javaHome: nil, deviceABI: "arm64-v8a"
        )
        XCTAssertTrue(result.success)
        XCTAssertNil(result.scheme)
        XCTAssertNil(result.destination)
        XCTAssertEqual(result.productPath, metadataDir.appendingPathComponent("app-debug.apk").path)
        XCTAssertEqual(result.applicationId, "com.example.app")
        XCTAssertEqual(result.warnings, ["w: some warning"])
    }

    func testFailedBuildCollectsErrorLines() async throws {
        let shell = ScriptedShell([.failure(GrantivaError.commandFailed("e: Main.kt:3:1 Unresolved reference\nFAILURE: Build failed with an exception.", 1))])
        let result = try await GradleBuildRunner(execute: shell.execute).build(
            projectRoot: scratch.path, module: "app", variant: "debug", extraArgs: [], javaHome: nil, deviceABI: "arm64-v8a"
        )
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.errors, ["e: Main.kt:3:1 Unresolved reference", "FAILURE: Build failed with an exception."])
        XCTAssertNil(result.productPath)
    }

    func testSuccessfulBuildWithoutMetadataFailsNamingTheDirectory() async throws {
        let shell = ScriptedShell([.success("BUILD SUCCESSFUL")])
        do {
            _ = try await GradleBuildRunner(execute: shell.execute).build(
                projectRoot: scratch.path, module: "app", variant: "debug", extraArgs: [], javaHome: nil, deviceABI: "arm64-v8a"
            )
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("output-metadata.json"), "\(error)")
            XCTAssertTrue("\(error)".contains("app/build"), "\(error)")
        }
    }
}
