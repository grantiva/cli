# Publish the full MCP tool list

Severity: docs
Platforms: cli, ios, android
Found by: CLI-DOCS-F14 (matrix rows CLI-122; also IOS-099, AND-093)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
A product doc lists every tool `grantiva mcp` exposes, with platform notes. Source: README §Commands ("grantiva mcp
Start the MCP server for AI agent integration"); docs/android.md §Runner sessions and the MCP server (names some).

## Actual
`tools/list` returns 22 tools; README and docs name only some and list none in full:
```
grantiva_a11y_check grantiva_a11y_tree grantiva_build grantiva_context grantiva_emulator_boot grantiva_emulator_delete
grantiva_emulator_ensure grantiva_emulator_list grantiva_run grantiva_screenshot grantiva_script grantiva_sim_boot
grantiva_sim_delete grantiva_sim_ensure grantiva_sim_list grantiva_swipe grantiva_tap grantiva_test grantiva_type
grantiva_vrt_approve grantiva_vrt_capture grantiva_vrt_compare
```
(The "19" in the internal QA spec is not a product claim; only the missing list is a product issue.)

## Repro
```
fixtures/mcp/send.sh <project-with-session> ios fixtures/mcp/tools-list.jsonl | python3 -I -m json.tool
grep -n 'grantiva_' README.md docs/*.md
```

## Evidence
- findings/evidence/cli/mcp/tools-list-ios.jsonl; help/mcp-tools-probe.txt (qa-cli worktree root); docs/android.md:96-102

## Suspected cause
Docs gap. Tools are registered under Sources/GrantivaMCP/Tools/.

## Acceptance criteria
- A doc (README §MCP or docs/mcp.md) lists all 22 tools with one line each, notes `grantiva_test` is iOS-only and
  `grantiva_emulator_*` Android-only, and states which need a runner session (see C11).
- GrantivaMCPTests/ToolRegistrationTests: a test asserts the documented list equals the registered tool names, so the
  doc cannot drift.
