# Task 4 implementation report

Status: **DONE_WITH_CONCERNS — source implementation complete; scheduled live acceptance pending**. Do not mark Task 4 or its findings complete.

## Provenance and scope

- Worktree: `/Users/kyle/Developer/grantiva-cli/.worktrees/fix4-lifecycle-output`
- Branch: `fix4/lifecycle-output`
- Clean recorded base: `8f2cff676b3c12e951478920fa20e600cdca4e29` (same as assigned base).
- Binding inputs read: Task 4 brief, parent plan Global Constraints, approved 2026-10-10 campaign spec, retained round-2 L53, round-3 L68/L69/L71/L72/L73/L75/L76/L78.
- No subagents/reviewers, push, PR, merge, owner-device action, global kill, or default runner-home use. The only simctl command was device-free `xcrun simctl help spawn` to inspect process/environment semantics.
- Source/test commit: `78e9b7526c80bb5f9c2892c19c1d3b31841cce3f` (`Fix lifecycle readiness, teardown and CLI output contracts`). Self-review completed; `git diff --check` passed. No attribution lines.
- Raw test evidence copied byte-for-byte to controller `findings/evidence/fix4-4/unit/`; `sha256.json` verifies every copied capture. Source worktree is clean.

## Changes

- L53: real `TargetFlags.validate()` rejects explicitly blank device, simulator, and emulator options; ordinary simulator names remain valid. The same validation covers runner start's independently declared flags. Existing malformed-UDID usage validation and unknown `--serial` parsing remain controls; no new flag aliases.
- L68: each start uses a unique temporary flow/report directory. Android readiness requires a terminal passed launch-and-settle report as well as its own non-stale UIAutomator2 attachment. In-progress attachments release their temporary forwards; failed launch reports and runner death fail promptly, and the wait remains bounded. There was no launch task in the baseline to await: the runner report is the production completion boundary.
- L69: already-running starting documents encode an explicit null port on both platforms; numeric ready ports and stopped document behavior are preserved.
- L71: compute the install outcome before optional metadata; a skipped absent app bypasses the data-container lookup. Installed-skipped and app-file/no-launch controls preserve status, exact app path, and container path; absent metadata remains explicit JSON null.
- L72: check SignalRelay termination before translating a foreground startup failure or a stop marker; startup SIGINT normalizes to exit 130 instead of a WDA timeout. Genuine timeout and unprompted death controls remain.
- L73: carry preliminary stopped-device metadata through the force branch, emit `runnerSessionStopped`, and count that actual work as reclaimed. Preserve free no-op and helper arrays; new key added to JSON casing fixtures.
- L75: project-relative reachable display names win over containing-file-relative operands. Absolute identity fallback outside cwd retains as-written operands unless the caller explicitly named an absolute root. Exact four-hop subdirectory cycles run with both `/tmp` and `/private/tmp` source spellings; existing absolute-root and simple cycle controls remain intact. Only the RunnerSession merge changed, not the resolver API.
- L76: Grantiva and runner classification uses the executable token, excluding Python/helper command-line lookalikes while retaining actual Grantiva and existing helper classifications.
- L78: stamp each simulator log predicate with a per-run UUID tautology tied to its device. Cleanup matches actual `log stream` executable tokens plus that marker, including reparented simulator children after wrapper exit; it terminates/waits within bounded deadlines and preserves other runs. Terminal wrapper diagnostics are delayed until remote cleanup; an unconfirmed cleanup emits an explicit warning and returns false. No broad name kill or unrelated process-environment read.

## Red/green evidence

Each subprocess environment removes `GRANTIVA_API_KEY` and sets `GRANTIVA_RUNNER_HOME` to a newly created, empty task-scoped temporary directory. Each batch asserts `os.listdir(home) == []` after tests. Exact home paths and emptiness inventories are in the evidence.

Commands: `swift test --filter TargetOptionsTests`, `SimulatorCommandTests`, `RunnerSessionOutputTests`, `RunnerLifecycleCommandTests`, `BuildCommandTests`, `LogStreamerTests`, `SimulatorReaperTests`, and `JSONKeyCasingContractTests` (each filter is a separate command).

Semantic red captures before the relevant fixes:

