# iOS slice findings: Grantiva CLI 2.0.1 (`~/.grantiva-qa/bin/grantiva`)

Host: Xcode 27.0 (27A266a); simulators `qa-ios-1`/`qa-ios-2` (iPhone 17, iOS 26.0), plus throwaway `QA *` devices.
App: landmarks-demo/ios, scheme `Landmarks (UI Testing)`, bundle `com.kylebrowning.Landmarks`. Every run used a copy
of the app at `/private/tmp/qa-ios/app`, so that `.grantiva/` writes and config variants stayed out of the shared repo.
`GRANTIVA_SESSION_ID=qa-ios`. All evidence paths below are relative to `findings/evidence/`.

The six defects seen during the gate are verified again here as IOS-F01, F02, F03, F04, F05 and F06.

---

### IOS-F01: Flow-header `env:` is never delivered to the app
Matrix IDs: IOS-030 (flows 09, 10, 99)
Severity: contract
Command: `grantiva run --no-build --flow .maestro/09-seed-empty.yaml --simulator qa-ios-1`
Expected: Grantiva claims Maestro flows run as a drop-in ("auto-detect and parse them — no rewrite needed"), so a flow that declares `env: LANDMARKS_SEED: empty` should run with that environment (source: README §Maestro Compatibility). The landmarks flow contract depends on it (flows/README.md).
Actual: The app starts with the default seed. `assertVisible "No landmarks yet"` fails, and the closest on-screen texts are "Landmarks", "All Landmarks". 99-crash fails on its last assert rather than by crashing. The same flow passes with `--env LANDMARKS_SEED=empty` (IOS-038).
Repro: landmarks-demo/ios, default seed, run flow 09 with no `--env`.
Evidence: IOS-030/09-seed-empty.err, IOS-030/99-crash.err, IOS-038/out.txt
Suspected cause: Sources/GrantivaCore/Runner/FlowEnvironment.swift. `inject` only rewrites `launchApp` steps with `--env` values, and the flow header `env:` block is never read. In real Maestro, header `env:` defines `${VAR}` variables, not launch environment. Either the README compatibility claim or the flow semantics needs a sentence.

### IOS-F02: `swipe` with `from:` ignores the element and swipes across the screen centre
Matrix IDs: IOS-030 (flow 02), IOS-029
Severity: wrong-result
Command: `grantiva run --no-build --flow .maestro/02-favorite.yaml --simulator qa-ios-1`
Expected: `swipe: {direction: LEFT, from: "Lake Tahoe"}` swipes on the Lake Tahoe row and reveals `Remove` (source: README §Maestro Compatibility).
Actual: The runner logs `dragfromtoforduration {"fromX":361.8,"fromY":437,"toX":40.2,"toY":437}`. y=437 is the vertical centre of the 874-pt screen. The row is near y≈210, so `tapOn "Remove"` fails.
Repro: Seed default. Run flow 02.
Evidence: IOS-029/rep/maestro-runner.log (line 240), IOS-030/02-favorite.err
Suspected cause: The bundled grantiva-runner (1.1.18-grantiva.7) drops `from`. Grantiva stages the flow unchanged.

### IOS-F03: A bare `scroll` step fails
Matrix IDs: IOS-030 (flow 10)
Severity: wrong-result
Command: `grantiva run --no-build --flow .maestro/10-seed-many.yaml --simulator qa-ios-1`
Expected: A bare `- scroll` scrolls down, as in Maestro (source: README §Maestro Compatibility). Grantiva's own `.maestro` parser also maps `scroll` to a swipe up (MaestroFlowParser.swift:237).
Actual: `✗ scroll (0ms) ╰─ Invalid scroll direction (cause: invalid direction: )`. The gate also saw `Failed to get screen size`.
Repro: Run flow 10 (with or without `--env LANDMARKS_SEED=many`).
Evidence: IOS-030/10-seed-many.err
Suspected cause: The bundled runner needs a `direction` and has no default.

