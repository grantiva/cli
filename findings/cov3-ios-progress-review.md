# Interim review — latest iOS evidence provenance and table integrity

Scope: read-only review of the current `cov3-ios` working tree, focused on attempts 2–4, `findings/evidence/cov3-ios/PROVENANCE.md`, historical-import exclusion, duplicate IDs, raw-capture overwrites, and the new verdicts those captures support. This is not completion approval. No device command or product/source edit was performed.

## Findings

### Important — N3-04 is graded pass from changed inputs

The matrix requires `grantiva_build {}`, `grantiva_run {}`, and `grantiva_test {}` for iOS, plus `grantiva_sim_boot {name: "cov3-ios-26"}` (`regression/docs/superpowers/plans/2026-10-13-round3-coverage-matrix.md:1557`). Attempt 2 instead sends both `scheme: "Landmarks (UI Testing)"` and `simulator: "cov3-ios-26"` to build, run, and test (`cov3-ios/findings/evidence/cov3-ios-attempt2/N3-04/requests.json`; raw responses in `mcp/transcript.txt`). Those responses do prove that the result formatting names the requested simulator and UDID, but they do not exercise the matrix's empty-argument config fallback. The ledger nevertheless grades N3-04 pass (`cov3-ios/findings/cov3-ios-results.md:44`). The footer already calls the attempt-2 explicit-scheme calls “input-variation evidence only” for other rows, making the N3-04 pass internally inconsistent. N3-04 should remain ungraded/blocked for its exact build/run/test inputs, or its note must be explicitly limited to the boot subcriterion until exact-input evidence exists.

### Important — established raw files were overwritten in place without a reconstructable rerun boundary

`run-session.sh` redirects each new capture to stable filenames while appending commands to the existing `commands.txt`. The current diff shows in-place replacement of:

- `findings/evidence/cov3-ios/B3-L13/stop.out`
- `findings/evidence/cov3-ios/B3-L43/start.out`
- `findings/evidence/cov3-ios/B3-L43/session.out`
- `findings/evidence/cov3-ios/N3-07/dump.out`

The corresponding command files contain repeated invocations, but every invocation names the same output filename. Earlier bytes are therefore no longer available from the working tree, and the ledger/provenance does not disclose that the cited evidence is the latest overwrite. The current files still support the stated shape/type verdicts, but their capture history is not auditable. Preserve future reruns in unique directories or filenames and add an explicit overwrite disclosure for these four current files.

### Important — provenance eligibility text is stale and incomplete

The results preamble says only pre-import captures plus “the ten post-recovery focused groups” in `PROVENANCE.md` are graded. The active ledger also grades new `B3-L15.2`, `MCP-031`, attempts 2–4, and five attempt-4 row copies. `PROVENANCE.md` describes attempts 2–4 but does not add `B3-L15.2` or `MCP-031` to its post-recovery group list, and the results preamble still describes only ten groups. This makes the eligibility rule contradict the rows it admits. Update the provenance inventory to enumerate every post-recovery eligible group and distinguish shared attempt-4 transcript copies from independently captured rows.

### Moderate — honest counts are stale after attempt-4 grading

The table currently has 151 rows: 145 pass, 5 blocked, and 1 fail. Of these, 39 are `@27.0` repeat lines, leaving 112 base rows: 106 pass, 5 blocked, and 1 fail. The footer still reports 107 base rows, 101 pass, 1 fail, 5 blocked, and 40 repeat lines. The difference aligns with the five new attempt-4 passes and the actual repeat count. Recompute the footer from the table after resolving N3-04; do not retain the present totals.

### Moderate — quarantined-import exclusion is documented but not fully self-verifying

The quarantine itself is clearly labeled excluded in `findings/evidence/cov3-ios-historical-cov2-import/README.md`, and the active results do not cite that directory. `PROVENANCE.md` points to the controller's identical/different manifests and names known historical additions under `STEP1`. However, its decisive pre-import inventory is only said to exist in the Task 4 agent transcript; no linkable snapshot of that exact inventory is stored beside `PROVENANCE.md`. A later reviewer can verify the quarantine and manifests, but cannot independently reconstruct which files inside pre-existing top-level directories were present before import. Persist the pre-import file list or a transcript reference with a stable path before completion approval.

## Checks that passed

- No exact duplicate table IDs were found: 151 rows, 151 exact IDs. Base IDs and explicit `@27.0` repeat IDs remain distinct.
- Attempt 3 raw responses support MCP-044, MCP-047, and MCP-048 as written. MCP-044 reports the configured simulator and no session; MCP-047/048 return the required simulator fields, including from the empty project directory.
- Attempt 4 uses one shared transcript copied byte-for-byte into all proposed row directories; `PROVENANCE.md` discloses that sharing and excludes the failed-starting responses from grading. The successful request IDs 5–7 support MCP-001, MCP-042, IOS-101, IOS-106, and the iOS half of X-020. The transcript shows PNG image content, the file path, and context tied to U1 rather than an arbitrary booted simulator.
- Attempt 4's excluded directories (MCP-009, MCP-017, MCP-021, MCP-076, IOS-108, IOS-109) are not graded in the current ledger.
- MCP-031's explicit simulator/scheme input matches the corrected matrix ruling at matrix line 867; its pass is not affected by the N3-04 input mismatch.
- IOS-112's explicit scheme matches the changed matrix input and its raw `isError` response includes xcodebuild's no-test-action reason.

## Interim disposition

The five attempt-4 verdicts and the three attempt-3 verdicts reviewed here are supported by raw responses. The current iOS ledger is not ready for completion approval because N3-04 overgrades changed inputs, counts are stale, the provenance eligibility list omits active groups, and overwritten raw files lack a clear rerun boundary.
