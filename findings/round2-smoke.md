# Round 2 smoke after the fix wave (2026-10-11)

Binary: `~/.grantiva-qa/bin/grantiva` 2.1.0 (main 5eab55d), bundling grantiva-runner 1.1.28-grantiva.10
(`versions/1.1.28-grantiva.10+android-drivers-2` in `~/.grantiva-qa/runner`). Demo: landmarks-demo b3f046f, ios/ and android/
copied to scratch (build dirs removed). Devices: simulator `smoke2-ios` (F7DCF106-9DDF-491B-BB72-68D90CFFE1AB, iPhone 17, iOS 26.0);
AVD `smoke2-android` (emulator-5554, API 35). Both torn down at the end. Evidence: `evidence/round2-smoke/<ID>/` (each has
`commands.txt`; every output file starts with its exact command and ends with the exit code).

**Environment caveat (read before the Android fails).** The emulator ran 3-4x slower than in round 1: launchApp 6-7 s vs 1.9 s,
02-favorite 24.9 s vs 6.9 s, inputText "X" 7.1 s. The AVD `emulator ensure` created has `hw.gpu.enabled=no`
(`ro.hardware.egl=emulation`, software rendering; `dumpsys gfxinfo`: 148 of 150 frames janky), window animations at 1.0, and the
host load average was 7-15 from other sessions. round2-A1-03edit and round2-A-K07 may depend on device speed; the round-1 AVD's
GPU setting is not recorded, so a re-run on a quiet host is needed before blaming runner .10.

