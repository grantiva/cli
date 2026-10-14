# Completion candidate5 controller readiness

Status: **prepared, statically parsed, not executed**.

`prepare-candidate.py` adapts the approved candidate4 controller. It preserves exclusive output creation, exact command metadata/raw capture, API-key removal, both isolated runner-home variables, clean source checks, one release build, QA backup-before-promotion, bundle/file manifests, pre-install clone equivalence, cache-byte preservation, packaged/installed native equality, unchanged demo proof verification, and immutable candidate manifest/hash output.

Candidate5 binding differences are recorded in `controller-vs-candidate4.diff`:

- new evidence root, source worktree, session, scratch/home namespace and candidate4 backup name;
- required, distinct CLI and runner merged-SHA arguments, both rejected while `PENDING`;
- reviewed runner SHA `9c18b962…` is retained as the test input identity; the controller requires its Git tree to equal the squash-merged runner tree and records both SHAs/trees plus the proof binding in the candidate manifest;
- before any build, the CLI merge is required to differ from functional baseline `73cfa99…` at exactly the two runner archives, `Sources/GrantivaCore/Runner/RunnerManager.swift`, and `Tests/GrantivaCoreTests/RunnerManagerTests.swift`; the test-file delta is limited to the two `.15` → `.16` expectation values required by the reviewed version bump;
- previous frozen identity is candidate4;
- new runner version `1.1.28-grantiva.16` and install stamp `1.1.28-grantiva.16+android-drivers-2`;
- fresh focused/full/vet runner proof and package/WDA preservation proof are mandatory and rehashed;
- demo SHA and its accepted build artifacts remain unchanged and are rehashed;
- pre-install clone entry count and hashes are derived from a fresh read-only APFS clone of the owner home `~/.grantiva/runner`; no historical entry count or candidate installed home is used.

Root must copy `initial-state.template.json` to `initial-state.json` and replace every `PENDING` binding after runner PR 28 and the packaging-only CLI PR merge. It must create a fresh read-only APFS clone from `/Users/kyle/.grantiva/runner` into the isolated candidate5 runner home, then capture current `source-before-upgrade.json`, `clone-before-upgrade.json`, and `clone-equivalence.json` with their actual entry count and hashes, and create an empty build home. The owner source is read only; candidate4 remains only the previous-manifest and QA-backup identity. The script refuses a scratch path containing `PENDING`, dirty/wrong source heads, existing candidate outputs, nonempty build home, mismatched QA candidate4 bytes, stale runner identity, missing/hash-mismatched proofs, or changed demo artifacts.

The runner version is an explicit `scripts/build-runner.sh --version` package argument, not a tracked runner source edit. The CLI packaging commit must remain the bounded four-path generated archive/RunnerManager stamp and matching test-constant update from functional baseline `73cfa99`.

`early-ios26-gate.template.json` is the mandatory first live gate after freeze and before broad smoke/campaign. Bind its manifest SHA, fresh frozen-demo copy, owned iOS26 UDID, and final candidate5 home. Execute the existing exact-command collector/controller convention; no new harness is introduced. Both `run --no-build` and `diff capture --no-build` must clear the Detail semantic-back path. A first failure stops broad work and remains preserved.

No build, test, packaging, promotion, device, or network command was run during this preparation.
