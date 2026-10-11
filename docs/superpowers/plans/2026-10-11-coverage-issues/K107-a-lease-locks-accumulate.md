# Simulator lease lock files are never pruned, so `<runner home>/locks/` keeps one file per device ever seen, deleted ones included

Severity: ux
Component: cli
Platforms: both (the lease is shared; `emulator-5556.lock` and `emulator-5598.lock` sit in the same directory)
Rows: IOS-057 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9
Split: IOS-057's lock directory shows two separate causes. K107-a (this brief) is the product leaving lock files for
real devices, including deleted simulators. K107-b is the unit-test suite creating `FAKE-…`/`TEST-REPORT-…` lock files
in the real runner home.

## Expected
README:76 says Ctrl-C on a `--keep-alive` run releases the session; the matrix (IOS-057) expects the lease to be
released, and that part passed. Beyond that, per-device state should not outlive the device: once a simulator (or
AVD) is deleted, nothing keyed by its UDID should stay under the runner home. The WDA device homes already follow this
rule (WDADeviceHome.swift:57-58: "Homes of simulators `existingDeviceIDs` no longer lists are removed"); the lock
files sitting next to them do not.

## Actual
After the SIGINT cleanup, which worked (runner, WDA and session files gone, lease free),
`ls $GRANTIVA_RUNNER_HOME/locks` lists 694 lock files (`findings/evidence/cov-ios/IOS-057/after.out:4-23`, first
entries):
```
156F8C50-0778-44FC-B4C3-FE38C6426882.lock
1745A949-CF2E-4E29-8C70-28C36806D398.lock
…
7062C1E5-DE78-4FD4-A9D3-D6A3CFFBFB42.lock
7C290C8F-0CB2-4601-A5D6-44E952F58929.lock
8936CA04-E25C-4288-A0C5-27F57AA5C22B.lock
…
emulator-5556.lock
emulator-5598.lock
```
By name: 16 simulator UDIDs (including `8936CA04…` and `7062C1E5…`, simulators deleted earlier in the slice), 2
emulator serials, 1 `install-<runner version>.lock`, and 675 test identifiers (468 `TEST-REPORT-<UUID>`, 206
`FAKE-<UUID>`, 1 `AAAA-1111`; see K107-b).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k107
unset GRANTIVA_API_KEY
rm -rf /tmp/k107 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k107 && cd /tmp/k107/ios   # main 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k107 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID"
grantiva run --simulator "$UDID" --no-build --flow .maestro/01-browse.yaml; echo "exit $?"
ls "$GRANTIVA_RUNNER_HOME/locks/$UDID.lock"
grantiva simulator teardown --session-id fix-k107; grantiva simulator delete --name "fix-k107 iPhone 17"
xcrun simctl list devices | grep -c "$UDID"            # 0: the simulator is gone
ls "$GRANTIVA_RUNNER_HOME/locks/$UDID.lock"           # still there
# a later run on any other simulator prunes the deleted device's WDA home but leaves (or re-creates) its lock file
```
Today: the lock file exists after the run, after teardown, and after the simulator is deleted.

## Evidence
- findings/evidence/cov-ios/IOS-057/after.out (directory listing after the SIGINT cleanup), before.out, commands.txt
- findings/cov-ios-results.md row IOS-057

## Suspected cause
- Sources/GrantivaCore/Runner/SimulatorLease.swift:48-50, :62-78: `acquire` creates `<runner home>/locks/<udid>.lock`
  with `O_CREAT`.
- SimulatorLease.swift:233-247: `release()` truncates the claim, unlocks and closes, but never unlinks the file. That
  is the usual choice for `flock` files: unlinking a locked file lets a waiter that already opened the old inode lock a
  file nobody else can see.
- Only `forceRelease` (SimulatorLease.swift:219-224) unlinks, and only `simulator teardown --force`
  (SimulatorReaper.swift:202) and `runner stop` (DriverCommand.swift:679) call it. `simulator delete` and plain
  `teardown` do not.
- Sources/GrantivaCore/Runner/WDADeviceHome.swift:86-94: pruning the home of a simulator that no longer exists first
  takes `SimulatorLease.acquire(udid: other, …)` (line 91), which creates a lock file for the deleted device if it did
  not have one, removes the home, and releases without unlinking. So pruning itself leaves a lock file for every
  deleted device.

Fix direction: make unlink-on-release safe by having `acquire` check, after `flock` succeeds, that the descriptor's
inode still matches the path (`fstat` vs `stat`) and retry when it does not. Then `release()` can unlink, and the
WDADeviceHome prune (and `simulator delete`) can remove a deleted device's lock while holding it.

## Acceptance criteria
- After a run ends (normally, by Ctrl-C, or by `teardown`), no `<udid>.lock` remains for that device, or one remains
  only while the device exists and is pruned with its WDA home once it is deleted.
- `simulator delete` removes the deleted device's lock file when no run holds it.
- Two concurrent `acquire` calls on the same UDID while a third releases and unlinks still give exactly one owner.
- `install-<version>.lock` is not affected.
- Unit tests in `GrantivaCoreTests/SimulatorLeaseTests.swift`: `testReleaseRemovesTheLockFile`,
  `testAcquireRetriesWhenTheLockFileWasUnlinkedWhileWaiting`; and in `WDADeviceHomeTests.swift`
  `testPruningADeletedDevicesHomeLeavesNoLockFile` (lease directory under the test's temp home).
