# Task 8 candidate 2 joint-forward helper preparation

## Scope and result

Created `task-8-candidate2-harness/forward_joint_live.py` from the reviewed `forward_joint_live.py` without modifying the original. This is helper preparation only; no device, product, build, or live test command was run.

The helper now takes `--candidate`, `--ownership`, `--source-root`, `--binary`, `--bundle`, `--packaged-runner`, `--home`, `--project`, and `--output`. Before live work it calls the sibling approved `candidate_identity.validate` with the Android device and AVD from ownership. That binds the CLI repository HEAD, immutable binary/version, bundle manifest, runner qualification, packaged runner, installed runner/home/stamp, demo repository/artifacts, and controller-owned Android identity to the frozen manifests. It also records a clean CLI source checkout at the candidate merged SHA. Runtime commands use the candidate manifest's installed runner; there is no test-only runner or source substitution.

All four reviewed cases remain: foreground interrupt, foreground normal stop, absent application failure, and healthy stock flow. The fixed `tcp:6790` unrelated control and dynamically allocated unrelated control must be the exact Android forward inventory before and after each case. Owned forwards, the project session, device-related global sessions, and exact installed-runner processes must be absent both immediately and after one second. PID-specific session-prefix and exact-process checks are repeated at both points for the foreground owned PID and for the full absent-app/healthy set containing the spawned PID plus every observed exact runner PID.

Final cleanup removes both unrelated controls and any tracked owned ports, then requires the Android forward inventory to equal its empty pre-test baseline. The original interrupt notice, exit statuses, ready identity, runner executable/device argv identity, hierarchy command, session-file delta checks, PID reaping checks, and evidence capture remain.

## Removed historical bindings

The copied helper contains none of the old repair ownership path, CLI SHA `a587...`, runner SHA `6b3...`, `.14` stamp/version, `fix4-84` session, source-built runner identity, or repair-build manifest binding. The runtime session is `fix4-8` and the remaining identity values come from the candidate and ownership manifests.

## Static verification

- Python compilation passed.
- `--help` passed and listed all nine required parameters.
- AST/text contract checks confirmed the manifest validator call, all four cases, immediate and delayed absence checks, exact pre-cleanup control inventory, exact post-cleanup baseline, and absence of every historical hardcoded binding.
- A focused AST contract confirmed `run_owned_case` forms `known_pids` from the spawned PID and all observed runner PIDs, passes that full set to `absence`, and that `absence` loops over every PID inside both timed checkpoints for prefixed global-session and exact process-state checks.
- An invocation omitting `--ownership` was rejected by argument parsing with exit 2 before any helper body or live command could run.

The full original-to-candidate2 helper diff is in `task8-candidate2-forward.diff`.
