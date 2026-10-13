# Optional tap failure is reported as a failed flow and exits nonzero

Severity: contract
Component: runner command report / CLI result aggregation boundary
Platforms: Android (reproduced); shared runner semantics
Rows: AND3-OBS-01 (side finding; no matrix row invented)
Candidate: CLI 8f2cff676b3c12e951478920fa20e600cdca4e29; runner fd9d8e8; QA binary SHA256 3f3293aaf1522fefe8d46457370b32a20fa8c657461bf32af086e75a754a73f8.
Status: independently confirmed during round-3 verification.

## Expected

A failing step with `optional: true` may wait through the runner's optional-find budget, but it must not fail the flow. It should be represented as a non-blocking warning (or otherwise as successful optional handling), later steps must continue, the flow must count as passed, and the CLI must exit 0. The same missing selector without `optional: true` must remain a required failure and exit nonzero.

This is separate from B2-L05/B3-L05's first-lookup latency contract. In the repro below, the first exact-text lookup returns with no match in 100–150 ms, well inside the two-second requirement. The approximately seven-second step duration is the intended optional polling budget, not a slow first 404 response.

## Actual

Three exact repetitions of a two-step flow (`launchApp`, then `tapOn: {text: "No Such", optional: true}`) each exit 1. The CLI's post-run human output prints the optional tap as `✗` and reports `0 passed, 1 failed`; the flow JSON records the command as `failed` with `error.type=element_not_found`.

The runner itself reaches the opposite overall verdict: runner stderr prints the flow as `PASS`, and `report/report.json` says top-level `status: "passed"` with summary `1 passed, 0 failed`. The defect is therefore the inconsistent command-level status crossing into CLI aggregation, not runner flow aggregation.

The underlying lookup is fast:

| Run | first exact-text `POST .../elements` | content-description fallback | regex fallback | optional step | CLI |
|---|---:|---:|---:|---:|---:|
| 1 | 99.737 ms | 606.890 ms | 24.782 ms | 7106 ms, failed | 1 |
| 2 | 129.910 ms | 603.117 ms | 26.115 ms | 7086 ms, failed | 1 |
| 3 | 150.490 ms | 607.959 ms | 26.882 ms | 7104 ms, failed | 1 |

Thus this defect is status/report/exit handling after the optional lookup exhausts its polling budget. It is not evidence that the first element request missed L05's latency bound.

## Repro and evidence

Use the preserved immutable harness and input in the Android slice:

- `findings/evidence/cov3-android/B2-L05-L06-exact-rerun3/input/controller-script.sh`
- `findings/evidence/cov3-android/B2-L05-L06-exact-rerun3/input/l05-absent.yaml`
- `findings/evidence/cov3-android/B2-L05-L06-exact-rerun3/runs/l05-absent-{1,2,3}/stdout.txt`
- `findings/evidence/cov3-android/B2-L05-L06-exact-rerun3/runs/l05-absent-{1,2,3}/result.json`
- `findings/evidence/cov3-android/B2-L05-L06-exact-rerun3/runs/l05-absent-{1,2,3}/report/client.log`
- `findings/evidence/cov3-android/B2-L05-L06-exact-rerun3/runs/l05-absent-{1,2,3}/report/flows/flow-000.json`

The three repetitions use the same current binary, owned Android device, and frozen flow. All produce the same status/exit failure. Independent analysis is in the CLI slice at `findings/android-b2l02-l05-l06-b3l05-l06-review.md`.

## Supported cause

At runner head fd9d8e8, `pkg/executor/flow_runner.go` executes the step and writes its command result before handling optionality. `executeStep` maps an unsuccessful driver result to `report.StatusFailed` and closes the command as failed. The outer loop then sees `step.IsOptional()` and continues, correctly leaving the flow status passed, but it does not change the recorded command to a warned/non-failing representation.

At CLI head 8f2cff67, `Sources/GrantivaCore/Runner/RunnerReportSteps.swift` maps every command whose raw status is `failed` to a failed `StepResult`, without considering the enclosing flow's passed verdict or the command's optionality. `Sources/GrantivaCLI/RunCommand+Result.swift` then counts a flow as passed only when every reconstructed step is passed, and `Sources/GrantivaCLI/RunCommand.swift` uses the same all-steps-passed test to throw `ExitCode.failure`. That explains the observed contradiction: runner report passed, CLI summary failed, process exit 1.

The intended contract is explicit in the same head:

- `pkg/executor/runner_test.go`, `TestRunner_Run_OptionalStepFailure`, says “Flow should still pass because the failing step was optional” and expects `StatusPassed`.
- `pkg/core/status.go` defines `StatusWarned` as “Optional step failed (non-blocking)” and treats it as successful.
- `pkg/core/result.go` says optional warned results do not make `AggregateStatus` fail; the retained raw report confirms that the runner's overall aggregation already passes.
- `pkg/executor/flow_runner.go` already has a warned-result reporting path, but the failing top-level optional step does not reach it as warned.

The exact repair point remains an implementation choice: the runner may persist a warned/non-failing optional command status, or the CLI report decoder may reconcile command optionality with the authoritative passed flow verdict. All report surfaces must remain consistent, and the fix must not convert required failures into warnings.

## Acceptance criteria

- Run the preserved missing-selector flow at least three times. The optional tap may consume its documented optional-find budget, but each run exits 0, the flow is counted as passed, and no command/report surface calls it a required failure.
- Text, JSON, JUnit, and ready/report summaries agree on the successful overall outcome. They may expose the optional miss as a warning with its useful `element_not_found` detail.
- Add a following required step and prove it executes after the optional miss.
- Run the same missing tap without `optional: true`; it remains `element_not_found`, fails the flow, skips later required steps as appropriate, and exits nonzero.
- Add or strengthen exact runner tests that exercise the production report writer and process-exit aggregation, rather than only the in-memory runner result.
- Preserve the fast first-request behavior and the documented optional polling budget; do not “fix” the status defect by shortening or bypassing selector fallback.
