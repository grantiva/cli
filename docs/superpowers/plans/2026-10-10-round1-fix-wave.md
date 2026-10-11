# Round 1 Fix Wave Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix every finding from the 2.1.0 regression pass (briefs R01-R05, the twelve observations, the README-vs-help wording list) and the runner follow-ups still open from the previous round, land them as reviewed, squash-merged PRs on `grantiva/runner`, `grantiva/cli` and `landmarks-demo`, repack the runner into the CLI, and produce the release binary the round-1 coverage pass will test.

**Architecture:** Runner fixes (Go, `~/Developer/maestro-runner`, drivers `pkg/driver/uiautomator2` and `pkg/driver/wda`, flow parsing `pkg/flow`) go first because the repack depends on them. CLI fixes (Swift, `Sources/GrantivaCore`, `Sources/GrantivaMCP`, `Sources/GrantivaCLI`) run in parallel in their own worktrees. The docs batch runs after the runner batches so README statements match behaviour. The repack task bundles the merged runner, and the final task builds the binary and smoke-tests the two blocking fixes on devices.

**Tech Stack:** Go 1.2x with `go test ./...` and golangci-lint (runner); Swift 6 package, `swift build`, `swift test` (CLI); gh CLI for PRs; Xcode 27.0 simulators iOS 26.0/27.0; Android SDK 35 emulator.

**Spec:** `docs/superpowers/specs/2026-10-10-full-coverage-campaign-design.md`. Inputs: `docs/superpowers/plans/2026-10-10-regression-issues/R01..R05`, `docs/superpowers/plans/2026-10-10-release-regression-report.md` §Observations and §Plan-text errors, `findings/` evidence on branch `coverage-campaign`.

## Global Constraints

- Repos and bases: runner `~/Developer/maestro-runner` (remote `grantiva` = github.com/grantiva/runner, `grantiva/main` 2f2ee31; the `origin` and `upstream` remotes there are NOT ours and are never fetched from, pushed to, or mentioned); CLI `/Users/kyle/Developer/grantiva-cli` (`origin/main` a278b77); demo `/Users/kyle/Developer/landmarks-demo` (`main`). Each task works in its own worktree under `<repo>/.worktrees/<branch>` on a branch named in the task, from the repo's current default branch (runner: `grantiva/main`; CLI and demo: `origin/main`), fetched first. Never work on `main` directly. Never `git stash`.
- Every PR: TDD (failing test first, then the fix), `go test ./...` or `swift test` green locally, CI green, review loop clean, then `gh pr merge --squash --delete-branch`. Commit messages and PR bodies carry no `Co-Authored-By`, no `Generated with`, no session links. Nothing anywhere (code comments, docs, PRs, commits, test names) mentions any other project the runner is related to or derived from; name only grantiva and grantiva-runner. Existing identifiers that already carry such a name are left as they are.
- Public contract: no CLI flag, JSON key or MCP tool name is removed or renamed in this wave; behaviour fixes only. New messages follow the existing voice in `Sources/GrantivaCore/Errors` (plain, name the thing, say what to do).
- Devices: device-backed tests in a task use simulators named `fix-<task>-ios` (iPhone 17, runtime 26.0, created with `grantiva simulator ensure`) or AVD `fix-<task>-android` (`grantiva emulator ensure`), always with an explicit `--simulator`/`--udid`/`--device`, torn down at the end of the task. Never touch `iPhone 17 Pro` (B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C) or AVD `Pixel_8_API_35`; never `teardown --all`; never kill a process you did not start. Android shells begin with the JAVA_HOME/ANDROID_HOME/PATH exports from the previous plan. `GRANTIVA_API_KEY` unset. A development runner binary for device checks is built with `make build` in the runner worktree and pointed at via `GRANTIVA_RUNNER_HOME=<scratch>/runner-home` with the dev binary copied under `versions/<stamp>/grantiva-runner` next to a `version` file holding the stamp, so the owner's real home is never touched.
- Scratch: `/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/<session>/scratchpad/fix-<task>/`.
- Reading evidence: the regression findings are on the CLI branch `coverage-campaign` (worktree `/Users/kyle/Developer/grantiva-cli/.worktrees/regression`) under `findings/`; read them there, never modify them.

