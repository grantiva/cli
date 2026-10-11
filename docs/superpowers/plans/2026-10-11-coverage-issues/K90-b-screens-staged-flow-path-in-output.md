# Screens-config runs print the staged temp flow path (`/var/folders/…/grantiva-flows-…/flow.yaml`) in the summary header and in errors instead of grantiva.yml

Severity: ux
Component: cli
Platforms: ios (seen on iOS; the screens execution path is shared with Android, not tested there)
Rows: IOS-141, CLI-049 (ios); split from cluster C90 screens-staging-leaks-into-output (the `evalScript` narration is K90-a)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Output about a screens-config run names the file the user wrote. Matrix CLI-049: a `run_flow` cycle A→B→A gives an
error naming the cycle with no hang (README:141); the cycle should start at grantiva.yml (or the screen), not at a
temporary file. The `--flow` path already does this: `run --flow a.yaml` names a.yaml/b.yaml.

## Actual
IOS-141 summary header (capture.err:116):
```
  [1/1] flow (/var/folders/jv/76l6crmx6nl3hf150gzry_ym0000gn/T/grantiva-flows-DD5529FF-64B0-41C2-9EED-4AF10B673538/flow.yaml) - Device: cov-ios-1 (ios 26.0 Simulator)
```
CLI-049 (capture.err; grantiva.yml screen `S` with `run_flow: "a.yaml"`, a.yaml → b.yaml → a.yaml; exit 1 in 1.4 s):
```
Error: Runner failed (exit 1):
Validation errors:
  - /tmp/…/CLI-049/a.yaml: circular dependency detected: /var/folders/jv/76l6crmx6nl3hf150gzry_ym0000gn/T/grantiva-flows-E7AD960A-8F07-4D31-9780-8782E65C60CD/flow.yaml -> /tmp/…/CLI-049/a.yaml -> /tmp/…/CLI-049/b.yaml -> /tmp/…/CLI-049/a.yaml
```
The cycle is detected correctly; only the first link names the staged file. The temp path is gone by the time the
user reads it.

## Repro
Fixtures (`findings/evidence/cov-cli/CLI-049/fixtures/`, after merge):
```
# grantiva.yml
scheme: "Landmarks (UI Testing)"
bundle_id: com.kylebrowning.Landmarks
screens:
  - name: S
    path:
      - run_flow: "a.yaml"
# a.yaml                                # b.yaml
appId: com.kylebrowning.Landmarks       appId: com.kylebrowning.Landmarks
---                                     ---
- runFlow: b.yaml                       - runFlow: a.yaml
```
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k90b
unset GRANTIVA_API_KEY
rm -rf /tmp/k90b && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k90b && cd /tmp/k90b/ios   # 4e49dc4
printf 'scheme: "Landmarks (UI Testing)"\nbundle_id: com.kylebrowning.Landmarks\nscreens:\n  - name: S\n    path:\n      - run_flow: "a.yaml"\n' > grantiva.yml
printf 'appId: com.kylebrowning.Landmarks\n---\n- runFlow: b.yaml\n' > a.yaml
printf 'appId: com.kylebrowning.Landmarks\n---\n- runFlow: a.yaml\n' > b.yaml
UDID=$(grantiva simulator ensure --name "fix-k90b iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID" --no-launch
timeout 120 grantiva diff capture --no-build --simulator "$UDID" 2>&1 | grep -n 'grantiva-flows\|circular'
grantiva simulator teardown --session-id fix-k90b
```
Today: the cycle line starts at `/var/folders/…/grantiva-flows-…/flow.yaml`.

## Evidence
- findings/evidence/cov-ios/IOS-141/commands.txt, capture.err (line 116)
- findings/evidence/cov-ios/CLI-049/commands.txt, capture.err (screens form), run-cycle.err (`--flow a.yaml` form,
  names a.yaml)
- findings/evidence/cov-cli/CLI-049/fixtures/ (after merge)

## Suspected cause
`Sources/GrantivaCore/Runner/RunnerSession.swift`: the screens path stages the generated flow with
`FlowGenerator.writeTemp` (:56-58) and runs the runner with `pathMap: [:]` (:148), so neither the streamed output nor
the failure message (`stderr` used as-is at :167-171) is rewritten; only the report is mapped, to the bare word
`screens` (:98, :106). The flow path builds `outputPathMap` from staged → user paths (:363-397) and passes it at
:480/:490, which is why `run --flow a.yaml` reads correctly.

## Acceptance criteria
- Re-running the repro: the cycle error reads
  `circular dependency detected: grantiva.yml (screen "S") -> …/a.yaml -> …/b.yaml -> …/a.yaml` (or names grantiva.yml
  in another clear way); no `grantiva-flows-` path appears anywhere on stdout or stderr.
- IOS-141's summary header names grantiva.yml (or `screens`) instead of the temp file.
- GrantivaCoreTests/OutputRewriterTests (or RunnerExecutionTests): the screens path passes a path map that rewrites
  the staged flow path to the config file's name in streamed output and in `failureMessage`.
