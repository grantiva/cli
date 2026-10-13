# iOS `heart` fallback triage

## Conclusion

The available evidence supports a **product fallback-selector defect**, rather than a stale fixture expectation. The candidate promises label → accessibility identifier → placeholder matching, but its second live query is `name == "heart"`, not `identifier == "heart"`. On the same app build and UI state, the bundled runner succeeds with the explicit WDA predicate `identifier ==[c] 'heart'`; the MCP implementation fails to find `heart` twice. The fixture therefore still supplies the identifier required by the matrix, while the MCP fallback does not query the attribute that the live WDA session demonstrably matches.

This is a triage conclusion, not a proposed product fix. IOS-102, B2-K78, and the iOS portion of D2-36 should remain failed on the round-3 candidate.

## Binding acceptance criteria

- `round3-coverage-matrix.md:799` requires IOS-102 to tap `heart` through the documented label-first, name/identifier fallback and identify the fallback in its result.
- `round3-coverage-matrix.md:1321` records the chosen K78 contract as label then identifier and expects `Tapped on "heart" (matched by identifier)` when that path is used.
- `round3-coverage-matrix.md:1448` requires D2-36's iOS sequence to try label, identifier (`heart`), then placeholder (`Name`).
- CLI-064 at line 200 has a narrower parse/staging contract. Its live execution is still useful here because it independently demonstrates that the staged `id: heart` reaches the same app through WDA.

## Live evidence

The recovered app and candidate provenance is explicit: `findings/round3-smoke.md:190-193` identifies CLI commit `8f2cff67`, runner `1.1.28-grantiva.13`, and demo commit `75acc87`; `findings/evidence/cov3-ios/PROVENANCE.md:19-23` describes attempts 7 and 8 and preserves their limitations.

1. In attempt 7, `findings/evidence/cov3-ios-attempt7/NAV/mcp/transcript.txt`, request 2 taps `Favorites` successfully and returns the Favorites hierarchy. The immediately following request 3 calls `grantiva_tap` with `label: "heart"` and returns `isError: true`, `Element not found: "heart"`.
2. Attempt 8 independently repeats that result in `findings/evidence/cov3-ios-attempt8/LIVE/mcp/transcript.txt` and the row extracts under `B2-K78/transcript.txt` and `D2-36/transcript.txt`: `Favorites` succeeds, then `heart` fails. Later navigation continues, so this is not a dead MCP server or absent app session.
3. In attempt 5, `findings/evidence/cov3-ios-attempt5/CLI-064/input.yaml` launches the same bundle, taps `Favorites` by text, then taps `heart` by id. `run.out` records every step as successful. More decisively, `report/maestro-runner.log:120-132` shows WDA receiving `**/XCUIElementTypeAny[\`identifier ==[c] 'heart'\`]`, returning HTTP 200 with an element, and the runner tapping its coordinates successfully.

The CLI-064 success does not by itself grade an MCP row, but it disproves the stale-fixture theory relevant to this triage: an element with identifier `heart` existed and was tappable after selecting Favorites.

## Fixture and candidate-source trace

The demo source at `75acc87`, `Landmarks/ContentView.swift:21-28`, defines the tab as `.tabItem { Label("Favorites", systemImage: "heart") }`. It does not add a manual `.accessibilityIdentifier("heart")`; the identifier observed by the runner is the SF Symbol identifier synthesized in the live SwiftUI/WDA tree. That matches the matrix's explicit “SF Symbol identifier” premise.

Candidate `8f2cff67` documents `LabelMatch.identifier` as WDA `name` in `Sources/GrantivaCore/WDA/WDAClient.swift:61-67`. Its actual lookup list at lines 245-247 is:

```swift
("label", .label), ("name", .identifier), ("placeholderValue", .placeholder)
```

The helper builds predicate-string `/elements` requests from those attribute names at lines 249-286. Consequently, after the label miss it asks WDA for `name == "heart"`; it never asks for `identifier == "heart"`. The live runner evidence establishes that an explicit identifier predicate succeeds. The source-level unit test `WDAClientTests.swift:171-205` scripts an empty response followed by an element response and checks the reported enum, but it does not exercise WDA attribute semantics; its stub cannot establish that `name` aliases `identifier` for this SwiftUI element.

The public documentation has the same unsupported equivalence: `docs/mcp.md:112` calls the second lookup the accessibility identifier while describing it as WDA `name`. The live evidence shows that equivalence does not hold for this tab's synthesized SF Symbol identifier.

## Scope and minimal missing observation

No device rerun is needed to classify the current round-3 result or distinguish the two candidate causes. The raw MCP transcripts do not include WDA HTTP request bodies, so the one missing diagnostic observation is a transport-level capture from an MCP `heart` call showing the responses to `label == "heart"`, `name == "heart"`, and an added control query `identifier == "heart"`. Such a capture would pinpoint the server responses directly, but candidate source plus the independent successful identifier query already supports the defect classification.

The malformed coordinate setup in attempt 7 and the invalid Edit/Name navigation in attempt 8 are separate evidence limitations. They do not weaken the repeated `heart` result and should not be used to grade the coordinate or placeholder portions of IOS-102/D2-36.
