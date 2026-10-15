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
        /// True when grantiva received SIGINT/SIGTERM and reaped the runner.
        var interrupted: Bool = false
        /// The signal that killed the runner, when one did.
        var terminatingSignal: Int32? = nil
    }

    /// How the runner ended, for a failure reason: `exit 3`, or
    /// `killed by SIGHUP` when a signal ended it (L11).
    static func exitDescription(_ outcome: Outcome) -> String {
        if let signal = outcome.terminatingSignal { return "killed by \(SubprocessLog.signalName(signal))" }
        return "exit \(outcome.terminationStatus)"
    }

    /// How long the relay keeps reading after the runner has exited. A
    /// descendant that outlives the runner (an orphaned xcodebuild) can hold
    /// the output pipe open forever; the session ends with the runner.
    static let outputGraceAfterExit: TimeInterval = 1

    struct Request {
        let executable: String
        let arguments: [String]
        let workingDirectory: String
        let lease: SimulatorLease
        let keepAlive: Bool
        let timeoutSeconds: UInt64
        /// Temp-staging path → the path the user passed, for output rewriting.
        let pathMap: [String: String]
        /// Cycle chains resolve relative hops against their preceding file;
        /// ordinary runFlow narration retains the operand as written.
        var cyclePathMap: [String: String]? = nil
        let reportDir: String
        /// The report dir to name in the ready file: the preserved
        /// `--report-dir`, or nil for an ephemeral one deleted on exit.
        var readyReportDir: String?
        let expectedFlows: Int
        /// Extra environment for the runner process; empty inherits ours unchanged.
        var environment: [String: String] = [:]
        let readyFile: ReadyFileSignal
        /// The platform recorded in the keep-alive owner sidecar.
        var platform: Platform? = nil
        /// The app the run launches, recorded in the keep-alive owner sidecar.
        var appID: String? = nil
        /// Where keep-alive sessions are discovered. Overridable for tests.
        var sessions: KeepAliveSessionStore = KeepAliveSessionStore()
        /// How long, after the flows finish, to wait for the runner's keep-alive
        /// session file before publishing the ready file anyway.
        var sessionFileGrace: TimeInterval = 10
        /// Line edits applied to the relayed output after path rewriting
        /// (ephemeral report paths, generated wait steps).
        var outputFilter = RunnerOutputFilter()
        /// True when the relayed output must not reach the terminal
        /// (`--quiet`, `--json`); read once when the request is made.
        var silenced: Bool = RunnerNarration.isSilenced
        /// Where relayed output goes. Overridable for tests.
        var narrationSink: @Sendable (String) -> Void = RunnerNarration.sink
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
        // If grantiva dies without running its cleanups (`kill -9`), the
        // runner's group is interrupted rather than left holding the device.
        let lifeline = child.bindLifetimeToParent(sessionDirectory: request.keepAlive ? request.sessions.directory : nil)

        // The runner's own session file (/tmp/grantiva-sessions/<pid>-<ts>.grantiva)
        // carries no simulator UDID. Record udid -> runner pid now, before the
        // flows run, so `grantiva hierarchy --udid` can resolve the session the
        // moment the runner publishes it — and before any --ready-file exists.
        if request.keepAlive {
            request.sessions.recordOwner(
                udid: request.lease.udid, runnerPid: child.pid, platform: request.platform, detached: false,
                appID: request.appID
            )
        }
        defer {
            if request.keepAlive {
                // The runner has been waited for by now. One that exited
                // cleanly removed its own `<pid>-*.grantiva`; one killed by a
                // signal never does, and once the sidecar goes nothing links
                // that file to a device (L12). Remove both.
                request.sessions.removeSessionFiles(runnerPid: child.pid)
            }
        }

        // Ctrl-C (or `kill -INT`) now reaps the runner's whole process group —
        // grantiva-runner, WebDriverAgent's xcodebuild, and any simctl diagnose
        // it started — and then releases the lease so the next run is not
        // refused by a lock whose owner is gone.
        SignalRelay.shared.track(group: child.processGroup, deviceNoun: SignalRelay.deviceNoun(for: request.platform ?? .ios))
        let lease = request.lease
        let readyFile = request.readyFile
        let readyToken = SignalRelay.shared.beforeTermination {
            readyFile.write(RunReadyState(
                status: "interrupted",
                flows: RunnerReportIndex.finalFlows(reportDir: request.reportDir, unfinishedAs: "interrupted"),
                reportDir: request.readyReportDir
            ))
        }
        let cleanupToken = SignalRelay.shared.onTermination {
            lease.release()
        }
        defer {
            SignalRelay.shared.disarmHold(group: child.processGroup)
            SignalRelay.shared.untrack(group: child.processGroup)
            SignalRelay.shared.removeCleanup(readyToken)
            SignalRelay.shared.removeCleanup(cleanupToken)
        }

        // stdout is relayed to stderr (so structured stdout stays clean for
        // --json) with staged temp paths rewritten back to the user's paths.
        let stdoutFD = stdoutPipe.fileHandleForReading.fileDescriptor
        let stderrFD = stderrPipe.fileHandleForReading.fileDescriptor
        let pathMap = request.pathMap
        let cyclePathMap = request.cyclePathMap
        let initialFilter = request.outputFilter
        let silenced = request.silenced
        let sink = request.narrationSink

        // Both pipes are read until EOF, or until the runner has exited and
        // nothing more arrives (`outputGraceAfterExit`).
        let runnerExited = ExitMark()

        // Every chunk goes through RunnerSession.narrate, the one place that
        // honours --quiet/--json for runner output.
        async let relayFinished: Void = withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var rewriter = OutputRewriter(replacements: pathMap, cycleReplacements: cyclePathMap)
                var filter = initialFilter
                Self.drain(stdoutFD, after: runnerExited) { chunk in
                    let text = String(decoding: chunk, as: UTF8.self)
                    let rewritten = rewriter.isEmpty ? text : rewriter.consume(text)
                    let emit = filter.isEmpty ? rewritten : filter.consume(rewritten)
                    RunnerSession.narrate(emit, silenced: silenced, sink: sink)
                }
                let remainder = rewriter.flush()
                let tail = filter.isEmpty ? remainder : filter.consume(remainder) + filter.flush()
                RunnerSession.narrate(tail, silenced: silenced, sink: sink)
                continuation.resume()
            }
        }

        async let stderrText: String = withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var data = Data()
                Self.drain(stderrFD, after: runnerExited) { data.append($0) }
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
        //
        // The same watcher arms the keep-alive hold (L56): once every flow is
        // terminal and the runner has published its session file, the
        // runner is holding and the verdict is settled, so the first Ctrl-C
        // or `runner stop` releases the hold and the run ends with the
        // runner's own status instead of 130.
        let group = child.processGroup
        let watcher: Task<Void, Never>? = (readyFile.path != nil || request.keepAlive) ? Task.detached(priority: .utility) {
            var completeSince: Date?
            var wroteReady = readyFile.path == nil
            var armed = !request.keepAlive
            while !Task.isCancelled {
                if let index = RunnerReportIndex.load(reportDir: request.reportDir),
                   index.isComplete(expectedFlows: request.expectedFlows) {
                    let published = request.keepAlive && child.isRunning
                        && request.sessions.session(forRunnerPid: child.pid) != nil
                    if published, !armed {
                        SignalRelay.shared.armHold(group: group)
                        armed = true
                    }
                    if !wroteReady {
                        if request.keepAlive, child.isRunning, !published {
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
                            reportDir: request.readyReportDir
                        )
                        readyFile.write(state)
                        wroteReady = true
                    }
                    if armed || !child.isRunning { return }
                }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        } : nil
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
        runnerExited.mark()
        // Nothing is held any more: a signal from here on interrupts.
        SignalRelay.shared.disarmHold(group: child.processGroup)
        // SignalRelay marks itself terminating before it reaps the group, so a
        // runner killed by an interrupt is already visible as one here.
        // After a release (L56) the runner normally exits 0 or 1, the verdict
        // its flows earned; one that exits 130, or dies by the release's
        // SIGINT/SIGTERM/SIGKILL, was interrupted (a crash or our own
        // --timeout kill is not).
        let interrupted = SignalRelay.shared.isTerminating
            || (SignalRelay.shared.wasReleased(group: child.processGroup)
                && SignalRelay.releaseWasInterrupted(
                    status: status, signal: child.terminatingSignal, timedOut: killed.isSet
                ))
        // The runner is gone; make sure nothing it started is still holding the
        // simulator (this also ends the watchdog). Harmless when the group is
        // already empty.
        child.signalGroup(SIGTERM)
        if let lifeline { close(lifeline) }

        await relayFinished
        let stderr = await stderrText
        try? stdoutPipe.fileHandleForReading.close()
        try? stderrPipe.fileHandleForReading.close()

        return Outcome(
            terminationStatus: status,
            stderr: stderr,
            timedOut: killed.isSet,
            interrupted: interrupted,
            terminatingSignal: child.terminatingSignal
        )
    }

    /// Reads `descriptor` until EOF, handing each chunk to `onChunk`. Once
    /// `exited` is marked, it stops after `outputGraceAfterExit` without
    /// data, so a descendant holding the pipe cannot hold grantiva.
    static func drain(_ descriptor: Int32, after exited: ExitMark, onChunk: (Data) -> Void) {
        var buffer = [UInt8](repeating: 0, count: 65_536)
        var lastData = Date()
        while true {
            var poller = pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0)
            let ready = Darwin.poll(&poller, 1, 100)
            if ready < 0 {
                if errno == EINTR { continue }
                return
            }
            if ready == 0 {
                if let since = exited.markedAt, Date().timeIntervalSince(max(since, lastData)) >= outputGraceAfterExit { return }
                continue
            }
            let count = Darwin.read(descriptor, &buffer, buffer.count)
            if count < 0 {
                if errno == EINTR || errno == EAGAIN { continue }
                return
            }
            if count == 0 { return }
            lastData = Date()
            onChunk(Data(buffer[0..<count]))
        }
    }
}

/// When the runner was seen to exit; nil while it runs.
final class ExitMark: @unchecked Sendable {
    private let lock = NSLock()
    private var date: Date?
    func mark() { lock.withLock { if date == nil { date = Date() } } }
    var markedAt: Date? { lock.withLock { date } }
}
