# Count and tear down only simulators Grantiva booted itself, and expire records whose owner is dead

Severity: contract
Platforms: ios
Found by: IOS-F09, IOS-F10 (matrix rows IOS-020, IOS-010, IOS-011)
Binary: grantiva 2.0.1 (commit c8dc86d), Xcode 27.0, iPhone 17 / iOS 26.0 simulators

## Expected
"Only simulators Grantiva boots count toward the limit; manually booted Xcode simulators are never shut down by Grantiva
teardown." Source: README.md:380-382; SIMULATOR-LIFECYCLE.md; SimulatorManager.swift:167-168 ("pre-existing devices the
session merely booted are only shut down").

## Actual
- IOS-F09: after `xcrun simctl boot <udid>` and a `run` against it, `simulator sessions` lists it (3/4 → 4/4), and
  `teardown --session-id qa-ios-manual --json` returns `"deleted" : false` with the device now `(Shutdown)`.
- IOS-F10: a record from a run without `GRANTIVA_SESSION_ID` never expires. The user's iPhone 17 Pro held a slot all
  session (owner pid dead, acquired ~40 h earlier) and blocked others:
```
Grantiva-managed simulator sessions (3/4):
  iPhone 17 Pro (B27D7D31-...) — simulator:B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C [active]
Warning: Waiting for simulator capacity (2/2): iPhone 17 Pro [simulator:B27D7D31-...], qa-ios-1 [qa-ios]
```
  The only way to clear it, `teardown --session-id simulator:B27D7D31-...`, would also shut that device down.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH"
rm -rf /tmp/qa-ios-app && cp -R /Users/kyle/Developer/landmarks-demo/ios /tmp/qa-ios-app && cd /tmp/qa-ios-app
u=$(xcrun simctl create qa-ios-manual com.apple.CoreSimulator.SimDeviceType.iPhone-17 com.apple.CoreSimulator.SimRuntime.iOS-26-0)
xcrun simctl boot $u && grantiva build install --simulator $u
grantiva simulator sessions
GRANTIVA_SESSION_ID=qa-ios-manual grantiva run --no-build --flow .maestro/01-browse.yaml --simulator $u
grantiva simulator sessions                                       # qa-ios-manual now listed
grantiva simulator teardown --session-id qa-ios-manual --json; xcrun simctl list devices | grep qa-ios-manual   # Shutdown
xcrun simctl boot $u; grantiva run --no-build --flow .maestro/01-browse.yaml --simulator $u   # no session id
grantiva simulator sessions --json | grep -A3 "simulator:$u"      # record stays after the run's pid exits
xcrun simctl delete $u
```

## Evidence
- findings/evidence/IOS-020/{sessions-before.txt,sessions-after-run.txt,teardown.json,state-after-teardown.txt}
- findings/evidence/IOS-010/sessions.json, IOS-011/wait-stderr.txt, triage/F13.err, triage/F25-sessions-before.txt

## Suspected cause
- Sources/GrantivaCore/Simulator/SimulatorManager.swift:45-64: `boot()` reserves (:48) and activates (:58) a capacity record
  even when `device.isBooted` is already true (:54), so a manually booted device becomes "Grantiva-managed".
- SimulatorManager.swift:169-188: `teardown(sessionId:)` shuts down every booted device with a record (:176-177).
- Sources/GrantivaCore/Simulator/SimulatorCapacity.swift:62 gives session-less runs owner `simulator:<udid>`, and `prune`
  (:186-199) keeps any record whose device is Booted, even when `ownerPID` is dead.

## Acceptance criteria
- Re-running the repro: the manual device is never listed by `simulator sessions`, `teardown` leaves it Booted, and a
  session-less record disappears once its owner pid is dead.
- `boot()` records whether Grantiva booted the device (e.g. `bootedByGrantiva`); a pre-booted device takes no slot (or a
  non-counting lease) and teardown never shuts it down. Active records whose owner pid is dead and which have no session
  ID are pruned.
- GrantivaCoreTests/SimulatorCapacityTests: `prune` drops an active `simulator:<udid>` record with a dead pid; a
  SimulatorManager test with a fake shell asserts no `simctl shutdown` for a device that was already booted.
