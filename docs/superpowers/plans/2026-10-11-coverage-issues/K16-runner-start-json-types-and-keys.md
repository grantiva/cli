# `runner start/stop --json` emit pid and port as strings and use iOS snake_case keys on Android

Severity: contract
Component: cli
Platforms: both (Android AND-126; iOS IOS-138 confirms the string types and the `bundle_id` vs `bundleId` split)
Rows: AND-126 (android); IOS-138 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
README:367-369 and help runner_start.txt: `runner start/stop --json` print a JSON result. Machine-readable results
should use the types and names the rest of the CLI uses for the same facts:
- pid and port are numbers, as in `.grantiva/session.json` (`"pid":64253`, `"wdaPort":8235`) and
  `emulator sessions --json` (`pid` number).
- App and device keys follow the platform's sibling commands: on Android `build install --json` says `applicationId`
  and `device.serial`; on iOS `session.json` says `bundleId` and `udid`.

## Actual
Android (AND-126/02.out, 01.out):
```
{
  "bundle_id" : "com.kylebrowning.landmarks",
  "log" : "\/var\/folders\/...\/grantiva-runner-1791703780.log",
  "pid" : "7067",
  "port" : "57776",
  "status" : "started",
  "udid" : "emulator-5554"
}
{
  "pid" : "6630",
  "status" : "stopped"
}
```
iOS (IOS-088/stale.out, IOS-138/stop-json-2.out): start `"pid" : "64253"`, `"port" : "8235"`, `"bundle_id"`; stop
`"pid" : "64253"`; the session.json written by the same start is
`{"wdaPort":8235,...,"bundleId":"com.kylebrowning.Landmarks","udid":"A1C8...","pid":64253}`.

## Repro
iOS:
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k16
unset GRANTIVA_API_KEY
rm -rf /tmp/k16 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k16 && cd /tmp/k16/ios
UDID=$(grantiva simulator ensure --name "fix-k16 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID"
grantiva runner start --detach --json --simulator "$UDID"
cat .grantiva/session.json; echo
grantiva runner start --detach --json --simulator "$UDID"     # already_running form
grantiva runner stop --json
grantiva simulator teardown --udid "$UDID"; grantiva simulator delete --name "fix-k16 iPhone 17"
```
Android: Android prelude (see K01), then `grantiva runner start --detach --json --device "$SERIAL"`,
`grantiva runner stop --json`, and `grantiva build install --device "$SERIAL" --no-launch --json` for the sibling keys.

## Evidence
- findings/evidence/cov-android/AND-126/01.out, 02.out, 03.out, 04.out, commands.txt
- findings/evidence/cov-ios/IOS-138/stop-json.out, stop-json-2.out, commands.txt; findings/evidence/cov-ios/IOS-088/stale.out

## Suspected cause
`Sources/GrantivaCLI/DriverCommand.swift` builds these documents as `[String: String]` dictionaries with string
interpolation:
- `:113-118` (already running): `"port": "\(existing.wdaPort)"`, `"pid": "\(existing.pid)"`, `"bundle_id"`.
- `:341-349` (detached start) and `:415-422` (foreground start): `"port"`, `"pid"`, `"bundle_id"`, `"udid"` with no
  platform check.
- `:654` (stop): `"pid": "\(session.pid)"`.

## Acceptance criteria
- `runner start --json`, the already-running form and `runner stop --json` emit `pid` and `port` as JSON numbers.
- Keys are consistent with the platform's siblings: iOS `bundleId` + `udid`, Android `applicationId` + `serial` (or a
  `device: {name, serial}` object as in `build install --json`), and the same key names in all three documents.
  Old keys may be kept for one release if documented as deprecated.
- README's JSON section (or `runner start --help`) shows the document shape.
- GrantivaCLITests (RunnerLifecycleCommandTests or OutputStreamContractTests): decoding each document asserts
  `pid`/`port` are numbers and the key set per platform.
