import Foundation

/// Stops simctl recordVideo using the same interrupt semantics as Control-C.
///
/// simctl writes to a staging movie while recording and finalizes/renames it
/// when it receives SIGINT. SIGTERM can leave the requested output empty while
/// the staging file remains behind, especially for short captures.
public enum RecorderLifecycle {
    public static func withCleanup<T>(for process: Process, operation: () async throws -> T) async throws -> T {
        do {
            let result = try await operation()
            try await stop(process)
            return result
        } catch {
            try? await stop(process)
            throw error
        }
    }

    public static func waitForStart(
        of recordingURL: URL,
        attempts: Int = 100,
        pollInterval: Duration = .milliseconds(100)
    ) async throws {
        let directory = recordingURL.deletingLastPathComponent()
        let stagingPrefix = recordingURL.lastPathComponent + ".sb-"
        for _ in 0..<attempts {
            let entries = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
            if entries.contains(where: { $0.lastPathComponent.hasPrefix(stagingPrefix) }) {
                return
            }
            try await Task.sleep(for: pollInterval)
        }
        throw GrantivaError.commandFailed("Timed out waiting for simulator recording to start", 1)
    }

    public static func stop(
        _ process: Process,
        gracefulAttempts: Int = 50,
        terminationAttempts: Int = 20,
        pollInterval: Duration = .milliseconds(100)
    ) async throws {
        if process.isRunning { process.interrupt() }
        if await waitForExit(process, attempts: gracefulAttempts, pollInterval: pollInterval) { return }

        if process.isRunning { process.terminate() }
        if await waitForExit(process, attempts: terminationAttempts, pollInterval: pollInterval) { return }

        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        guard await waitForExit(process, attempts: terminationAttempts, pollInterval: pollInterval) else {
            throw GrantivaError.commandFailed("Timed out stopping simulator recording", 1)
        }
    }

    private static func waitForExit(
        _ process: Process,
        attempts: Int,
        pollInterval: Duration
    ) async -> Bool {
        for _ in 0..<attempts where process.isRunning {
            // Cleanup commonly runs after the recording task has been cancelled.
            // Sleeping on that task would throw immediately and burn through every
            // poll before Process has observed the signal. Use an unstructured task
            // so cancellation of the operation cannot prevent cleanup from waiting.
            await Task.detached {
                try? await Task.sleep(for: pollInterval)
            }.value
        }
        return !process.isRunning
    }
}
