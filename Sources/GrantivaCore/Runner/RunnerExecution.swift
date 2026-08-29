import Darwin
import Dispatch
import Foundation

/// Spawns grantiva-runner, relays its output, and waits for it — with the
/// process-group, signal-forwarding and readiness behaviour that a `--keep-alive`
/// session needs.
enum RunnerExecution {
    struct Outcome {
        let terminationStatus: Int32
        let stderr: String
        /// True when grantiva itself killed the runner on its timeout.
        let timedOut: Bool
    }

    struct Request {
        let executable: String
        let arguments: [String]
        let workingDirectory: String
        let lease: SimulatorLease
        let keepAlive: Bool
        let timeoutSeconds: UInt64
        /// Temp-staging path → the path the user passed, for output rewriting.
        let pathMap: [String: String]
        let reportDir: String
        let expectedFlows: Int
        let readyFile: ReadyFileSignal
    }

    static func run(_ request: Request) async -> Outcome {
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        let child: ChildProcess
        do {
            child = try ChildProcess.spawn(
                executable: request.executable,
                arguments: request.arguments,
                workingDirectory: request.workingDirectory,
                stdout: stdoutPipe.fileHandleForWriting.fileDescriptor,
                stderr: stderrPipe.fileHandleForWriting.fileDescriptor
            )
        } catch {
            return Outcome(
                terminationStatus: 1,
                stderr: "Could not start grantiva-runner: \(error)",
                timedOut: false
            )
        }
        // The parent must drop its copies of the write ends or the readers
        // never see EOF.
        try? stdoutPipe.fileHandleForWriting.close()
        try? stderrPipe.fileHandleForWriting.close()

        request.lease.recordRunner(pid: child.pid, keepAlive: request.keepAlive)

        // Ctrl-C (or `kill -INT`) now reaps the runner's whole process group —
        // grantiva-runner, WebDriverAgent's xcodebuild, and any simctl diagnose
        // it started — and then releases the lease so the next run is not
        // refused by a lock whose owner is gone.
        SignalRelay.shared.track(group: child.processGroup)
        let lease = request.lease
        let readyFile = request.readyFile
        let cleanupToken = SignalRelay.shared.onTermination {
            readyFile.write(RunReadyState(status: "interrupted", flows: []))
            lease.release()
        }
        defer {
            SignalRelay.shared.untrack(group: child.processGroup)
            SignalRelay.shared.removeCleanup(cleanupToken)
        }

        // stdout is relayed to stderr (so structured stdout stays clean for
        // --json) with staged temp paths rewritten back to the user's paths.
        let stdoutFD = stdoutPipe.fileHandleForReading.fileDescriptor
        let stderrFD = stderrPipe.fileHandleForReading.fileDescriptor
        let pathMap = request.pathMap

        async let relayFinished: Void = withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var rewriter = OutputRewriter(replacements: pathMap)
                let handle = FileHandle(fileDescriptor: stdoutFD, closeOnDealloc: false)
                while true {
                    let chunk = handle.availableData
                    if chunk.isEmpty { break }
                    let text = String(decoding: chunk, as: UTF8.self)
                    let emit = rewriter.isEmpty ? text : rewriter.consume(text)
                    if !emit.isEmpty {
                        FileHandle.standardError.write(Data(emit.utf8))
                    }
                }
                let remainder = rewriter.flush()
                if !remainder.isEmpty {
                    FileHandle.standardError.write(Data(remainder.utf8))
                }
                continuation.resume()
            }
        }

        async let stderrText: String = withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let handle = FileHandle(fileDescriptor: stderrFD, closeOnDealloc: false)
                let data = handle.readDataToEndOfFile()
                continuation.resume(returning: String(decoding: data, as: UTF8.self))
            }
        }

        // Readiness: with --keep-alive the runner stays alive long after the
        // flows finish, so process exit is not the completion signal. Poll the
        // report the runner writes and publish the ready file the moment every
        // flow reaches a terminal state.
        let watcher = readyFile.path.map { _ in
            Task.detached(priority: .utility) {
                while !Task.isCancelled {
                    if let index = RunnerReportIndex.load(reportDir: request.reportDir),
                       index.isComplete(expectedFlows: request.expectedFlows) {
                        var state = index.readyState
                        state = RunReadyState(
                            status: state.status,
                            flows: state.flows,
                            reportDir: request.reportDir
                        )
                        readyFile.write(state)
                        return
                    }
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
            }
        }
        defer { watcher?.cancel() }

        let killed = KilledFlag()
        let timeoutTask = Task.detached(priority: .utility) {
            try await Task.sleep(nanoseconds: request.timeoutSeconds * 1_000_000_000)
            guard child.isRunning else { return }
            killed.set()
            child.terminateGroup()
        }

        let status = await withCheckedContinuation { (continuation: CheckedContinuation<Int32, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: child.wait())
            }
        }
        timeoutTask.cancel()
        // The runner is gone; make sure nothing it started is still holding the
        // simulator. Harmless when the group is already empty.
        child.signalGroup(SIGTERM)

        await relayFinished
        let stderr = await stderrText
        try? stdoutPipe.fileHandleForReading.close()
        try? stderrPipe.fileHandleForReading.close()

        return Outcome(
            terminationStatus: status,
            stderr: stderr,
            timedOut: killed.isSet
        )
    }
}
