# Foreground runner start interrupted during startup reports a false WDA timeout

Severity: contract
Component: cli / runner lifecycle
Rows: N2-15 [ios] (B3-L37 [ios] notice remains passing)
Candidate: CLI 8f2cff676b3c12e951478920fa20e600cdca4e29.
Status: evidence-backed triage during the incomplete round-3 coverage pass; steady-ready control pending.

## Expected

A foreground `runner start` ended by SIGINT exits as an interrupt (N2-15 permits the documented interrupt result and specifies exit 130), removes its project session and `/tmp/grantiva-sessions` files, releases the device, and does not report a driver startup failure caused by that same requested interrupt. Plain, quiet, and JSON modes follow the same lifecycle contract; quiet/JSON suppress runner narration.

B3-L37 separately requires the signal notice to name the platform device kind. Its iOS expectation is `[grantiva] received SIGINT — releasing simulator and reaping child processes` in all three modes. The evidence below satisfies that notice clause; this brief does not reopen or weaken B3-L37.

## Actual

Three foreground iOS starts (plain, `--quiet`, `--json`) were each signalled by SIGINT after their row-owned `.grantiva/session.json` appeared with `state: starting`. All three print the correct B3-L37 `releasing simulator` notice and remove their session file, but all three exit 1 and append:

`Error: Timed out waiting for WDA to start.`

The plain case also relays the runner's `Received interrupt, cleaning up...`; quiet and JSON correctly omit runner narration. The false timeout is Grantiva's terminal diagnosis in every mode. Signal-to-exit time is about 5 ms, so this is not an actual startup timeout.

The harness sent SIGINT to the recorded Grantiva foreground process group. It did not use SIGKILL, force teardown, or an owner-device action. Post-command snapshots and absent session files show cleanup completed.

## Evidence and repro

- iOS slice `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt70/` preserves the harness, exact command arrays, foreground PIDs, starting session documents, signal and exit epochs, stdout/stderr, exits, post-process snapshots, and before/after simulator inventories.
- `summary.json` records all three modes with `sessionState: starting`, exit 1, and no session afterward.
- `plain.err`, `quiet.err`, and `json.err` contain the correct B3-L37 signal notice followed by the false WDA-timeout error.
- Independent source/evidence review: CLI slice `findings/ios69b-70-android-k87-review.md`.
- A steady-ready repeat is being retained separately as attempt 70c. It is a scope control and is not assumed or claimed by this draft.

## Cause

Exact candidate `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCLI/DriverCommand.swift:600-704` installs SignalRelay cleanup, starts the runner, records the starting session, and waits for the iOS WDA port.

When SIGINT ends that wait before a port is published, the iOS startup guard at lines 675-700 checks only `requestedStop()`, which represents a `runner stop`/teardown stop marker. It does not normalize `SignalRelay.shared.isTerminating`. With no marker it calls `wdaStartupError`, producing the false timeout and exit 1.

The intended interrupt normalization exists later at lines 729-763 in the steady foreground-hold path: after SignalRelay termination it avoids racing cleanup and throws exit 130. A startup interruption never reaches that branch.

## Acceptance criteria

- Interrupt a foreground `runner start` while its published session is still `starting`: plain, `--quiet`, and `--json` terminate with the documented interrupt status (exit 130 unless the public contract deliberately chooses and documents another interrupt code).
- None of the three modes prints `Timed out waiting for WDA to start` when SIGINT caused the startup wait to end. Plain mode may relay the runner's interrupt acknowledgement; quiet/JSON keep suppressing runner narration.
- Preserve the correct B3-L37 platform notice, project/global session cleanup, lease release, runner/process-group cleanup, and no forced-kill escalation for an orderly SIGINT.
- Preserve genuine WDA startup timeout and unprompted runner-death errors; do not convert those to successful or interrupted outcomes.
- Add focused `RunnerLifecycleCommandTests` for an interrupt delivered during `waitForForegroundWDAPort`, distinct from existing steady foreground-hold tests and stop-marker tests. Assert exit/error normalization and cleanup in plain/quiet/JSON output modes.
- Re-run the three starting-state variants on an owned simulator, plus one steady-ready foreground control, and retain exit codes, output streams, process/session cleanup, and signal timing.
