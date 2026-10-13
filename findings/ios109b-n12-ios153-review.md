# iOS attempt 109b review: N-12 and IOS-153

## N-12 [iOS] — INVALID equivalence fixture; device-selection clause passes

The harness validly exercises the device-selection distinction. Its config names U2 (`cov3-ios-27`), while it starts a live detached runner on U1 (`cov3-ios-26`). `mcp/context.json` reports U1 as `source: runner session`, and the MCP VRT response names U1. Thus the MCP tool correctly ignores the configured simulator when a live session exists and produces five driver screenshots.

The three CLI `diff capture --no-build --json` calls each exit 0 and produce five captures on configured U2. The MCP images were preserved as baselines before those calls. This means the comparison crosses U1/iOS 26 and U2/iOS 27 rather than comparing the same runtime/device fixture. The final `diff compare --json` exits 1: all five screens fail the configured thresholds. The messages correctly identify the exceeded metric:

- Deep Links and Home exceed the pixel threshold;
- Detail and Favorites exceed both pixel and perceptual thresholds;
- Lakes exceeds the perceptual threshold.

The device-selection observation is valid: MCP ignored configured U2 and used live U1. The threshold comparison is not eligible to grade the equivalence clause because it compares different OS/device fixtures. Preserve the five failures as honest output but classify N-12 as partial/invalid, not a product or matrix failure. The minimal complement is one explicit CLI capture on U1 compared with the already preserved MCP/U1 baselines. No product brief is supported by 109b.

## IOS-153 — FAIL against the literal byte-identity clause

All three modes exit 0, emit valid five-screen JSON, and preserve five PNGs. Quiet stderr is empty. Plain stderr is also empty on this successful run. Verbose stderr is 8,068 bytes and contains timestamped debug labels, subprocess argv, and exit statuses, satisfying the verbosity behavior.

The stdout documents are not byte-identical:

- plain: 2,839 bytes, SHA-256 `9d520adc...`
- quiet: 2,840 bytes, SHA-256 `2877231f...`
- verbose: 2,840 bytes, SHA-256 `7e9513cb...`

The diffs are confined to truthful dynamic values: top-level duration, per-step durations, and capture timestamps. Stable schema, screen order, paths, sizes, simulator identity, actions, and statuses match. The literal matrix nevertheless says “stdout identical in all three modes (compare byte for byte),” so this row fails as written. This supports a Task 6 expectation correction for comparisons that normalize documented dynamic fields, not a product defect: independently executed captures cannot truthfully have identical timing and timestamps.

The successful run contains no warning or error, so it cannot by itself observe quiet-mode retention of those messages. The row's supplied success command does not create one; that behavior should remain joined to exact source tests or an already retained failure-mode output rather than inventing an extra live requirement.

## Evidence

- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt109b/`
- Matrix: `/Users/kyle/Developer/grantiva-cli/.worktrees/regression/docs/superpowers/plans/2026-10-13-round3-coverage-matrix.md:498,1178`
