# Candidate 4 CLI ordinal 151–175 review

Verdict: **PARTIAL — ordinals 151–154 approved; ordinals 155–175 are not yet present and cannot be reviewed.**

At review time `cov5-cli-results.md` contains 154 direct rows total. The requested slice therefore currently consists only of:

| Ordinal | Key | Proposed result | Review |
|---:|---|---|---|
| 151 | CLI-161 | pass | approved |
| 152 | CLI-162 | pass | approved |
| 153 | CLI-163 | pass | approved |
| 154 | CLI-164 | pass | approved |

Each of these four directories has a candidate-bound command record, raw stdout/stderr, and verdict. Every identity record matches candidate manifest SHA-256 `714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783` and all frozen files; every command exits zero without timeout or capture cleanup failure.

- CLI-161 retains the README path/stamp definition and a bounded on-disk runner-home listing that contains the matching `1.1.28-grantiva.15+android-drivers-2` installed layout.
- CLI-162 retains the README screen timeout/continue language and an executable negative grep proving the contradictory `fixed 300 s timeout` phrase absent.
- CLI-163 retains the threshold documentation stating both checks must pass, the 0–1 pixel fraction, mean CIE76 over differing pixels, and that both thresholds must be raised to loosen comparison.
- CLI-164 retains candidate docs/mcp.md and docs/android.md excerpts plus live candidate MCP help; these agree on server startup without a session/config, session-required tools and startup errors, platform resolution, and same-project/platform session discovery.

Material gap: **21 requested ordinals are absent.** There are no result rows or fresh evidence links at ordinals 155–175, so this review does not approve them and does not infer their identities from numeric CLI IDs. Re-review those ordinals after the CLI results file reaches at least 175 direct rows.
