# D2-42 candidate5 joined clause assessment

Verdict: **PASS**.

Expected: Only configured screens compared/approved; strays under `ignored`; a screen without a baseline gives `"passed": false` and `status` `new_screen` as a normal (non-isError) result; only strays: the error names the configured screens with no capture (docs/mcp.md vrt rows; plan N2-04)

Fresh N2-04 and current MCP VRT rows prove configured filtering, ignored strays, new-screen normal results, and only-stray diagnostic.

No historical runtime verdict is transferred; all runtime references above are current candidate5 captures. Source joins use `/Users/kyle/Developer/grantiva-cli/.worktrees/regression/findings/reviews/campaign-completion/candidate5-source-evidence-joins.json`.
