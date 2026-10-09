# Test the app that was installed: take the application ID from the APK/build output, or fail when `application_id` disagrees

Severity: wrong-result
Platforms: android
Found by: AND-F05 (matrix rows AND-028, AND-026; brief Step 3 paidDebug)
Binary: grantiva 2.0.1 (commit c8dc86d), runner 1.1.18-grantiva.7+android-drivers-2, emulator-5554 (Pixel_8_API_35, API 35)

## Expected
The run tests the app it built or installed. Source: CHANGELOG Unreleased (with `--app-file` "the application ID is read
with `apkanalyzer`"); docs/android.md (variant selection).

## Actual
With `application_id: com.kylebrowning.landmarks` in grantiva-android.yml, `--app-file app-paid-debug.apk` installs the
paid package but narrates, rewrites the flow to, and tests the free one:
```
Resolved: scheme=(none) simulator=emulator-5554 screens=0 flows=1
Installing com.kylebrowning.landmarks...
  01-browse                      ✓ PASS       8      8      0      0       3.5s
```
report.json `"app": {"id": "com.kylebrowning.landmarks"}`; `pm list packages` then lists both `com.kylebrowning.landmarks`
and `com.kylebrowning.landmarks.paid`. `--variant paidDebug` does the same. With `application_id` removed from the config
both commands correctly use `.paid`. Nothing warns that the IDs differ.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_SESSION_ID=qa-android
cd /Users/kyle/Developer/landmarks-demo/android
grantiva run --app-file app/build/outputs/apk/paid/debug/app-paid-debug.apk --flow .maestro/01-browse.yaml \
  --device emulator-5554 --report-dir /tmp/a03 2>&1 | grep Installing
jq -r .app.id /tmp/a03/report.json                  # com.kylebrowning.landmarks
adb -s emulator-5554 shell pm list packages | grep landmarks
adb -s emulator-5554 uninstall com.kylebrowning.landmarks.paid   # clean up
```

## Evidence
- findings/evidence/AND-S3-paid/{stderr.txt,report/report.json}
- findings/evidence/AND-028/log.txt (`--variant paidDebug`), AND-026/log.txt (config without `application_id`)

## Suspected cause
Sources/GrantivaCLI/TargetOptions.swift:91 (`applicationIdFlag ?? configured.applicationId ?? appID`) ranks the config
above the APK's ID (`appID`, read by Sources/GrantivaCore/Android/AndroidPlatform.swift:136 and passed from
Sources/GrantivaCLI/RunCommand.swift:132-139); Sources/GrantivaCLI/RunCommand.swift:248 (`resolved.bundleId ?? builtAppID`)
does the same against the Gradle output metadata. The ID then feeds install narration (:254), flow `appId` injection and
report.json.

## Acceptance criteria
- Re-running the repro: either the run uses `com.kylebrowning.landmarks.paid` (narration, flow appId, report `app.id`),
  or it fails before installing with an error naming both IDs and the flag/config key to change. `--application-id`
  given explicitly may still override, but with a warning when it disagrees with the APK.
- The same rule applies to `--variant` builds (output-metadata applicationId vs config) and to `build install`.
- GrantivaCLITests/TargetOptionsTests: `resolveAndroid` with config `application_id` A and APK ID B yields B (or throws
  a mismatch error); a RunCommandTests case covers the built-variant path.
