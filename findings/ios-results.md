# iOS slice results: grantiva 2.1.0 regression pass

Binary `~/.grantiva-qa/bin/grantiva` 2.1.0 (grantiva-runner 1.1.28-grantiva.8), `GRANTIVA_RUNNER_HOME=~/.grantiva-qa/runner`,
`GRANTIVA_SESSION_ID=reg-ios`, Xcode 27.0. App: scratch copy of landmarks-demo/ios.

- qa-reg-ios-1: iPhone 17, iOS 26.0, `4278E141-1297-46F9-989F-FB9995D123F9`
- qa-reg-ios-2: iPhone 17, iOS 27.0, `D65CAFEF-BB8A-4835-897F-C63578A905ED`

Evidence paths are relative to `findings/evidence/ios/`. Each evidence directory has a `commands.txt` with the exact commands that produced its files. Every hand-made input (flows, configs, MCP request files, env.sh) is under `inputs/`.

## Step 2: configured flows and screens

| Flow / check | iOS 26.0 | iOS 27.0 | evidence | note |
|---|---|---|---|---|
| 01-browse | pass | pass | run-26.0.txt, run-27.0.txt | |
| 02-favorite | pass | pass | run-26.0.txt, run-27.0.txt | |
| 03-edit | pass | pass | run-26.0.txt, run-27.0.txt | |
| 04-discard | pass | pass | run-26.0.txt, run-27.0.txt | |
| 05-category | pass | pass | run-26.0.txt, run-27.0.txt | |
| 06-visit | pass | pass | run-26.0.txt, run-27.0.txt | |
| 07-deeplink | pass | pass | run-26.0.txt, run-27.0.txt | |
| 08-caching | pass | pass | run-26.0.txt, run-27.0.txt | |
| 09-seed-empty | pass | pass | run-26.0.txt, run-27.0.txt | |
| 10-seed-many | pass | pass | run-26.0.txt, run-27.0.txt | |
| 11-slow | pass | pass | run-26.0.txt, run-27.0.txt | |
| 12-quote-label | pass | pass | run-26.0.txt, run-27.0.txt | |
| screens (Home, Favorites, Deep Links, Lakes, Detail) | pass | pass | captures-26.0/, captures-27.0/ | 19/19 screens on both (5 config screens + 14 flow screenshots); Lakes and Detail captures show the right screens |
| TOTAL | 12/12, exit 0 | 12/12, exit 0 | | |
| WDA cache hit | pass | pass | cache-grep.txt | `Using cached GrantivaAgent build (sim-ios26.0-iphone-wda16.12.8)` / `(sim-ios27.0-iphone-wda16.12.8)`; no `Building GrantivaAgent for the first time` |
| 99-crash must fail | pass (fails) | n/a | 99-crash.txt | exit 1; `launchApp` ✓ then `assertVisible "Landmarks"` ✗ `WDA error: The application under test with bundle id 'com.kylebrowning.Landmarks' is not running, possibly crashed` |

## Step 3: alerts and follow-up repros

