# Android slice findings (Task 7)

Grantiva 2.0.1 (`~/.grantiva-qa/bin/grantiva`, c8dc86d), runner 1.1.18-grantiva.7+android-drivers-2,
emulator-5554 (`Pixel_8_API_35`, API 35) plus `qa-android-1` (emulator-5556) created for this slice.
App under test: `/Users/kyle/Developer/landmarks-demo/android` (`grantiva-android.yml`, `.maestro/*`).
QA-only flows used for probes are in `findings/evidence/flows/`.

### AND-F01: Launch environment (`--env`, flow `env:`, `launchApp.environment`) never reaches the app on Android
Matrix IDs: AND-035, AND-037, AND-038, AND-039, AND-040
Severity: wrong-result
Command: `grantiva run --no-build --flow <flow> --device emulator-5554 --env 'LANDMARKS_NOTE=a=b c'` (and `--env LANDMARKS_NOTE=hello`, `--env LANDMARKS_SEED=many --env LANDMARKS_NOTE=x`, `--env LANDMARKS_SEED=empty`, `--env LANDMARKS_CRASH_ON_LAUNCH=1`)
Expected: each value reaches the app ("Environment variable for the app under test, as KEY=VALUE. Repeatable. Forwarded through the flow's launchApp environment." source: help/run.txt `--env`; on Android delivered as intent extras per the app label contract).
Actual: the runner calls `POST /session/<id>/appium/device/launch_app body={"appId":"com.kylebrowning.landmarks"}` with no environment; the app logs `extras=[none] env=[LANDMARKS_SEED=null, LANDMARKS_CRASH_ON_LAUNCH=null, LANDMARKS_NOTE=null]` on every one of the five runs. Note text never shows (`a=b c`, `hello`), seed `empty`/`many` not applied (09 and 10 fail), crash never happens (99-crash fails only at its last assert `This never appears`, so a crash-on-launch test is green up to that point for the wrong reason). Flow-level `env:` is dropped the same way (09, 10 in AND-043). The runner does force-stop the app before `launchApp` (`ActivityManager: Force stopping com.kylebrowning.landmarks` precedes the START), so singleTask reuse is not the cause. Only `launchApp: arguments:` is delivered (gate notes).
Repro: in `landmarks-demo/android`, `grantiva run --no-build --flow findings/evidence/flows/qa-note.yaml --device emulator-5554 --env 'LANDMARKS_NOTE=a=b c'`; `adb logcat | grep "Landmarks: launch"`.
Evidence: findings/evidence/AND-035/{stderr.txt,logcat.txt,report/client.log}, AND-037/log.txt, AND-038/log.txt, AND-039/log.txt, AND-040/log.txt, AND-043/summary.txt
Suspected cause: bundled grantiva-runner Android driver: `launchApp` maps `arguments` to intent extras but ignores `environment`. The CLI side (`Sources/GrantivaCore/Runner/FlowGenerator.swift:18-26`, `FlowEnvironment.swift`) only writes `launchApp: environment:`, so on Android it should write `arguments:` (or the runner should map `environment` to extras).

### AND-F02: `swipe: {direction: LEFT, from: "<text>"}` ignores `from` and reports success
Matrix IDs: AND-043 (02-favorite, green for the wrong reason)
Severity: wrong-result
Command: `grantiva run --no-build --flow .maestro/02-favorite.yaml --device emulator-5554 --snapshot full`
Expected: the swipe starts on the element matching `from` (Maestro `swipe` is listed as supported, source: README §Maestro Compatibility).
Actual: the runner prints `[swipe] Using screen coords: (972,1200) → (108,1200)` (screen center), makes no element lookup for `Lake Tahoe` for the swipe, reports `✓ swipe: LEFT`, and the after-swipe screenshot shows the row unchanged with no swipe action revealed. The flow passes only because each Favorites row also has a visible `Remove` button.
Repro: run 02-favorite with `--snapshot full`, look at `captures/02-favorite-cmd-008-after.png`.
Evidence: findings/evidence/AND-F-swipe/stderr.txt, AND-F-swipe/report/captures/02-favorite-cmd-008-after.png, AND-F-swipe/report/client.log
Suspected cause: bundled runner's Android swipe ignores the `from` selector (and should fail rather than fall back to screen center).

