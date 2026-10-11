# `emulator ensure` does not notice a failed system-image install, then fails in avdmanager with a doubled "Error: Error:" and a stray `null`

Severity: wrong-result
Component: cli
Platforms: android (Android-only)
Rows: AND-002 (android)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
docs/android.md:173-175: `ensure` installs the system image with `sdkmanager` when it is missing, then creates the AVD.
If the install fails (unknown package, no network, licence refused), `ensure` stops there with one clear error naming
the package and sdkmanager's reason, and does not attempt `avdmanager create`. (The real-install half of AND-002 was
blocked: the only uninstalled images were 1 GB+ downloads; this brief covers the error path the slice could exercise.)

## Actual
`ensure --name cov-android-2 --system-image "system-images;android-99;bogus;arm64-v8a" --no-boot` (AND-002/02.out, 02.err):
```
Installing system-images;android-99;bogus;arm64-v8a with sdkmanager
Creating AVD cov-android-2
Error: Error: Package path is not valid. Valid system image paths are:
system-images;android-35;google_apis;arm64-v8a
null
```
Exit 1; `avdmanager list avd | grep -c cov-android-2` is 0. The sdkmanager failure is not reported; the error comes
from avdmanager, with its own `Error:` prefix doubled by grantiva's and avdmanager's trailing `null`.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_SESSION_ID=fix-k31; unset GRANTIVA_API_KEY
cd /tmp
grantiva emulator ensure --name fix-k31 --system-image "system-images;android-99;bogus;arm64-v8a" --no-boot; echo "exit $?"
yes 2>/dev/null | sdkmanager --sdk_root="$ANDROID_HOME" "system-images;android-99;bogus;arm64-v8a"; echo "sdkmanager exit $?"   # what grantiva runs
avdmanager list avd | grep -c fix-k31
```

## Evidence
- findings/evidence/cov-android/AND-002/02.out, 02.err, 01.out (installed images), commands.txt

## Suspected cause
- `Sources/GrantivaCore/Android/EmulatorManager.swift:359-363`: when the image directory is missing it runs
  `yes 2>/dev/null | <sdkmanager> --sdk_root=... '<image>'` through `execute` and ignores the result. The pipeline's
  status is sdkmanager's; for an unknown package sdkmanager appears to print a warning and exit 0 (not confirmed; the
  repro's second command shows it), so nothing throws. There is no check that
  `systemImagePath(root:image:)` (:342-344) exists afterwards.
- :364-365 then runs `avdmanager create avd`, which fails; `GrantivaCore.shell` throws `commandFailed` with avdmanager's
  stderr verbatim (Sources/GrantivaCore/Shell.swift:38-44), which already starts with `Error:` and ends with `null`; the
  CLI's top-level handler adds its own `Error: ` prefix.

## Acceptance criteria
- The repro fails right after the sdkmanager step with one line such as
  `Error: sdkmanager could not install system-images;android-99;bogus;arm64-v8a: <sdkmanager's message>. Installed
  images: system-images;android-35;google_apis;arm64-v8a.`, exit 1, and no `Creating AVD` line.
- After a successful install the image directory exists and creation proceeds as today.
- No message printed by grantiva starts with `Error: Error:`, and avdmanager's trailing `null` is not shown.
- GrantivaCoreTests (EmulatorManagerTests): with a fake `execute` where sdkmanager returns 0 but the image dir stays
  missing, `ensure` throws the install error and never calls avdmanager; an avdmanager failure message is normalised
  (leading `Error:` stripped, `null` lines dropped).
