# The MCP server answers a malformed notification with a `-32700 Parse error` carrying an invented UUID `id`

Severity: contract
Component: mcp
Platforms: n/a (stdio transport; the same server code serves both platforms)
Rows: IOS-100 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9
Triage note: the malformed message came from the QA harness (its client adds `"jsonrpc"` to requests but not to
notifications), so no real MCP client is known to hit this. The defect is the shape of the reply, which a strict client
cannot correlate and may treat as a protocol fault. IOS-100's main check (stdout carries only JSON-RPC, requests are
answered while subprocesses run) passed.

## Expected
JSON-RPC 2.0 (§4.1, §5):
- a notification (no `id`) is never answered;
- when a message is invalid and its `id` cannot be determined, any error response carries `"id": null`;
- `-32700 Parse error` is for text that is not valid JSON; well-formed JSON that is not a valid request object is
  `-32600 Invalid Request`.

So `{"method":"notifications/initialized"}` (valid JSON, no `"jsonrpc"`, no `id`) should get either no reply or
`{"jsonrpc":"2.0","error":{"code":-32600,…},"id":null}`. docs/mcp.md:3 promises only JSON-RPC on stdout; it says
nothing about malformed input, so the spec governs.

## Actual
`findings/evidence/cov-ios/MCP-LIVE1/run/transcript.txt:3-5`:
```
>> {"method": "notifications/initialized"}
>> {"method": "tools/list", "id": 2, "jsonrpc": "2.0"}
<< (other) {"error": {"code": -32700, "data": {"detail": "Invalid message format"}, "message": "Parse error: Invalid JSON: Invalid message format"}, "id": "AE89705B-257F-4A2E-83BE-E154733FC3D9", "jsonrpc": "2.0"}
```
The `id` is a fresh UUID that matches nothing the client sent, the code says the JSON was unparseable though it
parsed, and the message reads `Invalid JSON`. The following request (id 2) was answered normally.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner"
rm -rf /tmp/k101 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k101 && cd /tmp/k101/ios   # main 4e49dc4
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"qa","version":"1"}}}' \
  '{"method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
  'this is not json' \
  | (cat; sleep 2) | grantiva mcp --platform ios --project-dir "$PWD" | cut -c1-200
```
No simulator is needed. Today: a `-32700` reply with a random UUID `id` for the id-less notification, and (per the
code path below) another random-id `-32700` for the non-JSON line, which should carry `"id": null`.

## Evidence
- findings/evidence/cov-ios/MCP-LIVE1/run/transcript.txt lines 3-5, requests.json, commands.txt
- findings/cov-ios-results.md row IOS-100

## Suspected cause
Not in this repository's code: the MCP Swift SDK the CLI depends on (Package.resolved: swift-sdk 0.12.1, a0ae212).
`.build/checkouts/swift-sdk/Sources/MCP/Server/Server.swift:226-265`: the receive loop tries batch, response, request
and notification decoders; when all fail it looks for an `id` in the raw JSON, then throws
`MCPError.parseError("Invalid message format")` (line 252). The catch sends
`AnyMethod.response(id: requestID ?? .random, …)` (lines 260-265), and `ID.random` (Sources/MCP/Base/ID.swift:12)
is a new UUID string. So every undecodable message gets a reply, with `-32700` regardless of whether the JSON parsed,
and an invented id when it had none.

The CLI only constructs the transport and server (Sources/GrantivaMCP/MCPServer.swift:22-24) and has no hook in that
loop. Options: move to an SDK release that fixes this, or wrap `StdioTransport` in a small `Transport` that
inspects each line before the server sees it: drop id-less invalid messages, and answer invalid JSON / invalid request
objects itself with `id: null` and the right code.

## Acceptance criteria
- An id-less message that is not a valid notification produces no output on stdout (or, if a reply is kept, it is
  `-32600` with `"id": null`).
- A line that is not JSON gets `-32700` with `"id": null`.
- A malformed message that does carry an `id` (e.g. `{"id":7,"method":"tools/list"}` without `"jsonrpc"`) gets
  `-32600` echoing `"id": 7`.
- Valid traffic is unchanged: initialize, tools/list and tools/call still work after any of the above.
- Test in `GrantivaMCPTests` (new `MCPTransportTests.swift`): drive the server through an in-memory transport (or
  the wrapper above) with the four input lines from the repro and assert the exact replies, including that no reply
  carries an `id` the client did not send.
