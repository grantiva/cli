# Task 8 lifecycle notice harness fix

## Scope

Harness-only correction. No product source was edited and no live device command was run.

## Finding

The preserved startup-interrupt evidence shows that iOS and Android both exited 130. iOS emitted the exact `releasing simulator` notice, while Android emitted the exact `releasing emulator` notice. The helper used one iOS-specific notice constant for both platforms, so it rejected the successful Android interruption after its runner PID and session cleanup assertions had passed.

Raw evidence remains unchanged under `findings/evidence/round4-smoke/03-lifecycle/helper/`.

## Change

- Replaced the single notice constant with exact `ios` and `android` notice mappings.
- Applied the platform-specific expectation to startup-state and ready-state interruption checks.
- Required the matching notice to be the sole stderr line beginning with `[grantiva] received SIGINT`.
- Retained exit 130, timeout absence, project-session absence, runner-PID absence, and shared-session cleanup assertions.
- Updated both `findings/tools/round4-smoke/lifecycle_smoke.py` and its `.superpowers/sdd/2026-10-13-round4-fix-wave/task-8-harness/` mirror; they are byte-identical.

The pre-edit helper is preserved at `.superpowers/sdd/2026-10-13-round4-fix-wave/task8-lifecycle-notice-base/lifecycle_smoke.py`.

## Static verification

A device-free AST/source check passed for both helper copies. It proved:

- the mapping contains the exact iOS `simulator` and Android `emulator` notices;
- both startup and ready interruption sites require exactly one platform notice;
- both sites retain exit-code 130 checks;
- session-cleanup assertions remain present;
- durable and mirror helpers are byte-identical.

Both helpers also passed Python bytecode compilation.

## Cleanup state

Cleanup for the failed attempt is complete based on preserved and host-only evidence:

- recorded CLI PIDs 30588 and 30621 are absent;
- recorded runner PIDs 30616 and 30626 are absent;
- the project session and shared session paths for both runners are absent;
- `failure-cleanup/android-forwards.result.json` records exit 0, its stdout is empty, and `cleanup.json` records no cleanup actions were needed.

The owned smoke devices were not deleted or contacted by this fix. They remain available for the controller's rerun and later Task 8 cleanup. This correction does not claim a product regression or a completed lifecycle smoke phase; the controller must rerun the phase.
