# iOS slice triage (independent confirmation)

Binary `~/.grantiva-qa/bin/grantiva` 2.0.1, `GRANTIVA_SESSION_ID=qa-ios`, no API key, Xcode 27.0. I re-ran each repro once
(F06 four times, F24 three times, F29 three times) on fresh simulators qa-ios-1 (93DF5345-…) and qa-ios-2 (0897A224-…,
later FD381223-…), both iPhone 17 / iOS 26.0. Both were torn down and deleted afterwards. The app was built from a copy at
`/private/tmp/qa-ios/app` (derived data `/private/tmp/qa-ios/dd`), with config variants in sibling copies. Re-run
evidence is in `findings/evidence/triage/`.

Not re-run, by rule. I judged these from source and the existing evidence instead:
- F05: reproducing it needs a runner re-extract.
- F09, F27: they could attach to or shut down the user's iPhone 17 Pro.
- F07: a live repro needs a simulator name that contains a model, and I could only create qa-ios-N names.
- F10: I read the live `simulator sessions` listing but did not change it.

Format: `ID | verdict | severity | title | duplicate-of | evidence from this re-run`

IOS-F01 | CONFIRMED | wrong-result | Flow-header `env:` never reaches the iOS app | AND-F01 | Flow 09 with no `--env` failed `assertVisible "No landmarks yet"`; the closest texts were "Landmarks", "All Landmarks", so the default seed loaded (`--env` itself works on iOS; only the header `env:` is dropped).
IOS-F02 | CONFIRMED | wrong-result | `swipe {direction, from:}` ignores the element and swipes across the screen centre | AND-F02 | Flow 02's runner log has `dragfromtoforduration {"fromX":361.8,"fromY":437,"toX":40.2,"toY":437}`, then `tapOn "Remove"` failed.
IOS-F03 | CONFIRMED | wrong-result | Bare Maestro `scroll` fails under `run --flow` | CLI-F30 | Flow 10: `✗ scroll (0ms) ╰─ Invalid scroll direction (cause: invalid direction: )`.
IOS-F04 | CONFIRMED | docs | Help and README say `simulator ensure --name` alone is enough, but a name without a model is rejected | IOS-F08 | `ensure --name qa-ios-1` gave exit 1, empty stdout, "Could not infer a device type from the name". help/simulator_ensure.txt:1 and README.md:360 both claim `--name` alone works.
IOS-F05 | CONFIRMED | crash | A missing resource bundle traps (exit 133) instead of throwing `runnerNotFound` | CLI-F23 | Not re-run (rule). RunnerManager.swift:31/35 call `Bundle.module.url(...)`, and SwiftPM's accessor calls fatalError before the nil guard; the gate log shows SIGTRAP rc=133.
IOS-F06 | CONFIRMED | wrong-result | Runner auto-accepts the app's own SwiftUI alert, so flow 04 flakes | - | 2 of 4 runs failed with `⚠ assertVisible "You have unsaved changes…"` then `✗ tapOn "Keep Editing"`; the other 2 passed.
IOS-F07 | CONFIRMED | wrong-result | `simulator ensure` on reuse reports the newest runtime and the inferred type, not the device's own | IOS-F08 | Not re-run live (naming rule). On the non-strict path, SimulatorManager.swift:136 returns `existing.udid`, but :148 builds the result from `runtime.name` (newest installed) and `type.name`. A strict reuse of qa-ios-1 without `--runtime` was rejected: "requested iPhone 17, iOS 27.0".
IOS-F08 | CONFIRMED | contract | `ensure` cannot reuse an existing simulator whose name has no model | - | With qa-ios-1 existing, `ensure --name qa-ios-1` failed "Could not infer a device type". The inference (:99-109) throws before the existing-device lookup (:129).
IOS-F09 | CONFIRMED | contract | A run on a manually booted simulator takes a capacity slot, and teardown then shuts it down | - | Not re-run (rule). SimulatorManager.boot (:46-58) calls reserve/activate even when `device.isBooted`; teardown(sessionId:) shuts down any booted device that has a record (:175-176). IOS-020 evidence shows `deleted:false` and the device Shutdown.
IOS-F10 | CONFIRMED | contract | Records from runs without a session ID never expire, so the user's iPhone 17 Pro holds a slot | IOS-F09 | Live: `simulator sessions` listed `iPhone 17 Pro — simulator:B27D7D31… [active]` all session, and my capacity-timeout repro named it as an occupant. `prune` (SimulatorCapacity.swift:195) keeps any booted record whether or not its owner pid is alive.
IOS-F11 | CONFIRMED | contract | With no scheme configured, the build silently picks the project's first scheme | - | With `scheme:` removed: `✓ Build succeeded  Scheme: Landmarks`, exit 0. The project lists two schemes (ProjectDetector.swift:86 `schemes.first`).
IOS-F12 | CONFIRMED | wrong-result | With no grantiva.yml, a `swipe {direction:}` in any `.maestro/` file blocks `run --flow` of a different file | CLI-F27 | A directory holding only `.maestro/`: `run --app-file … --flow .maestro/01-browse.yaml` gave "Unsupported Maestro command 'swipe' at …/02-favorite.yaml:11", exit 1.
IOS-F13 | CONFIRMED | ux | A capacity timeout leaves a newly created simulator behind; errors end in a stray " exited with code 1" | - | `GRANTIVA_MAX_SIMULATORS=2 …WAIT_TIMEOUT_SECONDS=5 ensure --name qa-ios-2 …` timed out (exit 1) with a message ending "`--session-id <id>`. exited with code 1", and qa-ios-2 (FD381223) was left Shutdown.
IOS-F14 | CONFIRMED | contract | `hierarchy --json` prints XML | CLI-DOCS-F12 | During a keep-alive run, `hierarchy --udid … --json` gave exit 0 and first line `<?xml version="1.0"…`.
IOS-F15 | CONFIRMED | ux | `hierarchy --timeout` failure is a raw NSError dump | - | `--timeout 0.01` gave exit 1 with `Error: Error Domain=NSURLErrorDomain Code=-1001 … UserInfo={_kCFStreamErrorCodeKey=-2102, …}` (about 5 lines of Foundation internals).
IOS-F16 | CONFIRMED | contract | Ctrl-C mid-flow writes ready status `failed` and leaves the flow `running` | AND-F10 | `kill -INT` during 11-slow (keep-alive) gave exit 130 and ready file `"status":"failed"`, `flows:[{"name":"11-slow","status":"running"}]`.
IOS-F17 | CONFIRMED | ux | Ready file `reportDir` points at a temp dir that is already deleted | AND-F11 | 01-browse with `--ready-file`: `ls <reportDir>` gave "No such file or directory".
IOS-F18 | CONFIRMED | ux | Screen names with spaces are percent-encoded in capture, baseline and diff file names | - | `diff capture` wrote `.grantiva/captures/Deep%20Links.png`; compare JSON reports `baselines/Deep%20Links.png` and `diffs/Deep%20Links_diff.png`.
IOS-F19 | CONFIRMED | wrong-result | The default `--logs` predicate never matches a simulator app's process | - | Flow 08 with `--logs` gave 2 `[log]` lines: a getpwuid_r line and the filter banner `processImagePath CONTAINS "com.kylebrowning.Landmarks"`. With `--logs-predicate 'process == "Landmarks"'` it gave 913.
IOS-F20 | CONFIRMED | contract | report.json and junit-report.xml name the deleted staged copy of the flow, not the path the user passed | - | `--report-dir` for 09: report.json:36 `sourceFile` and the junit `<property name="file">` are `/var/folders/…/grantiva-F1B3040D…/0/09-seed-empty.yaml` (CHANGELOG.md:144 promises the user's path).
IOS-F21 | CONFIRMED | docs | `run --timeout` has an undocumented 30 s minimum, and that usage error writes no ready file | CLI-F01 | `--timeout 5 --ready-file F21.ready` gave exit 64 "--timeout must be at least 30 seconds." and no ready file (README.md:85 says it is "always written").
IOS-F22 | CONFIRMED | contract | `run --json` prints nothing on stdout when a flow fails | - | Flow 09 with `--json`: exit 1, 0 bytes on stdout.
IOS-F23 | CONFIRMED | ux | `run --no-build` with the app uninstalled blames WebDriverAgent | IOS-F15 | After `simctl uninstall`: exit 1, 7.5 KB of stderr repeating `FBSOpenApplicationServiceErrorDomain Code=4` and "Check that WebDriverAgent is still running on http://localhost:8485 …"; it never says the app is not installed.
IOS-F24 | CONFIRMED | wrong-result | Concurrent runs on two different simulators kill each other's WebDriverAgent | - | 3 of 3 paired runs had one failure (a1✗b✓, a✓b2✗, a✓b3✗). One log shows `WDA started successfully on port 8485`, then `connection refused` 0.4 s later. The F25 teardown JSON shows WDA's xcodebuild using the shared `-derivedDataPath ~/.grantiva/runner/cache/wda-builds/sim-ios26.0-iphone/DerivedData`.
IOS-F25 | CONFIRMED | contract | `teardown --udid --force` clears a live session's capacity record and leaves session files | - | After `kill -9` of the keep-alive grantiva, `teardown --udid qa-ios-2 --force` returned `capacityRecordsCleared:1`; qa-ios-2 stayed Booted but vanished from `simulator sessions` (3/4 to 2/4). `/tmp/grantiva-sessions/31830-*.grantiva` and `31830.owner.json` remained, and a `simctl diagnose --udid=0897A224…` started afterwards.
IOS-F26 | CONFIRMED | contract | `record --json` stdout begins with simctl narration, so it is not valid JSON | CLI-F15 | stdout began "Recording completed. Writing to disk. / Wrote video to: …", and json.load failed at char 0. `rec.mp4` is a QuickTime MOV.
IOS-F27 | CONFIRMED | wrong-result | `diff capture --no-build` ignores grantiva.yml `simulator:` and drives the first booted device | - | Not re-run (rule). DiffCommand.swift:124-128 uses `target.simulator ?? target.device ?? target.emulator`, else `defaultDevice()`, and never reads `resolved.simulator`. Existing evidence IOS-F-diffsim shows it attached to the iPhone 17 Pro.
IOS-F28 | CONFIRMED | docs | Undocumented: a screen must pass both `diff.threshold` and `perceptual_threshold`, so `threshold` alone cannot loosen a compare | - | With `threshold: 1.0`, compare still failed Favorites (`pixel=1.01% perceptual=7.7`, pixel_threshold 1) and Lakes; README §Configuration shows the two keys without semantics.
IOS-F29 | CONFIRMED | wrong-result | `diff capture` screenshots mid-transition, so unchanged screens fail compare | AND-F15 | Approve, then recapture and compare 3 times with no app change: Deep Links failed 3/3 (pixel 7.4-8.3%), Favorites 3/3, Lakes 1/3 (pixel 11.2%, perceptual 17.6).
IOS-F30 | CONFIRMED | wrong-result | MCP `grantiva_tap` by label matches the element `name`, not its accessibility label | - | `grantiva_tap {"label":"Favorites"}` gave "Element not found … Run grantiva ui a11y" and `{"label":"heart"}` tapped. WDAClient.swift:82 uses `"using":"link text"`.
IOS-F31 | CONFIRMED | wrong-result | MCP `grantiva_type` posts to `/session/{id}/keys`, which the agent does not serve | - | `grantiva_type` gave "Failed to type text exited with code 1". A direct POST to `/session/<id>/keys` returned 404 and `/wda/keys` returned 200 (WDAClient.swift:144).
IOS-F32 | CONFIRMED | wrong-result | MCP `grantiva_context` reports the first booted simulator | CLI-F20 | `[Simulator] name: iPhone 17 Pro udid: B27D7D31…` with config `simulator: qa-ios-1`.
IOS-F33 | CONFIRMED | wrong-result | MCP VRT tools run whatever `grantiva` is first on PATH | CLI-F19 | `grantiva_vrt_compare {}` returned isError "Unknown option '--platform'" (from /opt/homebrew/bin/grantiva 2.0.0).
IOS-F34 | CONFIRMED | ux | MCP `grantiva_test` drops xcodebuild's failure reason | - | `{"scheme":"Landmarks","simulator":"qa-ios-2"}` gave "Tests FAILED / Passed: 0 / Failed: 0" in 1 s, with no reason.
IOS-F35 | CONFIRMED | ux | The summary table repeats the first flow's row for flows with the same basename | - | `qa/a/same.yaml` (8 steps) and `qa/b/same.yaml` (6 steps) both printed `same ✓ PASS 8 8 0 0 8.0s`; report.json durations are 5117 and 4953 ms.
IOS-F36 | CONFIRMED | wrong-result | A failed `diff capture` keeps the old captures, and `compare` passes against them | - | With the Detail path made to fail, capture exited 1 ("Runner failed (exit 1):\n exited with code 1"), all 5 capture mtimes were unchanged, and compare reported `passed: true` for all 5 screens.

## Counts

- Confirmed: 36. Not reproduced: 0. Not a bug: 0.
- Merged into another iOS finding: 4 (F04, F07 -> F08; F10 -> F09; F23 -> F15).
- Duplicates of CLI or Android findings, folded into their briefs: 13 (F01, F02, F03, F05, F12, F14, F16, F17, F21, F26, F29, F32, F33).
- Severity changes from the original report: F01 contract -> wrong-result; F14 docs -> contract (to match D01); F28 contract -> docs; F36 ux -> wrong-result (it is a false pass).

## Proposed issues (iOS), by severity

1. [wrong-result] Give each simulator its own WebDriverAgent test session so concurrent runs on different UDIDs stop killing each other (IOS-F24)
2. [wrong-result] Honour grantiva.yml `simulator:` in `diff capture --no-build` and in MCP `grantiva_vrt_capture`, never falling back to the first booted device (IOS-F27)
3. [wrong-result] Clear or invalidate stale captures when `diff capture` fails, so `diff compare` cannot pass against them (IOS-F36)
4. [wrong-result] Stop auto-accepting app alerts during flows; accept only system permission prompts (IOS-F06)
5. [wrong-result] Match MCP `grantiva_tap` labels (and script `tap`) against the accessibility label (IOS-F30)
6. [wrong-result] Send MCP `grantiva_type` keystrokes to the agent's `/wda/keys` endpoint (IOS-F31)
7. [wrong-result] Make the default `--logs` predicate match the app's process on a simulator (IOS-F19)
8. [contract] Count and tear down only simulators Grantiva booted itself, and expire records whose owner is dead (IOS-F09, IOS-F10)
9. [contract] Keep a live session's capacity record in `teardown --udid --force`, and remove the killed runner's session files (IOS-F25)
10. [contract] Make `simulator ensure --name` reuse an existing device before inferring a type, report that device's own type and runtime, and say in help and README that a new device needs a model in its name (IOS-F08, IOS-F04, IOS-F07)
11. [contract] Write the user's flow path into report.json, flows/*.json and junit-report.xml (IOS-F20)
12. [contract] Emit a JSON result on stdout when `run --json` fails (IOS-F22)
13. [contract] Fail with "No scheme specified" (or name the chosen scheme in a warning) when the project has several schemes and none is configured (IOS-F11)
14. [ux] Delete a simulator that `ensure` created when the capacity wait times out (IOS-F13)
15. [ux] Replace raw NSError dumps with actionable messages: hierarchy timeout, app not installed under `--no-build` (IOS-F15, IOS-F23)
16. [ux] Use the plain screen name, not percent-encoding, in capture, baseline and diff file names (IOS-F18)
17. [ux] Include xcodebuild's failure reason in MCP `grantiva_test` output (IOS-F34)
18. [ux] Report each flow's own steps and duration in the run summary when basenames collide (IOS-F35)
19. [docs] Document that a screen must pass both `diff.threshold` and `perceptual_threshold`, and how the perceptual distance is averaged (IOS-F28)

## Fold into existing brief

- A01 (IOS-F01): on iOS, `--env` already reaches the app through `launchApp.environment`, but the flow header `env:` block is never read. FlowEnvironment.inject rewrites only `launchApp` steps with `--env` values. Flow 09 fails without `--env LANDMARKS_SEED=empty` and passes with it, and 99-crash does not crash. The fix (or a README sentence saying header `env:` defines Maestro variables, not launch environment) is cross-platform, so the brief's platforms should include ios.
- A02 (IOS-F02): the iOS runner (1.1.18-grantiva.7) drops `from:` too. It issues `wda/dragfromtoforduration {"fromX":361.8,"fromY":437,"toX":40.2,"toY":437}` at the vertical centre of the 874-pt screen while the Lake Tahoe row is near y≈210, so flow 02 then fails `tapOn "Remove"`. On iOS the flow fails rather than passing by accident. Add ios to the brief's platforms.
- C10 (IOS-F03): on iOS, flow 10 fails at the first bare `- scroll` with "Invalid scroll direction (cause: invalid direction: )". Grantiva's own parser maps `scroll` to a swipe up (MaestroFlowParser.swift:237), but `run --flow` passes the step to the runner unchanged.
- C01 (IOS-F05): the iOS gate hit the trap on every `run` (exit 133, "unable to find bundle named grantiva_GrantivaCore") while `--version` still worked. The trigger was the Homebrew 2.0.0 binary and the 2.0.1 QA binary sharing `~/.grantiva/runner/version`. Each re-extracts when the other has run, and the MCP VRT tools shell out to the PATH 2.0.0 (C05). Two installed versions are enough to force the bundle access.
- C07 (IOS-F12): with no grantiva.yml, `GrantivaConfig.loadIfPresent` parses every `.maestro/*.yaml` into screens. A `swipe {direction:}` in 02-favorite.yaml therefore aborts `run --app-file … --flow .maestro/01-browse.yaml`, a different file, before any device work. `--flow` should not parse unrelated files.
- D01 (IOS-F14): same on iOS. `hierarchy --udid <udid> --json` during a keep-alive run returns XCUIElementType XML, exit 0.
- A06 (IOS-F16, IOS-F17, IOS-F21): iOS behaves the same way. SIGINT during 11-slow gives exit 130 and `{"status":"failed","flows":[{"name":"11-slow","status":"running"}]}`, and the `reportDir` of a run without `--report-dir` no longer exists when read. Also, a usage error such as `--timeout 5` exits 64 without writing the ready file, which breaks the README "always written" waiter. The brief should cover validation failures.
- C26 (IOS-F21): the same 30 s `--timeout` minimum applies on iOS (`--timeout 5` gives exit 64). With `--timeout 30` the runner was killed at 31 s and recorded `failed`.
- C13 (IOS-F26): `record --json` on iOS puts simctl's "Recording completed. Writing to disk." and "Wrote video to: …" ahead of the JSON, so json.load fails at char 0. Also, `--output rec.mp4` produces a QuickTime MOV container.
- A04 (IOS-F29): iOS shows the same race. The screens flow runs with `--wait-for-idle-timeout 0`, and an immediate recapture after approve failed Deep Links and Favorites 3/3 times and Lakes 1/3 (pixel up to 11.2%, perceptual 17.6). The diff images show ghosted text and a mid-animation tab-bar selection. Add ios to the brief's platforms.
- C06 (IOS-F32): on iOS, `[Simulator]` shows the user's iPhone 17 Pro (first booted) while config says `simulator: qa-ios-1`. In this re-run `[Runner Session]` said "No active session." even though `grantiva_tap` acted on the live qa-ios-2 keep-alive session (C03's machine-wide fallback).
- C05 (IOS-F33): on iOS, `grantiva_vrt_compare {}` and `grantiva_vrt_approve` return "Unknown option '--platform'" from /opt/homebrew/bin/grantiva 2.0.0. Both work when a PATH entry for 2.0.1 comes first.
- C21 (IOS-F30): MCP `grantiva_tap`'s not-found error says "Run grantiva ui a11y to inspect the tree", a command that does not exist.
- A10 (IOS-F13, IOS-F36): iOS has the stray " exited with code 1" suffix too. It appears on capacity timeouts ("…`--session-id <id>`. exited with code 1"), runner failures ("Runner failed (exit 1):\n exited with code 1"), the ownership error, and record errors. The suffix comes from GrantivaError.commandFailed, so the fix is not Android-specific.
