# Task 9 twin-boot failure diagnosis

2026-10-13. Read-only diagnosis of frozen candidate CLI `6ba12ed37658228a3ce87cb64e1f5d88dda38e07`. No tests, reruns, builds, device commands, network calls, product edits, reviewer dispatch, or implementer dispatch were performed. This document is the only intended write.

## Finding

The failure is consistent with a concrete production concurrency defect: a device snapshot taken before the registry lock can delete a newly activated twin's record, including `bootedByGrantiva: true`. The replacement record then becomes active with a nil ownership flag. The source permits this interleaving; the captured test output does not trace the interleaving, so it does not prove that this precise schedule occurred. Treat this as a source-supported production race requiring a deterministic regression, not as a dismissed flaky fixture.

The test's 200 ms sleep makes exposure schedule-dependent, but its expected ownership invariant is valid. A later passing attempt would not disprove the race or replace this campaign failure.

## Preserved evidence

Raw directory: `/private/tmp/grantiva-round4-source-window-1stf8uih/swift/commands/swift-full/`.

- `start.json`: `swift test`, candidate source directory `/Users/kyle/Developer/grantiva-cli/.worktrees/release-round4-candidate3`, clean HEAD above, tracked tree SHA256 `38f8c40f34c3f51f77cb0a63123b64499eeab9d83d286936b93a6dbe2c276341`; API key unset and separate fresh runner homes.
- `result.json`: exit 1, no timeout, elapsed 201.9355458 seconds. stdout SHA256 `3856014c71f664d7ee14ff5fdf0fc5a35df6183ea5bd2b543f156b5ff2a781ff`; stderr SHA256 `b87df8997b352327aa1a773f862cf3d5f6303fc3f64385c5aaa94585afabfe62`.
- `stdout.bin:2512–2522`: `testBootWaitingOnATwinsBootIssuesNoSecondBoot`, sole assertion failure at `Tests/GrantivaCoreTests/SimulatorManagerTests.swift:503`, nil versus `Optional(true)`; test duration 0.484 seconds. The preceding booted-state, one-boot, unwrap, and active-state assertions did not fail.
- `stdout.bin:2868–2871`: GrantivaCoreTests/full core test bundle reports 975 tests and one failure. Other bundle summaries must not be mistaken for an overall successful command.
- `stderr.bin`: build completed; no compiler failure.
- `postflight.json`: failed for `command-exit-or-timeout`; both fresh-home roots remain absent; source HEAD/tree/status unchanged. Home hygiene succeeded independently of suite correctness.
- Historical `findings/evidence/fix4-85/tests/full-green.raw:2516–2525` contains the same nil-versus-true failure, despite its filename. The historical retry reported by the controller is not current-candidate coverage evidence.

The controller reports all ten focused groups passed. Those filters do not include this SimulatorManager test and cannot satisfy an independently required full-suite pass.

## Exact source path and admissible schedule

All source line numbers below refer to the frozen candidate, not the regression worktree's working source.

1. `SimulatorManagerTests.swift:470–492` creates one Shutdown fake device and a private UUID directory; seeds a same-session pending record with live foreign PID 1 and `ephemeral: false`; schedules a finisher that sleeps, boots the fake, then calls `capacity.activate(..., bootedByGrantiva: true)`.
2. `SimulatorCapacity.swift:135–138` calls `await devices()` **before** acquiring `withRegistryLock`. A waiter can capture a Shutdown list and be delayed before acquiring the registry lock. In the manager path the returned JSON must also be decoded (`SimulatorManager.swift:35–39`).
3. The twin completes boot and activation during that gap. `SimulatorCapacity.swift:204–208` writes the seeded record as active/true under the registry lock.
4. The waiter now acquires the lock and prunes against its earlier Shutdown snapshot. `SimulatorCapacity.swift:348–365` keeps Booted records and pending records, but removes an active record whose snapshot state is Shutdown. The live PID and durable flag do not protect this active record from the final removal branch.
5. No record remains for the UDID. `SimulatorCapacity.swift:155–166` constructs a fresh pending record owned by the waiter. The initializer's default ownership flag is nil (`SimulatorCapacity.swift:31–43`). The true flag was lost by deletion/replacement, not overwritten by `activate(false)`.
6. `SimulatorManager.swift:127–133` refreshes device state after reserving. It now sees Booted, correctly skips another boot, and calls `activate(..., bootedByGrantiva: false)`. Activation sets active but changes the ownership flag only when its argument is true. The replacement therefore remains nil.
7. Awaiting `finisher.value` in the test ensures activation finished, but cannot restore a record replaced *after* that activation. Final state is Booted, one boot command, one active record, nil ownership: precisely the observed assertion pattern.

`FakeSimctl` serializes device snapshots and state mutation using its own `NSLock` (`SimulatorManagerTests.swift:639,653–674`). The registry uses a separate `flock` (`SimulatorCapacity.swift:326–345`). Neither lock joins the device snapshot and registry update into one consistent observation. There is no need to assume corrupt JSON, a fake-device data race, another test deleting the directory, a dead twin, or an inherited runner home to explain this result. PID 1 and direct activation model the foreign owner without a second process; the same ordering is possible between actual CLI processes and actual simctl snapshots. The fake omits bootstatus delay, but real activation after bootstatus still permits the waiter to hold an older device snapshot.

