# Candidate 4 iOS initial evidence review

Verdict: **APPROVED** — IOS-001 through IOS-009 support the proposed nine passes and all 35 stated clause checks.

I compared each row with the frozen matrix and inspected its verdict, command records, raw streams, intermediate inventories, and candidate identities. Every cited command is bound to candidate manifest SHA-256 `714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783`; no identity mismatch, recorder timeout, or surviving recorder process group appears in these directories.

- IOS-001 proves literal name-only absence, UUID-only stdout, human stderr, and creation as a booted iPhone 17 on the observed latest runtime, iOS 27.0.
- IOS-002 returns the same UUID with `Reused … — Booted`, retains that identity in the intermediate inventory, then deletes that exact owned device and proves absence.
- IOS-003 records the exact name/type/`latest` argv and binds the created UUID to iPhone 17, iOS 27.0, Booted. The device is retained as declared.
- IOS-004 binds the positive device to iOS 26.0 before cleanup. The 99.9 leg exits 1 with the unavailable-runtime error, and the post-attempt inventory proves the exact negative name was not created.
- IOS-005 records the literal `--no-boot` invocation, UUID-only stdout, `Created … — Shutdown` stderr, independent Shutdown inventory, and exact deletion.
- IOS-006 validates both JSON documents. The new result has `created: true`, the requested iPhone 17/iOS 26.0 identity, Booted state, and display geometry; the bare-name primary reuse has `created: false` and reports the primary's own iPhone 17/iOS 26.0 identity and geometry. Inventories corroborate both.
- IOS-007 exits 1 with the required inference guidance and before/after inventories prove `cov-thing` remains absent.
- IOS-008 retains two separately spawned candidate-bound calls with overlapping timestamps and exact identical argv. Both return the same UUID; one reports Created and the other waiting/Reused; the final inventory contains one matching booted device. The product's printed PID is not treated as independent process authority.
- IOS-009 reads the isolated cov5 ledger successfully and independently matches both owned UUID/name pairs to current booted inventory entries.

Material gaps: **none found**.
