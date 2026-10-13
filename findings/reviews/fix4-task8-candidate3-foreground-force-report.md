# Candidate 3 dependent foreground final-force fixture

Prepared a separate force-only fixture, `task8-candidate3-harness/foreground_force.py`. No approved lifecycle collector, product source, prior evidence, or ledger was changed. No live helper, CLI, runner, device, build, product test, or network operation was executed. Controller owns execution after independent review.

The general collector remains pinned to SHA-256 `e5ece28eed78f72feb2e0ec7ef0e2da83bfc5b13dda56aeb788360ac907d13b8`. The new helper imports its candidate and ownership validation, live target verification, argument validation, ownership recording, exact process/session assertions, start argument construction, and process spawn/wait primitives. It does not run any unrelated lifecycle phase. It requires the existing explicit `--phase force-teardown --allow-force-reclaim-owned-ios` arguments and a fresh output directory, so the controller can reuse the previous candidate/ownership argument set with this new script and a new output root.

The previous force attempt failed before force execution because detached command return deletes its unique temporary directory (`DriverCommand.swift:219–224,241–244`). The dependent fixture starts in foreground and keeps that CLI alive while copying the report. This changes fixture lifetime; it does not suppress copy errors or weaken report acceptance.

The fixture requires an exact ready session (PID, iOS, UDID, app, nonzero port); authenticates runner executable/hash, parent CLI PID, exact `--device`, report/flow argv, and foreground lease owner/runner/device; retains the entire report tree and generated flow; validates complete passed top report, each flow, and each flow's retained command data against the exact device and source flow. It checks CLI liveness before and after copying, requires hierarchy text containing Landmarks, and rechecks unchanged session and live runner before recording pre-force proof. Copy errors remain fatal. The identical `simulator teardown --udid <owned UDID> --force --json` operation must return one exact target with `runnerSessionStopped` and `reclaimed` true and both process arrays.

Frozen `DriverCommand.swift:516–527,825–860` treats a teardown-marked foreground stop as orderly and emits `Runner stopped by teardown (pid <PID>); the session has ended.` The fixture requires that exact notice and exit 0, then verifies both runner and foreground CLI PIDs absent, project/global session artifacts absent, and exact runner-home lease removed. It retains a final process inventory and writes the reclaim record with `physicalDeviceDeleted: false` and `finalCleanupRequired: true`. Physical deletion stays with controller cleanup.

Command metadata, stdout/stderr, exit status and timeout streams are retained. Ready/force/exit limits are 600/240/45 seconds. On failure, cleanup only signals the actual spawned Popen foreground child with SIGINT, allows its normal owned cleanup to finish, and records exact runner/session checks or unconfirmed cleanup; it never signals a discovered unrelated process or deletes foreign state. A cleanup failure cannot produce acceptance. The failure record and raw streams remain reviewable.

## Bounded fixture verification

Command:

```text
python3 .superpowers/sdd/2026-10-13-round4-fix-wave/task8-candidate3-foreground-force-fixtures.py
```

Final output:

```text
test_authentication_parent_executable_and_lease ... ok
test_authentication_rejects_foreign_session ... ok
test_cli_must_remain_alive_before_force ... ok
test_command_timeout_retains_streams ... ok
test_copy_error_is_not_suppressed ... ok
test_force_arrays_and_stopped_flag_required ... ok
test_force_response_must_bind_device_and_fields ... ok
test_foreground_nonzero_is_failure ... ok
test_foreground_notice_is_required ... ok
test_foreground_order_and_exact_force ... ok
test_hierarchy_must_contain_landmarks ... ok
test_incomplete_failed_missing_and_wrong_identity_reports ... ok
test_lease_remaining_is_failure ... ok
Ran 13 tests in 0.026s
OK
```

Tests use isolated temporary files and mocked process/command primitives; they never invoke the helper constructor or a real subprocess. The initial fake authentication test failed because macOS `/var` resolves to `/private/var`; correcting the fake installed-runner path to match production's resolved identity fixed that fixture. Production helper code was unchanged by that correction.

## Artifacts and SHA-256

```text
a19d5447a70e60c4cac37d3e6435eda1d122194dab0352a2dd1f99a7ddff4c96  task8-candidate3-harness/foreground_force.py
89c332f297cb90d4d2a4a4b58c5c756b036bbdaaa4a9bd4477c9f216c0485903  task8-candidate3-foreground-force-fixtures.py
891fd4f5e404eb6bea5e79e86435a38600b5904d85512e4dc04a85e076e0c5d6  task8-candidate3-foreground-force.diff
e5ece28eed78f72feb2e0ec7ef0e2da83bfc5b13dda56aeb788360ac907d13b8  task8-candidate3-harness/lifecycle_smoke.py (unchanged)
```

The diff contains only the new helper and its focused fake fixtures. No independent reviewer was spawned; the controller will assign review.
