# Round 4 Fix Wave Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all 22 open findings from the round-3 campaign—retained L51, L53, L61 and L62 plus L64–L81—merge reviewed PRs in the runner and CLI repositories, bundle the next runner build, produce a fresh release candidate, and verify every acceptance criterion in the round-4 coverage pass.

**Architecture:** Five behavior PRs keep ownership clear: three runner PRs cover Android crash/capture, gestures/lifecycle, and optional-report/device-argument semantics; two CLI PRs cover lifecycle/output/path rewriting and MCP/WDA behavior. A sixth CLI PR owns public diagnostics and documentation after the behavior PRs merge. The runner is then repacked and bundled into the CLI, followed by a bounded two-platform smoke and a full round-4 coverage pass. Round-3 device execution is complete at 467/467 Android and 478/478 iOS; the final report can add citations but cannot remove or defer any of the 22 mapped briefs.

**Tech Stack:** Go language level 1.26.0 with pinned toolchain 1.26.7 for grantiva-runner (`go test` with explicit package lists and `go vet`); Swift tools 6.1 package for grantiva-cli (`swift test`, `swift build -c release`); MCP JSON-RPC over stdio; Xcode 27.0 with WDA caches for iOS 26.0, 26.2, 26.4 and 27.0; Android SDK 35; GitHub CLI review and squash merge workflow.

**Spec:** `docs/superpowers/specs/2026-10-10-full-coverage-campaign-design.md`. Binding inputs are `docs/superpowers/plans/2026-10-13-coverage-issues-round3/L64-*.md` through `L81-*.md`, retained round-2 briefs `L51`, `L53`, `L61`, `L62`, `2026-10-13-round3-coverage-matrix.md`, `00-expectation-corrections-round3.md`, and the final round-3 report when written. Initial source provenance is CLI `8f2cff67` and runner `fd9d8e8`; each implementation task records the actual merged base SHA before editing.

## Global Constraints

- Repositories: runner `/Users/kyle/Developer/maestro-runner` using only `grantiva/main`; CLI `/Users/kyle/Developer/grantiva-cli` using `origin/main`; demo `/Users/kyle/Developer/landmarks-demo` only if L62 isolation proves a demo defect. Never mention or push unrelated remotes.
- Every finding is fixed regardless of severity. No brief is deferred. A task may move a fix between the named runner/CLI PRs only after recording the proven ownership and preserving the coverage map below.
- Every behavior change begins with a failing semantic test against production code, then the smallest fix, focused tests, package/suite tests, review, CI, and squash merge. Runner commands use explicit package lists, never bare `go test ./...`.
- Preserve public command names, flags, MCP tool names and existing JSON keys. New JSON keys use camelCase and are covered by `JSONKeyCasingContractTests`. Errors follow the existing single-prefix contract.
- Device work is limited to the task's explicitly created `fix4-*` simulator or AVD. Never touch owner devices, use global teardown, kill by pattern, or reuse the default runner home. Each task records created device IDs, process IDs and cleanup evidence.
- Release/device runner home: before Task 8 QA verification, create a fresh APFS clone of the owner's `~/.grantiva/runner`, point `GRANTIVA_RUNNER_HOME` at that clone, and exercise the in-place upgrade to the newly bundled runner. Earlier task-specific device regressions use their own scoped homes and do not claim the release upgrade check. `GRANTIVA_API_KEY` stays unset and `GRANTIVA_SESSION_ID` is the ledger's literal `fix4-` task ID. Unit tests independently use a fresh empty runner home and must leave it empty; the empty test home never substitutes for the required cloned upgrade-path check.
- Evidence under `findings/evidence/cov3-*` is read-only. New fix-wave evidence goes under the ledger-recorded `findings/evidence/fix4-*` task directory. Raw captures remain byte-for-byte unchanged.
- The controller maintains `findings/ledgers/2026-10-13-round4-fix-wave-ledger.md`, campaign handoff, PR SHA, review status and device cleanup after every task.
- The final round-3 report appends the completed measurements and exact citations. It may tighten a test threshold only when the binding criterion already names that threshold; it cannot create an unreviewed requirement or erase an observed failure.

## Review Focus

1. Large concurrent MCP responses remain one valid JSON object per line even when writes exceed 64 KiB; every response ID arrives exactly once, completion order is unconstrained, and notifications plus small responses remain intact. Task 5 tests this with partial writes and ten concurrent repetitions.
2. Lifecycle cancellation is truthful at every phase: startup SIGINT reports interrupted, detached Android readiness includes the launched app, force teardown reports a stopped runner, and logging children are absent when `run` returns. Task 4 owns all four boundaries.
3. Android gesture and app-state fixes remain deterministic under load: every non-ADB swipe uses held actions, bare stopApp verifies termination, and the favorite action removes the row 5/5 without accepting a stale revealed target. Task 2 owns these tests.
4. Optional failures agree across runner report, CLI text/JSON/JUnit and exit status while required failures remain failures. Task 3 exercises both branches through production report files.
5. Public diagnostics and compatibility documentation are complete: doctor exposes default-name ownership even when another simulator is booted; baseline filename migration, ISO-8601 dates, selector priority, lifecycle JSON and release notes are public and tested for exact phrases. Task 6 owns these checks.

---

### Task 0: Freeze inputs, create worktrees and ledger

**Files:**
- Create: `findings/ledgers/2026-10-13-round4-fix-wave-ledger.md`
- Modify: `docs/superpowers/plans/2026-10-12-campaign-handoff.md`

**Interfaces:**
- Consumes: the 22 briefs and final round-3 report measurements.
- Produces: immutable base SHAs, task branches, PR ownership and acceptance checklist used by Tasks 1–9.

