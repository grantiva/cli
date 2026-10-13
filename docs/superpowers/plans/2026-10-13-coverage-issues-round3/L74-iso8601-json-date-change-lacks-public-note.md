# ISO-8601 JSON date change lacks a public note

Severity: documentation contract
Component: CLI JSON output documentation
Rows: B-C22.2 [ios], B-C22.2 [android]
Candidate: CLI 8f2cff676b3c12e951478920fa20e600cdca4e29.
Status: evidence-backed triage during the incomplete round-3 coverage pass.

## Expected

B-C22.2 requires JSON date values to use ISO 8601 and requires a change note. Because CHANGELOG.md was removed in #179, binding matrix lines 924–925 accept the note in README, public docs, or release notes.

## Actual

The implementation and runtime behavior are correct on both platforms. Current simulator and emulator session documents emit ISO-8601 `acquiredAt`; iOS cleanup also emits ISO-8601 `createdAt`. Both shared JSON encoder entry points set `.iso8601`, and the exact-head semantic test pins epoch zero.

No public README/docs/release-note text explains that date-valued JSON fields changed to ISO 8601. The README's nearby JSON compatibility paragraph documents key casing and aliases, not date encoding. L70 documents baseline filename migration and does not cover this change.

## Evidence

- iOS current session: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios/IOS-010/sessions-json.out`.
- Android current session: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/X013-X015-X017-android-rerun1/text/sessions.json`.
- Additional iOS writer: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt77/cleanup-command.out`.
- Exact implementation: `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCore/Output/JSONOutput.swift`.
- Exact semantic test: `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests/JSONOutputTests.swift`.
- Independent review: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-cli/findings/bc22-k103-ios76d-77-review.md`.

## Acceptance criteria

- Add a concise public README, docs, or release-note statement that date-valued JSON fields use ISO-8601 UTC strings, with an example such as `1970-01-01T00:00:00Z` or an `acquiredAt` value.
- Identify the behavior as the JSON date representation scripts should consume; do not imply that Unix or Apple-reference numeric timestamps remain a supported output alternative.
- Preserve the existing `.iso8601` encoder behavior and semantic test.
- Recheck the note against current iOS and Android session JSON. No device or runtime change is requested.
