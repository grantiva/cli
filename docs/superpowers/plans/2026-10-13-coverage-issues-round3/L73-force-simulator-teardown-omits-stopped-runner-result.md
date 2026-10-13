# Force simulator teardown omits the runner session it stopped

Severity: contract
Component: CLI / simulator teardown JSON
Rows: D2-20 [ios], leg (d)
Candidate: CLI 8f2cff676b3c12e951478920fa20e600cdca4e29.
Status: evidence-backed triage during the incomplete round-3 coverage pass.

## Expected

When `grantiva simulator teardown --udid <UDID> --force --json` targets a simulator with a live detached `runner start` session, it stops that runner first, removes its session files, and reports that work. D2-20(d), README/help, and the command discussion name `runnerSessionStopped` as the JSON signal for this case.

## Actual

An exact detached iOS runner reached `ready` at PID 5064 and port 8191 and answered `runner dump-hierarchy --udid <UDID>`. Targeted force teardown then exited 0, removed the project session, ended PID 5064, and removed the runner home. Its JSON omitted `runnerSessionStopped` entirely and reported `reclaimed:false`, `processes:[]`, and `sessionFilesRemoved:[]`.

The command therefore performs the important cleanup but tells automation that it reclaimed nothing and supplies no required indication that it stopped a runner session.

## Evidence

- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt73/start.out`, `session-before-teardown.json`, and `hierarchy.out` prove the live ready runner.
- `live-teardown.out` and `live-teardown.exit.txt` preserve the successful but incomplete JSON result.
- `session-after.txt` and `ps-after.txt` prove the project session and PID are gone.
- Independent review: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-cli/findings/ios73-android-k111-n208-review.md`.

## Cause

Exact candidate `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCLI/SimulatorCommand.swift:137-167` stops runner sessions before branching on `--force`. The non-force path passes the stopped UDIDs through `marking`, which sets `SimulatorTeardownOutcome.runnerSessionStopped`.

The force path at lines 252-289 passes only reaped-helper metadata into `runForce`. It encodes `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCore/Simulator/SimulatorReaper.swift:26-81` `ForceTeardownResult`, which has no `runnerSessionStopped` field. Since the preliminary stop already ended the runner, the force reaper's later process snapshot is empty and its initializer computes `reclaimed:false`.

## Acceptance criteria

- A targeted `simulator teardown --udid <UDID> --force --json` that stops a live `runner start` reports `runnerSessionStopped:true`.
- Its JSON truthfully reports that teardown reclaimed/stopped the runner; it must not return `reclaimed:false` merely because the preliminary orderly stop finished before live-process inspection.
- The project and shared session files are removed, and the retained filesystem checks prove that no stale session remains. Do not require `sessionFilesRemoved` to list an orderly live-session removal if that field remains scoped to stale files.
- Preserve the existing no-op force case: a genuinely free simulator reports `reclaimed:false` and does not claim a stopped runner.
- Preserve non-force teardown behavior and helper/process arrays.
- Add a focused command test for the force path with a live runner session, distinct from the existing non-force `SimulatorTeardownOutcome` marking test.
- Re-run the ready detached-session case and retain start JSON, successful hierarchy, force-teardown JSON, process/session cleanup, and a free-simulator control.
