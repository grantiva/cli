# Round 4 binding acceptance inventory

Extracted from the 22 binding briefs. This is an execution checklist; the source brief and reviewed plan remain authoritative. No criterion is complete at creation.

## L51 — Task 2

Source: `docs/superpowers/plans/2026-10-12-coverage-issues-round2/L51-screen-and-start-end-swipes-still-input-swipe.md`

### Expected
Every swipe the runner performs on Android uses one gesture engine with the same timing model, so a flow author gets the
same travel, the same fling behaviour and the same `distance:`/`duration:` semantics whether the swipe targets an element,
a screen direction, or explicit `start:`/`end:` points. `engine: adb` stays as the explicit opt-in to `input swipe`.

### Fix direction
Route direction and point swipes through the same held-drag path as element swipes (start point = screen point or
`start:`), keep `engine: adb` as the escape hatch, and extend the L07 tests to the three forms. Schedule: round 4 unless
the round-3 coverage pass turns a `B3-L` row red on it.

## L53 — Task 3 + 4

**Reviewed-plan ruling:** The retained brief predates the supported flag inventory. Validate the runner’s existing `--device` and its existing `--udid` alias, and CLI’s existing target flags; preserve existing aliases and do not add unsupported `--serial`. Keep malformed simulator-UDID and unknown-flag controls. Tasks 3 and 4 contain the executable contract.

Source: `docs/superpowers/plans/2026-10-12-coverage-issues-round2/L53-runner-empty-device-value-accepted.md`

### Expected
An empty `--device` value is an argument failure: `Error: Invalid argument: '--device' must not be empty.` (or the runner's
equivalent one-line usage error), exit 64, before any device lookup or signing check runs.

### Fix direction
Validate `--device`, `--udid` and `--serial` values as non-empty (and, for simulators, UDID-shaped) at flag parsing;
one test per flag. Also check the CLI never forwards an empty device value (CLI side: refuse with the Invalid argument
line). Schedule: round 4 unless a `B3-L`/`N3` row fails on it.

## L61 — Task 1

Source: `docs/superpowers/plans/2026-10-12-coverage-issues-round2/L61-android-failure-capture-takes-5-10s.md`

### Expected
Once a step fails, the failure artefacts (screenshot, hierarchy, logcat tail) are captured within ~2 s on the default
software-rendered AVD at host load below 15, so a crash flow's wall time is the app's cold start plus a few seconds.

### Fix direction
Capture screenshot, hierarchy and logcat concurrently; take the screenshot through the UIAutomator2 server
(`GET /screenshot`, PNG over the existing socket) instead of `adb screencap` + pull when the server is alive; bound each
capture by a short deadline and record a note instead of blocking the report. Schedule: round 4 unless a `B3`/`N3` row
fails on it.

## L62 — Task 2

Source: `docs/superpowers/plans/2026-10-12-coverage-issues-round2/L62-android-02-favorite-remove-leaves-row-intermittently.md`

### Expected
`swipe: {direction: LEFT, from: "Lake Tahoe"}` reveals the row's swipe action; `tapOn: "Remove from favorites"` removes
the favourite; `assertNotVisible: "Lake Tahoe"` passes, 5 of 5, on slow and fast AVDs alike.

### Fix direction
Isolate first: (a) does the tap land on the label while the row is still animating open (Compose `SwipeToDismissBox`
anchors not settled → the click is consumed by the drag), in which case the runner should wait for the revealed action to
be stable (two identical bounds reads) before tapping, as the K97 settle rule does for screenshots; (b) or does the demo's
`onRemove` fire and the list not recompose (demo bug) — then a landmarks-demo PR. Schedule: round 4 unless a `B3`/`N3` row
fails on it.

## L64 — Task 1

Source: `docs/superpowers/plans/2026-10-13-coverage-issues-round3/L64-android-launch-passes-after-fatal.md`

### Expected

L57 requires launchApp not to pass when a fatal crash for one of the launch's PIDs is logged before it returns, even if a frame was displayed. A crash after launchApp returns may instead fail the following step. The withdrawn total wall-time target is not part of this finding.

