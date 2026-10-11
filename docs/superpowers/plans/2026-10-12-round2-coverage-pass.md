# Round 2 Coverage Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Exercise every grantiva subcommand, flag and MCP tool (minus `auth` and `console`) with a real flow on iOS 26.0, iOS 27.0 and Android API 35 against the release binary built after the round-2 fix wave, record a verdict and evidence per matrix row, and turn every finding of any severity into a brief for the round-3 fix wave, or declare the campaign clean.

**Architecture:** Task 0 (orchestrator, already done at dispatch) upgraded the test home and creates the slice worktrees. Task 1 derives the round-2 matrix from the round-1 matrix: results cleared, the round-1 expectation corrections applied, one `B2-K<nn>` row per round-2 brief quoting its acceptance criteria, and rows for every behaviour the fix wave added. Tasks 3-5 run the CLI, iOS and Android slices in parallel, one row at a time, with real flows and captured evidence. Task 6 merges the slice branches, triages every non-pass row into a brief, and writes the round report with the exit-criterion verdict.

**Tech Stack:** grantiva CLI 2.1.0 release build at `~/.grantiva-qa/bin/grantiva` (main 5eab55d, grantiva-runner 1.1.28-grantiva.10); landmarks-demo (SwiftUI + Compose, Maestro-format flows); Xcode 27.0 with iOS 26.0/27.0 runtimes; Android SDK 35 emulator.

**Spec:** `docs/superpowers/specs/2026-10-10-full-coverage-campaign-design.md`. Inputs: the 2.0.1 feature matrix (`~/.grantiva-qa/briefs/docs/superpowers/plans/2026-10-09-qa-feature-matrix.md`, 374 rows), the original briefs (`~/.grantiva-qa/briefs/docs/superpowers/plans/2026-10-09-qa-issues/`), the regression briefs R01-R05 (`docs/superpowers/plans/2026-10-10-regression-issues/`), the round-1 coverage report (`docs/superpowers/plans/2026-10-11-round1-coverage-report.md`), the round-1 matrix (`2026-10-11-round1-coverage-matrix.md`, corrected), the 118 round-2 briefs K01–K110 plus K111 (`docs/superpowers/plans/2026-10-11-coverage-issues/`), their expectation corrections (`00-expectation-corrections.md`), and the round-2 fix-wave rulings (`2026-10-11-round2-fix-wave.md` §Rulings).

## Global Constraints

