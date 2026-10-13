# iOS composite-row source evidence package

This is a read-only source-clause package for B2-K05, B2-K18, B2-K81, B2-K82-a, and B2-K93. It does not grade any whole row and does not replace runtime clauses.

## Provenance

- CLI candidate: `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main`, exact HEAD `8f2cff676b3c12e951478920fa20e600cdca4e29`.
- Runner candidate: `/Users/kyle/Developer/maestro-runner/.worktrees/release-round3b`, exact HEAD `fd9d8e8d1cb109eda6116f4221da10257b9838e3`.
- Existing CLI CI log: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-cli/findings/evidence/cov3-cli/B3-L31/ci-run-38227743323.log`. Lines 92–106 show fetch/checkout of exact CLI commit `8f2cff67`; named test lines below therefore apply to that candidate.
- No preserved runner CI/test log naming `TestStepAndFlowDurationsAgreeAcrossOutputs` was found in the campaign evidence. The runner semantic source match is exact-head evidence only and must not be described as an executed test.

## B2-K05 — duration consistency

Exact runner source: `pkg/executor/duration_consistency_test.go:30-146` at `fd9d8e8`.

`TestStepAndFlowDurationsAgreeAcrossOutputs` is an exact semantic match for the named source clause:

- lines 30–35 state that `OnStepComplete` and `FlowWriter` share the command duration, including failures, and that slow failure artifact capture is excluded;
- lines 36–60 run passing and failing variants and make failure screenshot capture sleep 300 ms;
- lines 74–78 collect live step and flow callback durations;
- lines 98–119 compare every callback duration to the report command duration and prove the failing duration excludes the 300 ms capture;
- lines 126–142 compare flow live/report/table totals and require setup time to be included.

Status of source clause: **semantic source match found; execution evidence unavailable in the preserved campaign logs.** The iOS worker must still map the live, summary, and report runtime comparisons.

## B2-K18 — ephemeral versus preserved report narration

Exact CLI source: `Tests/GrantivaCoreTests/RunnerSessionOutputTests.swift:162-210` at `8f2cff67`.

- `testAnEphemeralReportDirectoryIsNeverPrinted` (lines 181–190) feeds a runner Reports/Paths block through `RunnerOutputFilter`, proves the temp path and `Paths:` are removed, retains the runner result text, and emits the documented “Report not kept” instruction.
- `testAKeptReportDirectoryIsPrintedAsTheRunnerWroteIt` (lines 192–196) proves a preserved report block is unchanged.
- `testTheFilterWorksAcrossArbitraryChunkBoundaries` (lines 198–210) proves the behavior under streamed chunks.

Existing exact-head CI evidence:

- log lines 5968–5969: kept-report test started and passed;
- lines 5970–5971: ephemeral-report test started and passed.

Status of source clause: **source semantics and exact-head execution supported.** These tests cover the shared output filter; they do not replace B2-K18's separate runtime checks for `run`, `diff capture`, `ci run`, or existence of paths printed for a preserved report.

## B2-K81 — trailing trace/report trimming

Exact CLI source at `8f2cff67`:

- `Tests/GrantivaCoreTests/RunnerReportContractTests.swift:182-220`, `testTrailingKeepsTheLastGoodAfterShotAndTheFailingStepsShots`, builds steps 0–2, trims at failed step 2, requires only `cmd-001-after`, `cmd-002-before`, and `cmd-002-after` plus the named screenshot, trims Allure attachments, and drops report references to removed shots.
- `Tests/GrantivaCoreTests/RunnerTraceExportTests.swift:138-158`, `testTrailingKeepsLastStepAndPreviousAfterImageOnly`, independently requires exported trace to retain the previous after image and failing-step before image/hierarchy.

Existing exact-head CI evidence:

- log lines 5893–5894: report-directory trimming test passed;
- lines 6109–6110: exported-trace trailing test passed.

Status of source clause: **source semantics and exact-head execution supported.** Runtime failure/full/no-report-dir clauses remain separate.

## B2-K82-a — named captures only

Exact CLI source: `Tests/GrantivaCoreTests/RunnerReportContractTests.swift:26-42` at `8f2cff67`.

`testOnlyTakeScreenshotPointsBecomeCaptures` supplies before/after trace assets plus `cmd-003-Home.png`, then requires exactly the named `01-browse-cmd-003-Home` capture and no before/after image outside `trace/`. This is the semantic fixture required by the matrix even though the current test lives in `RunnerReportContractTests` rather than the matrix's suggested `RunnerArtifactCollectorTests` class.

Existing exact-head CI evidence: log lines 5883–5884 show the test started and passed.

Status of source clause: **source semantics and exact-head execution supported.** Full and trailing live `Screens:`/capture-list behavior remains runtime evidence.

## B2-K93 — hierarchy remediation scope

Exact CLI source at `8f2cff67`:

- `Tests/GrantivaCoreTests/RunnerSessionOutputTests.swift:114-145`: `testElementNotFoundAndNotVisibleFailuresCarryTheHierarchyHint` requires the exact hierarchy/MCP hint once for both error kinds; `testCrashesAndTimeoutsGetNoHierarchyHint` excludes it for `app_crash` and unfinished timeout failures.
- `Tests/GrantivaCLITests/RemediationCommandTests.swift:120-125`: `testSimulatorAndElementRemediationsNameTheCurrentCommands` verifies the element remediation names the current CLI and MCP commands.

Existing exact-head CI evidence:

- log lines 5984–5987: both positive and negative runner-output tests passed;
- lines 5396–5397: remediation command test passed.

Status of source clause: **source semantics and exact-head execution supported for element-not-found, not-visible, crash, and timeout.** The excerpts do not contain an explicit build-error negative assertion. That clause still needs runtime evidence or another exact semantic test; Android parity also remains outside this source package.

## Handoff boundary

This package closes only the source/test portions stated above. It intentionally leaves these runtime gaps for mapping by the iOS worker: B2-K18 `diff capture`/`ci run` and preserved-path behavior; B2-K81 full/failure/no-report-dir behavior; B2-K82-a full and trailing screen lists; B2-K93 build-error negative and Android parity. B2-K05 still needs evidence that the runner test executed at exact runner HEAD, unless the campaign's existing runner CI artifact is located.