### IOS-F04: `simulator ensure --name qa-ios-1` fails, although the help says `--name` alone is enough
Matrix IDs: IOS-007, IOS-001
Severity: docs
Command: `grantiva simulator ensure --name qa-ios-1 --runtime 26.0`
Expected: help: simulator ensure ("`--name` alone is enough") and README ("`ensure` needs only `--name`").
Actual: `Error: Invalid argument: Could not infer a device type from the name "qa-ios-1" …`, exit 1, and stdout is empty, so `udid=$(…)` captures nothing and the next command fails with `Simulator not found: ""`. Rejecting the name matches CHANGELOG 1.6.0 (so IOS-007 passes). The problem is that the help and README overstate what `--name` alone does: it only works when the name contains a model.
Repro: As above. Works with `--device-type "iPhone 17"`.
Evidence: IOS-007/err.txt, IOS-007/err2.txt

### IOS-F05: A missing resource bundle crashes `run` (exit 133) instead of reporting `runnerNotFound`
Matrix IDs: (gate; no matrix row)
Severity: crash
Command: any `grantiva run` that needs to (re)extract the runner while `grantiva_GrantivaCore.bundle` is not beside the binary
Expected: A clean error. The code tries to throw `GrantivaError.runnerNotFound` when the tarball URL is nil (RunnerManager.extractEmbedded).
Actual: The gate session saw `GrantivaCore/resource_bundle_accessor.swift:44: Fatal error: unable to find bundle named grantiva_GrantivaCore` with exit 133 on every `run`, while `--version` still worked. `~/.grantiva-qa/bin/grantiva_GrantivaCore.bundle` now has mtime 13:57 (recreated after the gate), and `~/.grantiva/runner/version` was rewritten at 13:55.
Repro: I could not reproduce this safely. Reproducing needs `~/.grantiva/runner/version` to mismatch, and that directory is shared with other agents and with the Homebrew 2.0.0 install. `HOME=` is ignored (`homeDirectoryForCurrentUser`). A lone copy of the binary works as long as the installed runner's stamp matches (IOS-F-bundle/).
Evidence: ios-gate.md "Environment breakage", IOS-F-bundle/
Suspected cause: Sources/GrantivaCore/Runner/RunnerManager.swift:31,35. `Bundle.module` is SwiftPM's accessor, and it calls `fatalError` when the bundle is missing, so the `guard … else throw runnerNotFound` never runs. Separately, every grantiva version on the host shares `~/.grantiva/runner` and its single `version` stamp (installStamp). Running two versions alternately (here Homebrew 2.0.0, which the MCP server also shells out to, see IOS-F33) makes each one re-extract. That forces a bundle access on the next run.

### IOS-F06: Flow 04 flakes because the runner auto-accepts the app's own alert
Matrix IDs: IOS-030 (flow 04)
Severity: wrong-result
Command: `grantiva run --no-build --flow .maestro/04-discard.yaml --simulator qa-ios-1` (repeated 6 times)
Expected: The SwiftUI "unsaved changes" alert stays up until the flow taps `Keep Editing` (source: README §Maestro Compatibility, Maestro alert semantics).
Actual: 2 of 6 runs passed. Failures show `⚠ assertVisible "You have unsaved changes…"` and then `✗ tapOn "Keep Editing"`, or `✗ assertVisible "Edit Landmark"`. The screen behind is gone, which is what pressing Discard does.
Repro: Seed default. Run flow 04 several times.
Evidence: IOS-F-04flaky/summary.txt, IOS-F-04flaky/run2..5.err, IOS-F-04flaky/run3/maestro-runner.log (lines 23, 29)
Suspected cause: The runner creates the WDA session with `"defaultAlertAction":"accept"` and `acceptAlertButtonSelector` = `label BEGINSWITH 'Allow' OR label == 'OK'`. With no match, WDA's accept falls back to the alert's default button. That auto-accepts app alerts, not only permission prompts, during the slow element lookups.

### IOS-F07: `simulator ensure --json` on reuse reports the wrong runtime (and an inferred device type)
Matrix IDs: IOS-006
Severity: wrong-result
Command: `grantiva simulator ensure --name "QA iPhone 17 Pro" --json` (device created earlier with `--runtime 26.0`)
Expected: The JSON record describes the device (source: README §stdout is the result, "`--json` emits the full record").
Actual: `"runtime" : "iOS 27.0"`, but simctl lists the device under iOS 26.0. With `--runtime 26.0` it reports 26.0.
Repro: `ensure --name "QA iPhone 17 Pro" --runtime 26.0`, then `ensure --name "QA iPhone 17 Pro" --json`.
Evidence: IOS-006/out.json, IOS-006/out-rt26.json, IOS-006/simctl-runtime.txt
Suspected cause: Sources/GrantivaCore/Simulator/SimulatorManager.swift:149. The result uses the requested or newest `runtime.name` and the inferred `type.name`, not `existing.runtime` or `existing.deviceTypeIdentifier`, when reusing a device.

