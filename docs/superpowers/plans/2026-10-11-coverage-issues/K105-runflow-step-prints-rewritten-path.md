# `runFlow` step lines print grantiva's rewritten absolute sub-flow path, not the path written in the flow

Severity: ux
Component: cli
Platforms: both (iOS rows on 26.0 and 27.0; the Android coverage run prints the same absolute `/tmp/…` path, findings/evidence/cov-android/CF-14-runflow/out-cf-14-runflow.stderr:32-35, though AND-225 was graded on behaviour only)
Rows: IOS-225, IOS-225@27.0 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
The live step line, the nested-flow header and the summary name the sub-flow as the user wrote it, e.g.
`runFlow: 14-runflow-sub.yaml`. grantiva already rewrites staged paths back to the user's own for runner output
(Sources/GrantivaCore/Runner/RunnerSession.swift:360-362: "runner output and error messages never name a
/var/folders temp file"), so a path grantiva itself rewrote should be mapped back the same way. README:172 lists
`runFlow` as supported; IOS-225's behaviour (each form runs the sub-flow) passed.

## Actual
`findings/evidence/cov-ios/FLOWS-26/14-runflow.err:50-61` (project at `/private/tmp/…/cov-ios/ios`; the `S` prefix
`/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad` is shortened to `…`):
```
  [1/1] 14-runflow (14-runflow.yaml)
      ▸ Run /tmp/…/cov-ios/ios/.maestro/coverage/14-runflow-sub.yaml
    ✓ runFlow: /tmp/…/cov-ios/ios/.maestro/coverage/14-runflow-sub.yaml (2.2s)
      ▸ Run /tmp/…/cov-ios/ios/.maestro/coverage/14-runflow-sub.yaml
    ✓ runFlow: /tmp/…/cov-ios/ios/.maestro/coverage/14-runflow-sub.yaml (2.2s)
```
Both the string form and the `file:` form print the absolute path, and with the `/tmp` spelling of a project that
lives under `/private/tmp` (see K104). 27.0 is identical (`FLOWS-27/14-runflow.err`). The summary block prints a bare
`✓ runFlow (2.2s)` (14-runflow.err:67, :71).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k105
unset GRANTIVA_API_KEY
rm -rf /tmp/k105 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k105 && cd /tmp/k105/ios   # main 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k105 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID"
grantiva run --simulator "$UDID" --no-build --flow .maestro/coverage/14-runflow.yaml --verbose 2>&1 | grep -E 'runFlow|▸ Run'
grantiva simulator teardown --udid "$UDID"; grantiva simulator delete --name "fix-k105 iPhone 17"
```
The flows (in the clone):
```
# .maestro/coverage/14-runflow.yaml
appId: com.kylebrowning.Landmarks
---
- launchApp
- runFlow: 14-runflow-sub.yaml
- launchApp
- runFlow:
    file: 14-runflow-sub.yaml
# .maestro/coverage/14-runflow-sub.yaml
appId: com.kylebrowning.Landmarks
---
- tapOn: "Deep Links"
- assertVisible: "Caching Demo"
```
Today: `runFlow: /tmp/k105/ios/.maestro/coverage/14-runflow-sub.yaml` (the `/tmp` spelling even though the clone
resolves to `/private/tmp/k105`).

## Evidence
- findings/evidence/cov-ios/FLOWS-26/14-runflow.err lines 50-61, 67-71; FLOWS-26/commands.txt line 35
- findings/evidence/cov-ios/FLOWS-27/14-runflow.err (27.0)
- findings/evidence/cov-android/CF-14-runflow/out-cf-14-runflow.stderr lines 29-35 (Android, same output)
- findings/cov-ios-results.md rows IOS-225, IOS-225@27.0

## Suspected cause
- Sources/GrantivaCore/Runner/FlowReferenceResolver.swift:94-120: before staging a flow into the temp dir,
  `rewriteRunFlow` replaces each relative `runFlow` path (string and `file:` forms) with an absolute one
  (`resolvePath`, :112-120). This is needed: the staged copy no longer sits next to the sub-flow.
- RunnerSession.swift:367-370 calls the resolver; the staged-file map (`stagedPathMap`, :363, :394) and the
  `OutputRewriter` built from it (:397, :490) only map the staged top-level flow paths back, not the rewritten
  `runFlow` targets.
- The runner then prints the path it was given: pkg/flow/step.go:1125-1129 (`RunFlowStep.Describe` →
  `"runFlow: " + s.File`) and pkg/executor/flow_runner.go:1272 (`"Run "+step.File`).
- The `/tmp` spelling comes from `.standardizedFileURL` at FlowReferenceResolver.swift:119, which strips `/private`
  (same Foundation behaviour as K104).

Fix direction: have `FlowReferenceResolver.resolve` also return the absolute → as-written mapping for every
`runFlow` it rewrites, and merge it into the map that feeds `OutputRewriter` and `RunnerReportRewriter`. Fixing only
the `/private` spelling is not enough.

## Acceptance criteria
- Live step lines read `runFlow: 14-runflow-sub.yaml` for both forms, and the nested header reads
  `▸ Run 14-runflow-sub.yaml`, on iOS and Android.
- report.json / JUnit name the sub-flow the same way (or, if they keep an absolute path for tooling, it is the
  `realpath` spelling); the summary block is unaffected.
- A sub-flow referenced from a nested `commands:` block (e.g. inside `repeat`) is mapped back too.
- Sub-flows still resolve correctly when the run is started from another directory (existing
  `testGeneratedFlowsResolveReferencesAgainstInvocationDirectory` stays green).
- Unit tests in `GrantivaCoreTests/FlowReferenceResolverTests.swift`: `testResolveReportsTheAsWrittenPathOfEachRewrittenRunFlow`;
  and in `GrantivaCoreTests` (RunnerSessionCleanupTests.swift fake-runner harness) a test whose fake runner echoes
  `runFlow: <absolute>` and asserts grantiva's stderr shows the as-written path.
