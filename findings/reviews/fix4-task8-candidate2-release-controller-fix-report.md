# Task 8 candidate 2 release controller correction

## Scope

Corrected only `candidate2_release.py` before its first execution. No build, install, promotion, device operation, or candidate freeze was run. The pre-correction script is preserved in `task8-candidate2-release-fix-base/candidate2_release.py`, and the complete scoped diff is `task8-candidate2-release-controller-fix.diff`.

## Corrections

The release build now creates a separate fresh `swift-build-scratch` directory and passes the same explicit `--scratch-path` to both `swift build -c release` and `swift build ... --show-bin-path`. The returned products path must be inside that scratch directory. The existing `buildHome` remains the isolated runner home for those commands and must remain empty. Post-build evidence records the scratch path, its top-level contents, and the resolved products path.

Before invoking `grantiva runner install`, the controller now authenticates the prepared clone proof. It requires the exact `cp -cR` command from the owner runner home to the state runner home, exit 0, the expected scratch-owned destination, exact equality between `source-before.json` and `clone-before-upgrade.json`, and exactly 8,593 entries. Every current clone entry must then match its recorded file size and SHA-256 or symlink target. Existing post-install cache preservation and bundled WDA checks remain unchanged.

Demo provenance is pinned to `84af7581b75134b0e417b254e4317d565f7b73c6`. The current demo checkout must have that HEAD and a clean porcelain status. Both artifact records, both start/result records, exact build commands/cwds, fresh runner-home records, API-unset/session metadata, successful exits, ending HEADs, and final status evidence are checked. The iOS post-build qualification must bind its clean final status, successful exit, HEAD, and artifact manifest hash to the iOS artifact; retained stdout must contain the native success marker for each platform. Paths and SHA-256 values for all raw build metadata, logs, artifacts, and the iOS qualification are saved in `demo-build-validation.json` and frozen under `demo.buildProof` in the candidate manifest.

All previously accepted QA candidate-1 backup verification, immutable promotion comparison, CLI/native version checks, runner extraction and install, cache preservation, approved WDA manifest qualification, runner Go proof, and candidate manifest construction remain in place.

## Verification

- Python source compiled in memory and parsed as an AST.
- Static checks confirmed both Swift commands use the same scratch path, products are constrained beneath it, the runner build home remains empty, and scratch contents are recorded.
- Static ordering checks confirmed clone command/inventory/current-entry authentication completes before the install call.
- The retained clone proof was read-only checked for exact source/clone equality and 8,593 entries.
- The existing raw iOS and Android records were read-only checked for the expected source SHA, successful exits, and ending HEADs.
- A temporary file-and-symlink inventory exercised the new size/hash/target matching predicates successfully.

No controller execution or reviewer dispatch was performed.
