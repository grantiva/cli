# Task 9 Swift and focused Go evidence review

**Evidence integrity: ACCEPTED, preserving Swift full-suite NONPASS.** Ten focused Swift commands and four focused Go commands have passing command evidence. The full Swift command failed. This review does not approve the candidate, complete the source window, assign matrix grades, or authorize retries.

## Integrity and execution checks

All 57 archived Swift files and all 21 retained Go-focused files were compared byte-for-byte with their original files under `/private/tmp/grantiva-round4-source-window-1stf8uih`. Every retained evidence file's size/hash matches its manifest entry. Manifest hashes match the archive records:

- Swift: `2eb243c67f32134981819589589403165e7a80337bd38774a144d3a8afd4e870`
- Focused Go: `2c9d6ac8fdc04f860701bd939bf05b11f657050df9a685097909a76e3130f523`

Each command's literal argv matches the pinned inventory. Candidate binding is `d833797d30a794d8cfe9d2dc4646329d4f791667eb8dfa5d17cf417d827f744e`. Command start/postflight proofs match manifest before/after proofs, with exact frozen HEADs, clean status and no tracked-entry issues. Recorded CLI tree hash is `38f8c40f34c3f51f77cb0a63123b64499eeab9d83d286936b93a6dbe2c276341`; runner tree hash is `0441413eb528a92aa1702a76aca00f700b34034f780d2e9f5941d1960a863173`. Raw stdout/stderr hashes and byte counts independently match each result. No command timed out.

All Swift command home pairs are distinct command-local paths, and every postflight reports both roots absent with no entries. The API key is recorded unset. Focused Go uses explicit package paths, `-count=1`, and command-specific caches. The Go cache contents are intentionally not copied into the repository archive; their hash inventory remains in the manifest and original cache directories remain local. This review verifies retained command evidence, not every omitted cache file.

## Focused Swift coverage

Every concrete Swift test named in the approved inventory has an explicit passing test-case line in its assigned focused output. Counts below count actual passing case lines, not repeated bundle summaries or zero-test sibling targets.

| Command | Passing cases | Exit |
|---|---:|---:|
| swift-l53-targets | 15 | 0 |
| swift-l67-doctor | 4 | 0 |
| swift-l74-json | 1 | 0 |
| swift-l75-cycle | 42 | 0 |
| swift-l81-doctor | 36 | 0 |
| swift-l82-attachment | 103 | 0 |
| swift-l84-orphans | 118 | 0 |
| swift-l85-selector | 146 | 0 |
| swift-pc5-launch-report | 5 | 0 |
| swift-ej3-paths | 49 | 0 |

Focused outputs end with some zero-test sibling bundle summaries; those do not erase the real selected cases earlier in the same raw streams. No missing inventory-named Swift case was found.

## Focused Go coverage and reporting limit

`go-l53`, `go-l83`, `go-pc9`, and `go-pc10-13` all exit 0 with passing package lines and passing postflight. Their exact regex filters select the inventory's named tests in the frozen runner source. The expected functions exist in the explicit packages, have no build constraints in those files and no direct skip calls in their bodies. The L83 table includes both UIAutomator2 and DeviceLab driver branches. The PC10–13 command reports successful results from both required packages.

These approved commands use ordinary nonverbose `go test` output, so raw logs report package success rather than per-test/subtest events or assertion counts. Exact filters plus frozen matching test declarations support the selected coverage, but this review does not invent individual observed Go test counts or separate subtest verdicts. No rerun is requested to improve verbosity.

## Swift full-suite failure remains authoritative

`swift-full` exits 1 without timeout. The raw case records contain 2,023 passing cases and exactly one failed case, totaling 2,024. Bundle totals are 281 + 975 + 667 + 101, with the one failure in GrantivaCoreTests. The exact failure is `SimulatorManagerTests.testBootWaitingOnATwinsBootIssuesNoSecondBoot`, `SimulatorManagerTests.swift:503`: `bootedByGrantiva` is nil instead of `Optional(true)`. The test's earlier Booted-state, one-boot, record unwrap and active-state assertions produce no failures.

The full result's stdout hash is `3856014c71f664d7ee14ff5fdf0fc5a35df6183ea5bd2b543f156b5ff2a781ff`; stderr hash is `b87df8997b352327aa1a773f862cf3d5f6303fc3f64385c5aaa94585afabfe62`. The failure is a test assertion, not a compiler failure or contaminated-home failure. Swift manifest status is correctly `CLOSED_NONPASS_UNREVIEWED`, with the preserved terminal reason `command-exit-or-timeout`; that generic reason must be interpreted alongside the specific exit and raw assertion.

The inventory's full-suite components for B4-L82.1, B4-L82.2, B4-L82.5, B4-L84.4 and B4-L85.5 remain unsatisfied. Their focused passes do not replace the independent full-suite requirement. This is not evidence that each corresponding feature regressed. All source-window row `satisfiedHere` fields must remain false pending their independent reviews and joins; this review changes none.

## Diagnosis and K67 triage assessment

`findings/reviews/fix4-task9-twin-boot-failure-diagnosis.md` correctly separates observed failure from an inferred schedule. Static inspection of the frozen source confirms the proposed race is admissible: `reserve` reads devices before acquiring the registry lock; `prune` removes an active record against a stale Shutdown snapshot; replacement initializes the ownership flag nil; and the manager's refreshed Booted branch activates without setting true. The test finisher's prior true activation cannot repair a record subsequently deleted/recreated. The teardown code requires true to shut down an already booted device, supporting the stated potential consequence without demonstrating a live leak.

The raw log has no scheduling trace, so it cannot establish that this exact interleaving caused this execution. The diagnosis explicitly says so. Its proposed deterministic closure/barrier regressions are appropriate later-fix work, not tests already performed. No live double-boot or teardown failure is established here. I did not independently audit the historical retry evidence; it is not used to accept or discount the current result.

Linking the issue to K67 is justified: its existing acceptance text explicitly requires the final active record to retain `bootedByGrantiva: true` and covers twin boot waiting. Preserve the original double-boot fix and describe the ownership-loss mechanism as a linked regression/addendum. The source assertion contradicts the desired invariant; it must not be relabeled as an executed failure of K67's separate five-iteration public/live criterion. Related live keys remain ungraded.

## Remaining boundary

No corruption or missing retained raw/metadata file was found. Nonverbose Go events and omitted archived cache contents are the specific reporting limits above. Go full/vet, L53 scratch control, AND-111 and all other required public/live/provenance joins are outside this review and remain independent work. The Swift failure must survive any later evidence assembly unchanged.

Only evidence hashes, local source text and existing records were read. No source command, test/build rerun, device query, network call, candidate change, helper edit or matrix grade was performed. Only this review document was added.
