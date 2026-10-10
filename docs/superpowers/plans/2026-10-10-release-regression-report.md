# Release regression pass for 2.1.0: report

Date: 2026-10-10. Plan: `docs/superpowers/plans/2026-10-10-release-regression.md`. Binding requirements: the acceptance
criteria of the 2026-10-09 briefs (`plans/2026-10-09-qa-issues/`) and the landmarks-demo flow set. Last round's spec,
briefs and report are not on this branch: they live on branch `qa-campaign` (commit 8084069), with an exported copy at
`~/.grantiva-qa/briefs/docs/superpowers/`.
Slice results: `findings/cli-results.md`, `findings/ios-results.md`, `findings/android-results.md`,
`findings/task0-upgrade.md`; evidence under `findings/evidence/{cli,ios,android}/`. Regression briefs:
`docs/superpowers/plans/2026-10-10-regression-issues/`.

**Verdict: `RELEASE 2.1.0: NO-GO`**. Blocking briefs: R01, R02 (wrong-result, both Android, both in the bundled runner).

## Target and build

- Commit `a278b77` on `main` ("Drop --no-auto-accept-alerts ..."), built as `644a929`, which is the plan commit on top
  of it and adds no source changes.
- One release binary (`swift build -c release`), copied to `~/.grantiva-qa/bin/` together with its resource bundle
  `grantiva_GrantivaCore.bundle`. `grantiva --version` prints `2.1.0`.
- Bundled runner: `grantiva-runner 1.1.28-grantiva.8` (stamp `1.1.28-grantiva.8+android-drivers-2`).
- Runner home for the pass: `GRANTIVA_RUNNER_HOME=~/.grantiva-qa/runner`, an APFS clone of `~/.grantiva/runner`. The
  real home was not modified.
- Hosts: Xcode 27.0 with iOS 26.0 and 27.0 runtimes; Android emulator API 35 (google_apis arm64).

## Runner upgrade check (findings/task0-upgrade.md): PASS

- Before: `versions/1.1.18-grantiva.7+android-drivers-2` only; `cache/wda-builds/` held `sim-ios26.0-iphone`,
  `sim-ios26.0-iphone-wda16.12.8` (left over from building the embedded cache), `sim-ios26.2-iphone`,
  `sim-ios26.4-iphone`, `sim-ios27.0-iphone`; both uiautomator2 APKs present.
- After `grantiva runner install`: `versions/` holds both stamps (the new binary 37016306 bytes, Oct 10); all five old
  cache dirs survive and `sim-ios26.2-iphone-wda16.12.8`, `sim-ios26.4-iphone-wda16.12.8`,
  `sim-ios27.0-iphone-wda16.12.8` are merged in from the embedded tarball; both APKs are under the new version;
  `grantiva runner version` prints `grantiva-runner 1.1.28-grantiva.8`.
- Deviation 1 (plan text, not a regression): the plan expected the top-level `version` file to hold the new stamp.
  That file is left over from the pre-2.0 layout; the stamp now lives at `versions/<stamp>/version`, which holds
  `1.1.28-grantiva.8+android-drivers-2`.
- Deviation 2 (plan text): the first attempt installed the old runner (35 MB, Aug 29) under the new stamp with no new
  caches, because the plan's Step 1 copied only the binary and `~/.grantiva-qa/bin/` still held the 2.0.1 resource
  bundle from Oct 9. The matching bundle was copied, the clone recreated and the upgrade rerun from a clean state.
- Stale-bundle observation: `runner install` does not check that the tarball it extracts matches the stamp it writes,
  and `runner version` is a compile-time constant, so a binary upgraded without its bundle runs the old runner while
  reporting the new one. Listed under Observations.

## Review Focus

| # | Item | Verdict | Evidence |
|---|---|---|---|
| 1 | Upgrade keeps old caches, adds the `-wda16.12.8` caches, `runner version` 1.1.28-grantiva.8 | pass | findings/task0-upgrade.md |
| 2 | First iOS run on 26.0 and 27.0 uses the embedded cache, no WDA build | pass | ios/cache-grep.txt: `Using cached GrantivaAgent build (sim-ios26.0-iphone-wda16.12.8)` in run-26.0.txt and `(sim-ios27.0-iphone-wda16.12.8)` in run-27.0.txt; no `Building GrantivaAgent for the first time` |
| 3 | App alert left for the flow, system prompt still accepted, `--no-auto-accept-alerts` gone | pass | ios/I04/summary.txt (flow 04 10/10; runner log `alert "Discard Changes?..." is owned by "com.kylebrowning.Landmarks", leaving it for the flow`); ios/I04/sysalert-maps.txt (`accepted system alert "Allow “Maps” to use your location?..." (button "Allow Once")`); cli/version-surface.txt (`run --help \| grep -c auto-accept` is 0) |
| 4 | Two simulators running flows at once, own WDA session and port each | pass | ios/I01/concurrent-ios26.txt, concurrent-ios27.txt, start-times.txt: started 14:44:38 / 14:44:39, exit 0 / 0, ports 8581 / 8457, distinct WDA sessions; per-UDID homes under `versions/<stamp>/devices/<udid>/` (I01/devices-listing-per-udid.txt) |
| 5 | Webhook event names validated server-side | pass | cli/C16-unknown-event.txt (`--event not.an.event` fails with `Not authenticated. Run: grantiva auth login`, exit 1); C16-blank-event.txt and C16-http-url.txt still fail locally with exit 64; C16-events-subcommand.txt |

