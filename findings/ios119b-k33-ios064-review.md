# iOS attempt 119b — B2-K33 and IOS-064

## Evidence scope

Attempt 119 is excluded: it used the wrong session ID. Attempt 119b uses the owned iOS project and UDID, candidate QA binary hash `3f3293aa…754a73f8`, and retains four valid outcomes: success plain 0, success verbose 0, crash failure verbose 1, and SIGINT sent to the positive CLI PID with verbose exit 130. The success and failure inventories contain no surviving `log stream` process.

## B2-K33 [ios]

**Approve pass.** The verbose success and failure captures each print the full `$ /usr/bin/xcrun simctl spawn … log stream` start line and a matching terminal `exit 143` line. The SIGINT capture prints the same start command and `stopped by SIGTERM` with the complete command. Plain mode omits those debug records. The retained exact-head `LogStreamerTests`, `ChildProcessTests`, `SubprocessLogTests`, and `CLILogHandlerTests` pin start/end formatting, termination logging, and ordinary redaction behavior. Joined with the already retained iOS record-video verbose/plain evidence, this covers K33's log-stream, runner, recorder, plain-versus-verbose, and source-test clauses.

## IOS-064

**Fail: product cleanup defect; draft a focused L78 brief.** Success and crash failure leave no observed log-stream process, but the Ctrl-C leg does. Immediately after the CLI exits 130, `sigint-after-processes.txt` contains PID 17077, state `R`, command `log stream --style compact …`, already reparented under the simulator's launchd-side parent. `sigint-active-observed` is `1`. The process is absent from `sigint-after-2s-processes.txt`, so the leak is bounded, but the binding row says “No orphan `log stream`” after success, failure, and Ctrl-C. A live reparented process after the owning CLI has returned is an orphan under that criterion; a two-second eventual exit does not make the literal observation pass.

The source supports a narrow cause and fix scope. `RunCommand.swift:424-459` registers `defer { logStreamer?.stop() }`; `LogStreamer.swift:115-180` starts `/usr/bin/xcrun simctl spawn … log stream` with Foundation `Process` and registers a SignalRelay cleanup. `LogStreamer.stop()` at `:182-211` sends `terminate()` to the `xcrun` process and polls that `Process.isRunning` for up to two seconds. It does not verify that the spawned simulator-side `log stream` process is gone before clearing its state and allowing the CLI to return. The SIGINT log's “stopped by SIGTERM” therefore describes the tracked xcrun wrapper, while the immediate process inventory proves the underlying stream is still alive.

This is not an expectation correction. The no-orphan requirement is clear, the other two modes already meet it, and bounded eventual cleanup is useful diagnostic context rather than an alternate documented contract. L78 should require all three run outcomes to return only after both the tracked wrapper and the spawned log-stream process are absent, with a regression test that models a wrapper exiting before its child and a live SIGINT check that performs the immediate post-exit inventory. The fix should preserve K33's single terminal diagnostic.
