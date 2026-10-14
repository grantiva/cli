# L87 runner source/spec review

Status: **APPROVED for source and test scope at commit `9c18b962a0d85bcbb76fb8141fdd4aae97d28389`; full-suite, vet, CI, packaging and live acceptance remain separate gates.**

Reviewed the exact commit diff from runner base `ba9008f4b2cd2c7320a9c46e04faed612b0958a2`. The commit changes only:

- `pkg/driver/wda/driver.go`
- new `pkg/driver/wda/back_button_collision_test.go`
- the shared test server in `pkg/driver/wda/falsegreen_test.go`

The worktree's only additional state is untracked `findings/` evidence; it is not part of the reviewed product commit.

## Source decision

The implementation is bounded to literal text taps. `findElementForTap` still routes relative, nonzero-index, checked and ID selectors to their established paths. `findElementForTapWithContext` still routes regex text directly to page-source matching before the new query. Only after those guards does it try a class-chain query requiring all three properties: the requested label, `identifier == 'BackButton'`, and button type. Failure falls through to the unchanged broad interactive lookup.

The new query preserves:

- case-insensitive plain text and case-sensitive `Exact` behavior;
- existing state filters;
- quoted apostrophe and backslash escaping;
- ordinary same-label fallback when no semantic back button exists;
- explicit ID, index, relative, checked and regex routing.

No assertion path, coordinate path, retry budget, timeout policy, application-node policy, demo source, or unrelated runner package is changed.

## Test decision

The tests are behaviorally discriminating:

- `TestTapTextPrefersSameLabelNavigationBackButton` gives the broad query `tab-first` and the semantic query a distinct `back-later` ID, then requires `back-later`; this would fail on the original generic-button implementation.
- The absent-back test requires the original broad `tab-first` fallback.
- The different-label test ensures a back identity cannot win without the requested label.
- The literal/state test checks exact case semantics, escaping and enabled-state predicate retention.
- Explicit ID and index tests assert no `BackButton` query is made. Existing routing and the package-wide WDA run cover the unchanged relative/regex paths.
- The shared recording server change preserves its existing boolean fixture behavior and adds distinct returned IDs only when requested by collision tests.

Retained author evidence is correctly bound to commit `9c18b962…`: focused `go test ./pkg/driver/wda -run 'Tap.*(Back|Explicit)' -count=1` passes, and uncached `go test ./pkg/driver/wda -count=1` passes in 95.420 seconds. These commands were not rerun during this review.

## Remaining gates

- Required uncached full runner suite and `go vet` on the reviewed tree.
- Runner PR CI and merge identity.
- Package using an explicitly reviewed `--version` argument; the version is script-supplied, not a runner source edit.
- Packaging-only CLI resource/stamp review, CLI CI, candidate freeze, and L87 owned-iOS live acceptance.

No source/spec change is requested.