- Binary: `/Users/kyle/.grantiva-qa/bin/grantiva` with its `grantiva_GrantivaCore.bundle` beside it; `export GRANTIVA="$HOME/.grantiva-qa/bin/grantiva"`; never `swift build` in a slice; never another grantiva binary.
- Runner home: `export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner"` in every shell (a clone of the owner's home, already upgraded to 1.1.28-grantiva.10 with the `-wda16.12.8-r1` caches). Never unset it; never write under `~/.grantiva/runner`; `GRANTIVA_API_KEY` unset; `export GRANTIVA_SESSION_ID=cov2-<slice>`.
- Devices: iOS slice owns `cov2-ios-1` (iPhone 17, 26.0) and `cov2-ios-2` (iPhone 17, 27.0); extra simulators `cov2-ios-3`/`-4` only inside a row that needs them, deleted before the row ends. Android slice owns AVD `cov2-android` (plus `cov2-android-2` inside a row that needs it). CLI slice has no devices; rows that need one are run by the iOS or Android slice instead (the matrix assigns them). Every device command names its device. Never touch `iPhone 17 Pro` (B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C) or AVD `Pixel_8_API_35`; if `adb devices` lists a device you did not create, leave it alone. Never `teardown --all`, never kill a process you did not start, never `pkill`/`killall`.
- Android shells begin with: `export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"; export ANDROID_HOME="$HOME/Library/Android/sdk"; export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"`.
- Demo apps: copy `/Users/kyle/Developer/landmarks-demo/{ios,android}` (main b3f046f: coverage flows + the Android `10-seed-many` target) to scratch before building. Flows live in `.maestro/` (stock 01-12, 99-crash) and `.maestro/coverage/` (merged in round 1); `grantiva.yml` keeps the stock 12 flows and the five screens.
- Verification, not fixing: nothing under `Sources/`, `Tests/`, `README.md`, `docs/` of the CLI is edited by a slice. A failing row is recorded as `fail` with evidence; a doubtful or inconsistent behaviour is `fail` too (the campaign has no "minor, leave it" bucket). Verdicts: `pass`, `fail`, `blocked <reason>` (environment), `n/a <reason>` (row does not apply on this platform).
- Evidence: every row cites a file under the slice's `findings/evidence/cov2-<slice>/<ROW-ID>/` holding the exact command(s) (a `commands.txt`) and the raw output; raw captures are verbatim (no edits), write-ups never name any related or upstream project.
- Worktrees `.worktrees/cov2-<slice>` on branches `cov2/<slice>` off `coverage-campaign`; commit there, never push, no attribution lines. Scratch: `/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/<session>/scratchpad/cov2-<slice>/`.

## New behaviours and findings carried from the round-2 fix wave (each becomes a matrix row)

- N2-01 K111 screenrecord overrun is not trimmed (open brief; verify current behaviour, expect `fail` unless fixed).
- N2-02 `grantiva runner --json` printed `Error: Unknown option '--json'` on the new binary; verify against README/help (`runner status --json`?).
- N2-03 `simulator ensure --runtime 26.0` (version only) rejected while `--runtime "iOS 26.0"` works; check the help's documented form.
- N2-04 `diff approve/compare --json` carry `ignored[]` (omitted when empty); configured-screen filter; all-filtered error names the missing screens.
- N2-05 `runner stop --json`: `status: "stopped"` + `alreadyExited: true` for a dead pid; `sessions[]` when several keep-alive sessions match; `runnerPid` in every document.
- N2-06 `CI=true` implies headless; non-TTY stdout never does; `GRANTIVA_EMULATOR_HEADLESS` still works.
- N2-07 Legacy JSON aliases: every key in `LegacyJSONKeys.renamed` is written in both spellings (diff, simulator ensure, runner start/stop) and the README lists each pair; `platformTwins` (`bundle_id` → `applicationId` on Android).
- N2-08 `StepResult.duration` is `null` when unknown, never omitted, never 0.
- N2-09 `run` writes trace/failure shots to `.grantiva/run-captures/`; `diff approve/compare` never see them.
- N2-10 `DefaultSimulator.name` is shared by init, doctor, driver and MCP schemas (static text "newest installed iPhone type"); the xcrun lookup has a 5 s timeout.
- N2-11 `diff capture --no-build` on a device held by a `runner start` session captures through the session.
- N2-12 Flow report `notes` field (accepted system alerts) and the `↳ accepted system alert` line.
- N2-13 `error.type` `app_crash` for every wait kind ended by a dead app; fast fail.
- N2-14 `scrollUntilVisible` on iOS under 10 s per search; the `(…, slow)` suffix replaces `⚠` for slow passed steps.
- N2-15 Foreground `runner start` stays attached, exits 130 on SIGINT, streams through the narration choke point; `--quiet`/`--json` silence it.
- N2-16 Android settings restore waits for a device that left adb (30 s listed-offline, 5 s unlisted); the K06 fresh-boot capture 3 of 3.
- N2-17 Element swipe `from:` far-side rule documented in the runner docs; row opens 10 of 10 (K09 correction).
- N2-18 ChildProcess spawn resets the signal mask (runner interruptible when grantiva inherits blocked signals); deferred minor: SIGHUP under nohup.
- N2-19 The remaining `Invalid argument:` MCP texts (K46 follow-up from Task 10) — record the current wording per tool.
- N2-20 Deferred minors from the fix wave ledger (holdTrack fails on a malformed extra track; nohup SIGHUP) — verify or file.

## Review Focus

1. Every matrix row that passed in the 2.0.1 matrix still passes on this binary (no regression in untouched areas). Tasks 3-5.
2. Every original brief's acceptance criteria (67 briefs + R01-R05) hold on the platform(s) they name. Tasks 3-5.
3. Cross-platform consistency: for each command that runs on both platforms, the text and `--json` shapes differ only where the platform demands (device naming, keys documented in docs/android.md). Task 1 defines the rows; Tasks 4-5 run them.
4. Every Maestro-format flow command the README lists as supported is exercised in at least one real flow per platform and behaves per the README. Task 1 rows; Task 2 flows; Tasks 4-5.
5. The MCP server: every tool in docs/mcp.md exercised against a live session on each platform, plus the no-session and no-config states. Tasks 4-5 (MCP rows), Task 3 (device-free MCP rows).

---

### Task 0: Test home, worktrees, help corpus

Run by the orchestrating session. Steps 1 and 3 were done in the round-2 fix wave's Task 14 (release binary 2.1.0 at main 5eab55d in `~/.grantiva-qa/bin/` with its bundle; `~/.grantiva-qa/runner` upgraded to `1.1.28-grantiva.10+android-drivers-2` with the four `-r1` caches; `findings/help/` regenerated and committed with the round-2 smoke).

- [ ] **Step 1:** Verify: `GRANTIVA_RUNNER_HOME=~/.grantiva-qa/runner ~/.grantiva-qa/bin/grantiva runner install | tail -2` (expect already installed, 1.1.28-grantiva.10); `ls ~/.grantiva-qa/runner/cache/wda-builds | grep -c -- '-r1'` (expect 4); `~/.grantiva-qa/bin/grantiva --version` (2.1.0).
- [ ] **Step 2:** `cd /Users/kyle/Developer/grantiva-cli && for s in cli ios android; do git worktree add -q .worktrees/cov2-$s -b cov2/$s coverage-campaign; mkdir -p .worktrees/cov2-$s/findings/evidence/cov2-$s; done`.

---

### Task 1: Build the round-2 feature matrix

Agent, worktree `.worktrees/regression` (branch `coverage-campaign`), no devices.

**Files:**
- Create: `docs/superpowers/plans/2026-10-12-round2-coverage-matrix.md`.
- Read: `docs/superpowers/plans/2026-10-11-round1-coverage-matrix.md` (corrected rows carry `(corrected round 2)`), `00-expectation-corrections.md`, every brief in `docs/superpowers/plans/2026-10-11-coverage-issues/K*.md`, `findings/help/*.txt`, `README.md`, `docs/*.md` (all at main 5eab55d), the N2 list above, the fix-wave rulings table.

**Interfaces:**
- Produces: the round-2 matrix with the same row format and the same stable IDs as round 1 (`CLI-nnn`, `IOS-nnn`, `AND-nnn`, `MCP-nnn`, `X-nnn`, `B-<brief>`, `N-nn`), result column empty; plus new rows `B2-K<nn>[-a|-b]` (one per round-2 brief file, quoting its Acceptance criteria as the expected text, slice per its Platforms line; expectation-corrected briefs K09/K94 become `B2-K09` "far-side rule documented and row opens 10/10" and `B2-K94` "summary line present"), `N2-nn` rows for the list above, and rows for every new flag/key/message the help corpus diff shows (`git diff 51c597a..5eab55d -- README.md docs/` and the help pages that changed in the round-2 smoke commit).

- [ ] **Step 1:** Copy the round-1 matrix, clear the result column, keep every row (the round-2 pass is a full pass), apply the corrected expected texts, drop nothing.
- [ ] **Step 2:** Add the `B2-K` rows from the briefs' Acceptance criteria (one row per criterion where a brief lists several testable criteria on different platforms; otherwise one row per brief), each naming the flow or command it uses (the K briefs' Repro sections name them; coverage flows live in `.maestro/coverage/`).
- [ ] **Step 3:** Add `N2-01..N2-20` rows and the help/README/docs-diff rows (new flags, keys, messages, headless rule, run-captures directory, alias list, `runner stop` fields, `simulator ensure` keys, MCP docs sections).
- [ ] **Step 4:** Self-check as in round 1 (no row without expected + source; no device row without a flow; counts per slice; every K brief has at least one `B2-K` row). Commit "Add the round 2 coverage matrix".

