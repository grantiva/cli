# iOS `swipe … from:` on a missing element says `Element not found:` without "for swipe", unlike the Android drivers

Severity: contract
Component: runner
Platforms: ios (iOS-only wording gap; the Android twin AND-219 passed on the "for swipe" wording but does not name the selector)
Rows: IOS-219, IOS-219@27.0 (ios); original brief R02 criterion 3 (docs/superpowers/plans/2026-10-10-regression-issues/R02-android-swipe-from-element-too-short.md)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
R02 criterion 3: "`from: \"No Such Row\"` still fails at the swipe with `Element not found for swipe`, exit 1".
Matrix IOS-219 applies that to iOS: the step fails at the swipe with `Element not found for swipe`, naming the
selector.

## Actual
FLOWS-26/07-swipe-from-missing.err:53-54 (26.0; FLOWS-27 is the same on 27.0), exit 1:
```
    ✓ launchApp (2.0s)
    ✗ swipe: LEFT (13.4s)
      ╰─ Element not found: text='No Such Row' (cause: context deadline exceeded: no elements match selector; closest on-screen texts: "show map", "Vertical scroll bar, 2 pages", "road.lanes")
```
The iOS line names the selector but not the action. Android (AND-219, cov-android results) says
`Element not found for swipe: context deadline exceeded: no such element ...`: the action, but not the selector.
Neither platform prints the form both criteria together imply.

## Repro
Flow (`ios/.maestro/coverage/07-swipe-from-missing.yaml`):
```
appId: com.kylebrowning.Landmarks
---
- launchApp
- swipe:
    direction: LEFT
    from: "No Such Row"
```
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k75
unset GRANTIVA_API_KEY
rm -rf /tmp/k75 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k75 && cd /tmp/k75/ios   # 4e49dc4
for rt in 26.0 27.0; do
  UDID=$(grantiva simulator ensure --name "fix-k75 $rt iPhone 17" --runtime $rt)
  grantiva build install --simulator "$UDID" --no-launch
  grantiva run --no-build --simulator "$UDID" --flow .maestro/coverage/07-swipe-from-missing.yaml 2>&1 | grep -A1 '✗ swipe'
done
grantiva simulator teardown --session-id fix-k75
```

## Evidence
- findings/evidence/cov-ios/FLOWS-26/07-swipe-from-missing.err (lines 50-60), .out, commands.txt
- findings/evidence/cov-ios/FLOWS-27/07-swipe-from-missing.err (lines 32-37)
- Android twin: findings/evidence/cov-android/AND-219/ (after merge)

## Suspected cause
grantiva-runner:
- `pkg/driver/wda/commands.go:866-872` (`swipe`, element branch): a failed `findElement` returns
  `findFailureMessage(err, *step.Selector)` (`pkg/driver/wda/offscreen.go:56-66`, which ends in
  `Element not found: <selector>`); the no-bounds branch at :870-871 also says `Element not found: …`.
- The Android drivers say `Element not found for swipe: %v` with the error, not the selector
  (`pkg/driver/uiautomator2/commands.go:1109`; `pkg/driver/devicelab/commands.go:1556`, :1562 uses
  `step.Selector.Describe()`).

## Acceptance criteria
- iOS 26.0 and 27.0: the swipe step fails with a line beginning `Element not found for swipe:` that names
  `text='No Such Row'` (the closest-texts cause may follow); exit 1.
- The off-screen variant keeps its own wording (`Element is off-screen (not missing): …`) but also says it was for a
  swipe.
- Android (UIAutomator2 and devicelab) also name the selector, so both platforms print the same structure (coordinate
  with whoever owns AND-219 / K01-style step wording).
- Runner tests: WDA `swipe` with a `From` selector that matches nothing returns a message containing
  `for swipe` and the selector description; same for the UIAutomator2 driver.
- Bundled runner version bumped in this repo if the runner changes.
