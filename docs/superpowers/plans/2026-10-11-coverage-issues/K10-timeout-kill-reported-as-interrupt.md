# After a `--timeout` kill, grantiva's error ends with the runner's "Received interrupt, cleaning up..."

Severity: ux
Component: cli
Platforms: both (Android AND-OBS-06; the same trailing line is in the iOS evidence of IOS-073 and IOS-135, which the iOS slice did not flag)
Rows: AND-OBS-06 (android); same output in IOS-073/timeout30.err and IOS-135/timeout30.err (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9
Triage note: the map files this under the runner, but the line is printed by grantiva: it is the runner's captured stderr,
appended by the CLI to its own error message. Re-graded component: cli (the runner's wording can stay).

## Expected
When grantiva stops the runner because `--timeout` expired, its `Error:` line explains that and is the last thing
printed (the flow path's message already says so: `grantiva killed the runner after 30s (--timeout <seconds> to raise
the cap). The runner's last output above shows how far it got.`). Nothing after it calls the kill an interrupt, which
reads as a Ctrl-C by the user and contradicts the message.

## Actual
Android (AND-049/01.err, last lines):
```
    ✓ launchApp (1.9s)
Failure screenshot: .grantiva/captures/android/failure-1791702727.png
Error: grantiva killed the runner after 30s (--timeout <seconds> to raise the cap). The runner's last output above shows how far it got.
Received interrupt, cleaning up...
```
iOS, same flow (IOS-073/timeout30.err) ends with the same two lines. The screens path (IOS-135, AND-119) prints
`Error: Runner timed out after 30s:` with the same `Received interrupt, cleaning up...` as the only text after the colon
(that wording half is K20). 1 of 1 runs each.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k10
unset GRANTIVA_API_KEY
rm -rf /tmp/k10 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k10 && cd /tmp/k10/android
SERIAL=$(grantiva emulator ensure --name fix-k10)
grantiva build install --device "$SERIAL" --no-launch
grantiva run --device "$SERIAL" --no-build --flow .maestro/coverage/18-long-wait.yaml --timeout 30 2>&1 | tail -3
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-k10
```
iOS: `cd ios`, `UDID=$(grantiva simulator ensure --name "fix-k10 iPhone 17" --runtime 26.0)`, `grantiva build install --simulator "$UDID"`,
then `grantiva run --simulator "$UDID" --no-build --flow .maestro/coverage/18-long-wait.yaml --timeout 30 2>&1 | tail -3`.
Flow `.maestro/coverage/18-long-wait.yaml`:
```
appId: com.kylebrowning.landmarks
---
- launchApp
- extendedWaitUntil:
    visible: "This never appears"
    timeout: 45000
```

## Evidence
- findings/evidence/cov-android/AND-049/01.err (last 4 lines), AND-049/commands.txt
- findings/evidence/cov-ios/IOS-073/timeout30.err (last 2 lines)
- findings/evidence/cov-ios/IOS-135/timeout30.err; findings/evidence/cov-android/AND-119/slow.err (screens path)
- Row pointer: findings/evidence/cov-android/AND-OBS-06/commands.txt

## Suspected cause
- The timeout kill sends SIGINT first: `RunnerExecution.run` starts `child.terminateGroup()` when the timer fires
  (Sources/GrantivaCore/Runner/RunnerExecution.swift:180-185), and `ChildProcess.terminateGroup` sends SIGINT, then
  SIGTERM, then SIGKILL (Sources/GrantivaCore/Runner/ChildProcess.swift:165-187).
- The runner answers any SIGINT/SIGTERM with `fmt.Fprintf(os.Stderr, "\nReceived %v, cleaning up...\n", sig)` (runner
  pkg/cli/test.go:955; `%v` of SIGINT prints `interrupt`).
- The runner's stderr is not streamed: it is collected (`stderrText`, RunnerExecution.swift:132-137) and returned in
  `Outcome.stderr`. `RunnerSession.failureMessage` (Sources/GrantivaCore/Runner/RunnerSession.swift:17-22) appends its last
  2000 characters after the reason, so the runner's "Received interrupt" line becomes the tail of grantiva's own `Error:`
  message (flow path :495-522, screens path :158-173).

## Acceptance criteria
- After a `--timeout` kill (flow path and screens path, iOS and Android) the output ends with grantiva's timeout
  sentence; no line after it says `interrupt`.
- A genuine Ctrl-C still reports an interrupt (`Runner interrupted`, ready file `interrupted`).
- Runner stderr that matters for a failure (for example a crash message) is still shown; only the runner's own signal
  acknowledgement is dropped when grantiva caused the signal (or the runner is told the reason, e.g. by an environment
  variable, and prints `Stopping: grantiva --timeout reached`).
- GrantivaCoreTests: `failureMessage` (or its replacement) given a timed-out outcome whose stderr is
  `\nReceived interrupt, cleaning up...\n` returns a message that does not contain `interrupt`.
