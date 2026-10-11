# `simulator teardown --udid <free UDID> --force --json` reports `reclaimed: true` when nothing held the device

Severity: contract
Component: cli
Platforms: ios (iOS-only: simulator teardown path; no Android twin expected)
Rows: IOS-017 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
On a simulator that no process holds and no live lease claims, `teardown --udid <UDID> --force --json` exits 0 with
`"reclaimed": false`. Sources: README:430-447 (reclaiming a simulator); the field's own contract,
`Sources/GrantivaCore/Simulator/SimulatorReaper.swift:43-47`: "A `--force` run that found nothing is a success — the
device was already free — but it is not the same event as one that killed a stranded runner, and a script that
expected to reclaim a busy device has no other way to tell them apart"; matrix row IOS-017.

## Actual
cov-ios-2 had no run in progress (its last run had ended normally). teardown-free.out (exit 0):
```
    "deviceHomesRemoved" : [
      "\/Users\/kyle\/.grantiva-qa\/runner\/versions\/1.1.28-grantiva.9+android-drivers-2\/devices\/C2C8E2D3-F7E6-4FBF-A2FE-7A25B9363961"
    ],
    "leaseReleased" : true,
    "processes" : [

    ],
    "reclaimed" : true,
    "sessionFilesRemoved" : [

    ],
```
No process was killed and no session file removed, yet `leaseReleased: true` and `reclaimed: true`. The text form
would print `Released the simulator lease for <udid>.` for the same non-event.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k68
unset GRANTIVA_API_KEY
rm -rf /tmp/k68 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k68 && cd /tmp/k68/ios   # 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k68 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID" --no-launch
grantiva run --no-build --simulator "$UDID" --flow .maestro/01-browse.yaml     # ends normally, exit 0
ls "$HOME/.grantiva-qa/runner/locks/" | grep "$UDID"                          # the lock file is still there
grantiva simulator teardown --udid "$UDID" --force --json | grep -E '"(reclaimed|leaseReleased)"'
grantiva simulator teardown --session-id fix-k68
```
Today: `"leaseReleased" : true`, `"reclaimed" : true`. (If the lock directory differs on your host, find it with
`grep -n leasePath Sources/GrantivaCore/Runner/SimulatorLease.swift`.)

## Evidence
- findings/evidence/cov-ios/IOS-017/commands.txt, teardown-free.out
- findings/evidence/cov-ios/IOS-057/ (note in the results: `<runner home>/locks/` keeps one .lock per UDID ever used)
- Contrast: findings/evidence/cov-ios/IOS-016/ (a real reclaim after kill -9: `reclaimed: true` is right there)

## Suspected cause
- `Sources/GrantivaCore/Runner/SimulatorLease.swift:219-224` (`forceRelease`): returns `true` whenever the lock file
  exists, then deletes it. A released lease leaves its file behind (`release()` at :233-246 truncates the claim and
  unlocks but never removes the file), so every UDID that has ever run reports `leaseReleased: true`.
- `Sources/GrantivaCore/Simulator/SimulatorReaper.swift:68`: `reclaimed = !processes.isEmpty || leaseReleased ||
  capacityRecordsCleared > 0`, so the false `leaseReleased` alone flips `reclaimed`.

## Acceptance criteria
- Re-running the repro: `"reclaimed": false`, `"leaseReleased": false`, `processes: []`, exit 0; the text form prints
  `No processes were holding <udid>.` and no `Released the simulator lease` line.
- After `kill -9` of a `run --keep-alive` (IOS-016 setup), `teardown --udid --force --json` still reports
  `reclaimed: true` and `leaseReleased: true`.
- `leaseReleased` is true only when the lease was held: its flock is held by another process, or the file carries
  a live (non-stale) claim such as a `runner start` hand-off.
- GrantivaCoreTests/SimulatorLeaseTests: `forceRelease` on an unlocked lock file with an empty claim returns false;
  with the flock held by a child process, or with a live hand-off claim, it returns true and the next `acquire`
  succeeds.
- GrantivaCoreTests/SimulatorReaperTests: a forced teardown with no processes and only a stale lock file yields
  `reclaimed == false`.
