# Task 1 — L61/L64 runner crash decision and failure capture

Status: **DONE_WITH_CONCERNS** — source, tests, changelog, and Task 1 device acceptance complete. Current-CLI notes-object decoding is assigned to Task 7 before bundle; controller review/CI/merge remain. No push, PR, or merge performed.

## Provenance and scope

- Worktree: `/Users/kyle/Developer/maestro-runner/.worktrees/fix4-crash-capture`; branch `fix4/crash-capture`.
- Clean starting base: `fd9d8e8d1cb109eda6116f4221da10257b9838e3`.
- Read Task 1 brief, parent plan Global Constraints, approved campaign design, retained L61 and round-3 L64 briefs.
- Controller approved narrow additional plumbing in `pkg/device/android.go`, `pkg/uiautomator2/device.go`, `pkg/report/types.go`, plus their tests: cancellation needs an owned/reaped ADB child and per-request screenshot HTTP context; the report needs persisted log-tail paths and per-artifact notes. No public `core.Driver` interface change.
- Controller approved routing existing nested failure capture through the same collector, preserving nested filenames and attachment ownership.

## Implementation

The launch confirmation retains every observed launch PID, including on failure. The launch execution goroutine owns all PID/fatal observations and the decision: after frame/PID confirmation and watch setup, it reads matching fatal logs immediately before success, without another device operation afterward. A matching FATAL/PID already identifies a crash even if the exception-detail line has not arrived. Permission batching, first-frame waits, and post-return crash watch are preserved.

The executor prefers an internal `failureArtifactCapturer`, unwrapping driver wrappers. Three collectors start concurrently with independent 1.5-second deadlines inside a 2-second parent deadline. It drains every completion/cancellation acknowledgement, saves successful collectors, and records artifact-specific errors. UIAutomator2 uses separate screenshot/source HTTP contexts; logcat is scoped to the launched PIDs and timestamp. Cancellation kills and waits for the exact owned ADB child, including bounded pipe cleanup. Legacy drivers remain synchronous. Both top-level and nested failures attach captures through this implementation. Added JSON keys are `artifacts.logTail` and `artifacts.notes`, all camelCase; existing keys remain unchanged.

## Verification recorded so far

Evidence: `findings/evidence/fix4-1/unit/` (raw log copies refreshed at completion).

Commands used this prefix (final package run also explicitly sets the runner-internal `MAESTRO_RUNNER_HOME=/tmp/fix4-1-empty-home`):

```sh
env -u GRANTIVA_API_KEY GRANTIVA_RUNNER_HOME=/tmp/fix4-1-empty-home GRANTIVA_SESSION_ID=fix4-1
```

- Baseline: `go test ./pkg/driver/uiautomator2/... ./pkg/executor/... ./pkg/report/...` — PASS, driver 206.325s, executor 6.594s, report 0.555s.
- RED, same package command: matching-fatal-before-return regression incorrectly returned success; screenshot/hierarchy/log-tail tests found zero context collectors. Focused RED log records the independent deterministic reproduction.
- Report RED: `go test ./pkg/report -run TestFailureArtifactPathsAndNotesRoundTrip -count=1` — failed because logTail and notes were discarded.
- Underlying cancellation RED: `go test ./pkg/device ./pkg/uiautomator2 -run 'TestShellContextCancelsAndReapsOwnedChild|TestScreenshotContextCancelsUnderlyingRequest' -count=1` against baseline production files — both failed for missing cancellable capability. Production files restored exactly afterward.
- Nested RED: `go test ./pkg/executor -run TestNestedFailureUsesCancellableArtifacts -count=1` — zero collectors before routing the nested path.
- Partial-fatal RED/GREEN: `go test ./pkg/driver/uiautomator2 -run TestFinalFatalDecisionDoesNotWaitForExceptionDetail -count=1` — success before fix; app_crash after fix.
- GREEN full scope: `go test ./pkg/driver/uiautomator2/... ./pkg/executor/... ./pkg/report/... ./pkg/device/... ./pkg/uiautomator2/...` — PASS (driver 206.425s, executor 120.587s, report 0.442s, device 6.930s, client 14.123s). Includes 25 repetitions for each blocked collector, concurrent starts, surviving artifact bytes, cancellation acknowledgement, zero active collectors, and bounded goroutine count.
- Focused `go test -race` across those five packages — PASS for decision race/healthy/post-return controls, independent screenshot/hierarchy requests, scoped/cancellable log tail, child reaping, HTTP connection cancellation, nested artifacts, report round-trip, and fixture chronology.
- `go vet ./pkg/driver/uiautomator2/... ./pkg/executor/... ./pkg/report/... ./pkg/device/... ./pkg/uiautomator2/...` — PASS.
- Final source (including hard transport deadline/recovery correction): `go test ./pkg/driver/uiautomator2/... ./pkg/executor/... ./pkg/report/... ./pkg/device/... ./pkg/uiautomator2/...` — PASS, driver 206.375s, executor 122.146s, report/device cached PASS, client 14.186s (`unit/fix4-1-transport-final-green.log`).
- Final `go vet` over the same explicit package list — PASS (`unit/fix4-1-transport-final-vet.log`).
- Top-level note/path persistence integration PASS, nested note/path persistence integration PASS.
- `go build -o /private/tmp/grantiva-fix4-1.6ddirwah/grantiva-runner-final .` — PASS. Final binary hash is in `final-source-provenance.json`; this binary includes the final transport correction and is distinct from the earlier live-server acceptance binary.
- `git diff --check` — PASS. `/tmp/fix4-1-empty-home` remains empty; no default runner home used for final tests. Exact focused commands/environment mapping is in `unit/commands.json`.

