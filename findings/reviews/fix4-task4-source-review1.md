# Spec Compliance

- **Source verdict: ❌ Needs fixes.** The L53/L68/L69/L71/L72/L73/L75/L76 source changes implement the requested boundaries; L78 still has an ownership race and an unbounded subprocess wait (Important findings below).
- **Acceptance verdict: ⚠️ Pending.** The scheduled Step 9 live acceptance, final committed-tree CI, PR and merge gates remain open. Their absence is not a source defect, and this review does not claim complete spec compliance.
- **Integration dependency: ⚠️ Task 7.** The nested `artifacts.notes`/`logTail` decoder and trace-export compatibility work recorded in `task-4-report.md` remains assigned to Task 7 before bundling. It is not a requested expansion of Task 4.
- **File inventory reconciliation: ⚠️ Missing named hunks.** The brief lists `Sources/GrantivaCLI/RunCommand.swift`, `Sources/GrantivaCore/Runner/FlowReferenceResolver.swift`, `Tests/GrantivaCLITests/RunCommandTests.swift`, and `Tests/GrantivaCoreTests/RunnerExecutionTests.swift`; none is changed. The narrower instructions explicitly put the path fix in the RunnerSession merge, and the cleanup behavior is implemented in LogStreamer. Reconcile these file-list departures in the task record; do not add empty changes to satisfy the inventory.

# Strengths

- `Sources/GrantivaCLI/DriverCommand.swift:216,285,388`: unique per-start report storage and production report polling connect Android readiness to completed launch/settle execution; the report option precedes the positional flow. Rejected temporary driver attachments are detached (`:318`).
- `Sources/GrantivaCLI/DriverCommand.swift:715,876`: foreground startup checks interruption before translating a timeout or treating a stop marker as an ordinary stop. `Tests/GrantivaCLITests/RunnerLifecycleCommandTests.swift:53` exercises plain, quiet and JSON parsing around the production wait/error helpers.
- `Sources/GrantivaCLI/BuildCommand.swift:204`, `Sources/GrantivaCLI/SimulatorCommand.swift:281`, `Sources/GrantivaCLI/RunnerLifecycleDocument.swift:50`: skipped absent installation bypasses container lookup, preliminary force-stop work survives in JSON, and starting-session output preserves null ports. The install tests invoke the real command with an injected device and inspect emitted JSON (`Tests/GrantivaCLITests/BuildCommandTests.swift:6`).
- `Sources/GrantivaCore/Runner/RunnerSession.swift:469` and `Tests/GrantivaCoreTests/RunnerSessionOutputTests.swift:522`: the path change is confined to merge precedence and the regression exercises real staging/resolution with both temporary-directory spellings.
- `Sources/GrantivaCore/Simulator/SimulatorReaper.swift:127`, `Sources/GrantivaCLI/TargetOptions.swift:62`: executable classification excludes the Python argument lookalikes, and blank targets fail at parser validation. The tests retain positive and unknown-flag controls.

# Issues

## Critical

- None identified.

## Important

1. **L78: the first signal can target a reused, unrelated PID.** `Sources/GrantivaCore/Runner/LogStreamer.swift:124–135`: ownership is established from a `ps` command string, but `processStartTime(pid)` is first read afterward. If the matching log child exits and that PID is reused between those operations, the code records the replacement's start time and immediately sends it SIGTERM. The `signalled` comparison only constrains subsequent escalation; it cannot validate the initial signal. The helper additionally retains only whole seconds (`Sources/GrantivaCore/Runner/RunnerStopMarker.swift:47–52`). Capture the process identity as part of ownership discovery, retain sufficient start-time precision, and revalidate that same identity and exact marker before signaling; never adopt a replacement's current start time as proof of ownership. Add an injected inventory/identity/signal regression that replaces the process between discovery and signaling and proves no signal reaches the replacement.

2. **L78: cleanup's deadline does not bound its inventory subprocess.** `Sources/GrantivaCore/Runner/LogStreamer.swift:119–140`: every iteration calls synchronous `snapshot()` before checking the deadline. The new production `processSnapshot()` runs `/bin/ps`, then blocks in `readDataToEndOfFile()` and `waitUntilExit()` without a timeout; the final confirmation snapshot is also outside the deadline. A stalled inventory therefore prevents `stop()` from returning indefinitely, including from the SignalRelay cleanup path. Give the inventory subprocess the remaining cleanup budget, terminate/reap that exact inventory child on timeout, and return the existing explicit incomplete-cleanup result. Add a focused test with a stalled inventory subprocess to prove the bound and absence of an abandoned inventory child.

## Minor

- **Expected failure-path warning leaks into green test output.** `Tests/GrantivaCoreTests/LogStreamerTests.swift:17–23` deliberately exercises failed inventory but does not capture/assert stderr; `findings/evidence/fix4-4/unit/full-suite.log:1580` contains `Warning: could not confirm log-stream cleanup for TEST-DEVICE ...`. Capture and assert that diagnostic so a passing suite is quiet. `green-argument-order.log:4` separately contains the existing `CLILogHandler.swift:34` protocol deprecation warning; this is outside this patch, but the final test output is not pristine.

# Checks and Evidence

- Read the complete 1,300-line review package once, base `8f2cff676b3c12e951478920fa20e600cdca4e29`, head `78e9b7526c80bb5f9c2892c19c1d3b31841cce3f`. No git commands, checkout changes, device operations, other reviewers, or test reruns.
- **Named risk — report completion during keep-alive:** checked `Sources/GrantivaCore/Runner/ReadyFile.swift:126–177`; the report decoder recognizes terminal per-flow statuses independently of runner exit. The changed production call supplies that report status. Live app-hierarchy correctness remains a scheduled gate.
- **Named risk — production log ownership and cleanup integration:** checked `Sources/GrantivaCore/Platform/IOSPlatform.swift:127–140` and `Sources/GrantivaCLI/RunCommand.swift:432–459`; the real iOS argv matches the new marker-insertion branch, and success/failure defer reaches `stop()`. The returned Boolean is currently discarded; the streamer itself emits a warning on incomplete cleanup.
- **Named risk — process identity precision and cancellation ordering:** checked `Sources/GrantivaCore/Runner/RunnerStopMarker.swift:47–52` and `Sources/GrantivaCore/Runner/SignalRelay.swift:248–275`; the former supplies only seconds, while the latter sets termination before signaling groups and invokes registered cleanups afterward. Read the remainder of `startDetached`/`startForeground` (`DriverCommand.swift:519–790`) because the review hunks cut off these lifecycle functions.
- Verified semantic failing assertions in the retained red captures for empty targets, explicit null ports, canonical cycles, argument lookalikes, readiness delay, startup interruption, absent-container lookup, force metadata, remote-child cleanup, and final argument ordering. The compile-correction captures were not counted as semantic red evidence.
- Existing full-suite evidence reports 270 MCP + 952 Core + 653 CLI + 101 API = **1,976 passing tests**; `full-suite-status.txt` reports exit 0 and an empty scoped runner home. `all-unit-homes.json` records all ten homes empty. This run predates the final argument-order fix. `green-argument-order.log:183` reports **63 passing lifecycle tests** after that fix. Final-tree CI is pending.

# Assessment

**Task quality: Needs fixes.** Most changes are narrow and connected to real production paths, with useful semantic red/green evidence. The new L78 cleanup needs identity-safe signaling and an actual end-to-end time bound before source approval; scheduled live acceptance and Task 7 compatibility remain separate gates.
