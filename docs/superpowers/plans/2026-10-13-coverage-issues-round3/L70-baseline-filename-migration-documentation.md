# Baseline filename migration lacks a public note

Severity: documentation contract
Component: public baseline and capture documentation
Rows: B-I16.2 [ios]
Candidate: CLI 8f2cff676b3c12e951478920fa20e600cdca4e29.
Status: evidence-backed triage during the incomplete round-3 coverage pass.

## Expected

B-I16.2 requires a public note explaining the filename change. The binding matrix lines 924–925 substitutes README, public docs, or release notes for the CHANGELOG removed by #179.

## Actual

The implementation produces literal-space filenames, accepts legacy percent-encoded baseline filenames, and migrates them on approval. No corresponding public migration note was found at the candidate HEAD. Runtime behavior passes; this is solely a documentation omission.

## Evidence

- iOS slice `findings/evidence/cov3-ios-attempt57/`: capture and comparison identify `Deep Links.png` and `Deep Links_diff.png`; legacy comparison resolves `Deep%20Links.png`; approval replaces the legacy baseline with the literal filename. Final retained artifacts and inventories support these observations.
- Exact candidate `Sources/GrantivaCore/Diff/BaselineStore.swift` implements legacy loading and migration. `Tests/GrantivaCoreTests/ScreenArtifactTests.swift` asserts literal/legacy naming, percent ambiguity, and migration.
- Independent exact-head public documentation searches and review: CLI slice `findings/ios57-bi16-review.md` and `findings/ios59-android-selector-and-bi16-doc-review.md`.

## Acceptance criteria

- Add a concise public baseline/capture note describing literal filenames, legacy percent-encoded baseline compatibility, and migration on approval.
- State the actual implementation behavior without implying users must rename working legacy baselines manually.
- Recheck the note against the retained migration evidence and exact implementation. No runtime change is requested.
