# Task 3 report: optional status and empty device validation

## Source

- Runner base: `64dd5188b0ba981bd71c0ec9ad3e104def2db5d6`
- Source commit: `567fd5f3b911cbb6a49cc7864aac3e64830784c7`
- Branch: `fix4/optional-device`
- Draft PR: https://github.com/grantiva/runner/pull/26
- Runner CI: GitHub Actions run `38423696144`, Test/Lint/Build passed

Optional top-level command failures are now persisted as report status `warned`, retain their structured error detail, count as successful for flow callbacks and aggregation, and allow later required steps to run. Required failures remain `failed`, stop later work, fail the flow, and produce a JUnit failure. Report command summaries expose a `warned` count, JUnit renders warned error detail in `system-out`, and Allure treats warned commands as passed.

The existing public `--device` flag and its pre-existing `--udid` alias now reject explicit empty or whitespace-only values before flow validation, device discovery, or signing. The process maps this argument error to usage exit 64. `--serial` remains unknown; no new public aliases were added.

## Test-first evidence

The source-compatible production-report regression was applied to a detached clean base worktree and run with:

`go test ./pkg/executor -run TestRunner_Run_OptionalStepFailure -count=1`

It failed behaviorally because the decoded optional command was `failed`, wanted `warned`. Raw output: `findings/evidence/fix4-3/unit/behavioral-red.txt`.

An earlier aggregate red run also established that explicit empty `--device` reached flow-file validation rather than returning its flag error. Its log is retained as `findings/evidence/fix4-3/unit/red.txt`; its executor portion was compile-red while the new report constant was first introduced, so it is supplementary rather than the canonical L79 RED.

## Verification

Focused semantic checks passed:

- `go test ./pkg/executor -run TestRunner_Run_OptionalStepFailure -count=1`
- `go test ./pkg/cli -run TestTestCommandRejectsEmptyDeviceBeforeDiscovery -count=1`
- `go test ./pkg/report -run 'TestGenerateJUnit|TestJUnit' -count=1`
- `go test ./pkg/core -run TestCommandResultStepStatus -count=1`

The required explicit package verification passed:

- `go test ./pkg/executor/... ./pkg/core/... ./pkg/report/... ./pkg/cli/...`
- `go vet ./pkg/executor/... ./pkg/core/... ./pkg/report/... ./pkg/cli/...`

Raw outputs are `findings/evidence/fix4-3/unit/green-final.txt` and `findings/evidence/fix4-3/unit/vet.txt`. Tests ran with `GRANTIVA_API_KEY` unset, `GRANTIVA_SESSION_ID=fix4-3`, and the fresh home recorded in `unit/home-path.txt`. `unit/home-after-final.txt` is empty, proving the unit runner home remained empty.

## Scoped integration status

Source/spec review passed with no findings in `task-3-source-review.md`.

The task-scoped Android/CLI integration used only owned AVD `fix4-3-android` on serial `emulator-5580`, a task-owned APFS-cloned runner home, and initially current merged CLI `03cee568869c45077c3015f97f8b75d19ea822c4`. The demo was rebuilt from clean source commit `1552ae983a27528eff4c1f8145aa075698b47f71`; the new APK is retained under `findings/evidence/fix4-3/artifacts/` with SHA-256 and source/build provenance for Task 8.

Direct runner argument acceptance covered both the canonical flag and its existing public alias with empty and whitespace-only values: `--device ""`, `--device "   "`, `--udid ""`, and `--udid "   "` each exited 64 with `invalid argument: --device must not be empty` before discovery/signing. The `--serial x` control exited 1 with `flag provided but not defined: -serial`. Exact shell-escaped argv, stdout, stderr, and exit files are under `live/device-argv/`.

After replacing the runner in the CLI's versioned task-home install directory, the first three text-mode and three JSON-mode optional repetitions proved the runner surfaces but exposed that merged CLI `03cee568` omitted the warned command from its own text/JSON step lists. Those omission captures remain unchanged under `live/optional-{text,json}-{1,2,3}-final/` and are consolidated in `live/acceptance-summary.txt`.

The required text and JSON controls both exited 1. Their flow/report/ready surfaces are failed, the missing tap retains `element_not_found`, the following command is explicitly `skipped` in the decoded flow detail and command summary, and JUnit has one failure. Raw proof is under `live/required-{text,json}/`.

An initial run at `live/optional-text-1/` accidentally exercised the cloned home's versioned bundled runner because replacing the legacy root-level binary did not replace Task 4's versioned install. It is excluded from acceptance. `live/installed-task-runner-path.txt` and `installed-task-runner-sha256-final.txt` prove the corrected versioned runner path and bytes used for all `-final` runs.

The narrow CLI counterpart was independently source/spec/quality approved at `c1373f6c07bf97ec5cb7978d45c954902958c04a`. A joint replay used its reviewed binary SHA-256 `c87ae8a4c30d75daf6b7b724e1526b2d1a8f954da422fb18e5343e18358b9f73`, runner commit `567fd5f` and binary SHA-256 `001b34982362260f615c979fd65430db8ae53fc1815a39f736f2055137676610`, emulator PID `88465`, and owned CPU-load PID `2958`. Exact provenance and argv are under `live/joint-final/`.

In the joint replay, three text runs each show the missing optional tap with `⚠`, retain the literal `element_not_found` detail, show the later assertion passed, summarize the flow as passed, and exit 0. Three JSON runs each expose the tap with status `warned` and the same detail, the later assertion passed, `allPassed:true`, and exit 0. All six runner reports agree on `passed:2, warned:1, failed:0`; ready files say passed/passed and JUnit says `failures="0"`. Required text and JSON controls both exit 1, show the missing tap failed with `element_not_found`, record the later assertion explicitly `skipped`, fail report/ready, and emit JUnit `failures="1"`. The consolidated proof is `live/joint-final/acceptance-summary.txt`.

Cleanup stopped exact emulator PID `88465` and load PID `2958`, removed serial `emulator-5580` and its forwards, deleted only AVD `fix4-3-android`, removed the scoped runner home and the two task-created disposable worktrees, and left protected `Pixel_8_API_35` as the only AVD. `live/joint-final/cleanup-summary-final.txt` records every owned PID/path absent plus final serial/forward/AVD inventories. The fresh APK and source/hash provenance remain in controller evidence for Task 8.

This is task-scoped integration evidence; Task 8 must repeat it against the final repacked candidate after Task 7.
