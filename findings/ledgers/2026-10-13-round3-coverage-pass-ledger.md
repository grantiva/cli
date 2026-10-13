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


### Snapshot, MCP isolation, and runner lifecycle continuation

- iOS23 completed snapshot modes; independent source audit supports K05, K81 and K82-a joins. iOS24 omitted platform on the shell runner start in a two-config project; its injection check is valid, live clauses ungraded. Fresh24b corrects the omission, preserves full raw JSON, and verifies typed Yosemite. Full raw responses, not truncated transcript previews, support text values. iOS25 cross-project isolation completed.
- Android118 no-device narration and119 screen failure/timeout completed and checkpointed ff38cb41. Runner hierarchy/stale batch completed with strict start identity and dead-PID guards; tree/JSON/XML, override identity, stop cleanup and stale replacement all pass.
- iOS evidence checkpoint bb1a4ec6 preserves attempts23/24/24b and exact K05 source assertions. Independent review docs checkpoint595e5d6e.
- Current exact-ID audit: iOS205/478 (195pass/5fail/5blocked), Android162/467 (152pass/4fail/4blocked/2n-a); both have zero duplicate IDs and missing evidence paths. CLI384 IDs complete but retains prior raw platform/rerun lines; effective CLI totals remain368pass/7fail/5blocked/4n-a.
- Ruling: serialization is per device. Cross-platform verification may run concurrently, except explicitly isolated defect reproductions such as AND127. An unrelated iOS process in an Android process snapshot is expected and does not invalidate exact Android-owned PID/serial evidence. Cost if wrong: investigate any observed cross-platform artifact contamination separately; none is proved here.


### Broader command batches and a new output failure

- iOS26 eight build/install rows approved independently, including preserved Xcode build request proving retained OTHER_SWIFT_FLAGS while the derived-data flag wins; additive evidence has separate checksum disclosure. Attempt27 supplies interrupted ready state, but timeout3 was invalid input (exit64). Fresh27b uses timeout30, exits1 after33s total, and publishes failed terminal flow/group state. iOS215/478 before28 grading.
- Reviewer found B-C03.2 project isolation lacks platform-mismatch half and AND083 override lacks competing-config snapshot; provisional passes removed pending exact follow-up. X001/X003 initial negative comparison used unsuitable AndroidAND106; matching AND043 one-flow raw/report supports both, documented in independent addendum.
- Android output-contract batch finished all expected exit codes but actual stderr exposes B2-K19 failure: --json --quiet --verbose emits verbose runner output. Quiet-only negative is concise. Independent triage assigned; no wrapper exit used as all-pass. Android169/467=158pass/5fail/4blocked/2n-a beforephaseb.
- Current controller sessions: iOS28 repeated captures/discard/systemalert18583; Androidphaseb build/boot/diff37106. Builds have <20 one-minute-load guard; ownership/AVD selection guarded; capture artifacts preserved per command.


Ruling: B2-K19 combined --json --quiet --verbose output is an expectation conflict, not a proven new product defect. Exact candidate LogVerbosity15–20 and RunnerNarration26–30 deliberately let verbose win; acceptance also says verbose shows runner output but does not resolve the combined flags explicitly. Preserve literal fail/raw until Task6 correction, file no L69 from this observation, and complete separate quiet/JSON/diff/ci clauses. Cost if wrong: revisit flag-precedence product behavior and align source/tests/docs rather than silently claiming a regression. Independent triage: cov3-cli/findings/B2-K19-android-triage-and-json-review.md.


Platform-half clarification: the plan explicitly requires separate [ios]/[android] result lines for platform=both rows. A valid local half is recorded and counted in its slice without waiting for the other platform; only criteria explicitly demanding a cross-platform comparison require that joined evidence before the comparison claim. Three iOS ready-state halves briefly removed after an ambiguous review were restored with suffixes; no runtime verdict changed. X004 remains awaiting matching interrupted report-dir mode, while X002 now has a direct full JSON comparison.

