# B3-L16 candidate5 clause assessment

Verdict: **PASS**.

Expected: Three missing: exit non-zero with one error naming all three (e.g. `No captures found for "Missing1", "Missing2", "Missing3" in .grantiva/captures. Run: grantiva diff capture`). • `Home Missing1`: exit non-zero naming Missing1, and `.grantiva/baselines/` unchanged (no `Home.png` created or replaced). • One missing screen keeps K49's sentence. • `grantiva_vrt_approve` returns the same text as an `isError` result (brief L16; README diff approve paragraph)

The retained current-candidate outputs were inspected against the clause, including expected nonzero validation/error exits where applicable.

- `B3-L16-run-1/baseline-list.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `baseline-list.stdout`, `baseline-list.stderr` retained.
- `B3-L16-run-1/mcp.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `mcp.stdout`, `mcp.stderr` retained.
- `B3-L16-run-1/mixed.command.json`: exit 1, timedOut=false, cleanupFailed=false; raw `mixed.stdout`, `mixed.stderr` retained.
- `B3-L16-run-1/one.command.json`: exit 1, timedOut=false, cleanupFailed=false; raw `one.stdout`, `one.stderr` retained.
- `B3-L16-run-1/three.command.json`: exit 1, timedOut=false, cleanupFailed=false; raw `three.stdout`, `three.stderr` retained.
