# On a busy host the runner gives up starting UIAutomator2 after a fixed 30 s that Grantiva never raises, and `runner start` then waits another minute on the dead runner before reporting a timeout without the reason

Severity: ux
Component: runner (limit) and cli (message, wait)
Platforms: android. **Load-only**: 2 sightings, at 1-min load 80.5 (AND-106/01, first stock run) and during AND-126/01 (load 11.9 recorded at the command's start; the slice notes 76 during the start). Not seen at the fix round's load of 5-13.
Rows: AND2-OBS-07 [android] (evidence in AND-126/01 and AND-106/01; both rows passed on retry)
Regresses/extends: new. Next to L05 (docs/superpowers/plans/2026-10-12-coverage-issues-round2/L05-android-first-find-after-launch-blocks.md), the other slow-AVD start-up path; the cluster map suggests folding it into L05's next fix.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
Starting a UIAutomator2 session on a slow or busy host either succeeds, retries, or fails with a limit the user can
raise, and the failure says why (the runner's reason) promptly.

## Actual
- `runner start --detach --json --device emulator-5554 --headless` (findings/evidence/cov2-android/AND-126/01.out, 01.err)
  took 91.8 s and failed:
```
exit=1

{
  "status" : "not_running"
}
Error: Timed out waiting for the UIAutomator2 session to start. Log: /var/folders/jv/76l6crmx6nl3hf150gzry_ym0000gn/T/grantiva-runner-1791745017.log
```
  The runner had already given up (AND-126/runner-1791745017.log):
```
  ⏳ Connecting to device emulator-5554...
  ✓ Connected to google sdk_gphone64_arm64 (SDK 35)
  ⏳ Starting UIAutomator2 server...
Error: failed to create driver: start UIAutomator2: UIAutomator2 server not ready after 30s
```
- The first stock `grantiva run` (AND-106/01.err, load 80.5) failed the same way: `Error: failed to create driver: start
  UIAutomator2: UIAutomator2 server not ready after 30s`. The third attempt passed.
- There is no Grantiva flag or environment variable for this limit.

## Repro
Load-dependent; the unit tests in the criteria are the reliable repro. On a device, saturate the host first:
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l48
unset GRANTIVA_API_KEY
rm -rf /tmp/l48 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l48 && cd /tmp/l48/android
sed -i '' 's/^emulator: .*/emulator: fix-l48/' grantiva-android.yml
SERIAL=$(grantiva emulator ensure --name fix-l48 --headless)
grantiva build install --device "$SERIAL" --no-launch
N=$(( $(sysctl -n hw.ncpu) * 6 )); for i in $(seq 1 $N); do yes > /dev/null & done; sleep 60; uptime
for i in 1 2 3; do
  adb -s "$SERIAL" shell am force-stop io.appium.uiautomator2.server
  /usr/bin/time -p grantiva runner start --detach --json --device "$SERIAL" 2>&1 | tail -4
  grantiva runner stop > /dev/null
done
pkill -x yes
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-l48
```
Without load the start takes 4.7-7.9 s on this AVD; the defect needs the 30 s limit to be hit.

## Evidence
- findings/evidence/cov2-android/AND-126/01.out, 01.err, runner-1791745017.log, commands.txt
- findings/evidence/cov2-android/AND-106/01.err, 01.out, commands.txt (load 80.53)
- findings/cov2-android-results.md rows AND2-OBS-07, AND-126, AND-106

## Suspected cause
- Runner: `pkg/device/uiautomator.go:47-53` sets `Timeout: 30 * time.Second` by default; `StartUIAutomator2` waits with
  `waitForUIAutomator2Ready(cfg.Timeout)` (`:95-100`, loop at `:270-281`) and stops the server on timeout. There is no
  retry. The runner already has an override: the global `--driver-start-timeout` flag (`pkg/cli/cli.go:129-134`,
  applied in `pkg/cli/android.go:169-173`).
- CLI: `AndroidPlatform.runnerGlobalArguments` (`Sources/GrantivaCore/Android/AndroidPlatform.swift:242-246`) never
  passes `--driver-start-timeout`, and no Grantiva option feeds it.
- CLI: `runner start` waits for the session with `waitForUIAutomator2Port` (`Sources/GrantivaCLI/DriverCommand.swift:302-309`,
  90 s via `waitForUIAutomator2` `:276-287`), which never checks whether the spawned runner has exited, so it keeps
  polling for ~60 s after the runner died. The messages at `:363` (detached) and `:455` (foreground) say only "Timed
  out waiting for the UIAutomator2 session to start" and do not carry the runner's error.

## Acceptance criteria
- Grantiva passes a UIAutomator2 start limit to the runner (`--driver-start-timeout`) that follows `--timeout` where the
  command has one, or a documented `GRANTIVA_DRIVER_START_TIMEOUT` / flag; the default stays 30 s unless the owner rules
  otherwise. Optionally the runner retries the start once before giving up.
- When the runner exits during start-up, `runner start` (both paths) and `run` report within ~1 s, with the runner's last
  error line, e.g. `The runner could not start UIAutomator2 on emulator-5554: UIAutomator2 server not ready after 30s.
  Raise the limit with …. Log: <path>`.
- Under the repro's load, a start that needs 40 s succeeds once the limit is raised.
- Tests: GrantivaCLITests/RunnerLifecycleCommandTests.swift: `waitForUIAutomator2` with a fake attach that never
  succeeds and a fake child that exits at 1 s returns (as a failure carrying the child's last stderr line) within 2 s, not
  at 90 s; GrantivaCoreTests/AndroidPlatformTests.swift: the runner arguments include `--driver-start-timeout <n>` when a
  limit is set. If the runner retries: a test in `pkg/device` (next to `uiautomator_test.go`) that a first readiness
  timeout followed by a healthy server yields success.
