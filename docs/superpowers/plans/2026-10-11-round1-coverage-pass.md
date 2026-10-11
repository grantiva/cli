# Round 1 Coverage Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Exercise every grantiva subcommand, flag and MCP tool (minus `auth` and `console`) with a real flow on iOS 26.0, iOS 27.0 and Android API 35 against the release binary built after the round-1 fix wave, record a verdict and evidence per matrix row, and turn every finding of any severity into a brief for the round-2 fix wave.

**Architecture:** Task 0 (orchestrator) resets the test home and creates slice worktrees and the help corpus. Task 1 rebuilds the 2.0.1 feature matrix for this binary and lists the demo flows coverage needs. Task 2 adds those flows (and any small app-side hooks) to landmarks-demo by PR. Tasks 3-5 run the CLI, iOS and Android slices in parallel, one row at a time, with real flows and captured evidence. Task 6 merges the slice branches, triages every non-pass row into a brief, and writes the round report with the exit-criterion verdict.

**Tech Stack:** grantiva CLI 2.1.0 release build at `~/.grantiva-qa/bin/grantiva` (main 51c597a, grantiva-runner 1.1.28-grantiva.9); landmarks-demo (SwiftUI + Compose, Maestro-format flows); Xcode 27.0 with iOS 26.0/27.0 runtimes; Android SDK 35 emulator.

**Spec:** `docs/superpowers/specs/2026-10-10-full-coverage-campaign-design.md`. Inputs: the 2.0.1 feature matrix (`~/.grantiva-qa/briefs/docs/superpowers/plans/2026-10-09-qa-feature-matrix.md`, 374 rows), the original briefs (`~/.grantiva-qa/briefs/docs/superpowers/plans/2026-10-09-qa-issues/`), the regression briefs R01-R05 (`docs/superpowers/plans/2026-10-10-regression-issues/`), the regression report's §Observations, and the "new findings" list below.

## Global Constraints