---

### Task 2: Demo flows

Not needed in round 2: the coverage flows merged in round 1 (landmarks-demo 4e49dc4) and the Android `10-seed-many` target landed in b3f046f. If Task 1 names a NEW flow, add it by PR exactly as round 1's Task 2 did (worktree `.worktrees/coverage-flows-2`, branch `coverage-flows-2`, devices `cov2-flows-ios`/`cov2-flows-android`, deleted at the end).

---

### Task 3: CLI slice

Agent, worktree `.worktrees/cov2-cli`, `GRANTIVA_SESSION_ID=cov2-cli`, no devices.

- [ ] **Step 1:** Run every matrix row with slice `CLI` in ID order; one evidence dir per row; results in `findings/cov2-cli-results.md` (`ID | result | evidence | note`).
- [ ] **Step 2:** The device-free MCP rows (no session, no config, tools/list, schema) via the stdio script.
- [ ] **Step 3:** Help-corpus consistency: every README/docs command example re-run against `findings/help/` (the Task 7 fix of round 1 should leave zero mismatches; any left is a `fail`).
- [ ] **Step 4:** Commit "CLI slice results for the round 1 coverage pass".

---

### Task 4: iOS slice

Agent, worktree `.worktrees/cov2-ios`, `GRANTIVA_SESSION_ID=cov2-ios`, simulators `cov2-ios-1` (26.0) and `cov2-ios-2` (27.0).

