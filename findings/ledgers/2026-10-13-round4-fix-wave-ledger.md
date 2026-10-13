# SDD ledger — plan: docs/superpowers/plans/2026-10-13-round4-fix-wave.md

## Frozen inputs and rulings

CLI origin/main: `8f2cff676b3c12e951478920fa20e600cdca4e29`; runner grantiva/main: `fd9d8e8d1cb109eda6116f4221da10257b9838e3`. Both fetched and ancestry verified before branch creation. Initial worktrees are clean: runner `fix4/crash-capture`; CLI `fix4/lifecycle-output`.

Round 3 final: 1170 logical / 1329 platform rows; 1281 pass, 22 fail, 20 blocked, 6 n/a. Three separate side findings; all failures covered by 22 open briefs. Independent final integration review approves consolidation. The original candidate and raw captures remain unchanged.

Ruling: Continue authorized PR creation, green-CI squash merges, and campaign pushes without another permission request — approved campaign spec and repeated user authorization govern — incorrect scope would cost reversible branch/review work; release/tagging stays excluded.
Ruling: Create dependent task worktrees from then-current merged main, not all at Task 0 — avoids stale overlapping runner and documentation changes — no acceptance is deferred.
Ruling: Product implementers run device-free baselines and red/green first; reserve device execution with the controller before creating a fix4 device — prevents competing device/load tests — acceptance remains required before completion.

## Preflight interface and consistency scan

| Tasks | Shared file/interface | Finding/ruling |
|---|---|---|
| 1 / 2 / 3 | UIA2 commands, executor flow runner, runner tests, changelog | Execute sequentially from merged main; capture interface precedes lifecycle/status consumers. |
| 3 / 4 | empty device arguments | Separate repos; same trimmed-empty contract, no aliases added. |
| 4 / 5 | CLI build/tests and lifecycle consumers | Separate worktrees; no planned source overlap; merge/retest second branch against main. |
| 4 / 6 | diagnostics/docs consume lifecycle output | Task 6 starts after merged 4 and 5. |
| 5 / 6 | docs/mcp.md and selector/transport contracts | Sequential docs consolidation preserves selector and date requirements. |
| 1–6 / 7 | tested sources into runner bundle | Bundle only merged reviewed heads. |
| 7 / 8 | archive stamps and WDA caches | One version literal, four regenerated runtime caches, fresh cloned upgrade home. |
| 8 / 9 | immutable candidate and full coverage | Smoke gate precedes coverage; failed smoke reopens task. |
| 0 | base/worktree timing | Later branches intentionally delayed until dependencies merge. |
| 1 | cancellable artifact fake vs implementation | Underlying cancellation required; no abandoned timeout goroutines. |
| 2 | gesture table vs shell fallback | Only explicit engine: adb may shell-swipe. |
| 3 | optional reporting vs required control | Production reports/status/exit all required; CLI integration after repack. |
| 4 | parser example vs actual parser | Follow binding Step 3 TargetFlags.validate production path; illustrative TargetOptions spelling is not an instruction to invent a parser. |
| 5 | large response IDs vs completion order | Exactly-once, unconstrained completion order; partial-write integration required. |
| 6 | documentation vs production doctor | L81 must exercise full entry, not helper-only test. |
| 7 | cache regeneration vs installed runtime | Inventory all four; no silently reused cache. |
| 8 | unit home vs upgrade home | Empty unit homes and APFS-cloned device home are separate. |
| 9 | full coverage vs task reruns | Every full matrix row remains; add B4 acceptance rows. |

## Evidence retained

L51: final four-form B3-L51-four-forms-rerun12 and B2-L03-per-step-hierarchy-rerun10 captures remain under findings/evidence/cov3-android; successful movement measurements do not close the held-action implementation finding. L38: B3-L38a sequential rerun4 proves starting/ready semantics while concurrent rerun3 separately proves L80 transport corruption. See reviewed Round 3 report and effective-row table for exact raw joins.

## Brief execution ledger

