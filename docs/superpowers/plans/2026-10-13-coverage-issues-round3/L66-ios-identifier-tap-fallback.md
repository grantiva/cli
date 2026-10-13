# iOS MCP tap misses an accessibility identifier that the runner finds

Severity: wrong-result
Component: mcp / iOS WDA selector
Rows: IOS-102, B2-K78, D2-36 [ios]
Candidate: CLI 8f2cff67, runner 1.1.28-grantiva.13, demo 75acc87.
Status: confirmed by the completed round-3 coverage pass; open for the round-4 fix wave.

## Expected

The agreed tap contract tries label, accessibility identifier, then placeholder. After opening Favorites, `grantiva_tap` with `label: "heart"` finds the tab's SF Symbol identifier and reports `Tapped on "heart" (matched by identifier)`.

## Actual

Live MCP calls return `Element not found: "heart"` in two attempts. Label-based navigation still works. The same demo build and Favorites state succeeds through the runner with `tapOn: { id: heart }`; its WDA log records a successful explicit identifier query and tap.

## Evidence

- iOS `findings/evidence/cov3-ios-attempt7/NAV/mcp/transcript.txt`: Favorites succeeds, then heart fails.
- iOS `findings/evidence/cov3-ios-attempt8/LIVE/mcp/transcript.txt`: independent repetition.
- iOS `findings/evidence/cov3-ios-attempt5/CLI-064/input.yaml`, `run.out`, and `report/maestro-runner.log:120`: `identifier ==[c] 'heart'` returns an element and the tap succeeds.
- Candidate `Sources/GrantivaCore/WDA/WDAClient.swift:245` tries `label`, `name`, and `placeholderValue`; it never queries `identifier`.
- CLI `findings/ios-heart-fallback-triage.md` contains the independent evidence/source review.

Evidence remains in the named slice worktrees until consolidation. The malformed coordinate setup and later invalid Edit navigation are separate harness limitations and do not support additional product findings.

## Suspected cause

The implementation treats WDA `name` as equivalent to accessibility identifier. The successful explicit identifier query and failed MCP calls support a selector mismatch. MCP-to-WDA HTTP response bodies were not captured, so the exact server responses to its predicates remain unobserved.

## Acceptance criteria

- Reproduce the agreed label → identifier → placeholder order with the real demo on the campaign-owned iOS simulator, including the `heart` identifier and `Name` placeholder.
- Preserve the match annotation, exclusion of application elements, literal escaping, and existing error/retry behavior.
- Tests verify the actual selected WDA attributes and priority rather than merely returning a stub element on the second request.
- Update the misleading WDA `name` equivalence in source comments and `docs/mcp.md`. Query the true identifier for the identifier leg; any separately retained `name` fallback must have explicit, tested semantics and priority consistent with the binding contract.
- Re-run the full binding criteria for IOS-102, B2-K78, and iOS D2-36 on the fixed candidate; this brief does not relax them.
