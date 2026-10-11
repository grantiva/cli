# A ready file for a run that failed during setup names a report directory that was never created and omits the error

Severity: contract
Component: cli
Platforms: both (shared code; seen in the CLI slice and on iOS 26.0)
Rows: CLI-044 (cli), IOS-031 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
README:85-88: the ready file is written at the terminal state, and "`reportDir` is present only when `--report-dir`
was given: the default report directory is deleted when the run exits" — i.e. it points at a directory a waiter can
read. `RunReadyState.error` is documented as "Why the run failed before reaching the runner (for example a usage
error)" (Sources/GrantivaCore/Runner/ReadyFile.swift:22-23). A setup failure therefore carries `error`, and carries
`reportDir` only if that directory exists.

## Actual
`run --report-dir out --ready-file out.ready` with `flows: []` and no screens (findings/evidence/cov-cli/CLI-044/after.out,
run.err), exit 1:
```
Error: Invalid argument: No screens or flows configured in grantiva.yml
ls: out: No such file or directory
{
  "finishedAt" : "2026-10-11T05:56:07Z",
  "flows" : [

  ],
  "reportDir" : "out",
  "status" : "failed"
}
```
Identical on iOS 26.0 (findings/evidence/cov-ios/IOS-031/after.out). A usage error (`--timeout 5`) does write `error`
(README:85, RunCommand.validate), so the two setup-failure paths disagree.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k39
rm -rf /tmp/k39 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k39 && cd /tmp/k39/ios
printf 'scheme: "Landmarks (UI Testing)"\nsimulator: fix-k39\nbundle_id: com.kylebrowning.Landmarks\nflows: []\n' > grantiva.yml
grantiva run --report-dir out --ready-file out.ready; echo "exit $?"
ls -d out; cat out.ready
grantiva run --timeout 5 --ready-file out2.ready; cat out2.ready     # has "error"
```
No device is touched; the run fails in about 20 ms.

## Evidence
- findings/evidence/cov-cli/CLI-044/commands.txt, run.err, after.out
- findings/evidence/cov-ios/IOS-031/commands.txt, run.err, after.out, grantiva.yml

## Suspected cause
- Sources/GrantivaCLI/RunCommand.swift:202-215 (the `catch` in `run()`): when no verdict was written it writes
  `RunReadyState(status: "failed", flows: [], reportDir: reportDir)`, passing the `--report-dir` value whether or not
  the directory was created, and no `error`, although `Self.failureMessage(error)` is computed two lines above for
  the `--json` document (:200).
- RunCommand.swift:66-77 (`validate`) is the path that does pass `error:`.

## Acceptance criteria
- Re-running the repro: `out.ready` is `{"status": "failed", "flows": [], "error": "No screens or flows configured in
  grantiva.yml", "finishedAt": ...}`, with no `reportDir` because `out/` does not exist; the error text equals the
  `--json` document's `error` for the same run.
- A setup failure after the report directory exists (for example a boot failure with `--report-dir`) keeps `reportDir`.
- Every ready file written by the setup-failure path has `error`.
- GrantivaCLITests/RunCommandTests: a run with no screens or flows and `--report-dir out --ready-file f` writes `error`
  and no `reportDir`; GrantivaCoreTests/ReadyFileTests: round-trip with `error` set and `reportDir` nil.
