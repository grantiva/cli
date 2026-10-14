# Candidate 5 full-coverage readiness

Status: candidate 5 frozen; early iOS26/27 gate passed and IOS-117/118/120 accepted. Broad smoke remains active; full-coverage homes/device allocations stay pending until smoke cleanup and review. No candidate 4 runtime verdict or raw capture is transferred.

## Canonical inventory and freeze binding

The key inventory remains `findings/evidence/completion-coverage/required-keys.json` (1,489 effective keys: CLI 431, iOS 536, Android 522) in the order of `docs/superpowers/plans/2026-10-13-round4-coverage-matrix.md` (SHA-256 `09c054ed467cac27d2c9e0ddababc95868d766a5e61bf110bfb47278f38dc166`). The candidate5 copy at `findings/evidence/completion-candidate5/coverage/required-keys.json` binds manifest `191e59afdca010e488f1825d5064fc05facde89f065e71bac9e1ecee91c3d30c`; key arrays and matrix binding remain unchanged. The six CLI handoffs remain CLI-048, CLI-049, CLI-061, CLI-064, CLI-066 and CLI-083 and are joined once from the fresh iOS slice.

Before launch, bind every helper to the immutable candidate 5 manifest, its QA binary/bundle/installed-runner hashes, and fresh actor homes. Refuse `PENDING`, candidate 4 manifest hashes, existing evidence destinations, or a nonempty result root.

## Fresh destinations and sessions

Use a new controller-owned root beneath `findings/evidence/completion-candidate5/coverage/`:

| Slice | Evidence destination | Session | Runner home |
| --- | --- | --- | --- |
| CLI | `coverage/cli/` | `candidate5-cli` | fresh clone at `<candidate5-coverage-scratch>/cli-runner-home` |
| iOS | `coverage/ios/` | `candidate5-ios` | fresh clone at `<candidate5-coverage-scratch>/ios-runner-home` |
| Android | `coverage/android/` | `candidate5-android` | fresh clone at `<candidate5-coverage-scratch>/android-runner-home` |

Set both `GRANTIVA_RUNNER_HOME` and `MAESTRO_RUNNER_HOME` to the slice home and unset `GRANTIVA_API_KEY`. Allocate new campaign-owned device names and IDs after smoke cleanup; do not reuse cov5 IDs or target protected owners.

## Execution queue after freeze

1. Verify the frozen manifest and QA binary, bundle, packaged runner, installed runner, demo app/APK, source SHAs, clean trees, fresh homes, empty result roots, and protected inventories. Run the prepared early iOS 26 stock `run --no-build` and `diff capture --no-build` gate first; both must pass before the broad queue.
2. Start device-free CLI concurrently with only one serialized live slice. Rebind the approved `capture-one.rb` collector from the cov5 CLI package; retain its exclusive outputs, process-group timeout cleanup, exact cwd, both homes, session and per-command identity capture. Reuse the existing 17-batch ordering description, not its candidate 4 raw results or verdicts.
3. CLI direct batch 1 is the first 25 direct keys in canonical order: CLI-001, 002, 003, 004, 005, 006, 007, 008, 009, 010, 123, 124, 125, 011, 012, 013, 014, 015, 016, 017, 019, 020, 021, 126 and 023. For each literal command, invoke the rebound collector as:
   `ruby <candidate5-capture-one.rb> <fresh-row-dir> <label> <exact-fixture-cwd> --timeout <row-timeout> -- /Users/kyle/.grantiva-qa/bin/grantiva <arguments>`.
   Write a clause verdict only after the command finishes and retained stdout, stderr, exit, timeout, identity, fixtures and relevant before/after observations are inspected.
4. After the early gate, serialize iOS then Android live/compiler/load-sensitive groups (or the reverse if reservations require it). Device-free CLI may continue throughout. Never overlap the two live slices. Use the existing standing delegation, build-routing and reservation semantics; provision fresh owned targets and record actual UUIDs/serials rather than carrying old bindings.
5. Execute iOS and Android in canonical key order. Their first canonical batches are the first 25 entries in each `required-keys.json` slice: iOS starts IOS-117 through IOS-120, then IOS-001 through IOS-020 and IOS-121; Android starts AND-106 through AND-108, AND-001 through AND-018, AND-109, AND-146, AND-110 and AND-019. Commands and fixtures come from the matrix and already reviewed helpers, rebound only for candidate identity, session, home, evidence root and newly reserved device identifiers.
6. Reconcile exactly 1,489 keys plus the 39 separate iOS 27 qualifications. Keep environmental N/A/blocked decisions clause-specific. Run the final B4-L85.5 campaign join only after all slice joins, six handoffs and explicit limitations are present.

## Source evidence policy

Candidate 4 runtime evidence never supplies a candidate 5 runtime grade, including behavior expected to be unchanged.

The candidate 4 Swift source disposition is manifest-specific. Candidate 5 changes only the two packaged runner archives, `RunnerManager.swift`, and the matching two-value expectation maintenance in `RunnerManagerTests.swift` relative to CLI baseline `73cfa99d94a00bbc0fd6fce13a7d72b9d9c29226`; after freeze, a controller mapping may reuse current Swift full/focused evidence only for exact unchanged source/test contracts and unchanged inspected files. The `RunnerManager.swift` and `RunnerManagerTests.swift` deltas must be inspected and explicitly ruled as the version/stamp update plus matching test-constant maintenance before any affected Swift source clause joins. Rehash unchanged README/docs/demo source inspections before linking them. Do not rerun accepted suites merely to rename the campaign.

Runner source changed for L87, so candidate 4 Go source results and runner-source joins do not transfer. Candidate 5 must use the fresh focused, full and vet proofs bound to reviewed runner SHA `9c18b962a0d85bcbb76fb8141fdd4aae97d28389`, with reviewed-tree equality to the squash-merged runner tree, as recorded by the candidate 5 manifest. L87 requires its new tab-first distinct-ID regression coverage. Older unchanged-runner proofs may remain historical context only; any source clause must point to the new manifest-bound proof or a fresh exact-source mapping.

The unchanged demo/WDA artifacts may reuse build provenance after candidate 5 rehash and manifest identity verification. That establishes dependency identity only. Public commands, device behavior, lifecycle, screenshots, reports, MCP behavior, compile observations and final campaign joins all require fresh candidate 5 captures.
