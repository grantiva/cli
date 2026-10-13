# iOS 69b/70 and Android B2-K87 review

Read-only review against the binding round-3 matrix, CLI candidate `8f2cff67`, and retained current-round evidence. No device/build/test operation was run.

## iOS attempt 69b

### D2-02 [ios]: supported

The frozen pass and fail configs each retain five named screens followed by their flow list. The harness invokes stock combined execution with explicit `--ready-file` and `--report-dir` in both cases. `pass.ready` lists `screens` first followed by all twelve flows, all `passed`; `fail.ready` lists `screens` first (`passed`) then `02-exact-negative` (`failed`). Both documents carry the exact absolute retained report directory, and both directories exist. Exit 0/1 agrees with the earned state.

### IOS-132: supported

The pass leg uses the five-screen plus twelve-flow config with `--snapshot full`. It exits 0, retains `pass-report/screens/report.json` and the rest of the screens report subtree, and mirrors full screen-session trace artifacts under `pass-report/captures/trace` (241 files). This proves full snapshot policy applies to the generated screens session rather than only a standalone flow.

### IOS-133: supported

The same combined run writes the screens runner report under `pass-report/screens/` and the subsequent flows under the parent report. The readiness document names `screens` first and all thirteen entries complete successfully.

## D2-04 [ios] retained attempt-10 join: supported

The exact commands in attempt 10 use the required `02-exact-negative.yaml --snapshot trailing --report-dir trailing-report` and `01-browse.yaml --snapshot full --report-dir full-report` inputs.

- Trailing failure retains only command 1 after and command 2 before/after/hierarchy under `assets/flow-000`, with the same set mirrored under `captures/trace`; the Allure set is correspondingly trimmed. The flow contains no explicit `takeScreenshot`, so the only non-trace capture is the failure screenshot.
- Full browse retains before/after assets for every command, mirrors them under `captures/trace`, and exposes only its two explicit `takeScreenshot` products in the ordinary capture list.

The current D2-04 [ios] pass is supported.

## B2-K87 [android]: supported as an Android platform half

`B2-K87-ten-runner-cycles-rerun2` performs ten genuine `runner start --detach` / hierarchy / `runner stop --json` cycles. All starts, hierarchy reads and stops exit 0. The ten PIDs are unique, every PID is dead after its stop, each project session file is absent, and each `pid-global-files-after.txt` is empty. Global session-file inventories are empty before and after, and adb forwards return byte-for-byte to their initial inventory.

The exact-head semantic assertion `RunnerLifecycleCommandTests.testStopOfARunnerThatIgnoresSIGINTRemovesItsSessionFileAndSaysItKilled` verifies the escalation branch still invokes PID-specific file cleanup and reports SIGKILL. This is the named criterion, not a test-name inference.

The matrix marks the row `both` even though the embedded brief text says `Platforms: ios`; under the binding platform-half rule the Android runtime and shared semantic assertion support `B2-K87 [android]`. They do not replace the separate iOS runtime half.

## iOS attempt 70: B3-L37 passes, separate startup-interrupt defect exposed

The three foreground `runner start` variants (plain, quiet, JSON) are signalled with SIGINT after their row-owned session file is published as `starting`. Every stderr contains the exact required iOS notice:

`[grantiva] received SIGINT — releasing simulator and reaping child processes`

All session files are absent afterward. Source inspection finds both production `SignalRelay.shared.track` call sites pass `SignalRelay.deviceNoun(for:)`, and exact-head semantic assertions cover Android `emulator` and iOS `simulator`. Thus the literal B3-L37 [ios] notice criterion is supported.

The same evidence exposes an additional product defect that B3-L37 does not waive: all three commands exit 1 and append `Error: Timed out waiting for WDA to start.` after the correct interrupt notice, even though the signal cleanup succeeds within milliseconds. `RunnerStartCommand.startForeground` installs SignalRelay cleanup while the session is `starting`, but its iOS startup guard handles only a `RunnerStopMarker` request; when SIGINT makes the WDA wait end without a port, it falls through to `wdaStartupError`. The later foreground-hold branch that normalizes a terminating relay to exit 130 is never reached. A ready-state control is useful to delimit this to startup, but is not needed to establish the captured startup-path error.

This should be triaged separately (candidate L72): foreground `runner start` interrupted during WDA startup should terminate as an interrupt (normally 130) without a false WDA-timeout error, while still cleaning session/lease/process state. Preserve attempt 70 as failure evidence; do not reclassify it as a harness failure.

## N3-06 [android]: video-duration behavior passes; literal metadata clause needs correction

The preserved ten-run batch is usable despite its wrapper exit 1: the wrapper looked for the nonexistent `.duration` key and rejected zero `recordedMilliseconds`. Posthoc ffprobe over the already retained MP4s shows all ten are exactly `3.000000` seconds, all record commands exited 0, and every JSON document reports `requestedDurationSeconds: 3`.

The row's additional literal requirement, `recordedMilliseconds >= 3000`, is incompatible with the documented held-frame meaning. Nine idle recordings report `lastFrameMilliseconds: 0` and `recordedMilliseconds: 0`; one reports 658 and 1316. Every stderr explicitly says the last frame was held to the requested 3.0 seconds. `README.md` and `docs/android.md` define `recordedMilliseconds` as where the source track ended **before** hold/trim so that underrun/overrun remains observable, and exact-head `RecordCommandTests` asserts held examples with `recordedMilliseconds` 0 and 67. The final movie duration, rather than this pre-edit diagnostic, is the correct duration assertion.

Therefore preserve N3-06 as a literal matrix fail pending Task 6 correction. Supported corrected expectation: ten ffprobe durations are 3.000 seconds within a frame tick; `requestedDurationSeconds` is 3; `recordedMilliseconds` may be below 3000 for an idle held-frame input and records the pre-hold track end. This is an expectation conflict, not a recording product defect.

## Android dead-runner stop rerun 2: valid partial join for N2-05 and B3-L13

`N2-05-B3L13-dead-runner-stop-json-rerun2` cleanly supplies the killed-before-stop leg. A detached Android start exits 0 with numeric PID/port and full Android app/device keys. The harness verifies that exact row-owned runner PID, sends SIGKILL to it, proves it dead, and then `runner stop --json` exits 0 with:

- `status: stopped`, `alreadyExited: true`;
- matching numeric `pid`, `runnerPid`, and `port`;
- matching `applicationId`/legacy `bundle_id` and `serial`/legacy `udid`;
- `killed: false` (stop itself did not need to kill an already-dead runner) and `reaped: []`.

The project session is absent and the PID-specific global file inventory is empty afterward. Exact-head `RunnerLifecycleCommandTests` semantically asserts the exited result and both Android metadata and the complete L13 stopped-document key contract.

This supports N2-05 [android] leg (a) and B3-L13 [android]'s `alreadyExited` variant. It is **not a whole-row grade**: N2-05 additionally requires the two-device keep-alive `sessions[]` leg and ordinary detached stop; B3-L13 additionally compares ordinary stopped and multi-session entry shapes. Those other variants must be joined from retained exact evidence before grading either compound row.

## Evidence

- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt69b/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt10/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt70/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B2-K87-ten-runner-cycles-rerun2/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/N3-06-ten-recordings-rerun1/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/N2-05-B3L13-dead-runner-stop-json-rerun2/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCLI/DriverCommand.swift` (`startForeground`, startup wait and foreground hold branches)
- `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCLITests/RunnerLifecycleCommandTests.swift`