| ID | Result | Evidence | Note |
|---|---|---|---|
| round2-A0 Android ensure + build install | pass | round2-A0/ | AVD created and booted in 17.6 s; freeDebug built and installed in 32.1 s. |
| round2-A1 Android stock flows (12) | fail | round2-A1/run.txt, run-attempt1-parallel-with-ios.txt, run-without-03.txt, run-11-slow.txt, run-12-quote-label.txt, failure-*.png | Stock run 2/12 twice (alone and concurrent with iOS): 03-edit fails, 04-12 skipped. With 03-edit removed from a scratch config: 8/11, 10-seed-many fails (round2-A-K07), 11/12 skipped; 11-slow and 12-quote-label pass alone. Net: 10 of 12 pass, 03-edit and 10-seed-many fail. |
| round2-A1-screens Android screens (5) | pass | round2-A1/run.txt lines 1-90 | Screens flow 21/21 steps, 5 captures, in every Android stock run. On a failing run no `Screens:`/`Flows:` summary line is printed (iOS prints both). |
| round2-A1-03edit Android inputText append | fail | round2-A1-03edit/ (run-1..3, run-1-client.log, run-1-maestro-runner.log, ../round2-A1/failure-03-edit.png) | 3 of 3 alone: `✗ inputText: " Renamed" (12.3-13.7s)` — `POST /session/<id>/actions [10.0019595s] ERROR: ... context deadline exceeded (Client.Timeout exceeded while awaiting headers)`. The failure screenshot shows the field already reads "Golden Gate Bridge Renamed" with the cursor at the end: the text was typed, the 10 s HTTP client timeout on the key-actions request expired first and the step failed. Round 1 (.9): 2.8 s pass. 04-discard's `inputText "X"` passes (7.1 s). |
| round2-A2-K09 swipe reveals Remove, row opens | pass | round2-A2-K09/ | 02-favorite 3/3 (`✓ swipe: LEFT from text="Lake Tahoe"` 1.2-1.4 s, `✓ tapOn "Remove"`); cmd-008 before ≠ after every run, after shows the Remove action. Coverage 05-swipe-forms passes (24.3 s). |
| round2-A3 Android 99-crash | fail | round2-A3/ | `error.type` is `app_crash` (crash-3-flow-000.json) and the message carries `java.lang.RuntimeException: LANDMARKS_CRASH_ON_LAUNCH`, but it does not fail fast: `assertVisible "Landmarks"` polls 10.2-10.7 s against the dead app and **passes** in 2 of 3 runs (runs 1, 3; the crash surfaces on the next step `assertVisible "Featured"` in 0.7 s); run 2 fails at "Landmarks" after 10.7 s. Flow 17.5 s; wall clock 26.8-30.2 s (round 1: flow 2.4-2.6 s, wall 5.0-5.4 s). |
| round2-A-K07 Android 10-seed-many asserts Landmark 28 | fail | round2-A-K07/, ../round2-A1/run-without-03.txt line 215 | Alone, 2 of 2: after four bare scrolls the page shows Landmark 14-22 (cmd-005-hierarchy.xml); `✗ assertVisible "Landmark 28" (17.6-19.0s)`. Deterministic run to run but 6 rows short of the 28-29 the fix device check saw. In the stock set the closest texts were "Landmarks", "Mono Lake", "Lake Tahoe" (no seeded rows at all) and the failure screenshot shows the unseeded list. Scroll steps took 1.3-7.7 s (settle waits on a slow device). |
| round2-A-K22 Android inline runFlow commands | pass | round2-A-K22/run.txt | `✓ runFlow` with nested `✓ tapOn "Favorites"` and `✓ assertVisible ...` shown as steps; 3/3. |
| round2-A-K109 Android extendedWaitUntil timeout | pass | round2-A-K109/ | 09-waits 8/8 (`extendedWaitUntil: notVisible` 3.0 s). Config staging: `✓ extendedWaitUntil: visible text="Cache Policy"` and `Wait until visible "Cache Policy" (5000ms max)`; with "No Such Element"/2000: `✗ ... (2.3s)` "not visible within 2s". |
| round2-I0 iOS ensure + build install | pass | round2-I0/, round2-X-b-runtime/version-only.txt | The command as given (`--name smoke2-ios --runtime "iOS 26.0"`) is refused: "Could not infer a device type from the name" (see round2-X-b). Created with `--device-type "iPhone 17" --runtime 26.0`. Build install 14.0 s. |
| round2-I1 iOS stock flows + screens | pass | round2-I1/run.txt | Flows 12/12 (90/90 steps, 1m 45s; wall 2:13 while the Android run shared the host); screens 5/5 (21/21). `✓ Using cached GrantivaAgent build (sim-ios26.0-iphone-wda16.12.8-r1)` in both phases, and the round-1 "Building GrantivaAgent... / GrantivaAgent built" wrapper lines are gone. Android banner reads `Running the flows in one UIAutomator2 session`, iOS `... GrantivaAgent session` (round-1 observation fixed). |
| round2-I2 iOS 03-edit | pass | round2-I1/run.txt lines 143-151 | inputText " Renamed" 1.0 s, Done 1.1 s, assert "Golden Gate Bridge Renamed" ✓. |
| round2-I4 iOS 99-crash | pass | round2-I4-crash/ | 3 of 3: `✓ launchApp (1.9s)`, `✗ assertVisible "Landmarks" (128-158ms)` with "app crashed: com.kylebrowning.Landmarks is not running"; `error.type` `app_crash` (crash-3-flow-000.json). Flow 3.7 s; wall 8.8-9.8 s. |
| round2-I-K22 iOS inline runFlow commands | pass | round2-I-K22/run.txt | Nested steps shown; 3/3. |
| round2-I-K109 iOS extendedWaitUntil timeout | pass | round2-I-K109/ | 09-waits 8/8; staging logs `extendedWaitUntil: visible text="Cache Policy"` / `(5000ms max)`; the 2 s variant fails in 2.7 s. |
| round2-I-K74 iOS 10-lifecycle `--flag` | pass | round2-I-K74/launch-lines.txt, maestro-runner.log | Flow 16/16. `launchApp com.kylebrowning.Landmarks: argv=["--flag" "true"] env=map[]`; launch body `{"arguments":["--flag","true"],"bundleId":"com.kylebrowning.Landmarks"}` (no `environment`). |
| round2-MCP-K53 MCP isError | pass | round2-MCP-K53/ios/transcript.txt, android/transcript.txt | iOS `grantiva_build` and `grantiva_sim_boot` with "no-such-sim", Android `emulator_delete` (hand-made AVD), `emulator_boot`/`emulator_delete` "no-such-avd": every answer is `result` with `isError: true`, no `error` key. Refusal reads "Pass force: true to delete it anyway." The force delete succeeds (`{"deleted":true,...}`). |
| round2-X-a `runner --json` | pass | round2-X-a-runner-json/out.txt | `runner --json` → `Error: Unknown option '--json'` (exit 64); `runner status` does not exist. Neither form is documented: README:356 lists `grantiva runner version`, which prints `grantiva-runner 1.1.28-grantiva.10`, and `runner version --json` → `{"version": "1.1.28-grantiva.10"}`. The fix-wave plan's Task 14 Step 2 uses the undocumented form. No command prints the installed stamp (`+android-drivers-2`) as JSON; `ls versions/` shows .7, .9 and .10. |
| round2-X-b `--runtime 26.0` vs `"iOS 26.0"` | pass | round2-X-b-runtime/ | Both forms work for create (`--device-type "iPhone 17" --runtime 26.0` created the device) and for reuse (`Reused smoke2-ios`). The refusal the controller saw is the device-type rule: a new name without a model and without `--device-type` fails with "Could not infer a device type from the name ... pass --device-type", for either runtime form. `simulator ensure --help` documents it in the OVERVIEW and lists `--runtime` as "Runtime name, version, identifier, or `latest`". |
| round2-X-c `--quiet` / `--json` | pass | round2-X-c-quiet-json/ | Both platforms: `--quiet` stderr empty, stdout 8 summary lines, no runner lines; `--json` stdout parses as one JSON document, stderr empty; exit 0. |
| round2-X-d `runner start --detach` + `runner stop` | pass | round2-X-d-detach/ios.txt, android.txt | `/tmp/grantiva-sessions` empty before, holds `<pid>.owner.json` during, empty after, on both platforms; `.grantiva/session.json` removed. |
| round2-X-d2 nothing left holding the simulator after `runner stop` | fail | round2-I3-teardown/teardown.txt line 4, round2-X-d-detach/ios.txt | `simulator teardown --force` printed `Killed diagnose pid 61570 holding F7DCF106-...` about 9 minutes after the iOS `runner stop`. Pid 61570 falls between the iOS runner (61488) and the Android runner (61616), so it most likely is the `simctl diagnose` a dying runner starts (SimulatorReaper.swift:199) and it outlived `runner stop`. Inference from pid order only; the process command line was not captured. |
| round2-X-e Android keep-alive banner | pass | round2-X-e-keepalive/run.txt | `UIAutomator2 keep-alive: session=...`, `Press Ctrl-C to release.`, `Releasing UIAutomator2 session...`; no GrantivaAgent. `runner stop` released it ("Stopped keep-alive session (pid 61836, emulator-5554)"), run exited 130, sessions dir empty. |
| round2-HELP help corpus | pass | round2-HELP/ | 172 pages regenerated; 17 changed (list below). |
| round2-HELP-K61 `grep -rl GrantivaAgent findings/help` | fail | round2-HELP/k61-grep.txt | Hits `run.txt` and `hierarchy.txt`, which serve both platforms, so the check as written fails. Every hit names the Android counterpart, as K61's acceptance asks: run `--keep-alive` "(GrantivaAgent on iOS, UIAutomator2 on Android)", hierarchy "from GrantivaAgent on iOS, from the UIAutomator2 server on Android" and `--timeout` "GrantivaAgent's (iOS) or UIAutomator2's (Android)". The other K61 strings are present (runner/runner start abstract = README:333, dump-hierarchy `--port`, `--app-file`). This is probably an expectation correction, not a product fault. |
| round2-I3 teardown + end state | pass | round2-I3-teardown/teardown.txt, teardown-2.txt | `simulator teardown --udid --force` removed `versions/1.1.28-grantiva.10+android-drivers-2/devices/F7DCF106-...` (count 1 → 0) but kept the session record, as its message says; `simulator teardown --session-id smoke2` then deleted the simulator. `emulator teardown --name` is not an option (exit 64; help offers `--serial`/`--all`); `--serial emulator-5554` worked. End: `simctl ... grep -c smoke2` = 0, `adb devices` empty, AVDs = Pixel_8_API_35 only, `/tmp/grantiva-sessions` empty, no lock for the UDID. |