### Acceptance criteria

These criteria isolate the observed defect. They do not replace, relax, or regrade the binding B3-L57 campaign row; its full five-run criterion and other accepted requirements must still be verified separately.

- A deterministic regression reproduces a matching fatal event between launch status reads and the success decision; launchApp returns app_crash.
- A displayed frame cannot mask a matching fatal event already observed before return.
- Healthy launch remains successful; crashes after successful return are caught by the following step.
- Five real demo crash runs preserve raw timing evidence and show no launchApp success after a matching fatal event. Failure remains within the accepted 2-second FATAL-to-failure bound.
- Preserve the existing permission batching and native-app Flutter-probe behavior; do not reintroduce the withdrawn total wall-time target.

## L65 — Task 5

Source: `docs/superpowers/plans/2026-10-13-coverage-issues-round3/L65-script-missing-steps-error-contract.md`

### Expected

With a live session, `grantiva_script {}` returns an isError result with exactly `Error: Invalid argument: 'steps' is required.` The no-session error still takes precedence without a session.

### Acceptance criteria

- Missing steps returns the agreed exact full text through ToolRegistry with a live session on both platforms.
- Tests pin the complete text and isError envelope, including the no-session precedence behavior.
- Wrong-type and empty-array handling retain their separately documented semantics.

## L66 — Task 5

Source: `docs/superpowers/plans/2026-10-13-coverage-issues-round3/L66-ios-identifier-tap-fallback.md`

### Expected

The agreed tap contract tries label, accessibility identifier, then placeholder. After opening Favorites, `grantiva_tap` with `label: "heart"` finds the tab's SF Symbol identifier and reports `Tapped on "heart" (matched by identifier)`.

### Acceptance criteria

- Reproduce the agreed label → identifier → placeholder order with the real demo on the campaign-owned iOS simulator, including the `heart` identifier and `Name` placeholder.
- Preserve the match annotation, exclusion of application elements, literal escaping, and existing error/retry behavior.
- Tests verify the actual selected WDA attributes and priority rather than merely returning a stub element on the second request.
- Update the misleading WDA `name` equivalence in source comments and `docs/mcp.md`. Query the true identifier for the identifier leg; any separately retained `name` fallback must have explicit, tested semantics and priority consistent with the binding contract.
- Re-run the full binding criteria for IOS-102, B2-K78, and iOS D2-36 on the fixed candidate; this brief does not relax them.

## L67 — Task 6

Source: `docs/superpowers/plans/2026-10-13-coverage-issues-round3/L67-doctor-ambiguous-platform-section.md`

### Expected

In a directory with both an Xcode project and Gradle settings, without a selecting flag/environment/config, `run` rejects ambiguous platform selection. `doctor` diagnoses both toolchains as advice, reports the Platform ambiguity under Advisory, and exits 0. CLI-025 cites the accepted C12 advice alternative and K35 advisory exit behavior.

### Acceptance criteria

- Put the ambiguous Platform warning under Advisory in both text and JSON.
- Preserve the useful selection guidance, advisory toolchain treatment, and doctor exit 0 even when the inspected toolchains are unavailable.
- Keep `run`'s ambiguity rejection unchanged.
- Add or adjust meaningful doctor tests for the text/JSON section and exit behavior, then re-run CLI-025 on the fixed candidate.

## L68 — Task 4

Source: `docs/superpowers/plans/2026-10-13-coverage-issues-round3/L68-android-detached-start-ready-before-app.md`

### Expected

The binding AND-127 matrix requires the Android session example to start a detached runner and immediately dump a hierarchy containing Landmarks. Help's narrower wording says the driver is up; it does not independently promise that the app is foregrounded. This finding enforces the matrix's stronger app-readiness criterion without adding a caller-side sleep.

### Acceptance criteria

