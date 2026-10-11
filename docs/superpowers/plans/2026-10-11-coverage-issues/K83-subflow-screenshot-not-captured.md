# A `takeScreenshot` inside a `runFlow` sub-flow runs but never becomes a capture point

Severity: wrong-result
Component: cli
Platforms: ios (seen on iOS; screen parsing is shared with Android, not tested there)
Rows: CLI-068 (ios; the CLI slice parse-only half was blocked without a device)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
README:172: "Each `takeScreenshot` becomes a named screen capture point." Matrix CLI-068: both `runFlow: sub.yaml` and
`runFlow: {file: sub.yaml}` include the sub-flow's steps, so a `takeScreenshot` in the sub-flow is a screen like one
in the parent.

## Actual
runflow-string.out (grantiva.yml is the flow-format file below; `diff capture --no-build`, exit 0):
```
  Main
    ✓ Run flow "sub.yaml"

Captured 1 screen in 11.6s
  • Main (320.6 KB)
```
The sub-flow's steps run (runflow-string.err:29-30: `✓ takeScreenshot (94ms)` inside
`✓ runFlow: /tmp/…/CLI-068/sub.yaml (1.9s)`), but `FromSub` is neither listed nor written. `runFlow: {file:}` gives
the same (runflow-file.out).

## Repro
Files in a copy of the iOS app directory:
```
# grantiva.yml
appId: com.kylebrowning.Landmarks
---
- launchApp
- runFlow: sub.yaml
- takeScreenshot: "Main"

# sub.yaml
appId: com.kylebrowning.Landmarks
---
- tapOn: "Landmarks"
- takeScreenshot: "FromSub"
```
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k83
unset GRANTIVA_API_KEY
rm -rf /tmp/k83 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k83 && cd /tmp/k83/ios   # 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k83 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID" --no-launch
printf 'appId: com.kylebrowning.Landmarks\n---\n- launchApp\n- runFlow: sub.yaml\n- takeScreenshot: "Main"\n' > grantiva.yml
printf 'appId: com.kylebrowning.Landmarks\n---\n- tapOn: "Landmarks"\n- takeScreenshot: "FromSub"\n' > sub.yaml
grantiva diff capture --no-build --simulator "$UDID"; ls .grantiva/captures/
grantiva simulator teardown --session-id fix-k83
```
Today: `Captured 1 screen`, only `Main.png`.

## Evidence
- findings/evidence/cov-ios/CLI-068/commands.txt, runflow-string.out/.err, runflow-file.out/.err
- Fixtures: findings/evidence/cov-cli/CLI-068/fixtures/ (grantiva.runFlow-string.yml, grantiva.runFlow-file.yml,
  sub.yaml) and the CLI slice note that the sub-flow is passed on as a runFlow step, not inlined at parse time

## Suspected cause
- `Sources/GrantivaCore/Config/MaestroFlowParser.swift:176-215`: screens are cut at top-level `takeScreenshot`
  commands only; a `runFlow` is kept as one navigation step and the sub-flow is not read, so `FromSub` is never a
  screen.
- `Sources/GrantivaCore/Runner/RunnerSession.swift:199-203`: after the run, captures are looked up only for the parsed
  `screens` by name, so the runner's `cmd-NNN-FromSub.png` (written by `executeTakeScreenshot` for nested steps,
  grantiva-runner `pkg/executor/flow_runner.go:1609-1611` → :709-753) is ignored.

## Acceptance criteria
- Re-running the repro: `Captured 2 screens`, `FromSub.png` and `Main.png` in `.grantiva/captures/`, in that order;
  same with `runFlow: {file: sub.yaml}`.
- A cycle or missing sub-flow still fails with the existing errors; a sub-flow with no takeScreenshot adds no screen.
- Duplicate names across parent and sub-flow are reported as an error (or disambiguated) rather than overwriting.
- GrantivaCoreTests/MaestroStandardFormsTests (or a new MaestroFlowParser test): parsing the two files above yields
  screens `["FromSub", "Main"]`.
