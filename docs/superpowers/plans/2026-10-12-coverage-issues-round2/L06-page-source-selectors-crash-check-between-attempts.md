# On Android, element waits answered from the page source (relative, index and size selectors) check for a crash only between attempts and never re-check a match, so they can pass on a dead app or detect its crash late

Severity: wrong-result
Component: runner
Platforms: android (Android-only: UIAutomator2 driver's page-source waits)
Rows: PR #20 review (task-A1-report.md "What changed" L02 "Not covered", "Concerns" 7); no device row yet
Binary: grantiva 2.1.0 (main e02e30a), grantiva-runner 1.1.28-grantiva.10 + PR #20 branch af369f1

## Expected
After L02, every element wait behaves the same on a crashed launch, whatever the selector kind: the step fails with
`error.type` `app_crash` and the FATAL EXCEPTION cause within ~2 s of the process dying, a request held by the dying
app does not delay detection beyond one crash poll (1 s), and a match found after the process died never passes.

## Actual
PR #20 covers only the waits that go through `watchedAttempt` (UiSelector lookups). Selectors the driver answers from
the page source still run the pre-L02 loop: a crash check before each attempt, none while `GET /source` is in flight,
and no re-check of a match. Found in review of af369f1; not yet reproduced on a device. What can follow:
- `assertVisible: {below: "X", text: "Y"}`, `{text: "Y", index: 1}` or `{text: "Y", width: N}` after a crashed
  launch matches what is left on screen (the launcher's label, as round2b-A3 run 1 matched "Landmarks" on the dead
  app before L02) and the step passes; the crash is pinned on the next step.
- A `GET /source` held by the server against a dying app (as the first `POST /element` was held 10 s in
  round2b-A3/crash-1..3-client.log:7) runs to the request floor before the next crash check, so detection takes
  10 s+ instead of ~1 s.
- tapOn by text: the UiSelector lookups are watched, but the page-source fallback's `GET /source` is not, so a held
  source request delays detection the same way (at af369f1 the fallback's match is not re-checked either; 1c14f02 on
  the PR branch adds that re-check).

## Repro
Not run (no device in this pass). Variant of 99-crash with one page-source selector per kind:
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l06
unset GRANTIVA_API_KEY
rm -rf /tmp/l06 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l06 && cd /tmp/l06/android
SERIAL=$(grantiva emulator ensure --name fix-l06)
grantiva build install --device "$SERIAL"
for kind in index below width; do
  case $kind in
    index) sel='{text: ".*", index: 1}' ;;
    below) sel='{text: ".*", below: "Landmarks"}' ;;
    width) sel='{text: "Landmarks", width: 1}' ;;   # set width to the launcher label's width if it does not match
  esac
  printf 'appId: com.kylebrowning.landmarks\nenv:\n  LANDMARKS_CRASH_ON_LAUNCH: "1"\n---\n- launchApp\n- assertVisible: %s\n- tapOn: %s\n' "$sel" "$sel" > .maestro/99-crash-$kind.yaml
  for i in 1 2 3; do
    /usr/bin/time -p grantiva run --device "$SERIAL" --no-build --flow .maestro/99-crash-$kind.yaml --report-dir /tmp/l06/$kind-$i > /tmp/l06/$kind-$i.txt 2>&1
    grep -E 'assertVisible|tapOn|app crashed|real' /tmp/l06/$kind-$i.txt | head -5
    grep -E 'GET .*/source ' /tmp/l06/$kind-$i/client.log | head -3 | cut -c1-120
  done
