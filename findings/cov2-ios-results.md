# iOS slice results: round 2 coverage pass

Binary `~/.grantiva-qa/bin/grantiva` 2.1.0 (main c65fc17); runner home `~/.grantiva-qa/runner` (1.1.28-grantiva.11, `-wda16.12.8-r1` caches); `GRANTIVA_SESSION_ID=cov2-ios`; `GRANTIVA_API_KEY` unset.
Devices: `cov2-ios-1` iPhone 17 iOS 26.0 (7E846901-F93F-4220-A153-7043061033D7), `cov2-ios-2` iPhone 17 iOS 27.0 (BEE381AC-0D32-4D84-B304-068815F08B2F); extra `cov2-ios-3`/`-4` only inside rows (UDIDs in the row evidence).
App: scratch copy of landmarks-demo/ios at b3f046f (`grantiva.yml` `simulator:` set to `cov2-ios-1`), built and installed with `build install` on both runtimes (STEP1). Evidence: `findings/evidence/cov2-ios/<ID>/` (`commands.txt` with cwd, command, exit, elapsed and the `uptime` before each device command; raw stdout/stderr verbatim). Helpers: `findings/evidence/cov2-ios/inputs/`.
Rows run on 26.0 (`cov2-ios-1`) unless the ID carries a `@27.0` suffix (flow-command rows and the stock set repeated on `cov2-ios-2`). Round-1 device names in the matrix are read as their `cov2-` equivalents (matrix header).

