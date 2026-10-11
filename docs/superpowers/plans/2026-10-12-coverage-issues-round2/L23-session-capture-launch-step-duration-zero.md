# A capture through a live runner session reports the launch-only screen's `Launch app` step with `duration: 0`

Severity: contract
Component: mcp (`SessionCapture`, used by `diff capture --no-build` on a device held by a `runner start` session and by MCP `grantiva_vrt_capture`)
Platforms: both (iOS and Android identical)
Rows: N2-08 [ios] (also seen in MCP-063 [ios]); X-022, B2-K17, N2-08 [android] (also MCP-064 [android])
Regresses/extends: K17 (capture step durations zero), fixed by CLI #193 for the runner-driven capture. Incomplete: the session-capture path added for K86-b (CLI #190) still hardcodes 0.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
README `run --json` paragraph (README:470-476 at c65fc17): each step's `duration` is in seconds, "`null` when the runner
measured none", and "the same `duration` rule holds for `diff capture --json` steps". A step is never reported as
`0`. A `grantiva_vrt_capture` result uses the same document as `diff capture --json` (K55).

## Actual
iOS: `runner start --detach` on cov2-ios-1, then `diff capture --no-build --json`. The session path captures 5/5, but
(findings/evidence/cov2-ios/N2-08/session-capture-json.out:9-16):
```
      "screenName" : "Home",
      "steps" : [
        {
          "action" : "Launch app",
          "duration" : 0,
          "status" : "passed"
        }
```
Android: the same through a `runner start` session (findings/evidence/cov2-android/B2-K17/session-capture.json:33-38) and
through MCP `grantiva_vrt_capture` (findings/evidence/cov2-android/MCP-064/). The CLI capture without a session measures
the same step (findings/evidence/cov2-android/AND-108/capture.json:35-37):
```
          "action" : "Launch app",
          "duration" : 8.284,
```
Every session capture in both slices shows it (iOS N2-08 and MCP-063; Android B2-K17, X-022, N2-08 and MCP-064). The
other screens' steps carry positive measured durations.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l23
unset GRANTIVA_API_KEY
rm -rf /tmp/l23 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l23 && cd /tmp/l23/ios
UDID=$(grantiva simulator ensure --name fix-l23 --device-type "iPhone 17" --runtime 26.0 | tail -1)
grantiva build install --simulator "$UDID"
grantiva runner start --detach --simulator "$UDID" --bundle-id com.kylebrowning.Landmarks
grantiva diff capture --no-build --simulator "$UDID" --json | jq '.screens[] | select(.screenName=="Home") | .steps'
# bug: [{"action":"Launch app","duration":0,"status":"passed"}]
grantiva runner stop
grantiva diff capture --no-build --simulator "$UDID" --json | jq '.screens[] | select(.screenName=="Home") | .steps[0].duration'
# without a session: a positive number
grantiva simulator teardown --session-id fix-l23
```
Android: same in `/tmp/l23/android` with `SERIAL=$(grantiva emulator ensure --name fix-l23)`, `--device "$SERIAL"`,
`grantiva runner start --detach --device "$SERIAL"`.

## Evidence
- findings/evidence/cov2-ios/N2-08/session-capture-json.out, start.out, stop.out, commands.txt
- findings/evidence/cov2-ios/MCP-063/ (MCP vrt_capture through the session)
- findings/evidence/cov2-android/B2-K17/session-capture.json, 01.out, commands.txt; findings/evidence/cov2-android/X-022/commands.txt
- findings/evidence/cov2-android/MCP-064/mcp-01/; findings/evidence/cov2-android/AND-108/capture.json (the measured 8.284 s)
- docs/superpowers/plans/2026-10-11-coverage-issues/K17-capture-step-durations-zero.md

## Suspected cause
`Sources/GrantivaMCP/Tools/SessionCapture.swift:157-159`: a screen with `path: launch` (no steps) gets
`StepResult(action: "Launch app", status: .passed, duration: 0)`. The app is launched once before the loop
(`device.terminate` / `device.launch` / `settle` at `:138-140`) and never timed. Steps of step-path screens are timed
(`:149-155`). `StepResult.duration` is optional (`Sources/GrantivaCore/Diff/DiffResult.swift:13-15`), so `nil` is
available.

Fix: time the initial terminate+launch+settle and give that duration to the first launch-only screen (others after it get
`null`, since the app was not relaunched for them), or use `nil` throughout. Check that the encoder writes `null`, not an
omitted key, per README (the `DiffResult.swift:13-14` comment says "omitted from JSON", which disagrees with README and
K17's "never omitted").

## Acceptance criteria
- Through a live session (both platforms, CLI and MCP), the Home `Launch app` step's `duration` is a positive number or
  `null`, never `0`.
- No step in any `diff capture --json` or `grantiva_vrt_capture` result has `"duration": 0`.
- The key is present (`null`), not omitted, when unmeasured, as README says.
- Tests: GrantivaMCPTests (a SessionCapture test with a fake driver/device whose launch takes 50 ms): the launch-only
  screen's step has `duration == nil` or `>= 0.05`, never `0`. The encoded JSON contains `"duration":null` or a positive
  number for it.