Counts (round2 rows): 26 rows, 20 pass, 6 fail (round2-A1, round2-A1-03edit, round2-A3, round2-A-K07, round2-X-d2, round2-HELP-K61).
Counts with the quiet-host re-run below: 34 rows, 23 pass, 11 fail (adds round2b-A1, round2b-A1-03edit, round2b-A3, round2b-A-K07, round2b-AB).
Counts with round 3 (runner .11) below: 47 rows, 35 pass, 12 fail (round 3 adds 13 rows: 12 pass, 1 fail: round3-A2-K09).

## Help corpus changes (`git diff --stat findings/help`, 17 pages, +106/-38)

build_build, build_install, ci_run, console_releases_update, diff_capture, diff_compare, emulator, emulator_ensure,
emulator_teardown, hierarchy, run, runner, runner_dump-hierarchy, runner_install, runner_start, runner_stop, simulator_teardown.

## Host state after teardown

- `xcrun simctl list devices | grep -c smoke2` = 0; booted: only `iPhone 17 Pro` (B27D7D31…, booted before this smoke, not touched).
- `adb devices`: empty. `avdmanager list avd -c`: `Pixel_8_API_35`. No qemu or grantiva-runner process for smoke2.
- `/tmp/grantiva-sessions`: empty. `~/.grantiva-qa/runner/locks`: no lock for F7DCF106 (locks from other sessions remain, untouched).
- Hand-made AVD `smoke2-k53-hand` (K53 repro) deleted by the MCP force call.
- The `smoke2-android` AVD was deleted with avdmanager while it was still running (sequencing slip after the `--name` usage error);
  `emulator teardown --serial emulator-5554` then killed it cleanly.