- [x] **Step 1: Record bases.** Run `git fetch -q grantiva && git rev-parse grantiva/main` in the runner and `git fetch -q origin && git rev-parse origin/main` in the CLI. Record both SHAs; verify the initial candidate ancestry includes runner `fd9d8e8` and CLI `8f2cff67`.
- [ ] **Step 2: Create worktrees.** Runner branches: `fix4/crash-capture`, `fix4/gestures-lifecycle`, and `fix4/optional-device`; CLI branches: `fix4/lifecycle-output`, `fix4/mcp-wda`, `fix4/public-docs`, and later `chore/bundle-runner-round4`, each from the then-current default branch.
- [x] **Step 3: Create the ledger.** Add one line for each of L51, L53, L61, L62 and L64–L81 with owner task, failing test, implementation commit, device evidence, PR, CI and merge SHA columns. Mark no row complete until its brief acceptance criteria are all checked.
- [x] **Step 4: Reconcile final measurements.** Read the completed round-3 report, append exact remaining L51/L38 evidence references to the ledger, and keep all 22 findings mapped even if an additive run passes.
- [x] **Step 5: Commit campaign metadata.** Commit only the plan, ledger and handoff update on the campaign branch.

### Task 1: Runner crash decision and bounded failure artifacts (L61, L64)

Worktree `maestro-runner/.worktrees/fix4-crash-capture`, branch `fix4/crash-capture`.

**Files:**
- Modify: `pkg/driver/uiautomator2/{commands.go,driver.go,wait_crash.go,launch_crash_after_draw_test.go,launch_timing_test.go}`
- Modify: `pkg/executor/flow_runner.go`, `pkg/executor/runner_test.go`
- Modify: `pkg/report/flow.go` and its existing tests only if a new artifact-specific note field is required; the collection implementation remains in `pkg/executor/flow_runner.go`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: UIAutomator2 crash observations and the existing report artifact writer.
- Produces: one launch decision that cannot ignore a fatal observed before return, plus independently bounded failure artifact collectors.

**Concrete regression shape:** Extend the existing fake-shell cases rather than introducing a second launch implementation. Add package-private context-aware artifact methods and a fake that blocks until its context is cancelled; never use `select {}` or leave a timed-out collector running:

```go
func (d *blockingArtifacts) FailureScreenshot(ctx context.Context) ([]byte, error) {
    d.started <- "screenshot"
    <-ctx.Done()
    d.finished <- "screenshot"
    return nil, ctx.Err()
}
func (d *blockingArtifacts) FailureHierarchy(ctx context.Context) ([]byte, error) {
    d.started <- "hierarchy"
    return []byte("<hierarchy/>"), nil
}

before := runtime.NumGoroutine()
for i := 0; i < 25; i++ { runOneFailedStep(t, d) }
if elapsed := time.Since(began); elapsed > 25*2250*time.Millisecond { t.Fatalf("captures took %s", elapsed) }
if got := <-d.finished; got != "screenshot" { t.Fatalf("collector never stopped: %q", got) }
runtime.GC()
if after := runtime.NumGoroutine(); after > before+8 { t.Fatalf("goroutines grew %d -> %d", before, after) }
```

- [x] **Step 1: Write failing L64 tests.** Extend `launch_crash_after_draw_test.go` with a deterministic fake where a frame is observed, then a matching PID fatal arrives between the last status read and success return. Assert `app_crash`; add healthy and post-return-crash siblings.
- [x] **Step 2: Write failing L61 tests.** Extend `pkg/executor/duration_consistency_test.go` around `FlowRunner.captureArtifacts`: use package-private context-aware screenshot, hierarchy and log-tail fakes where one waits on `ctx.Done()`. Assert all three collectors start concurrently, successful bytes survive, every blocked fake observes cancellation and exits, and the whole call returns in at most 2 seconds plus a 250 ms scheduling allowance. Repeat 25 failed captures and assert goroutine/resource counts return to the test's bounded baseline. Add reciprocal blocked-hierarchy and blocked-log-tail cases and the artifact paths/timeout-note JSON round-trip beside `pkg/report/flow.go`.
- [x] **Step 3: Verify red.** Run `go test ./pkg/driver/uiautomator2/... ./pkg/executor/... ./pkg/report/...`; expect the race test to pass launch incorrectly and the serial collector test to exceed its bound.
- [x] **Step 4: Implement the crash decision.** Keep the launch PID/fatal state under one synchronization boundary and perform the final matching-fatal check immediately before returning success. Preserve permission batching, first-frame behavior and post-launch crash watch.
- [x] **Step 5: Implement cancellable concurrent capture.** Refactor `pkg/executor/flow_runner.go:1908` `captureArtifacts` to prefer one package-private `failureArtifactCapturer` with `FailureScreenshot(context.Context)`, `FailureHierarchy(context.Context)` and `FailureLogTail(context.Context)`. Implement it on UIAutomator2 with the existing `requestContexter`, `sourceCtx` and app-scoped logcat plumbing so context cancellation aborts the HTTP request or kills the exact owned shell child; do not widen the cross-driver public `Driver` interface. Run all three collectors concurrently under independent deadlines and a 2-second outer bound, wait for cancellation acknowledgement before returning, and never abandon a goroutine. Keep the old context-free methods only for drivers without the internal interface; those drivers run synchronously rather than in an unkillable timeout goroutine. Persist artifact-specific timeout notes without discarding collectors that succeeded.
- [x] **Step 6: Verify green.** Re-run the focused packages, then `go vet ./pkg/driver/uiautomator2/... ./pkg/executor/... ./pkg/report/...`.
- [x] **Step 7: Device acceptance.** On owned `fix4-1-android` below host load 15, run the exact crash flow five times. No launch succeeds after a prior matching fatal; fatal-to-failure remains within the L64 two-second bound. Record artifact start/end timestamps and prove failure capture completes within the L61 bound with no collector child left afterward. Run the healthy launch control and a post-return-crash control separately; the latter must not retroactively fail a launch that already returned.
- [x] **Step 8: Review and merge.** Open a PR titled `Fix Android crash decisions and bound failure artifacts (L61, L64)`, resolve every review finding, require CI green, squash merge and record the merge SHA.

