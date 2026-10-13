# iOS attempts 17–19 bounded review

**Verdict: approved for the rows currently graded from attempts 17–18. Attempt 19 is valid candidate evidence for three rows but was not yet graded when reviewed. No actionable evidence-integrity defect found.**

Scope excludes the running attempt 20 and all previously accepted historical/provenance areas. I derived the current set from exact ledger IDs rather than trusting footer arithmetic.

## Attempt 17

The frozen commands, exit files, stdout/stderr, durable reports, fixtures, and preserved capture manifest support the current rows IOS-134, IOS-135, IOS-141, IOS-142, B-A13.1, B-C04.2, B-C07.1, B-C08.1, B-C09.1, B-C09.2, B-C15.2, and B-R03.2.

- The failing-screen run exits 1, reports `Broken`, and then runs all eight configured `01-browse` steps successfully under continuation.
- The 45-second screen wait is terminated by the explicit 30-second cap; the command's 35-second wall time includes setup and is consistent with “about 30 seconds.”
- The steps config executes the documented path forms and records six named screens, actions, statuses, and durations. The verbose rerun confirms mixed-case swipes and the unconditional 3.0-second wait.
- The Maestro config reaches the owned device, runs the standard forms, retains ID-selector labels for tap/assert, and produces its two named captures.
- The exact-selector behavior is also documented and pinned in candidate README/source at exact candidate HEAD, so B-A13.1 is not being inferred merely from a passing regex assertion.

Durability is stated precisely in `PROVENANCE.md`: the first steps command and second steps command reused the same scratch capture paths. Only the second command's final six PNG bytes are retained in `preserved-final-captures/steps`; the first command's JSON remains evidence of six successful captures. The ledger does not claim that the first PNG byte set survived. Maestro PNGs and the final steps PNGs are protected by the checksum manifest. This limitation does not defeat the matrix's execution/capture-count clauses.

## Attempt 18

MCP-068 and B2-K102 are supported as currently described.

- MCP-068's live-session VRT call refuses at pre-execution validation when the config contains `runFlow`, names the need to stop the runner or use CLI capture, and does not partially run the capture.
- Attempt 16c supplies direct and scripted no-focus failures, including the named failing step and stopped script. Attempt 18 supplies both focused paths: a four-step script taps the field and types successfully, and a direct `grantiva_type` after focus succeeds with the updated hierarchy.
- The copied source map has explicit candidate provenance and identifies the exact iOS WDA, Android UIAutomator2, MCP direct-type, script-stop, and session-VRT tests. Inspection of the exact candidate confirms those are semantic focus/no-key tests rather than inherited names. The join is therefore appropriate: runtime proves the iOS focused/unfocused behavior while source pins the no-key transport behavior on both drivers. This review does not treat the copied map alone as live Android evidence.

## Attempt 19

Attempt 19 is durable and reviewable. Every command has separate command, exit, elapsed, stdout, and stderr files; the harness snapshots `.grantiva` after each material stage; `snapshots.sha256` inventories the preserved bytes. Unlike attempt 17's disclosed reuse, these per-stage copies preserve the threshold and stale-capture transitions.

The evidence supports these candidate grades once the iOS worker adds exact ledger rows:

- **IOS-094:** default compare exits 1 because `Caching` exceeds only `perceptual_threshold 5.0`; raising pixel `threshold` alone still exits 1 with the same named perceptual failure; raising both thresholds exits 0 with `passed:true`. The before/after configs, baselines, captures, and diff image are retained per stage.
- **IOS-146 and B-I03.1:** an initial one-screen capture succeeds and is preserved. The next capture uses the failing config, exits 1, and the post-failure snapshot contains no captures. The subsequent compare exits 1 with `No captures found ... Run: grantiva diff capture`, and no screen is reported passed. This directly establishes missing/stale capture refusal rather than relying on a final directory alone.

Attempt 19 does **not** establish IOS-095's subtle-color boundary case: its changed `Caching` image has perceptual distance about 69.3 and is tested by raising the configured threshold to 80, not by placing a subtle change just below and above 5.0. It also does not establish all B2-K108 message cases because it demonstrates perceptual-only failure and then a pass, not pixel-only and both-threshold failures. Neither row was graded at review time, so this is a scope boundary rather than a requested correction.

## Exact set and counts

At review time the attempt 17–18 additions present in the ledger are 14 unique IDs: IOS-134, IOS-135, IOS-141, IOS-142, MCP-068, B-A13.1, B-C04.2, B-C07.1, B-C08.1, B-C09.1, B-C09.2, B-C15.2, B-R03.2, and B2-K102. No duplicate exact IDs were found.

The current disclosed campaign base is **182/478: 172 pass, 5 fail, 5 blocked**, with **6** CLI handoffs and **39** repeat lines. Attempt 19 had added no ledger row at the time of inspection, so those three candidate grades are excluded from these counts. Adding IOS-094, IOS-146, and B-I03.1 as passes would produce 185 base rows and 175 passes, assuming no simultaneous unrelated ledger change.
