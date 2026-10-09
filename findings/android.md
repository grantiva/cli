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
Evidence: findings/evidence/AND-042-screens/report/captures/qa-tab-landmarks-cmd-003-AfterLandmarksTap.png, AND-042/report/captures/failure-*.png
Suspected cause: runner Android selector order (`textContains` / `descriptionContains` / case-insensitive `textMatches`) takes the first hit, with no preference for an exact match.
