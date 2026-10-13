# Task 8 — repair candidate repack follow-up

## Result

The `.15` product package is complete at clean CLI commit `53b34ea38a82426a8dfd150fa64911ebbdb901aa`. It embeds runner `1.1.28-grantiva.15` built from clean merged runner commit `ba9008f4b2cd2c7320a9c46e04faed612b0958a2`; the install stamp is `1.1.28-grantiva.15+android-drivers-2`. The source base is merged CLI commit `d28bd212d7a5e67a3d92c05bde83d474a56c4a52`.

This task did not operate devices, promote or freeze a candidate, merge, tag, or release. Candidate 2 promotion remains gated on the controller's demo review, live acceptance, and merge requirements.

## Runner qualification

The governing uncached Go proof is `findings/evidence/fix4-7b/runner-build/go-test-uncached-metadata-complete/`. It is one combined `go test -count=1` run over the module root, `pkg/device`, `pkg/executor`, `pkg/report`, `pkg/cli`, and `pkg/driver/uiautomator2`. `start.json`, `result.json`, `argv.txt`, and `head.txt` bind the actual UTC interval, exact argv, API-unset `fix4-7b` environment, clean runner head `ba9008f4`, and distinct fresh empty `GRANTIVA_RUNNER_HOME` and `MAESTRO_RUNNER_HOME`. Both status files, both homes before and after, and stderr are empty. The root correctly reports no test files and all five required packages report `ok`; exit is 0.

The earlier `runner-build/go-test-uncached/` run also passed but omitted exact argv and timestamps from its result metadata. It is preserved unchanged and is superseded for candidate identity by the metadata-complete run; no fields were reconstructed.

The governing vet proof is `runner-build/go-vet-metadata-complete/`. Its actual timestamps, exact argv, clean `ba9008f4` head and statuses, API-unset `fix4-7b` environment, distinct fresh empty homes, fresh Go cache, empty stdout/stderr, and exit 0 bind `go vet` to the module root and the same five required package groups. The earlier `runner-build/go-vet/` run also passed but omitted exact argv, source, status, and timestamps; it is preserved unchanged and superseded for provenance by the metadata-complete run. `runner-build/package/` binds the clean runner head and clean pre-build status to the dual-architecture packaging command. The build log records the frozen version, runner commit `ba9008f`, both `darwin/arm64` and `darwin/amd64`, and native acceptance of all ten CLI-required flags.

## WDA reuse proof

`source-proof/` compares approved Task 7 runner source `ff68658f73e4b6d9d94897d99ad1a0a270a105b7` with final runner source `ba9008f4b2cd2c7320a9c46e04faed612b0958a2`. The only changed files are `pkg/device/devicelab_driver.go`, `pkg/device/uiautomator.go`, and the new `pkg/device/forward_cleanup_test.go`. The tree objects for `drivers/ios`, `pkg/driver/wda`, and `scripts/build-runner.sh` are identical, and the scoped diff exits 0 with no output.

`cache-proof/` extracts both approved `.14` embedded archives without touching an active runner home. Each architecture's WDA manifest compares byte-for-byte with Task 7 `wda/manifests-final/wda-cache.sha256`, whose SHA-256 is `48c95fede130e55ad3ec7cb018dfa487807a319dfe8274f5cf75ef6ca9390c5c`. Both contain exactly the four configurations for iOS 26.0, 26.2, 26.4, and 27.0, with 200 files per configuration. The forbidden-file and device-directory inventories are empty. This proves the approved WDA payloads were reusable; no device rebuild was needed or performed.

## Archive and resource proof

`archive-proof/` extracts the newly built archives and compares each complete `cache/wda-builds` manifest to the approved Task 7 manifest. Both archives contain exactly the four approved configurations, the expected WDA source package, and no lock, lease, version, or device-home artifacts. The CLI resource copies are byte-identical to runner `dist`.

Both extracted binaries execute successfully on this host and report the exact full version, commit, build time, Go version, and architecture. `go version -m` independently records the linker version `1.1.28-grantiva.15`, full VCS revision `ba9008f4b2cd2c7320a9c46e04faed612b0958a2`, clean VCS state, and correct architecture for each binary. The native help contracts contain all ten required flags. Final resource hashes are:

- arm64 runner: `12aae9dc17c9ce5942bcd5becd56d6a810932476633f6c5e1c3167e602c54761`
- amd64 runner: `c7bdb3703f23cadf464844cb77a250acc2a926b226d93728b29b1322eb15e132`
- Android drivers: `59cbbf5725cfe682e857b8e1e3ec1a063a265c537aeee1fb57c5d4b8a5c1fb2c`

The Android driver hash is identical before and after packaging. No Android payload changed.

## Swift verification and source binding

`swift-tests/focused-resource-contracts/` is the fresh-scratch, fresh-home focused run. It passes 38 `RunnerManagerTests`, 30 `SessionLifecycleTests`, 12 `DocsContractTests`, 8 `TeardownHelperReapTests`, and 5 `SelectorMatchTests`, with zero failures and both homes empty before and after.

`swift-tests/clean-head-full/` is the governing full Swift run. It records clean product head `53b34ea38a82426a8dfd150fa64911ebbdb901aa`, empty status before and after, exact resource hashes before and after, fresh empty homes, API credentials unset, session `fix4-7b`, and exit 0. It passes 2,022 tests with zero failures: 281 GrantivaMCP, 973 GrantivaCore, 667 GrantivaCLI, and 101 GrantivaAPI tests.

`source-binding/` preserves the complete tested pre-commit diff, final commit, clean post-commit status, and resource hashes. The governing clean-head full run removes any ambiguity from the earlier successful pre-commit full run.

## Product diff and review boundary

The product change replaces only the two runner archives and updates the frozen runner version in `RunnerManager`, its install-stamp test, documentation, and runner-version comments or fixtures. It does not change executable CLI behavior outside the embedded runner payload. The review package is `task8-repack-followup-review.diff`.

No candidate promotion, device smoke, merge, tag, or release was performed here. Those remain controller-owned and independently gated.
