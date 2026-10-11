# `simulator teardown --udid` without `--force` leaves the device's runner home behind when the device has no capacity record

Severity: wrong-result
Component: cli
Platforms: ios (iOS-only: simulator teardown and WDA device homes; no Android twin expected)
Rows: IOS-121 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
README:92: "`simulator teardown` (with or without `--force`) and `simulator delete` remove the device's home under
every installed runner version (`<runner home>/versions/<runner version>/devices/<udid>`), and teardown exits
non-zero naming any home it could not remove." Matrix row IOS-121.

## Actual
cov-ios-3 was created and booted with `simctl` (so, per README:452, a run on it takes no slot and leaves no
capacity record), then used by a `run` (IOS-020), which created its runner home.
```
$ ls -d $GRANTIVA_RUNNER_HOME/versions/*/devices/*            # homes-before.out
/Users/kyle/.grantiva-qa/runner/versions/1.1.28-grantiva.9+android-drivers-2/devices/8936CA04-E25C-4288-A0C5-27F57AA5C22B
$ grantiva simulator teardown --udid 8936CA04-… --json        # teardown-udid.out, exit 0
[

]
$ ls -d $GRANTIVA_RUNNER_HOME/versions/*/devices/*            # homes-after-teardown.out
/Users/kyle/.grantiva-qa/runner/versions/1.1.28-grantiva.9+android-drivers-2/devices/8936CA04-E25C-4288-A0C5-27F57AA5C22B
```
`simulator delete` afterwards did remove it (homes-after-delete.out), and `teardown --force` removes homes too
(IOS-016, IOS-017).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner"
unset GRANTIVA_API_KEY GRANTIVA_SESSION_ID
rm -rf /tmp/k69 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k69 && cd /tmp/k69/ios   # 4e49dc4
UDID=$(xcrun simctl create "fix-k69 iPhone 17" "iPhone 17" com.apple.CoreSimulator.SimRuntime.iOS-26-0)
xcrun simctl boot "$UDID" && xcrun simctl bootstatus "$UDID" -b >/dev/null
grantiva run --simulator "$UDID" --flow .maestro/01-browse.yaml               # builds, installs, runs; exit 0
ls -d "$GRANTIVA_RUNNER_HOME"/versions/*/devices/"$UDID"
grantiva simulator teardown --udid "$UDID" --json; echo "exit=$?"
ls -d "$GRANTIVA_RUNNER_HOME"/versions/*/devices/"$UDID"                       # still there today
xcrun simctl delete "$UDID"; rm -rf "$GRANTIVA_RUNNER_HOME"/versions/*/devices/"$UDID"
```
Today: teardown prints `[]`, exits 0, and the home is still listed.

## Evidence
- findings/evidence/cov-ios/IOS-121/commands.txt, homes-before.out, teardown-udid.out, homes-after-teardown.out,
  delete.out, homes-after-delete.out
- findings/evidence/cov-ios/IOS-020/commands.txt (how 8936CA04 was created, booted with simctl and run on)

## Suspected cause
- `Sources/GrantivaCore/Simulator/SimulatorManager.swift:285-288` (`teardown(udid:)`) only acts on capacity records
  for the UDID; with none it returns `[]` without touching anything.
- Home removal lives inside the per-record loop of `end(_:devices:)` (:294-315, removal at :308), so a device with no
  record never has its home removed. The `--force` path (`SimulatorReaper.forceTeardown`,
  SimulatorReaper.swift:213) removes homes unconditionally, which is why only the plain path is affected.

## Acceptance criteria
- Re-running the repro: `teardown --udid "$UDID"` (no `--force`) removes
  `<runner home>/versions/*/devices/<udid>` for every installed runner version and exits 0; with `--json` the output
  says which homes were removed even when no session record existed (an outcome entry with `deviceHomesRemoved`, or a
  documented equivalent).
- A home that cannot be removed makes teardown exit non-zero and name it (README:92), as the `--force` path does.
- The device itself is not shut down or deleted (it was not booted or created by Grantiva).
- GrantivaCoreTests/SimulatorManagerTests: `teardown(udid:)` with no capacity record and an existing device home in
  a temp runner home removes the home and reports it.
