# Under `nohup grantiva run --keep-alive` a SIGHUP kills the runner at once while grantiva survives, so the keep-alive session dies

Severity: crash
Component: cli (spawn attributes in grantiva; the runner only keeps the disposition it is given)
Platforms: ios (seen on iOS; the spawn path is shared, so Android is expected to behave the same, not exercised)
Rows: N2-18 [ios] (part a; part b is L12)
Regresses/extends: new brief for the fix-wave Task 5 deferred minor ("spawn resets SIGHUP") left by CLI #194 (K79 watchdog, signal-mask reset).
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
`nohup` sets SIGHUP to SIG_IGN so the command survives a hang-up (closing the terminal, an SSH drop). A process whose
SIGHUP was ignored when it started should hand that on: under `nohup grantiva run --keep-alive`, the runner survives a
SIGHUP as the nohup'd grantiva does, and the keep-alive session stays usable (`grantiva hierarchy`, MCP attach,
`runner stop`). The N2-18 matrix row records this as the deferred minor from the fix-wave Task 5 ledger.

## Actual
`nohup grantiva run --no-build --simulator <cov2-ios-1> --flow .maestro/01-browse.yaml --keep-alive --ready-file …`.
After the ready file reported `passed`, SIGHUP went to the runner pid read from its owner sidecar, then to grantiva
(findings/evidence/cov2-ios/N2-18/nohup-hup.out, 1 run, load 9.06):
```
grantiva pid 12004 (nohup child of 12004 ) runner pid 12109
after SIGHUP to runner: runner alive False grantiva alive True
after SIGHUP to grantiva: runner alive False grantiva alive True
nohup exit 1
runner alive at end False
```
The runner died on the first SIGHUP, and grantiva ignored both. grantiva did not notice that its runner was gone: it
kept running until the script sent SIGINT, then exited 1. The dead runner left its session file and orphaned WDA and
diagnose processes, which `simulator teardown --udid --force` then had to reap (L12). The other half of N2-18 holds: a
runner started from a parent that blocks SIGINT/SIGTERM has an empty blocked mask and stops on the first signal
(start-blocked.out, mask.out, stop-verbose.out).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l11
unset GRANTIVA_API_KEY
rm -rf /tmp/l11 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l11 && cd /tmp/l11/ios
UDID=$(grantiva simulator ensure --name fix-l11 --device-type "iPhone 17" --runtime 26.0 | tail -1)
grantiva build install --simulator "$UDID"
nohup grantiva run --no-build --simulator "$UDID" --flow .maestro/01-browse.yaml --keep-alive --ready-file /tmp/l11/ready >/dev/null 2>&1 &
NOHUP=$!
until [ -s /tmp/l11/ready ]; do sleep 1; done
RUNNER=$(jq -r --arg u "$UDID" 'select(.udid==$u) | .runnerPid' /tmp/grantiva-sessions/*.owner.json)
ps -o pid=,ignored= -p "$NOHUP" -p "$RUNNER"   # SIGHUP (bit 1) ignored in grantiva; bug: not in the runner
kill -HUP "$RUNNER"; sleep 3
kill -0 "$RUNNER" && echo "runner alive" || echo "bug: runner dead"
grantiva hierarchy --udid "$UDID" | head -3    # expect the tree from the live session
grantiva runner stop; wait "$NOHUP"
grantiva simulator teardown --session-id fix-l11
```
`findings/evidence/cov2-ios/inputs/nohup_hup.py` is the script the slice used (Python driver for the same steps).

## Evidence
- findings/evidence/cov2-ios/N2-18/nohup-hup.out, nohup-hup.err, commands.txt (loads 8.4-9.2)
- findings/evidence/cov2-ios/N2-18/start-blocked.out, mask.out, stop-verbose.out (the half that passes)
- findings/evidence/cov2-ios/inputs/nohup_hup.py
- docs/superpowers/plans/2026-10-12-round2-coverage-matrix.md row N2-18

## Suspected cause
- `Sources/GrantivaCore/Runner/ChildProcess.swift:64-79`: every spawn sets `POSIX_SPAWN_SETSIGDEF` with
  `[SIGINT, SIGTERM, SIGHUP, SIGQUIT, SIGPIPE]` (`:78`). A grantiva that inherited SIG_IGN for SIGHUP from `nohup`
  therefore starts the runner with SIGHUP back at SIG_DFL. The comment at `:69-73` explains the reset for SIGINT/SIGTERM
  (CI runners and `&` hand them over ignored). SIGHUP was added to the same list.
- The runner's own handler covers only SIGINT and SIGTERM (`pkg/cli/test.go:979`, `signal.Notify(sigCh, syscall.SIGINT,
  syscall.SIGTERM)`). Go keeps an ignored-at-start signal ignored unless it is `Notify`'d, so with SIG_DFL the runner
  terminates on SIGHUP.
- The existing test `testAHangUpEndsTheWatchdogWithoutTouchingTheRunner`
  (`Tests/GrantivaCoreTests/ChildProcessTests.swift:217-231`) makes the child ignore HUP itself (`trap '' HUP`), so it
  cannot catch the reset.
- Secondary: grantiva's keep-alive wait did not end when its runner died. It ran until SIGINT. Not traced. Check the
  keep-alive wait loop in `Sources/GrantivaCore/Runner/RunnerExecution.swift` for a child-exit observer.

## Acceptance criteria
- When grantiva starts with SIGHUP ignored (`nohup`, or `trap '' HUP` in the calling shell), the runner it spawns has
  SIGHUP ignored too, and survives `kill -HUP <runner pid>`. The keep-alive session keeps answering `grantiva hierarchy`
  and is stopped normally by `runner stop`.
- When grantiva starts with SIGHUP at its default, the behaviour is unchanged (a closing terminal still ends the runner
  through the group).
- SIGINT and SIGTERM stay reset to default, as today (N2-18 part 1 keeps passing).
- If a keep-alive runner dies anyway, grantiva notices within a few seconds and exits non-zero naming the runner's exit
  (signal name). It does not wait for an external SIGINT.
- Tests: GrantivaCoreTests/ChildProcessTests: spawn `/bin/sh -c 'sleep 30'` from a test that first sets SIGHUP to
  SIG_IGN in the process (restore it after). `kill(pid, SIGHUP)` leaves the child running, and the default-disposition
  case still kills it. Also a test that `ps -o ignored=` (or `sigaction` read through a helper child) shows SIGHUP ignored
  in the child.
