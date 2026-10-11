# The MCP VRT tools still run the CLI through a shell command string rather than an argument array

Severity: contract
Component: mcp
Platforms: n/a
Rows: B-C05.2 (cli); original brief C05 (mcp-vrt-tools-use-own-executable)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9
Triage note: brief C05's criterion 2 is phrased as a preference ("Prefer spawning the executable with an argument array instead of a shell string"); its security criterion holds (B-C05.1 passed: the server's own absolute path is used and a PATH stub is never invoked; IOS-114 showed a screen name with `; touch` is quoted). Low priority hardening.

## Expected
Brief C05 acceptance criteria: "Re-running the repro calls the server's own binary ... and the stub is never invoked.
Prefer spawning the executable with an argument array instead of a shell string."

## Actual
`VRTTools` builds strings and runs them through `shell` (findings/evidence/cov-cli/B-C05.2/):
```
"\(shellQuoted(executable)) diff capture --no-build --json --platform \(platform.rawValue)"
"\(shellQuoted(executable)) diff compare --json --platform \(platform.rawValue)"
"\(shellQuoted(executable)) diff approve --json --platform \(platform.rawValue)" + " " + screens.map(shellQuoted)
```
Safety rests entirely on `shellQuoted`.

## Repro
Source check (no device):
```
cd /path/to/grantiva-cli
sed -n 67,81p Sources/GrantivaMCP/Tools/VRTTools.swift
grep -n "try await shell(" Sources/GrantivaMCP/Tools/VRTTools.swift
```
Behavioural check that must keep passing (screen name with shell metacharacters):
```
export PATH="$HOME/.grantiva-qa/bin:$PATH"
rm -rf /tmp/k60 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k60 && cd /tmp/k60/ios
{ echo '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"qa","version":"1"}}}'
  echo '{"jsonrpc":"2.0","method":"notifications/initialized"}'
  echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"grantiva_vrt_approve","arguments":{"screens":["Home; touch /tmp/k60/pwned","$(touch /tmp/k60/pwned2)"]}}}'
  sleep 5; } | grantiva mcp --platform ios >/dev/null; ls /tmp/k60/pwned* 2>&1
```
Today: no file is created (correct), and the command still goes through `/bin/sh`.

## Evidence
- findings/evidence/cov-cli/B-C05.2/commands.txt, src.out (source excerpt)
- findings/evidence/cov-cli/B-C05.1/ (PATH-stub check, passed)
- findings/evidence/cov-ios/MCP-063/session/transcript.txt (IOS-114 quoting check)

## Suspected cause
- Sources/GrantivaMCP/Tools/VRTTools.swift:67-81 (`captureCommand`, `compareCommand`, `approveCommand` return
  strings) and :88, :108, :137 (`shell(...)`).

## Acceptance criteria
- The three tools spawn `VRTTools.executable` with an argument array (a `Process`/ChildProcess helper that captures
  stdout and stderr and maps a non-zero exit to `GrantivaError.commandFailed(stderr, code)` as `shell` does today); no
  `/bin/sh` is involved.
- Re-running the behavioural check: no `pwned` files; approve fails naming the screens.
- GrantivaMCPTests/VRTToolsTests: the command builders return `[String]` argv whose first element is the absolute
  executable and whose screen arguments are passed verbatim (`"Home; touch x"` is one element, unquoted); the existing
  tests asserting quoted strings are replaced.
