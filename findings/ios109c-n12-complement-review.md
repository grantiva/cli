# iOS attempt 109c N-12 complement review

## Verdict: N-12 [iOS] PASS

Attempt 109c supplies the same-device complement that attempt 109b lacked:

- The five baseline PNGs copied into 109c are byte-for-byte identical to attempt 109b's preserved MCP images; each corresponding SHA-256 matches.
- Those MCP images came from the live U1 session even though the 109b config named U2, proving the row's `simulator:`-ignored-with-live-session clause.
- The explicit CLI `diff capture --no-build --simulator U1 --json` exits 0, names U1/cov3-ios-26 in its JSON, and produces the same five named screens.
- `diff compare --json` exits 0 with `passed:true`. All five screens pass both configured thresholds. Detail and Home are pixel/perceptual identical; the other three remain below both thresholds.

The earlier 109b U1-versus-U2 failures remain preserved diagnostic output but are excluded as a cross-OS fixture mismatch. The 109b MCP capture plus 109c explicit-U1 CLI capture form the eligible row evidence.

Evidence:

- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt109b/mcp-images/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt109c/`
