# Task 8 joint CLI/runner forward source-live review

Reviewed the raw joint run under `findings/evidence/fix4-84/joint-source-live`, the CLI release-build manifest and source-build identity, the runner override preparation identity, the L83 direct healthy run under `findings/evidence/fix4-83/live-direct-healthy`, the L83 source report/review for `6b3c206a5c2590c8384c5a01077a9bf932c83be4`, and the approved corrected controller in `forward_joint_live.py`. No tests, builds, source edits, or device actions were performed.

## Verdict: PASS for source/live readiness

No blocking source or live-evidence gaps were found for CLI PR 213 head `a587581723ec2599e0247c186d27667951959d9e` together with runner PR 27 head `6b3c206a5c2590c8384c5a01077a9bf932c83be4`.

This is explicitly a joint source-repair verdict. It is not packaged-candidate, `.15`, CI, merge, tag, or release acceptance. Current-head CI for the CLI and runner remains a separate controller gate, as do the merged/rebuilt candidate and final smoke.

## Source and binary provenance

- The CLI binary is bound to clean source head `a5875817…`: the release manifest records the exact source checkout, successful release build, binary path and SHA-256 `e2b83e78…`; the source-build identity records literal session `fix4-84`, API environment unset, empty fresh-home inventories, successful build, matching post-build head, and empty status. The joint run independently repeats the checkout HEAD/status and binary version checks.
- The runner is bound to source `6b3c206…` by the preparation identity and pinned binary SHA-256 `cb41a305…`. The joint run independently verifies that hash and captures the native first version line `grantiva-runner 1.1.28-grantiva.14-l83-check`.
- The runner resides beneath `versions/1.1.28-grantiva.14+android-drivers-2` solely because the unchanged CLI lookup uses that directory. The preparation and candidate records explicitly describe the APFS-cloned home as a test-only source-runner override. Neither artifact claims a packaged `.15` build.
- The owned target is consistently `fix4-forward-android` / `emulator-5582`, and every captured joint command records the isolated runner home, literal `GRANTIVA_SESSION_ID=fix4-84`, and API environment unset.

## Joint live acceptance

The initial serial inventory is empty. The controller then creates and verifies two unrelated controls:

- `emulator-5582 tcp:6790 tcp:16790`, whose local number deliberately equals UIAutomator2's remote driver port;
- `emulator-5582 tcp:62003 tcp:16791`, using an ADB-allocated local port.

All four cases pass with those two controls preserved:

1. **Foreground ready and SIGINT:** ready session PID `82028`, owned `tcp:62150 -> tcp:6790`, and tracked `localfilesystem:/tmp/uia2-emulator-5582.sock -> tcp:6790` coexist with both controls. Hierarchy succeeds. Stderr contains the exact notice `[grantiva] received SIGINT — releasing emulator and reaping child processes`; the foreground exits `130`. Immediate and delayed inventories contain exactly the two controls, the session file is absent, and PID `82028` is absent.
2. **Foreground ready and normal stop:** ready session PID `82118`, owned `tcp:62326 -> tcp:6790`, and the tracked local-filesystem socket coexist with both controls. Hierarchy succeeds. Production `runner stop --json` reports the same PID/port/device and exits `0`; the foreground also exits `0`. Immediate and delayed inventories contain exactly the two controls, the session file is absent, and PID `82118` is absent.
3. **Absent-app failure:** the CLI exits `1` for `com.grantiva.task8.absent`; runner PID `82208` is observed during the attempt. Immediate and delayed inventories contain exactly the two controls. Before/after project session, global session directory, and exact runner/device process inventories are clean, and both the CLI process and observed runner PID are absent afterward.
4. **Healthy stock:** the pinned runner exits `0`; its report records one passing flow and all 8 steps passing. PID `82276` is observed during execution and absent afterward. Immediate and delayed inventories contain exactly the two controls, with clean before/after project/global sessions and exact runner/device process inventories.

The controller's final cleanup inventory still contains exactly the two unrelated controls and removes those exact controls individually. The final serial inventory is empty. It does not use remove-all cleanup.

## Independent L83 direct healthy corroboration

The earlier direct native-runner evidence independently starts from an empty inventory, creates `tcp:6790 -> tcp:16790`, runs the same healthy stock flow with all 8 steps passing, and finishes with that control as the only remaining forward. The artifact records runner source `6b3c206…`, binary SHA-256 `cb41a305…`, literal session `fix4-83`, API environment unset, and exact final control cleanup. Its screenshot provenance preserves captured outputs separately and restores the immutable historical input bytes.

## Evidence integrity and limits

`acceptance.json` reports all four joint cases passed, and its claims agree with the raw command metadata, stdout/stderr, ready-session documents, process identities, forward inventories, and session/process snapshots. Cleanup assertions in the approved helper require exact control-only inventories immediately and after one second; for absent-app and healthy they additionally require no new global session files, no device-specific session records, no exact runner/device process, no PID-prefixed session file, and no surviving observed process.

The original failed/unresolved attempts remain preserved elsewhere and are not used as passing evidence. The earlier L83 direct healthy run is corroboration, while the corrected joint run is the governing integrated source-live evidence.

## Gate status

- CLI `a5875817…` source review: PASS.
- Runner `6b3c206…` source review: PASS.
- Joint source-live readiness for foreground ready/SIGINT, normal foreground stop, absent-app failure, and healthy stock: PASS.
- CLI and runner current-head CI: separate controller gates.
- Merge and merged/rebuilt packaged candidate, including any `.15` identity and final Task 8 smoke: separate controller gates.
