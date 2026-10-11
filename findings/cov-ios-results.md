# iOS slice results: round 1 coverage pass

Binary `~/.grantiva-qa/bin/grantiva` 2.1.0; runner home `~/.grantiva-qa/runner` (1.1.28-grantiva.9); `GRANTIVA_SESSION_ID=cov-ios`.
Devices: `cov-ios-1` iPhone 17 iOS 26.0 (A1C8EC2A-FB08-4EAC-A738-51E98D13CDBF), `cov-ios-2` iPhone 17 iOS 27.0 (C2C8E2D3-F7E6-4FBF-A2FE-7A25B9363961).
App: scratch copy of landmarks-demo/ios at 4e49dc4 (config `simulator:` set to `cov-ios-1`). Evidence: `findings/evidence/cov-ios/<ID>/`.
Rows run on 26.0 unless the ID carries a `@27.0` suffix (flow-command rows and the stock set repeated on 27.0).

| ID | result | evidence | note |
|---|---|---|---|
| STEP1 | pass | STEP1/ | build install on cov-ios-1 (26.0) and cov-ios-2 (27.0), both exit 0 |
| IOS-117 | pass | IOS-117/stock-26.* | 12/12 flows + 5 screens, exit 0; `Using cached GrantivaAgent build (sim-ios26.0-iphone-wda16.12.8-r1)`; no first-time build (narration around it: see N-18) |
| IOS-118 | pass | IOS-118/stock-27.* | 12/12 + 5 screens, exit 0; cache line `sim-ios27.0-iphone-wda16.12.8-r1` |
| IOS-001 | pass | IOS-001/ | stdout only the UDID; stderr `Created cov-ios-3 iPhone 17 (E478…) — Booted`; simctl shows it Booted |
| IOS-002 | pass | IOS-002/ | same UDID; stderr `Reused cov-ios-3 iPhone 17 (E478…) — Booted` |
| IOS-003 | pass | IOS-003/ | created `cov-ios-4 Pin` as iPhone-17 on iOS 27.0 (newest); deleted in IOS-019 |
| IOS-004 | pass | IOS-004/ | `--runtime 26.0` created on iOS 26.0 (waited ~5 min for capacity 4/4, freed by IOS-019); `--runtime 99.9` exit 1 `Simulator runtime not found or unavailable: "99.9"`, nothing created; device deleted |
| IOS-005 | pass | IOS-005/ | `--no-boot`: created Shutdown, stdout the UDID; deleted |
| IOS-006 | pass | IOS-006/ | new: JSON with udid, point/pixel dimensions, scale, runtime iOS 27.0; bare `--name cov-ios-1 --json` reuse: `created:false`, `device_type: iPhone 17`, `runtime: iOS 26.0` |
| IOS-007 | pass | IOS-007/ | exit 1, `Could not infer a device type from the name "cov-thing". Include a device model in the name (for example "iPhone 17") or pass --device-type.`; nothing created |
| IOS-009 | pass | IOS-009/ | created.json lists `cov-ios-3 iPhone 17` (E478…) after IOS-001 |
| IOS-019 | pass | IOS-019/ | delete exit 0 `Deleted cov-ios-4 Pin (…)`; second exit 1 `Error: Invalid argument: Simulator not found: "cov-ios-4 Pin"` |
| IOS-008 | fail | IOS-008/concurrent*.out | expected one device, `Created` + `Reused`; actual: one device but the second call exits 1 with `Error: An error was encountered processing the command (domain=com.apple.CoreSimulator.SimError, code=405): Unable to boot device in current state: Booted` (3/3 tries); before it, it logs `Warning: Waiting for simulator capacity (4/6)` with capacity free (GRANTIVA_MAX_SIMULATORS=6), counting its twin's device |
| IOS-010 | pass | IOS-010/ | plain lists 3 Grantiva slots (3/4) with owner `cov-ios`; `--json` `acquiredAt` ISO 8601 (`2026-10-11T06:35:11Z`), `bootedByGrantiva`; the booted iPhone 17 Pro is not listed |
| IOS-011 | pass | IOS-011/ | MAX=3 with cov-ios-1..3: `Warning: Waiting for simulator capacity (3/3): cov-ios-1 [cov-ios], cov-ios-2 [cov-ios], cov-ios-3 iPhone 17 [cov-ios]` (the booted iPhone 17 Pro not named); gave up at the 15 s wait cap, device removed |
| IOS-012 | pass | IOS-012/ | MAX=1 (3 slots used): waits (`Waiting for simulator capacity (3/1)`), times out at 10 s |
| IOS-013 | pass | IOS-013/ | WAIT_TIMEOUT=5: exit 1 after 6.8 s `Timed out after 5s waiting for a Grantiva simulator slot (limit 3)…`; no cov-ios-4 device in simctl or created.json |
| IOS-014 | pass | IOS-014/ | ensure then `build install` under GRANTIVA_SESSION_ID=cov-ios: `sessions --json` unchanged, one record per device, all owner `cov-ios` |
| IOS-015 | pass | IOS-015/ | session cov-ios-tmp: Grantiva-created `cov-ios-4 Tmp` `deleted: true` (gone); pre-existing `cov-ios-3 Pre` (simctl-created) `deleted: false`, left Shutdown; per-session records in JSON |
| IOS-016 | pass | IOS-016/ | after kill -9 of the keep-alive run: `reclaimed: true`; killed runner, WDA xcodebuild and `simctl diagnose`; `capacityRecordsKept` cov-ios with reason; `deviceHomesRemoved` the 1.1.28 home; session files removed; exit 0; device stays Booted. Note: the killed run's temp report dir and staged-flow dir under /var/folders survive the reclaim (leftover-tmp.txt). |
| IOS-017 | fail | IOS-017/teardown-free.out | expected `reclaimed: false` for a free UDID; actual `"reclaimed" : true` with `processes: []`, `sessionFilesRemoved: []` (only the device home was removed and `leaseReleased: true` reported with no lease held); exit 0 |
| IOS-018 | blocked | IOS-018/created-json.out | blocked: created.json lists devices outside cov-ios-* (TienLen Flow deal-investigation, BLESwift E2E probe, fix-8-ios-26, fix-8-ios-27); `simulator cleanup` not run per the slice rules |
| IOS-020 | pass | IOS-020/ | cov-ios-3 created+booted with simctl; `run` on it (exit 0) under GRANTIVA_SESSION_ID=cov-ios-tmp2: `sessions --json` during the run lists only cov-ios-1/2 (no slot); `teardown --session-id cov-ios-tmp2 --json` prints `[]`, device still Booted |
| IOS-121 | fail | IOS-121/ | expected teardown and delete to remove `<runner home>/versions/*/devices/<udid>`; `simulator delete` did, but `simulator teardown --udid <cov-ios-3> --json` (no --force) after a run on it printed `[]`, exit 0, and left `…/1.1.28-grantiva.9+android-drivers-2/devices/8936CA04-…` in place (README: teardown with or without --force removes it) |
| IOS-122 | fail | IOS-122/run.err, run3.* | expected a run on the already-booted cov-ios-1 with GRANTIVA_SESSION_ID unset to take no slot; actual: refused before the runner, exit 1, `Error: Simulator cov-ios-1 (A1C8…) belongs to Grantiva session cov-ios. Teardown that session or select another simulator.` (README:452-455 does not document that a named session's device refuses session-less runs; "Teardown" used as a verb). On a simctl-booted cov-ios-3 the run passes and takes no slot (sessions during/after list only cov-ios-1/2) |
| IOS-155 | pass | IOS-155/ | `teardown --udid --force --json` plain/`--quiet`/`--verbose`: stdout byte-identical (549 B); plain and quiet stderr empty; verbose adds `[debug] <ISO time> com.grantiva.cli: $ /bin/ps …` and `exit 0: …`; device deleted at the end |
| IOS-021 | pass | IOS-021/ | `✓ Build succeeded`, exit 0 |
| IOS-022 | pass | IOS-022/ | builds, installs, launches (`[grantiva] Done — com.kylebrowning.Landmarks running on cov-ios-1`; launchctl shows the app) |
| IOS-023 | pass | IOS-023/ | JSON has status, scheme, bundleId, appPath, dataContainerPath, simulator.name/udid; app not running after (launchctl count 0) |
| IOS-024 | pass | IOS-024/ | absolute path with spaces and relative `rel-dd` both receive Build/Products/…/Landmarks.app; appPath points there |
| IOS-025 | pass | IOS-025/ | xcodebuild argv: `'build' 'COV_MARKER=1' '-derivedDataPath' 'y'` (config's `-derivedDataPath x` dropped, other setting kept); products in y/, no x/ |
| IOS-026 | pass | IOS-026/ | exit 1; `✗ Build failed` with xcodebuild's `The project named "Landmarks" does not contain a scheme named "NoSuchScheme"` |
| IOS-027 | fail | IOS-027/ | exit 1 with `No scheme specified. … Found: Landmarks, Landmarks (UI Testing).` as expected, but the same message tells `build build` users to `use --app-file to provide a pre-built binary`, and `build build` has no `--app-file` option (help: build_build.txt) |
| B-I13.1 | pass | IOS-027/, B-I13.1/ | two schemes, none configured: exit 1 `No scheme specified … Found: Landmarks, Landmarks (UI Testing).`; with one scheme (copy with the UI Testing scheme removed) auto-detects `Landmarks` silently, exit 0 |
| B-I13.2 | fail | B-I13.2/ | expected a cached detection never to override a missing scheme when the project has several; actual: after a one-scheme auto-detect cached `"scheme":"Landmarks","schemes":["Landmarks"]` in .grantiva/config.json, restoring the second scheme and running `build build` (no scheme) twice builds `Landmarks` silently, exit 0 both times |
| IOS-028 | pass | IOS-028/ | `--simulator cov-ios-1` and `--simulator <UDID>` both run xcodebuild with `-destination 'platform=iOS Simulator,id=A1C8EC2A-…'` |
| IOS-123 | fail | IOS-123/ | `build build --bundle-id com.kylebrowning.Landmarks` accepted, exit 0. Used: `build install --no-launch --bundle-id com.example.Other` fails, but with a raw `Error: An error was encountered processing the command (domain=NSPOSIXErrorDomain, code=2): The operation couldn’t be completed. No such file or directory` that names neither the bundle ID nor the mismatch with the built app |
| X-005 | pass | X-005/ (iOS half) | iOS `build build --json` keys: destination, duration, errors, productPath, scheme, success, warnings (Android half compared at triage) |
| X-006 | pass | X-006/ (iOS half) | iOS `build install --no-launch --json` keys exactly status, scheme, bundleId, appPath, dataContainerPath, simulator{name,udid} |
| IOS-124 | pass | IOS-124/ | README:234-250 as written (scheme/UDID/flow substituted): install JSON parses, `jq -r .dataContainerPath` gives an existing dir; `run --no-build … --bundle-id` 1/1, exit 0 |
| IOS-029 | pass | IOS-117/stock-26.* | configured run: per-step ✓ lines, 12/12, exit 0 (failing suites exit non-zero: IOS-068, IOS-069) |
| IOS-030 | pass | IOS-030/ | 01-12 each `run --no-build --flow` exit 0; 99-crash exit 1 |
| IOS-119 | pass | IOS-030/99-crash.* | fails at the first wait (`assertVisible: text="Landmarks"`, 12.2 s) with `WDA error: The application under test with bundle id 'com.kylebrowning.Landmarks' is not running, possibly crashed`; exit 1; `Failure screenshot: .grantiva/captures/failure-1791702372.png` (PNG 1206x2622) |
| IOS-031 | fail | IOS-031/ | fails before boot/build (0.02 s, exit 1, `No screens or flows configured in grantiva.yml`), no report, ready `failed` as expected; but the ready file has `"reportDir" : "out"` for a directory that was never created and no `error` field saying why (a usage error gets one, README:85) |
| IOS-032 | pass | IOS-032/ | stale `x.ready` deleted at startup (absent t=1..6 s during the run), rewritten once at the end with `status: passed` |
| IOS-035 | pass | IOS-035/ | `--env 'LANDMARKS_NOTE=a=b c'` with 22-show-note under --keep-alive: hierarchy has StaticText label/value `a=b c` |
| IOS-036 | pass | IOS-036/ | `--env LANDMARKS_NOTE=hello`: StaticText `hello` at y=168, first row under the Deep Links title |
| IOS-037 | pass | IOS-037/ | two `--env` flags: 08-scroll passes (Landmark 70 reached, so SEED=many arrived) and hierarchy on Deep Links has StaticText `x`. (scrollUntilVisible steps print ⚠ and take 33-35 s: see IOS-224) |
| IOS-038 | pass | IOS-038/ | `--env LANDMARKS_SEED=empty`: `✓ assertVisible: text="No landmarks yet"`, exit 0 |
| IOS-039 | pass | IOS-039/ | `--env LANDMARKS_CRASH_ON_LAUNCH=1`: fails at the first assert (app not running, possibly crashed), exit 1, `Failure screenshot: .grantiva/captures/failure-1791702615.png`, ready `failed` |
| IOS-040 | pass | IOS-040/ | no scheme configured: `Resolved: scheme=(none)`, `Using pre-built binary: Landmarks.app`, installs `com.kylebrowning.Landmarks`, 1/1, exit 0 |
| IOS-042 | pass | IOS-042/ | `--app-file Landmarks.ipa`: extracted (`Using pre-built binary: Landmarks.app`), installed, 1/1, exit 0 |
| IOS-043 | pass | IOS-043/ | iphoneos build rejected before anything runs: `Error: Invalid app binary: Binary is built for [iPhoneOS], not iPhoneSimulator. Rebuild with -destination 'generic/platform=iOS Simulator'.`, exit 1 |
| IOS-044 | pass | IOS-044/ | installed: passes; after `simctl uninstall`: exit 1 before the runner, `Error: com.kylebrowning.Landmarks is not installed on cov-ios-1. Drop --no-build or run grantiva build install.` |
| IOS-045 | pass | FLOWS-26/01-selectors.* | `✓ tapOn: text="Mountains → Yosemite Valley"`, label unmangled; `Yosemite Valley` asserted |
| IOS-077 | fail | FLOWS-26/10-lifecycle.*, $S/rep/26/10-lifecycle runner log copy: IOS-077/ | app receives `--flag` (runner log `launchApp com.kylebrowning.Landmarks: argv=["--flag" "true"]`), but the same arguments map is also sent as launch environment: `env=map[--flag:true]` / `"environment":{"--flag":"true"…}` (an environment variable named `--flag`) |
| IOS-201 | pass | IOS-030/01-browse.* | `✓ tapOn: text="Golden Gate Bridge"`; detail asserted |
| IOS-202 | pass | FLOWS-26/01-selectors.* | `tapOn: {text: "Lakes", exact: true}`, `{text: "Lake Tahoe", exact: true}` and `{text: …, index: 1}` tap the matching elements |
| IOS-203 | pass | FLOWS-26/01-selectors.* | `✓ assertVisible: id="clock"`, `✓ tapOn: id="clock"` on Caching Demo |
| IOS-204 | pass | FLOWS-26/01-selectors.* | `tapOn: "Golden Gate.*"` opens San Francisco detail; `assertVisible: ".*Lake.*"` passes; `assertNotVisible: "Lake"` passes (whole-value match) |
| IOS-205 | pass | FLOWS-26/01-selectors.* | regex assert passes; `✓ assertNotVisible: text="Golden Gate.*", exact=true`; exact tap opens Lake Tahoe (Sierra Nevada, CA); no `not supported` warning |
| IOS-206 | pass | FLOWS-26/02-exact-negative.* | fails at step 3: `Element not visible: text='Golden Gate.*' (cause: … no elements match selector; closest on-screen texts: "Golden Gate Bridge", …)`, exit 1 (no hierarchy hint: see B-C21.1, X-019) |
| IOS-207 | pass | FLOWS-26/01-selectors.* | `{text: "(Lake .*|.* Lake)", index: 1}` opens Mono Lake (`Lee Vining, CA`). Note: the step line prints `tapOn: text="(Lake .*|.* Lake)"` without the index |
| IOS-208 | fail | FLOWS-26/04-point-taps.* | behaviour as expected (`Last tap: center`, `Taps: 1`), but every point tap's step line is `✓ tapOn:  (1.3s)` with an empty selector: the point is not shown (exact and text selectors are) |
| IOS-209 | pass | FLOWS-26/04-point-taps.* | `point: "100%,100%"` and `"0%,0%"` both ✓ with no out-of-bounds error (empty step label: IOS-208) |
| IOS-210 | pass | FLOWS-26/03-gesture-lab-taps.* | `doubleTapOn: id="gesture-pad"` → `Double taps: 1`, `Taps: 1` unchanged |
| IOS-211 | pass | FLOWS-26/03-gesture-lab-taps.* | `longPressOn` → `Long presses: 1` |
| IOS-213 | pass | FLOWS-26/15-input-unicode.* | `inputText: " · Ünïcødé ✓"` → `San Francisco, CA · Ünïcødé ✓` visible, unmangled |
| IOS-214 | pass | IOS-030/01-browse.*, FLOWS-26/01-selectors.* | string, `{text:}`, regex and `{id:}` assertVisible all pass |
| IOS-215 | pass | IOS-030/05-category.* | flow 05 passes including `assertNotVisible: "Golden Gate Bridge"` on Lakes |
| IOS-216 | pass | FLOWS-26/05-swipe-forms.* | LEFT/RIGHT/UP/DOWN each followed by `Last swipe: left/right/up/down` |
| IOS-217 | pass | IOS-030/02-favorite.* | flow 02 passes (swipe from `Lake Tahoe` reveals Remove; empty state) |
| IOS-218 | pass | FLOWS-26/05-swipe-forms.* | `swipe: {direction: UP, from: {id: gesture-pad}}` → `Last swipe: up` |
| IOS-219 | fail | FLOWS-26/07-swipe-from-missing.* | expected `Element not found for swipe` naming `No Such Row`; actual `✗ swipe: LEFT (13.4s) ╰─ Element not found: text='No Such Row' (cause: …)` (no "for swipe"; Android's line reads `Element not found for swipe: …` per the landmarks-demo PR), exit 1 |
| IOS-220 | pass | FLOWS-26/05-swipe-forms.* | `start: "80%, 50%", end: "20%, 50%"` → `Last swipe: left` |
| IOS-221 | pass | FLOWS-26/06-swipe-absolute.* | outcome (a): `start: "300, 600", end: "60, 600"` read as points, `Last swipe: left` |
| IOS-222 | pass | FLOWS-26/05-swipe-forms.* | `duration: 1500` swipe: `✓ swipe: RIGHT (1.9s)`, `Last swipe: right` |
| IOS-223 | pass | IOS-030/10-seed-many.* | four bare `scroll` (each `scroll: DOWN`), `Landmark 30` visible |
| IOS-224 | fail | FLOWS-26/08-scroll.*, $S report: flows/flow-000.json | both elements found and report.json says `"status": "passed"`, but the live and summary lines print `⚠ scrollUntilVisible: text="Landmark 70" (32.4s)` / `⚠ … "Golden Gate Bridge" (34.9s)` with no explanation of the warning (and 32-35 s per search) |
| IOS-225 | pass | FLOWS-26/14-runflow.* | string and `file:` forms each run the sub-flow's two steps. Note: the step line prints the sub-flow as an absolute `/tmp/…/14-runflow-sub.yaml` path, not as written |
| IOS-226 | fail | FLOWS-26/14b-runflow-inline.* | expected inline `runFlow: {commands: […]}` to run; actual exit 1 before any step: `Error: Invalid argument: Invalid runFlow command: object form requires a string 'file' field`, and it still prints `Failure screenshot: …/failure-1791703009.png` for a parse error |
| IOS-227 | pass | IOS-030/11-slow.* | flow 11 passes (`Loaded after delay` within the wait) |
| IOS-228 | fail | FLOWS-26/09-waits.* | the wait passes after the load (5.2 s; report `passed`), but the step prints `⚠ extendedWaitUntil: notVisible text="Loading…"` with no explanation of the warning |
| IOS-229 | pass | FLOWS-26/09-waits.* | bare and `{timeout: 2000}` `waitForAnimationToEnd` both ✓ |
| IOS-230 | pass | IOS-030/01-browse.* | bare `launchApp` ✓ |
| IOS-231 | fail | FLOWS-26/10-lifecycle.*, IOS-231/ | Favorites empty after `launchApp: {clearState: true}` (and a probe shows the data container replaced, marker file gone), but the runner log shows no app-data clearing: only `apps/terminate` then `launchApp … argv=[] env=map[]` with a silent 0.8 s gap (favorites are in-memory in this app, so the Favorites check alone does not prove clearing) |
| IOS-232 | pass | FLOWS-26/11-launch-environment.* | `launchApp: {environment: {LANDMARKS_NOTE: from step}}` → `from step` on Deep Links |
| IOS-233 | pass | FLOWS-26/10-lifecycle.* | `stopApp` before any launch ✓ (1.1 s) and twice in a row ✓ (2 ms) |
| IOS-234 | pass | FLOWS-26/10-lifecycle.* | `killApp` (terminate) then `launchApp` → `Featured` |
| IOS-235 | pass | IOS-030/07-deeplink.*; captures listing | file `07-deeplink-cmd-004-Deep Link Lakes.png` (space kept, no %20) |
| IOS-236 | pass | IOS-030/09-seed-empty.* | flow 09 without `--env` passes: header `env: LANDMARKS_SEED: empty` reaches the app |
| IOS-237 | pass | FLOWS-26/16-setpermissions.* | `setPermissions` ✓ with the header appId, bare `scroll: DOWN` ✓ (the flow relaunches after setPermissions, which terminates the app on iOS) |
| IOS-238 | pass | FLOWS-26/10-lifecycle.*, IOS-077/ | app receives `--flag` (argv); see IOS-077 for the environment leak |
| N-11 | pass | FLOWS-26/04-point-taps.* | iOS half: `100%,100%` and `0%,0%` taps ✓, no error, on screen (Taps count unchanged: they land outside the pad, home-indicator area) |
| IOS-075 | pass | FLOWS-26/10-lifecycle.* | `- stopApp` as first step (app not running) ✓ |
| IOS-125 | pass | IOS-125/ | dir with no config: `Resolved: scheme=(none)`, the flow's `appId: com.kylebrowning.Landmarks` used, 1/1, exit 0 |
| IOS-126 | fail | IOS-126/ | flag > config holds (`--bundle-id com.kylebrowning.Landmarks` beats config `com.example.wrong`: pass; without the flag: `com.example.wrong is not installed`). But with no flag, no config `bundle_id`, scheme configured and flow `appId: ${APP_ID}`, there is no project detection: exit 1 `Error: Invalid argument: Bundle ID is required to run flows. Pass --bundle-id or set bundle_id in grantiva.yml.` (README:174 ends the order with project detection) |
| IOS-127 | pass | IOS-127/ | 11: step `environment:` beats header (`from step` shown, `from header` absent); 12 with `--env LANDMARKS_NOTE=from-cli` passes; 12 without it fails showing `from step` (expected negative) |
| IOS-128 | pass | IOS-128/ | `run --derived-data-path dd128a` and `diff capture --derived-data-path dd128b` each put Landmarks.app under their path; both exit 0 |
| IOS-056 | pass | IOS-056/ | `hierarchy` run the moment the ready file appeared: exit 0, iOS XML (XCUIElementTypeApplication "Landmarks") |
| IOS-047 | pass | IOS-047/kaA.* | keep-alive run: flow passes, ready `passed`, session held (`Press Ctrl-C to release.`), process stays alive until signalled (released in IOS-057) |
| IOS-048 | pass | IOS-048/ | plain `hierarchy`: iOS XML on stdout (48 elements); app pid 4609 identical before and after (no relaunch) |
| IOS-049 | pass | IOS-049/ | `--format json` parses (object with `value`, `sessionId`); shape: see X-011 |
| IOS-050 | pass | IOS-050/ | `--json` output parses and is identical to `--format json` |
| IOS-051 | pass | IOS-051/ | `--udid <cov-ios-1>` prints that simulator's XML |
| IOS-052 | pass | IOS-052/ | sessions on cov-ios-1 (01-browse, detail) and cov-ios-2 (05-category, Lakes): plain `hierarchy` returns the newer cov-ios-2 tree (Mono Lake present, Plan Visit absent) |
| IOS-053 | pass | IOS-053/ | `--udid <cov-ios-1>` returns the older session's tree (Plan Visit present, Mono Lake absent) |
| IOS-055 | pass | IOS-055/ | one line, exit 1: `Error: GrantivaAgent on port 8235 did not answer within 0.01s (--timeout). Is the run still alive?` |
| IOS-086 | pass | IOS-086/ | no runner start; `runner dump-hierarchy --udid <cov-ios-1>` falls back to the keep-alive session (tree shows the Golden Gate detail); `--format json` too |
| N-01 | fail | N-01/ | iOS half: with a live `run --keep-alive` session from the same project dir, `runner stop` prints `No active session found.` and exits 0; the keep-alive run (pid 4163) and its session files stay |
| IOS-060 | pass | IOS-060/ | fails in 0.85 s: `Simulator A1C8… is already owned by another Grantiva run (pid 4163, started 79s ago, grantiva-runner pid 4267, --keep-alive). Release it with `grantiva simulator teardown --udid … --force`, or run against a different simulator via `grantiva simulator ensure --name <unique-name>`.` |
| X-018 | pass | X-018/ (iOS half) | iOS refusal names `grantiva simulator teardown --udid … --force` and `grantiva simulator ensure --name <unique-name>` |
| IOS-057 | pass | IOS-057/ | kill -INT of the cov-ios-2 keep-alive: runner, WDA xcodebuild and WDA app process gone, its session/owner files removed, the other session's files kept; `simulator sessions` still lists cov-ios-2 under its named session (lease freed). Note: `<runner home>/locks/` keeps one .lock per UDID ever used, including deleted simulators |
| IOS-101 | pass | MCP-LIVE1/run/transcript.txt | keep-alive on cov-ios-1 (cov-ios-2 and the user's iPhone 17 Pro also booted): `[Config] platform: ios`; `[Simulator] udid: A1C8EC2A-…`, `source: runner session` = `[Runner Session] udid` |
| MCP-042 | fail | MCP-LIVE1/run/transcript.txt | sections and udids as expected, but `[Runner Session]` prints an empty `bundle_id: ` line for the keep-alive session, and `[Simulator] runtime: iOS-26-0` (identifier fragment; `simulator ensure --json` says `iOS 26.0`) |
| B-C06.1 | pass | MCP-LIVE1/run/transcript.txt | `[Simulator] udid` = `[Runner Session] udid` (A1C8…); no-session case: MCP-044 |
| X-020 | pass | MCP-LIVE1/run/transcript.txt (iOS half) | iOS sections: [Config], [Simulator] (name, udid, runtime, state, source), [Xcode], [Runner Session] (pid, wda_port, bundle_id, udid) |
| IOS-102 | fail | MCP-LIVE1/run/transcript.txt | `{label: "Favorites"}` taps the tab and returns the Favorites tree; `{x: 287, y: 822}` (points) opens Deep Links. But `{label: "heart"}` returns `Tapped on "heart"` on the Favorites screen, where the only `heart` is the Favorites tab's identifier: the symbol name still matches the tab |
| B-I05.1 | pass | MCP-LIVE1/run/transcript.txt | `{label: "Favorites"}` taps the tab, returns the Favorites tree; `heart` matches only through the tab's identifier (no element is labelled heart), which the criterion allows as a fallback |
| IOS-103 | pass | MCP-LIVE1/run/transcript.txt | `grantiva_tap {}` → result `isError: true`, `Error: provide either 'label' or both 'x' and 'y' coordinates.`; next request answered |
| IOS-106 | pass | MCP-LIVE1/run/transcript.txt | `{}` → image/png base64; `{format: file}` → `Screenshot saved to .grantiva/mcp-screenshot.png` (PNG 1206x2622) |
| IOS-108 | pass | MCP-LIVE1/run/transcript.txt | resources/list has both; `grantiva://hierarchy` application/json tree, `grantiva://screenshot` base64 PNG blob |
| MCP-076 | pass | MCP-LIVE1/run/transcript.txt (iOS half) | iOS: hierarchy resource JSON tree, screenshot resource base64 PNG, live keep-alive session |
| IOS-109 | pass | MCP-LIVE1/run/transcript.txt, MCP-LIVE1/run2/transcript.txt | Landmarks list and Deep Links: `No accessibility violations found.`; detail: 2 `small_tap_target` (`Favorite` 32x36pt, `Bridges` 112x30pt, below 44x44pt); tree via grantiva_a11y_tree |
| MCP-017 | pass | MCP-LIVE1/run/transcript.txt | JSON tree with label, type, frame, name, enabled, visible. Note: frame values are strings (`'height': '44'`) |
| MCP-021 | pass | MCP-LIVE1/run2/transcript.txt | iOS: small targets flagged against 44 pt on the detail screen; list/Deep Links clean (Compose clause n/a on iOS) |
| IOS-116 | pass | IOS-116/ | with grantiva.yml and grantiva-android.yml: `--platform ios` starts, context `platform: ios`, taps drive cov-ios-1; without `--platform` the server exits `Both grantiva.yml and grantiva-android.yml exist. Pass --platform ios|android or set GRANTIVA_PLATFORM.` |
| MCP-079 | pass | MCP-079/other-dir/transcript.txt | iOS half: server in $S/p027 while a keep-alive from $APP is live: every session tool (screenshot, tap, swipe, type, a11y_tree, a11y_check, script) returns isError no-session text ending `1 keep-alive session(s) started from another project directory or for another platform were ignored.`; context `No active session.` |
| B-C03.1 | pass | MCP-079/other-dir/transcript.txt | server for project B ($S/p027) does not touch A's session/simulator; starts with no session |
| B-C03.2 | pass | MCP-079/other-dir/transcript.txt, IOS-052 owner.json | owner.json records `projectDirectory` and `platform`; a session from another directory is not used (see MCP-079) |
| B-C11.2 | fail | MCP-079/other-dir/transcript.txt | session tools return isError with the no-session text (as required), but the text is `Error: Invalid argument: No active runner session at …/.grantiva/session.json. Start one with 'grantiva runner start' or `grantiva run --keep-alive` in …`: labelled "Invalid argument" though no argument was wrong, and the two commands are quoted differently (single quotes vs backticks) |
| MCP-044 | pass | MCP-079/other-dir/transcript.txt | no session for that dir: `[Simulator] name: cov-ios-1 … source: simulator in grantiva.yml (no runner session)`, `[Runner Session] No active session.`; not the user's booted iPhone 17 Pro |
| IOS-054 | fail | IOS-054/ | after `kill -9` of the keep-alive `grantiva run` (pid 4163), its runner (pid 4267) lives on and `hierarchy` / `hierarchy --udid` still return the tree (exit 0): the session file is keyed by the runner pid, so a kill -9'd run does masquerade as live (docs/dump-hierarchy.md:21). Only after `teardown --force` does `hierarchy` fail fast: `Error: Invalid argument: No keep-alive session found. Start one with `grantiva run --keep-alive` first.` |
| IOS-149 | pass | IOS-149/ | README:438 `grantiva simulator teardown --udid "$UDID" --force` after the kill -9: killed runner 4267, WDA 4332, diagnose 12034, released the lease, kept the cov-ios record, removed 2 session files and the device home; exit 0 |
| IOS-058 | pass | IOS-058/ | kill -INT during the 45 s wait of 18-long-wait under --keep-alive: exit 130, ready `status: interrupted`, flow `18-long-wait: interrupted` (none `running`); no runner/WDA left for the UDID; session files removed |
| IOS-073 | fail | IOS-073/ | killed at ~30 s (32.0 s), exit 1, ready `failed` with flow `failed`, message `Error: grantiva killed the runner after 30s (--timeout <seconds> to raise the cap). The runner's last output above shows how far it got.` (no stray colon); but the `--report-dir` report.json is left at `"status": "running"`, `summary.running: 1` (out073/report.json) |
| B-I11.2 | pass | IOS-073/out073/ | `--timeout 30 --report-dir`: no /var/folders path in out/; `sourceFile` and junit `file` are `.maestro/coverage/18-long-wait.yaml` as passed |
| B-A06.1 | pass | IOS-058/, IOS-073/, IOS-032/, IOS-034/ | iOS half: SIGINT ready file `interrupted` with the flow `interrupted`; `--timeout` kill writes `failed`, no `running` flow; ready files without `--report-dir` have no `reportDir` key |
| B-A06.2 | pass | IOS-058/ | iOS half: the interrupted status is in the ready file after SIGINT during a flow (recorded before teardown finished) |
| X-023 | pass | IOS-073/timeout30.err (iOS half) | iOS: `grantiva killed the runner after 30s (--timeout <seconds> to raise the cap). The runner's last output above shows how far it got.` (screens timeout wording: IOS-135) |
