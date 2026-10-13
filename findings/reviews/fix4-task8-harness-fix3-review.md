# Task 8 smoke-helper fix round 3 static review

Scope: `task-8-harness-fix3-review.diff`, the updated preparation report, and the current phase manifest/README. This review covers only the remaining phase-order finding and regressions introduced by this small fix. No device, build, helper, or previously reported static check was run.

## Verdicts

- **Specification compliance: APPROVED.** The sole remaining phase-order blocker is closed under the established Task 8 scope and prior controller rulings.
- **Code quality: APPROVED.** The minimal reorder is internally consistent and introduces no new scoped defect.
- **Live acceptance: NOT ASSESSED.** Final-candidate execution and evidence review remain required.

## Finding disposition

**Final force teardown after Android removal — ADDRESSED.** `manifest.example.json` now runs `07-final-force-teardown` while both owned targets are still live. The unchanged lifecycle constructor can therefore complete its mandatory iOS and Android ownership/live-identity validation before dispatching the isolated `force-teardown` phase. The command retains the full frozen bindings, literal `fix4-8`, `--allow-destroy-owned-ios`, passed-status assertion, and recreate-required marker assertion.

`08-final-cleanup` then explicitly expects the owned iOS UDID to be absent after force teardown and removes the still-live owned Android target plus residual owned sessions, locks, forwards, and PIDs while checking protected inventory. This ordering satisfies the Task 8 cleanup requirement without weakening lifecycle ownership checks or attempting to reuse the destroyed iOS device.

The diff changes only the final phase order and corresponding descriptions/paths. No new scoped breakage was found. Candidate-upgrade, docs/output, and cleanup helper bodies remain the previously accepted controller completion work; this approval covers the prepared Android, MCP, lifecycle, identity, and phase wiring statically, not their eventual live results.
