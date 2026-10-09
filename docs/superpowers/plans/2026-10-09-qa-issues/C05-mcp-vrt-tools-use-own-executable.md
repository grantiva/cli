# Run MCP VRT tools with the server's own executable

Severity: wrong-result
Platforms: cli, ios, android
Found by: CLI-F19 (matrix rows: none; MCP Step 5)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
`grantiva_vrt_capture`, `grantiva_vrt_compare` and `grantiva_vrt_approve` are "Equivalent to 'grantiva diff capture
--no-build --json'" (and compare/approve) for the Grantiva that is serving MCP. Source: tool descriptions in
Sources/GrantivaMCP/Tools/VRTTools.swift:15, :24, :36.

## Actual
The server was `~/.grantiva-qa/bin/grantiva` 2.0.1; `/opt/homebrew/bin/grantiva` 2.0.0 was first on PATH. Every call failed:
```
118 grantiva_vrt_capture  isError  "Capture failed:\nError: Unknown option '--platform'\nUsage: grantiva diff capture ..."
119 grantiva_vrt_compare  isError  "Error: Unknown option '--platform'\nUsage: grantiva diff compare ..."
120 grantiva_vrt_approve  isError  "Approve failed:\nError: Unknown option '--platform'\nUsage: grantiva diff approve ..."
```
With no `grantiva` on PATH the tools cannot run at all.

## Repro
1. Put an older grantiva (or a stub script that prints its argv and exits 2) first on PATH:
   ```
   mkdir -p /tmp/c05 && printf '#!/bin/sh\necho "stub $*" >&2; exit 2\n' > /tmp/c05/grantiva && chmod +x /tmp/c05/grantiva
   ```
2. Start the server from the real build with that PATH and call compare, in a project with a runner session:
   ```
   PATH=/tmp/c05:$PATH python3 -I fixtures/mcp/client.py "$PWD/.build/release/grantiva" <project> ios calls.jsonl 60 out.jsonl
   ```
   with `calls.jsonl` holding one `grantiva_vrt_compare` call. The result is the stub's output.

## Evidence
- findings/evidence/cli/mcp/calls-ios-summary.tsv (ids 118-120, 138, 141-142, 159-160)

## Suspected cause
Sources/GrantivaMCP/Tools/VRTTools.swift:55-68 build literal `"grantiva diff …"` shell strings and run them through
`shell(...)` (:73, :90, :116), so the shell resolves `grantiva` from PATH.

## Acceptance criteria
- Re-running the repro calls the server's own binary (`Bundle.main.executablePath` / `CommandLine.arguments[0]` resolved
  to an absolute path), and the stub is never invoked.
- Prefer spawning the executable with an argument array instead of a shell string.
- GrantivaMCPTests/VRTToolsTests: assert `captureCommand`/`compareCommand`/`approveCommand` start with the running
  executable's absolute path (quoted), not the bare word `grantiva`.
