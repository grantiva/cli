# The runner labels an Android emulator "Simulator" in every per-flow header and summary

Severity: contract
Component: runner
Platforms: android (Android-only: on iOS "Simulator" is correct)
Rows: AND-OBS-12 (android)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
An Android emulator is called an emulator. Grantiva's own narration does this (`Emulator booted: cov-android
(emulator-5554)`, `Emulator: cov-android (emulator-5554)` in `diff capture`), and docs/android.md uses "emulator"
throughout. The report.json key `isSimulator` is documented in the runner as "Simulator/emulator vs real device"
(pkg/core/driver.go:205), so the key itself may stay; only the human-readable label is wrong.

## Actual
Every Android run (CF-09-waits/out-cf-09-waits.stderr:39):
```
  [1/1] 09-waits (.maestro/coverage/09-waits.yaml) - Device: google sdk_gphone64_arm64 (android 35 Simulator)
```
report.json for an Android run (X-003/report.json:8-14, again at :43):
```
  "device": {
    "id": "emulator-5554",
    "name": "google sdk_gphone64_arm64",
    "platform": "android",
    "osVersion": "35",
    "isSimulator": true
  },
```

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k04
unset GRANTIVA_API_KEY
rm -rf /tmp/k04 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k04 && cd /tmp/k04/android
SERIAL=$(grantiva emulator ensure --name fix-k04)
grantiva build install --device "$SERIAL" --no-launch
grantiva run --device "$SERIAL" --no-build --flow .maestro/01-browse.yaml --report-dir /tmp/k04/out 2>&1 | grep -E 'Device:|Platform:'
grep -n -A6 '"device"' /tmp/k04/out/report.json | head -8
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-k04
```

## Evidence
- findings/evidence/cov-android/CF-09-waits/out-cf-09-waits.stderr line 39
- findings/evidence/cov-android/X-003/report.json lines 8-14 and 43
- Row pointer: findings/evidence/cov-android/AND-OBS-12/commands.txt

## Suspected cause
Runner (release-round1, ae48e34):
- `pkg/cli/android.go:288` and `:522` set `IsSimulator: info.IsEmulator` for the Android device info.
- `pkg/cli/test_unified_output.go:87-88` (`formatDeviceLabel`) appends `" Simulator"` whenever `IsSimulator` is true,
  and `:360-361` appends `" (Simulator)"` to the `Platform:` line, with no platform check.

## Acceptance criteria
- On Android the per-flow header reads `Device: google sdk_gphone64_arm64 (android 35 Emulator)` and any
  `Platform:` line says `Emulator`; a physical Android device gets neither word.
- iOS output is unchanged (`(ios 26.0 Simulator)`).
- report.json keeps `isSimulator` (documented as simulator/emulator); if a platform-neutral key is added, `isSimulator`
  stays for compatibility.
- Runner test (pkg/cli): `formatDeviceLabel` with `Platform: "android", IsSimulator: true` contains `Emulator` and not
  `Simulator`; with `Platform: "ios"` it still contains `Simulator`.
