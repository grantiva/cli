# Android Plan 2 acceptance pass

Date: 2026-10-08. Host: macOS (Darwin 27.2.0). Emulator `Pixel_8_API_35` running as
`emulator-5554`. `JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home`,
`ANDROID_HOME=$HOME/Library/Android/sdk`, platform-tools on PATH. CLI from `swift build` at the
worktree root; commands run from `examples/android` with `GRANTIVA=../../.build/debug/grantiva`.
Pre-run `window_animation_scale`: `1.0`.

The first pass stopped at step 4 (`diff capture`, exit 1) on a launch bug:
`adb shell monkey -p dev.grantiva.example -c android.intent.category.LAUNCHER 1` exited 251 with
`** SYS_KEYS has no physical keys but with factor 2.0%.` Commit 9723fc4 added `--pct-syskeys 0`
to `ADB.launch` and an `APK:` line to the Android build summary. The CLI was rebuilt and the pass
resumed at step 2 (re-run for the new output) and step 4 onwards. Steps 1 and 3 below are from
the first pass with the same sources apart from that fix (`run` launches through the runner, not
`ADB.launch`).

Result: 10 of 11 brief steps passed. Step 7 as written in the brief cannot pass against this
example (see there); the same check with a non-asserted text change passed.

## 1. `$GRANTIVA doctor` — PASSED

Exit status: 0.

```
  Required
    ✓ Android SDK       /Users/kyle/Library/Android/sdk
    ✓ adb               Android Debug Bridge version 1.0.41
    ✓ Android Emulator  /Users/kyle/Library/Android/sdk/emulator/emulator
    ✓ JDK               /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
    ✓ Android AVDs      Pixel_8_API_35
    ✓ Running Emulator  emulator-5554
    ✓ Runner            grantiva-runner 1.1.18-grantiva.7+android-drivers
  Project
    ✓ grantiva-android.yml  Found
    ● Git Repository        Not a git repository
  ...
  8 passed · 3 optional
```

Observations (not failures): only the Android section is printed. With only
`grantiva-android.yml` present, the platform selection is Android alone by design. "Not a git
repository" is existing behaviour: the check looks for `.git` in the current directory only.

## 2. `$GRANTIVA build` — PASSED

Exit status: 0 (re-run after 9723fc4).

```
[grantiva] Building :app:assembleDebug for Pixel_8_API_35...
✓ Build succeeded
  APK: /Users/kyle/Developer/grantiva-cli/.claude/worktrees/android-run-vrt/examples/android/app/build/outputs/apk/debug/app-debug.apk
  Duration: 0.5s
```

`output-metadata.json` gives `applicationId` `dev.grantiva.example`, output `app-debug.apk`.

## 3. `$GRANTIVA run --logs --verbose` — PASSED

Exit status: 0. 3 screens passed, 23 `[log]` lines, 0 occurrences of `xcrun` in the output.
Settings restored afterwards (`window_animation_scale` 1.0, `transition_animation_scale` 1.0,
`animator_duration_scale` deleted back to `null`, rotation restored).

```
Resolved: scheme=(none) simulator=Pixel_8_API_35 screens=3 flows=0
Preparing runner...
Runner ready
Booting emulator: Pixel_8_API_35
Emulator booted: Pixel_8_API_35 (emulator-5554)
...
[log] 10-08 10:30:38.716 I/rantiva.example( 7191): Late-enabling -Xcheck:jni
...
  Screens: 3 total, 3 passed, 0 failed
  Screenshots: .grantiva/captures/android/
```

Observation: "Booting emulator" is printed for an emulator that is already running, matching
the iOS wording.

## 4. `$GRANTIVA diff capture` — PASSED (after 9723fc4)

First attempt: exit status 1, FAILED:

```
Error: args: [-p, dev.grantiva.example, -c, android.intent.category.LAUNCHER, 1]
 ...
** SYS_KEYS has no physical keys but with factor 2.0%. exited with code 251
```

After 9723fc4: exit status 0.

```
Captured 3 screens in 9.4s
  Directory: .grantiva/captures/android
  Simulator: Pixel_8_API_35 (emulator-5554)
  Display: 411x914 points, 1080x2400 pixels @2.625x
  • Home (43.7 KB)
  • Details (52.8 KB)
  • Settings (36.3 KB)
```

`ls .grantiva/captures/android`: `Details.png Home.png Settings.png`.

## 5. `$GRANTIVA diff approve` — PASSED

Exit status: 0.

```
Approved 3 screens as baseline
  Directory: .grantiva/baselines/android
  • Details
  • Home
  • Settings
```

## 6. `$GRANTIVA diff compare` — PASSED

Exit status: 0.

