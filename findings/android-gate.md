# Android gate findings (seeded from Task 2's GATE-NOTES; verify and renumber as AND-F entries)

# Android gate notes (grantiva 2.0.1, runner 1.1.18-grantiva.7+android-drivers-2, emulator-5554 Pixel_8_API_35)

Gate result (Step 7 loop, final run on the committed build): 01-08, 11, 12 PASS. 02 hit one
infra flake in an earlier run, then passed 4/4. 09 and 10 FAIL (CLI/runner defect 1). 99 fails as
required, but for the wrong reason (defect 1): the crash env never reaches the app, so the flow fails only at "This never appears".

## Defect 1: launch environment never reaches the app on Android

Flow-level `env:` (09-seed-empty, 10-seed-many, 99-crash) and `grantiva run --env KEY=VALUE`
(which the CLI injects as `launchApp: environment:`) are both dropped. The runner sends:

    POST /session/<id>/appium/device/launch_app body={"appId":"com.kylebrowning.landmarks"}

and the activity starts with no extras:

    I Landmarks: launch action=android.intent.action.MAIN data=null extras=[none] env=[LANDMARKS_SEED=null, ...]
    ActivityTaskManager: START u0 {act=android.intent.action.MAIN cat=[android.intent.category.LAUNCHER] flg=0x10200000 pkg=com.kylebrowning.landmarks cmp=.../.MainActivity}

Only `launchApp: arguments:` is delivered, as string intent extras:

    launch_app body={"appId":"com.kylebrowning.landmarks","arguments":{"LANDMARKS_SEED":"empty"}}
    I Landmarks: launch ... extras=[LANDMARKS_SEED=empty]