| ID | verdict | evidence | note |
|---|---|---|---|
| I04 (flow 04 x10) | pass | I04/summary.txt, I04/run1-report/maestro-runner.log | 10/10 exit 0 (5 for Step 3 + 5 more for the brief's 10-run criterion). Runner log: `alert "Discard Changes?..." is owned by "com.kylebrowning.Landmarks", leaving it for the flow`; session `defaultAlertAction:""` |
| I04 system prompt still auto-accepted | pass | I04/sysalert-maps.txt, I04/sysalert-report/maestro-runner.log | Maps after `simctl privacy reset location`: `[wda] accepted system alert "Allow “Maps” to use your location?..." (button "Allow Once")`, flow passes |
| A02 (iOS half) | pass | A02/02-favorite.txt, A02/pass-report/maestro-runner.log, A02/02-favorite-nosuchrow.txt | flow 02 passes; step 8 looks up `Lake Tahoe` (`POST /element` predicate + `/rect`) before the swipe. `from: "No Such Row"` fails at the swipe: `Element not found: text='No Such Row'`, exit 1 |
| I-selectors: flow 10 with `--env LANDMARKS_SEED=many` | pass | I-selectors/10-seed-many-env.txt | bare `scroll` runs as `scroll: DOWN`, `Landmark 30` visible |
| I-selectors: flow 12 | pass | I-selectors/12-quote-label.txt | `tapOn: text="Mount "Denali""` passes |
| I-selectors: Settings `tapOn: {id: General}` | pass | I-selectors/settings-general-id-noconf.txt | passes from a dir with no grantiva.yml (`tapOn: id="General"`). Run from the app dir it launched Landmarks instead (settings-general-id.txt) because config `bundle_id` outranks the flow `appId:`, which README:175 documents, so not a defect |
| I-selectors: `assertVisible: {id: clock}` on caching screen | pass | I-selectors/caching-clock-id.txt | `assertVisible: id="clock"` passes |
| C08 | pass | C08/parsed-mode.txt, C08/flow-mode.txt, C08/parsed-assertVisible-id-clock.txt | parsed mode now `tapOn: id="General"` / summary `Tap on id "General"`; parsed `assertVisible: {id: clock}` → `assertVisible: id="clock"` |
| C09 | pass | C09/run.txt | `wait: 3` → `evalScript (3.0s)` / `Wait 3s (3.0s)` |
| C10 | pass | C10/scroll.txt, C10/setPermissions.txt, C10/setPermissions-report/ | no config, no `--bundle-id`: bare `scroll` → `scroll: DOWN` passes; `setPermissions` passes using the header appId. Flow 10 extra criterion: see I-selectors row |
| C07 | pass | C07/{swipe,extendedWaitUntil,waitForAnimationToEnd,back}.txt | the three standard forms parse and run (exit 0); `back` is rejected: `grantiva.yml:5: unsupported Maestro command 'back'`, matching README:173 |
| C07 (iOS detail) | pass | C07/ios-detail-noconf-run.txt | no-config dir with stock `.maestro/`, `run --app-file … --flow .maestro/01-browse.yaml` passes (no parse of 02's swipe) |
| C15 | pass | C15/diagonal.txt, C15/up-mixedcase.txt | `grantiva.yml: screen "Diag": swipe direction "diagonal" is not one of up, down, left, right`, before any runner start; `swipe: Up` works |
| A13 (iOS half) | pass | A13/exact-ios.txt, captures-26.0/Lakes.png, captures-26.0/Detail.png | `{text: "Landmarks", exact: true}` emitted as `tapOn: text="Landmarks", exact=true` and passes; stock screens capture Lakes and Detail |

## Step 4: two simulators at once

| ID | verdict | evidence | note |
|---|---|---|---|
| Concurrency (flow 01 on both, started 1 s apart) | pass | I01/concurrent-ios26.txt, I01/concurrent-ios27.txt, I01/start-times.txt | a=0 b=0; ports 8581 / 8457; WDA sessions F868D37E… / FCF6E7DD… |
| devices/ listing | see note | I01/devices-listing.txt, I01/devices-listing-per-udid.txt | `ls $GRANTIVA_RUNNER_HOME/cache/wda-builds/*/devices/` shows only stale dirs copied with the cloned home, none for our UDIDs. The per-UDID homes are at `$GRANTIVA_RUNNER_HOME/versions/1.1.28-grantiva.8+android-drivers-2/devices/<udid>/cache/wda-builds/…`, one per UDID (devices-listing-per-udid.txt). The I09 teardown JSON shows WDA running with `-derivedDataPath …/devices/<udid>/cache/wda-builds/sim-ios26.0-iphone-wda16.12.8/devices/<udid>/run-<pid>-<ts>/DerivedData` |

## Step 5: I briefs

| ID | verdict | evidence | note |
|---|---|---|---|
| I01 | pass | I01/pairs-summary.txt, I01/pair*-{a,b}.txt | 5/5 pairs (06 on ios-1, 07 on ios-2) exit 0/0; per-UDID WDA DerivedData (see Step 4). Doc nit: README:92 gives the home as `~/.grantiva/runner/devices/<udid>`, but on disk it is `<runner home>/versions/<runner version>/devices/<udid>` |
| I02 | pass | I02/capture.err, I02/capture.json, I02/capture-noconf.err, I02/mcp/transcript.txt | config `simulator: qa-reg-ios-1` and no flag: `Device: qa-reg-ios-1`, exit 0. With nothing configured and 3 booted: `3 simulators are booted: … Pass --simulator <name|UDID> or set simulator: in grantiva.yml.` (no device driven). MCP `grantiva_vrt_capture` captured on qa-reg-ios-1 (udid 4278E141…). The user's iPhone 17 Pro was never driven (before testing, the binary was checked to contain the several-booted guard) |
| I03 | pass | I03/repro.txt | after the failed capture (exit 1), `diff compare` exit 1: `No captures found in .grantiva/captures. Run: grantiva diff capture` |
| I04 | pass | see Step 3 | 10/10 |
| I05 | pass | I05/run2/mcp/transcript.txt, I05/run2/mcp/stdout.raw | from Home: `grantiva_tap {"label":"Favorites"}` → `Tapped on "Favorites"` and the tree shows `No Favorites`; `grantiva_script` taps `Deep Links`, `Edit Landmark`. `{"label":"heart"}` still taps (allowed as a fallback). The first attempt (I05/mcp) ran after flow 01, which ends on a detail screen with no tab bar, so `Favorites` was absent there; not a defect |
| I06 | pass | I06/mcp/transcript.txt, I06/mcp/type.json | `grantiva_type " Yosemite"` → `Typed " Yosemite"`, field value `Golden Gate Bridge Yosemite` |
| I07 | pass | I07/logs-default.txt | default predicate now adds `OR process == "Landmarks"`; 1596 `[log]` lines from `Landmarks[pid]`, 0 `getpwuid_r`/"Filtering the log data" lines; help text updated |
| I08 | pass | I08/repro.txt | manually created and booted `qa-reg-ios-3` is not listed by `simulator sessions` after a run with session `qa-reg-ios-manual`; `teardown --session-id qa-reg-ios-manual --json` → `[]`, device stays Booted; a session-less run leaves no `simulator:<udid>` record (count 0). The device was deleted afterwards |
| I09 | pass | I09/repro.txt, I09/teardown-session.json | kill -9 of keep-alive on qa-reg-ios-3 (session reg-ios-i09 holding -3 and -4): `capacityRecordsCleared: 0`, `capacityRecordsKept` gives the reason, `sessionFilesRemoved` lists `50009-….grantiva` and `50009.owner.json`, and the `simctl diagnose` child is killed (`kind: diagnose`); sessions still list -3 under reg-ios-i09; `pgrep simctl diagnose` none. The repro's "session files after" check grepped the grantiva pid (49912*), but the files are named after the runner pid (50009*), so that line proves nothing. The JSON `sessionFilesRemoved` is the evidence |
| I10 | pass | I10/repro.txt, I10/ensure-help.txt | bare `ensure --name qa-reg-ios-1 --no-boot` reuses (exit 0, UDID on stdout); `--json` reuse of qa-reg-ios-4 (made on 26.0) reports `iOS 26.0`, `iPhone 17`; a new model-less name still fails with the inference error; help says `--name` alone reuses |
| I11 | pass | I11/grep.txt, I11/out/ | `sourceFile` and the junit `file` property are `.maestro/09-seed-empty.yaml`, with no `/var/folders` path in `out/` |
| I12 | pass | I12/fail.json, I12/setup-fail.json, I12/exit.txt | flow 09 now passes, so 99-crash was used as the failing flow: `--json` exit 1 with `allPassed:false`, `error`, and the failing step with its message; a setup failure (unknown simulator) prints `{"allPassed": false, "error": "Invalid argument: Simulator not found: …"}`. `--report-dir` was not passed in any I12 run, so no report dir was preserved and the "report dir path when preserved" part was not exercised |
| I13 | pass | I13/run.txt, I13/run-second.txt | no `scheme:`: exit 1 `No scheme specified … Found: Landmarks, Landmarks (UI Testing).`; still errors with `.grantiva/config.json` cached |
| I14 | pass | I14/repro.txt, I14/provenance-after-the-fact.txt | `GRANTIVA_MAX_SIMULATORS=1` timeout → exit 1, and `qa-reg-ios-3` does not exist afterwards. The repro's `## provenance` block did not read created.json. `~/.grantiva/simulator-capacity/created.json` was read afterwards in the fix pass (read-only, 15:08): it has no `qa-reg-ios-3` or `0BE596F4` entry (grep count 0) and lists only qa-reg-ios-1/-2 and two unrelated older entries |
| I15 | pass | I15/hierarchy-timeout.err, I15/not-installed.txt | `Error: GrantivaAgent on port 8457 did not answer within 0.01s (--timeout). Is the run still alive?`; after uninstall: `com.kylebrowning.Landmarks is not installed on qa-reg-ios-1. Drop --no-build or run grantiva build install.` (386 bytes, runner not started). App reinstalled afterwards |
| I16 | pass | I16/capture.json, I16/ls-captures.txt, I19/repro.txt | files are `Deep Links.png`; compare JSON paths `.grantiva/baselines/Deep Links.png`, `diffs/Deep Links_diff.png` |
| I17 | pass | I17/mcp/transcript.txt | result text includes `Errors:\nxcodebuild: error: Scheme Landmarks is not currently configured for the test action.` plus an output tail; `isError: true` |
| I18 | pass | I18/run.txt, I18/report.json | rows `qa/a/same` (8 steps) and `qa/b/same` (6 steps); the report durations are 4552 / 9749 ms and the table shows 6.1 s / 9.8 s (the first row seems to include session setup) |
| I19 | pass | I19/repro.txt | doc fix as chosen: README:125-130 and the `grantiva init` template state both checks, the fraction, and mean CIE76 over differing pixels; behaviour unchanged (`threshold: 1.0` still fails `pixel=0.47% perceptual=66.4`) |

Criteria not checkable at run time: the unit-test and CHANGELOG items. Unit tests were only spot-checked for presence by grep (e.g. WDADeviceHomeTests, DiffCommandTests `noBuildDevice`, SimulatorReaperTests `capacityRecordsKept`, WDAClientTests `wda/keys`, BuildToolsTests) and were not run, since `swift build` is not allowed. CHANGELOG.md was removed in #179 in favour of generated release notes.

## Observations (not brief regressions)

- README:92 path for per-simulator runner homes (`~/.grantiva/runner/devices/<udid>`) does not match the on-disk layout (`<runner home>/versions/<runner version>/devices/<udid>`).
- After `teardown --udid --force` followed by `teardown --session-id reg-ios-i09`, the home of the force-reclaimed device (0BE596F4…) was still present, while the other device's home was removed; it was pruned on the next `grantiva run` (I09/device-homes-after-next-run.txt). README:92 says teardown removes the home.
- `run --flow X --no-build` on an already-booted simulator prints `Booting simulator: …` before `Simulator booted:` (I15/not-installed.txt). This is cosmetic.
