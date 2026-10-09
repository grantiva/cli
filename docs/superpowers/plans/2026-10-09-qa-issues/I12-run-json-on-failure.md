# Emit a JSON result on stdout when `run --json` fails

Severity: contract
Platforms: ios
Found by: IOS-F22 (matrix row IOS-074)
Binary: grantiva 2.0.1 (commit c8dc86d), runner 1.1.18-grantiva.7, Xcode 27.0, qa-ios-1 (iPhone 17, iOS 26.0)

## Expected
"stdout is the result": `--json` prints a JSON document for every outcome, failures included. Source: README.md:314
(§stdout is the result, stderr is the commentary).

## Actual
A failing flow prints 0 bytes on stdout, exit 1 (flows 09 and 02 both). A passing flow prints
`{"allPassed":true,"screens":[...]}`. Agents piping `run --json | jq` get a parse error instead of the failed step.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_SESSION_ID=qa-ios
rm -rf /tmp/qa-ios-app && cp -R /Users/kyle/Developer/landmarks-demo/ios /tmp/qa-ios-app && cd /tmp/qa-ios-app
grantiva simulator ensure --name qa-ios-1 --device-type "iPhone 17" --runtime 26.0
grantiva build install --simulator qa-ios-1
grantiva run --no-build --flow .maestro/09-seed-empty.yaml --simulator qa-ios-1 --json > fail.json; echo "exit $?"; wc -c fail.json
grantiva run --no-build --flow .maestro/01-browse.yaml --simulator qa-ios-1 --json | head -c 80
```
`fail.json` is 0 bytes.

## Evidence
- findings/evidence/triage/F22-fail.json (empty), F22-fail.err
- findings/evidence/IOS-074/fail.json, fail02.json (empty), IOS-074/out.json (passing case)

## Suspected cause
Sources/GrantivaCLI/RunCommand.swift:312-326: when the runner exits non-zero, RunnerSession.runFlowFiles throws
(`Runner failed`, Sources/GrantivaCore/Runner/RunnerSession.swift:393-409) and the catch only takes a failure screenshot and
rethrows, so the JSON branch at :350-386 is never reached.

## Acceptance criteria
- Re-running the repro: `fail.json` parses and has `"allPassed": false`, the failing flow/step and its message (from
  report.json via RunnerArtifactCollector), and the report dir path when preserved; exit stays 1.
- Setup failures under `--json` (no device, bad flag after validation) also print `{"allPassed": false, "error": "..."}`.
- GrantivaCLITests/RunCommandTests: with a fake runner exiting 1 and a fixture report.json, stdout is valid JSON with
  `allPassed == false` and the failed step.
