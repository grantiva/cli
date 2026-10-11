# SDD ledger — plan: docs/superpowers/plans/2026-10-11-round1-coverage-pass.md

Spec: docs/superpowers/specs/2026-10-10-full-coverage-campaign-design.md. Owner waived section-by-section approval ("start working").

## Pre-flight scan

| Pair / task | Produces vs consumes | Finding |
|---|---|---|
| T0 -> T1 | findings/help corpus | T1 reads it; T0 must finish first |
| T1 -> T2 | demo-flows doc with NEW flow specs | T2 implements exactly those; ordering only |
| T2 -> T3/T4/T5 | merged landmarks-demo flows under .maestro/coverage/ | slices re-copy the demo after the merge |
| T1 -> T3/T4/T5 | matrix rows with slice assignment | slices run rows by slice; CLI rows needing a device are assigned to iOS/Android in the matrix |
| T4 vs T5 | both run MCP/X rows | disjoint devices and evidence dirs |
| T0 Step 1 vs round-1 smoke | runner home reset | wait for the smoke commit before re-cloning |
| GC: "no fixing" vs T2 app hooks | T2 edits landmarks-demo (allowed by spec) not the CLI | consistent |

Ruling: plan written and execution started without an owner review gate, per the standing instruction — cost if wrong: rework of the matrix shape.

