# Coverage campaign — handoff (resume from here)

Updated: 2026-10-13 (round-3 coverage complete; round-4 fix wave starting). This file is the tool-agnostic resume point for the full-coverage campaign. Everything an agent needs is on branch `coverage-campaign` of grantiva/cli, worktree `/Users/kyle/Developer/grantiva-cli/.worktrees/regression`. The per-plan SDD ledgers are git-ignored scratch; copies are committed under `findings/ledgers/` at each phase boundary (the live ones are in `.superpowers/sdd/<plan>/progress.md`).

## Current checkpoint — supersedes historical progress below

Round 3 coverage and cleanup are complete: **1281 pass / 22 fail / 20 blocked / 6 n/a**, across 1329 platform rows (1170 logical rows). Independent integration review approves consolidation. **22 findings remain open:** L51, L53, L61, L62 and L64–L81. L52 remains fixed. See `2026-10-13-round3-coverage-report.md` and `findings/round3-final-integration-review.md`.

Active fix-wave checkpoint: CLI lifecycle draft PR #208 is in review fix round 1 (PID identity and bounded inventory cleanup), with live acceptance queued. Runner crash/capture has five passing calibrated device runs and complete Android cleanup; final cancellation regressions and source review precede PR/merge. MCP/iOS selector work has passing live large-response and selector checks; partial-write cancellation hardening is being tested. A separate demo fixture branch `fix4/stable-tab-identifier` makes `heart` explicit, preserving the literal selector contract. No product finding is closed yet. All four required iOS runtimes (26.0/26.2/26.4/27.0) are now installed; WDA caches still require regeneration after merged fixes. Task7 also owns the new runner artifact decoder/log-tail trace compatibility gate.

Execute reviewed `2026-10-13-round4-fix-wave.md` continuously. Task 1 runner crash/capture and Task 4 CLI lifecycle/output have isolated clean worktrees. Runner base is fd9d8e8d1cb109eda6116f4221da10257b9838e3; CLI base is 8f2cff676b3c12e951478920fa20e600cdca4e29. Track implementation, tests, PR/CI/merge and owned-device cleanup in `findings/ledgers/2026-10-13-round4-fix-wave-ledger.md`. No new product fixes are complete yet.

All campaign-created Round 3 devices are deleted; owner iPhone 17 Pro, iPhone 18 Pro and Pixel_8_API_35 are protected. Fresh fix4 devices only. QA binary and frozen source worktrees remain available for comparison. Campaign release/tagging is not authorized by a clean test result.

## Goal and exit criterion
Spec: `docs/superpowers/specs/2026-10-10-full-coverage-campaign-design.md`. Loop: fix wave → repack → smoke → full coverage pass → triage, until one full pass yields zero `fail` rows. Release is the owner's decision; the campaign never declares a release.

## Goals (the owner's words and intent)
- "The goal isn't to get a 2.1.0 out. It's to fully test everything with real flows (minus auth flows) before release. Anything that doesn't make sense, seems like a bug, or is 'minor' needs to be fixed." Repacking and re-testing is expected; it never means the release is approved.
- Coverage means every grantiva subcommand, flag and MCP tool, exercised with real Maestro-format flows on iOS 26.0, iOS 27.0 and Android API 35, through the release binary, on both platforms wherever the command exists. `auth` and `console` are out of scope (no credentials).
- Integration is by pull request: an agent opens the PR, a reviewer gates it, the controller squash-merges after the review loop and CI. Demo-app changes go through PRs to landmarks-demo.
- There is no "minor, leave it" bucket: every reviewer minor is fixed in a fix round, and every doubtful behaviour a slice sees is a `fail` with evidence.
- Nothing is ever asked of the owner mid-plan; conflicts are decided by a recorded ruling (`Ruling: <decision> — <why> — <cost if wrong>` in the ledger) so the owner can undo a wrong one later.

## The loop, and how it works
One round = fix wave → repack → smoke → full coverage pass → triage. The exit criterion is one full coverage pass with zero `fail` rows. Round 1 (fix wave from the 2.1.0 regression, then the first full pass) produced 118 briefs; round 2 (fix wave for those, then the second full pass) is in progress; its fails become round 3.

