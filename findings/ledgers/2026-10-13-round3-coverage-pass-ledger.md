# SDD ledger — plan: docs/superpowers/plans/2026-10-13-round3-coverage-pass.md
Spec: docs/superpowers/specs/2026-10-10-full-coverage-campaign-design.md. Preflight: same task shapes as the round-1/round-2 passes (scan table there applies: Tasks 3/4/5 are disjoint slices of one matrix; shared files only the matrix (read-only to slices) and results per slice; Task 2 is a no-op unless a row names a NEW committed flow; Task 6 merges the three slice branches). Clean.
Task 1: complete at dispatch — matrix written by the fix-wave Task 10 writer (cov3/plan 638d1fec, merged 6c9a72db): 1157 rows (+57 B3-, +16 N3-; 6 expected texts changed `(round 3 ruling: …)`); validation clean; versions filled (CLI main dc965716, runner 1.1.28-grantiva.12, caches r1).
Task 0: Step 1 waits on the round-3 smoke (fix-wave Task 9, agent running; findings/round3-smoke.md); Step 2 (slice worktrees cov3-cli/ios/android off coverage-campaign) after the smoke commit lands.
Ruling: the slices dispatch only after a smoke with zero fail rows; a smoke fail becomes an addendum brief (L54+) and a fix PR first, as in round 2 — why: the slices must test the binary that ships — cost if wrong: one more repack cycle.
Task 1 addendum: B3 rows for L52 (fixed in #205) and L53–L62 added (cov3/matrix-delta 24f78ab4 merged): matrix 1170 rows (CLI 384 / iOS 319 / Android 308 / both 159; 70 B3 rows); plan at runner .13, CLI SHA to fill after the .13 bundle PR; validation clean.
Task 0: Step 2 — slice worktrees cov3-cli/ios/android created off coverage-campaign (after the L63 merge; plan at CLI main 8f2cff67 / runner .13). Step 1 verification + TD-ios ×5 confirmation smoke pending the QA rebuild.
Task 0 Step 1: QA binary 2.1.0 @ 8f2cff67, runner 1.1.28-grantiva.13 confirmed. TD-ios ×5 confirmation smoke dispatched (opus, smoke6-ios) — the only check not yet clean on the final binary.
Ruling: Task 3 (CLI slice) dispatched now, before the TD-ios confirmation — the slice is device-free and does not exercise iOS teardown; the iOS and Android slices wait for the confirmation — cost if wrong: a few CLI rows re-run. Task 3 dispatched (opus) on .worktrees/cov3-cli @483d297a.
Task 0: Step 1 complete — TD-ios confirmation 5/5 on CLI 8f2cff67 / runner .13 (bb866976; teardown 4.27–4.70 s, xcodebuild reaped, no diagnose spawned, device home absent, sessions dir empty); MCP no-simulator build remains blocked (owner simulators booted throughout) → default-device rows follow the plan guard. ROUND 3 SMOKE: CLEAN apart from that blocked check. Task 0: complete.
Tasks 4 (iOS) and 5 (Android) dispatched in parallel (opus) on cov3-ios / cov3-android @bb866976; Task 3 (CLI) already running. Slices run flows serially; the Android slice waits for load < 20 before Gradle builds.

## Resume audit — 2026-10-12 (host date)
Existing isolated coverage-campaign and cov3 slice worktrees verified; preserve all committed and untracked evidence. Tasks 0/1 complete; Task 2 needs no new committed flows. Tasks 3/4/5 incomplete, no live grantiva or xcodebuild processes observed. QA binary SHA256 3f3293aaf1522fefe8d46457370b32a20fa8c657461bf32af086e75a754a73f8 matches release-main build at 8f2cff67. runner version reports 1.1.28-grantiva.13; versioned install stamp confirms .13 (root-level legacy version file is irrelevant).
| Tasks | Shared interface / internal consistency | Resume finding |
| 0 -> 3/4/5 | One binary and versioned runner install | Verified unchanged; no rebuild/install needed. |
| 1 -> 3/4/5 | Read-only matrix | 1170 rows; earlier handoff count 1157 is superseded. |
| 2 -> 4/5 | Demo flows | Existing demo source and scratch copies require provenance check before reuse. |
| 3 / 4 / 5 | Separate worktrees, reports and devices | Independent verification; coordinate deliberate load tests with other slices. |
| 3 -> 4 | CLI-083 handoff | Keep no-owner-device-touch guard. |
| 4 / 5 -> 6 | Evidence and result coverage | Recover existing evidence, finish missing rows, independent review before merge. |
| 6 | Brief numbering / carried items | L63 already fixed; next new brief L64. |
Ruling: refresh shared-constraints from current plan before resuming; its .12 and L52-open text was stale — current plan incorporates merged fixes — cost if wrong: re-evaluate affected rows.
Ruling: run independent verification slices in parallel as the approved spec requires; serialize deliberate host-load tests — no shared product edits, separate devices — cost if wrong: rerun timing-sensitive checks.
Ruling: preserve historical evidence and recover verdicts only where raw output supports them; missing evidence remains unfinished, never assumed pass — prevents rerunning completed work or fabricating coverage — cost if wrong: targeted rerun.
Ruling: new briefs begin at L64, since L63 is already assigned and fixed; carry unresolved L51/L53/L61/L62 rather than stale L52-open text — reflects latest fix-wave state — cost if wrong: adjust triage cross-references.

Resume dispatch: Task 3 /root/cov3_cli (base b79c9ec5, 349/384 rows recorded; 35 remain), Task 4 /root/cov3_ios (base bb866976, 20 evidence directories; results not yet written), Task 5 /root/cov3_android (base bb866976, 40 evidence directories; results not yet written). Separate gpt-5.6-sol workers, full report paths task-{3,4,5}-report.md. Controller will review complete slice ranges from initial bb866976/483d297a rather than resume heads to include earlier evidence.

Ruling: CLI-025 is an expectation correction: the Platform warning belongs to Project while both toolchains are Advisory; original C12 explicitly allows non-required toolchain advice and does not require an Advisory heading for the warning — preserved raw CLI evidence meets that contract — cost if wrong: revisit the heading during final review. Apply only at Task 6, retain original fail row.
Ruling: CLI-045 and CLI-145 mutually-exclusive-selector exit expectations must follow the approved round-3 usage-error contract (exit 64, Usage and See lines); cross-platform option rejections remain separately graded — supersedes stale exit-1 matrix text — cost if wrong: revisit compatibility expectations, not hide original evidence.

Resume progress: Android recovery checkpoints fb290ddd/d851bb5a preserve evidence/helpers. Initial BLOCKED report was premature (ordinary execution remained feasible; one-minute load was 9.51, not the 5-minute 25.33); controller resumed same worker and corrected interpretation. Current Android live checks: 25/467 recorded (20 pass, 1 fail, 4 guarded blocks), executing timeout/report group. iOS has completed recovered stock/coverage plus new focused groups and is writing results before continuing. CLI 384/384 recorded; pre-review report consistency and cancellation evidence gaps sent back for correction. No task marked complete.

Task 6 preparation: regenerated all 172 help pages from verified QA binary; all exit 0 with required headers; exactly simulator_teardown.txt changed (L63 text). Canonical findings/help updated; original CLI-003/D2-47/N3-16 failures preserved in slice branch. Evidence findings/evidence/cov3-controller/help-corpus/{commands.txt,summary.json,*.txt,*.err}. Fresh corpus matches all 172 pages. Final task review will assess these corrections with Task 6.

Task 4 recovery integrity issue: worker copied the round-2 result table into the round-3 path, rsynced round-2 evidence with --ignore-existing, then renamed round/version/device labels in the TABLE. Controller detected stale owner-device incident/TEARDOWN and old 442-row counts; rejected all imported verdicts, interrupted expansion and requested quarantine/reconstruction. Worker confirmed raw preexisting round-3 files were not overwritten (rsync --ignore-existing), raw output was not relabeled, and no new owner-device incident occurred; misleading incident text was historical. Provisional 470-pass/24-fail counts are INVALID and must never enter the round report. Correction in progress from actual round-3 command logs only. Full exact operation and file inventory requested in task-4 report.

Task 3 pre-review: committed results at 56905fbf plus working qualifications frozen; worker interrupted after N3-11 elevated rerun approval was canceled by user (do not repeat). Independent reviewer /root/review_cov3_cli (gpt-6-astra) dispatched against full task BASE483d297a, working snapshot task-3-review-package.txt, raw diff task-3-full-diff.txt (4.6MB), direct raw evidence access. Both spec/evidence-quality verdicts required. Review will address report/count inconsistencies and sandbox/early-return coverage gaps; no device tests or approval requests permitted for reviewer. Separate commit requests deferred for batching after concrete review.
Task 4 integrity correction: active table now31/478 base rows (25pass/6blocked) plus1 runtime repeat;447unrun, historical imported data quarantined, original raw preserved. Resume actual evidence mapping and fresh execution; MCP031 explicit-device path must not be wrongly blocked by default guard.

Task 3 review1: needs fixes (8Important,6Minor), review report task-3-review.md. Inventory complete384 IDs but live evidence scope overstated in several pass grades; no new proven product defect. Original worker /root/cov3_cli resumed for fix round1/5; all findings including minors required. N3-11 canceled rerun remains blocked; no standalone commit request.
Ruling: D2-27 is a matrix/brief conflict with approved L29; record fail(triage) now and correct expected help pages only during Task6 — build-build intentionally omits headless — cost if wrong: re-evaluate documentation contract, not silently accept old expectation.
Ruling: documentation-example completion inventories user-facing README/docs recursively and maps every example to help/real evidence or a specific authorized exclusion; never execute destructive/auth/default-device examples merely for coverage — preserves task's corpus-check scope and global constraints — cost if wrong: add targeted permitted runs for any remaining required example.

Task 4 checkpoint9542e3d4 completed as the controller's defer-commit instruction arrived (worker reports approval already completed). It includes historical quarantine (~1997files). Active corrected results now72/478 base (67pass/5blocked) plus36 runtime repeats,406unrun; MCP031's mistaken blocked grade removed pending explicit-device run.
Ruling: retain9542e3d4 as the recovery audit trail, without history rewrite or another commit prompt; quarantined prior-round data is excluded from current verdicts — avoids destructive cleanup and preserves provenance — cost if wrong: larger evidence tree, which can be curated later before sharing.
Android recording group completed:38/467 base (33pass/1fail/4blocked); five K111 videos exactly4.000s; no new failures in13 recording rows.

Task 3 fix round1/5: worker claims all14 review findings addressed; working tree now360pass/7fail/13blocked/4n-a across384IDs,405platform lines. Step3 inventory153 examples. No product edits, no device actions. Scoped re-review /root/review_cov3_cli dispatched with task-3-fix1-package.txt against exact prior working table; no new commit.
Ruling: authoritative Task3 report stays at ../cov3-cli/task-3-report.md; do not repeat the user's aborted cross-worktree copy approval — reviewers can read it in place, so moving it is unnecessary — cost if wrong: one nonstandard report link in the ledger. Worker warned not to repeat aborted requests; controller has not copied that report through another mechanism.

Task 3 fix round1/5 re-review:11addressed,3open (#1 incomplete docs-example inventory;#12 eight auto-mode captures duplicated into platform-specific passes;#13 helpdelta wording). All prior sandbox/guard blocked qualifications accepted. Fix round2/5 dispatched to original worker, only these3 plus newbreakage; capture8 device-free error rows explicitly perplatform if sandbox permits, no newapprovals or N3-11retry. Report stays in slice worktree.

### Full-access continuation

- User explicitly enabled full access to eliminate repeated approval prompts. Current policy is danger-full-access / approval never; all subsequent commands omit sandbox_permissions. Campaign device ownership and evidence provenance requirements remain in force.
- Task 3 fix round 3 implementation returned: documentation inventory variant links, prose extraction, and counts corrected; independent scoped re-review remains pending. Resuming the existing reviewer and creating a replacement both returned `agent thread limit reached`; no review approval is inferred from this infrastructure failure. Device slices continue independently.

### Controller execution after full-access change

Ruling: existing workers retained sandbox restrictions despite parent full access; workers prepare bounded scripts and adjudicate evidence, while controller executes inspected scripts without escalation — preserves device ownership and raw evidence and avoids further prompts — cost if wrong: review each script for cross-slice interference.

Android AND-075-rerun/02 ran through controller: seven flow steps passed, command exit 0 and no logcat process remained. Worker owns final row adjudication. iOS worker assigned scoped independent CLI fix-round3 review because original reviewer cannot resume (thread limit); no review gate waived.

Task 3: fix round 3/5 (remaining finding #1 addressed, 0 review findings open; changes still uncommitted). Independent reviewer was the iOS worker, which did not implement CLI artifacts; report: `.worktrees/cov3-ios/findings/task-3-rereview-3.md`. Original review findings #12/#13 already accepted in round2. Controller audit confirms all384 base IDs/405platformlines, no duplicate IDs or missing evidence paths. Additional full-access reruns B3-L17/N3-11 now captured and awaiting worker adjudication before checkpoint. This closes artifact-review findings, not coverage exclusions or the campaign.

Ruling: iOS build/run/test coverage may use the named campaign simulator to satisfy the binding explicit-device constraint; count only the actual observed build/launch/error-result criteria and disclose changed inputs. MCP-029/034/039 captures also supply the configured scheme explicitly, so they do not prove omitted-argument config fallback; that gap must remain visible to final review or receive a safely named-device rerun with scheme omitted. IOS-112 matches its explicit scheme criterion. Cost if wrong: rerun a config-fallback variant on the same owned simulator.

CLI reviewed evidence checkpoint: `6ad5a85b` on cov3/cli. Latest effective totals361pass/7fail/12blocked/4n-a; original384baseIDs and405platformlines preserved plus2reruns. Remaining live handoffs stay open.

### Continued full-access verification

- Controller executes inspected scripts; original worker sandbox restrictions persist. No further permission prompts used. CLI evidence committed at6ad5a85b.
- Interim iOS provenance review and scoped re-review are recorded in cov3-cli/findings/cov3-ios-progress-{review,rereview}.md; prior findings addressed for interim use. Four tracked pre-overwrite files are recoverable from9542e3d4 and archived byte-for-byte; uncommitted intermediate overwrites are explicitly unrecoverable. Reconstructed pre-import top-level inventory is not a contemporaneous file manifest and remains a final-report limitation.
- New triage drafts L64 (post-FATAL Android launch success) and L65 (script missing-steps text) independently reviewed in cov3-cli/findings/round3-triage-draft-review.md. L64 explicitly preserves all binding B3-L57 criteria; L65 now independently reproduced on Android as well as iOS.
- Android AND117 initially reported as product failure was a harness omission: original command lacked --env. Controller caught missing flag, worker removed unsupported failure; exact --env LANDMARKS_NOTE=from-cli rerun passed. No defect brief filed for that harness error.
- Additional harness corrections preserve failed attempts separately: Android Profile navigation was nonexistent, iOS Gesture Pad capitalization was wrong, and an isolated scratch iOS session ID conflicted with legitimate cov3-ios device ownership. Corrected named-device retries do not remove original attempts.
- N3-11 actual runner-use path now exercised with bundle-less exact binary, scratch runner-home clone, legitimate owning session and owned U1: start succeeds with one missing-bundle warning, stop succeeds. Worker adjudication/report integration pending.

### Device verification continuation

- iOS attempt11b meets B3-L14.2: cancellation at2.014s suppresses the response, xcodebuild is gone at cancellation+5.009s, and tools/list still responds. A reparented ibtoold remains; the criterion concerns xcodebuild and no helper was killed. Frozen executed harness and client preserve the cosmetic B3-L14.1 directory mismatch.
- iOS attempt12 passes relative success/failure report paths and identical-input quiet/verbose checks (IOS070/071/152). Recording attempt13 is running on explicit campaign U1.
- Independent heart fallback triage supports a product selector mismatch, not a stale fixture: runner identifier predicate finds heart; MCP label/name/placeholder lookup misses it. Draft L66 preserves full original row criteria; independent review pending.
- Android exact environment group completed: quoted a=b c reaches app extras, seed-empty CLI/header variants pass, unsupported logs predicate and Android CI reject clearly. Worker adjudication pending. Corrected mixed-baseline runtime and MCP verdicts agree; B2-K89 remains fail because required README mixed-case exit-code documentation is absent.
- Tasks3–5 remain in progress. No release-clean verdict or completed full pass is implied by these checkpoints.

### Reviewed handoffs and source-audit correction

- CLI handoff integration independently reviewed by iOS worker (findings/task-3-handoff-rereview.md) and committed bb328c5c. Current latest CLI totals368pass/7fail/5blocked/4n-a; 414raw result lines preserve historical blocked verdicts.
- L66 independent Android review approved; documentation/source-comment clarification incorporated. CLI triage identifies CLI025 as a real doctor section defect (new draft L67), while six other CLI fails are stale expectation/corpus conflicts for Task6 corrections.
- Correction: Android B2-K89 README omission claim was invalid. The audit read the demo README from scratch runtime cwd while claiming CLI candidate provenance. Actual candidate README726–729 already documents mixed exit1 and passedfalse, including CI distinction. Preserve faulty audit and add explicit absolute candidate-path/head audit; runtime/MCP/source-test evidence plus correct docs can support pass. No documentation defect should be filed. Worker tasked to audit other source evidence for cwd mistakes. This supersedes the preceding provisional K89 failure statement.

### Evidence checkpoints and harness isolation

- Android completed evidence checkpoint d162c83f:141/467 base rows (133pass/2fail/4blocked/2n-a). iOS completed evidence checkpoint9503dc71:168/478 base rows (159pass/4fail/5blocked), plus39runtime repeats and CLI handoffs. Neither slice complete.
- Exact runner source is available at /Users/kyle/Developer/maestro-runner/.worktrees/release-round3b HEADfd9d8e8; CLI reviewer mapping its source-test clauses without running builds/tests. Earlier no-local-checkout gap is superseded.
- iOS attempt16 client aborted before first runner start because newly added shell-output counter was uninitialized. Seven no-session responses remain valid captures; all live clauses unexecuted. Failed attempt and frozen helper preserved; worker preparing16b plus device-free helper smoke. Parent verified failed client's MCP PID27723 already exited. No device cleanup was necessary.

### MCP session/error checks

- iOS16b exposed a second harness defect: shell subprocesses inherited the controller worktree cwd while MCP used scratch cwd. Both owned-device runner sessions started/stopped successfully, but MCP saw no session. No product failure inferred; raw retained. 16c helper explicitly sets cwd and has a durable fake-MCP smoke asserting it;16c then completed real live checks.
- iOS16c demonstrates no-session errors, lazy attach, valid script, invalid script/no-focus error, missing label, and reattach on the same server. After app termination, six tools returnisError; screenshot returnsimage. Android afterforce-stop has screenshot/swipe/tree/checksuccess and tap/type/scriptisError. MCP078 literalcriterion remainsfailpending independent underlyingR05/docs triage; no newbriefuntilclassified.
- Android checkpointd162 independentreview accepted env/hierarchy/type/K89, foundoneimportant unsupported B2K24 pass: AND128 Maestro commandmetadata was overwritten/unrelated and explicitplatformlegmissing. Workeraskedpreserveprovenance/removeunsupportedpass andfreshprecisererun. Scopefixround1, no reviewgatewaived.

Review correction: controller inspected frozen controller-targeted-review-gaps.sh56–62, which copies the Maestro fixture to grantiva-android.yml before the recorded diffcapture command. That is valid input provenance; the reviewer's claim that rawcommandmetadata was overwritten is unsupported and must be withdrawn. K24 still lacks its explicitplatform secondleg and remaining defaults/override/native/source clauses. Preserve valid AND128capture; review narrowed to those real gaps.

### Interim reviews and current queued device work

- CLI reviewed iOS attempts10–16c: seven composite passes removedpendingmissingclauses, not converted to false environment blocks. Current169/478base158pass/5fail/5blocked,309unrecorded; priorraw remains validpartial. CLI reviewer preparing exactsourceclause package; iOS worker owns runtime gaps and capacity snapshots.
- MCP078 independentcrossplatformtriage supports expectationcorrection (R05 errortransport guarantee, device screenshot exception docs61–63), not provenproductbug. Retainliteral matrixfailsuntilTask6. Reviewdocs committed8123026e; source map1458adc8.
- Android K24 exactfresh default+explicitplatform reruns pass; visible PNGscopiedoutofignored.grantiva. Scopedrereview acceptedthoselegs, leftB-C08.2nativeidselectorbranchsource/tests evidence missing. Worker fixround2 limitedthatclause.
- Livecontroller groups: iOS17 broad screens/failure/timeout group; AndroidAND043stockindividual12flows. Stockscript initialself-copyfailed duecd+relative$0; parentcopiedexactunchangedscriptimmediately toinput/controller-script.sh, no producteffect. UseabsolutescriptinvocationsforlaterAndroidgroups. iOS18 preparedandinspectedbutmustwait17completion.

### Completed batches and scoped review closure

- Android stock01–12 allpassedindividually (controller58127completed0); evidence AND043-exact-rerun1. iOS17screensbatch completed0 wrapper: actual01/02/03success,04/05/06expectedfail,07timeoutfail,08unlimitedslowpass. iOS18focusedscript/standalonetypepass, liveVRT runFlowrefusal isError; workeradjudicationpending.
- K24 scopedreviewround2 APPROVED after nativeB-C08.2 source/test/CI/docs clausefilled; reportcov3-cli/findings/cov3-android-b2-k24-rereview.md. No unsupportedoverwritefinding remains.
- iOScompositesourcepackage preparedbyCLIreviewer (findings/ios-composite-source-evidence.md); sourceproofdoesnotreplace runtime clauses. iOSworker addingmissingruntime/leaseevidence, then scopedrereviewneeded.

Ruling: required unit/runner-test source clauses follow authoritative plan Task1step2: verify the exact semantic assertions in candidate source, without new slice builds/tests. Do not impose a new executed-CI requirement where the row merely requires a test; existing exact-head CI may corroborate. Explicit runtime/execution criteria still need their own evidence. This avoids reviewer-invented gates; cost ifwrong: separately verify any row whose wording actually demands execution.

Checkpoint updates: iOScompletedthrough18committeddefa7ebe (live19excluded); Androidcompletedthroughcontinue/timeoutcommittedab7c62b2. CurrentAndroid150/467 (141pass/3fail/4blocked/2n-a), iOS183/478 (172pass/5fail/5blocked), beforependingnewgroups. CLIreview/sourceheadf6cb7a1a. iOS19threshold/stalecapturegroup running, AndroidrunnerJSONgroup next.

Count correction: exactexpected-ID auditshowsiOS182/478base=172pass+5fail+5blocked,296missing; sixCLIhandoffs (CLI048/049/061/064/066 plusN3-11),39runtime repeats. Earlier183base/5handoff claims wronglyincludedN3-11asbase. Workerfixedfooter/report; no gradechanged. Audithelper nowreportsrecorded_base_ids,extra_base_ids,base_platform_verdicts toprevent recurrence.

Latestgroups: iOS19complete expectedthresholddefault1/pixelonly1/bothraised0; staleinitialcapture0/failedcapture1/compare1. Androidrecorddoc5s/3frames validraw despiteintermediateflatPNG-count harnesserror maskedbyfinalvideoassertion; workerpreservedrecursiveinventory.

iOS20controllerfixedprelaunchharnesslocal-variableexpansion andglobal-sessiondirectory, thenran: start0/launch0/capture1(startingWDA)/stop0. ActualU1leaseclaimduringstart namesPID44188handedOfftrue andproject, afterstopabsent; capturesuccessnotprovedandneedsboundedreadinessretry. AndroidAND127confirmed-app rerun stillreturnsSystemUIafterdetachedstart evenafterpriorbrowseflow; allcommands0butwrapper1dueLandmarkstreeassertion. No falsepass; workerinvestigatingappforegroundsetupagainstexactcriterion.


### Further verification and independent review

- L68 records Android detached start returning ready before its generated launch flow makes the app available. Isolated reproduction proves this occurrence without concurrent starts; shared temporary flow remains an unproven separate risk. Independent iOS review approved after wording explicitly attributed the stronger promise to matrix AND-127 rather than driver-up help.
- Completed Android evidence checkpoint f64a5e8c and iOS through22 checkpoint27cb86da. Independent CLI review `findings/ios20-22-android-new-batch-review.md` supports IOS084/087, N2-11, MCP065/070/073 and AND103/105/124/125/126; AND127 remains fail. Minor Android124 duplicate/count and127 evidence-link corrections assigned to worker.
- Attempt20 original stale manifest preserved unchanged; disclosure plus supplemental final manifest verifies retained bytes. iOS23 snapshot/crash batch completed;24 MCP argument/platform batch running. Android118 no-explicit-device run completed0 against sole connected owned emulator; adjudication pending. Tasks3–5 remain active; no complete full-pass claim.
