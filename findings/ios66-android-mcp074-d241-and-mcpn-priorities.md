# iOS66, Android MCP-074/D2-41, and remaining MCP/N priorities

## iOS attempt66 / D2-06

D2-06 [ios] is supported. The config deliberately omits `bundle_id` and the flow header uses `appId: ${APP_ID}`. Exact `run --no-build --flow appvar.yaml` exits 1 with the required explanation that project detection runs only while building and the precise `Pass --bundle-id or set appId ... or bundle_id` hint. The matching built command succeeds, detects and installs `com.kylebrowning.Landmarks`, then passes both flow steps. This proves the required detection-order difference.

The three install-status probes are separate D2-07 preparation. Launch and no-launch JSON are valid (`launched` and `installed`). The skipped probe lacks a bundle ID and exits at input validation, so it is correctly excluded; attempt66b is needed for the exact `skipped` document. That harness omission does not affect D2-06.

## Android MCP-074 and D2-41 half-batch

- **MCP-074: pass.** The isolated project starts with two genuine Android captures. `{screens:["Home"]}` returns only Home and creates only its Android baseline; the later empty argument approves both Deep Links and Home. Both documents report `.grantiva/baselines/android`, and the final inventory contains exactly those two PNGs.
- **D2-41 [android]: partial.** The device-free capture, compare, and approve failures are MCP tool results with `isError:true`; each begins with one `Error:` and contains no doubled prefix. Capture names the missing Android config; compare/approve name missing Android captures. This closes the three error-text cases. The batch does not exercise a live-session screen with an unfocused `type` step and therefore cannot supply the required `Screen "<name>", step <n> (Type "<text>"): No focused text field...` result. The argument-list/no-shell clause also requires exact source evidence; it is not established merely by these outputs. Keep D2-41 ungraded until those joins are present.

## Remaining MCP/N gap-bundle priorities

These are concrete next inputs, not proposed passes. CLI-owned no-session rows MCP-003/004/007/008/011/012/015/016/019/020/023/024/027/028 and N2-02/04/10/19/20 should remain in the CLI slice; device workers should not duplicate them.

### Priority 1: one live interaction session per platform

- iOS: MCP-001, MCP-005, MCP-009, MCP-013, MCP-017, MCP-021, MCP-025.
- Android: MCP-002, MCP-006, MCP-010, MCP-014, MCP-018, MCP-022, MCP-026.

Park on the exact screen named by each row and preserve individual responses: screenshot inline+file; Gesture Lab label then hierarchy-derived point/dp tap; left+invalid swipe; focused append type; tree; a11y check on both list and Deep Links; valid ordered script plus invalid two-entry script. Existing nearby tool successes do not replace the exact state, coordinate derivation, invalid leg, or two-screen a11y clauses.

### Priority 2: finish D2-41 with an existing live session

Use a scratch one-screen config whose path contains a `type` step while no field is focused. Preserve config, request, full raw response, step index/label, and server continuity. Join exact-head ToolRegistry/VRT subprocess construction showing argument arrays rather than a shell. This is a small complement to the accepted error half.

### Priority 3: platform build/run argument-without-config rows

- iOS: MCP-029/031/034/036/039 and N3-04 only where exact omitted/configured scheme and device-naming variants remain absent.
- Android: MCP-030/032/035/037 and N3-04, preserving module/variant/device, APK product, no unintended boot for build, and explicit device-name/serial narration.

Do not batch these as exit-code-only checks: the rows require product paths, build fields, device naming, and the iOS test-action reason.

### Priority 4: remaining N runtime contracts

- Android N3-06: ten separate 3-second recordings, each ffprobe duration and JSON pre-trim duration retained.
- Android N3-10: paired verbose browse runs with and without `GRANTIVA_DRIVER_START_TIMEOUT=45`, preserving the complete runner argv.
- Per-platform N2-05/N2-07: build a document manifest first; capture every started/already-running/stopped/already-exited/multi-session and legacy-alias document named by the rows rather than joining a subset after execution.
- iOS N2-18: blocked-signal detached start plus verbose first-SIGINT stop and the separate nohup/SIGHUP observation.
- N3-09: only on row-owned disposable devices because teardown and stop-marker polling are mandatory. Do not repurpose protected owner devices.

### Priority 5: documentation/host-only N rows

N3-15 is a read-only doctor text+JSON capture only when the host actually has the default-name unowned simulator precondition. N3-16 should be closed through the canonical regenerated help corpus plus exact README/docs searches, with one assertion per named addition; do not infer it from file existence or reopen the withdrawn runner-lineage target.