Checkpoint: iOS8761206b through valid27b; Android64f54f21 phaseb/083 completed raw. Phaseb4 nonzero compare commands report baseline differences, not targeting failures; all11 command criteria provisionally pass pending independent review. Output correction85685 running. iOS28 capture10/10 and first9discard runs succeeded as of observation; no final28grade yet.


### Lifecycle and output-mode expectation reviews

- Secondary Android AVD completed11 independentlyreviewed passes; created cov3-android-2, ran onlyemulator5556, deletedit, and finalAVDinventory exactlyretainedcov3-android/Pixel_8_API_35. Mainemulator5554untouched. Checkpointa1c66ac3.
- iOS28 repeatedcaptures10/discards10/systemalert allpass. B-I04.2 priorreview mistakenlylookedonlyCLIforCHANGELOG; runnerfd9d8e8 CHANGELOG701 suppliesrequirednote, retractedfinding. iOS29keepalive/hierarchypasses, IOS057pendingcleanupinventory. iOS30logs/cleanup33262running.
- IOS058 literalinterrupted-after-hold expectation conflictsbindingL36/L56 earnedstatusruling. PreservefailuntilTask6; no productbrief. AND137/138 literalbyte-equalityfails are truthful dynamicdurations/timestamps only; independentsemantic comparisons identical. PreservefailsuntilTask6, no newbrief.
- Androidoutputrerun2 completedK13/K20passes thenharnessBash3set-uemptyarrayabort; unfinishedmodesexcluded. Freshrerun3 explicitcommands complete0, quiet/verbose stderrbehaviorcorrect, dynamicJSONdifference preserved. macOSBash3emptyarraysneed safeexpansionorexplicitcommands.


### Build/install and log-mode review corrections

- iOS30logsdefault/predicate/levels supported; IOS057/064cleanup partial because sawLogStreamfalse and no exact WDA/simctl-diagnose descendant proof.31newshutdownsimensure/reuse/concurrent casespass; CLIteardown reclaimedfalse leavesnewshutdownsims, so parentguardedcleanup verifiedexact3newUUID/namepairs andsimctldeletedthem, absenceconfirmed.
- Androidbuildbatch B-A09.2 initiallymisgraded: rawactuallyenumeratesavailablevariantsandModulesapp, correctedpass. AND022 releasefixtureusesdebugsigning, so unsignedcase expectationconflict—not productbug. B-A10.2 allegedCHANGELOGgap retracted: bindingmatrix924–925 substitutesREADME/docs/releasenotesafterCLI changelogremoval#179; README252–255fulfillsnote. NoL69filed.
- Androidsettingsrun apply/restoration casescompleted0; graded066/067/145pass,065stilldiffcapturelegmissing. K25pairedAPKbatchcomplete0actualclausespendingadjudication. iOS32live-sessiondefaultresolution/5bootedambiguityrefusalpassed withoutownerdevicecommands. iOS33env/appfilebatchcomplete0pendingadjudication.


### Paired app files, launch arguments, and duplicate flow names

- iOS33 environment and prebuilt-app checks passed four rows; iOS34 crash continuation and fail-fast behavior passed. IOS072 fails: two explicitly named files in distinct directories share `same.yaml`, but only the second flow appears in output/report. Independent cause review assigned before filing the next brief. Raw checkpoint 520a103b.
- Android K25 paired app-file checks install correctly for build install, run, and diff capture. The initial CI invocation used unsupported --flow and is excluded; the corrected config-driven invocation stops at Android baseline support validation before installation. Literal compound fail retained pending independent applicability triage. No product brief assigned from that restriction yet.
- Android027 override identity and065 capture settings completed, graded pass. Completed raw checkpoint edc2b9e0;215/467 rows recorded (200 pass,9 fail,4 blocked,2 n/a). iOS35 VRT batch completed, awaiting grading.
- Existing agents continue preparing and grading coverage; CLI agent independently reviews latest evidence. Full coverage and Task6 remain incomplete.


