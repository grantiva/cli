# `run` prints two different flow counts: "Running 13 flow(s)" for 5 screens + 12 flows, then "Running 12 flow(s)"

Severity: ux
Component: cli
Platforms: both by code (observed on Android, N-16; the shared narration also runs on iOS, where IOS-133 passed without judging the count line)
Rows: N-16 (android)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Matrix N-16 (plan N16; round-1 smoke): with a config of 5 screens and 12 flows, the flow count is printed once and is
right ("Running 12 flow(s)"), with the screens counted separately (e.g. "Capturing 5 screens, then running 12 flow(s)").

## Actual
Stock Android config (AND-106/02.err:7 and :102):
```
Running 13 flow(s)...
...
Running 12 flow(s) in one GrantivaAgent session: .maestro/01-browse.yaml, ... .maestro/12-quote-label.yaml
```
The 13 is the screens session counted as one flow plus the 12 flows.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k13
unset GRANTIVA_API_KEY
rm -rf /tmp/k13 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k13 && cd /tmp/k13/android
SERIAL=$(grantiva emulator ensure --name fix-k13)
grantiva build install --device "$SERIAL" --no-launch
grantiva run --device "$SERIAL" --no-build 2>&1 | grep -n 'Running .* flow'      # stock grantiva-android.yml: 5 screens, 12 flows
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-k13
```
iOS (to confirm the shared path): `cd ios`, `UDID=$(grantiva simulator ensure --name "fix-k13 iPhone 17" --runtime 26.0)`,
`grantiva build install --simulator "$UDID"`, `grantiva run --simulator "$UDID" --no-build 2>&1 | grep -n 'Running .* flow'`.

## Evidence
- findings/evidence/cov-android/AND-106/02.err lines 7 and 102
- Row pointer: findings/evidence/cov-android/N-16/commands.txt

## Suspected cause
`Sources/GrantivaCLI/RunCommand.swift:390-391`:
```
let totalFlows = (resolved.screens.isEmpty ? 0 : 1) + resolved.flows.count
log("Running \(totalFlows) flow(s)...")
```
and the second count at `RunCommand.swift:426` (`Running \(resolved.flows.count) flow(s) in one ... session`).
Platform-independent.

## Acceptance criteria
- With 5 screens and 12 flows the narration says the screen count and the flow count once each, e.g.
  `Capturing 5 screen(s), then running 12 flow(s)...`, and no line says 13.
- Flows only: `Running 12 flow(s)...` once. Screens only: `Capturing 5 screen(s)...`, no flow count.
- `--flow <file>`: `Running 1 flow(s)...` once.
- GrantivaCLITests (RunCommandTests): a narration helper returns the expected line for screens+flows, flows only,
  screens only.
