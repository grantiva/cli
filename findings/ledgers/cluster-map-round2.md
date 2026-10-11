# Round 2 coverage pass: cluster map (CLI + iOS + Android slices)

Inputs: `cov2-cli/findings/cov2-cli-results.md` (CLI slice, tag `[cli]`), `cov2-ios/findings/cov2-ios-results.md`
(iOS slice, tag `[ios]`) and `cov2-android/findings/cov2-android-results.md` (Android slice, tag `[android]`; its extras
AND2-OBS-01..06 count as fails). Source references are CLI main c65fc17 (`Sources/…`) and runner 1be68db (`pkg/…`).
Every slice counts as fails every row graded `fail` and every row graded `fail (matrix/brief error — triage)`. `fail`
rows go to clusters, or to §Carried open items when they verify a brief that is still open (L01, L02, L05, L06, L07,
K111). Triage rows go to §Expectation corrections. Android evidence lives under
`cov2-android/findings/evidence/cov2-android/<ROW>/` and the shared `CF-*/` runs; each `commands.txt` records the 1-min host
load. Fails that may only be load artefacts are listed in §Load-sensitive.

**Android fix round 1** (cov2/android b58af30; task-5-report.md "## Fix round 1") re-ran the load-suspect rows on a fresh
default AVD at load 5-13 ("quiet host" below means this round, not load < 4). Grading changes:
- B2-L01 → pass.
- AND-107, AND-040, B-A01.1 and B-R01.3 → triage (M25 withdrawn).
- AND-213 stays `fail`, with its cause re-attributed to M41.
- New extra AND2-OBS-07 → M42.

Each cluster below carries a confirmation line where the re-run touched it.
CLI-049 was `blocked` in the CLI slice and handed over. The iOS slice graded it `fail`, so it counts in the iOS slice.

## Clusters

Severity order: crash > wrong-result > contract > ux > docs. In the "Brief" lines, *incomplete* means a fix shipped but
part of the brief's acceptance criteria still fails, and *extends* means a new defect next to the brief's own.

### M01 — mcp-build-default-takes-user-simulator
- Component: mcp. Severity: wrong-result.
- Rows: B2-K37.2 [ios] (seen through MCP-031).
- Expected: with no `simulator` argument and no config, `grantiva_build {scheme}` uses the shared default. If no
  Grantiva-created simulator of that name exists, the tool creates one, or returns an isError that names the default and how
  to override it. It never adopts a simulator the user created.
- Actual: the default resolved to `iPhone 18 Pro`, the user's own simulator, which was shut down. The tool booted it and
  recorded it as an ephemeral Grantiva slot under session cov2-ios.
- Brief: K37 fix insufficient. MCP build still takes a user's simulator. The provenance check exists only in `init`.
- Suspected cause: `Sources/GrantivaMCP/Tools/BuildTools.swift:107` and `:279` fall back to `DefaultSimulator.name` with no
  provenance check. The only "was not created by Grantiva" check is `Sources/GrantivaCLI/InitCommand.swift:175`.
  `DefaultSimulator.swift:17-20` returns the newest stock iPhone name, which a developer is likely to already have. The CLI
  `run`/`build` paths with no config probably share this gap (not exercised).

### M02 — android-init-default-avd-no-provenance-warning
- Component: cli. Severity: wrong-result.
- Rows: EXTRA-01 [cli] (evidence CLI-070/init.err).
- Expected: like iOS `init` (CLI-069/072), Android `init` warns when its default device already exists and Grantiva did not
  create it, or it writes a Grantiva-specific name.
- Actual: Android `init` writes `emulator: Pixel_8_API_35` without a warning. Grantiva did not create that AVD on this host.
  The next `run` would boot and drive the user's own AVD.
- Brief: K37 incomplete. The provenance criterion is met only on iOS, and Android has no twin.
- Suspected cause: `Sources/GrantivaCLI/InitCommand.swift:46` hardcodes `emulator: "Pixel_8_API_35"`. The warning at
  `InitCommand.swift:175` applies only to the iOS template. The AVD provenance ledger (K28 created-AVDs record) is never
  consulted.

### M03 — failing-run-text-summary-empty
- Component: cli. Severity: wrong-result.
- Rows: S2-03 [ios], S2-03 [android].
- Expected: a run with `screens:` and `flows:` prints the per-screen and per-flow blocks plus the `Screens: …` and `Flows: …`
  lines on a failing run, as it does on a passing one.
- Actual: the screens session passed and a flow failed, and stdout was 0 bytes. Neither summary line was printed. The exit
  code was 1. Android is the same: stdout empty, stderr ends with `Error: Runner failed (exit 1): 02-exact-negative: …`, and
  the ready file is correct (screens passed, 02-exact-negative failed, the rest skipped). The Android smoke showed the same.
- Brief: K20 extends. Screens-session failure reporting fixed `--json`, but the text form still prints nothing on a failure.
- Suspected cause: `Sources/GrantivaCLI/RunCommand.swift:552-557`. A throw from `runFlows` goes to `handleSuiteFailure` and is
  rethrown. `handleSuiteFailure` (`RunCommand.swift:205-217`) only emits the `--json` failure document. The text path
  (`resultLines`, `:561-565`) is reached only when nothing throws, so the earlier screen captures and the failed flow's rows
  are discarded.

### M04 — runner-dies-on-sighup-under-nohup
- Component: cli. Severity: crash.
- Rows: N2-18 [ios] (part a).
- Expected: under `nohup grantiva run --keep-alive`, the runner survives SIGHUP, as the nohup'd grantiva does. This is the
  fix-wave Task 5 deferred minor, which noted that spawn resets SIGHUP.
- Actual: a SIGHUP kills the runner at once while the grantiva process survives. The keep-alive session is dead. The run then
  exits 1 on SIGINT.
- Brief: fix-wave deferred minor (Task 5 ledger), now confirmed on a device. New brief.
- Suspected cause: `Sources/GrantivaCore/Runner/ChildProcess.swift:78-79` puts SIGHUP in the
  `posix_spawnattr_setsigdefault` set. A parent that inherited SIG_IGN for SIGHUP from nohup therefore spawns a runner with
  SIGHUP back at SIG_DFL. Fix direction: keep SIGHUP out of the default set when the parent ignores it, so nohup's choice is
  passed on.

### M05 — teardown-force-leaves-dead-runner-session-file
- Component: cli. Severity: contract.
- Rows: N2-18 [ios] (part b). The row is counted once, under M04.
- Expected: `simulator teardown --udid --force` removes the session file of a runner that died on its own
  (`/tmp/grantiva-sessions/<pid>-*.grantiva`), as README promises for a killed keep-alive.
- Actual: after the runner died from the SIGHUP, `teardown --udid --force` killed the orphaned WDA and diagnose processes.
  `12109-*.grantiva` stayed in `/tmp/grantiva-sessions` (leftover-session.out) and had to be removed by hand.
- Brief: K87 and K79 extend. Runner stop and the killed-runner cleanup cover a runner that teardown kills, not one that is
  already gone.
- Suspected cause: `Sources/GrantivaCore/Simulator/SimulatorReaper.swift:222-224` removes session files only for the runner
  pids it reaped in this teardown (`targets.filter { $0.kind == .runner }`). A runner that is already dead is never a
  target, so its file is skipped. A fix should also remove session files for this UDID whose pid is dead.

### M06 — runner-stop-json-shape-differs-from-start
- Component: cli. Severity: contract.
- Rows: IOS-138, B2-K16, N2-05, N2-07, D2-13 [ios]; B2-K16, N2-07, D2-13 [android].
- Expected: README:399-403 says `runner start --json` and `runner stop --json` share one shape: `status`, `pid` and `port`
  as numbers, `platform`, `bundleId` and `udid`. README also names `runner stop` for the `bundle_id` → `bundleId` pair.
