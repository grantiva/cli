import XCTest
@testable import GrantivaCLI
import GrantivaAPI
import GrantivaCore

final class CICompletionStateTests: XCTestCase {
    func testSuccessfulResultsCannotBeOverwrittenByLaterRecovery() async throws {
        let recorder = CompletionRecorder()
        var state = CIRunCompletionState()
        let resultUpload = upload(screenCount: 1)
        let response = try await state.completeResults(resultUpload) { upload in
            await recorder.complete(upload)
        }
        XCTAssertEqual(response.runId, "RUN-1")
        XCTAssertTrue(state.resultsCompleted)

        await state.completeFailureIfNeeded(upload(screenCount: 0)) { upload in
            await recorder.complete(upload)
        }
        let uploads = await recorder.uploads
        XCTAssertEqual(uploads.count, 1)
        XCTAssertEqual(uploads[0].screens.count, 1)
    }

    func testPipelineFailureSendsOneEmptyCompletion() async {
        let recorder = CompletionRecorder()
        let state = CIRunCompletionState()
        await state.completeFailureIfNeeded(upload(screenCount: 0)) { upload in
            await recorder.complete(upload)
        }
        let uploads = await recorder.uploads
        XCTAssertEqual(uploads.count, 1)
        XCTAssertTrue(uploads[0].screens.isEmpty)
    }

    func testFailedResultCompletionStillAllowsFailureRecovery() async {
        let recorder = CompletionRecorder()
        var state = CIRunCompletionState()
        do {
            _ = try await state.completeResults(upload(screenCount: 1)) { _ in
                throw GrantivaError.commandFailed("upload failed", 1)
            }
            XCTFail("expected failure")
        } catch {}
        XCTAssertFalse(state.resultsCompleted)

        await state.completeFailureIfNeeded(upload(screenCount: 0)) { upload in
            await recorder.complete(upload)
        }
        let uploads = await recorder.uploads
        XCTAssertEqual(uploads.count, 1)
    }

    func testFailureCompletionIsBestEffort() async {
        let state = CIRunCompletionState()
        await state.completeFailureIfNeeded(upload(screenCount: 0)) { _ in
            throw GrantivaError.commandFailed("backend unavailable", 1)
        }
    }

    func testLogUploadFailureDoesNotPreventFailureCompletion() async {
        struct LogFailure: LocalizedError {
            var errorDescription: String? { "logs unavailable" }
        }

        let recorder = CompletionRecorder()
        let state = CIRunCompletionState()
        let logError = await state.recoverFailure(
            upload(screenCount: 0),
            flushLogs: { throw LogFailure() }
        ) { upload in
            await recorder.complete(upload)
        }

        XCTAssertEqual(logError, "logs unavailable")
        let uploads = await recorder.uploads
        XCTAssertEqual(uploads.count, 1)
        XCTAssertTrue(uploads[0].screens.isEmpty)
    }

    func testFailureRecoveryDoesNotOverwriteCompletedResults() async throws {
        let recorder = CompletionRecorder()
        var state = CIRunCompletionState()
        _ = try await state.completeResults(upload(screenCount: 1)) { upload in
            await recorder.complete(upload)
        }

        let logError = await state.recoverFailure(
            upload(screenCount: 0),
            flushLogs: {}
        ) { upload in
            await recorder.complete(upload)
        }

        XCTAssertNil(logError)
        let uploads = await recorder.uploads
        XCTAssertEqual(uploads.count, 1)
        XCTAssertEqual(uploads[0].screens.count, 1)
    }

    private func upload(screenCount: Int) -> RunUpload {
        let screens = (0..<screenCount).map {
            RunScreenUpload(name: "screen-\($0)", status: "passed", pixelThreshold: 0.02, perceptualThreshold: 5, captureData: Data())
        }
        return RunUpload(branch: "main", commitSHA: "abc", trigger: "ci", duration: 1, screens: screens)
    }
}

private actor CompletionRecorder {
    private(set) var uploads: [RunUpload] = []
    func complete(_ upload: RunUpload) -> RunResponse {
        uploads.append(upload)
        return RunResponse(runId: "RUN-1", status: "complete", url: "https://example.com/run", screenCount: upload.screens.count, passedCount: upload.screens.count, failedCount: 0, newCount: 0)
    }
}
