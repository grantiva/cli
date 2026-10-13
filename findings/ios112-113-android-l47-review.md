# iOS 112/113 and Android B3-L47 review

## iOS attempt 112 — B-I05.2

**Approve pass.** `cov3-ios-attempt112/mcp/quoted-script.json` is a successful seven-step live script whose final action taps the literal quoted label `Mount "Denali"`; `mcp/after-tree.json` is the real Denali detail hierarchy. `mcp/stdout.raw` preserves the matching JSON-RPC response, and exact candidate/runner predicate and name-fallback tests cover escaping semantics. Harness exit 75 comes only from looking for the unrelated presentation phrase `7 steps`; it does not invalidate the successful tool response or final state.

## iOS attempts 113/113b — B2-K89

**Approve the iOS half.** Attempt 113 first captures five screens, then proves both required CLI cases in text and JSON: no baselines exits 1, reports five `new_screen` entries and `passed:false`; the mixed corpus exits 1, reports Home `passed` and four `new_screen` entries, and never emits a success headline. Selective Home approval exits 0 and establishes the mixed fixture. Attempt 113b's `mcp/compare.json` returns the same mixed five-screen verdict through `grantiva_vrt_compare`. This covers the row's no-baseline, mixed, CLI text/JSON, and MCP parity clauses; the established exact-head DiffCommand tests supply the named true/false unit assertions.

## Android B3-L47

**Approve pass.** `B3-L47-focused-lookup-load-rerun1/decoded.json` records five of five exact 03-edit runs at generated load 8.65 through 104.97. All exit 0 and pass inputText. Every client log contains the active-element lookup and actions call. Focused lookup durations are 469–743 ms and action durations 1.64–2.13 s, so lookup remains bounded to a few seconds and typing retains its normal request budget. `load/owned-pids.txt` and `load/posthoc-pid-absence.json` document the additive row-owned load and its cleanup. The empty `failures.txt` and decoded assertions agree with the raw run reports.