The broader `sessions(devices:)` pruning entry also consumes an externally obtained device snapshot (`SimulatorCapacity.swift:303–309`); a later fix should audit it for the same consistency issue. This observation is not a claim of another live failure.

## Consequence and uncertainty

The concrete lost flag affects teardown: `SimulatorManager.swift:395–409` shuts down a booted simulator only when `bootedByGrantiva == true`, and deletes a booted created simulator only under that ownership condition. A nil record can therefore release bookkeeping while leaving a Grantiva-booted simulator running (and, if created, undeleted). That is a source-derived consequence, not an executed teardown observation in this campaign.

The current raw log has no registry generations, owner-PID assertion, or snapshot/lock event trace. It cannot uniquely establish the schedule above. A deterministic source test is required in a later fix wave before claiming the root cause experimentally confirmed. No live double-boot failure is claimed: the one-boot assertion passed, and K67's existing refresh appears to address that original symptom.

## Coverage impact and brief disposition

- Retain `swift-full` as failed. Do not rerun to replace it during frozen coverage or alter the candidate in place.
- The source-window inventory explicitly binds `swift-full` to `B4-L82.1`, `B4-L82.2`, `B4-L82.5`, `B4-L84.4`, and `B4-L85.5`. Their full-suite component is unsatisfied even where focused regressions pass. In particular, L82.5 requires focused/full fresh-home tests to pass; L84.4 and L85.5 retain the full-suite/provenance requirement. This does not establish a regression in their specific foreground, orphan, or selector behaviors.
- `B2-K67` directly requires the final record to be active with `bootedByGrantiva: true`; its source acceptance is contradicted by the fresh test result. Preserve any separately observed live outcome as separate evidence instead of turning this unit result into an invented live execution.
- `IOS-008` (concurrent ensure) and `D2-21` (concurrent creation plus correct teardown) are related live behaviors that need targeted later verification. `B-I08.2` is the related ownership contract; no new live verdict is asserted here. The absence of runner-home writes supports only the hygiene portion of `B2-K107-b`, not a full-suite pass.

Proposed disposition: reopen existing **K67**, with a clearly scoped addendum titled “Stale pre-lock device snapshot loses twin boot ownership.” Its acceptance criterion already explicitly covers this flag, so a new unrelated brief would obscure the connection. Preserve the original double-boot evidence and label the new mechanism separately. If campaign policy requires a new round-4 identifier, file that identifier as a linked K67 regression, with CLI/iOS simulator-capacity ownership scope and the evidence above. No brief status or matrix verdict was edited by this diagnosis.

## Proposed deterministic tests for a later fix wave — not executed

1. **Minimal capacity regression without sleeps or devices:** create a private registry with the same pending live-foreign-PID durable record. Invoke `reserve(device: shutdownDevice, devices: ...)`. In the injected `devices` closure, first retain `[shutdownDevice]` as the captured snapshot, then call `activate(udid:, bootedByGrantiva: true)`, then return that retained Shutdown snapshot. This explicitly orders snapshot → twin activation → reserve's lock/prune. Assert the acquired and stored records retain true and the original owner/acquiredAt rather than becoming a replacement. On the current source, that sequence necessarily reaches the remove-and-recreate branch. If a fix revalidates snapshots, have subsequent closure calls return Booted.
2. **Manager regression:** replace the 200 ms timing assumption with a scripted executor or asynchronous barrier. Return Shutdown for the initial exact lookup. On the reserve-list request, capture Shutdown JSON, then simulate the twin's single boot and true activation, and only then release the captured JSON to the waiter. Later lists return Booted. Assert one boot total, returned Booted state, retained active/true record, and stable ownership. The gate must be outside the fake's NSLock to avoid locking the fake recursively.
3. **Teardown consequence regression:** with the created provenance entry and the record resulting from the deterministic manager interleaving, assert teardown shuts down and deletes the owned created simulator. Keep the existing manually booted-device control, which must still remain running.
4. **Fix acceptance:** make stale device snapshots unable to invalidate registry changes newer than the observation, while preserving genuine stale-record pruning, pending-twin waiting, capacity bounds, foreign-session refusal, and manual-device ownership. Evaluate a registry generation/revalidation design or equivalent consistent protocol; do not simply assign true whenever the refreshed device is Booted, since it may have been booted externally. Audit other snapshot-fed prune callers.
5. Only after the frozen campaign records its failure and a separately authorized fix wave begins: run deterministic regressions, the relevant SimulatorCapacity/SimulatorManager siblings, and focused/full suites in separate fresh homes with API key unset; retain red/green raw outputs, independent review, required CI, and replacement candidate provenance. Live concurrent-ensure and teardown verification must use an owned simulator under that later authorization. No retry-only resolution is sufficient.
