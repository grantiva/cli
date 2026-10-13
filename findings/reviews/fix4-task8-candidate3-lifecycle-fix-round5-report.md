# Task 8 candidate 3 lifecycle helper fix round 5

## Classification and source diagnosis

Attempt 2 is a helper false failure at the first detached iOS capture join. It is not a passing lifecycle phase and must remain immutable. Both startup-interrupt cases passed their genuine-starting, exit-130 and exact-notice assertions before this failure.

The actual frozen source is `/Users/kyle/Developer/grantiva-cli/.worktrees/release-round4-candidate3`, SHA `6ba12ed37658228a3ce87cb64e1f5d88dda38e07`, as recorded by attempt 2's `helper/verified-candidate-identity.json` and invocation arguments. In that checkout, `Sources/GrantivaCLI/DriverCommand.swift:219–224` creates the unique `grantiva-session-<UUID>` directory, puts the report and generated flow inside it, and defers removal of the whole directory. The detached branch at lines 241–244 returns after runner lease handoff. `startDetached` checks the completed launch report, records the ready session, emits started JSON, and returns the PID (lines 617–663). Thus normal detached-command completion removes launch files while the ready runner remains alive. This is separate from runner teardown. `completedLaunchStatus` at lines 349–353 checks report completion before readiness.

Raw evidence under `findings/evidence/round4-smoke-candidate3/03-lifecycle-attempt2` supports that sequence:

- `invocation/stderr.log` fails in `detach_ready` at `stop_report_snapshot`, solely on the required terminal-source existence check.
- `helper/detach-ready/ios.result.json` records detached CLI PID 69379 exit 0. `ios.stdout` records started runner PID 69412, port 8274, exact owned device `33BCE8AB-B7F2-4D47-B0B8-2CB1D8A1971E`.
- `helper/owned-resources.json` binds PID 69412 to that exact device and the `--output`/generated-flow paths under `grantiva-session-85FC0F56-7659-4C29-8B67-667342FBD55F`.
- `helper/detach-ready/ios-runner-report/report.json` is passed with a top-level endTime and a single passed flow with endTime. Its device and flow source path match the authenticated ownership record. The report has summary 1 passed, 0 failed/running/pending; both commands passed.
- Its retained `maestro-runner.log` records flow completion, report generation, and `keep-alive: holding session 69412-1791927082392620000 (port 8274)`.
- `ios-snapshot-terminal.json` truthfully records reportWasPresent/snapshotCaptured true and terminalReportAbsent true. It was retained before normal detached-command cleanup.
- Only after the helper failure, `helper/cleanup.json` and `failure-cleanup/stop-69412.stdout` show exact runner-stop exit 0/status stopped for that still-owned PID/device.

The round-4 change handled source deletion after its first successful join but incorrectly still required live source existence at the first join. This is the remaining false assumption corrected here.

## Smallest correction

The worker still copies a present source, records terminal absence otherwise, and propagates all copy/ownership errors unchanged. It no longer raises solely because the source is absent. The joined caller requires a recorded terminal source state and, for every mandatory case, still parses the retained report and requires complete passed top-level and flow statuses/end times. Missing, malformed, incomplete, and failed retained reports still fail. No source-disappearance exception is caught or suppressed during an actual copy: stable-file copy errors still propagate.

Ready interruption retains its pre-SIGINT join/validation. Force teardown retains its pre-teardown join/validation. Detached readiness validates at its existing join, now using authenticated retained bytes if the launching command already removed the source. Repeated stop does not recopy. Startup's explicitly optional capture, raw bytes, terminal metadata, timing, PID/device authentication, ownership recording, non-daemon joins, and cleanup are unchanged.

## Covering checks

Command from regression worktree:

```text
python3 .superpowers/sdd/2026-10-13-round4-fix-wave/task8-candidate3-lifecycle-fix-round5-fixtures.py
```

Output:

```text
test_actual_attempt2_report_with_source_removed_before_first_join ... ok
test_ast_cleanup_order_and_unchanged_startup_timing ... ok
test_incomplete_and_failed_reports ... ok
test_missing_required_report ... ok
test_optional_startup_retains_raw_bytes_and_terminal_absence ... ok
test_ownership_error_propagates ... ok
test_passed_capture_then_removed_source_and_repeated_stop ... ok
test_required_failed_source_removed_before_first_join ... ok
test_required_incomplete_source_removed_before_first_join ... ok
test_required_missing_source_removed_before_first_join ... ok
test_required_passed_source_removed_before_first_join ... ok
test_stable_copy_error_propagates ... ok
test_terminal_copy_error_propagates ... ok
Ran 13 tests in 0.130s
OK
```

The new fixtures exercise the actual worker/authentication/join methods with bounded events: after authenticated capture, the source report and generated flow disappear BEFORE the first stop/join while the mocked exact live runner and project session remain. A complete passed retained report succeeds; missing/incomplete/failed retained reports raise the expected specific failure. Successful cases assert retained report device and flow source match the exact authenticated ownership argv and retained paths. One case reads the real attempt-2 report, rebasing only device and source paths to isolated fixture identities. The previous eight checks remain included: startup optional raw retention, copy/ownership error channels, missing/incomplete/failed reports, repeated join after deletion, and AST phase ordering. All workers are joined. No helper main/constructor, live process command, device, network, product test, or build was run.

## Artifacts

`task8-candidate3-lifecycle-fix-round5.diff` is the exact round-4-reviewed-to-round-5 helper delta. `task8-candidate3-lifecycle-fix-round5-before.py` retains its reviewed input. Covering fixtures are `task8-candidate3-lifecycle-fix-round5-fixtures.py` plus imported `task8-candidate3-lifecycle-fix-round4-fixtures.py`. The full preparation diff and report are updated. No evidence, product source, durable helper, commit, push, promotion, or reviewer operation was changed or performed. Root owns review and any fresh live rerun.

SHA-256:

```text
e5ece28eed78f72feb2e0ec7ef0e2da83bfc5b13dda56aeb788360ac907d13b8  task8-candidate3-harness/lifecycle_smoke.py
4c7c2f8e690c5630769d897d20f28569a480d08d73a336db5fb577be5114489c  task8-candidate3-lifecycle-fix-round5.diff
18937798f7c3cdf7fb58350fe1fdd94a566a0387e9261e7506cb1720959ec0ca  task8-candidate3-harness-preparation.diff
```
