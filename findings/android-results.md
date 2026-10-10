# Android slice results: grantiva 2.1.0 regression pass

Binary `~/.grantiva-qa/bin/grantiva` 2.1.0 (grantiva-runner 1.1.28-grantiva.8), `GRANTIVA_SESSION_ID=reg-android`.
Device: AVD `qa-reg-android` (API 35 google_apis arm64), serial `emulator-5554`, created by `emulator ensure` and
torn down at the end. `emulator-5554` was NOT running before this slice started (`adb devices` empty,
`evidence/android/host-before.txt`), so the serial belonged to this slice throughout. App: scratch copy of
landmarks-demo/android, variant freeDebug. Evidence paths are relative to `findings/evidence/android/`.

## Flows (Step 2)

| ID | verdict | evidence path | note |
|---|---|---|---|
| screens (Home, Favorites, Deep Links, Lakes, Detail) | pass | run.txt, captures/ | 21/21 steps; Lakes and Detail captured correctly |
| 01-browse | pass | run.txt, run-continue-on-failure.txt | |
| 02-favorite | pass | run.txt, A02/02-favorite.txt | passes via the row's visible `Remove` button; the swipe itself reveals nothing (see A02) |
| 03-edit | regressed | run.txt, run-continue-on-failure.txt, flow03-rerun.txt, flow03-client.log, captures/failure-*.png | Expected `assertVisible "Golden Gate Bridge Renamed"` after `inputText: " Renamed"` (passed in the last round, where the runner typed with W3C key actions). Actual: fails 3 of 3 runs. The runner now sends `POST /element/<id>/value {"text":...}`, which replaces the field: the Name field holds ` Renamed` and the assert times out (17.8s). |
| 04-discard | pass | run-continue-on-failure.txt | |
| 05-category | pass | run-continue-on-failure.txt | |
| 06-visit | pass | run-continue-on-failure.txt | |
| 07-deeplink | pass | run-continue-on-failure.txt | |
| 08-caching | pass | run-continue-on-failure.txt | |
| 09-seed-empty | pass | run-continue-on-failure.txt, A01/09-seed-empty.txt | header `env:` reaches the app |
| 10-seed-many | pass | run-continue-on-failure.txt, A01/10-seed-many.txt | |
| 11-slow | pass | run-continue-on-failure.txt | |
| 12-quote-label | pass | run-continue-on-failure.txt | |
| 99-crash | pass (fails as required) | run-99.txt, captures-99/ | `✗ launchApp: 'com.kylebrowning.landmarks' crashed on launch: java.lang.RuntimeException: LANDMARKS_CRASH_ON_LAUNCH`, exit 1, later steps skipped |

Totals: flows 11/12 (03-edit regressed); screens pass. The plan's `run` is fail-fast, so run.txt stops after 03-edit
(2/12, rest SKIP); run-continue-on-failure.txt is the same run with `--continue-on-failure` (11/12).
run-attempt1-device-offline.txt: the first `run`, 30 s after boot, lost the device (`adb: device offline`) at the
first screens step; an infrastructure transient on a freshly booted AVD, not counted. run-attempt2-03edit-fail.txt
is the second attempt, with the same 03-edit failure.

## Briefs (Steps 3 and 4)

