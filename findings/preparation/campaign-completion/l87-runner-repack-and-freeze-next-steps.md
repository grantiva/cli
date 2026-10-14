# L87 runner-only repack and candidate-freeze next steps

Status: read-only preparation. No command in this document has been executed.

## Fixed inputs

- CLI functional source baseline: `73cfa99d94a00bbc0fd6fce13a7d72b9d9c29226`.
- Demo source remains `84af7581b75134b0e417b254e4317d565f7b73c6`; reuse its already accepted app/build proof only after rehashing every referenced byte.
- WDA cache/config payloads remain byte-identical to the approved package. L87 changes runner WDA selector code, not the bundled WDA server.
- Existing runner package workflow: `/Users/kyle/Developer/maestro-runner/.worktrees/package-round4-repair` and `findings/evidence/fix4-7b/`.
- Existing candidate controller pattern: `findings/evidence/completion-candidate4/prepare-candidate.py` and `candidate.json`.

## Required order

1. **Finish and review runner source and identity before packaging.** On the L87 runner branch, retain a minimal diff in `pkg/driver/wda/driver.go` plus targeted tests. The tests must cover competing same-label tab/back buttons, the no-back fallback, mismatched back label, and unchanged exact/regex/id/relative behavior. In this repository the release version is supplied by `scripts/build-runner.sh --version`; it is not a tracked runner source constant. Keep runner source unchanged for versioning and record the literal reviewed package argument (expected `1.1.28-grantiva.16`). The corresponding expected install stamp is that version plus the unchanged Android-driver suffix. Independent source/spec review must approve the exact source, tests and package-version argument before a package is built.
2. **Run runner verification on the reviewed tree.** Retain the author's already uncached focused result when it is bound to the exact reviewed tree; do not repeat it merely because the tree was committed. Run the required uncached full `go test -count=1 ./...` and `go vet ./...` after review, using fresh isolated caches/homes and API key unset. Repeat focused tests only if the reviewed diff changes afterward. Record exact argv, cwd, environment, times, exit, raw output, HEAD and clean status.
3. **Open runner PR, wait for required CI, then merge.** The reviewed version choice belongs to this PR, whether represented by a tracked version diff or a recorded package-version argument. The merged runner SHA is the only SHA permitted as the package input. Re-check clean HEAD after merge. Do not package an unmerged review commit and later claim the merge is identical without a tree proof.
4. **Carry the reviewed identity into packaging.** Use the exact reviewed runner version and its Android-driver-suffixed install stamp; do not make an uncommitted tracked-version edit after merge or derive a different value during candidate freeze.
5. **Use the established package script from the clean merged runner.** The fix4-7b workflow builds both `dist/grantiva-runner-arm64.tar.gz` and `dist/grantiva-runner-amd64.tar.gz`, checks flag parity, embeds version/commit metadata, and installs the two archives plus `RunnerManager.swift` version binding into a CLI packaging worktree. Capture before/after hashes for both runner archives and prove `android-drivers.tar.gz`, approved WDA cache manifests, configuration files and forbidden-file inventory are unchanged.
6. **Keep the CLI change packaging-only.** Start the CLI packaging branch at `73cfa99d94a00bbc0fd6fce13a7d72b9d9c29226`. The only expected CLI-repository changes are the two generated runner archives and the runner version/install-stamp binding in `RunnerManager.swift`. No CLI behavior source, docs, demo, WDA cache or Android-driver bytes change.
7. **Verify the packaged CLI source, then PR/CI/merge it.** Run the focused runner-resource/install-contract tests and the required clean full Swift suite on the packaging commit, followed by the repository's required CLI CI. Open the packaging PR only after local evidence is bound; merge only after required CI passes. Record the merged packaging SHA and a tree/diff proof against `73cfa99` showing the bounded three-path change.
8. **Build the replacement candidate only from that merged packaging SHA.** Adapt the candidate4 controller rather than introducing a new harness. Use a new exclusive evidence root, scratch directory, build home, runner home and session. Perform one clean release build, back up the current QA candidate before promotion, promote binary and bundle together, extract the arm64 archive, verify native version/commit/hash, and install into the fresh runner home.
9. **Freeze a new immutable manifest.** The manifest must record:
   - the new merged CLI packaging SHA, with `73cfa99` identified as its functional baseline;
   - new QA binary and bundle-file hashes;
   - new merged runner SHA, packaged/installed native hashes and new stamp;
   - fresh L87 runner test proof plus full/vet proof;
   - unchanged demo source/app manifest and rehashed proof references;
   - unchanged Android-driver/WDA cache hashes.
   Write the manifest exclusively, write its external SHA-256 record, then make both read-only.
10. **Validate only the affected candidate surface before resuming coverage.** Verify candidate identity and the narrow iOS semantic-back acceptance on owned iOS26 (and iOS27 if required by the brief), preserving original candidate4 failures. Broader smoke/replay scope is a root decision based on artifact impact; use the existing candidate4 helper package with new manifest/home/session bindings if requested.

## Identity constraint

A new runner cannot be embedded while literally retaining CLI source HEAD `73cfa99`: the two bundle archives and `RunnerManager.swift` stamp are tracked CLI inputs, so their update necessarily creates a new packaging-only CLI commit and a new release binary/bundle. “Unchanged CLI 73cfa99” must mean unchanged functional CLI source relative to that baseline, demonstrated by the bounded three-path diff. Claiming the old CLI SHA for a bundle containing new runner bytes would break source-to-artifact provenance.

## Candidate controller adjustments

Reuse the candidate4 controller controls: exclusive output labels, exact command capture, clean-source checks before/after the single release build, QA backup, bundle manifest, APFS-cloned runner home with pre-install equivalence, cache-only immutability after install, packaged/installed equality, and immutable candidate manifest. Change only the new evidence/scratch/home/session bindings and the runner/CLI identities. Unlike candidate4's unchanged-runner path, the replacement manifest must bind fresh runner test evidence and must not label it “unchanged-dependency provenance.”
