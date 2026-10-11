# Coverage campaign — handoff (resume from here)

Updated: 2026-10-12 (round-2 coverage pass in progress). This file is the tool-agnostic resume point for the full-coverage campaign. Everything an agent needs is on branch `coverage-campaign` of grantiva/cli, worktree `/Users/kyle/Developer/grantiva-cli/.worktrees/regression`. The per-plan SDD ledgers are git-ignored scratch; copies are committed under `findings/ledgers/` at each phase boundary (the live ones are in `.superpowers/sdd/<plan>/progress.md`).

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
- Then: repack the runner (`scripts/build-runner.sh --version 1.1.28-grantiva.<n> --wda-cache <home> --cli <cli worktree>`; WDA caches `sim-ios<rt>-iphone-wda16.12.8-r<rev>` for 26.0/26.2/26.4/27.0 — 26.2/26.4 are copies of 26.0 on this host), bundle PR, docs PR, then build the release binary from `main`, copy binary + bundle to `~/.grantiva-qa/bin`, `runner install` into `~/.grantiva-qa/runner`.
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
- Task 5 Android slice: implementer done (cov2/android eee675f): 371 pass / 36 fail / 2 triage / 3 blocked / 2 n/a + AND2-OBS-01..06; host load 98–394 for part of the run; review done → fix round 1 running (quiet-host re-runs of load-sensitive rows + regrades: B2-L01 → pass, crash-at-first-assert rows → expectation correction, K111 needs ffprobe). Cluster map final: 40 clusters M01–M40, 94 fail rows placed.
- Triage prep: `findings/ledgers/cluster-map-round2.md` covers CLI + iOS fails (24 clusters M01–M24, 19 expectation corrections); Android folds in when its slice lands.
- Task 6 (next): `git merge --no-ff cov2/cli cov2/ios cov2/android` into `coverage-campaign`; one brief per fail in `docs/superpowers/plans/2026-10-12-coverage-issues-round2/` (continue the L numbering from L08; format as the K/L briefs); expectation corrections for the `fail (matrix/brief error — triage)` rows; report `docs/superpowers/plans/2026-10-12-round2-coverage-report.md` with the verdict `ROUND 2: <n> findings — round 3 fix wave required`; push; then write `2026-10-13-round3-fix-wave.md` (writing-plans) and execute it (runner + CLI PRs, repack .12, smoke, round-3 coverage pass).

## Incidents to report to the owner
1. Round 1, CLI slice: README quick-start resolved `init`'s default simulator to the owner's `iPhone 18 Pro` and booted it with the demo app (shut down afterwards, not deleted).
2. Round 2, iOS slice (MCP-031 / B2-K37.2): `grantiva_build {scheme}` with no simulator resolved the default to `iPhone 18 Pro` and booted it; it is still Booted (left alone per the rule). Its record in `~/.grantiva/simulator-capacity/sessions.json` (which marked it an ephemeral slot deletable by a session teardown) was removed; backup in the session scratchpad. The capacity ledger is not scoped by `GRANTIVA_RUNNER_HOME` (finding for Task 6).
3. Round 1 fix wave: a runner test once killed host emulators (fixed, F18); an agent's malformed `pkill` killed other shells (rule added); 8 stale AVD names pruned from `~/.grantiva/android/created-avds.json`.
4. 675 stale test lock files were found under `~/.grantiva/runner/locks` (K107-b); the tests no longer write there, the files were left for the owner.
5. Host load from other processes spiked to 46 during one smoke run; Android emulator timings in `findings/round2-smoke.md` are load-sensitive.

## Open items carried
L05 (first lookup after launch slow on software-rendered AVD), L06 (page-source selectors crash-check only between attempts), L07 (far-side swipe opens the row 2/3 under load; demo flow cannot detect a missed swipe), K111 (screenrecord overrun), deferred minors: holdTrack fails on a malformed extra track; SIGHUP reset under nohup.
