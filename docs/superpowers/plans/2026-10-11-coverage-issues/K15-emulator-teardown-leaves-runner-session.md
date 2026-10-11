# `emulator teardown --serial` kills the emulator but leaves its detached runner running and `.grantiva/session.json` naming the dead serial

Severity: wrong-result
Component: cli
Platforms: android (Android-only)
Rows: AND-010 (android)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Matrix AND-010 (help emulator_teardown.txt: stops UIAutomator2, removes that serial's forwards, kills it): after
`emulator teardown --serial <serial>` of a device that has a `runner start --detach` session, nothing live refers to
that device: the runner process for it is stopped and `.grantiva/session.json` no longer names it (or teardown refuses
and says to run `grantiva runner stop` first).

## Actual
`runner start --detach --device emulator-5556` (pid 27331), then `emulator teardown --serial emulator-5556 --verbose`
(AND-010/04): it force-stops `io.appium.uiautomator2.server(.test)`, removes `tcp:53095` and prints
`Killed emulator-5556 (cov-android-2).` Afterwards (AND-010/05.out):
```
List of devices attached
emulator-5554	device

  PID COMMAND
27331 /Users/kyle/.grantiva-qa/runner/versions/1.1.28-grantiva.9+android-drivers-2/grantiva-runner --platform android --device emulator-5556 --no-ansi
{"startedAt":813393865.962027,"bundleId":"com.kylebrowning.landmarks","wdaPort":53095,"udid":"emulator-5556","platform":"android","pid":27331}
```
The runner and the session file survive until a manual `grantiva runner stop` (AND-010/06.out: `Runner stopped (pid 27331)`).

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k15
unset GRANTIVA_API_KEY
rm -rf /tmp/k15 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k15 && cd /tmp/k15/android
SERIAL=$(grantiva emulator ensure --name fix-k15)
grantiva build install --device "$SERIAL" --no-launch
grantiva runner start --detach --device "$SERIAL"
PID=$(python3 -c "import json;print(json.load(open('.grantiva/session.json'))['pid'])")
grantiva emulator teardown --serial "$SERIAL"
ps -p "$PID" -o pid,command; cat .grantiva/session.json      # today: runner alive, session names the dead serial
grantiva runner stop; grantiva emulator delete --name fix-k15
```

## Evidence
- findings/evidence/cov-android/AND-010/02.out (runner start), 04.err (teardown, verbose), 05.out (after), 06.out (manual stop), commands.txt

## Suspected cause
- `Sources/GrantivaCLI/EmulatorCommand.swift:162-177` (`Teardown.run`) calls `EmulatorManager.teardown` and prints the
  outcomes; nothing consults `RunnerSessionInfo` (`.grantiva/session.json`, Sources/GrantivaCore/Runner/RunnerSessionInfo.swift:14)
  or the keep-alive owner records.
- `Sources/GrantivaCore/Android/EmulatorManager.swift:454-497` (`teardown(serial:force:)`) stops the UIAutomator2
  packages and forwards (:471-474) and kills the emulator, but has no knowledge of the runner process on the host.
- `runner stop` already contains the right cleanup (terminate group, cleanupOrphans, remove session, release lease:
  Sources/GrantivaCLI/DriverCommand.swift:635-650); teardown could reuse it for a session whose `udid` is the serial.

## Acceptance criteria
- In the repro, after `emulator teardown --serial "$SERIAL"`: the runner pid is gone, `.grantiva/session.json` is
  removed (or no longer names the serial), and the lease for the serial is released; teardown prints that it stopped
  the runner session (e.g. `Stopped runner session (pid 27331) for emulator-5556.`).
  Alternative accepted: teardown refuses with `emulator-5556 has a runner session (pid N); run grantiva runner stop first`,
  exit 1, and kills nothing.
- A session for a different serial is left alone. `teardown --all` applies the same rule to every serial it kills.
- `--json` outcome gains a field saying whether a runner session was stopped.
- GrantivaCLITests (EmulatorCommandTests): with a stubbed session.json naming the torn-down serial, teardown invokes the
  runner-stop cleanup; with one naming another serial, it does not.
