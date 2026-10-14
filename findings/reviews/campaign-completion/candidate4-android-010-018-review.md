# Candidate4 Android 010–018 evidence review

Status: CHANGES REQUIRED, one narrow evidence gap; no confirmed product failure.

Reviewed matrix clauses, verdicts, actual command argv/status/stdout/stderr, ledger transitions, manual-origin fixture provenance and survival checks from `.worktrees/cov5-android/findings/evidence/cov5-android/AND-010` through `AND-018`. Candidate manifest is `714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783`.

- AND010: exact owned target kill and started-ledger pruning are supported. `before-forwards.stdout` and `after-forwards.stdout` are both empty; no active UIAutomator2 precondition is evidenced. The stops-server/removes-forward clauses need a narrow fresh supplement. Keep existing evidence immutable; do not count the row as independently accepted yet.
- AND011: manual PID68606 refusal, survival, and targeted force cleanup supported. Initial fixed-port launch refusal is preserved separately.
- AND012: explicit blocked result is correct; prohibited global command was not executed.
- AND013: dead PID999999 fixture pruned while primary56881 retained; actual manual replacement refused and survived. Adjacent stable launch is distinct from retained initial port refusal.
- AND014–016: created stopped deletion, manual AVD refusal/forced deletion, and running AVD forced-delete refusal are supported by commands and intermediate inventory/survival evidence.
- AND017: literal five-second timeout configuration returned clear expected error after 5.407 seconds; capture timeout did not fire. Exact resulting process was subsequently removed.
- AND018: actual frozen-app browse flow passed on externally started PID71427, which survived; before/after started ledger and sessions contain only primary56881.

No collector timeout or cleanup failure in these command records. Approved seven PASS rows and one BLOCKED row, with AND010 pending its missing clauses. No repeat of already-supported rows requested.
