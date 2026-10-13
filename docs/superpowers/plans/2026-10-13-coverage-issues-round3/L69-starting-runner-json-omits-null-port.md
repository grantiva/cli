# Starting runner JSON omits the promised null port

Severity: contract
Component: cli / runner lifecycle JSON
Rows: N3-03 [ios], N3-03 [android]
Candidate: CLI 8f2cff676b3c12e951478920fa20e600cdca4e29.
Status: confirmed by the completed round-3 coverage pass; open for the round-4 fix wave.
Regression: round-3 L38-a starting-state contract and N3-03; the row originates in the round-3 fix wave (CLI #200–#203, with #205 lifecycle addendum).

## Expected

A second `runner start --detach --json` during an existing session's starting window returns `status: already_running` and an explicit `port: null`, with the existing PID. README lines 414–424 and N3-03 both specify this shape. Plain text identifies the session as starting.

## Actual

The second JSON start identifies the existing runner with `status: already_running` but omits `port` entirely. The corresponding plain start correctly prints `Runner already running (pid 20340, starting)`.

## Evidence and repro

- iOS slice `findings/evidence/cov3-ios-attempt47/` preserves the harness, observed starting session, second JSON/plain commands and verbatim output. `second-json.out` has no port key; `second-text.out` identifies the same PID and starting state.
- The harness starts the first runner in the foreground, then issues the second detached JSON/plain starts while its session file directly records starting. This proves the shared already-running response path; it does not claim the first command was detached.
- Exact candidate `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCLI/DriverCommand.swift:161` passes nil port for a session that is not ready.
- At the same HEAD, `Sources/GrantivaCLI/RunnerLifecycleDocument.swift:48` encodes nil port only if `nullWhenUnrecorded` is true. The start path leaves its default false.
- Independent source/evidence review: CLI slice `findings/n3-01-n3-03-source-triage.md`, commit b18ffb48. No product source was changed during coverage.
- Android slice `findings/evidence/cov3-android/starting-session-contracts-rerun4/` reproduces the same omission with the exact first-detached form. Its frozen helper starts the first detached command asynchronously, observes `state: starting` at 100 ms, then captures second JSON/plain starts identifying the same runner PID. `run/second-json.out` again omits port; `run/second-text.out` has the starting wording. The same MCP process subsequently succeeds after readiness. Independent review: CLI `findings/ios53-android-startupv4-constraints-review.md`.

## Cause

The start command constructs the intended nil value, but the custom JSON encoder drops it. Its explicit-null switch currently serves stopped documents and is not enabled for this starting response.

## Acceptance criteria

- Emit an explicit JSON null port for an already-running session that is still starting on either platform.
- Preserve numeric port for ready sessions, existing PID/device/app metadata, correct text wording, and reuse without spawning another runner.
- Add a focused lifecycle serialization test that distinguishes a missing key from a present null value; inspect both platform forms and preserve stopped-document behavior.
- Re-run N3-03 with an observed starting state and the matrix's detached first-start form on each platform.
