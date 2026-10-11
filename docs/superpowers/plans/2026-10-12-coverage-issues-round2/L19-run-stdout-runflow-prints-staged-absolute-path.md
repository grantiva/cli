# `run`'s stdout step list prints `runFlow: <absolute /tmp path>` for a sub-flow written as a relative path

Severity: ux
Component: cli
Platforms: both (iOS and Android identical)
Rows: B2-K105 [ios], B2-K105 [android]
Regresses/extends: K105 (runFlow step prints rewritten path), fixed by CLI #193 for live lines and report.json. Incomplete: the stdout result block.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
K105 Expected: the live line, the nested header, report.json and the summary all name the sub-flow as written in the flow
(`runFlow: 14-runflow-sub.yaml`), for both forms (`runFlow: <file>` and `runFlow: {file: <file>}`).

## Actual
`.maestro/coverage/14-runflow.yaml` (`- runFlow: 14-runflow-sub.yaml` and `- runFlow: {file: 14-runflow-sub.yaml}`).
The live stderr lines and report.json are right. The stdout block is not (findings/evidence/cov2-ios/FLOWS-26/14-runflow.out,
exit 0 in 15.7 s):
```
  14-runflow
    ✓ launchApp
    ✓ runFlow: /tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-…/scratchpad/cov2-ios/ios/.maestro/coverage/14-runflow-sub.yaml
    ✓ launchApp
    ✓ runFlow: /tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-…/scratchpad/cov2-ios/ios/.maestro/coverage/14-runflow-sub.yaml
```
stderr for the same run (14-runflow.err:33-48): `✓ runFlow: 14-runflow-sub.yaml (2.1s)`. The path printed is in the
`/tmp` spelling, which is neither the cwd's realpath (`/private/tmp/…`) nor the path as written. Android prints the same
in the `run` result block, with and without `--report-dir`
(findings/evidence/cov2-android/B2-K105/verbose.out:4,6 and verbose-rd.out). 1 run per form per platform.

## Repro
Flow under test (landmarks-demo `ios/.maestro/coverage/14-runflow.yaml`, same on Android with the Android appId):
```yaml
appId: com.kylebrowning.Landmarks
---
- launchApp
- runFlow: 14-runflow-sub.yaml
- launchApp
- runFlow:
    file: 14-runflow-sub.yaml
```
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l19
unset GRANTIVA_API_KEY
rm -rf /tmp/l19 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l19 && cd /tmp/l19/ios
UDID=$(grantiva simulator ensure --name fix-l19 --device-type "iPhone 17" --runtime 26.0 | tail -1)
grantiva build install --simulator "$UDID"
grantiva run --no-build --simulator "$UDID" --flow .maestro/coverage/14-runflow.yaml 2>/dev/null | grep runFlow
# bug: "✓ runFlow: /tmp/l19/ios/.maestro/coverage/14-runflow-sub.yaml" (twice). Expected "✓ runFlow: 14-runflow-sub.yaml"
grantiva run --no-build --simulator "$UDID" --flow .maestro/coverage/14-runflow.yaml --json | jq -r '.screens[].steps[].action' | grep runFlow
grantiva simulator teardown --session-id fix-l19
```
Android: same in `/tmp/l19/android` with `--device "$SERIAL"` from `grantiva emulator ensure --name fix-l19`.

## Evidence
- findings/evidence/cov2-ios/FLOWS-26/14-runflow.out, 14-runflow.err, 14-runflow-report/, commands.txt (load 9.32)
- findings/evidence/cov2-android/B2-K105/verbose.out, verbose-rd.out, 01.out, commands.txt (load 11.52)
- docs/superpowers/plans/2026-10-11-coverage-issues/K105-runflow-step-prints-rewritten-path.md

## Suspected cause
- Staging rewrites every `runFlow` path to an absolute one (`FlowReferenceResolver.resolve(…, asWritten:
  &subFlowPathMap)`, `Sources/GrantivaCore/Runner/RunnerSession.swift:415-419`) and records absolute → as-written in
  `subFlowPathMap`. `reportPathMap` merges it with `stagedPathMap` (`:447-448`).
- The stdout steps come from report.json command `yaml` strings: `RunnerReportSteps.steps`
  (`Sources/GrantivaCore/Runner/RunnerReportSteps.swift:66-76`) is called by `RunnerArtifactCollector.collect`
  (`Sources/GrantivaCore/Runner/RunnerArtifactCollector.swift:88`) and by `RunnerFailureReport`
  (`Sources/GrantivaCore/Runner/RunnerFailureReport.swift:87`). `collect` is invoked at `RunnerSession.swift:584-587` with
  `stagedPathMap`, not `reportPathMap`, and does not rewrite step actions at all.
- report.json is rewritten with `reportPathMap` only in a `defer` (`RunnerSession.swift:485-490`,
  `RunnerReportRewriter.rewrite`), which runs after collection, and only with `--report-dir`. The live lines are fixed
  separately through `OutputRewriter(replacements: outputPathMap)` (`:548`). The step actions therefore keep the
  resolver's absolute path.

Fix: apply `OutputRewriter(replacements: outputPathMap)` (or `reportPathMap`) to every `StepResult.action` and
`message` built from report.json in `RunnerReportSteps.steps`, or pass the map into `collect` and `RunnerFailureReport`.

## Acceptance criteria
- `run --flow 14-runflow.yaml` prints `✓ runFlow: 14-runflow-sub.yaml` twice on stdout, on both platforms, with and
  without `--report-dir`. `--json` `steps[].action` reads the same.
- A failing sub-flow's `Error:` line and `--json` `error` name the sub-flow as written too.
- No `grantiva-flows-` path and no absolute path to a flow the user wrote relatively appears on stdout or in `--json`.
- Tests: GrantivaCoreTests/RunnerSessionOutputTests (or a RunnerArtifactCollector test), a report.json fixture whose
  command `yaml` is `runFlow: /abs/dir/sub.yaml` with `subFlowPathMap` `/abs/dir/sub.yaml → sub.yaml`: collected steps
  read `runFlow: sub.yaml`. The same for `RunnerFailureReport`.
