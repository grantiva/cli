# iOS 41/43, Android duration/snapshot, and lifecycle source review

Scope is limited to the newly graded iOS 41/43 rows, the finalized Android `duration-snapshot-contracts-exact-rerun1` rows, and reusable exact-head source clauses for still-missing B3/N lifecycle rows. Candidate provenance is CLI `8f2cff676b3c12e951478920fa20e600cdca4e29` and runner `fd9d8e8d1cb109eda6116f4221da10257b9838e3`. No live command or build was run.

## Findings

1. **Important — D2-18 [ios] is only partially evidenced.** The passing and failing attempt-41 commands both supply scalar `--flow`; their JSON therefore contains only `kind: "flow"`. The matrix deliberately asks for these commands "with a config that has screens" and defines entries with `kind` `screen`/`flow`. The captures prove the common flow shape, relative paths without `--report-dir`, absolute paths with an explicitly external report directory, the failed-step error, and attempt 43 proves the exact pre-flow bad-device document. They do not prove a configured screen entry or `kind: "screen"`. Keep those valid clauses, but remove the full pass until a current configured-screens JSON document is joined.

2. **Important — B2-K36 lacks its second runtime leg.** Attempt 43 correctly proves that a thrown simulator-list operation under `DEVELOPER_DIR=/nonexistent` reports `Could not list simulators: <reason>` with the Xcode fix in both text and JSON. `DoctorTests.swift` contains semantic tests for thrown and empty-list behavior. The acceptance criterion separately calls for a working toolchain with nothing booted to retain `No simulator booted` and its ensure fix. No such runtime capture is cited. This is a partial row, not a product failure.

3. **Minor — Android B2-K05 should cite the exact runner assertion it relies on.** Runtime evidence is strong: passing and failing step/live/summary/report durations and flow totals agree at shared precision. The required fake 300 ms artifact-capture assertion exists at `/Users/kyle/Developer/maestro-runner/.worktrees/release-round3b/pkg/executor/duration_consistency_test.go:31-142`, but the ledger cites only the runtime directory while claiming the exact test. Add this absolute exact-head source citation (and state it was inspected, not newly executed). This does not change the pass.

## Approved grades and bounded evidence

- **N2-08 [ios]: approved.** Attempt 41 contains 19 total step objects across pass (8), fail (3), and diff capture (8); every object has a positive numeric duration.
- **B2-K93 [ios]: approved.** The attempt-10 not-visible failure has exactly one hierarchy hint; attempt-23 crash/timeout and attempt-43 explicit build failure omit it. `RunnerSessionOutputTests.swift:114-145` pins the error-category semantics. The Android half is independently graded and is not a gate on this iOS half.
- **B2-K36 attempt-43 broken-toolchain leg: approved**, subject to finding 2.
- **D2-18 attempt-41 flow and attempt-43 pre-flow legs: approved**, subject to finding 1.
- **Attempt-43 diff ephemeral: valid partial B2-K18 evidence.** It exits 0, suppresses the temporary report path, and prints the optional `Report not kept` notice. It does not supply the remaining `ci run` or preserved-report legs.
- **Attempt-43 `diff-preserved` and `ci-no-key`: excluded.** Both use unsupported `--report-dir`, exit 64 at argument parsing, and establish no target runtime behavior.
- **Android N-17, B2-K82-a, and D2-04: approved.** The retained full/trailing/failure reports and files substantiate the graded duration and snapshot-selection claims. **B2-K81 remains correctly ungraded** because the explicit no-`--report-dir` mode was not captured.

## Reusable source joins for remaining lifecycle rows

These are clause-level source matches only. None completes the named runtime row.

| Row | Exact-head semantic assertion | Runtime still required |
|---|---|---|
| N-01 | `RunnerLifecycleCommandTests.swift:333-418` proves same-project keep-alive discovery, exact stopped text/identity JSON, multi-session release, and discovery while flows are still running. `RunnerSessionCleanupTests.swift:74-162` distinguishes interrupted-during-flow from earned pass after hold. | Live pass/fail keep-alive release, exit/status, ready-file terminal state, and residue/process observations on each platform. |
| B3-L12 | `SimulatorReaperTests.swift:246-277` and `RunnerLifecycleCommandTests.swift:145-177` prove dead-file cleanup, sidecar-less dead cleanup, and no signal to a reused PID. | Killed-runner cleanup plus force-teardown JSON and the other-device live-session retention control. |
| B3-L37 | `RunnerLifecycleCommandTests.swift:722-734` proves the tracked noun is `emulator` on Android and `simulator` on iOS. | Foreground plain/quiet/JSON SIGINT stderr on each platform and the call-site audit required by the row. |
| B3-L38-a / N-13 | `RunnerLifecycleCommandTests.swift:736-742` pins dump-hierarchy's Android starting text. `MCPServerTests.swift:176-223` pins live-sidecar starting, dead/foreign no-session, and both-platform WDA/UIAutomator2 wording. | The 100 ms start-to-ready observations, session JSON transition, all required MCP/resources/CLI calls, first ready attachment, and dead-pid runtime control. |
| B3-L52 | `RunnerLifecycleCommandTests.swift:738-742` plus `DumpHierarchyCommandTests.swift:38-45` classify a starting unpublished keep-alive session as retryable. | All three live hierarchy/dump/MCP calls during a slow keep-alive start and their successful post-ready calls. |
| B3-L54.1 | `RunnerLifecycleCommandTests.swift:652-716` proves removal-before-signal, cross-directory teardown marker classification, and orderly versus unprompted exit. | Three cross-directory foreground teardown runs and complete session/runner/WDA residue checks. |
| B3-L55.1 | `RunnerLifecycleCommandTests.swift:381-418` proves stop discovery during flows; `RunnerSessionCleanupTests.swift:74-105` pins interrupted state during a running flow. | Three live stop-during-flow runs, exit 130, ready-file state, and cleanup. |
| B3-L56.1 | `RunnerSessionCleanupTests.swift:107-162` preserves earned pass after hold and refuses incomplete pass; `RunnerExecutionTests.swift:430-519` separates owned release signals from interruption. | Passing/failing live flows released by both stop and SIGINT, including exit 0/1, failure summary, single JSON document, and residue. |

This source map should prevent rerunning semantic assertions while retaining every process, timing, output-mode, and cleanup observation as a runtime requirement.
