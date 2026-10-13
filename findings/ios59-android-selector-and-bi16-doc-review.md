# Scoped review: iOS 59, Android selector/config batches, and B-I16.2 documentation disposition

Candidate provenance: CLI `8f2cff67`; runner `fd9d8e8`. No product edits or live calls.

## iOS attempt 59 — B2-K83

**Pass supported.** Scalar and mapping `runFlow` forms each return two screens in the required order and retain distinct `FromSub.png` and `Main.png`. The no-screenshot subflow retains only `Main.png`. Missing and cycle cases exit 1 with precise runner validation errors; the duplicate case exits 1 with a precise config error and does not overwrite a capture. Exact-head `FlowStagingTests` pins scalar/mapping expansion, ordering, missing/cycle handling, and duplicate rejection.

The wrapper's `bad=3` is a harness expectation error: it expected usage exit 64 for all three negative cases, while the candidate deliberately reports these staging/config-validation failures as exit 1. B2-K83 requires that missing/cycle retain their existing errors and duplicate names be rejected or disambiguated; it does not require exit 64. Preserve the actual exits and wrapper mismatch, but do not downgrade the row.

## Android B2-K109 and B-C08.2

Both passes are supported.

- B2-K109's happy run preserves timed visible, timed notVisible-by-ID, exact-text, timed visible-by-ID, and no-timeout forms. The report identifies timed forms as `extendedWaitUntil`, while the no-timeout form remains `assertVisible`. The negative takes 2052 ms and reports `not visible within 2s`. Exact-head parser/generator excerpts cover the staged timeout/selector forms.
- B-C08.2 executes all five ID forms named by the criterion: tap, assertVisible, assertNotVisible, scrollUntilVisible, and extendedWaitUntil. Each appears with its ID in the runner log and passes. The retained platform-independent source/tests establish the same generation semantics for both platforms.

## Android selector-failure complements

- **B2-K02 [android]: supported.** The exact-assert corpus and new missing-tap corpus name the selector, include one cause, include closest Android texts, and use the hierarchy/MCP remediation rather than exposing raw transport output.
- **B2-K03 [android]: supported.** The new fail-early run has exactly one failed command and three later skipped commands without durations. Console totals/table and report, JUnit and Allure statuses agree.
- **B2-K01 [android]: still partial.** Joining the earlier batch supplies indexed text tap, percent point tap, and percent start/end swipe; the complement adds point-based doubleTapOn and longPressOn, all with nonblank live/summary/log descriptions. No retained runtime command in these two batches uses an **absolute** start/end swipe, which the literal criterion also names. Exact source formatter tests do not substitute for that requested runtime variant. Keep B2-K01 ungraded until an already-retained exact absolute-swipe output is identified or that single variant is run.

## B-I16.2 formal Task 6 disposition

This is a **product documentation omission**, not an obsolete matrix expectation.

The behavior is user-visible and compatibility-sensitive: new captures/baselines use literal spaces, old `%20` baseline names remain readable, and approve migrates them. Exact-head implementation/tests and attempt57 prove all behavior clauses. The only missing clause is the public change note.

`CHANGELOG.md` was removed by #179. Binding matrix lines 924-925 explicitly substitute README, public docs, or release notes for CHANGELOG criteria. At `8f2cff67`, recursive README/public-doc searches find no description of literal-space artifact names, `%20` compatibility, or approve-time migration. `.github/workflows/release.yml` uses `generate_release_notes: true`, but that future release mechanism is not itself a note for this change; the candidate is not tagged with a release containing one, and the exact candidate tree contains no release-note artifact. Git commit subjects and source comments are not public product documentation under the ruling.

Task 6 should retain the criterion and classify B-I16.2 as a documentation failure with runtime/source behavior passing. Minimal correction: add one public README/docs/release-note sentence stating that screen artifact filenames keep spaces, existing `%20` baselines remain readable, and `diff approve` migrates them. This is not a matrix correction because the requirement and substitution rule remain coherent after #179.
