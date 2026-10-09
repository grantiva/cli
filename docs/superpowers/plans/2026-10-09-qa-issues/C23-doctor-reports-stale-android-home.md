# Report a stale ANDROID_HOME in doctor

Severity: ux
Platforms: cli, android
Found by: CLI-F26 (matrix rows CLI-082)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
When `ANDROID_HOME` points at nothing usable, `doctor` fails the check or at least warns that it was set and skipped.
Source: CHANGELOG 1.8.0 Fixed; docs/android-environment.md ("Grantiva finds the SDK through `ANDROID_HOME`, then
`ANDROID_SDK_ROOT`, then `~/Library/Android/sdk`").

## Actual
```
$ env -u ANDROID_SDK_ROOT ANDROID_HOME=/nonexistent grantiva doctor --platform android
  Required

    ✓ Android SDK       /Users/kyle/Library/Android/sdk
```
No mention that `ANDROID_HOME` was set and ignored. Tools the user runs from the same shell (Gradle, adb) still use the
stale value.

## Repro
```
cp -R fixtures/detect/gradle-only /tmp/c23 && cd /tmp/c23        # branch qa/cli
env -u ANDROID_SDK_ROOT ANDROID_HOME=/nonexistent grantiva doctor --platform android | sed -n '/Required/,/Project/p'
```
Requires an SDK at `~/Library/Android/sdk`.

## Evidence
- findings/evidence/cli/detect/doctor-init.txt (lines 55-59)

## Suspected cause
Sources/GrantivaCore/Android/AndroidSDK.swift:24-38 (`locate`) silently skips candidates without `platform-tools/adb`;
Sources/GrantivaCore/Doctor/DoctorRunner.swift:134-142 (`checkAndroidSDK`) reports only the root found.

## Acceptance criteria
- Re-running the repro shows the SDK check as a warning:
  `/Users/kyle/Library/Android/sdk (ANDROID_HOME=/nonexistent has no platform-tools/adb; unset or fix it)`.
  Same for a stale `ANDROID_SDK_ROOT`.
- GrantivaCoreTests/AndroidSDKTests or DoctorTests: environment `ANDROID_HOME=/nonexistent` plus a valid home SDK yields
  status `.warning` with a message naming `ANDROID_HOME`.