### AND-F03: Stale emulator ledger record lets `emulator teardown` (and `--all`) kill an emulator the user started by hand
Matrix IDs: AND-013, AND-018 (AND-012 blocked because of it)
Severity: wrong-result
Command: `grantiva emulator teardown --serial emulator-5556` (no `--force`)
Expected: only emulators Grantiva started are killed; others need `--force` ("Kill emulators Grantiva started", help/emulator_teardown.txt; "only emulators Grantiva started; --force for others", docs/android.md §Emulator subcommand; "nothing else ever touches an emulator the user started", AndroidProvenance doc comment).
Actual: after a Grantiva-started emulator dies outside Grantiva, its ledger record stays. When the user boots the same AVD by hand on the same port, the record's pid is dead but the AVD name matches, so `teardown` keeps the record and kills the user's emulator (`Killed emulator-5556 (qa-android-1).`, exit 0). `emulator sessions` meanwhile lists the hand-started emulator as Grantiva-started (`pid 66219 exited, adb: device`). The shared host is in this state right now: `~/.grantiva/android/started.json` holds `emulator-5554 / Pixel_8_API_35 / pid 19482` (dead), while emulator-5554 is a hand-started qemu (pid 49817, no `-port` argument, which Grantiva always passes). `grantiva emulator teardown --all` would kill it.
Repro: `grantiva emulator ensure --name qa-android-1`; `adb -s emulator-5556 emu kill`; `emulator -avd qa-android-1 -port 5556 -no-window &`; `grantiva emulator sessions`; `grantiva emulator teardown --serial emulator-5556`.
Evidence: findings/evidence/AND-013/log.txt, AND-009/sessions.json, host/before.txt
Suspected cause: `Sources/GrantivaCore/Android/EmulatorManager.swift:349-355`: a dead-pid record is kept whenever `adb emu avd name` equals the recorded AVD, but an AVD name does not identify who started the process. Could compare the live qemu pid (or its start time) instead and drop records whose pid is gone.

### AND-F04: Gradle failures are reported as a bare "FAILURE: Build failed with an exception." (reason dropped), with an iOS "Scheme" line
Matrix IDs: AND-024, AND-025
Severity: ux
Command: `grantiva build build --variant noSuchVariant`; `grantiva build build --module nosuch`
Expected: a clear Gradle task error, non-zero exit (help/build_build.txt `--variant`, `--module`; matrix AND-024/025).
Actual: exit 1 with only `✗ Build failed / Scheme: (none) / ✗ FAILURE: Build failed with an exception.`; `--json` gives `"errors": ["FAILURE: Build failed with an exception."]`. Gradle's actual reason (`Cannot locate tasks that match ':app:assembleNoSuchVariant' as task 'assembleNoSuchVariant' not found in project ':app'.`) is not shown anywhere.
Repro: in landmarks-demo/android, run either command.
Evidence: findings/evidence/AND-024/{nosuch.txt,nosuch.json,gradle-direct.txt}, AND-025/module-nosuch.txt
Suspected cause: `Sources/GrantivaCore/Android/GradleBuildRunner.swift:92` keeps only lines starting `e: `, containing `error:`, or starting `FAILURE:`; the `* What went wrong:` block is dropped. `Sources/GrantivaCore/Output/TableOutput.swift:45` prints `Scheme:` for Android builds.

### AND-F05: Config `application_id` overrides the built/APK application ID, so another variant's APK is installed but the configured app is tested
Matrix IDs: AND-028 (and brief Step 3 paidDebug)
Severity: wrong-result
Command: `grantiva run --variant paidDebug --flow .maestro/01-browse.yaml --device emulator-5554` and `grantiva run --app-file app/build/outputs/apk/paid/debug/app-paid-debug.apk --flow .maestro/01-browse.yaml --device emulator-5554`, with `application_id: com.kylebrowning.landmarks` in grantiva-android.yml
Expected: the run tests the app that was built/installed (paid variant: `com.kylebrowning.landmarks.paid`); with `--app-file` "the application ID is read with `apkanalyzer`" (CHANGELOG Unreleased).
Actual: Grantiva installs `app-paid-debug.apk` (creating `com.kylebrowning.landmarks.paid`) but logs `Installing com.kylebrowning.landmarks...`, rewrites the flow to `appId: com.kylebrowning.landmarks`, and runs against the free app left over from an earlier install. The run passes; `report.json` `app.id` is `com.kylebrowning.landmarks`. With `application_id` removed from the config the same commands correctly use `.paid` (AND-026, AND-028 second run). Nothing warns that the configured ID differs from the APK's.
Repro: as above, then `adb shell pm list packages | grep landmarks` shows both, and the report's `app.id` is the free one.
Evidence: findings/evidence/AND-S3-paid/{stderr.txt,report/report.json}, AND-028/log.txt, AND-026/log.txt
Suspected cause: `Sources/GrantivaCLI/TargetOptions.swift:92` (`applicationIdFlag ?? configured.applicationId ?? appID`) and `Sources/GrantivaCLI/RunCommand.swift:248` (`resolved.bundleId ?? builtAppID`): the configured ID beats the build output and the APK. At minimum, warn or fail when they differ.

