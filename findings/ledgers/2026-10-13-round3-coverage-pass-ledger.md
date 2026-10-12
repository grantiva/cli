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