- Keep startup in its starting state until the generated app-launch flow reaches the readiness required by the documented immediate hierarchy operation.
- Verify the immediate hierarchy after detached start contains the expected app on the owned Android emulator, without a caller-added sleep. Use bounded polling only for diagnosis.
- Preserve prompt failure when launch fails, bounded startup timeout, rejection of stale UIAutomator2 sessions, and existing cancellation behavior.
- Add meaningful coverage of driver-attached/app-not-yet-ready ordering, then re-run every AND-127 clause, including metadata, tool listing, stop, and forward cleanup.

## L69 — Task 4

Source: `docs/superpowers/plans/2026-10-13-coverage-issues-round3/L69-starting-runner-json-omits-null-port.md`

### Expected

A second `runner start --detach --json` during an existing session's starting window returns `status: already_running` and an explicit `port: null`, with the existing PID. README lines 414–424 and N3-03 both specify this shape. Plain text identifies the session as starting.

### Acceptance criteria

- Emit an explicit JSON null port for an already-running session that is still starting on either platform.
- Preserve numeric port for ready sessions, existing PID/device/app metadata, correct text wording, and reuse without spawning another runner.
- Add a focused lifecycle serialization test that distinguishes a missing key from a present null value; inspect both platform forms and preserve stopped-document behavior.
- Re-run N3-03 with an observed starting state and the matrix's detached first-start form on each platform.

## L70 — Task 6

Source: `docs/superpowers/plans/2026-10-13-coverage-issues-round3/L70-baseline-filename-migration-documentation.md`

### Expected

B-I16.2 requires a public note explaining the filename change. The binding matrix lines 924–925 substitutes README, public docs, or release notes for the CHANGELOG removed by #179.

### Acceptance criteria

- Add a concise public baseline/capture note describing literal filenames, legacy percent-encoded baseline compatibility, and migration on approval.
- State the actual implementation behavior without implying users must rename working legacy baselines manually.
- Recheck the note against the retained migration evidence and exact implementation. No runtime change is requested.

## L71 — Task 4

Source: `docs/superpowers/plans/2026-10-13-coverage-issues-round3/L71-no-build-no-launch-queries-absent-ios-container.md`

### Expected

`grantiva build install --no-build --no-launch` performs neither an install nor a launch and completes with the install-skipped result. D2-07 defines its JSON status as `skipped`; D2-08 requires the text `Done` line to say `(install skipped)`. The command must work whether the configured app is already installed or absent because `--no-launch` requests no operation on that app.

D2-08's main app-file forms are separate: with `--app-file`, `--no-build` skips only the build and the supplied app is installed. The failing case here is the row's no-app-file install-skipped control.

B2-K25 is compound. Its other app-file, run, diff, ordinary status, and permitted CI-authentication-boundary legs remain independently retained; this brief owns only the same absent-app skipped-install failure.

### Acceptance criteria

- `build install --no-build --no-launch` exits 0 for a valid target when the configured app is absent, performs no install or launch, and prints `Done ... (install skipped, not launched)` in text mode.
- Its JSON form reports `status: skipped` and does not fail while obtaining optional container metadata; document the absent value consistently with the existing iOS result shape.
- Preserve the current installed-app behavior, app-file installation behavior, and ordinary no-build-with-launch not-installed refusal.
- Add a focused `InstallCommand` test whose injected iOS device reports the app absent and whose data-container lookup would fail if called; assert the skipped command never requires that lookup. Retain the existing status/message and JSON key tests.
- Re-run the absent and installed controls and the D2-08 app-file build-install leg on an owned simulator.

## L72 — Task 4

Source: `docs/superpowers/plans/2026-10-13-coverage-issues-round3/L72-foreground-start-sigint-during-startup-reports-wda-timeout.md`

### Expected

A foreground `runner start` ended by SIGINT exits as an interrupt (N2-15 permits the documented interrupt result and specifies exit 130), removes its project session and `/tmp/grantiva-sessions` files, releases the device, and does not report a driver startup failure caused by that same requested interrupt. Plain, quiet, and JSON modes follow the same lifecycle contract; quiet/JSON suppress runner narration.

B3-L37 separately requires the signal notice to name the platform device kind. Its iOS expectation is `[grantiva] received SIGINT — releasing simulator and reaping child processes` in all three modes. The evidence below satisfies that notice clause; this brief does not reopen or weaken B3-L37.