## Existing fixture chronology correction

Old post-launch crash tests preloaded their future crash text before calling launchApp and expected the launch to pass because launch never read that buffer. The corrected fixture reads the simulated clock at launch and withholds future crash lines until the test explicitly sets death/restart or an am_crash event. `TestPostLaunchCrashFixturePublicationBoundary` exercises all three publication points. The simpler `flipPid` fixture similarly publishes its configured crash only after its explicit death transition. The separate `fatalAfterStatusShell` regression does not use either chronology correction and independently failed on baseline: it publishes the fatal during the PID read after Displayed. The existing final-operation assertion now requires a final fatal read without another PID read, preserving the no-extra-pidof intent.

## Device acceptance — PASS

- Owned device: `fix4-1-android`, explicit serial `emulator-5580`, launched emulator PID 6654, software renderer, 2 cores/2048 MiB.
- Isolated task root: `/private/tmp/grantiva-fix4-1.6ddirwah`; runner home is a fresh APFS clone of owner runner home, with task-local Android driver APKs copied in. Both runner-home environment names point here; API key unset; session literal `fix4-1`.
- Evidence root: `findings/evidence/fix4-1/`. `workspace.json`, `inputs.json`, `emulator-process.json`, binary hash and source diff preserve identity/provenance.
- Stock flow copied byte-for-byte from demo `android/.maestro/99-crash.yaml`; APK package verified as `com.kylebrowning.landmarks` API 35; APK and flow hashes recorded.
- Initial healthy setup failed before driver connection because ADB was absent from PATH; retained raw output in `healthy/`. Harness now adds only SDK platform-tools to its child PATH.
- Next measurement was refused at load1 151.119 (>15) during parallel simulator startup; no acceptance claim from refused measurements. Controller notified; AVD remains idle while load settles.
- Five acceptance repetitions are `stock-4` through `stock-8`, run through the unchanged QA CLI so its existing Android FlowEnvironment conversion passes the stock header environment as intent extras. Input stock flow bytes and hashes are retained per run. The task-built runner was manually installed only under the scoped clone's version directory; `cli-runner-install.json` records binary/CLI hashes and install stamp. This is task-specific behavior acceptance, not release upgrade-path acceptance.
- `crash-1` was a non-acceptance direct-runner attempt: direct invocation did not perform CLI Android header-env conversion, so the app never crashed and failed a later ordinary assertion. `stock-1` was a rejected CLI invocation with mutually exclusive --device/--emulator. Neither is counted. `stock-2` and `stock-3` are supporting successful crash captures before clock-calibration probes were added.
- All five calibrated runs fail `launchApp` with `app_crash`, preserve matching fatal PID evidence and all three artifacts, and have no collector child left after return. Host load immediately before each was below 15.
- Device and host clocks differ by about 0.4 seconds. `clock-before.json` / `clock-after.json` retain host-before, device epoch, host-after, and RTT. Analysis uses the conservative hull of offset intervals from both probes; it does not treat negative raw cross-clock differences as latency. This assumes offset stays within the observed bracketing interval. Raw timestamps remain unchanged.

