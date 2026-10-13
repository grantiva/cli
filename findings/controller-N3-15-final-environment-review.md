# N3-15 final-environment review

## Verdict

**Proposed result: fail.** The final read-only rerun is valid and satisfies N3-15's stated precondition, but neither text nor JSON includes the required default-simulator ownership note. The earlier `blocked campaign simulator booted` result is stale now that the campaign's final cleanup and controller rerun are complete.

This is not a device-safety block. The row asks only for `doctor` and `doctor --json`; both commands ran without mutation, exited 0, and left the booted-device inventory byte-for-byte unchanged. The criterion does not require an empty booted inventory.

## Binding criterion and observed environment

The binding matrix at `docs/superpowers/plans/2026-10-13-round3-coverage-matrix.md:1568` says:

> Where a simulator of the default name exists that Grantiva did not create, doctor says it is not used as the default.

The final retained environment meets that condition:

- `findings/evidence/cov3-controller/N3-15-after-final-cleanup/booted-before.json` contains booted `iPhone 18 Pro` `FE441EE5-BBFC-4981-B68A-59C0DBCE26D6` on iOS 27.0. `DefaultSimulator` chooses the newest installed iPhone type (`/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCore/Simulator/DefaultSimulator.swift:15-24`), which is the same default name used by the L08 documentation and criterion.
- The retained L08 brief `docs/superpowers/plans/2026-10-12-coverage-issues-round2/L08-mcp-build-default-takes-user-simulator.md:19-35` identifies this exact name and UDID as the user's simulator that Grantiva did not create. It is also absent from the default-home created-simulator ledger `/Users/kyle/.grantiva/simulator-capacity/created.json`.
- A booted `iPhone 17 Pro` `B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C` also exists. Its presence does not negate the matrix precondition about the separate default-named device.
- `booted-before.json` and `booted-after.json` are identical. The controller did not boot, shut down, or modify either owner simulator.

## Actual result

`text.out` exits 0 and prints only:

```text
✓ Booted Simulator  iPhone 17 Pro — iOS 26.0
```

`json.out` exits 0 and likewise has one successful `Booted Simulator` record whose message is `iPhone 17 Pro — iOS 26.0`. Neither form contains `iPhone 18 Pro`, its UDID, `was not created by Grantiva`, or `not used as the default`. Both stderr files are empty.

The exit codes are correct and unaffected, but that does not satisfy the required note.

## Source explanation

Exact candidate `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCore/Doctor/DoctorRunner.swift:94-115` calls `listDevices()`, then immediately returns success for `devices.first(where: \.isBooted)`. It invokes `noBootedSimulatorCheck` only when there is no booted device. The ownership note at lines 119-128 therefore exists solely in the no-booted fix branch.

`/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests/DoctorTests.swift:252-269` tests `noBootedSimulatorCheck` directly with a shutdown, unowned default-named simulator. `testBootedSimulatorCheckNamesTheBootedDevice` at lines 279-285 covers the short-circuiting booted-device branch separately. There is no integration test for a booted non-default device plus an unowned default-named device, the exact final host state.

The implementation is internally consistent with its current helper structure, but it is narrower than N3-15. L08's product rule remains relevant while another simulator is booted: unnamed future commands still must not take the unowned default-named simulator.

## Disposition

- Replace the stale blocked result with **fail** and cite `findings/evidence/cov3-controller/N3-15-after-final-cleanup/`.
- Do not mark the row blocked on owner devices: the read-only input completed safely and the conditional default-name state was present.
- Do not correct the matrix to require an empty booted inventory. That would weaken the explicit “where a simulator of the default name exists” criterion and conceal the current branch limitation.
- A focused product fix should preserve the successful booted-simulator check while appending or otherwise exposing the unowned-default note in text and JSON. Add a `DoctorTests` case with booted `iPhone 17 Pro` plus unowned default `iPhone 18 Pro`; exit status must remain unchanged.

