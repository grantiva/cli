# Round 3 device-slice missing-row evidence audit 2

Date: 2026-10-12

This bounded read-only audit covers IDs currently reported by `audit_coverage.py ios|android` in `missing_base_ids`. It uses retained current-round evidence and exact candidate source. It does not grade rows or duplicate the complete CLI-owned ledger.

Candidate provenance: CLI `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main` at `8f2cff676b3c12e951478920fa20e600cdca4e29`; runner `/Users/kyle/Developer/maestro-runner/.worktrees/release-round3b` at `fd9d8e8d1cb109eda6116f4221da10257b9838e3`. Exact-head Swift CI is `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-cli/findings/evidence/cov3-cli/B3-L31/ci-run-38227743323.log` (lines 7106-7109: 1,961 tests, zero failures). The plan permits semantic source-test checks. Runtime claims always cite current-round raw paths. Platform halves remain independent unless the criterion itself calls for comparison.

## Strong Android candidates

| Missing ID | Current-round evidence and exact criterion join | Assessment |
|---|---|---|
| N-14 [android] | `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/AND-106/01.out` and `report/report.json` show stock `03-edit` appending and completing without an input warning. Current-round `CF-crash1/` through `CF-crash5/` contain the crash leg; use the exact flow report whose failed wait has `error.type: app_crash`. | **Full candidate**, after the worker records the exact crash report filename. The two required inputs are an explicit join. |
| N-17 [android] | `AND-106/01.err`, `01.out`, and `report/report.json` preserve live, summary/table, and JSON durations for the same stock commands and flows. | **Full candidate** after recording an explicit shared-precision comparison. The raw set is complete; exit 0 alone proves no equality. |
| B2-K04 [android] | `AND-106/report/maestro-runner.log` identifies `google sdk_gphone64_arm64 (android 35 Emulator)` in per-flow headers; `AND-106/report/report.json` records the same Android device and `isSimulator: true`. | **Full Android-half candidate.** Verify the report and header belong to the same invocation. |
| B2-K110 [android] | `AND-106/report/maestro-runner.log:4` says `Driver: uiautomator2`; its `report.json` has matching driver/device metadata. | **Small gap:** the explicit `--driver` leg is not established. Do not grade the whole row from the default leg. |

All relative paths in this section are beneath `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/`.

## iOS runtime/source joins with small, exact gaps

The reconstructed pre-import groups below are those allowed by `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios/PROVENANCE.md`. The inventory is explicitly non-contemporaneous. Quarantine is excluded and none of these mappings uses an overwritten stable path.