| ID | verdict | evidence path | note |
|---|---|---|---|
| A01 | pass | A01/ | `--env 'LANDMARKS_NOTE=a=b c'`: logcat `extras=[LANDMARKS_NOTE=a=b c]`, qa-note passes, note shown verbatim (A01/qa-note-cmd-003-Note.png). `--env "Q=it's"`: launches, `extras=[Q=it's]`, no shell error. 09/10 pass without `--env`; 99 fails at launchApp. docs/android.md:55 and README:177 document extras plus header `env:` delivery. |
| A02 | regressed | A02/ | Partly met: the runner looks up "Lake Tahoe" (`/element` + `/rect` in 02-favorite-client.log), and `from: "No Such Row"` fails with `Element not found for swipe: ... no such element` after 17.2s (02-nosuch.txt, exit 1). Not met: "cmd-008-after.png shows the revealed swipe action". `02-favorite-cmd-008-before.png` and `-after.png` are byte-identical (md5 dab5f51f...), and probe2 adds a settle wait and is still unchanged. The runner swipes from the element centre to 10% of the screen width: (155,500) to (108,500), 47 px. A hand `adb shell input swipe 155 500 108 500 300` does not reveal either; `155 500 0 500 300` does. The flow still passes only through the visible `Remove` button, as in the original finding. |
| A03 | pass | A03/ | `--app-file app-paid-debug.apk` with config `application_id` free: warns, installs and tests `.paid`, report `app.id` = `com.kylebrowning.landmarks.paid`. Same for `run --variant paidDebug` and `build install --variant paidDebug --json` (`applicationId` .paid). An explicit `--application-id` override warns. |
| A04 | pass | A04/hashes.txt | 10 of 10 `diff capture` runs: Deep Links hash never equals Home's. The generated flow has `waitForAnimationToEnd` after each tap. |
| A05 | pass | A05/ | Idle screen `record --duration 2 --frames-at 1000 --json`: exit 0, 001000ms.png written, `actualMilliseconds: 0` (the held frame), mp4 duration 2.000000. |
| A06 | pass | A06/ | SIGINT: exit 130, ready `status: interrupted`, flow `interrupted`. `--timeout 30`: `failed`, flow `failed` (none `running`). Passing run without `--report-dir`: no `reportDir` key. `--timeout 5 --ready-file`: exit 64 and the ready file has `failed` with `error`. |
| A07 | pass | A07/ps.txt | `adb logcat` was present during the run (no `-c`, starts with `-T`); none remains 5 s after exit 130. |
| A08 | pass | A08/ | none = default = info: I and W; debug adds D; `warning` exits 64 naming default, info, debug. docs/android.md:78-84 has the mapping table. |
| A09 | pass | A09/ | Text and `--json errors` include `Cannot locate tasks that match ':app:assembleNoSuchVariant' ...` plus a hint; `--module nosuch` likewise; no `Scheme:` line. |
| A10 | pass | A10/ | Refusal: `Emulator emulator-5554 is already owned ... grantiva emulator teardown --serial emulator-5554 --force ... grantiva emulator ensure --name <unique-name>.`, with no ` exited with code` suffix. The refused run wrote no failure screenshot (failure-shot-timeline.txt; the one PNG comes from the keep-alive run's own Ctrl-C). `build install --json` has `applicationId` and `device{name,serial}`; `Resolved: module=app variant=freeDebug device=...`; the record error has no suffix. |
| A11 | pass | A11/mcp.jsonl | Over MCP, after `grantiva_tap "Deep Links"`, `grantiva_a11y_check` reports no violations (0 `missing_label`). mcp-attempt1.jsonl: the first tap returned element-not-found while the app was on the Landmarks tab with Deep Links visible, and a retry 2 s later worked (not counted). |
| A12 | pass | A12/ | `doctor --platform android` in `<git root>/android`: `✓ Git Repository Detected`; a dir with no ancestor `.git` still warns. |
| A13 | pass | A13/ | qa-tab-landmarks: tapping "Landmarks" on Deep Links lands on the Landmarks tab (`text("Landmarks")` exact selector), not Golden Gate. Stock `diff capture` captures Lakes and Detail. The mapping form `tap: {text: "Landmarks", exact: true}` and `assert_visible: {text:..., exact: true}` works (exact-mapping.txt). |
| C02 | pass | C02/ | Android-detail path: `qa-reg-android-2` was booted by grantiva, then `adb emu kill`, then hand-started on 5556. `emulator sessions` no longer lists 5556, `teardown --serial emulator-5556` without `--force` refuses (exit 1), the hand-started emulator survives, and `emulator ensure` on it reuses it without recording it. Not run: the `adb kill-server` repro path (restarts the shared adb server and needs the user's AVD) and `teardown --all` (forbidden here). |
| D06 | pass | D06/ | docs/android-environment.md §CI says `ci run` refuses Android, points to local `diff capture/compare/approve`, and keeps the self-hosted-Mac note. `ci run --platform android` gives rc=1 with "Android baselines are local only ...". |
| D07 | pass | D07/ | docs/android.md §Devices states the order with no "Only running emulators" sentence; the EmulatorManager.swift doc comment matches. Behaviour without `emulator:`: two running gives an error listing both; one running is used (05-category passes). |

Counts: 16 briefs checked: 15 pass, 1 regressed (A02), 0 not-verifiable. Flows: 11/12 (03-edit regressed).
99-crash fails as expected.

## Other observations (not brief criteria)

- `grantiva build build` (no `--device`) boots the config's `emulator:` AVD when it is not running. During A03,
  `build build --variant paidDebug` booted the user's AVD `Pixel_8_API_35` headless as emulator-5556 (ledger
  record with `GRANTIVA_SESSION_ID=reg-android`, incident-5556/). This slice started it, so this slice tore it
  down with `emulator teardown --serial emulator-5556`. A build needs no device; booting one is surprising.
- `Resolved: ... device= ` and `Booting emulator: ` print an empty serial when no device is configured or passed
  (D07/run-no-device-*.txt).
- `diff capture` prints `Simulator: qa-reg-android (emulator-5554)`; `record --json` uses the keys `simulator`
  and `udid` on Android (A13/diff-capture.txt, A05/record.json).
- A `--timeout` kill message ends in `...shows how far it got.:` with a stray colon (A06/timeout.txt).
- `~/.grantiva/android/created-avds.json` still lists `qa-reg-android` and `qa-reg-android-2` after
  `avdmanager delete avd` (and older `qa-runner-*` and `qa-repack` names that no longer exist).
- A Ctrl-C of a `--keep-alive` run whose flow passed writes `failure-<ts>.png` (A10/failure-shot-timeline.txt).
