# Deprecated preparation wrapper

`run-row.sh` is preserved only as preparation provenance. **Do not execute it for cov5 evidence.** It binds the wrong home model, omits `MAESTRO_RUNNER_HOME`, permits raw-file replacement, and lacks the approved candidate identity and timeout capture.

The executable collector for cov5 must be a hash-verified copy of the approved cov4 CLI `capture-one.rb`, rebound only to candidate4, session `cov5-android`, and the controller-provisioned cov5 runner home. Until that exact copy exists and root records the initial reservation, Android execution remains blocked.