Ruling: IOS072 attempt34 repeated a documented singular --flow override and did not exercise the configured two-flow criterion. Preserve its raw evidence as a harness-input limitation; it is not a product defect. Fresh attempt36 configures both paths without --flow and passes both, with separate a/same.yaml and b/same.yaml report sourceFile values. Cost if wrong: revisit repeated-option validation separately, without claiming basename collision.

Ruling: B2-K25 Android CI clause conflicts with explicit CLI108/167, AND089, B-D06.1 and Android design/docs requiring refusal before device work. Keep the literal compound fail until Task6 expectation reconciliation; no remote CI implementation is implied by this regression test. Supported paired build-install/run/diff semantics pass. Cost if wrong: revisit platform scope as a separate product decision. Independent review: cov3-cli/findings/IOS072-K25-requirement-triage.md, checkpoint8173a80c.

Review gaps: B-I02.2 lacks conflicting flag/config and sole-booted fallback; IOS040 lacked retained bundle-ID proof; AND067/145 initial settings checks used slow flow instead of exact browse. Provisional grades removed while targeted evidence is gathered. iOS35 six VRT command rows pass; raw retained.


### Concurrent devices and cross-platform joins

- Android dual-device runtime completed both flows successfully, checked newest/default and explicit-device hierarchy, preserved another owned device's orphan forward across primary cleanup, and deleted its temporary secondary. Exact browse settings re-run closes AND067/145; raw checkpoint8e5c8c27. AND057 remains incomplete because unchanged persistent session forwarding proves reuse/no leak, not creation/removal of a command-scoped forward.
- Independent cross review supports X006/008/009/012/016/023. X011 needs the specified Landmarks-list state rather than detail; X014 needs a new booted Android serial case rather than only no-boot name. Initial optimistic comparison map corrected, checkpoint7aaed348. X005 lacks current iOS build-build JSON.
- iOS evidence/grades through35/36 checkpointc0a4ab84. iOS37/38 completed awaiting grading; Android K44 preflight completed and broader flow/report batch running. Remaining rows still substantial; no overall pass claimed.


### Harness integrity and exact preflight setup

- Android flow-contracts-bulk attempt1 was interrupted with shell exit2 after the worker edited an announced-ready script around launch. Frozen old script and controller completion output retained; no row grades from that interrupted batch. Ready-script paths are now immutable from announcement, with any change requiring a fresh version. v2 was inspected but not run because config-free K22 commands omitted explicit Android platform. Fresh v3 fixes that and completes all10 command outcomes as expected.
- iOS39 five-screen app-file workflow completes capture0, no-baseline compare1, approve0 and comparison0. iOS40 and AndroidK44 preflight cases reject immediately, but used already-booted devices while the matrix requires shut-down input; retained as partial, provisional grades withheld pending an owned-device lifecycle batch.
- iOS37/38 raw checkpoint1b0c924d; AndroidK44 raw40ee72ff. iOS41 output-mode/report batch runs next. No L69 product brief from the recent batches.


### Completed exact lifecycle inputs and review corrections

- Androidsecondary shutdown v3 completes K44 on a truly stopped newlycreated AVD, K29 no-boot running/stopped forms, K30 deleteJSON, and X014 freshboot plain/JSON plusreuse complements. Exact AVDname checks guard each returnedserial before teardown; finalinventory excludes secondary. Raw3be05757.
- iOS42c completes four timed shutdown preflight checks, runtime spelling/reuse/mismatch/inference, teardown outputmodes, concurrent ensure and guarded session-scoped cleanup. All new at42c names absent in finalinventory; EXIT cleanup required no deleteoperations. Raw161f8aa7.42/42b were rejected before execution for harnessguards and remain unrun.
- Reviewer initially treated Android K22 `Runner ready` narration as processstartup. Exact source shows this only reports binaryavailability; FlowReferenceResolver rejects before launching a subprocess. Finding retracted, K22pass restored; no L69. IOS145 remains partial because appfile/json substitutions do not prove bare READMEcapture. IOS129 retains functionalcoverage with explicit coordinationflag disclosure.
- AndroidK23a ID precedence completion passes; D2-08 permits recording the unsupportedCIerror and joins K25raw without a contradiction. Sourceaudit N14/K04 map existing exactAndroidraw; N17 withheld until per-step duration equality is inspectable.


