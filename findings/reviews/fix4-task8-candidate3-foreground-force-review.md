# Candidate 3 dependent foreground final-force review

**Specification verdict: APPROVED for controller execution.**

**Quality verdict: APPROVED.** No blocking, important, or minor finding identified. This is static preparation approval, not a live force acceptance or Task 8 gate verdict. Physical cleanup and independent review of fresh force evidence remain required.

Reviewed the report, complete two-file diff, helper and 13 fake fixture definitions, approved lifecycle review, latest cap ruling in `progress.md`, original `07-final-force-teardown/helper/failure.json`, retained candidate-3 iOS foreground report/detail, and relevant source at frozen CLI commit `6ba12ed37658228a3ce87cb64e1f5d88dda38e07`. The current worktree HEAD differs; executable compatibility was checked against the frozen commit, not current source.

Verified SHA-256:

- New `foreground_force.py`: `a19d5447a70e60c4cac37d3e6435eda1d122194dab0352a2dd1f99a7ddff4c96`.
- Unchanged approved `lifecycle_smoke.py`: `e5ece28eed78f72feb2e0ec7ef0e2da83bfc5b13dda56aeb788360ac907d13b8`.

## Specification and executable compatibility

The separate helper follows the controller's cap ruling: it imports and pins the approved general collector, requires the isolated force phase and explicit owned-iOS force opt-in, and preserves candidate/ownership/live-target checks. The original detached copy failure remains immutable; the new helper neither regrades it nor modifies the completed lifecycle phase.

Frozen `DriverCommand.swift` retains its generated flow/report temporary directory until foreground return, records the ready iOS session only after `waitForIOSLaunchFlow`, and records the foreground runner into the CLI-owned lease with `keepAlive: true`. These support the fixture's lifecycle assumption and its exact session/lease predicates. Frozen `RunnerSessionInfo` encodes the required iOS `state`, `platform`, `pid`, `port`, `bundleId`, and `udid` keys.

The authentication binds the exact positive runner PID and port, iOS device and app, installed runner executable/hash, actual spawned CLI parent PID, exact `--device` value, report `--output`, generated flow argv, and lease owner/runner/device. The report and flow are copied while that exact foreground CLI remains alive. All copy errors propagate. The retained report requires completed passed top-level/flow results, exact device/source-flow identity, contained existing flow data files, and completed passed commands. The actual previously retained candidate-3 foreground report and flow-detail schema supports these assertions, including path resolution across macOS `/var` and `/private/var`.

Before force, the fixture requires a Landmarks hierarchy, unchanged ready session, live device-bound runner, and live CLI, then records the report hash and pre-force proof. It executes the identical command `simulator teardown --udid <owned UDID> --force --json`. Frozen `SimulatorCommand` returns a result array and marks a stopped runner session as reclaimed; requiring exactly one target, matching UDID, true `runnerSessionStopped`/`reclaimed`, and both process arrays is compatible with that source. Empty process arrays are legitimate when orderly session stop already handled the runner.

Frozen `DriverCommand.foregroundEnding` explicitly returns `Runner stopped by teardown (pid <PID>); the session has ended.` for a teardown marker and completes normally. Thus the helper's exact notice and exit-0 requirements are supported, rather than an invented SIGINT expectation. Acceptance additionally requires both exact PIDs absent, project/global session artifacts absent, and the exact lease removed. It records a final process inventory and correctly leaves physical deletion to controller cleanup.

## Evidence quality and failure behavior

Command argv/cwd/start metadata, raw streams and result metadata are retained; command timeouts retain partial stdout/stderr. Spawned foreground streams are direct files, so exit-timeout evidence remains available. The fixture records explicit 600/240/45-second ready/force/foreground-exit limits. Exceptions write failed evidence and cannot reach acceptance.

Failure cleanup signals only the still-running Popen child created by this fixture, then allows its normal SIGINT cleanup and records exact registered-runner/session checks or unconfirmed cleanup. It does not signal a merely discovered process or delete unrelated state. Failed cleanup is not promoted to acceptance. The 13 author-reported fake checks cover the principal success/failure predicates; their definitions were reviewed without rerunning them.

No helper/product source edits, live CLI/runner/device calls, builds, tests, or network operations were performed during this review. Only this review document was added.
