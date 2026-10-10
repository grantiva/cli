# MCP config-dependent tools do not say that the config file is missing

Severity: contract
Blocking: no
Platforms: cli, ios, android
Found by: CLI slice, brief row `C11` (findings/cli-results.md, Step 1). Original brief: C11 (`plans/2026-10-09-qa-issues/C11-mcp-starts-without-session-or-config.md` (last round's files are on branch `qa-campaign`, commit 8084069; exported copy at `~/.grantiva-qa/briefs/docs/superpowers/`)), criterion 3.
Binary: grantiva 2.1.0 at a278b77, grantiva-runner 1.1.28-grantiva.8; no device needed

## Expected
C11 criterion 3: "Without a config, config-dependent tools return `isError` naming the missing file;
`grantiva_sim_*`/`grantiva_emulator_*` work." docs/android.md:142-143: "Tools that need a config file say which file
is missing."

## Actual
In an empty directory (no `grantiva.yml`, no `grantiva-android.yml`, no session), the server starts and answers, and
the config-dependent tools do return `isError: true`, but neither message says the config file is missing
(findings/evidence/cli/C11.txt, phases 1b and 1c):
```
>> {"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "grantiva_vrt_capture", "arguments": {}}, "id": 2}
<< {"id":2,"jsonrpc":"2.0","result":{"content":[{"text":"Capture failed:\nError: Invalid argument: No screens configured in grantiva.yml","type":"text"}],"isError":true}}

>> {"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "grantiva_build", "arguments": {}}, "id": 1}
<< {"id":1,"jsonrpc":"2.0","result":{"content":[{"text":"Error: Invalid argument: no scheme specified. Pass 'scheme' or set it in grantiva.yml.","type":"text"}],"isError":true}}
```
`No screens configured in grantiva.yml` reads as if the file exists and is empty; `no scheme specified` points at the
`scheme` argument. Neither names `grantiva.yml` (or `grantiva-android.yml`) as absent. For comparison, the CLI says
`No grantiva.yml here. Create one with grantiva init.` (C18) and `grantiva_context` says `No grantiva.yml found in
current directory.`

The rest of C11 holds: with no session, `initialize` and `tools/list` answer; the 7 session tools return isError with
"No active runner session ... Start one with 'grantiva runner start' or `grantiva run --keep-alive`"; `grantiva_sim_list`
and `grantiva_emulator_list` work; a server started without a session attaches to one started later
(C11-lazy-attach.txt). The CLI equivalent, `diff capture --no-build` in the same empty dir, prints the same
`No screens configured in grantiva.yml`.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner"
unset GRANTIVA_API_KEY
rm -rf /tmp/r04-empty && mkdir -p /tmp/r04-empty && cd /tmp/r04-empty
{
  echo '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"qa","version":"1"}}}'
  echo '{"jsonrpc":"2.0","method":"notifications/initialized"}'
  echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"grantiva_build","arguments":{}}}'
  echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"grantiva_vrt_capture","arguments":{}}}'
  sleep 5
} | grantiva mcp --project-dir /tmp/r04-empty | grep -E '"id":(1|2)'
```
Both responses carry `"isError":true`; neither text says that no `grantiva.yml` or `grantiva-android.yml` was found.
Neither call should reach a device: `vrt_capture` stops at the screens check, before any simulator is chosen
(C11.txt phase 1b). Run it on a host where the booted simulators are disposable anyway.

## Evidence
- findings/evidence/cli/C11.txt (phase 1b: `grantiva_vrt_capture`, `grantiva_context`; phase 1c: `grantiva_build`, the
  CLI comparison)
- findings/evidence/cli/C11-lazy-attach.txt (lazy attach, the parts of C11 that hold)
- findings/evidence/cli/C18.txt (the CLI's "No grantiva.yml here" wording)
- docs/android.md:142-143

## Suspected cause
Not traced to source in this pass. Hypothesis: with no config file the MCP server builds an empty default
configuration, so the build tool falls through to its "no scheme" check and capture to its "no screens" check, instead
of first reporting that the config file was not found as the CLI's C18 path does.

## Acceptance criteria
- Re-running the repro in an empty directory: `grantiva_build` and `grantiva_vrt_capture` return `isError: true` with
  text naming the missing file, for example `No grantiva.yml or grantiva-android.yml in /tmp/r04-empty. Create one
  with grantiva init.` (the CLI's C18 wording is fine).
- The same holds for every other tool that reads the config; `grantiva_sim_*`, `grantiva_emulator_*` and
  `grantiva_context` keep working as now.
- With a config that exists but has no `screens:`, `grantiva_vrt_capture` keeps saying `No screens configured in
  grantiva.yml`.
- GrantivaMCPTests: with no config file, `grantiva_build` returns isError whose text contains `grantiva.yml`
  and says it was not found.
