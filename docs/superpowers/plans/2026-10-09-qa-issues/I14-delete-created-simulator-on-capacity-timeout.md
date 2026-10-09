# Delete a simulator that `ensure` created when the capacity wait times out

Severity: ux
Platforms: ios
Found by: IOS-F13 (matrix rows IOS-012, IOS-013)
Binary: grantiva 2.0.1 (commit c8dc86d), Xcode 27.0, iPhone 17 / iOS 26.0 simulators

## Expected
A timed-out `ensure` leaves the host as it found it. Source: README.md:379-382 (capacity policy,
`GRANTIVA_SIMULATOR_WAIT_TIMEOUT_SECONDS`); help: simulator ensure.

## Actual
```
Warning: Waiting for simulator capacity (2/2): iPhone 17 Pro [simulator:B27D7D31-...], qa-ios-1 [qa-ios]
Error: Timed out after 5s waiting for a Grantiva simulator slot (limit 2). Active: iPhone 17 Pro [...], qa-ios-1 [qa-ios].
Release one with `grantiva simulator teardown --session-id <id>`. exited with code 1
```
exit 1, and `qa-ios-2` (FD381223) was created and left behind, Shutdown, registered as Grantiva-created. (The trailing
" exited with code 1" is covered by A10's iOS detail.)

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_SESSION_ID=qa-ios
grantiva simulator ensure --name qa-ios-1 --device-type "iPhone 17" --runtime 26.0
xcrun simctl list devices | grep -c qa-ios-2                                             # 0
GRANTIVA_MAX_SIMULATORS=1 GRANTIVA_SIMULATOR_WAIT_TIMEOUT_SECONDS=5 \
  grantiva simulator ensure --name qa-ios-2 --device-type "iPhone 17" --runtime 26.0; echo "exit $?"
xcrun simctl list devices | grep qa-ios-2                                                # left behind
grantiva simulator delete --name qa-ios-2
```
(Use a limit at or below the current `simulator sessions` count.)

## Evidence
- findings/evidence/triage/F13.err, F13.out (empty)
- findings/evidence/IOS-012/err.txt

## Suspected cause
Sources/GrantivaCore/Simulator/SimulatorManager.swift:129-149: the device is created and registered in provenance under
the provisioning lock (:142-143), then `boot()` (:149) waits for capacity and throws on timeout; nothing deletes the
just-created device on that error.

## Acceptance criteria
- Re-running the repro: after the timeout, `qa-ios-2` does not exist and its provenance entry is gone; a pre-existing
  device with that name is left untouched.
- Prefer reserving capacity before `simctl create`, or wrap the boot in a do/catch that deletes a device with
  `created == true`.
- GrantivaCoreTests/SimulatorManagerTests: with a fake shell and a capacity store that times out, `ensure` issues
  `simctl delete <udid>` for a device it created and not for a reused one.
