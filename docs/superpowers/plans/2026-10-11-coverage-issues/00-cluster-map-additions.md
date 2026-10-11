# Cluster map additions: iOS fix round 1 (cov/ios 7862a82)

This file adds to cluster-map.md and does not replace it. It places the 21 iOS fail rows that the iOS slice's fix round
added or reclassified. CLI paths are relative to `.worktrees/regression/Sources/`. Runner paths are in the runner's
`.worktrees/release-round1` checkout (ae48e34).

## Absorbed into existing clusters

| Row | Cluster | Note for the brief |
|---|---|---|
| IOS-207 (ios) | C01 step-line-omits-selector-details | `tapOn: text="(Lake .*\|.* Lake)"` without `index: 1`, so the log reads as a tap on the first match. This confirms the index half of C01 on iOS (pkg/flow/selector.go:358-378 has no `index`). |
| IOS-207@27.0 (ios) | C01 | same on 27.0 |
| IOS-239 (ios) | C76 unexplained-warning-marker | optional `tapOn: id="MapsTrayHeaderSearchField"` prints `⚠ tapOn: … (7.6-8.1s)` with no reason. C76 likely covers optional steps that did not find their element. |
| IOS-239@27.0 (ios) | C76 | same on 27.0 |
| IOS-OBS-05 (ios) | C18 deleted-report-paths-printed | confirms the iOS twin: `Reports:` and the JSON/JUnit/Allure paths printed for a temp dir that is deleted on exit |
| IOS-OBS-03 (ios) | C46 no-session-message-shape | MCP isError texts use three prefixes: `Error: 'name' is required.`, `Error: Invalid argument: …` (also for a missing session), and `Unknown tool: …` with no prefix. This widens C46 to one prefix rule for every MCP isError text. Sources: ToolRegistry.swift:172 (unknown tool), :193-195 (`errorResult`); MCPServer.swift:188 (invalidArgument for the missing session). |
| MCP-017 (ios) | C99 hierarchy-json-raw-envelope | `grantiva_a11y_tree` frame values and flags are strings (`'height': '44'`). The string-typed half of C99 applies to the MCP tree as well as `hierarchy --format json`; the tree conversion copies XML attribute strings. |
| IOS-OBS-06 (ios) | C78 tap-label-matches-symbol-identifier | MCP `{tap: "Name"}` misses the Edit Landmark text field that the flow's `tapOn: "Name"` focuses. Together with IOS-102, the MCP label lookup diverges from the runner both ways. Widen the slug to mcp-label-lookup-diverges-from-runner. Cause: the WDAClient.swift:88-105 predicate. |

## New clusters

**C100 mcp-resource-read-no-session-internal-error** · mcp · contract
- Rows: MCP-079, IOS-OBS-02 (ios)
- Expected: `resources/read grantiva://hierarchy` with no usable session answers in a form that states the condition, not an internal-error code for an expected state.
- Actual: JSON-RPC `-32603 Internal error: Invalid argument: No active runner session …`.
- Cause: MCPServer.swift:117-119. The `ReadResource` handler lets `tools.readResource` throw, and the error reaches the SDK as an internal error. This is the resource-handler sibling of C53 (ToolRegistry). The fix is either an explicit, documented JSON-RPC error code or empty contents with a message.

**C101 mcp-error-response-to-notification** · mcp · contract
- Rows: IOS-100 (ios)
- Expected: a malformed notification gets no response, or a parse error with `id: null` (JSON-RPC 2.0).
- Actual: `notifications/initialized` sent without `"jsonrpc"` drew a `-32700 Parse error` response with an invented UUID `id`.
- Cause: not located in the CLI. The stdio transport/decoder of the MCP SDK assigns an id when decoding fails; MCPServer.swift only sets up the server.

**C102 type-without-focus-reports-success** · mcp · wrong-result
- Rows: MCP-025 (ios)
- Expected: `{type: "x"}` with no focused field fails, naming the missing focus.
- Actual: `Step 5: typed "x"` (success); `grantiva_type` does the same (N-13).
- Cause: ScriptTools.swift:110 logs success unconditionally. The type call (UITools / WDAClient keys request) does not check for a focused element.

**C103 json-key-casing-mixed** · cli · contract
- Rows: IOS-OBS-01 (ios)
- Expected: one key-casing convention across `--json` outputs and the ready file.
- Actual: snake_case in `simulator ensure`, `diff capture/compare/approve`, MCP vrt and `runner start` (`device_type`, `screen_name`, `bundle_id`); camelCase in `simulator sessions`, `teardown`, `build install`, `run`, `record` and the ready file (`acquiredAt`, `leaseReleased`, `bundleId`, `allPassed`).
- Cause: no shared encoder strategy. Per-command `CodingKeys` and dictionary literals (e.g. DriverCommand.swift:116, :345, :419) decide the casing. Related to C16 (runner start keys). Fix one convention and document it; the change is breaking for consumers.

