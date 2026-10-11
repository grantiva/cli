# `emulator teardown --serial` kills the emulator so abruptly that an app installed seconds earlier is gone after the next boot

Severity: wrong-result
Component: cli
Platforms: android. **Confirmed on a quiet host** (fix round 1, load 6.1: 1 of 1, install 5 s before teardown); original 1 of 1 (AND-113/03, load 3.6).
Rows: AND2-OBS-06 [android], AND2-OBS-06 rerun [android] (knock-on failures in AND-029/01 and AND-115/01, whose rows passed on retry)
Regresses/extends: new.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
`grantiva emulator teardown --serial <s>` shuts the emulator down without losing the data partition: an app installed
before the teardown is still installed after the next `emulator ensure` boots the same AVD (boots use
`-no-snapshot-save`, so the data partition is the only state that should carry over, and it should carry over).

## Actual
Fix round 1, findings/evidence/cov2-android/FIX1-teardown/01.cmd and 01.out (uninstall, `build install --no-build
--app-file <apk> --no-launch`, `pm list`, `sleep 5`, `emulator teardown --serial emulator-5554`, `sleep 3`, `emulator
ensure --name cov2-android`, `pm list`):
```
Success
[grantiva] Done — com.kylebrowning.landmarks installed on cov2-android (not launched)
package:com.kylebrowning.landmarks
Killed emulator-5554 (cov2-android).
emulator-5554
pm-exit=0
```
The second `pm list` prints nothing. Original (findings/evidence/cov2-android/AND-113/03.out): the app installed by the
preceding `build install` was lost while an older install of the paid flavour survived:
```
package:com.kylebrowning.landmarks
package:com.kylebrowning.landmarks.paid
List of devices attached

emulator-5554
package:com.kylebrowning.landmarks.paid
```
AND-029/01 and AND-115/01 then failed with `Error: com.kylebrowning.landmarks is not installed on cov2-android. Drop
--no-build or run grantiva build install.`

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l46
unset GRANTIVA_API_KEY
rm -rf /tmp/l46 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l46 && cd /tmp/l46/android
sed -i '' 's/^emulator: .*/emulator: fix-l46/' grantiva-android.yml
SERIAL=$(grantiva emulator ensure --name fix-l46)
grantiva build build --variant freeDebug --json > /tmp/l46/build.json
APK=$(python3 -I -c 'import json;print(json.load(open("/tmp/l46/build.json"))["productPath"])')
for wait in 5 30; do
  adb -s "$SERIAL" uninstall com.kylebrowning.landmarks > /dev/null 2>&1
  grantiva build install --device "$SERIAL" --no-build --app-file "$APK" --no-launch
  adb -s "$SERIAL" shell pm list packages com.kylebrowning.landmarks
  sleep $wait
  grantiva emulator teardown --serial "$SERIAL"; sleep 3
  SERIAL=$(grantiva emulator ensure --name fix-l46)
  echo "after ${wait}s:"; adb -s "$SERIAL" shell pm list packages com.kylebrowning.landmarks
done
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-l46
```
Prediction (not run): lost after a 5 s wait, kept after 30 s, if the cause below holds.

## Evidence
- findings/evidence/cov2-android/FIX1-teardown/01.cmd, 01.out, 02.out, commands.txt
- findings/evidence/cov2-android/AND-113/03.out, commands.txt; AND-029/01.*, AND-115/01.*

## Suspected cause
Not confirmed.
- `Sources/GrantivaCore/Android/EmulatorManager.swift:590-632` (`teardown`): force-stops the UIAutomator2 packages,
  removes forwards, then `adb emu kill` (`ADB.swift:236-238`) and waits up to `killTimeout` (30 s, `:132`) for the serial
  and process to go. It never escalates to a signal (on timeout it throws), so a hard kill by Grantiva is not the cause.
- `emu kill` stops the virtual device without a guest shutdown, so whatever the guest has not written to its data
  partition is lost. Android's package manager persists its package list (`/data/system/packages.xml`) on a deferred
  write a few seconds after an install, so an app installed shortly before an `emu kill` may never reach disk; the
  paid-flavour app installed long before survived (AND-113/03). This is the likely mechanism; it was not traced.
- Boots use `-no-snapshot-save` (`bootArguments`, `:228-232`), so no snapshot rescues the state either.

## Acceptance criteria
- With the repro's 5 s wait, the app is still installed after the next boot, 3 of 3.
- `emulator teardown` (and `--all`, and teardown through `simulator`-style reclaim paths that stop an emulator) shuts the
  guest down gracefully first, e.g. `adb -s <s> shell reboot -p` (or `setprop sys.powerctl shutdown`) and waits for the
  serial to drop, falling back to `emu kill` after a bounded wait; or, at minimum, flushes before the kill (`adb shell
  sync`, after confirming that the package list has been written). The JSON/text outcome keeps `killed: true` semantics
  documented.
- Teardown time on the default AVD stays within the current 30 s bound.
- Tests in GrantivaCoreTests/EmulatorManagerTests.swift (next to
  `testTeardownKillsARecordedEmulatorAndRemovesTheRecord`, `:772`): with a scripted ADB, teardown issues the graceful
  shutdown (or flush) before `emu kill`, and falls back to `emu kill` when the serial is still listed after the bound.
