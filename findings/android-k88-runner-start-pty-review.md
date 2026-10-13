# Android B2-K88 runner-start PTY review

## Verdict

**PASS as a joined row.** The new PTY capture closes the only prior Android gap; retained detached/dead-runner evidence and exact-head lifecycle tests cover the remaining branches.

## Foreground and terminal clauses

- `B2-K88-runner-start-pty-rerun1/run/command.json` is an exact foreground `runner start --platform android --device emulator-5554 --application-id com.kylebrowning.landmarks` with no `--detach`.
- `elapsed-before-sigint.txt` is `30.009131`, proving it stayed attached until the scheduled terminal SIGINT rather than returning after startup.
- `transcript.txt` streams the real runner banner, Setup, session creation, flow progress, report output, keep-alive state, and the Grantiva SIGINT cleanup notice through the PTY.
- A concurrent `runner dump-hierarchy` exits 0 in `0.635850` seconds while the foreground process is alive.
- The foreground command exits the documented `130`; runner PID 36913 is dead afterward. The project session is removed, the owner sidecar exists during the run and is absent afterward, and the decoded audit records both the owned global files and lease/session cleanup as successful.
- The post-cleanup `runner stop` exits 0 with `No active session found.` The wrapper's false `postStopReportsNoSession` is an overstrict word check: the actual output is precisely a no-session result.

## Joined clauses

- Detached behavior remains covered by current Android detached-start groups, including `N2-05-B3L13-dead-runner-stop-json-rerun2`: detach returns, the runner survives for control, and stop cleanup succeeds.
- That same dead-runner capture kills the verified row-owned detached PID and records `alreadyExited:true`, `killed:false`, the exact Android serial, and cleanup in `stop.json`.
- Exact candidate `RunnerLifecycleCommandTests.testStopOfADeadRunnerSaysItHadExited` asserts the required text rendering `No running runner (pid 1234 had exited); cleaned up its session.` and the matching `alreadyExited` JSON semantics, including Android serial shape.
- `testForegroundHoldWaitsForTheRunnerThenCleansUp` and `testForegroundHoldCleansUpOnceOnInterrupt` semantically assert that foreground start cannot return before child exit/signal and cleans exactly once.

The matrix's dead-pid wording is therefore supported by the current dead-pid runtime state plus the exact named semantic test, consistent with the accepted iOS-half treatment; the new PTY capture directly establishes the terminal-only behavior that source tests could not substitute.

Evidence roots:

- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B2-K88-runner-start-pty-rerun1/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/N2-05-B3L13-dead-runner-stop-json-rerun2/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCLITests/RunnerLifecycleCommandTests.swift`
