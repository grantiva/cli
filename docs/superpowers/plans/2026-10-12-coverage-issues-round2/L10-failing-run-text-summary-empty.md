# A failing `run` with screens and flows prints nothing on stdout: no per-screen/per-flow blocks and no `Screens:`/`Flows:` lines

Severity: wrong-result
Component: cli
Platforms: both (iOS and Android identical; platform-independent code path)
Rows: S2-03 [ios], S2-03 [android]
Regresses/extends: K20 (screens-session failure reporting), fixed by CLI #193 for `--json` only. The text form still prints nothing.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
README `run` and K20: the text result is one block per configured screen and per flow, then `Screens: <n> total, <c>
captured, <f> failed` and `Flows: <n> total, <p> passed, <f> failed`, then `Screenshots: <dir>/`. That is what a passing
stock run prints (IOS-117). A failing run prints the same blocks for whatever ran, with the failed step marked `✗`,
before the `Error:` line, and still exits 1. `--json` already does this (`failureResult` carries every capture).

## Actual
iOS: the stock config (5 screens + 12 flows) with the first flow replaced by `coverage/02-exact-negative.yaml`. The
screens session passed and the flow failed, exit 1 in 44.2 s, and **stdout was 0 bytes**
(findings/evidence/cov2-ios/S2-03/run.out). stderr ends with the runner's table and the error only
(findings/evidence/cov2-ios/S2-03/run.err):
```
  TOTAL                            0/12       3      2      1      0      18.7s
  ✓ Tests completed. Generating reports...
Failure screenshot: .grantiva/run-captures/failure-1791747277.png
Error: Runner failed (exit 1): 02-exact-negative: assertVisible: text="Golden Gate.*", exact=true: Element not visible: text='Golden Gate.*', exact=true (cause: context deadline exceeded: no elements match selector; closest on-screen texts: "Golden Gate Bridge", "Golden Gate Bridge, San Francisco, CA", "Categories")
```
Android: the stock config with 03-edit replaced by 02-exact-negative, `--report-dir` and `--ready-file`, exit 1 in
117 s. Stdout held only the shell's `exit=1` and the ready file. grantiva printed neither summary line, while the ready
file is right (findings/evidence/cov2-android/S2-03/01.out): `screens` passed, `01-browse`/`02-favorite` passed,
`02-exact-negative` failed, the rest skipped. 1 run per platform. The Android smoke showed the same.

## Repro
iOS:
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l10
unset GRANTIVA_API_KEY
rm -rf /tmp/l10 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l10 && cd /tmp/l10/ios
UDID=$(grantiva simulator ensure --name fix-l10 --device-type "iPhone 17" --runtime 26.0 | tail -1)
grantiva build install --simulator "$UDID"
sed -i '' 's#- .maestro/01-browse.yaml#- .maestro/coverage/02-exact-negative.yaml#' grantiva.yml
grantiva run --no-build --simulator "$UDID" > out.txt 2> err.txt; echo "exit=$?"   # exit=1
wc -c out.txt                                    # bug: 0
grep -E 'Screens:|Flows:' out.txt err.txt        # bug: nothing
grantiva run --no-build --simulator "$UDID" --json | jq '[.screens[] | {name, kind, passed}]'   # --json does carry the screens and the failed flow
grantiva simulator teardown --session-id fix-l10
```
Android: the same in `/tmp/l10/android` with `SERIAL=$(grantiva emulator ensure --name fix-l10)`,
`grantiva build install --device "$SERIAL"`, the same `sed` on `grantiva-android.yml`, and
`grantiva run --no-build --device "$SERIAL"`. Finish with `grantiva emulator teardown --serial "$SERIAL"`.

## Evidence
- findings/evidence/cov2-ios/S2-03/commands.txt (load 10.71), config.out, run.out (0 bytes), run.err
- findings/evidence/cov2-android/S2-03/commands.txt (load 12.53), 01.out, 01.err
- findings/evidence/cov2-ios/IOS-117/ (the passing stock run's summary for comparison)
- docs/superpowers/plans/2026-10-11-coverage-issues/K20-screens-session-failure-reporting.md

## Suspected cause
- `Sources/GrantivaCLI/RunCommand.swift:552-558`: a throw from `runFlows` (or `runScreens`) lands in the `catch`, which
  calls `handleSuiteFailure` and rethrows. The text result at `:561-566` (`resultLines`) is reached only when nothing
  throws.
- `handleSuiteFailure` (`RunCommand.swift:205-217`) takes the failure screenshot and, only when `json` is set, emits
  `failureResult(error:report:)`. There is no text branch.
- The data exists: `RunnerFailureReport.captures` (`Sources/GrantivaCore/Runner/RunnerFailureReport.swift:20-23`) merges
  the earlier screen captures (`recordEarlierCaptures`, called at `RunCommand.swift:524`) with the failed session's
  screens and flows. `failureResult` (`Sources/GrantivaCLI/RunCommand+Result.swift:147-160`) already uses it for
  `--json`.
- Same shape to check in `diff capture` and `ci run` if they share `handleSuiteFailure` (the `captures` path at
  `RunCommand.swift:632` is a second suite loop).

## Acceptance criteria
- A failing `run` without `--json` and without `--quiet` prints, on stdout before the `Error:` line, the same blocks a
  passing run prints for every screen and flow that ran: the failed flow's failing step marked `✗` with its message, the
  steps not run absent or marked skipped, then `Screens: 5 total, 5 captured, 0 failed` and `Flows: <n> total, <p>
  passed, <f> failed` counting what the ready file counts. Exit 1 is unchanged.
- A failure before any capture (build error, usage error, ownership refusal) prints no empty summary.
- `--quiet` suppresses progress and runner narration only; the summary blocks are the command's result and still print on stdout (README `--quiet` contract; corrected in round 3, superseding the earlier reading that `--quiet` is silent). `--json` output is unchanged.
- Both platforms (same code).
- Tests: GrantivaCLITests/RunCommandTests, a suite whose screens session returns captures and whose flows session throws
  a runner-outcome failure: the text output contains the screen blocks, the failed flow block with `✗`, and both summary
  lines (drive `handleSuiteFailure`, or a new `failureLines(report:)` helper, with a captured `Output`). Pin also the
  "no captures, no summary" case.