| Brief | Task | Failing test | Implementation | Device evidence | PR | CI | Merge |
|---|---|---|---|---|---|---|---|
| L51 | 2 | pending | pending | pending | pending | pending | pending |
| L53 | 3 + 4 | pending | pending | pending | pending | pending | pending |
| L61 | 1 | semantic RED retained fix4-1 | cc0c15a6 | fix4-1 stock4–8 + controls + cleanup | runner#24 | Test/Lint/Build passed | e5cba28c |
| L62 | 2 | pending | pending | pending | pending | pending | pending |
| L64 | 1 | semantic RED retained fix4-1 | cc0c15a6 | fix4-1 stock4–8 + controls + cleanup | runner#24 | Test/Lint/Build passed | e5cba28c |
| L65 | 5 | pending | pending | pending | pending | pending | pending |
| L66 | 5 | pending | pending | pending | pending | pending | pending |
| L67 | 6 | pending | pending | pending | pending | pending | pending |
| L68 | 4 | pending | pending | pending | pending | pending | pending |
| L69 | 4 | pending | pending | pending | pending | pending | pending |
| L70 | 6 | pending | pending | pending | pending | pending | pending |
| L71 | 4 | pending | pending | pending | pending | pending | pending |
| L72 | 4 | pending | pending | pending | pending | pending | pending |
| L73 | 4 | pending | pending | pending | pending | pending | pending |
| L74 | 6 | pending | pending | pending | pending | pending | pending |
| L75 | 4 | pending | pending | pending | pending | pending | pending |
| L76 | 4 | pending | pending | pending | pending | pending | pending |
| L77 | 2 | pending | pending | pending | pending | pending | pending |
| L78 | 4 | pending | pending | pending | pending | pending | pending |
| L79 | 3 | pending | pending | pending | pending | pending | pending |
| L80 | 5 | pending | pending | pending | pending | pending | pending |
| L81 | 6 | pending | pending | pending | pending | pending | pending |

Task 0: active — bases and first worktrees prepared; remaining branches created on dependency completion.

## Dispatch checkpoint

Task 1: active — /root/fix4_runner_capture, base fd9d8e8d1cb109eda6116f4221da10257b9838e3, runner fix4/crash-capture.
Task 4: active — /root/fix4_cli_lifecycle, base 8f2cff676b3c12e951478920fa20e600cdca4e29, CLI fix4/lifecycle-output.
Task 5: active — /root/fix4_mcp_wda, same CLI base, CLI fix4/mcp-wda.
All three are implementing device-free red/green tests; actual device slots will be coordinated before live acceptance. No brief is closed.
Round 3 integration approved in findings/round3-final-integration-review.md; checkpoint commit 8800953f. Campaign push in progress.

Ruling: Task 1 may narrowly modify pkg/device/android.go, pkg/uiautomator2/device.go, and pkg/report/types.go plus their tests — underlying cancellation and artifact-specific persistence require these existing owners; no public Driver widening — focused regression checks must cover added plumbing.

Ruling: Task 5 may minimally integrate the serialized transport in ValidatingTransport.swift — validation errors and SDK responses must share the same atomic writer — test both paths; no dependency pin change is required absent proven need.
Task 7 preflight: iOS 26.0 and 27.0 installed; 26.2/26.4 missing. Started additive Xcode runtime download for 26.2. Old copied 26.0 cache directories cannot satisfy the reviewed Round 4 regeneration requirement. No packaging starts with this blocker unresolved.

Ruling: L78 may identify simulator-side log children with a unique per-run UUID predicate tautology plus exact executable/device association — xcrun ancestry is not reliable after reparenting — validate predicate on an owned device and prove unrelated stream survives; termination timeout must remain truthful.

Ruling: Task 1 routes nested failure capture through the same bounded collector, retaining nested attachment names — otherwise runFlow/retry would retain the original serial delay — add a focused nested regression.

## Device reservation (no identity assigned until creation)

Task 1 owns the next Android window: fix4-1-android / session fix4-1, mktemp scratch APFS clone of owner runner home, load1 <15 for measurements. Task 5 owns next iOS window: fix4-5-ios-26 / session fix4-5, independently cloned runner home; Android waits for Task 1 cleanup. Task 4 has no device reservation yet. Frozen QA candidate remains untouched. All agents report actual IDs/PIDs and raw cleanup; owner devices are excluded.

Task 7 runtime prerequisite resolved: Xcode installed iOS 26.2 (23C54) and 26.4 (23E244), exit 0 each. All required 26.0/26.2/26.4/27.0 now available. Post-install owner booted identity/state inventory unchanged; raw logs and summary in findings/evidence/fix4-controller/runtime-downloads/. WDA cache regeneration still awaits merged fix heads.

