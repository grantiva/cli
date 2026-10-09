# Write an accurate ready file: `interrupted` with final flow statuses on Ctrl-C/timeout, and no `reportDir` when the directory is deleted

Severity: contract
Platforms: cli, ios, android
Found by: AND-F10, AND-F11 (matrix rows AND-060, AND-049, AND-034)
Binary: grantiva 2.0.1 (commit c8dc86d), runner 1.1.18-grantiva.7+android-drivers-2, emulator-5554 (Pixel_8_API_35, API 35)

## Expected
A waiter can tell Ctrl-C from a test failure, and every field points at something real. Source: README §Agent-Native
Features (`jq -r .status ... # passed | failed | interrupted`); Sources/GrantivaCore/Runner/ReadyFile.swift:15 (`passed`,
`failed`, or `interrupted`); help: run (the default report dir is ephemeral).

## Actual
`kill -INT` ~8 s into a keep-alive run: exit 130, and the ready file says `failed` with the flow still `running`:
```
{ "flows" : [ { "name" : "qa-longwait", "status" : "running" } ],
  "reportDir" : "/var/folders/.../T/grantiva-report-DE149198-...", "status" : "failed" }
```
The `--timeout` kill leaves the same `running` flow status (AND-049). Without `--report-dir`, a passing run's ready file
names a directory that is already gone: `ls "$(jq -r .reportDir x.ready)"` -> `No such file or directory`.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_SESSION_ID=qa-android QA=/Users/kyle/Developer/grantiva-cli/.worktrees/qa-android
cd /Users/kyle/Developer/landmarks-demo/android
grantiva run --no-build --flow $QA/findings/evidence/flows/qa-longwait.yaml --device emulator-5554 \
  --keep-alive --ready-file /tmp/int.ready & pid=$!
sleep 12; kill -INT $pid; wait $pid; echo "exit $?"; cat /tmp/int.ready          # failed / running
grantiva run --no-build --flow .maestro/05-category.yaml --device emulator-5554 --ready-file /tmp/x.ready
ls "$(jq -r .reportDir /tmp/x.ready)"                                              # No such file or directory
```

## Evidence
- findings/evidence/AND-060/{int.ready,log.txt,stderr.txt}, AND-049/r.ready
- findings/evidence/AND-034/{x.ready,poll.txt}

## Suspected cause
Sources/GrantivaCore/Runner/SignalRelay.swift:128-131 terminates the runner's process group before running cleanups.
The runner exits non-zero, `RunnerExecution.run` returns, and Sources/GrantivaCore/Runner/RunnerSession.swift:401-405
writes `failed` with the report's live flow statuses. The `interrupted` cleanup (RunnerExecution.swift:85-87) runs
afterwards and is dropped by the write-once ReadyFileSignal (ReadyFile.swift:188-200). For AND-F11, RunnerSession.swift:
401-415 (and the watcher at RunnerExecution.swift:154-158) always set `reportDir`, even when `preserveReportDir` is false.

## Acceptance criteria
- Re-running the repro: the first ready file has `"status": "interrupted"` and no flow left `running` (mark it
  `interrupted`/`cancelled`); a `--timeout` kill writes `failed` with no `running` flow; the second ready file has no
  `reportDir` key (or `null`) unless `--report-dir` was given.
- Interruption is recorded before the group is terminated (e.g. set a terminating flag that RunnerSession consults, or run
  the ready-file cleanup first).
- GrantivaCoreTests/ReadyFileTests and RunnerExecutionTests: a simulated SIGINT during a running flow yields
  `interrupted`; RunnerSessionCleanupTests: an ephemeral report dir is not written to the ready file.
