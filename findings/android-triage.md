# Android slice triage (independent confirmation)

Binary `~/.grantiva-qa/bin/grantiva` 2.0.1, `GRANTIVA_SESSION_ID=qa-android`, no API key, emulator-5554 (Pixel_8_API_35)
only. Each repro was re-run once (F15 three times, as it is intermittent) from `landmarks-demo/android` or a scratch
project. Not re-run, by rule: AND-F03 (would need `emulator teardown`, judged from the live ledger and
EmulatorManager.swift), AND-F17 (needs a second emulator, judged from source), AND-F20 (needs a new emulator boot,
judged from source and CHANGELOG), AND-F23 (one-off flake, judged from evidence). Device animation scales read 0/0/0
before and after this pass; the `.paid` package the F05 repro installs was uninstalled again.

Format: `ID | verdict | severity | title | duplicate-of | evidence from this re-run`

AND-F01 | CONFIRMED | wrong-result | Launch environment (`--env`, flow `env:`, `launchApp.environment`) never reaches the Android app | - | `run --flow qa-note.yaml --env 'LANDMARKS_NOTE=a=b c'` failed at `assertVisible "a=b c"` (exit 1) and logcat showed `Landmarks: launch ... extras=[none] env=[... LANDMARKS_NOTE=null]`.
AND-F02 | CONFIRMED | wrong-result | `swipe: {direction: LEFT, from: "<text>"}` ignores `from` and reports success | - | 02-favorite with `--snapshot full` printed `[swipe] Using screen coords: (972,1200) -> (108,1200)` and `✓ swipe: LEFT`; cmd-008 before/after PNGs are identical with no swipe action revealed on the Lake Tahoe row (y≈400); the flow passed via the visible Remove button.
AND-F03 | CONFIRMED | wrong-result | Stale emulator ledger record lets `emulator teardown` kill a user-started emulator | CLI-F04 | Not re-run (rule): started.json still holds emulator-5554/Pixel_8_API_35/pid 19482, which is dead; the live emulator-5554 is qemu pid 49817 (started Oct 7, no `-port`); EmulatorManager.teardown (:347-352) drops a dead-pid record only when the AVD name differs, so this record survives and teardown would kill it.
AND-F04 | CONFIRMED | ux | Gradle failures are reported as bare "FAILURE: Build failed with an exception." | - | `build build --variant noSuchVariant`: exit 1, output `✗ Build failed / Scheme: (none) / ✗ FAILURE: Build failed with an exception.`; `--json` errors array holds only that line, with no task-not-found reason.
AND-F05 | CONFIRMED | wrong-result | Config `application_id` overrides the APK's ID, so the installed variant is not the one tested | - | `run --app-file app-paid-debug.apk --flow 01-browse.yaml` printed `Installing com.kylebrowning.landmarks...`, passed, report.json `app.id` = `com.kylebrowning.landmarks`, and `pm list packages` then showed both the free and `.paid` packages.
AND-F06 | CONFIRMED | contract | A failing `screens:` path aborts the suite despite `--continue-on-failure`; configured flows never run | CLI-F08 | Stock config + `--continue-on-failure --report-dir`: `Running 13 flow(s)...`, screens failed at `tapOn "Lakes"`, `Error: Runner failed (exit 1)`, none of the 12 flows ran, and the report dir got only `captures/`; RunCommand.runSuite (:404-410) throws after any failed screen when flows exist.
AND-F07 | NOT A BUG | wrong-result | `tapOn: "Landmarks"` on Deep Links taps the `landmarks://...` button rather than the exact-text tab | - | Reproduced (client.log `textContains("Landmarks")` clicked (540,779); capture shows Golden Gate Bridge detail), but CHANGELOG.md:128 documents default `text:` matching as case-insensitive and unanchored with `exact: true` as the opt-in; `screens:` `tap:` has no way to request exact (see enhancement below).
AND-F08 | CONFIRMED | contract | `hierarchy --json` prints XML | CLI-DOCS-F12 | During a keep-alive run, `hierarchy --json` exit 0, first line `<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>`.
AND-F09 | CONFIRMED | ux | "Already owned" refusal on Android suggests iOS `simulator` commands | AND-F21 | Second run on emulator-5554 during keep-alive: `Error: Simulator emulator-5554 is already owned ... Release it with \`grantiva simulator teardown --udid emulator-5554 --force\` ...` (also printed `Booting emulator: emulator-5554` first).
AND-F10 | CONFIRMED | contract | Ctrl-C mid-flow writes ready status `failed` and leaves the flow `running` | - | `kill -INT` ~8 s into qa-longwait (keep-alive, --logs): exit 130, ready file `"status": "failed"`, flows `[{"name": "qa-longwait", "status": "running"}]`.
AND-F11 | CONFIRMED | contract | Ready file `reportDir` points at an already-deleted temp directory when no `--report-dir` is given | AND-F10 | 05-category with `--ready-file x.ready`: exit 0, `ls "$(jq -r .reportDir x.ready)"` -> `No such file or directory`.
AND-F12 | CONFIRMED | contract | `--logs-level default` maps to logcat D, unknown levels are accepted | - | `--logs-level default` gave priorities D 6 / I 7 / W 14 (debug included); `--logs-level warning` was accepted (exit 0) and gave W only; AndroidPlatform.logStream uses `level.first` as the priority letter.
AND-F13 | CONFIRMED | contract | Ctrl-C mid-flow with `--logs` leaves an orphan `adb logcat` | - | Same SIGINT run as F10: `adb -s emulator-5554 logcat --uid=10210 -v time` (pid 90396) still alive with PPID 1 five seconds after exit 130; killed by hand.
AND-F14 | CONFIRMED | wrong-result | `record` on a static screen fails because the video ends at 0 ms | - | `record --duration 2 --frames-at 1000 --output static.mp4 --json` on an idle screen: exit 1, `Grantiva recording ended at 0ms before requested frame 1000ms exited with code 1`; ffprobe shows a single packet at 0.000000.
AND-F15 | CONFIRMED | wrong-result | `diff capture` can screenshot before a tap's navigation renders | - | Three `diff capture --no-build` runs (Home, Deep Links, Favorites): in tries 1 and 3 `Deep%20Links.png` had the same md5 as `Home.png` (51b8e928...), only try 2 differed; all exited 0.
AND-F16 | CONFIRMED | wrong-result | MCP VRT tools run whatever `grantiva` is first on PATH | CLI-F19 | `which -a grantiva` -> /opt/homebrew/bin/grantiva (2.0.0); VRTTools.swift:56 builds the literal `grantiva diff capture --no-build --json --platform android`; the live tool call could not be repeated because `grantiva mcp` produced no output without a live session (CLI-F18).
AND-F17 | CONFIRMED | wrong-result | MCP `grantiva_context` says "No emulator running" when several emulators run | CLI-F20 | Not re-run with two emulators (rule); with one emulator the section was right, but ContextTool.swift:69 calls `defaultDevice()` = `selectDevice(configured: nil)`, which throws "Several emulators are running" for >1 and `try?` turns it into "No emulator running", ignoring the config's `emulator:` and the session's serial.
AND-F18 | CONFIRMED | ux | `grantiva_a11y_check` flags every Compose button as `missing_label` | - | On Deep Links: 12 violations, every `android.widget.Button` reported `missing_label`; the hierarchy shows each Button is a non-clickable empty node beside a `TextView` (e.g. "Caching Demo") inside a clickable parent View, which TalkBack reads as the label.
AND-F19 | CONFIRMED | docs | `run --timeout` has an undocumented 30 s minimum | CLI-F01 | `--timeout 5` -> exit 64 with the minimum error; help/run.txt:68 states no minimum.
AND-F20 | NOT A BUG | docs | Emulators boot headless whenever stdout is not a TTY | - | Not re-run (needs a new boot); EmulatorManager.swift:216 (`headless || isatty(STDOUT_FILENO) == 0`) matches CHANGELOG.md:8 ("`-no-window` under `--headless` or without a terminal"), so the finding's "not mentioned in any doc" is wrong; help and docs/android.md could repeat it.
AND-F21 | CONFIRMED | ux | iOS wording and stray suffixes in Android output | CLI-F05, CLI-DOCS-F11 (partly) | `build install --no-launch --json` returned `bundleId` and `simulator: {name, udid}`; `run` printed `Resolved: scheme=(none) simulator=emulator-5554`; build failure printed `Scheme: (none)`; runner and record errors ended with ` exited with code 1`.
AND-F22 | CONFIRMED | ux | `doctor` reports "Not a git repository" inside a subdirectory of a work tree | - | `doctor --platform android` in landmarks-demo/android printed `Git Repository  Not a git repository / Run: git init`, while `git rev-parse --show-toplevel` = /Users/kyle/Developer/landmarks-demo.
AND-F23 | NOT REPRODUCED | ux | UIAutomator2 socket refused mid-flow (flake) | - | About 15 Android runs in this pass, none hit `dial unix /tmp/uia2-emulator-5554.sock: connect: connection refused`; evidence (AND-026/report-try1-flake) shows one occurrence, cause unknown.

