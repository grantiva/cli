# Round 3 smoke after the round-3 fix wave (2026-10-11)

Binary: `~/.grantiva-qa/bin/grantiva` 2.1.0 (CLI main dc965716), bundling grantiva-runner 1.1.28-grantiva.12
(`runner version --json` → `{"version": "1.1.28-grantiva.12"}`; installed `versions/1.1.28-grantiva.12+android-drivers-2` in `~/.grantiva-qa/runner`).
Demo: landmarks-demo 75acc87 (swipe action labelled "Remove from favorites"), ios/ and android/ copied to scratch. Session `smoke4`.
Devices: simulator `smoke4-ios` (DACD2CF4-C337-486F-98EB-02FB7A0AA705, iPhone 17, iOS 26.0); AVD `smoke4-android` (emulator-5554, API 35,
default `emulator ensure` AVD: `config.ini` `hw.gpu.enabled=no`/`mode=auto`, resolved `lavapipe`, `ro.hardware.egl=emulation`, so software rendering).
Both torn down at the end. Evidence: `evidence/round3-smoke/<ID>/` (each has `commands.txt`; every run file opens with the command and
`# start <time> <load>` and closes with `# exit` and `# wall ...; end <time> <load>`). The driver scripts are in the evidence root.

**Host load.** 2.6 before the smoke; **50.9** right after both devices booted and **108** during the parallel builds (the emulator at
240% CPU plus simulator boot daemons), 42.8 when the concurrent stock runs started, 11-15 during the Android single-flow runs
(18:16-18:35), 7-10 for the doubleTap runs, 3-8 for the keep-alive, record and teardown rows. Each row's evidence carries its own load.

