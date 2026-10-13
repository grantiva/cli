# MCP-078 cross-platform killed-app triage

**Conclusion: the current matrix expectation is overgeneralized. Preserve both platform failures against the binding matrix until Task 6 corrects it; the observed mixed results do not, by themselves, establish a product defect.**

## Binding requirement and where the matrix diverged

R05 acceptance criteria 2–3 require:

1. the same `isError` transport for every session tool **when it hits an error**, including other driver errors;
2. lazy attach to continue working; and
3. a missing label to return `Element not found: ...` as `isError`.

The brief does not say that killing the application must make every session tool fail. Its problem statement and repro concern thrown driver errors escaping `ToolRegistry.call` as JSON-RPC `-32603` errors. Criterion 2 broadens the transport guarantee to all session tools and other driver errors; it does not create an app-process liveness precondition for every operation.

The round-3 matrix row MCP-078 adds a materially stronger condition: “every session tool against a session whose app was killed ... isError.” Candidate `docs/mcp.md:20-24` defines the general failure-transport contract. Separately, `docs/mcp.md:61-63` explicitly says `grantiva_screenshot` uses `simctl` or `adb` when the session records its device and can succeed while WDA lacks a session; the tool table at line 111 describes it as a device screenshot. The distinction is between successful calls and failure transport.

## Candidate implementation

Candidate source is the `release-main` checkout at CLI commit `8f2cff676b3c12e951478920fa20e600cdca4e29`.

- `Sources/GrantivaMCP/ToolRegistry.swift:81-118` states the all-tools failure contract and catches errors thrown by every session tool, converting them through `sessionToolError`; it does not require a tool to throw after the app exits.
- `Sources/GrantivaMCP/ToolRegistry.swift:263-286` dispatches the seven tools to their individual handlers without a common app-process-alive guard.
- `Sources/GrantivaMCP/Tools/UITools.swift:105-137` deliberately captures a full-device screenshot through the platform (`simctl`/`adb`) whenever the session has a device ID. This operation does not depend on the application process.
- `Sources/GrantivaMCP/Tools/UITools.swift:140-240` lets tap, swipe, type, hierarchy, and audit report whatever result or driver error their driver operation produces. A hierarchy or audit of the current system screen can therefore succeed if the driver remains valid after the tested app exits.

This matches the public contract: successful device/driver operations return success; actual failures become `isError` results.

## Raw cross-platform observations

### iOS attempt 16c

`cov3-ios/findings/evidence/cov3-ios-attempt16c/requests.json` records the seven calls after `simctl terminate`. In `mcp/stdout.raw`, response IDs 16–22 show:

- tap, swipe, type, tree, check, and script: `result.isError: true`, with text that `com.kylebrowning.Landmarks is not running` and gives relaunch/restart guidance;
- screenshot: a successful image result (`isError` absent/false);
- no response is a JSON-RPC error object.

The screenshot success is the exact documented exception, so it is positive contract evidence rather than a product failure.

### Android killed-app capture

`cov3-android/findings/evidence/cov3-android/MCP-killed-app-errors/` records successful `am force-stop`, a subsequent failing `pidof` check (the app was absent), exact requests, and raw responses:

- tap, type, and script returned tool-level `isError` results;
- screenshot, swipe, tree, and accessibility check succeeded against the system UI exposed after force-stop;
- no response used a JSON-RPC error, and the MCP server remained usable.

Those successful operations do not violate R05 criteria 2–3 because no error escaped as a protocol error. Screenshot follows the explicit device-level exception at `docs/mcp.md:61-63`. Swipe/tree/check demonstrate that the Android driver still served the current screen; the general error contract at `docs/mcp.md:20-24` and tool descriptions at lines 113-116 do not promise that these calls first verify the configured application process.

The Android behavior could motivate a separate product-policy proposal if Grantiva wants all app-oriented UI tools to refuse system UI after the configured app exits. Current evidence does not support filing that as a violation of the accepted R05 contract: there is no documented universal liveness guard, and adding one would change currently valid device/session semantics.

## Task 6 correction

Keep the existing MCP-078 rows marked fail until Task 6 changes the binding matrix. The minimal correction is to test the actual R05 contract:

- after app termination, each tool that encounters a driver/app error returns a tool result with `isError: true`, never a JSON-RPC error;
- `grantiva_screenshot` may succeed through `simctl`/`adb` as documented;
- any other tool that still validly operates on the current device screen may succeed; do not require an invented error;
- separately retain the missing-label assertion: `grantiva_tap` on a missing label returns `Element not found: ...` as `isError`;
- verify the same MCP server remains alive/usable after the calls.

This correction narrows only the added killed-app assertion. It does not waive the brief’s all-tools error-shape guarantee when a tool actually fails.