## Counts

Confirmed 20, not reproduced 1 (F23), not a bug 2 (F07, F20). Merged into another Android finding: 2 (F09 -> F21,
F11 -> F10). Folded into CLI briefs: 6 (F03, F06, F08, F16, F17, F19).

## Proposed issues (Android), by severity

1. [wrong-result] Deliver `--env`, flow `env:` and `launchApp.environment` to Android apps as intent extras (AND-F01)
2. [wrong-result] Start Android swipes on the `from:` element, and fail when it cannot be found (AND-F02)
3. [wrong-result] Test the app that was installed: take the application ID from the APK/build output, or fail when `application_id` disagrees (AND-F05)
4. [wrong-result] Wait for the screen to settle after each path tap before `diff capture` screenshots (AND-F15)
5. [wrong-result] Hold the last frame to the requested duration in Android recordings so `--frames-at` works on static screens (AND-F14)
6. [contract] Write an accurate ready file: `interrupted` with final flow statuses on Ctrl-C/timeout, and no `reportDir` when the directory is deleted (AND-F10, AND-F11)
7. [contract] Stop the `adb logcat` stream when a run is interrupted mid-flow (AND-F13)
8. [contract] Map `--logs-level` values to the documented logcat priorities and reject unknown levels (AND-F12)
9. [ux] Show Gradle's "What went wrong" reason when an Android build fails (AND-F04)
10. [ux] Use Android terminology in Android output, JSON keys and ownership remediation (`grantiva emulator ...`, `applicationId`, `device`/`serial`, no `Scheme:`), and drop the stray " exited with code 1" suffix (AND-F21, AND-F09)
11. [ux] Treat Compose buttons labelled by merged descendant text as labelled in `grantiva_a11y_check` (AND-F18)
12. [ux] Detect a git work tree from a subdirectory in `doctor` (AND-F22)

