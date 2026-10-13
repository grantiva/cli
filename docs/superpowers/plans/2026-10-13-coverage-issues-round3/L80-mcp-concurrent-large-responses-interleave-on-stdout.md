# Concurrent large MCP responses interleave on stdout

Severity: contract
Component: MCP stdio response transport
Platforms: Android reproduced; shared MCP server transport
Rows: AND3-OBS-02 (side finding; no matrix row invented)
Candidate: CLI 8f2cff676b3c12e951478920fa20e600cdca4e29; QA binary SHA256 3f3293aaf1522fefe8d46457370b32a20fa8c657461bf32af086e75a754a73f8.
Status: independently confirmed during round-3 verification.

## Expected

Every JSON-RPC response written by the stdio MCP server is one complete newline-delimited JSON object. Concurrent requests may complete in either order, but their response bytes must never interleave. A client reading one line at a time must be able to decode every response and associate it with its request ID.

## Actual

Two concurrent ready-session hierarchy requests produce individually valid response objects whose bytes are interleaved on stdout:

- response ID 5 begins at the start of raw line 4;
- at raw-line byte offset exactly 65,536, response ID 4 begins before ID 5 has finished;
- ID 4 finishes on that same physical line;
- the displaced remainder of ID 5 resumes on raw line 5.

The resulting 135,963-byte line and 4,937-byte line are both invalid JSON. The client consequently times out IDs 4 and 5 even though both complete response bodies are visibly present in the preserved byte stream. The first three responses—initialize and the two smaller starting-state errors—remain valid. MCP stderr is empty.

This is not client-side corruption. The harness has one stdout reader thread which records each line exactly as received before parsing it. It writes requests sequentially to stdin. It never writes to the server's stdout pipe. The exact 65,536-byte insertion boundary and presence of two distinct complete JSON-RPC IDs inside the stream show concurrent response writes sharing stdout without whole-message serialization.

## Repro and evidence

- `findings/evidence/cov3-android/B3-L38-a-detached-timeline-rerun3/run/mcp.stdout.raw`
- `findings/evidence/cov3-android/B3-L38-a-detached-timeline-rerun3/run/missing-responses.json`
- `findings/evidence/cov3-android/B3-L38-a-detached-timeline-rerun3/run/mcp.stderr.raw`
- `findings/evidence/cov3-android/B3-L38-a-detached-timeline-rerun3/client.py`

The client sends `resources/read grantiva://hierarchy` and `grantiva_a11y_tree` back-to-back after the same detached session reaches ready. Both responses contain a large hierarchy. A sequential complement is kept separate so B3-L38-a can verify its intended lifecycle contract without hiding this transport failure.

## Supported cause

`Sources/GrantivaMCP/MCPServer.swift` uses the MCP package's `StdioTransport`. The raw boundary proves that two response encodings reach the shared stdout descriptor concurrently and are emitted in chunks rather than under a whole-response write lock. The exact repair site may be Grantiva's server integration or the pinned MCP transport dependency; the retained source does not by itself establish which layer owns the missing serialization. The causal statement is therefore limited to the observed shared-transport write behavior.

## Acceptance criteria

- Send at least two concurrent MCP requests whose individual responses exceed 65,536 bytes. Every stdout line is independently valid JSON and contains exactly one JSON-RPC response.
- Both response IDs arrive exactly once, regardless of completion order; neither response is truncated, split across lines, or contains bytes from the other.
- Repeat the concurrent pair at least ten times and include mixed resource/tool requests.
- Preserve concurrent small-response behavior and notification delivery.
- Add a transport-level test using partial/chunked underlying writes so correctness does not depend on payload size or an operating-system pipe's atomic-write limit.
