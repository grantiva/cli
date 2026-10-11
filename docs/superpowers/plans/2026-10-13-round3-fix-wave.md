# Round 3 Fix Wave Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix every round-2 coverage finding — briefs L08–L48 (44 files) plus the open L05, L06, L07 and K111 — as reviewed, squash-merged PRs on `grantiva/runner` and `grantiva/cli`, repack the runner as 1.1.28-grantiva.12, smoke, and run the round-3 coverage pass.

**Architecture:** Two runner PRs first (crash detection and lookup timing; gestures), because the repack depends on them. Three CLI PRs in parallel worktrees (MCP and default-device ownership; runner lifecycle and sessions; run output, config and diff/record), then a docs/CI PR after the behaviour PRs merge. The repack task bundles the merged runner; the smoke task builds the binary; the last task clones the round-2 coverage plan for round 3.

**Tech Stack:** Go 1.27 (`go test <package list>`, `go vet`) for the runner; Swift 6.4 package (`swift build -c release`, `swift test`) for the CLI; `gh`; Xcode 27.0 simulators iOS 26.0/27.0; Android SDK 35 emulator (default software-rendered AVD is the configuration under test).

**Spec:** `docs/superpowers/specs/2026-10-10-full-coverage-campaign-design.md`. Inputs: the briefs in `docs/superpowers/plans/2026-10-12-coverage-issues-round2/` (each carries Expected / Actual / Repro / Evidence / Suspected cause / Acceptance criteria and is the requirements document for its fix), `2026-10-12-round2-coverage-report.md`, `00-cluster-map-round2.md`, evidence under `findings/evidence/cov2-*/`, and the handoff `2026-10-12-campaign-handoff.md`.

## Global Constraints

- Repos and bases: runner `~/Developer/maestro-runner` (remote `grantiva` only; `grantiva/main` 1be68db; never fetch/push/mention the other remotes or any project the runner derives from — identifiers and raw output exempt); CLI `/Users/kyle/Developer/grantiva-cli` (`origin/main` c65fc17); demo `/Users/kyle/Developer/landmarks-demo` (`main` b3f046f; one small change expected: a distinct swipe-action label or an assert for L07 — by PR). Each task works in `<repo>/.worktrees/<branch>` on the branch named in the task, from the current default branch at task start.
- Every PR: TDD, the relevant tests green locally, CI green, review loop clean (minors are fixed too), `gh pr merge --squash --delete-branch`, `gh pr view --json state` = MERGED. No `Co-Authored-By`, no `Generated with`, no session links. Runner tests only with a package list, never bare `go test ./...`.
- Public contract: no CLI flag, JSON key or MCP tool name removed or renamed; keys may be added; where a brief adds a key or a line, that is the contract. JSON keys camelCase (the `LegacyJSONKeys` alias table and `JSONKeyCasingContractTests` are the mechanism). New messages follow the Errors voice: one `Error:` prefix rule (`Error: <what>. <remedy>`; usage errors exit 64 with the Usage lines; `Invalid argument:` only for argument values).
- Devices: `fix3-<task>-ios` (iPhone 17, iOS 26.0; `simulator ensure --name <n> --device-type "iPhone 17" --runtime "iOS 26.0"`) and AVD `fix3-<task>-android` (`emulator ensure --name <n>`, default software-rendered config), always with explicit `--simulator/--udid/--device`, torn down at the end (`simulator teardown --udid … --force` or `--session-id`; `emulator teardown --serial <serial>` then `avdmanager delete avd -n <n>`). Never touch `iPhone 17 Pro` (B27D7D31…), `iPhone 18 Pro` (FE441EE5…), `Pixel_8_API_35` or any device you did not create; never `teardown --all`, `simulator cleanup`, `pkill`/`killall`, kill of a PID you did not start, `git stash`. Android shells: `export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"; export ANDROID_HOME="$HOME/Library/Android/sdk"; export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"`.
- Runner home for device checks: `GRANTIVA_RUNNER_HOME=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/<session>/scratchpad/fix3-<task>/runner-home`; `GRANTIVA_API_KEY` unset; `GRANTIVA_SESSION_ID=fix3-<task>`; never `~/.grantiva/runner` or `~/.grantiva-qa/runner`. Dev runner: `make build` writes into `~/.maestro-runner/bin` (known N08 dev tooling); build into scratch where the Makefile allows, else note it; run flows directly with the dev runner binary when the CLI cannot install a local build.
- Swift tests write only under temp dirs; the `LeaseDirectoryGuard` tests fail any test that leases under the default home; every full `swift test` run uses a fresh empty `GRANTIVA_RUNNER_HOME` and asserts it stays empty.
- Reading evidence: `findings/` on `coverage-campaign` (worktree `.worktrees/regression`); read, never modify. New findings during the wave become briefs `L49+` in the same directory, never GitHub issues.
- Handoff: the controller keeps `docs/superpowers/plans/2026-10-12-campaign-handoff.md` and `findings/ledgers/` current at every phase boundary (the owner may switch tools).