### Task 2: Runner Android gestures and application lifecycle (L51, L62, L77)

Worktree `maestro-runner/.worktrees/fix4-gestures-lifecycle`, branch `fix4/gestures-lifecycle`.

**Files:**
- Modify: `pkg/driver/uiautomator2/commands.go`, `pkg/driver/uiautomator2/{commands_test.go,deterministic_gestures_test.go,bare_scroll_test.go}`
- Modify: `pkg/executor/flow_runner.go`, `pkg/executor/runner_test.go`
- Modify only if isolation proves demo ownership: Android favorite-row source and `.maestro/02-favorite.yaml` in landmarks-demo
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: the held-drag primitive already used by element swipe/bare scroll and `EffectiveAppID()`.
- Produces: held direction/coordinate swipes, explicit `engine: adb` escape hatch, stable target tapping, and verified stopApp postcondition.

**Concrete gesture regression:** Reuse `recordHeldDrag` and `heldDrag` from `commands_test.go`; the previously shell-backed coordinate case becomes:

```go
var drags []heldDrag
server := setupMockServer(t, map[string]func(http.ResponseWriter, *http.Request){
    "POST /actions": recordHeldDrag(t, &drags),
})
defer server.Close()
shell := &MockShellExecutor{}
driver := New(newMockHTTPClient(server.URL).Client, &core.PlatformInfo{ScreenWidth: 1080, ScreenHeight: 2400}, shell)
result := driver.swipe(&flow.SwipeStep{StartX: 100, StartY: 800, EndX: 100, EndY: 200, Duration: 300})
if !result.Success { t.Fatal(result.Error) }
want := heldDrag{100, 800, 100, 200, 300}
if len(drags) != 1 || drags[0] != want { t.Fatalf("drags = %+v, want [%+v]", drags, want) }
if len(shell.commands) != 0 { t.Fatal("non-ADB swipe invoked shell input") }
```

Add the same assertion table for direction and selector forms; the `engine: adb` control must still record exactly one `input swipe` shell command.

- [ ] **Step 1: Write failing L51 tests.** Table-test direction, explicit start/end, element and `engine: adb` forms. The first three must emit W3C held pointer actions with requested duration; only the last may invoke `adb shell input swipe`.
- [ ] **Step 2: Write failing L77 tests.** Exercise bare, scalar and mapping stopApp forms. A zero `am force-stop` exit with the package still running or foreground must return a lifecycle error naming the app; a stopped package clears the crash watch and passes a following not-visible assertion.
- [ ] **Step 3: Write the L62 isolation test.** Replay reveal → stable-bounds reads → tap against a fake hierarchy whose action moves during animation. Assert the runner waits for two identical app-node bounds before tapping. Add a fixture where the app callback fires but state does not change; that result identifies demo ownership without weakening runner assertions.
- [ ] **Step 4: Verify red.** Run `go test ./pkg/driver/uiautomator2/... ./pkg/executor/...`.
- [ ] **Step 5: Implement.** Route non-ADB swipes through the held action builder; add stable target revalidation before the post-swipe action; after force-stop poll exact package/foreground state within a bounded deadline and fail truthfully if it remains.
- [ ] **Step 6: Verify green and regressions.** Run `go test ./pkg/driver/uiautomator2/... ./pkg/executor/... ./pkg/core/...` and `go vet ./pkg/driver/uiautomator2/... ./pkg/executor/... ./pkg/core/...`.
- [ ] **Step 7: Device acceptance.** On owned software and GPU AVDs, run the four L51 forms and retain before/after app-only hierarchy frames; run favorite removal 5/5 on each; run bare stopApp 3/3 plus an intentionally ineffective fake-shell unit case. Generate load only with recorded owned PIDs and remove it afterward.
- [ ] **Step 8: Demo decision.** If the callback/state fixture proves demo ownership, open and merge a separate minimal landmarks-demo PR before the runner PR; otherwise record that no demo edit was required.
- [ ] **Step 9: Review and merge.** PR `Use deterministic held swipes and verify Android app lifecycle (L51, L62, L77)`, clean review, CI, squash merge.

### Task 3: Runner optional status and empty device validation (L53 runner half, L79)

Continue in a fresh runner worktree from merged Tasks 1–2, branch `fix4/optional-device`.

**Files:**
- Modify: `pkg/executor/flow_runner.go`, `pkg/executor/runner_test.go`
- Modify: `pkg/core/status.go`, `pkg/core/command_result_status_test.go`
- Modify: `pkg/report/{builder.go,flow.go,junit.go}` and tests beside them
- Modify: `pkg/cli/cli.go`, `pkg/cli/cli_test.go` for the runner's existing global `--device` flag only
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: optional `StatusWarned`, flow header app/device selection, canonical flow graph.
- Produces: consistent optional result surfaces and usage rejection for the runner's empty `--device` value.

**Concrete semantic assertions:** Add these cases to the current package tests, using their existing app/report helpers:

