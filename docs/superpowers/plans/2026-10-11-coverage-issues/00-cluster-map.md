# Round 1 coverage triage: cluster map (CLI + Android slices)

Sources: cli-fails.md (41 rows), android-fails.md (54 rows), cov-ios-results.md (63 fail rows: 58 on iOS 26.0 plus 5 `@27.0` repeats; the iOS slice had no `fail (matrix/brief error — triage)` rows). Row IDs shared by two slices (N-01, N-17, X-002, X-019) carry a slice tag. CLI paths are relative to
`.worktrees/regression/Sources/`. Runner paths are in the runner repository's `.worktrees/release-round1`
checkout (ae48e34, the code bundled as 1.1.28-grantiva.9); the runner's main checkout (2f2ee31) has older line numbers.

## Clusters

### Runner

**C01 step-line-omits-selector-details** · runner · ux
- Rows: AND-207, AND-208, AND-220 (android), IOS-208, IOS-208@27.0 (ios)
- iOS: point taps print `✓ tapOn:  (1.1s)` on 26.0 and 27.0, confirming the shared Describe() cause.
- Expected: live, summary and runner-log step lines name the index, point or start/end used.
- Actual: `tapOn: text="..."` without `index`; `tapOn:  ` (empty) for `point:`; bare `swipe` for start/end swipes.
- Cause: pkg/flow/step.go:1057 (`TapOnStep.Describe` renders only `Selector.DescribeQuoted()`, ignores `Point`); pkg/flow/selector.go:358-378 (`describeParts` has no `index`); pkg/flow/step.go:1138-1143 (`SwipeStep.Describe` drops start/end). Shared flow package, so iOS is affected too.

**C02 uia2-not-visible-message-raw** · runner · contract
- Rows: X-019 (android)
- Expected: failure line names the selector (`Golden Gate.*`) and carries the `Run grantiva hierarchy ...` remediation, as on iOS.
- Actual: `Element not visible: context deadline exceeded: no such element: ... (cause: <same text again>)`, no selector, no remediation.
- Cause: pkg/driver/uiautomator2/commands.go:278 formats `%v` of the error; the WDA driver uses `selectorDesc(step.Selector)` (pkg/driver/wda/commands.go:328). The CLI remediation hint keys on the iOS wording (not located in CLI).

**C03 summary-draws-skipped-as-failed** · runner · wrong-result
- Rows: AND-OBS-11 (android)
- Expected: steps skipped after a failure are shown as skipped in the summary block.
- Actual: drawn as `✗ assertVisible (0ms)` while the totals say `3 steps skipped`.
- Cause: pkg/cli/test_unified_output.go:184-187, every non-passed command falls into the `✗` branch; no skipped symbol.

**C04 android-emulator-labelled-simulator** · runner · contract
- Rows: AND-OBS-12 (android)
- Expected: an Android emulator is named as an emulator in the per-flow header.
- Actual: `Device: ... (android 35 Simulator)`; report.json `"isSimulator": true`.
- Cause: pkg/cli/android.go:288 and :522 set `IsSimulator: info.IsEmulator`; pkg/cli/test_unified_output.go:87-88 and :360-361 append "Simulator" for any IsSimulator. (The `isSimulator` key is documented as "Simulator/emulator vs real device", pkg/core/driver.go:205, so the label is the defect; the JSON key is arguably by design.)

**C05 live-vs-summary-duration-drift** · runner · wrong-result
- Rows: N-17 (android), N-17 (ios)
- iOS: failing steps drift (12.2 s live, 12.4 s summary, 12419 ms report); flow totals differ (99-crash 17.0 s live/table vs 14.4 s summary/report).
- Expected: live step line, summary block and report.json give the same duration per step.
- Actual: 1 ms drift in 4/90 steps; 200 ms drift on a failing `extendedWaitUntil` (12.5 s live vs 12.7 s summary).
- Cause: not located (live line and summary appear to time the step at different points; the summary/report value includes post-step work).

**C06 uia2-first-screenshot-connection-refused** · runner · wrong-result
- Rows: N-06 (android)
- Expected: UIAutomator2 connects on the first capture after a fresh boot, or the run retries / fails naming the driver.
- Actual: first `diff capture` on a fresh AVD fails 3/3 with `Failed to take screenshot: ... dial unix /tmp/uia2-<serial>.sock: connect: connection refused` (or `unexpected EOF`); no retry; second capture passes.
- Cause: pkg/driver/uiautomator2/commands.go:2134 and :2376-2380 return the raw error with no readiness wait/retry after `server started`.

**C07 bare-scroll-distance-nondeterministic** · runner · wrong-result
- Rows: N-03, AND-223 (android)
- Expected: four bare `scroll`s with seed `many` reach `Landmark 30`.
- Actual: last landmark reached varies 19-49 by run, AVD freshness and `--snapshot full`; fails on fresh AVDs and always with `--snapshot full`.
- Cause: not located (scroll gesture geometry/velocity on UIAutomator2; fling distance depends on timing, which `--snapshot full` changes).

**C08 notvisible-wait-intermittent-timeout** · runner · wrong-result
- Rows: AND-228 (android)
- Expected: `extendedWaitUntil {notVisible: "Loading…", timeout: 10000}` passes once loading ends (~3 s).
- Actual: 1 in 5 runs fails after 12.5 s with `Element 'Loading…' still visible after 10s`.
- Cause: pkg/driver/uiautomator2/commands.go:2333 (notVisible poll loop); likely a stale lookup that keeps matching a cached node. Not confirmed.

