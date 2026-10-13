# Task 9 source-window closeout review

**APPROVED for independent slice consumption as NONPASS evidence.** The aggregation preserves the failed Swift full-suite result and does not grant a clean candidate/campaign verdict, assign row verdicts or authorize new execution.

This review binds exactly `findings/evidence/round4-coverage/source-window/closeout.json`, SHA-256 `ccc9aef180b8e45d44ad7f75e8dddcf09567559aa0aa19e85d14a43453fb31f0`. The artifact's `CLOSED_NONPASS_PENDING_INDEPENDENT_REVIEW` status is preserved; this external review supplies the independent disposition without rewriting it.

## Aggregation checks

- All 79 path/hash references in the closeout independently rehash correctly, including candidate, entry gate, inventory, components, command start/results/postflight, inspection summaries, diagnosis and attached reviews. Every command result's underlying stdout/stderr hashes also match.
- The command-key set exactly equals the approved 20-command inventory. The row-key set exactly equals its 51 rows. Every row retains the exact `literalInventoryRequirements`, exact ordered command mapping, separate-evidence clauses and provenance-join flag. No command is missing.
- Only `swift-full` is failed. Exactly B4-L82.1, B4-L82.2, B4-L82.5, B4-L84.4 and B4-L85.5 propagate that failed full-suite requirement. No focused pass or older Task 8 pass replaces it. The preserved diagnosis correctly retains `observedRuntimeInterleavingProven: false`.
- All 51 rows retain `resultVerdictAssigned: false` and `satisfiedHere: false`. All inventory `nonSourceWindowClauses` survive unchanged. Public, live, provenance and closeout obligations have not been converted into passes.
- The six inspection rows are exactly L70.1–.3, L74.1/.2 and L85.4. Their 165 referenced evidence files independently match sizes/hashes, and each summary reference and additional pending clause survives aggregation. L70.3's migration provenance and L85.4's live semantic-back/retention/appearance clauses remain pending. This aggregation review verifies integrity and routing of those inspections, not a new final semantic grade for each criterion.
- The hash-bound final proof records all three frozen repositories clean, with no tracked-entry issues, and exactly matches the previously reviewed Go component's final source proofs. Its candidate binding matches the closeout. No additional source command was run to reconstruct that final capture during this review.

## Component dispositions and routing

The prior independent Swift/focused-Go and Go-full/vet/L53 reviews support their retained command outcomes. The AND-111 command points to the actual start/result and acceptance hash `d0bc4396e95c2c4bdfdf633afbab7bc3c410b4e2c96848508d03726ff22cd921`; the separate `task9-and111-evidence-review.md` approves its raw compile-only evidence with stated endpoint-observation limits. That review was completed after closeout preparation and supplements this review even though it is not in the immutable closeout's two-entry `reviews` array.

This is an evidence map, not a new ownership table. Existing approved key ownership and destinations continue to govern: CLI receives its source/provenance evidence, iOS receives PC.5's source half and its platform/join evidence, and Android receives AND-111. The iOS-actor CLI handoffs remain CLI-owned keys; there is no additional result key or denominator change. Consumers must use the established execution-key manifest and slice briefs together with this aggregation, rather than infer owners from which controller ran a command.

Inherited source criteria and other campaign requirements outside this bounded 51-row inventory are not declared completed here. Source-only inspections cannot satisfy later live/public requirements, and the L53 scratch binary cannot replace the separate frozen installed-runner control or candidate provenance. The current full-suite failure also cannot be converted into a clean result by the otherwise valid Task 8 entry gate.

## Limitations and review boundary

The component reviews' limits remain: Go nonverbose package output does not establish every case unskipped; omitted cache/build contents are retained at their declared original locations; AND-111 before/after snapshots are not a continuous event trace. No new missing reference, dropped mapped requirement or fabricated row verdict was found in this closeout.

No test/build rerun, device query, network operation, source edit, matrix grade or retry was performed. Only local evidence/reference checks and existing governing documents were used; only this review document was added.
