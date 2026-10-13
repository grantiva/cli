# Task 8 candidate 2 release controller review

**Verdict: APPROVED FOR CONTROLLER EXECUTION.** The three prior provenance findings are addressed with fail-closed preflight checks, and the focused corrections introduce no new scoped defect. This was a bounded read-only review; the script, builds, devices, and promotion were not run.

## Focused correction re-review

1. **Prior fresh-build P1 — ADDRESSED.** The script creates a new empty SwiftPM scratch directory, passes the same explicit `--scratch-path` to the release build and `--show-bin-path`, requires the returned products path to be contained by it, and records the scratch path, contents, and products path. The separate runner home used by build commands remains empty. For the frozen current state, the exact downstream-documentation path is `/private/tmp/grantiva-round4-candidate2-ciz5f2kj/swift-build-scratch`.

2. **Prior demo-provenance P1 — ADDRESSED.** The controller pins 84af explicitly; requires the current demo checkout to have that HEAD and a clean status; binds both artifact records and both start/result pairs to the same source, repo, command, working directory, fresh homes, API-unset session, time interval, successful exit, and ending HEAD; validates the exact platform build commands and success markers; and consumes the iOS clean post-build qualification with its matching manifest hash. Every raw proof file and log receives a frozen path/hash entry under `demo.buildProof`.

3. **Prior clone-binding P2 — ADDRESSED.** Before installation, the controller now requires the exact `cp -cR` source/destination and exit 0, the scratch-owned destination, identical source/clone inventories of exactly 8,593 entries, and a current byte-size/hash or symlink-target match for every entry. The retained post-install cache preservation checks remain separate and intact.

## Accepted controller behavior

- Candidate creation is guarded against overwrite, and CLI HEAD plus porcelain cleanliness are checked before and after the build/path lookup. The external PR/CI gate remains controller-owned as stated.
- The installed candidate 1 binary and complete bundle file list are checked against its frozen manifest before promotion. Binary, bundle, and candidate manifest are copied into a separate scratch backup and rechecked before QA replacement; promoted bytes are then compared with build outputs.
- Upgrade is performed through the promoted CLI with API credentials removed and session `fix4-8`. Packaged native version must be `.15`; installed path/stamp, byte hash, and complete native version output are bound to the packaged runner.
- Every recorded pre-existing cache entry is checked byte-for-byte after upgrade. Against the current fixed clone input, none of the four approved `*-wda16.12.8-r1` config names pre-exists, so all 800 approved bundled files are required byte-for-byte in the upgraded home; each config must also contain an app and xctestrun. The approved manifest's own SHA-256 is pinned.
- The candidate schema includes all 14 governing Go-proof artifacts with raw hashes, runner source/home/package/install fields expected by the approved identity helper, CLI binary and full bundle manifest, demo repo/app/APK fields, and the newly frozen demo build proof.

The reported in-memory compilation/AST checks, retained-metadata validation, and synthetic file/symlink inventory check directly cover the correction and were not repeated. Execution remains contingent on the controller's external merged-PR and CI gate stated in the task.
