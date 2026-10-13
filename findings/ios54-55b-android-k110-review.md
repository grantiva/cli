# Scoped review: iOS attempts 54/55b and Android B2-K110

Candidate provenance: Grantiva CLI `8f2cff67`; maestro-runner `fd9d8e8`. This review used retained round-3 artifacts only and performed no live or device operations.

## Findings

### 1. B-I01.2 is substantively supported, but its ledger citations omit the source link that proves the observed homes were used for WDA isolation

Attempt 54 fully supports B-I01.1: `pair-1` through `pair-5` preserve ten independent exit files, every U1/U2 command exited 0/0, and `failed-pairs.txt` is empty. Each report identifies its intended UDID and flow.

For B-I01.2, `device-homes-before.txt` and `device-homes-after.txt` prove distinct versioned homes for both UDIDs, and the paired runner logs show concurrent WDA builds/starts for the two UDIDs on distinct ports (8511 and 8174). README line 98 documents the per-UDID xctestrun, port, and DerivedData contract. The semantic implementation is at absolute candidate paths:

- `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCore/Platform/IOSPlatform.swift:158-167` prepares a `WDADeviceHome` for the selected device and exports it as `MAESTRO_RUNNER_HOME`.
- `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCore/Runner/WDADeviceHome.swift:6-18,53-70` defines and prepares the distinct per-device cache/DerivedData home.
- `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests/WDADeviceHomeTests.swift:30-60` semantically asserts distinct simulator homes and independently mutable xctestrun contents.

Thus the pass is supported by the runtime/source/documentation join. The current ledger row cites only inventories, two reports, and README; adding the source/test paths would make the evidence chain explicit. This is a citation-quality correction, not a missing rerun.

### 2. Attempt 55b supports all three new iOS grades

- **B-C11.3 [ios]: supported.** In the empty directory, `mcp-empty/build.json` and `vrt.json` are `isError` results naming the exact missing `grantiva.yml`. `list.json` and `boot-owned.json` show config-independent simulator operations still work, including an actual explicit boot operation on the owned simulator. The before/after inventories remain stable.
- **B-C03.2 [ios]: supported.** `mcp-ios/ios-context.json` records the live iOS session's project, platform, bundle, device, and port. The Android server in the same project rejects it as an other-platform session in `mcp-android/android-tree.json`; `ios-still-live.json` proves the ignored iOS session remained usable.
- **MCP-079 [ios]: supported.** Attempt 25 supplies the different-project/same-platform half and attempt 55b supplies the same-project/other-platform half. Both return the documented no-session error and preserve the ignored session.

No material unsupported criterion was found in these rows.

### 3. B2-K110's driver contract passes; the later flow failure is consistent with L62 but its cause is not established

The row's exact driver requirements are supported:

- The default run's runner log and report both identify `uiautomator2`.
- `B2-K110-explicit-runner-rerun4/commands.txt` invokes the exact bundled `.13` runner with `--driver uiautomator2`; `driver-line.txt` and `report-driver.json` both identify `uiautomator2` before the later flow assertion fails.
- `source/runner-driver-source-tests.txt` captures the semantic default-iOS, default-Android, and explicit-mixed-case/lowercased cases from `pkg/cli/narration_test.go` at runner `fd9d8e8`.
- `/Users/kyle/Developer/maestro-runner/.worktrees/release-round3b/CHANGELOG.md:60` explicitly records the formerly empty `Driver:` line and the resolved `wda`/`uiautomator2` fix. The retained runner command/version establishes the bumped bundled runner used by the run.

The failed flow does not weaken those driver observations. Its raw sequence proves `Favorite` was tapped, `Unfavorite` appeared, Lake Tahoe was later visible, the `Remove from favorites` tap reported success, and the final hierarchy still exposed a `Remove from favorites` strip while the expected empty-state message was absent. This resembles the already tracked L62 favorite-removal behavior. It does **not** prove that the flow began selected, that another favorite polluted the fixture, or why the strip remained. The ledger's current wording appropriately says “resembles” and keeps L62 under separate review; it should not be strengthened to a causal claim. K110 should remain pass because every K110 observation occurs before and independently of that later application-state failure.

## Verdict

Approved with one minor evidence-link improvement for B-I01.2. B-I01.1, B-C11.3, B-C03.2, MCP-079, and B2-K110 are supported at their graded scope. The K110 flow failure is compatible with the known L62 symptom class but remains causally unresolved in this evidence.