### Acceptance criteria

- Interrupt a foreground `runner start` while its published session is still `starting`: plain, `--quiet`, and `--json` terminate with the documented interrupt status (exit 130 unless the public contract deliberately chooses and documents another interrupt code).
- None of the three modes prints `Timed out waiting for WDA to start` when SIGINT caused the startup wait to end. Plain mode may relay the runner's interrupt acknowledgement; quiet/JSON keep suppressing runner narration.
- Preserve the correct B3-L37 platform notice, project/global session cleanup, lease release, runner/process-group cleanup, and no forced-kill escalation for an orderly SIGINT.
- Preserve genuine WDA startup timeout and unprompted runner-death errors; do not convert those to successful or interrupted outcomes.
- Add focused `RunnerLifecycleCommandTests` for an interrupt delivered during `waitForForegroundWDAPort`, distinct from existing steady foreground-hold tests and stop-marker tests. Assert exit/error normalization and cleanup in plain/quiet/JSON output modes.
- Re-run the three starting-state variants on an owned simulator, plus one steady-ready foreground control, and retain exit codes, output streams, process/session cleanup, and signal timing.

## L73 — Task 4

Source: `docs/superpowers/plans/2026-10-13-coverage-issues-round3/L73-force-simulator-teardown-omits-stopped-runner-result.md`

### Expected

When `grantiva simulator teardown --udid <UDID> --force --json` targets a simulator with a live detached `runner start` session, it stops that runner first, removes its session files, and reports that work. D2-20(d), README/help, and the command discussion name `runnerSessionStopped` as the JSON signal for this case.

### Acceptance criteria

- A targeted `simulator teardown --udid <UDID> --force --json` that stops a live `runner start` reports `runnerSessionStopped:true`.
- Its JSON truthfully reports that teardown reclaimed/stopped the runner; it must not return `reclaimed:false` merely because the preliminary orderly stop finished before live-process inspection.
- The project and shared session files are removed, and the retained filesystem checks prove that no stale session remains. Do not require `sessionFilesRemoved` to list an orderly live-session removal if that field remains scoped to stale files.
- Preserve the existing no-op force case: a genuinely free simulator reports `reclaimed:false` and does not claim a stopped runner.
- Preserve non-force teardown behavior and helper/process arrays.
- Add a focused command test for the force path with a live runner session, distinct from the existing non-force `SimulatorTeardownOutcome` marking test.
- Re-run the ready detached-session case and retain start JSON, successful hierarchy, force-teardown JSON, process/session cleanup, and a free-simulator control.

## L74 — Task 6

Source: `docs/superpowers/plans/2026-10-13-coverage-issues-round3/L74-iso8601-json-date-change-lacks-public-note.md`

### Expected

B-C22.2 requires JSON date values to use ISO 8601 and requires a change note. Because CHANGELOG.md was removed in #179, binding matrix lines 924–925 accept the note in README, public docs, or release notes.

### Acceptance criteria

- Add a concise public README, docs, or release-note statement that date-valued JSON fields use ISO-8601 UTC strings, with an example such as `1970-01-01T00:00:00Z` or an `acquiredAt` value.
- Identify the behavior as the JSON date representation scripts should consume; do not imply that Unix or Apple-reference numeric timestamps remain a supported output alternative.
- Preserve the existing `.iso8601` encoder behavior and semantic test.
- Recheck the note against current iOS and Android session JSON. No device or runtime change is requested.

## L75 — Task 4

Source: `docs/superpowers/plans/2026-10-13-coverage-issues-round3/L75-subdirectory-cycle-hops-use-containing-file-relative-operands.md`

### Expected

For a project-root invocation whose cycle is `flows/a.yaml` → `../shared/b.yaml` → `../flows/a.yaml`, every cycle hop is rendered relative to the project working directory:

`flows/a.yaml -> shared/b.yaml -> flows/a.yaml -> shared/b.yaml`

B3-L20 and the accepted L20 brief explicitly require project-directory-relative hops. Absolute paths remain absolute only when the user supplied an absolute path.

