# Make `wait: N` wait N seconds

Severity: wrong-result
Platforms: cli, ios, android
Found by: CLI-F29 (matrix rows CLI-046)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
"`- wait: 2` — wait N seconds". Source: README §Screens (README.md:124).

## Actual
`- wait: 1` is emitted as `waitForAnimationToEnd: {timeout: 1000}` and returns as soon as the screen settles:
```
    ✓ inputText: " QA" (401ms)
    ✓ waitForAnimationToEnd (275ms)
```
Triage re-run: `- wait: 3` took 734 ms although the summary line said "Wait 3.0s". Any flow using `wait` to let a network
call or animation finish is not waiting. (CHANGELOG Unreleased "Fixed" already notes runner 1.1.18 returns from
`waitForAnimationToEnd` early, for `runner start`.)

## Repro
1. Boot a simulator; in an empty dir write `grantiva.yml`:
   ```
   bundle_id: com.apple.Preferences
   screens:
     - name: Waited
       path:
         - wait: 3
   ```
2. `grantiva run --no-build --simulator <udid> 2>&1 | grep -E "waitForAnimationToEnd|Wait"`; the step takes well under 3 s.
   (fixtures/config/every-step-landmarks.yml is the landmarks-demo version.)

## Evidence
- findings/evidence/cli/flows/every-step-landmarks.txt

## Suspected cause
Sources/GrantivaCore/Runner/FlowGenerator.swift:46-50 maps `step.wait` to `waitForAnimationToEnd` with a timeout, which
is an upper bound, not a sleep. MaestroFlowParser.swift:334-338 maps `waitForAnimationToEnd` to `wait`, so the round trip
reaches the same thing.

## Acceptance criteria
- Re-running the repro, the step takes at least 3 s.
- Emit a construct that sleeps unconditionally (e.g. `extendedWaitUntil: {notVisible: <impossible>, timeout: N}` or the
  runner's sleep command), and keep a Maestro `waitForAnimationToEnd` mapped to a settle-wait, not to `wait`.
- GrantivaCoreTests/FlowGeneratorTests: assert `wait: 3` generates the sleep construct with 3000 ms, not
  `waitForAnimationToEnd`.