| ID | Result | Evidence | Note |
|---|---|---|---|
| A0 Android ensure + build install | pass | A0/ | Created and booted in 22.8 s; freeDebug built and installed in 93.0 s (load 46-108). |
| I0 iOS ensure + build install | pass | I0/ | `simulator ensure --name smoke4-ios --device-type "iPhone 17" --runtime "iOS 26.0"` created and booted it in 22.8 s; build install 16.0 s. |
| A1 Android stock flows + screens | fail | A1/run.txt, run-client-adb-offline.txt, run-maestro-runner-tail.log, failure-home.png | Run concurrently with the iOS stock run at load 42.8: the screens phase failed at Home `✗ waitForAnimationToEnd (4.4s)` "Failed to take screenshot: UIAutomator2 server on emulator-5554 stopped responding (socket missing); retried 2 times over 4.2s"; 0 of 5 captured; the flows phase did not run; exit 1. The client log shows the cause on the host side: `adb: device offline`, then `device 'emulator-5554' not found` at 18:06:43-44 (the adb server was not restarted: its process dates from Oct 7). The failing-run summaries printed (`Screens: 5 total, 0 captured, 5 failed`). |
| A1 rerun 1 (alone) | pass | A1/rerun-1.txt | Screens 5/5 (22/22, 1m 5s); flows **12/12** (90/90, 5m 30s; wall 7:05); exit 0; load 11.8 → 12.3. 03-edit `inputText " Renamed"` 22.7 s, 04-discard `inputText "X"` 8.9 s. |
| I1 iOS stock flows + screens | pass | I1/run.txt | Screens 5/5 (21/21, 17.1 s); flows 12/12 (90/90, 1m 47s; wall 2:15) while the Android run shared the host at load 42.8 → 17.7. |
| I4 iOS 99-crash x3 | pass | I4-crash/ | 3/3 `✓ launchApp (1.9-2.0s)`, `✗ assertVisible "Landmarks"` in **157 / 144 / 167 ms** with `error.type` `app_crash` ("... is not running, possibly crashed"); steps 3-4 skipped. Wall 10.1 / 9.0 / 9.1 s; load 11-13. |
| A3 Android 99-crash x3 | fail | A3-crash/crash-1..3.txt, device-crash-times.txt, crash-<i>-maestro-runner.log | Fails at the first step after `launchApp` with `app_crash` ("app crashed after launch: java.lang.RuntimeException: LANDMARKS_CRASH_ON_LAUNCH") 3/3, and no step passed on the dead app. But: logcat `FATAL EXCEPTION` at device 18:16:59.7 / 18:17:29.0 / 18:18:00.6 (device and host clocks agree to the second), `launchApp` **passed** at 18:17:02.2 / 18:17:31.9 / 18:18:01.6 (13.1 / 11.4 / 10.5 s steps, 2.5 / 3.0 / 1.1 s after the crash), and step 1 failed at 18:17:04.0 / 18:17:33.2 / 18:18:03.7: crash to failure **4.3 / 4.2 / 3.2 s**, not ~2 s. The runner CHANGELOG says a crash during launchApp's first-frame wait fails the launch at once; here the launch passed after the crash. Wall 30.1 / 28.2 / 30.2 s (L05 acceptance: under 12 s). Load 4.3-11.4. |
| A1-03edit 03-edit alone x3 | fail | A1-03edit/run-1..3.txt, run-<i>-client.log | Flow passes 3/3, but the first find after `launchApp`, `tapOn "Deep Links"`, takes **3.7 / 4.2 / 3.9 s** (acceptance: under ~3 s, 3 of 3). The client log shows four 404 selector variants (726 + 479 + 447 + 231 ms) before the plain `text("Deep Links")` lookup answers. launchApp 10.9-13.7 s; inputText passes. Wall 59.9 / 61.7 / 64.5 s; load 11.4-13.8. |
| A-seed-many Android 10-seed-many x3 | pass | A-seed-many/seed-1..3.txt | 3/3 `✓ assertVisible "Landmark 28"` (0.9-1.1 s); scrolls 6.9-8.9 s each. Wall 61.9-66.8 s; load 11.5-13.4. |
| I-seed-many iOS 10-seed-many x3 | pass | I-seed-many/ | 3/3 (the iOS flow asserts "Landmark 30"); wall 21.3-21.5 s. |
| A-K07 Android 02-favorite swipe x10 | pass | A-K07-swipe/fav-1..10.txt | 10/10 `✓ swipe: LEFT from text="Lake Tahoe"` (5.4-7.8 s) then `✓ tapOn "Remove from favorites"` (1.2-1.9 s). The label now exists only on the swipe action, so each pass shows the row opened. Wall 39.8-43.7 s; load 9.5-12.5. |
| I-K07 iOS 02-favorite swipe x10 | pass | I-K07-swipe/ | 10/10 (swipe 641-668 ms, `tapOn "Remove from favorites"` 1.7-1.8 s); wall 19.7-22.0 s; load 11-13. |
| A-doubletap Android doubleTap x5 | fail | A-doubletap/dt-1..5.txt, dt-<i>-maestro-runner.log, dt-<i>-client.log | **1 of 5.** Runs 1-4: `✓ doubleTapOn id="gesture-pad"` then `✗ assertVisible "Double taps: 1" (17.3-17.6s)`, closest texts `"Double taps: 0", "Taps: 3"`: the app saw two single taps. The runner sends one W3C sequence (`doubleTap: (540, 1295), presses 40 ms, gap 80 ms`), but the `POST /actions` took 972 ms in run 1 (692 ms in passing run 5), so the device stretched the 200 ms sequence. Load 7.0-9.8. |
| I-doubletap iOS doubleTap x5 | pass | I-doubletap/ | 5/5 `✓ doubleTapOn` (545-667 ms), `✓ "Double taps: 1"`. |
| I-runner `runner start --detach --json` / `runner stop --json` | pass | I-runner/cycle-1.txt | session.json at +0.93 s `"state":"starting"` (no port), after return `"state":"ready"`, `port`/`wdaPort` 8417. Start JSON: `bundleId`, `bundle_id`, `log`, `pid`, `platform`, `port`, `status: started`, `udid` (4.4 s). Stop JSON: `bundleId`, `bundle_id`, `killed: false`, `pid`, `platform`, `port: 8417`, `reaped: []`, `runnerPid`, `status: stopped`, `udid`. During: runner, xcodebuild, WebDriverAgentRunner; at +0 s and +60 s only `launchd_sim`; no grantiva-runner or xcodebuild; `/tmp/grantiva-sessions` and `.grantiva` empty after. |
| A-runner same on Android | pass | A-runner/cycle-1.txt | `starting` at +0.31 s (with `applicationId`, `serial`), `ready` with port 52552 after the 6.9 s start. Start JSON has `applicationId`, `serial`, `log`, `port`; stop JSON `applicationId`, `killed: false`, `port: 52552`, `reaped: []`, `runnerPid`, `serial`, `status: stopped`. Nothing naming emulator-5554 at +0 s/+60 s; no adb forwards; no UIAutomator2 process on the device; sessions dir empty. |
| TD-ios foreground `runner start` torn down from another cwd | fail | teardown/ios-*.txt | `simulator teardown --udid <udid> --json` from an empty dir: `deleted: true`, `runnerSessionStopped: false`, and three `leftoverProcesses` with `killed: false` (the `grantiva runner start`, the runner, WebDriverAgent's xcodebuild) plus a stderr warning for each. The help says a runner session on a torn-down simulator "is stopped first". `<pid>.stop.json` appeared at 18:47:33. The foreground start did **not** exit: 5 min later the start and its runner still held the deleted UDID, and `owner.json`, `.grantiva` descriptor and `.stop.json` were all still in `/tmp/grantiva-sessions`. Only after the smoke ran `runner stop` in the project dir did the start print "Runner stopped by teardown (pid 30577); the session has ended." and exit 0; the sessions dir was then empty. The teardown had removed the device home, and the runner left running re-created an empty `devices/DACD2CF4…/cache/wda-builds/...` skeleton (removed by the smoke; HOST/after.txt). |
| TD-android same on Android | fail | teardown/android-*.txt | `emulator teardown --serial emulator-5554 --json` from an empty dir: `killed: true`, `runnerSessionStopped: false`, `sessionFilesRemoved: []`. The emulator was gone, but the start and its runner kept running for 5 min. `owner.json`, the descriptor and `34287.stop.json` stayed in place. As on iOS, only the smoke's `runner stop` ended it ("Runner stopped by teardown", exit 0; sessions dir empty). |
| KA-stop-during `runner stop` during a keep-alive run's flow | fail | I-keepalive/during-*.txt, A-keepalive/during-*.txt | Both platforms, `runner stop` from the run's project dir 8 s into the 45 s `extendedWaitUntil` printed **"No active session found."** (exit 0), although `/tmp/grantiva-sessions/<runnerPid>.owner.json` existed, naming `grantivaPid` and that `projectDirectory`. The flow ran on to its failure and the run armed the hold. A second `runner stop` during the hold released it ("Stopped keep-alive session (pid …)"), and the run exited 130. A stop during the flow did not reach the run. |
| KA-sigint-during SIGINT during the flow | pass | I-keepalive/sigint-during-run.txt, A-keepalive/sigint-during-run.txt | `kill -INT` of the run's own pid during the flow: "[grantiva] received SIGINT — releasing simulator/emulator and reaping child processes", **exit 130**, sessions dir empty, on both platforms. |
| KA-after-hold stop after the hold → earned status | fail | I-keepalive/after-{pass,fail}-*, sigint-after-{pass,fail}-*; A-keepalive/after-{pass,fail}-*, sigint-after-pass-* | Every stop after "Press Ctrl-C to release" exited **130**: iOS 01-browse (passed) 130 with both `runner stop` and SIGINT; iOS 99-crash (failed) 130 with both; Android 01-browse 130 with both; Android 99-crash 130 with `runner stop`. Ruling: exit with the earned status (0 / 1). After a failed flow, no `Flows:` summary and no `Error:` line printed on either platform. After a pass, iOS printed `Flows: 1 total, 1 passed` and Android printed it for the `runner stop` case but not for SIGINT. Sessions dir empty after every case. |
| MCP-build `grantiva_build` without a simulator | blocked | MCP-build/blocked.txt | Not run: owner simulators `iPhone 17 Pro` and `iPhone 18 Pro` were booted before, during and after the smoke. |
| SUM-text failing-run summaries without flags | pass | I4-crash/crash-1.txt, A3-crash/crash-1.txt, A1/run.txt | Both platforms print the flow block (✓ launchApp, ✗ step with its message, skipped steps), `Flows: 1 total, 0 passed, 1 failed`, then the `Error:` line, exit 1. Android screens failure printed `Screens: 5 total, 0 captured, 5 failed`. |
| SUM-quiet failing run with `--quiet` | pass | X-summaries/{ios,android}-quiet.* | stdout: the flow block, `Flows: 1 total, 0 passed, 1 failed`, `Screenshots: .grantiva/run-captures/[android/]`. stderr: only the `Error: Runner failed (exit 1): …` line, no runner narration. Exit 1 on both platforms. |
| DST `--driver-start-timeout` propagation | pass | A-driver-start-timeout/ | With `GRANTIVA_DRIVER_START_TIMEOUT=45`, the runner argv of `run` and of `runner start --detach` both contain `--driver-start-timeout 45`. Without it, the flag is absent (runner default). README:197 row matches. |
| FR-ios numeric frames | pass | I-frames/ | `hierarchy --udid <udid> --format json` from a keep-alive session: 48 frames, all `x/y/width/height` ints. |
| FR-android numeric frames | pass | A-frames/ | Same on emulator-5554: 63 frames, all ints (e.g. `{"height":28,"width":411,"x":0,"y":0}`). |
| REC-android `record --duration 3` x3 | pass | A-record/ | ffprobe: video and both data streams `duration=3.000000`, format 3.000000, 3 of 3. Idle-screen warning "held to the requested 3.0s"; frames 0/1500/2900 → 0 ms. |
| REC-ios `record --duration 3` x3 | fail | I-record/ | ffprobe: `duration=0.066667` for video and format, 3 of 3. Frame report: requested 1500 and 2900 → actual 0 ms. No hold, no trim and no note. README:372-377 documents the hold only for Android, so this may be an expectation correction. Graded fail per the "doubtful = fail" rule: a 3 s recording request yields a 0.07 s file. |
| USAGE `Error:` prefix on usage errors | pass | X-usage/ | Empty dir. `run --device a --emulator b`, `runner start --device a --emulator b` and `record --device a --emulator b --duration 3` each print `Error: --device and --emulator are mutually exclusive; pass one.`, then `Usage: …` and `See 'grantiva <cmd> --help' for more information.`, exit 64. `record --duration 0` has the same shape. Without `--duration`, the parser's missing-argument error comes first (`Error: Missing expected argument '--duration <duration>'` + Help/Usage, 64). |
| USAGE-L26a record extension error | pass | X-usage/record-ios-mp4.txt, record-android-mov.txt | iOS `.mp4` and Android `.mov` each print `Error: --output must end in .mov on iOS (…)` / `.mp4 on Android (…)`, with a suggested path and the Usage + See lines, exit 64; no `Invalid argument:`. |
| HELP help corpus | pass | HELP/ | 172 pages regenerated with the round-2 `helpcorpus.sh`; 12 changed (+87/-108): build_build, build_install, ci_run, diff_capture, diff_compare, emulator_teardown, mcp, run, runner_install, runner_start, runner_stop, simulator_teardown. |
| END teardown end state | pass | HOST/before.txt, HOST/after.txt, teardown/avd-delete-and-sessions.txt | AVD deleted (`avdmanager delete avd -n smoke4-android`). `simctl … grep -c smoke4` = 0; booted before and after: `iPhone 17 Pro` and `iPhone 18 Pro` only (never touched). `adb devices` empty; AVDs: `Pixel_8_API_35` only. `/tmp/grantiva-sessions` empty; `simulator sessions --json` `[]`. No grantiva-runner, qemu or xcodebuild process; no lock for DACD2CF4. The empty device-home skeleton from TD-ios was removed. |

Counts: 31 rows; 1 blocked (MCP-build); 30 graded: **21 pass, 9 fail** (A1, A3, A1-03edit, A-doubletap, TD-ios, TD-android,
KA-stop-during, KA-after-hold, REC-ios). Rerun line: A1 rerun 1 pass (12/12 + 5/5 alone).

## Interpretation

- **Fixed and holding.** Several round-3 behaviours hold on both platforms:
  - the 02-favorite swipe now proves the row opened, 10/10 on each platform;
  - 10-seed-many reaches Landmark 28 on Android;
  - `runner start`/`stop` JSON shapes and the `starting` → `ready` session state;
  - helper reaping (nothing left at +0 s);
  - failing-run summaries, with and without `--quiet`;
  - numeric frames, Android recording trim, the usage-error shape, and `--driver-start-timeout` propagation.
  - iOS crash detection takes 144-167 ms.
- **Android crash timing (A3).** No step passes on the dead app any more, which was the round-3 fix. But `launchApp` still passes 1-3 s after `FATAL EXCEPTION`, and the failure lands 3.2-4.3 s after the crash, with a 28-30 s wall time.
- **Android first find (A1-03edit).** The first find after launchApp takes 3.7-4.2 s at load 11-14. Most of that goes to four 404 selector variants before the plain text lookup.
- **Android doubleTap (A-doubletap).** At load 7-10, the single W3C sequence is stretched on the device (`/actions` 0.7-1.0 s for a 200 ms gesture), and the app counts two taps 4 times in 5.
- **Teardown with a foreground `runner start` (TD-ios, TD-android).** Teardown writes the stop marker, but it neither stops the runner session (`runnerSessionStopped: false`) nor does the runner die with its device. The start keeps running indefinitely on a deleted simulator or a killed emulator, and its session files and `.stop.json` stay in `/tmp/grantiva-sessions` until a `runner stop` from the project dir. The message and exit code are right once the start does end.
- **Keep-alive stops (KA-stop-during, KA-after-hold).**
  - `runner stop` does not find a keep-alive run until its hold is armed.
  - A stop or Ctrl-C after the hold exits 130 rather than the earned 0/1. The runner CHANGELOG says the runner itself exits with the earned status, so the 130 likely comes from the CLI's SIGINT handling.
- **A1 first attempt.** adb lost the emulator for about a second at load 43 while both stock runs shared the host. The rerun alone passed.

## Round 3 re-smoke (runner .13, CLI 2f4d8381)

Run 2026-10-12 00:27-00:57. Binary: `~/.grantiva-qa/bin/grantiva` 2.1.0 (CLI main 2f4d8381, installed 00:26). It bundles runner 1.1.28-grantiva.13
(`runner version --json` → `{"version": "1.1.28-grantiva.13"}`; installed `versions/1.1.28-grantiva.13+android-drivers-2` in `~/.grantiva-qa/runner`).
Demo: landmarks-demo 75acc87, ios/ and android/ copied to scratch. Session `smoke5`. Devices:
- simulator `smoke5-ios` (iPhone 17, iOS 26.0): FD651786… for I-record, I-keepalive and TD-ios run 1, then re-created as 446D4576… and 3354BC21… for the TD-ios reruns;
- AVD `smoke5-android` (emulator-5554, default `emulator ensure` AVD: `hw.gpu.enabled=no`, `ro.hardware.egl=emulation`).

The platforms ran serially: all iOS work first, then all Android work, never two builds at once. Each step's evidence carries its uptime/load.

**Host load.** Load was 2.7 at the start. It rose to 30-58 around the simulator boot and the iOS build. It was 46-55 during I-record (no grantiva process of ours was busy; other host activity) and 26 → 12 during I-keepalive. During TD-ios runs 2-3 it rose to 59-95 (simulator re-creation and boot). Android: 23.6 → 10.5 during the stock set, then 7-13 for every later Android row.

Evidence: `evidence/round3-resmoke/<check>/`. Each directory has a `commands.txt`. The driver scripts are copies of the round-3 scripts with smoke5 paths, kept in the evidence root. `keepalive*.sh` add `--ready-file` and the time from the stop to the run's exit; `android-batch.sh` has this run's reduced batch.

**MCP-build.** Run only when `simctl list devices booted` shows no owner simulator. `iPhone 17 Pro` and `iPhone 18 Pro` were booted before, during and after this run, so the check is blocked again.

| check | round-3 result | re-smoke result | evidence |
|---|---|---|---|
| A1 Android stock flows + screens (alone) | fail (adb offline at load 43; rerun alone passed) | **pass** | A1/run.txt |
| A3 Android 99-crash ×3 (L57) | fail (launchApp passed after FATAL; failure 3.2-4.3 s after it) | **pass** | A3-crash/ |
| A1-03edit 03-edit ×3, first `tapOn "Deep Links"` (L58) | fail (3.7-4.2 s, four 404 variants first) | **pass** | A1-03edit/ |
| A-doubletap doubleTap ×5 (L59) | fail (1/5) | **pass** (5/5) | A-doubletap/ |
| TD-ios foreground `runner start`, teardown from another cwd (L54) | fail | **fail** | teardown/run{1,2,3}-ios-*, ios-device-home-after.txt |
| TD-android same (L54) | fail | **pass** | teardown/android-* |
| KA-stop-during `runner stop` during a keep-alive flow (L55) | fail | **pass** (iOS and Android) | I-keepalive/during-*, A-keepalive/during-* |
| KA-after-hold stop/Ctrl-C after the hold → earned status (L56) | fail | **pass** (8/8) | I-keepalive/{,sigint-}after-{pass,fail}-*, A-keepalive/ same |
| REC-ios `record --duration 3` ×3 (L60) | fail (0.067 s file) | **pass** | I-record/ |
| MCP-build `grantiva_build` without a simulator | blocked | **blocked** | MCP-build/blocked.txt |
| L61 Android failure-capture time (measurement) | n/a (open) | 4.3-6.8 s (not worse than the brief) | A3-crash/L61-capture-times.txt |
| L62 Android 02-favorite ×5 (measurement) | n/a (open) | 5/5 pass | L62-02favorite/ |

Rerun lines:
- **TD-ios runs 2 and 3.** These ran on freshly re-created simulators to test whether the `simctl diagnose` leftover from run 1 repeats. It repeats 3/3.

Counts: 10 re-smoked checks, **8 pass, 1 fail (TD-ios), 1 blocked (MCP-build)**, plus 2 measurement rows (L61, L62).

### Per-check notes

- **A1 (pass).** Alone, load 23.6 → 10.5: `Screens: 5 total, 5 captured, 0 failed` and `Flows: 12 total, 12 passed, 0 failed`, exit 0, wall 7:31.
- **A3 (pass).** All three runs report `error.type` `app_crash` with `LANDMARKS_CRASH_ON_LAUNCH`, exit 1. Times are from logcat `FATAL EXCEPTION` (device clock, which matches the host to the second) to the runner's step failure:

  | run | FATAL EXCEPTION | step failure | FATAL → failure | wall | load |
  |---|---|---|---|---|---|
  | 1 | 00:43:25.645 | `✗ launchApp` at 00:43:26.530 | **0.89 s** | 29.2 s | 10.5 |
  | 2 | 00:43:53.033 | `✗ launchApp` at 00:43:53.567 | **0.53 s** | 29.5 s | 10.0 |
  | 3 | 00:44:23.650 | `✗ assertVisible "Landmarks"` (`app crashed after launch`) at 00:44:24.859 | **1.21 s** | 26.8 s | 10.5 |

  In run 3 the app threw 76 ms after `launchApp` had passed (00:44:23.574), so the failure landed at the next step, which the acceptance allows. No step passed on the dead app. Wall time is informational.
- **A1-03edit (pass).** The flow passed 3/3 (wall 47.9 / 52.0 / 51.4 s, load 11.5-11.7).
  - First `tapOn "Deep Links"` after `launchApp`: **2.7 / 3.3 / 2.9 s** (informational).
  - Runner overhead before the first request: 1 / 2 / 1 ms. Measured from `Executing step 1` in the runner log to the send time of the first `POST /elements` in the client log (completion minus duration). The acceptance is < 300 ms.
  - The plain `text("Deep Links")` query now goes first, and no 404 variants come before it. The step makes 1 `POST /elements` (1.43-1.76 s on the device), then `GET …/attribute/clickable`, then `GET /source` (0.62-0.85 s, the clickable-parent lookup that the ledger ruling accepts), then the click.
- **A-doubletap (pass).** 5/5 `✓ doubleTapOn id="gesture-pad"` → `✓ "Double taps: 1"`, with `Taps: 1` unchanged. The runner log shows `doubleTap: (540, 1295) on the device (cmd input motionevent), gap 80 ms planned, took 255-309ms`. Load 7.4-12.5.
- **TD-ios (fail).** The L54 core behaviour now works 3/3:
  - teardown from an empty dir gives `deleted: true` and `runnerSessionStopped: true`;
  - the foreground start prints `Runner stopped by teardown (pid N); the session has ended.` and exits 0, 7 s after the teardown began, in each run;
  - `/tmp/grantiva-sessions` is empty afterwards;
  - no process names the UDID 2 s after the start exits.

  Graded fail because the teardown still reports a leftover process 3/3:
  - **The `simctl diagnose` leftover.** xcodebuild starts `simctl diagnose … --output=<runner home>/devices/<udid>/cache/wda-builds/…/attempt-1.xcresult/…/simctl_diagnostics --udid=<udid>` when its WDA test run is cut off. The teardown lists it in `leftoverProcesses` (`kind: diagnose`, `killed: false`). It also prints `Warning: <udid> is still held by diagnose pid N, which this teardown did not start: … Stop it, or reclaim the simulator with grantiva simulator teardown --udid <udid> --force.`
  - **The orphan device home.** After run 3, the diagnose output re-created the device home that the teardown had just removed (`devices/3354BC21…/cache/wda-builds/…/simctl_diagnostics`, 9.1 MB, still there 40 s later; ios-device-home-after.txt). The smoke removed it. Runs 1-2 left no home by the time of the later check.
  - This is the same orphan-skeleton symptom that round 3 saw, now caused by the diagnose child rather than the runner. The acceptance asks for no leftover processes, and a warning that tells the user to `--force` a clean teardown is doubtful, hence the fail.
  - Harness artefact, not graded: run 2 also listed this smoke's own zsh wrapper as a `grantiva` leftover, because its argv contained the UDID.
- **TD-android (pass).** Same check on Android, 1 run:
  - teardown gives `killed: true` and `runnerSessionStopped: true`;
  - the start printed `Runner stopped by teardown (pid 40698); the session has ended.` and exited 0, 5 s after the teardown began;
  - the sessions dir is empty; no process names emulator-5554 and no grantiva-runner or qemu is left; `adb devices` and `adb forward --list` are empty.
- **KA-stop-during (pass).** `runner stop` 8 s after the `launchApp` line of `coverage/18-long-wait.yaml`:

  | platform | `runner stop` output | run exit | stop → exit | ready file |
  |---|---|---|---|---|
  | iOS | `Stopped keep-alive session (pid N, <udid>)`, exit 0 | 130, with `received SIGINT — releasing simulator…` | 0.47 s | `"status": "interrupted"` |
  | Android | same | 130 | 2.09 s | `"status": "interrupted"` |

  The sessions dir was empty after both.
- **KA-after-hold (pass).** Every release after `Press Ctrl-C to release` exits with the earned status:

  | platform | flow | `runner stop` | SIGINT |
  |---|---|---|---|
  | iOS | 01-browse (passed) | exit 0 | exit 0 |
  | iOS | 99-crash (failed) | exit 1 | exit 1 |
  | Android | 01-browse (passed) | exit 0 | exit 0 |
  | Android | 99-crash (failed) | exit 1 | exit 1 |

  - Every run prints the flow block and the `Flows:` line; the failures add the `Error: Runner failed (exit 1): …` line.
  - Android prints `received SIGINT — releasing the keep-alive hold`.
  - The ready file stays `passed` / `failed`.
  - Stop → exit took 0.2-0.8 s on iOS and 1.9-4.7 s on Android.
  - The sessions dir was empty after every case, and no grantiva-runner or xcodebuild process was left.
- **REC-ios (pass).** ffprobe gives `duration=3.000000` for the video stream and the format, 3/3. `nb_frames` was 2 / 1 / 2: an idle screen yields few frames (frames past 3 s may remain in a file per the ruling; none did here).
  - Runs 1-2 printed the idle-screen warning (`last frame is at 477ms / 0ms; it was held to the requested 3.0s. The simulator records a frame only when the screen changes…`). The wording names neither screenrecord nor a device disconnect.
  - Run 3 printed no warning: its last frame is at 2842 ms, so it was not held for more than half the recording.
  - The frame report carries `lastFrameMilliseconds` and `recordedMilliseconds` (run 1: 477 / 953). Frames map to 0 / 477 / 477 ms (run 1) and 0 / 0 / 2842 ms (run 3).
  - Load 46-55.
- **MCP-build (blocked).** Owner simulators were booted at 00:30:59 (MCP-build/blocked.txt) and in HOST/before.txt and HOST/after.txt.
- **L61 (measurement).** Time from the step failure in the runner log to the failure artefacts (ms mtimes):

  | run | to `cmd-*-after.png` | to the hierarchy XML | to the CLI's `captures/failure-*.png` (after the runner exits) |
  |---|---|---|---|
  | 1 | 5.30 s | 5.60 s | 10.5 s |
  | 2 | 6.80 s | 7.10 s | 13.3 s |
  | 3 | 4.28 s | 4.50 s | 9.1 s |

  This is within the 5-10 s the brief describes, not worse, so it is not a fail row. It remains most of the 27-30 s crash-run wall time.
- **L62 (measurement).** 02-favorite ×5 on the default AVD at load 8.6-9.9: 5/5 pass, with `✓ swipe LEFT from "Lake Tahoe"` (5.0-5.4 s), then `✓ tapOn "Remove from favorites"` (1.0-1.2 s), then `✓ assertNotVisible "Lake Tahoe"`. The intermittent failure did not reproduce on this (slow, software-rendered) AVD.

### End state

- AVD `smoke5-android` deleted (`avdmanager delete avd`); AVDs: `Pixel_8_API_35` only; `adb devices` empty.
- `simctl list devices | grep -c smoke5` = 0; `simulator sessions --json` `[]`.
- Booted simulators before and after: `iPhone 17 Pro` and `iPhone 18 Pro` only, identical, never touched.
- `/tmp/grantiva-sessions` empty.
- No grantiva-runner, xcodebuild, qemu or `simctl diagnose` process.
- No runner device home left in `versions/1.1.28-grantiva.13…/devices/`: the orphan home from TD-ios run 3 was removed by the smoke.
- Files: HOST/before.txt, HOST/after.txt, teardown/avd-delete-and-sessions.txt.