Ruling: documentation rows requiring bare commands may select the campaign simulator from a frozen scratch config when preflight verifies its exact owned name/UDID. This is the narrow reconciliation with the standing explicit-device rule: it exercises documented config resolution without making the command nonliteral or permitting an owner/default device. Cost if wrong: investigate config-resolution evidence and fail any unexpected selection; never clean up owner devices. IOS145 will use this guarded form, not appfile/json substitutions.

Harness correction: iOS43 diff-preserved and ci-no-key commands incorrectly supplied unsupported --report-dir and exited64; exclude those two legs. Negative device/scheme JSON, doctor failures and ephemeral diff remain valid raw. Fresh CI invocation must omit unsupported options. Parent and workers now verify each command's flags against exact help before launch.


### Duration, report, and documentation continuation

- Android duration/snapshot five-case batch passed expected command outcomes. N17/K05/K82-a/D2-04 grades independently supported; K05 now includes exact fd9d8e8 semantic duration-consistency test source, not a claim of freshly executed Go tests. K81 remains waiting on no-report leg; K17 waiting on direct underlying report comparison. Raw a4abcf10, reviewed grades/source joins37686331.
- iOS44 exact guarded bare README workflow and current buildJSON/DerivedData variants complete0 wrapper; initial no-baseline comparison1 expected. Raw496a36bc. iOS43 missing-build hintnegative supported, while K36 needs workingtoolchain/noboot and D218 needs configuredscreen JSON; provisional broad grades withheld. Reviewed ledger0983e1b9.
- iOS45 crash/wait family and Android K17/K81 report-monitor completion are running. Current exact-ID audit before these: iOS271/478=260pass6fail5blocked; Android240/467=225pass9fail4blocked2n-a; no duplicate IDs or missing cited paths. CLI384 IDs complete, effective368pass7fail5blocked4n-a. Full pass remains incomplete.


### Starting-state and artifact review continuation

- Independent review approves iOS46 B3-L18, iOS47 N3-02 and Android K81/K82-b/K17. K17 monitor captured the exact temporary report named by its own verbose invocation; source assertion citation added. N3-03 literal fail: second start JSON omits required port:null while plain text identifies starting; exact source/docs triage assigned before a new brief. N3-01 awaits review of retained attempt16c detached screenshot join.
- Current audits: iOS280/478 (265 pass,7 fail,8 blocked), Android245/467 (230 pass,9 fail,4 blocked,2 n/a), no duplicate IDs or missing cited paths. Protected-owner/no-observable-endpoint constraints support newly recorded iOS blocks.
- Parent launched immutable iOS48 lifecycle and Android K83 subflow batches. Android X005 build retry stopped at load guard with wrapper3 before invoking Gradle; retain evidence and retry with a fresh output path when load permits.


### Reviewed starting contract and lifecycle harness recovery

- L69 filed for starting already-running JSON omitting promised port:null. Independent source triage b18ffb48 and subsequent brief review approve the defect and explicitly disclose first runner was foreground, not detached. Fixed-candidate acceptance requires both detached platform forms.
- Android X005v1 guard failure was malformed concatenation of all three host loads, not actual overload. v2 retired unrun; v3 uses os.getloadavg()[0], measured6.45, succeeds with actual product hash and unchanged adb list. X005 independently approved against iOS44 common JSON schema. Android K83 and D237 reviewed pass; D236 heart request was an absent fixture label, corrected Android Favorite request preserved separately.
- iOS48 client1 is a harness limitation: expected nonexistent running ready state and did not reap child concurrently while runner stop awaited process exit. Fresh48b client0: three active stops130, completed pass releases0, completed failure releases1, all stop commands0. Earlier timeout is not a new product defect.