### Acceptance criteria

- The exact subdirectory fixture prints `flows/a.yaml -> shared/b.yaml -> flows/a.yaml -> shared/b.yaml`, exits 1, and completes within five seconds.
- Preserve root-flow `a.yaml -> b.yaml -> a.yaml -> b.yaml` and screens `grantiva.yml -> a.yaml -> b.yaml -> a.yaml` output.
- Preserve user-supplied absolute paths as absolute where the contract requires them.
- Add a focused `RunnerSessionOutputTests` assertion that exercises the final merged output map for nested `../` operands, rather than testing `reachableFlowDisplayMap` alone.
- Verify both `/tmp` and `/private/tmp` source spellings still rewrite correctly.

## L76 — Task 4

Source: `docs/superpowers/plans/2026-10-13-coverage-issues-round3/L76-force-teardown-matches-unrelated-process-arguments.md`

### Expected

`grantiva simulator teardown --udid <UDID> --force` reclaims processes which actually hold that simulator: `grantiva-runner`, WebDriverAgent's `xcodebuild`, `simctl diagnose`, or a live `grantiva run`. It must not signal an unrelated process merely because its argument list mentions both the Grantiva binary path and the UDID.

### Acceptance criteria

- Process classification requires the actual executable to be Grantiva for `.grantiva`; a command such as `python3 helper.py /path/to/grantiva <UDID>` is excluded.
- Preserve matching of an actual `grantiva run ... --simulator <UDID> --keep-alive` process.
- Preserve the existing runner, WebDriverAgent, and `simctl diagnose` classifications and their device-specific guards.
- Add a focused `SimulatorReaperTests` semantic assertion using a synthetic process snapshot with an unrelated executable and Grantiva/UDID positional arguments; assert force teardown does not report, signal, or mark reclaimed from that process alone.
- Add a positive sibling assertion for an actual Grantiva executable so argument filtering cannot disable intended recovery.

## L77 — Task 2

Source: `docs/superpowers/plans/2026-10-13-coverage-issues-round3/L77-android-stop-app-reports-success-with-app-still-running.md`

### Expected

In a flow whose header supplies `appId`, the standard bare `stopApp` form inherits that app ID, terminates the application, and reports success only after the stop has taken effect. A following `assertNotVisible` may then treat the deliberately stopped app as absent rather than as a crash.

### Acceptance criteria

- On Android, the header-appId flow `launchApp: {clearState: true}` → bare `stopApp` leaves the application stopped and a following `assertNotVisible: "Landmarks"` passes.
- `stopApp` must not report success while the target package remains running or foreground. If termination does not take effect, return a clear lifecycle error naming the application ID.
- Preserve explicit `stopApp: <appId>` and mapping-form behavior as well as bare-form inheritance from the flow header.
- Add focused runner semantic assertions for the inherited-ID path and for an ineffective/failed force-stop, including the observable postcondition rather than only a zero shell exit.
- Preserve intentional-stop crash-watch semantics: a successful stop followed by a not-visible wait is absence, not `app_crash`.

## L78 — Task 4

Source: `docs/superpowers/plans/2026-10-13-coverage-issues-round3/L78-interrupted-run-returns-before-log-stream-exits.md`

### Expected

IOS-064 requires no orphan `log stream` after successful, failed, or interrupted `run --logs`. Returning from the command should mean its owned logging process has stopped. B2-K33 separately requires truthful verbose subprocess start/terminal diagnostics.

### Acceptance criteria

- Successful, failed and interrupted runs return only after their own simulator logging child has stopped; capture immediate post-exit inventories in repeated SIGINT controls.
- Cleanup remains bounded, scoped to the exact run and device, and does not stop another live run's logging process.
- A regression test models a wrapper exiting before its spawned logging child and proves cleanup waits for or safely terminates that child.
- Preserve exit130 and the single truthful verbose terminal diagnostic; plain mode remains free of debug subprocess lines.

## L79 — Task 3

Source: `docs/superpowers/plans/2026-10-13-coverage-issues-round3/L79-optional-tap-failure-exits-nonzero.md`