## Review Focus

1. R01: on Android `inputText` appends to the focused field's existing text (Maestro semantics) and the typed text is what the flow asserts. Task 1.
2. R02: `swipe: {direction, from}` travels from the element centre to the screen edge (minus the standard margin) so the row action is revealed; `start: 900, 520` style plain integers are pixels, `60%, 22%` are percentages. Task 2.
3. R05: during the seconds after `runner start --detach`, MCP session tools return `isError` results naming the WDA startup state, never a JSON-RPC error. Task 4.
4. `runner install` refuses to stamp a version whose extracted runner does not report that version. Task 5.
5. `grantiva build build` never boots an emulator or simulator. Task 6.

---

### Task 0: Setup and follow-up harvest

Run by the orchestrating session.

**Files:**
- Create: worktrees per task (listed in each task); `docs/superpowers/plans/2026-10-10-round1-runner-followups.md` on `coverage-campaign`.

- [ ] **Step 1: Toolchains.** `cd ~/Developer/maestro-runner && git fetch -q origin && git log --oneline -1 origin/main && go version && make -n build | head -2`; `cd /Users/kyle/Developer/grantiva-cli && git fetch -q origin && git log --oneline -1 origin/main && swift --version | head -1`; `gh auth status`.
- [ ] **Step 2: Harvest runner follow-ups.** For PRs #6-#12 on grantiva/runner: `gh pr view <n> -R grantiva/runner --comments` and `gh api repos/grantiva/runner/pulls/<n>/comments`; collect every review remark that was acknowledged as a follow-up rather than fixed (the memory list: whole-value and case-insensitive text+id matching on WDA, early fail of an element wait when the app process dies, swipe `from:` on the appium/devicelab/cdp drivers, uia2 minors, WDA isolation M-2/M-4/M-5, real-device alert path, lint cache). Write each as `F<nn> | PR | file:line | one-line requirement | which task takes it` into the followups doc. Tasks 1-3 consume it. Commit on `coverage-campaign`.
- [ ] **Step 3: Worktrees.** Runner: `git worktree add .worktrees/fix-uia2-input -b fix/uia2-input grantiva/main` and likewise `fix-swipe-geometry`, `fix-selectors-followups`. CLI: `fix-mcp-session`, `fix-runner-install-teardown`, `fix-android-polish`, `fix-docs-round1`, `chore-bundle-runner` (branches `fix/mcp-session`, `fix/runner-install-teardown`, `fix/android-polish`, `fix/docs-round1`, `chore/bundle-runner-round1`) from `origin/main`.

---

### Task 1: Runner — Android `inputText` appends; `tapOn` does not pick keyboard keys (R01)

Worktree `~/Developer/maestro-runner/.worktrees/fix-uia2-input`, branch `fix/uia2-input`.

**Files:**
- Modify: `pkg/driver/uiautomator2/commands.go` (text input path), the uia2 element lookup used by `tapOn`, tests beside them.
- Read first: brief R01, `findings/evidence/android/flow03-client.log`, `flow03-prior-round-comparison.txt`.

- [ ] **Step 1: Failing tests.** A driver test with a fake uia2 server asserting that `inputText " Renamed"` on a field holding `Golden Gate Bridge` results in the server receiving key/actions input that yields `Golden Gate Bridge Renamed` (not a `POST /element/<id>/value` that replaces). A lookup test asserting `tapOn "Done"` prefers a visible non-IME element when the page source has both a toolbar button "Done" and a keyboard key "Done" (reproduce the (994,2196) pick from the evidence; if the IME key is not in the page source, document in the test what the actual ambiguity was and assert the correct resolution).
- [ ] **Step 2: Fix.** Restore append semantics (type into the focused element via key actions as the previous round did, or set value to existing+new when the server only offers replace), keep the `am start` quoting and crash detection from PR #7 intact. Fix the tapOn ambiguity.
- [ ] **Step 3: Device check.** `make build`; run `.maestro/03-edit.yaml` from a scratch copy of landmarks-demo/android on `fix-1-android` through the grantiva 2.1.0 CLI with the dev runner home; it must pass; save output to the PR description. Tear the AVD down.
- [ ] **Step 4: PR.** `go test ./...`, lint, push, `gh pr create -R grantiva/runner` titled "Append inputText on Android and resolve tapOn to on-screen elements (R01)", body: what changed, the device check output, follow-ups consumed from the harvest. Merge after the review loop.

