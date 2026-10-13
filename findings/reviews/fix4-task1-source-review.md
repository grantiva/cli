### Spec Compliance

- ✅ L61/L64 source behavior and Task 1 device acceptance are compliant at `cc0c15a629071c0356b9a6fb66d70af8c4ff9579`, reviewed against base `fd9d8e8d1cb109eda6116f4221da10257b9838e3`. The final matching-fatal decision is in `pkg/driver/uiautomator2/commands.go:1850`; concurrent, independently cancellable failure collection is in `pkg/executor/flow_runner.go:1961`.
- ✅ The internal interface leaves the public driver contract unchanged; legacy drivers remain synchronous (`pkg/executor/flow_runner.go:1918`, `:1955`). Approved device/client/report plumbing and nested routing are necessary to implement cancellation and persist its outcome (`pkg/device/android.go:229`, `pkg/uiautomator2/transport.go:81`, `pkg/report/types.go:286`, `pkg/executor/flow_runner.go:1804`).
- ⚠️ Planned-file discrepancy: the brief explicitly lists `wait_crash.go`, `launch_timing_test.go`, and `runner_test.go`, but these files have no hunks. Existing `sourceCtx` is reused; new regressions instead live in `launch_crash_after_draw_test.go`, `wait_crash_test.go`, and the explicitly requested `duration_consistency_test.go`. No missing behavior follows from this placement, but the controller should reconcile the literal file checklist (`task-1-brief.md:6`; review package file list).
- ⚠️ Task 7 must deliver CLI decoding/export support for `artifacts.notes` and `logTail`, including the required JSON casing coverage, before bundling. The runner round-trip is covered here; the new object cannot be consumed by the current string-only CLI decoder. This is an assigned integration dependency, not a deferred L61 fix (`pkg/report/types.go:286`; `task-1-report.md`, Integration concern).
- ⚠️ PR, CI, squash merge, and final bundled integration acceptance remain controller gates. Source approval does not mark those complete (`task-1-brief.md`, Step 8).

### Strengths

- The executing launch goroutine retains all observed PIDs even on failure, then checks matching fatal logs after frame/PID observation and watch setup. No later launch device read occurs; `Execute` only updates local state/duration and `updateCrashWatch` returns immediately for launch (`pkg/driver/uiautomator2/commands.go:1832`, `:1893`, `:2014`; `pkg/driver/uiautomator2/driver.go:464`). A matching fatal/PID counts without waiting for the exception detail (`commands.go:2178`).
- The race regression publishes a fatal during the PID read after the displayed-frame snapshot, independently of the corrected post-launch fixtures. Healthy and after-return siblings verify both sides of the decision boundary (`pkg/driver/uiautomator2/launch_crash_after_draw_test.go:462`, `:487`, `:598`). Fixture publication follows an explicit simulated exit/restart/event, rather than hiding the new regression (`wait_crash_test.go:485`; `commands_test.go:4650`).
- Screenshot and hierarchy use independent request contexts. The failure-only marker preserves a hard parent deadline and prevents entry into context-free recovery; ordinary requests retain their existing deadline/retry behavior (`pkg/driver/uiautomator2/driver.go:514`, `:524`; `pkg/uiautomator2/transport.go:104`, `:241`, `:265`). The ordinary refused-connection control asserts three requests and an actual reconnect (`pkg/uiautomator2/transport_retry_test.go:64`).
- Cancellation reaches real resources: HTTP bodies are read synchronously under the request context and closed; the exact serial-scoped ADB child is killed and waited for, with bounded pipe cleanup (`pkg/uiautomator2/transport.go:295`; `pkg/device/android.go:229`). No timed-out capture goroutine is abandoned. Collection waits for all three results, saves independent successes, and records specific errors (`pkg/executor/flow_runner.go:1974`, `:1996`).
- The tests exercise concurrent starts, each reciprocal blocked collector, cancellation acknowledgement, successful artifact bytes, 25 captures per blocked case, zero active collectors, bounded goroutine growth, real HTTP cancellation, and child reaping (`pkg/executor/duration_consistency_test.go:213`; `pkg/driver/uiautomator2/launch_crash_after_draw_test.go:559`, `:608`, `:632`; `pkg/device/shell_timeout_test.go:40`). Top-level and nested report attachment tests cover persisted paths and notes (`duration_consistency_test.go:284`, `:310`; `pkg/report/flow_test.go:547`).

