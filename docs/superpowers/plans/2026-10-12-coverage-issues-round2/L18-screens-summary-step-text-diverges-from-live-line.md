# The screens summary on stdout names steps differently from the live line: `Wait 3.0s` vs `Wait 3s`, and `exact` is dropped

Severity: ux
Component: cli
Platforms: ios (seen on iOS; `stepAction` is platform-independent, so Android prints the same, not graded)
Rows: IOS-141 [ios], B2-K90-a [ios]
Regresses/extends: K90-a (screens wait narrated as evalScript), fixed by CLI #193 for the live line. Incomplete: the summary keeps its own labels.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
K90-a: a screens step reads the same in the live stderr line and in the stdout summary. A `wait: 3` step is `Wait 3s` in
both. A step written `{text: "…", exact: true}` keeps its exact qualifier in both (the live line shows `exact=true`), so
a reader can tell `Assert not visible "Golden Gate.*"` (substring/regex) from an exact match.

## Actual
`diff capture --no-build --verbose` with `.maestro/coverage/cfg/screens-steps.grantiva.yml`. All 6 screens were
captured, exit 0 in 51.6 s. Summary on stdout (findings/evidence/cov2-ios/IOS-141/capture.out):
```
  Lakes Exact
    ✓ Run flow ".maestro/coverage/cfg/relaunch.yaml"
    ✓ Assert visible "Golden Gate.*"
    ✓ Assert not visible "Golden Gate.*"
    ✓ Tap on "Lakes"
    ✓ Assert visible "Mono Lake"
  Caching
    ✓ Wait 3.0s
```
Live lines for the same steps (findings/evidence/cov2-ios/IOS-141/capture.err:47-62):
```
    ✓ assertNotVisible: text="Golden Gate.*", exact=true (690ms)
    ✓ tapOn: text="Lakes", exact=true (882ms)
    ✓ assertVisible: text="Mono Lake", exact=true (280ms)
    ✓ Wait 3s (3.0s)
```
The config writes `assert_not_visible: {text: "Golden Gate.*", exact: true}`, `tap: {text: "Lakes", exact: true}`,
`assert_visible: {text: "Mono Lake", exact: true}` and `wait: 3`. 1 run (load 8.81).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l18
unset GRANTIVA_API_KEY
rm -rf /tmp/l18 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l18 && cd /tmp/l18/ios
UDID=$(grantiva simulator ensure --name fix-l18 --device-type "iPhone 17" --runtime 26.0 | tail -1)
grantiva build install --simulator "$UDID"
cp .maestro/coverage/cfg/screens-steps.grantiva.yml grantiva.yml
grantiva diff capture --no-build --simulator "$UDID" > out.txt 2> err.txt
grep -E 'Wait|Golden Gate|Lakes|Mono Lake' out.txt      # bug: "Wait 3.0s", no exact
grep -E 'Wait 3s|exact=true' err.txt                    # live: "Wait 3s (3.0s)", exact=true
grantiva simulator teardown --session-id fix-l18
```

## Evidence
- findings/evidence/cov2-ios/IOS-141/capture.out, capture.err, commands.txt
- landmarks-demo `ios/.maestro/coverage/cfg/screens-steps.grantiva.yml` (b3f046f)
- docs/superpowers/plans/2026-10-11-coverage-issues/K90-a-screens-wait-narrated-as-evalscript.md

## Suspected cause
- `Sources/GrantivaCore/Runner/RunnerSession.swift:885-909` (`stepAction(for:)`, the summary label). It returns
  `"Wait \(seconds)s"` (`:894`) with `seconds: Double` (`GrantivaConfig.Screen.Step.wait`,
  `Sources/GrantivaCore/Config/GrantivaConfig.swift:33`), so `3` prints `3.0`. The live label comes from
  `FlowGenerator.waitLabel(seconds:)` (`Sources/GrantivaCore/Runner/FlowGenerator.swift:286-289`), which prints integral
  values without `.0`. There are two formatters for one step.
- The tap, assertVisible and assertNotVisible branches (`RunnerSession.swift:887-905`) never read `step.tapExact`,
  `step.assertVisibleExact` or `step.assertNotVisibleExact` (`GrantivaConfig.swift:70-72`).

Fix: have `stepAction` call `FlowGenerator.waitLabel` and add an exact marker (for example `Tap on "Lakes" (exact)`, or the
live line's `exact=true` form).

## Acceptance criteria
- `wait: 3` reads `Wait 3s` in the summary, and `wait: 1.5` reads `Wait 1.5s`, matching the live line.
- A step with `exact: true` (tap, assert_visible, assert_not_visible, by text) shows an exact marker in the summary. A
  step without it shows none.
- The same labels appear in `diff capture`, `run` (screens blocks) and the `--json` `steps[].action`. If `--json` keeps
  the old strings for compatibility, README says so.
- Tests: GrantivaCoreTests/RunnerSessionOutputTests, `stepAction` for `wait: 3`, `wait: 1.5`, and the three exact
  mappings, each equal to the expected string. One assertion ties the wait case to `FlowGenerator.waitLabel`.