### IOS-F08: `ensure` cannot reuse an existing simulator whose name has no model
Matrix IDs: IOS-002
Severity: contract
Command: `grantiva simulator ensure --name "QA Pin"` (device "QA Pin" exists, created with `--device-type "iPhone 17 Pro"`)
Expected: "reuses an existing simulator with that name". The code comment calls bare-name reuse "purely idempotent" (source: README §stdout; CHANGELOG 1.6.0 "Named provisioning is idempotent").
Actual: `Error: Could not infer a device type from the name "QA Pin"`, exit 1. Inference runs before the lookup, so every later bare call needs `--device-type` again.
Repro: Create with `--device-type`, then re-ensure by name only.
Evidence: IOS-002/reuse-qapin.err
Suspected cause: SimulatorManager.swift:99-109. Device-type inference throws before the existing-device lookup at line 133.

### IOS-F09: A run on a manually booted simulator takes a capacity slot, and session teardown then shuts that simulator down
Matrix IDs: IOS-020
Severity: contract
Command: `xcrun simctl boot <udid>`; `GRANTIVA_SESSION_ID=qa-ios-manual grantiva run --app-file … --simulator <udid>`; `grantiva simulator teardown --session-id qa-ios-manual --json`
Expected: "Only simulators Grantiva boots count toward the limit; manually booted Xcode simulators are never shut down by Grantiva teardown" (source: README §stdout/capacity; SIMULATOR-LIFECYCLE.md "only shuts down pre-existing devices the session merely booted").
Actual: After the run, `simulator sessions` lists the manual device as a Grantiva session (3/4 → 4/4). Teardown returns `deleted:false` and the device is **Shutdown**.
Repro: As above, with a simctl-created iPhone 17 / iOS 26.0.
Evidence: IOS-020/sessions-before.txt, sessions-after-run.txt, teardown.json, state-after-teardown.txt
Suspected cause: Sources/GrantivaCore/Simulator/SimulatorManager.swift:46-58. `boot()` reserves and activates a capacity record even when `device.isBooted` is already true. Teardown shuts down any booted device that has a record.

### IOS-F10: Records from runs without a session ID never expire; the user's iPhone 17 Pro is shown as Grantiva-managed and holds a slot
Matrix IDs: IOS-010, IOS-011
Severity: contract
Command: `grantiva simulator sessions --json`
Expected: Capacity counts simulators Grantiva booted for live work (source: README capacity paragraph). The pre-existing, user-owned `iPhone 17 Pro` should not be listed (task brief).
Actual: `iPhone 17 Pro (B27D7D31…) — simulator:B27D7D31… [active]`, `ownerPID 93503` (dead), `acquiredAt` about 40 h before this session. It took one of the four slots all session, so `qa-ios-1` waited at 4/4 (IOS-011 log names it as an occupant). Only `teardown --session-id simulator:B27D7D31…` would clear it, and that would also shut the user's device down (IOS-F09).
Repro: Run any `grantiva run`/`build install` against an already-booted device without `GRANTIVA_SESSION_ID`, then exit.
Evidence: IOS-010/sessions.json, IOS-011/wait-stderr.txt
Suspected cause: SimulatorCapacity.swift:62 (`owner = sessionId ?? "simulator:<udid>"`). Records persist by design, and `prune` keeps any record whose device is still booted, whether or not the owner pid is alive.

### IOS-F11: With no scheme configured, the build silently picks the project's first scheme
Matrix IDs: IOS-027
Severity: contract
Command: `grantiva build build --simulator qa-ios-1` in a copy of the app whose grantiva.yml has no `scheme:`
Expected: "No scheme specified. Pass --scheme, set it in grantiva.yml, or use --app-file …" (source: README §Pre-built binaries; BuildCommand.swift:42).
Actual: `✓ Build succeeded  Scheme: Landmarks`, exit 0. The project has two schemes and the non-UI-testing one was chosen without notice. The choice is cached in `.grantiva/config.json`, so it persists after the config is fixed only if the flag or config is set again.
Repro: Delete `scheme:` from grantiva.yml and build.
Evidence: IOS-027/out.txt, IOS-027/err.txt
Suspected cause: ProjectResolver.swift:97 and ProjectDetector.swift:86 (`schemes.first`). The documented error only fires when detection itself fails.