## Observations (not counted)

- Android `run` on a failing stock set prints no `Screens: 5 total, 5 captured` line even though the screens phase passed.
- `runner version --json` gives only `version`, not the installed stamp; the plan's "runner --json lists the new stamp" has no command behind it.
- Concurrent iOS + Android stock runs on one host work (iOS 12/12 while Android ran), but the Android timings doubled.

## Quiet-host Android re-run (round2b, 06:49-07:03)

The coordinator asked for a re-run of the failed Android rows on a fresh AVD `smoke2b-android` (emulator-5554, API 35, `emulator ensure`),
same binary, env and demo copy. Evidence: `evidence/round2-smoke/round2b-<ID>/`; each run file opens and closes with `uptime`.
Load was 2.17 before the AVD booted. It climbed to 6-12 while the runs were going: the emulator itself (qemu at 77-100% CPU) plus
`corespotlightd` at 200% during part of it, which was not started by this smoke. The host was quieter than in round2 but not idle.

| ID | Result | Evidence | Note |
|---|---|---|---|
| round2b-GPU AVD graphics | pass (facts) | round2b-A0/ensure.txt | `config.ini`: `hw.gpu.enabled=no`, `hw.gpu.mode=auto`. Resolved at boot (`hardware-qemu.ini`): `hw.gpu.enabled = true`, `hw.gpu.mode = lavapipe`. `ro.hardware.egl` = `emulation`; `ro.boot.qemu.gltransport.name` = `pipe`; `ro.opengles.version` 196609; SurfaceFlinger `GLES: ... ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device ...))`, so rendering is software (lavapipe/SwiftShader). qemu argv: `-avd smoke2b-android -port 5554 -no-snapshot-save -no-boot-anim`. Round 1: config.ini was not recorded (unknown). `emulator ensure` passes no GPU option at 51c597a or 5eab55d (EmulatorManager.swift:229-230 only adds `-no-window` when headless), so the round-1 AVD most likely had the same avdmanager defaults. |
| round2b-A0 ensure + build install | pass | round2b-A0/ | Created and booted in 17.7 s; build install 7.4 s. |
| round2b-A1 stock flows + screens | fail | round2b-A1/run.txt | Screens 21/21 in 11.1 s. Flows 2/12: 01-browse 3.9 s and 02-favorite 6.9 s (the round-1 speeds), then 03-edit fails at `inputText " Renamed" (13.6s)` and 04-12 are skipped. Load 6.08 → 9.69. |
| round2b-A1-03edit 03-edit alone x3 | fail | round2b-A1-03edit/run-1..3.txt, run-<i>-client.log | 3/3: launchApp 2.0 s, tapOn steps 1.2-2.0 s, then `✗ inputText " Renamed"` 13.8 / 13.6 / 13.7 s (round 1: 2.8 s pass). Client log, every run: `GET /element/active` OK, `GET /element/<id>/text` OK, then `POST /session/<id>/actions [10.0026s / 10.0025s / 10.0014s] ERROR: ... context deadline exceeded (Client.Timeout exceeded while awaiting headers)`, which is the 10 s HTTP client timeout. Wall 51 s per run; load 8.9-12.0. |
| round2b-AB runner .9 vs .10, same AVD | fail | round2b-AB-runner/ | Both runner binaries driven directly (`grantiva-runner --platform android --device emulator-5554 test .maestro/03-edit.yaml`): .9 (commit ae48e34) `✗ inputText " Renamed" (15.6s)`, and .10 `✗ (13.2s)`. Both fail with the same `POST .../actions ... Client.Timeout exceeded`. The 99-crash A/B is not valid: driven directly, the app did not crash (`✓ assertVisible "Featured"` on both), so the flow's crash env did not reach the app on that path. Not investigated. |
| round2b-A3 99-crash x3 | fail | round2b-A3/crash-1..3.txt, crash-<i>-client.log, -maestro-runner.log, -flow-000.json | Time to failure: flow 20.7 / 16.8 / 18.0 s, wall 35.6 / 27.4 / 31.7 s. Runs 1 and 3: `✓ assertVisible "Landmarks" (10.2s / 10.3s)` passes on the dead app, then `✗ assertVisible "Featured"` in 0.65-0.74 s with `error.type` `app_crash`. Run 2: `✗ assertVisible "Landmarks" (11.3s)`, `app_crash`. Client log, run 1: the first `POST /element` (text "Landmarks") blocks for `[10.001s] ERROR ... Client.Timeout exceeded`, then `textMatches("(?ims)(?:Landmarks)")` returns OK in 33 ms. Runs 2 and 3 show the same 10.00 s blocked `POST /element`. |
| round2b-A-K07 10-seed-many x3 | fail | round2b-A-K07/run-1..3.txt, run-<i>-cmd-005-hierarchy.xml, run-<i>-client.log | Last landmark visible: 22, 22, 22 (first visible 14 every run); `✗ assertVisible "Landmark 28"` after 17.7-19.0 s. Scroll steps 2.8-8.9 s; each bare scroll is a `POST /actions` drag taking 4.0-7.3 s in the client log. Load 6.0-8.9. |
| round2b-teardown | pass | round2b-teardown/teardown.txt | `emulator teardown --serial emulator-5554` → "Killed emulator-5554 (smoke2b-android)."; `avdmanager delete avd -n smoke2b-android` → deleted. `adb devices` empty; AVDs: Pixel_8_API_35; smoke2 simulators 0; `/tmp/grantiva-sessions` empty; no smoke2 process. |