Ruling: B3-L55.1/.2 input requiring a ready file with a running flow is an expectation conflict. Exact candidate prepares/removes the ready file before execution and publishes only terminal state after report completion or interruption. Use observed live flow output/process state to time active-flow stops; retain the literal matrix conflict until Task6 correction, together with actual130/interrupted/cleanup evidence. Cost if wrong: revisit ready-file publication as a separately promised API rather than claiming a running state was observed. Independent review: cov3-cli/findings/l69-android-mcp-x005-review.md.


### Broader joins and startup-window completion

- Independent scoped review approves iOS48b/49b lifecycle/crash-settle, iOS51/52 no-config/hierarchy/record/log/path checks, Android K14 project-scoped stop, D231/B-C06.2 hierarchy/context, and B-C04.2 timeout/continue behavior. Review checkpoints212eddbb/e6800247. iOS53 fills bare-name reuse and relative report paths after prior review correctly removed provisional broad joins.
- Android starting-session v1–v3 were inspected but never run: sequential detached startup missed the target window; a subsequent foreground adaptation did not exercise the required first-detached form. Fresh v4 starts detach asynchronously, directly observes starting at100ms, captures every named tool and both resources, then same-server ready success. First CLI exited before ready controls; all outputs retained. N303 reproduces L69 on Android as well; no new brief number.
- iOS five concurrent U1/U2 pairs running after Android startup completed; first3pairs0/0 at checkpoint. No owner simulator/device is operated. Default-sensitive no-config MCP batch is being adjusted to explicit owned targets before execution.
- Current worker counts: iOS305/478 (288p8f9b), Android263/467 (247p10f4b2na); full coverage remains incomplete. Duplicate Android D214 and a cross-worktree evidence path were caught by parent audit and corrected without changing raw captures.


### Concurrent devices, live capture, and orderly lifecycle controls

- iOS54 completes five concurrent U1/U2 pairs, all10flows0; per-UDID device homes and exact README/source isolation join independently reviewed.55b missing-config and wrong-platform/project isolation passes, with explicitownedbuild/boot and unchanged simulator inventories.56 captures all5screens via MCP and same-session bare CLI, then proves session usability; reviewed.57 validates literal filenames and legacy baseline migration; one intermediate copy addressed the wrong diff directory, but final retained capture tree contains the actual diff PNG. No runtime rerun needed solely for that copy limitation.
- Androidforegroundv2:5orderly foregroundstops0, one exactownedrunnerSIGKILL produces1, plain/quiet/JSONSIGINT130 with emulator noun, completed passingkeepaliveSIGINT0 with unchanged ready.passed. Independent review supports B3L36.1/L37/L56.2. AndroidB3L55.2 threeactive stops likewise130/interrupted/cleanup; literal running-ready input retained as Task6matrixfail.
- K110 defaultCLI logging and direct bundled-runner explicitdriver logging pass the narrow driver criterion. Invalid Grantiva-level --driver invocation and subsequent version-guard-only attempt are excluded harness inputs. Explicit bundled-runner flow later fails at favoriteempty-state; screenshot still shows revealed Removefromfavorites strip. Carry as L62-like observation with unresolved cause, not state-pollution or a new defect. Reviewer ios54-55b-android-k110-review.md; raw3d779f7b.
- Source trees remain clean at exact candidate CLI8f2cff676b3c12e951478920fa20e600cdca4e29 and runnerfd9d8e8d1cb109eda6116f4221da10257b9838e3. No product fixes during verification. Latest clean basecounts iOS313/478=296p8f9b; Android270/467=253p11f4b2na. Next wait/selector batches are live; Task6 incomplete.


### Selector, wait, and subflow continuation

