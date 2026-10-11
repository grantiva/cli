# On Android `.grantiva/session.json` names the app `bundleId` and the port `wdaPort`, while `runner start --json` says `applicationId` and `port`

Severity: contract
Component: cli
Platforms: android (every Android session file; logical). iOS passes (`bundleId` in both; the port key differs there too, `wdaPort` vs `port`, but K103's criterion names only the bundle).
Rows: B2-K103 [android]
Regresses/extends: K103 (docs/superpowers/plans/2026-10-11-coverage-issues/K103-json-key-casing-mixed.md) criterion 1 incomplete on Android; fixing PRs #193 (casing rule) and #194 (runner start/stop keys, K16). Related to M06 (`runner stop --json` shape), a different writer.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
K103 criterion 1: "`runner start --json` and `.grantiva/session.json` name the bundle the same way." On Android the
documented name is `applicationId` (README build-install paragraph; `runner start --json` emits it with the deprecated
`bundle_id` twin, `LegacyJSONKeys.platformTwins`); the port is `port`.

## Actual
Same start, findings/evidence/cov2-android/AND-126/02.out (`runner start --detach --json --device emulator-5554
--headless; cat .grantiva/session.json`):
```
{
  "applicationId" : "com.kylebrowning.landmarks",
  "bundle_id" : "com.kylebrowning.landmarks",
  "log" : "\/var\/folders\/jv\/76l6crmx6nl3hf150gzry_ym0000gn\/T\/grantiva-runner-1791745232.log",
  "pid" : 63796,
  "platform" : "android",
  "port" : 52419,
  "serial" : "emulator-5554",
  "status" : "started",
  "udid" : "emulator-5554"
}
{"pid":63796,"wdaPort":52419,"platform":"android","udid":"emulator-5554","startedAt":813438038.501549,"bundleId":"com.kylebrowning.landmarks"}
```
AND-082/01.out shows the same session-file keys. The file is also compact, unsorted and writes `startedAt` as seconds
since 2001 (`813438038.5`), unlike every `--json` document (ISO-8601, `JSONOutput.encoder`); noted, not graded.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l43
unset GRANTIVA_API_KEY
rm -rf /tmp/l43 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l43 && cd /tmp/l43/android
sed -i '' 's/^emulator: .*/emulator: fix-l43/' grantiva-android.yml
SERIAL=$(grantiva emulator ensure --name fix-l43)
grantiva build install --device "$SERIAL" --no-launch
grantiva runner start --detach --json --device "$SERIAL"
cat .grantiva/session.json; echo
grantiva runner stop --json
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-l43
```

## Evidence
- findings/evidence/cov2-android/AND-126/02.out, commands.txt
- findings/evidence/cov2-android/AND-082/01.out
- findings/evidence/cov2-android/B2-K103/commands.txt (pointers); findings/cov2-android-results.md row B2-K103

## Suspected cause
- `Sources/GrantivaCore/Runner/RunnerSessionInfo.swift:4-23`: one `Codable` struct for both platforms with stored
  properties `wdaPort` and `bundleId`, synthesized keys, written with a bare `JSONEncoder()` (`:33-37`).
- `runner start --json` goes through `RunnerLifecycleDocument.encode` (`Sources/GrantivaCLI/RunnerLifecycleDocument.swift:38-63`),
  which picks `applicationId` + `bundle_id` and `serial` for Android (`:50-61`) and `port` for both.
- Readers decode the file with the synthesized keys: `RunnerSessionInfo.load` (`:39-42`), `MCPServer.swift:172`,
  `DiffCommand.swift:256`, `DriverCommand.swift:152/:430/:970`, `DeviceRunnerSessions.swift:14`. A session file written
  by 2.1.0 must stay readable.

## Acceptance criteria
- On Android, `.grantiva/session.json` carries `applicationId` (and `port`) like `runner start --json`; on iOS it keeps
  `bundleId`. Whether the old `bundleId`/`wdaPort` keys stay beside the new ones for one release follows the K103
  alias ruling (`LegacyJSONKeys`), and README says which.
- Every reader accepts both the new keys and the 2.1.0 keys (a session started by 2.1.0 is still found and stopped by
  the next version).
- Tests in GrantivaCoreTests/RunnerSessionInfoTests.swift: encoding an Android `RunnerSessionInfo` yields
  `applicationId` (and `port`); decoding a 2.1.0 file (`{"pid":…,"wdaPort":…,"bundleId":…,"udid":"emulator-5554",
  "platform":"android"}`) still works; add the session file to `JSONKeyCasingContractTests.swift`'s fixtures with the
  cross-check that its app key equals `runner start --json`'s for the same platform.