## Rulings on the triage-noted briefs

| brief | ruling | why / cost if wrong |
|---|---|---|
| L15 | Fix both halves: a missing required argument is an argument failure (`Error: Invalid argument: 'name' is required.`); an unknown tool is `Error: Unknown tool: <name>`. | One prefix rule for every MCP text (K46/K53 contract). Cost: none. |
| L24 | The K97 crash rule covers `waitForAnimationToEnd`: a settle on a dead app fails the step with `app_crash`. | Screens flows settle before every screenshot; a crashed launch must not yield a screenshot of the launcher. Cost: a settle after an intentional `stopApp` must be exempt (test it). |
| L26-a | Print the Usage lines for the `record --output` extension error (resolve the platform first, then validate), exit 64. | K42's single usage-error shape. Cost: a validation step moves earlier. |
| L28 | Warn when the bundle is absent beside the binary even if an install exists; README stays. | A copied binary without its bundle is the likelier breakage. Cost: one warning line. |
| L30 | `docs/plans/` is shipped documentation: move `docs/plans/v2-swift-native-runner.md` under `docs/superpowers/` (not shipped) or delete it; make `DocsContractTests` scan `docs/plans/` too. | Readers of the repo see `docs/`. Cost: a moved file. |
| L31 | Add the CI step (and a `make`/script target) that runs `swift test` with a fresh empty `GRANTIVA_RUNNER_HOME` and fails if anything is written there; keep the existing guard. | Criterion 2 of K107-b is otherwise unprovable. Cost: CI minutes. |
| L38-a | Option 2: write the session file at runner launch with a `starting` state on both platforms so session tools and `resources/read` report "session is starting, retry" until the driver answers; docs/mcp.md says so for both platforms. | A user starting a runner should not read "No active runner session" for 15 s. Cost: a new state value (additive). |
| L38-b | Reproduce first with the orphaned-UIAutomator2-server precondition (kill -9 a keep-alive run, then `runner start --detach`); if reproduced, `--detach` returns only when its own driver answers and a new runner never adopts an orphaned server; if not reproduced in 5 of 5, close as not reproducible with the evidence. | Cost: ~20 min of device time. |
| L41 | Fix: list the available variants/modules in the unknown-variant error (from `./gradlew :app:tasks` or the Gradle model, cached). | Minors are fixed in this campaign. Cost: one Gradle call on the error path. |
| L05 | Investigate the server-side cause first (UIAutomator2 settings sent at session start, multi-window traversal, selector wait); the acceptance is the brief's timing on the default AVD. | Cost if the cause is the emulator itself: document and bound it. |
| L07 | Element swipes move to the held-drag path the bare scroll uses (explicit duration via the UIAutomator2 server), far-side start rule kept; demo PR gives the swipe action a distinct label so `02-favorite` detects a missed swipe. | Cost: one demo PR. |

## Review Focus

1. A crashed app never passes any step kind on either platform (element waits, page-source selectors, `waitForAnimationToEnd`, `extendedWaitUntil`, screens captures), and `app_crash` arrives within ~2 s of the crash on the default AVD. Task 1 (L02, L06, L24, L44).
2. Every gesture (tap, doubleTap incl. point-only, longPress, swipe `from:`, bare scroll, scrollUntilVisible) is deterministic on the software-rendered AVD at host load ≥ 8, with the row-open/landmark criteria from L07, L32–L34. Task 2.
3. Default-device resolution never takes a device Grantiva did not create: MCP build, `init` (both platforms), doctor, and the result names the device it used. Task 4 (L08, L09, L21, L45).
4. Runner lifecycle: `runner start/stop --json` share one documented shape on both platforms; a `starting` state exists; `runner stop` and both teardowns leave no session file, lock, temp dir or helper process; SIGHUP under nohup does not kill the runner. Task 5 (L11–L13, L27, L28, L35–L38, L43, L46, L48).
5. `--json`/text parity: a failing run prints its summary lines; staged paths never leak; frames are numbers on both platforms; usage errors share one shape; approve names every missing screen. Task 6 (L10, L16, L18–L20, L26, L39, L40, L42).

