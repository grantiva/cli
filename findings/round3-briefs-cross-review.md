# Round-3 L64–L79 brief cross-review

Scope: read-only review of the 16 current briefs, `failure-disposition.json`, and the completed iOS/Android result mappings. No brief, result verdict, or controller matrix was changed.

## Findings

### 1. Completion status requires a Task 6 finalization check

Severity: conditional bookkeeping follow-up; not a current inconsistency.

`failure-disposition.json` still has `"provisional": true`. L64–L77 describe themselves as triage “during the incomplete round-3 coverage pass”; L78 says “during incomplete round-3 verification.” That language remains accurate now: iOS is complete, but Android is still 463/467 and Task 6 has not completed. L79's “during round-3 verification” wording is also compatible with the current state.

Recommended follow-up: only after Android and Task 6 finish, decide whether to set the disposition document non-provisional and update the brief status sentences consistently, for example: `Status: evidence-backed finding confirmed by completed round-3 verification.` Preserve narrower qualifiers such as L64's statement that it is not itself a round-completion result and L78's transient-cleanup characterization. No status edit is warranted yet.

### 2. L71 omits one row that the disposition and completed iOS ledger map to it

Severity: missing row mapping.

L71 declares `Rows: D2-08 [ios] (with D2-07 status contract)`. The disposition file also maps `B2-K25 [ios]` to L71, and the completed iOS ledger records B2-K25 as failing on the same absent-app `--no-build --no-launch` data-container lookup. This is an intentional shared defect rather than a duplicate finding, but the brief header and acceptance section do not name the second failing row.

Recommended correction: make the header `Rows: D2-08 [ios], B2-K25 [ios] (with D2-07 status contract)` and state that B2-K25's other compound legs remain independently retained. The disposition text already contains that qualification.

### 3. L75 omits its completed Android row and Android reproduction

Severity: missing row mapping and missing evidence path.

L75 declares only `B3-L20 [ios] (platform-independent source path)` and cites only iOS attempt79. The disposition file maps both iOS and Android B3-L20 to L75. The completed Android ledger independently fails B3-L20 with the same containing-file-relative `../` chain and cites:

`/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B3-L20-cycle-four-forms-rerun2/`

Recommended correction: list both platform rows and add the Android evidence directory plus its completed-ledger/reviewer reference. The shared Swift output-rewriting cause remains appropriate because both platform commands traverse that code.

### 4. L65's row notation is less precise than its disposition mapping

Severity: minor naming inconsistency.

L65 says `Rows: B3-L15.2` and separately says `Platforms: ios and android`. The disposition file and completed ledgers use `B3-L15.2 [ios]` and `B3-L15.2 [android]`. The evidence contains both platform captures, so there is no coverage gap.

Recommended correction: list both qualified row IDs in the header for consistency with L69 and L74.

### 5. L65's causal history is stated more strongly than its evidence supports

Severity: causal wording qualification.

The source and tests prove that the candidate intentionally emits/asserts the extra word `array`. They do not independently prove the historical claim that “the prefix/label correction retained a pre-existing message variant.” That may be true, but the cited evidence establishes current implementation alignment, not when or why the variant was retained.

Recommended correction: label that sentence as inference, or replace it with the supported statement: current source emits the variant and current tests encode it rather than the binding exact text.

## Severity vocabulary

The L64–L79 set uses only `contract` and `wrong-result`. Usage is internally coherent:

- `wrong-result`: L66, L76, L77, where an operation selects/signals/reports the wrong target or outcome.
- `contract`: the remaining briefs, which concern exact output, lifecycle timing/state, documentation, or report aggregation contracts.

No severity rename is required. The side findings L76 and L79 correctly identify that they do not invent base matrix rows.

## Cross-brief overlap

No briefs should be merged:

- L70 and L74 are separate public-documentation omissions for baseline filenames and JSON dates.
- L64 and L68 both involve launch timing but cover different failure modes: matching fatal-crash suppression versus detached app readiness.
- L72 and L78 both involve SIGINT but cover distinct ownership boundaries: startup exit normalization versus delayed simulator log-child cleanup.
- L71's D2-08/B2-K25 overlap is one shared product defect and should be represented by adding B2-K25 to L71, not by creating another brief.
- L65 and L69 reproduce on both platforms but each has one shared implementation/output defect, so their single cross-platform briefs are appropriate.

## Evidence-path audit

The sampled literal paths for L64, L65, L74, L75, L77, L78, and L79 exist in their named slice worktrees. In particular, L64's older crash capture correctly uses `report/flow-000.json`; it should not be mechanically rewritten to the newer `report/flows/flow-000.json` layout.

The material evidence omission is L75's missing Android reproduction described above. L71's omission is a row/header mapping problem; its existing attempt65/65b evidence supports both mapped iOS rows. No broken cited path was found in the reviewed briefs.

## Mapping accounting

Every L64–L79 identifier is referenced by at least one current disposition row. Conversely, all rows whose disposition begins with L64–L79 map to a brief, with the two header mismatches above:

- L71 disposition rows: D2-08 [ios], B2-K25 [ios]; brief names only D2-08.
- L75 disposition rows: B3-L20 [ios], B3-L20 [android]; brief names only iOS.

Task6-only corrections such as MCP-078, IOS-058, B3-L55.1, X-013, IOS-016, B2-K103, IOS-153, and B2-K19 appropriately have no product brief. They are expectation corrections documented in the disposition file and the separate iOS correction draft.