done
grantiva emulator teardown --serial "$SERIAL"; avdmanager delete avd -n fix-l06
```
Defect: any run where the first assert passes, or fails later than ~2 s after `am_crash`
(`adb logcat -b events -d -s am_crash`), or fails with an error other than `app_crash`.

## Evidence
- .superpowers/sdd/2026-10-11-round2-fix-wave/task-A1-report.md: L02 "Not covered: page-source-only waits
  (relative/index/size selectors) still check only between attempts"; "Concerns" 7
- findings/evidence/round2-smoke/round2b-A3/crash-1.txt:32-35, crash-1..3-client.log:7 (held first request; a match on
  the dead app passing, pre-L02, on the UiSelector path)
- Runner tests at af369f1 cover only the UiSelector path (crash_during_find_test.go:56, :90, :122, :140); the tap
  fallback's match is covered from 1c14f02 (crash_during_find_test.go:200, `TestPageSourceMatchOnDeadAppFailsWithAppCrash`)
- Related: L02 (docs/superpowers/plans/2026-10-12-coverage-issues-round2/L02-android-crash-check-blocked-by-request.md), L05

## Suspected cause
Runner af369f1 (/Users/kyle/Developer/maestro-runner/.worktrees/fix3-uia2), pkg/driver/uiautomator2/driver.go unless
noted.
- Routing to the page source: `findElementWithContext` (:643) sends relative selectors to
  `findElementRelativeWithContext` (:645-647), size selectors (`width`/`height`, :650) and non-zero `index` (:655) to
  `findElementByPageSourceWithContext`, all before the watched UiSelector loop (`watchedAttempt` at :696).
  `findElementForTap` (:503) sends relative selectors straight to `findElementRelativeWithContext` (:505-510) and
  index selectors through `findElementWithOptions` (:513, :632). assertVisible reaches the same loops via
  `findElementFast` (:490) -> `findElementWithOptions`.
- `findElementRelativeWithContext` (:927-950): `crashed()` runs only before each attempt (:939) and is the throttled
  `newCrashCheck`, which at af369f1 also skips the first attempt (wait_crash.go:22-37, `first` at :26-31). The attempt
  `resolveRelativeSelector` (:964) fetches `d.client.Source()` (:982) with no `watchedAttempt` around it, and a
  match returns at :942-944 with no crash re-check.
- `findElementByPageSourceWithContext` (:1283-1306): same shape; the attempt `findElementByPageSourceOnceInternal`
  (:1310) fetches `d.client.Source()`, and a match returns at :1298-1300 with no re-check.
- tapOn by text: `findElementForTapWithContext` (:537) watches its UiSelector lookups (:564, :575), but its
  page-source fallbacks (:584-586 and :594-596) and `findElementWithContext`'s final fallback on timeout (:679-681)
  call `findElementByPageSourceOnce` (`client.Source()` at :1183) unwatched and, at af369f1, return a match unchecked.
- `GET /source` cannot be cancelled by a crash: `Client.Source()` takes no context and is sent under the step context
  (pkg/uiautomator2/device.go:170-171, client.go:139-140), so even wrapped in `watchedAttempt` the request would keep
  running; the wait would return at once but the server stays busy (see L05).
- Since af369f1 the PR branch gained 1c14f02 ("Re-check every match an element wait returns while the crash watch
  is armed (L02)"): it drops the first-attempt skip, adds `confirmMatch` (wait_crash.go:38-46 there) to the tapOn
  page-source fallbacks and the final fallback, and adds `TestPageSourceMatchOnDeadAppFailsWithAppCrash`
  (crash_during_find_test.go:200 there). At 1c14f02 `findElementRelativeWithContext` (:949-972, match at :964-966)
  and `findElementByPageSourceWithContext` (:1305-1328, match at :1320-1322) still have neither a concurrent check
  nor `confirmMatch`, and no page-source `GET /source` is watched.

## Acceptance criteria
- Every selector kind (UiSelector text/id/desc, relative `below`/`above`/`leftOf`/`rightOf`/`childOf`/`containsChild`,
  non-zero `index`, `width`/`height`, and tapOn's page-source fallback) fails the step with `app_crash` and the FATAL
  EXCEPTION cause within ~2 s of the crash, for assertVisible and tapOn.
- The crash check runs while a page-source attempt is in flight (the attempt goes through `watchedAttempt` or
  equivalent), and a crash cancels the in-flight `GET /source` (a context-taking `SourceCtx`).
- A page-source match found after the launched process died never passes: every page-source wait re-checks its match
  (`confirmMatch`) while the watch is armed.
- Live-app behaviour unchanged: a prompt page-source match on a live app costs no extra device calls beyond the
  single `pidof` re-check; a slow `GET /source` on a live app still passes.
- Runner tests in pkg/driver/uiautomator2 (next to crash_during_find_test.go), one per selector kind (relative,
  index, size, tap fallback), each with a fake client and the `lockedDevice` crash signal: (a) `Source()` blocks 10 s
  while the device reports the process gone plus a FATAL EXCEPTION -> step fails with `ErrAppCrashed` within 2 s;
  (b) `Source()` returns a matching hierarchy after the device is killed (launcher label) -> `ErrAppCrashed`, no tap
  sent; (c) live app, slow `Source()` that matches -> success.
