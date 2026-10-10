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
| 03-edit | regressed | run.txt, run-attempt2-03edit-fail.txt, run-continue-on-failure.txt, flow03-rerun.txt, flow03-client.log, flow03-prior-round-comparison.txt, captures/failure-*.png | Expected `assertVisible "Golden Gate Bridge Renamed"` after `inputText: " Renamed"`. The previous round passed: its client.log line 23 typed with `POST /actions` keyDown/keyUp, and report.json says `passed` (flow03-prior-round-comparison.txt). Actual: fails 4 of 4 runs (run-attempt2, run.txt, continue-on-failure, rerun). grantiva-runner now sends `POST /element/<id>/value {"text":...}` (flow03-client.log:31), and the Name field ends up holding ` Renamed` (failure PNG). Then `tapOn "Done"` clicks (994,2196), the keyboard's Done key (flow03-client.log:42), not the toolbar button, so the sheet stays open and the assert times out (17.8s). |
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
run-attempt1-device-offline.txt (runner log: run-attempt1-runner.log): the first `run`, 30 s after boot, lost the device (`adb: device offline`) at the
first screens step; an infrastructure transient on a freshly booted AVD, not counted. run-attempt2-03edit-fail.txt
is the second attempt, with the same 03-edit failure.

## Briefs (Steps 3 and 4)

| ID | verdict | evidence path | note |
|---|---|---|---|
| A01 | pass | A01/ | `--env 'LANDMARKS_NOTE=a=b c'`: logcat `extras=[LANDMARKS_NOTE=a=b c]`, qa-note passes, note shown verbatim (A01/qa-note-cmd-003-Note.png). `--env "Q=it's"`: launches, `extras=[Q=it's]`, no shell error. 09/10 pass without `--env`; 99 fails at launchApp. docs/android.md:55 and README:177 document extras plus header `env:` delivery. |
| A02 | regressed | A02/, A02/probes/ (summary.txt, commands.txt, hashes.txt, png/) | Met: the runner looks up "Lake Tahoe" (`/element` + `/rect`, A02/02-favorite-client.log), and `from: "No Such Row"` fails with `Element not found for swipe` after 17.2s (A02/02-nosuch.txt, exit 1). Not met: "cmd-008-after.png shows the revealed swipe action". In the fix-round device re-check with touch traces on, the `direction: LEFT, from: "Lake Tahoe"` swipe draws only a short trace inside the text element and the row stays closed, both in flow 02 (a) and in a one-step probe (c). A full-length runner coordinate swipe across the row, `60%,22%` to `5%,22%` (b2), does open it, as does the hand `adb shell input swipe 648 528 54 528 300` control (d). So runner swipes work in general; the from-element swipe is too short. The first-session probe `60%,17%` (b) missed because y=408 lies above this row (row [0,432][1080,621]). Hypothesis, from the grantiva-runner source rather than shown on device: the from-swipe runs from the element centre to 10% of the screen width, (155,500) to (108,500) = 47 px. A hand swipe over exactly those coordinates leaves the row closed, while 155 to 0 opens it (probes/e-manual-short-swipes.txt). Flow 02 still passes only through the visible `Remove` button. Separate: an absolute-pixel `start: 900, 520 / end: 100, 520` swipe (c2) never touches the row; the overlay reads dX -8640, which suggests the numbers are taken as percentages (hypothesis). |
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
| A13 | pass | A13/ | Criteria: (1) "`tap:` ... accept a mapping form `{text: \"Landmarks\", exact: true}` that FlowGenerator emits as `tapOn: {text: ..., exact: true}`; and/or the runner prefers a node whose full text equals the query before falling back to substring matches"; (2) "With either change, the stock landmarks `screens:` config captures Lakes and Detail on Android." (2) holds: stock `run` and `diff capture` capture Lakes and Detail (run.txt, diff-capture.txt, captures/). (1) holds through the runner's preference, not the mapping form. In qa-tab-landmarks, tapping "Landmarks" on Deep Links resolves `new UiSelector().text("Landmarks")` and lands on the Landmarks tab, not the Golden Gate link. grantiva accepts the mapping form and emits `exact=true` (exact-mapping.txt:74), but grantiva-runner prints `⚠ "exact" is not supported on android — will be ignored` (exact-mapping.txt:55), so `exact:` has no effect on Android. |
| C02 | pass (partial) | C02/ | Exercised (Android-detail path): grantiva booted `qa-reg-android-2`, then `adb emu kill`, then it was hand-started on 5556. `emulator sessions` no longer lists 5556; `teardown --serial emulator-5556` without `--force` refuses (exit 1) and the hand-started emulator survives; `emulator ensure` on it reuses it without writing a record. |
| C02 (not exercised) | not-verifiable-here | — | Criterion 1 via the brief's primary repro ("Re-running the repro leaves no record for emulator-5554, and `emulator teardown --all` does not kill it") was not run: it needs `adb kill-server` on the shared adb server and booting the user's `Pixel_8_API_35`, and `teardown --all` is forbidden in this pass. The `choosePort` console-port criterion was not exercised directly either. |
| D06 | pass | D06/ | docs/android-environment.md §CI says `ci run` refuses Android, points to local `diff capture/compare/approve`, and keeps the self-hosted-Mac note. `ci run --platform android` gives rc=1 with "Android baselines are local only ...". |
| D07 | pass | D07/ | docs/android.md §Devices states the order with no "Only running emulators" sentence; the EmulatorManager.swift doc comment matches. Behaviour without `emulator:`: two running gives an error listing both; one running is used (05-category passes). |

Counts: 16 briefs checked: 15 pass (C02 partial; one C02 sub-criterion not-verifiable-here), 1 regressed (A02). Flows: 11/12 (03-edit regressed, 4/4 runs).
99-crash fails as expected.

## Other observations (not brief criteria)

- `grantiva build build` (no `--device`) boots the config's `emulator:` AVD when it is not running. During A03,
  `$GRANTIVA build build --variant paidDebug` (cwd scratch app, no `--device`) booted the user's AVD `Pixel_8_API_35` headless as emulator-5556 (ledger
  record with `GRANTIVA_SESSION_ID=reg-android`, qemu started 14:39:10, incident-5556/). This slice started it, so
  this slice tore it down at 14:47:26 with `$GRANTIVA emulator teardown --serial emulator-5556`. A build needs no device; booting one is surprising.
- `Resolved: ... device= ` and `Booting emulator: ` print an empty serial when no device is configured or passed
  (D07/run-no-device-*.txt).
- `diff capture` prints `Simulator: qa-reg-android (emulator-5554)`; `record --json` uses the keys `simulator`
  and `udid` on Android (A13/diff-capture.txt, A05/record.json).
- A `--timeout` kill message ends in `...shows how far it got.:` with a stray colon (A06/timeout.txt).
- `~/.grantiva/android/created-avds.json` still lists `qa-reg-android` and `qa-reg-android-2` after
  `avdmanager delete avd` (and older `qa-runner-*` and `qa-repack` names that no longer exist).
- A Ctrl-C of a `--keep-alive` run whose flow passed writes `failure-<ts>.png` (A10/failure-shot-timeline.txt).
- Absolute-pixel swipe coordinates (`start: 900, 520`) never reach the screen point; the overlay suggests they are
  scaled as percentages (A02/probes, c2; hypothesis).
- README documents the `{text: ..., exact: true}` screens form, but grantiva-runner ignores `exact` on Android with
  a warning (A13/exact-mapping.txt:55).

Each evidence directory has a `commands.txt` with the exact commands; the top-level list is `commands.txt`, and the
fix round is `fix-round-commands.txt`.