### IOS-F12: Without grantiva.yml, any `.maestro/` file using `swipe` blocks every `run`, including `--flow` of another file
Matrix IDs: IOS-040 (setup)
Severity: wrong-result
Command: `grantiva run --app-file Landmarks.app --flow .maestro/01-browse.yaml --simulator qa-ios-1` in a directory with only `.maestro/`
Expected: Maestro flows are auto-detected "no rewrite needed" (source: README §Maestro Compatibility). `--flow` runs only that file (help: run).
Actual: `Error: Invalid argument: Unsupported Maestro command 'swipe' at …/.maestro/02-favorite.yaml:11`, exit 1, before anything runs. The same `swipe` is accepted when the flow is passed through grantiva.yml.
Repro: A directory holding the landmarks `.maestro/` and nothing else.
Evidence: IOS-F-maestrodir/noconf-run.err
Suspected cause: GrantivaConfig.loadIfPresent → MaestroFlowParser.loadDirectory parses every file into screens and throws on a `swipe` with `direction` (MaestroFlowParser.swift:291-308 only accepts `start`/`end`), even when `--flow` was given.

### IOS-F13: A capacity timeout leaves a created device behind; many errors end in a stray "exited with code 1"
Matrix IDs: IOS-013, IOS-029, IOS-060, IOS-073, IOS-082
Severity: ux
Command: `GRANTIVA_MAX_SIMULATORS=3 GRANTIVA_SIMULATOR_WAIT_TIMEOUT_SECONDS=5 grantiva simulator ensure --name qa-ios-2 --device-type "iPhone 17" --runtime 26.0`
Expected: Times out cleanly (it does, after 7 s, exit 1).
Actual: (1) `qa-ios-2` was created (Shutdown) before the wait and is left behind. (2) The message ends `…--session-id <id>`. exited with code 1`. The same suffix follows run failures (`Error: Runner failed (exit 1):\n exited with code 1`), the ownership error, and the record error (`…requested frame 5000ms exited with code 1`).
Evidence: IOS-012/err.txt, IOS-029/err.txt (tail), IOS-060/err.txt, IOS-082/err.txt
Suspected cause: GrantivaError.commandFailed description appends " exited with code N" to every message.

### IOS-F14: `hierarchy --json` prints XML
Matrix IDs: IOS-050
Severity: docs
Command: `grantiva hierarchy --udid <udid> --json`
Expected: help: hierarchy "--json Output as JSON".
Actual: XML on stdout, exit 0. Only `--format json` gives JSON. Confirms CLI-DOCS-F12 on a device.
Evidence: IOS-050/out.txt

### IOS-F15: The `hierarchy --timeout` error is a raw NSError dump
Matrix IDs: IOS-055
Severity: ux
Command: `grantiva hierarchy --udid <udid> --timeout 0.01`
Expected: Gives up "with a clear error" (help: hierarchy `--timeout`).
Actual: `Error: Error Domain=NSURLErrorDomain Code=-1001 "The request timed out." UserInfo={_kCFStreamErrorCodeKey=-2102, NSUnderlyingError=…}`, about 10 lines of Foundation internals. The timeout itself works (0.08 s; `--timeout 1` with an idle agent succeeds in 1.05 s).
Evidence: IOS-055/t001.err

### IOS-F16: Interrupting a run mid-flow writes `failed` to the ready file, not `interrupted`
Matrix IDs: IOS-058
Severity: contract
Command: `grantiva run --no-build --flow .maestro/11-slow.yaml --simulator qa-ios-2 --keep-alive --ready-file r &` then `kill -INT $!` while the flow is on Slow Screen
Expected: `jq -r .status r` → `passed | failed | interrupted` (source: README §Agent-Native Features, `--ready-file`). RunnerExecution.swift:86 writes `interrupted` on termination.
Actual: `{"status":"failed","flows":[{"name":"11-slow","status":"running"}]}`. Cleanup itself is correct: no runner/WDA/xcodebuild for that UDID survives, and the session and owner files are removed (IOS-057/058 pass on those points).
Evidence: IOS-058/r058.ready, IOS-058/err.txt
Suspected cause: The runner exits on the forwarded SIGINT, and the normal completion path writes `failed` before the termination cleanup runs, so the write-once ready file never gets `interrupted`.

### IOS-F17: The ready file and `report.json` point at a temp directory that has already been deleted
Matrix IDs: IOS-032, IOS-034
Severity: ux
Command: `grantiva run --no-build --flow .maestro/01-browse.yaml --simulator qa-ios-2 --ready-file /tmp/qa-missing-dir/x.ready`
Expected: The verdict file can be used to find the run's report (README §Agent-Native Features).
Actual: `"reportDir" : "/var/folders/…/grantiva-report-1308CED9-…"`. When the waiter reads it, that directory no longer exists (`ls` → No such file or directory).
Evidence: IOS-034/x.ready, IOS-032/x.ready

### IOS-F18: Screen names with spaces are percent-encoded in file names
Matrix IDs: IOS-090, IOS-092, IOS-029
Severity: ux
Command: `grantiva diff capture --no-build --simulator qa-ios-1 --json`
Expected: Captures and baselines named after the screen ("Deep Links") (source: README §Local Workflow).
Actual: `.grantiva/captures/Deep%20Links.png`, `.grantiva/baselines/Deep%20Links.png`, `diffs/Deep%20Links_diff.png`. `run` writes the same names into `--report-dir/captures`.
Evidence: IOS-090/out.json, IOS-092/layout.txt, IOS-029/rep/captures/

### IOS-F19: The default `--logs` filter never matches the app's process, so no app lines are streamed
Matrix IDs: IOS-061
Severity: wrong-result
Command: `grantiva run --no-build --flow .maestro/08-caching.yaml --simulator qa-ios-1 --logs`
Expected: "`[log]` lines interleaved … filter defaults to lines whose subsystem or process matches the app's bundle ID" (help: run `--logs`; README).
Actual: Only 2 `[log]` lines appear, both noise (`getpwuid_r did not find a match for uid 501` and the filter banner). The same run with `--logs-predicate 'process == "Landmarks"'` streams 896 lines from `Landmarks[pid]`.
Evidence: IOS-061/err.txt, IOS-061/proc-err.txt
Suspected cause: The default predicate is `subsystem BEGINSWITH "<bundle>" OR processImagePath CONTAINS "<bundle>"`. On a simulator, the image path is `…/Landmarks.app/Landmarks` and never contains the bundle ID, so only apps that log under their own subsystem are matched.

### IOS-F20: report.json and junit-report.xml name the staged temp copy of the flow
Matrix IDs: IOS-071
Severity: contract
Command: `grantiva run --no-build --flow .maestro/99-crash.yaml --report-dir out`
Expected: "Flow failures are reported against the path the user passed, not the temporary staged copy" (source: CHANGELOG 1.7.0).
Actual: Terminal output is rewritten (`[1/1] 99-crash (.maestro/99-crash.yaml)`), but `out/report.json` `sourceFile`, `out/flows/flow-000.json` and `junit-report.xml` `<property name="file">` all say `/var/folders/…/grantiva-62A09DE0-…/0/99-crash.yaml`. That path is deleted after the run, and these are the artifacts CI uploads.
Evidence: IOS-070/out-dir/report.json (line 36), IOS-070/out-dir/junit-report.xml
Suspected cause: OutputRewriter only rewrites the relayed stdout stream, not the report files.

### IOS-F21: `run --timeout` has an undocumented 30 s minimum, and usage errors skip the ready file
Matrix IDs: IOS-073
Severity: docs
Command: `grantiva run --no-build --flow .maestro/11-slow.yaml --simulator qa-ios-1 --timeout 5 --ready-file r.ready`
Expected: The runner is killed after 5 s (help: run `--timeout`, which gives no minimum). The ready file "is always written … a setup failure records `failed`" (README §Agent-Native Features).
Actual: `Error: --timeout must be at least 30 seconds.`, exit 64, and no ready file, so the documented `while [ ! -f r.ready ]` waiter spins forever. With `--timeout 30` and a 90 s wait, the runner is killed at 31 s and the result is `failed`, which is correct.
Evidence: IOS-073/err.txt, IOS-073/err30.txt, IOS-073/r30.ready

### IOS-F22: `run --json` prints nothing on stdout when a flow fails
Matrix IDs: IOS-074
Severity: contract
Command: `grantiva run --no-build --flow .maestro/09-seed-empty.yaml --simulator qa-ios-1 --json`
Expected: "stdout is the result": valid JSON for every outcome (source: README §stdout is the result).
Actual: 0 bytes on stdout and exit 1, for both flow 09 and flow 02. A passing flow prints `{"allPassed":true,"screens":[…]}`.
Evidence: IOS-074/fail.json (empty), IOS-074/fail02.json (empty), IOS-074/out.json

### IOS-F23: `run --no-build` with the app uninstalled gives a misleading WDA hint
Matrix IDs: IOS-044
Severity: ux
Command: `xcrun simctl uninstall <udid> com.kylebrowning.Landmarks; grantiva run --no-build --flow .maestro/01-browse.yaml --simulator qa-ios-1`
Expected: A clear launch/install error (help: run `--no-build`).
Actual: About 1.5 KB of FBSOpenApplicationServiceErrorDomain text ending "Check that WebDriverAgent is still running on http://localhost:8876 and that no other run holds its port". The real cause, that the app is not installed, is buried in the NSError.
Evidence: IOS-044/err.txt

### IOS-F24: Concurrent runs on two different simulators kill each other's WebDriverAgent
Matrix IDs: IOS-059
Severity: wrong-result
Command: `grantiva run --no-build --flow .maestro/06-visit.yaml --simulator qa-ios-1 & grantiva run --no-build --flow .maestro/07-deeplink.yaml --simulator qa-ios-2 & wait`
Expected: "Runs on different simulator UDIDs execute in parallel" (source: README §Agent-Native Features; CHANGELOG 2.0.0).
Actual: In 4 of 4 attempts at least one run failed (pass/fail: a✓ b✗, a✗ b✗, a✓ b✗, a✗ b✓). Each run gets its own port (8876 and 8607), and its log shows `WDA started successfully on port 8876`, then `connection refused` 0.4 s later. Each flow passes when run alone right after.
Evidence: IOS-059/exits*.txt, IOS-059/a4/maestro-runner.log (lines 13-33), IOS-059/b*.err, IOS-059/solo-*.err
Suspected cause: Both runners launch `xcodebuild test-without-building` with the same `-derivedDataPath ~/.grantiva/runner/cache/wda-builds/sim-ios26.0-iphone/DerivedData` and xctestrun. The second test session tears down the first one's WebDriverAgent.

### IOS-F25: `teardown --udid --force` drops a live session's capacity record and leaves session files
Matrix IDs: IOS-016
Severity: contract
Command: `grantiva run --keep-alive … --simulator qa-ios-1 &`, `kill -9` the grantiva pid, then `grantiva simulator teardown --udid <qa-ios-1> --force --json`
Expected: Kills the runner/WDA, breaks the lease, clears a *stale* capacity record (source: README §Reclaiming a simulator). It does do this: `reclaimed:true`, runner and WDA killed.
Actual: (1) `capacityRecordsCleared: 1` removed the qa-ios-1 record of the still-active `qa-ios` session. The device stays booted, `simulator sessions` no longer lists it, and `teardown --session-id qa-ios` would skip it (it reappeared only because a later run re-reserved it). (2) `/tmp/grantiva-sessions/71926-*.grantiva` and `71926.owner.json` of the killed runner were left behind. (3) A `simctl diagnose` for the UDID appeared after the teardown (it was started by the dying runner) and ran briefly.
Evidence: IOS-016/out.json, IOS-016/sessions-after.txt, IOS-016/procs-after-teardown.txt

### IOS-F26: `record` writes simctl output to stdout; `record --json` is not valid JSON
Matrix IDs: IOS-083, IOS-079
Severity: contract
Command: `grantiva record --simulator qa-ios-1 --duration 4 --output findings/evidence/IOS-083/rec.mp4 --frames-at 500,1500,3500 --json`
Expected: Valid JSON listing the video and frames on stdout (help: record; README §stdout is the result).
Actual: stdout begins `Recording completed. Writing to disk.\n\nWrote video to: …` and then the JSON, so `json.loads` fails. Without `--json` the same simctl lines also land on stdout. The JSON lists the three frames, and those PNGs exist. Also, `--output rec.mp4` produces a QuickTime/MOV container.
Evidence: IOS-083/out.json, IOS-079/out.txt
Suspected cause: The child `simctl io recordVideo` inherits stdout.

### IOS-F27: `diff capture --no-build` ignores grantiva.yml `simulator:` and drives whatever simulator booted first
Matrix IDs: IOS-090, IOS-113
Severity: wrong-result
Command: `grantiva diff capture --no-build --json` in the app dir (grantiva.yml `simulator: qa-ios-1`)
Expected: The configured simulator (README §Configuration, `simulator:`).
Actual: The runner attached to **iPhone 17 Pro (B27D7D31)**, the user's simulator that this campaign must not touch. Report header: `Device: iPhone 17 Pro (ios 26.0 Simulator)`. It tried to launch the app there (not installed) and failed. With `--simulator qa-ios-1` it works. The MCP `grantiva_vrt_capture` shells out to exactly this command (`diff capture --no-build --json`), so it has the same problem.
Repro: Have another simulator booted and listed first, then run `diff capture --no-build` with the target only in grantiva.yml.
Evidence: IOS-F-diffsim/err.txt, IOS-F-diffsim/NOTE.txt
Suspected cause: Sources/GrantivaCLI/DiffCommand.swift:124-128. Under `--no-build` it uses `target.simulator ?? … ?? device.defaultDevice()`, which skips `resolved.simulator` (the config value), and `defaultDevice()` is the first booted device. The MCP `grantiva_context` `[Simulator]` block uses the same first-booted lookup (IOS-F32).

### IOS-F28: `diff.threshold` cannot loosen a comparison; the perceptual check fails the screen on its own
Matrix IDs: IOS-094
Severity: contract
Command: `grantiva diff compare --json` with `diff: threshold: 1.0, perceptual_threshold: 5.0`
Expected: The screen passes or fails according to the pixel threshold (README §Configuration `diff.threshold`). Raising it to 1.0 should pass every screen.
Actual: It still fails (Deep Links pixel 0.44 ≤ 1.0, but perceptual 10.1 > 5). `perceptual_distance` is the mean CIE76 distance over *differing pixels only*, so a handful of strongly changed pixels fails any screen whatever `threshold` is. Pass needs both `pixel ≤ threshold` and `perceptual ≤ perceptual_threshold`. The README does not describe either point.
Evidence: IOS-094/thr1.json, IOS-094/thr1-p100.json (passes only when perceptual is also 100)
Suspected cause: DiffCommand.swift:517-518 (AND), ImageDiffer.swift:91-92 (average over the diff set).

### IOS-F29: `diff capture` takes the screenshot mid-transition, so an unchanged screen is reported as changed
Matrix IDs: IOS-094, IOS-097
Severity: wrong-result
Command: `grantiva diff capture --no-build --simulator qa-ios-1`, then `grantiva diff compare --json`
Expected: Unchanged screens pass (README §Local Workflow).
Actual: Favorites did not change, but it failed twice: pixel 2.25 % / perceptual 7.4, then 2.04 % / 4.6. The diff image shows ghosted text edges and a shifted tab-bar selection, which is a capture taken during the tab-switch animation.
Evidence: IOS-094/changed/compare2.json, IOS-094/changed/fav_diff_small.png, IOS-097/out.json
Suspected cause: The screens flow runs with `--wait-for-idle-timeout 0` (visible in the runner command line), and the capture steps take the screenshot without waiting for idle.

### IOS-F30: MCP `grantiva_tap` and script `tap` match the element's `name`, not its accessibility label
Matrix IDs: IOS-102, IOS-107
Severity: wrong-result
Command: MCP `tools/call grantiva_tap {"label":"Favorites"}` (runner session on qa-ios-2, Landmarks list visible)
Expected: "Tap on a UI element by accessibility label" (tool schema; CHANGELOG Unreleased).
Actual: `Element not found: "Favorites". Run grantiva ui a11y to inspect the tree.` The tab button has label `Favorites` and name `heart`. `{"label":"heart"}` taps it. Labels whose name happens to equal the label ("Golden Gate Bridge") work. A script `{tap:"Deep Links"}` and `{tap:"Edit Landmark"}` fail the same way. The hint names a command that does not exist (`grantiva ui`).
Evidence: IOS-mcp/phase1/transcript.txt (ids 7, 10), IOS-mcp/phase2, IOS-mcp/phase4 (id 2 `heart` works)
Suspected cause: Sources/GrantivaCore/WDA/WDAClient.swift:82. `{"using":"link text","value":label}` matches wdName, not wdLabel.

### IOS-F31: MCP `grantiva_type` never types on iOS (404 from the agent)
Matrix IDs: IOS-104
Severity: wrong-result
Command: MCP `grantiva_tap {"x":360,"y":234}` (focuses the Name field; keyboard is up) then `grantiva_type {"text":" Yosemite"}`
Expected: Types into the focused field and returns the updated tree (tool schema).
Actual: `Internal error: Failed to type text exited with code 1`. A direct `POST /session/<id>/keys` to the agent returns 404, while `POST /session/<id>/wda/keys` returns 200 and types.
Evidence: IOS-mcp/phase6/transcript.txt
Suspected cause: WDAClient.swift:144 uses `/session/{id}/keys`. GrantivaAgent serves `/wda/keys`.

### IOS-F32: MCP `grantiva_context` reports an unrelated simulator
Matrix IDs: IOS-101
Severity: wrong-result
Command: MCP `grantiva_context` with config `simulator: qa-ios-1` and a runner session on qa-ios-2
Expected: The booted simulator for this project or session (CHANGELOG Unreleased).
Actual: `[Simulator] name: iPhone 17 Pro udid: B27D7D31…`, the first booted device on the host, which is neither the configured nor the session simulator. `[Runner Session]` correctly shows `udid 4DAB1D26` (qa-ios-2). The `platform: ios` line is present.
Evidence: IOS-mcp/phase1/transcript.txt (id 3)

### IOS-F33: MCP VRT tools run whatever `grantiva` is first on PATH
Matrix IDs: IOS-113
Severity: wrong-result
Command: `grantiva mcp --project-dir <app>` (the 2.0.1 binary) → `grantiva_vrt_compare {}` / `grantiva_vrt_approve {"screens":["Home"]}`
Expected: Equivalent to `diff compare --json` / `diff approve Home --json` (tool descriptions).
Actual: `Error: Unknown option '--platform'`. The host PATH has Homebrew grantiva 2.0.0, which the server shelled out to. With a PATH entry pointing at 2.0.1 first, both tools work (approve Home succeeds, compare returns the JSON).
Evidence: IOS-mcp/phase7/transcript.txt, IOS-mcp/phase8/transcript.txt
Suspected cause: Sources/GrantivaMCP/Tools/VRTTools.swift:56-66 builds `"grantiva diff …"` strings instead of using the running executable's path.

### IOS-F34: MCP `grantiva_test` hides why the test run failed
Matrix IDs: IOS-112
Severity: ux
Command: MCP `grantiva_test {"scheme":"Landmarks","simulator":"qa-ios-2"}`
Expected: pass/fail counts and output (tool description "Returns pass/fail counts and output").
Actual: `Tests FAILED\nScheme: Landmarks\nDuration: 0.6s\nPassed: 0\nFailed: 0`. xcodebuild's actual message ("Scheme Landmarks is not currently configured for the test action") is dropped.
Evidence: IOS-mcp/phase7/transcript.txt (id 7)

### IOS-F35: The summary table repeats the first flow's duration for flows with the same basename
Matrix IDs: IOS-072
Severity: ux
Command: `grantiva run --no-build` with `flows: [qa/a/same.yaml, qa/b/same.yaml]`
Expected: Each flow runs once (it does) and is reported once.
Actual: Both rows read `same ✓ PASS 3 3 0 0 6.3s`. report.json has the real durations, 3534 ms and 3292 ms.
Evidence: IOS-072/err.txt (lines 63-66), IOS-072/rep/report.json

### IOS-F36: A failed `diff capture` keeps the old captures, and `compare` then passes against them
Matrix IDs: IOS-093
Severity: ux
Command: `diff capture --no-build --simulator qa-ios-1` (fails: seed `empty` set via `launchctl setenv`), then `diff compare --json`
Expected: compare should not report a pass for a capture that did not happen (README §Local Workflow).
Actual: capture exits 1, the previous captures stay in `.grantiva/captures`, and compare reports all 5 screens `passed` with 0 diff.
Evidence: IOS-094/changed/capture.err, IOS-094/changed/compare.json