Round 3 checkpoint and Round 4 setup pushed successfully through ec3a8134 on coverage-campaign (SSH exit 0). HTTPS attempts transferred slowly; interrupted only their verified owned process groups and retried the same repository/branch over existing authenticated SSH. No remote settings changed and no force push. Raw successful push output: findings/evidence/fix4-controller/campaign-push/.
Task 1 tests green (driver/executor/report/device/client, vet, focused race); Android live acceptance starting on fix4-1-android, reserved emulator-5580; scratch /private/tmp/grantiva-fix4-1.6ddirwah. Actual creation/cleanup evidence remains required.
Task 4 focused tests green, full suite running; source-only review will precede scheduled live checks. Task 5 focused 270 MCP +26 WDA tests green; full suite precedes iOS live checks.

Task 5 full suite: 1965 tests, zero failures, fresh home remained empty. Live iOS identity: fix4-5-ios-26 / 4AB20A5D-520A-4EA3-97ED-D09D90DCE79D, iOS26.0; scratch /private/tmp/grantiva-fix4-5.7th4H3/runner-home, session fix4-5. Device owned by Task 5 until cleanup report.

Task 1 Android identity: fix4-1-android, emulator-5580, emulator PID6654. Timing measurements refused while host load1 exceeded 15 (fresh iOS boot services); raw setup attempt and gate refusals retained. No acceptance inferred from unrun commands.
Interface addition: Task1 report command.artifacts.logTail is a relative asset path; command.artifacts.notes maps screenshot/hierarchy/logTail notes. Task4 asked to check CLI report path rewriting; repack integration must retain these fields. Unit tests set both GRANTIVA_RUNNER_HOME and the runner internal legacy home variable to the same fresh empty directory.
Ruling: Task5 also corrects UITools.swift public schema’s outdated WDA name equivalence to true identifier — same public selector contract as docs — targeted check sufficient for wording-only follow-up.

Ruling: New artifact schema compatibility is a required Task7 integration gate before bundle merge — Task4 found nested notes breaks [String:String] decoding and trace export omits logTail .txt — added production fixture red/green and safe trace preservation to Task7; no candidate can bypass it.
Ruling: Independent implementation work runs in separate worktrees and non-overlapping ownership (Tasks1/4/5), with controller-owned shared-interface gates — avoids the conflicting-edits rationale behind the SDD serial default while honoring continuous campaign execution — integration review/CI remain mandatory.
Ruling: Stabilize the demo Favorites tab with explicit accessibility identifier heart under Task5 — actual iOS26 renders the implicit SF Symbol identifier heart.fill even unselected, so changing selector semantics or accepting a missing target would weaken the binding contract — minimal demo test-hook PR, source diff review and live before/after required. Fresh worktree /private/tmp/grantiva-fix4-demo-selector, branch fix4/stable-tab-identifier, base75acc87b52c965246b0cf03ba4cd57fe4d44336b. No rebuild during Task1 timing window.
Task4 source committed 78e9b7526c80bb5f9c2892c19c1d3b31841cce3f, 1976 full tests green +63 focused after final argument-order correction. Fresh source reviewer /root/review_fix4_cli_lifecycle active; live criteria remain scheduled, no spec-complete claim.

Task4 draft PR opened: https://github.com/grantiva/cli/pull/208 at 78e9b752; independent source review active and CI started. Live acceptance remains required.

Task1 live worker report (independent review pending): calibrated stock-4..stock-8 launchApp app_crash 5/5; conservative fatal-to-decision upper bounds 0.223–0.265s; artifact spans 0.481–0.508s; screenshot/hierarchy/logTail all retained; no collector children. Healthy and separately injected post-return crash controls passed. Measurement window released; owned Android cleanup underway. Task5 may now rebuild minimal demo fixture and run targeted schema wording check.

Task4 review round1: source needs fixes, two Important L78 issues (initial signal PID reuse and inventory subprocess deadline) plus test diagnostic capture. Resumed original implementer /root/fix4_cli_lifecycle for fix round1; scoped red/green and fresh re-review required. Full report retained at findings/reviews/fix4-task4-source-review1.md. Live gates remain pending.

Task1 owned cleanup reported complete: emulator5580/PID6654 absent, fix4-1-android AVD+ini deleted; Pixel_8_API_35 preserved. Task5 Android slot released. End-to-end final artifact including CLI extra screenshot appeared 1.631–1.691s after failure on five runs; independent review pending.
Ruling: Task1 narrowly changes pkg/uiautomator2/transport.go to suppress context-free reconnect recovery only for best-effort failure capture — HTTP cancellation alone does not bound that callback after connection refusal — require refused-server red/green and ordinary-recovery control; prior live-server captures remain evidence for unchanged successful path.

