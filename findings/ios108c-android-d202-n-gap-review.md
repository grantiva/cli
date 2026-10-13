# iOS 108c, Android D2-02, and N-gap review

Candidate CLI provenance is `8f2cff67`; retained runner provenance is `fd9d8e8`.

## Completed rows

### MCP-081 [iOS] — PASS

`cov3-ios-attempt108c` is the valid complement to the excluded 108b fixture. The MCP server starts in a genuinely empty project directory. `mcp/before-config.json` is the expected `grantiva.yml not found` error. After the harness writes the config, `mcp/after-config.json` is a non-error `Build succeeded` response naming `Landmarks (UI Testing)`, `cov3-ios-26`, zero errors, and the product path; `mcp.exit` is 0. `mcp/context.json` also reports the newly written config source and values. This exactly exercises the nil-to-present reload required by matrix line 917 and candidate semantic test `Tests/GrantivaMCPTests/SessionLifecycleTests.swift:233-246`.

### D2-02 [Android] — PASS

The success half `D2-02-stock-ready-pass-rerun1` exits 0. Its decoded `assertions.json` has every check true. `ready.json` is `passed`, names the exact supplied report directory, and orders `screens` before all twelve configured flows (`01-browse` through `12-quote-label`); all thirteen entries are passed. The corresponding report exists and is passed.

The retained failure half `output-contracts-exact-rerun2/B2-K20-ready/ready.json` is `failed`, still contains the exact supplied `reportDir`, and preserves `screens` before `01-browse`; its report directory and failed report exist. Together these prove both the ordering clause and the “reportDir present whenever supplied, pass or fail” clause at matrix line 1414.

## Named Android N-family audit

| Row | Current disposition | Smallest remaining evidence |
|---|---|---|
| N2-13 | Not yet a full join | `B3-L49-L50-crash-waits-rerun1` is strong current crash evidence, but its scratch runs report the crash at `launchApp`; its named variants do not establish each literal post-launch primitive in the matrix (`extendedWaitUntil visible`, `assertNotVisible`, `scrollUntilVisible`, and `waitForAnimationToEnd`) executing and independently returning `error.type: app_crash` under its timeout. Preserve it as corroboration; a current exact four-primitive report set is still needed. |
| N2-16 | Missing literal compound runtime | Current settings batches establish ordinary restoration, but retained current-round evidence does not contain the required three fresh first captures plus a row-owned emulator teardown during the slow flow with the about-5-second missing-adb branch (and documented 30-second offline branch). Historical cov2 output remains quarantined. |
| N2-17 | Missing literal repeated geometry/runtime set | Current swipe-from evidence proves the feature in ordinary flows, but no retained current-round set was found with ten exact K09 runs, pointer-location trace proving the 90%-across far-side start and edge-margin end, and 10/10 row opens. The runner documentation/source clause cannot substitute for those runtime repetitions. |

## Evidence roots

- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt108c/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/D2-02-stock-ready-pass-rerun1/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/output-contracts-exact-rerun2/B2-K20-ready/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B3-L49-L50-crash-waits-rerun1/`