(probe flow with `arguments:` passes 09's assertion). The app honors extras: started by hand
with `am start --es LANDMARKS_SEED empty|many`, flows 09 and 10 minus `launchApp` pass, and
`--es LANDMARKS_CRASH_ON_LAUNCH 1` throws `RuntimeException: LANDMARKS_CRASH_ON_LAUNCH`.

Failure tails:

    $GRANTIVA run --flow .maestro/09-seed-empty.yaml --emulator Pixel_8_API_35 --report-dir build/reports/09-seed-empty
        ✓ launchApp (1.7s)
        ✗ assertVisible: text="No landmarks yet" (18.0s)
      09-seed-empty  ✗ FAIL  3 1 1 1  19.8s
    Error: Runner failed (exit 1)

    $GRANTIVA run --flow .maestro/10-seed-many.yaml --emulator Pixel_8_API_35 --report-dir build/reports/10-seed-many
        ✓ scroll x4
        ✗ assertVisible: text="Landmark 30"
    Error: Runner failed (exit 1)

    $GRANTIVA run --flow .maestro/09-seed-empty.yaml --no-build --env LANDMARKS_SEED=empty ...
        ✗ assertVisible: text="No landmarks yet" (17.9s)   # --env dropped too

Expected: flow `env:` / `--env` / `launchApp.environment` delivered to the app (as intent
extras on Android, per the label contract).

## Defect 2: `swipe: { direction: LEFT, from: "<text>" }` silently ignores `from`

02-favorite passes, but only because each Favorites row also has a visible `Remove` button.
The swipe step reports success (`✓ swipe: LEFT (333ms)`), makes no element lookup for
"Lake Tahoe" (nothing in client.log between the previous step and the next), and the
screenshot right after it shows the row unchanged. A coordinate swipe
(`swipe: {start: 60%, 17%, end: 5%, 17%}`) on the same row reveals the swipe `Remove` action,
and so does `adb shell input swipe 155 345 0 345 300` (a short swipe from the element center).
So `from:` is not honored: the swipe happens elsewhere (likely screen center, which is empty
space on this screen). Silent no-op rather than an error.

## Flake: UIAutomator2 socket dropped mid-flow (02, once)

    [ERROR] Step 7 failed (165ms): takeScreenshot - Error: Failed to take screenshot: send request:
    Get "http://localhost/session/.../screenshot": dial unix /tmp/uia2-emulator-5554.sock: connect: connection refused

Passed 3/3 on immediate rerun. The socket path is per-serial (`/tmp/uia2-emulator-5554.sock`),
so another agent's runner on the same emulator could kill it; not proven.

## Device state: Gboard "Try out your stylus" sheet on first inputText (03, once)

First run of 03-edit: after `inputText: " Renamed"` (W3C key actions) Gboard's one-time stylus
onboarding sheet covered the screen; only the leading space was typed and `tapOn: "Done"`
timed out (17.5s). It did not reappear; 03 passed on every later run. Fresh emulators will hit
this once; Grantiva's Android setup could disable it (e.g. `settings put secure stylus_handwriting_enabled 0`)
alongside the demo-mode and animation settings.

## Minor

- `grantiva doctor` in `android/` reports "Git Repository: Not a git repository" although
  `android/` is inside the landmarks-demo git work tree (it checks only the cwd for `.git`).
- Text matching is substring (`textContains`, then `descriptionContains`): `tapOn: "Favorite"`
  resolves to the detail button only because `textContains("Favorite").clickable(true)` misses
  and `descriptionContains` is tried before plain `textContains`. Labels like "Favorites" vs
  "Favorite" are fragile under this order.

## Files changed
Everything is new under `/Users/kyle/Developer/landmarks-demo/android/`: `.gitignore`, `settings.gradle.kts`, `build.gradle.kts`, `gradle.properties`, `gradle/libs.versions.toml`, `gradle/wrapper/gradle-wrapper.{jar,properties}`, `gradlew`, `gradlew.bat`, `app/build.gradle.kts`, `app/src/main/AndroidManifest.xml`, `app/src/main/res/values/{strings,themes}.xml`, `app/src/main/java/com/kylebrowning/landmarks/{LandmarksApp,MainActivity,TestEnvironment}.kt`, `data/{Category,Landmark,SampleData,LandmarkStore}.kt`, `nav/{Screen,AppNavHost}.kt`, `ui/{Common,LandmarksListScreen,LandmarkDetailScreen,CategoryScreen,VisitConfirmationScreen,EditLandmarkScreen,FavoritesScreen,DeepLinksScreen,CachingDemoScreen,SlowScreen}.kt`, `grantiva-android.yml`, `.maestro/01..12, 99`. That is 46 files. `ui/Common.kt` (shared top bar) is the only file the brief did not list. Nothing outside `android/` was touched; the untracked `ios/` belongs to the iOS agent.

## Self-review findings
- Fixed before commit: after process death the store would have come back empty on restore. `LandmarkStore.isSeeded` now forces a re-seed.
- Known minor issue, not fixed: a row revealed by swipe stays revealed after switching tabs and back, because the SwipeToDismissBox state is saveable. It doesn't affect any flow.
- `MainActivity.logLaunch` uses the deprecated `Bundle.get` for its debug log. It only produces a compile warning.
- I did not hand-test tab back-stack preservation across switches (one NavController per tab plus a SaveableStateHolder). The flows exercise only pop-to-root on reselect.
- `grantiva-android.yml` adds a `flows:` list (01-12), which the contract implies but does not spell out.

## Concerns
1. Defect 1 (Android runner drops launch `env` / `environment`; only `arguments` work) blocks 09, 10 and makes 99 pass for the wrong reason. It needs a CLI or runner fix, or a contract decision to use `launchApp: arguments:` on Android. I did not change flow semantics.
2. Defect 2: `swipe from:` is silently ignored. 02 is green only because of the visible per-row Remove button.
3. Flow 03 needs the edited name to be visible on Deep Links. See the design decision above; the iOS app must do the same.
4. The shared emulator's UIAutomator2 socket (`/tmp/uia2-emulator-5554.sock`) dropped once. Another agent may be driving emulator-5554 at the same time.