```go
for _, value := range []string{"", "   "} {
    err := app.Run([]string{"grantiva-runner", "--platform", "ios", "--device", value, "test", "flow.yaml"})
    if err == nil || !strings.Contains(err.Error(), "--device") { t.Fatalf("value %q: %v", value, err) }
}
err := app.Run([]string{"grantiva-runner", "--serial", "x", "test", "flow.yaml"})
if err == nil || !strings.Contains(err.Error(), "flag provided but not defined") { t.Fatalf("unknown flag: %v", err) }
```

For L79, assert the real decoded `report.FlowDetail` remains passed, its optional `report.Command` is warned, and `GenerateJUnit` emits `failures="0"`; change only `Optional:false` in the control and require failed status/nonzero.

- [ ] **Step 1: Write failing L79 production-report tests.** Extend the existing optional-result path in `pkg/executor/flow_runner.go` and `pkg/report/junit_test.go`: run a top-level optional missing tap followed by a required passing step through the real report writer. Assert the failed optional command is `core.StatusWarned`, `flow.Status == core.StatusPassed`, generated JUnit has zero failures, and the process result is successful. Repeat with `optional:false` and assert failed flow/JUnit/process status and skipped later work.
- [ ] **Step 2: Write failing L53 runner tests.** Add table cases to `pkg/cli/cli_test.go` that call the real app with `[]string{"grantiva-runner", "--platform", "ios", "--device", value, "test", "flow.yaml"}` for `value == ""` and `"   "`. Assert the usage error occurs before device discovery. Keep `[]string{"grantiva-runner", "--serial", "x", "test", "flow.yaml"}` as an unknown-flag control; do not add `--udid` or `--serial` aliases.
- [ ] **Step 3: Verify red.** Run `go test ./pkg/executor/... ./pkg/core/... ./pkg/report/... ./pkg/cli/...`.
- [ ] **Step 4: Implement.** Persist warned status before closing an optional command and validate the trimmed existing `--device` value in `pkg/cli/cli.go`.
- [ ] **Step 5: Verify green.** Run `go test ./pkg/executor/... ./pkg/core/... ./pkg/report/... ./pkg/cli/...` and `go vet ./pkg/executor/... ./pkg/core/... ./pkg/report/... ./pkg/cli/...`.
- [ ] **Step 6: CLI integration check after repack.** `grantiva-runner --platform ios --device "" test findings/fixtures/optional-miss.yaml` exits 64 before signing.
- [ ] **Step 7: L79 end-to-end acceptance.** Run the exact optional missing-tap flow three times through the repacked CLI. For every repetition, text, JSON, JUnit, `report.json`, flow detail and ready-file summary agree that the flow passed with one warned optional command; the warning retains useful `element_not_found` detail, the following required step executes, and the process exits 0. Run the otherwise-identical `optional:false` control: it exits nonzero, reports a failed command/flow on every surface, and does not execute the following required step.
- [ ] **Step 8: Review and merge.** PR `Make optional results and device arguments truthful (L53, L79)`, clean review, CI, squash merge.

### Task 4: CLI lifecycle, install, path and output contracts (L53 CLI half, L68, L69, L71, L72, L73, L75, L76, L78)

Worktree `grantiva-cli/.worktrees/fix4-lifecycle-output`, branch `fix4/lifecycle-output`.

**Files:**
- Modify: `Sources/GrantivaCLI/DriverCommand.swift`, `Sources/GrantivaCLI/RunnerLifecycleDocument.swift`, `Sources/GrantivaCLI/BuildCommand.swift`, `Sources/GrantivaCLI/SimulatorCommand.swift`, `Sources/GrantivaCLI/RunCommand.swift`
- Modify: `Sources/GrantivaCore/Runner/{LogStreamer.swift,FlowReferenceResolver.swift,RunnerSession.swift}`
- Modify: `Sources/GrantivaCore/Simulator/SimulatorReaper.swift`
- Test: `Tests/GrantivaCLITests/{RunnerLifecycleCommandTests,BuildCommandTests,SimulatorCommandTests,RunCommandTests}.swift`
- Test: `Tests/GrantivaCoreTests/{LogStreamerTests,SimulatorReaperTests,RunnerExecutionTests,RunnerSessionOutputTests}.swift`
- Modify: `Sources/GrantivaCLI/TargetOptions.swift`; Test: `Tests/GrantivaCLITests/TargetOptionsTests.swift`

**Interfaces:**
- Consumes: starting/ready session documents, stop outcomes, exact owned child processes.
- Produces: app-ready detach, explicit null port, interrupted startup, complete force-teardown result, safe reaping, synchronous log cleanup, canonical cycle paths and CLI-side device validation.

**Concrete CLI/path regressions:** These are additions to the existing XCTest classes and use their real parsers/resolver:

```swift
func testExplicitEmptyTargetsAreRejectedBeforeForwarding() throws {
    for args in [["--device", ""], ["--simulator", ""], ["--emulator", ""]] {
        XCTAssertThrowsError(try TargetOptions.parse(args))
    }
    XCTAssertNoThrow(try TargetOptions.parse(["--simulator", "Grantiva iPhone 18 Pro"]))
    XCTAssertThrowsError(try TargetOptions.parse(["--serial", "anything"]))
}
```

The L75 test follows `testAFlowRunNamesEveryHopOfACycleAsWritten`, but its files are `flows/a.yaml` and `shared/b.yaml`; its final assertion is exactly:

```swift
XCTAssertTrue(text.contains("circular dependency detected: flows/a.yaml -> shared/b.yaml -> flows/a.yaml -> shared/b.yaml"), text)
XCTAssertFalse(text.contains(project.path), text)
```

