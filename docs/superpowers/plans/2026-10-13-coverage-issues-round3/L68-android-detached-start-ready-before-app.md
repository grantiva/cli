# Android detached start reports ready before the app is ready

Severity: contract
Component: cli / runner lifecycle
Row: AND-127
Candidate: CLI 8f2cff67, runner fd9d8e8 / 1.1.28-grantiva.13.
Status: confirmed by the completed round-3 coverage pass; open for the round-4 fix wave.

## Expected

The binding AND-127 matrix requires the Android session example to start a detached runner and immediately dump a hierarchy containing Landmarks. Help's narrower wording says the driver is up; it does not independently promise that the app is foregrounded. This finding enforces the matrix's stronger app-readiness criterion without adding a caller-side sleep.

## Actual

Detached start succeeds and writes `state: "ready"`, but an immediate hierarchy contains Android System UI rather than the app. The app appears shortly afterward. This reproduced twice and again in an isolated run without concurrent iOS or Android starts.

In the isolated run, start returned at epoch 1791868741.460259. The first hierarchy poll began about 37 ms later and contained no Landmarks; the next began about 1.18 s after return and contained three Landmarks matches. These are observations, not a proposed timing threshold. The daemon executed the correct Android `launchApp` (1.5 s) and animation wait (376 ms).

## Evidence and repro

- Android `findings/evidence/cov3-android/AND-126-127-exact-rerun1/` preserves the initial ready session, system-only hierarchy, tool list, and stop/forward cleanup.
- `AND-127-exact-rerun1/` additionally proves the installed app works through a successful browse flow before detached start repeats the failure.
- `AND-127-isolated-poll-rerun2/` preserves commands, start/return epochs, session-at-return JSON, numbered hierarchy polls, generated flow, daemon log, and cleanup. Run its frozen controller script only against the campaign-owned emulator with no concurrent starts.
- Independent review: CLI `findings/AND127-detached-start-triage.md`.

## Cause supported by source and runtime

Candidate `Sources/GrantivaCLI/DriverCommand.swift` generates a launch-and-settle flow, but Android detached readiness waits for UIAutomator2 attachment and records ready without waiting for that flow's app launch to finish. The immediate and later trees corroborate this ordering.

The shared temporary session-flow path is a separate unproven concurrency risk. The isolated reproduction executed the correct Android flow, so do not attribute this finding to cross-platform file contamination.

## Acceptance criteria

- Keep startup in its starting state until the generated app-launch flow reaches the readiness required by the documented immediate hierarchy operation.
- Verify the immediate hierarchy after detached start contains the expected app on the owned Android emulator, without a caller-added sleep. Use bounded polling only for diagnosis.
- Preserve prompt failure when launch fails, bounded startup timeout, rejection of stale UIAutomator2 sessions, and existing cancellation behavior.
- Add meaningful coverage of driver-attached/app-not-yet-ready ordering, then re-run every AND-127 clause, including metadata, tool listing, stop, and forward cleanup.