### AND-F06: A failing `screens:` path aborts the suite even with `--continue-on-failure`; configured flows never run
Matrix IDs: AND-042
Severity: contract
Command: `grantiva run --device emulator-5554 --continue-on-failure --report-dir findings/evidence/AND-042/report`
Expected: "Keep running remaining flows after a failure." (help/run.txt `--continue-on-failure`); all configured flows run with per-flow pass/fail (AND-042).
Actual: `Running 13 flow(s)...`, the generated screens flow fails at `tapOn: "Lakes"` (see AND-F07), then the run exits 1 with `Error: Runner failed`; none of the 12 configured flows is executed or reported. The screens run also ignores `--report-dir` (it reports into `/var/folders/.../grantiva-report-*`; only the failure PNG reaches `--report-dir`).
Repro: run the app's stock config (screens + 12 flows) with `--continue-on-failure`.
Evidence: findings/evidence/AND-042/{stdout.txt,stderr.txt,report/}
Suspected cause: `Sources/GrantivaCLI/RunCommand.swift:404-410` (`runSuite` throws after any failed screen step when flows exist, without consulting `--continue-on-failure`).

### AND-F07: `tapOn: "Landmarks"` on the Deep Links screen taps the `landmarks://landmark/golden-gate-bridge` button instead of the exactly-matching tab
Matrix IDs: AND-042
Severity: wrong-result
Command: `grantiva run --no-build --flow findings/evidence/flows/qa-tab-landmarks.yaml --device emulator-5554 --snapshot full` (launch, tap `Deep Links`, tap `Landmarks`)
Expected: the tab labelled exactly `Landmarks` is tapped. The default `text:` match is documented as case-insensitive and unanchored (CHANGELOG, bundled runner .6), but an exact-text element exists on screen, and the shared `screens:` path in the label contract (`tap: "Landmarks"`, `tap: "Lakes"`) depends on it.
Actual: the tap reports success and the app opens Golden Gate Bridge detail (the deep-link button text contains "landmarks"). The stock `screens:` config therefore always fails at `tap: "Lakes"` on Android.
Repro: as above; view `captures/qa-tab-landmarks-cmd-003-AfterLandmarksTap.png`.
Evidence: findings/evidence/AND-042-screens/report/captures/qa-tab-landmarks-cmd-003-AfterLandmarksTap.png, AND-042-screens/report/client.log (`textContains("Landmarks")` clicked at (540,779)), AND-061/hierarchy-immediate.xml (Deep Links screen: the button `landmarks://landmark/golden-gate-bridge` has bounds [200,752][881,805], the tab text `Landmarks` is at [89,2253][256,2295]), AND-042/report/captures/failure-*.png
Suspected cause: bundled runner Android selector: UIAutomator `textContains` is case-insensitive, and the first hit in tree order wins (the Deep Links content precedes the bottom bar) with no preference for an exact, full-text match.

### AND-F08: `hierarchy --json` prints XML
Matrix IDs: AND-055
Severity: docs
Command: `grantiva hierarchy --json` (during a keep-alive run on emulator-5554)
Expected: `--json  Output as JSON` (help/hierarchy.txt). Already noted device-free as CLI-DOCS-F12; confirmed on Android.
Actual: exit 0, stdout is the UIAutomator2 XML page source (`<?xml version='1.0' ...`), not JSON. Only `--format json` gives JSON.
Repro: keep-alive run, then `grantiva hierarchy --json | head -1`.
Evidence: findings/evidence/AND-055/out.txt