- iOS58 config wait and ID forms pass independent review; Android ten exact waits all pass at 2420–2505ms with exact runner semantic assertions. Android K109 config preserves five selector/wait forms; missing-target timeout2052ms. Selector complement covers double/long point taps and fail-early skipped successors.
- iOS59 scalar/mapping/inline subflows succeed, missing/cycle/duplicate inputs correctly fail1. Harness expected64 incorrectly, so wrapper1 is disclosed without a product defect. iOS60 retired unrun after stale worker source was mistakenly inspected; exact release-main supports native ID and corrected60b completes0.
- iOS57 literal filenames/migration pass, but required public rename note is absent after CHANGELOG removal. Preserve B-I16.2 fail pending Task6 documentation disposition. Cross-platform X gap map and minimal paired fixtures reviewed and committed.
- Exact audits: iOS319/478 (301pass9fail9blocked), Android275/467 (258pass11fail4blocked2n-a), no duplicate IDs or missing evidence paths. CLI384 complete. Continue remaining gaps without approval checkpoints; Task6 remains incomplete.


### Recording, hierarchy, and app-file continuation

- iOS63 recording checks pass: live flow10 frame requests500/1500 map to487/1493ms; invalid past-duration request exits64 without changing prior video; relative/absolute text/JSON paths preserved. iOS64 exact config selection, fallback hierarchy, ownership refusal and ordered MCP script pass independent review.
- Android corrected notificationv3 proves exactly two subscribed updates and no rejected/post-unsubscribe updates; v2 retained as incomplete navigation fixture. Keepalive context/resourcesv4 completes cross-platform X011 againstiOS61, native ID/forwarded-port context and screenshot-resource checks. Detached contextv2 encountered documented starting readiness; no new defect inferred. v3 invalid treeformat rejected beforeexecution.
- Paired X017doctor and X024flow08logs pass. X013 literal fail is a Task6 expectation conflict: explicit B2K16/D213/N207 require platform-specific bundleId/applicationId keys. L70 public baseline filename migration note omission independently reviewed/committed.
- iOS65 app-file build/run/capture installs on a fresh owned simulator; shutdown capture boots and captures all5screens (D209pass); exact newly-created simulator deleted0 and absence verified after EXIT. No-keyCI error retained. No-app-file/no-launch afteruninstall fails querying absent data container;65b installedcontrol succeeds. New L71 captures this product defect, independently source-checked.
- iOS67b actual Maestro config diff-staging closes D205; unrun67 runnerflow substitution excluded. iOS66 built/appID-detection and launched/installed JSON pass; skippedstatus leg lacked bundleID because same config intentionally removed it, so pending tiny correctedcontrol, notnewdefect.
- Host load briefly exceeded85 afternew-simulator work; nextbuild held until true1-minute12.97, then66 completed. No product source modifications. Latest full audits iOS337/478=317pass11fail9blocked, Android289/467=271pass12fail4blocked2n-a. Both have no duplicate IDs/missing evidence paths. Remaining fullcoverage work continues; Task6 incomplete.


### Lifecycle race, interruption, and recording continuation

- iOS69b stock5screens+12flows passes; failed-control config preserves5screens and one negativeflow. Readyorder/screensreport/fullsnapshot clauses reviewed. Android ten detachedstart/dump/stopcycles pass,10uniquePIDs dead, no each-PID global session/owner/stopfiles, forwardinventoryunchanged.
- Android10three-second recordings allCLI0 and finalffprobe3.000s. Harness wrongly required nonexistent duration key and positive prehold duration, so wrapper1 is excluded; additiveffprobe measures retainedvideos. N306literal recordedMilliseconds>=3000 is Task6expectation conflict (documented prehold values9x0,1x1316), notnewproductdefect.
- iOS70 starts interruptedwhilepublishedstarting printcorrectsimulatornotice butfalseWDAtimeout/exit1. Source earlyguardbypassesSignalRelay interruptnormalization. NewL72 independentlyreviewed;70c confirmsready/hierarchy0 controls all3modesexit130/sessionclear. N215fail; B3L37noticepass.
- iOS71b concurrentensure returnsoneUUID, sessionreservationrefusals/same-session success and created-versus-preexistingteardown pass. Capacity4/4 was resolved by targetednonforce teardownofverifiedidle campaignU3(2E3D6203-A4A0-4C8C-A3D6-05EE4D608EE3), deleted0 withnoheldprocesses. U3isnowgone; neverreuseoldUUID. Both71brow-createddevicesabsentafterEXIT, postexitmanifestretained. D221directcreatedledgerproof stillmissing; five-race72bundleplanned.
- AndroiddetachedVRTK55 nowpassesexactvariant. MCP064selectorfamilies join successfultext/contentdescription/hint partialbatch with standalonewhole/suffixIDsuccessafterdecodedtreeguard. Earliernavigationfailureonlyfixture; no newdefect. N310pairedverbosewith/withouttimeoutenv both0.
- Currentaudit iOS350/478 (329pass12fail9blocked), Android299/467 (280pass13fail4blocked2n-a) beforelatestN310grade. Complete1170-rowcampaignstillinprogress,Task6notstarted. No approvals requested orproductfixes made.