**C09 swipe-from-element-wrong-geometry** · runner · wrong-result
- Rows: B-R02.1, B-A02.2 (android)
- Expected: `swipe {direction: LEFT, from: <element>}` starts at the element centre and runs most of the row width.
- Actual: trace starts at x≈241 px (element centre 155) and covers only 0-241 px of a 1080 px row; the row still opens.
- Cause: not located (UIAutomator2 swipe-from path near pkg/driver/uiautomator2/commands.go:1226; start point appears to be the element's right edge region and the distance is computed from it to the screen edge).

**C10 timeout-kill-reported-as-interrupt** · runner · ux
- Rows: AND-OBS-06 (android)
- Expected: grantiva's `Error:` line about the `--timeout` kill is the last line.
- Actual: the runner prints `Received interrupt, cleaning up...` after it, calling the timeout kill an interrupt.
- Cause: pkg/cli/test.go:954-955 prints on any signal; the CLI sends SIGINT for the timeout kill (CLI side not located).

### CLI

**C11 android-narration-names-grantivaagent** · cli · ux
- Rows: N-15, X-001 (android)
- Expected: Android narration names UIAutomator2, never GrantivaAgent.
- Actual: `Running N flow(s) in one GrantivaAgent session`, `GrantivaAgent keep-alive: session=...`, `Releasing GrantivaAgent session...`, `releasing simulator`.
- Cause: RunCommand.swift:426 (platform-blind string; also the `--keep-alive` help at RunCommand.swift:20); runner pkg/cli/keepalive.go:147, :149, :159.

**C12 boot-narration-for-running-device** · cli · ux
- Rows: AND-OBS-05 (android), EXTRA-05 (cli)
- Expected: `--device <serial>` targets an attached device (docs/android.md:36); no "Booting" line for a device already running.
- Actual: `Booting emulator: emulator-5554` for a running emulator; an unknown serial is also tried as an AVD name and announced as a boot.
- Cause: RunCommand.swift:116-124 (`bootNarration` always says "Booting <noun>: <target>"); serial-or-AVD fallback in EmulatorManager.swift:~200-225.

**C13 flow-count-includes-screens** · cli · ux
- Rows: N-16 (android)
- Expected: flow count printed once and right; screens counted separately.
- Actual: `Running 13 flow(s)...` then `Running 12 flow(s) in one ... session`.
- Cause: RunCommand.swift:390-391 (`totalFlows = (screens ? 1 : 0) + flows.count`) and the second line at :426.

**C14 runner-stop-misses-keepalive** · cli · wrong-result
- Rows: N-01 (android), N-01 (ios)
- iOS: same `No active session found.`, exit 0, keep-alive run left alive.
- Expected: `runner stop` stops a `run --keep-alive` session, or exits non-zero naming it and how to release it.
- Actual: `No active session found.`, exit 0; the keep-alive runner and its session files remain.
- Cause: DriverCommand.swift:~620-630 reads only `.grantiva/session.json` (RunnerSessionInfo.swift:14), which `run --keep-alive` does not write (KeepAliveSessionStore.swift holds that session).

**C15 emulator-teardown-leaves-runner-session** · cli · wrong-result
- Rows: AND-010 (android)
- Expected: `emulator teardown --serial` of a device with a runner session leaves no live state for it.
- Actual: emulator killed, but the detached runner keeps running and `.grantiva/session.json` still names the dead serial until `runner stop`.
- Cause: emulator teardown (EmulatorCommand.swift:~160-175) does not stop the runner or clear RunnerSessionInfo for that serial.

**C16 runner-start-json-types-and-keys** · cli · contract
- Rows: AND-126 (android), IOS-138 (ios)
- iOS: `"pid" : "64253"`, `"port" : "8235"` strings; start says `bundle_id` where session.json says `bundleId`.
- Expected: `runner start/stop --json` keys and types match siblings (numbers for pid/port; Android naming as in `build install --json`).
- Actual: `pid`/`port` are strings; Android gets iOS-named `bundle_id`/`udid`.
- Cause: DriverCommand.swift:116, :345, :419 (`"pid": "\(pid)"` string interpolation; platform-blind keys).

**C17 capture-step-durations-zero** · cli · wrong-result
- Rows: AND-108 (android)
- Expected: `diff capture --json` step `duration`s reflect the runner's timings.
- Actual: every `steps[].duration` is 0 (live-session MCP capture reports real values).
- Cause: RunnerFailureReport.swift:98-119 builds every StepResult with `duration: 0`.

**C18 deleted-report-paths-printed** · cli · ux
- Rows: AND-OBS-03 (android)
- Expected: no report paths printed for a temp report dir that is deleted at exit.
- Actual: `Reports: /var/folders/.../grantiva-report-*` and `Paths: JSON/JUnit/Allure` printed, then deleted.
- Cause: the runner prints them (runner pkg/cli/test.go:1156); the CLI passes a temp dir and removes it (RunnerSession.swift:76-93) without filtering the lines.

**C19 quiet-json-leak-runner-output** · cli · contract
- Rows: AND-137, AND-138 (android), IOS-074, IOS-152, IOS-153 (ios)
- iOS: 65-97 runner lines on stderr under `--json`/`--quiet`; IOS-074 adds that the JSON `error` says `Runner failed (exit 1); see the runner output above.`, pointing a JSON consumer at text it was told is suppressed. IOS-152/153's `--verbose` half (runner launch and `log stream` subprocess never listed) belongs with C33.
- Expected: `--quiet` silences progress; `--json` suppresses narration (README:398).
- Actual: the runner's ~68 progress lines (banner, Setup, Execution, every step, summary, Reports) still print on stderr with `--quiet`, `--json` and both.
- Cause: RunnerExecution.swift:115-126 forwards runner output to stderr unconditionally.

**C20 screens-session-failure-reporting** · cli · wrong-result
- Rows: AND-119 (android), IOS-134, IOS-135 (ios)
- iOS: failing screen `Broken` reported as flow `flow`; screens timeout `Error: Runner timed out after 30s:` with nothing after the colon; IOS-135 also leaves report.json `running` (see C80).
- Expected: a failing or timed-out screen is named; totals separate screens from flows; timeout message complete.
- Actual: failing screen `Broken` never named (`✗ Capture screens`, runner `flow`); `Screens: 3 total, 2 passed, 1 failed` mixes screens with flow screenshots; `Error: Runner timed out after 30s:` with nothing after the colon; ready file names the screens session `flow` or omits it.
- Cause: RunnerSession.swift:162 (timeout message with empty suffix); screens/flow naming in RunnerReportRewriter.swift (`stagedPathMap: [flowPath: "screens"]`, RunnerSession.swift:98) not applied to text/ready output.

**C21 run-json-reportdir-omitted-on-pass** · cli · contract
- Rows: X-002 (android), X-002 (ios)
- iOS widens it: no `flows` key; the passing run lists one entry per takeScreenshot (`01-browse-cmd-003-Home`) whose only step is `Run flow "01-browse"`, the failing run lists the flow with real steps. Slug should read run-json-shape-varies-by-outcome.
- Expected: `run --json` with `--report-dir` carries `reportDir` on pass and fail (matrix, README:383-386).
- Actual: only the failing run has `reportDir`.
- Cause: RunCommand.swift:507-508 (`RunResult` omits `error` and `reportDir` on success by design). Shared code, so iOS identical; if the README is read as success-omits, this becomes an expectation correction instead.

**C22 inline-runflow-commands-rejected** · cli · wrong-result
- Rows: AND-226 (android), IOS-226, IOS-226@27.0 (ios)
- iOS: same rejection on 26.0 and 27.0, and it still prints `Failure screenshot: …` for a parse error.
- Expected: `runFlow: {commands: [...]}` runs the inline commands (README:172).
- Actual: rejected before the run: `Invalid runFlow command: object form requires a string 'file' field`, exit 1.
- Cause: FlowReferenceResolver.swift:102-105 requires `file` in every object-form runFlow; inline `commands` (and `when`-only) forms must pass through untouched. Platform-independent.

**C23 flow-appid-ignored-on-android** · cli · contract
- Rows: B-C10.2 (android), IOS-126 (ios)
- iOS: with no flag, no config `bundle_id`, scheme configured and flow `appId: ${APP_ID}`, there is no project-detection fallback (README:174): `Bundle ID is required to run flows.` Same resolution chain (RunCommand.swift:254-264). Slug should read app-id-resolution-order.
- Expected: with no config and no `--application-id`, `run --flow` uses the flow's `appId:` header (brief C10).
- Actual: fails before the run with `Application ID is required...`.
- Cause: RunCommand.swift:254 (`target.resolve`) throws TargetOptions.swift:162's message before the `--flow` header fallback at RunCommand.swift:264 (`flowBundleId`) is consulted.

**C24 android-config-skips-maestro-format** · cli · wrong-result
- Rows: AND-128, B-C08.2 (android)
- Expected: a Maestro-format `grantiva-android.yml` parses (README:158-172), giving screens steps the id-selector form (brief C08: `tap: {id: X}`, assertVisible by id).
- Actual: Maestro-format file fails (`DecodingError.dataCorrupted ... expected a single document`, `unknown key "appId"`); native `assert_visible: {id: ...}` fails `Key 'text' not found`.
- Cause: GrantivaConfig.swift:305 gates `MaestroFlowParser.isMaestroFormat` on `platform == .ios`; the id form exists only through MaestroFlowParser.swift:274-276 (`assertVisibleById`), so Android has no id route at all.

**C25 no-build-ignores-app-file** · cli · wrong-result
- Rows: AND-OBS-01 (android)
- Expected: `build install --no-build --app-file <apk>` installs the APK, or rejects the combination.
- Actual: `Skipping build and install (--no-build)` then `Done — ... installed on cov-android (not launched)`; nothing installed.
- Cause: BuildCommand.swift:127 short-circuits on `--no-build` before `--app-file`, then prints the success line anyway.

**C26 install-warning-says-testing** · cli · ux
- Rows: B-A03.2 (android)
- Expected: `build install` application_id mismatch warning worded for an install.
- Actual: `... testing com.kylebrowning.landmarks.paid. Update application_id or pass --application-id to override.`
- Cause: AndroidProject.swift:41 (single message shared by run and build install).

**C27 headless-implied-without-tty** · cli · docs
- Rows: AND-005 (android)
- Expected: help/docs say when a boot is windowless.
- Actual: without `--headless`, boot is windowless whenever stdout is not a TTY; neither help nor docs/android.md:38 says so.
- Cause: EmulatorManager.swift:263 (`headless || isatty(STDOUT_FILENO) == 0`).

**C28 created-avds-record-bookkeeping** · cli · wrong-result
- Rows: AND-109 (android)
- Expected: an AVD deleted out-of-band is dropped from created-avds.json by teardown (docs/android.md:185-186); no claim about a record that never existed.
- Actual: a refused `teardown --serial` leaves the stale name; `teardown --force` on an unrecorded serial prints `... was already gone; dropped its record.`
- Cause: EmulatorCommand.swift:174 (message not conditioned on a record existing); prune at EmulatorManager.swift:376 not run on the refusal path.

**C29 ensure-reused-reports-wrong-state** · cli · wrong-result
- Rows: AND-110 (android)
- Expected: `emulator ensure --name X --no-boot` while X runs reports it booted.
- Actual: `Reused cov-android — Shutdown`.
- Cause: EmulatorCommand.swift:43 prints the state from the AVD record without matching the running serial (state lookup not located).

**C30 emulator-delete-json-compact** · cli · contract
- Rows: AND-146 (android)
- Expected: pretty-printed like sibling `--json` outputs.
- Actual: one-line compact JSON.
- Cause: EmulatorCommand.swift:77 (`JSONSerialization` with `.sortedKeys` only, no `.prettyPrinted`).

**C31 sdkmanager-failure-undetected** · cli · wrong-result
- Rows: AND-002 (android)
- Expected: a failed system-image install stops with a clear error.
- Actual: continues to `Creating AVD`, then `Error: Error: Package path is not valid. ... null` (doubled prefix, stray `null`), exit 1.
- Cause: EmulatorManager.swift:356-365 (sdkmanager exit/output not checked before avdmanager); message assembly doubles `Error:` (not located).

**C32 detach-prints-monkey-output** · cli · contract
- Rows: AND-OBS-04 (android)
- Expected: stdout carries only the command's result.
- Actual: monkey's output (`data="android.intent.category.LAUNCHER"`, `--pct-syskeys`) on stdout before `Runner started (detached)`.
- Cause: ADB.swift:84 (`shell monkey ...` output reaches stdout; likely the detached child inherits stdout, not located precisely).

**C33 verbose-omits-logcat-subprocess** · cli · ux
- Rows: AND-OBS-07 (android), IOS-154 (ios)
- iOS: `record --verbose` never lists `simctl io … recordVideo` or the frame extraction; IOS-152/153 (placed in C19) also show `run`/`diff capture --verbose` never list the runner launch or `log stream`. Slug should read verbose-omits-long-running-subprocesses; cause widens to the subprocess logger not wrapping long-lived Process launches (LogStreamer.swift, IOSPlatform.swift:179, RunnerExecution.swift).
- Expected: `--verbose` lists every subprocess (README:390).
- Actual: the long-running `adb ... logcat` spawned by `--logs` is never logged.
- Cause: LogStreamer.swift (logcat spawned outside the verbose subprocess logger; line not located).

**C34 record-held-frame-note-unreliable** · cli · wrong-result
- Rows: AND-124, AND-OBS-08 (android)
- Expected: on a static screen the held-frame note always prints, with the true last-frame time.
- Actual: note missing in 1/5 runs (and 1/4 `--quiet`); when printed it says `last frame is at 100ms` while the mp4/JSON say 50 ms.
- Cause: RecordCommand.swift:102-108 (`heldRecordingNote` uses the raw screenrecord duration and a half-duration threshold, not the written file's last frame).

**C35 doctor-advice-under-required** · cli · ux
- Rows: CLI-025, CLI-026, B-C12.1 (cli)
- Expected: advisory toolchain checks appear under an advisory heading consistent with the "optional" summary.
- Actual: `● Xcode`, `● JDK` (status warning) printed under "Required" (`"section": "Required"`) while the summary counts them optional.
- Cause: DoctorCheck.swift:17 (`case required`), section assigned per check rather than by the advice downgrade (DoctorRunner.swift, line not located).

**C36 doctor-booted-sim-false-negative** · cli · wrong-result
- Rows: CLI-081 (cli)
- Expected: when simctl cannot be queried (DEVELOPER_DIR broken) the check says so.
- Actual: `No simulator booted` with a `simulator ensure` fix while one is booted.
- Cause: DoctorRunner.swift:104 (query failure collapsed into "none booted").

**C37 default-simulator-name** · cli · contract
- Rows: EXTRA-03, EXTRA-06 (cli)
- Expected: one default simulator name everywhere, and init's default does not silently take over a user's own simulator.
- Actual: hard-coded `iPhone 16` (CLI, MCP schemas), init writes the newest installed iPhone type, doctor suggests `iPhone 17 Pro`; a later `run` reuses/boots/installs onto the user's same-named simulator.
- Cause: ProjectResolver.swift:25, :121; DriverCommand.swift:211; BuildTools.swift:107, :258; SimTools.swift:108; InitCommand.swift:93 (`newestIPhone`).

**C38 init-ambiguous-scheme-silent** · cli · ux
- Rows: CLI-069 (cli)
- Expected: init warns or asks when several shared schemes exist, as `run` refuses.
- Actual: init silently writes `scheme: Landmarks`.
- Cause: InitCommand.swift:93-96 vs ProjectResolver.swift:107 (run's multi-scheme refusal).

**C39 ready-file-failed-content** · cli · contract
- Rows: CLI-044 (cli), IOS-031 (ios)
- Expected: a failed ready file carries `error` and names only directories that exist.
- Actual: `"reportDir": "out"` for a never-created dir; no `error` field although the reason is known.
- Cause: ReadyFile.swift (failed-before-boot path; line not located).

**C40 snapshot-invalid-value-no-choices** · cli · ux
- Rows: CLI-055 (cli)
- Expected: `--snapshot bogus` lists failure/trailing/full like `--platform` does.
- Actual: `The value 'bogus' is invalid for '--snapshot <snapshot>'` with no choices.
- Cause: not located (the `--snapshot` enum lacks the `allValueStrings`/custom error used by `--platform`).

**C41 negative-timeout-missing-value** · cli · ux
- Rows: CLI-056 (cli)
- Expected: `--timeout -1` is an invalid-value error.
- Actual: `Missing value for '--timeout <timeout>'` (the `-1` is parsed as an option).
- Cause: not located (argument parser treats `-1` as a flag; needs `parsing: .unconditional` or a custom check).

**C42 teardown-usage-error-prefix** · cli · ux
- Rows: CLI-058 (cli)
- Expected: teardown usage errors use plain `Error:` like CLI-060/062.
- Actual: `Error: Invalid argument:` (the exit-1 GrantivaError prefix) on an exit-64 usage error; also for `--udid not-a-udid`, `--session-id ""`.
- Cause: SimulatorCommand.swift:164 throws `GrantivaError.invalidArgument` for validation instead of `ValidationError`.

**C43 platform-flag-rejection-wording** · cli · ux
- Rows: CLI-134 (cli)
- Expected: same wording across commands.
- Actual: build/ci/diff append `(resolved from --platform, GRANTIVA_PLATFORM, ...)`; runner start (and record) do not.
- Cause: DriverCommand.swift:129-131 and RecordCommand.swift:85-92 hand-write the shorter message.

**C44 missing-flow-file-detected-late** · cli · wrong-result
- Rows: CLI-133 (cli)
- Expected: `run --flow missing.yaml` fails naming the file before any device work.
- Actual: counted as `flows=1`, simulator booted, app built (21.8 s) and installed, then fails after 53 s.
- Cause: RunCommand.swift:258-273 (`--flow` path accepted without an existence check).

**C45 extracting-runner-noop-narration** · cli · ux
- Rows: CLI-084 (cli)
- Expected: no "Extracting" line when the install is already current.
- Actual: `Extracting runner...` every time.
- Cause: DriverCommand.swift:32 (note printed before the idempotence check).

**C46 no-session-message-quote-mix** · cli · ux
- Rows: CLI-087 (cli), B-C11.2 (ios)
- iOS: the MCP no-session isError is also labelled `Error: Invalid argument:` though no argument was wrong (MCPServer.swift:188 throws GrantivaError.invalidArgument). Slug should read no-session-message-shape.
- Expected: consistent quoting.
- Actual: `'grantiva runner start'` vs `` `grantiva run --keep-alive` `` in the same sentence; same in the MCP no-session text.
- Cause: DriverCommand.swift:736; MCPServer.swift:188.

**C47 dump-hierarchy-format-validated-late** · cli · ux
- Rows: CLI-140 (cli)
- Expected: `--format bogus` is a usage error naming tree/json/xml, exit 64.
- Actual: not validated up front; exit 1 `No active runner session...`.
- Cause: DriverCommand.swift:717 validates only the `--json` conflict; the format check is at :830/:844, after session resolution.

**C48 bundle-mismatch-message-and-residue** · cli · wrong-result
- Rows: CLI-142 (cli)
- Expected: binary/bundle version mismatch reported naming both versions and the bundle (README:186); no residue.
- Actual: existing install: mismatch not reported; fresh home: generic `Runner binary not found...` and an empty versions/<stamp>/ left behind.
- Cause: GrantivaError.swift:57 (generic message); extraction path in DriverCommand.swift:~25-40 does not compare bundle vs binary version.

**C49 approve-missing-screen-message-garbled** · cli · ux
- Rows: CLI-150 (cli), IOS-114 (ios)
- iOS: MCP `grantiva_vrt_approve` shows the same garbled `No captures found in No capture found for "Home; touch …"` text.
- Expected: `No capture found for "NoSuchScreen"`.
- Actual: `No captures found in No capture found for "NoSuchScreen". Run: grantiva diff capture`.
- Cause: DiffCommand.swift:641 passes a full sentence to `GrantivaError.noCaptures`, whose description wraps it as a directory (GrantivaError.swift:55).

**C50 releases-update-version-shadow** · cli · wrong-result
- Rows: CLI-170 (cli)
- Expected: `console releases update --version` prints 2.1.0 like every other page (or the option is renamed).
- Actual: exit 64 `Missing value for --version <version>`; help lists both `--version`s.
- Cause: ConsoleReleasesCommand.swift:173 (`@Option(name: .long) var version` shadows the root `--version` flag).

**C51 failed-diff-creates-empty-dirs** · cli · ux
- Rows: EXTRA-02 (cli)
- Expected: a failing `diff compare`/`diff approve`/vrt tool leaves no new directories.
- Actual: empty `.grantiva/captures/diffs` (and `captures/android/diffs`) created.
- Cause: DiffCommand.swift:266 and :380 create `diffs` before checking for captures.

**C52 missing-config-wording-run-vs-capture** · cli · ux
- Rows: none directly (raised by the CLI-028 entry under Expectation corrections; the row is placed there)
- Expected: one wording for "no grantiva.yml" across run and diff capture; no scheme error masking it.
- Actual: `run --no-build` says `No grantiva.yml here. Create one with grantiva init.`; `diff capture` says `grantiva.yml not found at <dir>/grantiva.yml. Create one with grantiva init.`; `run` without `--no-build` says `No scheme specified ...` instead.
- Cause: GrantivaConfig.missingFileMessage vs the run path's own message (not located precisely).

### MCP

**C53 mcp-tool-errors-become-jsonrpc** · mcp · contract
- Rows: CLI-100 (cli), MCP-057, MCP-061, MCP-062, AND-100 (android), MCP-031 (ios)
- iOS: `grantiva_build {scheme}` in a dir without config answers JSON-RPC -32603 `Simulator not found: "iPhone 16"` (the hard-coded default, see C37).
- Expected: every tool failure is an `isError` result (docs/mcp.md:21-22).
- Actual: `grantiva_build` (missing simulator), `grantiva_emulator_boot` (unknown name), `grantiva_emulator_delete` (refusals, missing AVD) answer JSON-RPC `-32603 Internal error: ...`. The delete refusal also names the CLI flag `--force` instead of the `force` argument.
- Cause: ToolRegistry.swift:108-170, every non-session tool is `try await` with no catch, so a thrown error reaches the SDK as an internal error (session tools are wrapped at :80-89). Same fix covers iOS sim tools.

**C54 mcp-build-boots-emulator** · mcp · wrong-result
- Rows: N-02 (android)
- Expected: `grantiva_build {}` compiles only, like `build build`.
- Actual: boots the configured AVD (24.4 s, `Booting AVD cov-android as emulator-5554`).
- Cause: BuildTools.swift:158 (`device.bootDevice(named:)` inside `build`).

**C55 mcp-session-capture-json-shape** · mcp · contract
- Rows: MCP-064, X-022 (android)
- Expected: live-session `grantiva_vrt_capture` JSON equals `diff capture --json` (incl. `emulator` on Android).
- Actual: keys `directory, duration, screens, simulator`; no `emulator` object (step durations here are real while CLI's are 0, see C17).
- Cause: SessionCapture.swift:121 always emits `simulator: target`.

**C56 mcp-context-keepalive-session-fields** · mcp · wrong-result
- Rows: X-020 (android), MCP-042 (ios)
- iOS: X-020 passed, but MCP-042 shows the keep-alive session's `[Runner Session]` with an empty `bundle_id:`; its `[Simulator] runtime: iOS-26-0` half belongs with C96.
- Expected: `[Runner Session]` shows the driver port and application ID of a keep-alive session.
- Actual: `driver_port: 0`, empty `application_id:`.
- Cause: ContextTool.swift:76-82 prints RunnerSessionInfo fields that a keep-alive session (KeepAliveSessionStore) does not fill.

**C57 mcp-hierarchy-notify-on-noop** · mcp · ux
- Rows: AND-OBS-09 (android)
- Expected: `notifications/resources/updated` only after calls that changed the UI.
- Actual: sent after a rejected `grantiva_script` and a `grantiva_tap` whose label was not found.
- Cause: ToolRegistry.swift:89-92 notifies for any uiMutating tool that returned a result, including isError results from callSessionTool.

**C58 mcp-context-synthesizes-config** · mcp · wrong-result
- Rows: AND-OBS-10 (android)
- Expected: `mcp --platform ios` with no grantiva.yml says there is none.
- Actual: `[Config] platform: ios, bundle_id: <Android appId>, screens: 18` synthesized from `.maestro/`, plus another process's booted simulator.
- Cause: GrantivaConfig.swift:282-286 (`.maestro/` fallback runs for iOS even when the project is Android-only); ContextTool "first booted simulator" fallback.

**C59 vrt-tool-error-wrapping** · mcp · ux
- Rows: MCP-075 (cli)
- Expected: sibling VRT tools wrap failures the same way.
- Actual: approve `Approve failed:\nError: ...`; compare `Error: ...`; capture `Capture failed:\n<msg>` with or without `Error:`.
- Cause: VRTTools.swift:95, :144; ToolRegistry.swift:160; SessionCapture.swift:376.

**C60 vrt-tools-shell-string** · mcp · contract
- Rows: B-C05.2 (cli)
- Expected: brief C05: spawn the executable with an argv array.
- Actual: still a shell string built with `shellQuoted` (safe against PATH stubs, B-C05.1 passes).
- Cause: VRTTools.swift:67-88.

### Docs and help text

**C61 help-ios-only-wording** · cli · docs
- Rows: CLI-008, CLI-123, CLI-125, CLI-111, CLI-119, N-07 (cli), AND-OBS-02 (android)
- Expected: help for both-platform commands/options names the Android driver or input (README:333; docs/android.md:48).
- Actual: `runner start` abstract "with WDA"; `dump-hierarchy -p` "WDA port"; `hierarchy --timeout` "GrantivaAgent's page-source response"; `--app-file` ".app bundle or .ipa archive" on run, diff capture, build install.
- Cause: DriverCommand.swift:76, :699 (note :269 already does the platform switch); HierarchyCommand.swift:38; Options.swift:39.

**C62 doctor-status-filter-documented-wrong** · docs · docs
- Rows: CLI-011 (cli), AND-092 (android)
- Expected: README's `jq '.[] | select(.status == "fail")'` selects failing checks.
- Actual: status values are ok/warning/error, so the filter matches nothing.
- Cause: README:380 and Output.swift:11 doc comment vs DoctorCheck.swift:11-13.

**C63 readme-runner-home-path-naming** · docs · docs
- Rows: CLI-161 (cli)
- Expected: README names the device-home path as on disk.
- Actual: README:92 says `versions/<runner version>/`, disk and README:186 use the install stamp (`1.1.28-grantiva.9+android-drivers-2`).
- Cause: README:92.

**C64 stale-simulator-lifecycle-doc** · docs · docs
- Rows: B-D05.1 (cli)
- Expected: no stale versions or internal notes in shipped docs.
- Actual: SIMULATOR-LIFECYCLE.md:29 "Ship 1.6.5 ... currently 1.6.4" and an internal status note.
- Cause: SIMULATOR-LIFECYCLE.md (repo root).

**C65 dump-hierarchy-doc-wda-versions** · docs · docs
- Rows: EXTRA-01 (cli)
- Expected: docs list the iOS versions the tarball ships agents for.
- Actual: docs/dump-hierarchy.md:55 says 26.2, 26.4, 27.0; a fresh home also gets 26.0.
- Cause: docs/dump-hierarchy.md:55.

**C66 readme-from-source-bundle** · docs · docs
- Rows: EXTRA-04 (cli)
- Expected: "From source" install produces a working binary.
- Actual: README:20-23 copies only the binary; without `grantiva_GrantivaCore.bundle` beside it the runner cannot be extracted.
- Cause: README:20-23.

### iOS slice additions

**C67 concurrent-ensure-boot-race** · cli · wrong-result
- Rows: IOS-008 (ios)
- Expected: two concurrent `simulator ensure` for one name give one device, `Created` + `Reused`.
- Actual: one device, but the second call exits 1 with CoreSimulator `code=405 ... Unable to boot device in current state: Booted` (3/3); it also logs `Waiting for simulator capacity (4/6)` with capacity free, counting its twin's device.
- Cause: not located (ensure boots without tolerating "already Booted"; capacity count includes the in-flight twin, SimulatorCapacity.swift).

**C68 teardown-free-udid-reports-reclaimed** · cli · contract
- Rows: IOS-017 (ios)
- Expected: `teardown --udid <free> --force --json` reports `reclaimed: false` (README:430-447).
- Actual: `"reclaimed": true` with empty `processes`/`sessionFilesRemoved` and `leaseReleased: true` though no lease was held.
- Cause: not located (`reclaimed` appears to be set by the device-home removal alone).

**C69 teardown-leaves-device-home** · cli · wrong-result
- Rows: IOS-121 (ios)
- Expected: `simulator teardown` (with or without `--force`) removes `<runner home>/versions/*/devices/<udid>` (README).
- Actual: `teardown --udid <udid> --json` without `--force` prints `[]`, exit 0, leaves the device home.
- Cause: not located (home cleanup only on the `--force` reclaim path).

**C70 session-device-refuses-sessionless-run** · docs · docs
- Rows: IOS-122 (ios)
- Expected: README:452-455 describes what happens to a run with `GRANTIVA_SESSION_ID` unset on a device owned by a named session.
- Actual: refused with `... belongs to Grantiva session cov-ios. Teardown that session or select another simulator.`: behaviour undocumented, "Teardown" used as a verb.
- Cause: SimulatorCapacity.swift:114 (message); README:452-455 (gap).

**C71 no-scheme-message-suggests-missing-option** · cli · ux
- Rows: IOS-027 (ios)
- Expected: the no-scheme error offers only options the command has.
- Actual: `build build` is told to `use --app-file to provide a pre-built binary`; `build build` has no `--app-file`.
- Cause: ProjectResolver.swift:105 and IOSPlatform.swift:36 (one message for every command).

**C72 cached-scheme-masks-ambiguity** · cli · wrong-result
- Rows: B-I13.2 (ios)
- Expected: a cached detection never picks a scheme silently once the project has several (brief I13).
- Actual: `.grantiva/config.json` cached `"schemes":["Landmarks"]` from a one-scheme detect; after a second scheme is restored, `build build` builds `Landmarks` silently, exit 0.
- Cause: ProjectResolver.swift:80 (`detected?.schemes == nil` re-detects only when the cache has no list) and :107; cache not invalidated when the project changes.

**C73 install-bundle-id-mismatch-raw-error** · cli · ux
- Rows: IOS-123 (ios)
- Expected: `build install --bundle-id <other>` names the bundle ID and the mismatch with the built app.
- Actual: raw `NSPOSIXErrorDomain code=2 ... No such file or directory`.
- Cause: not located (data-container/launch lookup by the wrong bundle ID surfaces simctl's error unwrapped).

**C74 launch-arguments-sent-as-environment** · runner · wrong-result
- Rows: IOS-077 (ios)
- Expected: `launchApp: {arguments: {...}}` passes launch arguments only.
- Actual: argv `["--flag" "true"]` and also `env=map[--flag:true]` (an environment variable named `--flag`).
- Cause: not located (WDA launchApp in the runner copies the arguments map into the launch environment).

**C75 ios-swipe-from-not-found-wording** · runner · contract
- Rows: IOS-219, IOS-219@27.0 (ios)
- Expected: `Element not found for swipe` naming the selector, as on Android.
- Actual: `✗ swipe: LEFT ... Element not found: text='No Such Row'` (no "for swipe") on 26.0 and 27.0.
- Cause: the UIAutomator2 and devicelab drivers say "for swipe" (pkg/driver/uiautomator2/commands.go:1109; devicelab/commands.go:1556, :1562); the WDA swipe-from path reuses the generic not-found error (not located).

**C76 unexplained-warning-marker** · runner · ux
- Rows: IOS-224, IOS-224@27.0, IOS-228 (ios)
- Expected: a step drawn with `⚠` says why; a passing step in report.json draws `✓`.
- Actual: `⚠ scrollUntilVisible: text="Landmark 70" (32.4s)` and `⚠ extendedWaitUntil: notVisible text="Loading…"` with no reason while report.json says `passed`; scrollUntilVisible also takes 32-36 s per search.
- Cause: pkg/cli/test_unified_output.go:~170-183 (yellow `⚠` branch prints `cmd.Warning` only when non-empty, so the marker is set by another condition, likely a duration or retry flag, without text). Slowness not located.

**C77 clearstate-not-narrated** · runner · ux
- Rows: IOS-231, IOS-231@27.0 (ios)
- Expected: `launchApp: {clearState: true}` shows the data clearing in the runner log.
- Actual: the container is replaced (probe) but the log shows only terminate and launch with a silent 0.8 s gap.
- Cause: not located (WDA clearState path does not log). Behaviour appears correct; this is an observability defect.

**C78 tap-label-matches-symbol-identifier** · mcp · wrong-result
- Rows: IOS-102 (ios)
- Expected: `grantiva_tap {label: "heart"}` does not match the Favorites tab by its SF Symbol identifier.
- Actual: `Tapped on "heart"` on a screen where the only `heart` is the tab's identifier.
- Cause: WDAClient.swift:88-105 (label predicate also matches identifier/name attributes).

**C79 killed-keepalive-runner-survives** · cli · wrong-result
- Rows: IOS-054 (ios)
- Expected: after `kill -9` of a keep-alive `grantiva run`, `hierarchy` ignores the dead session and fails fast (docs/dump-hierarchy.md:21).
- Actual: the runner child lives on and `hierarchy` still answers; the session is keyed by the runner pid, so the dead run masquerades as live until `teardown --force`.
- Cause: KeepAliveSessionStore.swift:~240-250 (liveness from the runner `pid`, not the owning grantiva pid); the runner is not tied to its parent's lifetime.

**C80 report-left-running-after-timeout** · cli · wrong-result
- Rows: IOS-073 (ios)
- Expected: after a `--timeout` kill, `--report-dir` report.json records the run as failed.
- Actual: `"status": "running"`, `summary.running: 1` (IOS-073 flows; IOS-135 screens, placed in C20).
- Cause: not located (the CLI kills the runner before it finalises the report and does not rewrite it; RunnerReportRewriter.swift is the natural place).

**C81 snapshot-failure-keeps-every-step** · cli · wrong-result
- Rows: IOS-066 (ios)
- Expected: `--snapshot failure` keeps the last good and failing step shots only.
- Actual: `captures/trace/` is right, but `assets/flow-000/` keeps before+after for every step, the same as `--snapshot full`.
- Cause: not located (snapshot pruning applies to the trace copy, not the runner's assets dir).

**C82 run-artifacts-treated-as-screens** · cli · wrong-result
- Rows: IOS-067, IOS-092 (ios)
- Expected: only takeScreenshot points and configured screens are captures; diff approve/compare see only those.
- Actual: `--snapshot full` trace shots are listed on stdout as captured screens (`Screens: 18 total`) and land in `captures/`; `run` also leaves takeScreenshot shots and `failure-<ts>.png` in `.grantiva/captures`, which a later `diff approve`/`diff compare` treat as 13 screens.
- Cause: not located (run and diff share `.grantiva/captures` without a manifest; DiffCommand.captureDirectory is used by both, RunCommand.swift:245).

**C83 subflow-screenshot-not-captured** · cli · wrong-result
- Rows: CLI-068 (ios)
- Expected: a `takeScreenshot` inside a `runFlow` sub-flow becomes a capture point (README:170).
- Actual: the sub-flow's `takeScreenshot: "FromSub"` runs but produces no capture; only the parent's `Main` is written.
- Cause: not located (capture collection reads the top-level flow's commands only).

**C84 record-frame-past-duration-not-prechecked** · cli · ux
- Rows: IOS-082 (ios)
- Expected: `--frames-at 5000` with `--duration 2` rejected before recording (brief C14).
- Actual: records 2 s, overwrites `recording.mov`, then errors.
- Cause: RecordCommand.swift (validation missing before the recorder starts; line not located).

**C85 record-json-mixed-path-styles** · cli · contract
- Rows: IOS-083 (ios)
- Expected: `video` and frame `path`s use one style.
- Actual: `video` relative, every frame `path` absolute (text mode likewise).
- Cause: RecordCommand.swift (not located precisely).

**C86 lease-rejects-runner-start-session** · cli · wrong-result
- Rows: IOS-089, IOS-143 (ios)
- Expected: `diff capture --no-build` drives the live runner session's device (README:262-264); refusals name `grantiva runner stop` for a `runner start` session.
- Actual: `diff capture --no-build` resolves the session's simulator then refuses `already owned by another Grantiva run (pid ..., --keep-alive)`; `run` describes the `runner start` session as `another Grantiva run ... --keep-alive` and offers only `teardown --force`.
- Cause: SimulatorLease.swift:126 (ownership message) and owner classification that treats a `runner start` session as a keep-alive run; the capture path does not use the session instead of taking a lease.

**C87 runner-stop-leaves-session-file** · cli · wrong-result
- Rows: IOS-087 (ios)
- Expected: `runner stop` removes all session files.
- Actual: in 1 of 5 cycles the runner's `<pid>-<ts>.grantiva` stayed in /tmp/grantiva-sessions.
- Cause: not located (race between runner exit and the CLI's cleanup).

**C88 foreground-runner-start-exits** · cli · wrong-result
- Rows: IOS-139 (ios)
- Expected: `runner start` without `--detach` holds until Ctrl-C.
- Actual: prints `Runner started ... Use 'grantiva runner stop'` and exits 0 after ~3.8 s; the runner is gone, session.json and owner.json left behind; `runner stop` then reports stopping a dead pid.
- Cause: DriverCommand.swift:~330-420 (foreground path returns after start instead of waiting on the child).

**C89 compare-without-baselines-passes** · cli · wrong-result
- Rows: IOS-091 (ios)
- Expected: `diff compare` with no baselines does not report a pass.
- Actual: `✓ Visual diff passed` (`New: 5`), exit 0; MCP `vrt_compare` `passed: true`.
- Cause: TableOutput.swift:94 and the `passed` computation ignore `new` screens.

**C90 screens-staging-leaks-into-output** · cli · ux
- Rows: IOS-141, CLI-049 (ios)
- Expected: screens-config steps and errors are reported in grantiva.yml terms.
- Actual: `wait: 3` shown as `✓ evalScript (3.0s)` live and `Wait 3s` in the summary; summary header and the runFlow cycle error name the staged `/var/folders/.../grantiva-flows-.../flow.yaml` instead of grantiva.yml.
- Cause: FlowGenerator.swift:64 (wait emitted as evalScript); staged flow path not mapped back in narration/errors (RunnerReportRewriter only maps the report).

**C91 alert-accept-not-narrated** · runner · ux
- Rows: IOS-151 (ios)
- Expected: an auto-accepted system alert prints `accepted system alert ...`.
- Actual: nothing in the run output, even with `--verbose`; only raw driver debug in a runner log deleted without `--report-dir`.
- Cause: not located (pkg/driver/wda alert handling logs at debug only).

**C92 lookup-returns-network-error-400** · mcp · wrong-result
- Rows: MCP-078, N-05 (ios)
- Expected: a missing label gives `Element not found: ...`; with the app terminated, texts say the app is not running.
- Actual: `Error: Network error (400): Failed to look up "No Such"` right after startup (3/5 cycles) and after `simctl terminate`; other tools say `Failed to swipe up` / `Failed to get hierarchy from WDA`.
- Cause: WDAClient.swift:88-110 (element-find 400 mapped to GrantivaError.networkError, GrantivaError.swift:59) instead of not-found / app-not-running.

**C93 run-failure-no-hierarchy-hint** · cli · contract
- Rows: B-C21.1, X-019 (ios)
- Expected: a `run` element-not-found/not-visible failure prints `Run grantiva hierarchy ...` (brief C21), as the MCP tools do.
- Actual: no hint on iOS; Android lacks it too (X-019 android, C02).
- Cause: not located (the hint exists only in the MCP error path).

**C94 mcp-run-no-product-line** · mcp · contract
- Rows: MCP-034, IOS-111 (ios)
- Expected (matrix): `grantiva_run` result carries `Product:` with the app path like `grantiva_build`.
- Actual: build/install/launch summary without `Product:`.
- Cause: BuildTools.swift:173 adds `Product:` only in `build`. Note: docs/mcp.md:62 does not promise it, so the orchestrator may treat this as a matrix correction instead.

**C95 mcp-run-no-config-bundle-detection** · mcp · wrong-result
- Rows: MCP-036 (ios)
- Expected: `grantiva_run {scheme}` without config detects the bundle ID from the built app.
- Actual: `Error: no bundle_id in grantiva.yml. Cannot launch app.` naming a file that does not exist.
- Cause: BuildTools.swift:198.

**C96 mcp-sim-list-availability-runtime** · mcp · contract
- Rows: MCP-047 (ios)
- Expected: `grantiva_sim_list` shows availability (docs/mcp.md:70) and human runtimes.
- Actual: `Name | UDID | State | Runtime` without availability; runtimes `iOS-26-0` (also in `grantiva_context`, MCP-042 placed in C56).
- Cause: SimTools.swift:97 (columns); runtime printed from the identifier fragment.

**C97 crash-wait-error-type** · runner · contract
- Rows: N-14 (ios)
- Expected: a wait that ends on a crash gets `error.type: app_crash` in report.json.
- Actual: `error.type: "assertion"` though the message says the app is not running.
- Cause: pkg/core/errors.go:120 defines `app_crashed`; the WDA wait failure path does not use it (not located).

**C98 cache-hit-build-narration** · runner · ux
- Rows: N-18 (ios)
- Expected: a cache hit says "using cached build" without build lines.
- Actual: `⏳ Building GrantivaAgent...` / `Using cached ...` / `✓ GrantivaAgent built`, and `Starting GrantivaAgent...` printed twice.
- Cause: pkg/cli/ios.go:112 and :125 (setup steps) plus pkg/driver/wda/runner.go:200 and :391 (driver prints its own copy).

**C99 hierarchy-json-raw-envelope** · cli · contract
- Rows: X-011 (ios)
- Expected: `hierarchy --format json` prints the tree like `runner dump-hierarchy --format json` and `grantiva_a11y_tree`.
- Actual: raw driver envelope `{"value": {...}, "sessionId": ...}` with string frames and flags.
- Cause: HierarchyCommand.swift (json format not unwrapped; line not located).

## Expectation corrections

| Row | Slice's argument | Recommendation |
|---|---|---|
| CLI-019 (cli) | teardown, diff compare and run behave as expected; `doctor --json` with a failing check prints the array on stdout and exits 1 with no `Error:` line, which README:380's jq pipe requires | correct the matrix: the doctor half should expect the check array on stdout and exit 1 (README:380); the other three commands pass |
| CLI-028 (cli) | README:158 allows flows in `.maestro/` with no grantiva.yml, so naming the empty `.maestro/` is right; secondary wording divergences remain | correct the matrix (expect `No flow files found in <dir>/.maestro`); the secondary wording issue is a product defect, becomes cluster C52 |
| MCP-077 (cli) | expectation comes from a live-session row; with no session the no-session isError legitimately comes first, so `type`/`swipe`/`script` argument naming must be rerun on device | correct the matrix: no-session variant expects the no-session isError for session tools; argument naming is covered by IOS-115 and the Android live-session twin |
| B-C16.1 (cli) | brief superseded by the server-side webhook event validation decision (#56, #108) | correct the brief: criterion becomes "unknown events are left to the server; no `events` subcommand" |
| B-C16.3 (cli) | suite asserts the opposite of the criterion, matching the server-side design | correct the brief (same decision as B-C16.1) |
| B-I04.3 (cli) | runner-side test holds; CLI has no alert policy to pass since #183 dropped the opt-out | correct the brief: drop the GrantivaCoreTests half of criterion 3 |

## Platform-dependent

Status of the iOS twins predicted before the iOS slice was folded in.

| Cluster | Android rows | iOS rows checked | iOS outcome |
|---|---|---|---|
| C01 step-line-omits-selector-details | AND-207, AND-208, AND-220 | IOS-207, IOS-208, IOS-220 | confirmed for point taps (IOS-208, @27.0); IOS-207/IOS-220 passed on behaviour, their step lines were not judged |
| C03 summary-draws-skipped-as-failed | AND-OBS-11 | IOS-134 | confirmed (skipped steps drawn `✗ ... (0ms)` in IOS-134's note) |
| C05 live-vs-summary-duration-drift | N-17 | N-17 (ios) | confirmed |
| C07 bare-scroll-distance-nondeterministic | N-03, AND-223 | IOS-223 | iOS passed: Android-only |
| C08 notvisible-wait-intermittent-timeout | AND-228 | IOS-228 | iOS passed on behaviour (only the `⚠` marker failed, C76): Android-only |
| C09 swipe-from-element-wrong-geometry | B-R02.1, B-A02.2 | IOS-217 | iOS passed: Android-only |
| C10 timeout-kill-reported-as-interrupt | AND-OBS-06 | IOS-135, X-023 | X-023 passed on iOS; not reported on iOS: treat as Android-only until seen |
| C11 android-narration-names-grantivaagent | N-15, X-001 | X-001 (ios), N-18 | iOS X-001 passed (GrantivaAgent is correct there); N-18 is a separate iOS narration defect (C98) |
| C13 flow-count-includes-screens | N-16 | IOS-133 | IOS-133 passed but did not judge the count line; unconfirmed |
| C14 runner-stop-misses-keepalive | N-01 | N-01 (ios) | confirmed |
| C16 runner-start-json-types-and-keys | AND-126 | IOS-138, X-013 | confirmed (IOS-138); X-013 passed on key parity |
| C17 capture-step-durations-zero | AND-108 | IOS-113, X-022 (ios) | iOS passed on key sets; durations not judged; unconfirmed |
| C18 deleted-report-paths-printed | AND-OBS-03 | IOS-070 | IOS-070 passed (with `--report-dir`); IOS-152 notes the runner prints report paths on iOS too: likely shared |
| C19 quiet-json-leak-runner-output | AND-137, AND-138 | IOS-152, IOS-153, IOS-074 | confirmed |
| C20 screens-session-failure-reporting | AND-119 | IOS-134, IOS-135 | confirmed |
| C21 run-json-reportdir-omitted-on-pass | X-002 | X-002 (ios), IOS-074 | confirmed and widened (shape varies by outcome) |
| C22 inline-runflow-commands-rejected | AND-226 | IOS-226, IOS-226@27.0 | confirmed |
| C23 app-id-resolution-order | B-C10.2 | IOS-126 | confirmed (iOS: `${APP_ID}` header, no project-detection fallback) |
| C33 verbose-omits-long-running-subprocesses | AND-OBS-07 | IOS-152, IOS-153, IOS-154 | confirmed |
| C53 mcp-tool-errors-become-jsonrpc | MCP-057, MCP-061, MCP-062, AND-100 | IOS-110, IOS-111, MCP-031 | confirmed by MCP-031 (`grantiva_build` JSON-RPC error); IOS-110 passed (success paths only) |
| C55 mcp-session-capture-json-shape | MCP-064, X-022 | IOS-113, X-022 (ios) | iOS passed (`simulator` is the right key there): Android-only |
| C56 mcp-context-keepalive-session-fields | X-020 | IOS-101, X-020 (ios), MCP-042 | X-020 passed on iOS but MCP-042 shows the empty `bundle_id:` for a keep-alive session: confirmed |
| C57 mcp-hierarchy-notify-on-noop | AND-OBS-09 | IOS-108 | IOS-108 passed; notifications not judged; unconfirmed |
| C02 / C93 run-failure remediation hint | X-019 | X-019 (ios), B-C21.1 | the missing hint is confirmed on iOS (C93); the selector-less message is Android-only (C02) |

## iOS-only

Clusters where the predicted iOS twin passed while Android failed. The brief should call these Android-specific defects:

- C07 bare-scroll-distance-nondeterministic: IOS-223 passed (four `scroll: DOWN`, Landmark 30 visible).
- C08 notvisible-wait-intermittent-timeout: IOS-228 passed the wait (5.2 s); its fail is only the unexplained `⚠` (C76).
- C09 swipe-from-element-wrong-geometry: IOS-217 passed (swipe from `Lake Tahoe` opens the row).
- C11 android-narration-names-grantivaagent: X-001 (ios) passed; GrantivaAgent narration is correct on iOS.
- C55 mcp-session-capture-json-shape: X-022 (ios) and IOS-113 passed; only Android lacks `emulator`.
- C02 uia2-not-visible-message-raw: iOS names the selector (`Element not visible: text='Golden Gate.*'`); only the hint half is shared (C93).

The reverse also holds for these iOS-only clusters (no Android twin expected, iOS driver or simulator paths): C67-C72, C74, C75 (iOS lacks Android's "for swipe" wording), C77, C78, C86, C88, C92, C96-C98.

Android-only (no iOS twin expected): C02 (message half), C04, C06, C12, C15, C24 (iOS already parses Maestro format), C25-C32, C34, C54.

## Unassigned

(none)

Rows: 41 cli + 54 android + 63 ios = 158; placed 158 (152 in clusters, 6 in expectation corrections)
