# A screens-config `wait: 3` step is narrated live as `evalScript`, and only the summary says `Wait 3s`

Severity: ux
Component: cli
Platforms: ios (seen on iOS; FlowGenerator and the runner narration are shared with Android, not tested there)
Rows: IOS-141 (ios); split from cluster C90 screens-staging-leaks-into-output (the staged-path leak is K90-b)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Screens-config steps are reported in grantiva.yml terms (README:132-149 documents `wait:` as a path step). Matrix
IOS-141: every step executes and is captured; the slice also judged the narration. A `wait: 3` shows as a wait in
both the live step lines and the summary.

## Actual
capture.err (`diff capture --no-build --verbose` with `.maestro/coverage/cfg/screens-steps.grantiva.yml`, exit 0),
live lines (:59-64) and summary block (:134-139) for the Caching screen:
```
    ✓ tapOn: text="Caching Demo" (884ms)
    ✓ waitForAnimationToEnd (757ms)
    ✓ evalScript (3.0s)
    ✓ assertVisible: text="Cache Policy" (465ms)
…
    ✓ tapOn (884ms)
    ✓ waitForAnimationToEnd (757ms)
    ✓ Wait 3s (3.0s)
```
A user who wrote `wait: 3` sees an `evalScript` they never wrote.

## Repro
Config excerpt (`ios/.maestro/coverage/cfg/screens-steps.grantiva.yml`):
```
screens:
  - name: Caching
    path:
      - run_flow: ".maestro/coverage/cfg/relaunch.yaml"
      - tap: "Deep Links"
      - tap: "Caching Demo"
      - wait: 3
      - assert_visible: "Cache Policy"
```
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k90a
unset GRANTIVA_API_KEY
rm -rf /tmp/k90a && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k90a && cd /tmp/k90a/ios   # 4e49dc4
cp .maestro/coverage/cfg/screens-steps.grantiva.yml grantiva.yml && sed -i '' '/^simulator:/d' grantiva.yml
UDID=$(grantiva simulator ensure --name "fix-k90a iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID" --no-launch
grantiva diff capture --no-build --simulator "$UDID" --verbose 2>&1 | grep -nE 'evalScript|Wait 3s'
grantiva simulator teardown --session-id fix-k90a
```

## Evidence
- findings/evidence/cov-ios/IOS-141/commands.txt, capture.err (lines 59-64 live, 134-139 summary), capture.out

## Suspected cause
- CLI: `Sources/GrantivaCore/Runner/FlowGenerator.swift:63-67` emits `wait:` as
  `- evalScript: {script: <sleep>, label: "Wait 3s"}` (`sleepScript` :155, `waitLabel` :161-163). The label reaches
  the report (hence the summary line).
- Runner: the live step line uses `step.Describe()` (`pkg/executor/flow_runner.go:289-296` in grantiva-runner), and
  `BaseStep.Describe()` returns the bare step type (`pkg/flow/step.go:164`), ignoring `label:`; the report builder
  uses `step.Label()` (`pkg/report/builder.go:112`).

## Acceptance criteria
- Re-running the repro: the live line for the wait reads `✓ Wait 3s (3.0s)` (or `wait: 3`), the same as the summary;
  no `evalScript` appears for a `wait:` step.
- Preferred: the runner's live narration uses a step's `label:` when one is set (this fixes every labelled step).
  Alternative: FlowGenerator emits a passing step whose own description reads as a wait.
- If the runner changes: runner test (pkg/executor) that a step with `label: "Wait 3s"` produces that text in the
  `OnStepComplete` description; bundled runner version bumped.
- GrantivaCoreTests/FlowGeneratorTests: the generated YAML for `wait: 3` carries the `Wait 3s` label (existing) and,
  if the construct changes, the new construct.