## Execution
Round-1 fix wave: complete (ledger .superpowers/sdd/2026-10-10-round1-fix-wave/progress.md). Release binary 2.1.0 (main 51c597a) + runner 1.1.28-grantiva.9 installed at ~/.grantiva-qa/bin; upgrade check on fresh clone PASS (four -r1 caches merged, old dirs kept). Smoke agent running (Task 9 Step 3 of the fix-wave plan).
Ruling: Task 0 Step 3 (help corpus) is delegated to the Task 1 agent as its first step — saves a turn; corpus is derived from --help only — cost if wrong: none.
Task 0: Step 2 complete (worktrees cov-cli/cov-ios/cov-android off coverage-campaign 055d08b); Step 1 (home re-clone) deferred until the smoke commits.
Task 1 dispatched 02:05 (opus) incl. Task 0 Step 3.
Task 0: Step 1 complete (home re-cloned from ~/.grantiva/runner, runner install -> 1.1.28-grantiva.9, 4 -r1 caches). Smoke b517e7c on coverage-campaign. N15-N18 (smoke cosmetics) sent to the Task 1 agent.
Task 1: DONE_WITH_CONCERNS 02:40, commits d85212b (help corpus, 172 pages), cb2cacf (matrix 863 rows: CLI 307 / iOS 270 / Android 226 / both 60; MCP 113, B 230, N 18, X 24; 22 NEW flows + 4 configs, hooks H1 Gesture Lab screen, H2 Compose testTagsAsResourceId). Reviewer dispatched; Task 2 dispatched in parallel.
Ruling: the CLI slice MAY run `swift test --filter <test>` in its own worktree to verify unit-test acceptance criteria (it does not change the binary under test) — the "no swift build in a slice" rule exists to keep one binary — cost if wrong: slice time.
Ruling: rows needing `teardown --all`, a physical device, credentials, another release's bundle, or an uninstalled system image are recorded `blocked <reason>` and listed in the report; `simulator cleanup` runs only when created.json lists only cov- devices — cost if wrong: those behaviours stay unverified this round.
Ruling: landmarks-demo `grantiva-android.yml` names Pixel_8_API_35; every slice edits its scratch copy to `cov-android` and passes --device — cost if wrong: none.
Task 3 (CLI slice) dispatched 02:50 (opus) in parallel with the Task 1 review and Task 2; it merges coverage-campaign into cov/cli first.
Task 1 review: spec ❌ (missing per-flag rows for diff capture/build install/ci run/diff compare/run --allow-device-settings/emulator delete --json/--version/--quiet/--verbose; 92 B rows elided; exact: rows non-discriminating; swipe-absolute expectation; owner-device rows; cross-refs; H1 details; vague cells; local path/upstream names). Fix round 1/5 dispatched; flow-affecting amendments forwarded to Task 2.
Task 1: fix round 1/5 (1f38a9c: +24 rows -1 dup = 886; all 230 B rows verbatim; exact rows discriminating) — scoped re-review dispatched; CLI slice told to merge.
Task 1: fix round 1/5 result: 8 addressed, 0 open (re-review clean at 1f38a9c; 886 rows). Task 1: complete.
Task 2: DONE_WITH_CONCERNS 03:40, landmarks-demo PR #1 (e05dd8b flows, 5990d41 iOS Gesture Lab, d6a31a3 Android Gesture Lab + testTagsAsResourceId); 19/20 iOS, 20/21 Android flows behave as specified; deviations accepted (iOS Back button; 15/16 step changes).
Findings surfaced by Task 2 (to be recorded by slices as fail rows / briefs): inline `runFlow: {commands:}` rejected before run (F-cov-1); Maestro-format grantiva-android.yml does not parse "expected a single document" (F-cov-2); swipe-from-missing message differs per platform and matches neither doc text (F-cov-3); exact-negative failure line lacks selector on Android and the "Run grantiva hierarchy" hint on both (F-cov-4); system-alert accept line absent even with --verbose and report dir deleted after run (F-cov-5); `100%,100%` point tap reports success but lands in the system area (F-cov-6).
Ruling: flow 14 split into 14-runflow (string + file forms) and 14b-runflow-inline (negative, current rejection documented) so both are measured — cost if wrong: one extra flow file.
Task 3: DONE 04:05, cov/cli head f2df277: 315 rows = 271 pass / 34 fail / 6 blocked (device: CLI-048,049,061,064,066,068 -> hand to iOS slice) / 4 n/a; +S3 pass; +EXTRA-01..05 fails. Reviewer dispatched.
INCIDENT 3: following README Quick Start as written (`grantiva run --flow flows/onboarding.yaml` with the init default `simulator: iPhone 18 Pro`) booted the owner's pre-existing simulator FE441EE5 (iPhone 18 Pro), built+installed the demo app on it, failed on the missing flow; agent released its session; device left Shutdown, not deleted; stale lock in the test home. Product finding too: default config names a real device by model name (EXTRA-03 / CLI-133 context).
Task 2: split done (4e6b183); PR landmarks-demo#1 ready; reviewer dispatched.
Task 2 review: code approved; gaps: cfg/screens-fail + screens-slow never run; PR body missing four findings + full deviation list; two comment minors. Fix round 1/5 dispatched.
Task 3 review: completeness ✅ 315/315; not approved: filtered swift-test log; CLI-153 incident note; re-verdicts (CLI-157 pass dup; CLI-025/B-C12.1 fail; matrix/brief-error marks for CLI-019 doctor half, CLI-028, B-C16.1/.3, B-I04.3, MCP-077; EXTRA-03 restated); minors. Fix round 1/5 dispatched.
Ruling: shared evidence directories (rows citing another row's dir) are acceptable when the cited file holds the row's command and output — cost if wrong: slower triage.
Ruling: CLI-019 doctor half, CLI-028, B-C16.1/.3, B-I04.3, MCP-077 are matrix/brief errors, not product fails; they go to the report's "expectation corrections" section, not to briefs — cost if wrong: a real defect hidden behind a corrected expectation (triage re-reads each).
Note for owner: the demo app is presumably still installed on the iPhone 18 Pro simulator (FE441EE5); a stale lock for it sits in the TEST home only.
Task 3: fix round 1/5 (d4be303) — scoped re-review dispatched.
Task 3: fix round 1/5 result: 6 addressed, 0 open (re-review clean at d4be303).
Ruling: existing test class identifiers that carry a related-project name (e.g. MaestroStandardFormsTests) may be cited in results — identifiers are exempt from the no-mention rule — cost if wrong: none.
Task 3: complete (cov/cli d4be303: 270 pass / 29 fail / 6 fail-triage / 6 blocked -> iOS slice / 4 n/a, + S3 pass, EXTRA-01..06 fail).
Task 2: fix round 1/5 (cf4fb36; screens-fail/slow run; PR body complete; two comment minors). New findings from Task 2: screens-fail reports failing screen as flow "flow" (F-cov-7); screens timeout message "Runner timed out after 30s:" trailing colon + wording differs from flow timeout (F-cov-8). Scoped re-review dispatched.
Task 2: fix round 1/5 result: 4 addressed (re-review clean at cf4fb36). Task 2: complete (landmarks-demo PR #1 squash-merged; local main fast-forwarded; worktree removed).
Tasks 4 (iOS) and 5 (Android) dispatched 05:20 (opus) in parallel; CLI blocked rows handed to iOS.
Task 5: implementer DONE (cov/android db2c4df: 257 pass / 35 fail / 2 blocked / 2 n/a + AND-OBS-01..10 fail; partly run AND-002, B-C02.1). Review package review-task5.diff (results md only; evidence on disk). Task reviewer dispatched (opus) with evidence spot-check brief.
Task 5: review (opus) Needs fixes — 3 Important (5 doubtful passes B-A03.2/AND-207/AND-108/AND-124/AND-010 to fail or OBS; unrecorded inconsistencies N-17 200 ms, skipped-steps drawn ✗, emulator labelled Simulator; X-003 no commands.txt) + 7 minors. Fix round 1/5 dispatched to the implementer (brief task-5-fix-round-1.md). Note: reviewer ran two read-only grantiva --help invocations against the brief; no device touched.
Task 5: fix round 1/5 (9defa8f; 250 pass / 42 fail / 2 blocked / 2 n/a + AND-OBS-01..12; implementer also reclassified AND-208/AND-220 — accepted, same defect class as AND-207; B-A02.2 bounds cited from the regression A02 probe dump instead of AND-053). Scoped re-review dispatched (sonnet, review-task5-fix1.diff).
Task 5: fix round 1/5 result: all addressed (re-review clean at 9defa8f). Task 5: complete (cov/android 9defa8f: 250 pass / 42 fail / 2 blocked / 2 n/a + AND-OBS-01..12 fail; host clean, cov-android deleted).
Triage prep: cluster-map agent dispatched (opus) over CLI + Android fail rows -> scratchpad/triage/cluster-map.md; iOS rows to be folded in at Task 6.
Triage prep: cluster-map.md done — 66 clusters (runner 10 / cli 42 / mcp 8 / docs 6), 6 expectation corrections (CLI-019, CLI-028, MCP-077 matrix; B-C16.1/B-C16.3/B-I04.3 briefs), 95/95 rows placed; 21 clusters mapped to iOS twin rows.
Task 4: implementer DONE (cov/ios 13be3b1: 316 pass / 63 fail / 1 blocked; 341 rows on 26.0 + 39 flow-command repeats on 27.0; concern: one pkill -P $$ sleep in IOS-139 on its own child; shared /tmp/grantiva-sessions with Android noted). Review package review-task4.diff; task reviewer dispatched (opus).
Triage prep: cluster-map updated with iOS — 99 clusters (C01–C99), 158/158 rows placed, 6 expectation corrections unchanged; iOS-only section lists Android-specific clusters (C07, C08, C09, C11, C55, part of C02); C94 flagged as possible matrix error. Awaiting Task 4 review before Task 6.
Task 4: review (opus) Needs fixes — 4 Important (≈15 untracked doubtful behaviours; IOS-239 ⚠ pass inconsistent with IOS-224/228; B-I06.2/N-08 unobserved criterion; IOS-092 approve step not evidenced) + minors. Ruling: fix round may re-create cov-ios-1 for B-I06.2 and IOS-092 re-runs only (slice-owned device, explicit UDID, teardown after) — cost if wrong: ~10 min of simulator time. Fix round 1/5 dispatched to the implementer (task-4-fix-round-1.md).
Triage prep: brief-writing dispatched in parallel (3 opus writers; C01–C33, C34–C66, C67–C99) into docs/superpowers/plans/2026-10-11-coverage-issues/ as K<nn> = C<nn>; uncommitted until Task 6; iOS fix-round additions folded in afterwards.
Task 4: fix round 1/5 (7862a82; 268 pass / 70 fail / 3 blocked on 26.0, 31/8 on 27.0, IOS-OBS-01..06; B-I06.2 and N-08 -> blocked; IOS-092 re-evidenced in IOS-092/fix1 with cov-ios-1 re-created and deleted). Concern logged: runner start left reports/2026-10-11_02-05-40 under the QA runner home. Scoped re-review dispatched (sonnet).
Task 4: fix round 1/5 result: all addressed (re-review clean at 7862a82); 3 minors fixed by orchestrator in 677ab8c (header UDID note, B-I06.2 runner start command, empty dir). Task 4: complete (cov/ios 677ab8c: 268 pass / 70 fail / 3 blocked on 26.0; 31 / 8 on 27.0; IOS-OBS-01..06 fail).
Task 6 Step 1: cov/cli, cov/ios, cov/android merged --no-ff into coverage-campaign (f53fa50).
Task 6 Step 2: briefs K34–K66 written (C34 split K34-a/K34-b; triage notes on K34-b, K48, K51, K53, K58, K60; cause corrections for C42/C48/C56/C57 recorded in briefs). Waiting on K01–K33, K67–K99, K100–K110 writers.
Task 6 Step 2: briefs K100–K110 written (C107 split K107-a product / K107-b tests write locks into the real runner home — 675 test lock files found; C104 contract, C106 ux; C105/C110 confirmed both platforms). Waiting on K01–K33 and K67–K99 writers.
Task 6 Step 2: briefs K67–K99 written (37 files; splits C76/C82/C86/C90; triage notes K74, K78, K81, K86-b, K91, K94). Waiting on K01–K33.
Task 6 Steps 2–4: 118 briefs (K01–K110 incl. 8 splits) + 00-cluster-map(.additions) + round report committed f6f77d4 and pushed to origin/coverage-campaign. Verdict: ROUND 1: 118 findings — round 2 fix wave required. Task 6: complete. Next: writing-plans for the round-2 fix wave.