- Actual: the `stop` documents (single, multi-session `sessions[]`, `alreadyExited`) have no `port` and no `bundleId` or
  `bundle_id`. They also add `killed` (`false` next to `status: stopped`), `reaped` and `runnerPid`. README documents
  `reaped` and `runnerPid` but not `killed`. `pid` and `port` are numbers now, which is the round-1 part of the fix.
  Android has the same gap: the stop document is `{killed, pid, platform, reaped, runnerPid, serial, status, udid}`, with no
  `applicationId`, no deprecated `bundle_id` and no `port`, while `started`/`already_running` carry `applicationId` +
  `bundle_id` and `serial` + `udid`.
- Brief: K16 incomplete. `runner stop` lacks `port` and `bundleId`, and `killed` is undocumented.
- Suspected cause: `Sources/GrantivaCLI/DriverCommand.swift:826-865`. Every stop `RunnerLifecycleDocument(status:
  "stopped", pid:, deviceID:, platform:)` is built without `port:` or `appID:`, although the session file holds both.
  `RunnerLifecycleDocument.swift:46` encodes `killed`. Fix one of two ways: carry `port` and `bundleId` (+`bundle_id`) from the
  session record and document or drop `killed`, or change README:399 so it no longer claims one shape.

### M07 — mcp-cancelled-request-still-answered
- Component: mcp. Severity: contract.
- Rows: D2-34 [cli] (part 2). The row is counted once, under M08.
- Expected: after `notifications/cancelled` for an in-flight `grantiva_build`, the call is cancelled and gets no late result
  (D2-34; MCP spec).
- Actual: `tools/list` (id 11) was answered first. The cancelled id 10 still received a late result (`Error: Invalid
  argument: Simulator not found: "cov-missing"`).
- Brief: K53 and K101 extend. The MCP error and transport contract does not cover cancellation.
- Suspected cause: `Sources/GrantivaMCP/MCPServer.swift:97-130` registers method handlers only, with no handler for
  `notifications/cancelled`. The `CallTool` task at `:102` is never cancelled. `ToolRegistry.swift:94-112` already rethrows
  `CancellationError`, so wiring the notification to the task's `cancel()` (and suppressing the response) should be enough.

