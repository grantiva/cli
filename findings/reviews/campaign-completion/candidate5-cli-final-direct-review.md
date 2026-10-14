# Candidate 5 CLI final direct-row review

**Scope:** independent read-only review of direct ordinals 301–425, the eight earlier PENDING dispositions changed since the through-300 review, and the narrow B-I19.2/.3 evidence-link correction. I compared the current ledger with the canonical candidate 5 clauses and inspected retained command, stream, identity, source, and accepted smoke/source-join evidence. No command, test, build, or device operation was run.

**Spec verdict: NOT APPROVED AS GRADED. Evidence-quality verdict: NOT APPROVED.** The ledger currently reports **421 PASS / 1 PENDING / 3 N/A**, but ten PASS rows in ordinals 301–425 lack clause-matching evidence. The independently supportable direct-row totals are therefore **411 PASS / 11 PENDING / 3 N/A**. This is an evidence-grading defect, not a demonstrated product failure.

## Reviewed group counts

| Group | Ledger claim | Independent result |
|---|---:|---:|
| Batch 13, ordinals 301–325 | 25 PASS | 23 PASS, 2 PENDING |
| Batch 14, ordinals 326–350 | 25 PASS | 22 PASS, 3 PENDING |
| Batch 15, ordinals 351–375 | 25 PASS | 25 PASS |
| Batch 16, ordinals 376–400 | 25 PASS | 22 PASS, 3 PENDING |
| Batch 17, ordinals 401–425 | 24 PASS, 1 PENDING | 22 PASS, 3 PENDING |
| Earlier changed dispositions | 8 PASS | 8 PASS |

The current ledger SHA is `7e734264f90d6509332dbe0f94de96d075c1736c9d1b4964f17864c3a9136641`. Batch verdict SHAs 13–17 are `1c11f774aa11c39bd63e142b5ca67ad484a88ad41bd9acef695b277edeed64bf`, `8adbd46bbe2004b9fd563d8bd920a4ff37763582e0b0f5d83eb6fd3e72741d54`, `4cae6ea2ba6012c5bc2f2dcfc9c13a422ba295f04b7c110cdffefe0d8bfb57a1`, `0484f07d7222344df360cd47dd9f28422f219737c780d0500cbc27ba46a6c8eb`, and `29ca0145e067bf80d9b1a85496e8196f4e4a7e0cf8b09781403c0cae75e538f0`.

All 125 ordinal keys match the canonical flattened order. Their assessments reference 228 command records; every referenced command and adjacent identity record exists and binds frozen candidate manifest SHA `191e59afdca010e488f1825d5064fc05facde89f065e71bac9e1ecee91c3d30c`. Existence and identity binding do not cure the clause mismatches below.

## Rows that must remain pending

- **B2-K100.1 (ordinal 336):** `resources.command.json` exits 2 because Python cannot open the requested client script. It does not exercise either MCP resource, protocol error typing, valid traffic after malformed traffic, or the required test path. No accepted source/smoke join covers those exact resource-read clauses.
- **B2-K101 (337):** `malformed.command.json` exits 2 on the same missing client-script fixture. It produces none of the required `-32700`, `-32600`, echoed-ID, id-less-message, or subsequent-valid-traffic observations.
- **N2-10 (341):** the schema capture exits 1 with a traceback. The successful source grep does not establish the public init warning, doctor advice, and every MCP schema description required together by the clause.
- **N2-20 (343):** the sole source command exits 2 because `Sources/GrantivaCore/Record` does not exist. It proves neither a malformed non-video-track test nor the required recorded-and-filed alternative.
- **B3-L31 (372):** the only command exits 2 because its workflow path is wrong. Exact-tree inspection shows the intended workflow text and test still exist, but the clause also requires the clean-home CI step to have passed; the failed capture does not prove that event.
- **N3-16 (378):** the only docs-source command exits 2 on a missing `findings/help` path. The broad docs smoke proves the help corpus and selected public-note checks, but it does not enumerate every round-3 public addition or prove the no-runner-lineage clause.
- **B4-L75.1, B4-L75.2, B4-L75.3, and B4-L75.5 (397–399, 401):** every runtime command exits at device selection with the protected manually created `iPhone 18 Pro` ownership refusal. None reaches cycle parsing, so none prints the required nested, root, screens, absolute-path, or `/tmp`/`/private/tmp` cycle spelling. Source proof cannot replace these clauses' explicit runtime-output requirements. These remain iOS runtime handoffs.
- **B4-L85.5 (420):** the ledger correctly leaves the root-owned final full-campaign gate PENDING. This review does not promote it.

The six original iOS-actor CLI handoffs—CLI-048, CLI-049, CLI-061, CLI-064, CLI-066, and CLI-083—remain separate from these 425 direct-row totals and are not approved by this review.

## Earlier pending resolutions

All eight changed dispositions are supported:

- **CLI-108, CLI-144, CLI-146, CLI-148, CLI-105, and CLI-153** now have fresh clause-specific captures with the expected diagnostic/exit behavior; their first pending attempts remain preserved.
- **CLI-091 and CLI-156** use the exact owned iOS 26 target and valid frozen prebuilt fixtures. Five commands total exit 1 with exactly the authentication error, empty stdout, and byte-identical simulator inventories before and after. The corrected `CLI-auth-prevalidation-source-run-2` inspection proves authentication occurs after target/artifact validation but before boot/build. Their earlier attempts and stale-path source inspection remain preserved and excluded.

## Narrow B-I19 follow-up

The B-I19.2 and B-I19.3 assessment links now point to the existing `B-I19.1-run-1/docs.command.json`. Their N/A grades remain valid only with the independent frozen-source join recorded in the through-300 review: `ImageDiffer.swift` SHA `7fa22ba0b09b491ae83a352e616e092dc5c36119516eefbe9b9cad65c8d4da27` retains `labDistanceSum / Double(diffCount)`, and the candidate packaging diff does not include that implementation. The corrected link alone proves the documentation, not the unchanged averaging implementation.

No additional material gap was found in the remaining 114 rows of ordinals 301–425.
