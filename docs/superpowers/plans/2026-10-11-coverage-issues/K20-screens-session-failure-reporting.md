# A failing or timed-out screens session is reported as an anonymous flow called `flow`, with mixed totals and an empty timeout reason

Severity: wrong-result
Component: cli
Platforms: both (Android AND-119; iOS IOS-134, IOS-135)
Rows: AND-119 (android); IOS-134, IOS-135 (ios). IOS-135's report.json left at `running` is C80 (another brief).
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
README:99 (screens session with `--continue-on-failure` and `--timeout`; briefs R03 and C04 for the timeout), matrix
IOS-134/IOS-135/AND-119:
- A failing screen is named: the user sees that screen `Broken` failed, at which step.
- Totals keep screens and flows apart (a screens session is not "1 of 3 screens").
- A timed-out screens session gets a complete message, like the flow path's
  `grantiva killed the runner after 30s (--timeout <seconds> to raise the cap). ...`.
- The ready file and the runner's report name the screens session consistently (e.g. `screens`) whether or not flows
  ran after it.

## Actual
`--continue-on-failure` with screens `Home` and `Broken` (tap "No Such Element") plus flow 01-browse (AND-119/cof.err,
cof.out; iOS IOS-134/continue.err:36-58, continue.out:3-12):
```
  [1/1] flow (/var/folders/.../grantiva-flows-28DD1868-.../flow.yaml) - Device: google sdk_gphone64_arm64 (android 35 Simulator)
...
  flow                           ✗ FAIL       6      3      1      2      20.6s  google sdk_gpho...
```
stdout:
```
  screens
    ✗ Capture screens
      Runner failed (exit 1); see the runner output above.

  01-browse-cmd-003-Home
    ✓ Run flow "01-browse"

  01-browse-cmd-007-Landmark Detail
    ✓ Run flow "01-browse"

  Screens: 3 total, 2 passed, 1 failed
```
`Broken` never appears; the runner calls the session `flow` and prints a staged `/var/folders` path; the "3 screens"
are the screens session plus two screenshots of a flow. The ready file lists only `01-browse` (screens session omitted).

`--timeout 30` on a screen that waits 45 s (AND-119/slow.err tail, 02.out; iOS IOS-135/timeout30.err):
```
Error: Runner timed out after 30s:
Received interrupt, cleaning up...
```
Ready file: `"flows": [{"name": "flow", "status": "failed"}]`. The only "detail" after the colon is the runner's
signal acknowledgement (K10).

## Repro
iOS (Android: Android prelude from K01, `cd android`, the `.grantiva-android.yml` variants and `--device "$SERIAL"`):
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k20
unset GRANTIVA_API_KEY
rm -rf /tmp/k20 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k20 && cd /tmp/k20/ios
UDID=$(grantiva simulator ensure --name "fix-k20 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID"
cp grantiva.yml /tmp/k20/grantiva.yml.orig
cp .maestro/coverage/cfg/screens-fail.grantiva.yml grantiva.yml
grantiva run --simulator "$UDID" --no-build --continue-on-failure --ready-file /tmp/k20/fail.ready > /tmp/k20/fail.out 2> /tmp/k20/fail.err; echo "exit $?"
grep -n 'Broken\|flow  \|Screens:' /tmp/k20/fail.out /tmp/k20/fail.err; cat /tmp/k20/fail.ready
cp .maestro/coverage/cfg/screens-slow.grantiva.yml grantiva.yml
grantiva run --simulator "$UDID" --no-build --timeout 30 --ready-file /tmp/k20/slow.ready 2>&1 | tail -2; cat /tmp/k20/slow.ready
cp /tmp/k20/grantiva.yml.orig grantiva.yml
grantiva simulator teardown --udid "$UDID"; grantiva simulator delete --name "fix-k20 iPhone 17"
```
Config used on Android (AND-119/screens-fail.yml; the iOS file has the same screens):
```
screens:
  - name: Home
    path: launch
  - name: Broken
    path:
      - tap: "No Such Element"
flows:
  - .maestro/01-browse.yaml
```
and `screens-slow.yml`: one screen `Slow` with `- tap: "Deep Links"` and `- wait: 45`.

## Evidence
- findings/evidence/cov-android/AND-119/cof.err, cof.out, 01.out (ready file), slow.err, 02.out (ready file), screens-fail.yml, screens-slow.yml, commands.txt
- findings/evidence/cov-ios/IOS-134/continue.err, continue.out, failfast.*; findings/evidence/cov-ios/IOS-135/timeout30.err, out-report.json

## Suspected cause
Three sites in the screens path, all CLI:
- Naming: the screens session runs one generated file, `grantiva-flows-<uuid>/flow.yaml`
  (Sources/GrantivaCore/Runner/FlowGenerator.swift:105-113), with no `name:` header and no per-screen labels, so the
  runner names it `flow` and its steps cannot be mapped to screens. `RunnerReportRewriter.rewrite(... stagedPathMap:
  [flowPath: "screens"])` (Sources/GrantivaCore/Runner/RunnerSession.swift:96-99) renames it only in the preserved report
  after the fact, and the runner's live output is relayed with an empty path map (`pathMap: [:]`, :148), so the temp
  path leaks. The `--continue-on-failure` row is built in Sources/GrantivaCLI/RunCommand.swift:589-597 as a single
  `Capture screens` step with the generic runner message.
- Totals: Sources/GrantivaCLI/RunCommand.swift:472-474 counts `captures` (the failed screens row plus one capture per flow
  screenshot) as "Screens".
- Timeout text: Sources/GrantivaCore/Runner/RunnerSession.swift:158-173 uses `"Runner timed out after \(timeoutSeconds)s"`
  and `failureMessage` adds `:` plus the runner's captured stderr, which is only `Received interrupt, cleaning up...`
  (K10). The flow path (:495-501) has the explanatory sentence.

## Acceptance criteria
- `--continue-on-failure` repro: output names `Broken` and its failed step (e.g. `✗ Broken: tap "No Such Element" —
  Element not found ...`), `Home` shows as captured, then 01-browse runs; exit 1.
- The summary reports screens and flows separately, e.g. `Screens: 2 total, 1 captured, 1 failed` and
  `Flows: 1 total, 1 passed`; flow screenshots are not counted as screens.
- No `/var/folders/.../grantiva-flows-*/flow.yaml` path and no flow named `flow` in the runner's relayed output; the
  screens session is called `screens` (or each screen by name) in live output, ready file and report.
- The ready file lists the screens session (`screens`, `failed`) alongside `01-browse` when both ran.
- Timeout repro: `Error: grantiva killed the screens session after 30s (--timeout <seconds> to raise the cap). It was at
  screen "Slow".` (wording free; no dangling colon, no "interrupt").
- GrantivaCoreTests (FlowGeneratorTests): the generated screens flow carries a `name:` and per-screen labels;
  GrantivaCLITests (RunCommandTests): the summary counts for 2 screens (1 failed) + 1 flow; a RunnerSession test for
  the timed-out screens message.
