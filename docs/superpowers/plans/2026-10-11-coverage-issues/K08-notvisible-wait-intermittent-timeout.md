# Android `extendedWaitUntil: notVisible` sometimes never sees the element disappear and times out

Severity: wrong-result
Component: runner
Platforms: android (Android-only: iOS twin IOS-228 passed the wait in 5.2 s; its only failure was the `⚠` marker, C76)
Rows: AND-228 (android)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Matrix AND-228 (README:172 lists `extendedWaitUntil` with `notVisible:`): on the Slow Screen, whose `Loading…` label
is replaced after `SLOW_SCREEN_DELAY_MS` (about 3 s), `extendedWaitUntil {notVisible: "Loading…", timeout: 10000}`
passes once the label is gone, every run.

## Actual
1 of 5 runs failed (CF-09-waits/out-cf-09-waits.stderr:30-36):
```
    ✓ assertVisible: text="Loading…" (612ms)
    ✗ extendedWaitUntil: notVisible text="Loading…" (12.5s)
      ╰─ Element 'Loading…' still visible after 10s (cause: context deadline exceeded)
✗ 09-waits 17.3s
```
The other 4 passed in 2.5-2.8 s (CF-09-waits/02.run.stderr:35 and 03.out: `✓ extendedWaitUntil: notVisible text="Loading…" (2.8s)`,
`(2.5s)`, `(2.5s)`). In the failed run the wait also overran its 10 s timeout by 2.5 s.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k08
unset GRANTIVA_API_KEY
rm -rf /tmp/k08 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k08 && cd /tmp/k08/android
SERIAL=$(grantiva emulator ensure --name fix-k08)
grantiva build install --device "$SERIAL" --no-launch
for i in $(seq 1 10); do
  grantiva run --device "$SERIAL" --no-build --flow .maestro/coverage/09-waits.yaml --report-dir /tmp/k08/r$i 2>&1 | grep 'extendedWaitUntil: notVisible'
done
grep -c 'notVisible\|/element' /tmp/k08/r*/client.log    # lookups issued during the wait, per run
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-k08
```
Flow `.maestro/coverage/09-waits.yaml`:
```
appId: com.kylebrowning.landmarks
---
- launchApp
- tapOn: "Deep Links"
- tapOn: "Slow Screen"
- assertVisible: "Loading…"
- extendedWaitUntil:
    notVisible: "Loading…"
    timeout: 10000
- assertVisible: "Loaded after delay"
- waitForAnimationToEnd
- waitForAnimationToEnd:
    timeout: 2000
```

## Evidence
- findings/evidence/cov-android/CF-09-waits/out-cf-09-waits.stderr lines 30-36 (the failing run) and 44-46 (summary)
- findings/evidence/cov-android/CF-09-waits/02.run.stderr line 35, CF-09-waits/03.out (passing runs); CF-09-waits/commands.txt
- Row pointer: findings/evidence/cov-android/AND-228/commands.txt
- No client.log or hierarchy was kept for the failing run; the repro above keeps them.

## Suspected cause
Runner (release-round1, ae48e34), `pkg/driver/uiautomator2/commands.go:2302-2350` (`waitUntil`). Not confirmed.
- The `notVisible` branch (:2343-2347) calls `findElementOnce` and treats any non-nil result as "still visible"; it
  never checks `info.Visible` or bounds, so a node that stays in the tree after it stops being shown (Compose keeps the
  outgoing content during a crossfade, or keeps a zero-size/offscreen node) counts as visible for as long as it exists.
- `findElementOnce` (pkg/driver/uiautomator2/driver.go:628-664) falls back to a page-source scan for text selectors
  (:655-660); that scan matches nodes regardless of visibility, so if the UiAutomator lookup misses, the fallback can
  still report the hidden `Loading…` node.
- The loop has no sleep and no per-iteration deadline (:2349 comment), so one slow lookup (page source on a busy
  screen) can run past the step timeout, matching the 12.5 s for a 10 s timeout.

## Acceptance criteria
- The repro passes 10 of 10 runs; each passing wait takes under 4 s.
- `notVisible` counts an element as visible only when it is displayed with non-zero on-screen bounds (same rule as
  `assertNotVisible`), including in the page-source fallback.
- A `notVisible` wait that does time out finishes within timeout + 1 s and its message says what still matched
  (text and bounds).
- iOS unchanged (IOS-228 still passes the wait).
- Runner test (pkg/driver/uiautomator2): with a fake client whose lookup keeps returning a node marked not displayed
  (or zero bounds), `waitUntil{notVisible}` succeeds; with one returning a displayed node, it fails at the timeout and
  not later than timeout + one poll.
