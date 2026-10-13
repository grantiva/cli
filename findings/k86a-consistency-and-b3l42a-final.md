# K86-a consistency ruling and B3-L42-a final review

## B2-K86-a — PASS on both platform halves

The same evidence rule applies to both halves.

- iOS attempt 102b supplies the exact handed-off runtime branch: a real detached runner reaches hierarchy, the conflicting run refuses quickly with ``grantiva runner start`` ownership and `grantiva runner stop` advice, and the live session remains usable until the exact stop. Attempt 64 supplies the current keep-alive-owner wording control.
- Android `B2-K86-a-handedoff-refusal-rerun2` supplies the equivalent exact handed-off runtime branch and retained current keep-alive control.
- Candidate `Tests/GrantivaCoreTests/SimulatorLeaseTests.swift:233-260` is shared platform-independent semantic evidence for handed-off versus keep-alive ownership messages, and explicitly asserts both iOS and Android handed-off forms. The dead/stale-owner branch is conditional classification behavior and does not require an additional destructive platform runtime after the live owner branches are established; the retained source behavior is sufficient under the plan's source-semantic rule.

Therefore the earlier Android full pass is consistent with closing the iOS half too. No extra dead-owner device run is required for either platform.

## B3-L42-a [Android] — PASS

The positive K24/K109 evidence and new negative complement now cover every clause:

- `B2-K24-exact-rerun1` proves live `diff capture --no-build` of the Clock screen with native `tap: {id: "clock"}` and `assert_visible: {id: "clock"}`, no unknown-id warning, the resulting capture, exact parser/generator semantic tests, CI evidence, and README `{id:}` documentation.
- `B2-K109-BC08-config-forms-rerun1` corroborates the wider live id-selector pipeline.
- `B3-L42-a-both-selector-negative-rerun1/assertions.json` has all six checks true. The exact native `tap` containing both keys exits nonzero, creates no capture, and reports `grantiva-android.yml:9: screens[0].path[0].tap: tap takes text or id, not both.` This names the config, step, both keys, and exclusivity.

The former partial finding is superseded.

## Attempt 109b status

Not reviewed as complete in this checkpoint. Plain and quiet captures exist and exit 0, but the directory currently has no verbose exit marker and `verbose.out` is empty. IOS-153 requires all three completed modes and byte-comparison after accounting for documented dynamic fields; grading from the in-progress snapshot would be premature. N3-12 is a different guarded default-device refusal row and is not established by these VRT captures.
