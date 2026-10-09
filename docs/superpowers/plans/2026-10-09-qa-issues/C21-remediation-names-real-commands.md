# Point error remediation lines at commands that exist

Severity: ux
Platforms: cli, ios
Found by: CLI-F13 (matrix rows: none; seen via MCP `grantiva_tap`)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
Every "Run: …" remediation names a command that exists on this host. Source: help: grantiva (no `sim` or `ui` subcommand).

## Actual
```
Internal error: Element not found: "No Such Label QA". Run grantiva ui a11y to inspect the tree.
No simulator is running. Run: grantiva sim boot "iPhone 16"
```
Both commands exit 64 (`grantiva sim boot "iPhone 16"`: 3 unexpected arguments; `grantiva ui a11y` likewise). The doctor
fix line says `xcrun simctl boot "iPhone 16"`, a device type absent on Xcode 27 hosts.

## Repro
```
grantiva sim boot "iPhone 16"; echo rc=$?
grantiva ui a11y; echo rc=$?
grep -n 'sim boot\|ui a11y' Sources/GrantivaCore/GrantivaError.swift
```
Live: with a runner session, call MCP `grantiva_tap {"label":"No Such Label QA"}` via fixtures/mcp/client.py.

## Evidence
- findings/evidence/cli/mcp/calls-ios-summary.tsv (id 150)

## Suspected cause
Sources/GrantivaCore/GrantivaError.swift:29 and :33 hold the stale strings; Sources/GrantivaCore/Doctor/DoctorRunner.swift:98
hardcodes "iPhone 16".

## Acceptance criteria
- `simulatorNotRunning` says `Run: grantiva simulator ensure --name "<device>"`; element-not-found says
  `Run grantiva hierarchy (or the grantiva_a11y_tree MCP tool) to inspect the tree.`; doctor names an installed device
  type or `grantiva simulator ensure --name "iPhone 17 Pro"`.
- Note `grantiva_tap` returned this as a JSON-RPC internal error (rpc-error), not an `isError` result; return `isError`.
- GrantivaCoreTests: a test parses every "Run: grantiva …" string in GrantivaError and asserts the subcommand path exists
  in the CLI command tree (or a fixed allowlist).

## iOS detail (IOS-F30)
On iOS, MCP `grantiva_tap` by label hits this string whenever WDA's name differs from the label (I05), e.g.:
```
<< {"error": {"code": -32603, "message": "Internal error: Element not found: \"Favorites\". Run grantiva ui a11y to inspect the tree."}}
```
`grantiva ui` does not exist. Repro:
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_SESSION_ID=qa-ios QA=/Users/kyle/Developer/grantiva-cli/.worktrees/qa-ios
rm -rf /tmp/qa-ios-app && cp -R /Users/kyle/Developer/landmarks-demo/ios /tmp/qa-ios-app && cd /tmp/qa-ios-app
grantiva simulator ensure --name qa-ios-2 --device-type "iPhone 17" --runtime 26.0
grantiva build install --simulator qa-ios-2
grantiva run --no-build --flow .maestro/01-browse.yaml --simulator qa-ios-2 --keep-alive --ready-file /tmp/c21.ready &
while [ ! -f /tmp/c21.ready ]; do sleep 0.2; done
cat > /tmp/c21.json <<'J'
[{"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"qa","version":"1"}}},
 {"method":"notifications/initialized","jsonrpc":"2.0"},
 {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Favorites"}}}]
J
python3 $QA/findings/evidence/IOS-mcp/client.py /tmp/c21.json /tmp/c21 /tmp/qa-ios-app -- grantiva mcp
grep -o 'Element not found[^"]*' /tmp/c21/transcript.txt; kill -INT %1
```
Evidence (qa-ios worktree): findings/evidence/IOS-mcp/phase1/transcript.txt (ids 7, 10).
Extra acceptance criterion: none beyond the existing ones; verify the iOS error text after I05 lands.
