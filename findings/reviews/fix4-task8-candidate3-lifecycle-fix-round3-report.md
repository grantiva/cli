# Candidate 3 lifecycle live-1 classification and harness fix round 3

## Classification

The first candidate-3 lifecycle invocation is a **harness false failure after a passing iOS startup-interrupt assertion**, not a product failure. Under the recorded L72 contract, startup interruption requires genuine `starting`, exit `130`, the exact interrupt notice, and exact cleanup; it does not require a completed launch report. The immutable live evidence records the CLI process exiting `130`, the runner session observed in genuine `starting` state, exact runner PID `66518` gone, the project session gone, and no cleanup actions required. The helper then failed in its snapshot callback because the production startup-interrupt cleanup had already removed the temporary report directory.

Binding evidence:

- `findings/evidence/round4-smoke-candidate3/03-lifecycle/helper/failure.json` records the completed startup-interrupt check and the later `FileNotFoundError`.
- `findings/evidence/round4-smoke-candidate3/03-lifecycle/helper/startup-interrupt/ios.starting.json`, `ios.result.json`, and `ios.stderr` establish `starting`, exit `130`, and the exact SIGINT cleanup notice.
- The retained `ios-runner-report/maestro-runner.log` proves the snapshot worker captured the report while it existed; `ios-generated-flow.yaml` preserves the authenticated generated flow.
- `cleanup.json` records an empty bounded action list, consistent with production cleanup already removing the session and owned runner.

The original attempt remains immutable and cannot count as a complete lifecycle phase. Candidate 3 needs a fresh full lifecycle rerun after independent review of this harness-only correction.

## Scoped correction

Report completion is now phase-specific. Only `startup_interrupt` passes `report_required=False`. That phase still requires the authentication handshake, exact PID/device argv binding, retained report and generated-flow paths, ownership recording, joined worker, propagated copy/ownership errors, exit `130`, exact interrupt diagnostic, runner PID absence, and session cleanup. If the report directory exists, it is copied. If production cleanup removes it before the terminal pass, the helper records truthful terminal metadata and accepts the absence; any snapshot already captured remains retained.

Detached readiness, ready-state interruption, and force teardown keep the default `report_required=True`. Their terminal report must exist and copy successfully. L68 detached readiness still requires its complete passed report, and completed-flow phases retain mandatory proof before cleanup. Stable-file copy failures still propagate, and `copy_report_snapshot` still tolerates only disappearing `.tmp` files. The completed-report acceptance check in detached readiness is unchanged.

Each snapshot lifecycle now writes `<label>-snapshot-terminal.json` with the policy, whether the source report was ever observed, whether any snapshot was retained, and whether the terminal source existed. This makes the startup exception explicit evidence instead of swallowing a filesystem error.

## Static and fixture verification

The helper was AST-parsed and all candidate-3 JSON templates were parsed. A temporary filesystem fixture exercised the real snapshot methods with authenticated fake runner argv: the optional startup policy accepted a report directory removed after authentication and wrote terminal-absence evidence, while the default required policy raised `FileNotFoundError` for the same transition. No product source, build, helper main, simulator, emulator, or device command was used.

The scoped last-reviewed-to-round-3 diff is `task8-candidate3-lifecycle-fix-round3.diff`. The complete candidate-3 preparation diff is regenerated at `task8-candidate3-harness-preparation.diff`.
