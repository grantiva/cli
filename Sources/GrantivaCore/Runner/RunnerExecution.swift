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
        /// Extra environment for the runner process; empty inherits ours unchanged.
        var environment: [String: String] = [:]
        let readyFile: ReadyFileSignal
        /// The platform recorded in the keep-alive owner sidecar.
        var platform: Platform? = nil
        /// Where keep-alive sessions are discovered. Overridable for tests.
        var sessions: KeepAliveSessionStore = KeepAliveSessionStore()
        /// How long, after the flows finish, to wait for the runner's keep-alive
        /// session file before publishing the ready file anyway.
        var sessionFileGrace: TimeInterval = 10
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
                environment: request.environment.isEmpty ? nil : request.environment,
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

        // The runner's own session file (/tmp/grantiva-sessions/<pid>-<ts>.grantiva)
        // carries no simulator UDID. Record udid -> runner pid now, before the
        // flows run, so `grantiva hierarchy --udid` can resolve the session the
        // moment the runner publishes it — and before any --ready-file exists.
        if request.keepAlive {
            request.sessions.recordOwner(udid: request.lease.udid, runnerPid: child.pid, platform: request.platform)
        }
        defer {
            if request.keepAlive {
                request.sessions.removeOwner(runnerPid: child.pid)
            }
        }

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
        //
        // The runner writes its keep-alive session file just after the last
        // flow goes terminal, so a waiter that polls the ready file and then
        // immediately runs `grantiva hierarchy` could race it. Hold the ready
        // file (briefly) until that session file is on disk.
        let watcher = readyFile.path.map { _ in
            Task.detached(priority: .utility) {
                var completeSince: Date?
                while !Task.isCancelled {
                    if let index = RunnerReportIndex.load(reportDir: request.reportDir),
                       index.isComplete(expectedFlows: request.expectedFlows) {
                        if request.keepAlive, child.isRunning,
                           request.sessions.session(forRunnerPid: child.pid) == nil {
                            let since = completeSince ?? Date()
                            completeSince = since
                            if Date().timeIntervalSince(since) < request.sessionFileGrace {
                                try? await Task.sleep(nanoseconds: 100_000_000)
                                continue
                            }
                        }
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