### AND-F09: The "already owned" refusal on Android tells the user to run iOS `simulator` commands
Matrix IDs: AND-063
Severity: ux
Command: `grantiva run --no-build --flow .maestro/05-category.yaml --device emulator-5554` while a `--keep-alive` run owns emulator-5554
Expected: fail fast, naming the owner, "with guidance to provision a unique simulator" (README §Agent-Native Features, Concurrent runs); on Android the guidance should name `grantiva emulator ...`.
Actual: fails in 1 s and names the owner correctly, but says `Simulator emulator-5554 is already owned ... Release it with \`grantiva simulator teardown --udid emulator-5554 --force\`, or run against a different simulator via \`grantiva simulator ensure --name <unique-name>\``. Both suggested commands are iOS-only. The refused run also wrote a failure screenshot of the other run's device into `.grantiva/captures/android/`.
Repro: `grantiva run --keep-alive --flow <flow> --device emulator-5554 &`, then a second run on the same serial.
Evidence: findings/evidence/AND-063/log.txt, AND-063/settings-after-refused-run.txt

### AND-F10: Interrupting a run mid-flow writes ready-file status `failed`, not `interrupted`; the flow is left `running`
Matrix IDs: AND-060
Severity: contract
Command: `grantiva run --no-build --flow findings/evidence/flows/qa-longwait.yaml --device emulator-5554 --keep-alive --ready-file int.ready &`, then `kill -INT <pid>` 12 s in
Expected: ready file status `interrupted` (README §Agent-Native Features: `jq -r .status ... # passed | failed | interrupted`; `Sources/GrantivaCore/Runner/RunnerExecution.swift:86` writes `interrupted` on termination).
Actual: grantiva exits in 3 s with clean device state, but the ready file says `"status": "failed"` with `flows: [{"name": "qa-longwait", "status": "running"}]`. The same `running` flow status appears when `--timeout` kills the runner (AND-049). A waiter cannot tell a Ctrl-C from a test failure. (SIGINT after flows finished leaves the earlier `passed` file in place, which matches "written once".)
Repro: as above; `cat int.ready`.
Evidence: findings/evidence/AND-060/log.txt, AND-049/r.ready
Suspected cause: the runner exits non-zero on SIGINT and `execute` writes the `failed` verdict before the SignalRelay cleanup's `interrupted` write, which then sees the file already present.

### AND-F11: Without `--report-dir`, the ready file's `reportDir` points at a temp directory that has already been deleted
Matrix IDs: AND-034
Severity: contract
Command: `grantiva run --no-build --flow .maestro/05-category.yaml --device emulator-5554 --ready-file x.ready`
Expected: a ready file a waiter can act on (README §Agent-Native Features).
Actual: `"reportDir": "/var/folders/.../grantiva-report-99711E97-..."`; `ls` on that path right after exit: `No such file or directory` (the default report dir is "ephemeral", help/run.txt). The field should be omitted (or null) when the directory is not kept.
Repro: as above, then `ls "$(jq -r .reportDir x.ready)"`.
Evidence: findings/evidence/AND-034/x.ready, AND-034/poll.txt

### AND-F12: `--logs-level` on Android: `default` becomes logcat priority D (debug), no flag shows Verbose, and any word is accepted
Matrix IDs: AND-073
Severity: contract
Command: `grantiva run --no-build --flow .maestro/01-browse.yaml --device emulator-5554 --logs [--logs-level default|info|debug|warning]`
Expected: `--logs-level  Log level for --logs: default, info, debug. Defaults to \`default\` (warnings/errors/default).` (help/run.txt); CHANGELOG Unreleased: without `--logs-tag` the level "filters every tag at that priority".
Actual: priority counts of `[log]` lines: no `--logs-level` → V 5, D 6, I 7, W 14 (no filter at all, more verbose than `debug`); `--logs-level default` → D 6, I 7, W 14 (same as `debug`); `info` → I 7, W 14; `debug` → D 7, I 7, W 14. `--logs-level warning` (not a documented value) is accepted silently. The stream also starts with `adb logcat -c`, which clears the whole device log buffer for every other consumer.
Repro: as above, count `awk '{print substr($4,1,1)}'` over `[log]` lines.
Evidence: findings/evidence/AND-071/stderr.txt, AND-073/{info,debug,explicit-default,warning}.stderr
Suspected cause: `Sources/GrantivaCore/Android/AndroidPlatform.swift:183-190` uses `level.first` as the logcat priority letter, so `default` maps to `D`; nil level adds no filter. `:175` runs `logcat -c`.