### 1. Fix wave (a plan executed with subagent-driven development)
- Input: the briefs from the previous pass (`K`/`L` files: Expected / Actual / Repro / Evidence / Suspected cause / Acceptance criteria; severity crash | wrong-result | contract | docs | ux). A writing-plans pass groups them into tasks by code area (runner output, UIAutomator2, WDA, CLI run output, keep-alive, simulator, emulator, diff/record, usage/doctor, MCP, docs) and records rulings for any brief whose expectation is doubtful (`Triage note:`).
- Per task: one implementer agent in its own worktree/branch, TDD against the briefs' acceptance criteria, device check on devices it creates (`fix<N>-<task>-ios/-android`) and deletes, PR opened but never merged by the implementer. Then one task reviewer (spec compliance + quality, with the diff as a file). Findings → fix round (resume the implementer; rounds ≥4 escalate to a fresh, stronger agent), each round ending in a scoped re-review; up to 5 rounds, then the controller adjudicates and parks with a ruling. Clean → CI → squash-merge → verify MERGED → remove the worktree. Parallel tasks are allowed in separate worktrees; a merge order is ruled and later PRs rebase.
- Then: repack the runner (`scripts/build-runner.sh --version 1.1.28-grantiva.<n> --wda-cache <home> --cli <cli worktree>`; WDA caches `sim-ios<rt>-iphone-wda16.12.8-r<rev>` for 26.0/26.2/26.4/27.0 — historically 26.2/26.4 were copies of 26.0; Round 4 requires real runtime-specific regeneration), bundle PR, docs PR, then build the release binary from `main`, copy binary + bundle to `~/.grantiva-qa/bin`, `runner install` into `~/.grantiva-qa/runner`.
- Smoke: stock 12 flows + 5 screens + `99-crash` on one iOS simulator and one Android emulator, plus one flow per risky fix. Smoke fails get briefs immediately (that is how L01–L07 appeared) and an addendum PR if they would poison the coverage pass.

### 2. Coverage pass (a plan with slices)
- Matrix: one row per command/flag/README example/flow command/MCP tool × platform, plus `B-<brief>` rows quoting each original brief's acceptance criteria, `B2-K<nn>` rows for the previous wave's briefs, `N`/`N2` rows for carried findings, `X` rows for cross-platform shape, `D2` rows for docs/help diffs, `S2` for smoke follow-ups. Row format `| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |`. IDs are stable across rounds; corrected expectations carry `(corrected round N)`.
- Slices: CLI (no devices), iOS (`cov<N>-ios-1` 26.0, `cov<N>-ios-2` 27.0; flow-command rows repeated on 27.0 with an `@27.0` suffix), Android (`cov<N>-android`, default software-rendered AVD). Each slice is one agent in its own worktree/branch; it runs every row in order, records `pass | fail | fail (matrix/brief error — triage) | blocked <reason> | n/a <reason>`, cites `findings/evidence/cov<N>-<slice>/<ROW>/commands.txt` + raw output, commits every ~40 rows, tears down, and reports. Rows needing a device that land in the CLI slice are handed to iOS.
- Each slice gets a task review (coverage scripted against the matrix; evidence spot-checks; doubtful passes become fails) and fix rounds exactly like code tasks.
- Triage: a cluster map groups fail rows by root cause (one cluster = one brief), separates expectation corrections (row/brief text predates a merged fix) and blocked rows. One brief per cluster, the round report (versions, counts per slice, Review Focus verdicts, brief list, host state, verdict line), push, then the next fix-wave plan.

### 3. Who does what
- The controller (this session or its successor) never edits product code; it writes plans, briefs, ledgers and reports, dispatches and reviews, merges PRs, and rules on conflicts. Implementers and slices never spawn reviewers. Every artifact is a file; agents are handed paths, not pasted history.
- Resume procedure for a new agent: read this file, the current plan, the live ledger (or its copy under `findings/ledgers/`), and the latest task report under the SDD workspace (`.superpowers/sdd/<plan>/task-<N>-report.md`); then continue at the first task without a `complete` line, re-dispatching nothing that is marked complete.

