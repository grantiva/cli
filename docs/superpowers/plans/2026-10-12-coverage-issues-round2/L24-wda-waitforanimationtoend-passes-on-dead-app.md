# On iOS `waitForAnimationToEnd` right after a crashed launch passes in about 0.5 s instead of failing with `app_crash`

Severity: wrong-result
Component: runner
Platforms: ios (iOS-only: the WDA driver. On Android the same flow's assert fails with `app_crash`; Android's open crash-wait gaps belong to L02/L06, not this brief)
Rows: N2-13 [ios]
Regresses/extends: K97 (crash during a wait reported as wrong error type), fixed by runner #18 (bundled from 1.1.28-grantiva.10). Extends it to the settle wait. The iOS sibling of L06's "a wait can pass on a dead app".
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
N2-13 and K97: no wait passes against a dead app. After `launchApp` of an app that crashes on launch, each wait command
ends at once with `error.type: app_crash` and the "app crashed: <bundle> is not running" cause, as `extendedWaitUntil`,
`assertNotVisible` and `scrollUntilVisible` already do on iOS.

Triage note: `waitForAnimationToEnd` is a settle, not an element wait, and it never fails today. It even reports
"did not settle within … — continuing" as success. The owner should confirm that the K97 rule covers it. The case for
yes: grantiva's generated screens flows put `waitForAnimationToEnd` before every `takeScreenshot`
(`Sources/GrantivaCore/Runner/FlowGenerator.swift:100-106`), so a screen captured right after a crashed launch is
taken of whatever is left on screen (cluster M38, brief L45, has the same weakness on Android).

## Actual
`LANDMARKS_CRASH_ON_LAUNCH: "1"`, then `waitForAnimationToEnd {timeout: 5000}`, then `assertVisible: "Featured"`. The
settle passes in 506 ms against the dead app, and only the next assert fails (findings/evidence/cov2-ios/N2-13/wait-anim.err:30-32):
```
    ✓ waitForAnimationToEnd (506ms)
    ✗ assertVisible: text="Featured" (127ms)
      ╰─ Element not visible: text='Featured' (cause: app crashed: com.kylebrowning.Landmarks is not running: WDA error: The application under test with bundle id 'com.kylebrowning.Landmarks' is not running, possibly crashed)
```
The other waits in the same row fail at once (findings/evidence/cov2-ios/N2-13/analysis.txt):
```
wait-anim None [('launchApp', 'passed', 1930, None), ('waitForAnimationToEnd', 'passed', 506, None), ('assertVisible', 'failed', 127, 'app_crash')]
wait-visible None [('launchApp', 'passed', 1949, None), ('extendedWaitUntil', 'failed', 7, 'app_crash')]
not-visible None [('launchApp', 'passed', 1963, None), ('assertNotVisible', 'failed', 10, 'app_crash')]
scroll-until None [('launchApp', 'passed', 1974, None), ('scrollUntilVisible', 'failed', 338, 'app_crash')]
```
The flow still fails, so no run turns green from this alone. 1 run of the wait-anim flow. 99-crash 3/3 fails correctly at
the first assert in 135-144 ms.

## Repro
Flow `wait-anim.yaml`:
```yaml
appId: com.kylebrowning.Landmarks
env:
  LANDMARKS_CRASH_ON_LAUNCH: "1"
---
- launchApp
- waitForAnimationToEnd:
    timeout: 5000
- assertVisible: "Featured"
```
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l24
unset GRANTIVA_API_KEY
rm -rf /tmp/l24 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l24 && cd /tmp/l24/ios
UDID=$(grantiva simulator ensure --name fix-l24 --device-type "iPhone 17" --runtime 26.0 | tail -1)
grantiva build install --simulator "$UDID"
printf 'appId: com.kylebrowning.Landmarks\nenv:\n  LANDMARKS_CRASH_ON_LAUNCH: "1"\n---\n- launchApp\n- waitForAnimationToEnd:\n    timeout: 5000\n- assertVisible: "Featured"\n' > wait-anim.yaml
for i in 1 2 3; do grantiva run --no-build --simulator "$UDID" --flow wait-anim.yaml --report-dir /tmp/l24/r$i 2>&1 | grep -E 'waitForAnimationToEnd|assertVisible'; done
# bug: "✓ waitForAnimationToEnd (~500ms)". Expected "✗ waitForAnimationToEnd" with app_crash
grantiva simulator teardown --session-id fix-l24
```

## Evidence
- findings/evidence/cov2-ios/N2-13/wait-anim.err, wait-anim.out, analysis.txt, flows/wait-anim.yaml, commands.txt
- findings/evidence/cov2-ios/N2-13/wait-visible.err, not-visible.err, scroll-until.err, crash1-3.err (the waits that pass the rule)
- docs/superpowers/plans/2026-10-11-coverage-issues/K97-crash-wait-error-type.md; docs/superpowers/plans/2026-10-12-coverage-issues-round2/L06-page-source-selectors-crash-check-between-attempts.md

## Suspected cause
Runner (release-round2b, 1be68db).
- `pkg/driver/wda/commands.go:1791-1816` (`waitForAnimationToEnd`) loops on two `client.Screenshot()` calls and returns
  success at the first pair within 0.5 % (`threshold = 0.005`). On timeout it also returns success
  ("Animation did not settle … — continuing"). It never consults the app state. A crashed app leaves the static home
  screen, which "settles" on the first pair (~500 ms = two screenshot round-trips).
- The K97 crash check is `appDied` (`pkg/driver/wda/wait_crash.go:37-55`). It runs only after an element-wait attempt
  fails with the agent's "is not running" error (callers at `commands.go:375,431,811,1766,1777`,
  `driver.go:633,754,1248`). Screenshots succeed on a dead app, so no such error reaches the settle, and it has no call to
  `appDied` anyway.
- Fix direction: when `d.launchedApp` is set, the settle checks `d.client.AppState(d.launchedApp)` once it has settled (and
  on timeout). `appStateNotRunning` returns `core.ErrAppCrashed.WithMessage("app crashed: <bundle> is not running")`, as
  `appDied` does. Rate limiting as in `appDied` (`appStateCheckInterval`).

## Acceptance criteria
- The repro flow fails 3 of 3 at `waitForAnimationToEnd` with `error.type: app_crash` and the "is not running" cause,
  within about 1 s of the step starting.
- With a live app, `waitForAnimationToEnd` timing and result are unchanged (stock set 12/12 on iOS 26.0 and 27.0; the
  screens captures in IOS-120 unchanged).
- A grantiva screens session whose app crashes on launch fails at the settle before `takeScreenshot`, so no capture of the
  home screen is saved as the screen.
- Runner tests in pkg/driver/wda (next to wait_crash_test.go): a fake client whose screenshots are identical and whose
  `AppState` returns 1 (not running) after a launch makes `waitForAnimationToEnd` return `ErrAppCrashed`. With `AppState`
  4 (foreground) it returns success as today. With no `launchedApp` it never queries the state.