---

### Task 0: Setup

Run by the orchestrating session.

- [ ] **Step 1:** `cd ~/Developer/maestro-runner && git fetch -q grantiva && git log --oneline -1 grantiva/main` (expect 1be68db); `cd /Users/kyle/Developer/grantiva-cli && git fetch -q origin && git log --oneline -1 origin/main` (expect c65fc17); `gh auth status`.
- [ ] **Step 2: Worktrees.** Runner: `.worktrees/fix3-crash` (`fix3/crash-detection`), `.worktrees/fix3-gestures` (`fix3/gestures`) off `grantiva/main`. CLI: `.worktrees/fix3-mcp` (`fix3/mcp-ownership`), `.worktrees/fix3-lifecycle` (`fix3/runner-lifecycle`), `.worktrees/fix3-output` (`fix3/run-output`), `.worktrees/fix3-docs` (`fix3/docs-ci`), `.worktrees/chore-bundle-runner-12` (`chore/bundle-runner-round3`) off `origin/main`.
- [ ] **Step 3: Ledger** via `scripts/sdd-workspace`; copy the Rulings table in; refresh the handoff.

---

### Task 1: Runner — crash detection and lookup timing (L02, L05, L06, L24, L44 runner half, L47, L48 runner half)

Worktree `~/Developer/maestro-runner/.worktrees/fix3-crash`, branch `fix3/crash-detection`.

**Files:** `pkg/driver/uiautomator2/{commands.go,driver.go,wait_crash.go,transport.go}`, `pkg/uiautomator2/client.go`, `pkg/device/uiautomator.go`, `pkg/cli/android.go` (session-start settings, `--driver-start-timeout`), `pkg/driver/wda/{commands.go,driver.go,wait_crash.go}`; tests beside each.
- Read first: the briefs; `findings/evidence/cov2-android/CF-rr-crash-*/`, `CF-rr-edit-*/`, `CF-rr-l06-index0-*/`, `CF-15-input-unicode/report/client.log`.

- [ ] **Step 1: Failing tests.** L02: a crash during a find is detected within ~2 s even when the server is blocked (bounded find + concurrent check), and no step passes after `am_crash` (fake server replays the missed-crash run); L06: relative/index/size (page-source) selectors re-check the launched process on every match and during the attempt; L24: `waitForAnimationToEnd` on a dead app fails with `app_crash` (and passes after an intentional `stopApp`); L47: `GET /element/active` and every per-step request carry the step deadline (no unbounded request); L48: the UIAutomator2 session start passes a start timeout derived from the step/CLI setting and retries once on a transport failure; L05: the first lookup after `launchApp` completes under 2 s on a fake server that honours the settings grantiva sends (document which setting was the cause once found); L44 runner half: `takeScreenshot` right after `launchApp` waits for the app's window to be drawn (first frame / window focus) before capturing.
- [ ] **Step 2: Run** `go test ./pkg/driver/uiautomator2/... ./pkg/driver/wda/... ./pkg/uiautomator2/... ./pkg/device/... ./pkg/cli/... ./pkg/executor/...`; each new test fails for the brief's reason.
- [ ] **Step 3: Fix** per the briefs' Suspected cause; CHANGELOG [Unreleased] keeps one Added/Changed/Fixed.
- [ ] **Step 4: Device check** on `fix3-1-android` (default AVD): 99-crash 5×: `app_crash` within 2 s, wall under 12 s, no step passes; the L06 variants (index, below, width) 3× each fail with `app_crash`; 03-edit first tap under 3 s, 3×; stock set 12/12 once; `waitForAnimationToEnd` screens flow after a crash fails. Record uptime per run. Tear down.
- [ ] **Step 5: PR** "Detect crashes during blocked finds and settles; bound every UIAutomator2 request; faster first lookup (L02, L05, L06, L24, L44, L47, L48)". Review loop, squash-merge, verify.