## Standing rules (binding for every agent)
- Never boot, shut down, erase, delete or command simulator `iPhone 17 Pro` (B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C), `iPhone 18 Pro` (FE441EE5-BBFC-4981-B68A-59C0DBCE26D6), AVD `Pixel_8_API_35`, or any device you did not create. Always pass `--simulator/--udid/--device` explicitly. Never `teardown --all`, `xcrun simctl shutdown all`, `simulator cleanup`, `pkill`/`killall`, or kill a PID you did not start. Never `git stash`.
- Test environment: `GRANTIVA="$HOME/.grantiva-qa/bin/grantiva"` (release build of grantiva/cli `main`, with `grantiva_GrantivaCore.bundle` beside it — without the bundle `runner install` silently uses a stale bundle), `GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner"`, `GRANTIVA_SESSION_ID=<slice>`, `GRANTIVA_API_KEY` unset. Never write under `~/.grantiva/runner`. Android shells: `export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"; export ANDROID_HOME="$HOME/Library/Android/sdk"; export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"`.
- Runner repo `~/Developer/maestro-runner`: the only remote to use is `grantiva` (github.com/grantiva/runner). Never fetch/push/mention the other remotes or any project the runner derives from (identifiers and raw output exempt). `go test` only with a package list, never bare `./...`.
- PRs: TDD, CI green, review loop (task review → fix rounds with scoped re-reviews; minors are fixed too), then `gh pr merge --squash --delete-branch` and verify `state == MERGED`. No `Co-Authored-By`, no `Generated with`, no session links in commits/PR bodies. Findings are repo files (briefs), never GitHub issues.
- Verification slices never fix; every doubtful behaviour is `fail`; evidence per row (`commands.txt` + verbatim raw output).
- Command gotchas learned: `emulator teardown --serial` (no `--name`); `simulator ensure --name X --device-type "iPhone 17" --runtime "iOS 26.0"`; `simulator teardown --udid … --force` may keep a session record, use `--session-id`; there is no `runner --json` (use `runner version --json`).

## Where things are (versions)
- grantiva/cli `main` c65fc17 = 2.1.0, bundles grantiva-runner 1.1.28-grantiva.11 (runner `grantiva/main` 1be68db). QA bin/home are on these.
- landmarks-demo `main` b3f046f (coverage flows under `.maestro/coverage/`; Android `10-seed-many` asserts Landmark 28).
- Merged PRs this campaign: runner #13–#20; CLI #184–#199; demo #1, #2.

