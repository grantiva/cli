# Round 2 Fix Wave Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix every round-1 coverage finding (briefs K01–K110 with their -a/-b splits, 118 files in `docs/superpowers/plans/2026-10-11-coverage-issues/`), land them as reviewed, squash-merged PRs on `grantiva/runner` and `grantiva/cli`, correct the matrix and the original briefs where the expectation was wrong, repack the runner into the CLI as 1.1.28-grantiva.10, smoke the result, and run the round-2 coverage pass.

**Architecture:** Runner fixes (Go) go first because the repack depends on them; they are three PRs grouped by area (output/narration, UIAutomator2 robustness, WDA semantics). CLI fixes (Swift) run in parallel worktrees as seven PRs grouped by code area (runner session output, keep-alive/runner commands, simulator lifecycle, emulator/Android, diff/record, usage errors/doctor/init, MCP), then one docs PR after the behaviour PRs merge so README text matches behaviour. A matrix/brief correction task lands on `coverage-campaign`. The repack task bundles the merged runner; the smoke task builds the binary; the last task clones the round-1 coverage-pass plan for round 2 and executes it.

**Tech Stack:** Go 1.2x (`go test <package list>`, golangci-lint) for the runner; Swift 6 package (`swift build -c release`, `swift test`) for the CLI; `gh` CLI; Xcode 27.0 simulators iOS 26.0/27.0; Android SDK 35 emulator.

**Spec:** `docs/superpowers/specs/2026-10-10-full-coverage-campaign-design.md`. Inputs: the briefs (each carries Expected / Actual / Repro / Evidence / Suspected cause / Acceptance criteria and is the requirements document for its fix), `docs/superpowers/plans/2026-10-11-round1-coverage-report.md`, `docs/superpowers/plans/2026-10-11-coverage-issues/00-cluster-map.md` and `00-cluster-map-additions.md`, evidence under `findings/evidence/cov-{cli,ios,android}/` on branch `coverage-campaign`.

## Global Constraints

