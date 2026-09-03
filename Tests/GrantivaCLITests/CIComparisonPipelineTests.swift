import XCTest
@testable import GrantivaCLI
import GrantivaCore

final class CIComparisonPipelineTests: XCTestCase {
    func testMissingRunnerScreenshotIsUploadedAsAnErrorAndFailsVerdict() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-ci-comparison-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let currentPath = directory.appendingPathComponent("Home.png").path
        let staleMissingPath = directory.appendingPathComponent("Checkout.png").path
        try Data("current".utf8).write(to: URL(fileURLWithPath: currentPath))
        try Data("stale".utf8).write(to: URL(fileURLWithPath: staleMissingPath))

        let missing = ScreenCapture(
            screenName: "Checkout", path: "", sizeBytes: 0,
            steps: [StepResult(
                action: "Take screenshot", status: .failed, duration: 0,
                message: "Screenshot not found in runner output"
            )]
        )
        let captured = ScreenCapture(
            screenName: "Home", path: currentPath, sizeBytes: 7,
            steps: [StepResult(action: "Tap Continue", status: .passed, duration: 0.2)]
        )
        let pipeline = CIComparisonPipeline(
            validateCaptures: { captures in
                try CICommand.currentInvocationArtifacts(
                    from: captures, outputDir: directory.path
                )
            },
            loadCapture: { path in
                XCTAssertEqual(path, currentPath)
                XCTAssertNotEqual(path, staleMissingPath)
                return Data("capture".utf8)
            },
            loadBaseline: { _ in nil },
            compare: { _, _ in XCTFail("new screens must not be compared"); throw TestError.unexpected },
            writeDiff: { _, _ in XCTFail("new screens must not write diffs") }
        )

        let outcome = try await pipeline.run(
            captures: [missing, captured],
            pixelThreshold: 0.02,
            perceptualThreshold: 5
        )

        XCTAssertFalse(outcome.allPassed)
        XCTAssertEqual(outcome.screens.count, 2, "every configured screen must reach the backend")
        XCTAssertEqual(outcome.screens[0].name, "Checkout")
        XCTAssertEqual(outcome.screens[0].status, "error")
        XCTAssertEqual(outcome.screens[0].message, "Screenshot not found in runner output")
        XCTAssertNil(outcome.screens[0].captureData)
        XCTAssertEqual(outcome.screens[0].steps.first?.status, "failed")
        XCTAssertEqual(outcome.screens[1].name, "Home")
        XCTAssertEqual(outcome.screens[1].status, "new_screen")
        XCTAssertEqual(outcome.screens[1].captureData, Data("capture".utf8))
        XCTAssertEqual(outcome.screens[1].steps.first?.action, "Tap Continue")
    }

    func testFailedComparisonUsesValidatedCurrentPathAndWritesDiff() async throws {
        var writtenName: String?
        var writtenData: Data?
        let diff = Data("diff".utf8)
        let pipeline = CIComparisonPipeline(
            validateCaptures: { _ in [DiffCommand.CaptureArtifact(
                fileName: "Home.png", screenName: "Home", path: "/current/home.png"
            )] },
            loadCapture: { path in
                XCTAssertEqual(path, "/current/home.png")
                return Data("capture".utf8)
            },
            loadBaseline: { _ in Data("baseline".utf8) },
            compare: { _, _ in DiffOutput(
                pixelDiffPercent: 0.03, perceptualDistance: 2, diffImageData: diff
            ) },
            writeDiff: { name, data in
                writtenName = name
                writtenData = data
            }
        )

        let outcome = try await pipeline.run(
            captures: [ScreenCapture(screenName: "Home", path: "/reported/home.png", sizeBytes: 7)],
            pixelThreshold: 0.02,
            perceptualThreshold: 5
        )

        XCTAssertFalse(outcome.allPassed)
        XCTAssertEqual(outcome.screens.first?.status, "failed")
        XCTAssertEqual(outcome.screens.first?.diffData, diff)
        XCTAssertEqual(writtenName, "Home")
        XCTAssertEqual(writtenData, diff)
    }
}

private enum TestError: Error {
    case unexpected
}
