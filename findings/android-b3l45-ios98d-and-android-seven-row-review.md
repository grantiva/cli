# Android B3-L45, iOS attempt98d, and Android seven-row review

Read-only review on 2026-10-13 against the binding round-3 matrix. Current candidate source is CLI `8f2cff67`; only retained round-3 runtime evidence is used.

## Android B3-L45

**B3-L45 [android]: pass.** `B3-L45-mcp-boot-text-rerun1` supplies all three literal branches. Explicit `{name:"cov3-android"}` and the configured empty-argument call each return `Emulator reused: cov3-android (emulator-5554), already running`. The row-created shutdown secondary returns `Emulator booted: cov3-android-mcpboot-r3 (emulator-5556)`. The assertion summary is all true, and teardown/delete remove the secondary exact name. The secondary name differs from the illustrative matrix name while retaining the required row-owned unique shutdown-device semantics.

Evidence: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B3-L45-mcp-boot-text-rerun1/`.

## iOS attempt98d

- **N-13 [ios]: pass.** The owner record proves the trigger is an exact detached `runner-start` session. In one MCP process all seven named session tools are invoked during its observed `starting` state and each returns a tool result with retryable starting text rather than a JSON-RPC error. After bounded CLI hierarchy polling establishes ready, the same server invokes all seven again; six succeed and type returns its ordinary no-focus tool error. Stop exits 0.
- **B2-K100.2 [ios]: pass.** Before the detached driver answers, both `grantiva://hierarchy` and `grantiva://screenshot` resource reads return JSON-RPC code `-32002` and the same starting/retry condition. This directly replaces the forbidden generic `-32603 Internal error` behavior.
- Attempt98d is a detached-start control and therefore does **not** satisfy B3-L52's required keep-alive input. The exact B3-L52 proof is attempt98e: in one slow `run --keep-alive`, starting CLI hierarchy, runner dump, and MCP tree return the retryable starting condition; `ready-hierarchy.*`, `ready-dump.*`, and the ready MCP tree then succeed in that same run. Joined with the cited docs/source, **B3-L52 [ios] is fully supported by attempt98e**, not attempt98d.

Evidence: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt98d/`.

## Android analysis-only joins

- **B-A06.1 [android]: pass.** `X-004/03.out` records SIGINT as group and flow `interrupted`; `B2-K10-K80-screens-timeout-interrupt-rerun1/timeout/ready.json` records timeout as `failed` with no running flow; `X-004/01.out` records a successful no-report run with no `reportDir` key.
- **B-A06.2 [android]: pass.** The same live interrupt result joins exact-head `RunnerExecution.swift:123-132`, whose termination cleanup writes interrupted flow state, and `SignalRelay.swift:254-268`, which marks termination before signalling tracked groups. This satisfies the named ordering semantic rather than inferring it only from a final file.
- **B-A10.1 [android]: partial.** `AND-063/01.err` names `Emulator emulator-5554`, gives both required teardown/ensure remedies, omits the generic child exit suffix, and rejects before a run owns the device. However, `01.out` reports three existing `failure*` files after the refusal and the directory has no before inventory or timestamp/hash audit proving that this invocation created none. The source ordering makes the intended early refusal plausible but cannot replace the explicit runtime no-failure-screenshot clause. Smallest missing input is a clean or before/after-hashed run-captures directory around the same refusal.
- **B-A11.1 and B-A11.2 [android]: already correctly pass.** `MCP-a11y-two-screens/mcp/check-deep-links.json` is the exact Deep Links runtime and reports no violations. `source-runtime-joins/B-A11/` pins exact-head production and semantic tests for the non-clickable/non-focusable widget stub inside the labelled clickable ancestor. No new runtime is needed.
- **B-C04.1 [android]: pass.** `output-contracts-exact-rerun2/B2-K20-ready/ready.json` names the exact retained report directory. After exit that directory still contains root and screens `report.json`, flow files, assets/captures, JUnit, logs, and Allure results. This is the configured-screens report layout required by the row; failure status does not weaken its persistence/path criterion.
- **B-I16.1 [android]: partial.** Current capture evidence preserves `.grantiva/captures/android/Deep Links.png`, and current changed comparisons preserve `diffs/Deep Links_diff.png`. I did not find a current JSON document whose path fields name that changed Deep Links diff; the retained passing compare has no diff-image path by design. Smallest missing input is one JSON compare with only Deep Links changed, retaining both exact files and the JSON `capturePath`/`diffImagePath` values. Source/file existence alone does not satisfy the explicit JSON-path clause.