Enhancement (from a NOT A BUG): let `screens:` `tap:` steps request an exact match, or prefer an exact full-text hit
over a substring hit, so the stock label-contract path (`tap: "Landmarks"` then `tap: "Lakes"`) works on Android (AND-F07).

## Fold into CLI briefs

- Fold into CLI brief CLI-F04 (AND-F03): live on this host now: started.json lists emulator-5554/Pixel_8_API_35/pid 19482 (dead) while the real emulator-5554 is a hand-started qemu (pid 49817, no `-port`); `emulator sessions` reports it as Grantiva-started. The original repro on emulator-5556 (Grantiva-booted AVD killed outside Grantiva, rebooted by hand on the same port) had `teardown --serial emulator-5556` without `--force` kill the hand-started emulator, exit 0.
- Fold into CLI brief CLI-F08 (AND-F06): with both `screens:` and `flows:`, any failed screen makes runSuite (RunCommand.swift:404-410) throw before flows run, regardless of `--continue-on-failure`; on Android the stock landmarks config therefore never runs its 12 flows (screens fail at `tap: "Lakes"`, see AND-F07).
- Fold into CLI brief CLI-DOCS-F12 (AND-F08): same on Android; `--json` returns UIAutomator2 XML.
- Fold into CLI brief CLI-F19 (AND-F16): Android adds `--platform android`, which the PATH 2.0.0 binary rejects ("Unknown option '--platform'") for capture, compare and approve.
- Fold into CLI brief CLI-F20 (AND-F17): the Android branch calls `defaultDevice()` with no configured AVD or session serial; with two emulators the "Several emulators are running" error is swallowed and the tool reports "No emulator running" while the session block lists emulator-5554.
- Fold into CLI brief CLI-F01 (AND-F19): same 30 s minimum on Android (`--timeout 5` -> exit 64).
