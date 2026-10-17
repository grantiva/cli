# Interrupted ready-file diagnosis

This is a read-only diagnosis of the frozen candidate 10 evidence. It does not
change interrupt behavior.

## Evidence qualification

The candidate 10 `BA06-BA07-interrupt-logs` run is a valid active-flow
interrupt fixture. Its stderr reaches `Runner ready`, starts the Android log
stream, and prints `Running 1 flow(s) ... 11-slow.yaml`. The sampled grantiva
process and its run-owned logcat child are alive for more than 1.5 seconds
before the collector sends SIGINT. The command exits 130, its owned logcat
child is gone, and `ready.json` is absent both before and after process exit.
This supports the retained B-A06.1/B-A06.2 failures and X-004's missing
`interrupted` member. Earlier attempts interrupted during startup do not add
evidence for the active-flow contract and should remain excluded.

The collector starts grantiva in a new process group and signals that exact
group. `ChildProcess` separately places grantiva-runner in its own group, so
the fixture does not bypass grantiva by directly signalling the runner group.

## Source path and ordering defect

`RunnerExecution.run` registers a SignalRelay cleanup that writes an
`interrupted` `RunReadyState` and releases the lease. However,
`SignalRelay.terminate` first calls `ChildProcess.terminateGroup` for every
tracked runner group and only afterwards invokes registered cleanups. The
frozen implementation therefore cannot satisfy B-A06.2's required
record-before-group-termination ordering. The active candidate 10 run further
shows that the expected cleanup write was not durably observable at all.

The normal post-wait path in `RunnerSession` also finalizes the report and
writes `interrupted`, but a terminating SignalRelay exits the grantiva process
from its dispatch signal handler after synchronous cleanups; that normal async
path is not a reliable fallback for an OS-signal interrupt.

The failure is specific to this signal/cleanup path:

- B2-K80's candidate 10 timeout path is driven by RunnerExecution's timeout
  task, returns to RunnerSession, finalizes the report, and writes a `failed`
  ready file. Its retained iOS evidence has terminal report, JUnit, and ready
  state and does not reproduce this defect.
- Older Android evidence contains an `interrupted` screens ready file, but it
  does not supersede the exact candidate 10 active-flow failure. It proves the
  vocabulary and finalizer can encode the value, not that every OS-signal path
  durably records it.
- AND060/startup-only attempts must not be used as active-flow proof. A signal
  before RunnerExecution has registered its cleanup has a different
  precondition.

## Minimal later repair boundary

A later interrupt repair should make the terminal ready-file write happen
before runner-group termination, while retaining one-write semantics and the
existing report finalization. Focused tests should signal an actually active
RunnerExecution request and assert: the ready file becomes `interrupted`
before the runner group is observed dead; unfinished flows are rewritten to
`interrupted`; exit is 130; and owned log streaming/session/lease resources
are removed. A separate startup-interrupt test should retain its own expected
behavior rather than stand in for the active-flow case.

Evidence reviewed:

- `candidate10-android/BA06-BA07-interrupt-logs/{stderr,during.json,termination-order.json,exit,assessment.json}`
- `candidate10-android/X004-ready-vocabulary/{assessment.json,adjacent-correction.json}`
- `candidate10-ios-b/activated/main-extra-022-b2-k80/assessment.json`
- `Sources/GrantivaCore/Runner/{RunnerExecution.swift,RunnerSession.swift,SignalRelay.swift,ReadyFile.swift}`
