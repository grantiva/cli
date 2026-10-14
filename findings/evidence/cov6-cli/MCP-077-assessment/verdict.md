# MCP-077 candidate5 clause assessment

Verdict: **FAIL**.

Expected: Each returns `result` with `isError: true`; never a JSON-RPC `error`; the server answers the next request. Without a session the session tools (`grantiva_type`, `grantiva_swipe`, `grantiva_script`) return the no-session text first; the missing-argument naming (`text`, `direction`, `steps`) is checked by the live-session rows IOS-1xx/AND-xxx; `name` and the unknown tool are named here (docs/mcp.md:21-22; 2.0.1 IOS-115) (corrected round 2)

Fresh candidate5 docs/public behavior or exact current-source inspection evidence satisfies the named clause; source-only evidence is used only for a source-only key. Evidence: .
