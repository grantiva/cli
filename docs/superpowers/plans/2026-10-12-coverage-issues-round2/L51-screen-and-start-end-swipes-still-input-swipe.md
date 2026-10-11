# Screen swipes, `start:`/`end:` swipes and `engine: adb` still go through `adb shell input swipe`

Severity: minor
Component: runner
Platforms: android
Rows: none yet; found in review of runner PR #21 (round-3 Task 2)
Regresses/extends: L07 (held-drag element swipes), K11 (bare scroll device independence)
Binary: grantiva-runner 1.1.28-grantiva.11 + PR #21 branch 7a6ff7c

## Expected
Every swipe the runner performs on Android uses one gesture engine with the same timing model, so a flow author gets the
same travel, the same fling behaviour and the same `distance:`/`duration:` semantics whether the swipe targets an element,
a screen direction, or explicit `start:`/`end:` points. `engine: adb` stays as the explicit opt-in to `input swipe`.

## Actual
Round 3 moved element swipes to UIAutomator2 held drags (L07). Screen-direction swipes and `start:`/`end:` swipes still
run `adb shell input swipe`, which flings at a fixed velocity on software-rendered AVDs and ignores `duration:` on some
API levels. The PR comment, body and CHANGELOG state this explicitly as the round-3 scope.

## Reproduce
On the default AVD: a flow with `swipe: {direction: UP}` then `swipe: {element: {id: list}, direction: UP}` on the same
list; compare travel distance and settle time from `dump-hierarchy` before and after each step.

## Fix direction
Route direction and point swipes through the same held-drag path as element swipes (start point = screen point or
`start:`), keep `engine: adb` as the escape hatch, and extend the L07 tests to the three forms. Schedule: round 4 unless
the round-3 coverage pass turns a `B3-L` row red on it.