## Documents
- Round 1: matrix `docs/superpowers/plans/2026-10-11-round1-coverage-matrix.md`; report `2026-10-11-round1-coverage-report.md`; briefs `2026-10-11-coverage-issues/K01..K111` (+ `00-cluster-map*.md`, `00-expectation-corrections.md`).
- Round-2 fix wave plan: `2026-10-11-round2-fix-wave.md` (rulings table inside; all 15 tasks done incl. addendum). Smoke results: `findings/round2-smoke.md` (+ `findings/evidence/round2-smoke/`).
- Addendum briefs: `2026-10-12-coverage-issues-round2/L01..L07` (L01–L04 fixed in runner #20 / CLI #198; L05, L06, L07 OPEN for round 3).
- Round-2 coverage pass plan: `2026-10-12-round2-coverage-pass.md`; matrix `2026-10-12-round2-coverage-matrix.md` (1084 rows). Slice branches/worktrees: `cov2/cli` (`.worktrees/cov2-cli`), `cov2/ios` (`.worktrees/cov2-ios`), `cov2/android` (`.worktrees/cov2-android`); results `findings/cov2-<slice>-results.md`, evidence `findings/evidence/cov2-<slice>/`.
- Help corpus: `findings/help/` (regenerated from c65fc17).

## Status of the round-2 coverage pass (see the ledger copy for detail)
- Task 1 matrix: complete.
- Task 3 CLI slice: complete (cov2/cli 33c3a4e): 335 pass / 7 fail / 13 fail-triage / 6 blocked / 4 n/a + EXTRA-01..07.
- Task 4 iOS slice: complete (cov2/ios 7bed447): 415 pass / 17 fail / 6 triage / 4 blocked; 39 @27.0 pass; 5 handed CLI rows 4 pass / 1 fail.
- Task 5 Android slice: complete (cov2/android 8885a21): 372 pass / 31 fail / 6 triage / 3 blocked / 2 n/a + AND2-OBS-01..07 (quiet-host re-runs recorded as `rerun` lines).
- Triage prep: `findings/ledgers/cluster-map-round2.md` covers CLI + iOS fails (24 clusters M01–M24, 19 expectation corrections); Android folds in when its slice lands.
- Task 6: complete. Slices merged (9fadf607); cluster map `00-cluster-map-round2.md` (41 clusters); briefs L08–L48 (44 files) in `2026-10-12-coverage-issues-round2/`; expectation corrections applied (`(corrected round 3)`, `00-expectation-corrections-round2.md`); report `2026-10-12-round2-coverage-report.md` — verdict **ROUND 2: 48 findings — round 3 fix wave required** (44 new + open L05/L06/L07/K111).
- Round-3 fix wave: plan `docs/superpowers/plans/2026-10-13-round3-fix-wave.md` (10 tasks; rulings table inside); ledger copy `findings/ledgers/2026-10-13-round3-fix-wave-ledger.md`. State as of 2026-10-13:
  - ALL round-3 fix PRs merged: runner #22 (T1 + L49/L50), #21 (T2) → grantiva/main 2d1b625; CLI #200 (T4), #202 (T6), #201 (T5), #203 (T7 docs/CI), #204 (T8 bundle runner 1.1.28-grantiva.12) → CLI main dc965716; landmarks-demo #3 (main 75acc87).
  - New briefs: L49, L50 (fixed in #22), L51 (screen/point swipes still `input swipe`, round 4), L52 (hierarchy lacks `starting` for keep-alive runs, round 4), L53 (runner accepts `--device ""`, round 4). L10 corrected (`--quiet` keeps the result summaries). Parked: holder-pid-reuse stale stop marker (L54 if seen).
  - Task 9 done: QA binary 2.1.0 @ dc965716, runner .12 installed. Round-3 smoke (`findings/round3-smoke.md`, evidence `findings/evidence/round3-smoke/`): 21 pass / 9 fail / 1 blocked → NOT CLEAN. Fails: teardown does not stop a foreground `runner start` (both platforms, stop marker not honoured); `runner stop` cannot reach a keep-alive run during its flows; keep-alive stop after the hold exits 130 not the earned status (+ no Flows summary after a failed flow); Android 99-crash timing (launchApp passes 1–3 s after the crash, fail at 3–4 s, wall 28–30 s); Android first find 3.7–4.2 s; Android doubleTap 1/5; iOS `record --duration 3` is 0.067 s; stock set under load 42.8 (environment, rerun passed). Blocked: MCP build with no simulator (owner simulators booted).
  - Smoke addendum (ruled): briefs L54–L60 filed from the smoke evidence (+ L61 slow Android failure capture, round 4). CLI addendum PR #205 (L52, L54–L56, L60: shared session lookup, teardown/`runner stop` reach a runner in its flows, keep-alive earned exit, iOS record hold/trim) MERGED → CLI main e44175be. Runner addendum PR #23 (L57–L59: launch fails on a dead process, plain selector first, on-device double tap) MERGED after 3 fix rounds → grantiva/main fd9d8e8. New briefs from the addendum: L61 (slow Android failure capture), L62 (Android 02-favorite removal intermittent on a fast AVD) — round 4. Repack 1.1.28-grantiva.13 MERGED (CLI PR #206 → main 2f4d8381). QA rebuilt at 2f4d8381 + runner .13. Re-smoke (`smoke5-*`, section in findings/round3-smoke.md, commit 28bce21e): 8 pass / 1 fail / 1 blocked — only TD-ios still fails (xcodebuild's `simctl diagnose` survives the teardown and re-creates the device home) → brief L63 FIXED: CLI PR #207 merged → CLI main 8f2cff67 (teardown reaps the run's helpers under one 30 s deadline, ~4.3 s). MCP no-simulator build still blocked (owner simulators booted). QA rebuilt at 8f2cff67; TD-ios confirmation 5/5 (bb866976) → ROUND 3 SMOKE CLEAN (MCP no-simulator build blocked by the owner's booted simulators). ROUND-3 COVERAGE PASS RUNNING: slices cov3-cli, cov3-ios, cov3-android dispatched in parallel on `.worktrees/cov3-*` (branches cov3/<slice>, never pushed; the controller merges). Ledger: `findings/ledgers/2026-10-13-round3-coverage-pass-ledger.md`. Next: slice reviews/fix rounds → Task 6 merge, triage (new briefs from L64), report `docs/superpowers/plans/2026-10-13-round3-coverage-report.md` with verdict `ROUND 3: CLEAN` or `ROUND 3: <n> findings — round 4 fix wave required` → bundle PR → QA bin rebuild → re-smoke the 9 failed checks (`findings/round3-smoke.md` addendum section) → cov3 slices. SDD workspace for the pass is ready: `.superpowers/sdd/2026-10-13-round3-coverage-pass/` (ledger, shared-constraints, task briefs).
  - Task 10 Step 1 done: `docs/superpowers/plans/2026-10-13-round3-coverage-pass.md` + `2026-10-13-round3-coverage-matrix.md` (1157 rows; +57 B3-, +16 N3-). Step 2 (slices cov3-cli/ios/android via SDD) starts after the smoke is clean.

## Incidents to report to the owner
1. Round 1, CLI slice: README quick-start resolved `init`'s default simulator to the owner's `iPhone 18 Pro` and booted it with the demo app (shut down afterwards, not deleted).
2. Round 2, iOS slice (MCP-031 / B2-K37.2): `grantiva_build {scheme}` with no simulator resolved the default to `iPhone 18 Pro` and booted it; it is still Booted (left alone per the rule). Its record in `~/.grantiva/simulator-capacity/sessions.json` (which marked it an ephemeral slot deletable by a session teardown) was removed; backup in the session scratchpad. The capacity ledger is not scoped by `GRANTIVA_RUNNER_HOME` (finding for Task 6).
3. Round 1 fix wave: a runner test once killed host emulators (fixed, F18); an agent's malformed `pkill` killed other shells (rule added); 8 stale AVD names pruned from `~/.grantiva/android/created-avds.json`.
4. 675 stale test lock files were found under `~/.grantiva/runner/locks` (K107-b); the tests no longer write there, the files were left for the owner.
5. Host load from other processes spiked to 46 during one smoke run; Android emulator timings in `findings/round2-smoke.md` are load-sensitive.

## Open items carried
L05 (first lookup after launch slow on software-rendered AVD), L06 (page-source selectors crash-check only between attempts), L07 (far-side swipe opens the row 2/3 under load; demo flow cannot detect a missed swipe), K111 (screenrecord overrun), deferred minors: holdTrack fails on a malformed extra track; SIGHUP reset under nohup.


## Resume checkpoint — 2026-10-12 host date

The existing round-3 pass is being resumed, not restarted. The current matrix has **1,170 rows** (384 CLI, 319 iOS, 308 Android, 159 both); the earlier 1,157 count above predates the smoke addendum. QA binary SHA256 `3f3293aaf1522fefe8d46457370b32a20fa8c657461bf32af086e75a754a73f8` matches the `release-main` worktree build at `8f2cff67`; `runner version` and its versioned stamp verify `1.1.28-grantiva.13`. The root runner-home `version` file is legacy and does not identify the active version.

- Tasks 0/1 remain complete; Task 2 needs no new committed demo flow.
- Tasks 3/4/5 are in progress in the existing cov3 worktrees, with recovered raw evidence preserved. Current workers: `/root/cov3_cli`, `/root/cov3_ios`, `/root/cov3_android`.
- Controller resume ledger committed as `47d26460`; use the live ledger and slice reports for newer progress.
- CLI initially had 349/384 rows; iOS and Android had untracked raw evidence, now being recovered and completed. No slice is complete until coverage and independent review finish.
- The current plan's constraints were recopied to its SDD workspace; the old copy still mentioned runner .12 and L52 as open.
- New briefs start at **L64**, since L63 was fixed already. Unresolved carries are L51/L53/L61/L62; a pass against their documented current behavior does not close those defects.
- CLI device handoffs include CLI-048/049/061/064/066 plus the guarded CLI-083/B-C21.1 and N3-15. Owner devices remain untouched.
- Next: complete slices → independent reviews/fix rounds → merge → triage/report → next fix wave as needed. Do not repeat the completed bundle/rebuild/smoke steps from the stale chain above unless new fixes require them.


### Resume integrity and approval notes

The initial iOS recovery incorrectly imported the round-2 result table and missing raw files. The controller rejected its provisional 470-pass tally. Originals were not overwritten (`rsync --ignore-existing`); the import and invalid table are quarantined and excluded. The corrected active table and `findings/evidence/cov3-ios/PROVENANCE.md` govern current coverage. Checkpoint `9542e3d4` preserves the audit trail. Do not infer current passes from archived prior-round data.

CLI review uses `/root/review_cov3_cli`; reports are in this plan's SDD workspace (`task-3-review.md`, `task-3-rereview-1.md`). The authoritative implementer report stays in `.worktrees/cov3-cli/task-3-report.md`; do not copy it just to standardize its location. First fix round addressed 11/14 findings; the second is resolving the remaining documentation inventory, platform-specific evidence and help wording. See ledger for subsequent status.

The user objected to approval frequency and canceled specific CLI N3-11 elevated verification and report-copy requests. Do not repeat those operations through a different route. N3-11 remains blocked; report can be reviewed in place. Batch necessary reviewed commits later, avoid standalone copy/commit prompts, and retain working-tree evidence. Device tests continue within established ownership boundaries; individual sandbox failures are not product failures.

## Full-access continuation checkpoint

User enabled full access and explicitly requested continued execution without further approval prompts. Existing device workers retained their original sandbox; the controller now runs their inspected scripts with full access while workers prepare fixtures and adjudicate raw evidence. Owner-device restrictions remain unchanged.

CLI evidence/review fixes are committed on cov3/cli at `6ad5a85b`; interim independent device and triage reviews are committed at `5a7a1b43`. Device slices remain incomplete and their latest work is uncommitted; consult live result files and the coverage-pass ledger, not stale counts above. Do not merge incomplete slices or declare a clean campaign.

New candidate briefs are L64 (Android launchApp can pass after FATAL) and L65 (missing script steps text differs from agreed contract). L65 is reproduced on both platforms. These are early triage drafts, not a completed round report. Additional iOS MCP label-fallback failures need triage after evidence review. A proposed Android environment-precedence failure was disproven: the first harness omitted --env, and the exact rerun passes.

Current evidence integrity: quarantined historical iOS imports remain excluded; four pre-overwrite tracked outputs were archived exactly from9542e3d4 with hashes. Uncommitted intermediate overwritten outputs cannot be recovered. Reconstructed pre-import top-level inventory is explicitly non-contemporaneous; preserve that limitation in final reporting. Fresh controller attempts use isolated output directories.

## Latest device and handoff checkpoint

CLI handoffs now close seven prior blocked verdicts: CLI048/049/061/064/066, B3-L14.1, and N3-11. Latest CLI totals368pass/7fail/5blocked/4n-a; original blocked observations remain, and independent integration review is pending. Actual runner-start N3-11 evidence uses the exact bundleless QA binary with a scratch-home clone and the legitimate owning session on U1. This supersedes the older blocked status, without deleting its original inconclusive captures.

L66 records the iOS accessibility identifier fallback defect. Independent triage and brief review support the classification: runner identifier query succeeds where MCP queries name and misses heart. Android B2-K89 runtime behavior passes but required README mixed-case exit-code documentation is absent; retain fail for Task6. Device result counts remain moving; consult their active tables. No clean/full-pass claim is justified yet.

Correction to preceding K89 note: independent review proved the Android audit read the demo README, not the CLI candidate. Candidate README726–729 already satisfies mixed-case documentation. Preserve erroneous audit but do not file a product defect; worker is correcting evidence/regrading. CLI handoffs independently reviewed and committed bb328c5c. L67 doctor section defect draft is under review.

Round4 checkpoint: runner Task1 merged PR24 at e5cba28c after approved review/CI; Task2 gestures/lifecycle active from that base. CLI Task4 live cycle-path fix and Task5 cancellation-expiry review fix remain active; demo19c1aad durable selector and cleanup evidence await independent review. Current authoritative ledger: findings/ledgers/2026-10-13-round4-fix-wave-ledger.md.

Demo PR4 merged1552ae983a27528eff4c1f8145aa075698b47f71 at2026-10-13T14:04:09Z after independent approved source/live review and successful local build (no configured demo CI). Final explicit tab fixture is now main. CLI209 a485f7b6 independent review approved, final CI still running. Task4 final60ccdf13 CI38409971540 running; six live plain/quiet/JSON startup interrupts pass130 and complete cleanup, real timeout64.10s and unexpected runner death controls pass; other iOS live criteria pending. Task4 fixes2–4 source review /root/review_fix4_cli_lifecycle active.