| Missing ID | Supported now | Exact remaining clause |
|---|---|---|
| D2-02 [ios] | `cov3-ios/IOS-117/stock-26.out` and `stock-26.err` show passing stock screens+flows totals and artifacts. | Required `--ready-file` ordering and `reportDir` presence on specified pass/fail inputs are absent. |
| D2-04 [ios] | `cov3-ios/FLOWS-26/01-browse-report/report.json` and `02-exact-negative-report/report.json` retain command/step and screenshot structure. | Missing exact `--snapshot trailing` versus `full` asset inventories. |
| D2-05 [ios] | `cov3-ios/FLOWS-26/14-runflow.*`, `14b-runflow-inline.*`, `08-scroll.*`, `09-waits.*` and matching reports prove file/inline subflows, scroll, and waits individually. | Missing one Maestro-format screens config covering every form and proving the subflow screenshot becomes a screen. |
| D2-18 [ios] | Attempt 10 `pass-json.out` and `fail-json.out` provide pass/fail CLI JSON; pre-import reports corroborate ordered steps and error detail. | Missing the pre-flow bad-device JSON object. A runner report cannot substitute for CLI stdout. |
| D2-19 [ios] | `cov3-ios/IOS-117/stock-26.err` and `IOS-119/crash-26.err` preserve plain pass/fail output; the passing no-report output has the exact `Report not kept` behavior. | Missing the complete quiet, JSON, and JSON+verbose pass/fail mode matrix. |
| B-I02.1 | `cov3-ios/IOS-120/commands.txt`, capture outputs, `shots-26/`, and `shots-27/` prove explicit U1/U2 invocations each produced five screens. | Missing before/after proof that the other simulator was untouched during each invocation. |
| B-I02.2 | The IOS-120 command ledger proves explicit simulator selection for both owned devices. | Missing config-over-session precedence and the ambiguous-many-booted negative. |
| B-I05.2 | `cov3-ios/IOS-117/stock-26.out` proves the quote-containing visible label `Mount "Denali"` in a runner flow. | This does not prove MCP label-first predicate/class-chain lookup and name fallback; an MCP locator trace/source assertion remains missing. |
| B-I06.2 | `cov3-ios/FLOWS-26/15-input-unicode.*` and `03-edit.*` show Unicode and ordinary input reaching fields. | Missing WDA request-path proof for `/wda/keys` and conditional `/keys` fallback. |
| B-I07.1 | `cov3-ios/FLOWS-26/08-caching.*` and `FLOWS-27/08-caching.*` establish the app interaction used by the logging repro. | Commands omitted `--logs`; app-line volume and filtering of system banner lines remain unproved. |
| B2-K18 [ios] | `cov3-ios-attempt23` command 03 proves `run` without `--report-dir` hides the ephemeral path and prints the optional notice. Candidate `Tests/GrantivaCoreTests/RunnerSessionOutputTests.swift:181-210` asserts ephemeral removal, kept-path retention, and arbitrary stream chunking; exact-head CI lines 5968-5971 show those tests pass. | Runtime legs for `diff capture`, `ci run`, and a preserved `--report-dir` whose printed paths all exist remain missing. |
| B2-K93 [ios] | `cov3-ios-attempt23/04-crash-no-hint.*` plus attempt 10 failure output establish the positive not-visible hint and crash negative. Candidate `RunnerSessionOutputTests.swift:114-145` asserts element-not-found/not-visible positives and app-crash/timeout negatives (CI 5984-5987); `RemediationCommandTests.swift:120-125` pins command names (CI 5396-5397). | Missing the explicit build-error negative. Android parity is a separate platform half. |
| B3-L12 [ios] | Candidate `Tests/GrantivaCoreTests/SimulatorReaperTests.swift:246-277` asserts forced teardown removes killed-runner session files and handles a dead runner file without sidecar; `RunnerLifecycleCommandTests.swift:170-177` rejects signaling a reused PID. | Missing live killed-run residue and proof another device's live session remains. |
| B3-L52 [ios] | Candidate `RunnerLifecycleCommandTests.swift:738-748` and `DumpHierarchyCommandTests.swift:38-45` require retryable starting classification for runner-dump and an unpublished keep-alive session. | Missing one current live window showing all three required CLI/MCP calls classify starting rather than no-session. |
| B3-L55.1 [ios] | Candidate `RunnerLifecycleCommandTests.swift:384-419` asserts stop finds/signals an executing keep-alive run and removes its owner; `RunnerSessionCleanupTests.swift:74-105` asserts ready state becomes `interrupted` (suite passes at CI 5917-5938). | Missing three live runs, exit 130, and complete process/session residue checks. |
| B3-L56.1 [ios] | Candidate `RunnerSessionCleanupTests.swift:107-162` asserts post-pass interrupt preserves `passed` and refuses pass when fewer flows were reported; `RunnerExecutionTests.testOnlyAReleasesOwnSignalsOrExit130AreAnInterrupt` passes at CI 5633-5634. | Missing live passing/failing × runner-stop/SIGINT combinations, earned exit 0/1, summary, and JSON. |

All relative iOS paths are beneath `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/`.

## Handoff

This audit yields three strong Android candidates (`N-14`, `N-17`, `B2-K04`) and seventeen rows with narrowly identified missing clauses. Workers must inspect the exact raw input before grading: an adjacent report or equivalent command variant does not fill a different runtime mode. `B2-K110` is default-driver-only; D2-18 needs CLI JSON stdout; and lifecycle source assertions do not replace live process-state observations.
