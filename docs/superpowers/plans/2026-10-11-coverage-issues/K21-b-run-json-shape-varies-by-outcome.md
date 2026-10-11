# `run --json` lists screenshots on a pass but flows on a failure, so the `screens` array changes meaning with the outcome

Severity: contract
Component: cli
Platforms: both (X-002 on Android and iOS; the iOS slice widened the finding)
Rows: X-002 (android), X-002 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9
Triage note: split from cluster C21 (see K21-a for the `reportDir` key). Different code: success goes through
RunnerArtifactCollector, failure through RunnerFailureReport.

## Expected
Matrix X-002 (README:383-386): the passing and failing `run --json` documents have the same keys and types, "flows/steps"
included. A consumer reading `screens[]` should get the same kind of entry for each flow either way: the flow's name,
whether it passed and its real steps (the failing document already has this).

## Actual
Passing `01-browse` (X-002/01.out; iOS IOS-074/json-pass.out): one entry per `takeScreenshot`, each with a single
synthetic step:
```
  "screens" : [
    {
      "name" : "01-browse-cmd-003-Home",
      "passed" : true,
      "steps" : [ { "action" : "Run flow \"01-browse\"", "status" : "passed" } ]
    },
    {
      "name" : "01-browse-cmd-007-Landmark Detail",
      ...
```
Failing `02-exact-negative` (IOS-074/json-fail.out): one entry for the flow with its real steps:
```
      "name": "02-exact-negative",
      "passed": false,
      "steps": [
        { "action": "launchApp", "status": "passed" },
        { "action": "assertVisible: text=\"Golden Gate.*\"", "status": "passed" },
        { "action": "assertVisible: text=\"Golden Gate.*\", exact=true", "message": "Element not visible: ...", "status": "failed" }
```
No `flows` key in either.

## Repro
Same commands as K21-a, printing the `screens` entries:
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k21b
unset GRANTIVA_API_KEY
rm -rf /tmp/k21b && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k21b && cd /tmp/k21b/ios
UDID=$(grantiva simulator ensure --name "fix-k21b iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID"
show='import json,sys;d=json.load(sys.stdin);print([(s["name"],[x["action"] for x in s["steps"]]) for s in d["screens"]])'
grantiva run --simulator "$UDID" --no-build --flow .maestro/01-browse.yaml --json 2>/dev/null | python3 -c "$show"
grantiva run --simulator "$UDID" --no-build --flow .maestro/coverage/02-exact-negative.yaml --json 2>/dev/null | python3 -c "$show"
grantiva simulator teardown --udid "$UDID"; grantiva simulator delete --name "fix-k21b iPhone 17"
```
Android: Android prelude (see K01), `--device "$SERIAL"`.

## Evidence
- findings/evidence/cov-android/X-002/01.out, 02.out, commands.txt
- findings/evidence/cov-ios/IOS-074/json-pass.out, json-fail.out, commands.txt

## Suspected cause
- Success: `Sources/GrantivaCore/Runner/RunnerSession.swift:534` → `RunnerArtifactCollector.collect`
  (Sources/GrantivaCore/Runner/RunnerArtifactCollector.swift:28-93) makes one `ScreenCapture` per screenshot file named
  `<flow>-<artifact>` with a single `Run flow "<flow>"` step (:79-90); when a flow took no screenshot,
  RunnerSession.swift:~543-553 adds one synthetic row per flow.
- Failure: `RunnerFailureReport.captures(reportDir:)` (Sources/GrantivaCore/Runner/RunnerFailureReport.swift:86-121) reads
  report.json and makes one entry per flow with its commands as steps.
- `RunCommand.RunResult.ScreenResult` (Sources/GrantivaCLI/RunCommand.swift:518-536) serialises whichever list it is given.

## Acceptance criteria
- For flows, passing and failing documents use the same entry kind: one entry per flow with `name` = flow name,
  `passed`, and `steps` = the runner's commands with status (and message on failure). Screenshot paths, if kept, move
  to a field on that entry (e.g. `screenshots: [{name, path}]`) or a separate top-level array, documented.
- Configured screens (screens session) keep one entry per screen, in both outcomes.
- The key set is documented in README next to :383-386, with an example of each.
- GrantivaCLITests (OutputStreamContractTests): decode a passing and a failing document for the same flow file and
  assert identical key sets and entry kinds; GrantivaCoreTests: the success collector builds per-flow steps from a
  fixture report.json.
