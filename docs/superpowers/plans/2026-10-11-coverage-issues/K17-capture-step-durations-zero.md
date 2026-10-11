# `diff capture --json` reports every step `duration` as 0, and every step as passed, from a synthetic list

Severity: wrong-result
Component: cli
Platforms: both by code (observed on Android, AND-108; iOS IOS-113/X-022 passed on key sets and did not judge durations)
Rows: AND-108 (android)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Matrix AND-108 (docs/android.md:68-76) asks for a `--json` document whose step fields are meaningful. `steps[].duration`
should carry the time the runner measured for the step (the runner times every command in report.json), as the MCP
live-session capture already does (X-022: real durations).

## Actual
AND-108/02.out, all 8 steps of 5 screens:
```
      "screen_name" : "Home",
      "size_bytes" : 125344,
      "steps" : [
        {
          "action" : "Launch app",
          "duration" : 0,
          "status" : "passed"
        }
      ],
...
          "action" : "Tap on \"Favorites\"",
          "duration" : 0,
          "status" : "passed"
```
The runner's live output for the same capture shows real timings (e.g. `✓ tapOn: text="Favorites" (1.6s)`).

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k17
unset GRANTIVA_API_KEY
rm -rf /tmp/k17 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k17 && cd /tmp/k17/android
SERIAL=$(grantiva emulator ensure --name fix-k17)
grantiva build install --device "$SERIAL" --no-launch
grantiva diff capture --device "$SERIAL" --no-build --json 2>/dev/null \
  | python3 -c "import json,sys;d=json.load(sys.stdin);print([(s['screen_name'],[x['duration'] for x in s['steps']]) for s in d['screens']])"
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-k17
```
iOS: `cd ios`, `UDID=$(grantiva simulator ensure --name "fix-k17 iPhone 17" --runtime 26.0)`, `grantiva build install --simulator "$UDID"`,
`grantiva diff capture --simulator "$UDID" --no-build --json` (same expectation).

## Evidence
- findings/evidence/cov-android/AND-108/02.out (JSON), 01.err (runner timings), commands.txt
- Comparison: X-022 (MCP live-session capture with real durations), findings/evidence/cov-android/MCP-064/ (via X-022/commands.txt)

## Suspected cause
The step list in the capture result is synthesised from the config, not read from the runner's report:
- Success path: `Sources/GrantivaCore/Runner/RunnerSession.swift:213` calls `buildStepResults(for: screen)`
  (:815-822), which returns `StepResult(action: ..., status: .passed, duration: 0)` for every configured step; the
  report.json the runner wrote into `reportDir` is not consulted for steps.
- Failure path: `Sources/GrantivaCore/Runner/RunnerFailureReport.swift:96-119` reads report.json commands but still
  writes `duration: 0` for each (:98, :100, :102, :114, :119).
- Flow captures: `Sources/GrantivaCore/Runner/RunnerArtifactCollector.swift:83-89` likewise (`duration: 0`).
- The MCP path computes real values (`Sources/GrantivaMCP/Tools/SessionCapture.swift:154`).

## Acceptance criteria
- In the repro every `steps[].duration` is the runner's measured duration for that step in seconds (matching
  report.json's `duration` ms / 1000 within rounding); a launch-only screen reports the launch step's duration.
- Step `status` comes from the runner's command status, not a constant `passed`.
- The failure path (`run --json` with a failing flow) carries the same real durations.
- If a step cannot be matched to a runner command, `duration` is omitted or `null` and documented, never a fake 0.
- GrantivaCoreTests (RunnerArtifactCollectorTests or a new RunnerSession test): given a fixture report.json with
  command durations, the captures' step durations equal them.
