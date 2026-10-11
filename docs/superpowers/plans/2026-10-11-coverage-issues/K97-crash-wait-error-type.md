# On iOS, a wait that ends because the app crashed is recorded as `error.type: "assertion"`, not `app_crash`

Severity: contract
Component: runner
Platforms: ios (iOS-only: the Android twin N-14 passed, with `error.type` `app_crash` on 99-crash's launchApp)
Rows: N-14 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Matrix N-14 (plan N14): with `--report-dir`, 99-crash's failed wait has `error.type` `app_crash` in report.json /
the flow JSON. 03-edit's inputText has no `warning` (that half passed).

## Actual
N-14/report-extract.txt (from N-14/reports/99-crash-flow.json):
```
n14b launchApp passed warning= None error= null
n14b assertVisible failed warning= None error= {"type": "assertion", "message": "Element not visible: text='Landmarks' (cause: context deadline exceeded: WDA error: The application under test with bundle id 'com.kylebrowning.Landmarks' is not running, possibly crashed)"}
n14b assertVisible skipped warning= None error= null
```
The message itself says the app is not running, possibly crashed.

## Repro
Flow (`ios/.maestro/99-crash.yaml`; the app crashes at launch when `LANDMARKS_CRASH_ON_LAUNCH` is set by the flow):
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k97
unset GRANTIVA_API_KEY
rm -rf /tmp/k97 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k97 && cd /tmp/k97/ios   # 4e49dc4
cat .maestro/99-crash.yaml
UDID=$(grantiva simulator ensure --name "fix-k97 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID" --no-launch
grantiva run --no-build --simulator "$UDID" --flow .maestro/99-crash.yaml --report-dir /tmp/k97/out
jq -c '.commands[] | select(.status=="failed") | .error' /tmp/k97/out/flows/flow-000.json
grantiva simulator teardown --session-id fix-k97
```
Today: `{"type":"assertion","message":"Element not visible: … is not running, possibly crashed)"}`. (If the flow
JSON lives elsewhere, `find /tmp/k97/out -name '*.json'`.)

## Evidence
- findings/evidence/cov-ios/N-14/commands.txt, report-extract.txt, reports/99-crash-flow.json, crash.out/.err
- findings/evidence/cov-ios/IOS-030/99-crash.* (same failure text, IOS-119)
- Android twin: cov-android results N-14 (after merge: findings/evidence/cov-android/N-14/)

## Suspected cause
grantiva-runner:
- `pkg/executor/convert.go:36-58` (`commandResultToError`) classifies by message text only, via `classifyError`
  (:103-122). The "not visible" case (:111-112) is tested before the "crash" case (:115-116), so
  `Element not visible: … possibly crashed` becomes `assertion`. The structured code is ignored.
- The WDA driver never returns `core.ErrAppCrashed` (`pkg/core/errors.go:118-122`, code `app_crashed`) for a wait
  that dies with the app; the UIAutomator2 driver does (`pkg/driver/uiautomator2/wait_crash.go:42-45`,
  `commands.go:1428`), which is why Android reports `app_crash`. The WDA driver already recognises the condition
  (`isAppDeathError`, `pkg/driver/wda/driver.go:482-500`).

## Acceptance criteria
- Re-running the repro: the failed wait's `error.type` is `app_crash`; the message still names the bundle ID and
  says it is not running; exit 1 unchanged.
- An ordinary not-visible failure (02-exact-negative) is still `assertion`; element-not-found is still
  `element_not_found`.
- Classification prefers a `core.ExecutionError` code when present (`app_crashed` → `app_crash`), and the WDA wait
  path returns `ErrAppCrashed` when WDA reports the app is not running.
- Runner tests: `classifyError` / `commandResultToError` on a result wrapping `ErrAppCrashed` with a "not visible"
  message gives `app_crash`; a WDA wait whose client reports "application … is not running" returns `ErrAppCrashed`.
- Bundled runner version bumped in this repo.
