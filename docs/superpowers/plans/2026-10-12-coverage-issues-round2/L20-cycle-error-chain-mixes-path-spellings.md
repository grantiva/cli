# The `runFlow` cycle error mixes relative names with one absolute `/tmp/...` hop

Severity: ux
Component: cli (the output rewrite; the chain itself comes from the runner's validator)
Platforms: ios (seen on iOS; staging and the rewrite are platform-independent, so Android is expected to match, not exercised)
Rows: CLI-049 [ios] (handed over from the CLI slice), B2-K90-b [ios]
Regresses/extends: K90-b (screens staged flow path in output), fixed by CLI #193. Incomplete: criterion 1's "names the user's files" holds for only some hops.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
K90-b criterion 1: screens output and errors name `grantiva.yml` and the user's files, never a staged or temp path.
A circular `runFlow` error starts at `grantiva.yml` (screens) or at the flow passed to `--flow`. It names every hop in one
form: the path as written, relative to the project directory.

## Actual
Fixtures (findings/evidence/cov2-ios/CLI-049/fixtures/): `a.yaml` runs `b.yaml`, `b.yaml` runs `a.yaml`, and
`grantiva.yml` has one screen whose path is `run_flow: "a.yaml"`. The cycle is found in 1.4 s, with no hang. The chain
has one absolute hop (findings/evidence/cov2-ios/CLI-049/capture.err):
```
Validation errors:
  - a.yaml: circular dependency detected: grantiva.yml -> a.yaml -> /tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-…/scratchpad/cov2-ios/cli/CLI-049/b.yaml -> a.yaml
```
`run --flow a.yaml` (run-cycle.err):
```
  - b.yaml: circular dependency detected: a.yaml -> b.yaml -> /tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-…/scratchpad/cov2-ios/cli/CLI-049/a.yaml -> b.yaml
```
The cwd was `/private/tmp/…/CLI-049`, so the absolute hop is not even in the cwd's realpath spelling. No
`grantiva-flows-` path appears (that half of K90-b holds). 1 run per form.

## Repro
Fixtures:
```yaml
# a.yaml
appId: com.kylebrowning.Landmarks
---
- runFlow: b.yaml
```
```yaml
# b.yaml
appId: com.kylebrowning.Landmarks
---
- runFlow: a.yaml
```
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l20
unset GRANTIVA_API_KEY
rm -rf /tmp/l20 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l20 && cd /tmp/l20/ios
UDID=$(grantiva simulator ensure --name fix-l20 --device-type "iPhone 17" --runtime 26.0 | tail -1)
printf 'appId: com.kylebrowning.Landmarks\n---\n- runFlow: b.yaml\n' > a.yaml
printf 'appId: com.kylebrowning.Landmarks\n---\n- runFlow: a.yaml\n' > b.yaml
grantiva run --no-build --simulator "$UDID" --flow a.yaml 2>&1 | grep circular
# bug: "a.yaml -> b.yaml -> /tmp/l20/ios/a.yaml -> b.yaml"; expected "a.yaml -> b.yaml -> a.yaml -> b.yaml"
printf 'bundle_id: com.kylebrowning.Landmarks\nscheme: "Landmarks (UI Testing)"\nscreens:\n  - name: A\n    path:\n      - run_flow: "a.yaml"\n' > grantiva.yml
grantiva diff capture --no-build --simulator "$UDID" 2>&1 | grep circular
# bug: "grantiva.yml -> a.yaml -> /tmp/l20/ios/b.yaml -> a.yaml"
grantiva simulator teardown --session-id fix-l20
```

## Evidence
- findings/evidence/cov2-ios/CLI-049/capture.err, run-cycle.err, commands.txt (load 11.02), fixtures/
- findings/evidence/cov2-ios/IOS-141/ (B2-K90-b's other half, passing)
- docs/superpowers/plans/2026-10-11-coverage-issues/K90-b-screens-staged-flow-path-in-output.md

## Suspected cause
- The runner builds the chain from the file paths it resolved (`pkg/validator/validator.go:390-399`, `validateFile`:
  `strings.Join(cycle, " -> ")` over absolute paths in `chain`).
- grantiva rewrites runner output with `OutputRewriter(replacements: outputPathMap)`
  (`Sources/GrantivaCore/Runner/RunnerSession.swift:548`). `outputPathMap` is `expandedPathMap(reportPathMap)`
  (`:447-449`, `/tmp` ↔ `/private/tmp` variants added by `RunnerReportRewriter.expanded`,
  `Sources/GrantivaCore/Runner/RunnerReportRewriter.swift:64-74`). It knows only (a) staged top-level copies →
  as passed (`stagedPathMap`, `:440`) and (b) the `runFlow` targets `FlowReferenceResolver` rewrote inside those staged
  copies (`subFlowPathMap`, `:415-419`).
- A hop that the runner resolved itself, inside a sub-flow grantiva did not stage (b.yaml's `runFlow: a.yaml` in the
  `--flow` case, a.yaml's `runFlow: b.yaml` in the screens case), is in neither map, so it prints as the runner's
  absolute path. The spelling (`/tmp`, not `/private/tmp`) follows the absolute flow paths grantiva passes. Not traced
  to the exact line. The order of hops matches this explanation in both forms.

Fix direction: resolve the `runFlow` graph transitively when staging (the resolver already reads each target), and add
every reachable file's absolute path (both spellings) → cwd-relative path to `subFlowPathMap`. Alternatively, have the
rewrite turn any absolute path under the project directory into a cwd-relative one.

## Acceptance criteria
- `run --flow a.yaml` on the fixtures prints `circular dependency detected: a.yaml -> b.yaml -> a.yaml -> b.yaml`
  (every hop relative, as written), on stderr, exit 1, within 5 s.
- The screens form prints `grantiva.yml -> a.yaml -> b.yaml -> a.yaml`.
- Fixtures in a subdirectory (`flows/a.yaml` → `../shared/b.yaml`) print each hop relative to the project directory.
  No hop is absolute unless the user wrote it absolute.
- Tests: GrantivaCoreTests (FlowReferenceResolverTests or RunnerSessionOutputTests): staging `a.yaml` whose sub-flow
  `b.yaml` runs `a.yaml` yields a path map that contains the absolute `a.yaml` and `b.yaml` (both spellings). An
  `OutputRewriter` over the runner's cycle line produces the all-relative chain.