## Results per slice

### CLI (findings/cli-results.md)

| Briefs checked | Pass | Regressed | Not verifiable here |
|---|---|---|---|
| 35 (C01-C26, D01-D09) | 27 (5 partial: C03, C07, C13, C14, C21) | 2 (C11, C26) | 6 (C01, C02, C04, C08, C09, C10) |

- Not verifiable here, why: C01 needs a simulator lease and `runner install` lock contention on a device host; C02 needs
  emulators started and torn down by the agent (exercised in the Android slice, pass, partial); C04 needs a `screens:`
  run on a simulator; C08, C09, C10 only show in device runs (all three pass in the iOS slice). C01 and C04 were
  therefore not re-verified anywhere in this pass.
- Partial passes: C03, C07, C13, C14 and C21 pass on the criteria observable here, with a named part not exercised
  (C03 "another platform" half; on-device execution for C07; `record 2>/dev/null` for C13; a real recording for C14;
  C21's doctor remediation criterion shown only by a source grep and `strings`, not by running doctor).
- Flows: none (no device of its own). Steps 2-4 (help and version surface, webhook events, session commands on the
  borrowed qa-reg-ios-1) pass except one Step 4 row, S4-startup-window, which is regressed (R05); one observation
  remains (S4-vrt-capture-owned). Counting that row, the CLI slice has 3 regressed rows; it is a Step 4 row, not one of
  the 35 briefs, so the brief counts above (27 / 2 / 6) are unchanged.
- Cache hit: n/a. Concurrency: n/a. Step 4 ran under `GRANTIVA_SESSION_ID=reg-ios` by controller ruling, because a
  simulator leased to one session cannot be used by another (S4-lease, expected behaviour).

### iOS (findings/ios-results.md)

| Briefs checked | Pass | Regressed | Not verifiable here |
|---|---|---|---|
| 26 (I01-I19, A02, A13, C07, C08, C09, C10, C15) | 26 | 0 | 0 |

| Runtime | Flows | Screens | 99-crash | Cache hit |
|---|---|---|---|---|
| iOS 26.0 (qa-reg-ios-1, iPhone 17) | 12/12, exit 0 | 19/19 (5 config + 14 flow screenshots) | fails as required: exit 1, `... is not running, possibly crashed` | yes |
| iOS 27.0 (qa-reg-ios-2, iPhone 17) | 12/12, exit 0 | 19/19 | not run (n/a) | yes |

Concurrency: pass (Review Focus 4). Unit-test and CHANGELOG criteria were not run (no `swift build` in this pass);
test presence was spot-checked by grep, and CHANGELOG.md was removed in #179 in favour of generated release notes.

### Android (findings/android-results.md)

| Briefs checked | Pass | Regressed | Not verifiable here |
|---|---|---|---|
| 16 (A01-A13, C02, D06, D07) | 15 (C02 partial) | 1 (A02) | C02's primary-repro sub-criterion only |

| Runtime | Flows | Screens | 99-crash |
|---|---|---|---|
| API 35 (qa-reg-android, emulator-5554) | 11/12 (03-edit regressed, 4 of 4 runs) | pass, 21/21 steps; Lakes and Detail correct | fails as required: `✗ launchApp: 'com.kylebrowning.landmarks' crashed on launch: java.lang.RuntimeException: LANDMARKS_CRASH_ON_LAUNCH`, exit 1 |

- The plan's `run` is fail-fast, so run.txt stops after 03-edit (2/12); run-continue-on-failure.txt is the full set
  (11/12). Flow 02 passes only through the row's visible `Remove` button (R02).
- C02 sub-criterion not verified: the primary repro needs `adb kill-server` on the shared adb server, booting the
  user's `Pixel_8_API_35`, and `emulator teardown --all`, all forbidden in this pass.
- One infrastructure transient not counted: the first `run`, 30 s after boot, lost the device (`adb: device offline`)
  (run-attempt1-device-offline.txt).
- Cache hit: n/a (no WDA). Concurrency: n/a.

## Regression briefs

| ID | Title | Severity | Blocking | Original brief |
|---|---|---|---|---|
| R01 | Android `inputText` replaces the focused field's text instead of appending (flow 03-edit); `tapOn "Done"` hits the keyboard key | wrong-result | yes | none (stock flow; QA spec §Gate) |
| R02 | Android `swipe: {direction: LEFT, from: <element>}` too short to open the row; absolute-pixel coordinates read as percentages (hypothesis) | wrong-result | yes | A02 (partially fixed) |
| R03 | README:99 contradicts README:101 on `--timeout` / `--continue-on-failure` for `screens:` | docs | no | C26 |
| R04 | MCP config-dependent tools do not say the config file is missing | contract | no | C11 (criterion 3) |
| R05 | MCP session tools answer with a JSON-RPC error, not an isError result, while WDA starts after `runner start --detach` | contract | no | C21 (rpc-error vs isError), C11 (lazy attach) |

Regressed rows whose original acceptance criteria were wrong: none.

## Observations for triage

Not regressions against any brief; candidates for later briefs.

- `runner install` with a stale resource bundle beside the binary extracts the old runner under the new stamp, and
  `runner version` still reports the new version (findings/task0-upgrade.md).
- `grantiva_vrt_capture` refuses while a runner session owns the simulator ("already owned by another Grantiva run"),
  though docs/mcp.md marks it Session "no" (cli S4-vrt-capture-owned; cli/C05.txt).
- README:92 gives the per-simulator runner home as `~/.grantiva/runner/devices/<udid>`; on disk it is
  `<runner home>/versions/<runner version>/devices/<udid>`. A plain `simulator teardown --udid` left both device homes in
  place, and after `--force` reclaim the reclaimed device's home stayed until the next run, although README:92 says
  teardown removes it (ios Observations; ios/teardown/teardown.txt, I09/device-homes-after-next-run.txt).
- `grantiva build build` without `--device` boots the config's `emulator:` AVD. During A03 the Android agent's
  `build build --variant paidDebug` booted the user's AVD `Pixel_8_API_35` headless as emulator-5556 at 14:39:10 under
  session reg-android; the agent tore that emulator process down at 14:47:26 with `emulator teardown --serial
  emulator-5556`. The AVD itself was not deleted (android/incident-5556/).
- `Resolved: ... device= ` and `Booting emulator: ` print an empty serial when no device is configured or passed
  (android/D07/run-no-device-*.txt).
- On Android, `diff capture` prints `Simulator: qa-reg-android (emulator-5554)` and `record --json` uses the keys
  `simulator` and `udid` (android/A13/diff-capture.txt, A05/record.json).
- The `--timeout` kill message ends with a stray colon: `...The runner's last output above shows how far it got.:`
  (android/A06/timeout.txt).
- `~/.grantiva/android/created-avds.json` keeps AVD names after `avdmanager delete avd` (android/created-avds-after.json).
- Ctrl-C of a `--keep-alive` run whose flow passed writes `failure-<ts>.png` (android/A10/failure-shot-timeline.txt).
- README:147 documents `{text: ..., exact: true}` for screens, but grantiva-runner ignores it on Android with
  `⚠ "exact" is not supported on android — will be ignored` (android/A13/exact-mapping.txt:55). A13 still passes through
  the runner's exact-text preference.
- README-vs-help wording differences at README:311 (`hierarchy`), 312 (`build`), 314 (`ci run`), 338 (`init` omits
  Android) (cli Step 2; cli/D02-examples.txt, D02-table.txt).
- `grantiva_vrt_capture` says "No screens configured in grantiva.yml" when no config file exists (folded into R04).

## Plan-text errors found during the pass

So the next plan gets these right:

- The top-level `<runner home>/version` file is a leftover from the old layout; the stamp is per install, at
  `versions/<stamp>/version`.
- Task 0 Step 1 must copy `grantiva_GrantivaCore.bundle` together with the binary.
- `sessions` and `update` are not top-level commands; the listings are `simulator sessions` and `emulator sessions`.
- `--event` belongs to `console webhooks create|update`.
- `runner stop --udid` does not exist (`runner stop` is project-scoped), and neither does a `grantiva context` command
  (`context` is the MCP tool `grantiva_context`).
- Per-UDID device dirs are under `<runner home>/versions/<stamp>/devices/<udid>/`, not `cache/wda-builds/*/devices/`.
- A simulator leased to one session cannot be borrowed under another session ID; the CLI slice's Step 4 ran as
  `reg-ios` by controller ruling.

## Host state after cleanup

- `xcrun simctl list devices | grep -c qa-reg-` → 0; `simulator sessions --json` → `[]` (ios/teardown/teardown.txt).
- No `qa-reg` AVDs; `adb devices` empty; `~/.grantiva/android/started.json` `[]` (android/fix-round-teardown.txt, 15:00:28).
- iPhone 17 Pro (`B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C`) still booted. It was listed by simctl and enumerated as a
  booted candidate by `grantiva_context` and `diff capture` (findings/cli-results.md:22, C06 row;
  findings/ios-results.md:63, I02 row), but no agent ever commanded it (ios/teardown/teardown.txt).
- `Pixel_8_API_35` AVD still present (see the `build build` observation for the 14:39-14:47 incident).
- The user's real runner home `~/.grantiva/runner` was not modified.

## Verdict

**`RELEASE 2.1.0: NO-GO`**: blocking briefs **R01** and **R02** (wrong-result). R03, R04 and R05 do not block.

For GO: fix R01 and R02 in grantiva-runner and bundle the fixed runner in this repo; then re-run Task 0's upgrade check
for the new runner, the full Android flow set (12/12 with 03-edit passing, 99-crash failing as required) and the A02
repro including flow 02's swipe revealing the row action, and the full iOS flow set on 26.0 and 27.0, since the runner
changes.