---

### Task 2: Runner — gestures (L07, L32, L33, L34, L36 runner half, L20 runner half)

Worktree `.worktrees/fix3-gestures`, branch `fix3/gestures`. Parallel with Task 1.

**Files:** `pkg/driver/uiautomator2/{commands.go,gestures.go,bare_scroll.go,driver.go}`, `pkg/core/{gesture.go,selector.go}`, `pkg/cli/{test.go,keepalive.go}` (L36: abort path must not `os.Exit(1)` when `runner stop` arrives before the keep-alive hold is armed — exit 0 as an orderly stop), `pkg/flow/validator.go` (L20: report sub-flow hops with the spelling the user wrote); tests.
- Read first: the briefs; `findings/evidence/cov2-android/CF-rr-gest-*/`, `CF-rr-scroll-*/`, `CF-rr-k09-*/`.

- [ ] **Step 1: Failing tests.** L32: `doubleTapOn` sends one double-click gesture that the fake server records as a double tap (two pointer downs within the double-tap window) and the app counter test fixture sees `Double taps: 1`; L33: `doubleTapOn`/`longPressOn` with `point:` only skip the element find; L34: `scrollUntilVisible` uses the held drag with measured top-up (same primitive as bare scroll), no `input swipe` fling, and the scroll cap follows the step timeout; L07: element swipe `from:` uses the held-drag primitive with an explicit duration independent of host load, far-side start kept, and the fake-server test asserts the gesture parameters; L36: a stop signal before the hold is armed exits 0; L20: cycle errors print the user's spelling.
- [ ] **Step 2: Run** `go test ./pkg/driver/uiautomator2/... ./pkg/core/... ./pkg/cli/... ./pkg/flow/...`; confirm failures.
- [ ] **Step 3: Fix.**
- [ ] **Step 4: Device check** on `fix3-2-android`: doubleTap 5/5 registers as a double tap; point-only doubleTap/longPress work; `scrollUntilVisible "Landmark 70"` 5/5; swipe `from:` opens the row 10/10 at host load ≥ 8 (run something load-generating you own, e.g. a `yes > /dev/null` you kill by its own pid, and record uptime); 10-seed-many 3/3 Landmark 28. Tear down.
- [ ] **Step 5: Demo PR** to landmarks-demo: give the Android swipe action a distinct accessibility label (e.g. "Remove from favorites (swipe)") and make `02-favorite.yaml` tap that label (SwiftUI equivalent if iOS shares the flow). Reviewed, merged by the controller.
- [ ] **Step 6: PR** "Deterministic gestures on UIAutomator2: double tap, point-only taps, scrollUntilVisible, held element swipes (L07, L20, L32–L34, L36)". Review loop, squash-merge, verify.

---

### Task 4: CLI — MCP and default-device ownership (L08, L09, L14, L15, L17, L21, L23, L45)

Worktree `/Users/kyle/Developer/grantiva-cli/.worktrees/fix3-mcp`, branch `fix3/mcp-ownership`.

**Files:** `Sources/GrantivaMCP/{MCPServer.swift,ToolRegistry.swift,Tools/BuildTools.swift,Tools/EmulatorTools.swift,Tools/SimTools.swift,Tools/ScriptTools.swift,Tools/ContextTool.swift,Tools/SessionCapture.swift}`, `Sources/GrantivaCore/Simulator/{DefaultSimulator.swift,SimulatorManager.swift,SimulatorCapacity.swift}`, `Sources/GrantivaCore/Platform/{IOSPlatform.swift,AndroidPlatform.swift,DevicePlatform.swift}`, `Sources/GrantivaCLI/Commands/{InitCommand.swift,DoctorRunner.swift}`, `Sources/GrantivaCore/Emulator/AndroidProvenance.swift`, `Sources/GrantivaCore/Diff/DiffResult.swift`, `docs/mcp.md`; tests in `Tests/GrantivaMCPTests`, `GrantivaCoreTests`, `GrantivaCLITests`.

