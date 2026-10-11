# A passing `run --json --report-dir <dir>` omits `reportDir`, so CI cannot find the report it asked for

Severity: contract
Component: cli
Platforms: both (X-002 on Android and iOS)
Rows: X-002 (android), X-002 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9
Triage note: cluster C21 is split. This file (K21-a) is the `reportDir` key; K21-b is the different `screens` shape
for passing and failing runs. The omission here is deliberate in code (RunCommand.swift:509-511: "both are omitted on
success"), and README:383-386 only describes the failing document, so the orchestrator may instead record an
expectation correction for the matrix ("`reportDir` on failure only") and document it in the README. Written as a
defect because the matrix asks for the same keys on pass and fail and a CI script that passed `--report-dir` needs the
path on success too.

## Expected
Matrix X-002 (README:383-386): `run --json` with `--report-dir` has the same keys (`allPassed`, `screens`, `error`,
`reportDir`) and types on a passing and a failing run; on a pass, `error` may be absent or null but `reportDir` is the
directory the caller asked for.

## Actual
Android, passing `01-browse` with `--report-dir $S/out-x002` (X-002/01.out): keys `allPassed`, `screens` only.
Failing `02-exact-negative` with `--report-dir` (X-002/02.out):
```
['allPassed', 'error', 'reportDir', 'screens']
/private/tmp/.../cov-android/out-x002f
rc=1
```
iOS identical (IOS-074/json-fail.out has `reportDir`; the passing document has none).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k21a
unset GRANTIVA_API_KEY
rm -rf /tmp/k21a && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k21a && cd /tmp/k21a/ios
UDID=$(grantiva simulator ensure --name "fix-k21a iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID"
grantiva run --simulator "$UDID" --no-build --flow .maestro/01-browse.yaml --json --report-dir /tmp/k21a/pass 2>/dev/null | python3 -c "import json,sys;print(sorted(json.load(sys.stdin)))"
grantiva run --simulator "$UDID" --no-build --flow .maestro/coverage/02-exact-negative.yaml --json --report-dir /tmp/k21a/fail 2>/dev/null | python3 -c "import json,sys;print(sorted(json.load(sys.stdin)))"
grantiva simulator teardown --udid "$UDID"; grantiva simulator delete --name "fix-k21a iPhone 17"
```
Android: Android prelude (see K01) with `--device "$SERIAL"`. Today: `['allPassed', 'screens']` then
`['allPassed', 'error', 'reportDir', 'screens']`.

## Evidence
- findings/evidence/cov-android/X-002/01.out (pass), 02.out (fail keys), commands.txt
- findings/evidence/cov-ios/IOS-074/json-pass.out, json-fail.out

## Suspected cause
- `Sources/GrantivaCLI/RunCommand.swift:480` emits `RunResult(screens: screens, allPassed: allPassed)` on success without
  `reportDir`, although `sessionOptions.reportDir` (:495-497) is in scope.
- `RunCommand.swift:509-517`: `RunResult` documents "both are omitted on success"; `failureResult` (:543-552) is the
  only place that sets `reportDir`.

## Acceptance criteria
- With `--report-dir`, the passing document contains `"reportDir": "<absolute path>"` equal to the failing one's form;
  without `--report-dir`, neither has it.
- `error` is either absent on success (documented) or `null`; README:383-386 states which keys appear on success and
  on failure.
- GrantivaCLITests (RunCommandTests or OutputStreamContractTests): encode a passing `RunResult` built with a report dir
  and assert the `reportDir` key.
- If the orchestrator rules this an expectation correction instead, README:383-386 gains one sentence: "`reportDir`
  appears only on failure."