- [x] **Step 1: Write failing lifecycle tests.** L68: detached Android start does not return until generated launch/settle flow completes and immediate hierarchy is the app. L69: starting JSON contains `"port": null`. L72: SIGINT during WDA startup produces interrupted status/exit130 rather than timeout; a ready control remains exit130.
- [x] **Step 2: Write failing teardown/reaper tests.** L73 force JSON includes `runnerSessionStopped:true` when preliminary stop succeeded. L76 excludes `python helper.py /path/to/grantiva SIMULATOR_UDID` but includes an actual Grantiva executable. L78 models the tracked wrapper exiting before its remote logging child and requires cleanup to await or terminate that exact child.
- [x] **Step 3: Write failing L53/L75 tests.** In `TargetOptionsTests`, parse the real `TargetFlags` with explicit empty `--device`, `--simulator`, and `--emulator` values and assert `validate()` rejects them before `RunnerInvocation` is built; retain ordinary simulator names as valid. In `SimulatorCommandTests`, feed a UDID-shaped but malformed value to the existing `SimulatorUDID.validate` path and require its current usage error. Do not add `--serial` and keep an unknown-flag parsing control. In `RunnerSessionOutputTests`, create real files `flows/a.yaml` and `shared/b.yaml`, stage `flows/a.yaml → ../shared/b.yaml → ../flows/a.yaml`, then assert the emitted cycle is exactly `flows/a.yaml → shared/b.yaml → flows/a.yaml → shared/b.yaml`. Fix `RunnerSession.swift:423-469` so `FlowReferenceResolver`'s project-root-relative reachable map wins when merging `subFlowPathMap`; preserve as-written operands only where no canonical mapping exists. Run the same assertion from `/tmp` and its `/private/tmp` spelling.
- [x] **Step 4: Write failing L71 tests.** `build install --no-build --no-launch --json` with absent app returns skipped without asking for a data container; installed and launched modes retain paths/status. Preserve D2-08's `--app-file` install/no-launch leg and prove its exact app path/status remain intact.
- [x] **Step 5: Verify red.** With `GRANTIVA_RUNNER_HOME=$(mktemp -d)`, run `swift test --filter TargetOptionsTests`, `swift test --filter SimulatorCommandTests`, `swift test --filter RunnerSessionOutputTests`, `swift test --filter RunnerLifecycleCommandTests`, `swift test --filter BuildCommandTests`, `swift test --filter LogStreamerTests`, and `swift test --filter SimulatorReaperTests`. Confirm the new assertions fail and the temporary home remains empty.
- [x] **Step 6: Implement lifecycle changes.** Await the Android launch task before ready/detach return; set null-preserving lifecycle encoding for starting; check SignalRelay before translating startup errors; carry preliminary stopped-runner metadata into force results.
- [x] **Step 7: Implement cleanup/install/path changes.** Classify by executable token; track the simulator-side log child with exact device/run ownership and await bounded termination; calculate skipped install output before data-container lookup; reject empty target values before runner argv construction; and change only the `RunnerSession` map merge needed for canonical cycle paths.
- [ ] **Step 8: Verify green.** Re-run every focused command from Step 5, then `swift test`; assert the fresh runner home remains empty.
- [ ] **Step 9: Bounded device acceptance.** Use only row-owned devices/PIDs and retain each literal control:
  - **L68 / AND-127:** after detached return, immediate hierarchy is the app; metadata and all required tool listings name the same PID/device; stop succeeds; session files and owned forwards are removed.
  - **L69 / N3-03 on both platforms:** observe a genuine `starting` document from the detached first-start form with explicit `"port":null`; the same PID transitions to ready/port and then stopped, and no second runner process appears.
  - **L72:** interrupt startup in plain, quiet and JSON modes; each exits 130, reports the B3-L37 interruption notice, never substitutes a WDA timeout, and removes its session. Keep separate steady-ready interruption, genuine WDA-timeout and unprompted-WDA-death controls.
  - **L73:** force teardown a live session and require `runnerSessionStopped:true`; also run the genuinely free force no-op, non-force refusal, and helper-array/cleanup controls.
  - **L78:** after success, failure and interruption, take repeated immediate process inventories and require the exact owned log child absent before return; another live run remains unaffected; interruption exits 130 and verbose output has one truthful terminal diagnostic.
  - **L71:** run absent, installed-skipped and D2-08 `--app-file` install/no-launch controls. Also verify harmless lookalike survival, empty target rejection before forwarding, and the exact canonical subdirectory cycle.
- [ ] **Step 10: Review and merge.** PR `Fix lifecycle, install and flow-path output contracts (L53, L68, L69, L71–L73, L75, L76, L78)`, review, CI, squash merge.

### Task 5: CLI MCP and iOS selector correctness (L65, L66, L80)

Worktree `grantiva-cli/.worktrees/fix4-mcp-wda`, branch `fix4/mcp-wda`.

**Files:**
- Modify: `Sources/GrantivaMCP/Tools/ScriptTools.swift`, `Sources/GrantivaMCP/MCPServer.swift`
- Modify dependency integration only if transport ownership is proven: `Package.swift` and resolved dependency metadata
- Modify: `Sources/GrantivaCore/WDA/WDAClient.swift`
- Modify: `Tests/GrantivaMCPTests/ToolErrorContractTests.swift`, `Tests/GrantivaMCPTests/ScriptToolsTests.swift`, `Tests/GrantivaMCPTests/MCPServerTests.swift`, `Tests/GrantivaMCPTests/MCPTransportTests.swift`
- Modify: `Tests/GrantivaCoreTests/WDAClientTests.swift`
- Modify: `docs/mcp.md`

**Interfaces:**
- Consumes: MCP JSON-RPC request IDs, stdio transport and WDA predicates.
- Produces: exact required-argument text, serialized whole-message writes and label → identifier → placeholder selector priority.