### Device and Verification Evidence

- ✅ Independently recomputed all five clock intervals from each run's before/after probes and raw fatal timestamp, and matched the decision to its persisted launch command. The conservative hull uses both probes and is conditional on offset remaining within that hull; negative raw cross-clock differences are not used as latency. Maximum fatal-to-decision upper bound is **0.264682 s** (`findings/evidence/fix4-1/acceptance-summary.json:276`; raw fatal lines: `stock-4/logcat.txt:506`, `stock-5/logcat.txt:511`, `stock-6/logcat.txt:530`, `stock-7/logcat.txt:503`, `stock-8/logcat.txt:503`). All five launch reports say `failed` / `app_crash` for the matching PID.
- ✅ Matched all collector start/end timestamps to raw runner logs, verified all three persisted artifact files and recorded byte counts, verified exact input hashes, and checked loads **5.2168–6.1494**, all below 15. Maximum collector span is **0.507682 s**; recorded failure-to-last-artifact including the CLI screenshot is **1.691346 s** (`acceptance-summary.json:277`; each `stock-4`–`stock-8/command.json`, `report/flows/flow-000.json`, and `report/maestro-runner.log`; example start/end lines `stock-4/report/maestro-runner.log:24`).
- ✅ All five raw post-run process snapshots contain zero owned `adb -s emulator-5580 shell/exec-out` children, consistent with each `result.json`. Cleanup records exact emulator PID absence, owned AVD removal, and preservation of the owner AVD (`cleanup.json:4`, `:7`, `:9`).
- ✅ Healthy control passes. Post-return control persisted launch success at `13:24:00.012075Z`, injected the crash at `13:24:00.040380Z`, and failed the following wait at `13:24:00.307309Z`, retaining the passed launch (`healthy3/result.json:2`; `post-return/injection.json:2`; `post-return/report/flows/flow-000.json:21`, `:32`).
- ✅ Live-server acceptance and final-source provenance are explicitly different (`final-source-provenance.json:7`, `:8`). The later change only hardens marked request deadline/refusal handling; deterministic final-source HTTP tests cover both screenshot and hierarchy, recovery exclusion, and ordinary recovery. The raw RED logs show the original failure, and final race/five-package/vet logs are clean PASS (`unit/fix4-1-http-deadline-red.log:1`, `unit/fix4-1-recovery-red.log:1`, `unit/fix4-1-transport-green.log:1`, `unit/fix4-1-transport-final-green.log:1`, `unit/fix4-1-transport-final-vet.log`). Repeating the unaffected live-server device runs is not required by an unresolved source concern.
- Check scope: read the supplied full diff once in three sequential chunks. Completed cut-off launch/transport functions only to check PID retention, post-decision device operations, and underlying request cancellation. Focused outside-diff reads checked `sourceCtx` marker propagation and the ordinary recovery control. Read the binding L61/L64 briefs and global constraints. No tests rerun, devices accessed, agents spawned, or git/source mutations performed; only this requested review file was written.

### Issues

#### Critical (Must Fix)

- None found.

#### Important (Should Fix)

- None found in the reviewed source or Task 1 acceptance evidence. The Task 7 compatibility dependency remains a pre-bundle gate.

#### Minor (Nice to Have)

- Reconcile the planned-file checklist with the actual test locations and reuse of unchanged `sourceCtx`; no cosmetic source edits are needed (`task-1-brief.md:6`; `pkg/driver/uiautomator2/wait_crash.go:172`; `pkg/executor/duration_consistency_test.go:213`).

### Assessment

**Task quality: Approved.**

**Reasoning:** The final decision handles the reproduced fatal-after-frame race, and artifact deadlines cancel underlying work while joining collectors and preserving independent successes. Five calibrated device repetitions, chronological controls, and deterministic final-transport evidence satisfy the task's behavioral requirements; CI/merge and assigned CLI integration gates remain separate.