- Binary: `/Users/kyle/.grantiva-qa/bin/grantiva` with its `grantiva_GrantivaCore.bundle` beside it; `export GRANTIVA="$HOME/.grantiva-qa/bin/grantiva"`; never `swift build` in a slice; never another grantiva binary.
- Runner home: `export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner"` in every shell (a clone of the owner's home, already upgraded to 1.1.28-grantiva.9 with the `-wda16.12.8-r1` caches). Never unset it; never write under `~/.grantiva/runner`; `GRANTIVA_API_KEY` unset; `export GRANTIVA_SESSION_ID=cov-<slice>`.
- Devices: iOS slice owns `cov-ios-1` (iPhone 17, 26.0) and `cov-ios-2` (iPhone 17, 27.0); extra simulators `cov-ios-3`/`-4` only inside a row that needs them, deleted before the row ends. Android slice owns AVD `cov-android` (plus `cov-android-2` inside a row that needs it). CLI slice has no devices; rows that need one are run by the iOS or Android slice instead (the matrix assigns them). Every device command names its device. Never touch `iPhone 17 Pro` (B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C) or AVD `Pixel_8_API_35`; if `adb devices` lists a device you did not create, leave it alone. Never `teardown --all`, never kill a process you did not start, never `pkill`/`killall`.
- Android shells begin with: `export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"; export ANDROID_HOME="$HOME/Library/Android/sdk"; export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"`.
- Demo apps: copy `/Users/kyle/Developer/landmarks-demo/{ios,android}` to scratch before building (after Task 2's PR merges, re-copy). Flows live in `.maestro/` (stock 01-12, 99-crash) and `.maestro/coverage/` (added by Task 2); `grantiva.yml` keeps the stock 12 flows and the five screens.
- Verification, not fixing: nothing under `Sources/`, `Tests/`, `README.md`, `docs/` of the CLI is edited by a slice. A failing row is recorded as `fail` with evidence; a doubtful or inconsistent behaviour is `fail` too (the campaign has no "minor, leave it" bucket). Verdicts: `pass`, `fail`, `blocked <reason>` (environment), `n/a <reason>` (row does not apply on this platform).
- Evidence: every row cites a file under the slice's `findings/evidence/cov-<slice>/<ROW-ID>/` holding the exact command(s) (a `commands.txt`) and the raw output; raw captures are verbatim (no edits), write-ups never name any related or upstream project.
- Worktrees `.worktrees/cov-<slice>` on branches `cov/<slice>` off `coverage-campaign`; commit there, never push, no attribution lines. Scratch: `/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/<session>/scratchpad/cov-<slice>/`.

## New findings carried from the round-1 fix wave (each becomes a matrix row)

- N01 `grantiva runner stop` does not stop a `run --keep-alive` session (reads `.grantiva/session.json`, written only by `runner start`); SIGINT is the only way.
- N02 MCP `grantiva_build` boots the configured AVD on Android (CLI `build build` no longer does).
- N03 `10-seed-many` on a fresh AVD reached Landmark 22 not 30 after four scrolls (also with the old runner); scroll geometry or density.
- N04 `diff capture` under the runner failed the Detail screen once ("Golden Gate Bridge" not found) right after a session capture on the same simulator.
- N05 a tap on a missing label right after WDA became ready once returned "Network error (400)" instead of "Element not found".
- N06 UIAutomator2 connection dropped once on a fresh emulator on the first `diff capture` attempt.
- N07 `runner start --help` says "with WDA" only; README:332 says UIAutomator2 on Android.
- N08 the runner's `make build` copies the binary into `~/.maestro-runner/bin` (dev tooling; verify `grantiva` never depends on it).
- N09 legacy iOS driver's per-simulator `dlrun-*` xctestrun copies are never cleaned up (runner; verify the bundled runner leaves none under the home after a run).
- N10 R02-a: `devicelab_ios_legacy` reads swipe `start`/`end` as percentages only (runner follow-up; verify the CLI's default iOS driver is WDA, so no user path hits it).
- N11 `100%` now maps to size-1 for every `ParsePointCoords` caller including `point:` taps; check a `tapOn: point: "100%,100%"` lands on screen on both platforms.
- N12 MCP session capture: hint/placeholder matching, `simulator:` ignored with a live session, driver screenshots; compare one session capture per screen against `diff capture` with `diff compare`.
- N13 WDA startup window: MCP session tools return isError ("The runner session is starting…") for ~10 s after `runner start --detach`; confirm no JSON-RPC error on any of the 7 tools during that window.
- N14 report.json: `warning` field on a command whose inputText replaced real text; `error.type` = `app_crash` when a wait ended on a crash.

## Review Focus

1. Every matrix row that passed in the 2.0.1 matrix still passes on this binary (no regression in untouched areas). Tasks 3-5.
2. Every original brief's acceptance criteria (67 briefs + R01-R05) hold on the platform(s) they name. Tasks 3-5.
3. Cross-platform consistency: for each command that runs on both platforms, the text and `--json` shapes differ only where the platform demands (device naming, keys documented in docs/android.md). Task 1 defines the rows; Tasks 4-5 run them.
4. Every Maestro-format flow command the README lists as supported is exercised in at least one real flow per platform and behaves per the README. Task 1 rows; Task 2 flows; Tasks 4-5.
5. The MCP server: every tool in docs/mcp.md exercised against a live session on each platform, plus the no-session and no-config states. Tasks 4-5 (MCP rows), Task 3 (device-free MCP rows).

---

### Task 0: Reset the test home, worktrees, help corpus

Run by the orchestrating session after the round-1 smoke has committed.

- [ ] **Step 1:** `rm -rf ~/.grantiva-qa/runner && cp -c -R ~/.grantiva/runner ~/.grantiva-qa/runner`; `GRANTIVA_RUNNER_HOME=~/.grantiva-qa/runner ~/.grantiva-qa/bin/grantiva runner install | tail -2` (expect 1.1.28-grantiva.9); `ls ~/.grantiva-qa/runner/cache/wda-builds | grep -c -- '-r1'` (expect 4).
- [ ] **Step 2:** `cd /Users/kyle/Developer/grantiva-cli && for s in cli ios android; do git worktree add -q .worktrees/cov-$s -b cov/$s coverage-campaign; mkdir -p .worktrees/cov-$s/findings/evidence/cov-$s; done`.
- [ ] **Step 3: Help corpus.** In `.worktrees/regression`: `mkdir -p findings/help && $GRANTIVA --help > findings/help/grantiva.txt` and recursively every `<cmd> --help` and `<cmd> <sub> --help` (including `console`/`auth` for completeness) into `findings/help/<cmd>[_<sub>].txt`; `ls findings/help | wc -l` (expect about 172). Commit "Add the 2.1.0 help corpus for the round 1 coverage pass".

---

### Task 1: Build the round-1 feature matrix

Agent, worktree `.worktrees/regression` (branch `coverage-campaign`), no devices.

**Files:**
- Create: `docs/superpowers/plans/2026-10-11-round1-coverage-matrix.md`, `docs/superpowers/plans/2026-10-11-round1-demo-flows.md`.

**Interfaces:**
- Consumes: `findings/help/*.txt`, `docs/mcp.md`, `docs/android.md`, `README.md` (all at main 51c597a), the 2.0.1 matrix, the brief sets, the N-list above.
- Produces: the matrix with stable row IDs (`CLI-nnn`, `IOS-nnn`, `AND-nnn`, `MCP-nnn`, `X-nnn` for cross-platform, `B-<briefID>` for brief criteria, `N-nn` for carried findings), each row `ID | command/tool | inputs | expected (source) | platform | slice | flow (existing path or NEW:<name>) | result`; the demo-flows doc listing each NEW flow with its purpose, platform(s), steps in Maestro-format YAML, and any app-side hook it needs.

- [ ] **Step 1:** Re-derive the device-free rows from every help page: one row per subcommand (exit 0 help, OVERVIEW/USAGE/OPTIONS), one row per flag with a concrete invocation and expected behaviour (default, validation error text with exit code, effect), one row per README/docs example (`README.md`, `docs/*.md`) proving the example runs as written. Keep 2.0.1 IDs where the row is unchanged; mark changed rows `(changed)`.
- [ ] **Step 2:** Device rows per platform: every subcommand that touches a device (`run` with every flag incl. `--env`, `--ready-file`, `--snapshot`, `--timeout`, `--continue-on-failure`, `--report-dir`, `--keep-alive`, `--logs*`, `--json`; `build build/install` with every flag; `record` with `--duration/--frames-at/--output/--json`; `diff capture/compare/approve` incl. thresholds and `--capture`; `ci run`; `hierarchy` and `runner dump-hierarchy` all formats; `simulator`/`emulator` ensure/sessions/teardown/delete/cleanup incl. `--force`, `--session-id`, capacity; `runner start/stop/version/install`; `doctor`; `init`), each with the flow it uses.
- [ ] **Step 3:** Flow-command rows: for each Maestro-format command the README lists as supported (and each selector form: text, id, exact, regex, index, point, percentages), one row per platform, with the flow that exercises it (stock or NEW). The coverage flows go under `.maestro/coverage/<nn>-<name>.yaml` in landmarks-demo.
- [ ] **Step 4:** MCP rows: every tool in docs/mcp.md × {live session, no session, no config} × platform, plus N12/N13 and the error-shape rule (isError, never JSON-RPC error). The driving method is the stdio JSON-RPC send script the regression's CLI slice used (`findings/evidence/cli/D09.txt` and `inputs/` under the iOS evidence show it).
- [ ] **Step 5:** Brief rows: `B-<ID>` for all 67 original briefs and R01-R05, quoting each acceptance criterion as the expected text; N rows for N01-N14; X rows for cross-platform shape (same command on both platforms, both `--json` and text).
- [ ] **Step 6:** Self-check: no row without an expected behaviour and a source; no device row without a flow; every NEW flow appears in the demo-flows doc; count rows per slice. Commit "Add the round 1 coverage matrix and the demo flows it needs".

---

### Task 2: Add the coverage flows to landmarks-demo

Agent, repo `/Users/kyle/Developer/landmarks-demo` (worktree `.worktrees/coverage-flows`, branch `coverage-flows` off `main`), devices `cov-flows-ios` (26.0) and `cov-flows-android` only to prove the flows run; delete them at the end.

**Files:**
- Create: `ios/.maestro/coverage/*.yaml`, `android/.maestro/coverage/*.yaml` per `2026-10-11-round1-demo-flows.md`; app-side hooks only where that doc names them (e.g. a screen that requests a permission, a long-running progress screen, deep-link variants), kept behind the existing `LANDMARKS_*` launch arguments/env pattern.

- [ ] **Step 1:** Implement each NEW flow exactly as the demo-flows doc specifies; where an app hook is needed, add it (SwiftUI and Compose) with a unit/UI test in the demo project's existing test target if one exists.
- [ ] **Step 2:** Build both apps from the worktree and run every new flow once on each platform with `$GRANTIVA run --flow <file>` (dev runner home not needed: the release binary and `~/.grantiva-qa/runner` are fine); each must pass or fail for the documented reason (some coverage flows are negative tests; the doc says which).
- [ ] **Step 3:** PR to landmarks-demo ("Add coverage flows for the grantiva round 1 pass"), reviewed, merged by the controller. Tear down the devices.

---

### Task 3: CLI slice

Agent, worktree `.worktrees/cov-cli`, `GRANTIVA_SESSION_ID=cov-cli`, no devices.

- [ ] **Step 1:** Run every matrix row with slice `CLI` in ID order; one evidence dir per row; results in `findings/cov-cli-results.md` (`ID | result | evidence | note`).
- [ ] **Step 2:** The device-free MCP rows (no session, no config, tools/list, schema) via the stdio script.
- [ ] **Step 3:** Help-corpus consistency: every README/docs command example re-run against `findings/help/` (the Task 7 fix of round 1 should leave zero mismatches; any left is a `fail`).
- [ ] **Step 4:** Commit "CLI slice results for the round 1 coverage pass".

---

### Task 4: iOS slice

Agent, worktree `.worktrees/cov-ios`, `GRANTIVA_SESSION_ID=cov-ios`, simulators `cov-ios-1` (26.0) and `cov-ios-2` (27.0).

- [ ] **Step 1:** Build and install the scratch iOS app (post-Task-2 copy) on both; `run --no-build` of the stock set on both (12/12 + screens, cache-hit line `sim-ios<rt>-iphone-wda16.12.8-r1`, no first-time build).
- [ ] **Step 2:** Every matrix row with slice `iOS` (incl. the CLI rows the matrix hands to iOS, the MCP live-session rows, the B rows for I/C briefs, the X rows), on 26.0; repeat the flow-command rows and the stock set on 27.0; evidence per row.
- [ ] **Step 3:** Concurrency row (two simulators, two shells), capacity rows (extra sims `cov-ios-3/-4`, deleted inside the row), teardown rows (device homes gone).
- [ ] **Step 4:** Teardown both simulators, `xcrun simctl list devices | grep -c cov-ios` = 0; commit "iOS slice results for the round 1 coverage pass".

---

### Task 5: Android slice

Agent, worktree `.worktrees/cov-android`, `GRANTIVA_SESSION_ID=cov-android`, AVD `cov-android`.

- [ ] **Step 1:** `adb devices` empty check; `emulator ensure --name cov-android`; build+install the scratch Android app; stock set 12/12 + screens; `99-crash` fails fast (record time-to-failure).
- [ ] **Step 2:** Every matrix row with slice `Android` (CLI rows handed to Android, MCP live-session rows, B rows for A/C/D briefs and R01/R02, N rows, X rows); `exact:` screens without the ignored warning; `inputText` append and the `warning` field; swipe `from:` reveals the row action; `build build` never boots; ledger pruning; `emulator` capacity rows with `cov-android-2` created and deleted inside the row.
- [ ] **Step 3:** Teardown and `avdmanager delete avd -n cov-android`; `adb devices` empty, no `cov-` AVDs; commit "Android slice results for the round 1 coverage pass".

---

### Task 6: Merge, triage, round report

Run by the orchestrating session.

- [ ] **Step 1:** `git merge --no-ff cov/cli cov/ios cov/android` into `coverage-campaign`.
- [ ] **Step 2:** Every `fail` row becomes a brief `docs/superpowers/plans/2026-10-11-coverage-issues/K<nn>-<slug>.md` (sections Expected / Actual / Repro / Evidence / Suspected cause / Acceptance criteria; severity from the spec vocabulary crash | wrong-result | contract | docs | ux; cite the matrix row and any original brief). `blocked` rows are listed in the report with the reason.
- [ ] **Step 3:** `docs/superpowers/plans/2026-10-11-round1-coverage-report.md`: binary and runner versions, matrix size and results per slice (pass / fail / blocked / n-a), Review Focus 1-5 verdicts, the brief list, host state after cleanup, and the exit-criterion statement: `ROUND 1: CLEAN` only if zero `fail` rows, otherwise `ROUND 1: <n> findings — round 2 fix wave required` with the brief IDs.
- [ ] **Step 4:** Commit and push `coverage-campaign`; then write `docs/superpowers/plans/<date>-round2-fix-wave.md` from the briefs (writing-plans) and execute it.
