# L86 — Twin boot can lose simulator ownership metadata

Status: open, initial source finding; full-round triage pending.
Severity: wrong-result / resource ownership. Component: CLI simulator capacity. Platform: iOS.
Reopens the ownership clause of [K67](../2026-10-11-coverage-issues/K67-concurrent-ensure-boot-race.md); this is one finding, not a second count for K67.
Frozen CLI source: `6ba12ed37658228a3ce87cb64e1f5d88dda38e07`. Candidate manifest SHA-256: `d833797d30a794d8cfe9d2dc4646329d4f791667eb8dfa5d17cf417d827f744e`.

## Expected

A waiter reusing a simulator booted by another Grantiva process retains an active capacity record with `bootedByGrantiva: true`. It issues no second boot. K67 explicitly requires both properties, and the existing SimulatorManager regression asserts them. Later teardown must retain the distinction between Grantiva-booted and manually booted devices.

## Actual

The fresh full Swift suite executed 2,024 tests, with 2,023 passing and one failure. `SimulatorManagerTests.testBootWaitingOnATwinsBootIssuesNoSecondBoot` failed at line 503: ownership was nil instead of `Optional(true)`. Booted state, one boot command, and active record assertions did not fail. Command exit was 1 after 201.94 seconds. All ten separately scoped Swift command groups passed; none substitutes for the full-suite result. Both fresh runner-home roots remained absent and frozen source remained clean.

The same assertion failed historically during L85 source validation and passed on its historical retry. That history does not erase this fresh failure or establish harmless flakiness. No current retry or source fix has occurred. A live leaked simulator is not claimed from this unit evidence.

## Repro

Observed command was `swift test` from `/Users/kyle/Developer/grantiva-cli/.worktrees/release-round4-candidate3`, API key unset, with distinct initially absent GRANTIVA_RUNNER_HOME and MAESTRO_RUNNER_HOME beneath `/private/tmp/grantiva-round4-source-window-1stf8uih/swift/commands/swift-full/`. Exact argv/environment are in the retained start record. This timing-dependent full-suite observation is not a promise that a blind retry reproduces it.

For the later fix wave, add a deterministic regression that captures a Shutdown device snapshot, activates the seeded twin record with true, and only then returns the old snapshot to `reserve`. Do not run this proposal or alter the candidate during frozen coverage.

## Evidence

- `findings/evidence/round4-coverage/source-window/swift/commands/swift-full/{start.json,result.json,stdout.bin,stderr.bin,postflight.json}`.
- `findings/evidence/round4-coverage/source-window/swift-archive.json`: byte-exact archive and bundle counts.
- `findings/reviews/fix4-task9-twin-boot-failure-diagnosis.md`: source path, admissible schedule and limits.
- `findings/reviews/fix4-task9-swift-focused-go-evidence-review.md`: independently accepted evidence preserving NONPASS.
- `findings/evidence/round4-coverage/source-window/closeout.json`: failed full-suite joins B4-L82.1/.2/.5, B4-L84.4 and B4-L85.5. These failures do not independently prove regressions in those rows' foreground/orphan/selector behavior.

## Suspected cause

Source permits a stale-snapshot race. `SimulatorCapacity.reserve` awaits device enumeration before taking the registry lock. A twin can boot and activate its record in the gap. The waiter then prunes the newly active record against an older Shutdown snapshot and replaces it with a pending record whose ownership flag is nil. The manager's later refresh sees Booted, correctly skips another boot, and activates without setting true; the replacement stays nil.

This schedule is source-supported and matches the observed assertion pattern, but the actual runtime interleaving was not traced. Other snapshot-fed prune entry points need evaluation during the fix. A later teardown can consequently omit shutdown/deletion under its ownership checks; that consequence is inferred from source, not a newly executed teardown observation.

## Acceptance criteria

- Add a deterministic failing regression for snapshot → twin activation → registry prune/claim ordering, without sleep-based scheduling, and preserve its red/green evidence.
- Retain the original record's Grantiva boot ownership through that ordering, while still preventing a second boot. Do not assign true merely because a device is currently Booted.
- Preserve real stale-record pruning, pending-twin coordination, capacity limits, foreign-session refusal, and manually booted-device protection. Audit other snapshot-fed prune callers for the same consistency issue.
- Test the resulting teardown ownership behavior, including a Grantiva-created/booted device and the manual-device control.
- Run relevant SimulatorCapacity/SimulatorManager regressions and focused/full suites in separate fresh homes with the API key unset; record source identity and unchanged home hygiene. A retry-only resolution is insufficient.
- Verify concurrent ensure and ownership-aware teardown on a separately allocated simulator in the later fix wave, preserving every original coverage verdict. Obtain independent review and required CI before merging; promote a new frozen candidate before claiming a clean campaign.
