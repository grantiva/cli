# The runner's summary block draws steps skipped after a failure as failed (`✗ ... (0ms)`)

Severity: wrong-result
Component: runner
Platforms: both (Android AND-OBS-11; iOS confirmed in IOS-134's summary block)
Rows: AND-OBS-11 (android); seen also in IOS-134 (ios, row placed in C20)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
A step that never ran because an earlier step failed is shown as skipped wherever it is listed, matching the totals
line (`N steps skipped`) and the table's `Skip` column printed by the same run. Source: the runner's own totals and
report.json, which classify these steps as not run; a reader must be able to tell the one real failure from the
steps after it.

## Actual
Android, 09-waits run whose `extendedWaitUntil` timed out (CF-09-waits/out-cf-09-waits.stderr:44-58):
```
    ✗ extendedWaitUntil (12.7s)
      ╰─ Element 'Loading…' still visible after 10s (cause: context deadline exceeded)
    ✗ assertVisible (0ms)
    ✗ waitForAnimationToEnd (0ms)
    ✗ waitForAnimationToEnd (0ms)
✗ 09-waits 17.3s

  4 steps passing (17.3s)
  1 steps failing
  3 steps skipped
...
  09-waits                       ✗ FAIL       8      4      1      3      17.3s  google sdk_gphone64_arm64 (...
```
Four `✗` lines, one real failure. Same in N-06/n06-1.err:41-45. iOS, screens session with a failing tap
(IOS-134/continue.err:45-48): `✗ tapOn (13.0s)` followed by `✗ waitForAnimationToEnd (0ms)`, `✗ takeScreenshot (0ms)`.

## Repro
Any flow that fails before its last step. Save as `/tmp/k03/fail-early.yaml`:
```
appId: com.kylebrowning.landmarks          # iOS: com.kylebrowning.Landmarks
---
- launchApp
- tapOn: "No Such Element"
- assertVisible: "Landmarks"
- waitForAnimationToEnd
```
Android:
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k03
unset GRANTIVA_API_KEY
rm -rf /tmp/k03/demo && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k03/demo && cd /tmp/k03/demo/android
SERIAL=$(grantiva emulator ensure --name fix-k03)
grantiva build install --device "$SERIAL" --no-launch
grantiva run --device "$SERIAL" --no-build --flow /tmp/k03/fail-early.yaml 2>&1 | sed -n '/- Device:/,/steps skipped/p'
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-k03
```
iOS: same flow with the iOS `appId`, `cd /tmp/k03/demo/ios`, `UDID=$(grantiva simulator ensure --name "fix-k03 iPhone 17" --runtime 26.0)`,
`grantiva build install --simulator "$UDID"`, `grantiva run --simulator "$UDID" --no-build --flow /tmp/k03/fail-early.yaml`.
Today: the summary block shows `✗ assertVisible (0ms)` and `✗ waitForAnimationToEnd (0ms)` under a `2 steps skipped` total.

## Evidence
- findings/evidence/cov-android/CF-09-waits/out-cf-09-waits.stderr lines 39-58
- findings/evidence/cov-android/N-06/n06-1.err lines 41-45
- findings/evidence/cov-ios/IOS-134/continue.err lines 45-49
- Row pointer: findings/evidence/cov-android/AND-OBS-11/commands.txt

## Suspected cause
Runner (release-round1, ae48e34), `pkg/cli/test_unified_output.go`:
- `printCommand` (:141) sets `passed := cmd.Status == report.StatusPassed` (:161) and sends every other status to the
  `✗` branch (:184-191). Commands left `pending` or marked `skipped` (`report.StatusPending`/`StatusSkipped`,
  pkg/report/types.go:25-29) are drawn as failures with their zero duration.
- The totals (:213-231) count the same commands as skipped, so the block contradicts itself. The legacy printer at
  pkg/cli/test.go:~1870 should be checked for the same branch.

## Acceptance criteria
- In the repro, the summary block shows exactly one `✗` (the `tapOn`), and the steps after it with a distinct
  skipped marker (for example `○ assertVisible (skipped)` or `- assertVisible (skipped)`), never `✗` and never a duration.
- The number of skipped-marked lines equals the `N steps skipped` total and the table's `Skip` column.
- report.json, JUnit and Allure keep their current statuses (this is a console change only).
- Runner test (pkg/cli): `printCommand` for a `skipped` and a `pending` command prints the skipped marker; a
  `failed` command still prints `✗` and its error line.
