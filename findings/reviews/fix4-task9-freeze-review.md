# Task 9 candidate bridge and freeze review

**Specification verdict: APPROVED for the controller's gated primary provisioning. Evidence-quality verdict: APPROVED.** The Task 9 freeze preserves the accepted Task 8 candidate, correctly binds its zero gate and cleanup, and fills only execution identity metadata while retaining the approved blank coverage matrix and criteria. No blocking finding was identified.

This is a static bridge/freeze review, not provisioning acceptance or a Task 9 result. Primary provisioning, its protected-state checks, the controlled source-verification window and independent review still precede general slice dispatch. Creation of the three campaign worktrees at one commit is controller-owned and outside this artifact review.

## Candidate and gate

Independently recomputed hashes:

- Task 9 `candidate.json`: `d833797d30a794d8cfe9d2dc4646329d4f791667eb8dfa5d17cf417d827f744e`.
- `task8-zero-gate.json`: `561d91c5377c52bb373c53527f267223553b3d8a5af6008e3f9118de4f9531c8`.

The new candidate's entire `cli`, `runner`, and `demo` objects equal the original Task 8 candidate's objects as parsed JSON. Its original-manifest path/hash and `task8CandidateManifestSHA256` bind `e9cfc7dce72ba8125b7c55df8d3dec355925003de24a4131c6510b9e67c51ebf`. No executable, source SHA, artifact, or runner home was substituted.

The gate uses `grantiva.task8.zero-gate.v1`, has `passed: true`, and binds the new Task 9 candidate hash. Each reference to the original candidate, review, passing cleanup, freeze-verification and home/cache manifests matches its current bytes. The durable zero-gate review is byte-identical to the review I wrote; the cleanup remains the reviewed passing Task 8 physical cleanup. This bridge does not regrade the earlier failed candidates or remove any qualification in that review.

## Actual frozen bytes

Rehashed the QA CLI, packaged and installed runner, Android APK, all resource-bundle files and all iOS app files; all match the candidate. Complete bundle/app enumeration also matches, so extra files are not hidden by checking only declared entries.

The release-home manifest contains 12,580 entries. Every declared file digest/size, directory and symlink target matches, and its complete path set equals the current home. The WDA-cache manifest contains 11,345 entries, all matching, and equals precisely the home-manifest subset under `cache/wda-builds/`. These are the post-smoke home's complete cache inventory, not a replacement claim for Task 8's separately reviewed 800 packaged WDA files. Freeze-verification records the same candidate hash, counts and clean source identities: CLI `6ba12ed…`, runner `ba9008f…`, demo `84af7581…`.

## Matrix and criteria preservation

Every canonical matrix table line is byte-equal to the approved blank draft. Recomputed draft and canonical SHA-256 values match `execution-document-freeze.json`: `5069ead6…` and `09c054ed…`. The frozen criteria index differs from its approved draft only in `status`, concrete `candidate`, and added hash-bound `approvedDraft` / `candidateManifest` references. Candidate fields have no remaining `UNKNOWN` and agree with the manifest. Counts, criteria, row routing and expectations are unchanged: 1,314 logical rows; 1,489 effective results, comprising CLI 431, iOS 536 and Android 522; 39 separate iOS 27 supplemental keys. No grade was populated.

The canonical execution plan changes the title/status and canonical matrix reference while preserving the approved execution rules. Its introductory future-freeze wording is inherited; the concrete execution index now records that completed freeze, while the approved preparation index remains unchanged.

## Consumer compatibility

The primary-provision controller still hashes to independently approved `72be0a9f59c6516549c61cd72b0605510ad41ed07145380732c46e1257c75d8b`. The candidate's `grantiva.task9.candidate.v1` schema, nested fields, gate hash, review and cleanup references, passing cleanup JSON, existing home and exact artifact manifests satisfy its static preconditions. No helper invocation was needed to establish compatibility.

The approved source-window controller explicitly expects the original Task 8 hash in `task8CandidateManifestSHA256`, while checking the new candidate hash through gate/provision/shutdown bindings. Both identities are supplied correctly. Its source-SHA constants match the retained objects, and the approved command-inventory file still hashes to its pinned `15437fda241ded594234cb4c59c0378eb50a595222945a6bc13d8d006894fc5b`. Future provision/shutdown evidence remains mandatory; this review does not fabricate it.

Only static files and artifact bytes were read. No helper, test, build, device, process-query or network operation ran. Only this review document was written.
