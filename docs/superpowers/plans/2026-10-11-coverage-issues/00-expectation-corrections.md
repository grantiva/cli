# Round 1 expectation corrections

Rows and briefs whose expectation, not the product, was wrong. None of these changes product code. Matrix rows carry `(corrected round 2)` in the expected column.

| row / brief | what the slice found | correction |
|---|---|---|
| CLI-019 | `doctor --json` exits 1 with the check array on stdout and no `Error:` line | matrix: doctor half rewritten; README:380's jq pipeline needs the array on stdout |
| CLI-028 | no config + empty `.maestro/` → "No flow files found", never naming grantiva.yml | matrix: that message is right (README:158); the run-vs-capture wording inconsistency is K52 |
| MCP-077 | without a session, `type`/`swipe`/`script` return the no-session text before argument validation | matrix: argument naming is checked by the live-session rows |
| AND-OBS-04 | monkey output attributed to `runner start --detach` | closed as a misattribution: the lines were the tail of the preceding `build install` (K32 owns the real defect) |
| IOS-102 | `{label: "heart"}` matches the Favorites tab by identifier | matrix: fallback to name/identifier is the brief I05 contract (K78); the result text must say which matched |
| MCP-034, IOS-111 | `grantiva_run` prints no `Product:` line | matrix: docs/mcp.md:62 promises none; K94 adds the summary line for consistency |
| brief C16 (B-C16.1, B-C16.3) | webhook event names are not validated locally; no `events` subcommand | brief corrected: server-side validation is the design; tests assert it |
| brief I04 (B-I04.3) | the CLI passes no alert policy | brief corrected: #183 removed the opt-out flag; the runner accepts system alerts by default |
| B-A02.2, B-R02.1, K09 | centre-start swipes open the row only 7 of 10; the far-side start (documented rule) opens it 10 of 10 | matrix and brief criteria rewritten to the documented swipe rule; K09 closed as an expectation correction (round 2 ruling) |
| N-03 (K07) | Android bare scrolls are deterministic but land on Landmark 28–29, not 30 (target tuned on iOS) | matrix corrected; Android `10-seed-many` asserts `Landmark 28` (landmarks-demo PR) |
| AND-OBS-04 note | — | see K32 |