```
✓ Visual diff passed
  Duration: 1.3s
  Passed: 3  Failed: 0  New: 0  Errors: 0

✓ Details  pixel=0.00%  perceptual=0.0
✓ Home  pixel=0.00%  perceptual=0.0
✓ Settings  pixel=0.00%  perceptual=0.0
```

## 7. `sed ... 's/Line three./Line three, changed./'` then `$GRANTIVA diff compare --capture` — FAILED as written

`sed` exit status 0 (line 62 became `Text("Line three, changed.")`). `diff compare --capture`
exit status 1:

```
Capturing 3 screen(s)...
...
    ✓ launchApp (1.7s)
    ✓ takeScreenshot (129ms)
    ✓ tapOn: text="Details" (760ms)
    ✗ assertVisible: text="Line three." (17.0s)
      ╰─ Element not visible: context deadline exceeded: no such element: An element could not be located on the page using the given search parameters (...)
✗ flow 19.7s
...
Error: Runner failed (exit 1):
 exited with code 1
```

Cause: the example's `Details` screen path has `assert_visible: Line three.`, so editing that
exact text makes the navigation assert fail before any screenshot is compared. The rebuild and
reinstall worked (the new text is what broke the assert). This is a conflict between the brief's
edit and the example config, not a CLI bug.

Supplementary check (not in the brief): `git checkout` the file, then
`sed -i '' 's/Line two./Line two, changed./'` (a line nothing asserts) and
`$GRANTIVA diff compare --capture`. Exit status 1, the expected result:

```
✗ Visual diff failed
  Duration: 11.8s
  Passed: 2  Failed: 1  New: 0  Errors: 0

✗ Details  pixel=0.08%  perceptual=62.7
    Failed: pixel=0.08% perceptual=62.7
✓ Home  pixel=0.00%  perceptual=0.0
✓ Settings  pixel=0.00%  perceptual=0.0
```

## 8. `git checkout app/src/main/java/dev/grantiva/example/MainActivity.kt` — PASSED

Exit status: 0 (`Updated 1 path from the index`). `git status` afterwards shows no change under
`examples/android`.

## 9. `$GRANTIVA ci run` — PASSED

Exit status: 1, before booting anything (with `--verbose`, no `adb`/`emulator` command is logged).

```
Error: Invalid argument: Android baselines are local only until the Grantiva backend supports platforms; use local baselines
```

## 10. `$GRANTIVA run --device emulator-5554` — PASSED

Exit status: 0.

```
Resolved: scheme=(none) simulator=emulator-5554 screens=3 flows=0
Preparing runner...
Runner ready
Booting emulator: emulator-5554
Emulator booted: Pixel_8_API_35 (emulator-5554)
Build finished: success=true duration=1.1s
Installing dev.grantiva.example...
Running 1 flow(s)...
...
  Screens: 3 total, 3 passed, 0 failed
```

## 11. `init` in a bare Gradle directory — PASSED

`cd /tmp && mkdir -p gradle-init && cd gradle-init && touch settings.gradle.kts && $GRANTIVA init && cat grantiva-android.yml && cd - && rm -rf /tmp/gradle-init`

`init` exit status 0, `cat` exit status 0; directory removed afterwards.

```
Created grantiva-android.yml
# Generated by grantiva init — commit this file
platform: android
module: app
variant: debug
# application_id: com.example.myapp   # read from the build when omitted
emulator: Pixel_8_API_35
system_image: "system-images;android-35;google_apis;arm64-v8a"
...
```

## Device state check — PASSED

`adb -s emulator-5554 shell settings get global window_animation_scale`: `1.0` (the pre-run value).
`ls .grantiva/android-settings-*`: no matches (exit 1). `.grantiva` holds `baselines` and
`captures` only.

## `swift test` (full suite) — PASSED

Exit status 0. Four XCTest runs: 94 + 369 + 296 + 101 = 860 tests, 0 failures. Swift Testing
runs: 0 tests. No `warning:` lines in the output.

## iOS end-to-end run — BLOCKED (one attempt)

No iOS project is in this repository. One attempt against
`~/Developer/GrantivaLLC/grantiva-examples` (Landmarks, `simulator: iPhone 17 Pro`):
`$GRANTIVA run`, exit status 1:

```
Resolved: scheme=Landmarks simulator=iPhone 17 Pro screens=8 flows=3
Preparing runner...
Runner ready
Booting simulator: iPhone 17 Pro
Error: Invalid argument: Multiple simulators are named "iPhone 17 Pro"; use a UDID
```

The host has more than one simulator named "iPhone 17 Pro", so the run stopped at simulator
selection, before the build. Not retried (one attempt allowed). The pre-existing Xcode 27
WebDriverAgent build failure noted in Plan 1's hand-off would also apply on this host.