| ID | result | evidence | note |
|---|---|---|---|
| STEP1 | pass | STEP1/ | ensure created cov2-ios-1 (26.0) and cov2-ios-2 (27.0), both Booted; build install on both exit 0 (app launched) |
| IOS-117 | pass | IOS-117/stock-26.* | 12/12 flows + 5/5 screens, exit 0; `Using cached GrantivaAgent build (sim-ios26.0-iphone-wda16.12.8-r1)` (printed twice); no first-time build |
| IOS-118 | pass | IOS-118/stock-27.* | 12/12 + 5/5 screens, exit 0; cache line `sim-ios27.0-iphone-wda16.12.8-r1`; no first-time build |
| IOS-119 | pass | IOS-119/crash-26.* | exit 1 in 10.2 s; fails at the first assertVisible with `(cause: app crashed: com.kylebrowning.Landmarks is not running ...)`; failure screenshot path printed |
| IOS-120 | pass | IOS-120/capture-26b.*, capture-27.*, shots-26/, shots-27/ | 5/5 captured on 26.0 and 27.0, exit 0; Lakes shows the Lakes list (Lake Tahoe, Mono Lake, Crater Lake); Detail shows Golden Gate Bridge with Plan Visit |
| IOS-001 | pass | IOS-001/ | stdout only the UDID (B32022DF-…); stderr `Created cov2-ios-3 iPhone 17 (B32022DF-…) — Booted`; simctl shows Booted |
| IOS-002 | pass | IOS-002/ | same UDID on stdout; stderr `Reused cov2-ios-3 iPhone 17 (B32022DF-…) — Booted` |
| IOS-003 | pass | IOS-003/ | created `cov2-ios-4 Pin` as iPhone-17 on iOS 27.0 (newest installed runtime), Booted; deleted in IOS-019 |
| IOS-004 | pass | IOS-004/ | `--runtime 26.0` created on iOS 26.0, Booted; `--runtime 99.9` exit 1 `Simulator runtime not found or unavailable: "99.9"`, no R99 device in simctl; R26 deleted |
| IOS-005 | pass | IOS-005/ | `--no-boot`: stdout the UDID only; stderr `Created … — Shutdown`; simctl Shutdown; deleted |
| IOS-006 | pass | IOS-006/ | new: JSON with udid, point/pixel dimensions, scale, `runtime: iOS 27.0`, `created: true`; bare `--name cov2-ios-1 --json` reuse: `created: false`, `deviceType: iPhone 17`, `runtime: iOS 26.0` |
| IOS-007 | pass | IOS-007/ | exit 1, `Could not infer a device type from the name "cov-thing". Include a device model in the name (for example "iPhone 17") or pass --device-type.`; no cov-thing in simctl |
| IOS-008 | pass | IOS-008/ | two concurrent ensures: one device (8BB2…); a: `Created … — Booted`, b: `Waiting for … another Grantiva process (pid 47961) is booting it.` (twice) then `Reused … — Booted`; both exit 0, same UDID |
| IOS-009 | pass | IOS-009/created-json.out | created.json lists `cov2-ios-3 iPhone 17` (B32022DF-…) after IOS-001 |
| IOS-010 | pass | IOS-010/ | plain lists 4 Grantiva slots (4/4) with owner `cov2-ios`; `--json` `acquiredAt` ISO 8601 (`2026-10-11T16:52:16Z`), `bootedByGrantiva`; the booted iPhone 17 Pro is not listed |
| IOS-011 | pass | IOS-011/ | MAX=3 with cov2-ios-1..3: `Warning: Waiting for simulator capacity (3/3): cov2-ios-1 [cov2-ios], cov2-ios-2 [cov2-ios], cov2-ios-3 iPhone 17 [cov2-ios]` (iPhone 17 Pro not named); gave up at the 15 s cap, nothing left behind |
| IOS-012 | pass | IOS-012/ | MAX=1 (3 slots used): waits (`Waiting for simulator capacity (3/1)`), times out at 10 s, exit 1 |
| IOS-013 | pass | IOS-013/ | WAIT_TIMEOUT=5: exit 1 after 6.7 s `Timed out after 5s waiting for a Grantiva simulator slot (limit 3)…`; no cov2-ios-4 in simctl or created.json |
| IOS-014 | pass | IOS-014/ | ensure cov2-ios-1 then `build install` under GRANTIVA_SESSION_ID=cov2-ios: `sessions --json` byte-identical before/after; one record per device, all owner `cov2-ios` |
| IOS-015 | pass | IOS-015/ | session cov2-ios-tmp: Grantiva-created `cov2-ios-4 Tmp` `deleted: true` (gone); pre-existing simctl-created `cov2-ios-3 Pre` `deleted: false`, left Shutdown; per-session records in JSON; exit 0 |
| IOS-016 | pass | IOS-016/ | after kill -9 of the keep-alive run: teardown --udid --force --json exit 0, `reclaimed: true`, WDA xcodebuild and `simctl diagnose` killed (runner had exited with its parent), `capacityRecordsKept` names session cov2-ios, `deviceHomesRemoved` the .11 home, `temporaryDirectoriesRemoved` both run temp dirs (leftover-tmp.txt empty); sessions dir empty |
| IOS-017 | pass | IOS-017/teardown-free.out | free UDID: exit 0, `reclaimed: false`, `processes: []`, nothing removed, `leaseReleased: false`; session record kept |
| IOS-018 | blocked | IOS-018/created-json.out | blocked: created.json lists devices outside cov2-ios-* (TienLen Flow deal-investigation, BLESwift E2E probe, fix-8-ios-26/27, fix2-13-ios-26/27); `simulator cleanup` not run per the row guard |
| IOS-019 | pass | IOS-019/ | delete exit 0 `Deleted cov2-ios-4 Pin (286E…)`; second exit 1 `Error: Invalid argument: Simulator not found: "cov2-ios-4 Pin"` |
| IOS-021 | pass | IOS-021/ | `✓ Build succeeded`, exit 0 |
| IOS-022 | pass | IOS-022/ | builds, installs, launches (`[grantiva] Done — com.kylebrowning.Landmarks running on cov2-ios-1`; launchctl lists the app) |
| IOS-023 | pass | IOS-023/ | JSON with status, scheme, bundleId, appPath, dataContainerPath, simulator.name/udid; launchctl shows no Landmarks process (not launched) |
| IOS-024 | pass | IOS-024/ | `--derived-data-path "$S/cov ios/Derived Data"` and relative `rel-dd`: both exit 0, Landmarks.app under each, JSON appPath points there |
| IOS-025 | pass | IOS-025/ | config build_settings [-derivedDataPath x, ONLY_ACTIVE_ARCH=YES] + `--derived-data-path y`: xcodebuild gets `ONLY_ACTIVE_ARCH=YES -derivedDataPath y`; `y/` has the app, no `x/` |
| IOS-026 | pass | IOS-026/ | exit 1; `✗ Build failed` with xcodebuild's `does not contain a scheme named "NoSuchScheme"` |
| IOS-027 | pass | IOS-027/ | no scheme configured, two schemes: exit 1 `Error: Invalid argument: No scheme specified. Pass --scheme or set it in grantiva.yml. Found: Landmarks, Landmarks (UI Testing).` |
| IOS-028 | pass | IOS-028/ | `--simulator cov2-ios-1` and `--simulator <UDID>` both pass `-destination platform=iOS Simulator,id=7E846901-…`; same device |
| IOS-123 | pass | IOS-123/ | `--bundle-id com.kylebrowning.Landmarks` accepted on build and install (launch uses it); control `--bundle-id com.kylebrowning.NotThis` refused: does not match the built app (flag is used) |
| IOS-124 | pass | IOS-124/ | README fixture script as written (scheme/UDID/bundle/flow substituted): install JSON parsed with `jq -r .dataContainerPath` (container exists); `run --no-build --flow … --simulator --bundle-id` 1/1 passed, exit 0 |
| IOS-029 | pass | IOS-029/commands.txt -> IOS-117/stock-26.out | all 12 configured flows run with per-step ✓ lines, exit 0 (the IOS-117 run); non-zero on a failed flow shown in IOS-069 |
| IOS-030 | pass | IOS-030/ | 01-12 each exit 0 (1/1 passed); 99-crash exit 1 |
| IOS-031 | pass | IOS-031/ | flows: [], no screens: exit 1 in 0.02 s `Error: No screens or flows configured in grantiva.yml`; no `out/`; ready `status: failed` with the error |
| IOS-032 | pass | IOS-032/run.out | stale x.ready deleted at startup (absent t=1..6 s); rewritten at the end with `status: passed`; run exit 0 |
| IOS-033 | pass | IOS-033/ | exit 1 in 0.02 s before build/boot: `--ready-file directory /nonexistent-cov/sub could not be created: … read only` |
| IOS-034 | pass | IOS-034/ | `$S/cov-missing/` created; x.ready `status: passed`; exit 0 |
| IOS-035 | pass | IOS-035/ | `--env 'LANDMARKS_NOTE=a=b c'` keep-alive run passed; hierarchy on Deep Links has `label="a=b c"` |
| IOS-036 | pass | IOS-036/ | `--env LANDMARKS_NOTE=hello`: StaticText `hello` at y=168 directly under the Deep Links title (y=119) |
| IOS-037 | pass | IOS-037/ | both --env values reach the app: 08-scroll passed (Landmark 70 asserted, ready passed) and hierarchy on Deep Links has StaticText `x` |
| IOS-038 | pass | IOS-038/ | `✓ assertVisible: text="No landmarks yet"`, 1/1 passed |
| IOS-039 | pass | IOS-039/ | exit 1; failure screenshot path printed; `(cause: app crashed …)`; ready `status: failed`, flow failed |
| IOS-040 | pass | IOS-040/ | app uninstalled first; `--app-file Landmarks.app` (no scheme needed): no build, `Installing com.kylebrowning.Landmarks...`, 1/1 passed |
| IOS-041 | pass | IOS-030/12-quote-label.* | flow 12 `tapOn: 'Mount "Denali"'` taps, `Alaska` asserted on the detail, exit 0 |
| IOS-042 | pass | IOS-042/ | app uninstalled first; `--app-file Landmarks.ipa`: extracted, installed, 1/1 passed, exit 0 |
| IOS-043 | pass | IOS-043/ | iphoneos build rejected before anything runs: `Error: Invalid app binary: Binary is built for [iPhoneOS], not iPhoneSimulator. Rebuild with -destination 'generic/platform=iOS Simulator'.`, exit 1 |
| IOS-044 | pass | IOS-044/ | installed: 1/1 passed; after `simctl uninstall`: exit 1 in 1.1 s before any flow, `Error: com.kylebrowning.Landmarks is not installed on cov2-ios-1. Drop --no-build or run grantiva build install.`; reinstalled |
| IOS-045 | pass | FLOWS-26/01-selectors.* | `✓ tapOn: text="Mountains → Yosemite Valley"`, label unmangled; `Yosemite Valley` asserted |
| IOS-075 | pass | FLOWS-26/10-lifecycle.* | `- stopApp` as the first step (app not running) ✓ (1.1 s) |
| IOS-077 | pass | FLOWS-26/10-lifecycle.*, FLOWS-26/10-lifecycle-report/maestro-runner.log | runner log `launchApp com.kylebrowning.Landmarks: argv=["--flag" "true"] env=map[]` (argv only; the round-1 environment leak is gone) |
| IOS-078 | pass | FLOWS-26/02-exact-negative.*, FLOWS-26/01-selectors.*, IOS-078/ | exact form fails (`Element not visible: text='Golden Gate.*', exact=true`, exit 1); regex `Golden Gate.*` passes; `assertVisible: "Golden Gate"` alone fails (whole-value match), closest texts listed |
| IOS-151 | pass | IOS-151/maps-nobuild.*, IOS-151/maestro-runner.log | from a dir without config (`--no-build`; without it the run refuses: no .xcodeproj, maps.err): Maps launched, `↳ accepted system alert "Allow “Maps” to use your location?" (Allow Once)` in the run output, flow passes; runner log `alert/accept body={"name":"Allow Once"}` |
| IOS-201 | pass | FLOWS-26/01-browse.* | `tapOn: "Golden Gate Bridge"` → `San Francisco, CA`, `Plan Visit` asserted |
| IOS-202 | pass | FLOWS-26/01-selectors.* | `tapOn: {text: "Lake Tahoe", exact: true}` and `{text: "Lakes"}` tap the matching element; `Sierra Nevada, CA` asserted |
| IOS-203 | pass | FLOWS-26/01-selectors.* | `assertVisible: id="clock"` and `tapOn: id="clock"` on Caching Demo pass (identifier, no element has text `clock`) |
| IOS-204 | pass | FLOWS-26/01-selectors.* | `tapOn: "Golden Gate.*"` taps; `assertVisible: ".*Lake.*"` passes; `assertNotVisible: "Lake"` passes (no whole-value match on Lake Tahoe) |
| IOS-205 | pass | FLOWS-26/01-selectors.* | regex assert ✓, `assertNotVisible: text="Golden Gate.*", exact=true` ✓ (exact honoured), exact tap opens Lake Tahoe; no `not supported` warning |
| IOS-206 | pass | FLOWS-26/02-exact-negative.* | `✗ assertVisible: text="Golden Gate.*", exact=true`, `Element not visible: text='Golden Gate.*', exact=true`; exit 1 |
| IOS-207 | pass | FLOWS-26/01-selectors.* | `tapOn: text="(Lake .*|.* Lake)", index=1` opened Mono Lake (`Lee Vining, CA` asserted) |
| IOS-208 | pass | FLOWS-26/04-point-taps.* | `tapOn: point="50%,50%"` → `Last tap: center`, `Taps: 1` |
| IOS-209 | pass | FLOWS-26/04-point-taps.* | `point="100%,100%"` ✓ (371 ms) and `0%,0%` ✓; no out-of-bounds error |
| IOS-210 | pass | FLOWS-26/03-gesture-lab-taps.* | `doubleTapOn: id="gesture-pad"` → `Double taps: 1`, `Taps` stays 1 (no single taps added) |
| IOS-211 | pass | FLOWS-26/03-gesture-lab-taps.* | `longPressOn` (1.4 s) → `Long presses: 1` |
| IOS-212 | pass | FLOWS-26/03-edit.*, FLOWS-26/03-edit-report/report.json | `inputText: " Renamed"` → `Golden Gate Bridge Renamed` visible; report.json has no `warning` |
| IOS-213 | pass | FLOWS-26/15-input-unicode.* | `inputText: " · Ünïcødé ✓"` → `San Francisco, CA · Ünïcødé ✓` visible, unmangled |
| IOS-214 | pass | FLOWS-26/01-browse.*, FLOWS-26/01-selectors.* | string, `{text:}`, regex and `{id:}` assertVisible all ✓ |
| IOS-215 | pass | FLOWS-26/05-category.* | `assertNotVisible: "Golden Gate Bridge"` on Lakes ✓ |
| IOS-216 | pass | FLOWS-26/05-swipe-forms.* | LEFT/RIGHT/UP/DOWN each followed by `Last swipe: left/right/up/down` |
| IOS-217 | pass | FLOWS-26/02-favorite.* | flow 02 passes: swipe LEFT from `Lake Tahoe`, `Remove` tapped, empty state asserted |
| IOS-218 | pass | FLOWS-26/05-swipe-forms.* | `swipe: UP from id="gesture-pad"` → `Last swipe: up` |
| IOS-219 | pass | FLOWS-26/07-swipe-from-missing.* | `✗ swipe: LEFT from text="No Such Row"`, `Element not found for swipe: text='No Such Row'`, exit 1 |
| IOS-220 | pass | FLOWS-26/05-swipe-forms.* | `swipe: start="80%, 50%" end="20%, 50%"` → `Last swipe: left` |
| IOS-221 | pass | FLOWS-26/06-swipe-absolute.* | outcome (a): `swipe: start="300, 600" end="60, 600"` read as points, `Last swipe: left` asserted |
| IOS-222 | pass | FLOWS-26/05-swipe-forms.* | `swipe: RIGHT` with duration 1500 took 1.9 s (others ~0.5 s) and registered `Last swipe: right` |
| IOS-223 | pass | FLOWS-26/10-seed-many.* | four bare `scroll` (each `scroll: DOWN`), `Landmark 30` visible |
| IOS-224 | pass | FLOWS-26/08-scroll.* | `scrollUntilVisible` Landmark 70 DOWN ✓ (8.4 s, slow) and Golden Gate Bridge UP ✓ (7.6 s, slow); both found |
| IOS-225 | pass | FLOWS-26/14-runflow.* | `runFlow: 14-runflow-sub.yaml` and `runFlow: {file: …}` each ran the sub-flow ✓ |
| IOS-226 | pass | FLOWS-26/14b-runflow-inline.* | `runFlow: {commands: [...]}` ✓ (Favorites empty state asserted inside) |
| IOS-227 | pass | FLOWS-26/11-slow.* | `extendedWaitUntil: visible text="Loaded after delay"` ✓ |
| IOS-228 | pass | FLOWS-26/09-waits.* | `extendedWaitUntil: notVisible text="Loading…"` ✓ (5.0 s), then `Loaded after delay` |
| IOS-229 | pass | FLOWS-26/09-waits.* | bare `waitForAnimationToEnd` ✓ (212 ms) and `{timeout: 2000}` ✓ (201 ms) |
| IOS-230 | pass | FLOWS-26/01-browse.* | bare `launchApp` ✓, Landmarks/Featured asserted |
| IOS-231 | pass | FLOWS-26/10-lifecycle.*, FLOWS-26/10-lifecycle-report/maestro-runner.log | Lake Tahoe favorited, then `launchApp (clearState)` → Favorites empty; runner log `clearState com.kylebrowning.Landmarks: uninstalled and reinstalled from …/Landmarks.app (0.3s)`; no --app-file |
| IOS-232 | pass | FLOWS-26/11-launch-environment.* | `from step` visible on Deep Links, `from header` not visible |
| IOS-233 | pass | FLOWS-26/10-lifecycle.* | `stopApp` before any launch ✓ and twice in a row ✓ (2 ms) |
| IOS-234 | pass | FLOWS-26/10-lifecycle.* | `killApp` then `launchApp` → `Featured` |
| IOS-235 | pass | FLOWS-26/07-deeplink.*, FLOWS-26/07-deeplink-report/files.txt | capture `07-deeplink-cmd-004-Deep Link Lakes.png` (space kept) |
| IOS-236 | pass | FLOWS-26/09-seed-empty.* | header `env: LANDMARKS_SEED: empty` reaches the app: `No landmarks yet` |
| IOS-237 | pass | FLOWS-26/16-setpermissions.* | `setPermissions` ✓ with the header appId; bare `scroll: DOWN` ✓ |
| IOS-238 | pass | FLOWS-26/10-lifecycle-report/maestro-runner.log | `argv=["--flag" "true"] env=map[]` |
| IOS-239 | pass | IOS-151/maps-nobuild.* | Maps location prompt auto-accepted (`↳ accepted system alert … (Allow Once)`); the optional tapOn shows `✓ … (8.3s, slow)`, no unexplained ⚠ |

## Counts

Matrix rows of the iOS slice (442): pass 92, fail 0, blocked 1, n/a 0 (total 93); not yet recorded: 349.

27.0 repeats: pass 0, fail 0, blocked 0, n/a 0 (total 0).

Other rows (handed-over / observation): pass 0, fail 0, blocked 0, n/a 0 (total 0).
