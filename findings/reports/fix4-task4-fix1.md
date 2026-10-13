# Task 4 review fixes, round 1

Status: **DONE_WITH_CONCERNS** — both Important L78 review findings and the introduced warning leakage are fixed; scheduled live acceptance, fresh review, final-tree CI, and merge remain pending.

- Worktree/branch: `/Users/kyle/Developer/grantiva-cli/.worktrees/fix4-lifecycle-output`, `fix4/lifecycle-output`.
- Reviewed base: `78e9b7526c80bb5f9c2892c19c1d3b31841cce3f`.
- Fix commit: `9c7748523e703338887124a52a0a3af6d40a884b` (`Revalidate log child identity and bound cleanup inventories`). No attribution lines. No push; controller owns draft PR #208 updates/re-review.
- Review input: `.superpowers/sdd/2026-10-13-round4-fix-wave/task-4-review.md`.
- Changed files: `Sources/GrantivaCore/Runner/LogStreamer.swift`, `Tests/GrantivaCoreTests/LogStreamerTests.swift`.
- Evidence: `findings/evidence/fix4-4/unit-fix1/`, with SHA256 manifest. No device actions or subagents.

## Important issue 1: reused PID before initial signal

Ownership discovery now brackets the command inventory with kernel identity reads. The captured identity contains both `pbi_start_tvsec` and `pbi_start_tvusec`, so two starts in the same second are distinct. A stable discovered identity is retained; a replacement cannot inherit an earlier PID's ownership. Immediately before each initial or escalation signal, cleanup obtains a fresh command inventory, requires the exact marker token and executable, requires the previously captured identity to match, then rechecks that identity before signaling. Marker prefix/suffix lookalikes do not match. This is confined to LogStreamer; RunnerStopMarker's other callers are unchanged.

Semantic RED (`red.log`, exit 1): the reused PID and changed-marker cases each recorded signal target `[500]` instead of `[]` with the behavior-neutral inventory/identity/signal seams. GREEN includes replacement during inventory, replacement between stable discovery and signaling, and marker-change cases; all record no signal to the replacement. The replacement identities intentionally differ only in microseconds.

## Important issue 2: stalled inventory and final confirmation

Every inventory receives the cleanup deadline still in force. The subprocess output is drained with nonblocking reads while the child runs, avoiding a blocking EOF read or wait. Inventory reserves part of its remaining budget for SIGKILL of its exact child and synchronous observation of Foundation's reap; Foundation maintains child-reaping ownership throughout. Expiry returns the explicit incomplete-cleanup result. The outer cleanup performs no extra inventory after its deadline, including for final absence confirmation.

Semantic RED (`red.log`): an inventory configured with a 100 ms budget blocked for about 578 ms and returned normally. GREEN kills/reaps the stalled exact inventory child within the bound; a late final-confirmation inventory shares the remaining outer deadline, returns incomplete, has no extra unbudgeted snapshot, and leaves `kill(pid, 0)` at ESRCH plus `waitpid(..., WNOHANG)` at ECHILD. A 128 KiB output control proves that full pipes do not deadlock successful inventories.

## Minor warning and file-list reconciliation

The expected failed-inventory warning is captured from stderr and asserted exactly once. The final focused logs contain no leaked `Warning: could not confirm log-stream cleanup ...` line. The unrelated existing CLILogHandler protocol deprecation, when emitted by a build, remains outside scope; this report does not call all historical output pristine.

The brief's named files below deliberately have no hunks:

- `Sources/GrantivaCLI/RunCommand.swift`: existing `startLogStream` passes the real iOS argv through LogStreamer, and the existing `defer { logStreamer?.stop() }` covers success/failure. SignalRelay invokes the streamer's registered cleanup. The fix belongs in that shared cleanup implementation.
- `Sources/GrantivaCore/Runner/FlowReferenceResolver.swift`: its reachable project-relative map was already correct; the narrower L75 instruction explicitly required changing only RunnerSession's merge precedence.
- `Tests/GrantivaCLITests/RunCommandTests.swift`: the new L78 behavior is exercised through production LogStreamer start/stop, exact subprocesses, injected ownership inventories, and warning capture in LogStreamerTests. RunCommand's routing did not change.
- `Tests/GrantivaCoreTests/RunnerExecutionTests.swift`: runner execution/hold/report orchestration is unchanged by these fixes. The affected lifecycle helper regressions are in RunnerLifecycleCommandTests and LogStreamerTests.

No empty changes were added to satisfy the file inventory.

## Verification and remaining gates

All test invocations remove `GRANTIVA_API_KEY`, use a fresh empty scoped `GRANTIVA_RUNNER_HOME`, and assert the home remains empty. The exact directories, command outcomes, and emptiness are recorded in `red-status.json`, `green-status.json`, and `final-status.json`.

- `swift test --filter LogStreamerTests`: semantic RED, then GREEN; final **19 tests, zero failures**.
- `swift test --filter RunnerLifecycleCommandTests`: final **63 tests, zero failures**.
- `git diff --check`: passed before commit.

No full suite was repeated during this review round, preserving the controller's host-load constraint. The earlier 1,976-test full pass predates both the final argument-order correction and this L78 review fix; the final-tree CI/full-suite gate remains open. This qualification supersedes any interpretation that the current commit has a full-suite pass.

All original live controls remain pending: L68/AND-127 app readiness and cleanup; L69/N3-03 starting/null-port lifecycle on both platforms; L72 startup/ready interruption and genuine timeout/death controls; L73 live force/no-op/refusal/helper cleanup; L78 marked NSPredicate validity, immediate child absence after success/failure/SIGINT, concurrent-stream survival and truthful diagnostics; L71 absent/installed/app-file install output; L53/L75/L76 empty target, canonical cycle and harmless lookalike controls. Task 7's notes/logTail compatibility gate remains separately assigned and unresolved here.
