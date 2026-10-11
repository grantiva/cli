# `--json` outputs mix snake_case and camelCase keys from one command to the next

Severity: contract
Component: cli
Platforms: both (the encoders are platform-independent; keys observed on iOS)
Rows: IOS-OBS-01 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
One key-casing convention across every `--json` document and the `--ready-file` file, stated once in the README
(README:365-369 says only that commands which advertise `--json` emit structured output). A consumer that writes one
decoder (e.g. a `JSONDecoder` with one `keyDecodingStrategy`, or jq paths) should not need per-command casing rules.
The README already documents camelCase keys for `run --json` (`"allPassed"`, `reportDir`, README:383-386), which is the
natural convention to keep; the snake_case outputs are then the ones that change. That is a breaking change for
consumers either way, so the fix needs a release note.

## Actual
Keys by command, extracted from the slice's raw outputs (`findings/evidence/cov-ios/IOS-OBS-01/keys-by-command.txt`):
```
== IOS-006/ensure-json-new.out        (simulator ensure --json)
"created" : "device_type" : "display_scale" : … "pixel_dimensions" : "point_dimensions" : …
== IOS-096/compare-json.out           (diff compare --json)
"baseline_path" : "capture_path" : … "perceptual_distance" : "pixel_diff_percent" : "screen_name" : …
== IOS-088/stale.out                  (runner start --json, then .grantiva/session.json)
"bundle_id" : "bundleId": "log" : "pid" : "pid": "platform": "port" : "startedAt": "status" : "udid" : "wdaPort":
== IOS-010/sessions-json.out          (simulator sessions --json)
"acquiredAt" : "bootedByGrantiva" : "ephemeral" : "name" : "ownerPID" : "sessionId" : …
== IOS-023/install-json.out           (build install --json)
"appPath" : "bundleId" : "dataContainerPath" : …
```
Also snake_case: `diff capture --json` (`screen_name`, `size_bytes`), `diff approve --json` (`approved_screens`,
`baseline_directory`) and the MCP vrt tools that return those documents. Also camelCase: `simulator teardown --json`
(`capacityRecordsKept`, `leaseReleased`), `run --json` (`allPassed`, `reportDir`), `record --json`
(`requestedMilliseconds`, `actualMilliseconds`) and the ready file (`finishedAt`, `reportDir`). The sharpest case is
`runner start --json` printing `bundle_id` for the value that the session file it writes calls `bundleId`
(`findings/evidence/cov-ios/IOS-088/stale.out`).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k103
unset GRANTIVA_API_KEY
rm -rf /tmp/k103 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k103 && cd /tmp/k103/ios   # main 4e49dc4
keys() { grep -o '"[A-Za-z_]*" *:' | sort -u | tr '\n' ' '; echo; }
grantiva simulator ensure --name "fix-k103 iPhone 17" --runtime 26.0 --json | keys
UDID=$(grantiva simulator ensure --name "fix-k103 iPhone 17" --runtime 26.0)
grantiva simulator sessions --json | keys
grantiva build install --simulator "$UDID" --json | keys
grantiva runner start --simulator "$UDID" --json | keys; keys < .grantiva/session.json; grantiva runner stop
grantiva run --simulator "$UDID" --no-build --flow .maestro/01-browse.yaml --json --ready-file /tmp/k103/r.json | keys; keys < /tmp/k103/r.json
grantiva simulator teardown --udid "$UDID" --force --json | keys
grantiva simulator delete --name "fix-k103 iPhone 17"
```
Today: `device_type`/`pixel_dimensions` and `bundle_id` (snake) next to `sessionId`, `bundleId`, `allPassed`,
`finishedAt`, `leaseReleased` (camel).

## Evidence
- findings/evidence/cov-ios/IOS-OBS-01/keys-by-command.txt, commands.txt (sources named per section)
- findings/evidence/cov-ios/IOS-088/stale.out (`runner start --json` vs session.json in one file)
- findings/evidence/cov-ios/IOS-006/, IOS-010/, IOS-016/, IOS-023/, IOS-032/, IOS-074/, IOS-083/, IOS-096/, IOS-113/ (raw outputs)
- findings/cov-ios-results.md rows IOS-OBS-01 and X-014

## Suspected cause
No shared encoder or key strategy; each output picks its casing locally:
- snake_case by explicit `CodingKeys`: Sources/GrantivaCore/Simulator/SimulatorDevice.swift:73-75 (`device_type`
  and the dimension keys), Sources/GrantivaCore/Diff/DiffResult.swift:41-42, :86, :139-140, :176 (`screen_name`,
  `pixel_diff_percent`, …).
- snake_case by dictionary literal: Sources/GrantivaCLI/DriverCommand.swift:117, :346, :420 (`"bundle_id"` in
  `runner start --json`; C16 covers the string-typed `pid`/`port` in the same literals).
- camelCase by default synthesis: Sources/GrantivaCore/Simulator/SimulatorCapacity.swift:9-11 (`sessionId`,
  `acquiredAt`), Sources/GrantivaCore/Simulator/SimulatorReaper.swift:32 (`leaseReleased`),
  Sources/GrantivaCore/Runner/ReadyFile.swift:21 (`reportDir`), Sources/GrantivaCore/Runner/RunnerSessionInfo.swift:7
  (`bundleId`), and the `run`/`build install`/`record` result types in Sources/GrantivaCLI/.
- There are 19 bare `JSONEncoder()` constructions under Sources/ and none sets `keyEncodingStrategy`.

Note that `GrantivaConfig.swift:185` maps `bundle_id` for the YAML config file; config-file keys are a separate,
documented surface and should stay snake_case.

## Acceptance criteria
- Every `--json` output and the ready file use one casing (camelCase recommended, matching the documented
  `run --json`); `runner start --json` and `.grantiva/session.json` name the bundle the same way.
- A shared encoder factory (e.g. `JSONEncoder.grantivaOutput`) is used by every `--json` path, so new outputs inherit
  the convention.
- README "Commands that advertise `--json`" states the convention, and the release notes list each renamed key.
- Test in `GrantivaCLITests` (new `JSONKeyCasingContractTests.swift`): encode a representative value of each
  `--json` result type (ensure, sessions, teardown, build install, runner start, run, record, diff capture/compare/
  approve, ready file) and assert no key contains `_`. Grantiva config decoding tests stay unchanged.