**Interpretation, row by row.**

- **round2b-A1 / round2b-A1-03edit: a defect that this environment exposes, not a .10 regression.** The emulator ran at round-1 speed (01-browse 3.9 s, 02-favorite 6.9 s), yet 03-edit failed the same way 4 of 4 times. Runner .9 fails identically on the same AVD, so this is not a .10 regression. The round-1 pass (2.8 s) was on another AVD and host state that were not recorded.
  - What happens: the UIAutomator2 server takes more than 10 s to answer the key-actions `POST /actions` for 8 characters on this software-rendered AVD. Every scroll drag on the same path takes 4-7 s, which points the same way.
  - Host load contributes, but at load 5-12 it reproduces every time.
  - The defect: a fixed 10 s client timeout fails a step whose text was in fact typed. The failure screenshot from the loaded run shows the full "Golden Gate Bridge Renamed".
- **round2b-A3: defect.** The visible wait does poll for a crash (`crashPoll` 1 s, uiautomator2/commands.go:1477-1486), but one `POST /element` against the dying app blocks for the full 10 s HTTP timeout, so no crash check runs in that window.
  - After the timeout the regex retry finds a "Landmarks" text and the assert **passes** on a dead app (2 of 3 runs). The likely sources are the crash dialog or the launcher label; no capture was taken at that step.
  - So the crash short-circuit exists but does not cover a blocked server call, and the K97 fast fail (WDA) has no working counterpart on UIAutomator2 here.
  - Round 1 (.9): `assertVisible` failed in 318 ms. The .9 comparison could not be repeated (see round2b-AB).
- **round2b-A-K07: not a load artefact.** The flow lands on Landmark 22 in 3 of 3 runs on the fresh AVD and 2 of 2 on the round2 AVD, under both heavy and moderate load. The scroll is deterministic, but its distance on this AVD is 6 rows short of the 28-29 the fix device check saw. Either the held-drag distance depends on the device (graphics backend or frame pacing during the 4-7 s `/actions` drag), or the Landmark 28 expectation only holds for the AVD it was tuned on.