---

### Task 2: Runner — swipe geometry (R02)

Worktree `.worktrees/fix-swipe-geometry`, branch `fix/swipe-geometry`.

**Files:**
- Modify: `pkg/driver/uiautomator2/commands.go` swipe path, `pkg/driver/wda` swipe path, `pkg/flow/step.go` swipe coordinate parsing, tests.
- Read first: brief R02, `findings/evidence/android/A02/probes/summary.txt`, `e-manual-short-swipes.txt`.

- [ ] **Step 1: Failing tests.** (a) `swipe: {direction: LEFT, from: X}` with X at rect [0,432][1080,621] on a 1080-wide screen produces a swipe from X's centre to x = screen-edge margin (Maestro: to the edge), travelling most of the width; (b) `start: 900, 520` / `end: 100, 520` are pixels, `start: 60%, 22%` are percentages, on both drivers; (c) the `from:` element swipe on the WDA driver uses the same rule.
- [ ] **Step 2: Fix** on both drivers and the parser; keep the element lookup and "Element not found for swipe" failure from PR #6.
- [ ] **Step 3: Device check.** On `fix-2-android`: flow 02 passes AND its cmd-008 before/after captures differ (the Remove action is revealed by the swipe, not by the button); a one-step flow with `start: 900, 520 / end: 100, 520` on the row opens it. Save md5s and output to the PR. Tear down.
- [ ] **Step 4: PR** "Swipe from an element to the screen edge and read plain swipe coordinates as pixels (R02)". Merge after review.

---

### Task 3: Runner — `exact:` on Android and the harvested follow-ups

Worktree `.worktrees/fix-selectors-followups`, branch `fix/selectors-followups`. Depends on Task 0 Step 2.

**Files:**
- Modify: uia2 selector matching (`exact`), WDA text/id matching (whole-value, case rules per the follow-up), element-wait loop (early fail when the app process is gone), the other drivers' swipe `from:`, isolation items, tests for each.

- [ ] **Step 1: Failing tests** per follow-up row the harvest assigns to this task, plus: `tapOn: {text: "Landmarks", exact: true}` on Android matches only the exact text and never warns.
- [ ] **Step 2: Fix** each; remove the `"exact" is not supported on android` warning.
- [ ] **Step 3: Device check** on `fix-3-android` and `fix-3-ios`: the landmarks screens with `exact: true` in `grantiva.yml` capture Lakes and Detail without the warning; `99-crash` fails within 5 s of the crash instead of waiting out the element timeout.
- [ ] **Step 4: PR** "Support exact selectors on Android, fail element waits when the app dies, and close the selector follow-ups". Merge after review.

---

### Task 4: CLI — MCP session lifecycle (R04, R05, vrt_capture ownership)

Worktree `/Users/kyle/Developer/grantiva-cli/.worktrees/fix-mcp-session`, branch `fix/mcp-session`.

**Files:**
- Modify: `Sources/GrantivaMCP/ToolRegistry.swift`, `Sources/GrantivaMCP/Tools/UITools.swift`, `Sources/GrantivaCore/WDA/WDAClient.swift` (resolveSessionId), the VRT tools, config-loading error text; tests in `Tests/GrantivaMCPTests`.
- Read first: briefs R04, R05, `findings/evidence/cli/C11-lazy-attach.txt`, `C05.txt`, `C11.txt`, `docs/mcp.md`.

