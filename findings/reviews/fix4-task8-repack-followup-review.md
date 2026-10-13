# Task 8 repair candidate repack — independent review

## Verdicts

- **Spec: PASS.** The package contents, source binding, WDA reuse, metadata-complete uncached Go test and vet proofs, and Swift proof satisfy the execution binding.
- **Quality: PASS.** I found no correctness, maintainability, or unintended-scope defect in `d28bd212d7a5e67a3d92c05bde83d474a56c4a52..53b34ea38a82426a8dfd150fa64911ebbdb901aa` or in the embedded archives.

## Findings

None.

The prior vet-provenance P1 is resolved by `/Users/kyle/Developer/grantiva-cli/.worktrees/regression/findings/evidence/fix4-7b/runner-build/go-vet-metadata-complete/`. Its `start.json`, `result.json`, `argv.txt`, `head.txt`, and status files bind the actual 2026-10-13T19:04:32Z–19:04:38Z interval and exact root-plus-five-package `go vet` invocation to clean runner head `ba9008f4b2cd2c7320a9c46e04faed612b0958a2`. The proof records API unset, session `fix4-7b`, a fresh Go cache, distinct fresh empty runner homes before and after, empty stdout/stderr, and exit `0`. The updated report correctly preserves the earlier incomplete `runner-build/go-vet/` evidence and explicitly supersedes it for provenance.

## Verified scope and evidence

- The product commit has exact parent `d28bd212d7a5e67a3d92c05bde83d474a56c4a52`, is clean, and changes only the two runner archives plus seven `.14` to `.15` version/documentation/test literals. `git diff --check` passes.
- The committed archive hashes are arm64 `12aae9dc17c9ce5942bcd5becd56d6a810932476633f6c5e1c3167e602c54761` and amd64 `c7bdb3703f23cadf464844cb77a250acc2a926b226d93728b29b1322eb15e132`; they match runner `dist` and the clean-head tested-resource binding.
- Independent extraction confirmed native arm64 and x86_64 binaries. Both execute on this host and report `1.1.28-grantiva.15`, commit `ba9008f`, build time `2026-10-13T18:37:41Z`, Go `1.27.1`, and their correct architecture. `go version -m` records full revision `ba9008f4b2cd2c7320a9c46e04faed612b0958a2`, `vcs.modified=false`, and the `.15` linker version for both.
- Both binaries expose all ten required flags: `--app-file`, `--artifacts`, `--device`, `--fail-fast`, `--flatten`, `--keep-alive`, `--no-app-install`, `--output`, `--platform`, and `--wait-for-idle-timeout`.
- Each archive contains exactly the four approved iOS configurations (`26.0`, `26.2`, `26.4`, `27.0`). Independent hashing produced 800 manifest entries per architecture and byte-identical matches to `/Users/kyle/Developer/grantiva-cli/.worktrees/regression/findings/evidence/fix4-7/wda/manifests-final/wda-cache.sha256` (manifest SHA-256 `48c95fede130e55ad3ec7cb018dfa487807a319dfe8274f5cf75ef6ca9390c5c`). Recorded forbidden-file and device-directory inventories are empty.
- Approved and final runner WDA/driver/build inputs have identical tree listings and hashes. The only runner changes are `pkg/device/devicelab_driver.go`, `pkg/device/uiautomator.go`, and `pkg/device/forward_cleanup_test.go`.
- Android resource SHA-256 remains `59cbbf5725cfe682e857b8e1e3ec1a063a265c537aeee1fb57c5d4b8a5c1fb2c` before packaging, after packaging, and at clean-head verification.
- The superseding uncached Go test proof is metadata-complete and passes the module root plus all five required package groups at clean `ba9008f4b2cd2c7320a9c46e04faed612b0958a2`, with `-count=1`, a fresh `GOCACHE`, separate fresh runner homes, API unset, session `fix4-7b`, exact timestamps/argv, empty stderr, and exit `0`. The earlier incomplete proof remains preserved and is correctly superseded.
- The superseding vet proof is likewise metadata-complete and passes the exact module-root-plus-five-package scope at clean `ba9008f4b2cd2c7320a9c46e04faed612b0958a2`; the original incomplete vet evidence remains preserved and is correctly superseded.
- Focused resource contracts pass with the reported 38 RunnerManager, 30 SessionLifecycle, 12 DocsContract, 8 TeardownHelperReap, and 5 SelectorMatch tests. The governing clean-head full Swift run at `53b34ea38a82426a8dfd150fa64911ebbdb901aa` passes 2,022 tests (281 MCP, 973 Core, 667 CLI, 101 API), with clean status and unchanged resource hashes before/after. Its warnings are pre-existing compiler deprecations/style warnings outside this packaging diff.

No devices, broad test reruns, product edits, merge, tag, release, or candidate promotion were performed during this review.
