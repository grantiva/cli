# After a `--timeout` kill, the `--report-dir` report.json still says the run and its flow are `running`

Severity: wrong-result
Component: cli
Platforms: ios (seen on iOS; the timeout path is shared with Android, not tested there)
Rows: IOS-073 (ios); the screens-mode twin IOS-135 is placed in C20 (its report.json is also left `running`); original brief A06 (~/.grantiva-qa/briefs/docs/superpowers/plans/2026-10-09-qa-issues/A06-ready-file-interrupted-and-report-dir.md)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Brief A06: "a `--timeout` kill writes `failed` with no `running` flow"; README:97 (`--timeout`: the runner is killed
with SIGTERM). Matrix IOS-073 (changed): killed at about 30 s; ready `failed`, no flow `running`. The kept report in
`--report-dir` is the run's artifact of record and should agree with the ready file.

## Actual
The kill, exit code, message and ready file are right (timeout30.err, exit 1):
```
    ✓ launchApp (2.0s)
Failure screenshot: /private/tmp/…/cov-ios/out073/captures/failure-1791704032.png
Error: grantiva killed the runner after 30s (--timeout <seconds> to raise the cap). The runner's last output above shows how far it got.
Received interrupt, cleaning up...
```
but out073/report.json is left as the runner wrote it at the start of the wait:
```
  "status": "running",
    "running": 1,
      "status": "running",
        "running": 1,
```
(`summary`: total 1, passed 0, failed 0, running 1). JUnit and flow-000.json in the same directory are equally
unfinished.

## Repro
Flow (`ios/.maestro/coverage/18-long-wait.yaml`):
```
appId: com.kylebrowning.Landmarks
---
- launchApp
- extendedWaitUntil:
    visible: "This never appears"
    timeout: 45000
```
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k80
unset GRANTIVA_API_KEY
rm -rf /tmp/k80 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k80 && cd /tmp/k80/ios   # 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k80 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID" --no-launch
grantiva run --no-build --simulator "$UDID" --flow .maestro/coverage/18-long-wait.yaml --timeout 30 \
  --ready-file /tmp/k80/r.ready --report-dir /tmp/k80/out; echo "exit=$?"
jq -c '{status, flows: [.flows[].status]}' /tmp/k80/r.ready          # failed / failed
jq -c '{status, summary}' /tmp/k80/out/report.json                   # today: running, running: 1
grantiva simulator teardown --session-id fix-k80
```

## Evidence
- findings/evidence/cov-ios/IOS-073/commands.txt, timeout30.err, out073/report.json, out073/flow-000.json,
  out073/junit-report.xml
- findings/evidence/cov-ios/IOS-135/ (screens path: same `running` report, out-report.json)

## Suspected cause
- CLI: `Sources/GrantivaCore/Runner/RunnerSession.swift:495-521` (flow path; the screens path at :158-170 is the same
  shape): on a timeout it writes the ready file from `RunnerReportIndex.finalFlows(reportDir:unfinishedAs:)`, which
  computes the final statuses in memory, but never writes them back to report.json (or the per-flow JSON / JUnit) in
  the report directory. `RunnerReportRewriter` (Sources/GrantivaCore/Runner/RunnerReportRewriter.swift) only maps
  staged paths.
- Runner: the SIGTERM handler (`pkg/cli/test.go:942-972` in grantiva-runner) runs the driver cleanup and calls
  `os.Exit(1)` without finalising the report, so the file stays as last flushed.

## Acceptance criteria
- Re-running the repro: report.json has `"status": "failed"`, `summary.running: 0`, `summary.failed: 1`, and the
  flow's status `failed` with an error saying grantiva stopped it at the `--timeout` cap; flow-000.json agrees; the
  JUnit file records one failure (or is rewritten consistently).
- The ready file is unchanged (`failed`, flow `failed`, `reportDir` set because `--report-dir` was given).
- The same holds for the screens path (`diff capture` / configured screens with `--timeout`, IOS-135) and for an
  interrupt (`kill -INT` → `interrupted` in both files).
- GrantivaCoreTests/RunnerSessionReportTests (or RunnerReportWorkspaceTests): given a report dir whose report.json
  says `running`, the timeout finaliser rewrites it to `failed` with no `running` flows.
