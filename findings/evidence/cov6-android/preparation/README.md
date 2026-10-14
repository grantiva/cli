# Candidate5 Android coverage readiness

Status: static preparation only. No device, build, test, QA binary, runner, SDK-manager, or network command has been executed from this worktree.

The frozen identity is candidate5 manifest SHA-256 `191e59afdca010e488f1825d5064fc05facde89f065e71bac9e1ecee91c3d30c`, merged CLI `dd5d3336296a41014a45070cc5a8c4295a0873ec`, QA binary `b0e9eb55…`, runner `.16` from `d98b088…`, and unchanged demo/APK. The controller key inventory contains exactly 522 Android obligations.

`capture-one.rb` preserves the accepted cov5 collector semantics and changes only manifest path/hash, session, and the pending runner-home binding. It must not execute until root replaces the pending home and records a bounded diff. The stable manual-emulator helper is likewise preserved with deliberately non-runnable pending AVD/port bindings until root allocates the extra device.

The first canonical entries and literal clauses are in `first-canonical-batch.{json,md}`. Their physical execution is split by prerequisites: AND-001 requires absent primary creation, while AND-106–108 require that created primary, installed frozen APK, and stock scratch configuration. Root controls this scheduling and all later quiet/build windows. Known carried blocks remain AND-002 under the no-SDK-download constraint, AND-012 global teardown, AND-088 credentials, and N-08 root-only behavior unless the controller changes those constraints.

## Controller allocation binding

The controller provision record now binds the Android actor to `/private/tmp/grantiva-candidate5-coverage-qjr26z3g/android-runner-home`, session `candidate5-android`, absent primary `cov6-android`, and proposed primary serial/port `emulator-5584`/`5584`. The primary PID remains unset until literal AND-001 creates and boots an authenticated generation. `cov6-android-2` is name-reserved only; its port, serial, and PID remain unset until a later controller allocation.

`first-window-106-019.json` contains all 25 requested canonical keys and their frozen clauses. Physical execution starts with AND-001 to satisfy the absent-primary prerequisite, then returns to AND-106 through AND-108 and the remaining row plan; ledger publication retains canonical order. Candidate5 smoke is an exact eligible join for AND-107 only. AND-106 still needs full 12/12 stock evidence and AND-108 still needs the five-screen visual capture. No live command has run from this worktree.