### AND-F13: Ctrl-C during a flow run with `--logs` leaves an orphan `adb logcat` process
Matrix IDs: AND-075
Severity: contract
Command: `grantiva run --no-build --flow findings/evidence/flows/qa-longwait.yaml --device emulator-5554 --logs &`, then `kill -INT <pid>` while the flow is running
Expected: no orphan `logcat` process on success, failure or Ctrl-C (help/run.txt `--logs`; matrix AND-075; CHANGELOG Unreleased says keep-alive Ctrl-C "cleans up orphans").
Actual: grantiva exits 130; `adb -s emulator-5554 logcat --uid=10210 -v time` (pid 47930) keeps running, reparented to launchd (PPID 1, still alive 22 s later; killed by hand). Success and failure exits leave nothing, and Ctrl-C of a `--keep-alive` run after the flows finished also cleans up; only the mid-flow interrupt leaks.
Repro: as above; `ps -axo pid,ppid,command | grep "adb.*logcat"`.
Evidence: findings/evidence/AND-075/log.txt

### AND-F14: `record` on a static screen fails (or returns frame 0 for every timestamp)
Matrix IDs: AND-076
Severity: wrong-result
Command: `grantiva record --device emulator-5554 --duration 2 --frames-at 1000 --json` with nothing changing on screen
Expected: a video of the requested duration plus a PNG per requested timestamp (docs/android.md §Recording; help/record.txt).
Actual: exit 1, `Error: Grantiva recording ended at 0ms before requested frame 1000ms exited with code 1` (twice in a row). `screenrecord` emits frames only when the screen changes, so the mp4 holds a single packet at 0.000 s. In a 4 s static recording with one late change, all three frames came back with `actualMilliseconds: 0` and identical PNGs. With UI motion during the recording, frames are correct (1484/3497 ms).
Repro: leave the app idle, run the command above; `ffprobe -show_entries packet=pts_time .grantiva/recordings/recording.mp4`.
Evidence: findings/evidence/AND-079/log.txt, AND-076/log.txt, AND-076/recording.json
Suspected cause: `Sources/GrantivaCLI/RecordCommand.swift:147` treats the last video timestamp as the recording's end. A variable-frame-rate Android recording should hold the last frame up to the requested duration, or record with a constant frame rate / `--bugreport`.

### AND-F15: `diff capture` can screenshot a screen before the tap's navigation has rendered
Matrix IDs: AND-085
Severity: wrong-result
Command: `grantiva diff capture --no-build --device emulator-5554` with screens Home (launch), Deep Links (tap "Deep Links"), Favorites (tap "Favorites")
Expected: each capture shows its screen (docs/android.md §Captures and baselines).
Actual: on the first capture `Deep%20Links.png` was byte-identical to `Home.png` (md5 51b8e928...), i.e. the Landmarks list. The step log shows the tap succeeded. Two later captures were correct. `diff approve` then promoted the wrong image as the Deep Links baseline. The MCP `grantiva_tap` "Updated hierarchy" can be stale the same way (a dp tap on the Deep Links tab returned a tree without `Slow Screen`, though the next taps proved it navigated). Animations are 0 during captures, so this is a missing settle/idle wait after the tap.
Repro: run `diff capture` a few times with a tab-switch screen and compare md5s.
Evidence: findings/evidence/AND-085/first/ (Home.png and Deep%20Links.png identical), AND-085/try3/, AND-085/config-used.yml, AND-096/session2.log

