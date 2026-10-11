# MCP `resources/read grantiva://hierarchy` with no usable session answers a JSON-RPC `-32603 Internal error` instead of stating the condition

Severity: contract
Component: mcp
Platforms: both (iOS ran the row; `ToolRegistry.readResource` and the `ReadResource` handler are platform-independent, and Android takes the same path with no emulator session)
Rows: MCP-079, IOS-OBS-02 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
"No runner session" is an expected, documented state of the MCP server: docs/mcp.md:16-22 says session tools
return an `isError` result naming `grantiva runner start` until a session exists, and "report every failure as an
`isError` result, never as a JSON-RPC error". Resources have no `isError` field, but the same state should reach the
client in a form that names it, not as the code JSON-RPC 2.0 reserves for a server fault (`-32603 Internal error`).
Either:
- a deliberate, documented error code (the MCP spec uses `-32002` for "resource not found"; an
  application-defined code in the `-32000..-32099` server-error range is also acceptable) with the no-session text as
  `message`, or
- a successful `contents` entry whose text states that no session is active (and how to start one).

The resources themselves (`grantiva://hierarchy`, `grantiva://screenshot`) are not documented in docs/mcp.md or the
README at all (only `grantiva mcp --help`), so whichever form is chosen also needs a line in docs/mcp.md.

This is the resource-handler sibling of C53 (non-session tools answering `-32603`).

## Actual
MCP-079 (server started for project B while the only keep-alive session belonged to another directory),
`findings/evidence/cov-ios/MCP-079/other-dir/transcript.txt:20-21` (path shortened):
```
>> {"method": "resources/read", "params": {"uri": "grantiva://hierarchy"}, "id": 10, "jsonrpc": "2.0"}
<< [0.0s] {"error": {"code": -32603, "data": {"detail": "Invalid argument: No active runner session at
   /tmp/…/cov-ios/p027/.grantiva/session.json. Start one with 'grantiva runner start' or `grantiva run --keep-alive`
   in /tmp/…/cov-ios/p027. 1 keep-alive session(s) started from another project directory or for another platform
   were ignored."}, "message": "Internal error: Invalid argument: No active runner session at …"}, …}
```
In the same server run every session tool returned the expected `isError` no-session result; only the resource read
became a JSON-RPC error. The message is also double-prefixed (`Internal error: Invalid argument: …`), and "Invalid
argument" is wrong because the URI was valid (see C46).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k100
unset GRANTIVA_API_KEY
rm -rf /tmp/k100 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k100 && cd /tmp/k100/ios   # main 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k100 iPhone 17" --runtime 26.0)
grantiva runner stop 2>/dev/null   # make sure this directory has no session
printf '%s\n' \
  '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"qa","version":"1"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}}}' \
  '{"jsonrpc":"2.0","id":2,"method":"resources/read","params":{"uri":"grantiva://hierarchy"}}' \
  '{"jsonrpc":"2.0","id":3,"method":"resources/read","params":{"uri":"grantiva://screenshot"}}' \
  | (cat; sleep 3) | grantiva mcp --platform ios --project-dir "$PWD"
grantiva simulator delete --name "fix-k100 iPhone 17"
```
Today: id 1 is a `result` with `isError: true` and the no-session text; ids 2 and 3 are `error` objects with
`code: -32603` and `message: "Internal error: Invalid argument: No active runner session at …"`. A second keep-alive
session started from another directory (as in MCP-079) only adds the "were ignored" suffix.

## Evidence
- findings/evidence/cov-ios/MCP-079/other-dir/transcript.txt lines 20-21 (resources/read), requests.json, commands.txt
- findings/evidence/cov-ios/IOS-OBS-02/resources-read.txt (the error object extracted), commands.txt
- findings/cov-ios-results.md rows MCP-079 and IOS-OBS-02

## Suspected cause
- Sources/GrantivaMCP/MCPServer.swift:117-120: the `ReadResource` handler calls
  `try await tools.readResource(uri:)` with no `catch`.
- Sources/GrantivaMCP/ToolRegistry.swift:237-249: both resource cases call `try await connection.current()`, which
  throws `GrantivaError.invalidArgument` from `MCPServer.loadActiveSession` (MCPServer.swift:187-189) when no session
  resolves.
- The MCP SDK (swift-sdk 0.12.1, `.build/checkouts/swift-sdk/Sources/MCP/Server/Server.swift:837`) turns any
  non-`MCPError` thrown from a handler into `MCPError.internalError(error.localizedDescription)`, i.e. `-32603` with the
  `Internal error: ` prefix. Note that the unknown-URI branch (ToolRegistry.swift:252) already throws a typed
  `MCPError.invalidRequest`, so typed errors do reach the client unchanged.

## Acceptance criteria
- With no session, `resources/read` for `grantiva://hierarchy` and `grantiva://screenshot` never answers `-32603`.
  It answers either a documented error code (not `-32603`, not `-32602`) whose message starts with the no-session text
  without `Internal error:`/`Invalid argument:` prefixes, or a `result` whose contents state that no session is active.
- A session that is still starting (WDA not yet answering) is reported the same way, with the "retry in a few seconds"
  text the session tools use (docs/mcp.md:19).
- An unknown URI keeps its current typed error.
- docs/mcp.md lists both resources and states what a read returns when there is no session.
- Unit test in `GrantivaMCPTests` (MCPServerTests.swift or ToolErrorContractTests.swift):
  `testResourceReadWithoutASessionIsNotAnInternalError`: build the registry with a connection whose resolver throws
  the no-session error, call the resource path the server handler uses, and assert the chosen code/contents. If the
  fix lives in the handler closure, factor the closure into a testable static function first.