**C104 project-directory-private-stripped** · cli · wrong-result
- Rows: IOS-OBS-04 (ios)
- Expected: owner.json `projectDirectory` is absolute with symlinks resolved (docs/dump-hierarchy.md:21), i.e. `/private/tmp/...`.
- Actual: `/tmp/...` for a run started in `/private/tmp/...`; the MCP no-session texts use the same `/tmp` spelling.
- Cause: KeepAliveSessionStore.swift:65 uses `URL.resolvingSymlinksInPath()`. Foundation strips the `/private` prefix there, which reverses the `/tmp` → `/private/tmp` symlink. Use `realpath(3)` instead. The same helper likely produces the `/tmp` spelling in C105.

**C105 runflow-step-prints-rewritten-path** · cli · ux
- Rows: IOS-225, IOS-225@27.0 (ios)
- Expected: the `runFlow` step line shows the sub-flow path as written in the flow.
- Actual: an absolute `/tmp/…/.maestro/coverage/14-runflow-sub.yaml` (a `/tmp` spelling of the `/private/tmp` project).
- Cause: FlowReferenceResolver.swift:96-97 rewrites `runFlow` paths to absolute ones (needed for staging). The runner prints the rewritten `File` (pkg/flow/step.go:1125-1127). The `/tmp` spelling comes from the path normalisation (see C104).

**C106 reclaim-leaves-killed-run-temp-dirs** · cli · wrong-result
- Rows: IOS-016 (ios)
- Expected: `simulator teardown --force` reclaim after a `kill -9`'d run removes everything that run left.
- Actual: processes, records and the device home are handled, but the killed run's `/var/folders/…/grantiva-report-…` and staged-flow `/var/folders/…/grantiva-…` dirs survive.
- Cause: the temp dirs are removed only in the run's own exit path (RunnerSession.swift:76-93); the reclaim (teardown) has no record of them (not located). Related to C68/C69 (teardown accounting).

**C107 lease-locks-accumulate** · cli · ux
- Rows: IOS-057 (ios)
- Expected: SIGINT cleanup leaves no per-device state for devices that no longer exist.
- Actual: `<runner home>/locks/` keeps one `.lock` per UDID ever used, including deleted simulators and `FAKE-…` UDIDs.
- Cause: SimulatorLease.swift:49 creates lock files under `RunnerManager.baseDir + "/locks"` and never prunes them (no cleanup on release, delete or teardown).

**C108 diff-failure-omits-threshold** · cli · ux
- Rows: IOS-095 (ios)
- Expected: a failing diff says which threshold was exceeded.
- Actual: `Failed: pixel=0.03% perceptual=63.6` with no threshold named.
- Cause: DiffCommand.swift:587 and CICommand.swift:136 (same format string in both).

**C109 extendedwait-timeout-dropped-in-staging** · cli · wrong-result
- Rows: IOS-142 (ios)
- Expected: a screens step `extendedWaitUntil: {visible: X, timeout: 5000}` keeps its timeout.
- Actual: staged as a plain `assertVisible: text="X"`, so the 5000 ms timeout is silently dropped.
- Cause: MaestroFlowParser.swift:360-366 maps `extendedWaitUntil` visible/notVisible to `assertVisible`/`assertNotVisible` and ignores `timeout`.

**C110 runner-log-driver-empty** · runner · ux
- Rows: N-10 (ios)
- Expected: the runner log's `Driver:` line names the driver in use (`wda`).
- Actual: `Driver: ` is empty; report.json says `"driver": "wda"`.
- Cause: pkg/cli/test.go:911 logs `cfg.Driver` before auto-selection fills it (config read at test.go:809 from the `driver` flag, which is empty when defaulted).

## Status changes (not fails)

- B-I06.2: pass → blocked. The `/wda/keys` request is not observable because MCP talks to the agent directly and nothing logs it. Its side observation is placed above as IOS-OBS-06 (C78).
- N-08: pass → blocked. Whether grantiva reads `~/.maestro-runner` cannot be shown without root (fs_usage/opensnoop). A run with that directory stripped from PATH passes, and nothing under it changed.

## Recount

Fail rows: 41 cli + 54 android + 84 ios = 179. The 84 iOS rows are the earlier 63 plus 21 from the fix round; there are still no iOS triage rows. Placed: 179. The 21 new rows break down as 8 absorbed and 13 in new clusters.
Clusters: 110 (C01-C99 in cluster-map.md, C100-C110 here). Expectation corrections are unchanged at 6.
