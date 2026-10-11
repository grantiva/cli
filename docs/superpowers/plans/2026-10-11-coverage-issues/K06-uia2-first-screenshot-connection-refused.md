# On a freshly booted emulator the UIAutomator2 connection drops mid-capture and the run fails with a raw socket error

Severity: wrong-result
Component: runner
Platforms: android (Android-only: UIAutomator2 path)
Rows: N-06 (android); also the first stock run on cov-android (AND-106/01, recorded under N-06)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Matrix N-06 (plan N06): the first `diff capture` on a freshly booted AVD gets a working UIAutomator2 session each time;
if the connection drops, the runner reconnects or retries the call, or fails with a message that names UIAutomator2
(for example "the UIAutomator2 server stopped responding"), not a raw socket error.

## Actual
3 of 3 fresh boots failed their first `diff capture` (plus AND-106/01); the second capture on the same boot passed
(N-06/03.out: `Captured 5 screens in 13.9s`). The session starts and early steps pass, then a screenshot call fails.
Boot 1 (N-06/n06-1.err:17-31):
```
  ✓ UIAutomator2 server started
  ⏳ Creating session...
  ✓ Session created
    ✓ launchApp (2.2s)
    ✓ waitForAnimationToEnd (737ms)
    ✓ takeScreenshot (179ms)
    ✓ tapOn: text="Favorites" (1.6s)
    ✗ waitForAnimationToEnd (298ms)
      ╰─ Failed to take screenshot: send request: Get "http://localhost/session/d1b3f447-.../screenshot": dial unix /tmp/uia2-emulator-5556.sock: connect: connection refused (cause: <same text>)
```
Boot 2 failed after 13 steps with `Failed to take screenshot: read response: unexpected EOF` (n06-2.err:36-37); boot 3
after `launchApp` (n06-3.err:24-27). Exit 1 each time, ending `Error: Runner failed (exit 1); see the runner output above.`
In AND-106/01 the same refusal (:37, :47) was followed by `adb: device 'emulator-5554' not found` when Grantiva restored
settings (:92-93), so the device itself dropped off adb briefly.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k06
unset GRANTIVA_API_KEY
rm -rf /tmp/k06 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k06 && cd /tmp/k06/android
grantiva build build                                   # produces app/build/outputs/apk/free/debug/app-free-debug.apk
for i in 1 2 3; do
  grantiva emulator delete --name fix-k06 >/dev/null 2>&1
  SERIAL=$(grantiva emulator ensure --name fix-k06)    # brand-new AVD, cold first boot
  grantiva build install --device "$SERIAL" --no-build --app-file app/build/outputs/apk/free/debug/app-free-debug.apk --no-launch
  grantiva diff capture --device "$SERIAL" --no-build > /tmp/k06/cap-$i.out 2> /tmp/k06/cap-$i.err; echo "boot $i first capture exit $?"
  grep -E 'Failed to take|refused|EOF' /tmp/k06/cap-$i.err | head -2
  grantiva emulator teardown --serial "$SERIAL"; sleep 3
done
grantiva emulator delete --name fix-k06
```
Note: `build install --no-build --app-file` currently skips the install (K25); if that is still open, install with
`adb -s "$SERIAL" install -r app/build/outputs/apk/free/debug/app-free-debug.apk` instead.

## Evidence
- findings/evidence/cov-android/N-06/n06-1.err, n06-2.err, n06-3.err (first captures, boots 1-3); N-06/03.out (second capture passes); N-06/commands.txt
- findings/evidence/cov-android/AND-106/01.err lines 37, 47, 92-93

## Suspected cause
Runner (release-round1, ae48e34). Not confirmed on device.
- No recovery in the HTTP client: `pkg/uiautomator2/client.go:87-113` (`request`) returns `send request: %w` on any
  transport error, with no reconnect, re-forward or retry.
- The step wraps it raw: `pkg/driver/uiautomator2/commands.go:2134` (`takeScreenshot`) and `:2376-2380`
  (`waitForScreenStatic`, used by `waitForAnimationToEnd`) return `Failed to take screenshot: %v`.
- Why it drops: the session talks to the device through an adb forward to `/tmp/uia2-<serial>.sock`
  (pkg/cli/android.go:367). Hypothesis: on a first boot adbd (or the UIAutomator2 instrumentation) restarts shortly
  after Grantiva's boot wait completes (Sources/GrantivaCore/Android/EmulatorManager.swift:~271-292 waits for
  `sys.boot_completed` and `pm path android`), which drops the forward; AND-106/01 shows the device leaving `adb devices`
  briefly. A second capture works because the system has settled.

## Acceptance criteria
- The repro's first capture passes on 3 of 3 fresh boots (or, if the server genuinely dies, the runner restarts it,
  re-creates the forward and session, and retries the failed call once before failing the step).
- When recovery fails, the step message names the driver, e.g. `UIAutomator2 server on emulator-5556 stopped
  responding (connection refused); retried once`, not only the raw `dial unix` text, and the cause is not repeated.
- Grantiva's settings restore tolerates a device that briefly leaves adb (retry once) rather than printing two warnings.
- Runner test (pkg/uiautomator2 or pkg/driver/uiautomator2): a fake transport that refuses the first connection and
  then succeeds makes `Screenshot()` succeed; one that keeps refusing yields an error mentioning UIAutomator2.
