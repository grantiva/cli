# Start the MCP server without a live runner session or config file

Severity: contract
Platforms: cli, ios, android
Found by: CLI-F18 (matrix rows CLI-099)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
`grantiva mcp` "Start[s] the MCP server for AI agent integration": it answers `initialize` and `tools/list`, and the tools
that need no session (`grantiva_sim_*`, `grantiva_emulator_*`, `grantiva_build`, `grantiva_context`, VRT tools) work, so an
agent can provision a device. Source: README §Commands (README.md:286); help: mcp.

## Actual
The process exits 1 before reading stdin; an MCP client shows only "server failed to start":
```
== mcp --project-dir <scratch>/mcp-ios --platform -
  Error: Invalid argument: No active runner session at .../mcp-ios/.grantiva/session.json. Start one with 'grantiva runner start' or `grantiva run --keep-alive`.
  exit=1
== mcp --project-dir <scratch>/mcp-empty --platform -
  Error: Invalid argument: No grantiva.yml or grantiva-android.yml found in project directory: .../mcp-empty
  exit=1
```

## Repro
```
mkdir -p /tmp/c11/ios && printf 'scheme: App\nsimulator: iPhone 17 Pro\n' > /tmp/c11/ios/grantiva.yml
fixtures/mcp/send.sh /tmp/c11/ios ios        # from the qa-cli worktree; GRANTIVA=<binary> to override
mkdir -p /tmp/c11/empty && fixtures/mcp/send.sh /tmp/c11/empty -
```
Neither prints an `initialize` response.

## Evidence
- findings/evidence/cli/mcp/startup.txt
- help/mcp-tools-probe.txt (qa-cli worktree root)

## Suspected cause
Sources/GrantivaMCP/MCPServer.swift:20-36: `resolveProjectDirectory`, `loadActiveSession` (:28) and
`device.attachDriver` (:35) all run before `server.start(transport:)` (:109), and any throw ends the process.

## Acceptance criteria
- Re-running the repro, both servers answer `initialize` and list all tools.
- Session-dependent tools (`grantiva_tap`, `grantiva_swipe`, `grantiva_type`, `grantiva_screenshot`, `grantiva_a11y_*`,
  `grantiva_script`) return `isError` with the "No active runner session ... Start one with ..." text; the driver attaches
  lazily on first use, and re-checks after a session starts.
- Without a config, config-dependent tools return `isError` naming the missing file; `grantiva_sim_*`/`grantiva_emulator_*` work.
- GrantivaMCPTests/MCPServerTests: start the server with no session over an in-memory transport and assert
  `tools/list` succeeds and `grantiva_tap` returns `isError`.
- Update help: mcp and docs/android.md §Runner sessions to say the session is needed only for device tools.
