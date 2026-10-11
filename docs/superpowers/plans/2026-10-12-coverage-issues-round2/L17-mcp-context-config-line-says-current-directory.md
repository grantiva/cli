# `grantiva_context` says "No grantiva.yml found in current directory." even when the directory it searched was `--project-dir`, and names only one platform's file

Severity: ux
Component: mcp
Platforms: n/a (MCP stdio; the same text for both platforms' files)
Rows: MCP-046 [cli]
Regresses/extends: R04 criterion 2 (MCP config tools name the missing file) and K58 (MCP context synthesizes config), fixed by CLI #195. The context line was not converted.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
docs/mcp.md:44-48 at c65fc17: the project directory is `--project-dir`, defaulting to the current directory. R04
criterion 2: every tool that reads the config names the missing file as the config tools do, for example
`grantiva.yml not found at <dir>/grantiva.yml. Create one with grantiva init.` (`GrantivaConfig.missingFileMessage`).
With no config, `grantiva_context`'s `[Config]` section names the directory it searched and the file names that would
have counted (`grantiva.yml`, and `grantiva-android.yml` when the platform was not forced).

## Actual
Server started from a directory that has a grantiva.yml, with `--project-dir` an empty directory
(findings/evidence/cov2-cli/MCP-046/cwd_has_config_projectdir_empty.out, id 1):
```
[Config]
  No grantiva.yml found in current directory.

[Simulator]
  name: cov2-ios-1
  udid: 7E846901-F93F-4220-A153-7043061033D7
  runtime: iOS 26.0
  state: Booted
  source: first booted simulator (no runner session, no simulator in grantiva.yml)
```
The sentence is false for the server's cwd (which has a grantiva.yml) and does not name the directory that was searched.
`noflag.out` (empty directory as both cwd and `--project-dir`) prints the same line.

Aside, same output: with no session and no configured simulator, `[Simulator]` falls back to the first booted simulator
on the host. Here that was `cov2-ios-1`, which belonged to another session. docs/mcp.md:47-48 says context reports
"the session's simulator or emulator, or the configured one when there is no session". The UI tools do not act on that
device, and `grantiva_build` without a simulator picks a different one (L08). Folded in here as a second criterion, not
split, because it is the same section of the same tool output.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner"; unset GRANTIVA_API_KEY
rm -rf /tmp/l17 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l17 && mkdir /tmp/l17/empty
cd /tmp/l17/ios   # has grantiva.yml
{ cat <<'EOF'
{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"l17","version":"1"}}}
{"jsonrpc":"2.0","method":"notifications/initialized"}
{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"grantiva_context","arguments":{}}}
EOF
sleep 3; } | grantiva mcp --project-dir /tmp/l17/empty | jq -r 'select(.id==1) | .result.content[0].text' | head -8
# bug: "No grantiva.yml found in current directory." and a [Simulator] that is just the first booted one
```

## Evidence
- findings/evidence/cov2-cli/MCP-046/cwd_has_config_projectdir_empty.out, .requests.jsonl, noflag.out, commands.txt
- findings/evidence/cov2-cli/B2-K58/ (config source naming passes; the no-config wording was graded here)
- docs/superpowers/plans/2026-10-10-regression-issues/R04-mcp-config-tools-do-not-name-missing-file.md

## Suspected cause
- `Sources/GrantivaMCP/Tools/ContextTool.swift:63-64`: the no-config branch hardcodes `"[Config]\n  No
  \(platform.configFileName) found in current directory."`. `ContextTool.context` (`:29-37`) is not given the project
  directory. `ToolRegistry` has both `projectDirectory` (`Sources/GrantivaMCP/ToolRegistry.swift:18`) and the
  ready-made `missingConfig = GrantivaConfig.missingFileMessage(platform:directory:)` (`:125`) that the config tools
  use. The call at `:161-167` passes neither.
- `[Simulator]` fallback: `ContextTool.simulatorSection` (`ContextTool.swift:113-137`) ends with
  `devices.first(where: \.isBooted)` labelled "first booted simulator" (`:134-136`). The documented order stops at the
  configured simulator.

## Acceptance criteria
- With no config, `[Config]` reads `grantiva.yml not found at <project dir>/grantiva.yml. Create one with grantiva
  init.` (the `missingFileMessage` text, `/private` spelling per K104), for the directory actually searched. When the
  platform was auto-detected, the line names both `grantiva.yml` and `grantiva-android.yml`. The words "current
  directory" appear only when `--project-dir` was not given.
- With no session and no configured simulator, `[Simulator]` either says `No runner session and no simulator in
  grantiva.yml.` (optionally listing booted simulators as a hint, not as "the device"), or docs/mcp.md documents the
  first-booted fallback and says the UI tools do not use it. Pick one.
- Tests: GrantivaMCPTests/ContextToolTests, (1) `context(config: nil, …, projectDirectory: /x/empty)` contains
  `/x/empty/grantiva.yml` and not `current directory`. (2) No session, no config, one booted simulator: the expected
  `[Simulator]` text for the chosen rule.