### AND-F16: MCP `grantiva_vrt_capture|compare|approve` run whatever `grantiva` is first on PATH, not the running binary
Matrix IDs: AND-103
Severity: wrong-result
Command: `grantiva mcp` (2.0.1 from `~/.grantiva-qa/bin`) in landmarks-demo/android, tools/call `grantiva_vrt_capture`, `grantiva_vrt_compare`, `grantiva_vrt_approve {"screens":["Home"]}`
Expected: the tools use `.grantiva/captures/android/` and `.grantiva/baselines/android/` (docs/android.md; tool descriptions say "Equivalent to 'grantiva diff capture --no-build --json'").
Actual: all three return `isError` with `Error: Unknown option '--platform'` and the usage text of an older CLI: the server shells out to `grantiva diff ... --platform android` by name, which resolves to Homebrew's `/opt/homebrew/bin/grantiva` 2.0.0. On a host with only one install the tools would work; with a dev build, a pinned version, or no `grantiva` on PATH they break or silently run a different version.
Repro: put an older grantiva first on PATH, start `grantiva mcp` from another path, call `grantiva_vrt_compare`.
Evidence: findings/evidence/AND-100/session3.log
Suspected cause: `Sources/GrantivaMCP/Tools/VRTTools.swift:56,60,64` hard-code the string `grantiva`; use the current executable path (`CommandLine.arguments[0]` / `Bundle.main.executablePath`) or call the diff code in-process.

