# Android launchApp can still pass after a matching fatal crash

Severity: contract
Component: runner
Platforms: android
Rows: B3-L57
Regresses: L57, addressed in runner #23; retain the revised acceptance criteria and withdrawn wall-time target.
Candidate: CLI 8f2cff67, runner fd9d8e8 / 1.1.28-grantiva.13.
Status: evidence-backed triage during the incomplete round-3 coverage pass; not a round-completion statement.

## Expected

L57 requires launchApp not to pass when a fatal crash for one of the launch's PIDs is logged before it returns, even if a frame was displayed. A crash after launchApp returns may instead fail the following step. The withdrawn total wall-time target is not part of this finding.

## Actual

Two of five captured crash runs report launchApp success after the matching FATAL line. Both fail the following assertion with app_crash, so the overall flow verdict is correctly failed.

| Capture | FATAL timestamp | launchApp success timestamp | Delay |
|---|---|---|---|
| CF-crash1 | 02:33:04.904 | 02:33:05.596303 | 0.692 s |
| CF-crash2 | 02:33:29.392 | 02:33:29.604464 | 0.212 s |

The last launch status in each says a PID exists, drawn=true, crashed=false. CF-crash3 and CF-crash5 fail at launchApp. CF-crash4 passes launchApp before FATAL and is not counted as this violation.

## Repro

On the campaign-owned cov3-android emulator, use the verified QA binary and QA runner home to run the demo's `.maestro/99-crash.yaml` five times with `--device emulator-5554 --no-build` and distinct report directories. Capture device FATAL/am_crash timestamps and runner step timestamps. Exact original commands and loads are in each evidence directory's commands.txt. Do not use an owner device or a default device selector.

## Evidence

- `findings/evidence/cov3-android/CF-crash1/` and `CF-crash2/`: commands.txt, fatal.txt, am_crash.txt, run.out, report/maestro-runner.log, report/flow-000.json.
- `findings/evidence/cov3-android/CF-crash3/` through `CF-crash5/`: comparison runs.
- `findings/evidence/cov3-android/B3-L57/commands.txt`: shared-evidence mapping.

Evidence currently lives on cov3/android until the slice is merged.

## Suspected cause

Inference: process/frame/crash observations become stale or are combined across different instants; a fatal event can occur before success returns while the final snapshot still reports crashed=false. Confirm in the bundled runner source rather than assuming the earlier L57 cause still applies.

## Acceptance criteria

These criteria isolate the observed defect. They do not replace, relax, or regrade the binding B3-L57 campaign row; its full five-run criterion and other accepted requirements must still be verified separately.

- A deterministic regression reproduces a matching fatal event between launch status reads and the success decision; launchApp returns app_crash.
- A displayed frame cannot mask a matching fatal event already observed before return.
- Healthy launch remains successful; crashes after successful return are caught by the following step.
- Five real demo crash runs preserve raw timing evidence and show no launchApp success after a matching fatal event. Failure remains within the accepted 2-second FATAL-to-failure bound.
- Preserve the existing permission batching and native-app Flutter-probe behavior; do not reintroduce the withdrawn total wall-time target.
