# Round 2 coverage pass: cluster map (CLI + iOS slices)

Inputs: `cov2-cli/findings/cov2-cli-results.md` (CLI slice, tag `[cli]`) and `cov2-ios/findings/cov2-ios-results.md`
(iOS slice, tag `[ios]`). The Android slice is not finished, so this map does not cover it. Source references are CLI main
c65fc17 (`Sources/…`) and runner 1be68db (`pkg/…`). Both slices count as fails every row graded `fail` and every row graded
`fail (matrix/brief error — triage)`. `fail` rows go to clusters. Triage rows go to §Expectation corrections.
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
- Rows: S2-03 [ios].
- Expected: a run with `screens:` and `flows:` prints the per-screen and per-flow blocks plus the `Screens: …` and `Flows: …`
  lines on a failing run, as it does on a passing one.
- Actual: the screens session passed and a flow failed, and stdout was 0 bytes. Neither summary line was printed. The exit
  code was 1. The Android smoke showed the same.
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
- Rows: IOS-138, B2-K16, N2-05, N2-07, D2-13 [ios].
- Expected: README:399-403 says `runner start --json` and `runner stop --json` share one shape: `status`, `pid` and `port`
  as numbers, `platform`, `bundleId` and `udid`. README also names `runner stop` for the `bundle_id` → `bundleId` pair.
- Actual: the `stop` documents (single, multi-session `sessions[]`, `alreadyExited`) have no `port` and no `bundleId` or
  `bundle_id`. They also add `killed` (`false` next to `status: stopped`), `reaped` and `runnerPid`. README documents
  `reaped` and `runnerPid` but not `killed`. `pid` and `port` are numbers now, which is the round-1 part of the fix.
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
- Rows: B2-K105 [ios].
- Expected: the live line, nested header, report.json and the summary name the sub-flow as written (K105 Expected).
- Actual: live lines and report.json are fixed. grantiva's stdout step list still prints
  `✓ runFlow: /tmp/…/ios/.maestro/coverage/14-runflow-sub.yaml` (twice). That is the `/tmp` spelling, not the realpath.
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
- Rows: N2-08 [ios] (also seen in MCP-063).
- Expected: every step's `duration` is a positive number or `null` when the runner measured none, never `0` (README `run --json`
  duration rule, which also holds for `diff capture --json`).
- Actual: a session capture reports Home's `Launch app` with `duration: 0`.
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
| N-08 | ios | whether grantiva reads `~/.maestro-runner` cannot be observed without root (`fs_usage`/`opensnoop`) | partly: a source grep for the path in both repos settles "never reads" statically. A dynamic check needs sudo, which only the owner can grant |

## Carried open items

- **L05** (Android first find after `launchApp` blocks 5-10 s; failure capture queues behind it). Not observed: both
  finished slices are device-free or iOS. Runner 1be68db carries L01-L04 only (#20), so L05 is expected open. The B2-L05
  row is the Android slice's.
- **L06** (Android page-source selectors check for a crash only between attempts). Not observed on Android (Android slice
  pending). `confirmMatch` exists in `pkg/driver/uiautomator2/wait_crash.go:34-38` and is called from `driver.go:591,604,692`.
  Whether every page-source path (relative, index, size, tap fallback) goes through it was not verified. On iOS, the sibling
  rule holds for element waits (N2-13: `app_crash` within 7-338 ms), but `waitForAnimationToEnd` passes on a dead app → M17.
- **L07** (Android `swipe {direction, from}` flaky under load). The CLI slice's source check (B-R02.5, pass) found both
  Android drivers' swipe tests assert `input swipe 246 500 0 500 300`. The element swipe still goes through `adb input swipe`,
  which L07 asks to replace with a UIAutomator2 `/actions` sequence with a hold, so L07 is open at 1be68db. No device
  observation yet.
- **K111** (Android `record` overrun never trimmed). Not observed (Android slice pending: B2-K111, N2-01). At c65fc17,
  `MP4LastFrameHold.swift` has no trim or overrun handling (no `stts` shortening), so K111 is expected to stay `fail`.
- **Deferred minor: `holdTrack` with a malformed extra track** → N2-20 `fail` [cli], filed as M18.
- **Deferred minor: SIGHUP under nohup** → N2-18 `fail` [ios]. The runner dies on SIGHUP (M04), and teardown then leaves
  its session file (M05). The first half of N2-18 holds: a `runner start --detach` from a parent with SIGINT/SIGTERM blocked
  gets a runner whose blocked mask is 0, and that runner stops on the first signal.

## Unassigned

(none)

Rows: 27 + 23 = 50; placed 50. The 31 `fail` rows are in clusters M01-M24 (CLI 14: MCP-046, B-D05.1, B2-K60,
B2-K107-b, N2-19, N2-20, D2-34, EXTRA-01..07; iOS 17: IOS-121, IOS-138, IOS-141, B2-K16, B2-K37.2, B2-K90-a, B2-K90-b,
B2-K105, N2-03, N2-05, N2-07, N2-08, N2-13, N2-18, S2-03, D2-13, CLI-049). The 19 triage rows (CLI 13, iOS 6) are in
§Expectation corrections. D2-34 and N2-18 are each counted once, under M08 and M04, and also cited by M07 and M05.
Blocked rows (CLI 6, iOS 4, plus CLI-083's blocked half) are not fails and are listed in §Blocked.
