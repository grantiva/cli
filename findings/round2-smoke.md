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

Counts: 26 rows, 20 pass, 6 fail (round2-A1, round2-A1-03edit, round2-A3, round2-A-K07, round2-X-d2, round2-HELP-K61).

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
