# iOS `scrollUntilVisible` takes 32-36 s to reach a row about 70 items down, roughly 2 s per scroll

Severity: ux
Component: runner
Platforms: ios (the Android twin AND-224 passed and ran the whole 08-scroll flow in 38.6 s, both searches included)
Rows: IOS-224, IOS-224@27.0 (ios); split from cluster C76 unexplained-warning-marker (the `⚠` marker is K76-a)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Matrix IOS-224 only requires both elements to be found (README:172), and they are. The slowness was noted by the
slice; as a yardstick, Android finds the same rows with the same flow in 38.6 s for the entire flow (AND-224 /
AND-038), while each iOS search alone takes about that long. No document sets a time budget.

## Actual
FLOWS-26/08-scroll.err:54-56 (26.0) and FLOWS-27/08-scroll.err:36-38 (27.0):
```
    ⚠ scrollUntilVisible: text="Landmark 70" (32.4s)
    ⚠ scrollUntilVisible: text="Golden Gate Bridge" (34.9s)
    ⚠ scrollUntilVisible: text="Landmark 70" (33.8s)
    ⚠ scrollUntilVisible: text="Golden Gate Bridge" (36.0s)
```
IOS-037 saw 33-35 s for the same steps. The per-iteration timing was not captured (no runner log kept for this run).

## Repro
Flow (`ios/.maestro/coverage/08-scroll.yaml`):
```
appId: com.kylebrowning.Landmarks
env:
  LANDMARKS_SEED: many
---
- launchApp
- scroll
- scrollUntilVisible:
    element: "Landmark 70"
    direction: DOWN
    timeout: 60000
- assertVisible: "Landmark 70"
- scrollUntilVisible:
    element: "Golden Gate Bridge"
    direction: UP
    timeout: 60000
- assertVisible: "Golden Gate Bridge"
- tapOn: "Deep Links"
```
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k76b
unset GRANTIVA_API_KEY
rm -rf /tmp/k76b && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k76b && cd /tmp/k76b/ios   # 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k76b iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID" --no-launch
grantiva run --no-build --simulator "$UDID" --flow .maestro/coverage/08-scroll.yaml --report-dir /tmp/k76b/out 2>&1 | grep scrollUntilVisible
grep -nE 'POST .*/elements|/screenshot|/actions|swipe' /tmp/k76b/out/maestro-runner.log | head -80   # per-iteration timeline
grantiva simulator teardown --session-id fix-k76b
```

## Evidence
- findings/evidence/cov-ios/FLOWS-26/08-scroll.err, .out; findings/evidence/cov-ios/FLOWS-27/08-scroll.err
- findings/evidence/cov-ios/IOS-037/ (33-35 s for the same steps)
- Android yardstick: cov-android results AND-224 / AND-038 (after merge: findings/evidence/cov-android/AND-224/)

## Suspected cause
Not confirmed (no runner log in the evidence). grantiva-runner `pkg/driver/wda/commands.go:760-829`
(`scrollUntilVisible`) does, per iteration: `findElement(step.Element, true, 1000)` (:790), which on a miss waits out
its full 1000 ms; when the element is in the tree but under the visibility threshold, a page-source fetch (:806); then
`d.scroll` (:819) and `d.settleScreen()` (:823; `pkg/driver/wda/driver.go:423-442`), which takes full screenshots
until two consecutive ones hash equal, up to `screenSettleLimit`. With about 15 scrolls to reach row 70 that is
roughly 2 s each. Hypothesis: the 1 s miss timeout plus at least two full-resolution screenshots per settle dominate.

## Acceptance criteria
- The runner log of the repro shows, per iteration, the find, scroll and settle durations (debug level is enough),
  so the cost is measured rather than guessed.
- Each `scrollUntilVisible` in 08-scroll completes in at most half of today's time on iOS 26.0 and 27.0 (≤ 17 s per
  search; adjust the target once the timeline is known and record it in the fix PR), still finding both elements and
  passing the flow.
- The fast path does not regress the "half-hidden element" and "made no progress" behaviours (commands.go:792-810,
  :823-825).
- Runner test (pkg/driver/wda, fake client): a miss in the per-iteration find does not block for the step's full
  find timeout when the element is absent from the tree, and settle takes at most N screenshots on a static screen.
- Bundled runner version bumped in this repo.
