# `diff compare` with no baselines reports `✓ Visual diff passed` and exits 0

Severity: wrong-result
Component: cli
Platforms: ios (seen on iOS; the verdict code is shared with Android, not tested there)
Rows: IOS-091 (ios); the MCP verdict (`grantiva_vrt_compare` `passed: true` with new screens) shows in MCP-063/MCP-070
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Matrix IOS-091 (README:466): with no baselines, each screen is reported as new / missing a baseline, and the run is
not a pass. A comparison that compared nothing cannot have passed; CI that gates on the exit code would otherwise
accept a fresh checkout with no baselines at all.

## Actual
compare-nobaseline.out (exit 0):
```
✓ Visual diff passed
  Duration: 0.0s
  Passed: 0  Failed: 0  New: 5  Errors: 0

? Deep Links
    New screen — no baseline. Run: grantiva diff approve
? Detail
    New screen — no baseline. Run: grantiva diff approve
…
exit=0
```
MCP `grantiva_vrt_compare` returns `passed: true` with 4 new screens in the same situation (MCP-063 transcript,
noted under MCP-070).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k89
unset GRANTIVA_API_KEY
rm -rf /tmp/k89 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k89 && cd /tmp/k89/ios   # 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k89 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID" --no-launch
grantiva diff capture --no-build --simulator "$UDID"
rm -rf .grantiva/baselines
grantiva diff compare; echo "exit=$?"
grantiva diff compare --json | jq '.passed'
grantiva simulator teardown --session-id fix-k89
```
Today: `✓ Visual diff passed`, exit 0, `true`.

## Evidence
- findings/evidence/cov-ios/IOS-091/commands.txt, compare-nobaseline.out
- findings/evidence/cov-ios/MCP-063/session/transcript.txt (vrt_compare `passed: true` with new screens)

## Suspected cause
- `Sources/GrantivaCLI/DiffCommand.swift:554-624` (`compare`): `allPassed` starts `true` (:563) and is cleared only
  for failed or errored comparisons; a screen with no baseline is appended as `.newScreen` (:612-620) without
  touching it, and :623 returns `passed: allPassed`.
- `Sources/GrantivaCore/Output/TableOutput.swift:94` prints the headline from `result.passed`; the exit code follows
  it at DiffCommand.swift:426-428. MCP `grantiva_vrt_compare` shares the same result.

## Acceptance criteria
- Re-running the repro: `diff compare` exits non-zero, the headline is not `✓ Visual diff passed` (for example
  `? No baselines: 5 new screens. Run: grantiva diff approve`), and `--json` has `"passed": false` (or a distinct
  documented status field such as `"verdict": "no_baselines"` with `passed: false`).
- Decide and document the mixed case (some screens pass, some are new): it must not be a silent pass; README's diff
  section says what exit code it gives.
- `grantiva_vrt_compare` reports the same verdict. `ci run` keeps whatever first-run behaviour it documents
  (check CICommand before changing the shared verdict).
- GrantivaCLITests/DiffCommandTests: `compare` over captures with no baselines returns `passed == false`; with all
  baselines matching returns `true`.