Task5 stable demo identifier live before/after passed literal heart in selected/unselected states; separate demo commit/review pending. Task5 Android identity: fix4-5-android / emulator-5580, PID12409.
Ruling: Serialized MCP writes must also survive caller cancellation once a frame starts; cancelled queued messages must not start, real write failure closes/fails transport and releases all waiters, explicit disconnect must terminate underlying I/O — otherwise framing can still corrupt after a partial cancelled write — add deterministic controls, final full suite and final-binary live large-pair replay on both platforms.
Task1 additional cancellation regression proves failure-capture context must enforce a hard deadline despite ordinary transport soft step deadlines; preserve ordinary semantics, test held-HTTP cancellation acknowledgement with finite safety release. No closed-finding claim until independent review and final CI.

Demo fixture draft PR: https://github.com/grantiva/landmarks-demo/pull/4, commit4e3ecfd589be47e51441d0a92c98b4612ded1f70. Package task-5-demo-review.diff prepared; full Task5 independent review includes this source diff and live before/after/stock-flow evidence. No demo merge before that gate.
Task4 fix1 worker report: semantic red reproduced both PID identity/marker reuse and stalled inventory overrun; initial green now passes precise identity revalidation and budgeted nonblocking inventory with exact-child reap, diagnostic capture. Additional deadline controls and final scoped tests remain in progress.

Task1 source commit cc0c15a629071c0356b9a6fb66d70af8c4ff9579 complete/clean; independent reviewer /root/review_fix4_runner_capture active; runner branch pushed for draft PR/CI. Final package/vet/build and focused race tests pass. Device cleanup complete.
Task4 fix1 commit9c7748523e703338887124a52a0a3af6d40a884b pushed to draft PR208; scoped re-review /root/review_fix4_cli_lifecycle active, final-head CI pending. Prior head78e9b752 CI passed.
Task5 final Android mixed-large-response acceptance worker reports pass:10pairs (69270–69317bytes),20unique IDs,10small responses/10notifications; exact script controls pass. Cleanup complete (emulator5580/PID12409 absent, fix4-5-android deleted, Pixel_8_API_35 preserved). Next Android slot reserved for Task4 after its source re-review gate. Task5 retains own iOS for final-code replay.

Runner draft PR24: https://github.com/grantiva/runner/pull/24 at cc0c15a6, independent review/CI in progress.
Task4 scoped fix1 re-review approved all findings, no new blocking issue; resumed original implementer for full live acceptance. Android slot now fix4-4-android (verify serial5580 free); iOS waits Task5 cleanup, then fix4-4-ios-26 plus only-needed owned control simulator. Both runner-home env names use fresh scoped APFS clone; API key unset. Final-head CI and all live criteria still pending.

Task1 independent source/spec/acceptance review APPROVED. Minor file-list reconciliation resolved in report: sourceCtx reused unchanged, regression files chosen by existing ownership, no omitted behavior or cosmetic source edits. CI/merge and Task7 compatibility remain gates.
Task4 live Android: fix4-4-android / emulator5580 / PID18081; scoped home /private/tmp/grantiva-fix4-4.b2UyuL/runner-home; source9c774852 debug SHAaeaa9587eae499b0a3709189c7a2b2120ce90ebf6ae90357fbd2b0783122d06e. iOS still queued.
Task5 final CLI suite1970pass and final L80 both platforms pass; demo literal-heart durability recheck after restart failed, so draft demo PR4 stays unapproved. Investigating actual foreground/visibility state; preserve initial pass plus later failure without regrading.

Task1: complete — runner PR24 squash merged e5cba28c8ea9fe4ae685b15ffa528bc376b5d3b7 at 2026-10-13T13:53:33Z. Independent source/spec/device review approved; final Test/Lint/Build CI38406426508 passed (Release skipped). L61/L64 task acceptance closed; downstream bundle still requires Task7 schema integration.
Task2: active — fresh worktree maestro-runner/.worktrees/fix4-gestures-lifecycle at e5cba28c; /root/fix4_gestures_lifecycle owns device-free TDD now, Android waits Task4 cleanup.
Task4 live discovered missing --flatten in detached-start argv; production regression RED then63 lifecycle tests GREEN, committed ed2e10e61014f8bbc3905986e63c7255de843461. Actual Android AND-127/N3-03 passed after correction, plus launch-failure, stale-session replacement and empty-target controls. Original failures preserved. New actual mixed absolute/relative L75 cycle remains open.
Ruling: Extend Task4 cycle formatting beyond map merge only, narrowly on circular dependency detected lines using prior canonical hop and existing mapped display targets — actual runner emits mixed operands omitted from original unit fixture — require actual mixed-hop RED/GREEN, streaming chunk-boundary and unchanged absolute/non-cycle controls; scoped review before merge.
Task5 draft CLI PR209 at62088d41 passed CI38407525054 and1970 fresh-home tests; source reviewer found Important cancellation-expiry bug for responses queued behind >2s backpressure. Original implementer resumed fix round1, scoped re-review and final-head CI required; no complete claim.
Task5 demo corrected modifier placement committed19c1aada9c856479f0c29fbd51c029866ae2b3a9; implementer reports four selected/unselected actual-navigation restart cycles and all four stock flows passed, then final selector/script controls. Independent demo review pending. iOS owned device4AB20A5D-520A-4EA3-97ED-D09D90DCE79D deleted with owned processes absent; Android already cleaned. iOS window released to Task4.

