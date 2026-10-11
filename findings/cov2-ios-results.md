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
| IOS-020 | pass | IOS-020/ | cov2-ios-3 created+booted with simctl; run on it under GRANTIVA_SESSION_ID=cov2-ios-tmp2 exit 0; `sessions --json` during the run lists only cov2-ios-1/2 (no slot); `teardown --session-id cov2-ios-tmp2 --json` prints `[]`, device still Booted |
| IOS-121 | fail | IOS-121/teardown-locked.err, IOS-121/ | behaviour as expected: `teardown --udid` (no --force) removed the .11 device home (`deviceHomesRemoved`); with a locked file it exits 1 naming the home in `deviceHomeFailures`; `simulator delete` after a run removed the home. Fail on the message: `Error: … couldn’t be removed because you don’t have permission to access it.. Delete it by hand.` (doubled period: the underlying error's own full stop plus the CLI's) |
| IOS-122 | fail (matrix/brief error — triage) | IOS-122/run.err, IOS-122/run-unowned.out | row input is cov2-ios-1 (owned by session cov2-ios): with GRANTIVA_SESSION_ID unset the run is refused, exit 1, `Simulator cov2-ios-1 (…) belongs to Grantiva session cov2-ios. Run with GRANTIVA_SESSION_ID=cov2-ios, end that session with …, or select another simulator.` — exactly what README §Simulators Grantiva created now documents for a named session's device, so the row's expectation is outdated. The documented half holds: on a simctl-booted, unowned cov2-ios-3 a session-less run passes and takes no slot (sessions during/after list only cov2-ios-1/2) |
| IOS-155 | pass | IOS-155/ | `teardown --udid --force --json` plain/`--quiet`/`--verbose`: stdout byte-identical (598 B); plain and quiet stderr empty; verbose adds `[debug] <ISO time> com.grantiva.cli: $ …` and `exit 0: …` per subprocess; device deleted at the end |
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
| IOS-047 | pass | IOS-047/, IOS-056/ | keep-alive run: flow passes, ready `passed`, `GrantivaAgent keep-alive: port=8987 …`, `Press Ctrl-C to release.`; process still alive in later shells until killed (IOS-054) |
| IOS-048 | pass | IOS-048/ | plain `hierarchy`: iOS XML on stdout (48 elements); app pid 28143 identical before and after (no relaunch); /tmp/grantiva-sessions held only this slice's session |
| IOS-049 | pass | IOS-049/ | `--format json` parses (object with children, enabled, frame, label, name, type, visible) |
| IOS-050 | pass | IOS-050/ | `--json` parses and is identical to `--format json` |
| IOS-051 | pass | IOS-051/ | `--udid <cov2-ios-1>` prints that simulator's XML (detail screen, Plan Visit present) |
| IOS-052 | pass | IOS-052/ | sessions on cov2-ios-1 (01-browse, detail) and cov2-ios-2 (05-category, Lakes), no other session in /tmp/grantiva-sessions: plain `hierarchy` exit 0 returns the newer cov2-ios-2 tree (Mono Lake 2, Plan Visit 0) |
| IOS-053 | pass | IOS-053/ | `--udid <cov2-ios-1>` returns the older session's tree (Plan Visit 1, Mono Lake 0) |
| IOS-054 | pass | IOS-054/ | after kill -9 of the keep-alive run its runner exited too and /tmp/grantiva-sessions is empty; `hierarchy --udid` and plain `hierarchy` fail fast (0.02 s, exit 1): `No active runner session. Start one with …` (the orphaned WDA xcodebuild is reclaimed by teardown --force, cleanup below) |
| IOS-055 | pass | IOS-055/ | one line, exit 1: `Error: GrantivaAgent on port 8987 did not answer within 0.01s (--timeout). Is the run still alive?` |
| IOS-056 | pass | IOS-056/ | `hierarchy --udid` run the moment the ready file appeared: exit 0, iOS XML (XCUIElementTypeApplication Landmarks); no race |
| IOS-057 | pass | IOS-057/ | SIGINT on the cov2-ios-2 keep-alive: `received SIGINT — releasing simulator and reaping child processes`, gone in 1 s; runner, WDA xcodebuild and WDA app gone (only the frozen Landmarks app remains), its session/owner files removed (only cov2-ios-1's remain), no simctl diagnose; `BEE381AC….lock` present before, gone after (lease released, file deleted); sessions still lists the ensure-held slot (session cov2-ios) |
| IOS-058 | pass | IOS-058/ | kill -INT during the 45 s wait of 18-long-wait under --keep-alive: exit 130, `received SIGINT — releasing simulator and reaping child processes`, ready `status: interrupted`, flow `18-long-wait: interrupted` (none `running`); no runner/WDA left for the UDID; sessions dir empty |
| IOS-059 | pass | IOS-059/ | cov2-ios-1 (01) and cov2-ios-2 (05) concurrently: both exit 0, GrantivaAgent ports 8987/8819, per-UDID homes `versions/1.1.28-grantiva.11…/devices/<udid>` for each |
| IOS-060 | pass | IOS-060/ | fails in 0.96 s: `Simulator 7E84… is already owned by another Grantiva run (pid 27555, started 102s ago, grantiva-runner pid 27672, --keep-alive). Release it with `grantiva simulator teardown --udid … --force`, or …`, exit 1 |
| IOS-129 | pass | IOS-129/ | README `grantiva run --flow … --keep-alive --logs` held the session (`Press Ctrl-C to release.`) with 1043 `[log]` lines; `grantiva hierarchy > state.xml` exit 0, 12095-byte XML; SIGINT to the grantiva process released it (exit 130). Harness note: the script's own `kill -INT $P` hit a bash subshell, so the INT was sent by hand (commands.txt) |
| IOS-130 | pass | IOS-130/ | README ready-file loop ends; `jq -r .status` prints `passed`; kill -INT → exit 130 |
| IOS-131 | pass | IOS-131/, IOS-129/script.out | docs/dump-hierarchy.md :13 run --keep-alive, :16 `hierarchy > state.xml` (12095 B XML), :18 `hierarchy --format json > state.json` (44792 B, parses) all as written |
| IOS-061 | pass | IOS-061/ | default `--logs` on flow 08: 1560 `[log]` app lines, 0 `getpwuid_r`/"Filtering the log data" banners |
| IOS-062 | pass | IOS-062/ | `--logs-predicate` alone streams (implies --logs): `subsystem == "com.kylebrowning.Landmarks"` 0 lines (the app logs nothing under its subsystem), `process == "Landmarks" AND subsystem == "com.apple.xpc"` 45 lines, all matching |
| IOS-063 | pass | IOS-063/ | `--logs-level` debug 30299 ≥ info 4916 ≥ default 1574 lines |
| IOS-064 | pass | IOS-064/ | `log stream` for the UDID: 0 after a passing run, 0 after the failing 99-crash run, 1 during a keep-alive and 0 after SIGINT (exit 130) |
| IOS-065 | pass | IOS-065/ | `--snapshot failure` on 02-exact-negative: only the failing step's `assets/flow-000/cmd-002-after.png` plus `captures/failure-*.png` (and its allure copy) |
| IOS-066 | pass | IOS-066/ | `--snapshot trailing`: last-good `cmd-001-after` plus the failing step's `cmd-002-before/after` (assets and captures/trace), failure shot; no shots for cmd-000 (round-1 defect gone) |
| IOS-067 | pass | IOS-067/ | `--snapshot full`: before/after for every step cmd-000..007 (assets and captures/trace); stdout lists only the two takeScreenshot captures and `Flows: 1 total, 1 passed` (trace shots no longer reported as screens) |
| IOS-068 | pass | IOS-068/ | `--continue-on-failure` with 99-crash first: 99-crash ✗, 01-browse ✓, 05-category ✓ (TOTAL 2/3), exit 1 |
| IOS-069 | pass | IOS-069/ | no flag: suite stops after 99-crash (01/05 `SKIP`, TOTAL 0/3), exit 1 |
| IOS-070 | pass | IOS-070/ | relative `--report-dir out`: out/report.json, junit, flows/, assets/flow-000 PNGs, captures/; no ./.grantiva/captures created; no /var/folders path in out/ |
| IOS-071 | pass | IOS-071/ | failing flow with `--report-dir out071`: no /var/folders path anywhere; `sourceFile` and junit `<property name="file">` are `.maestro/coverage/02-exact-negative.yaml` as passed |
| IOS-072 | pass | IOS-072/ | qa/a/same.yaml and qa/b/same.yaml each run once: `[1/2] qa/a/same`, `[2/2] qa/b/same`, TOTAL 2/2, exit 0 |
| IOS-073 | pass | IOS-073/ | killed at ~30 s (32.1 s), exit 1, ready `failed` with flow `failed`; `Error: grantiva killed the runner after 30s (--timeout <seconds> to raise the cap). The runner's last output above shows how far it got.` plus `18-long-wait: extendedWaitUntil …: grantiva stopped the run at the --timeout cap (30s)` (no stray colon); report.json now `status: failed`, `running: 0` (round-1 defect gone) |
| IOS-074 | pass | IOS-074/ | stdout only JSON; failing: `allPassed: false`, failed step with `message`, `error` naming the step and message, `reportDir`; exit 1; passing: valid JSON `allPassed: true`, exit 0; stderr: only the 2-line Error under --json on failure, nothing on success (round-1 narration leak gone) |
| IOS-075 | pass | FLOWS-26/10-lifecycle.* | `- stopApp` as the first step (app not running) ✓ (1.1 s) |
| IOS-077 | pass | FLOWS-26/10-lifecycle.*, FLOWS-26/10-lifecycle-report/maestro-runner.log | runner log `launchApp com.kylebrowning.Landmarks: argv=["--flag" "true"] env=map[]` (argv only; the round-1 environment leak is gone) |
| IOS-078 | pass | FLOWS-26/02-exact-negative.*, FLOWS-26/01-selectors.*, IOS-078/ | exact form fails (`Element not visible: text='Golden Gate.*', exact=true`, exit 1); regex `Golden Gate.*` passes; `assertVisible: "Golden Gate"` alone fails (whole-value match), closest texts listed |
| IOS-132 | pass | IOS-132/ | screens-only config with `--snapshot full --report-dir out`: before/after shot per screens step in out/assets/flow-000 (99 PNGs outside allure), 5 screens captured, exit 0 |
| IOS-133 | pass | IOS-133/ | screens+flows with `--report-dir out`: flows report at out/ (report.json, junit, flows/, assets/), screens report under out/screens/ (its own report.json, junit, assets); exit 0 |
| IOS-134 | pass | IOS-134/ | `--continue-on-failure`: screen `Broken ✗ Tap on "No Such Element"` with the reason, `Screens: 2 total, 1 captured, 1 failed`, 01-browse still runs and passes, exit 1; without it the run stops after the screens session (01-browse never runs) with `Error: … Screen "Broken" failed at tapOn …`; skipped steps shown as `- … (skipped)` (round-1 naming defects gone). Note: the --continue-on-failure run prints no `Error:` line, only the summaries |
| IOS-135 | pass | IOS-135/ | screens-only run with a 45 s wait and `--timeout 30`: killed at ~30 s (32.1 s), exit 1, ready `failed`, `Error: grantiva killed the screens session after 30s (--timeout <seconds> to raise the cap). It was at screen "Slow".`; report.json `status: failed`, `running: 0` |
| IOS-152 | pass | IOS-152/ | `run --json` plain/`--quiet`/`--verbose`: stdout identical apart from the per-step measured `duration` values (equal after normalising them; three separate runs cannot match byte for byte); json plain/quiet stderr empty, verbose 82 lines incl. the grantiva-runner launch and `log stream`-free subprocess lines with exit status; without --json `--quiet` drops all 65 stderr narration lines, stdout unchanged (16 lines); the failing `--quiet` run still prints its 2-line `Error:` naming the step (stdout empty, as in the plain failing run) |
| IOS-079 | pass | IOS-079/ | `.grantiva/recordings/recording.mov` (QuickTime) written, exit 0; stdout `Recording: …` plus `Frame report: …/recording.json` |
| IOS-080 | pass | IOS-080/ | `--output "…/cov rec/a.mov"` (space in dir, dir created) written there, a.json beside it |
| IOS-081 | pass | IOS-081/ | `--frames-at 0,150,300,2900`: four PNGs under recording-frames/ (all `-> 0ms` on the idle app: variable frame rate, see IOS-136) |
| IOS-082 | pass | IOS-082/ | rejected up front as a usage error, exit 64: `Error: --frames-at 5000 is past --duration 2 (2000 ms).`; no recording made (recording.mov unchanged); round-1 defect gone |
| IOS-083 | pass | IOS-083/ | valid JSON with `video`, `frames[{requestedMilliseconds, actualMilliseconds, path}]`, `simulator`, `udid`, `requestedDurationSeconds`; `video` and frame paths now both relative |
| IOS-136 | pass | IOS-136/ | recording while flow 10 scrolls: requested 500/1500 → actual 492/1500 ms (not 0); flow and record both exit 0 |
| IOS-137 | pass | IOS-137/ | `record … 2>/dev/null`: stdout starts with `Recording:`, then `Frame report:`; no recorder noise |
| IOS-154 | pass | IOS-154/ | `record --duration 2 --json` plain/`--quiet`/`--verbose`: stdout byte-identical; plain/quiet stderr empty; verbose 18 `[debug]` lines incl. `simctl io … recordVideo` with its exit status |
| IOS-084 | pass | IOS-084/ | `runner start --detach`: stdout `Runner started (detached)`, WDA port 8987, PID, `Log: /var/folders/…/grantiva-runner-….log`, `Session: .grantiva/session.json`; session.json written; cov2-ios-1 capacity record kept |
| IOS-085 | pass | IOS-085/ | with `runner start` live: `--format tree`, `json`, `xml`, `-f json`, `-p 8987` and `--json` all print, exit 0 |
| IOS-087 | pass | IOS-087/ | `runner stop`: `Runner stopped (pid 81569)`, runner gone (after-procs.out; the `runners=2` in after.out counts the grep pipeline itself), both session files and .grantiva/session.json removed, `<udid>.lock` removed (lease released); ensure slot kept |
| IOS-088 | pass | IOS-088/ | stale .grantiva/session.json naming dead pid 99999: `runner start --detach --json` starts cleanly (`status: started`), session.json rewritten with the new pid; stopped after |
| IOS-089 | pass | IOS-089/ | `run` on the `runner start` simulator fails fast (1.7 s, exit 1): `… is held by a `grantiva runner start` session (grantiva-runner pid 81569, …). Stop it with `grantiva runner stop` (from <dir>) …`; session.json unchanged, dump-hierarchy still answers |
| IOS-138 | fail | IOS-138/ | both print JSON, numbers are numbers now (round-1 defect gone); start: status, pid, port, platform, bundleId (+ deprecated bundle_id), udid, log. But README (`runner start --json` and `runner stop --json` share one shape: status, pid and port, platform, bundleId and udid) does not match stop: it has no `port` and no `bundleId`, and carries an undocumented top-level `"killed": false` while reporting `status: stopped` (the runner was stopped) |
| IOS-139 | pass | IOS-139/ | foreground `runner start` (no --detach) prints `Runner started … Press Ctrl-C (or run 'grantiva runner stop') to stop the session.` and holds until SIGINT at 30 s (timeout -s INT); then `received SIGINT — releasing simulator and reaping child processes`: session files and .grantiva/session.json removed, no runner left (round-1 'exits after 3.8 s' defect gone) |
| IOS-140 | pass | IOS-140/ | docs/dump-hierarchy.md:46-48 as written: `runner start` (holds in the foreground, run as terminal 1), `runner dump-hierarchy --format json` (JSON tree, exit 0), `runner stop` (`Runner stopped`, exit 0); start then exits 0 (`the session has ended`) |
| IOS-090 | pass | IOS-090/ | config `simulator: cov2-ios-1`, cov2-ios-2 booted with the app: `Simulator: cov2-ios-1 (7E84…)`, captures `Deep Links.png` etc. (plain names); cov2-ios-2 app pid 34822 unchanged, no WDA on it |
| IOS-091 | pass | IOS-091/ | no baselines: `? No baselines: 5 new screens. Run: grantiva diff approve`, each screen `New screen — no baseline`, `New: 5`, exit 1 (no longer a pass) |
| IOS-092 | pass | IOS-092/ | `diff approve` → `Approved 5 screens as baseline`, the 5 PNGs in .grantiva/baselines/ (fresh project copy, captures dir held only the 5 screens) |
| IOS-093 | pass | IOS-093/ | unchanged UI: `Passed: 5`, each `pixel=0.00% perceptual=0.0`, exit 0 |
| IOS-094 | pass | IOS-094/ | Caching clock change (recaptured 61 s later): defaults fail (`pixel=0.05% perceptual=67.6`); `threshold: 1.0` alone still fails on perceptual; `threshold: 1.0` + `perceptual_threshold: 80.0` passes (6/6) |
| IOS-095 | pass | IOS-094/compare-*.out | perceptual distance 67.6 fails at `perceptual_threshold: 5.0` and passes at 80.0; the failure line now names the check and limit: `Failed: perceptual=67.6 exceeds perceptual_threshold 5.0 (pixel=0.05%, threshold 2.00%)` |
| IOS-096 | pass | IOS-096/ | `--json`: `passed`, `duration`, `screens[]` with pixelDiffPercent, perceptualDistance, both thresholds, baseline/capture paths, message (camelCase plus the documented snake_case duplicates) |
| IOS-097 | pass | IOS-097/ | `diff compare --capture`: `Building Landmarks (UI Testing)...`, captures 5 screens, then compares (`Passed: 5`), exit 0 |
| IOS-098 | pass | IOS-098/ | `diff approve Home` → `Approved 1 screen as baseline • Home`; only Home.png's mtime changed |
| IOS-141 | fail | IOS-141/capture.out, capture.err | every screens step executes (tap/assert with and without exact, run_flow, wait 3, type, swipes in four letter cases), 6 screens captured, exit 0 (round-1 `evalScript` label gone: live line `✓ Wait 3s (3.0s)`). Fail on the stdout summary: it drops the `exact` qualifier, so the Lakes Exact screen reads `✓ Assert visible "Golden Gate.*"` followed by `✓ Assert not visible "Golden Gate.*"` and `✓ Tap on "Lakes"`/`✓ Assert visible "Mono Lake"` (stderr shows `exact=true`); the wait is `Wait 3.0s` there vs `Wait 3s` live |
| IOS-142 | pass | IOS-142/ | Maestro-format grantiva.yml: one capture per takeScreenshot (`Home Swiped`, `Caching Maestro`), exit 0; each step carried as written (`extendedWaitUntil: visible text="Cache Policy"` staged as such, summary `Wait until visible "Cache Policy" (5000ms max)`; round-1 assertVisible staging gone) |
| IOS-143 | pass | IOS-143/ | in the session's directory ($APP, config simulator: line removed, restored after) `diff capture --no-build` resolves cov2-ios-1 from the live runner start session and captures 5/5 through it, exit 0 (round-1 'already owned' refusal gone). From another project dir (p143) the session is not considered (`3 simulators are booted … Pass --simulator`): runner sessions are per project directory (.grantiva/session.json) |
| IOS-144 | pass | IOS-144/ | no simulator configured, no session, 3 booted (cov2-ios-1, cov2-ios-2, the user's iPhone 17 Pro, already booted): fails at once (0.3 s), exit 1, `3 simulators are booted: … Pass --simulator <name|UDID> or set simulator: in grantiva.yml.`; none commanded (no WDA on cov2-ios-2) |
| IOS-145 | fail (matrix/brief error — triage) | IOS-145/ | README §Local Workflow as written in a fresh copy: `diff capture` builds and captures 5 (exit 0), `diff approve` exit 0, a second compare passes 5/5; the first `diff compare` exits 1 with `? No baselines: 5 new screens. Run: grantiva diff approve` — which the current README states (compare exits 1 when a screen has no baseline), so the row's 'all three succeed' is outdated for that step |
| IOS-146 | pass | IOS-146/ | capture ok (Home) + approve, then a failing capture (Broken, exit 1), then `diff compare`: exit 1, `Error: No captures found in .grantiva/captures. Run: grantiva diff capture` (stale captures cleared; no screen reported passed) |
| IOS-156 | pass | IOS-156/ | `diff capture --app-file …/Landmarks.app --simulator <cov2-ios-1>`: `Using pre-built binary: Landmarks.app` (no build), 5 screens captured on cov2-ios-1, exit 0 |
| IOS-157 | pass | IOS-157/ | `diff compare --capture --scheme … --simulator … --bundle-id … --derived-data-path dd157`: xcodebuild runs that scheme on cov2-ios-1 with `-derivedDataPath …/dd157` (app lands there), then compares (Passed: 5), exit 0 |
| IOS-158 | pass | IOS-158/ | `--capture --app-file Landmarks.app`: pre-built binary, no build, Passed: 5; `--capture --no-build`: no build/install, Passed: 5; both exit 0 |
| IOS-153 | pass | IOS-153/ | `diff capture --no-build --json` plain/`--quiet`/`--verbose`: stdout the JSON in all three, equal apart from measured duration/size values (three captures cannot match byte for byte); plain and quiet stderr empty (round-1 narration leak gone); verbose 106 `[debug]` lines incl. the grantiva-runner launch with exit status |
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
| CLI-048 | pass | CLI-048/ | relative `run_flow: "sub/flow.yaml"` resolves beside grantiva.yml (cfg/sub/flow.yaml), 1 screen captured, exit 0; missing `sub/missing.yaml` fails before any step, exit 1, `- sub/missing.yaml: parse error: failed to read file: open sub/missing.yaml: no such file or directory`; `run --flow m.yaml` with `runFlow: nothere.yaml` likewise names the path |
| CLI-049 | fail | CLI-049/ | cycle A→B→A detected in 1.4 s, no hang, exit 1, and the screens form now starts at grantiva.yml (round-1 temp-file path gone); but the chain mixes spellings: `grantiva.yml -> a.yaml -> /tmp/claude-501/…/CLI-049/b.yaml -> a.yaml` (one hop absolute via /tmp, the others relative); `run --flow a.yaml` likewise `a.yaml -> b.yaml -> /tmp/…/a.yaml -> b.yaml` |
| CLI-061 | pass | CLI-061/ | Maestro-format `tapOn: "Mount \"Denali\" 🏔️"` parses; the staged step is `tapOn: text="Mount "Denali" 🏔️"` byte for byte (bytes.out: …f0 9f 8f 94 ef b8 8f); the tap then fails only because the app has no such label |
| CLI-064 | pass | CLI-064/ | `tapOn: {text: Favorites}` staged as `tapOn: text="Favorites"` (taps), `tapOn: {id: favoritesTab}` as `tapOn: id="favoritesTab"` (fails only because the app has no such identifier: `Element not found: id='favoritesTab'`) |
| CLI-066 | pass | CLI-066/ | `- scroll` → `swipe: UP` (finger up, content down); `scroll: {direction: up}` → `swipe: DOWN`; run exit 0 |

## Counts

Matrix rows of the iOS slice (442): pass 162, fail 5, blocked 1, n/a 0 (total 168); not yet recorded: 274.

27.0 repeats: pass 0, fail 0, blocked 0, n/a 0 (total 0).

Other rows (handed-over / observation): pass 4, fail 1, blocked 0, n/a 0 (total 5).