**Concrete transport regression:** Extend `MCPTransportTests`, using its existing in-memory `clientSide`, `serverSide`, `Server` and `ValidatingTransport`. After initialize/initialized, concurrently send two tool/resource requests whose returned JSON strings are `String(repeating: "x", count: 70_000)` and `String(repeating: "y", count: 70_000)`. Repeat ten times, collect newline records until all 20 IDs arrive, and assert:

```swift
let objects = try lines.map { try XCTUnwrap(JSONSerialization.jsonObject(with: $0) as? [String: Any]) }
XCTAssertEqual(Set(objects.compactMap { $0["id"] as? Int }).count, 20)
XCTAssertEqual(objects.count, 20)
XCTAssertTrue(objects.allSatisfy { $0["jsonrpc"] as? String == "2.0" })
```

Wrap the in-memory sink so each `send(_:)` writes at most 4,096 bytes per low-level write; the test must still observe one complete JSON object per newline.

- [ ] **Step 1: Write failing L65 tests.** Through ToolRegistry with live-session context, `{}` yields exactly `Error: Invalid argument: 'steps' is required.` with isError; no-session precedence, wrong-type and empty-array cases retain their contracts.
- [ ] **Step 2: Write failing L66 tests.** Record actual predicate strings in order. `heart` misses label then matches identifier; `Name` reaches placeholder; application nodes remain excluded; quotes are escaped; match annotation names the winning attribute.
- [ ] **Step 3: Write failing L80 transport tests.** Arrange two response payloads above 65,536 bytes and a transport sink that performs partial writes. Send resource/tool requests concurrently ten times. Assert every newline-delimited record parses, has exactly one ID, and each ID arrives once. Add concurrent small responses and notification delivery.
- [ ] **Step 4: Verify red.** Run `swift test --filter GrantivaMCPTests` and `swift test --filter WDAClientTests`.
- [ ] **Step 5: Fix.** Correct script wording; use the true identifier predicate between label and placeholder; serialize complete encoded JSON-RPC messages at the integration layer. If the pinned MCP package owns writes, pin the reviewed fixed dependency and retain a Grantiva integration regression so later upgrades cannot regress.
- [ ] **Step 6: Verify green.** Repeat focused tests, then full `swift test` with fresh home.
- [ ] **Step 7: Binding live acceptance.** On owned live sessions on both iOS and Android, call `grantiva_script {}` through `ToolRegistry` and require exact `Error: Invalid argument: 'steps' is required.` with `isError`; separately preserve no-session precedence, wrong-type and empty-array controls. On iOS rerun full IOS-102, B2-K78 and D2-36: label → identifier → placeholder priority, winning-attribute annotation, application-node exclusion, quote escaping, retry behavior and all existing binding assertions. Then pipeline mixed resource/tool hierarchy responses larger than 65,536 bytes ten times on both platforms; every newline is one valid JSON object, every request ID arrives exactly once in unconstrained completion order, and small responses plus notifications still arrive.
- [ ] **Step 8: Review and merge.** PR `Serialize MCP responses and fix script/WDA selector contracts (L65, L66, L80)`, review, CI, squash merge.

### Task 6: Public diagnostics and migration documentation (L67, L70, L74, L81)

Worktree `grantiva-cli/.worktrees/fix4-public-docs`, branch `fix4/public-docs`, created from main after Tasks 4–5 merge.

**Files:**
- Modify: `Sources/GrantivaCLI/DoctorCommand.swift`
- Modify: `Sources/GrantivaCore/Doctor/DoctorRunner.swift`
- Modify: `Tests/GrantivaCLITests/DoctorSelectionTests.swift`, `Tests/GrantivaCoreTests/DoctorTests.swift`
- Modify: `README.md`, `docs/mcp.md` (the repository has no `CHANGELOG.md`; these are the binding public substitutes)
- Modify: `Tests/GrantivaCLITests/DocsContractTests.swift`, `Tests/GrantivaCLITests/HelpCorpusTests.swift`

**Interfaces:**
- Consumes: final merged behavior and public compatibility contracts.
- Produces: Advisory doctor classification, visible default-simulator ownership diagnostics independent of list order, and searchable migration notes for filenames and ISO-8601 dates.

**Concrete documentation contract:** Extend `DocsContractTests` with literal public-contract assertions rather than campaign issue IDs:

```swift
let readme = try text("README.md")
let mcpDocs = try text("docs/mcp.md")
XCTAssertTrue(readme.contains("legacy baseline"))
XCTAssertTrue(readme.contains("percent-encoded"))
XCTAssertTrue(mcpDocs.contains("ISO 8601"))
for key in ["acquiredAt", "createdAt"] { XCTAssertTrue(mcpDocs.contains(key), key) }
```

