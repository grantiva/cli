# Inline `runFlow: {commands: [...]}` is rejected before the run with "object form requires a string 'file' field"

Severity: wrong-result
Component: cli
Platforms: both (Android AND-226; iOS 26.0 and 27.0, IOS-226)
Rows: AND-226 (android); IOS-226, IOS-226@27.0 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
README:172 lists `runFlow` among supported commands and says flows run with `run --flow` "go to the runner as written".
Maestro's `runFlow` takes a file, or an inline `commands:` list (optionally with `when:`/`env:`/`label:`). Matrix
AND-226/IOS-226: the inline commands run.

## Actual
Every platform, before any step (CF-14b-runflow-inline/out-cf-14b-runflow-inline.stderr; FLOWS-26/14b-runflow-inline.err):
```
Running 1 flow(s)...
Running 1 flow(s) in one GrantivaAgent session: .maestro/coverage/14b-runflow-inline.yaml
Failure screenshot: .../captures/failure-1791704050.png
Error: Invalid argument: Invalid runFlow command: object form requires a string 'file' field
```
Exit 1. A failure screenshot is taken although nothing ran (the device just shows whatever was on screen). Same on
iOS 27.0 (FLOWS-27/14b-runflow-inline.err).

## Repro
iOS (Android: Android prelude from K01, `cd android`, `--device "$SERIAL"`; the Android flow is identical except `appId`):
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k22
unset GRANTIVA_API_KEY
rm -rf /tmp/k22 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k22 && cd /tmp/k22/ios
UDID=$(grantiva simulator ensure --name "fix-k22 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID"
grantiva run --simulator "$UDID" --no-build --flow .maestro/coverage/14b-runflow-inline.yaml; echo "exit $?"
grantiva simulator teardown --udid "$UDID"; grantiva simulator delete --name "fix-k22 iPhone 17"
```
Flow `.maestro/coverage/14b-runflow-inline.yaml` (android copy):
```
appId: com.kylebrowning.landmarks
---
- launchApp
- runFlow:
    commands:
      - tapOn: "Favorites"
      - assertVisible: "Landmarks you favorite will appear here."
```

## Evidence
- findings/evidence/cov-android/CF-14b-runflow-inline/out-cf-14b-runflow-inline.stderr, 01.out, commands.txt
- findings/evidence/cov-ios/FLOWS-26/14b-runflow-inline.err, FLOWS-27/14b-runflow-inline.err (commands in FLOWS-26/commands.txt)
- Row pointer: findings/evidence/cov-android/AND-226/commands.txt

## Suspected cause
- `Sources/GrantivaCore/Runner/FlowReferenceResolver.swift:94-110` (`rewriteRunFlow`): for the object form it requires
  `options["file"] as? String` and otherwise throws `invalidRunFlow("object form requires a string 'file' field")`
  (:103-105). Inline `commands:` (and a `when:`-guarded inline block) have no `file`.
- The resolver runs on every `run --flow` file before staging (Sources/GrantivaCore/Runner/RunnerSession.swift:367-370)
  and on generated screens flows (FlowGenerator.swift:108), so the runner never sees the flow.
- The failure screenshot comes from `RunCommand.handleSuiteFailure` (Sources/GrantivaCLI/RunCommand.swift:134-147):
  `wantsFailureScreenshot` (:130-132) is true for any error that is not a lease refusal, including a parse error.

## Acceptance criteria
- The repro passes on iOS 26.0, 27.0 and Android: the inline `tapOn` and `assertVisible` run and show as steps.
- An inline block's nested `runFlow: file` entries are still resolved relative to the parent flow (the existing
  `commands` recursion, FlowReferenceResolver.swift:78-91, applies to them).
- `runFlow: {file: x.yaml, when: ...}` keeps working; `runFlow: {}` (neither `file` nor `commands`) still fails with an
  error naming both accepted forms.
- A flow that fails to parse or resolve before the runner starts takes no failure screenshot.
- GrantivaCoreTests (FlowReferenceResolverTests): inline `commands` passes through unchanged; inline commands containing
  `runFlow: sub.yaml` get that path resolved; an empty object throws. GrantivaCLITests: `wantsFailureScreenshot` is false
  for an `invalidArgument` raised before the runner started.
