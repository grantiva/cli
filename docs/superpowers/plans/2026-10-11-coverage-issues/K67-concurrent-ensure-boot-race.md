# Two concurrent `simulator ensure` calls for one new name make one device, but the second call fails trying to boot it again

Severity: wrong-result
Component: cli
Platforms: ios (iOS-only: simulator provisioning path; no Android twin expected)
Rows: IOS-008 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Two `grantiva simulator ensure --name <new name>` calls started together yield exactly one device; one prints
`Created …`, the other `Reused …`, and both exit 0 with the same UDID on stdout. Source: SIMULATOR-LIFECYCLE.md:19
("Verified: two concurrent `ensure` calls for a brand-new name yield exactly one device (`Created` + `Reused`)");
matrix row IOS-008.

## Actual
One device is created (the provisioning lock works), but the call that reuses it exits 1 in 3 of 3 tries
(concurrent.out, concurrent-rerun.out, concurrent-max6.out; which of A/B loses varies). concurrent-rerun.out:
```
== A
7665ACDF-1F3D-4BB5-825C-DDB0031CD2B2
Created cov-ios-4 Race iPhone 17 (7665ACDF-1F3D-4BB5-825C-DDB0031CD2B2) — Booted
A exit=0
== B
Warning: Waiting for simulator capacity (4/4): cov-ios-1 [cov-ios], cov-ios-2 [cov-ios], cov-ios-3 iPhone 17 [cov-ios], cov-ios-4 Race iPhone 17 [cov-ios]
Warning: Waiting for simulator capacity (4/4): cov-ios-1 [cov-ios], cov-ios-2 [cov-ios], cov-ios-3 iPhone 17 [cov-ios], cov-ios-4 Race iPhone 17 [cov-ios]
Error: An error was encountered processing the command (domain=com.apple.CoreSimulator.SimError, code=405):
Unable to boot device in current state: Booted
B exit=1
```
With `GRANTIVA_MAX_SIMULATORS=6` (concurrent-max6.out) the losing call still logs
`Warning: Waiting for simulator capacity (4/6): …` although 4 of 6 slots are used: the wait is not a capacity
wait at all, it is waiting for its twin's pending reservation on the same device, and the message counts that
twin's device among the holders.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k67
unset GRANTIVA_API_KEY
rm -rf /tmp/k67 && mkdir -p /tmp/k67 && cd /tmp/k67
race() {
  ( grantiva simulator ensure --name "fix-k67 Race iPhone 17" >a.out 2>a.err; echo "A exit=$?" >>a.err ) &
  ( grantiva simulator ensure --name "fix-k67 Race iPhone 17" >b.out 2>b.err; echo "B exit=$?" >>b.err ) &
  wait; cat a.out a.err b.out b.err
  xcrun simctl list devices | grep -c "fix-k67 Race"      # 1
  grantiva simulator delete --name "fix-k67 Race iPhone 17"
}
for i in 1 2 3; do race; done
export GRANTIVA_MAX_SIMULATORS=8; race                   # the losing call still logs "Waiting for simulator capacity (n/8)"
unset GRANTIVA_MAX_SIMULATORS
grantiva simulator teardown --session-id fix-k67
```
Today: in each iteration one call exits 1 with `code=405 … Unable to boot device in current state: Booted`.

## Evidence
- findings/evidence/cov-ios/IOS-008/commands.txt
- findings/evidence/cov-ios/IOS-008/concurrent.out, concurrent-rerun.out, concurrent-max6.out (3 of 3 failing)
- findings/evidence/cov-ios/IOS-008/cleanup-delete*.out (one device to delete each time)

## Suspected cause
Located by reading; not confirmed under a debugger.
- `Sources/GrantivaCore/Simulator/SimulatorManager.swift:100-121` (`boot(nameOrUDID:ephemeral:)`): `device` is
  read once at :101 (Shutdown at that moment), then `capacity.reserve` (:107) blocks while the twin holds a pending
  record for the same UDID. When the twin finishes and the reservation is granted, :114 tests the stale snapshot
  (`if !device.isBooted`) and runs `xcrun simctl boot` on a device that is now Booted, which CoreSimulator rejects
  with 405. :118 also passes `bootedByGrantiva: !device.isBooted` from the same stale snapshot.
- `Sources/GrantivaCore/Simulator/SimulatorCapacity.swift:118-120`: a record for the same UDID that is `pending`
  under another pid returns `ReservationOutcome.full(records)`, so the caller's `onWait` prints the generic
  `capacityWait` message (SimulatorManager.swift:83-88) with the full record list, even when `records.count <
  maximum`.

## Acceptance criteria
- Re-running the repro: in 5 of 5 iterations both calls exit 0, print the same UDID on stdout, one stderr line says
  `Created …` and the other `Reused …`; `simctl list` shows one device.
- While one call waits for its twin's boot, it does not print `Waiting for simulator capacity (n/max)` when n is
  below the limit; if it says anything, the line names the device and that another Grantiva process is booting it.
- The capacity record for the device ends `active` with `bootedByGrantiva: true` (`simulator sessions --json`).
- GrantivaCoreTests/SimulatorManagerTests: with an injected executor whose device list flips from Shutdown to Booted
  while `reserve` waits, `boot` issues no `simctl boot` and returns the booted device.
- GrantivaCoreTests/SimulatorCapacityTests: a `pending` record for the same UDID held by another live pid, under
  the limit, yields a wait outcome distinct from "host full" (and the message helper renders it differently).