Task4 mixed-hop fix3 committed fbaf0f250e22a0dc5eb18b3b55b27713115253bc; 46 focused tests passed after semantic RED, full suite/CI and scoped fixes2+3 review queued. Owned iOS identity fix4-4-ios-26 / E768BFF7-C4E9-4E97-A30D-54F060C4D310, same scoped home/sessionfix4-4; live acceptance underway. Task5 may minimally extend RequestCancellation tracker with queued-response ownership to preserve suppression until send/drop and release bookkeeping on every terminal path.

Task4 Android live acceptance completed and device cleanup released the window to Task2. Actual canonical four-hop cycle passes under /private/tmp in3.04s and /tmp in1.75s. Task4 iOS L71 absent plain/JSON passed; initial harness JSON-key and path-alias attempts preserved with qualifications. L72 quiet startup interrupt exposed real Once cleanup concurrency race: correct interruption output but starting session remained after process exit. Deterministic production Once regression/fix underway; no L72 closure until repeated cleanup proves completion.
Task5 cancellation-expiry fix committed a485f7b6b3cffedc1f64dcc82851fa80e4080ace, focused21tests pass and exact default2s-expiry RED reproduced extra cancelled response. Full suite still running; scoped package prepared. Demo final19c1aad pushed PR4; no configured demo CI checks, local build/live plus independent source/acceptance review are required.

Task4 startup cleanup fix committed60ccdf13a74e4ab6bb7966cc2af067ec13ddfb10: production Once concurrent callers now wait for owned cleanup completion; deterministic RED and64 lifecycle tests GREEN. Live plain/quiet/JSON repetitions, timeout/death controls underway; scoped review package9c774852→60ccdf13 prepared. D2-08 alias qualification resolved against existing AppBinaryResolver.resolve NSString.standardizingPath behavior, with original operand evidence retained and exact /tmp-path install/no-launch control passed.
Task5 final a485f7b6 full suite1973tests passed (281MCP/948Core/643CLI/101API), empty home unchanged; PR209 CI38409615340 running. /root/review_fix4_mcp resumed for scoped expiry fix and final demo source/durability/cleanup acceptance. All final pre-review-fix live evidence and unit fix evidence retained in campaign commitab363096.

Task5 independent scoped source re-review APPROVED a485f7b6; queued cancellation expiry fixed with bounded cleanup. Final demo19c1aad source and literal-fixture durability/cleanup acceptance independently APPROVED. Earlier device captures on62088d41 remain applicable to unchanged framing/device code; final bookkeeping-only source has1973tests, no newer-device-run claim.
Ruling: Demo review's existing build warnings are evidence qualifications, not a demonstrated campaign feature defect — current supported build succeeds; Swift6-mode cache conformance migration and absent optional AppIntents metadata do not contradict the fixture or product contract under test — retain exact warning logs and never claim warning-free output; reject the suggestion to create a separate deferred cleanup bucket. Reopen if a supported build or feature fails. No demonstrated defect is deferred.

Demo PR4 merged1552ae983a27528eff4c1f8145aa075698b47f71 at2026-10-13T14:04:09Z after independent approved source/live review and successful local build (no configured demo CI). Final explicit tab fixture is now main. CLI209 a485f7b6 independent review approved, final CI still running. Task4 final60ccdf13 CI38409971540 running; six live plain/quiet/JSON startup interrupts pass130 and complete cleanup, real timeout64.10s and unexpected runner death controls pass; other iOS live criteria pending. Task4 fixes2–4 source review /root/review_fix4_cli_lifecycle active.
