# A `run --keep-alive` released after its hold (by `runner stop` or Ctrl-C) exits 130 instead of the status its flows earned, and after a failed flow prints no `Flows:` summary or `Error:` line

Severity: contract
Component: cli (the runner already exits with the earned status after a release)
Platforms: ios (4 of 4: passed and failed flow, each with `runner stop` and with SIGINT; load 11-17), android (3 of 3: passed flow with both, failed flow with `runner stop`; load 2.4-7.4)
Rows: round3-smoke KA-after-hold (findings/evidence/round3-smoke/I-keepalive/after-{pass,fail}-*, sigint-after-{pass,fail}-*; A-keepalive/after-{pass,fail}-*, sigint-after-pass-*)
Regresses/extends: L36 ruling (ledger, Task 2 re-review: "a stop received after the hold is armed releases the hold and exits with the status the run earned"); runner #21 implements the runner half. L10 (failing-run summaries).
Binary: grantiva 2.1.0 (main dc965716), grantiva-runner 1.1.28-grantiva.12

## Expected
Once a `--keep-alive` run has printed `Press Ctrl-C to release.`, its flows are over and the ready file holds the
verdict. Releasing the hold, with `runner stop` from the project directory or with Ctrl-C / `kill -INT`, ends the run
exactly as the same run without `--keep-alive` ends: the flow blocks, `Flows: 1 total, 1 passed, 0 failed` (or
`… 0 passed, 1 failed` plus the `Error: Runner failed (exit 1): …` line), and exit 0 for a pass, 1 for a failure.
A stop during the flows stays exit 130 (L36, L55). A second SIGINT while the release is in progress may still exit 130.

## Actual
Every release after the hold exited 130 (`# exit` lines of the run files):

| file | flow | stop | exit | `Flows:` line |
|---|---|---|---|---|
| I-keepalive/after-pass-run.txt | 01-browse (passed) | runner stop | 130 | printed |
| I-keepalive/sigint-after-pass-run.txt | 01-browse (passed) | SIGINT | 130 | printed |
| I-keepalive/after-fail-run.txt | 99-crash (failed) | runner stop | 130 | none, no `Error:` |
| I-keepalive/sigint-after-fail-run.txt | 99-crash (failed) | SIGINT | 130 | none, no `Error:` |
| A-keepalive/after-pass-run.txt | 01-browse (passed) | runner stop | 130 | printed |
| A-keepalive/sigint-after-pass-run.txt | 01-browse (passed) | SIGINT | 130 | none |
| A-keepalive/after-fail-run.txt | 99-crash (failed) | runner stop | 130 | none, no `Error:` |

I-keepalive/after-fail-run.txt (tail):
```
  GrantivaAgent keep-alive: port=8417 session=17065-1791768281995494000
  /tmp/grantiva-sessions/17065-1791768281995494000.grantiva
    Press Ctrl-C to release.

[grantiva] received SIGINT — releasing simulator and reaping child processes

  Releasing GrantivaAgent session...
# exit 130  end 18:24:45
```
The `runner stop` side was right each time (`Stopped keep-alive session (pid N, <device>)`, exit 0), and the sessions
directory was empty afterwards.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l56
unset GRANTIVA_API_KEY
rm -rf /tmp/l56 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l56 && cd /tmp/l56/ios
UDID=$(grantiva simulator ensure --name fix-l56 --device-type "iPhone 17" --runtime "iOS 26.0")
grantiva build install --simulator "$UDID" --no-launch
for flow in 01-browse 99-crash; do for how in stop int; do
  out=/tmp/l56/$flow-$how.txt
  grantiva run --simulator "$UDID" --no-build --flow .maestro/$flow.yaml --keep-alive > $out 2>&1 &
  RUN=$!
  until grep -q "Press Ctrl-C to release" $out; do sleep 0.5; done; sleep 3
  if [ $how = stop ]; then grantiva runner stop; else kill -INT $RUN; fi
  wait $RUN; echo "$flow $how exit $? (expected $([ $flow = 01-browse ] && echo 0 || echo 1))"
  grep -E "^  Flows:|^Error:" $out
