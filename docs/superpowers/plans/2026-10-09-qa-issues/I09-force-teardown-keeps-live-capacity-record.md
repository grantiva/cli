# Keep a live session's capacity record in `teardown --udid --force`, and remove the killed runner's session files

Severity: contract
Platforms: ios
Found by: IOS-F25 (matrix row IOS-016)
Binary: grantiva 2.0.1 (commit c8dc86d), runner 1.1.18-grantiva.7, Xcode 27.0, qa-ios-2 (iPhone 17, iOS 26.0)

## Expected
`teardown --udid --force` "kills whatever is holding that simulator, releases the lease, and clears any **stale** capacity
record". Source: README.md:376-377 (§Reclaiming a simulator). The record of a session that still owns the device is not
stale, and the killed runner's keep-alive files should go with it.

## Actual
After `kill -9` of a keep-alive grantiva on qa-ios-2 (session `qa-ios` still active on qa-ios-1 and qa-ios-2), the
reclaim kills runner and WDA correctly but also drops the session's record:
```
"capacityRecordsCleared" : 1, "leaseReleased" : true, "reclaimed" : true, "udid" : "0897A224-..."
```
`simulator sessions` goes from `(3/4) ... qa-ios-2 (...) — qa-ios [active]` to `(2/4)` without qa-ios-2, though it stays
Booted, so `teardown --session-id qa-ios` would skip it. `/tmp/grantiva-sessions/31830-1791583257475743000.grantiva` and
`31830.owner.json` remain, and a `simctl diagnose --udid=0897A224...` started by the dying runner appears afterwards.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_SESSION_ID=qa-ios
rm -rf /tmp/qa-ios-app && cp -R /Users/kyle/Developer/landmarks-demo/ios /tmp/qa-ios-app && cd /tmp/qa-ios-app
grantiva simulator ensure --name qa-ios-2 --device-type "iPhone 17" --runtime 26.0
grantiva build install --simulator qa-ios-2
grantiva run --no-build --flow .maestro/01-browse.yaml --simulator qa-ios-2 --keep-alive --ready-file /tmp/i09.ready & pid=$!
while [ ! -f /tmp/i09.ready ]; do sleep 0.2; done
grantiva simulator sessions; kill -9 $pid
grantiva simulator teardown --udid qa-ios-2 --force --json | grep capacityRecordsCleared      # 1
grantiva simulator sessions                       # qa-ios-2 gone although Booted and owned by qa-ios
ls /tmp/grantiva-sessions/; pgrep -fl "simctl diagnose"
grantiva simulator teardown --session-id qa-ios
```

## Evidence
- findings/evidence/triage/F25-teardown.json, F25-sessions-before.txt, F25-sessions-after.txt, F25-files-before.txt
- findings/evidence/IOS-016/{out.json,sessions-after.txt,procs-after-teardown.txt}

## Suspected cause
Sources/GrantivaCore/Simulator/SimulatorReaper.swift:193-196 calls `capacity.remove(udid:)` unconditionally after the
kill, whatever the record's session or liveness. forceTeardown (:133-204) never calls
KeepAliveSessionStore.removeOwner (Sources/GrantivaCore/Runner/KeepAliveSessionStore.swift:102) or removes the runner's
`<pid>-<ts>.grantiva` file, and does not include `simctl diagnose` children in its kill set.

## Acceptance criteria
- Re-running the repro: `capacityRecordsCleared` is 0 for a record whose session is still active elsewhere (or the
  record is kept/re-owned), `simulator sessions` still lists qa-ios-2 under `qa-ios`, and `/tmp/grantiva-sessions` has
  no `31830*` files. No `simctl diagnose` for the UDID survives.
- Only records whose owner pid is dead and whose session has no other live device, or `pending` records, are cleared;
  the JSON says which records were kept and why.
- GrantivaCoreTests/SimulatorReaperTests: with an injected capacity store holding an active `qa-ios` record, force
  teardown keeps it; with a fake session dir, the killed runner's `.grantiva` and `.owner.json` files are removed.
