# D2-42 corrected verdict

Result: **pass**

Fresh MCP compare returns a normal non-isError JSON payload with `passed: false`, both configured screens as `new_screen`, and the stray under `ignored`. Fresh MCP approve approves only A/B and lists the stray under `ignored`; the only-stray configured-screen diagnostic is joined from current-candidate N2-04.
