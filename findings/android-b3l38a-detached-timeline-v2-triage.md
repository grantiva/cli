# B3-L38-a detached timeline v2 static triage

Disposition: the v2 cadence evidence is usable, but its missing ready MCP outputs are a harness evidence gap rather than a product result.

- `run/cadence.json` records 23 `starting` samples and 300 `ready` samples at no more than 110 ms spacing. The sampler runs on its own thread, so synchronous probes did not pause the state timeline.
- `run/initialize.json` contains a valid initialize response using protocol `2025-11-25`. The client never sends the required `notifications/initialized` notification afterward. Other retained campaign MCP clients do send it.
- The line-oriented JSON response reader is compatible with the server transport, as shown by the initialize and both starting-probe responses. However, it does not preserve raw stdout or reader exceptions.
- Both `collect()` results after initialization are ignored. Consequently, the wrapper exits zero even when `ready-resource.json` and `ready-tool.json` are absent after their 30-second response window. Empty `mcp.err` cannot establish whether the server emitted unreadable stdout, remained blocked, or withheld requests because the client lifecycle was incomplete.

The v2 result therefore supports detached absent-to-starting-to-ready cadence and valid starting-state responses. It does not prove ready-state MCP resource/tool responses in the same session.

Immutable v3 complement:

- `findings/harnesses/b3l38a-detached-timeline-client-v3.py`
- `findings/harnesses/run-android-b3l38a-detached-timeline-v3.sh`

V3 sends `notifications/initialized`, retains raw stdout/stderr and every request, captures reader exceptions, starts an immediate ready-state CLI hierarchy probe, and fails when any initialize/starting/ready response ID is absent.
