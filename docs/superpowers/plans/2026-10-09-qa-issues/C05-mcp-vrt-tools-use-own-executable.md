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

## Android detail (AND-F16)
Android adds `--platform android` to all three commands (Sources/GrantivaMCP/Tools/VRTTools.swift:55-64), so a
pre-Android `grantiva` first on PATH rejects every call. With the 2.0.1 server in landmarks-demo/android and Homebrew
2.0.0 first on PATH, `grantiva_vrt_capture`, `grantiva_vrt_compare` and `grantiva_vrt_approve {"screens":["Home"]}` all
return `isError`:
```
Unknown option '--platform'
Usage: grantiva diff capture [--json] [--verbose] [--quiet] [--app-file <app-file>] [--no-build] ... [--bundle-id <bundle-id>]
```
Repro: `which -a grantiva` lists /opt/homebrew/bin/grantiva (2.0.0) first; then
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_SESSION_ID=qa-android
cd /Users/kyle/Developer/landmarks-demo/android
export PATH="/opt/homebrew/bin:$PATH"      # older grantiva first
~/.grantiva-qa/bin/grantiva mcp             # tools/call grantiva_vrt_compare {}
```
Evidence (qa-android worktree): findings/evidence/AND-100/session3.log.
Extra acceptance criterion: with an older `grantiva` first on PATH, the Android VRT tools read and write
`.grantiva/captures/android/` and `.grantiva/baselines/android/` through the server's own binary.

## iOS detail (IOS-F33)
On iOS, with the 2.0.1 server and Homebrew 2.0.0 first on PATH, `grantiva_vrt_compare {}` and
`grantiva_vrt_approve {"screens":["Home"]}` fail:
```
{"text": "Error: Unknown option '--platform'\nUsage: grantiva diff compare [--json] [--verbose] [--quiet] ..."}
{"text": "Approve failed:\nError: Unknown option '--platform'\nUsage: grantiva diff approve ..."}
```
Both work when a PATH entry for 2.0.1 comes first (approve Home succeeds, compare returns the JSON).
Repro:
```
export GRANTIVA_SESSION_ID=qa-ios QA=/Users/kyle/Developer/grantiva-cli/.worktrees/qa-ios
rm -rf /tmp/qa-ios-app && cp -R /Users/kyle/Developer/landmarks-demo/ios /tmp/qa-ios-app && cd /tmp/qa-ios-app
export PATH="/opt/homebrew/bin:$PATH"; which -a grantiva | head -1     # 2.0.0 first
cat > /tmp/c05.json <<'J'
[{"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"qa","version":"1"}}},
 {"method":"notifications/initialized","jsonrpc":"2.0"},
 {"method":"tools/call","params":{"name":"grantiva_vrt_compare","arguments":{}}},
 {"method":"tools/call","params":{"name":"grantiva_vrt_approve","arguments":{"screens":["Home"]}}}]
J
python3 $QA/findings/evidence/IOS-mcp/client.py /tmp/c05.json /tmp/c05 /tmp/qa-ios-app \
  -- ~/.grantiva-qa/bin/grantiva mcp --project-dir /tmp/qa-ios-app
grep -o "Unknown option[^\\]*" /tmp/c05/transcript.txt
```
Evidence (qa-ios worktree): findings/evidence/IOS-mcp/phase7/transcript.txt (ids 2-3), IOS-mcp/phase8/transcript.txt.
This also re-extracted the runner under 2.0.0 and set up C01's iOS trap (see C01 iOS detail).
Extra acceptance criterion: on iOS, the repro's compare returns JSON and approve succeeds through the server's binary.
