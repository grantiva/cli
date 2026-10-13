# B2-K53 named-tool envelope audit

Exact candidate source is `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main` at `8f2cff67`.

## Android runtime

Android's explicit runtime variants are complete in `MCP059-062-D235-emulator-lifecycle-rerun1`:

- `running-missing/missing-boot.json` is the named missing-AVD `grantiva_emulator_boot` failure.
- `running-missing/running-delete.json` is a refused delete of a running AVD.
- `config-handmade/refuse.json` and `empty-handmade/refuse.json` are hand-made AVD delete refusals and explicitly say `Pass force: true to delete it anyway.`
- The paired force calls succeed as ordinary `result` documents, proving the refusal is about ownership rather than an uncallable tool.

Every failure is a JSON-RPC response with top-level `result`, one text content block beginning `Error:`, and `isError: true`; none has a top-level `error`. This supports B2-K53 `[android]`.

## iOS runtime

The failing-build variant is covered by `cov3-ios-attempt55b/mcp-empty/build.json`: `grantiva_build` in the empty project returns top-level `result`, error text naming the missing config, and `isError: true`, with no top-level `error`.

iOS attempt 93 supplies the remaining explicit runtime variant. `mcp/missing.json` is the response to `grantiva_sim_boot {name: "no-such-sim"}` and returns top-level `result`, one text block saying `Error: Invalid argument: Simulator not found: "no-such-sim"`, and `isError: true`; there is no top-level `error`. Its following tools/list response proves the server remains usable. Joined with attempt 55b's failing build response, B2-K53 `[ios]` is fully supported.

## Shared source clauses

`Tests/GrantivaMCPTests/ToolErrorContractTests.swift` has the exact named table for `grantiva_build`, `grantiva_run`, `grantiva_sim_boot`, `grantiva_sim_delete`, `grantiva_emulator_boot`, `grantiva_emulator_delete`, `grantiva_emulator_ensure`, and `grantiva_emulator_list`, asserting thrown non-cancellation failures become `isError` results. `testCancellationStillPropagatesAsCancellation` pins the cancellation exception, and `Sources/GrantivaMCP/ToolRegistry.swift` centralizes the conversion while rethrowing cancellation. These satisfy the named semantic/unit and cancellation clauses. Runtime variants are now present on both platforms.
