# Candidate 2 Android stop-focus diagnosis

**Diagnosis verdict: HARNESS OUTPUT-SHAPE FALSE NEGATIVE; NO PRODUCT FAILURE.** The candidate 2 literal L77 flow passed, the exact target package was absent, and additive read-only evidence proves that Settings was the focused window and the visible UI after the flow. The failing assertion queried a restricted `dumpsys window windows` view that omits `mCurrentFocus` on this Android image. This is the same limitation retained and qualified in candidate 1.

## Direct evidence

- `02-runner-android/helper/stop-bare-clearstate/raw-report/report.json` and its flow detail retain the successful literal `launchApp: {clearState: true}` -> visible `Landmarks` -> bare `stopApp` -> not-visible `Landmarks` flow. The helper reached the later focus assertion, so all preceding healthy, crash, gesture, favorite, and L77 runner checks had completed.
- `02-runner-android/helper/stop-package-pid/{command.json,result.json,stdout.raw}` records exact serial `emulator-5580`, exact package `com.kylebrowning.landmarks`, expected and actual exit 1, and empty stdout. The target process was absent immediately after the flow.
- `02-runner-android/helper/stop-focused-window/command.json` records `adb -s emulator-5580 shell dumpsys window windows`, exit 0. Its 47,228-byte stdout contains the Settings window `Window{49ce5c9 ... SettingsHomepageActivity}`, the matching activity `ActivityRecord{76d73e0 ...}`, and Settings as the IME layering/input/control target. It contains `mTopFocusedDisplayId=0`, but no `mCurrentFocus` field. Therefore the helper's line 113 regular expression cannot match even though the restricted output contains the intended Settings window.
- The additive, non-mutating `02a-stop-focus-diagnosis/full-window.stdout` from `adb -s emulator-5580 shell dumpsys window` contains `mCurrentFocus=Window{49ce5c9 ... com.android.settings/...SettingsHomepageActivity}` and `mFocusedApp=ActivityRecord{76d73e0 ...}`. These are the same exact window and activity IDs found in the earlier restricted capture, binding the complement to the preserved post-flow state rather than a different Settings instance.
- `02a-stop-focus-diagnosis/hierarchy.stdout` is a Settings hierarchy and contains no `com.kylebrowning.landmarks`. `package-pid` again exits 1 with empty output. `identity.stdout` identifies the owned `smoke4-android` AVD, while every diagnostic command JSON binds serial `emulator-5580` and the provisioning ownership manifest.

The full dump includes historical Landmarks window/ANR records, but those records are not current-focus or live-process evidence. The same dump names Settings as `mCurrentFocus`/`mFocusedApp`; the contemporaneous hierarchy exposes Settings only; and the repeated exact-package `pidof` is empty. Those direct current-state checks control the classification.

## Candidate 1 comparison

Candidate 1 did not actually pass this assertion within the monolithic helper. Its `helper-attempt5/stop-focused-window/stdout.raw` has the same shape: a 47,217-byte successful restricted dump with the Settings window and IME targets, `mTopFocusedDisplayId=0`, and no `mCurrentFocus`. Candidate 1's invocation therefore exited at the same assertion. The retained `02-runner-android/acceptance.json` explicitly says attempt 5 exited because the restricted window dump omitted `mCurrentFocus`, and `task8-android-continuation-review.md` / `task8-android-final-review.md` accepted the separately captured full-window and hierarchy complement without rewriting the failed invocation.

The current and historical helper sources are byte-identical, including the exact restricted command and regex. Candidate 2 is consequently a reproduction of the known evidence-controller assumption, not a regression in `stopApp` or a difference between candidate binaries.

## Disposition

The candidate 2 L77 stop postcondition is supported by the original passing literal flow, immediate exact-package absence, and the additive full-window plus hierarchy complement. Preserve the original assertion failure and the additive records together, as candidate 1 did. No flow rerun or product change is justified by this failure. A future harness revision may use the full `dumpsys window` view (or another focus-specific surface) for `mCurrentFocus`; that maintenance is separate from this completed diagnostic and must not rewrite the retained failed invocation.

**Spec verdict: APPROVED for the bounded candidate 2 L77 stop evidence with its additive complement.**

**Quality verdict: APPROVED; no product defect is evidenced.** The only identified defect is the already-known harness assumption that `dumpsys window windows` includes the global `mCurrentFocus` field.