### Concurrent creation and reclaim continuation

- iOS72b five concurrent ensure pairs all return one UUID, exactly one created and one reused, with direct created-ledger proof and targeted deletion. Both D221 and K67 independently reviewed. N207 decoded aliases audit independently reviewed. Attempt73 free teardown/sessionless nonforce controls succeed; live detached teardown reporting requires separate review despite successful cleanup. Attempt74 killed keepalive reclaim succeeds, removes owned processes/home/staging, preserves explicit report, and deletes the exact temporary simulator.
- Android MCP069 basic and advanced swipe refusal groups complete0. Five four-second recordings all measure4.000000s; frame-at4000 control exits0 and produces its PNG under recording-frames. Harness incorrectly searched only parent directory, so its wrapper1 is preserved and qualified. MCP064 remains partial: Name matches content-description as well as hint, so it cannot prove hint fallback.
- Latest worker counts iOS360/478 and Android300/467; device batches75 and AndroidN211 active. All raw retained; Task6 still incomplete. User authorization persists; no approval prompts.


### Output, documentation, and nested-flow continuation

- iOS76/76b invalid fixtures had unsupported native launchApp;76c run_flow rejected before execution;76d exact native type-only screen passes D241 with full screen/step context and unfocused Home proof. IOS018 scratch-home cleanup77 succeeds; both real ledgers unchanged and row devices gone.
- AndroidL10v1 used different report dirs and cannot establish equality;v2 uses identical report path with per-run archives, plain/quiet stdout byte-equal and all failure summaries correct. Three inputText controls pass; guest GPU property empty, actual owned AVD config confirms software rendering. Exact-empty MCP build/run v2 completes0 after hostload8.32; v1 explicitargs remains separate valid evidence.
- Independent review finds K103 literal no-underscore promise conflicts with documented compatibility aliases (Task6 correction); IOS016 literal kill-runner wording conflicts with K68 runner exiting with killed parent. Both literal failures retained. New L74 records missing public ISO8601 change note.
- New L75: root/screens cycles report correctly within5s, but subdirectory cycle paths retain containing-file-relative ../ operands. Exact source merge overwrites canonical project-relative display map; Android counterpart running. L73 live force teardown reporting omission also retained.
- iOS78 rejected unrun (invalid zero-session preflight/nonforce U1 would delete campaign device).78b force version preserved U1 but helper argv caused reaper matching/SIGINT; watcher also used foreground instead of runner PID.78c fixes fixture argv/watcher and runs now.80b five immediate missing lookups returned valid starting errors; five CLI missing-target flows complete. Follow-up MCP-only same-server post-ready controls required.
- Audited coverage iOS371/478 and Android318/467; CLI384 complete. Task6 remains unstarted.


### Session reuse, app artifacts, and collateral process triage

