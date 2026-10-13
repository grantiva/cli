# Task 7 final bundle review

## Verdict

- **Specification: PASS.** The final Task 7 product range `03cee568869c45077c3015f97f8b75d19ea822c4..80d3ad8d524878c899c7ab3e66ec310735bdcb12` satisfies Steps 1–6 of the brief and the plan's global constraints. Step 7 remains correctly bounded to the ongoing PR 212 review/CI and eventual merge; this review does not claim that external gate complete.
- **Quality: PASS.** I found no actionable source, bundle, provenance, cleanup, or evidence defect. The product worktree is clean at `80d3ad8d`; the runner packaging worktree is clean at `ff68658f73e4b6d9d94897d99ad1a0a270a105b7`; `git diff --check` passes for the full review range.

## Findings

No blocking or non-blocking findings.

## Independent evidence checks

- The frozen values are consistent across the ledger evidence, source, documentation, tests, and package: runner version `1.1.28-grantiva.14` and install stamp `1.1.28-grantiva.14+android-drivers-2`. The native arm64 executable extracted from the committed archive reports `grantiva-runner 1.1.28-grantiva.14`, commit `ff68658`, and `darwin/arm64`.
- Commit `80d3ad8d` changes only the two runner archives. Their committed SHA-256 values are `3dc5a4302cdc954035db3da97d7e8b3d37c7a14c839e75b99e35bc5b000120f7` for amd64 and `0888742a9a86413e48a250973eece1180c8c3695ad38c1bfc4de0a6ae4850fce` for arm64, exactly matching `swift-tests-final/clean-head-binding/archive-sha256.txt` and the Task 7 report. This makes the tests run with the archive-only modifications at `138c3413` applicable byte-for-byte to clean final head `80d3ad8d`.
- The governing WDA manifest contains exactly four configurations and 800 files: iOS 26.0, 26.2, 26.4, and 27.0 with WDA `16.12.8-r1`. Both extracted-archive manifests compare byte-for-byte equal to `wda/manifests-final/wda-cache.sha256`; the bundle entry lists contain exactly those four configuration roots and exclude the staging lock.
- Each accepted runtime record names its dedicated Task 7 UDID, clean CLI source head `138c3413`, isolated staging runner home, exit 0, `GrantivaAgent built` on stderr, absence of the cached-build marker, a complete xctestrun and WDA runner product, and no lingering runner process. These records support four genuinely fresh cache builds. The retained precondition-failed, incomplete-proof, and initial lock-bearing attempts are clearly identified as excluded and do not feed the governing manifest or archive conclusions.
- Cleanup evidence binds deletion to the four recorded Task 7 UDIDs and records all four devices, shadow homes, and leases absent while the shared cache manifest remained unchanged. The separate staging-root cleanup records that the exact dedicated root was absent afterward. Owner/default devices were not cleanup targets.
- Runner qualification is bound to `ff68658f`: the final verification records exit 0 for vet and the unbundled dual-architecture build, while `go-test-uncached` records the required four explicit package groups under `go test -count=1`, exit 0, unset API credentials, and empty before/after inventories for both isolated homes. This appropriately supersedes the cached uiautomator2 result in the earlier verification run.
- Final Swift evidence records exit 0 and empty before/after isolated homes for the required RunnerManager, JSON casing, and full suites. The full log reports 2,015 tests with zero failures: 281 GrantivaMCP, 971 GrantivaCore, 662 GrantivaCLI, and 101 GrantivaAPI. The corrected report now states these exact counts.
- Report-schema compatibility retains its prior independent PASS: the production-shaped fixture, semantic RED, 29-test focused GREEN, nested log-tail export, path containment, old-report compatibility, and post-cleanup byte survival are present and bound to the reviewed source. The seed app evidence is accurately limited to path, bundle ID, size/hash, and successful launch health; it does not claim source provenance, which belongs to Task 8's clean demo builds.

No tests, builds, or device operations were rerun for this review, as required.
