# iOS attempt125b and 127 review

## B-I15.2 [ios]

**Approve pass.** Attempt125b first establishes a real detached session that answers hierarchy. It uniquely identifies and terminates the installed WebDriverAgent while preserving the runner process: `terminate.exit` and `runner-alive-stopped.exit` are 0. The next hierarchy exits 1 with `Cannot reach GrantivaAgent on port 8511. Is the grantiva run --keep-alive session still alive?`, which names the actual port and actionable remediation rather than no-session advice. The same runner is resumed and stopped normally; `stop.out` preserves PID 29779 and port 8511 and `stop.exit` is 0. Exact-head `HierarchyCommand.agentError` and its tests cover `.cannotConnectToHost` and `.timedOut` mappings. The harness's exit78 came only from a too-narrow wording proxy and does not invalidate the saved runtime or cleanup.

## B2-K18 [ios]

**Blocked at the authenticated CI boundary, with the local clauses supported.** Attempt127's supported quiet diff capture exits 0 with empty stderr. Joined with attempt43's ephemeral diff/run behavior, attempt68's ephemeral and preserved run outputs, and the exact output-filter tests, the local run/diff and preserved-path clauses are covered. Both supported CI invocations in attempt127 reach the real authentication gate and exit 1 with `Not authenticated. Run: grantiva auth login`; no runner starts, so those captures cannot establish authenticated CI report-path filtering. The JSON-mode auth error appearing on stderr rather than stdout is not a product defect under K18, and the wrapper's attempted JSON decode is only a harness assumption. Preserve K18 as blocked unless authenticated CI evidence becomes available.

## B2-K19 [ios]

**Fail against the literal row, with CI additionally blocked.** Current retained evidence covers the meaningful local surfaces: attempt68 provides run quiet/JSON success and failure plus verbose; attempt41 `diff capture --json` exits 0 with empty stderr; attempt127 quiet diff exits 0 with empty stderr. Exact-head tests cover suppressed relay and JSON failure wording. The authenticated CI quiet/JSON branches remain blocked at the same real auth gate.

Independently of that external boundary, the row has observed literal violations already assigned to Task6 expectation correction: attempt109b's plain/quiet/verbose stdout documents are not byte-identical because truthful dynamic durations differ, and the combined quiet+verbose case emits verbose diagnostics because verbose intentionally wins. Those results conflict with a literal byte-identity reading (and with treating every command containing `--quiet` as silent), while the row also says verbose must show runner output. Therefore the row should be recorded as **fail (matrix expectation conflict; CI branch also blocked)** rather than wholly blocked. This is not a new product defect and requires no rerun.