- [ ] **Step 1:** Build and install the scratch iOS app (post-Task-2 copy) on both; `run --no-build` of the stock set on both (12/12 + screens, cache-hit line `sim-ios<rt>-iphone-wda16.12.8-r1`, no first-time build).
- [ ] **Step 2:** Every matrix row with slice `iOS` (incl. the CLI rows the matrix hands to iOS, the MCP live-session rows, the B rows for I/C briefs, the X rows), on 26.0; repeat the flow-command rows and the stock set on 27.0; evidence per row.
- [ ] **Step 3:** Concurrency row (two simulators, two shells), capacity rows (extra sims `cov2-ios-3/-4`, deleted inside the row), teardown rows (device homes gone).
- [ ] **Step 4:** Teardown both simulators, `xcrun simctl list devices | grep -c cov2-ios` = 0; commit "iOS slice results for the round 2 coverage pass".

---

### Task 5: Android slice

Agent, worktree `.worktrees/cov2-android`, `GRANTIVA_SESSION_ID=cov2-android`, AVD `cov2-android`.

- [ ] **Step 1:** `adb devices` empty check; `emulator ensure --name cov2-android`; build+install the scratch Android app; stock set 12/12 + screens; `99-crash` fails fast (record time-to-failure).
- [ ] **Step 2:** Every matrix row with slice `Android` (CLI rows handed to Android, MCP live-session rows, B rows for A/C/D briefs and R01/R02, N rows, X rows); `exact:` screens without the ignored warning; `inputText` append and the `warning` field; swipe `from:` reveals the row action; `build build` never boots; ledger pruning; `emulator` capacity rows with `cov2-android-2` created and deleted inside the row.
- [ ] **Step 3:** Teardown and `avdmanager delete avd -n cov2-android`; `adb devices` empty, no `cov2-` AVDs; commit "Android slice results for the round 2 coverage pass".

---

### Task 6: Merge, triage, round report

Run by the orchestrating session.

- [ ] **Step 1:** `git merge --no-ff cov2/cli cov2/ios cov2/android` into `coverage-campaign`.
- [ ] **Step 2:** Every `fail` row becomes a brief `docs/superpowers/plans/2026-10-12-coverage-issues-round2/L<nn>-<slug>.md` (same sections and severity vocabulary as the K briefs; cite the matrix row, the K brief it regresses or reopens, and the fix-wave PR). `blocked` rows are listed in the report with the reason. Rows the slice marks `fail (matrix/brief error — triage)` go to an expectation-corrections section.
- [ ] **Step 3:** `docs/superpowers/plans/2026-10-12-round2-coverage-report.md`: binary and runner versions, matrix size and results per slice (pass / fail / blocked / n-a), Review Focus 1-5 verdicts, the per-K-brief verification table (every B2-K row's verdict), the brief list, host state after cleanup, and the exit-criterion statement: `ROUND 2: CLEAN` only if zero `fail` rows, otherwise `ROUND 2: <n> findings — round 3 fix wave required` with the brief IDs.
- [ ] **Step 4:** Commit and push `coverage-campaign`. If CLEAN: the campaign's exit criterion is met; present the final summary to the owner (release stays their call). Otherwise write `docs/superpowers/plans/<date>-round3-fix-wave.md` from the L briefs (writing-plans) and execute it.
