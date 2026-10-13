# Missing script steps differs from the agreed required-argument text

Severity: contract
Component: mcp
Platforms: ios and android, observed with live sessions
Rows: B3-L15.2
Regresses: L15's exact missing-required-argument criterion from the round-3 fix wave.
Candidate: CLI 8f2cff67, runner 1.1.28-grantiva.13.
Status: evidence-backed triage during the incomplete round-3 coverage pass.

## Expected

With a live session, `grantiva_script {}` returns an isError result with exactly `Error: Invalid argument: 'steps' is required.` The no-session error still takes precedence without a session.

## Actual

The live iOS and Android replies are `Error: Invalid argument: 'steps' array is required.` The iOS swipe and type replies return the agreed missing-argument shape. The prefix and isError envelope are correct; the remaining difference is the extra word `array`.

## Repro

Start a session on the explicitly named campaign-owned simulator using the QA binary and QA runner home. Initialize MCP, then send `tools/call` for `grantiva_script` with empty arguments. The recorded transcript includes the full request and response. Do not substitute a no-session request, which takes a different path.

## Evidence

- `findings/evidence/cov3-ios/B3-L15.2/mcp/transcript.txt`, request ID 2.
- `findings/evidence/cov3-android/MCP-live-readonly/mcp/script-missing.json`, request ID 15, confirms the same live Android result.
- Candidate `Sources/GrantivaMCP/Tools/ScriptTools.swift:80` constructs the observed text.
- `Tests/GrantivaMCPTests/ToolErrorContractTests.swift:68,280` and `ScriptToolsTests.swift:50` encode the same variant, so their agreement with the source does not establish compliance with L15.

Live evidence currently lives on cov3/ios and cov3/android until the slices are merged.

## Suspected cause

The prefix/label correction retained a pre-existing message variant, and tests assert that retained variant instead of the approved exact text.

## Acceptance criteria

- Missing steps returns the agreed exact full text through ToolRegistry with a live session on both platforms.
- Tests pin the complete text and isError envelope, including the no-session precedence behavior.
- Wrong-type and empty-array handling retain their separately documented semantics.
