# On Android, assertVisible with count: is unwatched and can pass on the launcher after a crash, and extendedWaitUntil visible does not cancel a held request, so crash detection can stretch to the request deadline

Severity: wrong-result
Component: runner
Platforms: android (Android-only: UIAutomator2 driver)
Rows: none yet; found in review of runner PR #22 (not run on a device)
Regresses/extends: L06, L24, K97 (L06 covered relative/index/size selectors and the tap fallback, not these two paths)
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11 + PR #22 branch 44ac084

## Expected
Every Android element wait fails with `app_crash` and the FATAL EXCEPTION cause within ~2 s of the launched process
dying, and a match found after the process died never passes, whichever path answers it. A request held by the dying
app is cancelled by the crash instead of being waited out.

## Actual
Two gaps remain on the PR #22 branch after L02/L06. Found by reading the source; not reproduced on a device.
- (a) `assertVisible: {text: ..., count: N}` goes `assertVisibleCount` (`commands.go:~288`) -> `countVisibleMatches`
  (`commands.go:~328-345`). That calls the unwatched `d.client.Source()` and returns the count with no crash check
  and no `confirmMatch`, and the loop (`for { select ... default }`) has no crash check between attempts either. After
  a crash the launcher is on screen; a count that matches its labels passes the step (e.g. `count: 2` of "Landmarks"
  on the launcher, as `launcherSource` in pagesource_crash_test.go), and a count that does not match spins to the
  assert timeout and fails with the count message, not `app_crash`. A `GET /source` held by the dying server also
  stalls it.
- (b) `extendedWaitUntil: {visible: ...}` (`waitUntil`, `commands.go:~2565-2580`) checks the crash before each attempt
  (`newCrashCheck`) and re-checks a returned match (`confirmMatch`, L02), but the attempt itself is
  `d.findElementOnce(*step.Visible)` (driver.go:772), which runs unwatched under the step context. A request the
  server holds against a dying app is therefore not cancelled by a crash, and detection waits for the request to
  return (round2b-A3 saw a first request held 10 s), up to the request deadline, instead of ~1-2 s. The pre-attempt
  check does not run while the attempt is in flight.

## Repro
Not run (no device in this pass). Variant of 99-crash, run as in L06's recipe (3 runs each):
```
appId: com.kylebrowning.landmarks
env:
  LANDMARKS_CRASH_ON_LAUNCH: "1"
---
- launchApp
- assertVisible: {text: "Landmarks", count: 2}
- extendedWaitUntil:
    visible: {text: "Landmarks Home"}
    timeout: 20000
```
Defect: the count assert passes (or fails with the count message rather than `app_crash`), or the wait fails with
`app_crash` later than ~2 s after `am_crash` (`adb logcat -b events -d -s am_crash`). (b) needs a server that holds
the request, so it is only reliably shown by the unit test below.

## Evidence
- Source read at fix3/crash-detection (44ac084), /Users/kyle/Developer/maestro-runner/.worktrees/fix3-crash:
  pkg/driver/uiautomator2/commands.go:~288-345 (`assertVisibleCount`, `countVisibleMatches`: `d.client.Source()`, no
  `watchedInfo`, no `confirmMatch`); commands.go:~2565-2580 (`waitUntil` visible branch: `newCrashCheck` before
  `findElementOnce`, `confirmMatch` after); wait_crash.go `watchedAttempt`/`watchedInfo`/`sourceCtx` exist and are used by the
  other element waits (driver.go:590, :733, :974, :1236, :1363).
- pagesource_crash_test.go covers relative/index/size/tap fallback (L06) and a dead-app match for `waitUntil`
  (`TestWaitUntilVisibleOnDeadAppFailsWithAppCrash`, :154) but no held-request case for `waitUntil` and nothing for count.
- Related: L02, L05, L06, L24.

## Suspected cause
L06 routed the single-match page-source attempts through `watchedInfo`; `countVisibleMatches` was a separate loop and
was not touched. `waitUntil` was given the pre-attempt check and `confirmMatch` in L02, but its attempt was not
wrapped in `watchedAttempt`/`watchedInfo`, which is what cancels a held request (`SourceCtx`, `contextSourcer`).
Not confirmed from source: whether `findElementOnce` honours a cancelled context on its UiSelector path
(`tryFindElement` takes no context, so wrapping it in `watchedAttempt` may return at once on a crash while the
server request keeps running, as in L05/L06); the fix may need context-taking client calls for that path.

## Acceptance criteria
- `assertVisible` with `count:` runs each attempt through the crash watch (in-flight check every crash poll, the
  `GET /source` sent with `SourceCtx` so a crash cancels it) and re-checks a returned count (`confirmMatch`) before
  it passes. A crash fails the step with `app_crash` and the FATAL EXCEPTION cause within ~2 s, including when the
  count does not match the launcher.
- `extendedWaitUntil: visible` attempts run through the crash watch so a crash cancels a held request: `app_crash`
  arrives within ~2 s even when the request would be held 10 s or more.
- Live app unchanged: a prompt match costs no extra device calls beyond the single `pidof`; a slow request on a
  live app that matches still passes.
- Intentional stopApp/killApp/clearState exempt (watch off), as L24.
- Runner tests in pkg/driver/uiautomator2 (next to pagesource_crash_test.go), fake client plus the `lockedDevice`
  crash signal, per path:
  - count: (a) `Source()` blocks 10 s while the app dies -> `ErrAppCrashed` within 2 s; (b) `Source()` returns the
    launcher with a matching count after the kill -> `ErrAppCrashed`; (c) live app, slow `Source()` with the right
    count -> success.
  - waitUntil visible: (a) `FindElement`/`Source()` blocks 10 s while the app dies -> `ErrAppCrashed` within 2 s;
    (b) live app, slow match -> success.