## Round 3 (runner .11)

Binary: `~/.grantiva-qa/bin/grantiva` 2.1.0 (main c65fc17) with grantiva-runner 1.1.28-grantiva.11 (`versions/1.1.28-grantiva.11+android-drivers-2`;
runner PR #20 L01-L04, CLI PR #198 L04 reaper). Session `smoke3`. Devices: AVD `smoke3-android` (emulator-5554, API 35, fresh default
AVD from `emulator ensure`: `config.ini` `hw.gpu.enabled=no`/`mode=auto`, resolved `lavapipe`, SurfaceFlinger ANGLE on SwiftShader, so
rendering is software); simulator `smoke3-ios` (6B18B654-219E-426E-A024-FEC8E0C44977, iPhone 17, iOS 26.0). Evidence:
`evidence/round2-smoke/round3-<ID>/`. Load: 3.2 at the start, **46.5** when the Android stock run began (from outside this
smoke; it fell to 9.0 by its end), then 7-16 during the Android single-flow runs and 3-7 during the iOS rows.

| ID | Result | Evidence | Note |
|---|---|---|---|
| round3-A0 Android ensure + build install | pass | round3-A0/ | AVD created and booted in 17.5 s; build install 1:11 (load spike). |
| round3-A1 Android stock flows + screens | pass | round3-A1/run.txt | Flows **12/12** (90/90 steps, 6m 58s; wall 9:59); screens **5/5** (21/21, 1m 28s); exit 0. 03-edit `inputText " Renamed" (29.6s)`, 04-discard `inputText "X" (10.7s)`, 10-seed-many passed. Every step ran 3-10x slower than in round 1 at load 46 → 9. |
| round3-A1-03edit 03-edit alone x3 | pass | round3-A1-03edit/run-1..3.txt, run-<i>-client.log | 3/3 pass. inputText step **20.1 / 19.3 / 18.3 s** (round 1: 2.8 s). The key-actions request now completes: `POST /actions [15.87s / 14.91s / 15.14s] OK`, no longer cut off at 10 s. Wall 57.1 / 53.4 / 56.7 s; load 7.9-10.1 before each run. Passes, but slow on the software-rendered AVD. |
| round3-A3 Android 99-crash x3 | pass | round3-A3/crash-1..3.txt, crash-<i>-maestro-runner.log, crash-<i>-flow-000.json, device-crash-times.txt | 3/3: `launchApp` passes, then `✗ assertVisible "Landmarks"` (18.1 / 13.9 / 9.6 s) with `error.type` `app_crash`, and steps 3-4 are skipped. **No step passed against the dead app.** Crash to failure (logcat `FATAL EXCEPTION ... LANDMARKS_CRASH_ON_LAUNCH` at device 09:30:58.6 / 09:32:10.2 / 09:32:59.4; the device clock runs about 1 s behind the host; step failed at host 09:31:03.56 / 09:32:13.83 / 09:33:01.96) ≈ **4-5 s / 2.6-3.6 s / 1.6-2.6 s**. The app itself crashed 8-14 s into the step because launch is slow on this AVD. The runner log shows `crash check during a lookup in flight for <t>: crashed=false` every ~1 s while a lookup is blocked (the L-fix), then `crashed=true (took 5.3s / 3.4s / 2.2s)`, so the check itself is the bulk of the crash-to-failure time. Wall 86.6 / 64.9 / 40.6 s; load 10.8 / 16.3 / 14.0. |
| round3-A-K07 Android 10-seed-many x3 | pass | round3-A-K07/run-1..3.txt, run-<i>-cmd-005-after.png | 3/3 `✓ assertVisible "Landmark 28"` (2.4 / 1.0 / 1.1 s). The assert-step captures show Landmark 20-28 with 28 the last row visible, every run (run 1 and run 2 captures are byte-identical). Scrolls 6.4-14.6 s each. Wall 62.8 / 59.3 / 61.1 s. |
| round3-A2-K09 Android swipe reveals Remove x3 | fail | round3-A2-K09/summary.txt, run<i>-cmd-008-{before,after}.png, run1-cmd-009-before.png | The flow passes 3/3 (`✓ swipe: LEFT from text="Lake Tahoe" (1.4s)`, `✓ tapOn "Remove"`), but the swipe opened the row only in **2 of 3** runs. Run 1: cmd-008 before = after = cmd-009 before (`dab5f51f`); the row is unchanged and the tap hit the row's always-visible inline "Remove" text button. Runs 2 and 3: after ≠ before, and the red swipe "Remove" background shows. The flow cannot tell the two cases apart, because `tapOn "Remove"` matches either. |
| round3-A-keepalive Android keep-alive banner | pass | round3-A-keepalive/run.txt | `Running 1 flow(s) in one UIAutomator2 session`, `UIAutomator2 keep-alive: session=4802-...`, `Press Ctrl-C to release.`, `Releasing UIAutomator2 session...`; no GrantivaAgent. `runner stop` → "Stopped keep-alive session (pid 4767, emulator-5554)"; the run exits 130 and `/tmp/grantiva-sessions` is empty afterwards. |
| round3-I0 iOS ensure + build install | pass | round3-I0/ | `simulator ensure --name smoke3-ios --device-type "iPhone 17" --runtime "iOS 26.0"` created and booted the simulator in 24.2 s; build install 10.0 s. |
| round3-I1 iOS stock flows + screens | pass | round3-I1/run.txt | Flows 12/12 (90/90, 1m 43s; wall 2:10); screens 5/5 (21/21); cached GrantivaAgent build used in both phases. |
| round3-I4 iOS 99-crash x3 | pass | round3-I4-crash/ | 3/3 `✗ assertVisible "Landmarks"` in **144 / 132 / 143 ms** with `app_crash`; launchApp passed, steps 3-4 skipped; wall 9.8 / 8.8 / 8.8 s. |
| round3-I-reap 3x `runner start --detach --json` → `runner stop --json` | pass | round3-I-reap/cycle-1..3.txt | `reaped[]`: cycle 1 one `webDriverAgent` (xcodebuild test-without-building, pid 8773, `killed: true`); cycle 2 `[]` (the runner handled SIGINT itself: "Received interrupt, cleaning up..."); cycle 3 one `webDriverAgent` (pid 9283, killed). Processes naming the UDID at **+0 s**: launchd_sim, plus a `simctl diagnose -l -b --timeout=600 --log-option=--last --log-option=2m` (ppid 1, 3 s old) in cycles 1 and 3, and in cycles 2-3 the app under test (Landmarks pid 9090, launched in cycle 2). At **+60 s**: the diagnose is gone in every cycle; no grantiva-runner or xcodebuild is left; only launchd_sim and the app remain. `/tmp/grantiva-sessions` is empty after each cycle. |
| round3-I3 `simulator teardown --udid` without `--force` | pass | round3-teardown/ios-teardown-json.txt | `deleted: true`, `leftoverProcesses: []`, `deviceHomeFailures: []`, `deviceHomesRemoved: [.../1.1.28-grantiva.11+android-drivers-2/devices/6B18B654-...]`, `runnerSessionStopped: false`; afterwards `simctl ... grep -c smoke3` = 0 and device-home count = 0. |
| round3-teardown end state | pass | round3-teardown/android.txt, host-state.txt | `emulator teardown --serial emulator-5554` → "Killed emulator-5554 (smoke3-android)."; AVD deleted. End: no smoke simulators, `adb devices` empty, AVDs = Pixel_8_API_35, `/tmp/grantiva-sessions` empty, no lock for 6B18B654, no qemu/smoke3 process; booted: iPhone 17 Pro only (not touched). Load 3.15. |

Round 3 counts: 13 rows, 12 pass, 1 fail (round3-A2-K09).

**Round 3 interpretation.**

- **Fixed in .11:**
  - 03-edit no longer fails at 10 s: the key-actions request ran for about 15 s and completed.
  - 99-crash no longer passes a step against the dead app. A blocked lookup is now interleaved with crash checks, so the step fails 1.6-5 s after the crash.
  - 10-seed-many reaches Landmark 28 on the software-rendered AVD. That is the same AVD type on which .10 stopped at 22.
- **Remaining fail:** the K09 swipe-to-reveal is flaky on this AVD (2 of 3). The stock 02-favorite flow hides the miss, because the tap target also exists without the swipe. The round2-A2/round2b runs (.10, slower AVD) opened 3 of 3.
- **Speed (not counted as fails):** Android steps on the default software-rendered AVD at load 7-46 are 3-10x slower than in round 1; inputText alone takes 18-30 s.
