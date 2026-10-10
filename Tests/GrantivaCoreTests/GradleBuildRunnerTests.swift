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

    /// A09: Gradle's reason is in the What-went-wrong block, not on a
    /// `FAILURE:` line. Captured from `./gradlew :app:assembleNoSuchVariant`.
    func testFailedBuildIncludesGradlesWhatWentWrongBlock() async throws {
        let log = """
        [Incubating] Problems report is available at: file:///tmp/problems-report.html

        FAILURE: Build failed with an exception.

        * What went wrong:
        Cannot locate tasks that match ':app:assembleNoSuchVariant' as task 'assembleNoSuchVariant' not found in project ':app'.

        * Try:
        > Run gradlew tasks to get a list of available tasks.
        > Run with --stacktrace option to get the stack trace.

        BUILD FAILED in 412ms
        """
        let shell = ScriptedShell([.failure(GrantivaError.commandFailed(log, 1))])
        let result = try await GradleBuildRunner(execute: shell.execute).build(
            projectRoot: scratch.path, module: "app", variant: "noSuchVariant", extraArgs: [], javaHome: nil, deviceABI: "arm64-v8a"
        )
        XCTAssertFalse(result.success)
        XCTAssertEqual(Array(result.errors.prefix(2)), [
            "FAILURE: Build failed with an exception.",
            "Cannot locate tasks that match ':app:assembleNoSuchVariant' as task 'assembleNoSuchVariant' not found in project ':app'.",
        ])
        XCTAssertTrue(result.errors.last?.contains("--variant") == true, "\(result.errors)")
        XCTAssertFalse(result.errors.contains { $0.contains("Run gradlew tasks") }, "the Try block is not an error: \(result.errors)")
    }

    /// A09: `--module nosuch` (captured from AND-025).
    func testAnUnknownModuleKeepsGradlesReasonAndTheHint() {
        let lines = """
        FAILURE: Build failed with an exception.

        * What went wrong:
        Cannot locate tasks that match ':nosuch:assembleFreeDebug' as project 'nosuch' not found in root project 'Landmarks'.

        * Try:
        > Run gradlew projects to get a list of available projects.
        """.components(separatedBy: "\n")
        let errors = GradleBuildRunner.errorLines(lines)
        XCTAssertEqual(errors.count, 3, "\(errors)")
        XCTAssertEqual(errors[1], "Cannot locate tasks that match ':nosuch:assembleFreeDebug' as project 'nosuch' not found in root project 'Landmarks'.")
        XCTAssertTrue(errors[2].contains("--module"), "\(errors)")
    }

    func testWhatWentWrongBlocksOfSeveralFailuresAreAllKept() {
        let lines = """
        FAILURE: Build completed with 2 failures.

        1: Task failed with an exception.
        -----------
        * What went wrong:
        Execution failed for task ':app:compileDebugKotlin'.
        > Compilation error. See log for more details

        * Try:
        > Run with --stacktrace option to get the stack trace.
        ==============================================================================

        2: Task failed with an exception.
        -----------
        * What went wrong:
        Execution failed for task ':lib:mergeDebugResources'.
        """.components(separatedBy: "\n")
        XCTAssertEqual(GradleBuildRunner.errorLines(lines), [
            "FAILURE: Build completed with 2 failures.",
            "Execution failed for task ':app:compileDebugKotlin'.",
            "> Compilation error. See log for more details",
            "Execution failed for task ':lib:mergeDebugResources'.",
        ])
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
