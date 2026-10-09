# Restrict the MCP server to its own project's runner session

Severity: wrong-result
Platforms: cli, ios, android
Found by: CLI-F21 (matrix rows CLI-099, CLI-100)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
`grantiva mcp --project-dir <dir>` drives only that project's session (its `.grantiva/session.json` or a keep-alive session
for the same project, bundle and platform), or refuses. Source: help: mcp; docs/android.md §Runner sessions and the MCP server.

## Actual
With no session in the project, the server attached to another project's `run --keep-alive` on qa-cli-1 and returned that
app's tree from `grantiva_a11y_tree`, while `grantiva_context` for the same server said:
```
[Config]
  platform: ios
  scheme: Other
  simulator: iPhone 16e
  bundle_id: com.example.other
...
[Runner Session]
  No active session.
```
An Android project in the same situation tried adb against the iOS UDID and exited:
```
Error: adb: device 'D3E7E498-2E80-469C-A465-4757C8995ACC' not found exited with code 1
```

## Repro
1. In project A (any iOS project with a `grantiva.yml`, or the Settings app): start a keep-alive run on a simulator:
   ```
   grantiva run --keep-alive --no-build --simulator <udid> --bundle-id com.apple.Preferences &
   ```
2. In an unrelated empty dir B, write a `grantiva.yml` with `scheme: Other`, `simulator: iPhone 16e`,
   `bundle_id: com.example.other`, and no `.grantiva/session.json`.
3. Call a tool through the MCP server for B:
   ```
   python3 -I fixtures/mcp/client.py "$(which grantiva)" B - calls.jsonl 30 out.jsonl
   ```
   with `calls.jsonl` holding a `grantiva_a11y_tree` call. The result is project A's tree.

## Evidence
- findings/evidence/cli/mcp/keepalive-fallback-unrel-ios-context.jsonl, keepalive-fallback-unrel-ios-tree.jsonl
- findings/evidence/cli/mcp/keepalive-fallback-unrel-android-context.jsonl, keepalive-fallback-unrel-android-tree.jsonl
- findings/evidence/cli/mcp/keepalive-run-tail.txt

## Suspected cause
Sources/GrantivaMCP/MCPServer.swift:154-159: `loadActiveSession` falls back to `KeepAliveSessionStore().locate()`, the newest
live keep-alive session machine-wide, and checks no project directory, bundle ID, configured simulator, or platform.

## Acceptance criteria
- Re-running the repro: the server for B does not touch A's simulator (it refuses or starts with no session; see C11).
- A keep-alive session is used only when it was started from the same project directory and platform; the session store
  must record those fields if it does not.
- GrantivaMCPTests/MCPServerTests: `loadActiveSession` with a fake store holding a session for another project directory
  (and one for another platform) asserts it is not returned.
- docs/android.md §Runner sessions and the MCP server states which sessions the server attaches to.