### AND-F17: MCP `grantiva_context` says "No emulator running" while two emulators are running
Matrix IDs: AND-094
Severity: wrong-result
Command: MCP tools/call `grantiva_context` with emulator-5554 and emulator-5556 running and a live `runner start` session on emulator-5554
Expected: `platform: android` under `[Config]`, the running emulator, and the Android SDK (CHANGELOG Unreleased Changed).
Actual: `[Config]` and `[Android SDK]` are right, but `[Emulator]\n  No emulator running.` The session block below lists `udid: emulator-5554`.
Repro: two emulators running, `runner start --device emulator-5554 --detach`, MCP `grantiva_context`.
Evidence: findings/evidence/AND-093/session1.log, AND-105/with-platform.log
Suspected cause: `Sources/GrantivaMCP/Tools/ContextTool.swift:69` calls `device.defaultDevice()` = `selectDevice(configured: nil)` (`AndroidPlatform.swift:87-88`), which throws "Several emulators are running" (ignoring the config's `emulator:`); `try?` turns that into "No emulator running".

### AND-F18: `grantiva_a11y_check` flags every Compose button as `missing_label`
Matrix IDs: AND-099
Severity: ux
Command: MCP `grantiva_a11y_check` on the Deep Links screen
Expected: keys on `class`, `content-desc`, `clickable`; 48 dp minimum (docs/android.md, CHANGELOG Unreleased).
Actual: 12 violations: each of the six buttons is reported as `missing_label` ("Interactive element of type android.widget.Button has no accessibility label or name") and `small_tap_target` (379x40 dp). The 40 dp height is real, but the labels are not missing: each Compose `Button` carries its text on a child `TextView` (`Caching Demo`, `Slow Screen`, ...), which TalkBack reads as the button's label. The checker only looks at the node's own `text`/`content-desc`.
Repro: as above; compare with `hierarchy` XML for the Button nodes.
Evidence: findings/evidence/AND-093/session1.log, AND-061/hierarchy-immediate.xml
Suspected cause: `Sources/GrantivaMCP/Tools/UITools.swift:287` (missing_label rule) does not consider descendant text for clickable Android nodes.

### AND-F19: `run --timeout` refuses values under 30 s; help does not say so
Matrix IDs: AND-049
Severity: docs
Command: `grantiva run --no-build --flow .maestro/11-slow.yaml --device emulator-5554 --timeout 5`
Expected: runner killed after 5 s and the run fails (help/run.txt `--timeout`: "Max seconds to wait for the runner subprocess before killing it with SIGTERM. Default: 600").
Actual: exit 64, `Error: --timeout must be at least 30 seconds.` With `--timeout 30` and a 90 s wait the runner is killed after 30 s as described (exit 1, clear message).
Evidence: findings/evidence/AND-049/{stderr.txt,stderr-30.txt}
Suspected cause: `Sources/GrantivaCLI/RunCommand.swift:65`; help text lacks the minimum.

### AND-F20: Emulators are booted headless whenever stdout is not a TTY (undocumented)
Matrix IDs: AND-001, AND-005, AND-032
Severity: docs
Command: `grantiva emulator ensure --name qa-android-1 --system-image "system-images;android-35;google_apis;arm64-v8a" > out.txt`
Expected: `--headless  Boot without a window` (help/emulator_ensure.txt; docs/android.md §Devices), implying a window by default.
Actual: without `--headless` the qemu command line has `-no-window` (`qemu-system-aarch64-headless ... -no-window`). The usual scripted form `serial=$(grantiva emulator ensure ...)` therefore never shows a window. Not mentioned in any doc.
Evidence: findings/evidence/AND-001/stdout.txt (process listing in the report), AND-013/log.txt
Suspected cause: `Sources/GrantivaCore/Android/EmulatorManager.swift:216` (`headless || isatty(STDOUT_FILENO) == 0`).

### AND-F21: iOS wording and small output defects in Android output
Matrix IDs: AND-021, AND-031
Severity: ux
Command: various (`build install --no-launch --json`, `run`, `build build`, `emulator ensure`)
Expected: Android terminology (docs/android.md).
Actual: `build install --json` uses `bundleId` and `simulator: {name, udid}`; `run` prints `Resolved: scheme=(none) simulator=emulator-5554`; build failures print `Scheme: (none)` (CLI and MCP `grantiva_build`); `run` with `flows: []` says `No screens or flows configured in grantiva.yml` although the file is `grantiva-android.yml`; help for `build build` still says "Build the app for a simulator using xcodebuild"; `emulator ensure` prints `Reused qa-android-1 (emulator-5556) — Booted` right after `Booting AVD qa-android-1` on a stopped AVD; many errors end with a stray ` exited with code 1` (e.g. the boot-timeout and record errors).
Evidence: findings/evidence/AND-021/stdout.json, AND-031/log.txt, AND-024/nosuch.txt, AND-013/log.txt, AND-017/log.txt

### AND-F22: `doctor` reports "Not a git repository" in a subdirectory of a git work tree
Matrix IDs: AND-090
Severity: ux
Command: `grantiva doctor --platform android` in `/Users/kyle/Developer/landmarks-demo/android`
Expected: the project check passes inside a work tree (`git rev-parse --show-toplevel` = `/Users/kyle/Developer/landmarks-demo`).
Actual: `● Git Repository  Not a git repository / Run: git init`. Running `git init` there would create a nested repository.
Evidence: findings/evidence/AND-090/doctor.txt
Suspected cause: `Sources/GrantivaCore/Doctor/DoctorRunner.swift:196` checks only `./.git`.

### AND-F23: Flake: UIAutomator2 socket refused mid-flow (adb briefly lost the device)
Matrix IDs: none (seen on AND-026's first attempt)
Severity: ux
Command: `grantiva run --variant paidDebug --flow .maestro/01-browse.yaml --device emulator-5554 --report-dir ...`
Expected: stable runs.
Actual: once in about 60 runs this session: step 4 `takeScreenshot` failed with `dial unix /tmp/uia2-emulator-5554.sock: connect: connection refused`, and the runner's cleanup then got `adb: error: device 'emulator-5554' not found`. No other agent was using emulator-5554 and the adb server was not restarted (started Oct 7), so this is not cross-agent interference as the gate notes guessed. Immediate rerun passed. The gate saw the same failure once on 02.
Evidence: findings/evidence/AND-026/report-try1-flake/maestro-runner.log, AND-026/log.txt

## Notes (not findings)

- Gboard stylus sheet (gate notes): not reproduced. The first `inputText` on the fresh `qa-android-1` (03-edit) passed.
- `hierarchy` with no `--udid` picks the newest live session across every project and platform on the host (`/tmp/grantiva-sessions` is shared); with the iOS agents' keep-alive sessions live, an Android user can get an iOS tree. Documented behavior, but surprising on a shared host.
- `run` force-stops the app before `launchApp` (logcat `Force stopping com.kylebrowning.landmarks` precedes each START), so the app's `singleTask` mode did not mask anything.
- AND-015 used a hand-made AVD (`qa-android-manual`) instead of `Pixel_8_API_35`: the session's safety classifier blocked running `emulator delete --name Pixel_8_API_35` against the shared AVD.
- `kill -9` of a keep-alive grantiva leaves the runner orphaned (it keeps the device; the next run is refused by the runner with "device emulator-5554 is already in use") and leaves `/tmp/grantiva-sessions/<runner>.owner.json`. Once the orphan runner is gone, the next run restores the settings and the forward (AND-068).
