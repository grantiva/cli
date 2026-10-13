# Interrupted run returns before its simulator log stream exits

Severity: contract
Component: cli / log lifecycle
Platforms: iOS
Rows: IOS-064
Candidate: CLI 8f2cff676b3c12e951478920fa20e600cdca4e29; QA binary SHA256 3f3293aaf1522fefe8d46457370b32a20fa8c657461bf32af086e75a754a73f8.
Status: independently confirmed during incomplete round-3 verification; cleanup lag is transient, not a persistent leak.

## Expected

IOS-064 requires no orphan `log stream` after successful, failed, or interrupted `run --logs`. Returning from the command should mean its owned logging process has stopped. B2-K33 separately requires truthful verbose subprocess start/terminal diagnostics.

## Actual

In attempt119b, success plain and verbose return0 and crash failure returns1 with no matching stream in the immediate process snapshots. The SIGINT case returns130 and prints its expected signal notice and `stopped by SIGTERM` diagnostic for the tracked xcrun wrapper. Immediately after that return, PID17077 remains running as `log stream --style compact --predicate ... Landmarks`, parent43186. It is absent from the snapshot two seconds later and a later direct PID check.

Thus the underlying simulator-side stream briefly survives the owning CLI, despite its completed cleanup diagnostic. There is no evidence of a lasting process leak. B2-K33 passes; IOS-064 fails the explicit no-orphan contract.

## Repro and evidence

Use the preserved `findings/evidence/cov3-ios-attempt119b/harness.sh` with the campaign-owned cov3-ios-26 device, QA runner home and `GRANTIVA_SESSION_ID=cov3-ios`. It runs the success/failure controls, launches `run --no-build --simulator <owned UUID> --flow .maestro/11-slow.yaml --logs --verbose`, observes the actual logging process, sends SIGINT only to its recorded CLI PID, waits for exit, and immediately inventories processes.

Evidence in the iOS slice `findings/evidence/cov3-ios-attempt119b/`: `harness.sh`, `commands.txt`, `sigint-active-observed`, `sigint.pid`, `sigint.exit`, `sigint.err`, `sigint-after-processes.txt`, `sigint-after-2s-processes.txt`, and the success/failure controls. The original attempt119 is excluded because its incorrect session ID caused ownership refusals before valid device work. No owner device or unrelated process was touched.

Independent review: CLI slice `findings/ios119b-k33-ios064-review.md`.

## Suspected cause

At the exact candidate head, `Sources/GrantivaCore/Runner/LogStreamer.swift` starts an xcrun simctl spawn wrapper. Its stop routine terminates and waits on the tracked Foundation Process, without confirming the simulator-side log child has exited. `Sources/GrantivaCLI/RunCommand.swift` defers that stop routine and registers signal cleanup. The observed terminal diagnostic describes the wrapper, not proof that its simulator-side child is absent. Fix investigation must distinguish the wrapper lifecycle from the remote spawned process; never introduce broad process-name killing.

## Acceptance criteria

- Successful, failed and interrupted runs return only after their own simulator logging child has stopped; capture immediate post-exit inventories in repeated SIGINT controls.
- Cleanup remains bounded, scoped to the exact run and device, and does not stop another live run's logging process.
- A regression test models a wrapper exiting before its spawned logging child and proves cleanup waits for or safely terminates that child.
- Preserve exit130 and the single truthful verbose terminal diagnostic; plain mode remains free of debug subprocess lines.
