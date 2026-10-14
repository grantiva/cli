# Candidate5 iOS coverage preparation

Status: **static preparation only**. No device, build, WDA, CLI, or test command has run from this worktree.

The canonical manifest contains 536 effective iOS keys, 39 exact iOS 27 supplemental keys, and the six iOS-actor CLI handoffs. The approved candidate5 early gate is joined only to IOS-117, IOS-118, and IOS-120 in `early-gate-joins.json`; all three joins remain proposed for slice review and are not rerun merely for this namespace. IOS-119 remains fresh work.

`capture-one.rb` preserves the approved collector semantics. Its only changes from the approved candidate5 early-gate collector are session `candidate5-ios` and an unresolved runner-home token. The collector and the IOS-001–009 batch template are intentionally non-runnable until root binds a fresh home and primary devices. Diffs, syntax checks, and hashes are retained adjacent.

The first coverage group is IOS-001–009. After it returns actual extra identities, IOS-010, IOS-019, IOS-011–018, IOS-020, and IOS-119 follow under separately bounded lifecycle/capacity/build/WDA reservations. `first-batch-clauses.json` preserves the canonical literal clauses; `first-batch-bindings.json` records fixture names, ordering, isolation, and protected-device rules; `first-batch-command-units.json` records exact prepared commands or the dependencies that must exist before command materialization.
