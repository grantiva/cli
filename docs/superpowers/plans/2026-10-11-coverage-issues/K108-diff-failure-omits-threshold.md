# A failing visual diff prints `Failed: pixel=… perceptual=…` without saying which threshold was exceeded

Severity: ux
Component: cli
Platforms: both (`diff compare` and the `ci` comparison are platform-independent; observed on iOS)
Rows: IOS-095 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
README:123-128: a screen passes only when **both** `diff.threshold` (pixel share) and `diff.perceptual_threshold`
hold, and "raising only `threshold` still fails the screen on `perceptual_threshold` (for example
`pixel=7.97% perceptual=6.4` against a limit of 5)". The failure line should carry that "against a limit of 5"
part: name the check that failed and its limit, e.g.
`Failed: perceptual=63.6 exceeds perceptual_threshold 5.0 (pixel=0.03%, threshold 2.00%)`, so the user knows which
knob to turn without reading the config and doing the comparison by hand.

## Actual
`findings/evidence/cov-ios/IOS-094/compare-default.out` (config `threshold: 0.02`, `perceptual_threshold: 5.0`):
```
✗ Visual diff failed
  Duration: 0.3s
  Passed: 5  Failed: 1  New: 0  Errors: 0

✗ Caching  pixel=0.03%  perceptual=63.6
    Failed: pixel=0.03% perceptual=63.6
```
With `threshold: 1.0`, `perceptual_threshold: 5.0` the failure line is byte-identical (`compare-threshold-only.out`),
although now only the perceptual check can have failed. With `perceptual_threshold: 80.0` the screen passes
(`compare-both.out`). IOS-095's behaviour check (below fails, above passes) passed.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k108
unset GRANTIVA_API_KEY
rm -rf /tmp/k108 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k108 && cd /tmp/k108/ios   # main 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k108 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID"
cp .maestro/coverage/cfg/screens-steps.grantiva.yml grantiva.yml     # diff: threshold 0.02, perceptual_threshold 5.0
grantiva diff capture --no-build --simulator "$UDID" && grantiva diff approve
sleep 60                                                             # the Caching screen shows a clock
grantiva diff capture --no-build --simulator "$UDID"
grantiva diff compare; echo "exit $?"
grantiva simulator teardown --session-id fix-k108; grantiva simulator delete --name "fix-k108 iPhone 17"
```
Today: exit 1 with `Failed: pixel=0.03% perceptual=<n>` for Caching and no threshold named. `diff compare --json`
does carry `pixel_threshold` / `perceptual_threshold` per screen, so only the human-readable message lacks them.

## Evidence
- findings/evidence/cov-ios/IOS-094/compare-default.out, compare-threshold-only.out, compare-both.out
- findings/evidence/cov-ios/IOS-094/grantiva-threshold-only.yml, grantiva-both.yml (the `diff:` blocks, lines 44-46), commands.txt
- findings/cov-ios-results.md rows IOS-094, IOS-095

## Suspected cause
The same format string in both comparison paths, built after a two-part pass test:
- Sources/GrantivaCLI/DiffCommand.swift:573-574 (`passed = pixelDiffPercent <= config.threshold && perceptualDistance
  <= config.perceptualThreshold`) and :585-587 (`"Failed: pixel=… perceptual=…"`).
- Sources/GrantivaCLI/CICommand.swift:126-127 and :134-136, the same code for `grantiva ci`.
The thresholds are in scope at both sites (`config.threshold`/`config.perceptualThreshold`,
`pixelThreshold`/`perceptualThreshold`) and are already stored on the result (`ScreenDiff.pixelThreshold`, …), so
only the message needs them. The MCP `grantiva_vrt_compare` tool returns the same documents, so it inherits the fix.

## Acceptance criteria
- A screen failing only the perceptual check prints a line naming `perceptual_threshold` and its value; failing only
  the pixel check names `threshold` (as a percent, matching how `pixel=` is printed); failing both names both.
- `diff compare` and the `ci` comparison print the same wording (one shared formatter).
- `--json` documents are unchanged apart from `message`.
- Unit tests in `GrantivaCLITests`: `DiffCommandTests.testFailureMessageNamesTheExceededThreshold` covering the three
  cases (pixel only, perceptual only, both), and an equivalent case in `CIComparisonPipelineTests`.