done; done
grantiva simulator teardown --udid "$UDID"
# Android: cd /tmp/l56/android, SERIAL=$(grantiva emulator ensure --name fix-l56), --device "$SERIAL".
```

## Evidence
- findings/evidence/round3-smoke/I-keepalive/commands.txt, after-pass-*, after-fail-*, sigint-after-pass-*,
  sigint-after-fail-*
- findings/evidence/round3-smoke/A-keepalive/commands.txt, after-pass-*, after-fail-*, sigint-after-pass-*
- findings/evidence/round3-smoke/keepalive.sh, keepalive-sig.sh

## Suspected cause
CLI, main dc965716. Confirmed from the code; the runner's own exit status after the release was not captured in the
evidence (no runner log kept for these rows), so the runner half is from the code.
- Runner (grantiva/main 2d1b625): `handleRunSignal` (`pkg/cli/keepalive.go:247-251`) releases an armed hold and
  returns; the run then ends through its normal path and returns exit 1 for a failed run, 0 for a pass
  (`pkg/cli/test.go:1201-1210`). So the runner hands the CLI 0 or 1.
- Both stops reach the CLI as SIGINT to the grantiva process: Ctrl-C directly, `runner stop` through
  `RunnerSessionStopper.stop` → `interrupt(owner)` (Sources/GrantivaCore/Runner/RunnerSessionStopper.swift:116-121).
- `SignalRelay.handle` (Sources/GrantivaCore/Runner/SignalRelay.swift:154-162) runs `terminate` (marks terminating,
  SIGINTs the runner's group and waits up to 5 s for it, runs the cleanups; :166-189) and then calls
  `exit(128 + signalNumber)` unconditionally. It never asks whether a hold was armed or what the runner returned.
- Meanwhile the main thread sees the runner exit with `interrupted = SignalRelay.shared.isTerminating` true
  (RunnerExecution.swift:233-235) and `RunnerSession` classifies the outcome as `interrupted` before looking at the
  status (RunnerSession.swift:572-629, "An interrupt is checked first"). For a failed flow the catch path then takes a
  failure screenshot first (`wantsFailureScreenshot`, RunCommand.swift:201-204, true because the flows did not pass;
  `handleSuiteFailure`, :210-226) before printing the summary, so the relay's `exit(130)` lands first and nothing
  prints. For a passed flow `markPassedBeforeInterrupt` (RunnerSession.swift:616-621) skips the screenshot and the
  summary usually wins the race (Android SIGINT row: it lost). `RunCommand.awaitSignalRelayExit` (:326-330) also
  ends in `Darwin.exit(130)`.

## Acceptance criteria
- The repro exits 0 for 01-browse and 1 for 99-crash with both `runner stop` and SIGINT, on both platforms, 3 of 3
  each; the output ends with the flow block and `Flows:` line (and for 99-crash the `Error:` line), as the same run
  without `--keep-alive` does; `--json` emits the run document with `allPassed` matching the exit; the ready file is
  unchanged (written once, `passed` / `failed`).
- A stop during the flows still exits 130 with ready file `interrupted` (L36 ruling, L55); a second SIGINT during
  the release still exits 130 promptly; `runner stop`'s own output and exit code unchanged.
- Fix direction: once the hold is armed (the readiness watcher in RunnerExecution.swift:188-215 has seen every flow
  terminal and the runner's session file), the relay treats the first SIGINT/SIGTERM as a release: it forwards the
  signal to the runner's group, runs no `exit`, and lets the main path see the runner's own status, classified as
  `passed`/`failed` rather than `interrupted`. Before the hold, today's behaviour stays. Say in the PR how the armed
  state reaches the relay (a flag the watcher sets is enough).
- Tests: GrantivaCoreTests (SignalRelay / RunnerSession): with the armed flag set, a simulated SIGINT does not exit
  and a fake runner exiting 1 yields a `failed` outcome (not `interrupted`), 0 yields `passed`; without the flag, the
  outcome is `interrupted` as today. GrantivaCLITests: the failure path prints the `Flows:` summary before returning
  exit 1 after a release.
