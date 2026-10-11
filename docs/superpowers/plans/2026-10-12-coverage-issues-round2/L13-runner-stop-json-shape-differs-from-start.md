# `runner stop --json` does not share `runner start --json`'s shape: no `port`, no app ID key, and an undocumented `killed`

Severity: contract
Component: cli
Platforms: both (iOS and Android, same document builder)
Rows: IOS-138, B2-K16, N2-05, N2-07, D2-13 [ios]; B2-K16, N2-07, D2-13 [android]
Regresses/extends: K16 (runner start JSON types and keys), fixed by CLI #194 (numbers for pid/port, platform keys). Incomplete: the stop half.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
README at c65fc17 (`runner start --json` / `runner stop --json` paragraph, README:399-403): "`runner start --json` and
`runner stop --json` share one shape: `status` (…), `pid` and `port` as numbers, `platform`, and the platform's own names
for the app and the device: `bundleId` and `udid` on iOS, `applicationId` and `serial` on Android". README:414-415 and
the key table (README:467: "`bundle_id` → `bundleId` (runner start, runner stop; `applicationId` on Android)") name
`runner stop` as carrying the app ID pair. README documents `runnerPid`, `alreadyExited`, `sessions` and `reaped` as
the stop-only fields, and nothing else.

## Actual
The `pid` and `port` numbers are fixed (round-1 half). Every stop document lacks `port` and the app ID, and the plain
stop adds `"killed": false`. iOS start vs stop on one session (findings/evidence/cov2-ios/IOS-138/start-json.out,
stop-json.out):
```
start: {"bundleId":"com.kylebrowning.Landmarks","bundle_id":"com.kylebrowning.Landmarks","log":"…","pid":84798,"platform":"ios","port":8987,"status":"started","udid":"7E846901-…"}
stop:  {"killed":false,"pid":84798,"platform":"ios","reaped":[],"runnerPid":84798,"status":"stopped","udid":"7E846901-…"}
```
Android (findings/evidence/cov2-android/B2-K16/01.out, 02.out):
```
{ "applicationId" : "com.kylebrowning.landmarks", "bundle_id" : "com.kylebrowning.landmarks", "pid" : 39267, "platform" : "android", "port" : 62621, "serial" : "emulator-5554", "status" : "already_running", "udid" : "emulator-5554" }
{ "killed" : false, "pid" : 39267, "platform" : "android", "reaped" : [ ], "runnerPid" : 39267, "serial" : "emulator-5554", "status" : "stopped", "udid" : "emulator-5554" }
```
The multi-session stop (findings/evidence/cov2-ios/N2-05/b-stop.out) and the `alreadyExited` stop (a-stop.out) also
have no `port` and no `bundleId`. Those two also omit `killed`, so `killed` appears in some stop documents and not in
others. Seen on every stop in 8 rows across both slices.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l13
unset GRANTIVA_API_KEY
rm -rf /tmp/l13 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l13 && cd /tmp/l13/ios
UDID=$(grantiva simulator ensure --name fix-l13 --device-type "iPhone 17" --runtime 26.0 | tail -1)
grantiva build install --simulator "$UDID"
grantiva runner start --detach --json --simulator "$UDID" --bundle-id com.kylebrowning.Landmarks | jq -S 'keys'
grantiva runner stop --json | jq -S 'keys'   # bug: no port, no bundleId/bundle_id; extra killed
grantiva simulator teardown --session-id fix-l13
```
Android: in `/tmp/l13/android` with `SERIAL=$(grantiva emulator ensure --name fix-l13)`, `grantiva build install --device
"$SERIAL"`, `grantiva runner start --detach --json --device "$SERIAL"`, `grantiva runner stop --json` (no
`applicationId`/`bundle_id`, no `port`), then `grantiva emulator teardown --serial "$SERIAL"`.

## Evidence
- findings/evidence/cov2-ios/IOS-138/start-json.out, stop-json.out
- findings/evidence/cov2-ios/B2-K16/start1.out, start2.out, stop.out
- findings/evidence/cov2-ios/N2-05/a-stop.out (alreadyExited), b-stop.out (sessions[])
- findings/evidence/cov2-ios/N2-07/key-scan.txt; findings/evidence/cov2-ios/D2-13/
- findings/evidence/cov2-android/B2-K16/01.out, 02.out; findings/evidence/cov2-android/N2-07/; findings/evidence/cov2-android/D2-13/
- docs/superpowers/plans/2026-10-11-coverage-issues/K16-runner-start-json-types-and-keys.md

## Suspected cause
- `Sources/GrantivaCLI/DriverCommand.swift:827-865` (`RunnerStopCommand.document`): every `stopped` document is built
  as `RunnerLifecycleDocument(status: "stopped", pid:, deviceID:, platform:)` with no `port:` and no `appID:`. The
  `Result` cases (`DriverCommand.swift:728-740`: `.stopped(pid:udid:killed:reaped:)`, `.exited`, `.keepAlive` outcomes)
  do not carry them either, although the sources do: `RunnerSessionInfo` (`.grantiva/session.json`) has `wdaPort` and
  `bundleId` (`Sources/GrantivaCore/Runner/RunnerSessionInfo.swift:5-12`). The keep-alive session has `port`, and its
  owner sidecar has `appID` since K56 (`Sources/GrantivaCore/Runner/KeepAliveSessionStore.swift:14,142-149`).
- `killed` is encoded whenever set (`Sources/GrantivaCLI/RunnerLifecycleDocument.swift:46`). It is set for `.stopped`
  and `.terminated` (`DriverCommand.swift:835,855`) but not for `.exited` or `.released`. README never mentions it.
- The contract test `Tests/GrantivaCLITests/JSONKeyCasingContractTests.swift:99-109` covers stop fixtures for casing
  only, not for sharing start's keys.

## Acceptance criteria
Pick one and apply it to both platforms:
- (a, preferred) Every `runner stop --json` document with `status: stopped` (single, `alreadyExited`, each `sessions[]`
  entry) carries `port` (number) and the app ID as start does: `bundleId` + `bundle_id` on iOS, `applicationId` +
  `bundle_id` on Android, beside `udid`/`serial`. When a value was not recorded (an old sidecar), the key is `null`, not
  omitted. `killed` is either documented in README as a stop-only field and present on every `stopped` document
  (`false` when not escalated), or removed and folded into `reaped`/text output.
- (b) README:399-403 and README:467 are reworded to list exactly the keys stop emits, and `killed` is documented.
- In both cases a test pins it: GrantivaCLITests/RunnerLifecycleCommandTests, for each stop shape (`stopped`,
  `alreadyExited`, `sessions[]`, iOS and Android), the key set equals start's key set minus `log` plus the documented
  stop-only keys. JSONKeyCasingContractTests keeps passing.