- [ ] **Step 1: Failing tests.** (R05) with a session file present and a WDA stub that answers `/status` but has no session, every one of the 7 session tools returns a result with `isError: true` whose text names the WDA startup state and says to retry, and no JSON-RPC `error` object is produced; (R04) with no `grantiva.yml` in cwd, `grantiva_vrt_capture`, `grantiva_build`, `grantiva_run` and `grantiva_test` return `isError` text that says `grantiva.yml` was not found at `<path>`; (ownership) with a live runner session on the simulator, `grantiva_vrt_capture` captures through that session instead of refusing.
- [ ] **Step 2: Fix.** Catch `WDAClient` session errors in `ToolRegistry.call`/`callSessionTool` and map to `isError`; distinguish "no config file" from "config has no screens/scheme" at the loading site; let VRT capture reuse the active session's device lease. Update `docs/mcp.md` where it describes these.
- [ ] **Step 3: Device check** on `fix-4-ios`: `runner start --detach` then an immediate `tools/call grantiva_a11y_tree` returns `isError` (not `-32603`); `grantiva_vrt_capture` while the session is live succeeds.
- [ ] **Step 4: PR** "Return isError during WDA startup, name the missing config file, and let vrt_capture use the active session (R04, R05)". Merge after review.

---

### Task 5: CLI — install integrity and device-home cleanup

Worktree `.worktrees/fix-runner-install-teardown`, branch `fix/runner-install-teardown`.

**Files:**
- Modify: `Sources/GrantivaCore/Runner/RunnerManager.swift` (installUnlocked), `Sources/GrantivaCore/Runner/WDADeviceHome.swift`, simulator teardown path, `README.md:92`; tests in `Tests/GrantivaCoreTests/RunnerManagerTests.swift` and the simulator lifecycle tests.
- Read first: `findings/task0-upgrade.md` §Observation, `findings/evidence/ios/teardown/teardown.txt`, `I09/device-homes-after-next-run.txt`.

- [ ] **Step 1: Failing tests.** (install) when the extracted `grantiva-runner --version` (or an embedded `RUNNER_VERSION` file in the tarball, whichever the build script can emit; prefer the file) does not equal the stamp, `installIfNeeded` throws a `GrantivaError` naming both versions and the bundle path, leaves the previous install intact and writes no stamp; (teardown) `simulator teardown --udid` and `--force` remove `<install dir>/devices/<udid>` for every runner version directory, and the removal failure is reported, not swallowed by `try?`.
- [ ] **Step 2: Fix** both; add the version marker to `scripts/`'s expectations if the tarball carries it (coordinate with Task 8: the repack must emit it); README:92 states the real path `<runner home>/versions/<runner version>/devices/<udid>` and that teardown removes it.
- [ ] **Step 3: Device check** on `fix-5-ios`: run flow 01 (`--keep-alive` then `runner stop`), `simulator teardown --udid`, confirm the device dir is gone.
- [ ] **Step 4: PR** "Verify the extracted runner matches its stamp and remove device homes on teardown". Merge after review.

---

### Task 6: CLI — Android polish

Worktree `.worktrees/fix-android-polish`, branch `fix/android-polish`.

**Files:**
- Modify: build command device resolution (`Sources/GrantivaCLI/Build*`), emulator resolution messages, `diff capture` and `record --json` output on Android, the `--timeout` kill message, `created-avds.json` bookkeeping, interrupt handling in the run path; tests beside each.
- Read first: report §Observations bullets 4-9 and 11, `findings/evidence/android/incident-5556/`, `D07/run-no-device-*.txt`, `A13/diff-capture.txt`, `A05/record.json`, `A06/timeout.txt`, `created-avds-after.json`, `A10/failure-shot-timeline.txt`, `D02-table.txt`.

- [ ] **Step 1: Failing tests.** `build build` with no `--device` and a configured `emulator:` never calls the boot path (compiles the APK only; `build install` may boot and says so); `Resolved: … device=` and `Booting emulator:` never print an empty serial (they name the AVD or say "no device"); `diff capture` on Android prints `Emulator: <avd> (<serial>)` and `record --json` emits `emulator`/`serial` alongside (not instead of) the existing keys; the kill message has no trailing colon; `emulator delete`/`teardown` prunes the AVD from `created-avds.json`, and `emulator ensure` drops entries whose AVD no longer exists; Ctrl-C of a `--keep-alive` run whose flows all passed writes no `failure-*.png`.
- [ ] **Step 2: Fix** each.
- [ ] **Step 3: Device check** on `fix-6-android`: `build build` with the AVD stopped leaves `adb devices` empty afterwards; `diff capture` output; Ctrl-C scenario.
- [ ] **Step 4: PR** "Android polish: build never boots a device, Android wording and JSON keys, AVD ledger pruning, no failure shot after a passed keep-alive run". Merge after review.

