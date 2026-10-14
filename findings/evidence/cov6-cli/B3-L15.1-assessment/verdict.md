# B3-L15.1 candidate5 clause assessment

Verdict: **PASS**.

Expected: `grantiva_sim_ensure {}` and `grantiva_emulator_ensure {}` read exactly `Error: Invalid argument: 'name' is required.`; the unknown tool reads exactly `Error: Unknown tool: grantiva_bogus_tool` (round 3 ruling L15), an `isError` result, not a JSON-RPC error; the session tools without a session give the no-session text first, with no `Invalid argument:` label. • Every `isError` text of every tool starts with `Error: ` exactly once. • ToolErrorContractTests asserts the full texts (source check) (brief L15; docs/mcp.md error paragraph)

The retained current-candidate outputs were inspected against the clause, including expected nonzero validation/error exits where applicable.

- `B3-L15.1-run-1/grantiva_bogus_tool.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `grantiva_bogus_tool.stdout`, `grantiva_bogus_tool.stderr` retained.
- `B3-L15.1-run-1/grantiva_emulator_ensure.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `grantiva_emulator_ensure.stdout`, `grantiva_emulator_ensure.stderr` retained.
- `B3-L15.1-run-1/grantiva_script.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `grantiva_script.stdout`, `grantiva_script.stderr` retained.
- `B3-L15.1-run-1/grantiva_sim_ensure.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `grantiva_sim_ensure.stdout`, `grantiva_sim_ensure.stderr` retained.
- `B3-L15.1-run-1/grantiva_swipe.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `grantiva_swipe.stdout`, `grantiva_swipe.stderr` retained.
- `B3-L15.1-run-1/grantiva_type.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `grantiva_type.stdout`, `grantiva_type.stderr` retained.
