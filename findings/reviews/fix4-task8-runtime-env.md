# Task 8 direct-runner runtime environment review

Scope: `task8-runtime-env-report.md`, `task8-runtime-env-review.diff`, the exact changed initialization lines in both mirrored Android helpers, frozen `findings/evidence/round4-smoke/candidate.json`, and retained no-device check evidence. No helper, device command, build, or smoke rerun was performed.

## Verdicts

- **Specification compliance: APPROVED.** The change corrects only the direct-runner runtime environment and preserves all reviewed acceptance behavior and bindings.
- **Code quality: APPROVED.** The installed-home derivation is fail-closed, candidate-bound, and consistent with production runner launch behavior.
- **Live acceptance: NOT ASSESSED.** The controller must rerun into new evidence; prior failed setup attempts remain non-acceptance evidence.

## Review

The original failure is correctly diagnosed: `GRANTIVA_RUNNER_HOME` identifies the fresh clone root used by CLI upgrade/cache management, while a direct `grantiva-runner` process needs `MAESTRO_RUNNER_HOME` at the installed version directory that owns `drivers/android`.

The helper now performs full frozen-candidate validation first, rereads the exact manifest path returned by that validator, and verifies its bytes still match the validated manifest SHA-256. It derives the installed home from the frozen installed-runner path and requires exact equality with `<clone root>/versions/<installStamp>`. It also requires the installed binary, packaged binary, and both frozen validated hashes to agree before using that directory, then requires `drivers/android` to exist. These checks prevent silently selecting an adjacent or stale version directory.

The child environment preserves `GRANTIVA_RUNNER_HOME` at the clone root, sets `MAESTRO_RUNNER_HOME` to the verified installed parent, keeps literal session `fix4-8`, removes the API key, and prepends the resolved explicit `--adb` parent to `PATH`. This matches the inspected production separation between CLI home and runner install directory and lets the direct runner resolve ADB without relying on the controller shell.

Provenance now records both effective homes and the ADB parent. The runner/CLI argv, project binding, evidence paths, flows, assertions, repetition counts, and acceptance emission are unchanged. The durable and scratch helper copies are reported byte-identical, and no original attempt evidence was rewritten.

The retained initialization-only check is appropriately limited: it supports candidate/layout/environment correctness but does not claim device or smoke success. No new scoped defect was found.
