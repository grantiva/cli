# Android `assertVisible` failure prints the raw UIAutomator2 error twice and never names the selector

Severity: contract
Component: runner
Platforms: android (Android-only for the message; iOS X-019 names the selector. The missing `Run grantiva hierarchy ...` hint is shared with iOS and is tracked as C93)
Rows: X-019 (android); original brief C21 (QA campaign, criterion 1, via the matrix row)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Matrix X-019: an element-not-found failure has the same line structure on both platforms and carries the remediation
(`Run grantiva hierarchy ...`, brief C21). On iOS the same flow prints the selector and the closest texts on screen
(findings/evidence/cov-ios/FLOWS-26/02-exact-negative.err:55):
```
      ╰─ Element not visible: text='Golden Gate.*' (cause: context deadline exceeded: no elements match selector; closest on-screen texts: "Golden Gate Bridge", "Golden Gate Bridge, San Francisco, CA", "Categories")
```

## Actual
Android, same flow (X-019/01.err:33-34, repeated in the summary block at :41-42, then :71):
```
    ✗ assertVisible: text="Golden Gate.*", exact=true (17.1s)
      ╰─ Element not visible: context deadline exceeded: no such element: An element could not be located on the page using the given search parameters (cause: context deadline exceeded: no such element: An element could not be located on the page using the given search parameters)
...
Error: Runner failed (exit 1); see the runner output above.
```
No selector, the WebDriver text twice, no closest-text list and no remediation. 1 of 1 runs.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k02
unset GRANTIVA_API_KEY
rm -rf /tmp/k02 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k02 && cd /tmp/k02/android
SERIAL=$(grantiva emulator ensure --name fix-k02)
grantiva build install --device "$SERIAL" --no-launch
grantiva run --device "$SERIAL" --no-build --flow .maestro/coverage/02-exact-negative.yaml > /tmp/k02/out.txt 2>&1; echo "exit $?"
grep -A1 '✗ assertVisible' /tmp/k02/out.txt; tail -2 /tmp/k02/out.txt
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-k02
```
Flow `.maestro/coverage/02-exact-negative.yaml`:
```
appId: com.kylebrowning.landmarks
---
- launchApp
- assertVisible: "Golden Gate.*"
- assertVisible:
    text: "Golden Gate.*"
    exact: true
```

## Evidence
- findings/evidence/cov-android/X-019/01.err lines 33-35, 41-43, 71; X-019/commands.txt
- findings/evidence/cov-ios/FLOWS-26/02-exact-negative.err lines 55, 63 (iOS wording for comparison)

## Suspected cause
Runner (release-round1, ae48e34):
- `pkg/driver/uiautomator2/commands.go:276-279` (`assertVisible`): on a failed `findElementFast` it returns
  `errorResult(err, fmt.Sprintf("Element not visible: %v", err))`. The message is the raw error, and
  `core.ErrorResult` appends `(cause: <err>)`, so the WebDriver text appears twice. The WDA driver instead formats
  `selectorDesc(step.Selector)` (pkg/driver/wda/commands.go:328, helper at :1770) and its not-found error carries the
  closest on-screen texts (pkg/driver/wda/driver.go:1377).
- The same `%v` pattern is used for `Element not found` at uiautomator2/commands.go:40, 159, 192, 420, 1963, so
  `tapOn` and friends have the same defect.
- The remediation hint lives only in the CLI's `GrantivaError` (Sources/GrantivaCore/GrantivaError.swift:35), which the
  `run` path never produces; that half is C93.

## Acceptance criteria
- The repro prints `Element not visible: text='Golden Gate.*', exact=true` (or the iOS wording `text='Golden Gate.*'`)
  followed by one cause; the WebDriver message appears at most once.
- Where the page source is available, the Android cause lists the closest on-screen texts like iOS (or the brief
  states why Android cannot).
- `tapOn: "No Such Element"` on Android fails with `Element not found: text='No Such Element'`, not the raw error.
- After C93 lands, the remediation line follows on both platforms.
- Runner test (pkg/driver/uiautomator2): a fake client whose element lookup times out yields a step message that
  contains the selector description and does not repeat the cause.
