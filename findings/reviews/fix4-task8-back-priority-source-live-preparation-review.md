# Task 8 L85 source-live helper preparation review

## Verdict

**Specification compliance: CHANGES REQUIRED.** The live navigation sequence covers the intended collision and focused controls, but it does not yet prove the promised source/build/artifact identity or the required label-stage annotation.

**Safety and evidence quality: CHANGES REQUIRED.** The ownership document is not checked against actual simulator identity before runner start, and timeout/PID edge cases can leave incomplete cleanup evidence.

This is a static verdict. The helper must not be executed until its controller-supplied manifests and the checks below are corrected. It is non-final source evidence and cannot pass Task 8.

## Findings

### P1 — declared file lists and clean-state fields do not prove complete artifacts or clean sources

The bundle and app loops validate only files named by the manifest. A manifest containing the illustrative single entry passes while extra, missing-from-manifest files remain unchecked. The installed-app check repeats that same partial list. This contradicts the report's complete bundle/app-manifest claim.

Likewise, CLI and demo status are compared to controller-provided `cleanStatus` strings without requiring those strings to be empty. A manifest can bless a dirty checkout and the helper will accept the same dirty status.

Require `cleanStatus == ""` for both repos, then require live `git status --porcelain` to be empty. Compute the complete relative-path/SHA-256 manifest for the bundle and source app and require exact equality with their declared lists; apply the same complete equality to the installed app container. Reject duplicate paths and paths that are absolute or escape the declared root.

### P1 — frozen build proof is opaque and does not bind source HEAD to the tested binary/bundle

`frozenBuildProof` is validated only as an arbitrary existing file with a matching hash. Its contents are never parsed. The tested binary can therefore have the declared hash/version while being unrelated to `cli.head`; the adjacent bundle is similarly unbound. The resulting provenance record overstates a source-build identity.

Define and validate a small explicit build-proof schema. At minimum, require it to bind the resolved CLI repo and exact source HEAD to the release binary path/SHA-256 and the complete adjacent-bundle manifest or its canonical digest. Record those validated fields in `provenance.json`. The proof may remain explicitly non-final, but it cannot be an opaque hash.

Also require the installed runner path to be beneath the declared fresh runner home and bind the runner home/install identity to the source manifest. Presently any hash-matching runner path and any unrelated existing directory can be supplied independently.

### P1 — asserted ownership is not checked against actual simulator identity

Before runner start, the helper accepts `owned: true`, any nonempty runtime, and any nonempty creation-command array. It does not query CoreSimulator to establish that the exact UUID exists with the asserted name and runtime, nor does it bind the name/runtime pair. `fix4-back-26` can claim iOS 27 and still pass this validation. `get_app_container` proves only that the UUID has the app.

Capture `simctl list devices --json` before start and require one exact UUID with the expected pair: `fix4-back-26` on the approved iOS 26 runtime or `fix4-back-27` on the approved iOS 27 runtime. Require the recorded creation command to contain that exact name, device type and runtime, and persist the actual simulator record. This is a read-only identity check, not a new provisioning framework.

### P1 — the repaired back tap does not prove the retained label-stage annotation

The helper requires only `good(back)` before inspecting the resulting hierarchy. L85 explicitly preserves the label-match annotation for a preferred BackButton. A result annotated as an identifier fallback could therefore pass even though label-stage behavior changed.

Require the decoded response to begin with the ordinary label result `Tapped on "Landmarks". Updated hierarchy:` and then retain the existing Golden Gate checks from both the returned and fresh hierarchies. This distinguishes the required within-label preference from a changed fallback contract.

### P1 — cleanup can pass without an exact runner PID, and timeouts lose terminal evidence

After start, `owned_pid` may remain `None`; the final block then writes `ownedRunnerPidAbsent: true` without checking any PID. Require the started session to contain a valid positive integer PID before entering MCP acceptance, and prove that exact PID absent after stop.

`command()` also does not catch `subprocess.TimeoutExpired`. A timeout writes raw streams through the open file handles, but no terminal `result.json`, despite the report claiming start/end/exit evidence for every command. A start timeout is especially relevant because the process may have created a session before the wrapper raises. Catch the timeout, write a terminal result with timeout/end metadata, and re-raise so the existing scoped `finally` attempts exact session cleanup. Cleanup should still write its evidence when client close or stop encounters an error; preserve the original exception and cleanup failures rather than allowing an early cleanup exception to skip the remaining scoped checks.

## Controls that are already sound

- The helper is explicitly non-final and cannot claim Task 8 passed. It takes a literal UUID, fresh project/output paths, isolated runner home, session `fix4-85`, and an unset API key.
- The runner start command is explicit about iOS, UUID and bundle ID. Stop is scoped to the supplied project and refuses a session whose platform/UUID differs.
- The live sequence establishes cold unselected and selected literal-heart identifier behavior, placeholder fallback, quoted label handling, persistent tab stack, the application/back/tab collision, returned and fresh root hierarchies, an exact-UUID screenshot, and a live-frame coordinate control.
- L65 missing/wrong-type/empty controls and unknown-selector behavior are retained. The helper neither creates nor deletes a simulator and performs no broad process kill.

## Scope

I reviewed only `back_priority_source_live.py`, its preparation report and baseline diff. I did not execute the helper, touch a simulator, inspect ongoing tests, or review/modify the uncommitted product implementation.

## Scoped five-P1 fix re-review

**Final static verdict: APPROVED for the planned non-final source-live runs.** Revised helper SHA-256 `31593a6623298f58fc3ce524346074f5d7bb07c46337771af4bb4005ff0004ff` resolves all five finding groups without weakening the focused L85 sequence.

- `normalized_manifest()` rejects empty, duplicate, absolute and parent-escaping entries, prevents resolved paths from escaping their root, computes every regular file below the root, and requires exact sorted path/hash equality. The source and installed app manifests must also equal each other. Both repositories now require declared and actual empty porcelain status.
- The parsed `grantiva.fix4-85.release-build.v1` proof binds the resolved repository and exact current HEAD to a successful terminal build command, hash-bound raw stdout/stderr, the tested binary path/hash, and the complete adjacent-bundle manifest. Provenance retains those validated fields. The `.15` runner path is exactly bound beneath the declared fresh home and expected install stamp.
- The ownership record binds exact name/device type/runtime creation argv and preclaim ordering. Before start, a recorded `simctl` inventory must contain exactly one matching UUID with the declared name/runtime, and the `fix4-back-26`/`fix4-back-27` name must match the corresponding runtime major. The exact installed app is then checked before runner start.
- The repaired semantic tap now requires the ordinary label-stage prefix `Tapped on "Landmarks". Updated hierarchy:` before the returned and independent Golden Gate hierarchy checks.
- The started session must expose a positive integer runner PID before MCP acceptance. Command timeouts persist terminal metadata and partial stream sizes. Cleanup independently attempts client close and exact owned-project stop, then always checks session and exact-PID absence and writes the primary and cleanup errors. A cleanup-only failure prevents acceptance; a primary failure remains primary while its cleanup defects remain durable.

The source manifest and build-proof templates match the validator's required fields and are usable by the controller. The helper remains explicitly non-final, leaves physical simulator deletion to the controller, and cannot substitute for a merged replacement candidate or complete Task 8 rerun. No new actionable defect was found in this scoped revision; approval does not claim the ongoing build/tests or either live runtime has passed.
