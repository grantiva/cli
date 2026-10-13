# Task 8 candidate 3 lifecycle helper fix round 4

The round-3 P1 is addressed in the prepared helper only. Ready interruption now stops and joins its authenticated snapshot worker after the ready-state hierarchy check and before SIGINT. `stop_report_snapshot` validates the retained `report.json` for every required caller: top-level status must be passed with an end time, and the nonempty flow list must contain only passed flows with end times. Missing, malformed, incomplete, or failed reports raise. This uses the terminal report shape observed in the existing runner evidence; it does not change product acceptance or product code.

Force teardown already joins before `simulator teardown --force`; the shared required validation now applies at that existing join. Detached readiness also gains the same completion validation, with its existing passed-report check left intact. After a successful capture, repeated stop calls validate retained bytes only and never recopy from the live report directory. The ready-interrupt finally block therefore remains safe after production deletes that source.

Startup still uses the explicit optional policy. It observes starting, authenticates without waiting for ready, signals at the same point, and retains its existing exit-130/notice/owned-cleanup assertions. Raw observed report bytes and explicit terminal-source metadata remain intact. The original candidate-3 live attempt remains immutable and classified as a helper false failure after passing iOS startup-interrupt assertions; it is not a completed lifecycle grade.

The session parse/process-disappearance catch is now limited to reading session identity and binding the process. It no longer surrounds copying or ownership recording, so ownership `KeyError` and other ownership/copy failures reach the existing worker error channel and caller. Exact PID/device binding, readiness/error handshake, non-daemon thread joins, phase timings, and scoped cleanup are otherwise unchanged.

## Verification

Command (from the regression worktree):

```text
python3 .superpowers/sdd/2026-10-13-round4-fix-wave/task8-candidate3-lifecycle-fix-round4-fixtures.py
```

Output:

```text
test_ast_cleanup_order_and_unchanged_startup_timing ... ok
test_incomplete_and_failed_reports ... ok
test_missing_required_report ... ok
test_optional_startup_retains_raw_bytes_and_terminal_absence ... ok
test_ownership_error_propagates ... ok
test_passed_capture_then_removed_source_and_repeated_stop ... ok
test_stable_copy_error_propagates ... ok
test_terminal_copy_error_propagates ... ok
Ran 8 tests in 0.042s
OK
```

The fixtures import the actual helper without invoking its main or constructor and exercise its real capture/authentication/join methods in bounded temporary filesystem/thread cases. Process binding and ownership persistence are mocked; no process/device command runs. The optional startup fixture coordinates a live capture thread through source deletion and checks exact retained binary bytes and terminal absence metadata. The required-success fixture deletes source/session/flow after successful validation, forbids any subsequent copy operation, and successfully calls stop again. Missing report and five incomplete/failed documents reject. Copy failures both before authentication and during terminal capture propagate; ownership failure propagates through both wait and join. All started workers are joined. AST assertions additionally check ready SIGINT and force teardown ordering and unchanged startup timing; this is not a live phase run.

No evidence, product source, durable helper, build, device, network, commit, push, or reviewer operation occurred. Root still owns the fresh full lifecycle rerun.

## Review artifacts

- `task8-candidate3-lifecycle-fix-round4.diff`: exact round-3-reviewed helper to round-4 helper delta.
- `task8-candidate3-lifecycle-fix-round4-before.py`: reviewed input snapshot for reproducibility.
- `task8-candidate3-lifecycle-fix-round4-fixtures.py`: covering fixtures.
- `task8-candidate3-harness-preparation.diff`: full prepared helper diff updated only in the lifecycle helper section.
- `task8-candidate3-harness-preparation-report.md`: updated policy description.

SHA-256:

```text
38a48f3765fd4615f483f066ed6519da0f9fa31746f52aa3dd66dc37ed21e0d9  task8-candidate3-harness/lifecycle_smoke.py
b79c7ec546c5092c54c3e623bc7a57edce4bfaa29b382acd466b056e56bec347  task8-candidate3-lifecycle-fix-round4.diff
0303c7dcdd98457a7629ebfe5f79978ed9bfb8b7f56b99fb3e1f85de151ad9be  task8-candidate3-harness-preparation.diff
```
