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