| Finding | Capture | Observed failing assertion |
| --- | --- | --- |
| L53 | `red-TargetOptionsTests.log` | All six blank/whitespace target values unexpectedly accepted. |
| L69 | `red-RunnerLifecycleCommandTests.log` | Both already-running starting documents lacked a null port key. |
| L75 | `red-RunnerSessionOutputTests.log` | Both path spellings emitted `../shared/b.yaml` in the four-hop cycle. |
| L76 | `red-SimulatorReaperTests.log` | Python helper PIDs 100 and 101 classified alongside real Grantiva PID 102. |
| L68 | `red3-RunnerLifecycleCommandTests.log` | Driver attached immediately, before three launch-settle polls. |
| L72 | `red3-RunnerLifecycleCommandTests.log` | Plain, quiet, and JSON startup interruption produced timeout errors instead of ExitCode(130). |
| L71 | `red3-BuildCommandTests.log` | Absent skipped app called the injected failing data-container lookup. |
| L73 | `red3-SimulatorCommandTests.log` | Stopped-runner key absent and reclaimed incorrectly false. |
| L78 | `red5-LogStreamerTests.log` | Wrapper had exited but owned remote child remained alive after stop returned. |

The initial SimulatorCommand malformed-UDID control was green at baseline. `red2-*` and `red4-*` record dependency-seam compile corrections and are **not** claimed as semantic red evidence. The green cycle run initially exposed absolute-root controls; the scoped merge fallback corrected those without weakening their assertions.

All `green2-*` focused groups passed. Final strengthened install JSON, launch failure/timeout, log cleanup failure and JSON key tests also run in `final-*`. Full `swift test` passed exit 0: **1,976 tests, zero failures** (270 MCP, 952 Core, 653 CLI, 101 API), runner home empty. See `full-suite.log`, `full-suite-status.txt`, and `all-unit-homes.json` (all ten scoped test homes empty).

Self-review then caught the new Android report option being appended after the positional flow. A production runnerArguments regression failed semantically in `red-argument-order.log`; the fix places `--output` before the flow, and the entire 63-test RunnerLifecycleCommandTests group passed in `green-argument-order.log`. This narrow correction was made after the full suite; no second heavy full run was started because the controller requested avoiding added host load during Task 1 crash timing. Final code is compiled and the changed argument path is green; controller CI must run the final committed tree. Documentation-only comments were then clarified without behavior changes.

## Live acceptance still required

Controller scheduled the next Android slot to Task 1 and next iOS slot to Task 5. Task 4 must resume on `fix4-4-ios-26` and `fix4-4-android`, session `fix4-4`, with a fresh APFS-cloned scratch runner home and controller evidence root `findings/evidence/fix4-4`, only after those slots are free. No devices have been created or used by this worker.

- L68 / AND-127: detached return immediately exposes the app hierarchy; metadata/tool listings agree on PID/device; stop removes session files and owned forwards.
- L69 / N3-03 both platforms: genuine detached-first-start window, explicit null port from second start, same PID transitions to ready/numeric port and stopped, no duplicate runner.
- L72: plain/quiet/JSON startup SIGINT exit 130 with exact B3-L37 notice and session/lease/process cleanup; retain ready interruption, genuine WDA timeout, and unprompted death controls.
- L73: live forced teardown reports `runnerSessionStopped:true` and reclaimed true; retain free no-op, non-force refusal, helpers and filesystem cleanup controls.
- L78: validate UUID NSPredicate on owned iOS simulator; repeated immediate inventories after success, failure, interruption show exact child absent before return; another live stream survives; interruption exit 130 and one truthful verbose terminal diagnostic.
- L71: absent skipped, installed-skipped, and D2-08 app-file install/no-launch exact output/path controls on owned simulator.
- L53/L75/L76: live empty-target-before-forwarding, exact canonical subdirectory cycle within five seconds, harmless lookalike survival with actual Grantiva positive control.

Controller code review, PR creation, CI, squash merge, and all live gates remain pending. No all-complete claim is made.

## Cross-task compatibility gate assigned to Task 7

Controller explicitly assigned the new runner artifact schema integration to **Task 7 repack integration before bundle merge**; no candidate may consume it before these compatibility checks pass. This is an additional recorded concern, not a silent omission or a Task 4 scope expansion:

- `Sources/GrantivaCore/Runner/RunnerReportSteps.swift:33` has `Command.artifacts: [String:String]?`. A new nested `artifacts.notes` map causes the entire flow-data decode to fail at `commands(of:in:)`, returning an empty command list and losing CLI step/failure details. Replace with compatible typed artifacts (including `logTail` and `notes`) or an equivalently tolerant structured decoder.
- `Sources/GrantivaCore/Runner/RunnerSession.swift` trace exporter around lines 790–810 accepts only `.png` and `.xml`; it excludes new `cmd-*-log-tail.txt`, so ephemeral report cleanup would lose that evidence. Preserve the new log-tail asset with the existing path-containment and attribution guards, including nested-command filenames if supported by the integration.
- `RunnerReportRewriter` rewrites strings generically without dropping fields, and `RunnerReportFinalizer` preserves generic JSON artifacts. Neither needs a key-specific path rewrite merely because `logTail` is a relative assets path.
- Required fixture: a real `report.json` plus referenced `flows/<id>.json` containing a failed command with screenshot/hierarchy/logTail string paths and a nested notes map keyed screenshot/hierarchy/logTail; assert commands/steps/failure detail decode, new fields survive rewrite/finalization, and the exact log-tail bytes remain in trace output after ephemeral report cleanup. Keep old reports without new keys passing.

## Review fix round 1

Both Important L78 ownership/deadline findings and the introduced warning-leak test were addressed in `9c7748523e703338887124a52a0a3af6d40a884b`. See `task-4-fix1-report.md` for semantic RED/GREEN evidence, precise identity and bounded inventory behavior, and reconciliation of unchanged brief-named files. Final focused groups: 19 LogStreamerTests and 63 RunnerLifecycleCommandTests passed; all fresh homes remained empty. No full suite was repeated: the earlier 1,976-test full pass predates this fix and the final argument-order correction. Final-tree CI, re-review, all scheduled live acceptance and merge remain pending. No push or device actions.


## Completed live acceptance and combined integration (2026-10-13)

The original pending live list is superseded by `task-4-live-report.md`, which maps every Step9 criterion to raw evidence, preserves actual product/harness failures, records owned-device cleanup and corrects app provenance. Live-discovered source fixes ed2e10e6 (--flatten), fbaf0f25 (mixed cycle hops), and60ccdf13 (concurrent cleanup completion) have semantic RED/GREEN evidence and approved source review `task-4-live-fixes-review.md`. App debug dylib proves baseline demo75acc87, not stable4e3ecfd; Task4 does not exercise literalheart.

Controller-authorized merge of reviewed Task5 main4231a01a into reviewed Task4 source60ccdf13 produced **f6b4a1ad9c9959998d58b336eddfa316fae14c9e**, no conflicts and no new source beyond those two branches. Full fresh-empty-home `swift test` now passes **1,998 tests** (281MCP,961Core,655CLI,101API), zero failures, home empty after. This supersedes the earlier final-tree full-suite qualification for this combined head. Exact commands/status/raw output: `findings/evidence/fix4-4/integration/`. Branch pushed to PR208 as explicitly directed; no merge/release/tag performed.

Both owned iOS simulators and owned Android AVD deleted; no owned PIDs/log markers/shared session files; owner simulator states unchanged. Scratch clone retained for acceptance evidence, explicitly recorded. Independent live acceptance review and final combined-head CI remain pending; Task7 notes/logTail compatibility remains separately assigned.


## Final literal acceptance follow-up

Independent acceptance review found two missing literal controls: actual WDA-process death (the prior runner-only death was distinct) and exact screens four-hop output. The added real captures exposed genuine false-ready and absolute-alias duplication defects. Separate commits e9ae823d and05d8cd39 fix these with semantic RED/GREEN and narrowly scoped source/tests; see task-4-fix5-report.md and task-4-fix6-report.md. Both commits were pushed to PR208 under controller authorization.

The updated task-4-live-report.md now indexes every literal criterion, original failures and final changed-path replays. All live criteria now pass. Recreated simulator7FFA9197-B06B-4C08-B3C0-AE6798FF7026 was targeted-cleaned/shutdown/deleted; no owned process/shared session remains and owner simulator states are unchanged. Earlier untouched live captures remain tied to their recorded heads. No broad unrelated replay was claimed. Final05d8cd39 fresh-empty-home full suite is running under findings/evidence/fix4-4/integration-fix6, and independent source/acceptance review and final-head CI remain pending. Task4 is not merge-ready on the strength of the earlier1998-test f6b4a1ad suite alone.

Final update: final05d8cd39 full suite passed2006 tests, zero failures, fresh empty runner home/API key unset, evidence integration-fix6. All live criteria completed. The retained fix4-4 capacity reservation found during independent review was released through supported simulator teardown --session-id fix4-4; ios-capacity-cleanup-fix6 proves pre/post ledger active→[], no task devices/processes and unchanged owner states. No live acceptance or cleanup remains pending. Final-head CI and independent fix5–6/source/live acceptance review remain pending. No push beyond already-authorized05d8cd39 or merge was performed.