- Repos and bases: runner `~/Developer/maestro-runner` (remote `grantiva` = github.com/grantiva/runner, `grantiva/main` ae48e34; the other remotes there are NOT ours and are never fetched from, pushed to, or mentioned); CLI `/Users/kyle/Developer/grantiva-cli` (`origin/main` 51c597a); demo `/Users/kyle/Developer/landmarks-demo` (`main` 4e49dc4; no demo change is expected this wave, flows are only read). Each task works in its own worktree `<repo>/.worktrees/<branch>` on the branch named in the task, created from the repo's current default branch at task start.
- Every PR: TDD (failing test first, then the fix), the relevant tests green locally, CI green, review loop clean, then `gh pr merge --squash --delete-branch`, and `gh pr view <n> --json state` confirmed `MERGED` (a merge once silently did nothing). Commit messages and PR bodies carry no `Co-Authored-By`, no `Generated with`, no session links. Nothing anywhere (code comments, docs, PRs, commits, test names) mentions any other project the runner is related to or derived from; name only grantiva and grantiva-runner. Existing identifiers that already carry such a name are left as they are.
- Runner tests: never bare `go test ./...` on this host; always a package list (e.g. `go test ./pkg/driver/... ./pkg/flow/... ./pkg/cli/...`). The `pkg/emulator` force-kill test is the reason (fixed in #16, but the rule stays).
- Public contract: no CLI flag, JSON key or MCP tool name is removed or renamed in this wave; keys may be added. Where a brief's acceptance criteria add a key or a line, that is the contract. New messages follow the existing voice in `Sources/GrantivaCore/Errors` (plain, name the thing, say what to do). JSON output from every command uses camelCase keys (K103 makes this a rule and adds the test).
- Devices: device-backed checks in a task use simulators `fix2-<task>-ios` (iPhone 17, iOS 26.0, `grantiva simulator ensure --name`) or AVD `fix2-<task>-android` (`grantiva emulator ensure --name`), always with an explicit `--simulator`/`--udid`/`--device`, torn down at the end of the task (`simulator teardown --udid … --force`, `emulator teardown --name …` then `avdmanager delete avd -n …`). Never touch `iPhone 17 Pro` (B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C), `iPhone 18 Pro` (FE441EE5-BBFC-4981-B68A-59C0DBCE26D6) or AVD `Pixel_8_API_35`, or any device you did not create; never `teardown --all`; never `xcrun simctl shutdown all`; never kill a process you did not start; never `pkill`/`killall`; never `git stash`. Android shells begin with `export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"; export ANDROID_HOME="$HOME/Library/Android/sdk"; export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"`.
- Runner home for device checks: a task's own `GRANTIVA_RUNNER_HOME=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/<session>/scratchpad/fix2-<task>/runner-home` (never `~/.grantiva/runner`, never `~/.grantiva-qa/runner`); `GRANTIVA_API_KEY` unset; `GRANTIVA_SESSION_ID=fix2-<task>`. The development runner binary comes from `make build` in the runner worktree, installed into that home with `grantiva runner install` only through the repack path, or run directly by the Go tests.
- Swift tests must not write outside the package's temp directories: K107-b fixes the two suites that take leases under the real runner home; every new test uses `FileManager.default.temporaryDirectory` roots.
- Reading evidence: `findings/` on the CLI branch `coverage-campaign` (worktree `/Users/kyle/Developer/grantiva-cli/.worktrees/regression`); read, never modify. Briefs are read from the same worktree.
- Findings during this wave (something a fix uncovers) are recorded as new briefs `K111+` in the same directory on `coverage-campaign`, never as GitHub issues.

## Rulings on the triage-noted briefs

Recorded here so every implementer reads the same decision; the ledger repeats them.

| brief | ruling | why |
|---|---|---|
| K09 | Product fix: `swipe: {direction, from}` starts at the element centre and ends at the screen-edge margin on both drivers (brief R02/A02 criteria); the "row opens 10 of 10" check stays an acceptance criterion. | Maestro semantics start at the element; the 90%-across rule contradicts two accepted briefs. Cost if wrong: an element hugging the target edge gets a short swipe; the device check catches it. |
| K21-a | Product fix: `run --json` always carries `reportDir` when a report directory exists, pass or fail; README documents the passing document too. | Additive key; consumers stop special-casing. |
| K23-b | Both: README caveat ("project detection runs only when building") and a hint line when `--no-build` resolves no app ID (`Pass --bundle-id or set appId`). | Deliberate code, undocumented. |
| K32 | Accept the rewritten brief: `build install` must not launch an app it did not install and must not leak monkey stderr. AND-OBS-04 is closed as a misattribution (expectation correction). | The evidence shows the lines came from `build install`. |
| K34-b | Product fix with diagnostics: `record --verbose` prints held-frame statistics (frames, held span, threshold); the note prints whenever the documented condition holds; a 10-run static-screen check must print it 10 of 10 or the verbose line must explain why not. | Cannot be closed without the diagnostic. |
| K48 | Both halves: README rewording for the existing-install case and a warning when the installed stamp's runner differs from the bundled tarball version. | |
| K51 | Fix `diff compare`; verify `diff approve` in the test and record the result. | Source shows only compare creates the directory. |
| K53 | Product fix: every MCP tool failure is an `isError` result; docs/mcp.md says so for all tools, not only session tools. | MCP spec; sibling tools already behave this way. |
| K58 | ux fix as re-graded: the context names the config source; an Android project never supplies an iOS bundle ID. | |
| K60 | Do it: spawn with an argument array. | Minors are fixed in this campaign; low risk. |
| K74 | Product fix: launch arguments are not mirrored into the app environment; `env:` remains the way to set environment. Runner CHANGELOG line. | Maestro semantics; no flow in the demo relies on the mirror. Cost if wrong: a user flow that read an argument from the environment breaks; the CHANGELOG line names it. |
| K78 | Keep the brief I05 contract (label match first, fallback to name/identifier); docs/mcp.md:50 states the order; matrix row IOS-102 becomes an expectation correction. IOS-OBS-06 (MCP cannot find the "Name" text field the flow's `tapOn` focuses) stays a defect and is fixed in this brief. | Two sources disagreed; the brief is the older contract. |
| K81 | Fix as written (`--snapshot trailing`). | Slug error only. |
| K86-b | Product fix: `diff capture --no-build` on a device held by a `runner start` session captures through that session (reuse the MCP session-capture path) instead of refusing; README:262-264 stands. | The README promise is the better product. |
| K91 | Check the full runner log of the repro first; whichever way it falls, surface `accepted system alert <label>` in the run output as a narrated line (ux). | |
| K94 | Expectation correction for MCP-034/IOS-111 (docs/mcp.md:62 promises no `Product:` line) AND add the same build/install summary line to `grantiva_run` for consistency with `grantiva_build`. | One-line change removes an inconsistency. |
| K101 | Bump the MCP Swift SDK if a release fixes the reply id/-32700 shape; otherwise add the transport wrapper the brief describes. | |
| K106 | Fix: record a run's temp directories in the lease claim; reclaim removes them. | ux; disk leak. |
| K10 | cli component as re-graded; runner wording stays. | |

## Expectation corrections (Task 12)

CLI-019 (doctor half), CLI-028, MCP-077, AND-OBS-04, IOS-102, MCP-034, IOS-111 → matrix rows corrected; B-C16.1, B-C16.3 → brief C16 corrected; B-I04.3 → brief I04 corrected. None of these changes product code.

## Review Focus

1. Every `--json` document from every command (run, runner start/stop, emulator delete, record, diff, doctor, teardown) uses camelCase keys, numbers for pids/ports, and the same shape pass or fail except for documented outcome fields. Task 4 (K16, K21-a/b, K30, K85, K103) adds the cross-command key-casing test.
2. `--quiet` and `--json` never leave runner narration on stdout or stderr; `--verbose` lists every subprocess the CLI starts. Task 4 (K19, K33).
3. A `runner start` or `run --keep-alive` session is stopped by `runner stop`, is gone after `simulator teardown`/`emulator teardown` of its device, and leaves no session file or lock behind; foreground `runner start` stays attached. Task 5 (K14, K15, K79, K87, K88, K107-a).
4. Maestro-format flows: inline `runFlow: {commands:}`, `extendedWaitUntil` with `timeout`, `scrollUntilVisible`, `clearState`, `launchApp` arguments, `swipe from:` behave per the README on both platforms and the step line names what was acted on. Tasks 1, 3, 4 (K01, K22, K74, K77, K109, K09, K105).
5. MCP: every tool returns `isError` on failure (never a JSON-RPC error), notifications get no reply, `resources/read` without a session is an `isError`-style resource error, and session captures share the `diff` JSON shape. Task 10 (K53, K55, K100, K101).

---

### Task 0: Setup

Run by the orchestrating session.

- [ ] **Step 1: Toolchains and bases.** `cd ~/Developer/maestro-runner && git fetch -q grantiva && git log --oneline -1 grantiva/main` (expect ae48e34) `&& go version`; `cd /Users/kyle/Developer/grantiva-cli && git fetch -q origin && git log --oneline -1 origin/main` (expect 51c597a) `&& swift --version | head -1`; `gh auth status`.
- [ ] **Step 2: Worktrees.** Runner: `git worktree add .worktrees/fix2-output -b fix2/output grantiva/main`, likewise `fix2-uia2` (`fix2/uia2`), `fix2-wda` (`fix2/wda`). CLI: `fix2-session-output` (`fix2/session-output`), `fix2-keepalive` (`fix2/keepalive`), `fix2-simulator` (`fix2/simulator`), `fix2-emulator` (`fix2/emulator`), `fix2-diff-record` (`fix2/diff-record`), `fix2-usage` (`fix2/usage`), `fix2-mcp` (`fix2/mcp`), `fix2-docs` (`fix2/docs`), `chore-bundle-runner-10` (`chore/bundle-runner-round2`) from `origin/main`.
- [ ] **Step 3: Ledger.** `bash <sdd-skill>/scripts/sdd-workspace docs/superpowers/plans/2026-10-11-round2-fix-wave.md`; copy the Rulings table into the ledger.

---

### Task 1: Runner — output and narration (K01, K03, K04, K05, K10 runner half none, K76-a, K77, K98, K110)

Worktree `~/Developer/maestro-runner/.worktrees/fix2-output`, branch `fix2/output`.

**Files:**
- Modify: `pkg/cli/test.go`, `pkg/cli/test_unified_output.go`, `pkg/flow/step.go`, `pkg/flow/flow_runner.go`, `pkg/core/selector.go`, `pkg/driver/android.go`, `pkg/driver/ios.go`, `pkg/runner/runner.go`, `pkg/cli/cli.go`; tests beside each.
- Read first: briefs K01, K03, K04, K05, K76-a, K77, K98, K110 (full text; the acceptance criteria are the test list).

- [ ] **Step 1: Failing tests.** One table-driven test per brief in the package named by its Suspected cause: step line carries `point:`, `index:` and the selector for tap/swipe/scroll steps (K01); the summary draws skipped steps with the skipped glyph and never `✗ … (0ms)` while "n steps skipped" is reported (K03); the device line says `Emulator` for Android and report.json `isSimulator` is false for an emulator (K04); the live step duration, the summary duration and report.json `duration` for a step are the same value (K05, including the failing-step case); the `⚠` glyph is reserved for warnings and a slow passed step gets a `(slow)` suffix or a distinct glyph with a legend line (K76-a); `clearState` and `launchApp clearState:` produce a step line (K77); a WDA cache hit narrates "Using cached GrantivaAgent for <runtime>" and never "Building" (K98); the runner log `Driver:` line names the resolved driver (K110).
- [ ] **Step 2: Run them.** `go test ./pkg/cli/... ./pkg/flow/... ./pkg/core/... ./pkg/driver/... ./pkg/runner/...` — each new test fails for the reason its brief describes.
- [ ] **Step 3: Fix** per the briefs' Suspected cause lines; keep the unified output's existing layout otherwise.
- [ ] **Step 4: Tests green** with the same package list; `golangci-lint run ./...`.
- [ ] **Step 5: PR.** Push `fix2/output` to `grantiva`; `gh pr create -R grantiva/runner` titled "Narrate selectors, skipped steps, devices and durations consistently"; body lists the briefs by ID with one line each. Review loop, squash-merge, verify `MERGED`.

---

### Task 2: Runner — UIAutomator2 robustness (K02, K06, K07, K08, K09, K75)

Worktree `.worktrees/fix2-uia2`, branch `fix2/uia2`. Depends on nothing; runs in parallel with Task 1.

**Files:**
- Modify: `pkg/driver/uiautomator2/commands.go`, `pkg/driver/uiautomator2/client.go`, `pkg/driver/uiautomator2/driver.go`, `pkg/core/gesture.go`, `pkg/driver/wda/commands.go` (swipe start rule, "for swipe" wording), `pkg/driver/wda/offscreen.go`; tests beside each.
- Read first: briefs K02, K06, K07, K08, K09 (with the ruling above), K75; evidence `findings/evidence/cov-android/{AND-228,N-03,N-06,B-R02.1,B-A02.2}/`.

- [ ] **Step 1: Failing tests.** `notVisible`/`assertNotVisible` failure text is the grantiva message ("Element still visible: <selector> after <t>") not the raw driver error, on both drivers (K02, K75 for the iOS "for swipe" wording); a connection-refused/EOF from the uia2 server mid-flow is retried with backoff up to the step timeout and surfaced as one message naming the retry count when it still fails (K06, fake server dropping the socket); a bare `scroll` moves by a fixed fraction of the scrollable area with a settle wait so four scrolls land on the same content twice in a row against a fake hierarchy (K07); the `notVisible` wait polls until the deadline and does not time out early when the element disappears within the window (K08, fake server removes the element at t+2 s); `SwipeCoordsToScreenEdge` starts at the element centre and ends at the edge margin on both drivers; pixels vs percentages unchanged (K09).
- [ ] **Step 2: Run them**, confirm each fails. `go test ./pkg/driver/uiautomator2/... ./pkg/driver/wda/... ./pkg/core/...`.
- [ ] **Step 3: Fix.**
- [ ] **Step 4: Device check.** `make build`; AVD `fix2-2-android` (API 35); with a scratch copy of landmarks-demo/android built and installed through the 2.1.0 QA binary pointed at the task's runner home (install the dev runner there with `grantiva runner install --from <tarball>` if the command supports it, otherwise run the flows through the dev runner directly): `.maestro/coverage/` flows for swipe (row opens 10 of 10, trace covers >50% of the width), `10-seed-many` scroll (Landmark 30 reached 5 of 5), the `notVisible` wait flow (5 of 5), and a fresh-boot `diff capture` (3 of 3 fresh boots). Save outputs to the PR body. Tear down.
- [ ] **Step 5: PR** "Make UIAutomator2 gestures and waits deterministic; start element swipes at the centre (K02, K06–K09, K75)". Review loop, squash-merge, verify.

---

### Task 3: Runner — WDA semantics and error classification (K74, K91, K97, K76-b)

Worktree `.worktrees/fix2-wda`, branch `fix2/wda`. Parallel with Tasks 1–2.

**Files:**
- Modify: `pkg/driver/wda/commands.go` (launch arguments, scrollUntilVisible loop), `pkg/driver/wda/alerts.go`, `pkg/driver/wda/driver.go`, `pkg/flow/convert.go`, `pkg/flow/errors.go`, `pkg/flow/wait_crash.go`; `CHANGELOG.md` (runner); tests.
- Read first: briefs K74 (ruling), K91 (ruling), K97, K76-b; evidence `findings/evidence/cov-ios/{IOS-077,IOS-151,N-14,IOS-224}/`.

- [ ] **Step 1: Failing tests.** `launchApp: arguments: [--flag]` sends `arguments` to WDA and leaves `environment` untouched unless `env:` is given (K74); when a wait ends because the app process died, `classifyError` returns `app_crash` before "not visible" and the WDA driver returns `ErrAppCrashed` when `/wda/apps/state` reports not running (K97); the alert auto-accept logs at Info and emits a step-level event the CLI can narrate (`accepted system alert "<label>"`) (K91); `scrollUntilVisible` on WDA uses one find per scroll with a short settle instead of a 1 s miss timeout plus screenshots, so a 10-scroll search against a fake WDA finishes under 5 s (K76-b).
- [ ] **Step 2: Run, confirm failures.** `go test ./pkg/driver/wda/... ./pkg/flow/...`.
- [ ] **Step 3: Fix.** Add the CHANGELOG line for K74 ("launch arguments are no longer mirrored into the app environment; use `env:`").
- [ ] **Step 4: Device check** on `fix2-3-ios` (iPhone 17, 26.0): `99-crash` reports `error.type: app_crash`; `21-system-alert-maps` narrates the accepted alert; `IOS-077` repro shows `--flag` in arguments and not in the environment; the `scrollUntilVisible` coverage flow completes in under 10 s per search. Save to the PR. Tear down.
- [ ] **Step 5: PR** "Classify crashes during waits, narrate accepted alerts, stop mirroring launch arguments (K74, K76-b, K91, K97)". Review loop, squash-merge, verify.

---

### Task 4: CLI — runner session output and flow staging (K10, K11, K12, K13, K17, K18, K19, K20, K21-a, K21-b, K22, K23-a, K23-b, K24, K44, K80, K81, K82-a, K83, K90-a, K90-b, K93, K103, K105, K109)

Worktree `/Users/kyle/Developer/grantiva-cli/.worktrees/fix2-session-output`, branch `fix2/session-output`. The largest CLI task; split the commits by brief group (output, JSON, staging) so the reviewer can follow.

**Files:**
- Modify: `Sources/GrantivaCore/Runner/RunnerSession.swift`, `RunnerExecution.swift`, `RunnerArtifactCollector.swift`, `RunnerFailureReport.swift`, `RunnerReportRewriter.swift`, `Sources/GrantivaCore/Flows/FlowGenerator.swift`, `FlowReferenceResolver.swift`, `MaestroFlowParser.swift`, `Sources/GrantivaCore/Config/GrantivaConfig.swift`, `Sources/GrantivaCore/Target/TargetOptions.swift`, `Sources/GrantivaCore/Project/ProjectResolver.swift`, `Sources/GrantivaCLI/Commands/RunCommand.swift`, `CICommand.swift`, `Sources/GrantivaCore/Errors/GrantivaError.swift`, `Sources/GrantivaCore/Output/*.swift`; `README.md` lines the briefs cite (K21-a passing document, K23-b caveat); tests in `Tests/GrantivaCoreTests/` and `Tests/GrantivaCLITests/`.
- Read first: every brief listed in the title; `00-cluster-map.md` entries C10–C24 for the shared causes.

**Interfaces:**
- Produces: `JSONOutput.encoder` with `.convertToCamelCase`-free guarantee enforced by a test that decodes every command's JSON fixture and asserts all keys match `^[a-z][A-Za-z0-9]*$` (K103) — Tasks 5–9 add their fixtures to this test.
- Produces: `RunnerSession.narrate(_:)` becomes the single choke point for runner stderr so `--quiet`/`--json` suppress it (K19); Task 5's `runner start` reuses it.

- [ ] **Step 1: Failing tests (output group).** Timeout kill is reported as "Timed out after <t>s" without the runner's "Received interrupt" tail (K10); Android narration says "GrantivaAgent" nowhere and "Booting" only when a boot happens (K11, K12); "Running N flows" counts flows only (K13); `--quiet` leaves zero runner lines and `--json` leaves stdout JSON-only with runner text absent or on stderr per the README (K19); `Reports:` is printed only for a directory that survives the run (K18); screens-mode failure names the screen and the message has no trailing colon (K20); failure lines carry the selector and the hierarchy hint (K93); `wait:` in screens flows narrates as `wait` (K90-a) and no staged temp path appears in output (K90-b, K105).
- [ ] **Step 2: Failing tests (JSON group).** `run --json` on pass carries `reportDir` and `screens[]` with the same shape as on failure (K21-a/b); capture step durations are real (K17); report.json ends `passed|failed`, never `running`, after a timeout (K80); `--snapshot trailing` keeps only the trailing N steps' shots (K81); trace shots are not counted as screens (K82-a); the cross-command camelCase key test (K103) over fixtures for run, runner start/stop, record, diff, doctor, teardown, emulator delete.
- [ ] **Step 3: Failing tests (staging group).** Inline `runFlow: {commands: [...]}` is staged and runs (K22); a sub-flow `takeScreenshot` produces a capture (K83); `extendedWaitUntil` with `timeout` keeps the timeout and `scrollUntilVisible` stays a scroll (K109, replace the test that locks the drop); Maestro-format `grantiva-android.yml` parses and screens accept `{id:}` on Android (K24); a flow `appId:` header is honoured on Android without a config (K23-a); with `--no-build` and no resolvable app ID the CLI prints the hint and README says detection runs only when building (K23-b); a missing flow file fails before any device work (K44).
- [ ] **Step 4: Run** `swift test --filter GrantivaCoreTests` and `--filter GrantivaCLITests`; each new test fails as its brief predicts.
- [ ] **Step 5: Fix** group by group, committing after each group's tests pass.
- [ ] **Step 6: Device check** on `fix2-4-ios` and `fix2-4-android`: the coverage flows named by K22, K83, K109, K24 and K23-a pass; `run --json` pass/fail documents validated with `jq` against the acceptance criteria; `--quiet` prints nothing from the runner. Save to the PR. Tear down.
- [ ] **Step 7: PR** "Make run output, JSON documents and flow staging match the README (K10–K24, K44, K80–K83, K90, K93, K103, K105, K109)". Review loop, squash-merge, verify.

---

### Task 5: CLI — keep-alive sessions and runner commands (K14, K15, K16, K33, K45, K46, K47, K61, K79, K87, K88, K99, K104)

Worktree `.worktrees/fix2-keepalive`, branch `fix2/keepalive`. Parallel with Task 4; rebase on `origin/main` after Task 4 merges and re-run tests before the review loop ends.

**Files:**
- Modify: `Sources/GrantivaCLI/Commands/DriverCommand.swift` (runner start/stop/install/dump-hierarchy), `HierarchyCommand.swift`, `EmulatorCommand.swift` (teardown stops the device's runner), `Sources/GrantivaCore/Runner/KeepAliveSessionStore.swift`, `RunnerSessionInfo.swift`, `RunnerManager.swift`, `ChildProcess.swift`, `LogStreamer.swift`, `Sources/GrantivaCore/Platform/IOSPlatform.swift`, `Sources/GrantivaMCP/MCPServer.swift` (no-session text), `Sources/GrantivaCore/Options.swift` (help wording); tests.
- Read first: the briefs in the title; the ruling on K10 is not here but K46's one-prefix rule is shared with Task 10 (K46 owns the CLI texts; Task 10 owns the MCP texts).

- [ ] **Step 1: Failing tests.** `runner stop` finds a `run --keep-alive` session (the session file is written by both entry points) and exits non-zero when nothing to stop (K14); `emulator teardown`/`simulator teardown` of a device stops its runner session and removes its session file (K15); `runner start --json`/`runner stop --json` emit numbers for pid/port and platform-neutral keys (K16); `--verbose` logs every long-running subprocess the CLI starts (runner, `log stream`, logcat, recorder) with its command line (K33); "Extracting runner" prints only when extraction happens (K45); the no-session error uses the one `Error:` prefix with the remediation line and never says "Invalid argument" (K46); `runner dump-hierarchy --format bogus` is rejected before any session lookup (K47); help text names UIAutomator2 beside WDA on every both-platform page and `--timeout`/`--port` descriptions are platform-neutral (K61, from the 172-page corpus list in the brief); killing the keep-alive CLI process also ends the runner (process group) (K79); `runner stop` removes the session file after SIGKILL escalation too (K87); foreground `runner start` stays attached until SIGINT and streams the runner log (K88); `hierarchy --format json` returns the unwrapped tree like the XML path (K99); stored `projectDirectory` keeps `/private` and session matching uses a canonical comparison (K104).
- [ ] **Step 2: Run**, confirm failures.
- [ ] **Step 3: Fix.**
- [ ] **Step 4: Device check** on `fix2-5-ios`: `runner start --detach` → `runner stop` leaves `/tmp/grantiva-sessions` empty; `run --keep-alive` then `runner stop` stops it; foreground `runner start` runs for 30 s and exits on SIGINT; `simulator teardown` of the device while a session runs stops it. Save to the PR. Tear down.
- [ ] **Step 5: PR** "Stop every keep-alive session, keep foreground runner start attached, neutral help wording (K14–K16, K33, K45–K47, K61, K79, K87, K88, K99, K104)". Review loop, squash-merge, verify.

---

### Task 6: CLI — simulator lifecycle (K36, K37, K67, K68, K69, K70, K86-a, K86-b, K106, K107-a, K107-b)

Worktree `.worktrees/fix2-simulator`, branch `fix2/simulator`. Parallel with Tasks 4–5.

**Files:**
- Modify: `Sources/GrantivaCore/Simulator/SimulatorManager.swift`, `SimulatorCapacity.swift`, `SimulatorLease.swift`, `SimulatorReaper.swift`, `WDADeviceHome.swift`, `Sources/GrantivaCore/Project/ProjectResolver.swift` and the four other "iPhone 16" sites named in K37, `Sources/GrantivaCLI/Commands/DoctorRunner.swift`, `DiffCommand.swift` (capture through a live session, K86-b), `Tests/GrantivaCoreTests/RunnerSessionReportTests.swift`, `RunnerSessionCleanupTests.swift` (K107-b), `README.md` "Reclaiming a simulator" and the session-device paragraph (K70); tests.
- Read first: the briefs; the K86-b ruling.

- [ ] **Step 1: Failing tests.** Concurrent `simulator ensure` for the same name boots once and the second caller waits on a fresh device snapshot (K67); `teardown` reports `reclaimed: true` only when a process or lease was actually reclaimed (K68); `teardown` without `--force` removes the device home when the device is idle (K69); a device held by a session gives a message that names the session kind and the command that releases it (`runner stop` vs `teardown --force`) (K86-a); `diff capture --no-build --simulator <held>` captures through the live session (K86-b, fake session); `release()` deletes the lock file and cleanup of a deleted simulator does not create one (K107-a); the two test suites take leases under a temp root and leave `~/.grantiva/runner/locks` untouched (K107-b: assert the real locks directory count is unchanged before/after); reclaim removes the killed run's temp dirs recorded in the lease claim (K106); the default simulator name is derived once (newest installed iPhone) and shared by init, doctor, driver, MCP schemas (K37); doctor's "booted simulator" check matches on UDID not name (K36); README: a session-owned device can be used by `run` through the session or the message says how to release it (K70).
- [ ] **Step 2: Run**, confirm failures; also confirm the K107-b pre-fix assertion fails (locks are written).
- [ ] **Step 3: Fix.** Also delete the 675 stale `TEST-REPORT-*`/`FAKE-*`/`AAAA-1111` lock files only from the task's scratch runner home, never from `~/.grantiva/runner` (the owner's home is cleaned by the owner; the brief records the count).
- [ ] **Step 4: Device check** on `fix2-6-ios`: two concurrent `simulator ensure --name fix2-6-ios` calls; `runner start --detach` then `diff capture --no-build --simulator <udid>` succeeds; teardown leaves no lock, no device home. Save to the PR. Tear down.
- [ ] **Step 5: PR** "Simulator leases: release locks, capture through live sessions, honest teardown (K36, K37, K67–K70, K86, K106, K107)". Review loop, squash-merge, verify.

---

### Task 7: CLI — emulator and Android build (K25, K26, K27, K28, K29, K30, K31, K32)

Worktree `.worktrees/fix2-emulator`, branch `fix2/emulator`. Parallel with Tasks 4–6.

**Files:**
- Modify: `Sources/GrantivaCore/Emulator/EmulatorManager.swift`, `Sources/GrantivaCLI/Commands/EmulatorCommand.swift`, `BuildCommand.swift`, `Sources/GrantivaCore/Android/ADB.swift`, `AndroidProject.swift`, `Sources/GrantivaCore/Shell.swift`, `Sources/GrantivaCore/Output/JSONOutput.swift`, `docs/android.md` (K27 headless rule); tests.
- Read first: the briefs; the K32 ruling.

- [ ] **Step 1: Failing tests.** `--no-build --app-file <apk>` installs the file and the narration says so, never "installed" for a skipped install (K25); the install warning says "installing" not "testing … paid" (K26); headless is implied only by `--headless` or a documented env var, not by a non-TTY stdout, and docs/android.md states the rule (K27); refused teardown still prunes the created-AVD ledger of AVDs that no longer exist (K28); `ensure --no-boot` reports a running AVD as running (K29); `emulator delete --json` is pretty-printed like its siblings (K30); a non-zero `sdkmanager` exit or an "Failed to find package" line fails `ensure` with the package name (K31); `build install` never launches an app it did not install and adb/monkey stderr is captured, not echoed (K32).
- [ ] **Step 2: Run**, confirm failures.
- [ ] **Step 3: Fix.**
- [ ] **Step 4: Device check** on `fix2-7-android`: `build install --no-build --app-file <apk>` installs and launches; `ensure --no-boot` on the running AVD; `emulator delete --json` output; a failing `sdkmanager` (bogus package) message. Save to the PR. Tear down.
- [ ] **Step 5: PR** "Emulator ensure/teardown bookkeeping and Android install narration (K25–K32)". Review loop, squash-merge, verify.

---

### Task 8: CLI — diff and record (K34-a, K34-b, K49, K51, K55, K82-b, K84, K85, K89, K108)

Worktree `.worktrees/fix2-diff-record`, branch `fix2/diff-record`. Parallel with Tasks 4–7.

**Files:**
- Modify: `Sources/GrantivaCLI/Commands/DiffCommand.swift`, `RecordCommand.swift`, `CICommand.swift`, `RunCommand.swift` (captures directory separation, K82-b), `Sources/GrantivaCore/Record/MP4LastFrameHold.swift`, `Sources/GrantivaCore/Diff/*`, `Sources/GrantivaMCP/Tools/SessionCapture.swift` (shared JSON shape, K55), `Sources/GrantivaCore/Output/TableOutput.swift`; `docs/android.md:119-123` if the held-frame rule changes; tests.
- Read first: the briefs; the K34-b and K51 rulings.

- [ ] **Step 1: Failing tests.** Held-frame note reports the frame's start time (K34-a) and `record --verbose` prints held-frame statistics; the note prints whenever the documented condition holds (K34-b); `diff approve` for a missing screen prints a clean message (K49); a failing `diff compare` creates no directories and `diff approve` is verified either way (K51); session-capture JSON and `diff capture --json` share one shape including the device object (K55); `run` writes trace/failure shots to `.grantiva/run-captures/` (or an equivalent documented directory) so `diff approve`/`compare` never see them (K82-b); `record --frame-at` past the duration is rejected before recording (K84); `record --json` paths are all absolute (K85); `diff compare` with no baselines fails with "No baselines; run diff approve" and exit 1 (K89); diff failure lines name the threshold exceeded (K108).
- [ ] **Step 2: Run**, confirm failures.
- [ ] **Step 3: Fix.**
- [ ] **Step 4: Device check** on `fix2-8-ios`: a failing `run` followed by `diff capture` and `diff approve` approves only real screens (listing before/after); `diff compare` with no baselines exits 1; `record --duration 4` on a static screen prints the note 10 of 10 or the verbose statistics explain each miss. Save to the PR. Tear down.
- [ ] **Step 5: PR** "Keep run artefacts out of visual baselines; honest compare and record output (K34, K49, K51, K55, K82-b, K84, K85, K89, K108)". Review loop, squash-merge, verify.

---

### Task 9: CLI — usage errors, doctor, init, misc (K35, K38, K39, K40, K41, K42, K43, K48, K50, K52, K71, K72, K73)

Worktree `.worktrees/fix2-usage`, branch `fix2/usage`. Parallel with Tasks 4–8.

**Files:**
- Modify: `Sources/GrantivaCLI/Commands/DoctorCommand.swift`, `DoctorRunner.swift`, `DoctorFormatter.swift`, `DoctorCheck.swift`, `InitCommand.swift`, `RunCommand.swift` (ready file, `--timeout`, `--snapshot`), `HierarchyCommand.swift`, `SimulatorCommand.swift`, `DriverCommand.swift`, `EmulatorCommand.swift`, `RecordCommand.swift`, `ConsoleReleasesCommand.swift`, `GrantivaCommand.swift`, `BuildCommand.swift`, `XcodeBuildRunner.swift`, `Sources/GrantivaCore/Project/ProjectResolver.swift`, `ProjectDetector.swift`, `Sources/GrantivaCore/Runner/RunnerManager.swift`, `Sources/GrantivaCore/Errors/GrantivaError.swift`, `Sources/GrantivaCore/Platform/DevicePlatform.swift`; tests.
- Read first: the briefs; the K48 ruling.

- [ ] **Step 1: Failing tests.** Advisory toolchain checks print under an "Advisory" heading with `section: "Advisory"` in JSON and the summary counts agree (K35); `init` with two schemes asks or fails naming both, never silently picks (K38); the ready file after an early failure has `error` and no `reportDir` for a directory that does not exist (K39); `--snapshot bogus` lists the valid values like `--platform` does (K40); `--timeout -1` reports an invalid value, not a missing one (K41); every usage error uses the plain `Error:` prefix and exit 64, never `Invalid argument:` (K42); platform-flag rejections say which flag applies to which platform (K43); a stale install reports both versions and leaves no empty directory; README wording for the existing-install case (K48); `console releases update --version` works (option renamed in help only via an alias, the inherited flag still prints the version) (K50); run vs capture missing-config wording agree (K52); the no-scheme message names `--scheme`, not `--app-file` (K71); a cached scheme is dropped when the project now has two (K72); a bundle-id mismatch at install is a clean grantiva message (K73).
- [ ] **Step 2: Run**, confirm failures.
- [ ] **Step 3: Fix.**
- [ ] **Step 4: No device check needed**; run the CLI against fixture projects in `Tests/Fixtures`.
- [ ] **Step 5: PR** "Consistent usage errors, doctor sections and init scheme handling (K35, K38–K43, K48, K50, K52, K71–K73)". Review loop, squash-merge, verify.

---

### Task 10: CLI — MCP server (K53, K54, K56, K57, K58, K59, K60, K78, K92, K94, K95, K96, K100, K101, K102)

Worktree `.worktrees/fix2-mcp`, branch `fix2/mcp`. Parallel with Tasks 4–9; rebase after Task 5 merges (shared `MCPServer.swift` no-session text).

**Files:**
- Modify: `Sources/GrantivaMCP/MCPServer.swift`, `ToolRegistry.swift`, `Tools/BuildTools.swift`, `EmulatorTools.swift`, `SimTools.swift`, `ContextTool.swift`, `VRTTools.swift`, `ScriptTools.swift`, `UITools.swift`, `Sources/GrantivaCore/Drivers/WDAClient.swift`, `UIAutomator2Client.swift`, `Sources/GrantivaCore/Runner/KeepAliveSessionStore.swift` (app ID field, K56), `Package.swift` (SDK bump if K101 ruling applies), `docs/mcp.md`; tests in `Tests/GrantivaMCPTests/`.
- Read first: the briefs; rulings K53, K58, K60, K78, K94, K101.

- [ ] **Step 1: Failing tests.** Every tool failure (build, emulator_boot, emulator_delete refusals, vrt tools, sim tools, no-config) is an `isError` result and never a JSON-RPC error; the delete refusal names the `force` argument (K53, K59); `grantiva_build` never boots an AVD (K54); keep-alive sessions record the app ID and `grantiva_context` shows `driver_port` and the app ID (K56); `resources/updated` is sent only when the hierarchy changed and only to subscribers (K57); the context names its config source and never uses another platform's project (K58); VRT tools spawn with an argument array (K60); `tap` label matching: label first, then name/identifier fallback, and a text field reachable by its accessibility label (K78 with IOS-OBS-06); a missing element right after startup is "Element not found", never "Network error (400)" (K92: retry the WDA session once on 400 invalid-session); `grantiva_run` prints the build/install summary line (K94); `grantiva_run` without a config detects the project and bundle ID like the CLI (K95); `sim_list` carries `available` and the runtime in the documented format (K96); `resources/read` without a session returns a resource error payload, not -32603 (K100); a notification without `jsonrpc` gets no reply, a malformed request gets `-32600` with the request id (K101); `type` with no focused field returns `isError` "No focused text field" on both drivers (K102).
- [ ] **Step 2: Run** `swift test --filter GrantivaMCPTests`, confirm failures.
- [ ] **Step 3: Fix.** Update docs/mcp.md: isError for all tools, tap matching order, `grantiva_run` summary, `sim_list` columns.
- [ ] **Step 4: Device check** on `fix2-10-ios` (and `fix2-10-android` for emulator tool errors and `type` without focus): the JSON-RPC transcripts from the briefs' Repro sections, all answers `isError` or results. Save to the PR. Tear down.
- [ ] **Step 5: PR** "MCP: isError everywhere, honest context, tap matching order, no 400s after startup (K53–K60, K78, K92, K94–K96, K100–K102)". Review loop, squash-merge, verify.

---

### Task 11: CLI — docs (K62, K63, K64, K65, K66, plus README lines owned by Tasks 4–10 that were deferred)

Worktree `.worktrees/fix2-docs`, branch `fix2/docs`, created after Tasks 4–10 merge (rebased on `origin/main`).

**Files:**
- Modify: `README.md` (doctor jq filter K62; runner home path naming K63; "From source" copies the bundle K66), `SIMULATOR-LIFECYCLE.md` (K64: drop stale version claims and internal notes or delete the file and point to docs), `docs/dump-hierarchy.md:55` (K65: WDA runtimes 26.0, 26.2, 26.4, 27.0), `docs/android.md` and `docs/mcp.md` consistency pass against the merged behaviour; `Tests/GrantivaCLITests/HelpCorpusTests.swift` (new: every `--help` page mentions the platform-neutral wording from K61 — regenerate `findings/help/` on `coverage-campaign` in Task 13 to compare).
- [ ] **Step 1: Failing test.** A test that greps README for the doctor filter and asserts it uses `select(.status == "error")` (or whatever K62 settles) and that `docs/dump-hierarchy.md` lists the four runtimes.
- [ ] **Step 2: Fix docs.** Read each merged PR's body for README lines promised but deferred; apply them.
- [ ] **Step 3: PR** "Docs: doctor filter, runner home naming, from-source bundle, WDA runtimes, lifecycle note (K62–K66)". Review loop, squash-merge, verify.

---

### Task 12: Matrix and brief corrections (on `coverage-campaign`)

Run by the orchestrating session in `.worktrees/regression`.

**Files:**
- Modify: `docs/superpowers/plans/2026-10-11-round1-coverage-matrix.md` rows CLI-019 (doctor half: exit 1 with the array on stdout, no `Error:` line), CLI-028 ("No flow files found in <dir>/.maestro" when the config is absent and `.maestro/` is empty; the K52 wording rule applies), MCP-077 (argument names as the live-session rows recorded), AND-OBS-04 (closed: misattribution, see K32), IOS-102 (label first, fallback to name/identifier per brief I05 and K78), MCP-034 and IOS-111 (expect the build/install/launch summary line per K94); the exported QA briefs C16 and I04 live at `~/.grantiva-qa/briefs/docs/superpowers/plans/2026-10-09-qa-issues/` — append a "Correction (round 1 coverage)" section to each explaining the server-side webhook validation and #183's flag removal; add `docs/superpowers/plans/2026-10-11-coverage-issues/00-expectation-corrections.md` listing all nine.
- [ ] **Step 1:** Edit the rows; keep the row IDs; add `(corrected round 2)` to the expected column.
- [ ] **Step 2:** Commit "Correct round-1 matrix and brief expectations (CLI-019, CLI-028, MCP-077, AND-OBS-04, IOS-102, MCP-034, IOS-111; briefs C16, I04)"; push `coverage-campaign`.

---

### Task 13: Repack the runner and bundle it

Runner `grantiva/main` after Tasks 1–3 merge; CLI worktree `.worktrees/chore-bundle-runner-10`, branch `chore/bundle-runner-round2`, rebased on `origin/main` after Tasks 4–11 merge.

**Files:**
- Modify: `Sources/GrantivaCore/Resources/grantiva-runner-{arm64,amd64}.tar.gz`, `Sources/GrantivaCore/Runner/RunnerManager.swift` (`runnerVersion` → `1.1.28-grantiva.10`), `Tests/GrantivaCoreTests/RunnerManagerTests.swift` stamp expectations, `docs/dump-hierarchy.md` version line if it names the runner version.

- [ ] **Step 1: WDA caches.** In `~/Developer/maestro-runner` on `grantiva/main`: `make build`; run one flow against simulators `fix2-13-ios-26` (26.0), `fix2-13-ios-262` (26.2), `fix2-13-ios-264` (26.4), `fix2-13-ios-27` (27.0) through the dev runner with the task's runner home so `cache/wda-builds/sim-ios<rt>-iphone-wda16.12.8-r1` (or `-r2` if the vendored WDA changed in Task 3; the revision comes from `bundledWDARevision`) exist for all four; tear the simulators down.
- [ ] **Step 2: Build.** `scripts/build-runner.sh --version 1.1.28-grantiva.10 --wda-cache <task runner home> --cli /Users/kyle/Developer/grantiva-cli/.worktrees/chore-bundle-runner-10`; confirm the tarballs contain `grantiva-runner --version` = `1.1.28-grantiva.10` and the four caches.
- [ ] **Step 3: Tests.** `swift test --filter RunnerManagerTests`; fix the stamp expectation to `1.1.28-grantiva.10+android-drivers-2`.
- [ ] **Step 4: PR** "Bundle runner 1.1.28-grantiva.10 (round 2 fix wave)" with the runner PR list in the body. Review loop, squash-merge, verify.

---

### Task 14: Release binary and smoke

Run by the orchestrating session from `main` after Task 13 merges.

- [ ] **Step 1: Build.** `cd /Users/kyle/Developer/grantiva-cli && git pull -q && swift build -c release`; copy `.build/release/grantiva` AND `.build/release/grantiva_GrantivaCore.bundle` to `~/.grantiva-qa/bin/` (the bundle must sit beside the binary or `runner install` silently uses a stale bundle).
- [ ] **Step 2: Upgrade the QA runner home.** `GRANTIVA_RUNNER_HOME=~/.grantiva-qa/runner ~/.grantiva-qa/bin/grantiva runner install`; confirm `versions/1.1.28-grantiva.10+android-drivers-2/grantiva-runner --version` and the four caches; `runner --json` lists the new stamp.
- [ ] **Step 3: Smoke.** Re-run `docs/superpowers/plans/2026-10-10-round1-fix-wave.md` Task 9's smoke (stock 12 + screens + 99-crash on `smoke2-ios` 26.0 and `smoke2-android`), plus one flow each for K09 (swipe), K22 (inline runFlow), K109 (extendedWaitUntil timeout), K74 (launch arguments), and the MCP isError transcript from K53; record to `findings/round2-smoke.md` + `findings/evidence/round2-smoke/` on `coverage-campaign`; commit and push. Tear down.
- [ ] **Step 4: Regenerate the help corpus** into `findings/help/` (same script as round 1) and commit.

---

### Task 15: Round 2 coverage pass

Run by the orchestrating session.

- [ ] **Step 1: Clone the plan.** Copy `docs/superpowers/plans/2026-10-11-round1-coverage-pass.md` to `docs/superpowers/plans/<date>-round2-coverage-pass.md`; update: binary/runner versions (2.1.0 at the new `main`, runner 1.1.28-grantiva.10), the matrix corrections from Task 12, device names `cov2-ios-1`, `cov2-ios-2`, `cov2-android`, session IDs `cov2-<slice>`, evidence dirs `findings/evidence/cov2-<slice>/`, results files `findings/cov2-<slice>-results.md`, branches `cov2/<slice>`; add rows for K111+ findings if any were filed during the wave; carry the Task 6 triage shape unchanged. Task 2 (demo flows) is skipped unless a brief added a flow.
- [ ] **Step 2: Execute it** with subagent-driven-development (Tasks 0, 1 matrix delta, 3–6), including the review loops the round-1 pass used (every doubtful `pass` is a `fail`).
- [ ] **Step 3: Verdict.** `ROUND 2: CLEAN` ends the campaign (release remains the owner's call); otherwise write `<date>-round3-fix-wave.md` from the new briefs and repeat.