- [ ] **Step 1: Write failing L67 test.** In an ambiguous Xcode/Gradle directory, assert doctor text and JSON place Platform under Advisory, preserve selection guidance and exit 0; `run` still rejects ambiguity.
- [ ] **Step 2: Write failing L81 production-entry tests.** Call `DoctorRunner.checkBootedSimulator` with booted non-default `iPhone 17 Pro` plus unowned default `iPhone 18 Pro` in both list orders. Both checks remain `.ok`/Advisory and expose `"iPhone 18 Pro" (USER-DEFAULT) was not created by Grantiva, so it is not used as the default`. Add negative controls where no default-named device exists and where `USER-DEFAULT` is in `createdUDIDs`; neither may emit the note. Preserve no-booted and list-failure tests.
- [ ] **Step 3: Write failing documentation tests.** Require public text that states legacy baseline lookup/migration and ambiguous `%` filenames (L70), and identifies every date-valued JSON field now encoded as ISO 8601 with compatibility impact (L74). Require the L66 selector-order wording and current lifecycle JSON examples.
- [ ] **Step 4: Verify red.** Run `swift test --filter DoctorSelectionTests`, `swift test --filter DoctorTests`, `swift test --filter DocsContractTests`, and `swift test --filter HelpCorpusTests`.
- [ ] **Step 5: Implement.** Change ambiguous Platform to Advisory. Make the full booted-simulator check append the L81 ownership note without changing its status/section or whichever booted simulator it reports. Add concise migration/release-note sections with concrete old/new examples and no internal campaign language.
- [ ] **Step 6: Exact acceptance.** Rerun CLI-025 text and JSON: ambiguity is Advisory, exits 0 with usable toolchains, retains platform-selection guidance, and `run` still rejects ambiguity. Rerun N3-15 in a deterministic source-level fixture with both device orders plus the absent-default and Grantiva-owned-default controls; then inspect text/JSON formatting without changing owner devices.
- [ ] **Step 7: Verify green.** Re-run focused tests, regenerate the help corpus with the repository script, run full `swift test`, and confirm no stale generated diff.
- [ ] **Step 8: Review and merge.** PR `Fix doctor diagnostics and document round-4 compatibility changes (L67, L70, L74, L81)`, review, CI, squash merge.

### Task 7: Repack and bundle the merged runner

Runner `grantiva/main` after Tasks 1–3; CLI worktree `grantiva-cli/.worktrees/chore-bundle-runner-round4` after Tasks 4–6.

**Files:**
- Modify: CLI runner version/stamp files located by `rg '1\.1\.28-grantiva' Sources Tests scripts README.md`
- Modify generated runner bundle artifacts through runner repository `scripts/build-runner.sh`
- Modify: `Sources/GrantivaCore/Runner/RunnerReportSteps.swift` and `Sources/GrantivaCore/Runner/RunnerSession.swift` for new failure-artifact compatibility
- Test: `Tests/GrantivaCoreTests/RunnerReportContractTests.swift`, `RunnerSessionReportTests.swift`, and `RunnerTraceExportTests.swift`
- Test: `Tests/GrantivaCoreTests/RunnerManagerTests.swift` and stamp tests

- [ ] **Step 1: Prove new report-schema compatibility before bundling.** Task 1 adds `command.artifacts.logTail` (relative asset path) and nested `command.artifacts.notes` (screenshot/hierarchy/logTail note map). First add a failing real `report.json` plus referenced flow fixture: failed-command decoding, CLI step/failure details, generic rewrite/finalization, and exact log-tail trace bytes must survive the new schema and ephemeral report cleanup. Keep old reports without new fields passing. Replace the `[String:String]?` artifacts decoder in `RunnerReportSteps` with a compatible structured representation; extend the trace exporter to preserve the specific log-tail text assets with existing path-containment/attribution safeguards, including nested-command filenames. Run focused report/trace tests red then green; include source compatibility in the bundle PR review. Do not bundle a runner that makes command decoding empty or drops log evidence.
- [ ] **Step 2: Choose and freeze the next version.** Read `RunnerManager.runnerVersion` and the latest matching runner tag, increment the Grantiva revision once under the repository convention, write the resulting literal version to the ledger, and use that same literal in every subsequent command and PR title. Do not calculate it independently in two places.
- [ ] **Step 3: Build runner artifacts.** From merged runner main run `go test ./pkg/driver/uiautomator2/... ./pkg/executor/... ./pkg/report/... ./pkg/cli/...`, `go vet` for the same packages, and runner repository `scripts/build-runner.sh --version "$ROUND4_RUNNER_VERSION"` once without installation to validate both architectures and flag parity.
- [ ] **Step 4: Regenerate every required WDA cache.** Start from a dedicated empty cache staging home. First inventory iOS 26.0, 26.2, 26.4 and 27.0; if any required runtime is unavailable, stop packaging and record the release-environment blocker rather than silently omitting or reusing its cache. For one owned simulator on each runtime, run the merged CLI/runner WDA start path until its `cache/wda-builds/` configuration directory is complete, then stop the exact session. Record simulator UDID, runtime, xcodebuild exit, cache directory and SHA-256 manifest. Do this on every round even when WDA source is unchanged; do not reuse the round-3 cache as the packaged input.
- [ ] **Step 5: Bundle.** From the runner repository run `scripts/build-runner.sh --version "$ROUND4_RUNNER_VERSION" --wda-cache "$ROUND4_WDA_CACHE" --cli /Users/kyle/Developer/grantiva-cli/.worktrees/chore-bundle-runner-round4`. Verify both architecture archives, embedded executable version, driver payloads, and all four WDA cache configurations against the Step 4 manifest.
- [ ] **Step 6: Update stamps and tests.** Change the CLI's version/stamp expectations and public version example to `$ROUND4_RUNNER_VERSION`. Run `swift test --filter RunnerManagerTests`, `swift test --filter JSONKeyCasingContractTests`, and full `swift test` with a separate fresh empty unit-test home.
- [ ] **Step 7: Review and merge.** PR title is `Bundle runner $ROUND4_RUNNER_VERSION for the round 4 fix wave`; review, CI, squash merge.

### Task 8: Release candidate and bounded smoke

Run by the controller after Task 7 merges.

**Files:**
- Create: `findings/round4-smoke.md`
- Create: `findings/evidence/round4-smoke/`
- Regenerate: `findings/help/`

