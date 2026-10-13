# Task 9 frozen-source inspection report

Status: **SOURCE-ONLY EVIDENCE SUPPLIED; NO ROW VERDICTS ASSIGNED.** This bounded window inspected exactly six rows: `B4-L70.1`, `.2`, `.3`, `B4-L74.1`, `.2`, and `B4-L85.4`.

The immutable evidence root is `findings/evidence/round4-coverage/source-inspections/`. Its manifest is `manifest.json`, SHA-256 `8cb7738708e8c2e9ab78e0b8ce23d6780b15951957817c073f4d4b62b5f3b86e`. It binds candidate `findings/evidence/round4-coverage/candidate.json`, SHA-256 `d833797d30a794d8cfe9d2dc4646329d4f791667eb8dfa5d17cf417d827f744e`, the literal canonical matrix, and the approved source-window inventory.

## Frozen source proofs

- CLI inspections used only `/Users/kyle/Developer/grantiva-cli/.worktrees/release-round4-candidate3` at exact HEAD `6ba12ed37658228a3ce87cb64e1f5d88dda38e07`. Its status remained empty and its tracked tree remained SHA-256 `38f8c40f34c3f51f77cb0a63123b64499eeab9d83d286936b93a6dbe2c276341` across every CLI row.
- Demo inspection used only `/Users/kyle/Developer/landmarks-demo/.worktrees/release-round4-candidate2` at exact HEAD `84af7581b75134b0e417b254e4317d565f7b73c6`. Its status remained empty and its tracked tree remained SHA-256 `88223c745c17119bf3f1d59515e89edd9381d27b40a4f6b67355b4158f6c85e6`.
- Every row records before/after `git rev-parse HEAD`, `git status --porcelain=v1 --untracked-files=all`, and `git ls-files -z` argv, cwd, API-key-unset state, timestamps, exit, complete raw stdout/stderr, hashes, and derived tracked-tree proof. Every cited file has its own byte count and SHA-256.

## Source observations

- `B4-L70.1` supplies the frozen README note and implementation path. The note says baseline/capture/diff names keep ordinary characters such as spaces literal, encode path-unsafe characters, retain legacy percent-encoded lookup, and migrate on approval. `BaselineStore.swift` implements current and legacy names, fallback lookup, migration on save, decoding, and current/legacy canonical recognition.
- `B4-L70.2` supplies the exact public and implementation lines showing working legacy baselines need no manual rename. Literal `%` becomes `%25`, removing the legacy ambiguity while fallback lookup remains.
- `B4-L70.3` freshly rechecks that public note against `legacyFileName`, `existingFileName`, `isCanonical`, percent decoding, and approval-time legacy removal. Retained migration/runtime evidence is still a provenance join; it was not copied or regraded as fresh output.
- `B4-L74.1` supplies the frozen `docs/mcp.md` statement that date-valued JSON fields use ISO-8601 UTC strings, including `1970-01-01T00:00:00Z`.
- `B4-L74.2` supplies the adjacent public contract that scripts should consume this representation and that numeric Unix and Apple-reference timestamps are not output alternatives.
- `B4-L85.4` supplies the frozen demo-source half only. `PersistentTabContainer.swift` uses public `UITab`/`UITabBarController`, ordered Landmarks/Favorites/Deep Links tabs with `map`/`heart`/`link` symbols, literal `heart` accessibility identifier, retained hosting controllers, and selected-tab synchronization. `ContentView.swift` supplies separate `NavigationStack` paths for all three tabs, and `Navigator.swift` supplies distinct persisted paths and selected-tab state. The bounded negative search found no private selector calls, coordinate substitution, selector aliases, accessibility-label rewrite, or private API marker in those files.

`B4-L85.4` cannot be final-graded from this source evidence. Its owned-iOS-26 semantic-back acceptance without coordinates, switch-away/switch-back retention, and live label/order/symbol/geometry observation remain pending.

## Artifact counts and hashes

The root contains 166 immutable files: 47 command metadata records, 94 raw stream files, 12 before/after repository proofs, six cited-file manifests, six row summaries, and one root manifest. Row summary hashes are:

- `B4-L70.1`: `1a809c6ffe81a5a8255d0e52f07ede6e964c4a1a36de860f7feddf0f99b8dcd4`
- `B4-L70.2`: `4b802b24c09aeaeb45d4bd10a4820d0f52eae254c9767449bc23b08e86f6f213`
- `B4-L70.3`: `040b4a80403c4feb8fa9a2fa2c61d6f04abeacbd0ef73f2728afb399e022080f`
- `B4-L74.1`: `2d35d08ace1be18045c5da75c65dad449579e982984435cf35f2406e0117608d`
- `B4-L74.2`: `d799ab329ca1abbedfe6a3111d5860612338c641806ce813118bf2899c10b3ea`
- `B4-L85.4`: `a8a10a59cf4c5b38e0a5626827412e3cba8fc9f50d8f2255f097c43004296b2e`

Only read-only `git`, `sed`, and `rg` commands ran against frozen source. `GRANTIVA_API_KEY` was unset. No source test, build, `go list`, device, network, CI, product edit, verdict assignment, commit, push, or reviewer dispatch occurred.