| Run | Fatal-to-decision interval (s) | Concurrent capture span (s) | Failure to last artifact, including CLI screenshot (s) |
| --- | --- | --- | --- |
| stock-4 | 0.239650–0.264682 | 0.480785 | 1.631160 |
| stock-5 | 0.201625–0.227517 | 0.507682 | 1.691345 |
| stock-6 | 0.203076–0.222607 | 0.496215 | 1.645846 |
| stock-7 | 0.227386–0.251475 | 0.486749 | 1.661290 |
| stock-8 | 0.231424–0.256271 | 0.482233 | 1.649790 |

- Healthy control `healthy3` passes (exit 0; no collector child left).
- Post-return control `post-return` waits for the persisted launch success before issuing the exact scoped `adb -s emulator-5580 shell am crash com.kylebrowning.landmarks`. Launch returned passed at 13:24:00.012075Z; injection started at 13:24:00.040380Z; following extendedWaitUntil failed with app_crash at 13:24:00.307309Z. Launch remains passed in the final report. `injection.json` preserves the already-passed launch record.
- Cleanup PASS: exact owned emulator PID 6654 absent, emulator-5580 absent from adb, fix4-1-android AVD directory and .ini deleted, protected owner AVD registration still present. `cleanup.json` records commands/results. Controller notified that Android slot is released.
- Pending device criteria: none for Task 1's live-server acceptance. The final transport hard-deadline/refusal edge is verified by deterministic tests after device cleanup; it does not alter the previously measured live-server success path.

## Final self-review transport correction

Self-review found that the existing UIA2 transport intentionally extends ordinary step deadlines and only propagates explicit context.Canceled, and its connection recovery callback has no cancellation contract. That is unsuitable for failure artifact deadlines. Controller approved `pkg/uiautomator2/transport.go` as narrow additional scope.

`uiautomator2.FailureCaptureContext` carries a package-private marker through the driver's ScreenshotCtx/sourceCtx calls to requestDeadline/doWithRetry. Only marked capture requests inherit the hard parent deadline and skip reconnect/retry; ordinary soft step deadlines and recovery remain unchanged. Both explicit cancellation and deadline expiry stop the underlying HTTP request.

- RED: `TestFailureCapturesDoNotEnterUncancellableRecovery` took 9.012s despite a 300ms parent deadline on a refused connection.
- RED: `TestFailureCaptureDeadlineAbortsUnderlyingHTTP` failed for both screenshot and hierarchy; each only exited after the finite 300ms safety release, with no request cancellation acknowledgement. No abandoned test goroutine was used.
- GREEN with race detector: `go test -race ./pkg/driver/uiautomator2 ./pkg/uiautomator2 -run 'TestFailureCaptureDeadlineAbortsUnderlyingHTTP|TestFailureCapturesDoNotEnterUncancellableRecovery|TestFailureScreenshotAndHierarchyUseIndependentRequests|TestScreenshotRetriesRefusedConnection' -count=1` — both packages PASS. The last test is the ordinary recovery control (three requests after two refusals; reconnect still called).
- Final five-package tests/vet cover the final source after this correction. Device acceptance above used the immediately preceding live-server source; this distinction is deliberate and the controller accepted deterministic verification of the refusal/deadline-only change without another device cycle.

## Integration concern and review/commit

Current QA CLI decodes command artifacts as string values and cannot decode the new nested notes object when a timeout/error note is present. Controller assigned decoder and trace-export compatibility to Task 7 before bundling; the five successful artifact runs had no notes. Runner raw JSON, notes, byte persistence, and round-trip are directly tested. Repacked CLI output surfaces still require the campaign's integration pass.

Self-review complete; no remaining implementation findings. Commit: `cc0c15a629071c0356b9a6fb66d70af8c4ff9579` (`Fix Android crash decisions and cancel failure captures`), containing source, tests and CHANGELOG. Worktree is clean. Parent/base remains `fd9d8e8d1cb109eda6116f4221da10257b9838e3`. No remotes were used, no push, PR, or merge performed.

Controller independently reviews and owns PR/CI/merge gate. **Pending device criteria: none for this task.** The campaign still must validate all CLI report/trace surfaces after Task 7's decoder compatibility change and repack.
