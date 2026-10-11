# Step and flow durations differ between the live lines, the summary block and report.json

Severity: wrong-result
Component: runner
Platforms: both (confirmed on Android and iOS 26.0, N-17 in both slices)
Rows: N-17 (android), N-17 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Matrix N-17 (plan N17; round-1 smoke): for the same step, the live step line, the summary block and report.json give
the same duration, and the flow's live total, table row, summary block and report agree. A user comparing a CI log with
the uploaded report must see one number.

## Actual
Passing steps drift by 1 ms in 4 of 90 steps (Android stock run, AND-106/durcmp.txt):
```
01-browse 1 assertVisible: text="Landmarks" live 751ms summary 752ms report 752
01-browse 3 takeScreenshot live 213ms summary 214ms report 214
02-favorite 10 assertNotVisible: text="Lake Tahoe" live 654ms summary 655ms report 655
08-caching 5 takeScreenshot live 160ms summary 161ms report 161
```
Failing steps drift by 200-700 ms. Android 09-waits (CF-09-waits/out-cf-09-waits.stderr:35 vs :45):
`✗ extendedWaitUntil: notVisible text="Loading…" (12.5s)` live, `✗ extendedWaitUntil (12.7s)` in the summary.
iOS (N-17/analysis.txt): 99-crash `✗ assertVisible` live 12.2 s, summary 12.4 s, report.json 12419 ms;
12-env-precedence-cli live 12.5 s, summary 13.2 s.
Flow totals also disagree on iOS: 99-crash live line and table 17.0 s, summary block and report 14.4 s; 01-browse
7.7 s live/table vs 5.0 s summary (IOS-117/stock-26.err).

## Repro
iOS (larger drift; any failing flow shows it):
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k05
unset GRANTIVA_API_KEY
rm -rf /tmp/k05 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k05 && cd /tmp/k05/ios
UDID=$(grantiva simulator ensure --name "fix-k05 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID"
grantiva run --simulator "$UDID" --no-build --flow .maestro/coverage/02-exact-negative.yaml --report-dir /tmp/k05/out 2>&1 \
  | grep -E '✗ assertVisible|02-exact-negative +[0-9.]+s|✗ 02-exact-negative'
python3 -c "import json;f=json.load(open('/tmp/k05/out/flows/flow-000.json'));print([(c['type'],c.get('duration')) for c in f['commands']])"
grantiva simulator teardown --udid "$UDID"; grantiva simulator delete --name "fix-k05 iPhone 17"
```
Android: same commands with the Android prelude (see K01) and `grantiva run --device "$SERIAL" ...`; the stock set
(`grantiva run --device "$SERIAL" --no-build --report-dir /tmp/k05/out`) shows the 1 ms drift on passing steps.
(Per-command durations are in the report directory's `flows/flow-000.json`, `commands[].duration`.)

## Evidence
- findings/evidence/cov-android/AND-106/durcmp.txt (comparison script output; script in findings/evidence/cov-android/inputs/durcmp.py)
- findings/evidence/cov-android/CF-09-waits/out-cf-09-waits.stderr lines 35 and 45
- findings/evidence/cov-ios/N-17/analysis.txt; findings/evidence/cov-ios/N-14/crash.err; findings/evidence/cov-ios/N-14/reports/99-crash-flow.json
- Row pointer: findings/evidence/cov-android/N-17/commands.txt

## Suspected cause
Runner (release-round1, ae48e34); the live line and the report time different intervals:
- Live step line: `FlowRunner.executeStep` measures `stepDuration := time.Since(stepStart)` at
  pkg/executor/flow_runner.go:630 (start at :422) and returns it to `OnStepComplete` (:292-296).
- Summary block and report.json: `FlowWriter.CommandStart` (pkg/report/flow.go:50-55) stamps a start after the debug
  log and platform gate, and `CommandEndWithWarning` (:76-88) stamps the end when it is called, which is after the
  failure enrichment (WebView/CDP detection, flow_runner.go:~650-672) and the failure `captureArtifacts(idx, "after", ...)`
  screenshot plus hierarchy (:680-686). That post-step work is ~200-700 ms on a failure and ~1 ms otherwise.
- Flow totals: the live line and table use `time.Since(flowStart)` with `flowStart` taken at flow_runner.go:55, before
  per-flow setup; report.json's flow duration runs from `flowWriter.Start()` (:178) to `flowWriter.End` (:376), which
  excludes that setup (2.6 s on iOS 99-crash).

## Acceptance criteria
- For every step of the repro (passing and failing), the live line, the summary block and report.json show the same
  value at their shared precision (live `12.4s` ⇔ report `12419ms` rounds to the same tenth).
- A flow's live total, table row, summary block and report.json flow duration are equal; if setup time is meant to be
  separate, it is reported separately and labelled.
- Decide and document whether a failing step's duration includes failure artifact capture; whichever is chosen, all
  three outputs use it.
- Runner test (pkg/executor): with a fake driver that fails a step and a fake artifact capture that sleeps 300 ms, the
  duration passed to `OnStepComplete` equals the command duration written by the FlowWriter.
