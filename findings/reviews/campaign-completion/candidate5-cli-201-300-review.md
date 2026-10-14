# Candidate 5 CLI direct ordinals 201–300 review

**Scope:** independent read-only review of direct ordinals 201–300 only, corresponding to batches 09–12 in the cov6 CLI ledger. I compared every key with the canonical candidate 5 required-key entry, read each assessment, checked its referenced raw command and adjacent identity record, and inspected the conditional N/A preconditions in the exact frozen release tree. No command or test was rerun.

**Verdict: APPROVED WITH TWO EVIDENCE-LINK CORRECTIONS.** The reviewed set contains **97 PASS and 3 N/A**. The grades match the canonical clauses and actual evidence. B-I19.2 and B-I19.3 name a nonexistent `source-inspection.command.json`; their N/A preconditions are nevertheless independently established by the frozen candidate source and manifest. That filename defect should be corrected before a mechanical final evidence audit.

## Batch verdicts

| Batch | Direct ordinals | Reviewed result |
|---|---:|---:|
| 09 | 201–225 | 25 PASS |
| 10 | 226–250 | 25 PASS |
| 11 | 251–275 | 24 PASS, 1 N/A |
| 12 | 276–300 | 23 PASS, 2 N/A |

The results ledger SHA is `69df833f4eed84e9d1c67b1ab80e41809889b3beb939e96cd0a3df835cf9f517`. Batch verdict SHAs are `8bcf6dfe38513677a914cce340ecfa72988b4faa785b0ea70ebe711524edf7da`, `787437e47048eacc698e0d6c32e13a903c178647f3a16b0c00f8a5e46196c18b`, `12de68522d70ff8c6d88930375ac08162bcccf2d7aca026e08ad2ffb9916ce98`, and `121cc6859b3e74404f04cad679ff84defa70931ac41bc28d8203667eadaea0ae` respectively.

All 100 keys occur in the canonical candidate 5 CLI slice at the claimed flattened direct ordinal. The assessments reference 113 command captures. Except for the two B-I19 filename defects below, every referenced command exists, has a matching adjacent identity record, and binds candidate manifest SHA `191e59afdca010e488f1825d5064fc05facde89f065e71bac9e1ecee91c3d30c`. Expected nonzero public-negative captures are graded from their actual diagnostic and output, rather than treated as command failures.

## N/A preconditions

- **B-D05.2:** N/A is correct. Its condition applies only to an Unreleased section in `CHANGELOG.md`. The frozen candidate release tree has no `CHANGELOG.md`. B-D05.1's recorded inspection command SHA is `30ffbcc791a81536a8f196f8fee9018ee263d0861f315eacba72f4b4cc1d16dd`; its argv includes the absence probe, though its shell lacks fail-fast behavior. I independently confirmed the exact tree precondition, so the N/A does not depend on the command's final pipeline status alone.
- **B-I19.2:** N/A is correct. The frozen implementation still calculates mean CIE76 only across differing pixels: `labDistanceSum / Double(diffCount)`, with zero for identical images. `Sources/GrantivaCore/Diff/ImageDiffer.swift` SHA is `7fa22ba0b09b491ae83a352e616e092dc5c36119516eefbe9b9cad65c8d4da27`; the candidate manifest's packaging diff does not include this file. The conditional “if averaging is changed instead” branch did not occur.
- **B-I19.3:** N/A is correct. The candidate behavior is the doc-only branch described by the clause, so no added ImageDiffer unit test is required. B-I19.1's fresh README capture proves the documented differing-pixel definition; its command SHA is `707aede1c830bb5f79f16fd92104f748fbbd035cea109b718295811c54fe9be2`, and the frozen README SHA is `740f44373d5006b51bfd7429decaf2004b9b7265f9b30e075fe1e1b2bd249ab1`.

## Material evidence-link correction

`B-I19.2-assessment-2/verdict.md` and `B-I19.3-assessment-2/verdict.md` both cite `B-I19.1-run-1/source-inspection.command.json`, which does not exist. The retained fresh capture is `B-I19.1-run-1/docs.command.json`. That docs capture proves B-I19.1, while the conditional N/A decisions additionally require the frozen `ImageDiffer.swift` inspection and candidate manifest packaging-diff boundary recorded above. The grades remain correct; the assessment links alone are incomplete.

No other material gap was found in direct ordinals 201–300. This review does not cover ordinals through 200 or after 300, device-runtime handoffs, or pending canonical rows.