- iOS78c proves real runner-PID owner/stop marker bytes, foreground/teardown0 and cleanup;80c five same-server starting→ready→missing cycles join80b five CLI missing-label controls.81 ten detached start/hierarchy/stop cycles pass with unique PIDs and no leftover session files.84 exact two-minute post-stop control returns reclaimed:false/no helper processes.
- Definitive82 inert Python sleeper, unused Grantiva path/UDID arguments, fresh shutdown disposable: force teardown identifies it as Grantiva and signals SIGINT despite no device access. Exact JSON and process snapshots prove L76; IOS3-OBS-01 records side failure. Cleanup deletes only the disposable. No unowned process was involved.
-83 supplies exactly-one-device CLI sessions JSON in isolated scratch home; X015 paired comparison independently approved. Audit caught duplicate base X015 and three nonexistent citations; worker merged the existing platform row and corrected actualpaths. Audit again clean.85b simulator IPA works, absent-app no-build fails with proper guidance, and exact app is restored.86 no-report flow/screen JSON pass/fail closes K21a/b.
- Android configured and configless MCP build/run accepted after independent exact-argument review; hierarchy JSON aliases/conflicts, configless tool failures, same-server lazy reattach, and current numeric-frame checks pass. Historical B3L40 small-target result differs 411x41→411x13 despite matching old/current trees; further stable bracketed current check pending, no defect/correction declared yet.
- Exact source worktrees remain unchanged. Currentcounts iOS381/478 plus one side failure, Android331/467. MainU1/U2/emulator5554 retained for remainingchecks. iOS87 real unsigned iphoneos demo build and Android8case wait/runflow group active. Task6 unstarted, fullcampaign incomplete.


### Stable accessibility, app builds, and MCP lifecycle continuation

- Fresh Android same-server tree/check/tree is stable and matches historical sole 411x41 small tap target exactly; independent review supports B3-L40 pass. Six valid wait/runFlow legs pass; initial screens fixture failure excluded. Corrected diff screens both exit0; wrapper strict duration check sees2.999 for3s, separate timing-source review pending full clause join.
- Android log-level default/info/debug and invalid value controls pass; no-session tools then same-server lazy attach pass. Four uniquely owned disposable AVD configured/configless ensure/delete and handmade refusal/force controls pass; all removed and primary adb inventory unchanged.
- iOS83–87 app/session/report joins independently reviewed;88 configless build/launch exits0.89b preflight mistook legitimate capacity reservations for live sessions;89c starts/stops correctly but macOS ps ignored keyword is unsupported. Both fixture limitations retained, no product failure inferred; corrected lifecycle harness pending.90 failure-summary/duration controls active.
- Completed evidence checkpoints: iOS459248e1, Android4e6042be, CLIabddac36. Full verification and Task6 remain incomplete; no product sources changed.


### Signal, report finalization, and cross-platform continuation

- iOS89e blocked-signal detached start/stop passes;89f direct runner HUP survives and hierarchy responds;89g adds concurrent-reap normal stop and prompt killed-runner detection/sidecar cleanup;89h parent HUP survives and stops normally. Invalid ps fields, wrong owner key, and unreaped-child timeout attempts remain preserved as fixture limitations. N2-18 full join reviewed. B3-L12 still requires additional orphan/live-device control variants.
- iOS90 failure summary/artifacts have exactly one failed and two skipped commands; wrapper incorrectly counted duplicate glyphs across two streams.92 five-screen plain output closes reviewed X007;93 missing-simulator MCP closes reviewed K53.91 realpath alias/private attaches, owner kill9, runner cleanup and no-session readers all pass pending full row joins.
- Android two-device v1 stop timed out on an unreaped parent; v2 reaps concurrently and stop0 returns both shaped sessions. Secondary exit130 reflects active-flow interruption and is valid; disposable AVD removed. N205/B3L13 reviewed with prior single/dead controls. L18 run-only wait-label complement passes. Screens timeout30 and SIGINT reports/flow/ready/JUnit all finalize correctly with running0; naive wrapper string check excluded. K10/K80 reviewed pass.
- Latest audited counts iOS395/478 and Android356/467, CLI384 complete. Exact CLI/runner source worktrees unchanged. Task6 remains unstarted until full slices complete.
