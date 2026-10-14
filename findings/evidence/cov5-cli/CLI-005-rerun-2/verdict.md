# CLI-005 cov5 clause assessment

Verdict: **pass**.

Current evidence was freshly executed against candidate4 manifest SHA-256 `714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783`; each command has adjacent identity and exit capture. The following observations are from this directory’s current stdout/stderr and command records:
- All three help commands exit 0. `build install` contains `--app-file`, `--no-build`, and `--no-launch`; `build build` contains none of them.
- The build group help labels `build (default)`.
- In the exact fresh empty cwd, bare `build` and explicit `build build` both exit 1. `cmp-build-errors` exits 0, proving the same default-command behavior and error text.

The empty-directory behavior stops at project resolution; no build or device command occurs.
