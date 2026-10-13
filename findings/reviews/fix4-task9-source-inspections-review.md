# Task 9 fresh source-inspection evidence review

**Specification verdict: APPROVED for the six source-only evidence contributions. Evidence-quality verdict: APPROVED.** Fresh captured source supports the scoped observations, with accurate pending clauses and no row verdict assignment. No blocking finding was identified within this bounded inspection window.

This review does not complete the six rows, grade retained runtime evidence, approve the separate running test window, or authorize general slice dispatch. In particular, B4-L70.3's migration-evidence join and B4-L85.4's live requirements remain pending.

## Provenance and integrity

Independently recomputed manifest SHA-256 is `8cb7738708e8c2e9ab78e0b8ce23d6780b15951957817c073f4d4b62b5f3b86e`. All 165 declared evidence files match their byte counts and hashes; together with the manifest they are exactly the 166 files present, with no undeclared file. All six summary hashes match the manifest. Candidate `d833797d30a794d8cfe9d2dc4646329d4f791667eb8dfa5d17cf417d827f744e`, canonical matrix `09c054ed…`, and approved command-inventory `15437fda…` references match current bytes.

All 47 command records have expected exits, ordered timestamps, the appropriate frozen checkout as cwd, API key unset, and raw stdout/stderr hashes matching their streams. Commands are restricted to the recorded source reads and Git identity/inventory queries. The lone negative-search exit 1 is explicitly expected and has empty stdout/stderr; it is not a suppressed execution failure.

For each row, raw before/after HEAD agrees with its source proof, raw status is empty, and tracked-file inventories are byte-identical. Before/after derived proofs are equal: CLI `6ba12ed37658228a3ce87cb64e1f5d88dda38e07`, 340 tracked files, tree digest `38f8c40f…`; demo `84af7581b75134b0e417b254e4317d565f7b73c6`, 165 tracked files, tree digest `88223c74…`. Every cited source file was independently rehashed and matches its byte count and digest. Captured `sed` ranges were also independently compared to the corresponding frozen file bytes and match exactly.

These fresh command metadata and captures establish current source observations. No earlier passing result is imported, and `resultVerdictAssigned` remains false at both manifest and row-summary levels.

## Literal-clause assessment

| Row | Supported source contribution | Remaining boundary |
|---|---|---|
| B4-L70.1 | README explicitly describes literal ordinary filenames, legacy percent-encoded lookup and migration on approval; implementation shows current/legacy generation, lookup fallback and approval save/removal. | Evidence contribution only; no result assigned. |
| B4-L70.2 | Public text explicitly says working legacy baselines need no manual rename; captured code supports fallback and `%25` encoding. | Evidence contribution only; no result assigned. |
| B4-L70.3 | Fresh public-note and exact-implementation recheck covers canonical/current/legacy names, decoding and migration removal. | The literal retained-migration-evidence provenance join remains pending; no old runtime grade is reused. |
| B4-L74.1 | Public MCP docs name ISO 8601 UTC strings and the exact epoch example, plus affected fields. | This is the documentation clause, not a claim of fresh runtime JSON verification. |
| B4-L74.2 | Adjacent public text names the representation scripts should consume and explicitly excludes numeric Unix/Apple-reference output alternatives. | Evidence contribution only; no result assigned. |
| B4-L85.4 | Frozen demo files show public UIKit tabs, literal `heart` identifier, ordered labels/symbols, retained hosting controllers, separate NavigationStack paths and restoration state. | All specified live iOS 26 controls remain mandatory. |

For L85.4, the inspected container uses public `UITab` and `UITabBarController`; `heart` is set on the Favorites tab model, and update code retains hosts/tabs while synchronizing selection. The content view binds separate Landmarks, Favorites and Deep Links paths, while Navigator retains and restores those paths independently. The bounded negative search found none of its specified private-selector, coordinate-substitution, alias or accessibility-label-rewrite patterns in these three files. That scoped negative result is not a claim of exhaustive whole-repository absence.

The live portion must still establish the literal heart identifier in both selected/unselected states, label/order/symbol/geometry, independent stacks and switch-away/switch-back retention, and semantic-back acceptance without coordinate taps. Source declarations cannot establish those runtime observations. The manifest's pending clauses and explicit prohibition on final-grading B4-L85.4 preserve that boundary.

Only existing evidence and frozen source bytes were read or hashed for this review. No test, build, Git/source command against the checkouts, device/process operation, network access or evidence modification occurred. Only this review document was written.