- [ ] **Step 1: Build release candidate and exercise upgrade.** From merged CLI main run `swift build -c release`; copy the binary and resource bundle to the QA bin directory. Create the device-verification home with `cp -cR "$HOME/.grantiva/runner" "$ROUND4_SCRATCH/runner-home"`, point `GRANTIVA_RUNNER_HOME` at that fresh APFS clone, run the merged CLI once to perform the in-place bundled-runner upgrade, and prove the pre-existing cache plus newly packaged iOS 26.0/26.2/26.4/27.0 WDA caches remain valid. Record source/destination manifests, binary, bundle and runner hashes/versions. Unit-test empty homes remain separate.
- [ ] **Step 2: Runner smoke.** On owned `smoke4-android`, run healthy stock, crash five times, L51 four gestures, favorite removal five times, stopApp, optional/required misses and subdirectory cycle. Capture raw report and cleanup evidence.
- [ ] **Step 3: CLI/MCP smoke.** On owned `smoke4-ios` and the Android AVD, exercise startup/ready interruption, detach readiness, force teardown JSON, absent install, log cleanup, L65 missing-steps/error-precedence on both platforms, the full L66 selector family on iOS, and ten large concurrent response pairs.
- [ ] **Step 4: Docs/output smoke.** Run ambiguous doctor text/JSON, inspect public migration notes and regenerate every help page. All corpus tests pass.
- [ ] **Step 5: Cleanup.** Delete only smoke-created devices and verify their IDs, sessions, locks, forwards and owned PIDs are absent. Record protected-device inventories unchanged.
- [ ] **Step 6: Gate.** Any failed acceptance criterion reopens its owning task and PR; do not proceed to coverage with a qualified smoke failure.

### Task 9: Round 4 coverage, final report and campaign exit

**Files:**
- Create: `docs/superpowers/plans/2026-10-13-round4-coverage-pass.md`
- Create: `docs/superpowers/plans/2026-10-13-round4-coverage-matrix.md`
- Create: `docs/superpowers/plans/2026-10-13-round4-coverage-report.md`
- Modify: campaign handoff and ledgers

- [ ] **Step 1: Build the matrix delta.** Clone the round-3 matrix with results cleared. Add `B4-*` regression rows that quote every acceptance bullet from all 22 briefs and rows for the new serialized transport/warned status/app-ready detach behaviors. Keep approved expectation corrections.
- [ ] **Step 2: Execute all slices.** Run CLI, iOS and Android slices using explicit owned devices and the round-3 evidence rules. Preserve each initial verdict and rerun separately; no product fixes inside coverage slices.
- [ ] **Step 3: Independent review.** Review every new row, every non-pass, raw provenance, per-platform halves and cleanup. Resolve review findings before merging slice results.
- [ ] **Step 4: Report.** Publish exact counts, versions, hashes, the 22-brief verification table, any new briefs, protected-device state and cleanup. `ROUND 4: CLEAN` requires zero fail rows; otherwise state the exact number of findings and continue the campaign.
- [ ] **Step 5: Commit and push campaign artifacts.** Update handoff/ledger, run docs contract checks, commit the report and push the campaign branch.

## Coverage map

| Brief | Owning task | Required proof |
|---|---:|---|
| L51 | 2 | direction/start-end/element held actions; explicit ADB escape; app-only movement evidence |
| L53 | 3 + 4 | runner existing `--device` rejects empty; CLI prevents empty forwarding and validates explicit simulator UDID-shaped inputs; unknown flags remain unknown and no `--serial` is added |
| L61 | 1 | concurrent bounded screenshot/hierarchy/log capture within accepted device bound |
| L62 | 2 | favorite removal 5/5 on slow/fast AVD and isolated runner/demo ownership |
| L64 | 1 | fatal-before-return always makes launch app_crash; five real repetitions |
| L65 | 5 | exact live-session script missing-steps text and no-session precedence |
| L66 | 5 | real label → identifier → placeholder order and annotation |
| L67 | 6 | Platform ambiguity under Advisory in text/JSON, exit 0 |
| L68 | 4 | detached Android return followed immediately by app hierarchy |
| L69 | 4 | starting JSON explicitly contains null port |
| L70 | 6 | public baseline filename migration and legacy ambiguity note |
| L71 | 4 | absent app no-build/no-launch skipped without container lookup |
| L72 | 4 | startup SIGINT interrupted/130; no WDA timeout; ready control |
| L73 | 4 | force teardown JSON reports stopped runner and cleanup |
| L74 | 6 | public ISO-8601 date migration note naming affected fields |
| L75 | 4 | `FlowReferenceResolver`/`RunnerSession` subdirectory cycle paths are project-root-relative |
| L76 | 4 | unrelated executable with Grantiva argument survives force teardown |
| L77 | 2 | bare stopApp terminates app or returns a truthful error |
| L78 | 4 | no owned log child immediately after success/failure/interruption return |
| L79 | 3 | optional miss warned/pass/exit0 across every report surface; required control fails |
| L80 | 5 | ten concurrent >64 KiB pairs produce valid one-response-per-line JSON |
| L81 | 6 | full doctor entry exposes unowned-default note in both booted-device orders; absent/owned default controls omit it |

## Self-review record

- Spec coverage: all 22 briefs appear exactly once in the coverage map. Each has one owning implementation task except L53, whose existing runner-flag rejection is Task 3 and whose CLI forwarding/UDID validation is Task 4.
- Placeholder scan: commands use ledger-bound shell variables only after the preceding step records their literal values; there are no angle-bracket placeholders or deferred implementation decisions.
- Type consistency: task interfaces use existing status, lifecycle, JSON and transport concepts; the only new internal interface, `failureLogTailer`, is fully specified in Task 1 and remains package-private.
- Review Focus: each of the five high-risk input classes has an owning failing test and device/integration acceptance step.
