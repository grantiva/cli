# Task 7 — repack and bundle the merged runner

## Result

Task 7 implementation and packaging are complete on product head `80d3ad8d524878c899c7ab3e66ec310735bdcb12`; final independent review, CI completion, and merge remain pending. The bundle uses the controller-frozen runner version `1.1.28-grantiva.14` and install stamp `1.1.28-grantiva.14+android-drivers-2`. Runner input was the clean merged head `ff68658f73e4b6d9d94897d99ad1a0a270a105b7`. CLI cache generation used clean source head `138c34136d544026a0b249c81af4129aa71b1297`; final head `80d3ad8d` adds only the two verified archive bytes.

The product diff contains the approved report/trace compatibility source and fixtures, the version/stamp documentation and tests, and the two generated runner archives. Campaign evidence and this report live only in the controller worktree.

## Runner qualification

`findings/evidence/fix4-7/runner-build/go-test-uncached/` is the governing test proof: `go test -count=1` executed all four required package groups at runner head `ff68658f`, with fresh empty `GRANTIVA_RUNNER_HOME` and `MAESTRO_RUNNER_HOME`, API credentials unset, exit 0, and both home inventories empty before and after. The earlier `runner-build/verification-final/` run remains valid for executor/report/CLI plus vet and dual-architecture build, but its uiautomator2 result was cached; the uncached run supersedes that one package result. `runner-build/` is retained as the initial successful build whose environment metadata was incomplete. No old raw evidence was rewritten.

The unbundled build produced both architectures, passed native flag parity, and stamped the frozen version. The runner packaging worktree remained clean at `ff68658f`.

## Fresh WDA caches

The governing source qualification is `findings/evidence/fix4-7/wda/inputs/final-source/`: clean runner `ff68658f`, clean CLI `138c3413`, exact frozen literals, and the exact seed CLI binary path and SHA-256. The seed app was the recorded existing DerivedData `Landmarks.app`; its path, bundle identifier, size and SHA-256 are preserved under `wda/inputs/`. It was proven healthy for this cache seed, without claiming source-build provenance.

The accepted live runs are exactly:

- `wda/builds/26.0/`: `D0F49870-E499-4434-8B11-DCC9132F7F3C`, `sim-ios26.0-iphone-wda16.12.8-r1`
- `wda/builds/26.2/`: `2F23D99B-CDB0-4049-A143-82E5701D867D`, `sim-ios26.2-iphone-wda16.12.8-r1`
- `wda/builds/26.4/`: `826F9080-5241-4B05-A4DD-9B7BF1985106`, `sim-ios26.4-iphone-wda16.12.8-r1`
- `wda/builds/27.0/`: `041FC430-3778-4DC6-98E9-31ED3B3C9C47`, `sim-ios27.0-iphone-wda16.12.8-r1`

Every accepted result records exit 0, `GrantivaAgent built` on stderr, no cached-build marker, complete xctestrun and WDA runner products, successful shared-cache promotion, and no lingering runner process. `wda/manifests-final/` is the governing four-configuration manifest set.

Cleanup targeted only the four recorded Task 7 simulator identifiers. `wda/cleanup/result.json` proves all four devices, shadow homes and leases absent and the shared cache unchanged. `wda/cleanup-stage-final/` records removal of the exact dedicated staging root after bundle comparison. The named owner devices and default runner home were never targeted.

## Bundle verification

`findings/evidence/fix4-7/wda/bundle-final/` is the accepted bundle proof. It records exit 0, exactly four configurations per architecture, exclusion of the staging lock file, byte-for-byte cache agreement with `wda/manifests-final/wda-cache.sha256`, and byte identity between the generated archives and the copies committed to CLI resources. The committed resource hashes are:

- amd64: `3dc5a4302cdc954035db3da97d7e8b3d37c7a14c839e75b99e35bc5b000120f7`
- arm64: `0888742a9a86413e48a250973eece1180c8c3695ad38c1bfc4de0a6ae4850fce`

## Explicitly excluded retained attempts

All paths below are immutable diagnostic evidence and do not contribute bytes or conclusions to the accepted package:

- `wda/builds-precondition-failed/26.0-uncommitted-cli/` is excluded because it ran before the `.14` source update was committed and therefore failed the clean-source precondition. Its generated cache was removed before the accepted rebuild.
- `wda/builds-incomplete-proof/26.0-self-process-false-positive/` is excluded because the process check matched its own inspection shell and stopped before writing a complete result. Although build artifacts existed, the proof was incomplete. Its cache was removed before the accepted rebuild.
- `wda/manifests/` and `wda/bundle/` are the initial manifest and bundle attempt. They included a staging `.lock` file as a fifth archive entry. The initial `swift-tests/runner-manager/` run detected this and failed. Those archives were replaced.
- `wda/manifests-final/` and `wda/bundle-final/` govern because they exclude `.lock`, contain exactly the four required configurations, compare byte-for-byte across staging, both extracted architectures, and CLI resource copies, and pass the packaging tests.

The failed and superseded raw logs were preserved unchanged. New accepted evidence was written to distinct `*-final` or accepted `builds/<runtime>` paths; no earlier result was reconstructed or overwritten.

## Swift verification

`findings/evidence/fix4-7/swift-tests-final/` contains the accepted fresh-home, API-unset runs against the final archive bytes:

- `runner-manager/`: 38 tests, 0 failures.
- `json-casing/`: 8 tests, 0 failures.
- `full/`: full `swift test` exit 0; 2,015 tests passed with zero failures: 281 GrantivaMCP, 971 GrantivaCore, 662 GrantivaCLI, and 101 GrantivaAPI tests.

Every accepted test home inventory is empty before and after. `swift-tests-final/clean-head-binding/` records clean product head `80d3ad8d` and the same archive hashes tested while those archives were the only modifications at `138c3413`; the archive commit changed no tested bytes.

Report/trace compatibility is separately documented in `task-7-compat-report.md`, including the production-shaped fixture, semantic RED, 29-test fresh-home focused GREEN, exact log-tail export, path containment, nested filenames, and ephemeral cleanup.

## Review boundary

No tag, release, or merge was performed. The remaining external action is review/CI and eventual merge under Task 7 Step 7.