- [ ] **Step 1: Failing tests.** L08: a default-name simulator that Grantiva did not create (not in `created.json`) is never booted by `grantiva_build`/`grantiva_run`/`run`; the tool returns `isError` naming the device and the fix (pass `simulator`, or create one), and every build/run result names the device it used; the capacity ledger lives under `GRANTIVA_RUNNER_HOME` (or is keyed by it) so a QA home cannot claim the owner's devices; L09: Android `init` warns when the default AVD exists but was not created by Grantiva (parity with iOS) and never hardcodes `Pixel_8_API_35`; L14: a `notifications/cancelled` for an in-flight or just-queued request yields no late result (grantiva-side cancellation registry); L15: prefix rule per the ruling; L17: `grantiva_context` names the directory it checked; L21: runtimes print as `iOS 26.0` everywhere (doctor, context, refusals); L23: session-capture `Launch app` duration is `null` or measured, never 0; L45: `grantiva_emulator_boot` reports `reused` for a running AVD.
- [ ] **Step 2: Run** `swift test --filter GrantivaMCPTests` (+ Core/CLI suites touched); confirm failures.
- [ ] **Step 3: Fix.** docs/mcp.md updated for the prefix rule, the device-naming line in results, `reused`.
- [ ] **Step 4: Device check** on `fix3-4-ios` and `fix3-4-android`: in an empty directory, `grantiva_build {scheme}` with no simulator returns `isError` (and boots nothing — check `xcrun simctl list devices booted` before/after; the owner's devices must be untouched); with `simulator: fix3-4-ios` it builds and names the device; Android `init` in a clean dir warns about the default AVD. Tear down.
- [ ] **Step 5: PR** "MCP: never take a user's device as the default; one error prefix; honest context, boot and capture results (L08, L09, L14, L15, L17, L21, L23, L45)". Review loop, squash-merge, verify.

---

### Task 5: CLI — runner lifecycle and sessions (L11, L12, L13, L27, L28, L35, L36 CLI half, L37, L38-a, L38-b, L43, L46, L48 CLI half)

Worktree `.worktrees/fix3-lifecycle`, branch `fix3/runner-lifecycle`. Parallel with Task 4; rebase on the merged Task 4 if `MCPServer.swift` conflicts.

**Files:** `Sources/GrantivaCore/Runner/{ChildProcess.swift,RunnerExecution.swift,KeepAliveSessionStore.swift,RunnerManager.swift,RunnerLifecycleDocument.swift,DeviceRunnerSessions.swift,RunnerSessionStopper.swift,RunnerHelperReaper.swift}`, `Sources/GrantivaCLI/Commands/{DriverCommand.swift,EmulatorCommand.swift,SimulatorCommand.swift}`, `Sources/GrantivaCore/Simulator/{SimulatorReaper.swift,SimulatorLease.swift}`, `Sources/GrantivaCore/Emulator/EmulatorManager.swift`, `Sources/GrantivaCore/Android/{ADB.swift,AndroidPlatform.swift,UIAutomator2Client.swift}`, `Sources/GrantivaCore/Output/LegacyJSONKeys.swift`, `Sources/GrantivaMCP/MCPServer.swift` (starting state), `README.md`, `docs/mcp.md`, `docs/android.md`; tests.

- [ ] **Step 1: Failing tests.** L11: the runner inherits an ignored SIGHUP (reset only signals that are not ignored in the parent; test under a blocked/ignored mask); grantiva notices a dead keep-alive runner within a second and reports it; L12: `teardown --force` (and `runner stop`) removes the dead runner's `<pid>-*.grantiva` file (the session file carries the udid/serial so teardown can link it); L13 + L43: `runner start --json`, `runner stop --json` and `session.json` use one key set on both platforms (`bundleId`/`applicationId` twin, `port`, `runnerPid`, documented `killed`), aliases registered, fixtures in `JSONKeyCasingContractTests`; L27: `runner install` prints one path spelling (standardize before the directory exists); L28: a missing bundle warns on every command that would need it; L35: Android `emulator teardown --force` removes the killed run's temp dirs (parity with K106); L36 CLI half: `runner stop` of a foreground `runner start` exits 0 and prints the orderly line; L37: the SIGINT notice says "emulator" on Android; L38-a: the `starting` state per the ruling; L38-b: per the ruling (repro first); L46: `emulator teardown` syncs (`adb shell sync` or waits for the package manager) before killing so a just-installed app survives, test with a fake adb; L48 CLI half: the CLI stops waiting when the runner process has died (no 90 s wait) and passes a start timeout.
- [ ] **Step 2: Run** the covering suites; confirm failures.
- [ ] **Step 3: Fix.** README/docs for the JSON shape, `starting`, teardown behaviour.
- [ ] **Step 4: Device check** on `fix3-5-ios` and `fix3-5-android`: `nohup grantiva run --keep-alive …` survives a terminal SIGHUP (send SIGHUP to grantiva's own pid — yours — and verify the runner lives); `runner start --detach` on Android: `resources/read` during the first seconds says starting; `runner stop --json` shapes compared across platforms with `jq`; kill -9 a keep-alive run then `emulator teardown --force`: no session file, no temp dirs; L38-b repro 5×; install then teardown after 5 s then boot: app present 3/3. Tear down.
- [ ] **Step 5: PR** "Runner lifecycle: survive SIGHUP, one session JSON shape, starting state, clean teardown on Android (L11–L13, L27, L28, L35–L38, L43, L46, L48)". Review loop, squash-merge, verify.

---

### Task 6: CLI — run output, config, diff and record (L10, L16, L18, L19, L20 CLI half, L22, L25, L26-a, L26-b, L29, L39, L40, L41, L42-a, L42-b, L44 CLI half, K111)

Worktree `.worktrees/fix3-output`, branch `fix3/run-output`. Parallel with Tasks 4–5.

**Files:** `Sources/GrantivaCLI/Commands/{RunCommand.swift,RunCommand+Result.swift,RecordCommand.swift,DiffCommand.swift,BuildCommand.swift,SimulatorCommand.swift,EmulatorCommand.swift,DriverCommand.swift}`, `Sources/GrantivaCore/Runner/{RunnerSession.swift,RunnerArtifactCollector.swift,RunnerFailureReport.swift,RunnerReportSteps.swift,RunnerReportRewriter.swift,FlowGenerator.swift}`, `Sources/GrantivaCore/Config/{GrantivaConfig.swift,ConfigKeyValidator.swift,MaestroFlowParser.swift}`, `Sources/GrantivaCore/Record/MP4LastFrameHold.swift`, `Sources/GrantivaCore/Android/{UIAutomator2HierarchyParser.swift,GradleBuildRunner.swift}`, `Sources/GrantivaCore/Target/TargetOptions.swift`, `Sources/GrantivaMCP/Tools/UITools.swift`, `README.md`, `docs/android.md`; tests.

- [ ] **Step 1: Failing tests.** L10: a failing run prints `Screens:`/`Flows:` summaries (text and `--quiet` modes) on both platforms; L16: `diff approve` names every missing screen and saves nothing when any is missing; L18: screens summaries keep `exact` and the live/summary wait text agree; L19 + L20: stdout step lists and cycle errors show the user's paths (path map applied in `RunnerArtifactCollector`/`RunnerFailureReport`); L22: no doubled period; L25: a malformed extra track is skipped, not fatal; L26-a/b: both usage errors exit 64 with the Usage lines and the plain `Error:` prefix (one shared mutually-exclusive check); L29: `build build --help` has no `--headless`; L39: `build install --json` with `skipped` carries `appPath`; L40: Android frames are numbers (parser + `UITools` consumer + docs); L41: unknown variant lists the available ones; L42-a: native config supports `{id:}` steps; L42-b: config parse errors are plain messages naming the key and line; L44 CLI half: generated screens flows wait for the app window before the first screenshot; K111: the last-frame hold trims an overrunning recording to the requested duration while `recordedMilliseconds` keeps the pre-trim end (test with a synthetic 5.66 s stts).
- [ ] **Step 2: Run** the covering suites; confirm failures.
- [ ] **Step 3: Fix.**
- [ ] **Step 4: Device check** on `fix3-6-android` (and `fix3-6-ios` for the summary lines): a failing run prints both summaries; `hierarchy --format json` frames numeric; a native-config `{id:}` screen captures; `record --duration 3` 10× all trimmed to 3.000 s (ffprobe); Home capture through a session is not blank 3/3. Tear down.
- [ ] **Step 5: PR** "Run output and config: summaries on failure, user paths, numeric frames, native id steps, trimmed recordings (L10, L16, L18–L20, L22, L25, L26, L29, L39–L42, L44, K111)". Review loop, squash-merge, verify.

---

### Task 7: CLI — docs and CI (L30, L31, docs consistency)

Worktree `.worktrees/fix3-docs`, branch `fix3/docs-ci`, created after Tasks 4–6 merge (rebased on `origin/main`).

- [ ] **Step 1: Failing tests.** `DocsContractTests` scans `docs/plans/` (L30) — fails on the stale plan doc until it moves under `docs/superpowers/`; a CI job (and `scripts/test-fresh-home.sh`) runs `swift test` with `GRANTIVA_RUNNER_HOME` at a fresh empty directory and fails if the directory is non-empty afterwards (L31).
- [ ] **Step 2: Fix.** Move/delete the plan doc; add the CI step; consistency pass over README/docs for the merged behaviour (JSON shapes, `starting`, teardown, prefix rule, numeric frames, trimmed recordings).
- [ ] **Step 3: PR** "Docs and CI: scan shipped plans, fresh-home test run (L30, L31)". Review loop, squash-merge, verify.

---

### Task 8: Repack the runner and bundle it

Runner `grantiva/main` after Tasks 1–2 merge; CLI worktree `.worktrees/chore-bundle-runner-12`, branch `chore/bundle-runner-round3`, rebased on `origin/main` after Tasks 4–7 merge.

- [ ] **Step 1:** `drivers/ios` changed since 1be68db? If yes, `bundledWDARevision` → r2 and rebuild the 26.0/27.0 caches on `fix3-8-ios-26`/`-27`; else reuse the r1 caches. `scripts/build-runner.sh --version 1.1.28-grantiva.12 --wda-cache <home> --cli <worktree>`; both tarballs report `1.1.28-grantiva.12` with the four cache names.
- [ ] **Step 2:** `runnerVersion` → `1.1.28-grantiva.12`; stamp expectation; doc comments; README stamp example. `swift test --filter RunnerManagerTests`; full `swift test` (fresh home).
- [ ] **Step 3: PR** "Bundle runner 1.1.28-grantiva.12 (round 3 fix wave)". CI, merge, verify.

---

### Task 9: Release binary and smoke

Run by the orchestrating session after Task 8 merges.

- [ ] **Step 1:** `swift build -c release` from `main`; copy binary + `grantiva_GrantivaCore.bundle` to `~/.grantiva-qa/bin/`; `GRANTIVA_RUNNER_HOME=~/.grantiva-qa/runner grantiva runner install` → `1.1.28-grantiva.12+android-drivers-2`, four caches.
- [ ] **Step 2: Smoke** (agent): the round-2 smoke set (`findings/round2-smoke.md` round-3 section as the template) on `smoke4-ios` and `smoke4-android`: stock sets, 99-crash timing, 03-edit, 10-seed-many, 02-favorite swipe 10×, doubleTap, runner start/stop reaping + JSON shapes, MCP build without simulator in an empty dir (must `isError`, boot nothing), failing-run summaries; record as `findings/round3-smoke.md` + evidence; regenerate `findings/help/`; commit and push `coverage-campaign`.

---

### Task 10: Round 3 coverage pass

Run by the orchestrating session.

- [ ] **Step 1:** Clone `docs/superpowers/plans/2026-10-12-round2-coverage-pass.md` → `<date>-round3-coverage-pass.md`: versions (main after Task 8, runner .12), names `cov3-*`, branches `cov3/<slice>`, results `findings/cov3-<slice>-results.md`, evidence `findings/evidence/cov3-<slice>/`; Task 1 = matrix delta (round-2 matrix with the `(corrected round 3)` texts, results cleared, `B3-L<nn>` rows for L08–L48 + L05/L06/L07/K111 acceptance criteria, rows for new behaviours: `starting` state, device-naming lines, `reused`, trimmed recordings, numeric frames, usage-error shape); re-run the previously blocked rows that are now feasible (CLI-083 and B-C21.1 only if no owner simulator is booted — otherwise blocked again; CLI-153 after L08/L09; IOS-018 with a scratch home).
- [ ] **Step 2:** Execute with subagent-driven development (slices in parallel; reviews; fix rounds; merge; triage; report with `ROUND 3: CLEAN` or `ROUND 3: <n> findings — round 4 fix wave required`). Update the handoff at every boundary.