---

### Task 7: CLI — docs round 1 (R03, D02 wording, README:147)

Worktree `.worktrees/fix-docs-round1`, branch `fix/docs-round1`. Depends on Tasks 3 and 5 being merged (rebase onto `origin/main` first).

**Files:**
- Modify: `README.md` (lines 99/101, 147, 311, 312, 314, 338 and any other README example whose text differs from `--help`), `docs/android.md`, `docs/mcp.md` as needed.

- [ ] **Step 1: Sweep.** From the release binary built from the rebased `main` (`swift build -c release` here is allowed: this is a docs task and the binary is for comparison), regenerate help for every command into scratch and diff every README code block that shows a command against the help; list every mismatch.
- [ ] **Step 2: Fix** all of them; README:99 drops the obsolete note (C26); README:147 stays accurate now that `exact:` works on Android; README:338 `init` mentions Android.
- [ ] **Step 3: PR** "Align README and docs with 2.1 help output (R03, D02)". Merge after review. No tests; the reviewer re-runs the diff.

---

### Task 8: Repack the runner and bundle it

Runner `main` after Tasks 1-3 merge; CLI worktree `.worktrees/chore-bundle-runner`, branch `chore/bundle-runner-round1`, rebased on `origin/main` after Tasks 4-7 merge.

**Files:**
- Modify: `Sources/GrantivaCore/Resources/grantiva-runner-{arm64,amd64}.tar.gz`, `Sources/GrantivaCore/Runner/RunnerManager.swift` (`runnerVersion` -> `1.1.28-grantiva.9`), `Tests/GrantivaCoreTests/RunnerManagerTests.swift` stamp expectations.

- [ ] **Step 1: Build.** In `~/Developer/maestro-runner` on `main`: `scripts/build-runner.sh --version 1.1.28-grantiva.9 --wda-cache <dir> --cli <cli worktree>` per the recipe in the previous round (caches: run the new runner once against a 26.0 and a 27.0 simulator named `fix-8-ios-26`/`fix-8-ios-27` with `MAESTRO_RUNNER_HOME=<scratch>` and the `grantiva-wda.xcconfig`, copy 26.0 to 26.2/26.4, prune to `DerivedData/Build/Products`). If Task 5 introduced a version marker file, make sure the tarball carries it.
- [ ] **Step 2: Verify** the tarballs list `./grantiva-runner`, `./drivers/`, `./cache/wda-builds/sim-ios{26.0,26.2,26.4,27.0}-iphone-wda16.12.8/`; `swift test` passes with the new stamp.
- [ ] **Step 3: PR** "Bundle grantiva-runner 1.1.28-grantiva.9 (round 1 fixes)". Merge after review. Tear down the simulators.

---

### Task 9: Release binary and smoke

Run by the orchestrating session after Task 8 merges.

- [ ] **Step 1:** `cd /Users/kyle/Developer/grantiva-cli/.worktrees/regression && git fetch -q && git merge -q origin/main` (keeps `coverage-campaign` current), `swift build -c release`, copy binary AND bundle to `~/.grantiva-qa/bin/`, `grantiva --version` -> 2.1.0, `runner version` -> 1.1.28-grantiva.9.
- [ ] **Step 2:** Fresh clone of `~/.grantiva/runner` to `~/.grantiva-qa/runner`; `runner install` with `GRANTIVA_RUNNER_HOME` set; verify the new stamp directory, all caches, and that `versions/1.1.28-grantiva.9*/grantiva-runner --version` reports the new version.
- [ ] **Step 3: Smoke.** Android `smoke-android` AVD: flows 02 and 03 pass with the swipe revealing the action; iOS `smoke-ios` (26.0): flows 01 and 03 pass with the cache hit line. Tear both down. Record in `findings/round1-smoke.md` on `coverage-campaign`; commit.
- [ ] **Step 4:** Write the round-1 coverage-pass plan with superpowers:writing-plans (`docs/superpowers/plans/2026-10-11-round1-coverage-pass.md`): rebuild the feature matrix from the new help output and `docs/mcp.md`, three slices, demo-flow additions as landmarks-demo PRs, triage into `docs/superpowers/plans/2026-10-11-coverage-issues/`. Then execute it.
