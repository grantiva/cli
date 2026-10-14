# L87 CLI package review

Decision: **APPROVED.** Commit `5de5f36bd7132d981676830716ec1d946d5477e1` (tree `858d699c6edcf817e36893327ce07c2489dfb182`, parent `73cfa99d94a00bbc0fd6fce13a7d72b9d9c29226`) contains the reviewed four-path package change, and its affected and full Swift validation pass. I found no packaging defect. I did not run builds, tests, or live commands.

## Scope reviewed

The review is based on CLI base `73cfa99d94a00bbc0fd6fce13a7d72b9d9c29226`, runner squash merge `d98b08898f45b94bad607f76e19089bb0e15d5c0`, and reviewed runner head `9c18b962a0d85bcbb76fb8141fdd4aae97d28389`. Controller evidence `findings/evidence/fix6-L87-source/merge-acceptance.json` proves both runner commits have tree `060236c478bceba52bb7e54081dd06a44d6aa299` and binds the passing PR CI to the reviewed head.

The tracked CLI delta is exactly four paths:

- `Sources/GrantivaCore/Resources/grantiva-runner-arm64.tar.gz`
- `Sources/GrantivaCore/Resources/grantiva-runner-amd64.tar.gz`
- `Sources/GrantivaCore/Runner/RunnerManager.swift`
- `Tests/GrantivaCoreTests/RunnerManagerTests.swift`

The product Swift change is only `runnerVersion` from `.15` to `1.1.28-grantiva.16`; the existing expression therefore yields install stamp `1.1.28-grantiva.16+android-drivers-2`. The test change updates only the two corresponding `.15` expectations to `.16` in `testInstallStampChangesWhenDriversMoveButRunnerVersionDoesNot`. This is necessary constant maintenance after the preserved first focused failure at lines 507–508 and does not weaken the assertions. The captured bounded diff and current hashes are in `findings/reviews/campaign-completion/l87-package-review.diff`.

## Archive and dependency findings

Author proof under `findings/evidence/l87-package/archive-proof/` identifies runner source `d98b088…`, runner tree `060236c…`, and CLI base `73cfa99…`. Both archives carry `1.1.28-grantiva.16`, commit `d98b088`, Go `1.27.1`, `CGO_ENABLED=0`, clean VCS metadata, and the expected architecture (`darwin/arm64` or `darwin/amd64`). The arm64 executable's direct `--version` result exits 0; amd64 identity is necessarily established from its Go build metadata and embedded version strings on this arm64 host.

Both archive inventories contain 1,393 listed entries and their 1,392 cached-WDA file hashes are byte-identical across architectures. Both forbidden-entry reports are empty. Independent read-only comparison against the base archives found 2,903 regular non-runner members per architecture and zero added, removed, or changed members; this covers cached WDA and the archive-local driver material. The standalone `android-drivers.tar.gz` SHA-256 is unchanged from base at `59cbbf5725cfe682e857b8e1e3ec1a063a265c537aeee1fb57c5d4b8a5c1fb2c`. Because the tracked diff is exactly the two runner archives, `RunnerManager.swift`, and its two-value test expectation maintenance, demo and other packaged resources are unchanged.

The arm64 help captures retain the required app-file, checksum, no-install, artifact, device, fail-fast, flatten, keep-alive, output, retry, platform and wait-for-idle flags. The new archive hashes are arm64 `9b20219924504b5b30a85182708caa693caa8b15d3c4f5988cc563be877ba580` and amd64 `cb8cf912c80da1183591becb5d701953984f35beaccf506e7b570920d9813805`.

## Validation and final binding

`findings/evidence/l87-package/commit-proof.txt` (SHA-256 `40d5e15ea55aaa55949e36b252baba8e19de115bff887822dc915ce157905fdc`) records the exact commit, tree, parent, and four committed paths. `final-working-tree.sha256` (SHA-256 `b61d6fe02dd5a5d2b58b8ade27976fd6ed31b562afc1a817c39273f89163c1c4`) matches the committed reviewed bytes: arm64 archive `9b202199…`, amd64 archive `cb8cf912…`, RunnerManager `e5bba6ee…`, and RunnerManagerTests `ca6d96ba…`. The worktree has only untracked evidence after the commit.

The first focused run remains retained at exit 1 and fails solely on the two stale `.15` expectations. The adjacent affected rerun uses both runner-home variables at `/private/tmp/l87-swift-affected.Ycn3fI/runner-home`, API key unset, and passes the exact changed test 1/1; its exit file SHA-256 is `9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa` and stdout SHA-256 is `a34ea3e848a90a49d59fbd54ff2863e8136e3538fb1326876c553000f3df3277`.

The full suite uses a separate fresh home `/private/tmp/l87-swift-full.aE1lIj/runner-home`, both variables equal, API key unset, and exits 0. Its exit file SHA-256 is `9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa`; stdout SHA-256 is `96e0e82c1b8ac6eec5d975c8a465ea46efa9cdee9675fa81476e97ca591ef552`; stderr SHA-256 is `ebf1189fa44e69720e9e514eea01aaec87b27cbe638ff4f43578360e04402b45`. XCTest reports 667 GrantivaCore and 101 GrantivaAPI tests passing, with the other target summaries also green. The identity records were captured while HEAD remained the parent with exactly the four reviewed working-tree paths; the final hash manifest and commit proof bind those tested bytes to commit `5de5f36…`.

Any post-review archive regeneration or committed-path change reopens the affected identity and scope checks. The untracked `findings/` proof directory is evidence and is excluded from the four-path product diff.
