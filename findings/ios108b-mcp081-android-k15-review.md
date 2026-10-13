# Attempt 108b / Android B2-K15 scoped review

Reviewed against the round-3 matrix using CLI candidate `8f2cff67`. This review does not cover the still-running Android D2-02 capture.

## Verdicts

| Row | Verdict | Evidence and criterion mapping |
|---|---|---|
| IOS-123 | PASS | `cov3-ios-attempt108b/ios123-build.exit` is 0. `ios123-build.out` is successful build JSON for scheme `Landmarks (UI Testing)`, bundle `com.kylebrowning.Landmarks`, and the expected simulator destination. The immutable harness command supplies the matrix's exact `--bundle-id com.kylebrowning.Landmarks`; the successful product output establishes that it was accepted and used. |
| IOS-124 | PASS | The attempt follows the README fixture pattern with the substituted campaign UDID and seeded-state copy. `ios124-install.exit` is 0; `ios124-install.out` is valid install JSON and contains a non-null `dataContainerPath`; `ios124-data-container.txt` is the successful `jq -r` extraction. `ios124-run.exit` is 0 and `ios124-run.out` records the seeded-state flow passing 8/8 commands with both screenshots. The wrapper's inventory proxy changed only the simulator data-path size; identity and state were stable, so that proxy does not contradict either matrix requirement. |
| MCP-081 | EXCLUDE attempt 108b; still needs the true-empty retry | The literal input is “server started in an empty dir; then `grantiva.yml` written.” Attempt 108b copied `.maestro` into the alleged empty server directory before startup, so startup resolved a non-nil fallback config. The before and after calls both return the cached-config `no scheme specified` error, while context independently sees the later `grantiva.yml`. Candidate `ToolRegistry.currentConfig()` at `Sources/GrantivaMCP/ToolRegistry.swift:223-226` returns the startup config whenever non-nil and invokes `loadConfig` only when it was initially nil. The exact semantic test `Tests/GrantivaMCPTests/SessionLifecycleTests.swift:233-246` proves the required initially-nil transition. Thus this run did not exercise MCP-081 and is not evidence of a product defect; no L78 brief is supported. |
| B2-K15 [android] | PASS | `B2-K15-live-teardown-accepted-rerun3/assertions.json` has all 11 checks true for separate text and JSON live runs. Each targeted teardown stops its exact detached runner, removes the project session, releases the `emulator-5556` lease, kills the owned secondary, and leaves the unrelated primary alive. The JSON outcome is `recorded:true`, `killed:true`, `runnerSessionStopped:true`; the text run emits the required stopped-runner line. The owned AVD is deleted during cleanup. Candidate tests `EmulatorCommandTests.swift:128-181` assert stopped-runner text/JSON, exact matching-session removal, and preservation of a session naming another serial. `EmulatorCommand.swift:139-200` applies the same per-outcome stop loop to the list returned by `teardownAll()`, satisfying the `--all` semantic branch without a prohibited global live teardown. Primary survival is used only as live device noninterference evidence; the unrelated-session claim comes from the semantic test. |

## MCP-081 fixture diagnosis

The attempt's `mcp/before-config.json` and `mcp/after-config.json` are internally honest, but they answer a different transition: fallback config to newly written project config. The matrix and semantic test specify nil config to newly written config. `mcp/context.json` seeing `source: grantiva.yml` does not make the build call eligible because context loads current project context separately while the build registry retains its non-nil startup config. The planned 108c true-empty retry is the minimal discriminating run.

## Provenance

- iOS raw: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt108b/`
- Android raw: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B2-K15-live-teardown-accepted-rerun3/`
- Matrix: `/Users/kyle/Developer/grantiva-cli/.worktrees/regression/docs/superpowers/plans/2026-10-13-round3-coverage-matrix.md:371-372,917,1253`
- CLI source/tests: `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main` at `8f2cff67`