### Expected

A failing step with `optional: true` may wait through the runner's optional-find budget, but it must not fail the flow. It should be represented as a non-blocking warning (or otherwise as successful optional handling), later steps must continue, the flow must count as passed, and the CLI must exit 0. The same missing selector without `optional: true` must remain a required failure and exit nonzero.

This is separate from B2-L05/B3-L05's first-lookup latency contract. In the repro below, the first exact-text lookup returns with no match in 100–150 ms, well inside the two-second requirement. The approximately seven-second step duration is the intended optional polling budget, not a slow first 404 response.

### Acceptance criteria

- Run the preserved missing-selector flow at least three times. The optional tap may consume its documented optional-find budget, but each run exits 0, the flow is counted as passed, and no command/report surface calls it a required failure.
- Text, JSON, JUnit, and ready/report summaries agree on the successful overall outcome. They may expose the optional miss as a warning with its useful `element_not_found` detail.
- Add a following required step and prove it executes after the optional miss.
- Run the same missing tap without `optional: true`; it remains `element_not_found`, fails the flow, skips later required steps as appropriate, and exits nonzero.
- Add or strengthen exact runner tests that exercise the production report writer and process-exit aggregation, rather than only the in-memory runner result.
- Preserve the fast first-request behavior and the documented optional polling budget; do not “fix” the status defect by shortening or bypassing selector fallback.

## L80 — Task 5

Source: `docs/superpowers/plans/2026-10-13-coverage-issues-round3/L80-mcp-concurrent-large-responses-interleave-on-stdout.md`

### Expected

Every JSON-RPC response written by the stdio MCP server is one complete newline-delimited JSON object. Concurrent requests may complete in either order, but their response bytes must never interleave. A client reading one line at a time must be able to decode every response and associate it with its request ID.

### Acceptance criteria

- Send at least two concurrent MCP requests whose individual responses exceed 65,536 bytes. Every stdout line is independently valid JSON and contains exactly one JSON-RPC response.
- Both response IDs arrive exactly once, regardless of completion order; neither response is truncated, split across lines, or contains bytes from the other.
- Repeat the concurrent pair at least ten times and include mixed resource/tool requests.
- Preserve concurrent small-response behavior and notification delivery.
- Add a transport-level test using partial/chunked underlying writes so correctness does not depend on payload size or an operating-system pipe's atomic-write limit.

## L81 — Task 6

Source: `docs/superpowers/plans/2026-10-13-coverage-issues-round3/L81-doctor-default-ownership-note-hidden-by-booted-simulator.md`

### Expected

N3-15 requires `doctor` and `doctor --json` to say that a simulator with Grantiva's default name is not used as the default when that simulator exists but Grantiva did not create it:

`("iPhone 18 Pro" (<udid>) was not created by Grantiva, so it is not used as the default)`

The check remains advisory and the note does not change the command's exit code. The row is read-only and does not require every simulator to be shut down.

### Acceptance criteria

- Call the full `DoctorRunner.checkBootedSimulator` production entry with a booted non-default iPhone 17 Pro and an unowned default-named iPhone 18 Pro. The returned check names the booted simulator and also contains `"iPhone 18 Pro" (USER-DEFAULT) was not created by Grantiva, so it is not used as the default`.
- Repeat with the two devices in the opposite list order. The ownership note is present in both orders; simulator-list ordering cannot hide it.
- Doctor text and `--json` expose the same note. The check remains in `Advisory`, its status remains `ok` when a simulator is booted, and the note does not change either command's exit code.
- When no simulator with the default name exists, a booted non-default simulator remains the ordinary concise success with no ownership note.
- When the default-named simulator's UDID is in the active runner home's created ledger, no `was not created by Grantiva` note is emitted.
- Preserve the existing no-booted behavior, including its ownership-aware ensure fix, and preserve the `Could not list simulators` failure branch.
- Add focused `GrantivaCoreTests/DoctorTests` coverage through `checkBootedSimulator`, not only direct tests of `noBootedSimulatorCheck`.