### M08 — mcp-error-text-prefix-and-label
- Component: mcp. Severity: contract.
- Rows: N2-19 [cli], D2-34 [cli] (part 1).
- Expected: per docs/mcp.md, every failure's text starts `Error: `, and argument failures read `Error: Invalid argument:
  <message>`.
- Actual: an unknown tool returns `Unknown tool: grantiva_bogus_tool` / `Unknown tool: grantiva_nope` with no `Error: `
  prefix. `grantiva_sim_ensure {}` and `grantiva_emulator_ensure {}` return `Error: 'name' is required.` without the `Invalid
  argument:` label.
- Brief: K53 and K46 follow-up incomplete.
- Suspected cause: `Sources/GrantivaMCP/ToolRegistry.swift:192` (`"Unknown tool: \(name)"`). Missing-argument texts are
  hand-built in `Tools/SimTools.swift:126,142` and `Tools/EmulatorTools.swift:108,115`. The same shape appears in
  `Tools/ScriptTools.swift:80` (`'steps' array is required.`) and `Tools/UITools.swift:185,202`. Route them through the
  invalid-argument formatter.

### M09 — vrt-approve-stops-at-first-missing-screen
- Component: cli (shared by `diff approve` and MCP `grantiva_vrt_approve`). Severity: contract.
- Rows: B2-K60 [cli].
- Expected: approve fails and names every missing screen (K60 behavioural check).
- Actual: three screens were requested and all three were missing. Only the first is named. The argv half of K60 holds: no
  shell, and no `pwned*` files.
- Brief: K60 criterion 2 not met. K49 (approve-missing-screen message) extends.
- Suspected cause: `Sources/GrantivaCLI/DiffCommand.swift:780-784` throws `notFound` at the first missing capture inside the
  loop. Any screen before it has already been saved (`:786`), so an approve that fails partway is also a partial approve.
  Check all names before saving any, then report them all.

### M10 — mcp-context-config-line-says-current-directory
- Component: mcp. Severity: ux.
- Rows: MCP-046 [cli].
- Expected: the `[Config]` line says no config file was found in the directory that was searched (the `--project-dir`), and
  names `grantiva.yml` / `grantiva-android.yml` (docs/mcp.md:14-15, 64; R04 criterion 2).
- Actual: it says `No grantiva.yml found in current directory.` even when the server's cwd has a grantiva.yml and
  `--project-dir` is empty. It names only the resolved platform's file.
- Brief: R04 criterion 2 and K58 extend.
- Suspected cause: `Sources/GrantivaMCP/Tools/ContextTool.swift:64`.
- Aside: `[Simulator]` falls back to the first booted simulator, which belonged to another session (cov2-ios-1). This is
  worth a look alongside M01.

### M11 — screens-summary-step-text-diverges-from-live-line
- Component: cli. Severity: ux.
- Rows: IOS-141, B2-K90-a [ios].
- Expected: the stdout summary names each screens step the way the live line does (K90-a: the wait line is the same in both).
- Actual: the summary prints `✓ Wait 3.0s` while the live line prints `✓ Wait 3s (3.0s)`. The summary also drops the `exact`
  qualifier, for example `✓ Assert visible "Golden Gate.*"` where stderr shows `exact=true`.
- Brief: K90-a incomplete.
- Suspected cause: `Sources/GrantivaCore/Runner/RunnerSession.swift:885-909` (`stepAction`). `"Wait \(seconds)s"`
  interpolates a `Double`, and the tap, assertVisible and assertNotVisible branches never read the step's `exact` flag.

### M12 — run-stdout-runflow-prints-staged-absolute-path
- Component: cli. Severity: ux.
- Rows: B2-K105 [ios], B2-K105 [android].
- Expected: the live line, nested header, report.json and the summary name the sub-flow as written (K105 Expected).
- Actual: live lines and report.json are fixed. grantiva's stdout step list still prints
  `✓ runFlow: /tmp/…/ios/…/coverage/14-runflow-sub.yaml` (twice). That is the `/tmp` spelling, not the realpath.
  Android prints the same staged path in the `run` result block (verbose.out, verbose-rd.out), for both forms.
- Brief: K105 incomplete.
- Suspected cause: `Sources/GrantivaCore/Runner/RunnerSession.swift:485-495` and `:580-587`. Captures are collected from
  report.json by `RunnerArtifactCollector.collect(…, stagedPathMap:)`. That collector receives `stagedPathMap`, not
  `reportPathMap` (which merges `subFlowPathMap`, `:448`), and the report rewrite runs afterwards in a `defer`. Step actions
  therefore keep the resolver's absolute path.

### M13 — cycle-error-chain-mixes-path-spellings
- Component: cli. Severity: ux.
- Rows: CLI-049 [ios], B2-K90-b [ios].
- Expected: the cycle error starts at grantiva.yml and names the user's files in one form (K90-b criterion 1).
- Actual: `grantiva.yml -> a.yaml -> /tmp/claude-501/…/CLI-049/b.yaml -> a.yaml`. One hop is absolute in its `/tmp`
  spelling and the others are relative. `run --flow a.yaml` gives `a.yaml -> b.yaml -> /tmp/…/a.yaml -> b.yaml`. There is no
  hang, and no `grantiva-flows-` path appears.
- Brief: K90-b incomplete.
- Suspected cause: the runner builds the chain from resolved paths (`pkg/validator/validator.go:390-396`). grantiva maps
  back only the hops its own `FlowReferenceResolver` rewrote in the staged top-level flow (`subFlowPathMap`,
  `RunnerSession.swift:412-419`). A hop the runner resolved itself inside an unstaged sub-flow, plus the
  `/tmp` vs `/private/tmp` spelling (K104), stays absolute. Not confirmed by tracing.

### M14 — runtime-printed-as-identifier-fragment
- Component: cli. Severity: ux.
- Rows: EXTRA-05 [cli], N2-03 [ios].
- Expected: one runtime spelling, `iOS 26.0`, wherever a runtime is shown. K96 fixed `grantiva_sim_list` and
  `grantiva_context`.
- Actual: doctor's Booted Simulator check prints `cov2-ios-1 — iOS-26-0`. The `simulator ensure` reuse refusal prints
  `(device type: com.apple.CoreSimulator.SimDeviceType.iPhone-17, runtime: iOS-26-0); requested iOS 27.0`, with raw
  identifiers next to the user's form.
- Brief: K96 incomplete. Doctor and the ensure refusal were not converted.
- Suspected cause: `Sources/GrantivaCore/Doctor/DoctorRunner.swift:111` (`device.runtime`) and
  `Sources/GrantivaCore/Simulator/SimulatorManager.swift:204` (`existing.runtime`, `existing.deviceTypeIdentifier`). Reuse
  the runtime and device-type name lookup already used at `SimulatorManager.swift:247`.

### M15 — teardown-home-failure-message-double-period
- Component: cli. Severity: ux.
- Rows: IOS-121 [ios].
- Expected: the message names the home it could not remove in clean text. The behaviour itself holds (exit 1,
  `deviceHomeFailures`).
- Actual: `… couldn’t be removed because you don’t have permission to access it.. Delete it by hand.` The underlying error's
  full stop is followed by the CLI's own.
- Brief: K69 extends.
- Suspected cause: `Sources/GrantivaCLI/SimulatorCommand.swift:303-305` appends `". Delete it by hand."` to
  Foundation's `localizedDescription`, which already ends in a period. Trim a trailing `.` first.

### M16 — session-capture-launch-step-duration-zero
- Component: mcp (`SessionCapture`, used by `diff capture --no-build` through a live session and by MCP `grantiva_vrt_capture`).
  Severity: contract.
- Rows: N2-08 [ios] (also seen in MCP-063); X-022, B2-K17, N2-08 [android] (also MCP-064).
- Expected: every step's `duration` is a positive number or `null` when the runner measured none, never `0` (README `run --json`
  duration rule, which also holds for `diff capture --json`).
- Actual: a session capture reports Home's `Launch app` with `duration: 0`. On Android, the CLI capture without a session
  measures the same step (8.284 s, AND-108), while `diff capture --no-build --json` through a session and MCP
  `grantiva_vrt_capture` report `0`.
- Brief: K17 incomplete (session-capture path).
- Suspected cause: `Sources/GrantivaMCP/Tools/SessionCapture.swift:158`, `StepResult(action: "Launch app", status: .passed,
  duration: 0)`. Use `nil`, or time the launch.

### M17 — wda-waitforanimationtoend-passes-on-dead-app
- Component: runner. Severity: wrong-result.
- Rows: N2-13 [ios].
- Expected: no wait passes against a dead app. Each wait ends at once with `error.type: app_crash` (N2-13; K97).
- Actual: `extendedWaitUntil`, `assertNotVisible` and `scrollUntilVisible` fail at once with `app_crash`.
  `waitForAnimationToEnd` right after `launchApp` passes in 506 ms against the crashed app, and only the next assert fails.
- Brief: K97 extends. This is the iOS sibling of L06's "a wait can pass on a dead app".
- Suspected cause: `pkg/driver/wda/commands.go:1791-1816` compares two screenshots and never consults `appDied`
  (`pkg/driver/wda/wait_crash.go:34-55`). The home screen is static, so it "settles". The fix brief should decide whether
  `waitForAnimationToEnd` is a wait under the K97 rule: it is not an element wait, so check whether the stock flows depend on
  it passing.
- Android: on Android the four N2-13 waits fail with `app_crash` except `extendedWaitUntil {visible: "Landmarks"}`, which
  passes by matching the launcher's label. That is an open L02 criterion (§Carried open items), not this cluster. The
  screenshot-stability weakness also explains M38: a static blank or home screen "settles" at once.

### M18 — mp4-hold-fails-on-malformed-extra-track
- Component: cli. Severity: wrong-result.
- Rows: N2-20 [cli].
- Expected: a malformed non-video track is skipped and the last-frame hold still applies to the video track, with a test that
  pins it.
- Actual (source): a track whose `hdlr` is readable and not video is skipped. Any track without an `mdia` box returns
  `Unreadable("a track has no mdia box")`, which fails the whole hold, so the video track is not held. No test covers an
  extra track.
- Brief: fix-wave Task 8 deferred minor. New brief.
- Suspected cause: `Sources/GrantivaCore/*/MP4LastFrameHold.swift:131-135` (the loop returns at the first `.failure`) and
  `:217-219` (`holdTrack` fails before it knows the track is video). Return `.success(false)` for a track with no
  `mdia`/`hdlr`, and add a case to `MP4LastFrameHoldTests`.

### M19 — usage-error-shapes-inconsistent
- Component: cli. Severity: contract.
- Rows: EXTRA-04, EXTRA-07 [cli].
- Expected: one class of usage error has one exit code and one shape: exit 64, plain `Error: <message>`, and the
  `Usage:`/`See … --help` lines, as with `--frames-at`, `--duration` and `--session-id`/`--udid`.
- Actual, two problems:
  - `record --output` extension errors exit 64 with no Usage lines.
  - `--device`/`--emulator` on `record` and `run` exits 1 with `Error: Invalid argument: … mutually exclusive; pass one.`
    and no Usage. `simulator teardown --session-id/--udid` and `emulator teardown --serial/--all` exit 64 with the plain
    form and Usage.
- Brief: K41, K42 and K43 extend.
- Suspected cause:
  - `Sources/GrantivaCLI/RecordCommand.swift:199-204` logs and throws `ExitCode.validationFailure` on purpose, so no Usage is
    printed.
  - `TargetOptions.swift:59`, `RecordCommand.swift:113` and `DriverCommand.swift:179` throw
    `GrantivaError.invalidArgument`, while `SimulatorCommand.swift:121` and `EmulatorCommand.swift:178` throw
    `ValidationError`.
  - Move the device/emulator exclusivity into `validate()`. For the extension check, which needs the resolved platform,
    accept the missing Usage or document it.

### M20 — runner-install-path-two-spellings
- Component: cli. Severity: ux.
- Rows: EXTRA-02 [cli].
- Expected: one spelling of the install path across runs and in `--json`.
- Actual: the run that extracts prints `/private/tmp/…`, later runs and `--json` print `/tmp/…` for the same directory, and
  the CLI-142 warning and error use `/tmp/…` while the cwd is `/private/tmp/…`.
- Brief: K104 extends (the `/private` prefix stripped from the project directory).
- Suspected cause: not located precisely. `RunnerManager.resolveBaseDir` (`Sources/GrantivaCore/Runner/RunnerManager.swift:199-201`)
  only standardizes, so the `/private` form must come from the extraction path (`install` → `result.path`,
  `DriverCommand.swift:66-72`). Canonicalize once with `realpath`, as `KeepAliveSessionStore.swift:85-91` does.

### M21 — runner-install-silent-without-bundle
- Component: cli. Severity: contract.
- Rows: EXTRA-03 [cli].
- Expected: README's `GRANTIVA_RUNNER_HOME` row says `runner install` warns when the bundle does not carry the installed
  runner. With no bundle beside the binary at all, that is not carried either.
- Actual: with a current install and no bundle, `runner install` exits 0 without a warning. A bundle from another release
  does warn (CLI-142).
- Brief: K48 incomplete (the README half and the code disagree).
- Suspected cause: `Sources/GrantivaCore/Runner/RunnerManager.swift:157-162`, where `bundleMismatchWarning()` returns nil
  when `resourceBundle` is absent ("nil when the bundle matches or is absent"). Either warn, or reword README to "a bundle
  from another release".

### M22 — build-build-advertises-headless
- Component: cli. Severity: docs.
- Rows: EXTRA-06 [cli].
- Expected: `build build` never resolves or boots a device (docs/android.md), so its help does not offer device-boot options.
- Actual: `build build --help` lists `--headless` ("Boot an emulator without a window (Android)").
- Brief: K54 and K27 extend (help hygiene).
- Suspected cause: `Sources/GrantivaCLI/BuildCommand.swift:28` includes `@OptionGroup var target: TargetOptions`, which
  carries `--headless` (`TargetOptions.swift:36`). Split the target options or hide `--headless` on `build build`.

### M23 — internal-plan-doc-ships-stale-versions
- Component: docs. Severity: docs.
- Rows: B-D05.1 [cli].
- Expected: no shipped file claims a version other than 2.1.0 (D05 criterion as narrowed after CHANGELOG.md was removed).
- Actual: `docs/plans/v2-swift-native-runner.md` (c65fc17), titled "v2.0.0 — Swift-Native Runner" and marked "Status:
  Proposed", presents 2.0.0 as an upcoming cutover and cites 0.9.0, 1.0.0, 1.0.1 and 1.1.0 as the releases of "this session".
- Brief: D05 extends.
- Suspected cause: an internal planning note under the public `docs/`. Move it out of `docs/`, or mark it as a historical
  note.

### M24 — test-suite-runner-home-guard-missing
- Component: cli (tests/CI). Severity: contract.
- Rows: B2-K107-b [cli].
- Expected: tests take an injectable lease directory (met), the full suite leaves an empty `GRANTIVA_RUNNER_HOME` empty, and a
  guard test or CI step enforces it.
- Actual: no guard test (no `TestHygieneTests` or equivalent under `Tests/`), and `ci.yml` runs plain `swift test`. The QA
  runner home holds 674 `FAKE-`/`TEST-REPORT-` lock files dated 2026-10-10, before this binary, so a leak cannot be ruled out.
  Criterion 2 needs a `swift test` run, which no slice did.
- Brief: K107-b incomplete (criterion 3).
- Suspected cause: criterion 3 was not implemented. Add the CI step (`GRANTIVA_RUNNER_HOME=$(mktemp -d) swift test` followed by
  an emptiness check) to `.github/workflows/ci.yml`.

### M25 — withdrawn (crash on launch detected at the first assert)
- Rows moved to §Expectation corrections: AND-107, AND-040, B-A01.1 and B-R01.3 were re-graded `fail (matrix/brief error —
  triage)` in fix round 1. Their expected text should read "fails with app_crash at launchApp or at the first step after
  it", which is the outcome B2-L02 requires.
- The fix-round 99-crash re-run once **missed** the crash: run 2 reported a plain `assertion` 12.2 s after `am_crash`. That
  is recorded under L02 and L06 in §Carried open items, not here.
- The cause notes stay as background for L02: `confirmLaunch` settles after 1 s alive
  (`pkg/driver/uiautomator2/commands.go:1566-1630`).

### M26 — android-doubletap-registers-as-two-taps
- Component: runner. Severity: wrong-result.
- Rows: AND-210 [android].
- Expected: `doubleTapOn: {id: "gesture-pad"}` gives `Double taps: 1`, `Taps: 0` (README:172; round 1 did).
- Actual: the step passes in 1.4 s but registers two single taps, 3 of 3 runs (`Double taps: 0`, `Taps: 3`), at load 9-19
  on the software AVD.
- Brief: new. The command shares the UIAutomator2 robustness family of K06-K09.
- Suspected cause: `pkg/uiautomator2/gestures.go:51-57` sends the server's `/appium/gestures/double_click`. On a slow
  software-rendered AVD the two clicks probably land further apart than the double-tap timeout (~300 ms). Not confirmed:
  there is no pointer trace. A fix would send one W3C `/actions` sequence with an explicit short inter-tap gap. Re-run on a
  quiet host first (§Load-sensitive).
- **Confirmed on a quiet host** (fix round 1, load 5-13): two single taps in 3 of 3 runs.

### M27 — android-doubletap-point-only-selector-rejected
- Component: runner. Severity: wrong-result.
- Rows: AND2-OBS-01 [android].
- Expected: README lists `point:` for taps, so `doubleTapOn: {point: "50%,50%"}` double-taps the point, as `tapOn {point}`
  taps one.
- Actual: the step fails at once with `Element not found: selector (cause: no selector specified)`.
- Brief: new.
- Suspected cause: `pkg/driver/uiautomator2/commands.go:155` calls `findElementForTap` before the point branch at `:163`.
  A point-only selector has nothing to find, so the step fails before reaching `DoubleClick(x, y)`. Handle a point-only
  selector first, as `tapOn` does.

### M28 — android-scrolluntilvisible-short-scrolls
- Component: runner. Severity: wrong-result.
- Rows: AND-224 [android].
- Expected: `scrollUntilVisible {element: "Landmark 70", direction: DOWN}` finds it (README:172; round 1 passed).
- Actual: fails 2 of 2 with `Element not found after 20 scrolls` (49.8/52.2 s). The last hierarchy reaches only Landmark 55.
- Brief: L03 extends. L03 made bare `scroll` device-independent with a measured top-up. `scrollUntilVisible` was not
  covered.
- Suspected cause: `pkg/driver/uiautomator2/commands.go:1019-1055` scrolls each step with `performScrollInRect` /
  `performScroll` at a 0.3 fraction and no measured top-up. On the software AVD a gesture moves the content less, so 20
  scrolls fall short of row 70. Apply L03's measured-travel plan here, or count progress instead of scrolls.
- **Confirmed on a quiet host, flaky** (fix round 1, load 8-11): run 1 fails after 20 scrolls (53.5 s); runs 2-3 find
  Landmark 70 (26.2/17.5 s).

### M29 — android-force-teardown-leaves-killed-run-temp-dirs
- Component: cli. Severity: ux.
- Rows: B2-K106 [android].
- Expected: after `kill -9` of a run, a forced teardown removes the run's temp dirs and lists them (K106).
- Actual: `emulator teardown --serial emulator-5556 --force --json` kills the emulator (`killed: true`,
  `runnerSessionStopped: false`), but both temp dirs stay (`grantiva-96934240-…`, `grantiva-report-E0C92521-…` under
  `$TMPDIR`), and the JSON lists no removed paths. iOS passes (B2-K106 [ios]).
- Brief: K106 incomplete (Android).
- Suspected cause: only `SimulatorReaper` removes the claim's temp dirs (`Sources/GrantivaCore/Simulator/SimulatorReaper.swift:216`,
  `:247`). `EmulatorManager.teardown(serial:force:)` (`Sources/GrantivaCore/Android/EmulatorManager.swift:590`) has no
  equivalent, and its outcome has no `temporaryDirectoriesRemoved` field.

### M30 — android-foreground-runner-start-stop-exits-1
- Component: cli. Severity: contract.
- Rows: N2-15 [android]. Also cited by M31.
- Expected: a foreground `runner start` ended by `runner stop` from another shell prints `Runner stopped …; the session has
  ended.` and exits 0, as on iOS (N2-15 [ios] pass; K88).
- Actual: Android prints `Error: The runner exited with status 1; the session has ended.` and exits 1. Cleanup is correct.
- Brief: K88 incomplete (Android).
- Suspected cause: `Sources/GrantivaCLI/DriverCommand.swift:519-521` with `isOrderlyRunnerExit` (`:544-546`), which accepts
  0, SIGINT, SIGTERM, SIGKILL and 128+INT/TERM only. The Android runner exits 1 when stopped. Not located on the runner
  side: either the runner's Android shutdown should exit 0 on SIGTERM, or the CLI should treat a stop it requested as
  orderly (for example, by checking that the session file was removed by `runner stop`).

### M31 — sigint-narration-says-simulator-on-android
- Component: cli. Severity: ux.
- Rows: AND2-OBS-04 [android] (also seen in N2-15 [android]).
- Expected: the interrupt notice names the device kind: `releasing emulator` on Android, as the keep-alive `run` says.
- Actual: foreground `runner start` on Android prints `[grantiva] received SIGINT — releasing simulator and reaping child
  processes`.
- Brief: K04 and K11 extend (Android labelled as iOS).
- Suspected cause: `SignalRelay.shared.deviceNoun` is set only in `Sources/GrantivaCore/Runner/RunnerExecution.swift:106` (the
  run path). The `runner start` path in `DriverCommand.swift` never sets it, so it keeps the default `simulator`.

### M32 — android-runner-start-readiness-not-reported
- Component: cli and mcp. Severity: contract.
- Rows: B2-K100.2, D2-44, AND2-OBS-03 [android].
- Expected: while `runner start` is still bringing the driver up, MCP reads answer `-32002` with `The runner session is
  starting … Retry in a few seconds.` (docs/mcp.md:19; K100). `runner start --detach` "returns once the driver is up"
  (help).
- Actual:
  - During a 7.9 s Android start, `resources/read` of both URIs answers `-32002` `No active runner session at
    <dir>/.grantiva/session.json. Start one with …`, never the "starting" text. iOS passes.
  - Separately, one `runner start --detach` returned after 1.5 s (B2-K79/03), and `hierarchy` / `runner dump-hierarchy`
    then failed for ~15 s (`No active runner session`, `not answering on local port 62675`). Other starts returned after
    4.7-7.9 s, ready.
- Brief: K100 incomplete (Android). The OBS-03 half is new.
- Suspected cause: the "starting" state exists only for WDA: `Sources/GrantivaCore/WDA/WDAClient.swift:363-368`
  (`sessionStartingMessage`). There is no Android counterpart, and `.grantiva/session.json` seems to be written only once
  UIAutomator2 is ready. The `--detach` readiness check (`DriverCommand.swift`, `WDAStartup` at `:551`) is WDA-oriented, and
  an early return on Android was not traced. The early return may be load-dependent (load 10.3).
- **Detach half: intermittent, unconfirmed.** The fix round did not reproduce it in 0 of 3 runs (`--detach` returned after
  4.7-5.9 s, and the first dump answered 0.4-1.5 s later). Keep it as a single sighting. The K100.2/D2-44 half (no
  "starting" text) is logical and stands.

### M33 — build-install-skipped-omits-apppath
- Component: cli. Severity: contract.
- Rows: D2-07 [android].
- Expected: README (c65fc17 :258-263) lists `appPath` for every Android `build install --json` document.
- Actual: `launched` and `installed` carry `applicationId, appPath, device{name, serial}`. `--no-build --no-launch` gives
  `status: skipped` without `appPath`.
- Brief: new (D2 contract row).
- Suspected cause: `Sources/GrantivaCLI/BuildCommand.swift:202/210` pass `appPath: productPath`, which is `nil` when nothing
  was built or resolved (`appPath: String?` at `:308`/`:324`; `skipped` at `:260`). Either resolve the installed APK's path,
  or say in README that `skipped` omits it.

### M34 — android-hierarchy-frame-values-are-strings
- Component: cli. Severity: contract.
- Rows: D2-31 [android].
- Expected: docs/dump-hierarchy.md:30: `frame` is `{x, y, width, height}` with numbers, the same tree from `hierarchy
  --format json`, `runner dump-hierarchy --format json` and `grantiva_a11y_tree`.
- Actual: Android gives the same tree from all three, but every `frame` value is a JSON string (`"height" : "50"`). iOS
  passes.
- Brief: K99 extends. K99 was iOS-only and noted that string frames "may be tracked separately". The round-2 docs now promise
  numbers for all platforms, so the Android half is a defect, not an open question.
- Suspected cause: `Sources/GrantivaCore/Android/UIAutomator2HierarchyParser.swift:69-70`, where
  `func dp(_ px: Int) -> String` returns `String(...)`. Return an `Int`.

### M35 — android-unknown-variant-lists-no-variants
- Component: cli. Severity: ux.
- Rows: B-A09.2 [android].
- Expected: for an unknown variant or module, "ideally also list the available ones" (brief A09 criterion 2).
- Actual: the error only adds "`./gradlew tasks --all` lists the assemble<Variant> tasks of each module".
- Brief: A09 criterion 2 (an "ideally" criterion) not met. Low priority, or close by ruling.
- Suspected cause: `Sources/GrantivaCore/Android/GradleBuildRunner.swift:115` gives the pointer only, without running
  `./gradlew :<module>:tasks` to list the variants.

### M36 — native-config-id-selector-raw-decodingerror
- Component: cli. Severity: ux.
- Rows: B-C08.2 [android].
- Expected: the native `screens:` step gains an id-selector form (for example `tap: {id: X}`) for tap, assertVisible,
  assertNotVisible, scrollUntilVisible and extendedWaitUntil (brief C08 criterion 2).
- Actual: `tap: {id: "clock"}` / `assert_visible: {id: …}` in `grantiva-android.yml` fails to parse with a raw decoder
  dump: `grantiva-android.yml could not be parsed: DecodingError.keyNotFound: Key 'text' not found … Path:
  screens[0].path[2].tap` plus `unknown key "id"`. The iOS half passed through the flow-format config path, which does carry `id`.
- Brief: C08 criterion 2 incomplete. The native form was never added, and the raw error is a K-series ux defect of its own.
- Suspected cause: only the flow-format parser (`Sources/GrantivaCore/Config/`, the `tapById` setter at line 499) sets `tapById`. The native `Step` decoding in
  `Sources/GrantivaCore/Config/GrantivaConfig.swift` has no `{id}` form, and `:317/:337/:350` interpolate the raw
  `DecodingError` (`\(error)`). This is probably platform-neutral: an iOS `grantiva.yml` with the native `{id}` form should
  fail the same way (not run).

### M37 — android-session-json-names-differ-from-runner-start
- Component: cli. Severity: contract.
- Rows: B2-K103 [android].
- Expected: `runner start --json` and `.grantiva/session.json` name the bundle the same way (K103 criterion 1). iOS passes:
  `bundleId` in both.
- Actual: Android `runner start --json` says `applicationId` (+ `bundle_id`) and `port`. `.grantiva/session.json` says
  `bundleId` and `wdaPort` (AND-082/01, AND-126/02).
- Brief: K103 incomplete (Android). Related to M06, but a different writer.
- Suspected cause: `Sources/GrantivaCore/Runner/RunnerSessionInfo.swift:6-18` stores and encodes `wdaPort` / `bundleId`
  for both platforms. Encode the platform's names (`applicationId`, `port`) for Android, keeping the old keys readable.

### M38 — screens-capture-before-app-renders
- Component: cli. Severity: wrong-result.
- Rows: N-12, AND2-OBS-02 [android].
- Expected: a launch-only screen is captured after the app has drawn. Session and CLI captures of the same screens pass
  `diff compare` against each other (N-12).
- Actual: while the default AVD was slow, the CLI capture of the launch-only `Home` screen is blank (status bar only,
  ~20 KB). This happened in AND-108, the stock `run` screens, N-12 and the flow-format `Home Swiped`, so N-12 fails
  `pixel=99.90%`. Session captures show the list, and once the emulator sped up, Home was 122 KB (B-A04.1).
- Brief: new. Related to M17: the settle wait is fooled by a static screen.
- Suspected cause: `Sources/GrantivaCore/Runner/FlowGenerator.swift:133-134` and `:215-217`. Before `takeScreenshot`, the
  generated flow's only wait is `waitForAnimationToEnd` (timeout 5000), which returns as soon as two screenshots match. A
  blank pre-render screen is static, so it "settles" at once. A launch-only screen needs an app-drawn condition, such as
  waiting until the hierarchy contains the app's package, or a minimum delay after `launchApp`.
- **Confirmed on a quiet host** (fix round 1): the launch-only Home is blank in 3 of 3 captures (19.3 KB).

### M39 — mcp-emulator-boot-reports-reuse-as-boot
- Component: mcp. Severity: ux.
- Rows: AND2-OBS-05 [android].
- Expected: like the CLI after K12/K29, a reuse of an already running AVD is reported as `Using`/`Reused`, not as a boot.
- Actual: `grantiva_emulator_boot` answers `Emulator booted: cov2-android (emulator-5554)` for an AVD that was already
  running.
- Brief: K12 and K29 extend (MCP twin).
- Suspected cause: `Sources/GrantivaMCP/Tools/EmulatorTools.swift:103` always says "booted". Use the boot outcome's reuse
  flag, as the CLI does.

### M40 — emulator-teardown-loses-recently-installed-app
- Component: cli. Severity: wrong-result.
- Rows: AND2-OBS-06 [android].
- Expected: `emulator teardown --serial` shuts the emulator down without losing the data partition. An app installed before
  the teardown is still installed after the next `ensure`.
- Actual: `com.kylebrowning.landmarks` was listed before teardown and missing after `ensure` (AND-113/03). AND-029/01 and
  AND-115/01 then failed with `… is not installed`.
- Brief: new.
- Suspected cause: not located. `EmulatorManager.teardown` (`Sources/GrantivaCore/Android/EmulatorManager.swift:590-630`)
  ends the emulator with `adb emu kill` (or a kill after `killTimeout`). Boots use `-no-snapshot-save` (`:229`). A kill
  before the guest flushes userdata would lose a recent install. Check whether teardown escalates to a kill, and add `adb
  shell sync` or a graceful `reboot -p` before `emu kill`.
- **Confirmed on a quiet host** (fix round 1): an app installed 5 s before `teardown` is gone after the next boot (1 of 1).

### M41 — focused-element-lookup-unbounded-under-load
- Component: runner. Severity: wrong-result.
- Rows: AND-213 [android].
- Expected: `inputText " · Ünïcødé ✓"` types the text within its step timeout, as runs 2-3 and the fix-round re-run do (3 of 3,
  1.5-2.4 s, `GET /element/active` 170-192 ms at load 7-10).
- Actual: 1 of 3 original runs (load 68 at start) failed: `✗ inputText … (48.0s)`, `did not answer POST /actions within
  10s`.
  - client.log: the step spent 35.5 s on `GET /element/active` (404, no focused field). That left only the 10 s minimum for
    `POST /actions`, which was cut.
  - AND-120/01 shows the same pattern after a 25.7 s lookup.
  - With `active` = 404, the timeout recovery had no field to read.
- Brief: new. This is not L01: the fix round re-graded B2-L01 to pass because no call was cut at 10 s while its step still
  had time. It sits next to L05, the other slow first-lookup on the software AVD.
- Suspected cause: `pkg/driver/uiautomator2/commands.go:421`. `d.client.ActiveElement()` runs under the step's whole
  deadline (`requestDeadline`, `pkg/uiautomator2/transport.go:82-99`) with no bound of its own, so a slow lookup spends the
  step's budget before typing starts. Fix direction:
  - cap the lookup (a few seconds) and fall back to key events without the before-text, or
  - reserve part of the step deadline for `/actions`.
- Status: load-only. The original failure was at load 68, and the quiet-host re-run passed 3 of 3. Write the brief with the
  load condition as its repro.

### M42 — uia2-session-start-fixed-30s-no-retry
- Component: runner (limit) and cli (message). Severity: ux.
- Rows: AND2-OBS-07 [android].
- Expected: starting a UIAutomator2 session on a busy host either succeeds, retries, or fails with a limit the user can raise.
- Actual:
  - `runner start --detach --json` failed with `Timed out waiting for the UIAutomator2 session to start` (runner log
    `UIAutomator2 server not ready after 30s`, load 76, AND-126/01).
  - The first stock run hit the same 30 s limit (AND-106/01, load 98).
  - The limit is not configurable, and the run gives up rather than retrying.
- Brief: new.
- Suspected cause: `pkg/device/uiautomator.go:270-280` (`waitForUIAutomator2Ready(timeout)`, called with a fixed 30 s). The
  CLI reports it at `Sources/GrantivaCLI/DriverCommand.swift:363` and `:455`. Make the limit follow `--timeout`, or add a
  retry before giving up.
- Status: load-only (load 76-98). Not seen at the fix round's load of 5-13.

## Expectation corrections

Row text cites README/brief lines that were checked at c65fc17 where noted.

| row | slice | slice's argument | recommendation |
|---|---|---|---|
| CLI-003 | cli | 170/172 help pages are byte-identical. `runner_stop` and `simulator_teardown` differ only by the L04 (#198) sentences added after the corpus was regenerated (7593fab) | correct the matrix (regenerate `findings/help` at c65fc17) |
| D2-47 | cli | 15/17 pages match. The same two pages differ for the same L04 reason as CLI-003 | correct the matrix (same corpus regeneration as CLI-003) |
| CLI-011 | cli | the row's `select(.status == "fail")` filter is stale. Statuses are ok/warning/error, and README:439 now uses `"error"` (K62) | correct the matrix |
| CLI-025 | cli | `run` errors correctly. `doctor` in a dir with both Xcode and Gradle reports `● Platform Found both…` under Advisory and exits 0, which is brief C12's allowed alternative (B-C12.1). The row's "exits non-zero" contradicts it | correct the matrix (C12's alternative is the ruled behaviour; doctor's advisory checks never fail the exit code after K35) |
| CLI-038 | cli | the empty or comments-only config is rejected before any build with `Error: No screens or flows configured in grantiva.yml`. The row expects an `Invalid argument:` label, which `RunCommand.nothingToRunMessage` (shared with the K52 sentence) deliberately omits | correct the matrix (K52 wording supersedes) |
| CLI-083 | cli | half the input could not be produced. "No booted simulator" is impossible while the iOS slice's and the user's simulators are booted. The advisory-and-exit-0 part holds for the checks that could be produced | not a matrix or brief error: a blocked half. Re-run the no-booted-simulator half (see §Blocked, with B-C21.1) |
| CLI-085 | cli | prints `grantiva-runner 1.1.28-grantiva.11`, the runner bundled with c65fc17 (#199). The row expects `.9` | correct the matrix (version literal follows the bundled runner) |
| N2-02 | cli | same `.10` vs `.11` literal. The row also says "none [prints the installed stamp] today", but doctor's Runner check and `runner install` do print `1.1.28-grantiva.11+android-drivers-2` | correct the matrix (version literal and the "none does today" clause) |
| CLI-087 | cli | the no-session message now uses backticks and has no `Invalid argument:` label (K46). The row quotes the pre-K46 text | correct the matrix |
| CLI-143 | cli | `record --duration 0` exits 64 with the usage line, because K41 moved range checks into validation (B2-K41 expects exactly this). The row expects exit 1 with `Invalid argument:` | correct the matrix |
| CLI-145 | cli | the other-platform rejections now use the shared long form (K43), and `--device`/`--emulator` reads `… mutually exclusive; pass one.` The row quotes the old texts | correct the matrix (the exit-1 vs exit-64 inconsistency for `--device`/`--emulator` is a product defect filed as M19) |
| CLI-161 | cli | README:98 now says `<runner home>/versions/<stamp>/devices/<udid>` and explains `<stamp>` (K63), matching the disk. The row's literal `<runner version>` is stale | correct the matrix |
| B-C18.1 | cli | the missing-config texts are now `GrantivaConfig.missingFileMessage` (`grantiva-android.yml not found at <path>. Create one with grantiva init --platform android.`), which meets the intent (file, location, init command). The criterion quotes C18's older `No grantiva-android.yml here. …` | correct the brief (C18 criterion 1 → K52 wording) |
| IOS-122 | ios | with `GRANTIVA_SESSION_ID` unset, a run on a device owned by session cov2-ios is refused with guidance, which is what README "Simulators Grantiva created" documents after K70. The unowned half (cov2-ios-3) passes | correct the matrix (row input must be an unowned, simctl-booted device) |
| IOS-145 | ios | the README Local Workflow runs as written. The first `diff compare` exits 1 with `? No baselines: 5 new screens` per K89 and the current README. The row's "all three succeed" predates K89 | correct the matrix |
| MCP-025 | ios | `[{bogus:1},5]` is rejected as expected. The 5-step script stops at `type "x"` because no field is focused (the round-1 K102 fix), so "returns the final tree" cannot hold on Gesture Lab | correct the matrix (drop the `type` step or precede it with a tap on a text field) |
| N-01 | ios | `runner stop` releases a `run --keep-alive` session fully. The ready file stays `passed` because it was written at the flows' terminal state, and README:83 and :419 say it is written once and keeps `passed`/`failed` | correct the matrix (`interrupted` applies only when the stop lands before the flows finish) |
| B2-K14 | ios | same as N-01. The K14 criterion asks for the ready file to read `interrupted` after a stop that follows completed flows | correct the brief (K14 criterion: ready file unchanged once terminal; `interrupted` only if stopped mid-flow) |
| B2-K68 | ios | free UDID: `reclaimed:false, leaseReleased:false` (bullet 1 met). After `kill -9` of a keep-alive, `reclaimed:true` with WDA and diagnose killed, but `leaseReleased:false`. Bullet 2 asks for `true`, while bullet 3 says `true` only when the flock is held or the claim is live | correct the brief. See the judgment below |
| AND-107, AND-040, B-A01.1, B-R01.3 | android | re-graded in fix round 1 (was M25). `launchApp` passes and the first assert fails with `app_crash` and `LANDMARKS_CRASH_ON_LAUNCH`; no step passes against the dead app. The rows (brief R01 criterion 3, A01 criterion 1) expect the failure at `launchApp`, while B2-L02 requires the first-assert outcome | correct the matrix and the R01/A01 criteria: "fails with app_crash at launchApp or at the first step after it". The one missed crash in the re-run (a plain `assertion`, run 2) is a product defect under L02/L06, not part of this correction |
| AND-223 | android | four bare scrolls land with Landmark 28 as the last row (20-28 visible). N-03/B2-K07 were corrected to `Landmark 28` for Android (00-expectation-corrections.md:16, landmarks-demo flow asserts 28 and passes). This row still expects `Landmark 30` | correct the matrix (apply the N-03 correction to AND-223) |
| MCP-026 | android | steps 1-4 run in order, then step 5 `type "x"` stops with isError `No focused text field …`, listing the steps that ran. That is the K102/D2-37 behaviour; the row still expects the final tree. The invalid-script half passes | correct the matrix (same fix as MCP-025: drop the `type` step or focus a field first) |

**B2-K68 judgment.** The contradiction is real but conditional. When K68 was written, K79 was open: the runner outlived
its killed grantiva and kept the lease's flock through its inherited descriptor. In that world, bullet 3's rule ("held:
flock held by another process, or a live claim") gave `leaseReleased: true` after `kill -9`, so bullets 2 and 3 agreed. The
K79 fix makes the runner exit with its killed parent. Nothing then holds the flock, and the claim names dead pids, so it is
stale. `SimulatorLease.isHeld` (`Sources/GrantivaCore/Runner/SimulatorLease.swift:374-381`) correctly reports false, and
`forceRelease` (`:341-345`) returns that. The observed `reclaimed: true` is right: processes were killed
(`SimulatorReaper.swift:73`). Bullet 3 states the field's contract (`SimulatorReaper.swift:43-47`), so bullet 2 should change
to: after `kill -9` of a `run --keep-alive`, `reclaimed: true` (the orphaned WDA/diagnose are reaped); `leaseReleased` is
true only if the runner still held the lease when teardown ran. Not a product defect.

## Blocked

| row | slice | reason | re-run feasible? |
|---|---|---|---|
| CLI-048 | cli | relative and missing `run_flow` resolution happens after device resolution (fake UDID) | resolved: taken by the iOS slice, pass |
| CLI-049 | cli | cycle check after device resolution | resolved: iOS slice took it, `fail` → M13 |
| CLI-061 | cli | staged-flow label only visible with a device | resolved: iOS slice, pass |
| CLI-064 | cli | emitted `id:` selector only visible with a device | resolved: iOS slice, pass |
| CLI-066 | cli | bare `scroll`/`scroll {direction: up}` swipe only visible with a device | resolved: iOS slice, pass |
| CLI-153 | cli | README Quick Start `init` resolves its default to the user's `iPhone 18 Pro`, so the row stops before `runner install`/`ci run` (Global Constraint) | yes, once M01/K37 gives `init` a Grantiva-specific default, or on a host with no stock-named iPhone 18 Pro. Alternatively, create a Grantiva-owned simulator of that name in a scratch HOME (needs owner approval) |
| CLI-083 (half) | cli | "no booted simulator" doctor state needs every simulator shut down | yes, in a window when no slice and none of the user's simulators is booted. Batch it with B-C21.1 |
| B-C21.1 | ios | `simulatorNotRunning` and doctor no-simulator advice need no booted simulator. The user's booted iPhone 17 Pro and 18 Pro rule that out. The reachable part (the hierarchy hint) holds | yes, same window as CLI-083. Needs the owner to shut their simulators down, or a host with none booted |
| IOS-018 | ios | `created.json` lists devices from other sessions (TienLen, BLESwift, fix-8-*, fix2-13-*), so `simulator cleanup` would delete them | yes, with a scratch `GRANTIVA_RUNNER_HOME`/HOME whose ledger holds only `cov2-*` devices, or after the owner prunes the ledger |
| B-I06.2 | ios | the HTTP request `grantiva_type` sends to WDA (`/wda/keys`) is logged nowhere, and `grantiva mcp` has no `--verbose` | yes, by a source check (MCP driver's type path) or a logging proxy in front of WDA's port. No product change needed to verify |
| N-08 | ios | whether grantiva reads the runner's developer install dir in HOME cannot be observed without root (`fs_usage`/`opensnoop`) | partly: a source grep for the path in both repos settles "never reads" statically. A dynamic check needs sudo, which only the owner can grant |
| AND-002 | android | the install half needs a small uninstalled system image (downloads are 1 GB+). The sdkmanager error path is clean (B2-K31) | yes, on a host with bandwidth and disk for one image download, or with a deliberately uninstalled small image. Owner's call |
| AND-012 | android | Global Constraints forbid `emulator teardown --all` while other AVDs (the owner's `Pixel_8_API_35`) may be running | yes, only on a host or window where every running emulator is Grantiva-created for the campaign, or with a scratch ledger. Needs owner approval |
| AND-088 | android | no credentials in the campaign (spec §Out of scope) | no, not within the campaign's scope. Needs a test API key |

## Carried open items

The Android rows below verify briefs that are still open at runner 1be68db / CLI c65fc17. They are placed here, not in
clusters, and feed the existing briefs' next fix. Fix-round outcomes (load 5-13) are included.

- **L01** (Android inputText cut by a fixed 10 s request timeout). **Rows: none (B2-L01 re-graded pass in fix round 1).**
  - 03-edit passes 3 of 3 alone (inputText 12.8/21.0/15.9 s; `/actions` completed after 8.2-15.1 s and was not cut) and
    inside the stock set.
  - The two 10 s `/actions` cuts (CF-15-input-unicode, AND-120/01) followed a 35.5 s / 25.7 s `GET /element/active` that had
    used up the step budget. No call was cut at 10 s while its step still had time, so L01's criteria hold.
  - AND-213 moved to M41.
  - Still worth checking under L05: the three `POST /element` calls each cut at 10.00 s at the start of CF-15-input-unicode
    (10:30:12-42).
- **L02** (Android crash check stalled by a blocked find; assert can pass on the dead app). Rows: B2-L02, N2-13 [android].
  - Original run: 99-crash fails 3 of 3 at `assertVisible "Landmarks"` with `app_crash`, 0.7-1.9 s after `am_crash`, but the
    timing criteria are missed (assert step 5.6-6.0 s, flow 16.2-19.2 s, wall 31.4-32.3 s).
  - **Fix round 1, new evidence that the crash check can still miss** (load 5.7-10.4, fresh default AVD, B2-L02/rerun):
    - run 1 `app_crash` 0.5 s after `am_crash` (step 7.1 s);
    - **run 2 `error.type: assertion` (`Element not visible: text='Landmarks'`) 12.2 s after `am_crash`, step 19.2 s: the
      crash was not recognised at all;**
    - run 3 `app_crash` 3.6 s after (step 11.0 s).
    - Not within ~2 s in 2 of 3 runs; assert step > 3 s, flow > 6 s (22.7-30.7 s) and wall > 12 s (54-57 s) in all 3.
    - Run 2 breaks L02's criteria 1 and 3 outright (a crash reported as not-visible), which is worse than slow detection.
  - N2-13 [android]: `extendedWaitUntil {visible: "Landmarks", timeout: 15000}` passed against the crashed app (13.2 s; it
    matched the launcher's label), which breaks L02 criterion 4. The re-run's 99-crash part repeats the run-2 miss.
  - The 4 rows that expected the failure at `launchApp` are now expectation corrections (old M25).
- **L05** (Android first find after `launchApp` blocks 5-10 s). Row: B2-L05 [android].
  - Original run: first `tapOn "Deep Links"` 9.1/10.8/8.5 s, first `POST /element` (404) 6.33/6.05/5.95 s, 99-crash wall
    31.4-32.3 s.
  - **Confirmed on a quiet host** (fix round 1): first `POST /element` 8.6/6.9/6.5 s and first `tapOn` 12.4/9.6/9.2 s, so the
    slowness is the software-rendered AVD, not host load.
  - Load section: AND2-OBS-07 (UIAutomator2 session start timing out at 30 s at load 76-98) is filed as M42; consider
    folding it into L05's next fix, since both are slow-AVD start-up paths.
- **L06** (page-source selectors check for a crash only between attempts). Row: B2-L06 [android].
  - Original run: the (a) `index: 1` scratch variant passed both steps 3 of 3 against an app that never came up. (b)
    `below:` and (c) `width:` failed with `app_crash` 1.8-4.0 s after `am_crash`.
  - **Fix round 1 with the matrix's variant** `{text: "Landmarks", index: 0}`, 3 runs at load 9.6-10.8: it never passes.
    Each assert started before the crash and failed with `app_crash` 2.0/1.6/3.8 s after `am_crash`, so 1 of 3 is outside
    ~2 s.
  - The earlier `index: 1` pass came from a scratch variant whose `.*` text matched launcher content. Under L06's "no match
    after death" criterion it remains a defect sighting.
  - The L02 run-2 miss above (a plain `assertion` 12.2 s after the crash) is also L06 evidence: the crash check between
    attempts can miss a death entirely.
- **L07** (Android element swipe flaky under load). Rows: B-A02.2, B-R02.1, B2-K09, N2-17 [android].
  - The far-side start (~x=250 px) and edge end are as documented.
  - The row opens in 5 of 10 runs at load 10-13, and **7 of 10 in fix round 1**. Confirmed open.
  - Still `adb input swipe` (B-R02.5 source check).
- **K111** (Android `record` overrun never trimmed). Rows: B2-K111, N2-01 [android].
  - **Confirmed by ffprobe** (fix round 1): the kept AND-079 `--duration 3` mp4 is 5.662756 s, untrimmed.
  - The overrun is intermittent: 12 new 3 s recordings and the 5 × 4 s repro all measured exactly the requested length.
  - At c65fc17, `MP4LastFrameHold.swift` has no trim. Open.
- **Deferred minor: `holdTrack` with a malformed extra track** → N2-20 `fail` [cli], filed as M18.
- **Deferred minor: SIGHUP under nohup** → N2-18 `fail` [ios]. The runner dies on SIGHUP (M04), and teardown then leaves its
  session file (M05). The first half of N2-18 holds.

## Load-sensitive

Fails whose evidence pointed at host load or a slow software-rendered AVD, with the fix-round 1 outcome (fresh default AVD,
load 5-13). The original Android run saw load from about 10 to 394, with the AVD slow until about 12:50. Logical clusters
are not listed.

**Confirmed on a quiet host** (write the brief from the re-run evidence):

| rows | cluster / brief | original | fix round 1 |
|---|---|---|---|
| AND-210 | M26 | two taps, 3 of 3 (load 9-19) | two taps, 3 of 3 |
| AND-224 | M28 | 2 of 2 fail (load 6-11) | 1 of 3 fail (flaky) |
| N-12, AND2-OBS-02 | M38 | blank Home (load 14-41, slow period) | blank Home, 3 of 3 (19.3 KB) |
| AND2-OBS-06 | M40 | app lost after teardown (load 9.5) | reproduced, 1 of 1 |
| B-A02.2, B-R02.1, B2-K09, N2-17 | L07 | row opens 5 of 10 (load 10-13) | 7 of 10 |
| B2-L05 | L05 | first find 6-11 s | 6.5-8.6 s, first tapOn 9.2-12.4 s |
| B2-L02, N2-13 | L02 | slow detection | slow, plus one missed crash (run 2) |
| B2-L06 | L06 | (a) scratch `index: 1` passes | matrix variant: `app_crash` 1.6-3.8 s, 1 of 3 outside ~2 s |
| B2-K111, N2-01 | K111 | 5.663 s untrimmed | ffprobe 5.662756 s; overrun intermittent (0 of 12 new) |

**Still load-only** (seen only at high load; not reproduced in the fix round):

| rows | cluster | evidence |
|---|---|---|
| AND-213 | M41 | 1 of 3 at load 68 (35.5 s `GET /element/active`); re-run 3 of 3 pass (lookup 170-192 ms) |
| AND2-OBS-07 | M42 | 30 s UIAutomator2 start limit hit at load 76 and 98; not seen at 5-13 |
| AND2-OBS-03 | M32 (detach half) | `--detach` returned after 1.5 s once (load 10.3); 0 of 3 in the re-run. Intermittent, unconfirmed |

**Resolved by the fix round:**
- B2-L01 → pass (the 10 s cuts are explained by M41).
- AND-107, AND-040, B-A01.1, B-R01.3 → expectation corrections.
- B2-K108 (Android) was not a fail, but its pass was doubtful. Fix round 1 produced the pixel-only failure line, so the pass
  stands: `pixel=75.00% exceeds threshold 2.00% (perceptual=1.4 …)`.

## Unassigned

(none)

Rows: 27 + 23 + 44 = 94; placed 94.

- **CLI (27):** 14 `fail` rows in clusters (MCP-046, B-D05.1, B2-K60, B2-K107-b, N2-19, N2-20, D2-34, EXTRA-01..07) and 13
  triage rows in §Expectation corrections.
- **iOS (23):** 17 `fail` rows in clusters (IOS-121, IOS-138, IOS-141, B2-K16, B2-K37.2, B2-K90-a, B2-K90-b, B2-K105,
  N2-03, N2-05, N2-07, N2-08, N2-13, N2-18, S2-03, D2-13, CLI-049) and 6 triage rows.
- **Android (44 = 31 `fail` + 6 triage + 7 extras), after fix round 1:**
  - 8 absorbed into existing clusters: S2-03 → M03; B2-K16, N2-07, D2-13 → M06; B2-K105 → M12; X-022, B2-K17, N2-08 → M16.
  - 13 in Android clusters: AND-210 → M26; AND-224 → M28; B2-K106 → M29; N2-15 → M30; B2-K100.2, D2-44 → M32; D2-07 → M33;
    D2-31 → M34; B-A09.2 → M35; B-C08.2 → M36; B2-K103 → M37; N-12 → M38; AND-213 → M41.
  - 10 under §Carried open items: B2-L02, N2-13 (L02); B2-L05 (L05); B2-L06 (L06); B-A02.2, B-R02.1, B2-K09, N2-17 (L07);
    B2-K111, N2-01 (K111).
  - 7 extras: AND2-OBS-01 → M27; OBS-02 → M38; OBS-03 → M32; OBS-04 → M31; OBS-05 → M39; OBS-06 → M40; OBS-07 → M42.
  - 6 triage rows in §Expectation corrections: AND-107, AND-040, B-A01.1, B-R01.3, AND-223, MCP-026.
- **Clusters:** 41 active (M01-M24, M26-M42); M25 withdrawn.
- **Split rows:** D2-34 and N2-18 are each counted once, under M08 and M04, and also cited by M07 and M05. N2-15 [android]
  is counted under M30 and cited by M31.
- **Not counted as fails:** blocked rows (CLI 6, iOS 4, Android 3, plus CLI-083's blocked half), listed in §Blocked;
  Android n/a AND-069/070; B2-L01 (now pass).
